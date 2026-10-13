(* sop/uv_auto_seam: one geometry input. Fixtures are polygon-only (a selected polyline, or a degenerate
   polygon under the default whole-geometry selection, is a native error and the gate's cache check needs
   the default cook to succeed): empty, single point, flat grid, a wavy grid and a set of quads with a
   non-manifold edge, an interior fold and a free quad, all carrying the fixture groups and attributes.
   The wavy grid uses sines so no two neighbouring faces are exactly coplanar (angle 0 would otherwise
   compare equal normals against cos 0, a rounding tie rather than a semantic case).
   Dropped: the degenerate-polygon and selected-polyline error branches, for the default-cook reason. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let fl name x = name, P.Float_value x
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b

let wavy geometry =
  let n = Geometry.point_count geometry in
  let plane f count = Array.init count (fun i -> 2.5 *. f (float i)) in
  Geometry.with_positions (Packed.Float3.of_owned ~x:(plane (fun i -> sin (1.3 *. i +. 0.2)) n)
    ~y:(plane (fun i -> cos (0.9 *. i +. 1.1)) n) ~z:(plane (fun i -> sin (2.7 *. i +. 0.5)) n)
    |> get_string_ok) geometry |> get_string_ok
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:6 ~rows:6 ~size:4. () |> get_ok
let quads () =
  let xs = [|0.;1.;1.;0.; 0.;1.; 1.;0.; 1.;0.; 5.;6.;6.;5.|]
  and ys = [|0.;0.;1.;1.; -1.;-1.; 0.2;0.2; 1.5;1.5; 5.;5.;6.;6.|]
  and zs = [|0.;0.;0.;0.; 0.2;-0.1; 1.;1.; 0.8;0.8; 0.;0.;0.;0.|] in
  let topology = Topology.create_owned ~point_count:14
    ~vertex_points:[|0;1;2;3; 1;0;4;5; 0;1;6;7; 3;2;8;9; 10;11;12;13|]
    ~primitive_offsets:[|0;4;8;12;16;20|]
    ~primitive_kinds:(Array.make 5 Topology.Polygon) |> get_string_ok in
  Geometry.create ~positions:(Packed.Float3.of_owned ~x:xs ~y:ys ~z:zs |> get_string_ok) ~topology ()
  |> get_string_ok
let inputs = standard_inputs |> List.filter (fun (label, _) -> label <> "mixed") |> fun standard ->
  standard @ List.map (fun (label, g) -> label, [g]) [
    "wavy grid", fixture_attributes (fixture_groups (wavy (small_grid ())));
    "quads", fixture_attributes (fixture_groups (quads ())) ]

let cases =
  List.concat_map (fun angle -> List.concat_map (fun boundaries -> List.map (fun manifold ->
    Printf.sprintf "angle %g/boundaries %b/non-manifold %b" angle boundaries manifold,
    [fl "angle" angle; bo "include_boundaries" boundaries; bo "include_non_manifold" manifold])
    [true; false]) [true; false]) [0.; 0.3; 1.0471975511965976; 3.141592653589793]
  @ List.concat_map (fun group -> List.map (fun boundaries ->
    Printf.sprintf "group %S/boundaries %b" group boundaries,
    [tx "group" group; bo "include_boundaries" boundaries; fl "angle" 0.8])
    [true; false]) ["a"; " old_x "; "nothing"]
  @ [ "name", [tx "name" "cuts"];
      "name existing", [tx "name" "a"];
      "name padded", [tx "name" " cuts "];
      "partition", [tx "partition_attribute" "integer"];
      "partition group", [tx "partition_attribute" " integer "; tx "group" "a"];
      "partition missing", [tx "partition_attribute" "absent"];
      "partition wrong type", [tx "partition_attribute" "float"];
      "partition wrong owner", [tx "partition_attribute" "vec2"];
      "uv", [tx "existing_uv" "vec2"];
      "uv wide", [tx "existing_uv" "vec2"; fl "uv_tolerance" 0.01; fl "angle" 3.141592653589793];
      "uv zero tolerance", [tx "existing_uv" " vec2 "; fl "uv_tolerance" 0.; fl "angle" 3.141592653589793];
      "uv group", [tx "existing_uv" "vec2"; tx "group" "a"];
      "uv missing", [tx "existing_uv" "absent"];
      "uv wrong type", [tx "existing_uv" "vec3"];
      "uv wrong owner", [tx "existing_uv" "float"];
      "island", [tx "island_attribute" "isl"];
      "island flat", [tx "island_attribute" "isl"; fl "angle" 3.141592653589793];
      "island group", [tx "island_attribute" "isl"; tx "group" "a"; fl "angle" 3.141592653589793];
      "island existing", [tx "island_attribute" "integer"; tx "group" "a"; fl "angle" 3.141592653589793];
      "island existing all", [tx "island_attribute" "integer"; fl "angle" 0.5];
      "island wrong type", [tx "island_attribute" "float"];
      "island with cuts", [tx "island_attribute" "isl"; tx "partition_attribute" "integer"; tx "existing_uv" "vec2";
                           fl "angle" 3.141592653589793; bo "include_boundaries" false];
      "all options", [tx "name" "s"; tx "group" "old_x"; fl "angle" 2.0; bo "include_non_manifold" false;
                      tx "partition_attribute" "integer"; tx "existing_uv" "vec2"; fl "uv_tolerance" 0.001;
                      tx "island_attribute" "isl2"] ]

let bench () =
  let n = 1000 in
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:n ~rows:n ~size:8. () |> get_ok in
  [g], []
let () = register { key = "uv_auto_seam"; native = Sop.Nodes.Uv_auto_seam.factory; inputs; cases; ulps = 4; bench = Some bench }
