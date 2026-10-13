(* sop/revolve: one geometry input (pending draft nodes/revolve.pending). Fixtures place
   profile vertices exactly on the Y axis (collapsed rings, axis-axis edges) and on the
   tilted axis (1,1,0) so the on-axis test is exercised for both. *)
open Rdk
open Port_gate
module P = Param
let ch name value = name, P.Choice_value value
let it name n = name, P.Int_value n
let fl name x = name, P.Float_value x
let bo name b = name, P.Bool_value b
let tx name s = name, P.Text_value s
let xyz prefix (x, y, z) = [fl (prefix ^ "_x") x; fl (prefix ^ "_y") y; fl (prefix ^ "_z") z]
let profiles ~xs ~ys ~zs ~vertex_points ~offsets ~kinds =
  let count = Array.length xs in
  let topology = Topology.create_owned ~point_count:count ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> Rdk_test_support.get_string_ok in
  let positions = Packed.Float3.Private.of_owned_exn ~x:xs ~y:ys ~z:zs in
  Geometry.create ~positions ~topology () |> Rdk_test_support.get_string_ok
let decorate g = fixture_attributes (fixture_groups g)
let open_k = Topology.Open_polyline and closed_k = Topology.Closed_polyline and poly_k = Topology.Polygon
let curves = profiles
  ~xs:[|1.;2.;1.5;0.;0.;1.;1.;0.;3.;2.;0.5|] ~ys:[|0.;1.;2.;3.;0.;0.;1.;1.;0.5;1.5;2.|]
  ~zs:[|0.;0.5;-0.5;0.;0.;0.;0.25;0.;0.1;-0.2;0.3|]
  ~vertex_points:[|0;1;2;3;4;5;6;7;8;9;10|] ~offsets:[|0;4;8;11|] ~kinds:[|open_k; closed_k; open_k|]
(* shared and repeated (non-adjacent) points *)
let shared = profiles ~xs:[|1.;2.;0.;1.5|] ~ys:[|0.;1.;2.;1.|] ~zs:[|0.;0.;0.5;1.|]
  ~vertex_points:[|0;1;2;1;3;0;3;2|] ~offsets:[|0;3;5;8|] ~kinds:[|open_k; open_k; closed_k|]
let slanted = profiles ~xs:[|0.;1.;2.;3.|] ~ys:[|0.;1.;2.;3.|] ~zs:[|0.;0.;1.;0.5|]
  ~vertex_points:[|0;1;2;3|] ~offsets:[|0;4|] ~kinds:[|open_k|]
let polygon = profiles ~xs:[|1.;2.;1.5;1.;2.|] ~ys:[|0.;1.;2.;3.;4.|] ~zs:[|0.;0.;0.;0.;0.|]
  ~vertex_points:[|0;1;2;3;4|] ~offsets:[|0;3;5|] ~kinds:[|poly_k; open_k|]
let short = profiles ~xs:[|1.;2.|] ~ys:[|0.;1.|] ~zs:[|0.;0.|]
  ~vertex_points:[|0;1|] ~offsets:[|0;2|] ~kinds:[|open_k|]
let zero_edge = profiles ~xs:[|1.;1.;2.|] ~ys:[|0.;0.;1.|] ~zs:[|0.;0.;0.|]
  ~vertex_points:[|0;1;2|] ~offsets:[|0;3|] ~kinds:[|open_k|]
let empty = profiles ~xs:[||] ~ys:[||] ~zs:[||] ~vertex_points:[||] ~offsets:[|0|] ~kinds:[||]
let inputs = List.map (fun (label, g) -> label, [decorate g]) [
  "curves", curves; "shared", shared; "slanted", slanted; "short", short; "empty", empty]
(* Not registered: [polygon] and [zero_edge] make the default parameters an error, and the gate's
   cache-identity check needs the defaults to cook. Both errors were exercised by hand with the
   cache check disabled and matched native (code and refusal). *)
let _unregistered = [polygon; zero_edge]
let connectivities = ["Points"; "Rows"; "Columns"; "Rows and columns"; "Quads"; "Triangles";
  "Alternating triangles"; "Reverse triangles"]
let matrix = List.concat_map (fun kind -> List.concat_map (fun connectivity ->
  List.map (fun reverse ->
    Printf.sprintf "%s/%s/reverse=%b" kind connectivity reverse,
    [ch "revolve_type" kind; ch "connectivity" connectivity; bo "reverse_cross_sections" reverse;
     it "divisions" 5; fl "start_angle" 0.3; fl "end_angle" 2.9; tx "group" "a"])
    [false; true]) connectivities) ["Closed"; "Open arc"]
let caps = List.concat_map (fun connectivity ->
  List.map (fun reverse -> Printf.sprintf "caps/%s/reverse=%b" connectivity reverse,
    [bo "caps" true; ch "connectivity" connectivity; bo "reverse_cross_sections" reverse; it "divisions" 6;
     tx "group" "a"])
    [false; true]) ["Quads"; "Triangles"; "Alternating triangles"; "Reverse triangles"]
let parameters = [
  "divisions/3", [it "divisions" 3];
  "divisions/17", [it "divisions" 17];
  "divisions/1-open", [ch "revolve_type" "Open arc"; it "divisions" 1];
  "divisions/2-closed-error", [it "divisions" 2];
  "start_angle", [ch "revolve_type" "Open arc"; fl "start_angle" (-1.5); fl "end_angle" 4.0];
  "end_angle", [ch "revolve_type" "Open arc"; fl "end_angle" (-5.0)];
  "open-zero-span-error", [ch "revolve_type" "Open arc"; fl "start_angle" 1.0; fl "end_angle" 1.0];
  "angles-ignored-closed", [fl "start_angle" 1.0; fl "end_angle" 1.0];
  "group", [tx "group" "a"]; "group-padded", [tx "group" " dest_a "]; "group-blank", [tx "group" " \t "];
  "group-missing", [tx "group" "nothing"];
  "group-unicode", [tx "group" "\195\169\231\140\171"];
  "uv/custom", [tx "uv_attribute" " st "]; "uv/blank", [tx "uv_attribute" " "];
  "uv/existing-name", [tx "uv_attribute" "vec2"];
  "uv/point-existing", [tx "uv_attribute" "vec2"; ch "connectivity" "Points"];
  "uv/P-error", [tx "uv_attribute" "P"]; "uv/N-error", [tx "uv_attribute" " N "];
  "caps/group-custom", [bo "caps" true; tx "cap_group" " ends "];
  "caps/group-blank", [bo "caps" true; tx "cap_group" " "];
  "caps/group-ignored-without-caps", [tx "cap_group" "ends"];
  "caps/open-arc-error", [bo "caps" true; ch "revolve_type" "Open arc"];
  "caps/rows-error", [bo "caps" true; ch "connectivity" "Rows"];
  "origin", xyz "origin" (0.5, -1.0, 0.25);
  "axis/x", xyz "axis" (1., 0., 0.);
  "axis/tilted", xyz "axis" (1., 1., 0.);
  "axis/tilted-origin", xyz "axis" (-0.5, 2., 0.75) @ xyz "origin" (0.25, 0.5, -0.125);
  "axis/small", xyz "axis" (1e-200, 2e-200, 0.);
  "axis/zero-error", xyz "axis" (0., 0., 0.);
  "points/no-uv", [ch "connectivity" "Points"; tx "uv_attribute" " "];
  "triangles-div4", [ch "connectivity" "Triangles"; it "divisions" 4];
]
let cases = parameters @ matrix @ caps
let bench () =
  let n = 200_000 in
  let g = profiles ~xs:(Array.init (n * 5) (fun i -> 1. +. float (i mod 5) *. 0.25))
    ~ys:(Array.init (n * 5) (fun i -> float (i mod 5) *. 0.5))
    ~zs:(Array.init (n * 5) (fun i -> float (i / 5 mod 7) *. 0.01))
    ~vertex_points:(Array.init (n * 5) Fun.id) ~offsets:(Array.init (n + 1) (fun i -> i * 5))
    ~kinds:(Array.make n open_k) in
  [g], [it "divisions" 3; ch "connectivity" "Quads"]
let () = register { key = "revolve"; native = Sop.Nodes.Revolve.factory; inputs; cases; ulps = 4;
  bench = Some bench }
