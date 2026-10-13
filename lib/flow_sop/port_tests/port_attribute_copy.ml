(* sop/attribute_copy: two geometry inputs (source, target). PARTIAL draft gate: cases cover cyclic and
   to-element matching with exact groups, same-owner and detail rules; value matching, group patterns,
   cross-owner projection and ragged attributes are listed as cases at the end and fail until ported. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let ch name value = name, P.Choice_value value

let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:6 ~rows:6 ~size:4. () |> get_ok
let base () = fixture_attributes (fixture_groups (polygon_polyline ()))
let grid () = fixture_attributes (fixture_groups (small_grid ()))
let inputs = [
  "mixed to mixed", [base (); base ()];
  "grid to mixed", [grid (); base ()];
  "mixed to grid", [base (); grid ()] ]

let rule owner pattern into = owner ^ "\t" ^ pattern ^ "\t" ^ into
let cases =
  List.concat_map (fun owner -> List.map (fun (label, rules) ->
    Printf.sprintf "%s %s" owner label, [ch "group_owner" owner; tx "rules" rules])
    [ "all point", rule "point" "*" "";
      "all vertex", rule "vertex" "*" "";
      "all primitive", rule "primitive" "*" "";
      "detail", rule "detail" "*" "";
      "vec rewrite", rule "point" "vec*" "copy_*";
      "two rows", rule "point" "float" "" ^ "\n" ^ rule "vertex" "int*" "i_*";
      "non-ragged mix", rule "point" "[ftv]*" "";
      "none match", rule "point" "absent*" "" ])
    ["Points"; "Vertices"; "Primitives"]
  @ [ "duplicate destination", [tx "rules" (rule "point" "float" "same" ^ "\n" ^ rule "point" "vec2" "same")];
      "empty rewrite", [tx "rules" (rule "point" "float" "*x")];
      "source group", [tx "source_group" "a"];
      "target group", [tx "target_group" "a"];
      "both groups", [tx "source_group" "a"; tx "target_group" "dest_a"; ch "group_owner" "Primitives";
                      tx "rules" (rule "primitive" "*" "")];
      "missing source group", [tx "source_group" "nothing"];
      "missing target group", [tx "target_group" "nothing"];
      "to element", [ch "match_" "To source element"; tx "target_element_attribute" "integer"];
      "to element missing", [ch "match_" "To source element"; tx "target_element_attribute" "absent"];
      "to element wrong type", [ch "match_" "To source element"; tx "target_element_attribute" "float"];
      "to element blank", [ch "match_" "To source element"; tx "target_element_attribute" " "];
      "by values vertex", [ch "match_" "By attribute values"; ch "group_owner" "Vertices"];
      "by values blank", [ch "match_" "By attribute values"; tx "source_match_attribute" " "];
      "allow P", [bo "allow_position" true; tx "rules" (rule "point" "P" "")];
      (* not ported yet: each of these fails the gate *)
      "TODO by values int", [ch "match_" "By attribute values"; tx "source_match_attribute" "integer";
                            tx "target_match_attribute" "integer"];
      "TODO by values text", [ch "match_" "By attribute values"; tx "source_match_attribute" "text";
                             tx "target_match_attribute" "text"; ch "group_owner" "Primitives";
                             tx "rules" (rule "primitive" "*" "")];
      "TODO pattern groups", [tx "source_group_pattern" "*"; tx "target_group_pattern" "d*"];
      "TODO projection", [ch "group_owner" "Primitives"; tx "rules" (rule "point" "*" "")];
      "TODO ragged", [tx "rules" (rule "point" "*_rows" "")] ]

let () = register { key = "attribute_copy"; native = Sop.Nodes.Attribute_copy.factory; inputs; cases; ulps = 4; bench = None }
