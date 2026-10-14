(* sop/group_combine: one geometry input (pending draft). *)
open Rdk
open Port_gate
module P = Param
let base owner = ["owner", P.Choice_value owner; "name", P.Text_value "out"]
let table rows = P.Text_value (String.concat "\n" (List.map (String.concat "\t") rows))
let cases =
  List.concat_map (fun owner ->
    ["default/" ^ owner, base owner;
     "defaults_name/" ^ owner, ["owner", P.Choice_value owner];
     "invert_base/" ^ owner, base owner @ ["base_inverted", P.Bool_value true];
     "pattern/" ^ owner, base owner @ ["base_pattern", P.Text_value "a dest_a"];
     "none/" ^ owner, base owner @ ["base_pattern", P.Text_value "zzz"];
     "existing/" ^ owner, ["owner", P.Choice_value owner; "name", P.Text_value "a"; "base_pattern", P.Text_value "dest_a"]]
    @ List.concat_map (fun op -> List.map (fun invert ->
      Printf.sprintf "%s/%s/%b" owner op invert,
      base owner @ ["base_pattern", P.Text_value "a";
        "steps", table [[op; "dest_a"; string_of_bool invert]; [op; "old_x"; "false"]]])
      [false; true]) ["replace"; "union"; "intersection"; "subtract"; "xor"])
    ["Points"; "Vertices"; "Primitives"; "Edges"]
  @ ["blank_name", ["owner", P.Choice_value "Points"; "name", P.Text_value "  "];
     "blank_base", base "Points" @ ["base_pattern", P.Text_value " "];
     "bad_glob", base "Points" @ ["base_pattern", P.Text_value "["];
     "blank_step", base "Points" @ ["steps", table [["union"; " "; "false"]]];
     "uppercase_tokens", base "Points" @ ["steps", table [[" UNION "; "dest_a"; " YES "]]]]
let bench () =
  let g = points 1_000_000 in
  let put name phase g = Geometry.with_group (Group.init ~owner:Group.Point ~name 1_000_000 (fun i -> i mod 3 = phase)) g
    |> Rdk_test_support.get_string_ok in
  [put "b" 1 (put "a" 0 g)], base "Points" @ ["base_pattern", P.Text_value "a"; "steps", table [["union"; "b"; "true"]]]
let () = register { key = "group_combine"; native = Sop.Nodes.Group_combine.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
