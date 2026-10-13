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
