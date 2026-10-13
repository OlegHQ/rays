(* sop/rest_position: one input plus optional reference (pending draft nodes/rest_position.pending). *)
open Port_gate
module P = Param
let modes = ["Store"; "Extract"; "Swap"]
let normals = ["None"; "If present"; "Always"]
let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value
let cases =
  [ "rest_attribute blank", [text "rest_attribute" ""];
    "rest_attribute N", [text "rest_attribute" "N"];
    "all attributes", [text "rest_attribute" "N"; choice "normals" "If present";
      text "normal_attribute" "restN"; text "rest_normal_attribute" "rest"];
    "extract P stored", [choice "mode" "Extract"; text "rest_normal_attribute" "P"] ]
  @ List.concat_map (fun mode -> List.map (fun normal ->
      Printf.sprintf "%s/%s" mode normal, [choice "mode" mode; choice "normals" normal])
    normals) modes
  @ List.concat_map (fun mode -> List.map (fun (rest, normal, stored) ->
      Printf.sprintf "%s/rest=%s/N=%s/stored=%s" mode rest normal stored,
      [choice "mode" mode; choice "normals" "If present";
       text "rest_attribute" rest; text "normal_attribute" normal; text "rest_normal_attribute" stored])
    ["rest", "rest", "rest"; "rest", "N", "rest"; "N", "N", "restN"; "rest", "restN", "restN"]) modes
let bench () = [points 1_000_000], []
let () = register { key = "rest_position"; native = Sop.Nodes.Rest_position.factory;
  inputs = standard_inputs; cases; ulps = 4; bench = Some bench }
