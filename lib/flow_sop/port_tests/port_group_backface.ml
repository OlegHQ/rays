(* sop/group_backface: one geometry input (pending draft). *)
open Port_gate
module P = Param
let t name v = name, P.Text_value v
let c name v = name, P.Choice_value v
let f name v = name, P.Float_value v
let cases =
  ["defaults", [];
   "below", [f "viewpoint_z" (-10.)];
   "side", [f "viewpoint_x" 50.; f "viewpoint_z" 0.];
   "on_plane", [f "viewpoint_z" 0.; f "viewpoint_x" 0.5];
   "diagonal", [f "viewpoint_x" 3.; f "viewpoint_y" (-4.); f "viewpoint_z" 2.];
   "origin", [f "viewpoint_z" 0.];
   "huge", [f "viewpoint_x" 1e300; f "viewpoint_y" (-1e300); f "viewpoint_z" 1e300];
   "far", [f "viewpoint_z" 1e300];
   "named", [t "name" "a"; c "merge" "Union"];
   "named_ordered", [t "name" "dest_a"; c "merge" "Exclusive or"];
   "base", [t "base" " a "; f "viewpoint_z" (-10.)];
   "base_missing", [t "base" "zzz"];
   "blank_name", [t "name" " "]]
  @ List.map (fun merge -> "merge_" ^ merge, [c "merge" merge; t "name" "a"; f "viewpoint_z" (-3.)])
      ["Replace"; "Union"; "Intersection"; "Subtract"; "Exclusive or"]
(* Polygons of every kind of flatness, each with its own points: a warped quad, a tilted planar
   pentagon, a triangle, coincident and collinear corners, a barely warped quad (below the default
   tolerance), a 1e12-scale warped hexagon, and a polyline. *)
let warped () =
  let open Rdk in
  let polys = [
    [0.,0.,0.; 1.,0.,0.; 1.,1.,0.3; 0.,1.,0.];
    List.map (fun (x, y) -> x, y, 0.5 *. x +. 0.25 *. y) [0.,0.; 2.,0.; 3.,1.; 1.,2.; -1.,1.];
    [0.,0.,0.; 1.,0.,0.; 0.,1.,0.];
    [2.,2.,2.; 2.,2.,2.; 2.,2.,2.; 2.,2.,2.];
    [0.,0.,0.; 1.,1.,1.; 2.,2.,2.; 3.,3.,3.];
    [0.,0.,0.; 1.,0.,0.; 1.,1.,1e-9; 0.,1.,0.];
    List.map (fun (x, y, z) -> x *. 1e12, y *. 1e12, z *. 1e12)
      [0.,0.,0.; 1.,0.,0.; 2.,1.,0.001; 2.,2.,0.; 1.,2.,0.; 0.,1.,0.];
    [0.,0.,0.; 1.,0.,0.; 2.,0.,1.; 3.,0.,1.];
    [0.,0.,0.; 1.,0.,0.; 1.,1.,0.; 0.,1.,0.; 0.5,0.5,0.4];
    [-1.,-1.,0.5; 1.,-1.,-0.5; 1.,1.,0.5; -1.,1.,-0.5] ] in
  let kinds = [|0;0;0;0;0;0;0;1;0;0|] in
  let points = List.concat polys in
  let n = List.length points in
  let x = Array.of_list (List.map (fun (x, _, _) -> x) points) and y = Array.of_list (List.map (fun (_, y, _) -> y) points)
  and z = Array.of_list (List.map (fun (_, _, z) -> z) points) in
  let offsets = Array.of_list (List.rev (List.fold_left (fun acc poly -> (List.hd acc + List.length poly) :: acc) [0] polys)) in
  let topology = Topology.create_owned ~point_count:n ~vertex_points:(Array.init n Fun.id) ~primitive_offsets:offsets
    ~primitive_kinds:(Array.map (fun k -> if k = 0 then Topology.Polygon else Topology.Open_polyline) kinds)
    |> Rdk_test_support.get_string_ok in
  fixture_groups (Geometry.create ~positions:(Packed.Float3.of_owned ~x ~y ~z |> Rdk_test_support.get_string_ok) ~topology ()
    |> Rdk_test_support.get_string_ok)
let bench () = [Rdk_test_support.get_ok (Rdk.Plane_generators.grid ~connectivity:Rdk.Plane_generators.Grid_quads
    ~columns:707 ~rows:707 ~size:8. ())], ["viewpoint_z", P.Float_value (-10.)]
let () = register { key = "group_backface"; native = Sop.Nodes.Group_backface.factory; inputs = standard_inputs @ ["warped", [warped ()]];
  cases; ulps = 4; bench = Some bench }
