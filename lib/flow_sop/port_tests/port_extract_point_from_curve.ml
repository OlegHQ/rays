(* sop/extract_point_from_curve: one geometry input. Curves carry a point attribute "distance" (float),
   "idist" (integer), a primitive "cut" (float) and "icut" (integer), and every storage type on every owner.
   Dropped: a non-finite cut attribute (the interpreter reports E_NONFINITE where native reports invalid_curve) and
   polygon or non-finite distance inputs (the defaults would error there and the cache check needs them to cook). *)
open Rdk
open Port_gate
module P = Param
let tx name v = name, P.Text_value v
let ch name v = name, P.Choice_value v
let fl name v = name, P.Float_value v
let bo name v = name, P.Bool_value v
let open_k = Topology.Open_polyline and closed_k = Topology.Closed_polyline
let add owner name storage geometry = Geometry.with_attribute
  (Attribute.create_owned ~owner ~name storage |> Rdk_test_support.get_string_ok) geometry
  |> Rdk_test_support.get_string_ok
let curves ~count ~vertex_points ~offsets ~kinds =
  let topology = Topology.create_owned ~point_count:count ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> Rdk_test_support.get_string_ok in
  let positions = Packed.Float3.Private.of_owned_exn
    ~x:(Array.init count (fun i -> float i *. 0.75 +. float (i mod 3)))
    ~y:(Array.init count (fun i -> float (i mod 4) *. 0.5)) ~z:(Array.init count (fun i -> float (i mod 5) *. 0.25)) in
  let geometry = Geometry.create ~positions ~topology () |> Rdk_test_support.get_string_ok in
  let prims = Array.length kinds in
  (* A zig-zag distance crossing 0 and 0.5 several times; some exact hits, a plateau and a negative run. *)
  let wave i = match i mod 7 with 0 -> -1.5 | 1 -> 0. | 2 -> 0.5 | 3 -> 1. | 4 -> 0.5 | 5 -> -0.25 | _ -> 0. in
  let geometry = fixture_attributes (fixture_groups geometry) in
  geometry
  |> add Attribute.Point "distance" (Attribute.Float (Array.init count wave))
  |> add Attribute.Point "idist" (Attribute.Int (Array.init count (fun i -> (i mod 5) - 2)))
  |> add Attribute.Point "bad_text" (Attribute.Text (Array.make count "x"))
  |> add Attribute.Primitive "cut" (Attribute.Float (Array.init prims (fun i -> if i mod 2 = 0 then 0.5 else -0.1)))
  |> add Attribute.Primitive "icut" (Attribute.Int (Array.init prims (fun i -> i mod 3 - 1)))
let inputs = List.map (fun (label, g) -> label, [g]) [
  "open", curves ~count:12 ~vertex_points:[|0;1;2;3;4;5;6;7;8;9;10;11|] ~offsets:[|0;4;8;12|] ~kinds:[|open_k; open_k; open_k|];
  "closed", curves ~count:9 ~vertex_points:[|0;1;2;3;4;5;6;7;8;5|] ~offsets:[|0;4;7;10|] ~kinds:[|closed_k; closed_k; open_k|];
  "short", curves ~count:5 ~vertex_points:[|0;1;2;3;4|] ~offsets:[|0;2;5|] ~kinds:[|open_k; closed_k|];
  "empty", curves ~count:0 ~vertex_points:[||] ~offsets:[|0|] ~kinds:[||];
  "wide", curves ~count:40 ~vertex_points:(Array.init 40 Fun.id) ~offsets:[|0;40|] ~kinds:[|open_k|]]
let cases = [
  "constant_half", [fl "constant" 0.5];
  "constant_negative", [fl "constant" (-0.25)];
  "constant_none", [fl "constant" 9.];
  "primitive_attribute", [ch "cut" "Primitive attribute"];
  "primitive_attribute_int", [ch "cut" "Primitive attribute"; tx "primitive_attribute" "icut"];
  "primitive_attribute_missing", [ch "cut" "Primitive attribute"; tx "primitive_attribute" "nothing"];
  "primitive_attribute_text", [ch "cut" "Primitive attribute"; tx "primitive_attribute" "untouched"];
  "primitive_attribute_padded", [ch "cut" "Primitive attribute"; tx "primitive_attribute" " cut "];
  "current_time", [ch "cut" "Current time"];
  "distance_int", [tx "distance_attribute" "idist"];
  "distance_missing", [tx "distance_attribute" "nothing"];
  "distance_padded", [tx "distance_attribute" " distance "];
  "distance_text", [tx "distance_attribute" "bad_text"];
  "distance_blank_error", [tx "distance_attribute" " "];
  "distance_P_error", [tx "distance_attribute" "P"];
  "group", [tx "group" "a"]; "group_padded", [tx "group" " dest_a "];
  "group_missing", [tx "group" "nothing"];
  "group_unicode", [tx "group" "\195\169\231\140\171"];
  "point_all", [tx "point_attributes" "*"];
  "point_some", [tx "point_attributes" "float vec3 text"];
  "point_exclude", [tx "point_attributes" "* ^float ^text"];
  "point_none", [tx "point_attributes" "zzz"];
  "point_bad", [tx "point_attributes" "["];
  "primitive_copy", [bo "copy_primitive_attributes" true];
  "primitive_copy_some", [bo "copy_primitive_attributes" true; tx "primitive_attributes" "cut float_rows integer"];
  "primitive_copy_off", [tx "primitive_attributes" "cut"];
  "primitive_copy_bad", [bo "copy_primitive_attributes" true; tx "primitive_attributes" "["];
  "both_clash", [tx "point_attributes" "float"; bo "copy_primitive_attributes" true; tx "primitive_attributes" "float"];
  "clash_generated", [tx "point_attributes" "float"; tx "curve_u_attribute" "float"];
  "generated_u", [tx "curve_u_attribute" "u"];
  "generated_cuts", [tx "number_cuts_attribute" "cuts"];
  "generated_number", [tx "curve_number_attribute" "curve"];
  "generated_all", [tx "curve_u_attribute" " u "; tx "number_cuts_attribute" "n"; tx "curve_number_attribute" "c";
    tx "point_attributes" "*"; bo "copy_primitive_attributes" true; fl "constant" 0.5];
  "generated_duplicate", [tx "curve_u_attribute" "same"; tx "curve_number_attribute" " same "];
  "generated_P", [tx "curve_u_attribute" "P"];
  "generated_replace_existing", [tx "curve_u_attribute" "vec2"; tx "point_attributes" "float"];
  "everything", [tx "point_attributes" "*"; bo "copy_primitive_attributes" true; tx "curve_u_attribute" "u";
    tx "number_cuts_attribute" "n"; tx "curve_number_attribute" "c"; ch "cut" "Primitive attribute"; tx "group" "a"]]
let bench () =
  let n = 200_000 in
  let g = curves ~count:(n * 5) ~vertex_points:(Array.init (n * 5) Fun.id) ~offsets:(Array.init (n + 1) (fun i -> i * 5))
    ~kinds:(Array.make n open_k) in
  [g], [fl "constant" 0.5]
let () = register { key = "extract_point_from_curve"; native = Sop.Nodes.Extract_point_from_curve.factory;
  inputs; cases; ulps = 4; bench = Some bench }
