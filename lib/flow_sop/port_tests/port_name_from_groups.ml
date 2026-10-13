(* sop/name_from_groups: one geometry input (pending draft nodes/name_from_groups.pending). *)
open Port_gate
module P = Param
let ch name value = name, P.Choice_value value
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let fields owner attribute pattern default overlap delete =
  [ch "owner" owner; tx "attribute" attribute; tx "pattern" pattern; tx "default" default;
   ch "overlap" overlap; bo "delete_groups" delete]
let owners = ["Point"; "Vertex"; "Primitive"]
let overlaps = ["First group"; "Last group"; "Error on overlap"]
let cases =
  [ "defaults", [];
    "override unicode default", fields "Point" "name" "*" "fallbacké\000😀" "Last group" true ]
  @ List.concat_map (fun owner -> List.concat_map (fun overlap -> List.map (fun delete ->
      Printf.sprintf "%s/%s/delete=%b" owner overlap delete,
      fields owner "name" "*" "fallbacké\000😀" overlap delete) [false; true]) overlaps) owners
  @ List.map (fun (attribute, pattern) ->
      Printf.sprintf "attribute %S pattern %S" attribute pattern,
      fields "Point" attribute pattern "default" "Last group" true)
    ["old", "* ^a*"; " name ", "z*"; "name", "unmatched"; "name", ""; "name", " \t\n";
     "name", "é*"; "name", "z_first empty"; "P", "unmatched"; "P", "*"]
  @ List.map (fun (attribute, pattern, overlap) ->
      Printf.sprintf "error %S %S %s" attribute pattern overlap,
      fields "Point" attribute pattern "" overlap false)
    [" \t\n", "[", "Error on overlap"; "keep_int", "[", "First group";
     "name", "\\", "First group"; "name", "[", "First group"; "P", "*", "Error on overlap"]
  @ List.concat_map (fun owner -> List.map (fun name ->
      Printf.sprintf "error %s/%s" owner name, fields owner name "*" "" "Error on overlap" false)
    ["keep_float"; "keep_int"; "keep_vec2"; "keep_vec3"; "keep_vec4"; "keep_float_rows"; "keep_int_rows"])
    owners
let bench () = [points 1_000_000], fields "Point" "name" "*" "default" "Last group" true
let () = register { key = "name_from_groups"; native = Sop.Nodes.Name_from_groups.factory;
  inputs = standard_inputs; cases; ulps = 4; bench = Some bench }
