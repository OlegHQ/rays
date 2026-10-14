(* sop/measure: one geometry input (pending draft). Fixtures: empty, a single point, a flat 8x8 quad
   grid, a closed tetrahedron (signed volume), curves next to a polygon (area refuses a selected
   curve) and, last, a concave L hexagon + triangles with attributes of every owner/type and groups. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let t name v = name, P.Text_value v
let c name v = name, P.Choice_value v
let tb_geometry point_count positions build =
  let tb = Rdk_test_support.Tb.create ~point_count () in
  build tb;
  let x = Array.map (fun (x, _, _) -> x) positions and y = Array.map (fun (_, y, _) -> y) positions
  and z = Array.map (fun (_, _, z) -> z) positions in
  Rdk.Geometry.create ~positions:(Rdk.Packed.Float3.of_owned ~x ~y ~z |> get_string_ok)
    ~topology:(Rdk_test_support.Tb.freeze tb) () |> get_string_ok
let tetra () = tb_geometry 4 [|0.,0.,0.; 1.25,0.,0.; 0.,1.5,0.1; 0.3,0.2,1.7|] (fun tb ->
  let open Rdk_test_support.Tb in
  add_triangle tb 0 2 1; add_triangle tb 0 1 3; add_triangle tb 1 2 3; add_triangle tb 2 0 3)
let curves () = tb_geometry 6 [|0.,0.,0.; 1.,0.,0.; 1.,1.,0.; 0.,1.,0.3; 2.,2.,2.; 3.,1.,0.|] (fun tb ->
  let open Rdk_test_support.Tb in
  add_polygon tb [|0;1;2;3|]; add_open_polyline tb [|0;4;5|]; add_closed_polyline tb [|1;5;4|])
let shapes () = tb_geometry 9
  [|0.,0.,0.; 2.,0.,0.1; 2.,1.,0.; 1.,1.,0.2; 1.,2.,0.; 0.,2.,0.; 0.,0.,1.; 1.,0.,1.3; 0.5,0.7,1.1|]
  (fun tb -> let open Rdk_test_support.Tb in
    add_polygon tb [|0;1;2;3;4;5|]; add_triangle tb 6 7 8; add_triangle tb 8 7 6; add_polygon tb [|6;7;8;0|])
let cases =
  ["perimeter", [c "kind" "Perimeter"];
   "volume", [c "kind" "Signed volume"];
   "throughout", [c "accumulation" "Throughout"];
   "perimeter throughout", [c "kind" "Perimeter"; c "accumulation" "Throughout"];
   "group", [t "group" " a "];
   "group throughout", [t "group" "a"; c "accumulation" "Throughout"];
   "group existing float", [t "group" "a"; t "attribute" "float"];
   "group existing float throughout", [t "group" "dest_a"; t "attribute" "float"; c "accumulation" "Throughout"];
   "existing non-float", [t "attribute" "vec3"];
   "named", [t "attribute" " size "; t "total_attribute" "sum"];
   "total", [t "total_attribute" "total"; c "kind" "Signed volume"];
   "group missing", [t "group" "zzz"];
   "group unicode", [t "group" "\195\169\231\140\171"; c "kind" "Perimeter"]]
let inputs = List.map (fun (label, g) -> label, [g]) [
  "empty", fixture_groups (points 0); "single", fixture_groups (points 1);
  "grid", fixture_groups (Plane_generators.grid ~connectivity:Grid_quads ~columns:8 ~rows:8 ~size:3. () |> get_ok);
  "tetra", fixture_groups (tetra ()); "curves", fixture_groups (curves ());
  "shapes", fixture_attributes (fixture_groups (shapes ()))]
let () = register { key = "measure"; native = Sop.Nodes.Measure.factory; inputs; cases; ulps = 4;
  bench = Some (fun () -> [Plane_generators.grid ~connectivity:Grid_quads ~columns:1000 ~rows:1000 ~size:8. () |> get_ok], []) }
