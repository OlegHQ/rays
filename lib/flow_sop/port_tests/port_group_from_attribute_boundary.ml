(* sop/group_from_attribute_boundary: one geometry input (pending draft
   nodes/group_from_attribute_boundary.pending). Fixtures carry an attribute of every storage on every owner
   (float, integer, text, vec2/3/4, one-element rows) plus ragged int and float rows, on a quad grid
   (manifold), three triangles sharing an edge (non-manifold) and the polygon + polyline. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let fl name x = name, P.Float_value x
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let ch name value = name, P.Choice_value value

let add owner name storage g = Geometry.with_attribute
  (Attribute.create_owned ~owner ~name storage |> get_string_ok) g |> get_string_ok
let ragged g =
  let on owner count g =
    let offsets = Array.make (count + 1) 0 in
    for i = 0 to count - 1 do offsets.(i + 1) <- offsets.(i) + (i mod 3) done;
    let total = offsets.(count) in
    g |> add owner "ragged_int" (Attribute.Int_array (Packed.Int_array.create_owned ~offsets:(Array.copy offsets)
         ~values:(Array.init total (fun i -> i / 2)) |> get_string_ok))
      |> add owner "ragged_float" (Attribute.Float_array (Packed.Float_array.create_owned ~offsets
         ~values:(Array.init total (fun i -> float (i / 2) *. 0.5)) |> get_string_ok)) in
  g |> on Attribute.Point (Geometry.point_count g) |> on Attribute.Vertex (Geometry.vertex_count g)
    |> on Attribute.Primitive (Geometry.primitive_count g)
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:6 ~rows:5 ~size:8. () |> get_ok
let fan () =
  let topology = Topology.create_owned ~point_count:5 ~vertex_points:[|0;1;2;0;1;3;0;1;4|]
    ~primitive_offsets:[|0;3;6;9|] ~primitive_kinds:[|Topology.Polygon; Polygon; Polygon|] |> get_string_ok in
  let positions = Packed.Float3.of_owned ~x:[|0.;1.;0.5;0.5;0.5|] ~y:[|0.;0.;1.;-1.;0.2|]
    ~z:[|0.;0.;0.;0.3;1.|] |> get_string_ok in
  Geometry.create ~positions ~topology () |> get_string_ok
let prepared g = ragged (fixture_attributes (fixture_groups g))
let inputs = List.map (fun (label, g) -> label, [prepared g]) [
  "mixed", polygon_polyline (); "fan", fan (); "grid", small_grid () ]

let rules rows = String.concat "\n" (List.map (String.concat "\t") rows)
let attrs rows = tx "attributes" (rules rows)
let cases =
  List.concat_map (fun owner ->
    List.map (fun (label, extra) -> owner ^ " " ^ label, ch "owner" owner :: extra)
      [ "positions", [attrs [["point"; "P"]]];
        "all point", [attrs [["point"; "*"]]];
        "all primitive", [attrs [["primitive"; "*"]]];
        "all vertex", [attrs [["vertex"; "*"]]];
        "named", [attrs [["point"; "float"]; ["vertex"; "integer"]; ["primitive"; "text"]]];
        "unshared", [attrs [["point"; "float"]]; bo "include_unshared_edges" true];
        "unshared only", [bo "include_unshared_edges" true];
        "unshared curves", [bo "include_unshared_edges" true; bo "include_all_unshared_curve_edges" true];
        "nothing", [] ])
    ["Edges"; "Points"; "Primitives"]
  @ [ "primitives share points", [ch "owner" "Primitives"; attrs [["point"; "float"]];
        bo "include_all_primitives_sharing_boundary_points" true];
      "primitives share points unshared", [ch "owner" "Primitives"; bo "include_unshared_edges" true;
        bo "include_all_primitives_sharing_boundary_points" true];
      "share points on edges", [ch "owner" "Edges"; bo "include_all_primitives_sharing_boundary_points" true];
      "share points on points", [ch "owner" "Points"; bo "include_all_primitives_sharing_boundary_points" true];
      "curves without unshared", [bo "include_all_unshared_curve_edges" true];
      "vertices", [ch "owner" "Vertices"; attrs [["point"; "float"]]];
      "name blank", [tx "name" "  "; attrs [["point"; "float"]]];
      "name raw", [tx "name" " raw "; attrs [["point"; "float"]]];
      "ragged int", [attrs [["point"; "ragged_int"]]];
      "ragged float", [attrs [["primitive"; "ragged_float"]]];
      "ragged vertex", [attrs [["vertex"; "ragged_*"]]];
      "vec only", [attrs [["point"; "vec*"]]];
      "vec3 vertex", [attrs [["vertex"; "vec3"]]];
      "vec2 primitive", [attrs [["primitive"; "vec2"]]];
      "rows", [attrs [["point"; "*_rows"]; ["vertex"; "*_rows"]; ["primitive"; "*_rows"]]];
      "text point", [attrs [["point"; "text"]]];
      "integer vertex", [attrs [["vertex"; "integer"]]];
      "pattern class", [attrs [["point"; "[fi]*"]]];
      "pattern question", [attrs [["primitive"; "f?oat"]]];
      "pattern P only", [attrs [["point"; "[P]"]]];
      "pattern star matches P", [attrs [["point"; "*"]]; ch "owner" "Points"];
      "pattern none", [attrs [["point"; "nonexistent"]]];
      "pattern bad", [attrs [["point"; "[a"]]];
      "owner plural", [attrs [["points"; "float"]; ["vertices"; "float"]; ["primitives"; "float"]]];
      "owner padded", [attrs [["  Point "; "float"]]];
      "owner detail", [attrs [["detail"; "float"]]];
      "owner unknown", [attrs [["edge"; "float"]]];
      "three columns", [tx "attributes" "point\tfloat\textra"];
      "duplicate rules", [attrs [["point"; "float"]; ["point"; "f*"]; ["point"; "float"]]];
      "tolerance zero", [attrs [["point"; "float"]]; fl "tolerance" 0.];
      "tolerance wide", [attrs [["point"; "*"]]; fl "tolerance" 0.3];
      "tolerance huge", [attrs [["point"; "*"]; ["primitive"; "*"]; ["vertex"; "*"]]; fl "tolerance" 100.];
      "tolerance positions", [attrs [["point"; "P"]]; fl "tolerance" 1.5];
      "everything", [ch "owner" "Primitives"; tx "name" "all"; attrs [["point"; "*"]; ["vertex"; "*"]; ["primitive"; "*"]];
        fl "tolerance" 0.01; bo "include_unshared_edges" true; bo "include_all_unshared_curve_edges" true;
        bo "include_all_primitives_sharing_boundary_points" true] ]

let bench () =
  [Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> get_ok],
  [tx "attributes" "point\tP"; bo "include_unshared_edges" true]
let () = register { key = "group_from_attribute_boundary";
  native = Sop.Nodes.Group_from_attribute_boundary.factory; inputs; cases; ulps = 4; bench = Some bench }
