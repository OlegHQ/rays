(* D.1 / D.2: sop/adjacency and sop/components against the native indices. *)
module E = Flow.Eval
module G = Rdk.Geometry
module T = Rdk.Topology
let ok = function Ok value -> value | Error message -> failwith message
let flow_ok = function Ok value -> value | Error d -> failwith (Flow.Diagnostic.to_string d)

let fixtures () =
  let topology points vertex_points primitive_offsets primitive_kinds =
    T.create_owned ~point_count:points ~vertex_points ~primitive_offsets ~primitive_kinds |> ok in
  ["empty", T.empty ~point_count:0;
   "shared-polygons", topology 5 [|0;1;2;2;1;3|] [|0;3;6|] [|T.Polygon;Polygon|];
   "open-repeated", topology 3 [|0;1;1;2;1|] [|0;5|] [|T.Open_polyline|];
   "closed", topology 4 [|3;2;1;0|] [|0;4|] [|T.Closed_polyline|];
   "mixed-nonmanifold", topology 6 [|0;1;2;0;1;3;1;0;4;0;1;5|]
     [|0;3;6;9;12|] [|T.Polygon;Open_polyline;Closed_polyline;Polygon|]]
  |> List.map (fun (name, topology) ->
    let count = T.point_count topology in
    let positions = Rdk.Packed.Float3.Private.of_owned_exn
      ~x:(Array.init count float) ~y:(Array.make count 0.) ~z:(Array.make count 0.) in
    name, (G.create ~positions ~topology () |> ok))

let evaluate geometry body =
  let source = "(workspace adjacency (graph g :context sop [(geo : geometry nil)] (let* [tested " ^ body ^ "] geo)))" in
  let forms = Flow.Syntax.parse source |> flow_ok in
  let checked = match Flow.Workspace.check ~ops:Flow_sop.Operators.all {Flow.Check.version=1;kinds=[]} forms with
    | Some checked, [] -> checked
    | _, ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds)) in
  let value = Flow.Eval.static ~record:true ~inputs:["g",["geo",E.Deferred (Flow.Ty.geometry,7)]] checked
    |> flow_ok |> fun evaluation -> List.assoc ["g";"tested"] evaluation.records |> List.hd |> snd in
  value, Flow_sop.Attribute_kernel.resolve ~geometry:(fun id -> if id=7 then Some geometry else None)

(* Both execution tiers at one and eight domains must return the same value. *)
let agree geometry body expected =
  let value, resolve = evaluate geometry body in
  let live = Frame_input.at_time 0.25 in
  let core = Flow_ir.Executor.compile ~strict:true value |> flow_ok in
  List.iter (fun domains -> Rays_math.Parallel.run ~domains (fun () ->
    assert (flow_ok (E.Private.force_reference ~resolve value ~live) = expected);
    assert (flow_ok (Flow_ir.Executor.force ~strict:true ~resolve core ~live) = expected))) [1;8]

let ok_error = function Ok value -> value | Error e -> failwith (Rdk.Error.to_string e)
let ints a = E.Int_array (Array.copy a)

let () =
  List.iter (fun (_, geometry) ->
    let index = Rdk.Topology_index.create (G.topology geometry) in
    let v = Rdk.Topology_index.Private.view index in
    agree geometry "(sop/adjacency geo)" (E.Record [
      "primitive_of_vertex", ints v.primitive_of_vertex; "next_vertex", ints v.next_vertex;
      "previous_vertex", ints v.previous_vertex; "edge_of_vertex", ints v.edge_of_vertex;
      "opposite_vertex", ints v.opposite_vertex; "edge_a", ints v.edge_a; "edge_b", ints v.edge_b;
      "point_edge_offsets", ints v.point_edge_offsets; "point_edges", ints v.point_edges;
      "point_vertex_offsets", ints v.point_offsets; "point_vertices", ints v.point_vertices]);
    agree geometry "(get (sop/adjacency geo) :edge_a)" (ints v.edge_a)) (fixtures ());
  let resolve = Flow_sop.Attribute_kernel.resolve ~geometry:(fun _ -> None) in
  List.iter (fun geometry -> match resolve (E.Source ("sop/adjacency", Flow.Ty.Array Int,
      ["geometry",geometry;"component",E.Text "next_vertex"])) with
    | Error d -> assert (d.code = "E_DATA_SOURCE") | Ok _ -> assert false)
    [E.No_geo; E.Deferred (Flow.Ty.geometry,7)]

(* D.2: ids and count equal Analysis.classify_connectivity, with and without a mask. *)
let () =
  List.iter (fun (_, geometry) ->
    List.iter (fun (over, owner, group_owner, count) ->
      let classify mask =
        let group = Option.map (fun mask -> Rdk.Group.init ~owner:group_owner ~name:"m" count
          (fun i -> mask.(i) = 1)) mask in
        let primitives, points = if owner = Rdk.Analysis.Connectivity_primitives then group, None else None, group in
        let ids, n = Rdk.Analysis.classify_connectivity ?primitives ?points owner geometry |> ok_error in
        E.Record ["id", ints ids; "count", E.Int n] in
      agree geometry (Printf.sprintf "(sop/components geo :over \"%s\")" over) (classify None);
      let mask = Array.init count (fun i -> if i mod 3 = 1 then 0 else 1) in
      let literal = String.concat " " (Array.to_list (Array.map string_of_int mask)) in
      agree geometry (Printf.sprintf "(sop/components geo :over \"%s\" :mask (array/int %d 1))" over count)
        (classify (Some (Array.make count 1)));
      if count > 0 then
        agree geometry (Printf.sprintf
          "(sop/components geo :over \"%s\" :mask (exact (map (fn [(i : int)] (if (int/eq (int/mod i 3) 1) 0 1)) (array/range %d :type int))))"
          over count) (classify (Some mask));
      ignore literal)
      [ "edges", Rdk.Analysis.Connectivity_points, Rdk.Group.Point, G.point_count geometry;
        "points", Rdk.Analysis.Connectivity_primitives, Rdk.Group.Primitive, G.primitive_count geometry ])
    (fixtures ())

(* sop/components :seams, a 0/1 edge mask: ids and count equal Analysis.classify_connectivity with the
   same seam edge group (alone and with a mask), and a bad mask is E_COMPONENTS_SEAMS. *)
let () =
  List.iter (fun (_, geometry) ->
    let topology = G.topology geometry in
    let index = Rdk.Topology_index.create topology in
    let edges = Rdk.Topology_index.edge_count index in
    let seam_bit i = i mod 3 = 1 in
    let seams = Rdk.Edge_group.init ~topology ~index ~name:"seams" seam_bit in
    let seam_text = Printf.sprintf
      "(exact (map (fn [(i : int)] (if (int/eq (int/mod i 3) 1) 1 0)) (array/range %d :type int)))" edges in
    List.iter (fun (over, owner, group_owner, count) ->
      let classify mask =
        let group = Option.map (fun mask -> Rdk.Group.init ~owner:group_owner ~name:"m" count
          (fun i -> mask.(i) = 1)) mask in
        let primitives, points = if owner = Rdk.Analysis.Connectivity_primitives then group, None else None, group in
        let ids, n = Rdk.Analysis.classify_connectivity ?primitives ?points ~seams owner geometry |> ok_error in
        E.Record ["id", ints ids; "count", E.Int n] in
      if edges > 0 then begin
        agree geometry (Printf.sprintf "(sop/components geo :over \"%s\" :seams %s)" over seam_text) (classify None);
        let mask = Array.init count (fun i -> if i mod 4 = 2 then 0 else 1) in
        if count > 0 then
          agree geometry (Printf.sprintf
            "(sop/components geo :over \"%s\" :seams %s :mask (exact (map (fn [(i : int)] (if (int/eq (int/mod i 4) 2) 0 1)) (array/range %d :type int))))"
            over seam_text count) (classify (Some mask))
      end)
      [ "edges", Rdk.Analysis.Connectivity_points, Rdk.Group.Point, G.point_count geometry;
        "points", Rdk.Analysis.Connectivity_primitives, Rdk.Group.Primitive, G.primitive_count geometry ];
    let refused body code =
      let value, resolve = evaluate geometry body in
      match E.Private.force_reference ~resolve value ~live:(Frame_input.at_time 0.25) with
      | Error d -> assert (d.code = code) | Ok _ -> assert false in
    refused (Printf.sprintf "(sop/components geo :seams (array/int %d 0))" (edges + 1)) "E_COMPONENTS_SEAMS";
    if edges > 0 then refused (Printf.sprintf "(sop/components geo :seams (array/int %d 2))" edges) "E_COMPONENTS_SEAMS")
    (fixtures ());
  print_endline "Components seams: edge mask equals Analysis.classify_connectivity with seams, alone and masked"
