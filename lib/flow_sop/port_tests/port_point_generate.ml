(* sop/point_generate: one geometry input (pending draft). Custom fixtures add point float attributes
   "prob" (in [0,1]) and "scale" (0..2.8) so the probability and scale modes succeed. *)
open Rdk
open Port_gate
module P = Param
let t name v = name, P.Text_value v
let c name v = name, P.Choice_value v
let with_float name f geometry =
  let n = Geometry.point_count geometry in
  Rdk_test_support.get_string_ok (Geometry.with_attribute (Rdk_test_support.get_string_ok
    (Attribute.create_owned ~owner:Attribute.Point ~name (Attribute.Float (Array.init n f)))) geometry)
let with_int name f geometry =
  let n = Geometry.point_count geometry in
  Rdk_test_support.get_string_ok (Geometry.with_attribute (Rdk_test_support.get_string_ok
    (Attribute.create_owned ~owner:Attribute.Point ~name (Attribute.Int (Array.init n f)))) geometry)
let rich () =
  fixture_attributes (fixture_groups (polygon_polyline ()))
  |> with_float "prob" (fun i -> float ((i * 7) mod 10) /. 10.)
  |> with_float "scale" (fun i -> float (i mod 5) *. 0.7)
let meta () = rich () |> with_int "sourcepoint" (fun i -> 100 + i) |> with_int "sourceindex" (fun i -> 200 - i)
let inputs = List.map (fun (label, g) -> label, [g]) [
  "empty", with_float "prob" (fun _ -> 0.) (points 0); "single", with_float "prob" (fun _ -> 1.) (points 1);
  "grid4225", with_float "prob" (fun i -> float (i mod 4) /. 3.) (fixture_groups (grid ()));
  "meta", meta (); "rich", rich ()]
let cases =
  List.concat_map (fun (mode, extra) -> List.map (fun keep -> Printf.sprintf "%s/keep=%b" mode keep,
    c "mode" mode :: ("keep_input", P.Bool_value keep) :: extra) [false; true])
    ["Total count", ["total", P.Int_value 7];
     "Per point", ["points_per_point", P.Float_value 2.5];
     "Probability attribute", [t "probability_attribute" "prob"]]
  @ ["total0", [c "mode" "Total count"; "total", P.Int_value 0];
     "total0_keep", [c "mode" "Total count"; "total", P.Int_value 0; "keep_input", P.Bool_value true];
     "per0", ["points_per_point", P.Float_value 0.];
     "per_fraction", ["points_per_point", P.Float_value 0.4; "seed", P.Int_value 5];
     "per_fraction_context", ["points_per_point", P.Float_value 0.6; "context_seed", P.Bool_value true];
     "per_big", ["points_per_point", P.Float_value 3.7; "seed", P.Int_value 9999];
     "scale", ["points_per_point", P.Float_value 1.3; t "scale_attribute" " scale "];
     "scale_missing", [t "scale_attribute" "nothing"];
     "scale_wrong_type", [t "scale_attribute" "integer"];
     "scale_negative", [t "scale_attribute" "float"];
     "prob_missing", [c "mode" "Probability attribute"];
     "prob_wrong_type", [c "mode" "Probability attribute"; t "probability_attribute" "integer"];
     "prob_range", [c "mode" "Probability attribute"; t "probability_attribute" "float"];
     "prob_seed", [c "mode" "Probability attribute"; t "probability_attribute" "prob"; "seed", P.Int_value 77];
     "prob_context", [c "mode" "Probability attribute"; t "probability_attribute" "prob"; "context_seed", P.Bool_value true];
     "prob_blank_name", [c "mode" "Probability attribute"; t "probability_attribute" " "];
     "group", [t "group" " a "; "points_per_point", P.Float_value 1.5];
     "group_keep", [t "group" "a"; "keep_input", P.Bool_value true; "points_per_point", P.Float_value 1.5];
     "group_ordered", [t "group" "dest_a"; "keep_input", P.Bool_value true];
     "group_missing", [t "group" "zzz"];
     "generated_group", [t "generated_group" " gen "];
     "generated_group_keep", [t "generated_group" "gen"; "keep_input", P.Bool_value true];
     "generated_group_existing", [t "generated_group" "a"; "keep_input", P.Bool_value true];
     "generated_group_ordered", [t "generated_group" "dest_a"; "keep_input", P.Bool_value true];
     "generated_group_existing_drop", [t "generated_group" "a"];
     "generated_group_total", [c "mode" "Total count"; "total", P.Int_value 3; t "generated_group" "gen"; "keep_input", P.Bool_value true];
     "metadata_names", [t "source_point_attribute" "from"; t "source_index_attribute" "rank"];
     "metadata_names_keep", [t "source_point_attribute" "from"; t "source_index_attribute" "rank"; "keep_input", P.Bool_value true];
     "metadata_existing_keep", [t "source_point_attribute" "float"; "keep_input", P.Bool_value true];
     "metadata_existing", [t "source_index_attribute" "text"];
     "metadata_swapped", [t "source_point_attribute" "sourceindex"; t "source_index_attribute" "sourcepoint"];
     "metadata_P", [t "source_point_attribute" "P"];
     "metadata_blank", [t "source_index_attribute" " "];
     "metadata_same", [t "source_point_attribute" "x"; t "source_index_attribute" "x"];
     "copy_none", [t "copy_point_attributes" ""];
     "copy_some", [t "copy_point_attributes" "float vec3 text"];
     "copy_exclude", [t "copy_point_attributes" "* ^float"; "keep_input", P.Bool_value true];
     "copy_some_keep", [t "copy_point_attributes" "int*"; "keep_input", P.Bool_value true];
     "copy_total_keep", [c "mode" "Total count"; "total", P.Int_value 2; "keep_input", P.Bool_value true];
     "copy_bad_pattern", [t "copy_point_attributes" "["];
     "detail_all", [t "copy_detail_attributes" "*"];
     "detail_named", [t "copy_detail_attributes" "untouched float"];
     "detail_keep", [t "copy_detail_attributes" "*"; "keep_input", P.Bool_value true];
     "detail_bad_pattern", [t "copy_detail_attributes" "["]]
let bench () =
  let g = with_float "prob" (fun i -> float (i mod 4) /. 3.) (points 1_000_000) in
  [g], ["points_per_point", P.Float_value 1.]
let () = register { key = "point_generate"; native = Sop.Nodes.Point_generate_from_input.factory; inputs;
  cases; ulps = 4; bench = Some bench }
