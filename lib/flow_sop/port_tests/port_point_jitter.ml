(* sop/point_jitter: one geometry input (pending draft nodes/point_jitter.pending). *)
open Port_gate
module P = Param
let ch name value = name, P.Choice_value value
let it name n = name, P.Int_value n
let fl name x = name, P.Float_value x
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let axis (x, y, z) = [fl "axis_x" x; fl "axis_y" y; fl "axis_z" z]
let cases =
  [ "defaults", [];
    "scale 0", [fl "scale" 0.];
    "axis 0 0 0", axis (0., 0., 0.);
    "group empty", [tx "group" "empty"];
    "all fields", [tx "group" " selected "; tx "mask_attribute" " mask ";
      tx "id_attribute" " stable_id "; bo "use_point_scale" true]
      @ axis (0.25, 1.5, 0.75) @ [fl "scale" 2.75];
    "id missing, min seed", [tx "id_attribute" "missing"; it "seed" min_int];
    "id P", [tx "id_attribute" " P "];
    "seed Auto 42", [ch "seed_mode" "Auto"; it "seed" 42];
    "whitespace mask and id", [tx "mask_attribute" " \t\n "; tx "id_attribute" " \t "] ]
let bench () = [points 1_000_000], []
let () = register { key = "point_jitter"; native = Sop.Nodes.Point_jitter.factory;
  inputs = standard_inputs; cases; ulps = 4; bench = Some bench }
