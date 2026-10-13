(* sop/box: zero-input generator, every connectivity, normals mode, consolidation, transform, UV and face groups.
   Port_gate renders a change as `:field value`, but a vec3 group (size, center, rotation) is called as
   `:center [x y z]`, so the gate cannot vary those components. The gate renders vec3 groups from their physical field names, so the cases always run. *)
open Port_gate
module P = Param
let ch name v = name, P.Choice_value v
let fl name v = name, P.Float_value v
let it name v = name, P.Int_value v
let tx name v = name, P.Text_value v
let bl name v = name, P.Bool_value v
let vec3 = true
let v3 l = if vec3 then l else []
let divs = [it "x_divisions" 2; it "y_divisions" 3; it "z_divisions" 4]
let rot = [fl "rotation_x" 0.3; fl "rotation_y" (-0.7); fl "rotation_z" 1.1]
let transform = [fl "center_x" 1.5; fl "center_y" (-2.); fl "center_z" 0.25] @ rot
let cases =
  List.concat_map (fun c -> List.concat_map (fun n -> List.map (fun consolidate ->
    Printf.sprintf "%s/%s/%b" c n consolidate,
    [ch "connectivity" c; ch "normals" n; bl "consolidate_points" consolidate] @ divs @ v3 transform)
    [false; true]) ["Auto"; "None"; "Point"; "Vertex"])
    ["Triangles"; "Quads"; "Surface points"; "Lattice points"]
  @ ["fast_path_triangles_point", [ch "connectivity" "Triangles"; ch "normals" "Point"];
     "fast_path_triangles_none", [ch "connectivity" "Triangles"; ch "normals" "None"];
     "fast_path_triangles_vertex", [ch "connectivity" "Triangles"; ch "normals" "Vertex"];
     "quads_point_default_size", [ch "normals" "Point"];
     "uniform_scale", [fl "uniform_scale" 2.5; ch "connectivity" "Triangles"];
     "uv", [tx "uv_attribute" "uv"] @ divs;
     "uv_trimmed_triangles", [tx "uv_attribute" " st "; ch "connectivity" "Triangles"] @ divs;
     "uv_blank", [tx "uv_attribute" " \t "];
     "uv_P", [tx "uv_attribute" " P "];
     "uv_N", [tx "uv_attribute" "N"];
     "uv_points", [tx "uv_attribute" "uv"; ch "connectivity" "Surface points"];
     "groups", [tx "face_groups" "face"] @ divs;
     "groups_triangles", [tx "face_groups" " side "; ch "connectivity" "Triangles"] @ divs;
     "groups_blank", [tx "face_groups" "  "];
     "groups_points", [tx "face_groups" "face"; ch "connectivity" "Lattice points"];
     "uv_groups_normals_consolidated", [tx "uv_attribute" "uv"; tx "face_groups" "g"; bl "consolidate_points" true] @ divs;
     "vertex_normals_points", [ch "connectivity" "Surface points"; ch "normals" "Vertex"];
     "lattice_point_normals", [ch "connectivity" "Lattice points"; ch "normals" "Point"];
     "thin_divisions", [it "x_divisions" 1; it "y_divisions" 5; it "z_divisions" 1; bl "consolidate_points" true];
     "single_row", [it "x_divisions" 7; it "y_divisions" 1; it "z_divisions" 1];
     "max_divisions", [it "x_divisions" 4611686018427387903];
     "huge_divisions", [it "x_divisions" 4611686018427387900; it "y_divisions" 2];
     "huge_divisions_points", [it "x_divisions" 3000000000; it "y_divisions" 3000000000; ch "connectivity" "Surface points"];
     "huge_topology", [it "x_divisions" 100000000; it "y_divisions" 100000000; it "z_divisions" 1; ch "connectivity" "Quads"]]
  @ v3 (["fast_path_triangles_auto_size", [ch "connectivity" "Triangles"; ch "normals" "Auto";
       fl "size_x" 2.; fl "size_y" 0.5; fl "size_z" 3.];
     "size", [fl "size_x" 2.; fl "size_y" 0.5; fl "size_z" 3.];
     "center", [fl "center_x" 1.5; fl "center_y" (-2.); fl "center_z" 0.25];
     "rotation_triangles_point", [ch "connectivity" "Triangles"; ch "normals" "Point"] @ rot;
     "zero_size", [fl "size_y" 0.];
     "huge_uniform_scale", [fl "size_x" 1e300; fl "uniform_scale" 1e10];
     "overflow_center", [fl "size_x" 1e308; fl "center_x" 1.7e308];
     "overflow_center_lattice", [fl "size_x" 1e308; fl "center_x" 1.7e308; ch "connectivity" "Lattice points"];
     "overflow_center_consolidated", [fl "size_x" 1e308; fl "center_x" 1.7e308; bl "consolidate_points" true];
     "overflow_rotated", [fl "size_x" 1.7e308; fl "size_y" 1.7e308; fl "size_z" 1.7e308; fl "rotation_x" 0.5];
     "overflow_interior_product", [fl "size_x" 1.7e308; it "x_divisions" 3]]
   @ List.map (fun order -> "order_" ^ order, [ch "rotation_order" order; ch "connectivity" "Triangles"] @ rot @ divs)
       ["XYZ"; "XZY"; "YXZ"; "YZX"; "ZXY"; "ZYX"]
   @ List.map (fun (l, c) -> "axis_" ^ l, c)
       ["x", [fl "rotation_x" 0.5]; "y", [fl "rotation_y" 0.5]; "z", [fl "rotation_z" 0.5]])
(* Quads at 400 divisions per axis: 6 * 401^2 = 0.96M points (not consolidated). *)
let bench () = [], [it "x_divisions" 400; it "y_divisions" 400; it "z_divisions" 400;
  ch "connectivity" "Quads"; ch "normals" "Vertex"; tx "uv_attribute" "uv"; tx "face_groups" "f"]
let () = register { key = "box"; native = Sop.Nodes.Box.factory; inputs = no_input; cases; ulps = 4; bench = Some bench }
