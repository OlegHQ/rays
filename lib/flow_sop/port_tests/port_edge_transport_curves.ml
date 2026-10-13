(* sop/edge_transport_curves: one geometry input (pending draft nodes/edge_transport_curves.pending).
   Not covered: the "point shared by two selected curves" refusal. The gate's cache check cooks
   the default parameters, which select every curve, so a fixture that errors by default cannot
   be registered. It was exercised by hand with the cache check disabled. *)
open Rdk
open Port_gate
module P = Param
let ch name value = name, P.Choice_value value
let bo name b = name, P.Bool_value b
let tx name s = name, P.Text_value s
let open_k = Topology.Open_polyline and closed_k = Topology.Closed_polyline and poly_k = Topology.Polygon
let curves ~points ~vertex_points ~offsets ~kinds =
  let topology = Topology.create_owned ~point_count:points ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> Rdk_test_support.get_string_ok in
  let x = Array.init points (fun i -> float i *. 0.75 -. 2.) and y = Array.init points (fun i -> float (i * i mod 7) *. 0.5)
  and z = Array.init points (fun i -> if i mod 3 = 0 then 1e3 else float i *. 0.1) in
  let positions = Packed.Float3.Private.of_owned_exn ~x ~y ~z in
  let geometry = Geometry.create ~positions ~topology () |> Rdk_test_support.get_string_ok in
  let float_attribute owner name values = Attribute.create_owned ~owner ~name (Attribute.Float values)
    |> Rdk_test_support.get_string_ok in
  let pv = Array.init points (fun i -> float ((i * 5 + 3) mod 7) -. 2.5 +. if i mod 4 = 1 then 0.125 else 0.) in
  let vertices = Array.length vertex_points in
  let vv = Array.init vertices (fun i -> float ((i * 3 + 1) mod 5) -. 1.5) in
  let geometry = Geometry.with_attribute (float_attribute Attribute.Point "value" pv) geometry
    |> Rdk_test_support.get_string_ok in
  let geometry = Geometry.with_attribute (float_attribute Attribute.Vertex "value" vv) geometry
    |> Rdk_test_support.get_string_ok in
  fixture_attributes (fixture_groups geometry)
let inputs = List.map (fun (label, g) -> label, [g]) [
  "open", curves ~points:11 ~vertex_points:[|0;1;2;3;4;5;6;10;9;8;7|] ~offsets:[|0;4;7;11|]
    ~kinds:[|open_k; open_k; open_k|];
  "closed", curves ~points:12 ~vertex_points:[|3;1;2;5;4;6;7;8;9;11;10;0|] ~offsets:[|0;5;8;12|]
    ~kinds:[|closed_k; closed_k; poly_k|];
  "repeated", curves ~points:5 ~vertex_points:[|0;1;0;2;3;4;3|] ~offsets:[|0;4;7|] ~kinds:[|open_k; closed_k|];
  "empty", curves ~points:0 ~vertex_points:[||] ~offsets:[|0|] ~kinds:[||]]
let operations = ["Transport"; "From root"; "Total"; "Maximum"; "Minimum"]
let matrix = List.concat_map (fun op -> List.concat_map (fun owner -> List.concat_map (fun direction ->
  List.map (fun root ->
    Printf.sprintf "%s/%s/%s/%s" op owner direction root,
    [ch "operation" op; ch "owner" owner; ch "direction" direction; ch "root_value" root])
    ["Zero"; "Hold"]) ["Forward"; "Backward"]) ["Point"; "Vertex"]) operations
let normalize = List.concat_map (fun op -> List.concat_map (fun n -> List.map (fun owner ->
  Printf.sprintf "norm/%s/%s/%s" op n owner, [ch "operation" op; ch "normalization" n; ch "owner" owner])
  ["Point"; "Vertex"]) ["Per component"; "Global"]) operations
let parameters = [
  "integrate", [bo "integrate_constant" true; ch "operation" "Total"];
  "integrate/vertex/backward", [bo "integrate_constant" true; ch "operation" "Total"; ch "owner" "Vertex";
    ch "direction" "Backward"];
  "integrate/missing-attribute", [bo "integrate_constant" true; ch "operation" "Total"; tx "attribute" "fresh"];
  "integrate/normalized", [bo "integrate_constant" true; ch "operation" "Total"; ch "normalization" "Global"];
  "integrate-without-total-error", [bo "integrate_constant" true];
  "scale", [bo "scale_by_edge_length" true; ch "operation" "Total"];
  "scale/backward/vertex", [bo "scale_by_edge_length" true; ch "operation" "Total"; ch "direction" "Backward";
    ch "owner" "Vertex"];
  "scale+integrate", [bo "scale_by_edge_length" true; bo "integrate_constant" true; ch "operation" "Total"];
  "scale-without-total-error", [bo "scale_by_edge_length" true];
  "group", [tx "primitive_group" "a"; ch "operation" "Total"];
  "group/padded", [tx "primitive_group" " dest_a "; ch "operation" "Maximum"; ch "owner" "Vertex"];
  "group/missing", [tx "primitive_group" "nothing"];
  "group/unicode", [tx "primitive_group" "\195\169\231\140\171"; ch "operation" "Total"];
  "attribute/missing", [tx "attribute" "absent"];
  "attribute/wrong-type-int", [tx "attribute" "integer"];
  "attribute/wrong-type-text", [tx "attribute" "text"; ch "owner" "Vertex"];
  "attribute/spaces", [tx "attribute" " value "; ch "operation" "Total"];
  "attribute/P-error", [tx "attribute" "P"];
  "attribute/blank-error", [tx "attribute" "  "];
]
let cases = parameters @ matrix @ normalize
let bench () =
  let n = 333_333 in
  let g = curves ~points:(n * 3) ~vertex_points:(Array.init (n * 3) Fun.id)
    ~offsets:(Array.init (n + 1) (fun i -> i * 3)) ~kinds:(Array.make n open_k) in
  [g], [ch "operation" "Total"]
let () = register { key = "edge_transport_curves"; native = Sop.Nodes.Edge_transport_curves.factory; inputs;
  cases; ulps = 4; bench = Some bench }
