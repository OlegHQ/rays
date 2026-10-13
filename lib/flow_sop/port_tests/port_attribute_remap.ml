(* sop/attribute_remap: one geometry input (pending draft). Every owner x value type, input range,
   outside-range policy, ramp, destination, group and refusal branch. *)
open Port_gate
open Rdk
module P = Param
let tx name v = name, P.Text_value v
let ch name v = name, P.Choice_value v
let fl name v = name, P.Float_value v
let kinds = ["Scalar", "float"; "Vector 2", "vec2"; "Vector 3", "vec3"; "Vector 4", "vec4"]
(* The default cook reads a float attribute "value" on the chosen owner: add one everywhere. *)
let with_value geometry =
  List.fold_left (fun geometry owner ->
    let n = match owner with Attribute.Point -> Geometry.point_count geometry | Vertex -> Geometry.vertex_count geometry
      | Primitive -> Geometry.primitive_count geometry | Detail -> 1 in
    Rdk_test_support.get_string_ok (Geometry.with_attribute (Rdk_test_support.get_string_ok
      (Attribute.create_owned ~owner ~name:"value" (Attribute.Float (Array.init n (fun i -> float ((i * 7) mod 11) *. 0.37 -. 1.))))) geometry))
    geometry [Attribute.Point; Vertex; Primitive; Detail]
let inputs = List.map (fun (label, geometries) -> label, List.map with_value geometries) standard_inputs
let cases =
  List.concat_map (fun owner ->
    List.concat_map (fun (kind, attr) ->
      let base = [ch "owner" owner; ch "kind" kind; tx "name" attr] in
      List.map (fun (label, changes) -> Printf.sprintf "%s/%s/%s" label owner kind, base @ changes)
        ["default", [];
         "cycle", [ch "policy" "Cycle"; fl "output_min_x" (-1.); fl "output_max_y" 2.];
         "extrapolate", [ch "policy" "Extrapolate"; ch "input_range" "Explicit"; fl "input_max_x" 0.5; fl "input_max_y" 0.4;
           fl "input_max_z" 0.3; fl "input_max_w" 2.; fl "output_min_z" 1.; fl "output_max_w" 3.];
         "explicit_clamp", [ch "input_range" "Explicit"; fl "input_min_x" 0.2; fl "input_max_x" 0.8; fl "input_min_y" (-1.);
           fl "input_max_y" 1.; fl "input_min_z" 0.1; fl "input_max_z" 1.5; fl "input_min_w" (-2.); fl "input_max_w" 2.];
         "explicit_equal", [ch "input_range" "Explicit"; fl "input_max_x" 0.];
         "ramp", [tx "ramp" "0:0,0.25:1,0.5:0.2,1:3"; ch "policy" "Clamp"];
         "ramp_cycle", [tx "ramp" " 0 : 1 , 1 : 0 "; ch "policy" "Cycle"; ch "input_range" "Explicit"; fl "input_max_x" 0.7];
         "ramp_extrapolate", [tx "ramp" "0:0,0.5:1,1:0"; ch "policy" "Extrapolate"];
         "ramp_bad_start", [tx "ramp" "0.1:0,1:1"];
         "ramp_bad_end", [tx "ramp" "0:0,0.9:1"];
         "ramp_not_increasing", [tx "ramp" "0:0,0.5:1,0.5:2,1:0"];
         "ramp_single", [tx "ramp" "0:1"];
         "ramp_garbage", [tx "ramp" "0:a,1:1"];
         "ramp_range", [tx "ramp" "0:0,2:1"];
         "into_new", [tx "into" " fresh "];
         "into_existing", [tx "into" "float"];
         "into_existing_mismatch", [tx "into" "vec3"];
         "into_text", [tx "into" "text"];
         "into_group", [tx "into" "fresh"; tx "group" "a"];
         "group", [tx "group" "a"; ch "input_range" "Explicit"; fl "input_max_x" 0.5];
         "group_into_existing", [tx "group" " a "; tx "into" "float"];
         "group_missing", [tx "group" "nope"];
         "output_range", [fl "output_min_x" 5.; fl "output_max_x" (-5.); fl "output_min_y" 2.; fl "output_max_y" 3.;
           fl "output_min_z" (-3.); fl "output_max_z" (-2.); fl "output_min_w" 1.; fl "output_max_w" 9.]]) kinds
    @ List.map (fun (label, changes) -> Printf.sprintf "%s/%s" label owner, ch "owner" owner :: changes)
      ["missing", [tx "name" "nope"];
       "text_source", [tx "name" "text"];
       "int_source", [tx "name" "integer"];
       "kind_mismatch", [tx "name" "vec3"; ch "kind" "Vector 2"];
       "blank_name", [tx "name" " "];
       "explicit_reversed", [ch "input_range" "Explicit"; fl "input_min_x" 2.];
       "explicit_reversed_y", [ch "input_range" "Explicit"; ch "kind" "Vector 2"; tx "name" "vec2"; fl "input_min_y" 2.];
       "explicit_reversed_unused", [ch "input_range" "Explicit"; fl "input_min_y" 2.; fl "input_min_w" 5.];
       "detail_group", [tx "group" "a"]]
    @ (if owner = "Point" then
      [ "position", [tx "name" "P"; ch "kind" "Vector 3"; fl "output_max_x" 2.];
        "position_into", [tx "name" "P"; ch "kind" "Vector 3"; tx "into" "rest"];
        "position_identity", [tx "name" "P"; ch "kind" "Vector 3"; ch "input_range" "Explicit"; fl "input_max_x" 1.;
          fl "input_max_y" 1.; fl "input_max_z" 1.; ch "policy" "Extrapolate"];
        "position_group", [tx "name" "P"; ch "kind" "Vector 3"; tx "group" "a"; fl "output_max_y" 4.];
        "position_scalar", [tx "name" "P"];
        "into_position", [tx "name" "float"; tx "into" "P"];
        "into_position_vec3", [tx "name" "vec3"; ch "kind" "Vector 3"; tx "into" "P"];
        "position_cycle", [tx "name" "P"; ch "kind" "Vector 3"; ch "policy" "Cycle"; ch "input_range" "Explicit"; fl "input_max_x" 0.3] ]
    else [])) ["Point"; "Vertex"; "Primitive"; "Detail"]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  [g], [tx "name" "P"; tx "into" "mapped"; ch "kind" "Vector 3"; ch "policy" "Cycle"; tx "ramp" "0:0,0.5:1,1:0"]
let () = register { key = "attribute_remap"; native = Sop.Nodes.Attribute_remap.factory;
  inputs; cases; ulps = 4; bench = Some bench }
