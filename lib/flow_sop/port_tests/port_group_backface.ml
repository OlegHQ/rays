(* sop/group_backface: one geometry input (pending draft). *)
open Port_gate
module P = Param
let t name v = name, P.Text_value v
let c name v = name, P.Choice_value v
let f name v = name, P.Float_value v
let cases =
  ["defaults", [];
   "below", [f "viewpoint_z" (-10.)];
   "side", [f "viewpoint_x" 50.; f "viewpoint_z" 0.];
   "on_plane", [f "viewpoint_z" 0.; f "viewpoint_x" 0.5];
   "far", [f "viewpoint_z" 1e300];
   "named", [t "name" "a"; c "merge" "Union"];
   "named_ordered", [t "name" "dest_a"; c "merge" "Exclusive or"];
   "base", [t "base" " a "; f "viewpoint_z" (-10.)];
   "base_missing", [t "base" "zzz"];
   "blank_name", [t "name" " "]]
  @ List.map (fun merge -> "merge_" ^ merge, [c "merge" merge; t "name" "a"; f "viewpoint_z" (-3.)])
      ["Replace"; "Union"; "Intersection"; "Subtract"; "Exclusive or"]
let bench () = [Rdk_test_support.get_ok (Rdk.Plane_generators.grid ~connectivity:Rdk.Plane_generators.Grid_quads
    ~columns:707 ~rows:707 ~size:8. ())], ["viewpoint_z", P.Float_value (-10.)]
let () = register { key = "group_backface"; native = Sop.Nodes.Group_backface.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
