(* sop/torus: zero-input generator (pending draft). Every connectivity x normals, open and wrapped sweeps,
   reversed spans, U and V caps, UVs, orientations, rotation orders, overflow and refusal paths. *)
open Port_gate
module P = Param
let ch name v = name, P.Choice_value v
let fl name v = name, P.Float_value v
let it name v = name, P.Int_value v
let tx name v = name, P.Text_value v
let bl name v = name, P.Bool_value v
let connectivities = ["Triangles"; "Alternating triangles"; "Quads"; "Rows"; "Columns"; "Rows and columns"; "Points"]
let polygons = ["Triangles"; "Alternating triangles"; "Quads"]
let rot = [fl "rotation_x" 0.3; fl "rotation_y" (-0.7); fl "rotation_z" 1.1]
let small = [it "rows" 5; it "columns" 4]
let open_sweep = [bl "u_wrap" false; bl "v_wrap" false; fl "u_end" 4.; fl "v_end" 5.]
let cases =
  List.concat_map (fun c -> List.concat_map (fun n ->
    let base = [ch "connectivity" c; ch "normals" n] @ small in
    [Printf.sprintf "%s/%s" c n, base;
     Printf.sprintf "%s/%s/open" c n, base @ open_sweep;
     Printf.sprintf "%s/%s/open_uv_size" c n, base @ open_sweep @ [fl "major_radius" 2.; fl "minor_radius" 0.5; fl "uniform_scale" 1.5];
     Printf.sprintf "%s/%s/u_open" c n, base @ [bl "u_wrap" false; fl "u_end" 3.];
     Printf.sprintf "%s/%s/v_open" c n, base @ [bl "v_wrap" false; fl "v_start" 1.; fl "v_end" 4.5];
     Printf.sprintf "%s/%s/reversed_u" c n, base @ [fl "u_start" 5.; fl "u_end" 1.; bl "u_wrap" false];
     Printf.sprintf "%s/%s/reversed_both" c n, base @ [fl "u_start" 5.; fl "u_end" 1.; fl "v_start" 4.; fl "v_end" 0.5];
     Printf.sprintf "%s/%s/reversed_v" c n, base @ [fl "v_start" 5.; fl "v_end" 1.; bl "v_wrap" false]])
    ["None"; "Point"; "Vertex"]) connectivities
  @ List.concat_map (fun c -> [
      c ^ "/uv_off", [ch "connectivity" c; tx "uv_attribute" " "] @ small;
      c ^ "/uv_named", [ch "connectivity" c; tx "uv_attribute" " st "; ch "normals" "Vertex"] @ small @ open_sweep;
      c ^ "/auto", [ch "connectivity" c; ch "normals_mode" "Auto"; ch "normals" "None"] @ small;
      c ^ "/u_caps", [ch "connectivity" c; bl "u_wrap" false; bl "u_end_caps" true; ch "normals" "Vertex"; tx "uv_attribute" "uv"; fl "u_end" 4.] @ small;
      c ^ "/u_caps_reversed", [ch "connectivity" c; bl "u_wrap" false; bl "u_end_caps" true; ch "normals" "Vertex"; tx "uv_attribute" "uv";
        fl "u_start" 4.; fl "u_end" 0.5] @ small;
      c ^ "/v_cap", [ch "connectivity" c; bl "v_wrap" false; bl "v_end_cap" true; ch "normals" "Vertex"; tx "uv_attribute" "uv"; fl "v_end" 4.] @ small;
      c ^ "/v_cap_reversed", [ch "connectivity" c; bl "v_wrap" false; bl "v_end_cap" true; ch "normals" "Vertex"; tx "uv_attribute" "uv";
        fl "v_start" 4.; fl "v_end" 0.5; fl "u_start" 5.; fl "u_end" 1.] @ small;
      c ^ "/both_caps", [ch "connectivity" c; bl "u_wrap" false; bl "v_wrap" false; bl "u_end_caps" true; bl "v_end_cap" true;
        ch "normals" "Vertex"; tx "uv_attribute" "uv"; fl "u_end" 4.; fl "v_end" 5.] @ small @ rot]) polygons
  @ List.map (fun o -> "orientation_" ^ o, [ch "orientation" o] @ small @ rot) ["X axis"; "Y axis"; "Z axis"]
  @ List.map (fun o -> "order_" ^ o, [ch "rotation_order" o] @ small @ rot) ["XYZ"; "XZY"; "YXZ"; "YZX"; "ZXY"; "ZYX"]
  @ List.map (fun (axis, label) -> "axis_" ^ label, [ch "orientation" "Custom axis"] @ small @ axis @ rot)
      [[fl "axis_x" 1.; fl "axis_y" 0.; fl "axis_z" 0.], "x"; [fl "axis_x" 0.; fl "axis_y" (-3.); fl "axis_z" 0.], "neg_y";
       [fl "axis_x" 1.; fl "axis_y" 1.; fl "axis_z" 1.], "diagonal"; [fl "axis_x" 5.; fl "axis_y" 4.; fl "axis_z" 4.5], "scaled"]
  @ ["default_size", [];
     "center", small @ [fl "center_x" 1.5; fl "center_y" (-2.); fl "center_z" 0.25];
     "minimum_counts", [it "rows" 3; it "columns" 3];
     "open_minimum_counts", [it "rows" 2; it "columns" 2; bl "u_wrap" false; bl "v_wrap" false];
     "radius_tiny", small @ [fl "major_radius" 1e-300; fl "minor_radius" 1e-300];
     "radius_huge", small @ [fl "major_radius" 1e300; fl "minor_radius" 1e300; fl "center_x" 1.5e308];
     "overflow_ring", small @ [fl "major_radius" 1.7e308; fl "minor_radius" 1.7e308];
     "overflow_center", small @ [fl "center_x" 1.7976931348623157e308; fl "major_radius" 1e308];
     "huge_rows", [it "rows" 4611686018427387903];
     "huge_rows_pair", [it "rows" 3000000000; it "columns" 3000000000];
     "huge_rows_columns_mode", [ch "connectivity" "Rows and columns"; it "rows" 2000000000000; it "columns" 2000000000000];
     "invalid_rows_wrapped", [it "rows" 2];
     "invalid_columns_wrapped", [it "columns" 2];
     "invalid_radius_zero", [fl "minor_radius" 0.];
     "invalid_scale_overflow", [fl "major_radius" 1e300; fl "uniform_scale" 1e300];
     "invalid_zero_span", [fl "u_end" 0.];
     "invalid_zero_v_span", [fl "v_start" 6.283185307179586];
     "invalid_uv_P", [tx "uv_attribute" " P "];
     "invalid_uv_N", [tx "uv_attribute" "N"];
     "invalid_vertex_points", [ch "connectivity" "Points"; ch "normals" "Vertex"];
     "points_auto_vertex", [ch "connectivity" "Points"; ch "normals_mode" "Auto"; ch "normals" "Vertex"];
     "invalid_u_caps_wrapped", [bl "u_end_caps" true];
     "invalid_u_caps_rows", [ch "connectivity" "Rows"; bl "u_end_caps" true; bl "u_wrap" false];
     "invalid_v_cap_wrapped", [bl "v_end_cap" true];
     "invalid_v_cap_rows", [ch "connectivity" "Rows"; bl "v_end_cap" true; bl "v_wrap" false];
     "invalid_v_cap_coincident", [bl "v_end_cap" true; bl "v_wrap" false; fl "v_start" 0.; fl "v_end" 6.283185307179586];
     "invalid_custom_axis_zero", [ch "orientation" "Custom axis"; fl "axis_x" 0.; fl "axis_y" 0.; fl "axis_z" 0.]]
let bench () = [], [it "rows" 1000; it "columns" 1000; ch "connectivity" "Quads"; ch "normals" "Vertex"; tx "uv_attribute" "uv"]
let () = register { key = "torus"; native = Sop.Nodes.Torus.factory; inputs = no_input; cases; ulps = 4; bench = Some bench }
