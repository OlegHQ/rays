(* sop/attribute_blur: one geometry input (pending draft nodes/attribute_blur.pending). *)
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

(* Grid with every storage type, control attributes and point and vertex normals. *)
let blur_grid () =
  let geometry = fixture_attributes (fixture_groups (grid ())) in
  let n = Geometry.point_count geometry in
  let nx = Array.init n (fun i -> float (i mod 5) *. 0.25) and ny = Array.init n (fun i -> float (i mod 3))
  and nz = Array.init n (fun i -> 1. +. float (i mod 7)) in
  geometry
  |> add_point_attribute "alpha" (Attribute.Float (Array.init n (fun i -> float (i mod 5) /. 4.)))
  |> add_point_attribute "weight" (Attribute.Float (Array.init n (fun i -> float (i mod 7) /. 6.)))
  |> add_point_attribute "N" (Attribute.Float3 (Packed.Float3.of_owned ~x:nx ~y:ny ~z:nz |> get_string_ok))

(* Coincident points (zero-length edges), a border of triangles and a duplicate edge. *)
let degenerate () =
  let topology = Topology.create_owned ~point_count:7
    ~vertex_points:[|0;1;2; 1;2;3; 3;4;5; 5;6;6|] ~primitive_offsets:[|0;3;6;9;12|]
    ~primitive_kinds:[|Topology.Polygon; Polygon; Polygon; Open_polyline|] |> get_string_ok in
  let x = [|0.;0.;1.;1.;2.;2.;3.|] and y = [|0.;0.;0.;1.;1.;0.;0.5|] and z = Array.make 7 0.25 in
  let positions = Packed.Float3.Private.of_owned_exn ~x ~y ~z in
  let g = Geometry.create ~positions ~topology () |> get_string_ok in
  fixture_attributes (fixture_groups g)
  |> add_point_attribute "alpha" (Attribute.Float [|0.;1.;0.5;0.;1.;0.25;1.|])

let inputs = standard_inputs @ ["blur-grid", [blur_grid ()]; "degenerate", [degenerate ()]]

let steps = [flt "laplacian_step" 0.25; num "iterations" 3]
let cases = [
  "iterations 0", [num "iterations" 0]; "iterations 2", [num "iterations" 2];
  "iterations 5 step", [num "iterations" 5; flt "laplacian_step" (-0.4)];
  "pattern all", [text "attributes" "*"; num "iterations" 2];
  "pattern vec", [text "attributes" "float vec2 vec3 vec4 integer"; num "iterations" 2];
  "pattern P float", [text "attributes" "P float"; num "iterations" 2];
  "pattern N", [text "attributes" "N"; num "iterations" 2];
  "pattern none", [text "attributes" "nothing"];
  "pattern blank", [text "attributes" "   "];
  "group a", [text "group" "a"; num "iterations" 2];
  "group literal", [text "group" "literal *?[]^\\"];
  "group missing", [text "group" "missing"];
  "edge length", [choice "method_" "Edge length"; num "iterations" 2; text "attributes" "*"];
  "edge length steps", [choice "method_" "Edge length"] @ steps;
  "custom steps", [choice "mode" "Custom steps"; num "iterations" 4; text "attributes" "*"];
  "custom odd even", [choice "mode" "Custom steps"; flt "odd_step" 0.8; flt "even_step" (-0.3); num "iterations" 3];
  "weight", [text "weight_attribute" "weight"; num "iterations" 2; text "attributes" "*"];
  "alpha", [text "alpha_attribute" "alpha"; num "iterations" 2; text "attributes" "*"];
  "alpha edge", [text "alpha_attribute" "alpha"; choice "method_" "Edge length"; num "iterations" 2];
  "weight alpha group", [text "weight_attribute" " weight "; text "alpha_attribute" "alpha"; text "group" "a"; num "iterations" 2];
  "weight missing", [text "weight_attribute" "nothing"];
  "alpha wrong type", [text "alpha_attribute" "vec3"];
  "weight wrong type", [text "weight_attribute" "integer"];
  "pin borders", [bool "pin_borders" true; num "iterations" 3; text "attributes" "*"];
  "pin borders edge", [bool "pin_borders" true; choice "method_" "Edge length"; num "iterations" 3];
  "blend half", [flt "original_blend" 0.5; flt "blurred_blend" 0.5; num "iterations" 2; text "attributes" "*"];
  "blend overshoot", [flt "original_blend" 0.25; flt "blurred_blend" 1.25];
  "blend zero", [flt "original_blend" 0.; flt "blurred_blend" 0.]]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:1000 ~rows:1000 ~size:8. () |> get_ok in
  [g], [num "iterations" 3]
let () = register { key = "attribute_blur"; native = Sop.Nodes.Attribute_blur.factory; inputs; cases; ulps = 4;
  bench = Some bench }
