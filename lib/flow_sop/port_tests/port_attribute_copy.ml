(* sop/attribute_copy: two geometry inputs (source, target). Cases cover every matching mode, exact and
   patterned groups, every owner projection, ragged attributes, canonical P and construction refusals. *)
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
      "by values int", [ch "match_" "By attribute values"; tx "source_match_attribute" "integer";
                            tx "target_match_attribute" "integer"];
      "by values text", [ch "match_" "By attribute values"; tx "source_match_attribute" "text";
                             tx "target_match_attribute" "text"; ch "group_owner" "Primitives";
                             tx "rules" (rule "primitive" "*" "")];
      "by values grouped", [ch "match_" "By attribute values"; tx "source_match_attribute" "integer";
                            tx "target_match_attribute" "integer"; tx "source_group" "a"; tx "target_group" "a"];
      "by values mixed storage", [ch "match_" "By attribute values"; tx "source_match_attribute" "integer";
                                  tx "target_match_attribute" "text"];
      "by values missing", [ch "match_" "By attribute values"; tx "source_match_attribute" "absent"];
      "by values P", [ch "match_" "By attribute values"; tx "source_match_attribute" "P"];
      "by values none selected", [ch "match_" "By attribute values"; tx "source_match_attribute" "absent";
                                  tx "rules" (rule "point" "absent*" "")];
      "pattern groups", [tx "source_group_pattern" "*"; tx "target_group_pattern" "d*"];
      "pattern one group", [tx "source_group_pattern" "a"; tx "target_group_pattern" "dest_a"];
      "pattern no group", [tx "source_group_pattern" "zzz*"];
      "pattern beats exact", [tx "source_group_pattern" "a"; tx "source_group" "nothing"];
      "pattern vertices", [ch "group_owner" "Vertices"; tx "source_group_pattern" "[ao]*"; tx "target_group_pattern" "*_a"];
      "pattern primitives", [ch "group_owner" "Primitives"; tx "source_group_pattern" "*"; tx "rules" (rule "vertex" "*" "")];
      "bad group pattern", [tx "source_group_pattern" "["];
      "projection point to primitive", [tx "rules" (rule "primitive" "*" "")];
      "projection vertex to point", [ch "group_owner" "Vertices"; tx "rules" (rule "point" "*" "")];
      "projection vertex to primitive grouped",
        [ch "group_owner" "Vertices"; tx "rules" (rule "primitive" "*" ""); tx "source_group" "a"; tx "target_group" "dest_a"];
      "projection primitive to vertex", [ch "group_owner" "Primitives"; tx "rules" (rule "vertex" "*" "")];
      "projection primitive to point", [ch "group_owner" "Primitives"; tx "rules" (rule "point" "*" "")];
      "projection point to vertex grouped", [tx "rules" (rule "vertex" "*" ""); tx "source_group" "dest_a"];
      "projection every owner", [ch "group_owner" "Primitives";
        tx "rules" (rule "point" "*" "" ^ "\n" ^ rule "vertex" "*" "" ^ "\n" ^ rule "primitive" "*" "" ^ "\n" ^ rule "detail" "*" "")];
      "detail float", [tx "rules" (rule "detail" "float" "")];
      "detail integer", [tx "rules" (rule "detail" "integer" "")];
      "detail text", [tx "rules" (rule "detail" "text" "")];
      "detail vec3", [tx "rules" (rule "detail" "vec3" "")];
      "detail rows", [tx "rules" (rule "detail" "*_rows" "")];
      "ragged", [tx "rules" (rule "point" "*_rows" "")];
      "ragged vertex rewrite", [ch "group_owner" "Primitives"; tx "rules" (rule "vertex" "*_rows" "r_*")];
      "ragged merge", [tx "rules" (rule "primitive" "int_rows" "float_rows")];
      "kind mismatch merge", [ch "group_owner" "Primitives"; tx "rules" (rule "primitive" "float" "integer")];
      "P rewrite", [bo "allow_position" true; tx "rules" (rule "point" "vec3" "P")];
      "P all", [bo "allow_position" true; ch "group_owner" "Primitives"; tx "rules" (rule "point" "*" "")];
      "P grouped", [bo "allow_position" true; tx "source_group" "a"; tx "target_group" "dest_a"; tx "rules" (rule "point" "[Pv]*" "")];
      "P without allow", [tx "rules" (rule "point" "vec3" "P")];
      "P float", [bo "allow_position" true; tx "rules" (rule "point" "float" "P")];
      "P vertex owner", [bo "allow_position" true; tx "rules" (rule "vertex" "vec3" "P")];
      "uppercase owner", [tx "rules" ("  Points \t" ^ "vec*" ^ "\t copy_* ")];
      "bad owner", [tx "rules" (rule "edge" "*" "")];
      "two columns", [tx "rules" "point\t*"];
      "empty rules", [tx "rules" ""];
      "bad pattern", [tx "rules" (rule "point" "[" "")];
      "bad rewrite", [tx "rules" (rule "point" "a*b" "x")];
      "bad escape", [tx "rules" "point\t*\t\\q"] ]

(* One million points: a float, an int and a vec3 attribute copied cyclically from a half-size source. *)
let bench () =
  let n = 1_000_000 in
  let add name storage g = Geometry.with_attribute
    (Attribute.create_owned ~name ~owner:Attribute.Point storage |> get_string_ok) g |> get_string_ok in
  let source m = points m
    |> add "f" (Attribute.Float (Array.init m float))
    |> add "i" (Attribute.Int (Array.init m Fun.id))
    |> add "v" (Attribute.Float3 (Packed.Float3.of_owned ~x:(Array.init m float) ~y:(Array.make m 1.)
         ~z:(Array.make m 2.) |> get_string_ok)) in
  [source (n / 2); points n], []
let () = register { key = "attribute_copy"; native = Sop.Nodes.Attribute_copy.factory; inputs; cases; ulps = 4;
  bench = Some bench }
