(* sop/groups_from_name: one geometry input (pending draft). *)
open Port_gate
module P = Param
let t name v = name, P.Text_value v
let c name v = name, P.Choice_value v
let cases =
  List.concat_map (fun owner ->
    List.map (fun (label, changes) -> Printf.sprintf "%s/%s" label owner, c "owner" owner :: changes)
      ["default", [];
       "text_attribute", [t "attribute" "text"];
       "prefix", [t "attribute" "text"; t "prefix" "g_"];
       "union", [t "attribute" "text"; c "conflict" "Union"];
       "force_valid", [t "attribute" "text"; c "invalid_names" "Force valid"];
       "force_valid_prefix_digit", [t "attribute" "text"; t "prefix" "1"; c "invalid_names" "Force valid"];
       "prefix_existing_group", [t "attribute" "text"; t "prefix" "dest_"];
       "max_groups", [t "attribute" "text"; "max_groups", P.Int_value 1];
       "max_payload", [t "attribute" "text"; "max_payload_bytes", P.Int_value 1048576];
       "not_text", [t "attribute" "float"];
       "missing", [t "attribute" "nothing"];
       "blank_attribute", [t "attribute" " "]])
    ["Point"; "Vertex"; "Primitive"]
let () = register { key = "groups_from_name"; native = Sop.Nodes.Groups_from_name.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = None (* the bench needs a text attribute of 1,000,000 values *) }
