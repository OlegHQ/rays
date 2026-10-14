(* sop/uv_project: one geometry input. Besides the standard fixtures (flat, so cylinder/sphere hit
   their poles) the custom fixtures wrap a grid around the Y axis (a cell straddles the seam) and
   fold its rows into a sphere (poles collapse a whole row onto the axis), with groups and an
   existing "vec2" vertex attribute. Construction refusals are covered by the gate's own check. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param

let with_positions geometry f =
  let view = Packed.Float3.Private.view (Geometry.positions geometry) in
  let n = Array.length view.x in
  let x = Array.make n 0. and y = Array.make n 0. and z = Array.make n 0. in
  for i = 0 to n - 1 do
    let a, b, c = f view.x.(i) view.y.(i) view.z.(i) in x.(i) <- a; y.(i) <- b; z.(i) <- c
  done;
  let positions = Packed.Float3.of_owned ~x ~y ~z |> get_string_ok in
  Geometry.create ~positions ~topology:(Geometry.topology geometry) () |> get_string_ok

let pi = 4. *. atan 1.
let tube x y z = let lon = (x +. 2.) /. 4. *. 2. *. pi +. pi /. 4. in
  3. *. cos lon +. 0.5, y *. 0.75 +. z, 3. *. sin lon -. 0.25
let ball x y z = let lon = (x +. 2.) /. 4. *. 2. *. pi +. pi /. 4. and lat = y /. 2. *. pi /. 2. in
  2. *. cos lat *. cos lon, 2. *. sin lat +. z, 2. *. cos lat *. sin lon

let grid_of connectivity columns rows =
  Plane_generators.grid ~connectivity ~columns ~rows ~size:4. () |> get_ok

let with_uv geometry =
  let n = Geometry.vertex_count geometry in
  let plane scale = Array.init n (fun i -> float (i mod 7) *. scale) in
  Geometry.with_attribute (Attribute.create_owned ~owner:Attribute.Vertex ~name:"vec2"
    (Attribute.Float2 (Packed.Float2.of_owned ~x:(plane 0.25) ~y:(plane (-0.5)) |> get_string_ok))
    |> get_string_ok) geometry |> get_string_ok

let decorate g = with_uv (fixture_groups g)
let custom = List.map (fun (label, g) -> label, [g]) [
  "tube-quads", decorate (with_positions (grid_of Grid_quads 8 3) tube);
  "tube-triangles", decorate (with_positions (grid_of Grid_triangles 6 3) tube);
  "ball-quads", decorate (with_positions (grid_of Grid_quads 8 6) ball);
  "ball-triangles", decorate (with_positions (grid_of Grid_triangles 5 4) ball);
  "origin-on-point", decorate (with_positions (grid_of Grid_quads 4 4) (fun x y z -> x, y, z)) ]
let inputs = List.map (fun (l, gs) -> l, List.map with_uv gs) standard_inputs @ custom

let text name value = name, P.Text_value value
let num name value = name, P.Float_value value
let flag name value = name, P.Bool_value value
let choice value = "projection", P.Choice_value value
let vec3 prefix (x, y, z) = [num (prefix ^ "_x") x; num (prefix ^ "_y") y; num (prefix ^ "_z") z]
let cases =
  List.concat_map (fun projection ->
    List.map (fun (label, changes) -> projection ^ "/" ^ label, choice projection :: changes) ([
      "default", [];
      "origin", vec3 "origin" (0.5, -0.25, 0.75);
      "origin_center", vec3 "origin" (0., 0., 0.);
      "ranges", [num "u_min" (-1.5); num "u_max" 2.25; num "v_min" 0.5; num "v_max" (-3.)];
      "range_zero", [num "u_min" 1.; num "u_max" 1.];
      "no_fix_seams", [flag "fix_seams" false];
      "no_fix_poles", [flag "fix_poles" false];
      "no_fixes", [flag "fix_seams" false; flag "fix_poles" false];
      "group", [text "group" "a"];
      "group_padded", [text "group" " dest_a "; flag "fix_poles" false];
      "group_missing", [text "group" "nope"];
      "group_literal", [text "group" "literal *?[]^\\"];
      "existing_uv", [text "name" "vec2"; text "group" "a"];
      "existing_uv_full", [text "name" "vec2"];
      "other_name", [text "name" "map"];
      "blank_name", [text "name" "  "];
      "wrong_storage", [text "name" "float"];
      "wrong_storage_vec3", [text "name" "vec3"];
      "overflow", [num "u_max" 1e308; num "u_min" (-1e308)];
      "tiny_origin_far", vec3 "origin" (1e-300, 1e150, -1e150) ] @
      (match projection with
       | "Planar" -> [
           "u_v_axes", vec3 "planar_u" (1., 1., 0.) @ vec3 "planar_v" (0., 0.5, 2.);
           "u_axis_y", vec3 "planar_u" (0., 3., 0.) @ vec3 "planar_v" (1., 0., 0.);
           "parallel_axes", vec3 "planar_u" (1., 0., 0.) @ vec3 "planar_v" (-2., 0., 0.);
           "zero_axis", vec3 "planar_u" (0., 0., 0.);
           "nearly_parallel", vec3 "planar_v" (1., 1e-7, 0.);
           "ignored_cylinder_params", vec3 "axis" (0., 0., 0.) @ [num "height" 0.] ]
       | _ -> [
           "axis_x", vec3 "axis" (1., 0., 0.);
           "axis_tilted", vec3 "axis" (0.3, 1., -0.7) @ vec3 "seam" (1., 0.2, 0.);
           "seam_z", vec3 "seam" (0., 0., 1.);
           "seam_oblique", vec3 "seam" (1., 1., 1.);
           "seam_parallel", vec3 "seam" (0., 2., 0.);
           "axis_zero", vec3 "axis" (0., 0., 0.);
           "seam_zero", vec3 "seam" (0., 0., 0.);
           "ignored_planar_params", vec3 "planar_u" (0., 0., 0.);
           "tall", [num "height" 7.5];
           "short", [num "height" 0.01; num "v_min" (-1.)];
           "zero_height", [num "height" 0.] ])))
    ["Planar"; "Cylindrical"; "Spherical"]
let bench () =
  [with_positions (grid_of Grid_quads 700 700) ball], [choice "Spherical"; vec3 "origin" (0.1, 0.2, 0.3) |> List.hd]
let () = register { key = "uv_project"; native = Sop.Nodes.Uv_project.factory; inputs; cases; ulps = 4;
  bench = Some bench }
