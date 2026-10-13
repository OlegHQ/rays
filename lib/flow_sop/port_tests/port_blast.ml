(* sop/blast: one geometry input (pending draft). *)
open Rdk
open Port_gate
module P = Param
let fields owner group selected compact policy =
  ["owner", P.Choice_value owner; "group", P.Text_value group; "selected", P.Bool_value selected;
   "compact_points", P.Bool_value compact; "policy", P.Choice_value policy]
let policies = ["Destroy touched primitives"; "Heal primitives"]
let cases =
  List.concat_map (fun owner -> List.concat_map (fun selected -> List.concat_map (fun compact ->
    List.map (fun policy -> Printf.sprintf "%s/%b/%b/%s" owner selected compact policy,
      fields owner "a" selected compact policy) policies) [false; true]) [true; false])
    ["Points"; "Vertices"; "Primitives"]
  @ List.concat_map (fun group -> List.map (fun owner -> Printf.sprintf "%S/%s" group owner,
      fields owner group true false "Heal primitives") ["Points"; "Vertices"; "Primitives"])
    ["group"; "dest_a"; "old_x"; "literal *?[]^\\"; "\195\169\231\140\171"; " a "]
(* The default group name must exist on every owner, or the cache check never cooks. *)
let with_default_group geometry =
  List.fold_left (fun geometry owner ->
    let count = match owner with Group.Point -> Geometry.point_count geometry
      | Vertex -> Geometry.vertex_count geometry | Primitive -> Geometry.primitive_count geometry in
    Geometry.with_group (Group.init ~owner ~name:"group" count (fun i -> i mod 2 = 1)) geometry
    |> Rdk_test_support.get_string_ok) geometry [Group.Point; Vertex; Primitive]
let inputs = List.map (fun (label, gs) -> label, List.map with_default_group gs) standard_inputs
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  let n = Geometry.point_count g in
  let g = Geometry.with_group (Group.init ~owner:Group.Point ~name:"group" n (fun i -> i mod 7 = 0)) g
    |> Rdk_test_support.get_string_ok in
  [g], fields "Points" "group" true true "Heal primitives"
let () = register { key = "blast"; native = Sop.Nodes.Blast.factory; inputs;
  cases; ulps = 4; bench = Some bench }
