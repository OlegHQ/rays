(* sop/platonic: zero-input table-driven generator (pending draft). Every solid x normals mode, every orientation,
   rotation order, center, radius, face-group prefixes and the overflow / refusal paths. *)
open Port_gate
module P = Param
let ch name v = name, P.Choice_value v
let fl name v = name, P.Float_value v
let tx name v = name, P.Text_value v
let kinds = ["Tetrahedron"; "Cube"; "Octahedron"; "Icosahedron"; "Dodecahedron"; "Soccer ball"]
let rot = [fl "rotation_x" 0.3; fl "rotation_y" (-0.7); fl "rotation_z" 1.1]
let cases =
  List.concat_map (fun kind -> List.map (fun normals ->
    Printf.sprintf "%s/%s" kind normals, [ch "kind" kind; ch "normals" normals]) ["None"; "Point"; "Vertex"]) kinds
  @ List.concat_map (fun kind -> [
      kind ^ "/transform", [ch "kind" kind; fl "radius" 2.5; fl "center_x" 1.5; fl "center_y" (-2.); fl "center_z" 0.25] @ rot;
      kind ^ "/transform_point", [ch "kind" kind; ch "normals" "Point"; fl "radius" 0.5; fl "center_x" 1.5] @ rot;
      kind ^ "/groups", [ch "kind" kind; tx "face_groups" " g "];
      kind ^ "/axis", [ch "kind" kind; ch "orientation" "Custom axis"; fl "axis_x" 0.3; fl "axis_y" (-0.2); fl "axis_z" 0.9]]) kinds
  @ List.map (fun o -> "orientation_" ^ o, [ch "orientation" o; ch "kind" "Icosahedron"]) ["X axis"; "Y axis"; "Z axis"]
  @ List.map (fun o -> "order_" ^ o, [ch "rotation_order" o; ch "kind" "Cube"] @ rot) ["XYZ"; "XZY"; "YXZ"; "YZX"; "ZXY"; "ZYX"]
  @ List.map (fun (axis, label) -> "axis_" ^ label, [ch "orientation" "Custom axis"; ch "kind" "Octahedron"] @ axis @ rot)
      [[fl "axis_x" 1.; fl "axis_y" 0.; fl "axis_z" 0.], "x"; [fl "axis_x" 0.; fl "axis_y" 0.; fl "axis_z" 1.], "z";
       [fl "axis_x" 0.; fl "axis_y" (-3.); fl "axis_z" 0.], "neg_y"; [fl "axis_x" 1.; fl "axis_y" 1.; fl "axis_z" 1.], "diagonal";
       [fl "axis_x" 5.; fl "axis_y" 4.; fl "axis_z" 4.5], "scaled"]
  @ ["custom_axis_unused_zero", [ch "orientation" "Y axis"; fl "axis_x" 0.; fl "axis_y" 0.; fl "axis_z" 0.];
     "face_group_blank", [tx "face_groups" "  "];
     "face_group_cube", [ch "kind" "Cube"; tx "face_groups" "f"];
     "radius_tiny", [fl "radius" 1e-300; ch "kind" "Cube"];
     "radius_huge", [fl "radius" 1e300; ch "kind" "Cube"; fl "center_x" 1.5e308];
     "overflow_center", [fl "center_x" 1.7976931348623157e308; fl "radius" 1e308];
     "overflow_radius", [fl "radius" 1.7976931348623157e308; fl "center_y" 1.7976931348623157e308; ch "kind" "Tetrahedron"];
     "invalid_radius_zero", [fl "radius" 0.];
     "invalid_radius_negative", [fl "radius" (-1.)];
     "invalid_custom_axis_zero", [ch "orientation" "Custom axis"; fl "axis_x" 0.; fl "axis_y" 0.; fl "axis_z" 0.]]
let () = register { key = "platonic"; native = Sop.Nodes.Platonic.factory; inputs = no_input;
  cases; ulps = 4; bench = None (* at most 180 vertices: nothing to time at 1,000,000 *) }
