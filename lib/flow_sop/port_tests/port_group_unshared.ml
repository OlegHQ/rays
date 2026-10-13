(* sop/group_unshared: one geometry input. *)
open Rdk
open Port_gate
module P = Param
let fields owner name merge = ["owner", P.Choice_value owner; "name", P.Text_value name; "merge", P.Choice_value merge]
let merges = ["Replace"; "Union"; "Intersection"; "Subtract"; "Exclusive or"]
let cases =
  List.concat_map (fun owner -> List.map (fun merge ->
    Printf.sprintf "%s/%s" owner merge, fields owner "unshared" merge) merges) ["Points"; "Vertices"; "Primitives"; "Edges"]
  @ List.concat_map (fun owner -> List.map (fun merge ->
    Printf.sprintf "existing %s/%s" owner merge, fields owner "a" merge) merges) ["Points"; "Primitives"; "Edges"]
  @ ["blank", fields "Edges" "  " "Replace"]
let bench () =
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  [grid], fields "Primitives" "unshared" "Replace"
let () = register { key = "group_unshared"; native = Sop.Nodes.Group_unshared.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
