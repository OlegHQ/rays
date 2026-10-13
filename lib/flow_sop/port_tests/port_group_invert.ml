(* sop/group_invert: one geometry input (pending draft). *)
open Rdk
open Port_gate
module P = Param
let fields owner pattern new_name conflict =
  ["owner", P.Choice_value owner; "pattern", P.Text_value pattern; "new_name", P.Text_value new_name;
   "conflict", P.Choice_value conflict]
let cases =
  List.concat_map (fun owner -> List.map (fun conflict ->
    Printf.sprintf "%s/%s" owner conflict, fields owner "*" "dest_*" conflict)
    ["Skip"; "Error"; "Overwrite"; "Union"]) ["Any"; "Points"; "Vertices"; "Primitives"; "Edges"]
  @ List.mapi (fun i (pattern, new_name) -> Printf.sprintf "pattern%d" i, fields "Any" pattern new_name "Overwrite")
    ["*", ""; "unmatched", ""; "a dest_a", ""; "* ^old*", ""; "literal\\ \\*\\?\\[\\]\\^\\\\", "";
     "\195\169*", "\231\140\171*"; "a", " renamed "; "[", ""; "", ""; "unmatched", "*"]
let bench () =
  let g = Geometry.with_group (Group.init ~owner:Group.Point ~name:"selected" 1_000_000 (fun i -> i mod 2 = 0))
    (points 1_000_000) |> Rdk_test_support.get_string_ok in
  [g], fields "Points" "*" "" "Overwrite"
let () = register { key = "group_invert"; native = Sop.Nodes.Group_invert.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
