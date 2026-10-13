(* sop/point_velocity: input, optional previous, optional next (pending draft).
   Fixtures use 9 points. "pid" is a point int id (reversed or shifted in the samples so
   matching is non-trivial, with misses), "ptag" a text id, "dup" repeats an id. The
   grouped vec3 parameters (set, add) are changed by physical name. *)
open Rdk
open Port_gate
module P = Param
let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value
let num name value = name, P.Float_value value
let flag name value = name, P.Bool_value value
let cloud ?(count = 9) ?(sx = 1.) ?(sy = 0.5) ?(sz = -0.25) ?(bad = false) () =
  Kernel.generate_point_ranges count (fun ~first ~last ~x ~y ~z ->
    for i = first to last - 1 do
      x.(i) <- float i *. 0.375 +. sx; y.(i) <- float (i * i) *. 0.0625 +. sy;
      z.(i) <- (if bad && i = 2 then Float.nan else sin (float i) +. sz)
    done)
let with_attr owner name storage geometry =
  Geometry.with_attribute (Attribute.create_owned ~owner ~name storage |> Rdk_test_support.get_string_ok) geometry
  |> Rdk_test_support.get_string_ok
let ids ?(count = 9) ~order ~miss geometry =
  let key i = let j = order count i in if miss j then 1000 + j else j in
  geometry
  |> with_attr Attribute.Point "pid" (Attribute.Int (Array.init count key))
  |> with_attr Attribute.Point "ptag" (Attribute.Text (Array.init count (fun i -> Printf.sprintf "k%d" (key i))))
  |> with_attr Attribute.Point "dup" (Attribute.Int (Array.init count (fun i -> i / 2)))
  |> with_attr Attribute.Point "vec2" (Attribute.Float2 (Packed.Float2.of_owned
       ~x:(Array.make count 1.) ~y:(Array.make count 2.) |> Rdk_test_support.get_string_ok))
let identity _ i = i
let reversed count i = count - 1 - i
let velocities geometry =
  with_attr Attribute.Point "v" (Attribute.Float3 (Packed.Float3.of_owned ~x:(Array.init 9 float)
    ~y:(Array.init 9 (fun i -> -. float i)) ~z:(Array.init 9 (fun i -> float (i * 2))) |> Rdk_test_support.get_string_ok))
    geometry
let current () = fixture_attributes (fixture_groups (ids ~order:identity ~miss:(fun _ -> false) (cloud ())))
  |> velocities
let sample ?(count = 9) ?(order = identity) ?(miss = fun _ -> false) ?bad dx =
  ids ~count ~order ~miss (cloud ~count ~sx:(1. +. dx) ~sy:(0.5 -. dx *. 0.5) ?bad ())
(* The gate cooks every fixture at default parameters (backward difference, no matching), so
   every fixture carries a usable previous snapshot; failure scenarios live in the next
   snapshot or in an attribute. Dropped scenarios: a non-finite current P or previous
   snapshot (the default cook would fail), a previous snapshot of a different size (same),
   and every non-finite data scenario: Rays Lisp rejects non-finite array data with
   E_NONFINITE where native reports invalid_argument, a language-level code difference. *)
let inputs = [
  "previous_next", [current (); sample (-0.125); sample 0.25];
  "previous", [current (); sample (-0.125)];
  "reversed", [current (); sample ~order:reversed (-0.125); sample ~order:reversed 0.25];
  "missing_ids", [current (); sample ~miss:(fun j -> j mod 4 = 1) (-0.125); sample ~miss:(fun j -> j = 3) 0.25];
  "next_count_mismatch", [current (); sample (-0.125); sample ~count:11 0.25];
  "empty", [fixture_groups (points 0); fixture_groups (points 0); fixture_groups (points 0)];
  "single", [fixture_groups (points 1); points 1; points 1] ]
let compute extra = choice "initialization" "Compute from deformation" :: extra
let cases =
  List.concat_map (fun approximation ->
    let a = choice "approximation" approximation in
    [ "default/" ^ approximation, [a];
      "dt/" ^ approximation, [a; num "dt" 0.04];
      "add/" ^ approximation, [a; num "add_x" 0.5; num "add_y" (-1.25); num "add_z" 3.];
      "group/" ^ approximation, [a; text "group" "a"];
      "group_ordered/" ^ approximation, [a; text "group" "dest_a"; num "add_x" 1.];
      "group_missing/" ^ approximation, [a; text "group" "nope"];
      "name/" ^ approximation, [a; text "velocity_attribute" "w"];
      "existing/" ^ approximation, [a; text "velocity_attribute" "v"; text "group" "a"];
      "wrong_storage/" ^ approximation, [a; text "velocity_attribute" "vec2"];
      "match_int/" ^ approximation, [a; text "match_attribute" "pid"];
      "match_text/" ^ approximation, [a; text "match_attribute" " ptag "];
      "match_zero/" ^ approximation, [a; text "match_attribute" "pid"; choice "unmatched" "Zero"];
      "match_error/" ^ approximation, [a; text "match_attribute" "pid"; choice "unmatched" "Error"];
      "match_dup/" ^ approximation, [a; text "match_attribute" "dup"; choice "unmatched" "Zero"];
      "match_missing_attr/" ^ approximation, [a; text "match_attribute" "nope"];
      "match_wrong_type/" ^ approximation, [a; text "match_attribute" "vec2"];
      "match_mixed_type/" ^ approximation, [a; text "match_attribute" "integer"];
      "match_group/" ^ approximation, [a; text "match_attribute" "pid"; text "group" "dest_a"; choice "unmatched" "Zero"] ])
    ["Backward difference"; "Central difference"; "Forward difference"]
  @ [ "accel", [choice "approximation" "Central difference"; flag "compute_acceleration" true];
      "accel_name", [choice "approximation" "Central difference"; flag "compute_acceleration" true;
                     text "acceleration_attribute" "a2"; text "velocity_attribute" "vel"; num "dt" 0.5];
      "accel_group", [choice "approximation" "Central difference"; flag "compute_acceleration" true;
                      text "group" "a"; num "add_z" 1.];
      "accel_match", [choice "approximation" "Central difference"; flag "compute_acceleration" true;
                      text "match_attribute" "pid"; choice "unmatched" "Zero"];
      "accel_existing", [choice "approximation" "Central difference"; flag "compute_acceleration" true;
                         text "acceleration_attribute" "vec3"; text "velocity_attribute" "v"];
      "accel_wrong_storage", [choice "approximation" "Central difference"; flag "compute_acceleration" true;
                              text "acceleration_attribute" "vec2"];
      "accel_backward", [flag "compute_acceleration" true];
      "accel_same_name", [choice "approximation" "Central difference"; flag "compute_acceleration" true;
                          text "acceleration_attribute" "v"];
      "accel_keep", [choice "initialization" "Keep incoming"; flag "compute_acceleration" true;
                     choice "approximation" "Central difference"];
      "accel_P", [choice "approximation" "Central difference"; flag "compute_acceleration" true;
                  text "acceleration_attribute" "P"];
      "accel_blank", [choice "approximation" "Central difference"; flag "compute_acceleration" true;
                      text "acceleration_attribute" " "];
      "name_blank", [text "velocity_attribute" " "]; "name_P", [text "velocity_attribute" "P"];
      "dt_tiny", [num "dt" 0.000001]; "dt_zero", [num "dt" 0.] ]
  @ List.concat_map (fun group ->
      let g = if group = "" then [] else [text "group" group] in
      [ "keep/" ^ group, choice "initialization" "Keep incoming" :: g;
        "keep_add/" ^ group, choice "initialization" "Keep incoming" :: num "add_x" 2. :: g;
        "keep_existing/" ^ group, choice "initialization" "Keep incoming" :: text "velocity_attribute" "vec3" :: g;
        "keep_wrong/" ^ group, choice "initialization" "Keep incoming" :: text "velocity_attribute" "vec2" :: g;
        "keep_float_attr/" ^ group, choice "initialization" "Keep incoming" :: text "velocity_attribute" "v" :: num "add_y" 1. :: g;
        "set/" ^ group, choice "initialization" "Set value" :: num "set_x" 1. :: num "set_y" (-2.) :: num "set_z" 0.5 :: g;
        "set_add/" ^ group, choice "initialization" "Set value" :: num "set_x" 1. :: num "add_z" 0.75 :: g;
        "set_existing/" ^ group, choice "initialization" "Set value" :: num "set_y" 1. :: text "velocity_attribute" "v" :: g;
        "attr/" ^ group, choice "initialization" "From attribute" :: text "source_attribute" "v" :: g;
        "attr_scaled/" ^ group, choice "initialization" "From attribute" :: text "source_attribute" "v" :: num "source_scale" (-1.5) :: g;
        "attr_add/" ^ group, choice "initialization" "From attribute" :: text "source_attribute" " v " :: num "add_x" 1. :: g;
        "attr_unit_to_name/" ^ group, choice "initialization" "From attribute" :: text "source_attribute" "v" :: text "velocity_attribute" "w" :: g;
        "attr_missing/" ^ group, choice "initialization" "From attribute" :: text "source_attribute" "nope" :: g;
        "attr_missing_scaled/" ^ group, choice "initialization" "From attribute" :: text "source_attribute" "nope" :: num "source_scale" 2. :: g;
        "attr_wrong/" ^ group, choice "initialization" "From attribute" :: text "source_attribute" "vec2" :: g;
        "attr_wrong_scaled/" ^ group, choice "initialization" "From attribute" :: text "source_attribute" "float" :: num "source_scale" 2. :: g;
        "attr_blank/" ^ group, choice "initialization" "From attribute" :: text "source_attribute" " " :: g;
        "attr_self/" ^ group, choice "initialization" "From attribute" :: text "source_attribute" "v" :: text "velocity_attribute" "v" :: num "source_scale" 2. :: g ])
      [""; "a"; "dest_a"; "nope"]
let bench () =
  let n = 1_000_000 in
  let g shift = Kernel.generate_point_ranges n (fun ~first ~last ~x ~y ~z ->
    for i = first to last - 1 do x.(i) <- float i *. 0.125 +. shift; y.(i) <- 0.5 *. shift; z.(i) <- 0.25 done) in
  [g 0.; g (-0.0625); g 0.125], [choice "approximation" "Central difference"]
let () = register { key = "point_velocity"; native = Sop.Nodes.Point_velocity.factory; inputs; cases; ulps = 4;
  bench = Some bench }
