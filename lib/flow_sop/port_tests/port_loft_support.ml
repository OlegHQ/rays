(* Shared fixtures of the section-zipping nodes (poly_loft, skin, poly_bridge): rings and polylines at
   irregular positions (no exact distance ties except where a case wants them). *)
open Rdk
open Port_gate

type section = { kind : Topology.primitive_kind; count : int; level : float; radius : float; phase : float }

let sec ?(kind = Topology.Closed_polyline) ?(radius = 1.) ?(phase = 0.) count level =
  { kind; count; level; radius; phase }

(* Positions: points of each section on a deformed ring (or arc when open) at its level. *)
let build sections =
  let total = List.fold_left (fun n s -> n + s.count) 0 sections in
  let x = Array.make total 0. and y = Array.make total 0. and z = Array.make total 0. in
  let vertex_points = Array.init total Fun.id in
  let at = ref 0 in
  List.iteri (fun si s ->
    for i = 0 to s.count - 1 do
      let angle = s.phase +. (6.283185307179586 *. float i /. float s.count)
        +. (0.07 *. sin (float (7 * i + 3 * si))) in
      let r = s.radius *. (1. +. (0.05 *. cos (float (5 * i + si)))) in
      x.(!at) <- r *. cos angle; y.(!at) <- r *. sin angle;
      z.(!at) <- s.level +. (0.03 *. sin (float (3 * i + si)));
      incr at
    done) sections;
  let offsets = Array.make (List.length sections + 1) 0 in
  List.iteri (fun i s -> offsets.(i + 1) <- offsets.(i) + s.count) sections;
  let kinds = Array.of_list (List.map (fun s -> s.kind) sections) in
  let topology = Topology.create_owned ~point_count:total ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> Rdk_test_support.get_string_ok in
  let positions = Packed.Float3.of_owned ~x ~y ~z |> Rdk_test_support.get_string_ok in
  Geometry.create ~positions ~topology () |> Rdk_test_support.get_string_ok

let decorate g = fixture_attributes (fixture_groups g)

let with_normals owner geometry =
  let n = match owner with Attribute.Point -> Geometry.point_count geometry
    | _ -> Geometry.vertex_count geometry in
  let plane f = Array.init n f in
  Geometry.with_attribute (Attribute.create_owned ~owner ~name:"N"
    (Attribute.Float3 (Packed.Float3.of_owned ~x:(plane (fun i -> float i)) ~y:(plane (fun _ -> 1.))
      ~z:(plane (fun _ -> 0.)) |> Rdk_test_support.get_string_ok)) |> Rdk_test_support.get_string_ok)
    geometry |> Rdk_test_support.get_string_ok

(* The same geometry with positions moved (the rest input). *)
let shifted geometry =
  let view = Packed.Float3.Private.view (Geometry.positions geometry) in
  let n = Array.length view.x in
  let x = Array.init n (fun i -> view.x.(i) +. 0.3 *. sin (float i))
  and y = Array.init n (fun i -> view.y.(i) -. 0.2 *. cos (float i))
  and z = Array.init n (fun i -> view.z.(i) +. 0.1) in
  let positions = Packed.Float3.of_owned ~x ~y ~z |> Rdk_test_support.get_string_ok in
  Geometry.create ~positions ~topology:(Geometry.topology geometry) ~attributes:(Geometry.attributes geometry)
    ~groups:(Geometry.groups geometry) () |> Rdk_test_support.get_string_ok

let open_k = Topology.Open_polyline and closed_k = Topology.Closed_polyline and poly_k = Topology.Polygon
