(* sop/edge_divide: one geometry input. Fixtures carry groups (edge, point, vertex; ordered and plain)
   and attributes of every owner and type. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param

let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:3 ~rows:3 ~size:2. () |> get_ok
let triangles () = Plane_generators.grid ~connectivity:Grid_triangles ~columns:3 ~rows:2 ~size:2. () |> get_ok
let decorate g = fixture_attributes (fixture_groups g)
let curves ~points:count ~vertex_points ~offsets ~kinds =
  let topology = Topology.create_owned ~point_count:count ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> get_string_ok in
  Geometry.create ~positions:(Geometry.positions (Port_gate.points count)) ~topology () |> get_string_ok
(* Three triangles sharing the edge 0-1 (non-manifold), plus a closed polyline. *)
let fan () = curves ~points:7 ~vertex_points:[|0;1;2; 1;0;3; 0;1;4; 2;3;5;6|]
  ~offsets:[|0;3;6;9;13|] ~kinds:[|Topology.Polygon; Polygon; Polygon; Closed_polyline|]

let inputs = List.map (fun (label, g) -> label, [decorate g]) [
  "empty", points 0; "single", points 1;
  "mixed", polygon_polyline ();
  "fan", fan ();
  "grid", small_grid ();
  "triangles", triangles ();
  "grid4225", grid () ]

let fields group divisions share =
  ["group", P.Text_value group; "divisions", P.Int_value divisions; "share_points", P.Bool_value share]
let cases =
  List.concat_map (fun share ->
    List.concat_map (fun divisions ->
      List.map (fun (label, group) -> Printf.sprintf "%b/%d/%s" share divisions label, fields group divisions share)
        ["all-none", ""; "a", "a"; "dest", "dest_a"; "old", " old_x "])
      [1; 2; 3; 5])
    [true; false]
  @ [ "missing", fields "missing" 2 true; "literal", fields "literal *?[]^\\" 3 false;
      "unicode", fields "\195\169\231\140\171" 2 true; "divisions 64", fields "a" 64 true ]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:300 ~rows:300 ~size:8. () |> get_ok in
  let topology = Geometry.topology g in let index = Topology_index.create topology in
  let g = Geometry.with_edge_group (Edge_group.init ~topology ~index ~name:"half"
      (fun e -> e mod 2 = 0)) g |> get_string_ok in
  [g], fields "half" 2 true
let () = register { key = "edge_divide"; native = Sop.Nodes.Edge_divide.factory; inputs; cases; ulps = 4;
  bench = Some bench }
