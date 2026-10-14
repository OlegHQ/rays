(* sop/group_find_path: one geometry input (pending draft nodes/group_find_path.pending).
   Every fixture is connected and carries explicitly ordered base groups "ordered" (default),
   "ordered_two", "ordered_odd", "ordered_loop" and "ordered_same" on points, vertices and primitives,
   so the default cook finds a path (the cache check cooks the defaults); the fixture_groups
   "a", "dest_a", "old_x" are ordered too and serve as base or collision groups. The grid fixture is
   full of equal-length ties, so the hop/length/predecessor order decides the answer. Not covered:
   non-finite positions or overflowing lengths, which the Lisp arithmetic reports as E_NONFINITE
   where native reports invalid_group. *)
open Rdk
open Port_gate
module P = Param
let ch name value = name, P.Choice_value value
let bo name b = name, P.Bool_value b
let tx name s = name, P.Text_value s

let ordered geometry owner name indices =
  let length = match owner with
    | Group.Point -> Geometry.point_count geometry
    | Vertex -> Geometry.vertex_count geometry
    | Primitive -> Geometry.primitive_count geometry in
  let indices = Array.of_list (List.sort_uniq compare (List.filter (fun i -> i < length) (Array.to_list indices)) |> fun seen -> List.filter (fun i -> List.mem i seen) (Array.to_list indices) |> List.fold_left (fun acc i -> if List.mem i acc then acc else acc @ [i]) []) in
  Geometry.with_group (Group.ordered ~owner ~name ~length indices |> Rdk_test_support.get_string_ok) geometry
  |> Rdk_test_support.get_string_ok

let decorate ~points ~prims ~vertices geometry =
  let add geometry (owner, picks) = List.fold_left (fun geometry (name, pick) ->
    ordered geometry owner name pick) geometry picks in
  let groups owner count = [owner, [
    "ordered", Array.of_list (List.filter (fun i -> i < count) [0; count - 1; count / 2]);
    "ordered_two", [|0; count - 1|];
    "ordered_odd", [|count / 3; 0; count - 1|];
    "ordered_loop", [|0; count / 2; count - 1; count / 3|]]] in
  let geometry = fixture_groups geometry in
  List.fold_left add geometry
    (groups Group.Point points @ groups Group.Vertex vertices @ groups Group.Primitive prims)

let grid columns rows =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns ~rows ~size:6. () |> Rdk_test_support.get_ok in
  decorate ~points:(Geometry.point_count g) ~prims:(Geometry.primitive_count g)
    ~vertices:(Geometry.vertex_count g) g

let mesh ~points ~vertex_points ~offsets ~kinds =
  let topology = Topology.create_owned ~point_count:points ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> Rdk_test_support.get_string_ok in
  let positions = Packed.Float3.Private.of_owned_exn
    ~x:(Array.init points (fun i -> float (i mod 4) *. 0.75 +. float (i / 4) *. 0.1))
    ~y:(Array.init points (fun i -> float (i / 4) *. 0.9 +. float (i * i mod 3) *. 0.05))
    ~z:(Array.init points (fun i -> if i mod 5 = 0 then 0.3 else 0.)) in
  let g = Geometry.create ~positions ~topology () |> Rdk_test_support.get_string_ok in
  decorate ~points ~prims:(Geometry.primitive_count g) ~vertices:(Geometry.vertex_count g) g

let poly = Topology.Polygon and open_k = Topology.Open_polyline and closed_k = Topology.Closed_polyline
let inputs = List.map (fun (label, g) -> label, [g]) [
  "book", mesh ~points:6 ~vertex_points:[|0;1;2;1;0;3;0;1;4;4;5;0|] ~offsets:[|0;3;6;9;12|]
    ~kinds:[|poly; poly; poly; poly|];
  "polylines", mesh ~points:12 ~vertex_points:[|0;1;2;3;4;5;6;7;8;9;10;11;3;8|]
    ~offsets:[|0;6;12;14|] ~kinds:[|open_k; closed_k; open_k|];
  "strip", mesh ~points:10 ~vertex_points:[|0;1;5;4;1;2;6;5;2;3;7;6;4;5;9;8|]
    ~offsets:[|0;4;8;12;16|] ~kinds:[|poly; poly; poly; poly|];
  "grid", grid 4 3]

let parameters = [
  "points", [ch "owner" "Points"];
  "prims", [ch "owner" "Primitives"];
  "vertices-error", [ch "owner" "Vertices"];
  "base-two", [tx "base_group" "ordered_two"];
  "base-two/prims", [ch "owner" "Primitives"; tx "base_group" "ordered_two"];
  "base-odd", [tx "base_group" "ordered_odd"];
  "base-odd/prims", [ch "owner" "Primitives"; tx "base_group" "ordered_odd"];
  "base-loop", [tx "base_group" "ordered_loop"];
  "base-a", [tx "base_group" "a"];
  "base-dest", [tx "base_group" "dest_a"; ch "owner" "Primitives"];
  "base-missing", [tx "base_group" "nothing"];
  "base-padded", [tx "base_group" " ordered "];
  "base-unicode", [tx "base_group" "\195\169\231\140\171"];
  "name", [tx "name" "route"];
  "name/overwrite-base", [tx "name" "ordered"];
  "name/unicode", [tx "name" "\195\169\231\140\171x"];
  "name/blank-error", [tx "name" "  "];
  "close", [ch "ending" "Close path"];
  "close/two", [tx "base_group" "ordered_two"; ch "ending" "Close path"];
  "close/prims", [ch "owner" "Primitives"; ch "ending" "Close path"];
  "close/no-avoid", [ch "ending" "Close path"; bo "avoid_self_intersection" false];
  "close/loop", [tx "base_group" "ordered_loop"; ch "ending" "Close path"];
  "no-avoid", [bo "avoid_self_intersection" false];
  "no-avoid/prims", [ch "owner" "Primitives"; bo "avoid_self_intersection" false];
  "no-avoid/loop", [tx "base_group" "ordered_loop"; bo "avoid_self_intersection" false];
  "pairs", [ch "mode" "Start/end pairs"; tx "base_group" "ordered_two"];
  "pairs/prims", [ch "mode" "Start/end pairs"; tx "base_group" "ordered_two"; ch "owner" "Primitives"];
  "pairs/loop", [ch "mode" "Start/end pairs"; tx "base_group" "ordered_loop"];
  "pairs/loop/no-avoid", [ch "mode" "Start/end pairs"; tx "base_group" "ordered_loop"; bo "avoid_self_intersection" false];
  "pairs/loop/close", [ch "mode" "Start/end pairs"; tx "base_group" "ordered_loop"; ch "ending" "Close path"];
  "pairs/loop/close/no-avoid", [ch "mode" "Start/end pairs"; tx "base_group" "ordered_loop"; ch "ending" "Close path";
    bo "avoid_self_intersection" false];
  "pairs/loop/close/prims", [ch "mode" "Start/end pairs"; tx "base_group" "ordered_loop"; ch "ending" "Close path";
    ch "owner" "Primitives"];
  "pairs/odd-error", [ch "mode" "Start/end pairs"; tx "base_group" "ordered_odd"];
  "pairs/default-base", [ch "mode" "Start/end pairs"];
  "collision", [tx "collision_group" "dest_a"];
  "collision/prims", [tx "collision_group" "dest_a"; ch "owner" "Primitives"];
  "collision/padded", [tx "collision_group" " old_x "];
  "collision/close", [tx "collision_group" "dest_a"; ch "ending" "Close path"];
  "collision/pairs", [tx "collision_group" "old_x"; ch "mode" "Start/end pairs"; tx "base_group" "ordered_loop"];
  "collision/no-avoid", [tx "collision_group" "dest_a"; bo "avoid_self_intersection" false];
  "collision/missing", [tx "collision_group" "nothing"];
  "collision/blocks-base", [tx "collision_group" "a"; tx "base_group" "a"];
  "collision/blocks-base/prims", [tx "collision_group" "ordered"; ch "owner" "Primitives"];
  "contain", [tx "collision_group" "a"; bo "contain" true];
  "contain/other-base", [tx "collision_group" "dest_a"; bo "contain" true; tx "base_group" "dest_a"];
  "contain/prims", [tx "collision_group" "a"; bo "contain" true; ch "owner" "Primitives"; tx "base_group" "a"];
  "contain/close", [tx "collision_group" "a"; bo "contain" true; ch "ending" "Close path"; tx "base_group" "a"];
  "contain-without-collision-error", [bo "contain" true];
]
let cases = parameters
let bench () =
  let side = 1000 in
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:(side - 1) ~rows:(side - 1) ~size:8. ()
    |> Rdk_test_support.get_ok in
  let n = Geometry.point_count g in
  [ordered g Group.Point "ordered" [|0; n - 1|]], []
let () = register { key = "group_find_path"; native = Sop.Nodes.Group_find_path.factory; inputs;
  cases; ulps = 4; bench = Some bench }
