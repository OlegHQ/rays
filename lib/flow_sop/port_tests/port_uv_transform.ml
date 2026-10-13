(* sop/uv_transform: one geometry input (pending draft). The standard fixtures carry a "vec2"
   attribute on every owner, a "float" attribute and the groups a/dest_a/old_x. Construction
   refusals raise at lowering, which the gate's oracle arm does not accept, so non-finite
   parameters are covered by the gate's own refusal check only. *)
open Rdk
open Port_gate
module P = Param
let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value
let num name value = name, P.Float_value value
let uv = ["vec2", "uv"]
let cases =
  List.concat_map (fun owner -> List.map (fun (label, changes) ->
    Printf.sprintf "%s/%s" owner label, choice "owner" owner :: text "name" "vec2" :: changes)
    [ "default", [];
      "translate", [num "translate_u" 0.75; num "translate_v" (-1.25)];
      "scale", [num "scale_u" 2.5; num "scale_v" (-0.5)];
      "angle", [num "angle" 0.7];
      "pivot", [num "pivot_u" (-0.3); num "pivot_v" 2.0];
      "all", [num "translate_u" 0.1; num "translate_v" 0.2; num "scale_u" 1.5; num "scale_v" 0.25;
              num "angle" (-2.1); num "pivot_u" 0.9; num "pivot_v" 0.1];
      "group", [text "group" "a"; num "angle" 1.0; num "scale_u" 3.];
      "group_padded", [text "group" " dest_a "; num "translate_u" 1.];
      "missing_group", [text "group" "nope"];
      "no_group_other_owner_name", [text "group" "old_x"; num "angle" 0.3] ])
    ["Point"; "Vertex"]
  @ [ "missing_attribute", [text "name" "uv"];
      "blank_name", [text "name" "  "];
      "padded_name", [text "name" " vec2 "];
      "wrong_storage_float", [text "name" "float"];
      "wrong_storage_vec3", [text "name" "vec3"];
      "wrong_storage_int", [text "name" "integer"];
      "wrong_owner_primitive_name", [choice "owner" "Point"; text "name" "vec2"; num "angle" 3.14];
      "overflow", [text "name" "vec2"; num "scale_u" 1e308; num "translate_u" 1e308; num "angle" 0.5];
      "overflow_group", [text "name" "vec2"; num "scale_u" 1e308; num "translate_u" 1e308; text "group" "a"];
      "default_group_overflow_unselected", [text "name" "vec2"; num "scale_v" 1e308; text "group" "dest_a"] ]
let bench () =
  let count = 1_000_000 in
  let plane scale = Array.init count (fun i -> float (i mod 997) *. scale) in
  let attribute = Attribute.create_owned ~owner:Attribute.Point ~name:"uv"
    (Attribute.Float2 (Packed.Float2.of_owned ~x:(plane 0.001) ~y:(plane 0.002) |> Rdk_test_support.get_string_ok))
    |> Rdk_test_support.get_string_ok in
  let g = Geometry.with_attribute attribute (points count) |> Rdk_test_support.get_string_ok in
  [g], [choice "owner" "Point"; num "angle" 0.5; num "scale_u" 1.5; num "translate_v" 0.25]
(* The default attribute name "uv" must exist for the cache check, so the standard fixtures also
   carry point and vertex "uv" attributes (-0, negatives and values beyond [0,1]). *)
let with_uv geometry =
  List.fold_left (fun geometry (owner, count) ->
    let plane scale = Array.init count (fun i -> if i mod 5 = 0 then -0. else (float (i mod 11) -. 3.) *. scale) in
    Geometry.with_attribute (Attribute.create_owned ~owner ~name:"uv"
      (Attribute.Float2 (Packed.Float2.of_owned ~x:(plane 0.375) ~y:(plane (-0.2)) |> Rdk_test_support.get_string_ok))
      |> Rdk_test_support.get_string_ok) geometry |> Rdk_test_support.get_string_ok) geometry
    [Attribute.Point, Geometry.point_count geometry; Attribute.Vertex, Geometry.vertex_count geometry]
let inputs = List.map (fun (label, geometries) -> label, List.map with_uv geometries) standard_inputs
let () = ignore uv; register { key = "uv_transform"; native = Sop.Nodes.Uv_transform.factory;
  inputs; cases = ("default_uv", []) :: cases
    @ List.map (fun (l, c) -> "uv_" ^ l, c) [
        "point_group", [choice "owner" "Point"; text "group" "a"; num "angle" 0.6];
        "vertex_translate", [num "translate_u" 0.4; num "scale_v" 2.];
        "vertex_missing_group", [text "group" "zzz"] ];
  ulps = 4; bench = Some bench }
