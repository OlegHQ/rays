(* sop/poly_path: one geometry input. Fixtures: chains whose ends sit 0.125 apart (the test points are
   spaced 0.125 in x), isolated loops, branches, shared and self edges, with every payload owner. *)
open Rdk
open Port_gate
module P = Param
let curves ~points:count ~vertex_points ~offsets ~kinds =
  let topology = Topology.create_owned ~point_count:count ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> Rdk_test_support.get_string_ok in
  Geometry.create ~positions:(Geometry.positions (Port_gate.points count)) ~topology ()
    |> Rdk_test_support.get_string_ok
let decorate g = fixture_attributes (fixture_groups g)
let open_k = Topology.Open_polyline and closed_k = Topology.Closed_polyline and poly_k = Topology.Polygon
let inputs = List.map (fun (label, g) -> label, [decorate g]) [
  "empty", points 0; "single", points 1;
  "mixed", polygon_polyline ();
  "chains", curves ~points:10 ~vertex_points:[|0;1;2; 3;4; 5;6;7;8;9|] ~offsets:[|0;3;5;10|]
    ~kinds:[|open_k; open_k; open_k|];
  "loops", curves ~points:9 ~vertex_points:[|0;1;2;0; 3;4;5; 6;7|] ~offsets:[|0;4;7;9|]
    ~kinds:[|open_k; closed_k; open_k|];
  "degenerate", curves ~points:4 ~vertex_points:[|0;0;1;2;2;3|] ~offsets:[|0;3;6|] ~kinds:[|open_k; open_k|];
  "fan", curves ~points:7 ~vertex_points:[|0;1;2; 1;0;3; 0;1;4; 2;3;5;6|] ~offsets:[|0;3;6;9;13|]
    ~kinds:[|poly_k; poly_k; poly_k; closed_k|];
  "grid", Plane_generators.grid ~connectivity:Grid_quads ~columns:3 ~rows:3 ~size:2. () |> Rdk_test_support.get_ok;
  "grid400", Plane_generators.grid ~connectivity:Grid_quads ~columns:19 ~rows:19 ~size:4. () |> Rdk_test_support.get_ok ]
let fields ?(connect = false) ?(distance = 0.001) ?(only = false) ?(close = false) () =
  ["connect_end_points", P.Bool_value connect; "maximum_distance", P.Float_value distance;
   "connect_only_to_other_end_points", P.Bool_value only; "make_isolated_loops_closed", P.Bool_value close]
let cases = [
  "close", fields ~close:true ();
  "connect", fields ~connect:true ();
  "connect near", fields ~connect:true ~distance:0.2 ();
  "connect only", fields ~connect:true ~distance:0.2 ~only:true ();
  "connect wide", fields ~connect:true ~distance:1.0 ();
  "connect wide only", fields ~connect:true ~distance:1.0 ~only:true ();
  "connect exact", fields ~connect:true ~distance:0. ();
  "connect close", fields ~connect:true ~distance:0.2 ~close:true ();
  "only ignored", fields ~only:true ~distance:0.2 () ]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:300 ~rows:300 ~size:8. () |> Rdk_test_support.get_ok in
  [g], fields ()
let () = register { key = "poly_path"; native = Sop.Nodes.Poly_path.factory; inputs; cases; ulps = 4;
  bench = Some bench }
