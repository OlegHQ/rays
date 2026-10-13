(* sop/uv_sphere: zero-input generator over every connectivity, pole option, normals mode, UV and frame.
   Port_gate renders `:field value`, but vec3 groups (axis, radius, center, rotation) are called
   `:center [x y z]`; the gate renders them from the physical field names. *)
open Port_gate
module P = Param
let ch name v = name, P.Choice_value v
let fl name v = name, P.Float_value v
let it name v = name, P.Int_value v
let tx name v = name, P.Text_value v
let bl name v = name, P.Bool_value v
let vec3 = true
let v3 l = if vec3 then l else []
let small = [it "segments" 5; it "rings" 4]
let rot = [fl "rotation_x" 0.3; fl "rotation_y" (-0.7); fl "rotation_z" 1.1]
(* Native refuses these when the node is constructed; the Lisp node refuses them in `:validate`, which only
   runs at lowering, but Port_gate compares native construction errors with the checker alone. *)
let lowering = true
let l c = if lowering then c else []
let cases =
  List.concat_map (fun c -> List.concat_map (fun n -> List.concat_map (fun unique ->
    List.filter_map (fun tri ->
      if c = "Points" && n = "Vertex" && not lowering then None else Some (
      Printf.sprintf "%s/%s/unique=%b/tri=%b" c n unique tri,
      [ch "connectivity" c; ch "normals" n; bl "unique_points_per_pole" unique; bl "triangular_poles" tri] @ small
      @ v3 [fl "radius_x" 2.; fl "radius_y" 0.5; fl "radius_z" 1.5; fl "center_x" 1.; fl "center_y" (-2.)] @ v3 rot))
      [false; true]) [false; true]) ["None"; "Point"; "Vertex"])
    ["Triangles"; "Alternating triangles"; "Quads"; "Rows"; "Columns"; "Rows and columns"; "Points"]
  @ ["compatible_normals", [ch "normals" "Point"; tx "uv_attribute" ""];
     "compatible_normals_odd", [ch "normals" "Point"; tx "uv_attribute" ""; it "segments" 7; it "rings" 5];
     "default_small", small;
     "normals_auto", [ch "normals_mode" "Auto"; ch "normals" "None"] @ small;
     "uv_vertex", [tx "uv_attribute" "st"; ch "connectivity" "Quads"] @ small;
     "uv_points", [tx "uv_attribute" " st "; ch "connectivity" "Points"] @ small;
     "uv_blank", [tx "uv_attribute" "  "] @ small;
     "uniform_scale", [fl "uniform_scale" 2.5; ch "normals" "Vertex"] @ small;
     "base_radius", [fl "base_radius" 3.] @ small;
     "radius_x_auto", [ch "radius_x_mode" "Auto"; fl "base_radius" 3.] @ small;
     "radius_y_auto", [ch "radius_y_mode" "Auto"; fl "base_radius" 3.] @ small;
     "radius_z_auto", [ch "radius_z_mode" "Auto"; fl "base_radius" 3.] @ small;
     "minimum_segments_rings", [it "segments" 3; it "rings" 2; ch "connectivity" "Quads"];
     "minimum_quads_no_tri_poles", [it "segments" 3; it "rings" 2; ch "connectivity" "Quads"; bl "triangular_poles" false];
     "x_axis_orientation", [ch "orientation" "X axis"; ch "normals" "Vertex"] @ small;
     "z_axis_orientation", [ch "orientation" "Z axis"; ch "normals" "Vertex"] @ small]
  @ l ["uv_P", [tx "uv_attribute" "P"];
     "uv_N", [tx "uv_attribute" " N "];
     "zero_base_radius", [fl "base_radius" 0.];
     "zero_scale", [fl "uniform_scale" 0.];
     "point_vertex_normals_refused", [ch "connectivity" "Points"; ch "normals" "Vertex"];
     "huge_segments", [it "segments" 4611686018427387903];
     "huge_rings", [it "rings" 4611686018427387903];
     "cardinality_overflow", [it "segments" 100000000000; it "rings" 100000000000];
     "custom_axis_zero", [ch "orientation" "Custom axis"; fl "axis_x" 0.; fl "axis_y" 0.; fl "axis_z" 0.]]
  @ List.map (fun order -> "order_" ^ order, [ch "rotation_order" order; ch "orientation" "X axis"] @ small) ["XYZ"; "XZY"; "YXZ"; "YZX"; "ZXY"; "ZYX"]
  @ v3 (List.map (fun (l, c) -> l, c @ small)
    ["radii", [fl "radius_x" 2.; fl "radius_y" 0.5; fl "radius_z" 1.5; ch "normals" "Vertex"];
     "center", [fl "center_x" 1.5; fl "center_y" (-2.); fl "center_z" 0.25];
     "rotation", rot @ [ch "normals" "Vertex"];
     "rotation_orders", rot @ [ch "orientation" "X axis"; ch "rotation_order" "ZYX"];
     "custom_axis", [ch "orientation" "Custom axis"; fl "axis_x" 0.3; fl "axis_y" (-0.8); fl "axis_z" 0.5; ch "normals" "Vertex"];
     "custom_axis_x", [ch "orientation" "Custom axis"; fl "axis_x" 1.; fl "axis_y" 0.; fl "axis_z" 0.];
     "custom_axis_diagonal", [ch "orientation" "Custom axis"; fl "axis_x" 1.; fl "axis_y" 1.; fl "axis_z" 1.; ch "normals" "Vertex"];
     "custom_axis_tiny", [ch "orientation" "Custom axis"; fl "axis_x" 1e-300; fl "axis_y" 2e-300; fl "axis_z" 0.];
     "center_with_identity_orientation", [fl "center_y" 1.];
     "extreme_ratio", [fl "radius_x" 1e-200; fl "radius_y" 1.; fl "radius_z" 1e-200; ch "normals" "Vertex"];
     "extreme_ratio_pole", [fl "radius_x" 1e-300; fl "radius_y" 1e300; fl "radius_z" 1e-300; ch "normals" "Vertex"];
     "overflow_center", [fl "center_x" 1.7e308; fl "radius_x" 1e308; ch "orientation" "X axis"]]
   @ l ["scaled_radius_overflow", [fl "radius_x" 1e300; fl "uniform_scale" 1e10]])
(* 1000 segments x 1000 rings: 999,000 interior points. *)
let bench () = [], [it "segments" 1000; it "rings" 1000; ch "normals" "Vertex"]
let () = register { key = "uv_sphere"; native = Sop.Nodes.Uv_sphere.factory; inputs = no_input; cases; ulps = 4; bench = Some bench }
