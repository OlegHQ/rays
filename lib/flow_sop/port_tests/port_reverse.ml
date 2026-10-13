(* sop/reverse: one geometry input (pending draft). *)
open Rdk
open Port_gate
module P = Param
let fields group operation shift =
  ["group", P.Text_value group; "operation", P.Choice_value operation; "shift", P.Int_value shift]
let cases =
  List.concat_map (fun operation -> List.concat_map (fun group ->
    List.map (fun shift -> Printf.sprintf "%s/%S/%d" operation group shift, fields group operation shift)
      [1; 0; -1; 2; 3; -32; 32])
    [""; "a"; "dest_a"; "old_x"; " a "]) ["Reverse vertices"; "Shift vertices"]
  @ ["missing", fields "nope" "Reverse vertices" 1; "literal", fields "literal *?[]^\\" "Shift vertices" 1;
     "unicode", fields "\195\169\231\140\171" "Reverse vertices" 1]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  [g], fields "" "Reverse vertices" 1
let () = register { key = "reverse"; native = Sop.Nodes.Reverse.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
