(* sop/compact_points: one geometry input, no parameters (pending draft).
   Fixtures add geometry with unused points in the middle and at both ends. *)
open Rdk
open Port_gate
let sparse () =
  let topology = Topology.create_owned ~point_count:9 ~vertex_points:[|1;2;5;2;5;7|]
    ~primitive_offsets:[|0;3;6|] ~primitive_kinds:[|Topology.Polygon; Topology.Open_polyline|]
    |> Rdk_test_support.get_string_ok in
  Geometry.create ~positions:(Geometry.positions (points 9)) ~topology () |> Rdk_test_support.get_string_ok
let inputs = standard_inputs @ ["sparse", [fixture_attributes (fixture_groups (sparse ()))]]
let bench () =
  (* 1,000,000 points, triangles over the even ones only. *)
  let triangles = 166_666 in
  let topology = Topology.create_owned ~point_count:1_000_000
    ~vertex_points:(Array.init (3 * triangles) (fun v -> 2 * v))
    ~primitive_offsets:(Array.init (triangles + 1) (fun i -> 3 * i))
    ~primitive_kinds:(Array.make triangles Topology.Polygon) |> Rdk_test_support.get_string_ok in
  [Geometry.create ~positions:(Geometry.positions (points 1_000_000)) ~topology ()
   |> Rdk_test_support.get_string_ok], []
let () = register { key = "compact_points"; native = Sop.Nodes.Compact_points.factory; inputs;
  cases = []; ulps = 4; bench = Some bench }
