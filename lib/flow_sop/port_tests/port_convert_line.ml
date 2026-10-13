(* sop/convert_line: one geometry input. Fixtures: polygon/polyline shapes, grids, near-touching chains for
   connect path, closed loops. A non-finite selected position errors under the default cook only with a
   length attribute, so it is not a fixture. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param

let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:3 ~rows:3 ~size:2. () |> get_ok
let decorate g = fixture_attributes (fixture_groups g)
let curves ~points:count ~vertex_points ~offsets ~kinds =
  let topology = Topology.create_owned ~point_count:count ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> get_string_ok in
  Geometry.create ~positions:(Geometry.positions (Port_gate.points count)) ~topology () |> get_string_ok
let open_k = Topology.Open_polyline and closed_k = Topology.Closed_polyline and poly_k = Topology.Polygon
(* Chains whose ends sit 0.125 apart in x, so a 0.2 distance connects them. *)
let chains () = curves ~points:10 ~vertex_points:[|0;1;2; 3;4; 5;6;7;8;9|]
  ~offsets:[|0;3;5;10|] ~kinds:[|open_k; open_k; open_k|]
let loops () = curves ~points:9 ~vertex_points:[|0;1;2;0; 3;4;5; 6;7|] ~offsets:[|0;4;7;9|]
  ~kinds:[|open_k; closed_k; open_k|]
let degenerate () = curves ~points:4 ~vertex_points:[|0;0;1;2;2;3|] ~offsets:[|0;3;6|] ~kinds:[|open_k; open_k|]
let fan () = curves ~points:7 ~vertex_points:[|0;1;2; 1;0;3; 0;1;4; 2;3;5;6|]
  ~offsets:[|0;3;6;9;13|] ~kinds:[|poly_k; poly_k; poly_k; closed_k|]

let inputs = List.map (fun (label, g) -> label, [decorate g]) [
  "empty", points 0; "single", points 1;
  "mixed", polygon_polyline ();
  "chains", chains (); "loops", loops (); "degenerate", degenerate (); "fan", fan ();
  "grid", small_grid (); "grid4225", grid () ]

let fields ?(group = "") ?(connect = false) ?(distance = 0.001) ?(only = false) ?(close = false)
    ?(remove = false) ?(length = "") () =
  ["group", P.Text_value group; "connect_path", P.Bool_value connect; "maximum_distance", P.Float_value distance;
   "connect_only_to_other_end_points", P.Bool_value only; "make_isolated_loops_closed", P.Bool_value close;
   "remove_unused_points", P.Bool_value remove; "length_attribute", P.Text_value length]
let cases =
  List.concat_map (fun (glabel, group) -> [
      "plain/" ^ glabel, fields ~group ();
      "length/" ^ glabel, fields ~group ~length:"len" ();
      "remove/" ^ glabel, fields ~group ~remove:true ();
      "connect/" ^ glabel, fields ~group ~connect:true ();
      "connect near/" ^ glabel, fields ~group ~connect:true ~distance:0.2 ();
      "connect only/" ^ glabel, fields ~group ~connect:true ~distance:0.2 ~only:true ();
      "connect close/" ^ glabel, fields ~group ~connect:true ~close:true ~remove:true ();
      "connect length/" ^ glabel, fields ~group ~connect:true ~distance:0.2 ~close:true ~length:" len " () ])
    ["all", ""; "a", "a"; "dest", "dest_a"; "old", " old_x "]
  @ [ "missing", fields ~group:"missing" (); "literal", fields ~group:"literal *?[]^\\" ~connect:true ();
      "unicode", fields ~group:"\195\169\231\140\171" ~length:"\195\169" () ]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:300 ~rows:300 ~size:8. () |> get_ok in
  [g], fields ~length:"len" ()
let () = register { key = "convert_line"; native = Sop.Nodes.Convert_line.factory; inputs; cases; ulps = 4;
  bench = Some bench }
