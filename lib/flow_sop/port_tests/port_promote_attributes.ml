(* sop/promote_attributes: one geometry input. Cases cover the sixteen owner pairs, all twelve methods on
   float, vector, integer, text and ragged attributes, piece partitions, delete source, rename and index
   patterns (including exclusion terms) and the construction and cook refusals. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let tx name value = name, P.Text_value value
let ch name value = name, P.Choice_value value
let bo name b = name, P.Bool_value b

let owners = ["Point"; "Vertex"; "Primitive"; "Detail"]
let methods = ["First"; "Last"; "Average"; "Minimum"; "Maximum"; "Mode"; "Median"; "Sum"; "Sum of squares";
               "Root mean square"; "Array of all"; "Unique values"]
let route source destination = [ch "source" source; ch "destination" destination]
let pairs = List.concat_map (fun s -> List.map (fun d -> s, d) owners) owners

(* the grid fixture has no shared points; the mixed fixture has a point shared by both primitives *)
let cases =
  List.concat_map (fun (s, d) ->
    let label what = Printf.sprintf "%s to %s %s" s d what in
    [ label "defaults", route s d;
      label "first no ragged", route s d @ [tx "pattern" "* ^*_rows"; ch "method_" "First"];
      label "last no ragged", route s d @ [tx "pattern" "* ^*_rows"; ch "method_" "Last"];
      label "average floats", route s d @ [tx "pattern" "float vec2 vec3 vec4"];
      label "median floats", route s d @ [tx "pattern" "float vec3"; ch "method_" "Median"];
      label "mode ints", route s d @ [tx "pattern" "integer text"; ch "method_" "Mode"];
      label "array of all", route s d @ [tx "pattern" "float integer float_rows"; ch "method_" "Array of all"];
      label "delete source", route s d @ [tx "pattern" "float integer"; ch "method_" "First"; bo "delete_source" true] ])
    pairs
  @ List.concat_map (fun m ->
    let label what = Printf.sprintf "%s %s" m what in
    let route = route "Vertex" "Point" in
    [ label "float", route @ [tx "pattern" "float"; ch "method_" m];
      label "vec", route @ [tx "pattern" "vec2 vec3 vec4"; ch "method_" m];
      label "int", route @ [tx "pattern" "integer"; ch "method_" m];
      label "text", route @ [tx "pattern" "text"; ch "method_" m];
      label "ragged", route @ [tx "pattern" "*_rows"; ch "method_" m];
      label "primitive to point", [ch "source" "Primitive"; ch "destination" "Point"; tx "pattern" "float integer text";
                                   ch "method_" m];
      label "point to detail", [ch "source" "Point"; ch "destination" "Detail"; tx "pattern" "float vec3 integer text";
                                ch "method_" m] ]) methods
  @ [ "piece int", route "Point" "Primitive" @ [tx "piece_attribute" "integer"; tx "pattern" "float vec3 integer"];
      "piece text", route "Vertex" "Primitive" @ [tx "piece_attribute" "text"; tx "pattern" "float"];
      "piece identity", route "Primitive" "Primitive" @ [tx "piece_attribute" "integer"; tx "pattern" "float";
                                                         tx "into_pattern" "p_*"];
      "piece primitive to point", route "Primitive" "Point" @ [tx "piece_attribute" "integer"; tx "pattern" "float"];
      "piece detail", route "Point" "Detail" @ [tx "piece_attribute" "integer"; tx "pattern" "float"];
      "piece median", route "Point" "Vertex" @ [tx "piece_attribute" "integer"; tx "pattern" "float"; ch "method_" "Median"];
      "piece array", route "Point" "Vertex" @ [tx "piece_attribute" "text"; tx "pattern" "float"; ch "method_" "Array of all"];
      "piece unique", route "Vertex" "Primitive" @ [tx "piece_attribute" "integer"; tx "pattern" "integer";
                                                    ch "method_" "Unique values"];
      "piece missing", route "Point" "Primitive" @ [tx "piece_attribute" "absent"];
      "piece float", route "Point" "Primitive" @ [tx "piece_attribute" "float"];
      "piece with none selected", route "Point" "Primitive" @ [tx "piece_attribute" "absent"; tx "pattern" "zzz*"];
      "piece blank", route "Point" "Primitive" @ [tx "piece_attribute" "   "; tx "pattern" "float"];
      "no match", [tx "pattern" "zzz*"];
      "rename", route "Point" "Primitive" @ [tx "pattern" "float vec3"; tx "into_pattern" "mean_*"];
      "rename same owner", route "Point" "Point" @ [tx "pattern" "float"; tx "into_pattern" "copy_*"];
      "rename same name", route "Point" "Point" @ [tx "pattern" "float"; tx "into_pattern" "float"];
      "rename same name piece", route "Point" "Point" @ [tx "pattern" "float"; tx "into_pattern" "float";
                                                         tx "piece_attribute" "integer"];
      "rename exclusion", route "Point" "Primitive" @ [tx "pattern" "* ^vec* ^*_rows"; tx "into_pattern" "m_*"];
      "rename two terms", route "Point" "Primitive" @ [tx "pattern" "float vec3"; tx "into_pattern" "f_* v_*"];
      "rename term mismatch", route "Point" "Primitive" @ [tx "pattern" "float vec3"; tx "into_pattern" "f_*"];
      "rename bad", route "Point" "Primitive" @ [tx "pattern" "float"; tx "into_pattern" "a*b*"];
      "rename blank result", route "Point" "Primitive" @ [tx "pattern" "float"; tx "into_pattern" "?"];
      "rename collision", route "Point" "Primitive" @ [tx "pattern" "float vec2"; tx "into_pattern" "same same"];
      "rename P", route "Vertex" "Point" @ [tx "pattern" "vec3"; tx "into_pattern" "P"];
      "rename P primitive", route "Vertex" "Primitive" @ [tx "pattern" "vec3"; tx "into_pattern" "P"];
      "bad pattern", [tx "pattern" "["];
      "index first", route "Point" "Primitive" @ [tx "pattern" "float vec3 integer text"; ch "method_" "First";
                                                  tx "index_pattern" "src_*"];
      "index last", route "Vertex" "Point" @ [tx "pattern" "float vec2 integer text"; ch "method_" "Last";
                                              tx "index_pattern" "src_*"];
      "index minimum", route "Vertex" "Primitive" @ [tx "pattern" "float vec4 integer text"; ch "method_" "Minimum";
                                                     tx "index_pattern" "src_*"];
      "index maximum", route "Point" "Primitive" @ [tx "pattern" "float vec3 integer"; ch "method_" "Maximum";
                                                    tx "index_pattern" "src_*"];
      "index mode", route "Vertex" "Primitive" @ [tx "pattern" "float vec2 integer text"; ch "method_" "Mode";
                                                  tx "index_pattern" "src_*"];
      "index piece", route "Point" "Primitive" @ [tx "pattern" "float"; ch "method_" "Maximum";
                                                  tx "index_pattern" "src_*"; tx "piece_attribute" "integer"];
      "index with rename", route "Point" "Primitive" @ [tx "pattern" "float"; ch "method_" "Minimum";
                                                        tx "into_pattern" "v_*"; tx "index_pattern" "i_*"];
      "index average", route "Point" "Primitive" @ [tx "index_pattern" "src_*"];
      "index ragged", route "Point" "Primitive" @ [tx "pattern" "*_rows"; ch "method_" "First"; tx "index_pattern" "src_*"];
      "index equals value", route "Point" "Primitive" @ [tx "pattern" "float"; ch "method_" "First"; tx "index_pattern" "*"];
      "index equals piece", route "Point" "Primitive" @ [tx "pattern" "float"; ch "method_" "First";
                                                         tx "index_pattern" "integer"; tx "piece_attribute" "integer";
                                                         tx "into_pattern" "v_*"];
      "index P", route "Vertex" "Point" @ [tx "pattern" "vec3"; ch "method_" "First"; tx "index_pattern" "P";
                                           tx "into_pattern" "v_*"];
      "integer average", route "Point" "Primitive" @ [tx "pattern" "integer"; ch "method_" "Average"];
      "text sum", route "Point" "Primitive" @ [tx "pattern" "text"; ch "method_" "Sum"];
      "text average", route "Point" "Primitive" @ [tx "pattern" "text"; ch "method_" "Average"];
      "text unique", route "Point" "Primitive" @ [tx "pattern" "text"; ch "method_" "Unique values"];
      "vector array", route "Point" "Primitive" @ [tx "pattern" "vec3"; ch "method_" "Array of all"];
      "ragged first", route "Point" "Primitive" @ [tx "pattern" "int_rows"; ch "method_" "First"];
      "rename tab separators", route "Point" "Primitive" @ [tx "pattern" "float\tvec3"; tx "into_pattern" "f_*\tv_*"];
      "rename newline separators", route "Point" "Primitive" @ [tx "pattern" "float\nvec3"; tx "into_pattern" "f_*\n\tv_*"];
      "rename mixed whitespace", route "Point" "Primitive" @ [tx "pattern" " \tfloat \t vec3\n"; tx "into_pattern" "f_* \tv_*"];
      "rename escaped space", route "Point" "Primitive" @ [tx "pattern" "a\\ b"; tx "into_pattern" "x\\ y"];
      "rename escaped space wildcard", route "Point" "Primitive" @ [tx "pattern" "a\\ * float"; tx "into_pattern" "q\\ * f_*"];
      "rename escaped tab", route "Point" "Primitive" @ [tx "pattern" "c\\\td"; tx "into_pattern" "z\\\ty"];
      "rename last match wins", route "Point" "Primitive" @ [tx "pattern" "float* *at"; tx "into_pattern" "first_* last_*"];
      "rename exclusion first", route "Point" "Primitive" @ [tx "pattern" "^float vec*"; tx "into_pattern" "v_*"];
      "rename exclusion unmatched name", route "Point" "Primitive" @ [tx "pattern" "^float vec3"; tx "into_pattern" "v_*"];
      "rename dangling escape", route "Point" "Primitive" @ [tx "pattern" "float"; tx "into_pattern" "x\\"];
      "rename tab term mismatch", route "Point" "Primitive" @ [tx "pattern" "float\tvec3"; tx "into_pattern" "f_*"];
      "index tab separators", route "Point" "Primitive" @ [tx "pattern" "float\tvec3"; ch "method_" "First";
                                                           tx "into_pattern" "f_*\tv_*"; tx "index_pattern" "i_*\tj_*"];
      "index escaped space", route "Point" "Primitive" @ [tx "pattern" "a\\ b"; ch "method_" "First";
                                                          tx "into_pattern" "x\\ y"; tx "index_pattern" "i\\ j"] ]

let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> get_ok in
  let n = Geometry.point_count g in
  let g = Geometry.with_attribute (Attribute.create_owned ~name:"w" ~owner:Attribute.Point
    (Attribute.Float (Array.init n (fun i -> float (i mod 97)))) |> get_string_ok) g |> get_string_ok in
  [g], [tx "pattern" "w"; ch "source" "Point"; ch "destination" "Primitive"; ch "method_" "Average"]
(* point attributes whose names contain a space and a tab *)
let spaced () =
  let geometry = snd (List.nth (List.map (fun (l, gs) -> l, List.hd gs) standard_inputs) 3) in
  let n = Geometry.point_count geometry in
  List.fold_left (fun geometry name -> Geometry.with_attribute (Attribute.create_owned ~owner:Attribute.Point ~name
    (Attribute.Float (Array.init n (fun i -> float i *. 0.5))) |> get_string_ok) geometry |> get_string_ok)
    geometry ["a b"; "a c"; "c\td"]
let () = register { key = "promote_attributes"; native = Sop.Nodes.Promote_attributes.factory;
  inputs = standard_inputs @ ["spaced", [spaced ()]]; cases; ulps = 4; bench = Some bench }
