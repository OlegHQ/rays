(* sop/edge_equalize: one geometry input (pending draft nodes/edge_equalize.pending). *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value
let num name value = name, P.Int_value value
let flt name value = name, P.Float_value value

let with_positions geometry f =
  let view = Packed.Float3.Private.view (Geometry.positions geometry) in
  let n = Array.length view.x in
  let x = Array.init n (fun i -> f 0 i view.x.(i)) and y = Array.init n (fun i -> f 1 i view.y.(i))
  and z = Array.init n (fun i -> f 2 i view.z.(i)) in
  Geometry.with_positions (Packed.Float3.Private.of_owned_exn ~x ~y ~z) geometry |> get_string_ok

let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:8 ~rows:8 ~size:4. () |> get_ok
let wiggle axis i v = v +. 0.07 *. float ((i * (axis + 3)) mod 5)
let mild axis i v = v +. 0.000002 *. float ((i * (axis + 3)) mod 5)

let pairs ~n =
  let topology = Topology.create_owned ~point_count:(2 * n)
    ~vertex_points:(Array.init (2 * n) Fun.id) ~primitive_offsets:(Array.init (n + 1) (fun i -> 2 * i))
    ~primitive_kinds:(Array.make n Topology.Open_polyline) |> get_string_ok in
  Geometry.create ~positions:(Geometry.positions (points (2 * n))) ~topology () |> get_string_ok

let pair_fixture g = fixture_groups (with_positions g (fun a i v -> if a = 0 then v +. 0.3 *. float (i mod 3) else v))

(* A zero-length edge: two coincident points. *)
let coincident () =
  let g = fixture_groups (pairs ~n:4) in
  with_positions g (fun _ i v -> if i = 1 then 0. else v)

let inputs =
  [ "empty", [fixture_groups (points 0)]; "single", [fixture_groups (points 1)];
    "pairs", [pair_fixture (pairs ~n:9)]; "pairs-regular", [fixture_groups (pairs ~n:5)];
    "coincident", [coincident ()];
    "mixed", [fixture_groups (with_positions (polygon_polyline ()) wiggle)];
    "grid", [fixture_groups (with_positions (small_grid ()) mild)];
    "grid-regular", [fixture_groups (small_grid ())] ]

let cases =
  List.concat_map (fun m -> [
    m ^ "/defaults", [choice "method_" m];
    m ^ "/group a", [choice "method_" m; text "group" "a"];
    m ^ "/group dest", [choice "method_" m; text "group" "dest_a"; num "iterations" 100];
    m ^ "/output group", [choice "method_" m; text "output_group" "equalized"];
    m ^ "/group + output", [choice "method_" m; text "group" "old_x"; text "output_group" " out "];
    m ^ "/iterations 1", [choice "method_" m; num "iterations" 1];
    m ^ "/loose", [choice "method_" m; flt "tolerance" 0.5];
    m ^ "/tight", [choice "method_" m; flt "tolerance" 1e-12; num "iterations" 256] ]) ["Average"; "Longest"; "Shortest"]
  @ [ "missing group", [text "group" "missing"]; "literal group", [text "group" "literal *?[]^\\"];
      "unicode group", [text "group" "\195\169\231\140\171"; text "output_group" "\195\169"];
      "output over input", [text "group" "a"; text "output_group" "a"];
      "blank output", [text "output_group" "   "] ]
let bench () =
  (* Native does not converge on a 1M grid in few iterations: bench the closed-form (degree 1) path. *)
  [with_positions (pairs ~n:500_000) (fun a i v -> if a = 0 then v +. 0.3 *. float (i mod 3) else v)], []
let () = register { key = "edge_equalize"; native = Sop.Nodes.Edge_equalize.factory; inputs; cases; ulps = 4;
  bench = Some bench }
