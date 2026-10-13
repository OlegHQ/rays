(* sop/spiral: zero-input generator (pending draft). Both extents, all four radius models, ramps, direction,
   divisions, uniform and equal-arc angle, several spirals, orientations, frames, quaternions, distances,
   overflow and refusal paths. *)
open Port_gate
module P = Param
let ch name v = name, P.Choice_value v
let fl name v = name, P.Float_value v
let it name v = name, P.Int_value v
let tx name v = name, P.Text_value v
let bl name v = name, P.Bool_value v
let rot = [fl "rotation_x" 0.3; fl "rotation_y" (-0.7); fl "rotation_z" 1.1]
let attributes = [tx "angle_attribute" "angle"; tx "x_axis_attribute" "xa"; tx "y_axis_attribute" "ya";
  tx "tangent_attribute" "tan"; tx "orient_attribute" "orient"; tx "distance_attribute" "dist"]
let ramps = [tx "height_ramp" "0:0.5, 0.3:1.5, 1:1"; tx "radius_ramp" "0:1, 0.5:2, 0.8:0.5, 1:1.5"]
let radius_modes = [
  "ac", [ch "radius_mode" "Archimedean change"; fl "radius_change" 0.4];
  "ae", [ch "radius_mode" "Archimedean end"; fl "start_radius" 0.5; fl "end_radius" 2.];
  "lc", [ch "radius_mode" "Logarithmic change"; fl "logarithmic_scale" 1.3];
  "le", [ch "radius_mode" "Logarithmic end"; fl "start_radius" 0.5; fl "end_radius" 2.]]
let cases =
  List.concat_map (fun (label, radius) -> List.concat_map (fun (u_label, u) -> [
      Printf.sprintf "%s/%s" label u_label, radius @ u @ [it "divisions" 10];
      Printf.sprintf "%s/%s/ramps" label u_label, radius @ u @ ramps @ [it "divisions" 10];
      Printf.sprintf "%s/%s/attributes" label u_label, radius @ u @ attributes @ [it "divisions" 7; it "spiral_count" 3];
      Printf.sprintf "%s/%s/rotated_attributes" label u_label, radius @ u @ attributes @ rot @ [ch "orientation" "Z axis"; fl "center_x" 1.5]])
    ["uniform", [bl "uniform_angle" true]; "equal_arc", [bl "uniform_angle" false]]) radius_modes
  @ [ "default", [];
      "height_pitch", [ch "extent_mode" "Height and pitch"; fl "height" 3.; fl "pitch" 0.5];
      "height_pitch_negative", [ch "extent_mode" "Height and pitch"; fl "height" (-3.); fl "pitch" (-0.5)];
      "negative_height", [fl "height" (-2.)];
      "zero_height", [fl "height" 0.];
      "clockwise", [ch "direction" "Clockwise"; fl "start_angle" 1.2];
      "per_curve", [ch "divisions_mode" "Per curve"; it "divisions" 12];
      "per_curve_minimal", [ch "divisions_mode" "Per curve"; it "divisions" 1];
      "per_turn_fraction", [fl "turns" 0.7; it "divisions" 5];
      "spirals", [it "spiral_count" 5; it "divisions" 6];
      "radius_scale", [fl "radius_scale" 2.5; fl "uniform_scale" 1.5];
      "single_knot_height", [tx "height_ramp" "0.5:3"];
      "single_knot_radius", [tx "radius_ramp" "1:2"];
      "ramp_spaces", [tx "height_ramp" " 0 : 0 ,  1 : 2 "];
      "ramp_two_knots", [tx "height_ramp" "0:1,1:0"; tx "radius_ramp" "0:2,1:0.5"];
      "ramps_equal_arc", [bl "uniform_angle" false; tx "height_ramp" "0:1,0.25:0,0.75:2,1:1"; tx "radius_ramp" "0:1,0.25:2,0.75:1,1:1"; it "divisions" 9];
      "ramps_shared_break_equal_arc", [bl "uniform_angle" false; tx "height_ramp" "0:1,0.5:2,1:1"; tx "radius_ramp" "0:1,0.5:2,1:1"; it "divisions" 8];
      "equal_arc_zero_radius_start", [bl "uniform_angle" false; ch "radius_mode" "Archimedean end"; fl "start_radius" 0.; fl "end_radius" 2.];
      "equal_arc_per_curve", [bl "uniform_angle" false; ch "divisions_mode" "Per curve"; it "divisions" 17; ch "extent_mode" "Height and pitch"; fl "height" 4.; fl "pitch" 0.7];
      "orientation_x", [ch "orientation" "X axis"; tx "tangent_attribute" "t"] @ rot;
      "orientation_z", [ch "orientation" "Z axis"; tx "orient_attribute" "q"] @ rot;
      "axis_custom", [ch "orientation" "Custom axis"; fl "axis_x" 5.; fl "axis_y" 4.; fl "axis_z" 4.5; tx "x_axis_attribute" "xa"; tx "orient_attribute" "q"] @ rot;
      "axis_x", [ch "orientation" "Custom axis"; fl "axis_x" 1.; fl "axis_y" 0.; fl "axis_z" 0.; tx "orient_attribute" "q"];
    ]
  @ List.map (fun o -> "order_" ^ o, [ch "rotation_order" o; tx "tangent_attribute" "t"; it "divisions" 5] @ rot) ["XYZ"; "XZY"; "YXZ"; "YZX"; "ZXY"; "ZYX"]
  @ List.map (fun (label, rest) -> "frame_" ^ label, [it "divisions" 6; tx "x_axis_attribute" "xa"; tx "y_axis_attribute" "ya";
      tx "tangent_attribute" "tan"; tx "orient_attribute" "q"] @ rest)
      ["flat", [fl "height" 0.; fl "radius_change" 0.]; "tall", [fl "height" 20.; fl "turns" 0.2];
       "reverse", [ch "direction" "Clockwise"; fl "height" (-4.)];
       "all_branches", [fl "turns" 2.; fl "height" 1.5; ch "radius_mode" "Archimedean end"; fl "end_radius" 0.5]]
  @ ["attribute_names_trimmed", [tx "angle_attribute" " a "; tx "distance_attribute" " d "];
     "distance_long", [it "divisions" 512; fl "turns" 20.; tx "distance_attribute" "d"; it "spiral_count" 2];
     "distance_blocks", [ch "divisions_mode" "Per curve"; it "divisions" 9000; tx "distance_attribute" "d"; it "spiral_count" 2];
     "overflow_center", [fl "center_x" 1.7976931348623157e308; fl "start_radius" 1e308];
     "overflow_radius_scale", [fl "radius_scale" 1e300; fl "uniform_scale" 1e300; fl "start_radius" 10.];
     "overflow_height", [fl "height" 1e308; fl "uniform_scale" 10.];
     "invalid_turns_zero", [fl "turns" 0.];
     "invalid_pitch_zero", [ch "extent_mode" "Height and pitch"; fl "pitch" 0.];
     "invalid_turns_negative_pitch", [ch "extent_mode" "Height and pitch"; fl "height" 2.; fl "pitch" (-0.5)];
     "invalid_radius_negative", [fl "radius_change" (-2.)];
     "invalid_log_zero_start", [ch "radius_mode" "Logarithmic change"; fl "start_radius" 0.];
     "invalid_log_zero_scale", [ch "radius_mode" "Logarithmic change"; fl "logarithmic_scale" 0.];
     "invalid_log_end_zero", [ch "radius_mode" "Logarithmic end"; fl "end_radius" 0.];
     "invalid_log_overflow", [ch "radius_mode" "Logarithmic change"; fl "logarithmic_scale" 4.; fl "turns" 20.; fl "start_radius" 1e300];
     "invalid_ramp_start", [tx "height_ramp" "0.5:1,1:2"];
     "invalid_ramp_end", [tx "height_ramp" "0:1,0.5:2"];
     "invalid_ramp_order", [tx "radius_ramp" "0:1,0.6:2,0.5:1,1:1"];
     "invalid_ramp_shape", [tx "radius_ramp" "0:1,1"];
     "invalid_ramp_number", [tx "radius_ramp" "0:x,1:1"];
     "invalid_ramp_range", [tx "radius_ramp" "0:1,2:1"];
     "invalid_names_pole", [tx "angle_attribute" " P "];
     "invalid_names_repeat", [tx "angle_attribute" "a"; tx "distance_attribute" " a "];
     "invalid_custom_axis_zero", [ch "orientation" "Custom axis"; fl "axis_x" 0.; fl "axis_y" 0.; fl "axis_z" 0.];
     "invalid_uniform_scale_zero", [fl "uniform_scale" 0.];
     "huge_divisions", [it "divisions" 4611686018427387903; ch "divisions_mode" "Per curve"];
     "huge_spirals", [it "spiral_count" 4611686018427387903];
     "huge_turns_divisions", [fl "turns" 20.; it "divisions" 1000000000000000]]
let bench () = [], [ch "divisions_mode" "Per curve"; it "divisions" 500000; it "spiral_count" 2; fl "turns" 200.;
  tx "angle_attribute" "angle"; tx "distance_attribute" "dist"; tx "tangent_attribute" "tan"; tx "orient_attribute" "q"]
let () = register { key = "spiral"; native = Sop.Nodes.Spiral.factory; inputs = no_input; cases; ulps = 4; bench = Some bench }
