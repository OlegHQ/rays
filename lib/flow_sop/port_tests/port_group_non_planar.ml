(* sop/group_non_planar: one geometry input (pending draft). *)
open Port_gate
module P = Param
let t name v = name, P.Text_value v
let c name v = name, P.Choice_value v
let cases =
  ["defaults", [];
   "tolerance0", ["tolerance", P.Float_value 0.];
   "tolerance_large", ["tolerance", P.Float_value 100.];
   "tolerance_small", ["tolerance", P.Float_value 1e-12];
   "named", [t "name" "a"; c "merge" "Union"];
   "named_ordered", [t "name" "dest_a"; c "merge" "Exclusive or"];
   "base", [t "base" " a "; "tolerance", P.Float_value 0.];
   "base_missing", [t "base" "zzz"];
   "blank_name", [t "name" " "]]
  @ List.map (fun merge -> "merge_" ^ merge, [c "merge" merge; t "name" "a"])
      ["Replace"; "Union"; "Intersection"; "Subtract"; "Exclusive or"]
let bench () = [Rdk_test_support.get_ok (Rdk.Plane_generators.grid ~connectivity:Rdk.Plane_generators.Grid_quads
    ~columns:707 ~rows:707 ~size:8. ())], []
let () = register { key = "group_non_planar"; native = Sop.Nodes.Group_non_planar.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
