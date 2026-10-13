(* sop/groups_from_name: one geometry input (pending draft). *)
open Port_gate
open Rdk
(* Text attributes "name" and "text" on points, vertices and primitives: valid, invalid, empty,
   digit-leading and repeated names, so the default cook succeeds and every branch is reached. *)
let with_names geometry =
  List.fold_left (fun geometry owner ->
    let n = match owner with Attribute.Point -> Geometry.point_count geometry
      | Vertex -> Geometry.vertex_count geometry | _ -> Geometry.primitive_count geometry in
    let names = [|"a"; "b"; "dest_a"; "bad name"; ""; "1x"; "\195\169"; "b"|] in
    let add name geometry = Geometry.with_attribute
      (Attribute.create_owned ~owner ~name
        (Attribute.Text (Array.init n (fun i -> names.(i mod Array.length names)))) |> Rdk_test_support.get_string_ok)
      geometry |> Rdk_test_support.get_string_ok in
    geometry |> add "name" |> add "text")
    geometry [Attribute.Point; Attribute.Vertex; Attribute.Primitive]
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
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:100 ~rows:100 ~size:8. () |> Rdk_test_support.get_ok in
  [with_names g], ["attribute", P.Text_value "name"]
let () = register { key = "groups_from_name"; native = Sop.Nodes.Groups_from_name.factory; inputs = List.map (fun (label, gs) -> label, List.map with_names gs) standard_inputs;
  cases; ulps = 4; bench = Some bench }
