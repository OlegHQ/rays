(* sop/attribute_laplacian: one geometry input (pending draft nodes/attribute_laplacian.pending).
   Every fixture is a manifold polygon surface because the default cook (cotangent of P) must succeed:
   a quad grid, a bumpy quad grid, a closed tetrahedron, a convex hexagon and a convex pentagon with a
   triangle. Topology refusals (curves, non-manifold edges, winding) cannot be a fixture for that reason
   and are not part of this gate. Each carries float / integer / vec2 / vec3 / vec4 point attributes. *)
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

let cases =
  List.concat_map (fun w -> [
    w, [ch "weighting" w];
    w ^ " raw", [ch "weighting" w; bo "normalize" false];
    w ^ " float", [ch "weighting" w; tx "source" "float"];
    w ^ " integer", [ch "weighting" w; tx "source" "integer"; tx "output" "int_lap"];
    w ^ " vec2", [ch "weighting" w; tx "source" "vec2"];
    w ^ " vec3 raw", [ch "weighting" w; tx "source" "vec3"; bo "normalize" false];
    w ^ " vec4", [ch "weighting" w; tx "source" "vec4"];
    w ^ " group", [ch "weighting" w; tx "point_group" "a"];
    w ^ " group padded raw", [ch "weighting" w; tx "point_group" " a "; bo "normalize" false; tx "source" "float"];
    w ^ " group missing", [ch "weighting" w; tx "point_group" "nope"];
    w ^ " output existing", [ch "weighting" w; tx "source" "float"; tx "output" "float"];
    w ^ " output existing group", [ch "weighting" w; tx "source" "vec3"; tx "output" "vec3"; tx "point_group" "a"];
    w ^ " output wrong type", [ch "weighting" w; tx "source" "float"; tx "output" "vec3"];
    w ^ " output blank", [ch "weighting" w; tx "output" "  "];
    w ^ " output blank source", [ch "weighting" w; tx "source" "float"; tx "output" ""];
    w ^ " output padded", [ch "weighting" w; tx "output" " lap "];
    w ^ " source missing", [ch "weighting" w; tx "source" "nope"];
    w ^ " source blank", [ch "weighting" w; tx "source" "  "];
    w ^ " source text", [ch "weighting" w; tx "source" "label"];
    w ^ " source primitive", [ch "weighting" w; tx "source" "prim_float"] ])
    ["Cotangent"; "Positive cotangent"; "Uniform"]
  @ [ "output P", [tx "output" "P"]; "output spaced P", [tx "output" " P "]; "source P output explicit", [tx "output" "pl"] ]

let bench () = [Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> get_ok],
  [ch "weighting" "Uniform"]
let node = { key = "attribute_laplacian"; native = Sop.Nodes.Attribute_laplacian.factory; inputs; cases;
  ulps = 4; bench = Some bench }
let () = register node
