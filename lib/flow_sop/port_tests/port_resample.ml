(* sop/resample: one geometry input (pending draft nodes/resample.pending).
   Not registered: polygon primitives and zero-length curves (the default parameters would
   error and the gate's cache check needs the defaults to cook). *)
open Rdk
open Port_gate
module P = Param
let ch name value = name, P.Choice_value value
let it name n = name, P.Int_value n
let fl name x = name, P.Float_value x
let bo name b = name, P.Bool_value b
let tx name s = name, P.Text_value s
let open_k = Topology.Open_polyline and closed_k = Topology.Closed_polyline
let curves ~xs ~ys ~zs ~vertex_points ~offsets ~kinds =
  let points = Array.length xs in
  let topology = Topology.create_owned ~point_count:points ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> Rdk_test_support.get_string_ok in
  let positions = Packed.Float3.Private.of_owned_exn ~x:xs ~y:ys ~z:zs in
  let geometry = Geometry.create ~positions ~topology () |> Rdk_test_support.get_string_ok in
  let count = Array.length kinds in
  let add owner name storage geometry = Geometry.with_attribute
    (Attribute.create_owned ~owner ~name storage |> Rdk_test_support.get_string_ok) geometry
    |> Rdk_test_support.get_string_ok in
  let normals = Array.init points (fun i -> [| float (i mod 3) -. 1.; 0.5; float (i mod 2) |]) in
  let n_plane k = Array.map (fun v -> v.(k)) normals in
  let geometry = add Attribute.Point "N" (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
    ~x:(n_plane 0) ~y:(n_plane 1) ~z:(n_plane 2))) geometry in
  let geometry = add Attribute.Primitive "seglen" (Attribute.Float (Array.init count (fun i ->
    if i mod 3 = 1 then 0. else 0.4 +. float i *. 0.3))) geometry in
  let geometry = add Attribute.Primitive "segs" (Attribute.Int (Array.init count (fun i ->
    if i mod 3 = 1 then 0 else 3 + i * 2))) geometry in
  fixture_attributes (fixture_groups geometry)
let inputs = List.map (fun (label, g) -> label, [g]) [
  "open", curves
    ~xs:[|0.;1.;2.5;3.;0.;0.5;2.;4.;4.;5.;6.5;7.|] ~ys:[|0.;0.5;0.;1.;2.;2.5;3.;3.5;0.;1.;1.;3.|]
    ~zs:[|0.;0.;1.;0.5;0.;1.;0.25;0.;0.;0.;2.;0.|]
    ~vertex_points:[|0;1;2;3;4;5;6;7;8;9;10;11|] ~offsets:[|0;4;8;12|] ~kinds:[|open_k; open_k; open_k|];
  "closed", curves
    ~xs:[|0.;2.;2.;0.;5.;7.;6.;1.;3.|] ~ys:[|0.;0.;2.;2.;0.;0.;3.;5.;5.|] ~zs:[|0.;0.;0.5;0.;1.;1.;1.;0.;2.|]
    ~vertex_points:[|0;1;2;3;4;5;6;7;8;5|] ~offsets:[|0;4;7;10|] ~kinds:[|closed_k; closed_k; open_k|];
  "two-vertices", curves ~xs:[|0.;1.5|] ~ys:[|0.;0.5|] ~zs:[|0.;0.|] ~vertex_points:[|0;1|] ~offsets:[|0;2|]
    ~kinds:[|open_k|];
  "empty", curves ~xs:[||] ~ys:[||] ~zs:[||] ~vertex_points:[||] ~offsets:[|0|] ~kinds:[||]]
let parameters = [
  "segments/1", [it "segments" 1];
  "segments/2", [it "segments" 2];
  "segments/3", [it "segments" 3];
  "segments/7", [it "segments" 7];
  "segments/64", [it "segments" 64];
  "length", [bo "use_segments" false; bo "use_maximum_segment_length" true; fl "maximum_segment_length" 0.7];
  "length/small", [bo "use_segments" false; bo "use_maximum_segment_length" true; fl "maximum_segment_length" 0.13];
  "length/uneven", [bo "use_segments" false; bo "use_maximum_segment_length" true; fl "maximum_segment_length" 0.7;
    bo "even_last_segment" false];
  "length/huge", [bo "use_segments" false; bo "use_maximum_segment_length" true; fl "maximum_segment_length" 100.];
  "length-and-segments", [bo "use_maximum_segment_length" true; fl "maximum_segment_length" 1.1; it "segments" 5];
  "length-and-segments/capped", [bo "use_maximum_segment_length" true; fl "maximum_segment_length" 0.2;
    it "segments" 4; bo "even_last_segment" false];
  "length-and-segments/uneven", [bo "use_maximum_segment_length" true; fl "maximum_segment_length" 0.9;
    it "segments" 40; bo "even_last_segment" false];
  "length-error-zero", [bo "use_maximum_segment_length" true; fl "maximum_segment_length" 0.];
  "nothing-error", [bo "use_segments" false];
  "override/length", [bo "use_segments" false; tx "segment_length_attribute" "seglen"];
  "override/length-padded", [tx "segment_length_attribute" " seglen "; it "segments" 2];
  "override/segments", [bo "use_segments" false; tx "segments_attribute" "segs"];
  "override/segments-with-count", [tx "segments_attribute" "segs"; it "segments" 2];
  "override/both", [bo "use_segments" false; tx "segments_attribute" "segs"; tx "segment_length_attribute" "seglen"];
  "override/missing-error", [tx "segment_length_attribute" "nope"];
  "override/wrong-type-error", [tx "segments_attribute" "seglen"];
  "override/length-wrong-type-error", [tx "segment_length_attribute" "segs"];
  "even-last/off", [bo "even_last_segment" false];
  "group", [tx "group" "a"]; "group/padded", [tx "group" " dest_a "; it "segments" 4];
  "group/missing", [tx "group" "nothing"]; "group/unicode", [tx "group" "\195\169\231\140\171"];
  "curve_u", [tx "curve_u_attribute" "curve_u"];
  "curve_number", [tx "curve_number_attribute" "curve_number"];
  "distance", [tx "distance_attribute" "dist"];
  "tangent", [tx "tangent_attribute" "tan"];
  "all-generated", [tx "curve_u_attribute" "u"; tx "curve_number_attribute" "n"; tx "distance_attribute" "d";
    tx "tangent_attribute" "t"; it "segments" 5];
  "generated/replace-existing", [tx "curve_u_attribute" "float"; tx "curve_number_attribute" "integer";
    tx "distance_attribute" "vec2"; tx "tangent_attribute" "N"];
  "generated/padded", [tx "curve_u_attribute" " u "];
  "generated/duplicate-error", [tx "curve_u_attribute" "same"; tx "distance_attribute" " same "];
  "generated/P-error", [tx "tangent_attribute" "P"];
  "generated/length-driven", [bo "use_segments" false; bo "use_maximum_segment_length" true;
    fl "maximum_segment_length" 0.5; tx "curve_u_attribute" "u"; tx "distance_attribute" "d";
    tx "tangent_attribute" "t"; tx "curve_number_attribute" "n"];
]
let cases = parameters
let bench () =
  let n = 200_000 in
  let g = curves ~xs:(Array.init (n * 5) (fun i -> float (i mod 5) *. 0.5 +. float (i / 5 mod 7) *. 0.01))
    ~ys:(Array.init (n * 5) (fun i -> float (i mod 5) *. 0.25))
    ~zs:(Array.init (n * 5) (fun i -> float (i mod 3) *. 0.125))
    ~vertex_points:(Array.init (n * 5) Fun.id) ~offsets:(Array.init (n + 1) (fun i -> i * 5))
    ~kinds:(Array.make n open_k) in
  [g], [it "segments" 4]
let () = register { key = "resample"; native = Sop.Nodes.Resample.factory; inputs; cases; ulps = 4;
  bench = Some bench }
