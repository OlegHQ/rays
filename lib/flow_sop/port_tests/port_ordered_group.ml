(* sop/ordered_group: one geometry input (pending draft). *)
open Port_gate
module P = Param
let cases =
  List.concat_map (fun owner ->
    List.map (fun (label, changes) -> Printf.sprintf "%s/%s" label owner, ("owner", P.Choice_value owner) :: changes)
      ["default", [];
       "order", ["elements", P.Text_value "2 1 0"];
       "separators", ["elements", P.Text_value " 3,1\t0\n2 "];
       "empty", ["elements", P.Text_value ""];
       "out_of_bounds", ["elements", P.Text_value "0 99999"];
       "duplicate", ["elements", P.Text_value "0 0"];
       "named_existing", ["name", P.Text_value "a"; "elements", P.Text_value "0"];
       "blank_name", ["name", P.Text_value " "];
       "negative", ["elements", P.Text_value "-1"];
       "not_an_integer", ["elements", P.Text_value "x"]])
    ["Points"; "Vertices"; "Primitives"]
(* The empty fixture is dropped: the default element "0" is out of bounds there on both sides, and the
   gate's cache check needs a defaults cook that succeeds (errors are never cached). The empty list on
   a non-empty geometry and the out-of-bounds refusal stay covered by the cases. *)
let bench () = [points 1_000_000], ["elements", P.Text_value (String.concat " " (List.init 1000 string_of_int))]
let () = register { key = "ordered_group"; native = Sop.Nodes.Ordered_group.factory; inputs = List.filter (fun (label, _) -> label <> "empty") standard_inputs;
  cases; ulps = 4; bench = Some bench }
