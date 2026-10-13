(* sop/match_axis: one geometry input (pending draft nodes/match_axis.pending). *)
open Port_gate
module P = Param
let f name value = name, P.Float_value value
let v prefix x y z = [f (prefix ^ "_x") x; f (prefix ^ "_y") y; f (prefix ^ "_z") z]
let cases =
  List.map (fun name -> "set " ^ name, [f name 0.5])
    ["from_x"; "from_y"; "from_z"; "into_x"; "into_y"; "into_z"]
  @ [ "general", v "from" 0.2 0.9 (-0.4) @ v "into" (-0.7) 0.1 0.6;
      "x to z", v "from" 1. 0. 0. @ v "into" 0. 0. 1.;
      "antiparallel y", v "from" 0. 1. 0. @ v "into" 0. (-1.) 0.;
      "antiparallel x basis", v "from" 1. 0. 0. @ v "into" (-1.) 0. 0.;
      "antiparallel z basis", v "from" 0.5 0.5 0.1 @ v "into" (-0.5) (-0.5) (-0.1);
      "antiparallel y basis", v "from" 0.5 0.1 0.5 @ v "into" (-0.5) (-0.1) (-0.5);
      "parallel scaled", v "from" 0. 1. 0. @ v "into" 0. 0.5 0.;
      "zero from", v "from" 0. 0. 0.;
      "zero into", v "into" 0. 0. 0.;
      "tiny from", v "from" 1e-16 0. 0. ]
let bench () = [points 1_000_000], v "from" 0.2 0.9 (-0.4) @ v "into" (-0.7) 0.1 0.6
let () = register { key = "match_axis"; native = Sop.Nodes.Match_axis.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
