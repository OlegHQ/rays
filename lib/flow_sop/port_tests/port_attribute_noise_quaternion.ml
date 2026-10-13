(* sop/attribute_noise_quaternion: one geometry input (pending draft). The location and range are the
   native encoded strings; text like "attribute:x" and "min-max;vec4,..." is covered per branch. *)
open Port_gate
open Rdk
module P = Param
let tx name v = name, P.Text_value v
let it name v = name, P.Int_value v
let fl name v = name, P.Float_value v
let minmax = "min-max;vec4,-0.5,-1,0,0.25;vec4,0.5,1,2,1"
let cases =
  List.concat_map (fun owner ->
    List.map (fun (label, changes) -> Printf.sprintf "%s/%s" label owner, ("owner", P.Choice_value owner) :: changes)
      ["default", [];
       "position", [tx "location" "position"; it "seed" 7];
       "attribute_vec3", [tx "location" "attribute:vec3"; tx "name" "fresh"];
       "attribute_missing", [tx "location" "attribute:missing"];
       "attribute_float", [tx "location" "attribute:float"];
       "attribute_colon", [tx "location" "attribute:a:b"];
       "attribute_blank", [tx "location" "attribute:"];
       "bad_location", [tx "location" "bogus"];
       "positive", [tx "range" "positive"; tx "location" "position"];
       "min_max", [tx "range" minmax; tx "location" "position"; it "octaves" 3];
       "min_max_scalar", [tx "range" "min-max;scalar,0;scalar,1"];
       "min_max_reversed", [tx "range" "min-max;vec4,1,1,1,1;vec4,0,0,0,0"];
       "min_max_garbage", [tx "range" "min-max;vec4,a,1,1,1;vec4,0,0,0,0"];
       "bad_range", [tx "range" "wide"];
       "existing_vec4", [tx "name" "vec4"; tx "location" "position"];
       "existing_vec4_group", [tx "name" "vec4"; tx "location" "position"; tx "group" "a"];
       "existing_float", [tx "name" "float"];
       "existing_vec3", [tx "name" "vec3"];
       "existing_text", [tx "name" "text"];
       "group", [tx "group" "a"; tx "location" "position"];
       "group_missing", [tx "group" "nope"];
       "frequency", [fl "frequency_x" 2.5; fl "frequency_y" 0.5; fl "frequency_z" 3.; tx "location" "position"];
       "octaves", [it "octaves" 4; tx "location" "position"];
       "octaves_too_many", [it "octaves" 65];
       "blank_name", [tx "name" " "];
       "name_P", [tx "name" "P"]])
    ["Point"; "Vertex"; "Primitive"; "Detail"]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  [g], [tx "location" "position"; it "octaves" 2]
let () = register { key = "attribute_noise_quaternion"; native = Sop.Nodes.Attribute_noise_quaternion.factory;
  inputs = standard_inputs; cases; ulps = 4; bench = Some bench }
