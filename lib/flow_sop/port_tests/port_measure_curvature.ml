(* sop/measure_curvature: one geometry input (pending draft nodes/measure_curvature.pending).
   Fixtures are manifold polygon surfaces (the default cook needs a valid surface): an open quad grid, a bumpy
   one (non-zero curvature, boundary points), a closed tetrahedron (no boundary), a convex hexagon and a
   mixed quad/triangle patch. Topology refusals (curves, non-manifold) cannot be fixtures because every
   case must be able to succeed on each fixture; the attribute cases cover the wrong-storage refusals. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let fl name x = name, P.Float_value x
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let ch name value = name, P.Choice_value value

let hash i salt = float ((i * 7919 + salt * 104729 + 13) mod 1000) /. 500. -. 1.
let add owner name storage g = Geometry.with_attribute
  (Attribute.create_owned ~owner ~name storage |> get_string_ok) g |> get_string_ok
let decorated g =
  let n = Geometry.point_count g in
  let plane salt = Array.init n (fun i -> hash i salt) in
  let base = fixture_groups g in
  base
  |> add Attribute.Point "float" (Attribute.Float (plane 5))
  |> add Attribute.Point "integer" (Attribute.Int (Array.init n (fun i -> (i * 37) mod 11 - 5)))
  |> add Attribute.Point "vec2" (Attribute.Float2 (Packed.Float2.of_owned ~x:(plane 6) ~y:(plane 7) |> get_string_ok))
  |> add Attribute.Point "vec3" (Attribute.Float3 (Packed.Float3.of_owned ~x:(plane 8) ~y:(plane 9) ~z:(plane 10) |> get_string_ok))
  |> add Attribute.Point "vec4" (Attribute.Float4 (Packed.Float4.of_owned ~x:(plane 11) ~y:(plane 12) ~z:(plane 13)
       ~w:(plane 14) |> get_string_ok))
  |> add Attribute.Point "label" (Attribute.Text (Array.make n "t"))
  |> add Attribute.Primitive "prim_float" (Attribute.Float (Array.make (Geometry.primitive_count g) 1.))
let grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:6 ~rows:5 ~size:8. () |> get_ok
let bumpy () =
  let g = grid () in
  let n = Geometry.point_count g in
  let view = Packed.Float3.Private.view (Geometry.positions g) in
  Geometry.with_positions (Packed.Float3.of_owned ~x:(Array.copy view.x) ~y:(Array.copy view.y)
    ~z:(Array.init n (fun i -> 0.4 *. hash i 3)) |> get_string_ok) g |> get_string_ok
let polygons ~x ~y ~z vertex_points offsets =
  let topology = Topology.create_owned ~point_count:(Array.length x) ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:(Array.make (Array.length offsets - 1) Topology.Polygon) |> get_string_ok in
  Geometry.create ~positions:(Packed.Float3.of_owned ~x ~y ~z |> get_string_ok) ~topology () |> get_string_ok
let tetra () = polygons ~x:[|0.;1.;0.5;0.5|] ~y:[|0.;0.;1.;0.4|] ~z:[|0.;0.;0.;1.|]
  [|0;2;1; 0;1;3; 1;2;3; 2;0;3|] [|0;3;6;9;12|]
let hexagon () = polygons ~x:[|1.;0.5;-0.5;-1.;-0.5;0.5|] ~y:[|0.;0.87;0.87;0.;-0.87;-0.87|] ~z:[|0.1;0.;0.;0.2;0.;0.|]
  [|0;1;2;3;4;5|] [|0;6|]
let mixed_faces () = polygons ~x:[|0.;1.;2.;0.;1.;2.;1.|] ~y:[|0.;0.;0.;1.;1.;1.;2.|] ~z:[|0.;0.2;0.;0.3;0.;0.1;0.|]
  [|0;1;4;3; 1;2;5;4; 3;4;6; 4;5;6|] [|0;4;8;11;14|]
let inputs = List.map (fun (label, g) -> label, [decorated g]) [
  "grid", grid (); "bumpy", bumpy (); "tetra", tetra (); "hexagon", hexagon (); "quads and triangles", mixed_faces () ]

let it name v = name, P.Int_value v
let outs = [ "mean", "curvature"; "gaussian", "gauss"; "minimum", "kmin"; "maximum", "kmax";
             "curvedness", "curvy"; "shape_index", "shape" ]
let all_outputs = List.map (fun (f, n) -> tx f n) outs
let cases =
  [ "mean only", []; "boundary one-sided", [ch "boundary" "One-sided"];
    "all outputs", all_outputs;
    "all outputs one-sided", ch "boundary" "One-sided" :: all_outputs ]
  @ List.map (fun (f, n) -> "only " ^ f, (if f = "mean" then [] else [tx "mean" ""; tx f n])) outs
  @ List.map (fun (f, n) -> "only " ^ f ^ " one-sided", (ch "boundary" "One-sided" :: (if f = "mean" then [] else [tx "mean" ""; tx f n]))) outs
  @ [ "smoothing 1", [it "smoothing_iterations" 1; tx "gaussian" "gauss"];
      "smoothing 3 strength 1", [it "smoothing_iterations" 3; fl "smoothing_strength" 1.; tx "gaussian" "gauss"];
      "smoothing 5 strength 0.25 one-sided", all_outputs @ [it "smoothing_iterations" 5; fl "smoothing_strength" 0.25;
        ch "boundary" "One-sided"];
      "smoothing strength 0", [it "smoothing_iterations" 4; fl "smoothing_strength" 0.; tx "gaussian" "gauss"];
      "smoothing 2 all", all_outputs @ [it "smoothing_iterations" 2];
      "group", [tx "point_group" "a"; tx "gaussian" "gauss"];
      "group padded all", all_outputs @ [tx "point_group" " a "];
      "group missing", [tx "point_group" "nope"];
      "group smoothing", all_outputs @ [tx "point_group" "a"; it "smoothing_iterations" 2];
      "output existing float", [tx "mean" "float"];
      "output existing float group", [tx "mean" "float"; tx "point_group" "a"; tx "gaussian" "gauss"];
      "output existing wrong type", [tx "mean" "vec3"];
      "output existing integer", [tx "gaussian" "integer"];
      "output existing text", [tx "mean" "label"];
      "output padded", [tx "mean" " cur "];
      "output blank mean only gaussian", [tx "mean" "  "; tx "gaussian" "g"];
      "all outputs blank", [tx "mean" ""];
      "output P", [tx "mean" "P"];
      "output padded P", [tx "gaussian" " P "];
      "duplicate names", [tx "gaussian" "curvature"];
      "duplicate padded names", [tx "gaussian" "k"; tx "minimum" " k "];
      "padded group all", all_outputs @ [tx "point_group" "a"] ]

let bench () = [Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> get_ok],
  [tx "gaussian" "gauss"]
let node = { key = "measure_curvature"; native = Sop.Nodes.Measure_curvature.factory; inputs; cases;
  ulps = 4; bench = Some bench }
let () = register node
