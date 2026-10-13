(* sop/points: zero-input bounded generator (accepted port). *)
open Port_gate
module P = Param
let text name value = name, P.Text_value value
let cases =
  List.concat_map (fun n -> List.concat_map (fun (g, group) -> List.map (fun (m, names) ->
    Printf.sprintf "count=%d/%s/%s" n g m, ("points", P.Int_value n) :: text "generated_group" group :: names)
    ["default", []; "custom", [text "source_point_attribute" " point\195\169 "; text "source_index_attribute" " index\231\140\171 "]])
    ["empty", ""; "blank", " \t\r\n"; "trim_named", " \t made\195\169 \n"]) [1; 7; 50]
  @ List.map (fun (l, c) -> l, ("points", P.Int_value 7) :: c)
    ["literal_wildcard_group", [text "generated_group" " *?[ab] "];
     "group_equals_attribute", [text "generated_group" "sourcepoint"];
     "group_P_is_valid", [text "generated_group" " P "];
     "raw_spaced_P_metadata", [text "source_point_attribute" " P "; text "source_index_attribute" "p"];
     "trim_equivalent_distinct_metadata", [text "source_point_attribute" "same";
       text "source_index_attribute" " same "; text "generated_group" " same "];
     "swapped_metadata", [text "source_point_attribute" "sourceindex"; text "source_index_attribute" "sourcepoint"];
     "escaped_utf8_metadata", [text "source_point_attribute" " a\\\"\195\169\231\140\171\n ";
       text "source_index_attribute" "\t b "];
     "form_feed_blank", [text "generated_group" "\012"]]
let () = register { key = "points"; native = Sop.Nodes.Point_generate.factory; inputs = no_input;
  cases; ulps = 4; bench = None (* capped at 50 points: nothing to time at 1,000,000 *) }
