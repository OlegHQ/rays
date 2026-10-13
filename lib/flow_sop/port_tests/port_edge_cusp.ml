(* sop/edge_cusp: one geometry input. Fixtures: polygon grids (manifold), a non-manifold fan, and the mixed
   polygon+polyline shape (selected polyline edges are an error case), some with point N. *)
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
let fan () = curves ~points:7 ~vertex_points:[|0;1;2; 1;0;3; 0;1;4; 2;3;5;6|]
  ~offsets:[|0;3;6;9;13|] ~kinds:[|Topology.Polygon; Polygon; Polygon; Closed_polyline|]
(* Two triangles sharing an edge, a third attached at a point only. *)
let bowtie () = curves ~points:7 ~vertex_points:[|0;1;2; 1;3;2; 2;4;5|] ~offsets:[|0;3;6;9|]
  ~kinds:[|Topology.Polygon; Polygon; Polygon|]
(* A surface that all edges of one group select: a closed cube-like quad ring. *)
let ring () = curves ~points:8 ~vertex_points:[|0;1;2;3; 4;5;6;7; 0;1;5;4; 1;2;6;5; 2;3;7;6; 3;0;4;7|]
  ~offsets:[|0;4;8;12;16;20;24|] ~kinds:(Array.make 6 Topology.Polygon)
let with_normals g =
  let n = Geometry.point_count g in
  let nx = Array.init n (fun i -> float (i mod 3) *. 0.25) and ny = Array.init n (fun _ -> 1.) and nz = Array.make n 0. in
  let attribute = Attribute.create_owned ~owner:Attribute.Point ~name:"N"
    (Attribute.Float3 (Packed.Float3.Private.of_owned_exn ~x:nx ~y:ny ~z:nz)) |> get_string_ok in
  Geometry.with_attribute attribute g |> get_string_ok

let inputs = List.map (fun (label, g) -> label, [g]) [
  "empty", decorate (points 0); "single", decorate (points 1);
  "mixed", decorate (polygon_polyline ());
  "fan", decorate (fan ());
  "bowtie", decorate (bowtie ());
  "ring", decorate (ring ());
  "grid", decorate (small_grid ());
  "grid-normals", with_normals (decorate (small_grid ()));
  "triangles-normals", with_normals (decorate (triangles ()));
  "grid4225", decorate (grid ()) ]

let fields group normals = ["group", P.Text_value group; "update_point_normals", P.Bool_value normals]
let cases =
  List.concat_map (fun normals ->
    List.map (fun (label, group) -> Printf.sprintf "%b/%s" normals label, fields group normals)
      ["none", ""; "a", "a"; "dest", "dest_a"; "old", " old_x "; "missing", "nothing"])
    [true; false]
  @ [ "literal", fields "literal *?[]^\\" true; "unicode", fields "\195\169\231\140\171" true ]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:300 ~rows:300 ~size:8. () |> get_ok in
  let topology = Geometry.topology g in
  let index = Topology_index.create topology in
  let g = Geometry.with_edge_group (Edge_group.init ~topology ~index ~name:"half" (fun e -> e mod 3 = 0)) g
    |> get_string_ok in
  [g], fields "half" false
let () = register { key = "edge_cusp"; native = Sop.Nodes.Edge_cusp.factory; inputs; cases; ulps = 4;
  bench = Some bench }
