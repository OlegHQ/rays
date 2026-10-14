(* sop/group_edges: one geometry input (pending draft nodes/group_edges.pending).
   Fixtures: a bumpy quad grid (manifold, boundary and varied dihedral angles), three triangles sharing
   one edge (non-manifold), and the standard polygon + polyline (collinear, so dihedral angle filters
   refuse it natively: those are error cases). *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let fl name x = name, P.Float_value x
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let ch name value = name, P.Choice_value value

let hash i salt = float ((i * 7919 + salt * 104729 + 13) mod 1000) /. 500. -. 1.
let bumpy () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:6 ~rows:5 ~size:8. () |> get_ok in
  let n = Geometry.point_count g in
  let view = Packed.Float3.Private.view (Geometry.positions g) in
  let moved = Packed.Float3.of_owned ~x:(Array.copy view.x) ~y:(Array.copy view.y)
    ~z:(Array.init n (fun i -> 0.8 *. hash i 3)) |> get_string_ok in
  fixture_groups (Geometry.with_positions moved g |> get_string_ok)
let fan () =
  let topology = Topology.create_owned ~point_count:5 ~vertex_points:[|0;1;2;0;1;3;0;1;4|]
    ~primitive_offsets:[|0;3;6;9|] ~primitive_kinds:[|Topology.Polygon; Polygon; Polygon|] |> get_string_ok in
  let positions = Packed.Float3.of_owned ~x:[|0.;1.;0.5;0.5;0.5|] ~y:[|0.;0.;1.;-1.;0.2|]
    ~z:[|0.;0.;0.;0.3;1.|] |> get_string_ok in
  fixture_groups (Geometry.create ~positions ~topology () |> get_string_ok)
let inputs = List.map (fun (label, g) -> label, [g]) [
  "bumpy grid", bumpy (); "fan", fan (); "mixed", fixture_attributes (fixture_groups (polygon_polyline ())) ]

let pi = 3.141592653589793
let cases =
  List.map (fun i -> "incidence " ^ i, [ch "incidence" i]) ["Any"; "Boundary"; "Manifold"; "Non-manifold"]
  @ [ "name", [tx "name" " raw name "]; "name blank", [tx "name" "  "];
      "group", [tx "group" "a"]; "group padded", [tx "group" " a "]; "group missing", [tx "group" "nope"];
      "group + boundary", [tx "group" "a"; ch "incidence" "Boundary"];
      "group + manifold", [tx "group" "dest_a"; ch "incidence" "Manifold"];
      "min length", [bo "use_min_length" true; fl "min_length" 1.5];
      "max length", [bo "use_max_length" true; fl "max_length" 1.5];
      "length band", [bo "use_min_length" true; fl "min_length" 1.3; bo "use_max_length" true; fl "max_length" 1.7];
      "exact length", [bo "use_min_length" true; fl "min_length" 1.6; bo "use_max_length" true; fl "max_length" 1.6];
      "length zero", [bo "use_max_length" true; fl "max_length" 0.];
      "length min > max", [bo "use_min_length" true; fl "min_length" 2.; bo "use_max_length" true; fl "max_length" 1.];
      "length unused ignored", [fl "min_length" 2.; fl "max_length" 1.];
      "length + group", [tx "group" "a"; bo "use_min_length" true; fl "min_length" 1.5];
      "length + incidence", [ch "incidence" "Boundary"; bo "use_max_length" true; fl "max_length" 1.5];
      "min angle", [bo "use_min_angle" true; fl "min_angle" 0.3];
      "max angle", [bo "use_max_angle" true; fl "max_angle" 0.9];
      "angle band", [bo "use_min_angle" true; fl "min_angle" 0.2; bo "use_max_angle" true; fl "max_angle" 1.2];
      "angle full", [bo "use_min_angle" true; fl "min_angle" 0.; bo "use_max_angle" true; fl "max_angle" pi];
      "angle right", [bo "use_min_angle" true; fl "min_angle" (pi /. 2.)];
      "angle flat", [bo "use_max_angle" true; fl "max_angle" 0.];
      "angle min > max", [bo "use_min_angle" true; fl "min_angle" 1.; bo "use_max_angle" true; fl "max_angle" 0.5];
      "angle too big", [bo "use_max_angle" true; fl "max_angle" 4.];
      "angle too small", [bo "use_min_angle" true; fl "min_angle" (-0.5)];
      "angle unused ignored", [fl "min_angle" 2.; fl "max_angle" 1.];
      "dihedral + group", [tx "group" "a"; bo "use_min_angle" true; fl "min_angle" 0.3];
      "dihedral + group both", [tx "group" "dest_a"; bo "use_max_angle" true; fl "max_angle" 1.0];
      "dihedral + manifold", [ch "incidence" "Manifold"; bo "use_min_angle" true; fl "min_angle" 0.3];
      "dihedral + length", [bo "use_min_angle" true; fl "min_angle" 0.3; bo "use_min_length" true; fl "min_length" 1.5];
      "incident min", [ch "angle_basis" "Incident edges"; bo "use_min_angle" true; fl "min_angle" 2.0];
      "incident max", [ch "angle_basis" "Incident edges"; bo "use_max_angle" true; fl "max_angle" 1.0];
      "incident band", [ch "angle_basis" "Incident edges"; bo "use_min_angle" true; fl "min_angle" 1.0;
        bo "use_max_angle" true; fl "max_angle" 2.0];
      "incident straight", [ch "angle_basis" "Incident edges"; bo "use_min_angle" true; fl "min_angle" (pi -. 0.01)];
      "incident right", [ch "angle_basis" "Incident edges"; bo "use_min_angle" true; fl "min_angle" (pi /. 2.);
        bo "use_max_angle" true; fl "max_angle" (pi /. 2.)];
      "incident group", [ch "angle_basis" "Incident edges"; tx "group" "a"; bo "use_min_angle" true; fl "min_angle" 1.0];
      "incident group max", [ch "angle_basis" "Incident edges"; tx "group" "dest_a"; bo "use_max_angle" true;
        fl "max_angle" 1.5];
      "incident boundary", [ch "angle_basis" "Incident edges"; ch "incidence" "Boundary"; bo "use_min_angle" true;
        fl "min_angle" 1.0];
      "incident ignored without angle", [ch "angle_basis" "Incident edges"];
      "everything", [tx "name" "all"; tx "group" "a"; ch "incidence" "Manifold"; bo "use_min_length" true;
        fl "min_length" 1.0; bo "use_max_length" true; fl "max_length" 3.0; bo "use_min_angle" true;
        fl "min_angle" 0.1; bo "use_max_angle" true; fl "max_angle" 2.0];
      "everything incident", [tx "name" "all"; ch "angle_basis" "Incident edges"; ch "incidence" "Any";
        bo "use_min_length" true; fl "min_length" 1.0; bo "use_min_angle" true; fl "min_angle" 0.1;
        bo "use_max_angle" true; fl "max_angle" 2.5] ]

let bench () =
  [Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> get_ok],
  [ch "incidence" "Manifold"; bo "use_min_length" true; fl "min_length" 0.001]
let () = register { key = "group_edges"; native = Sop.Nodes.Group_edges.factory; inputs; cases; ulps = 4;
  bench = Some bench }
