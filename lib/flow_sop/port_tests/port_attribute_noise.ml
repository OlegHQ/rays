(* sop/attribute_noise: one geometry input (pending draft). Every owner x kind x operation, range,
   location, group and existing-attribute branch; refusals at construction and at cook. *)
open Port_gate
open Rdk
module P = Param
let tx name v = name, P.Text_value v
let ch name v = name, P.Choice_value v
let it name v = name, P.Int_value v
let fl name v = name, P.Float_value v
let bl name v = name, P.Bool_value v
let cases =
  List.concat_map (fun owner ->
    List.map (fun (label, changes) -> Printf.sprintf "%s/%s" label owner, ch "owner" owner :: changes)
      (["default", [];
       "vector", [ch "kind" "Vector"; tx "name" "fresh"];
       "quaternion", [ch "kind" "Quaternion"; tx "name" "fresh"; it "octaves" 3];
       "element_number", [ch "location" "Element number"; it "seed" 5];
       "attribute_location", [ch "location" "Attribute"; tx "location_attribute" "vec3"];
       "attribute_missing", [ch "location" "Attribute"; tx "location_attribute" "nope"];
       "attribute_float", [ch "location" "Attribute"; tx "location_attribute" "float"];
       "zero_centered", [ch "range" "Zero centered"; ch "kind" "Vector"];
       "min_max", [ch "range" "Minimum / maximum"; fl "min_x" (-2.); fl "max_x" 3.];
       "min_max_vector", [ch "range" "Minimum / maximum"; ch "kind" "Vector"; fl "min_y" 1.; fl "max_y" 4.; fl "min_z" (-1.); fl "max_z" 0.];
       "min_max_quaternion", [ch "range" "Minimum / maximum"; ch "kind" "Quaternion"; fl "min_w" (-1.); fl "max_w" 0.5];
       "min_max_reversed", [ch "range" "Minimum / maximum"; fl "min_x" 3.; fl "max_x" 2.];
       "existing_float_add", [tx "name" "float"; ch "operation" "Add"];
       "existing_float_sub", [tx "name" "float"; ch "operation" "Subtract"; fl "blend" 0.4];
       "existing_float_mul", [tx "name" "float"; ch "operation" "Multiply"];
       "existing_float_min", [tx "name" "float"; ch "operation" "Minimum"];
       "existing_float_max", [tx "name" "float"; ch "operation" "Maximum"];
       "existing_float_initial", [tx "name" "float"; ch "operation" "Set initial"];
       "new_initial", [tx "name" "fresh"; ch "operation" "Set initial"];
       "existing_vec3_set", [tx "name" "vec3"; ch "kind" "Vector"; ch "operation" "Add"];
       "existing_vec4_set", [tx "name" "vec4"; ch "kind" "Quaternion"; fl "blend" 0.5];
       "existing_mismatch", [tx "name" "vec3"];
       "existing_vec2", [tx "name" "vec2"; ch "kind" "Vector"];
       "existing_text", [tx "name" "text"];
       "existing_int", [tx "name" "integer"];
       "blend_zero", [tx "name" "float"; fl "blend" 0.];
       "blend_high", [fl "blend" 1.5];
       "group", [tx "group" "a"];
       "group_existing", [tx "group" "a"; tx "name" "float"; ch "operation" "Add"];
       "group_missing", [tx "group" "nope"];
       "frequency_offset", [fl "frequency_x" 3.; fl "frequency_y" 0.5; fl "offset_x" 1.25; fl "offset_z" (-2.)];
       "fractal", [it "octaves" 4; fl "lacunarity" 2.7; fl "roughness" 0.3];
       "octaves_too_many", [it "octaves" 65];
       "lacunarity_zero", [fl "lacunarity" 0.];
       "roughness_high", [fl "roughness" 1.5];
       "context_seed", [bl "context_seed" true];
       "quaternion_add", [ch "kind" "Quaternion"; ch "operation" "Add"];
       "blank_name", [tx "name" " "];
       "location_blank", [ch "location" "Attribute"; tx "location_attribute" " "]]
      @ (if owner = "Point" then
        ["position", [tx "name" "P"; ch "kind" "Vector"; ch "range" "Zero centered"; fl "frequency_x" 2.];
         "position_float", [tx "name" "P"];
         "position_initial", [tx "name" "P"; ch "operation" "Set initial"];
         "position_add_group", [tx "name" "P"; ch "kind" "Vector"; ch "operation" "Add"; tx "group" "a"];
         "position_blend_zero", [tx "name" "P"; ch "kind" "Vector"; ch "operation" "Add"; fl "blend" 0.]]
      else []) @ (if owner = "Detail" then ["detail_group", [tx "group" "a"]] else [])))
    ["Point"; "Vertex"; "Primitive"; "Detail"]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  [g], [ch "kind" "Vector"; tx "name" "fresh"; it "octaves" 2]
let () = register { key = "attribute_noise"; native = Sop.Nodes.Attribute_noise.factory;
  inputs = standard_inputs; cases; ulps = 4; bench = Some bench }
