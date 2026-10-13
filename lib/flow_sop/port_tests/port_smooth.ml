(* sop/smooth: one geometry input (pending draft nodes/smooth.pending). *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value
let num name value = name, P.Int_value value
let flt name value = name, P.Float_value value
let bool name value = name, P.Bool_value value

let add_point_attribute name storage geometry =
  Geometry.with_attribute (Attribute.create_owned ~owner:Attribute.Point ~name storage |> get_string_ok) geometry
  |> get_string_ok

let smooth_grid () =
  let geometry = fixture_attributes (fixture_groups (grid ())) in
  let n = Geometry.point_count geometry in
  let nx = Array.init n (fun i -> float (i mod 5) *. 0.25) and ny = Array.init n (fun i -> float (i mod 3))
  and nz = Array.init n (fun i -> 1. +. float (i mod 7)) in
  geometry
  |> add_point_attribute "alpha" (Attribute.Float (Array.init n (fun i -> float (i mod 5) /. 4.)))
  |> add_point_attribute "weight" (Attribute.Float (Array.init n (fun i -> float (i mod 7) /. 6.)))
  |> add_point_attribute "N" (Attribute.Float3 (Packed.Float3.of_owned ~x:nx ~y:ny ~z:nz |> get_string_ok))

(* Geometry with only vertex normals, to reach the recompute branch. *)
let vertex_normals () =
  let geometry = fixture_groups (grid ()) in
  let n = Geometry.vertex_count geometry in
  let storage = Attribute.Float3 (Packed.Float3.of_owned ~x:(Array.make n 0.) ~y:(Array.make n 1.) ~z:(Array.make n 0.)
    |> get_string_ok) in
  Geometry.with_attribute (Attribute.create_owned ~owner:Attribute.Vertex ~name:"N" storage |> get_string_ok) geometry
  |> get_string_ok

let inputs = standard_inputs @ ["smooth-grid", [smooth_grid ()]; "vertex-normals", [vertex_normals ()]]

let cases =
  [ "iterations 1", [num "iterations" 1]; "iterations 3 step", [num "iterations" 3; flt "step" 0.25];
    "pattern all", [text "attributes" "*"; num "iterations" 2];
    "pattern N", [text "attributes" "N float"; num "iterations" 2; bool "recompute_normals" true];
    "pattern none", [text "attributes" "nothing"];
    "primitive group", [text "group" "a"; num "iterations" 2];
    "primitive group missing", [text "group" "missing"];
    "constrained", [text "constrained_points" "a"; num "iterations" 2];
    "constrained missing", [text "constrained_points" "missing"];
    "both", [text "group" "dest_a"; text "constrained_points" "old_x"; num "iterations" 2];
    "pin unshared", [choice "boundary" "Pin unshared"; num "iterations" 3];
    "pin group boundary", [choice "boundary" "Pin group boundary"; num "iterations" 3];
    "pin group boundary + group", [choice "boundary" "Pin group boundary"; text "group" "a"; num "iterations" 3];
    "pin unshared + group", [choice "boundary" "Pin unshared"; text "group" "dest_a"; num "iterations" 3];
    "edge length", [choice "method_" "Edge length"; num "iterations" 3; text "attributes" "*"];
    "custom steps", [choice "mode" "Custom steps"; num "iterations" 4; text "attributes" "*"];
    "custom odd even", [choice "mode" "Custom steps"; flt "odd_step" 0.8; flt "even_step" (-0.3); num "iterations" 3];
    "weight", [text "weight_attribute" "weight"; num "iterations" 2];
    "alpha", [text "alpha_attribute" "alpha"; num "iterations" 2];
    "weight missing", [text "weight_attribute" "nothing"];
    "blend", [flt "original_blend" 0.5; flt "smoothed_blend" 0.5; num "iterations" 2; text "attributes" "*"];
    "recompute", [bool "recompute_normals" true; num "iterations" 2];
    "recompute pin", [bool "recompute_normals" true; choice "boundary" "Pin unshared"; num "iterations" 2];
    "recompute group", [bool "recompute_normals" true; text "group" "a"; num "iterations" 2] ]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:1000 ~rows:1000 ~size:8. () |> get_ok in
  [g], [num "iterations" 3]
let () = register { key = "smooth"; native = Sop.Nodes.Smooth.factory; inputs; cases; ulps = 4;
  bench = Some bench }
