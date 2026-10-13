module E = Flow.Eval
module G = Rdk.Geometry

let error code message = Error (Flow.Diagnostic.error ~code message)
let topology geometry component =
  let view = Rdk.Topology.Private.view (G.topology geometry) in
  match component with
  | "vertex_points" -> Ok (E.Int_array (Array.copy view.vertex_points))
  | "primitive_offsets" -> Ok (E.Int_array (Array.copy view.primitive_offsets))
  | "kinds" -> Ok (E.Int_array (Array.init (Bytes.length view.primitive_kinds)
      (fun i -> Char.code (Bytes.get view.primitive_kinds i))))
  | _ -> error "E_DATA_SOURCE" "Topology source requires vertex_points, primitive_offsets or kinds."

let adjacency geometry component =
  let view = Rdk.Topology_index.Private.view (Rdk.Topology_index.create (G.topology geometry)) in
  let array a = Ok (E.Int_array (Array.copy a)) in
  match component with
  | "primitive_of_vertex" -> array view.primitive_of_vertex
  | "next_vertex" -> array view.next_vertex
  | "previous_vertex" -> array view.previous_vertex
  | "edge_of_vertex" -> array view.edge_of_vertex
  | "opposite_vertex" -> array view.opposite_vertex
  | "edge_a" -> array view.edge_a
  | "edge_b" -> array view.edge_b
  | "point_edge_offsets" -> array view.point_edge_offsets
  | "point_edges" -> array view.point_edges
  | "point_vertex_offsets" -> array view.point_offsets
  | "point_vertices" -> array view.point_vertices
  | _ -> error "E_DATA_SOURCE" "Unknown adjacency component."

(* The union-find of [Analysis.classify_connectivity]: [over] edges labels
   points, [over] points labels primitives; a 0/1 mask keeps the labelled
   elements (-1 elsewhere, not counted). *)
let components geometry args =
  let owner = match List.assoc_opt "over" args with
    | None | Some (E.Text "edges") -> Ok (Rdk.Analysis.Connectivity_points, Rdk.Group.Point, G.point_count geometry)
    | Some (E.Text "points") -> Ok (Rdk.Analysis.Connectivity_primitives, Rdk.Group.Primitive, G.primitive_count geometry)
    | _ -> error "E_COMPONENTS_OVER" "Components :over is edges or points." in
  Result.bind owner (fun (owner, group_owner, count) ->
    let group = match List.assoc_opt "mask" args with
      | None -> Ok None
      | Some (E.Int_array mask) when Array.length mask = count ->
          if Array.exists (fun bit -> bit <> 0 && bit <> 1) mask then
            error "E_COMPONENTS_MASK" "Components mask holds only 0 and 1."
          else Ok (Some (Rdk.Group.init ~owner:group_owner ~name:"mask" count (fun i -> mask.(i) = 1)))
      | Some (E.Int_array _) -> error "E_COMPONENTS_MASK" "Components mask length differs from the labelled element count."
      | Some _ -> error "E_COMPONENTS_MASK" "Components mask is an integer array." in
    Result.bind group (fun group ->
      let primitives = if owner = Rdk.Analysis.Connectivity_primitives then group else None
      and points = if owner = Rdk.Analysis.Connectivity_points then group else None in
      match Rdk.Analysis.classify_connectivity ?primitives ?points owner geometry with
      | Error e -> error "E_COMPONENTS" (Rdk.Error.to_string e)
      | Ok (ids, n) -> (match List.assoc_opt "component" args with
          | Some (E.Text "count") -> Ok (E.Int n)
          | Some (E.Text "id") -> Ok (E.Int_array ids)
          | _ -> error "E_DATA_SOURCE" "Components source requires id or count.")))

(* Flow arrays remain reusable immutable inputs: owned native constructors
   receive copies, never the evaluator's retained input buffers. *)
let mesh_points = function
  | E.Vec3_array points as value ->
      Flow.Value.validate value;
      let count=Array.length points/3 in
      Ok(count,(fun ()->
        let x=Array.make count 0. and y=Array.make count 0. and z=Array.make count 0. in
        for i=0 to count-1 do x.(i)<-points.(3*i);y.(i)<-points.(3*i+1);z.(i)<-points.(3*i+2)done;
        Rdk.Packed.Float3.Private.of_owned_exn ~x ~y ~z))
  | E.Record fields when List.length fields=3 ->
      (match List.assoc_opt "x" fields,List.assoc_opt "y" fields,List.assoc_opt "z" fields with
       |Some(E.Float_array x),Some(E.Float_array y),Some(E.Float_array z)->
           (* Reuse the ordinary finite-array boundary before structural count
              validation. Retained Flow planes are never adopted by geometry. *)
           if max (Array.length x) (max (Array.length y) (Array.length z)) <= 65536 then
             Flow.Value.validate(E.Record fields)
           else begin
             let fields=Array.of_list fields in
             let errors=Rays_math.Parallel.init_array ~grain:1 (Array.length fields) (fun index->
               let value=snd fields.(index) in
               if index=0 then (Flow.Value.validate value;None)
               else try Flow.Value.validate value;None with
               |(Flow.Value.Fail _|Flow.Value.Diagnostic_fail _)as exn->Some exn) in
             Array.iter (Option.iter raise) errors
           end;
           if Array.length x<>Array.length y || Array.length x<>Array.length z then
             error "E_ARRAY_COUNT" "Mesh coordinate planes need the same element count."
           else begin
             let count=Array.length x in
             Ok(count,(fun ()->Rdk.Packed.Float3.Private.of_owned_exn
               ~x:(Array.copy x) ~y:(Array.copy y) ~z:(Array.copy z)))
           end
       | _,_,_->error "E_TOPOLOGY_TYPE" "Mesh planes require exactly x, y and z float arrays.")
  | E.Record _->error "E_TOPOLOGY_TYPE" "Mesh planes require exactly x, y and z float arrays."
  |_->error "E_TOPOLOGY_TYPE" "Mesh requires vec3 points and integer vertex_points, primitive_offsets and kinds arrays."
let mesh args =
  match List.assoc_opt "points" args, List.assoc_opt "vertex_points" args,
      List.assoc_opt "primitive_offsets" args, List.assoc_opt "kinds" args with
  | Some points, Some (E.Int_array vertices),
      Some (E.Int_array offsets), Some (E.Int_array kinds) ->
      (try
         Result.bind(mesh_points points)(fun(count,positions)->
         if Array.exists (fun kind -> kind < 0 || kind > 2) kinds then
           error "E_TOPOLOGY_KIND" "Primitive kinds are 0 (polygon), 1 (open polyline) or 2 (closed polyline)."
         else
           let kinds = Array.map (function 0 -> Rdk.Topology.Polygon
             | 1 -> Open_polyline | _ -> Closed_polyline) kinds in
           Result.bind (Result.map_error (Flow.Diagnostic.error ~code:"E_TOPOLOGY")
             (Rdk.Topology.create_owned ~point_count:count ~vertex_points:(Array.copy vertices)
               ~primitive_offsets:(Array.copy offsets) ~primitive_kinds:kinds)) (fun topology ->
             let positions=positions()in
             Result.map_error (Flow.Diagnostic.error ~code:"E_TOPOLOGY")
               (G.create ~positions ~topology ())))
       with Flow.Value.Fail (code, message, _) -> error code message
         | Flow.Value.Diagnostic_fail diagnostic -> Error diagnostic)
  | _ -> error "E_TOPOLOGY_TYPE" "Mesh requires vec3 points and integer vertex_points, primitive_offsets and kinds arrays."

let count geometry = function
  | "points" -> Ok (G.point_count geometry)
  | "vertices" -> Ok (G.vertex_count geometry)
  | "primitives" -> Ok (G.primitive_count geometry)
  | "edges" -> Ok (Rdk.Topology_index.edge_count (Rdk.Topology_index.create (G.topology geometry)))
  | _ -> error "E_TOPOLOGY_COUNT" "Count element is points, vertices, primitives or edges."

let resolve ~geometry = function
  | E.Source (("sop/count" | "sop/edges" | "sop/topology" | "sop/adjacency" | "sop/components" as name), _, args) ->
      (match List.assoc_opt "geometry" args with
       | Some (E.Deferred (ty, id)) when Flow.Ty.is_geometry ty ->
           (match geometry id with
            | None -> error "E_DATA_SOURCE" "Topology source has not been cooked."
            | Some geometry ->
                if name="sop/count" then
                  (match List.assoc_opt "element" args with
                   | Some (E.Text element) -> Result.map (fun n -> E.Int n) (count geometry element)
                   | _ -> error "E_TOPOLOGY_COUNT" "Count element is points, vertices, primitives or edges.")
                else if name="sop/topology" then
                  (match List.assoc_opt "component" args with
                   | Some (E.Text component) -> topology geometry component
                   | _ -> error "E_DATA_SOURCE" "Topology source requires vertex_points, primitive_offsets or kinds.")
                else if name="sop/components" then components geometry args
                else if name="sop/adjacency" then
                  (match List.assoc_opt "component" args with
                   | Some (E.Text component) -> adjacency geometry component
                   | _ -> error "E_DATA_SOURCE" "Adjacency source requires a component name.")
                else
                  let index = Rdk.Topology_index.Private.view
                    (Rdk.Topology_index.create (G.topology geometry)) in
                  (match List.assoc_opt "component" args with
                   | Some (E.Text "a") -> Ok (E.Int_array (Array.copy index.edge_a))
                   | Some (E.Text "b") -> Ok (E.Int_array (Array.copy index.edge_b))
                   | _ -> error "E_DATA_SOURCE" "Edge source requires endpoint component a or b."))
       | _ -> error "E_DATA_SOURCE" "Topology source requires cooked geometry.")
  | _ -> error "E_DATA_SOURCE" "Unknown topology data source."
module R = Rdk_core.Topology_remap

let remap ?cancel ~grain ~source ~target args =
  let module Failure = struct exception Error of Flow.Diagnostic.t end in
  let refuse code message = raise (Failure.Error (Flow.Diagnostic.error ~code message)) in
  let result code = function Ok value -> value | Error message -> refuse code message in
  let check () = Rdk.Cancel.check_opt cancel in
  try
    check ();
    if grain <= 0 then refuse "E_REMAP" "Remap grain must be positive.";
    let positions = match List.assoc_opt "positions" args with
      | None | Some (E.Text "target") -> false
      | Some (E.Text "mapped") -> true
      | _ -> refuse "E_REMAP_POLICY" "Remap positions is target or mapped." in
    let mapping name source_count target_count =
      match List.assoc_opt name args with
      | Some (E.Int_array map) ->
          if Array.length map <> target_count then
            refuse "E_REMAP_COUNT" ("Remap " ^ name ^ " map must match target owner count.");
          Array.iteri (fun row index ->
            if row land 4095 = 0 then check ();
            if index < 0 || index >= source_count then
              refuse "E_REMAP_INDEX" ("Remap " ^ name ^ " source index is out of bounds.")) map;
          map
      | _ -> refuse "E_REMAP_TYPE" ("Remap " ^ name ^ " requires an integer array.") in
    let point_map = mapping "points" (G.point_count source) (G.point_count target) in
    let vertex_map = mapping "vertices" (G.vertex_count source) (G.vertex_count target) in
    let primitive_map = mapping "primitives" (G.primitive_count source) (G.primitive_count target) in
    let target_topology = G.topology target and source_topology = G.topology source in
    (* Explicit CSR is checked even if there are no source edge groups. *)
    let edge_groups = match List.assoc_opt "edges" args with
      | None when G.edge_groups source = [] -> []
      | None when source_topology == target_topology -> G.edge_groups source
      | None -> refuse "E_REMAP_EDGES" "Remap changed topology requires explicit edge ancestry."
      | Some (E.Record fields) ->
          (match fields with
           | ["offsets", E.Int_array offsets; "values", E.Int_array ancestors]
           | ["values", E.Int_array ancestors; "offsets", E.Int_array offsets] ->
               if G.edge_groups source = [] then [] else
               let source_index = Rdk.Topology_index.create ?cancel source_topology
               and target_index = Rdk.Topology_index.create ?cancel target_topology in
               result "E_REMAP_EDGES" (R.edge_groups_from_ancestry ?cancel ~grain ~source_index
                 ~target_topology ~target_index ~offsets ~ancestors (G.edge_groups source))
           | _ -> refuse "E_REMAP_EDGES" "Remap edges requires offsets and values integer arrays.")
      | Some _ -> refuse "E_REMAP_EDGES" "Remap edges requires offsets and values integer arrays." in
    let identity map =
      let same = ref true in
      Array.iteri (fun i value -> if i land 4095 = 0 then check (); if i <> value then same := false) map;
      !same in
    let point_same = Array.length point_map = G.point_count source && identity point_map
    and vertex_same = Array.length vertex_map = G.vertex_count source && identity vertex_map
    and primitive_same = Array.length primitive_map = G.primitive_count source && identity primitive_map in
    let attributes = List.map (fun attribute ->
      check ();
      match Rdk.Attribute.owner attribute with
      | Detail -> attribute
      | Point when point_same -> attribute
      | Vertex when vertex_same -> attribute
      | Primitive when primitive_same -> attribute
      | Point -> R.attribute ?cancel ~grain point_map attribute
      | Vertex -> R.attribute ?cancel ~grain vertex_map attribute
      | Primitive -> R.attribute ?cancel ~grain primitive_map attribute) (G.attributes source) in
    let groups = List.map (fun group ->
      check ();
      match Rdk.Group.owner group with
      | Point when point_same -> group
      | Vertex when vertex_same -> group
      | Primitive when primitive_same -> group
      | Point -> R.group ?cancel ~grain point_map group
      | Vertex -> R.group ?cancel ~grain vertex_map group
      | Primitive -> R.group ?cancel ~grain primitive_map group) (G.groups source) in
    let positions = if not positions then G.positions target
      else if point_same then G.positions source
      else let p = Rdk.Packed.Float3.Private.view (G.positions source) in
        Rdk.Packed.Float3.Private.of_owned_exn
          ~x:(R.select_float ?cancel ~grain point_map p.x)
          ~y:(R.select_float ?cancel ~grain point_map p.y)
          ~z:(R.select_float ?cancel ~grain point_map p.z) in
    check ();
    let output = result "E_REMAP" (G.create ~positions ~topology:target_topology
        ~attributes ~groups ~edge_groups ()) in
    check (); Ok output
  with Failure.Error diagnostic -> Error diagnostic
