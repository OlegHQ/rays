(* sop/group_copy: two geometry inputs, source then target (pending draft). *)
open Rdk
open Port_gate
module P = Param
let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value
let flag name value = name, P.Bool_value value
let table rows = P.Text_value (String.concat "\n" (List.map (String.concat "\t") rows))
let rules rows = ["use_rules", P.Bool_value true; "rules", table rows]
(* Shuffled ids and repeated tags on every owner, so first-match lookup has hits, misses and
   duplicates. [salt] makes source and target disagree. *)
let with_keys salt geometry =
  List.fold_left (fun geometry owner ->
    let n = match owner with Attribute.Point -> Geometry.point_count geometry
      | Vertex -> Geometry.vertex_count geometry | Primitive -> Geometry.primitive_count geometry | Detail -> 1 in
    let put name storage geometry = Geometry.with_attribute
      (Attribute.create_owned ~owner ~name storage |> Rdk_test_support.get_string_ok) geometry
      |> Rdk_test_support.get_string_ok in
    geometry
    |> put "id" (Attribute.Int (Array.init n (fun i -> (n - 1 - i + salt) mod (n + 1))))
    |> put "tag" (Attribute.Text (Array.init n (fun i -> Printf.sprintf "t%d" ((i * 3 + salt) mod 5)))))
    geometry [Attribute.Point; Vertex; Primitive]
let base () = fixture_groups (grid ())
let small () = fixture_groups (polygon_polyline ())
let inputs = [
  "grid_to_mixed", [with_keys 0 (base ()); with_keys 1 (small ())];
  "mixed_to_grid", [with_keys 1 (small ()); with_keys 0 (base ())];
  "mixed_to_mixed", [fixture_attributes (with_keys 0 (small ())); fixture_attributes (with_keys 2 (small ()))];
  "empty_target", [with_keys 0 (small ()); fixture_groups (points 0)];
  "empty_source", [fixture_groups (points 0); with_keys 0 (small ())];
  "single_to_grid", [fixture_groups (points 1); with_keys 0 (base ())];
  "plain_target", [with_keys 0 (small ()); points 3] ]
let owners = ["point"; "vertex"; "primitive"; "edge"]
let conflicts = ["Skip"; "Overwrite"; "Add suffix"]
let cases =
  List.map (fun conflict -> "conflict/" ^ conflict, [choice "conflict" conflict]) conflicts
  @ ["empty/default", [flag "copy_empty" true];
     "empty/skip", [flag "copy_empty" true; choice "conflict" "Skip"]]
  @ List.concat_map (fun owner -> List.concat_map (fun conflict ->
      [Printf.sprintf "rule/%s/%s" owner conflict,
        choice "conflict" conflict :: rules [[owner; "*"; ""; ""]];
       Printf.sprintf "prefix/%s/%s" owner conflict,
        choice "conflict" conflict :: rules [[owner; "dest_* a"; "x_"; ""]]]) conflicts) owners
  @ List.concat_map (fun owner -> List.map (fun (attr, label) ->
      Printf.sprintf "match/%s/%s" owner label, rules [[owner; "*"; "m_"; attr]])
      ["id", "id"; "tag", "tag"; "integer", "dups"; "text", "uniform"; " id ", "trimmed";
       "nope", "missing"; "float", "float"; "vec3", "vec3"; "P", "P"]) owners
  @ [ "rules_multi", rules
        [["primitive"; "a"; "p_"; "id"]; ["point"; "a dest_a"; "q_"; "tag"]; ["edge"; "old_x"; ""; ""]; ["vertex"; "*"; "v_"; ""]];
      "rules_chain", rules [["point"; "a"; "z_"; ""]; ["point"; "z_*"; "z_"; ""]];
      "rules_none", ["use_rules", P.Bool_value true; "rules", P.Text_value ""];
      "rules_unused_off", ["rules", table [["point"; "a"; "p_"; "id"]]];
      "plural_tokens", rules [[" Points "; "a"; ""; ""]; ["VERTICES"; "a"; ""; ""]];
      "blank_pattern", rules [["point"; "  "; "b_"; ""]];
      "exclusion", rules [["point"; "* ^old*"; "e_"; ""]];
      "unmatched", rules [["point"; "zzz"; ""; ""]];
      "unmatched_bad_attr", rules [["point"; "zzz"; ""; "nope"]];
      "literal_name", rules [["primitive"; "literal\\ \\*\\?\\[\\]\\^\\\\"; "L"; ""]];
      "unicode", rules [["point"; "\195\169*"; "\231\140\171"; ""]];
      "bad_glob", rules [["point"; "["; ""; ""]];
      "bad_owner", rules [["thing"; "*"; ""; ""]];
      "bad_columns", rules [["point"; "*"; ""]] ]
let bench () =
  let n = 1_000_000 in
  let put name phase g = Geometry.with_group (Group.init ~owner:Group.Point ~name n (fun i -> i mod 3 = phase)) g
    |> Rdk_test_support.get_string_ok in
  [put "b" 1 (put "a" 0 (points n)); points n], rules [["point"; "*"; "c_"; ""]]
let () = register { key = "group_copy"; native = Sop.Nodes.Group_copy.factory; inputs; cases; ulps = 4;
  bench = Some bench }
