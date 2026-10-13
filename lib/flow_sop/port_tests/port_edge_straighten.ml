(* sop/edge_straighten: one geometry input. Fixtures: noisy chains (several components, sizes 2 and 3+),
   an exactly straight chain, coincident points, a grid, and the standard shapes.
   Not covered: a non-finite endpoint on a selected edge (it errors under the default cook too, which
   the cache check cannot accept). *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let text name value = name, P.Text_value value

let with_positions geometry f =
  let view = Packed.Float3.Private.view (Geometry.positions geometry) in
  let n = Array.length view.x in
  let x = Array.init n (fun i -> f 0 i view.x.(i)) and y = Array.init n (fun i -> f 1 i view.y.(i))
  and z = Array.init n (fun i -> f 2 i view.z.(i)) in
  Geometry.with_positions (Packed.Float3.Private.of_owned_exn ~x ~y ~z) geometry |> get_string_ok

let chains ~count ~length =
  let n = count * length in
  let topology = Topology.create_owned ~point_count:n ~vertex_points:(Array.init n Fun.id)
    ~primitive_offsets:(Array.init (count + 1) (fun i -> i * length))
    ~primitive_kinds:(Array.make count Topology.Open_polyline) |> get_string_ok in
  Geometry.create ~positions:(Geometry.positions (points n)) ~topology () |> get_string_ok
let noisy axis i v = match axis with
  | 0 -> float i *. 0.37 +. 0.01 *. float ((i * 7) mod 5)
  | 1 -> float i *. 0.21 +. 0.03 *. float ((i * 3) mod 4) -. v
  | _ -> 0.5 +. 0.02 *. float ((i * 11) mod 7)
let straight axis i _ = match axis with 0 -> float i *. 0.5 | 1 -> float i *. 0.25 | _ -> float i *. -0.125
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:6 ~rows:6 ~size:3. () |> get_ok
let wobble axis i v = v +. 0.05 *. float ((i * (axis + 2)) mod 3)

let inputs = List.map (fun (label, g) -> label, [fixture_groups g]) [
  "empty", points 0; "single", points 1;
  "noisy", with_positions (chains ~count:3 ~length:5) noisy;
  "pairs", with_positions (chains ~count:4 ~length:2) noisy;
  "straight", with_positions (chains ~count:2 ~length:6) straight;
  "coincident", with_positions (chains ~count:2 ~length:4) (fun _ _ _ -> 1.25);
  "mixed", with_positions (polygon_polyline ()) wobble;
  "grid", with_positions (small_grid ()) wobble;
  "grid-flat", small_grid ();
  "grid4225", grid ()]

let cases = [
  "defaults", [];
  "group a", [text "group" "a"];
  "group dest", [text "group" "dest_a"];
  "group padded", [text "group" " old_x "];
  "output group", [text "output_group" "straightened"];
  "group + output", [text "group" "a"; text "output_group" " out "];
  "output over input", [text "group" "a"; text "output_group" "a"];
  "blank output", [text "output_group" "   "];
  "missing group", [text "group" "missing"];
  "literal group", [text "group" "literal *?[]^\\"];
  "unicode", [text "group" "\195\169\231\140\171"; text "output_group" "\195\169"] ]
let bench () = [with_positions (chains ~count:100_000 ~length:10) noisy], []
let () = register { key = "edge_straighten"; native = Sop.Nodes.Edge_straighten.factory; inputs; cases; ulps = 4;
  bench = Some bench }
