(* sop/attribute_fade: three geometry inputs, the last two optional (pending draft). The gate cooks at
   frame 0, so the elapsed time is steered by Frame offset and the start attribute "t0" (frame - start). *)
open Rdk
open Port_gate
module P = Param
let tx name v = name, P.Text_value v
let fl name v = name, P.Float_value v
let bl name v = name, P.Bool_value v
let with_attr name storage geometry =
  Rdk_test_support.get_string_ok (Geometry.with_attribute (Rdk_test_support.get_string_ok
    (Attribute.create_owned ~owner:Attribute.Point ~name storage)) geometry)
let prepared geometry =
  let n = Geometry.point_count geometry in
  geometry
  |> with_attr "t0" (Attribute.Float (Array.init n (fun i -> -. float (i mod 9) *. 0.7)))
  |> with_attr "hold_s" (Attribute.Float (Array.init n (fun i -> float (i mod 4) *. 0.5)))
  |> with_attr "negative" (Attribute.Float (Array.init n (fun i -> if i mod 3 = 0 then -1. else 1.)))
  |> with_attr "ti" (Attribute.Int (Array.init n (fun i -> - (i mod 5))))
  |> with_attr "fade" (Attribute.Float (Array.init n (fun i -> 0.25 +. float (i mod 6) *. 0.125)))
  |> with_attr "text_attr" (Attribute.Text (Array.make n "x"))
let fixtures = [
  "empty", prepared (points 0); "single", prepared (points 1);
  "grid", prepared (fixture_groups (grid ()));
  "mixed", prepared (fixture_groups (polygon_polyline ()))]
(* input, start source, hold source *)
let inputs = List.concat_map (fun (label, g) ->
  let other = prepared (points (Geometry.point_count g)) |> with_attr "t0" (Attribute.Float
    (Array.init (Geometry.point_count g) (fun i -> float (i mod 3)))) in
  [label, [g]; label ^ "+start", [g; other]; label ^ "+start+hold", [g; other; other]]) fixtures
(* Dropped: a start/hold source with a different point count (native refuses). The gate's cache check
   needs the default cook to succeed on every fixture, and that refusal is not parameter dependent. *)
let cases =
  ["frame_before", [fl "frame_offset" 1.];
   "in", [fl "frame_offset" (-1.)];
   "in_edge", [fl "frame_offset" (-2.)];
   "hold", [fl "frame_offset" (-2.5); fl "fade_hold" 1.];
   "hold_edge", [fl "frame_offset" (-3.); fl "fade_hold" 1.];
   "out", [fl "frame_offset" (-4.); fl "fade_hold" 1.];
   "out_edge", [fl "frame_offset" (-5.); fl "fade_hold" 1.];
   "after", [fl "frame_offset" (-6.); fl "fade_hold" 1.];
   "start_attribute", [tx "start_attribute" " t0 "; fl "frame_offset" (-1.)];
   "start_int", [tx "start_attribute" "ti"; fl "frame_offset" (-3.)];
   "start_missing", [tx "start_attribute" "nothing"; fl "frame_offset" (-1.)];
   "start_text", [tx "start_attribute" "text_attr"];
   "retime", [tx "start_attribute" "t0"; fl "start_retime_offset" 2.; fl "start_retime_scale" 0.5; fl "frame_offset" (-2.)];
   "retime_negative", [tx "start_attribute" "t0"; fl "start_retime_scale" (-1.5); fl "frame_offset" (-4.)];
   "hold_scale", [tx "hold_scale_attribute" "hold_s"; fl "fade_hold" 2.; fl "frame_offset" (-4.)];
   "hold_scale_negative", [tx "hold_scale_attribute" "negative"; fl "fade_hold" 2.];
   "hold_scale_negative_zero_hold", [tx "hold_scale_attribute" "negative"; fl "fade_hold" 0.];
   "hold_scale_missing", [tx "hold_scale_attribute" "nothing"; fl "fade_hold" 1.; fl "frame_offset" (-3.)];
   "hold_scale_text", [tx "hold_scale_attribute" "text_attr"];
   "no_fade_in", [fl "fade_in" 0.; fl "frame_offset" (-0.5); fl "fade_hold" 1.];
   "no_fade_out", [fl "fade_out" 0.; fl "frame_offset" (-5.)];
   "no_durations", [fl "fade_in" 0.; fl "fade_out" 0.; fl "frame_offset" (-1.)];
   "ramps", [tx "fade_in_ramp" "0:0,0.3:0.8,1:1"; tx "fade_out_ramp" "0:1,0.6:0.1,1:0.5"; fl "frame_offset" (-1.3)];
   "ramps_out", [tx "fade_in_ramp" "0:0,0.3:0.8,1:1"; tx "fade_out_ramp" "0:1,0.6:0.1,1:0.5"; fl "frame_offset" (-3.1)];
   "blank_ramps", [tx "fade_in_ramp" ""; tx "fade_out_ramp" " "; fl "frame_offset" (-1.)];
   "ramp_bad_start", [tx "fade_in_ramp" "0.5:0,1:1"];
   "ramp_bad_end", [tx "fade_out_ramp" "0:1,0.5:0"];
   "ramp_single", [tx "fade_in_ramp" "0:1"];
   "ramp_garbage", [tx "fade_out_ramp" "0:x,1:0"];
   "attribute", [tx "fade_attribute" "dissolve"; fl "frame_offset" (-1.)];
   "attribute_existing", [tx "fade_attribute" "fade"; fl "frame_offset" (-1.)];
   "attribute_existing_unchanged", [tx "fade_attribute" "fade"; fl "frame_offset" (-100.); fl "fade_hold" 100.; fl "fade_out" 0.];
   "attribute_non_float", [tx "fade_attribute" "ti"];
   "attribute_P", [tx "fade_attribute" "P"];
   "attribute_blank", [tx "fade_attribute" " "];
   "group", [tx "group" "a"; fl "frame_offset" (-1.)];
   "group_attribute", [tx "group" " dest_a "; tx "start_attribute" "t0"];
   "group_missing", [tx "group" "nope"];
   "visualize", [bl "visualize" true; fl "frame_offset" (-1.)];
   "visualize_group", [bl "visualize" true; tx "group" "a"; tx "start_attribute" "t0"];
   "visualize_Cd", [bl "visualize" true; tx "fade_attribute" "Cd"];
   "visualize_unchanged", [bl "visualize" true; tx "fade_attribute" "fade"; fl "frame_offset" (-100.); fl "fade_hold" 100.; fl "fade_out" 0.]]
let bench () =
  let n = 1_000_000 in
  let g = points n |> with_attr "t0" (Attribute.Float (Array.init n (fun i -> -. float (i mod 9) *. 0.7))) in
  [g], [tx "start_attribute" "t0"; fl "frame_offset" (-1.)]
let () = register { key = "attribute_fade"; native = Sop.Nodes.Attribute_fade.factory; inputs;
  cases; ulps = 4; bench = Some bench }
