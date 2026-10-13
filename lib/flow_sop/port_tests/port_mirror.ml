(* sop/mirror: one geometry input (pending draft). The standard "mixed" fixture holds a
   polygon and an open polyline; the extra fixture adds point and vertex normals "N" and a
   closed polyline so reflected normals and every primitive kind are reached. *)
open Rdk
open Port_gate
module P = Param
let fields keep (ox, oy, oz) (nx, ny, nz) =
  ["keep_original", P.Bool_value keep;
   "origin_x", P.Float_value ox; "origin_y", P.Float_value oy; "origin_z", P.Float_value oz;
   "normal_x", P.Float_value nx; "normal_y", P.Float_value ny; "normal_z", P.Float_value nz]
let with_normals geometry =
  let add owner count geometry =
    let plane f = Array.init count f in
    Geometry.with_attribute (Attribute.create_owned ~owner ~name:"N"
      (Attribute.Float3 (Packed.Float3.of_owned ~x:(plane (fun i -> 0.1 *. float i))
         ~y:(plane (fun i -> 1. -. 0.05 *. float i)) ~z:(plane (fun i -> if i mod 2 = 0 then -0. else 0.3))
         |> Rdk_test_support.get_string_ok)) |> Rdk_test_support.get_string_ok) geometry
    |> Rdk_test_support.get_string_ok in
  add Attribute.Point (Geometry.point_count geometry) geometry
  |> fun g -> add Attribute.Vertex (Geometry.vertex_count g) g
let mixed_kinds () =
  let topology = Topology.create_owned ~point_count:8 ~vertex_points:[|0;1;2;3;1;4;5;6;7;0|]
    ~primitive_offsets:[|0;4;6;10|]
    ~primitive_kinds:[|Topology.Polygon; Open_polyline; Closed_polyline|] |> Rdk_test_support.get_string_ok in
  Geometry.create ~positions:(Geometry.positions (points 8)) ~topology () |> Rdk_test_support.get_string_ok
let inputs = standard_inputs @
  ["normals", [with_normals (fixture_attributes (fixture_groups (mixed_kinds ())))]]
let cases =
  List.concat_map (fun keep -> List.map (fun (label, origin, normal) ->
    Printf.sprintf "%s/%b" label keep, fields keep origin normal)
    ["default", (0., 0., 0.), (1., 0., 0.);
     "y", (0., 0.5, 0.), (0., 1., 0.);
     "z", (0., 0., -0.25), (0., 0., 3.);
     "oblique", (0.3, -0.7, 1.1), (0.4, -0.9, 0.2);
     "unnormalised", (1., 2., 3.), (-5., 0.01, 7.);
     "tiny", (0., 0., 0.), (1e-10, 0., 0.);
     "zero", (0., 0., 0.), (0., 0., 0.);
     "too-small", (0., 0., 0.), (1e-21, 0., 0.);
     "huge", (1e300, 0., 0.), (1e200, 1e200, 0.)]) [true; false]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  [g], fields true (0., 0.2, 0.) (0.3, 1., 0.1)
let () = register { key = "mirror"; native = Sop.Nodes.Mirror.factory; inputs; cases; ulps = 4; bench = Some bench }
