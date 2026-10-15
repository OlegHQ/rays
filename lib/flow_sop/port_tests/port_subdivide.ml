(* sop/subdivide: two inputs (mesh, optional creases). Fixtures are small closed and open polygon
   meshes; the default hole group "subdivision_hole" must exist on them (the native node refuses a
   missing hole group), so most cases name no hole group. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param

let box () = Box_generator.box ~connectivity:Box_generator.Box_quads ~consolidate_points:true
  ~normals:Box_generator.Box_no_normals ~size:(Rays_math.Vec3.create 2. 2. 2.) () |> get_ok
let tri_box () = Box_generator.box ~connectivity:Box_generator.Box_triangles ~consolidate_points:true
  ~normals:Box_generator.Box_no_normals ~size:(Rays_math.Vec3.create 2. 2. 2.) () |> get_ok
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:3 ~rows:3 ~size:2. () |> get_ok
let tri_grid () = Plane_generators.grid ~connectivity:Grid_triangles ~columns:3 ~rows:2 ~size:2. () |> get_ok

(* The default hole group must exist: an empty primitive group named subdivision_hole. *)
let with_holes ?(members = fun _ -> false) g =
  let count = Geometry.primitive_count g in
  Geometry.with_group (Group.init ~owner:Group.Primitive ~name:"subdivision_hole" count members) g
  |> get_string_ok

let inputs = List.map (fun (label, g) -> label, [with_holes g]) [
  "box", box (); "trianglebox", tri_box (); "trianglegrid", tri_grid (); "grid", small_grid () ]

let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value
let base = [text "hole_group" ""]
let with_ extra = extra @ base
let cases =
  let scheme s = with_ [choice "scheme" s] in
  [ "default", base;
    "depth 2", with_ ["iterations", P.Int_value 2];
    "depth 3", with_ ["iterations", P.Int_value 3];
    "loop", scheme "Loop";
    "loop depth 2", with_ [choice "scheme" "Loop"; "iterations", P.Int_value 2];
    "bilinear", scheme "Bilinear";
    "bilinear depth 2", with_ [choice "scheme" "Bilinear"; "iterations", P.Int_value 2] ]
  @ List.concat_map (fun s ->
      List.map (fun (b, v) -> Printf.sprintf "%s/boundary %s" s b,
        with_ [choice "scheme" s; choice "boundary_interpolation" v; "iterations", P.Int_value 2])
        ["none", "None"; "edge", "Edge only"; "corner", "Edge and corner"])
    ["Catmull-Clark"; "Loop"; "Bilinear"]
  @ [ "smooth triangles", with_ [choice "triangle_policy" "Smooth"];
      "smooth triangles depth 2", with_ [choice "triangle_policy" "Smooth"; "iterations", P.Int_value 2];
      "auto creases", with_ [choice "crease_weight_mode" "Auto"];
      "auto creases depth 3", with_ [choice "crease_weight_mode" "Auto"; "iterations", P.Int_value 3];
      "weight 0", with_ ["crease_weight", P.Float_value 0.];
      "weight 0.5", with_ ["crease_weight", P.Float_value 0.5; "iterations", P.Int_value 2];
      "weight 2", with_ ["crease_weight", P.Float_value 2.];
      "weight 2 depth 2", with_ ["crease_weight", P.Float_value 2.; "iterations", P.Int_value 2];
      "weight 2 depth 3", with_ ["crease_weight", P.Float_value 2.; "iterations", P.Int_value 3];
      "weight 3 chaikin", with_ ["crease_weight", P.Float_value 3.; choice "creasing_method" "Chaikin";
        "iterations", P.Int_value 3];
      "weight 2.5 loop", with_ ["crease_weight", P.Float_value 2.5; choice "scheme" "Loop"; "iterations", P.Int_value 3];
      "generate resulting", with_ ["crease_weight", P.Float_value 3.; "generate_resulting_creases", P.Bool_value true] ]
let () = register { key = "subdivide"; native = Sop.Nodes.Subdivide.factory; inputs; cases; ulps = 4;
  bench = None }
