(* sop/edge_relax: source plus same-topology reference (pending draft nodes/edge_relax.pending). *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value
let num name value = name, P.Int_value value
let flt name value = name, P.Float_value value
let bool name value = name, P.Bool_value value

let with_positions geometry f =
  let view = Packed.Float3.Private.view (Geometry.positions geometry) in
  let n = Array.length view.x in
  let x = Array.init n (fun i -> f 0 i view.x.(i)) and y = Array.init n (fun i -> f 1 i view.y.(i))
  and z = Array.init n (fun i -> f 2 i view.z.(i)) in
  Geometry.with_positions (Packed.Float3.Private.of_owned_exn ~x ~y ~z) geometry |> get_string_ok

let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:8 ~rows:8 ~size:4. () |> get_ok
let wiggle axis i v = v +. 0.07 *. float ((i * (axis + 3)) mod 5)
let stretch _ _ v = v *. 1.3

(* Disjoint two-point polylines: every point has one edge (closed-form path). *)
let pairs ~n =
  let topology = Topology.create_owned ~point_count:(2 * n)
    ~vertex_points:(Array.init (2 * n) Fun.id) ~primitive_offsets:(Array.init (n + 1) (fun i -> 2 * i))
    ~primitive_kinds:(Array.make n Topology.Open_polyline) |> get_string_ok in
  Geometry.create ~positions:(Geometry.positions (points (2 * n))) ~topology () |> get_string_ok

let pair source_f reference_f g = let g = fixture_groups g in [with_positions g source_f; with_positions g reference_f]

let inputs =
  [ "empty", [fixture_groups (points 0); fixture_groups (points 0)];
    "single", [fixture_groups (points 1); fixture_groups (points 1)];
    "grid", pair wiggle (fun _ _ v -> v) (small_grid ());
    "grid-stretched", pair (fun _ _ v -> v) stretch (small_grid ());
    "pairs", pair (fun a i v -> if a = 0 then v +. 0.3 *. float (i mod 3) else v) (fun _ _ v -> v *. 0.5) (pairs ~n:9);
    "pairs-same", pair (fun _ _ v -> v) (fun _ _ v -> v) (pairs ~n:5);
    "mixed", pair wiggle stretch (polygon_polyline ()) ]

let cases =
  [ "iterations 1", [num "iterations" 1]; "iterations 5 small step", [num "iterations" 5; flt "step_size" 0.1];
    "step 1", [flt "step_size" 1.]; "step 0.3", [flt "step_size" 0.3; num "iterations" 7];
    "step 0.5", [flt "step_size" 0.5; num "iterations" 4];
    "step 0.75", [flt "step_size" 0.75; num "iterations" 4];
    "tolerance loose", [flt "tolerance" 0.5]; "tolerance tight", [flt "tolerance" 1e-12; num "iterations" 100];
    "distribution", [choice "target_mode" "Scale-independent distribution"];
    "distribution step", [choice "target_mode" "Scale-independent distribution"; flt "step_size" 0.25; num "iterations" 10];
    "only shorten", [bool "only_shorten" true]; "only shorten distribution",
      [bool "only_shorten" true; choice "target_mode" "Scale-independent distribution"];
    "point group", [choice "group_owner" "Point"; text "group" "a"];
    "point group 2", [choice "group_owner" "Point"; text "group" "dest_a"; flt "step_size" 0.4];
    "primitive group", [choice "group_owner" "Primitive"; text "group" "a"];
    "primitive group 2", [choice "group_owner" "Primitive"; text "group" "old_x"; num "iterations" 6];
    "missing point group", [choice "group_owner" "Point"; text "group" "missing"];
    "missing primitive group", [choice "group_owner" "Primitive"; text "group" "missing"];
    "pin", [text "pin_group" "a"]; "pin missing", [text "pin_group" "missing"];
    "pin + group", [choice "group_owner" "Point"; text "group" "dest_a"; text "pin_group" "a"];
    "pin + primitives", [choice "group_owner" "Primitive"; text "group" "dest_a"; text "pin_group" "old_x"];
    "pin only shorten", [text "pin_group" "old_x"; bool "only_shorten" true];
    "everything", [choice "group_owner" "Point"; text "group" "old_x"; text "pin_group" "a"; bool "only_shorten" true;
      choice "target_mode" "Scale-independent distribution"; flt "step_size" 0.2; num "iterations" 9] ]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:1000 ~rows:1000 ~size:8. () |> get_ok in
  [with_positions g wiggle; g], [num "iterations" 4]
let () = register { key = "edge_relax"; native = Sop.Nodes.Edge_relax.factory; inputs; cases; ulps = 4;
  bench = Some bench }
