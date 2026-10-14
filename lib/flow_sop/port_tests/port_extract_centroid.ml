(* sop/extract_centroid: one geometry input (pending draft nodes/extract_centroid.pending).
   Fixtures: a collinear polygon + polyline (line hulls), a planar grid (polygon hulls) and a
   scattered grid (solid hulls); each carries int and text "piece"/"label" attributes on points and
   primitives. A default cook must succeed on every fixture, so the empty geometry is not one:
   its error is the "Primitives" case on the single point. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let tx name value = name, P.Text_value value
let ch name value = name, P.Choice_value value

let hash i salt = float ((i * 7919 + salt * 104729 + 13) mod 1000) /. 500. -. 1.
let add owner name storage g = Geometry.with_attribute
  (Attribute.create_owned ~owner ~name storage |> get_string_ok) g |> get_string_ok
let labelled g =
  let on owner count g =
    add owner "piece" (Attribute.Int (Array.init count (fun i -> (i * 7 + 1) mod 3))) g
    |> add owner "label" (Attribute.Text (Array.init count (fun i -> if i mod 4 = 0 then "a" else if i mod 4 = 3 then "\195\169" else "b")))
    |> add owner "single" (Attribute.Int (Array.make count 5)) in
  g |> on Attribute.Point (Geometry.point_count g) |> on Attribute.Primitive (Geometry.primitive_count g)
let spread g =
  let n = Geometry.point_count g in
  let plane salt scale = Array.init n (fun i -> scale *. hash i salt) in
  Geometry.with_positions (Packed.Float3.of_owned ~x:(plane 1 2.5) ~y:(plane 2 1.5) ~z:(plane 3 0.75)
    |> get_string_ok) g |> get_string_ok
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:6 ~rows:5 ~size:8. () |> get_ok
let inputs = List.map (fun (label, g) -> label, [labelled g]) [
  "single", points 1;
  "collinear", fixture_attributes (polygon_polyline ());
  "planar grid", small_grid ();
  "scattered grid", spread (small_grid ()) ]

let cases =
  List.concat_map (fun run -> List.map (fun m ->
    run ^ " / " ^ m, [ch "run_over" run; ch "method_" m; tx "piece_attribute" "piece"])
    ["Point mass"; "Bounding box"; "Convex hull"]) ["Detail"; "Primitives"; "Point pieces"; "Primitive pieces"]
  @ List.concat_map (fun run -> List.map (fun m ->
    run ^ " label / " ^ m, [ch "run_over" run; ch "method_" m; tx "piece_attribute" "label"])
    ["Point mass"; "Bounding box"; "Convex hull"]) ["Point pieces"; "Primitive pieces"]
  @ List.concat_map (fun run -> [
      run ^ " one piece", [ch "run_over" run; tx "piece_attribute" "single"];
      run ^ " one piece hull", [ch "run_over" run; tx "piece_attribute" "single"; ch "method_" "Convex hull"];
      run ^ " missing", [ch "run_over" run; tx "piece_attribute" "absent"];
      run ^ " padded name", [ch "run_over" run; tx "piece_attribute" " piece "];
      run ^ " float attribute", [ch "run_over" run; tx "piece_attribute" "float"];
      run ^ " vec3 attribute", [ch "run_over" run; tx "piece_attribute" "vec3"];
      run ^ " blank attribute", [ch "run_over" run; tx "piece_attribute" "  "];
      run ^ " P attribute", [ch "run_over" run; tx "piece_attribute" "P"];
      run ^ " integer attribute", [ch "run_over" run; tx "piece_attribute" "integer"];
      run ^ " text attribute", [ch "run_over" run; tx "piece_attribute" "text"];
      run ^ " output name", [ch "run_over" run; tx "piece_output_attribute" "centroid_id"];
      run ^ " output padded", [ch "run_over" run; tx "piece_output_attribute" " id "];
      run ^ " output P", [ch "run_over" run; tx "piece_output_attribute" "P"];
      run ^ " output spaced P", [ch "run_over" run; tx "piece_output_attribute" " P "];
      run ^ " output same as input", [ch "run_over" run; tx "piece_output_attribute" "piece"] ])
    ["Point pieces"; "Primitive pieces"]
  @ List.concat_map (fun run -> [
      run ^ " source attribute", [ch "run_over" run; tx "source_primitive_attribute" "src"];
      run ^ " source padded", [ch "run_over" run; tx "source_primitive_attribute" " src "];
      run ^ " source P", [ch "run_over" run; tx "source_primitive_attribute" "P"];
      run ^ " source spaced P", [ch "run_over" run; tx "source_primitive_attribute" " P "];
      run ^ " source blank", [ch "run_over" run; tx "source_primitive_attribute" "   "];
      run ^ " ignored piece attribute", [ch "run_over" run; tx "piece_attribute" "P"] ])
    ["Detail"; "Primitives"]
  @ [ "everything", [ch "run_over" "Primitive pieces"; ch "method_" "Bounding box"; tx "piece_attribute" "label";
        tx "piece_output_attribute" "which"; tx "source_primitive_attribute" "ignored"] ]

let bench () = [spread (points 1_000_000)], []
let () = register { key = "extract_centroid"; native = Sop.Nodes.Extract_centroid.factory; inputs; cases;
  ulps = 4; bench = Some bench }
