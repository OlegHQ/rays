(* sop/point_replicate: two geometry inputs, the second (custom shape) optional. Partial draft: the body is a
   stub, so the gate stops at the first oracle comparison (see the commit message). *)
open Port_gate
module P = Param
let ch name v = name, P.Choice_value v
let fl name v = name, P.Float_value v
let tx name v = name, P.Text_value v
let bl name v = name, P.Bool_value v
let cases =
  List.map (fun shape -> "shape_" ^ shape, [ch "shape" shape; fl "points_per_point" 3.]) ["Point"; "Box"; "Sphere"; "Disk"; "Line"]
  @ ["keep_input", [bl "keep_input" true; fl "points_per_point" 2.];
     "quasi", [bl "quasi_stratified" true; fl "points_per_point" 4.];
     "noise", [bl "use_noise" true; fl "points_per_point" 3.];
     "velocity", [ch "velocity_stretch" "Scaled velocity"; fl "radial_velocity" 0.5];
     "transform_attributes", [tx "transform_attributes" "P N"];
     "group", [tx "group" "a"; tx "generated_group" "gen"]]
let () = register { key = "point_replicate"; native = Sop.Nodes.Point_replicate.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = None }
