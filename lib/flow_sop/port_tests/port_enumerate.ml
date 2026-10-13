(* sop/enumerate: one geometry input (pending draft). Fixtures: ordered/reversed groups "a",
   "dest_a", "old_x" on every owner; "integer" is a two-valued int attribute (two pieces),
   "text" a one-valued text attribute, "float" for wrong-storage errors. *)
open Rdk
open Port_gate
module P = Param
let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value
let num name value = name, P.Int_value value
let owners = ["Point"; "Vertex"; "Primitive"]
(* Pieces by "tag" (five values) with a few int/text repeats on the grid and the mixed fixture. *)
let with_tags geometry =
  List.fold_left (fun geometry owner ->
    let n = match owner with Attribute.Point -> Geometry.point_count geometry
      | Vertex -> Geometry.vertex_count geometry | Primitive -> Geometry.primitive_count geometry | Detail -> 1 in
    let put name storage geometry = Geometry.with_attribute
      (Attribute.create_owned ~owner ~name storage |> Rdk_test_support.get_string_ok) geometry
      |> Rdk_test_support.get_string_ok in
    geometry |> put "kind" (Attribute.Int (Array.init n (fun i -> (i * 7 + 3) mod 5 - 2)))
    |> put "label" (Attribute.Text (Array.init n (fun i -> Printf.sprintf "L%d" ((i * 5 + 1) mod 4)))))
    geometry [Attribute.Point; Vertex; Primitive]
let inputs = List.map (fun (l, g) -> l, [g]) [
  "empty", with_tags (fixture_groups (points 0)); "single", with_tags (fixture_groups (points 1));
  "grid4225", with_tags (fixture_groups (grid ()));
  "mixed", fixture_attributes (with_tags (fixture_groups (polygon_polyline ())))]
let cases =
  List.concat_map (fun owner ->
    let o = choice "owner" owner in
    [ "default/" ^ owner, [o];
      "name/" ^ owner, [o; text "name" "serial"];
      "start_step/" ^ owner, [o; num "start" (-7); num "step" 3];
      "zero_step/" ^ owner, [o; num "step" 0];
      "neg_step/" ^ owner, [o; num "start" 10; num "step" (-2)];
      "group/" ^ owner, [o; text "group" "a"];
      "group_ordered/" ^ owner, [o; text "group" "dest_a"; num "start" 5];
      "group_trimmed/" ^ owner, [o; text "group" " old_x "];
      "group_missing/" ^ owner, [o; text "group" "nope"];
      "text/" ^ owner, [o; choice "storage" "Text"];
      "text_prefix/" ^ owner, [o; choice "storage" "Text"; text "prefix" "\195\169_"; num "start" (-3)];
      "text_group/" ^ owner, [o; choice "storage" "Text"; text "group" "a"; text "name" "text"];
      "existing_int/" ^ owner, [o; text "name" "integer"; text "group" "a"];
      "existing_int_all/" ^ owner, [o; text "name" "integer"];
      "existing_text/" ^ owner, [o; choice "storage" "Text"; text "name" "text"; text "group" "dest_a"];
      "wrong_float/" ^ owner, [o; text "name" "float"];
      "wrong_text_as_int/" ^ owner, [o; text "name" "text"];
      "wrong_int_as_text/" ^ owner, [o; choice "storage" "Text"; text "name" "integer"];
      "wrong_vec3/" ^ owner, [o; text "name" "vec3"];
      "blank_group/" ^ owner, [o; text "group" "  "] ]
    @ List.concat_map (fun (piece, plabel) -> List.concat_map (fun mode ->
        [ Printf.sprintf "piece/%s/%s/%s" owner plabel mode,
            [o; text "piece_attribute" piece; choice "mode" mode];
          Printf.sprintf "piece_group/%s/%s/%s" owner plabel mode,
            [o; text "piece_attribute" piece; choice "mode" mode; text "group" "a"; num "start" 2; num "step" (-3)];
          Printf.sprintf "piece_text/%s/%s/%s" owner plabel mode,
            [o; text "piece_attribute" piece; choice "mode" mode; choice "storage" "Text"; text "group" "dest_a"] ])
        ["Elements within pieces"; "Pieces"])
      ["kind", "int"; "label", "text"; "integer", "two"; "text", "one"; " kind ", "trimmed";
       "nope", "missing"; "float", "float"; "vec3", "vec3"; "P", "P"; "  ", "blank"])
    owners
  @ [ "blank_name", [text "name" "  "]; "P_point", [text "name" "P"];
      "P_vertex", [choice "owner" "Vertex"; text "name" "P"];
      "spaced_name", [text "name" " id "];
      "huge_start", [num "start" max_int]; "huge_start_negative_step", [num "start" min_int; num "step" (-1)];
      "huge_start_single", [num "start" max_int; text "group" "a"];
      "big_step_window", [num "start" (max_int - 8); num "step" 2; text "group" "a"] ]
let bench () =
  let n = 1_000_000 in
  let g = Geometry.with_attribute (Attribute.create_owned ~owner:Attribute.Point ~name:"kind"
    (Attribute.Int (Array.init n (fun i -> i mod 1000))) |> Rdk_test_support.get_string_ok) (points n)
    |> Rdk_test_support.get_string_ok in
  [g], [text "piece_attribute" "kind"; choice "mode" "Elements within pieces"]
let () = register { key = "enumerate"; native = Sop.Nodes.Enumerate.factory; inputs; cases; ulps = 4;
  bench = Some bench }
