(* sop/edge_transport: one geometry input (pending draft nodes/edge_transport.pending).
   Every fixture carries float "value" and "other" point attributes (the default cook must not
   error: the cache check cooks the defaults). The grid fixture has many equal-length ties, the
   polyline fixture has several components and isolated points. Not covered: non-finite sums and
   lengths, which the Lisp arithmetic reports as E_NONFINITE where native reports
   invalid_edge_transport. *)
open Rdk
open Port_gate
module P = Param
let ch name value = name, P.Choice_value value
let bo name b = name, P.Bool_value b
let tx name s = name, P.Text_value s

let decorate geometry =
  let n = Geometry.point_count geometry in
  let put name storage geometry = Geometry.with_attribute
    (Attribute.create_owned ~owner:Attribute.Point ~name storage |> Rdk_test_support.get_string_ok) geometry
    |> Rdk_test_support.get_string_ok in
  geometry
  |> put "value" (Attribute.Float (Array.init n (fun i -> float ((i * 5 + 3) mod 7) -. 2.5 +. if i mod 4 = 1 then 0.125 else 0.)))
  |> put "other" (Attribute.Float (Array.init n (fun i -> float (i mod 3) *. 0.375 -. 0.5)))
  |> put "label" (Attribute.Text (Array.make n "x"))
  |> fixture_groups

let polylines ~points ~vertex_points ~offsets ~kinds =
  let topology = Topology.create_owned ~point_count:points ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> Rdk_test_support.get_string_ok in
  let positions = Packed.Float3.Private.of_owned_exn
    ~x:(Array.init points (fun i -> float i *. 0.75 -. 2.))
    ~y:(Array.init points (fun i -> float (i * i mod 7) *. 0.5))
    ~z:(Array.init points (fun i -> if i mod 5 = 0 then 1e3 else float i *. 0.1)) in
  decorate (Geometry.create ~positions ~topology () |> Rdk_test_support.get_string_ok)

let open_k = Topology.Open_polyline and closed_k = Topology.Closed_polyline
let inputs = List.map (fun (label, g) -> label, [g]) [
  "empty", polylines ~points:0 ~vertex_points:[||] ~offsets:[|0|] ~kinds:[||];
  "single", polylines ~points:1 ~vertex_points:[||] ~offsets:[|0|] ~kinds:[||];
  "polylines", polylines ~points:14 ~vertex_points:[|0;1;2;3;4;3;5;6;7;5;9;8;10;12|]
    ~offsets:[|0;5;9;11;14|] ~kinds:[|open_k; closed_k; open_k; open_k|];
  "grid", decorate (Plane_generators.grid ~connectivity:Grid_quads ~columns:5 ~rows:4 ~size:4. () |> Rdk_test_support.get_ok)]

let operations = ["Transport"; "From root"; "Total"; "Maximum"; "Minimum"]
let matrix = List.concat_map (fun op -> List.concat_map (fun dir -> List.map (fun root ->
  Printf.sprintf "%s/%s/%s" op dir root, [ch "operation" op; ch "direction" dir; ch "root_value" root])
  ["Zero"; "Hold"]) ["Forward"; "Backward"]) operations
let roots = List.concat_map (fun r -> List.map (fun op ->
  Printf.sprintf "roots/%s/%s" r op, [ch "roots" r; ch "operation" op; ch "root_value" "Hold"])
  ["Transport"; "From root"; "Total"]) ["First point"; "Last point"]
  @ List.concat_map (fun (group, extra) -> List.map (fun op ->
    Printf.sprintf "root-group/%s/%s" group op,
    [ch "roots" "Root group"; tx "root_group" group; ch "operation" op; ch "root_value" "Hold"] @ extra)
    ["Transport"; "From root"; "Total"; "Maximum"])
    ["a", []; "dest_a", [ch "direction" "Backward"]; "old_x", []; " a ", [tx "point_group" "dest_a"];
     "\195\169\231\140\171", [ch "direction" "Backward"]]
  @ ["root-group/blank", [ch "roots" "Root group"; ch "operation" "Total"];
     "root-group/ignored-when-first", [tx "root_group" "nothing"; ch "operation" "Total"];
     "root-group/missing", [ch "roots" "Root group"; tx "root_group" "nothing"];
     "root-group/outside-selection", [ch "roots" "Root group"; tx "root_group" "a"; tx "point_group" "dest_a"]]
let split = List.concat_map (fun op -> List.map (fun dir ->
  Printf.sprintf "split/%s/%s" op dir,
  [ch "operation" op; ch "direction" dir; ch "split" "Split"; ch "root_value" "Hold"])
  ["Forward"; "Backward"]) ["Transport"; "Total"]
let merge = List.concat_map (fun op -> List.map (fun merge ->
  Printf.sprintf "merge/%s/%s" op merge,
  [ch "operation" op; ch "direction" "Backward"; ch "merge" merge; ch "root_value" "Hold"])
  ["Add"; "Maximum"; "Minimum"]) operations
let normalize = List.concat_map (fun op -> List.concat_map (fun n -> List.map (fun dir ->
  Printf.sprintf "norm/%s/%s/%s" op n dir, [ch "operation" op; ch "normalization" n; ch "direction" dir])
  ["Forward"; "Backward"]) ["Per component"; "Global"]) operations
let parameters = [
  "integrate", [bo "integrate_constant" true; ch "operation" "Total"];
  "integrate/backward", [bo "integrate_constant" true; ch "operation" "Total"; ch "direction" "Backward"];
  "integrate/missing-attribute", [bo "integrate_constant" true; ch "operation" "Total"; tx "attribute" "fresh"];
  "integrate/normalized", [bo "integrate_constant" true; ch "operation" "Total"; ch "normalization" "Per component"];
  "integrate-without-total-error", [bo "integrate_constant" true];
  "scale", [bo "scale_by_edge_length" true; ch "operation" "Total"];
  "scale/backward", [bo "scale_by_edge_length" true; ch "operation" "Total"; ch "direction" "Backward"];
  "scale/split", [bo "scale_by_edge_length" true; ch "operation" "Total"; ch "split" "Split"];
  "scale/last", [bo "scale_by_edge_length" true; ch "operation" "Total"; ch "roots" "Last point"];
  "scale+integrate", [bo "scale_by_edge_length" true; bo "integrate_constant" true; ch "operation" "Total"];
  "scale-without-total-error", [bo "scale_by_edge_length" true];
  "group", [tx "point_group" "a"; ch "operation" "Total"];
  "group/backward", [tx "point_group" "a"; ch "operation" "Maximum"; ch "direction" "Backward"];
  "group/padded", [tx "point_group" " dest_a "; ch "operation" "Transport"; ch "root_value" "Hold"];
  "group/last-norm", [tx "point_group" "old_x"; ch "roots" "Last point"; ch "operation" "Total";
    ch "normalization" "Per component"];
  "group/missing", [tx "point_group" "nothing"];
  "group/unicode", [tx "point_group" "\195\169\231\140\171"; ch "operation" "Total"];
  "attribute", [tx "attribute" "other"; ch "operation" "Total"];
  "attribute/missing", [tx "attribute" "absent"];
  "attribute/wrong-type-text", [tx "attribute" "label"];
  "attribute/wrong-type-int", [tx "attribute" "integer"];
  "attribute/P-error", [tx "attribute" "P"];
  "attribute/blank-error", [tx "attribute" "  "];
]
let cases = parameters @ matrix @ roots @ split @ merge @ normalize
let bench () =
  (* A root every 16 points keeps the forest shallow: the Lisp sweeps cost depth x points. *)
  let side = 1000 in
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:(side - 1) ~rows:(side - 1) ~size:8. ()
    |> Rdk_test_support.get_ok in
  let n = Geometry.point_count g in
  let g = Geometry.with_group (Group.init ~owner:Group.Point ~name:"roots" n (fun i -> i mod 16 = 0)) g
    |> Rdk_test_support.get_string_ok in
  let g = Geometry.with_attribute (Attribute.create_owned ~owner:Attribute.Point ~name:"value"
    (Attribute.Float (Array.init n (fun i -> float (i mod 7) -. 2.5))) |> Rdk_test_support.get_string_ok) g
    |> Rdk_test_support.get_string_ok in
  [g],
  [ch "operation" "Total"; bo "scale_by_edge_length" true; ch "roots" "Root group"; tx "root_group" "roots"]
let () = register { key = "edge_transport"; native = Sop.Nodes.Edge_transport.factory; inputs;
  cases; ulps = 4; bench = Some bench }
