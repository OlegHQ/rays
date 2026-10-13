(* sop/ends: one geometry input (pending draft nodes/ends.pending). *)
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
  "open", curves ~points:9 ~vertex_points:[|0;1;2;3;4;5;6;7;8|] ~offsets:[|0;4;9|] ~kinds:[|open_k; open_k|];
  "closed", curves ~points:9 ~vertex_points:[|0;1;2;3;4;5;6;7;8|] ~offsets:[|0;3;9|] ~kinds:[|closed_k; closed_k|];
  "mixed", curves ~points:13 ~vertex_points:[|0;1;2;3;4;5;6;7;8;9;10;11;12|]
    ~offsets:[|0;4;7;10;13|] ~kinds:[|open_k; closed_k; poly_k; open_k|];
  "shared", curves ~points:6 ~vertex_points:[|0;1;2;3;1;4;5;2|] ~offsets:[|0;4;8|] ~kinds:[|closed_k; open_k|];
  "repeated", curves ~points:5 ~vertex_points:[|0;1;2;3;0;4;3;1|] ~offsets:[|0;5;8|] ~kinds:[|open_k; open_k|];
  "short", curves ~points:5 ~vertex_points:[|0;1;2;3;4|] ~offsets:[|0;2;5|] ~kinds:[|open_k; open_k|];
  "empty", curves ~points:0 ~vertex_points:[||] ~offsets:[|0|] ~kinds:[||]]
let modes = ["Open"; "Close straight"; "Unroll shared point"; "Unroll new point"]
let fields group mode = ["group", P.Text_value group; "mode", P.Choice_value mode]
let cases = List.concat_map (fun mode -> List.map (fun (label, group) ->
    Printf.sprintf "%s/%s" mode label, fields group mode)
    ["all", ""; "group", "a"; "padded", " dest_a "; "missing", "nothing"; "unicode", "\195\169\231\140\171"])
  modes
let bench () =
  let n = 333_333 in
  let g = curves ~points:(n * 3) ~vertex_points:(Array.init (n * 3) Fun.id)
    ~offsets:(Array.init (n + 1) (fun i -> i * 3)) ~kinds:(Array.make n closed_k) in
  [g], fields "" "Unroll new point"
let () = register { key = "ends"; native = Sop.Nodes.Ends.factory; inputs; cases; ulps = 4; bench = Some bench }
