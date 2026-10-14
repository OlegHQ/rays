(* sop/point_replicate: two geometry inputs, the second (custom shape) always connected here, because native
   refuses shape Custom without it at construction (a Lisp validator cannot see connectivity; that case is not
   covered). Fixtures carry every instancing attribute (pscale scale orient N v up rot trans pivot transform
   rest id Cd) in separate geometries because the frame branches are exclusive. *)
open Port_gate
open Rdk
open Rdk_test_support
module P = Param
let ch name v = name, P.Choice_value v
let fl name v = name, P.Float_value v
let tx name v = name, P.Text_value v
let bl name v = name, P.Bool_value v
let it name v = name, P.Int_value v
let add_attr name storage geometry = Geometry.with_attribute
  (Attribute.create_owned ~owner:Attribute.Point ~name storage |> get_string_ok) geometry |> get_string_ok
let v3 name f n = add_attr name (Attribute.Float3 (Packed.Float3.of_owned
  ~x:(Array.init n (fun i -> let x, _, _ = f i in x)) ~y:(Array.init n (fun i -> let _, y, _ = f i in y))
  ~z:(Array.init n (fun i -> let _, _, z = f i in z)) |> get_string_ok))
let v4 name f n = add_attr name (Attribute.Float4 (Packed.Float4.of_owned
  ~x:(Array.init n (fun i -> let x, _, _, _ = f i in x)) ~y:(Array.init n (fun i -> let _, y, _, _ = f i in y))
  ~z:(Array.init n (fun i -> let _, _, z, _ = f i in z)) ~w:(Array.init n (fun i -> let _, _, _, w = f i in w))
  |> get_string_ok))
let f1 name f n = add_attr name (Attribute.Float (Array.init n f))
let i1 name f n = add_attr name (Attribute.Int (Array.init n f))
let rows name width f n = add_attr name (Attribute.Float_array (Packed.Float_array.create_owned
  ~offsets:(Array.init (n + 1) (fun i -> i * width))
  ~values:(Array.init (n * width) (fun k -> f (k / width) (k mod width))) |> get_string_ok))
let n = 6
let base () = fixture_groups (points n)
let ids = i1 "id" (fun i -> [| 10; 3; 3; 7; 100; -5 |].(i)) n
let cd = v3 "Cd" (fun i -> float i *. 0.25, 0.5, 1. -. float i *. 0.125) n
let vel = v3 "v" (fun i -> float i *. 0.5, 0.25 -. float i *. 0.125, if i = 2 then 0. else 1.) n
let normals = v3 "N" (fun i -> [| 0., 0., 1.; 0., 0., -1.; 1., 2., 2.; 0., 0., 0.; -3., 0.5, 0.1; 0.2, -0.7, 0.4 |].(i)) n
let ups = v3 "up" (fun i -> [| 0., 1., 0.; 0., 1., 0.; 2., 4., 4.; 1., 0., 0.; 0., 0., 0.; -0.5, 0.5, 2. |].(i)) n
let fixture_orient () = base () |> ids |> cd |> vel |> normals
  |> f1 "pscale" (fun i -> 0.5 +. float i *. 0.25) n |> v3 "scale" (fun i -> 1. +. float i *. 0.125, 1.5, 0.75) n
  |> v4 "orient" (fun i -> [| 0., 0., 0., 0.; 1., 2., 3., 4.; 0., 0.7, 0., 0.7; 0.3, -0.2, 0.1, 0.9; 0., 0., 0., 2.; 0.1, 0.1, 0.1, 0.1 |].(i)) n
  |> v4 "rot" (fun i -> 0.2 *. float i, 0.1, -0.3, 1. +. float i) n
  |> v3 "trans" (fun i -> 0.5, float i *. 0.25, -1.) n |> v3 "pivot" (fun i -> 0.25, -0.5 +. float i *. 0.125, 0.1) n
let fixture_dir_n () = base () |> ids |> cd |> vel |> normals |> ups
  |> v4 "rot" (fun i -> 0., 0.3 *. float i, 0., 1.) n
let fixture_dir_v () = base () |> cd |> vel |> ups
let fixture_dir_free () = base () |> normals
let fixture_m9 () = base () |> ids |> cd |> normals |> v3 "trans" (fun i -> float i, 0., 0.5) n
  |> v3 "pivot" (fun i -> 0.5, 0.25, float i *. 0.125) n
  |> v4 "rot" (fun _ -> 0.5, 0.5, 0.5, 0.5) n
  |> rows "transform" 9 (fun i k -> [| 1.; 0.5; 0.; 0.25; 2.; 0.; 0.1; 0.; 0.5 +. float i *. 0.1 |].(k)) n
let fixture_m16 () = base () |> ids |> cd |> normals |> vel |> f1 "pscale" (fun _ -> 3.) n
  |> rows "transform" 16 (fun i k ->
      [| 0.; -1.; 0.; 0.5 +. float i; 1.; 0.; 0.; -0.25; 0.; 0.; 2.; float i *. 0.5; 0.; 0.; 0.; 1. |].(k)) n
let fixture_rest () = base () |> ids |> v3 "rest" (fun i -> float i, 2. *. float i, 0.5) n |> cd
let fixture_singular () = base () |> ids |> cd |> normals |> f1 "pscale" (fun i -> if i = 3 then 0. else 1.) n |> vel
let custom () = points 5 |> v3 "x" (fun i -> float i, 0., 0.) 5
let pair (label, g) = label, [g; custom ()]
let fixtures =
  List.map (fun (label, gs) -> label, gs @ [custom ()]) standard_inputs
  @ List.map pair [
      "orient", fixture_orient (); "dir_n", fixture_dir_n (); "dir_v", fixture_dir_v (); "dir_free", fixture_dir_free ();
      "m9", fixture_m9 (); "m16", fixture_m16 (); "rest", fixture_rest (); "singular", fixture_singular ()]
  @ ["empty_custom", [base () |> ids; points 0]]
let ppp = fl "points_per_point" 3.
let cases =
  List.map (fun shape -> "shape_" ^ shape, [ch "shape" shape; ppp]) ["Point"; "Box"; "Sphere"; "Disk"; "Line"; "Custom"]
  @ ["points_per_point", [fl "points_per_point" 2.5; tx "scale_attribute" "pscale"];
     "scale_attribute_missing", [tx "scale_attribute" "missing"];
     "keep_input", [bl "keep_input" true; fl "points_per_point" 2.];
     "group", [tx "group" "a"; tx "generated_group" "gen"; ppp];
     "group_keep", [tx "group" "a"; tx "generated_group" "a"; bl "keep_input" true; ppp];
     "missing_group", [tx "group" "zzz"];
     "context_seed", [bl "context_seed" true; ppp];
     "seed", [it "seed" 7; ppp; ch "shape" "Box"];
     "id_attribute", [tx "id_attribute" "integer"; ppp];
     "id_attribute_float", [tx "id_attribute" "float"; ppp];
     "center", [fl "center_x" 1.; fl "center_y" (-0.5); fl "center_z" 2.; ppp];
     "size", [fl "size_x" 2.; fl "size_y" 0.5; fl "size_z" 3.; ppp];
     "orient_x", [fl "orientation_x" 0.3; ppp];
     "orient_y", [fl "orientation_y" (-0.7); ppp];
     "orient_z", [fl "orientation_z" 1.1; ppp];
     "orient_xyz", [fl "orientation_x" 0.3; fl "orientation_y" (-0.7); fl "orientation_z" 1.1; ppp];
     "uniform", [fl "uniform_scale" 1.5; ppp];
     "center_orient", [fl "center_x" 1.; fl "center_y" (-0.5); fl "center_z" 2.; fl "orientation_x" 0.3; ppp];
     "center_orient_xyz", [fl "center_x" 1.; fl "center_y" (-0.5); fl "center_z" 2.; fl "orientation_x" 0.3; fl "orientation_y" (-0.7); fl "orientation_z" 1.1; ppp];
     "size_orient", [fl "size_x" 2.; fl "size_y" 0.5; fl "size_z" 3.; fl "orientation_x" 0.3; fl "orientation_y" (-0.7); ppp];
     "size_uniform", [fl "size_x" 2.; fl "size_y" 0.5; fl "size_z" 3.; fl "uniform_scale" 1.5; ppp];
     "center_size_uniform", [fl "center_x" 1.; fl "size_x" 2.; fl "size_y" 0.5; fl "uniform_scale" 1.5; ppp];
     "geometry", [fl "center_x" 1.; fl "center_y" (-0.5); fl "center_z" 2.; fl "size_x" 2.; fl "size_y" 0.5; fl "size_z" 3.;
                  fl "orientation_x" 0.3; fl "orientation_y" (-0.7); fl "orientation_z" 1.1; fl "uniform_scale" 1.5; ppp];
     "geometry_line", [ch "shape" "Line"; fl "orientation_y" 0.9; fl "orientation_z" 0.4; fl "size_z" 2.; ppp];
     "quasi", [bl "quasi_stratified" true; fl "points_per_point" 4.];
     "quasi_box_keep", [bl "quasi_stratified" true; ch "shape" "Box"; bl "keep_input" true; fl "points_per_point" 5.];
     "quasi_custom", [bl "quasi_stratified" true; ch "shape" "Custom"; ppp];
     "velocity_scaled", [ch "velocity_stretch" "Scaled velocity"; fl "velocity_scale" 0.75; ppp];
     "velocity_only", [ch "velocity_stretch" "Velocity only"; fl "velocity_scale" (-0.5); ppp];
     "velocity_inherit", [fl "inherit_velocity" 0.5; fl "radial_velocity" 0.5; ppp];
     "radial_only", [fl "radial_velocity" (-1.25); fl "inherit_velocity" (-2.); bl "keep_input" true; ppp];
     "noise", [bl "use_noise" true; ppp];
     "noise_full", [bl "use_noise" true; fl "noise_amplitude_x" 0.5; fl "noise_amplitude_y" 0.25; fl "noise_amplitude_z" 1.;
                    fl "noise_frequency_x" 2.; fl "noise_frequency_y" 0.5; fl "noise_frequency_z" 3.;
                    fl "noise_offset_x" 0.3; fl "noise_offset_y" (-1.); fl "noise_offset_z" 2.; fl "noise_roughness" 0.8;
                    fl "noise_attenuation" 2.; it "noise_turbulence" 5; it "noise_seed" 9; ppp];
     "noise_turbulence1", [bl "use_noise" true; it "noise_turbulence" 1; fl "noise_attenuation" 0.5; ppp];
     "noise_context", [bl "use_noise" true; bl "noise_context_seed" true; ppp];
     "noise_seed_unused", [it "noise_seed" 4; ppp];
     "generated_group", [tx "generated_group" "gen"; ppp];
     "copy_none", [tx "copy_point_attributes" ""; ppp];
     "copy_some", [tx "copy_point_attributes" "Cd v"; bl "keep_input" true; ppp];
     "keep_source", [bl "keep_source_attributes" true; ppp];
     "keep_source_named", [bl "keep_source_attributes" true; tx "source_point_attribute" "src"; tx "source_index_attribute" "rank";
                           bl "keep_input" true; ppp];
     "source_names_unused", [tx "source_point_attribute" "src"; tx "source_index_attribute" "rank"; ppp];
     "transform_p", [tx "transform_attributes" "P"; ppp];
     "transform_none", [tx "transform_attributes" ""; ppp];
     "transform_n", [tx "transform_attributes" "N Cd"; ppp];
     "transform_all", [tx "transform_attributes" "*"; bl "keep_input" true; ppp];
     "transform_v_custom", [tx "transform_attributes" "v N"; ch "shape" "Custom"; ch "velocity_stretch" "Scaled velocity"; ppp];
     "invalid_pattern", [tx "copy_point_attributes" "[a"];
     "invalid_transform_pattern", [tx "transform_attributes" "[a"];
     "bad_noise", [fl "noise_roughness" 1.5];
     "blank_id", [tx "id_attribute" " "];
     "all", [bl "keep_input" true; bl "quasi_stratified" true; bl "use_noise" true; ch "shape" "Custom";
             ch "velocity_stretch" "Scaled velocity"; fl "radial_velocity" 0.25; tx "group" "a"; tx "generated_group" "gen";
             tx "transform_attributes" "*"; fl "orientation_x" 0.4; fl "uniform_scale" 0.75; ppp]]
let bench () = [points 1_000_000; custom ()], [fl "points_per_point" 1.]
let () = register { key = "point_replicate"; native = Sop.Nodes.Point_replicate.factory; inputs = fixtures;
  cases; ulps = 4; bench = Some bench }
