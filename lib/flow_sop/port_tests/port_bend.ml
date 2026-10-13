(* sop/bend: one geometry input (pending draft nodes/bend.pending). Finite inputs only. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let fl name x = name, P.Float_value x
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let ch name value = name, P.Choice_value value
let vec prefix (x, y, z) = [fl (prefix ^ "_x") x; fl (prefix ^ "_y") y; fl (prefix ^ "_z") z]

(* Positions spread over [-2.5, 2.5]^3, unit-ish point and vertex normals, and a point
   float attribute "mask" reaching beyond [0, 1]. *)
let hash i salt = float ((i * 7919 + salt * 104729 + 13) mod 1000) /. 500. -. 1.
let spread geometry =
  let n = Geometry.point_count geometry and vn = Geometry.vertex_count geometry in
  let plane salt scale count = Array.init count (fun i -> scale *. hash i salt) in
  let add owner name storage g = Geometry.with_attribute
    (Attribute.create_owned ~owner ~name storage |> get_string_ok) g |> get_string_ok in
  let vectors count = Attribute.Float3 (Packed.Float3.of_owned ~x:(plane 4 1. count) ~y:(plane 5 1. count)
    ~z:(plane 6 1. count) |> get_string_ok) in
  Geometry.with_positions (Packed.Float3.of_owned ~x:(plane 1 2.5 n) ~y:(plane 2 2.5 n) ~z:(plane 3 2.5 n)
    |> get_string_ok) geometry |> get_string_ok
  |> add Attribute.Point "N" (vectors n) |> add Attribute.Vertex "N" (vectors vn)
  |> add Attribute.Point "mask" (Attribute.Float (Array.init n (fun i -> 0.6 *. hash i 7 +. 0.5)))
let deformable_inputs =
  [ "cloud", [spread (fixture_groups (grid ()))];
    "cloud mixed", [spread (fixture_attributes (fixture_groups (polygon_polyline ())))] ]
let inputs = standard_inputs @ deformable_inputs

let cases =
  [ "owner point group a", [ch "group_owner" "Point"; tx "group" "a"] ]
  @ List.map (fun owner -> "owner " ^ owner, [ch "group_owner" owner; tx "group" " a "; fl "bend_angle" 1.1])
      ["Point"; "Vertex"; "Primitive"; "Edge"]
  @ [ "missing group", [tx "group" "nope"];
      "mask", [tx "mask_attribute" "mask"; fl "bend_angle" 1.3; fl "twist_angle" (-0.7)];
      "mask float", [tx "mask_attribute" " float "; fl "bend_angle" 1.3];
      "mask missing", [tx "mask_attribute" "absent"];
      "mask vec3", [tx "mask_attribute" "vec3"];
      "mask P", [tx "mask_attribute" "P"];
      "origin", vec "origin" (0.5, -0.25, 0.75) @ [fl "bend_angle" 1.0];
      "direction", vec "direction" (0.3, 0.5, -0.8) @ vec "up" (0.2, 0.1, 1.) @ [fl "bend_angle" 0.9; fl "twist_angle" 0.4];
      "up", vec "up" (1., 0.2, 0.3) @ [fl "bend_angle" 0.9];
      "direction zero", vec "direction" (0., 0., 0.);
      "up zero", vec "up" (0., 0., 0.);
      "up parallel", vec "up" (0., 1., 0.);
      "up nearly parallel", vec "up" (0., 1., 1e-9) @ [fl "bend_angle" 1.0];
      "length", [fl "length" 0.4; fl "bend_angle" 2.0];
      "long length", [fl "length" 7.; fl "twist_angle" 3.];
      "length zero", [fl "length" 0.];
      "bend", [fl "bend_angle" 1.4];
      "bend negative", [fl "bend_angle" (-2.2)];
      "twist", [fl "twist_angle" 1.4];
      "bend small", [fl "bend_angle" 1e-5];
      "bend tiny sum", [fl "bend_angle" 3e-5; fl "twist_angle" 2e-5];
      "limit off", [bo "limit" false; fl "bend_angle" 1.2];
      "both", [bo "both_directions" true; fl "bend_angle" 1.2; fl "twist_angle" 0.9];
      "both limit off", [bo "both_directions" true; bo "limit" false; fl "bend_angle" 1.2];
      "continuous", [bo "both_directions" true; bo "continuous_twist" true; fl "twist_angle" 1.3];
      "discontinuous twist", [bo "both_directions" true; bo "continuous_twist" false; fl "twist_angle" 1.3];
      "capture", [tx "capture_attribute" "cap"; fl "bend_angle" 1.0];
      "capture masked", [tx "capture_attribute" " cap "; tx "mask_attribute" "mask"; fl "twist_angle" 1.0];
      "capture not deforming", [tx "capture_attribute" "cap"];
      "capture over existing", [tx "capture_attribute" "mask"; fl "bend_angle" 1.0];
      "capture P", [tx "capture_attribute" "P"];
      "recompute", [bo "recompute_normals" true; fl "bend_angle" 1.0];
      "recompute still", [bo "recompute_normals" true];
      "everything", [ch "group_owner" "Primitive"; tx "group" "a"; tx "mask_attribute" "mask";
        bo "recompute_normals" true; tx "capture_attribute" "cap"; bo "both_directions" true;
        fl "length" 2.; fl "bend_angle" 2.5; fl "twist_angle" (-1.5)] @ vec "origin" (0.2, 0.3, -0.4) ]
let bench () = [spread (points 1_000_000)], [fl "bend_angle" 1.0; fl "twist_angle" 0.5]
let () = register { key = "bend"; native = Sop.Nodes.Bend.factory; inputs; cases; ulps = 4; bench = Some bench }
