(* sop/edge_transport_parent: one geometry input (pending draft nodes/edge_transport_parent.pending).
   Every fixture carries an int point attribute "parent" (a second one, "parent2", and a text
   attribute "label"), float "value" and "other", and the standard point groups, so the default
   cook never errors (the cache check cooks the defaults). Not covered: non-finite sums, which
   the Lisp arithmetic reports as E_NONFINITE where native reports invalid_edge_transport. *)
open Rdk
open Port_gate
module P = Param
let ch name value = name, P.Choice_value value
let bo name b = name, P.Bool_value b
let tx name s = name, P.Text_value s

let forest ~parents ~parents2 =
  let n = Array.length parents in
  let positions = Packed.Float3.Private.of_owned_exn
    ~x:(Array.init n (fun i -> float i *. 0.75 -. 2.))
    ~y:(Array.init n (fun i -> float (i * i mod 7) *. 0.5))
    ~z:(Array.init n (fun i -> if i mod 5 = 0 then 1e3 else float i *. 0.1)) in
  let geometry = Geometry.create ~positions ~topology:(Topology.empty ~point_count:n) ()
    |> Rdk_test_support.get_string_ok in
  let put name storage geometry = Geometry.with_attribute
    (Attribute.create_owned ~owner:Attribute.Point ~name storage |> Rdk_test_support.get_string_ok) geometry
    |> Rdk_test_support.get_string_ok in
  geometry
  |> put "parent" (Attribute.Int (Array.copy parents))
  |> put "parent2" (Attribute.Int (Array.copy parents2))
  |> put "value" (Attribute.Float (Array.init n (fun i -> float ((i * 5 + 3) mod 7) -. 2.5 +. if i mod 4 = 1 then 0.125 else 0.)))
  |> put "other" (Attribute.Float (Array.init n (fun i -> float (i mod 3) *. 0.375 -. 0.5)))
  |> put "label" (Attribute.Text (Array.make n "x"))
  |> fixture_groups

let inputs = List.map (fun (label, g) -> label, [g]) [
  "empty", forest ~parents:[||] ~parents2:[||];
  "single", forest ~parents:[|-1|] ~parents2:[|0|];
  "cycles", forest ~parents:[|1; 0; 1; 3; 2; 5; 5; 7; 6|] ~parents2:[|-1; 0; 1; 2; 3; 4; 5; 6; 7|];
  "chain", forest ~parents:[|-1; 0; 1; 2; 3; 4; 5; 6; 7; 8; 9; 10|]
    ~parents2:[|3; 3; 3; 3; 0; 4; 4; 5; 5; 9; 9; 10|];
  "forest", forest ~parents:[|-1; 0; 0; 1; 1; 2; 2; 99; 8; 8; 7; 11; -5; 12; 12; 3|]
    ~parents2:[|0; 0; 1; 1; 2; 2; 6; 6; 7; 9; 9; 12; 12; 15; 14; 14|]]

let operations = ["Transport"; "From root"; "Total"; "Maximum"; "Minimum"]
let matrix = List.concat_map (fun op -> List.concat_map (fun dir -> List.map (fun root ->
  Printf.sprintf "%s/%s/%s" op dir root, [ch "operation" op; ch "direction" dir; ch "root_value" root])
  ["Zero"; "Hold"]) ["Forward"; "Backward"]) operations
let split = List.concat_map (fun op -> List.map (fun dir ->
  Printf.sprintf "split/%s/%s" op dir,
  [ch "operation" op; ch "direction" dir; ch "split" "Split"; ch "root_value" "Hold"])
  ["Forward"; "Backward"]) operations
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
  "integrate/normalized", [bo "integrate_constant" true; ch "operation" "Total"; ch "normalization" "Global"];
  "integrate/split", [bo "integrate_constant" true; ch "operation" "Total"; ch "split" "Split"];
  "integrate-without-total-error", [bo "integrate_constant" true];
  "scale", [bo "scale_by_edge_length" true; ch "operation" "Total"];
  "scale/backward", [bo "scale_by_edge_length" true; ch "operation" "Total"; ch "direction" "Backward"];
  "scale/split", [bo "scale_by_edge_length" true; ch "operation" "Total"; ch "split" "Split"];
  "scale+integrate", [bo "scale_by_edge_length" true; bo "integrate_constant" true; ch "operation" "Total"];
  "scale-without-total-error", [bo "scale_by_edge_length" true];
  "group", [tx "point_group" "a"; ch "operation" "Total"];
  "group/backward", [tx "point_group" "a"; ch "operation" "Maximum"; ch "direction" "Backward"];
  "group/padded", [tx "point_group" " dest_a "; ch "operation" "Transport"; ch "root_value" "Hold"];
  "group/split-norm", [tx "point_group" "old_x"; ch "operation" "Total"; ch "split" "Split";
    ch "normalization" "Per component"];
  "group/missing", [tx "point_group" "nothing"];
  "group/unicode", [tx "point_group" "\195\169\231\140\171"; ch "operation" "Total"];
  "parent2", [tx "parent_attribute" "parent2"; ch "operation" "Total"];
  "parent2/backward", [tx "parent_attribute" "parent2"; ch "operation" "Total"; ch "direction" "Backward"];
  "parent/missing", [tx "parent_attribute" "absent"];
  "parent/wrong-type", [tx "parent_attribute" "value"];
  "parent/blank-error", [tx "parent_attribute" "  "];
  "attribute", [tx "attribute" "other"; ch "operation" "Total"];
  "attribute/missing", [tx "attribute" "absent"];
  "attribute/wrong-type-text", [tx "attribute" "label"];
  "attribute/wrong-type-int", [tx "attribute" "parent"];
  "attribute/P-error", [tx "attribute" "P"];
  "attribute/blank-error", [tx "attribute" "  "];
]
let cases = parameters @ matrix @ split @ merge @ normalize
let bench () =
  let n = 1_000_000 in
  let g = forest ~parents:(Array.init n (fun i -> (i - 1) / 4)) ~parents2:(Array.make n 0) in
  [g], [ch "operation" "Total"; bo "scale_by_edge_length" true]
let () = register { key = "edge_transport_parent"; native = Sop.Nodes.Edge_transport_parent.factory; inputs;
  cases; ulps = 4; bench = Some bench }
