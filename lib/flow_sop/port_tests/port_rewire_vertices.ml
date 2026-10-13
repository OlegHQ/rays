(* sop/rewire_vertices: one geometry input (pending draft). Custom fixtures carry integer "target"
   attributes on points (chains, a cycle, out-of-range values), vertices and primitives. *)
open Rdk
open Port_gate
module P = Param
let tx name v = name, P.Text_value v
let ch name v = name, P.Choice_value v
let bl name v = name, P.Bool_value v
let with_int owner name f geometry =
  let n = match owner with Attribute.Point -> Geometry.point_count geometry | Vertex -> Geometry.vertex_count geometry
    | Primitive -> Geometry.primitive_count geometry | Detail -> 1 in
  Rdk_test_support.get_string_ok (Geometry.with_attribute (Rdk_test_support.get_string_ok
    (Attribute.create_owned ~owner ~name (Attribute.Int (Array.init n f)))) geometry)
let prepared geometry =
  let points = Geometry.point_count geometry in
  geometry
  |> with_int Attribute.Point "target" (fun i -> match i mod 7 with 0 -> (i + 1) mod points | 1 -> (i + 1) mod points
       | 2 -> (i + points - 2) mod points | 3 -> i | 4 -> -1 | 5 -> points + 3 | _ -> (i * 5 + 1) mod points)
  |> with_int Attribute.Vertex "target" (fun i -> (i * 3 + 1) mod (max 1 points))
  |> with_int Attribute.Primitive "target" (fun i -> (i * 2 + 1) mod (max 1 points))
  |> with_int Attribute.Detail "target" (fun _ -> 0)
let inputs = List.map (fun (label, g) -> label, [prepared g]) [
  "empty", fixture_groups (points 0); "single", fixture_groups (points 1);
  "grid4225", fixture_groups (grid ());
  "mixed", fixture_attributes (fixture_groups (polygon_polyline ()))]
let cases =
  List.concat_map (fun owner ->
    List.map (fun (label, changes) -> Printf.sprintf "%s/%s" label owner, ch "owner" owner :: changes)
      (["default", [];
        "keep_target", [bl "delete_target_attribute" false];
        "keep_unused", [bl "keep_unused_points" true];
        "original", [tx "original_point_attribute" " orig "];
        "original_N", [tx "original_point_attribute" "N"];
        "original_existing", [tx "original_point_attribute" "integer"];
        "blank_target", [tx "target_attribute" " "];
        "missing_target", [tx "target_attribute" "nope"];
        "wrong_type", [tx "target_attribute" "float"];
        "wrong_type_text", [tx "target_attribute" "text"];
        "detail_name", [tx "target_attribute" "integer"; bl "delete_target_attribute" false];
        "all_options", [bl "keep_unused_points" true; bl "delete_target_attribute" false; tx "original_point_attribute" "was"]]
       @ List.map (fun so -> Printf.sprintf "select_%s" so, [ch "selection_owner" so; tx "selection" "a"])
           ["Point"; "Vertex"; "Primitive"; "Edge"]
       @ List.map (fun so -> Printf.sprintf "select_ordered_%s" so, [ch "selection_owner" so; tx "selection" "dest_a"; bl "keep_unused_points" true])
           ["Point"; "Vertex"; "Primitive"; "Edge"]
       @ ["select_missing", [tx "selection" "nope"];
          "select_blank_group", [tx "selection" "  "];
          "select_trimmed", [ch "selection_owner" "Point"; tx "selection" " a "]]
       @ (if owner = "Point" then
         ["recursive", [bl "recursive" true];
          "recursive_keep", [bl "recursive" true; bl "keep_unused_points" true; bl "delete_target_attribute" false];
          "recursive_selected", [bl "recursive" true; ch "selection_owner" "Point"; tx "selection" "a"]]
       else ["recursive_refused", [bl "recursive" true]]))) ["Point"; "Vertex"; "Primitive"]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  let n = Geometry.point_count g in
  [with_int Attribute.Point "target" (fun i -> if i mod 3 = 0 then (i + 1) mod n else i) g],
  [ch "owner" "Point"; tx "target_attribute" "target"]
let () = register { key = "rewire_vertices"; native = Sop.Nodes.Rewire_vertices.factory; inputs;
  cases; ulps = 4; bench = Some bench }
