(* sop/circle_from_edges: one geometry input. Default (no group) fits the boundary edges, so every fixture
   has a boundary that is a simple path or loop; branching, collinear and short components are error
   cases reached through the "a" / "branch" / "short" edge groups. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param

let curves ~positions ~vertex_points ~offsets ~kinds =
  let count = Array.length positions in
  let topology = Topology.create_owned ~point_count:count ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> get_string_ok in
  let x = Array.map (fun (a, _, _) -> a) positions and y = Array.map (fun (_, b, _) -> b) positions
  and z = Array.map (fun (_, _, c) -> c) positions in
  Geometry.create ~positions:(Packed.Float3.Private.of_owned_exn ~x ~y ~z) ~topology () |> get_string_ok

(* A tilted, noisy circle of n points around (1, 2, 3). *)
let circle_points ?(arc = 2. *. Float.pi) n =
  Array.init n (fun i ->
    let angle = arc *. float i /. float n in
    let r = 2. +. 0.01 *. float ((i * 7) mod 5) in
    let u = r *. cos angle and v = r *. sin angle in
    1. +. 0.6 *. u +. 0.1 *. v, 2. +. 0.3 *. u +. 0.8 *. v +. 0.02 *. float (i mod 3), 3. -. 0.5 *. u +. 0.2 *. v)
let ring n = curves ~positions:(circle_points n) ~vertex_points:(Array.init n Fun.id) ~offsets:[|0; n|]
  ~kinds:[|Topology.Closed_polyline|]
let path n = curves ~positions:(circle_points ~arc:Float.pi n) ~vertex_points:(Array.init n Fun.id) ~offsets:[|0; n|]
  ~kinds:[|Topology.Open_polyline|]
let two_loops () =
  let a = circle_points 6 and b = Array.map (fun (x, y, z) -> x +. 9., y, z +. 1.) (circle_points 5) in
  curves ~positions:(Array.append a b) ~vertex_points:(Array.init 11 Fun.id) ~offsets:[|0; 6; 11|]
    ~kinds:[|Topology.Closed_polyline; Closed_polyline|]
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:4 ~rows:4 ~size:3. () |> get_ok
let tilt g =
  let view = Packed.Float3.Private.view (Geometry.positions g) in
  let n = Array.length view.x in
  let x = Array.init n (fun i -> view.x.(i) +. 0.2 *. view.z.(i)) and y = Array.init n (fun i -> view.y.(i) +. 0.5 *. view.x.(i))
  and z = Array.init n (fun i -> view.z.(i) +. 0.1 *. float (i mod 2)) in
  Geometry.with_positions (Packed.Float3.Private.of_owned_exn ~x ~y ~z) g |> get_string_ok

(* Edge groups: every edge, and the first k edges. *)
let with_groups g =
  let topology = Geometry.topology g in
  let index = Topology_index.create topology in
  let count = Topology_index.edge_count index in
  let add name keep g = Geometry.with_edge_group (Edge_group.init ~topology ~index ~name keep) g |> get_string_ok in
  g |> add "all" (fun _ -> true) |> add "arc" (fun e -> e < 4) |> add "short" (fun e -> e < 2)
    |> add "tail" (fun e -> e >= count / 2)
let decorate g = with_groups (fixture_attributes (fixture_groups g))

let inputs = List.map (fun (label, g) -> label, [decorate g]) [
  "empty", points 0; "single", points 1;
  "ring", ring 9; "ring-big", ring 24; "path", path 8; "two-loops", two_loops ();
  "grid", tilt (small_grid ()); "grid4225", grid () ]

let fields ?(group = "") ?(use_radius = false) ?(radius = 1.) ?(sx = 1.) ?(sy = 1.) ?(sz = 1.) ?(output = "") () =
  ["group", P.Text_value group; "use_radius", P.Bool_value use_radius; "radius", P.Float_value radius;
   "scale_x", P.Float_value sx; "scale_y", P.Float_value sy; "scale_z", P.Float_value sz;
   "output_group", P.Text_value output]
let cases =
  List.concat_map (fun (label, group) -> [
      label ^ "/default", fields ~group ();
      label ^ "/radius", fields ~group ~use_radius:true ~radius:3.5 ();
      label ^ "/scale", fields ~group ~sx:2. ~sy:0.5 ~sz:(-1.5) ();
      label ^ "/output", fields ~group ~output:"circled" () ])
    ["boundary", ""; "all", "all"; "arc", "arc"; "short", "short"; "tail", " tail "; "a", "a"; "dest", "dest_a"; "missing", "nothing"]
  @ [ "radius ignored", fields ~radius:0.5 (); "output over input", fields ~group:"all" ~output:"all" ();
      "blank output", fields ~output:"   " (); "literal", fields ~group:"literal *?[]^\\" ();
      "unicode", fields ~group:"\195\169\231\140\171" ~output:"\195\169" () ]
(* Many small loops: the sequential per-component sums take one pass per point of the largest loop, so one
   huge loop is not a representative size. *)
let bench () =
  let loops = 50_000 and size = 10 in
  let one = circle_points size in
  let positions = Array.init (loops * size) (fun i ->
    let x, y, z = one.(i mod size) and k = i / size in x +. float (k mod 100) *. 9., y +. float (k / 100) *. 9., z) in
  [curves ~positions ~vertex_points:(Array.init (loops * size) Fun.id)
     ~offsets:(Array.init (loops + 1) (fun i -> i * size)) ~kinds:(Array.make loops Topology.Closed_polyline)], fields ()
let () = register { key = "circle_from_edges"; native = Sop.Nodes.Circle_from_edges.factory; inputs; cases; ulps = 4;
  bench = Some bench }
