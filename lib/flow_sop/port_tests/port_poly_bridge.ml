(* sop/poly_bridge: one geometry input with edge groups "source" and "destination" (whole primitives of
   the fixture's sections). Errors are reached through cases (missing or overlapping or odd groups, open
   paths with a pairing shift, divisions on unequal counts): the default cook of every fixture succeeds. *)
open Rdk
open Port_gate
open Port_loft_support
module P = Param

(* Edge ordinals of each section: an open polyline of m points owns m - 1 edges, a closed one m. *)
let edge_ranges sections =
  let at = ref 0 in
  List.map (fun s ->
    let edges = if s.kind = open_k then s.count - 1 else s.count in
    let first = !at in
    at := !at + edges;
    first, !at) sections

let bridged ~source ~destination sections =
  let geometry = decorate (build sections) in
  let ranges = Array.of_list (edge_ranges sections) in
  let member sections_ edge = List.exists (fun k -> let first, last = ranges.(k) in edge >= first && edge < last) sections_ in
  let topology = Geometry.topology geometry in
  let index = Topology_index.create topology in
  List.fold_left (fun g (name, group) -> Geometry.with_edge_group
    (Edge_group.init ~topology ~index ~name (member group)) g |> Rdk_test_support.get_string_ok) geometry
    ["source", source; "destination", destination]

let rings = bridged ~source:[0] ~destination:[1] [sec 6 0.; sec 6 1. ~radius:1.3 ~phase:0.4]
let rings_unequal = bridged ~source:[0] ~destination:[1] [sec 5 0.; sec 7 1. ~radius:1.3 ~phase:0.4]
let arcs = bridged ~source:[0] ~destination:[1]
  [sec ~kind:open_k 5 0.; sec ~kind:open_k 5 1. ~radius:1.2 ~phase:0.3]
let arcs_unequal = bridged ~source:[0] ~destination:[1]
  [sec ~kind:open_k 4 0.; sec ~kind:open_k 6 1. ~radius:1.2 ~phase:0.3]
let two_pairs = bridged ~source:[0; 2] ~destination:[1; 3]
  [sec 5 0.; sec 5 1. ~radius:2.; sec ~radius:2.5 6 2.5 ~phase:1.; sec 4 3. ~radius:0.4]
let mixed_pairs = bridged ~source:[0; 2] ~destination:[1; 3]
  [sec ~kind:open_k 4 0. ~radius:3.; sec ~kind:open_k 4 1. ~radius:0.5; sec 5 2. ~radius:0.4; sec 5 3. ~radius:2.]
let polygons = bridged ~source:[0] ~destination:[1]
  [sec ~kind:poly_k 4 0.; sec ~kind:poly_k 6 1. ~radius:0.8]

let inputs =
  List.map (fun (label, g) -> label, [g]) [
    "rings", rings; "rings unequal", rings_unequal; "arcs", arcs; "arcs unequal", arcs_unequal;
    "two pairs", two_pairs; "mixed pairs", mixed_pairs; "polygons", polygons;
    "normals", with_normals Attribute.Point rings ]

let fields ?(source = "source") ?(destination = "destination") ?(pairing = "By order") ?(connect = true)
    ?(minimize = "Two point distance") ?(reverse_source = false) ?(reverse_destination = false) ?(shift = 0)
    ?(divisions = 1) ?(keep = true) ?(output = "bridge") ?(tolerance = 0.) ?(normals = false) () =
  ["source_group", P.Text_value source; "destination_group", P.Text_value destination;
   "pairing", P.Choice_value pairing; "connect_closest_ends", P.Bool_value connect;
   "minimize", P.Choice_value minimize; "reverse_source", P.Bool_value reverse_source;
   "reverse_destination", P.Bool_value reverse_destination; "pairing_shift", P.Int_value shift;
   "divisions", P.Int_value divisions; "keep_input", P.Bool_value keep; "output_group", P.Text_value output;
   "collinearity_tolerance", P.Float_value tolerance; "recompute_normals", P.Bool_value normals]

let cases = [
  "centroid", fields ~pairing:"By centroid" ();
  "no connect", fields ~connect:false ();
  "three point", fields ~minimize:"Three point distance" ();
  "reverse source", fields ~reverse_source:true ();
  "reverse destination", fields ~reverse_destination:true ();
  "reverse both", fields ~reverse_source:true ~reverse_destination:true ~connect:false ();
  "shift", fields ~shift:2 ();
  "shift negative", fields ~shift:(-1) ~connect:false ();
  "divisions", fields ~divisions:3 ();
  "divisions drop", fields ~divisions:2 ~keep:false ~tolerance:0.1 ();
  "divisions centroid", fields ~divisions:4 ~pairing:"By centroid" ~output:"" ();
  "drop input", fields ~keep:false ();
  "no output group", fields ~output:" " ();
  "tolerance", fields ~tolerance:0.5 ();
  "normals", fields ~normals:true ();
  "swapped groups", fields ~source:"destination" ~destination:"source" ();
  "missing source", fields ~source:"nothing" ();
  "missing destination", fields ~destination:"nothing" ();
  "overlap", fields ~destination:"source" ();
  "odd groups", fields ~source:"a" ~destination:"dest_a" ();
  "odd groups two", fields ~source:"old_x" ~destination:"a" ~pairing:"By centroid" () ]

let bench () =
  let arcs = List.init 12_500 (fun i -> sec ~kind:open_k 20 (float i *. 0.01) ~radius:(1. +. (0.001 *. float (i mod 7)))) in
  let shifted = List.init 12_500 (fun i -> sec ~kind:open_k 20 (float i *. 0.01 +. 0.005) ~radius:(1.2 +. (0.001 *. float (i mod 5)))) in
  let sections = arcs @ shifted in
  let geometry = build sections in
  let ranges = Array.of_list (edge_ranges sections) in
  let topology = Geometry.topology geometry in
  let index = Topology_index.create topology in
  let group name lo hi = Geometry.with_edge_group (Edge_group.init ~topology ~index ~name (fun e ->
    let k = fst ranges.(lo) in let last = snd ranges.(hi) in e >= k && e < last)) in
  let geometry = geometry |> (fun g -> group "source" 0 12_499 g |> Rdk_test_support.get_string_ok)
    |> (fun g -> group "destination" 12_500 24_999 g |> Rdk_test_support.get_string_ok) in
  [geometry], fields ()

let () = register { key = "poly_bridge"; native = Sop.Nodes.Poly_bridge.factory; inputs; cases; ulps = 4;
  bench = Some bench }
