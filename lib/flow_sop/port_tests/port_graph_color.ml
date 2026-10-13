(* sop/graph_color: one geometry input (pending draft nodes/graph_color.pending). *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value
let flag name value = name, P.Bool_value value
(* Three triangles around one shared edge, a quad, and an open polyline: non-manifold edge sharing. *)
let shared () =
  let topology = Topology.create_owned ~point_count:7
    ~vertex_points:[|0;1;2; 1;0;3; 0;1;4; 1;2;5;6; 5;6|]
    ~primitive_offsets:[|0;3;6;9;13;15|]
    ~primitive_kinds:[|Topology.Polygon; Polygon; Polygon; Polygon; Open_polyline|] |> get_string_ok in
  fixture_groups (Geometry.create ~positions:(Geometry.positions (points 7)) ~topology () |> get_string_ok)
let connectivities = ["Primitives by point"; "Points by primitive"; "Primitives by edge"]
let owners = ["Point"; "Vertex"; "Primitive"; "Edge"]
let cases =
  List.concat_map (fun c -> [
    Printf.sprintf "%s/plain" c, [choice "connectivity" c];
    Printf.sprintf "%s/sorted" c, [choice "connectivity" c; flag "sort_output" true];
    Printf.sprintf "%s/worksets" c, [choice "connectivity" c; flag "sort_output" true; flag "output_worksets" true];
    Printf.sprintf "%s/worksets custom" c, [choice "connectivity" c; flag "sort_output" true; flag "output_worksets" true;
      text "workset_begin_attribute" "wb"; text "workset_length_attribute" "wl"];
    Printf.sprintf "%s/attribute" c, [choice "connectivity" c; text "color_attribute" "mycolor"];
    Printf.sprintf "%s/float attribute" c, [choice "connectivity" c; text "color_attribute" "float"];
    Printf.sprintf "%s/integer attribute" c, [choice "connectivity" c; text "color_attribute" "integer"]])
    connectivities
  @ List.concat_map (fun c -> List.map (fun o ->
      Printf.sprintf "%s/group %s" c o, [choice "connectivity" c; choice "group_owner" o; text "group" " a "])
    owners) connectivities
  @ List.concat_map (fun c -> [
      Printf.sprintf "%s/group sorted" c, [choice "connectivity" c; choice "group_owner" "Edge"; text "group" "a";
        flag "sort_output" true; flag "output_worksets" true];
      Printf.sprintf "%s/missing group" c, [choice "connectivity" c; text "group" "nothing"]]) connectivities
  (* Not cases: construction refusals (blank or P names, worksets without sorted output or with equal
     names). The gate only sees checker refusals, and :validate runs at lowering, so a refusal case
     reads "native refused but the Lisp node was accepted". *)
let bench () = [Plane_generators.grid ~connectivity:Grid_quads ~columns:1000 ~rows:1000 ~size:8. () |> get_ok], []
let () = register { key = "graph_color"; native = Sop.Nodes.Graph_color.factory;
  inputs = standard_inputs @ ["shared", [shared ()]]; cases; ulps = 4; bench = Some bench }
