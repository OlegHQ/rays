(* ulps = 16, not 4: with a rotated custom axis a point normal component is a sum of three products of
   magnitude about 0.2 that cancels to about 0.014, so the one-ulp (of the terms) difference in where the
   native arm64 code fuses the multiply-adds shows as 8 ulps of the result. Every other case is within 4.
   sop/tube: zero-input generator (pending draft). Every connectivity, normals mode, tips, caps, UVs, cap group,
   orientations, rotation orders, overflow and refusal paths. *)
open Port_gate
module P = Param
let ch name v = name, P.Choice_value v
let fl name v = name, P.Float_value v
let it name v = name, P.Int_value v
let tx name v = name, P.Text_value v
let bl name v = name, P.Bool_value v
let connectivities = ["Triangles"; "Alternating triangles"; "Quads"; "Rows"; "Columns"; "Rows and columns"; "Points"]
let polygon c = List.mem c ["Triangles"; "Alternating triangles"; "Quads"]
let rot = [fl "rotation_x" 0.3; fl "rotation_y" (-0.7); fl "rotation_z" 1.1]
let size = [fl "top_radius" 0.5; fl "bottom_radius" 1.5; fl "height" 3.]
let cases =
  List.concat_map (fun c -> List.concat_map (fun n ->
    let base = [ch "connectivity" c; ch "normals" n; it "rows" 4; it "columns" 5; bl "end_caps" (polygon c)] in
    [Printf.sprintf "%s/%s" c n, base @ (if n = "Vertex" && c = "Points" then [] else []);
     Printf.sprintf "%s/%s/size" c n, base @ size @ [tx "uv_attribute" ""];
     Printf.sprintf "%s/%s/tip_bottom" c n, base @ [fl "bottom_radius" 0.];
     Printf.sprintf "%s/%s/tip_top" c n, base @ [fl "top_radius" 0.; fl "bottom_radius" 2.]]) ["None"; "Point"; "Vertex"])
    connectivities
  @ List.concat_map (fun c -> List.concat_map (fun (label, extra) ->
      [Printf.sprintf "%s/%s" c label, [ch "connectivity" c; it "rows" 3; it "columns" 6] @ extra])
      ["caps_default", [];
       "caps_consolidated", [bl "consolidate_cap_points" true];
       "caps_tip_bottom", [fl "bottom_radius" 0.];
       "caps_tip_top_consolidated", [fl "top_radius" 0.; bl "consolidate_cap_points" true];
       "caps_tip_top", [fl "top_radius" 0.];
       "no_caps", [bl "end_caps" false; tx "cap_group" ""];
       "cap_group", [tx "cap_group" " lids "];
       "uv_name", [tx "uv_attribute" " st "];
       "uv_off", [tx "uv_attribute" " "];
       "auto_normals", [ch "normals_mode" "Auto"; ch "normals" "None"];
       "sized", size;
       "scale", [fl "radius_scale" 2.5; fl "top_radius" 0.4]]) ["Triangles"; "Alternating triangles"; "Quads"]
  @ List.map (fun c -> "tall_grid_" ^ c, [ch "connectivity" c; it "rows" 5; it "columns" 3] @ size) ["Triangles"; "Alternating triangles"; "Quads"]
  @ List.map (fun o -> "orientation_" ^ o, [ch "orientation" o; it "columns" 7] @ rot) ["X axis"; "Y axis"; "Z axis"]
  @ List.map (fun o -> "order_" ^ o, [ch "rotation_order" o; it "columns" 4] @ rot) ["XYZ"; "XZY"; "YXZ"; "YZX"; "ZXY"; "ZYX"]
  @ List.map (fun (axis, label) -> "axis_" ^ label, [ch "orientation" "Custom axis"; it "columns" 5] @ axis @ rot)
      [[fl "axis_x" 1.; fl "axis_y" 0.; fl "axis_z" 0.], "x"; [fl "axis_x" 0.; fl "axis_y" (-3.); fl "axis_z" 0.], "neg_y";
       [fl "axis_x" 1.; fl "axis_y" 1.; fl "axis_z" 1.], "diagonal"; [fl "axis_x" 5.; fl "axis_y" 4.; fl "axis_z" 4.5], "scaled"]
  @ ["center", [fl "center_x" 1.5; fl "center_y" (-2.); fl "center_z" 0.25];
     "center_rotation_vertex", [fl "center_x" 1.5; ch "normals" "Vertex"; it "rows" 3] @ rot;
     "points_uv", [ch "connectivity" "Points"; bl "end_caps" false; tx "uv_attribute" "uv"; fl "bottom_radius" 0.];
     "rows_uv_tip", [ch "connectivity" "Rows"; bl "end_caps" false; tx "uv_attribute" "uv"; fl "top_radius" 0.; ch "normals" "Vertex"];
     "columns_uv_tip", [ch "connectivity" "Columns"; bl "end_caps" false; tx "uv_attribute" "uv"; fl "bottom_radius" 0.; it "rows" 4; ch "normals" "Vertex"];
     "rows_columns_uv", [ch "connectivity" "Rows and columns"; bl "end_caps" false; tx "uv_attribute" "uv"; it "rows" 4];
     "radius_tiny", [fl "top_radius" 1e-300; fl "bottom_radius" 1e-300];
     "radius_huge", [fl "top_radius" 1e300; fl "center_x" 1.5e308];
     "overflow_center", [fl "center_x" 1.7976931348623157e308; fl "top_radius" 1e308; fl "height" 1e308];
     "overflow_height", [fl "height" 1.7976931348623157e308; fl "center_z" 1.7e308; ch "orientation" "Z axis"];
     "huge_rows", [it "rows" 4611686018427387903];
     "huge_rows_pair", [it "rows" 3000000000; it "columns" 3000000000];
     "huge_columns_rows_mode", [ch "connectivity" "Rows and columns"; bl "end_caps" false; it "rows" 2000000000000; it "columns" 2000000000000];
     "invalid_radii_zero", [fl "top_radius" 0.; fl "bottom_radius" 0.];
     "invalid_radius_scale_zero", [fl "radius_scale" 0.];
     "invalid_height_zero", [fl "height" 0.];
     "invalid_scale_overflow", [fl "top_radius" 1e300; fl "radius_scale" 1e300];
     "invalid_uv_P", [tx "uv_attribute" " P "];
     "invalid_uv_N", [tx "uv_attribute" "N"];
     "invalid_vertex_points", [ch "connectivity" "Points"; ch "normals" "Vertex"; bl "end_caps" false];
     "points_auto_vertex", [ch "connectivity" "Points"; ch "normals_mode" "Auto"; ch "normals" "Vertex"; bl "end_caps" false];
     "invalid_caps_rows", [ch "connectivity" "Rows"];
     "invalid_cap_group_no_caps", [bl "end_caps" false];
     "invalid_custom_axis_zero", [ch "orientation" "Custom axis"; fl "axis_x" 0.; fl "axis_y" 0.; fl "axis_z" 0.]]
let bench () = [], [it "rows" 400; it "columns" 1200; ch "connectivity" "Quads"; ch "normals" "Vertex"; tx "uv_attribute" "uv"]
let () = register { key = "tube"; native = Sop.Nodes.Tube.factory; inputs = no_input; cases; ulps = 16; bench = Some bench }
