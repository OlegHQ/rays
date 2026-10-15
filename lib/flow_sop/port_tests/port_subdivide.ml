(* sop/subdivide: two inputs (mesh, optional creases). Fixtures are small closed and open polygon
   meshes; the default hole group "subdivision_hole" must exist on them (the native node refuses a
   missing hole group), so each carries an empty or partial one. *)
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

(* The default hole group must exist: a primitive group named subdivision_hole. *)
let with_holes ?(members = fun _ -> false) g =
  let count = Geometry.primitive_count g in
  Geometry.with_group (Group.init ~owner:Group.Primitive ~name:"subdivision_hole" count members) g
  |> get_string_ok
let holes_some g = with_holes ~members:(fun p -> p mod 3 = 1) g

(* A creases input: float creaseweight attributes (vertex and/or primitive) and a group. *)
let float_attr owner name values =
  Attribute.create_owned ~owner ~name (Attribute.Float values) |> get_string_ok
let with_attr a g = Geometry.with_attribute a g |> get_string_ok
let crease_vertex g =
  with_attr (float_attr Attribute.Vertex "creaseweight"
    (Array.init (Geometry.vertex_count g) (fun v -> if v mod 3 = 0 then 2.5 else if v mod 5 = 0 then 0.75 else 0.))) g
let crease_prims g =
  let g = with_attr (float_attr Attribute.Primitive "creaseweight"
    (Array.init (Geometry.primitive_count g) (fun p -> float (p mod 4)))) g in
  Geometry.with_group (Group.init ~owner:Group.Primitive ~name:"csel" (Geometry.primitive_count g) (fun p -> p mod 2 = 0)) g
  |> get_string_ok
let crease_both g = crease_prims (crease_vertex g)

let single = List.map (fun (label, g) -> label, [g]) [
  "box+groups", fixture_groups (with_holes (box ())); "grid holes", fixture_groups (holes_some (small_grid ()));
  "trianglegrid+groups", fixture_groups (with_holes (tri_grid ())); "trianglegrid holes", holes_some (tri_grid ());
  "mixed", with_holes (polygon_polyline ());
  "box", with_holes (box ()); "trianglebox", with_holes (tri_box ()); "trianglegrid", with_holes (tri_grid ());
  "grid", with_holes (small_grid ()) ]
let two = [
  "box+creases", [with_holes (box ()); crease_vertex (box ())];
  "grid+primitive creases", [with_holes (small_grid ()); crease_prims (small_grid ())];
  "trianglegrid+both", [fixture_groups (with_holes (tri_grid ())); crease_both (tri_grid ())];
  "box+other topology", [with_holes (box ()); tri_box ()];
  "box+bad creases", [with_holes (box ());
    with_attr (float_attr Attribute.Vertex "creaseweight" (Array.make (Geometry.vertex_count (tri_box ())) 1.)) (tri_box ())] ]
let inputs = single

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
      "generate resulting", with_ ["crease_weight", P.Float_value 3.; "generate_resulting_creases", P.Bool_value true];
      "resulting group", with_ ["crease_weight", P.Float_value 3.; "generate_resulting_creases", P.Bool_value true;
        text "resulting_crease_group" "creased"; "iterations", P.Int_value 2];
      "resulting group auto", with_ [choice "crease_weight_mode" "Auto"; "generate_resulting_creases", P.Bool_value true;
        text "resulting_crease_group" "a"] ]
  @ (let holes extra = [ "remove_holes", P.Bool_value true ] @ extra in
     [ "remove holes", holes base;
       "remove holes depth 2", holes (with_ ["iterations", P.Int_value 2]);
       "remove holes loop", holes (with_ [choice "scheme" "Loop"; "iterations", P.Int_value 2]);
       "remove holes bilinear", holes (with_ [choice "scheme" "Bilinear"]);
       "remove holes boundary none", holes (with_ [choice "boundary_interpolation" "None"]);
       "keep holes boundary none", with_ [choice "boundary_interpolation" "None"; "iterations", P.Int_value 2];
       "hole group copy", [ "remove_holes", P.Bool_value true; text "hole_group" "a" ];
       "hole group default name", [ "remove_holes", P.Bool_value true ];
       "hole group missing", [ text "hole_group" "missing_holes" ] ])
  (* partial groups and curves reach the native crack carrier; an empty selection returns the input *)
  @ List.map (fun (label, cracks) -> "group a/" ^ label, with_ [text "group" "a"; choice "cracks" cracks])
      ["none", "Do not close"; "pull", "Pull, no edge division"; "pull divide", "Pull, divide edges";
       "pull triangulate", "Pull, triangulate"; "stitch", "Stitch, no edge division";
       "stitch divide", "Stitch, divide edges"; "stitch triangulate", "Stitch, triangulate"]
  @ [ "group holes", with_ [text "group" "subdivision_hole"];
      "group missing", with_ [text "group" "missing_group"];
      "group a loop", with_ [text "group" "a"; choice "scheme" "Loop"] ]
  (* normals *)
  @ [ "recompute normals", with_ ["recompute_point_normals", P.Bool_value true];
      "recompute normals depth 2", with_ ["recompute_point_normals", P.Bool_value true; "iterations", P.Int_value 2] ]
let () = register { key = "subdivide"; native = Sop.Nodes.Subdivide.factory; inputs; cases; ulps = 4;
  bench = None }

(* The creases input is connected: its fixtures carry two geometries. *)
let crease_cases =
  [ "default", base;
    "crease input", with_ [];
    "crease input depth 2", with_ ["iterations", P.Int_value 2];
    "crease input auto", with_ [choice "crease_weight_mode" "Auto"];
    "crease input auto depth 2", with_ [choice "crease_weight_mode" "Auto"; "iterations", P.Int_value 2];
    "crease input group", with_ [text "crease_group" "csel"; "iterations", P.Int_value 2];
    "crease input group auto", with_ [text "crease_group" "csel"; choice "crease_weight_mode" "Auto"];
    "crease input missing group", with_ [text "crease_group" "missing_crease"];
    "crease input chaikin", with_ [choice "crease_weight_mode" "Auto"; choice "creasing_method" "Chaikin";
      "iterations", P.Int_value 3];
    "crease input loop", with_ [choice "crease_weight_mode" "Auto"; choice "scheme" "Loop"; "iterations", P.Int_value 2];
    "crease input resulting", with_ [choice "crease_weight_mode" "Auto"; "generate_resulting_creases", P.Bool_value true;
      text "resulting_crease_group" "r"];
    "crease input group a", with_ [text "group" "a"] ]
let () = register { key = "subdivide"; native = Sop.Nodes.Subdivide.factory; inputs = two; cases = crease_cases;
  ulps = 4; bench = None }
