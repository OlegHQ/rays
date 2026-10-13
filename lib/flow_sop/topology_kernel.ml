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
           Flow.Value.validate(E.Record fields);
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
  | E.Source (("sop/count" | "sop/edges" | "sop/topology" as name), _, args) ->
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
                else
                  let index = Rdk.Topology_index.Private.view
                    (Rdk.Topology_index.create (G.topology geometry)) in
                  (match List.assoc_opt "component" args with
                   | Some (E.Text "a") -> Ok (E.Int_array (Array.copy index.edge_a))
                   | Some (E.Text "b") -> Ok (E.Int_array (Array.copy index.edge_b))
                   | _ -> error "E_DATA_SOURCE" "Edge source requires endpoint component a or b."))
       | _ -> error "E_DATA_SOURCE" "Topology source requires cooked geometry.")
  | _ -> error "E_DATA_SOURCE" "Unknown topology data source."
