(* sop/circle: zero-input generator (pending draft nodes/circle.pending). *)
open Port_gate
module P = Param
let ch name value = name, P.Choice_value value
let it name n = name, P.Int_value n
let fl name x = name, P.Float_value x
let bo name b = name, P.Bool_value b
let xyz prefix (x, y, z) = [fl (prefix ^ "_x") x; fl (prefix ^ "_y") y; fl (prefix ^ "_z") z]
let custom = xyz "horizontal" (0.25, -0.5, 0.75) @ xyz "vertical" (0.75, 0.5, -0.25)
let arcs = ["Closed"; "Open arc"; "Chord closed"; "Sliced"]
let orientations = ["XZ"; "XY"; "YZ"; "Custom axes"]
let sweep = [fl "start_angle" 0.5; fl "end_angle" 4.0]
let matrix = List.concat_map (fun arc -> List.concat_map (fun orientation ->
  List.map (fun reverse ->
    Printf.sprintf "%s/%s/reverse=%b" arc orientation reverse,
    [ch "arc" arc; ch "orientation" orientation; bo "reverse" reverse; it "segments" 7]
    @ sweep @ custom) [false; true]) orientations) arcs
let parameters = [
  "arc/open-zero-sweep", [ch "arc" "Open arc"; fl "start_angle" 1.0; fl "end_angle" 1.0];
  "segments/3", [it "segments" 3];
  "segments/17", [it "segments" 17; ch "arc" "Sliced"];
  "start_angle", [ch "arc" "Open arc"; fl "start_angle" (-2.0)];
  "end_angle", [ch "arc" "Chord closed"; fl "end_angle" (-5.0)];
  "radius/auto", [ch "radius_x_mode" "Auto"; ch "radius_y_mode" "Auto"; fl "radius" 2.5];
  "radius_x/explicit", [fl "radius_x" 2.0; ch "radius_y_mode" "Auto"; fl "radius" 0.5];
  "radius_y/explicit", [fl "radius_y" 3.0; ch "radius_x_mode" "Auto"; fl "radius" 0.5];
  "uniform_scale", [fl "uniform_scale" 2.0];
  "rotation", [fl "rotation" 0.37];
  "error/radius0-auto", [ch "radius_x_mode" "Auto"; fl "radius" 0.];
  "error/radius_x0", [fl "radius_x" 0.];
  "error/uniform_scale0", [fl "uniform_scale" 0.];
  "error/open-zero-sweep", [ch "arc" "Open arc"; fl "start_angle" 2.0; fl "end_angle" 2.0];
  "error/custom-zero-horizontal", [ch "orientation" "Custom axes"] @ xyz "horizontal" (0., 0., 0.);
  "error/custom-parallel", [ch "orientation" "Custom axes"] @ xyz "horizontal" (1., 0., 0.)
    @ xyz "vertical" (1., 0., 0.);
  "center", xyz "center" (-2.5, 1.25, -0.75);
]
let cases = ("defaults", []) :: parameters @ matrix
  @ [("custom-axes/center", [ch "orientation" "Custom axes"; it "segments" 9] @ custom
       @ xyz "center" (1.5, -2.0, 0.25))]
let bench () = [], [it "segments" 1_000_000]
let () = register { key = "circle"; native = Sop.Nodes.Circle.factory; inputs = no_input;
  cases; ulps = 4; bench = Some bench }
