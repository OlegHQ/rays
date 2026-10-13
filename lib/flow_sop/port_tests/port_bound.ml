(* sop/bound: one geometry input (pending draft). Box and sphere shapes, every group owner, padding, outputs. *)
open Port_gate
module P = Param
let ch name v = name, P.Choice_value v
let fl name v = name, P.Float_value v
let it name v = name, P.Int_value v
let tx name v = name, P.Text_value v
(* A fixture needs a 3D extent: with the standard flat fixtures every default cook (box output needs
   positive extent on every axis) is an error, and the gate's cache check cannot hold for a cook that
   fails. So the "empty", "single" and flat standard fixtures are replaced by two non-degenerate ones
   (their error paths are covered by cases: empty/missing group, collinear selection). *)
let spread geometry =
  let n = Rdk.Geometry.point_count geometry in
  let x = Array.init n (fun i -> float (i mod 7) *. 0.5 -. 1.25 +. float i *. 0.01)
  and y = Array.init n (fun i -> float ((i * 5) mod 11) *. 0.25 -. 0.5)
  and z = Array.init n (fun i -> if i mod 3 = 0 then -0. else float (i mod 5) *. 0.75 +. 0.125) in
  let positions = Rdk.Packed.Float3.of_owned ~x ~y ~z |> Rdk_test_support.get_string_ok in
  Rdk.Geometry.with_positions positions geometry |> Rdk_test_support.get_string_ok
let empty_group geometry =
  Rdk.Geometry.with_group (Rdk.Group.init ~owner:Rdk.Group.Point ~name:"none"
    (Rdk.Geometry.point_count geometry) (fun _ -> false)) geometry |> Rdk_test_support.get_string_ok
let inputs = List.map (fun (label, g) -> label, [empty_group (spread g)]) [
  "mixed", fixture_attributes (fixture_groups (polygon_polyline ()));
  "grid4225", fixture_groups (grid ())]
let pad = [fl "lower_x" 0.25; fl "lower_y" 0.5; fl "lower_z" 0.125; fl "upper_x" 1.; fl "upper_y" 0.75; fl "upper_z" 2.]
let outputs = [tx "bounds_group" " hull "; tx "center_attribute" " c "; tx "radii_attribute" "r"]
let cases =
  List.concat_map (fun owner -> List.concat_map (fun (shape, extra) ->
    List.map (fun group -> Printf.sprintf "%s/%s/%S" owner shape group,
      [ch "group_owner" owner; tx "group" group; ch "shape" shape] @ extra)
      ["a"; " dest_a "; "missing"; ""])
    ["Box", [it "divisions_x" 2; it "divisions_y" 3; it "divisions_z" 4]; "Sphere", [it "segments" 7; it "rings" 5]])
    ["Point"; "Vertex"; "Primitive"; "Edge"]
  @ ["box_padding", pad; "box_outputs", outputs; "box_padding_outputs", pad @ outputs;
     "box_divisions", [it "divisions_x" 5; it "divisions_y" 1; it "divisions_z" 2];
     "box_thin_axis", [it "divisions_x" 3; it "divisions_y" 3; it "divisions_z" 3] @ outputs;
     "sphere", [ch "shape" "Sphere"];
     "sphere_padding", ch "shape" "Sphere" :: pad;
     "sphere_outputs", ch "shape" "Sphere" :: outputs;
     "sphere_min_radius", [ch "shape" "Sphere"; fl "minimum_radius" 100.];
     "sphere_min_radius_padding", ch "shape" "Sphere" :: fl "minimum_radius" 3. :: pad;
     "sphere_resolution", [ch "shape" "Sphere"; it "segments" 13; it "rings" 9];
     "group_P_is_fine", [tx "bounds_group" "P"];
     "center_attribute_N", [tx "center_attribute" "N"];
     "empty_group", [tx "group" "none"];
     "empty_group_vertex", [ch "group_owner" "Vertex"; tx "group" "none"];
     "huge_divisions", [it "divisions_x" 4611686018427387903];
     "huge_divisions_pair", [it "divisions_x" 3000000000; it "divisions_y" 3000000000];
     "huge_divisions_cells", [it "divisions_x" 2000000000000; it "divisions_y" 2000000000000];
     "padding_overflow", [fl "upper_x" 1.7e308; fl "lower_x" 1.7e308; fl "upper_y" 1e308];
     "sphere_padding_overflow", [ch "shape" "Sphere"; fl "upper_x" 1.7e308; fl "lower_x" 1.7e308];
     "invalid_negative_pad", [fl "lower_x" (-1.)];
     "invalid_center_P", [tx "center_attribute" " P "];
     "invalid_radii_P", [tx "radii_attribute" "P"];
     "invalid_same_names", [tx "center_attribute" "x"; tx "radii_attribute" " x "];
     "blank_names", [tx "center_attribute" "  "; tx "radii_attribute" "\t"; tx "bounds_group" " "]]
let bench () =
  [spread (points 1_000_000)], [ch "shape" "Box"; it "divisions_x" 2; tx "center_attribute" "c"]
let () = register { key = "bound"; native = Sop.Nodes.Bound.factory; inputs;
  cases; ulps = 4; bench = Some bench }
