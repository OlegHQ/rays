(* sop/group_edge_depth: one geometry input. *)
open Rdk
open Port_gate
module P = Param
let fields point_group name depth merge =
  ["point_group", P.Text_value point_group; "name", P.Text_value name; "depth", P.Int_value depth;
   "merge", P.Choice_value merge]
let merges = ["Replace"; "Union"; "Intersection"; "Subtract"; "Exclusive or"]
let cases =
  List.concat_map (fun depth -> List.map (fun merge ->
    Printf.sprintf "depth%d/%s" depth merge, fields "a" "depth_out" depth merge) merges) [0; 1; 2; 7]
  @ List.map (fun merge -> "existing " ^ merge, fields "a" "dest_a" 2 merge) merges
  @ List.map (fun merge -> "self " ^ merge, fields "a" "a" 1 merge) merges
  @ ["other seed", fields "old_x" "depth" 3 "Replace"; "missing", fields "nope" "depth" 1 "Replace";
     "blank seed", fields " " "depth" 1 "Replace"; "blank name", fields "a" " " 1 "Replace"]
let bench () =
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  let seed = Group.init ~owner:Group.Point ~name:"seed" (Geometry.point_count grid) (fun i -> i mod 5000 = 0) in
  [Geometry.with_group seed grid |> Rdk_test_support.get_string_ok], fields "seed" "depth" 3 "Replace"
(* The default seed group "seed" must exist so that the default case cooks. *)
let with_seed geometry =
  let seed = Group.init ~owner:Group.Point ~name:"seed" (Geometry.point_count geometry) (fun i -> i mod 3 = 0) in
  Geometry.with_group seed geometry |> Rdk_test_support.get_string_ok
let inputs = List.map (fun (label, geometries) -> label, List.map with_seed geometries) standard_inputs
let () = register { key = "group_edge_depth"; native = Sop.Nodes.Group_edge_depth.factory; inputs;
  cases; ulps = 4; bench = Some bench }
