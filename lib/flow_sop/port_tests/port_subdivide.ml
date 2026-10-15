(* sop/subdivide: two inputs (mesh, optional creases). Fixtures are small closed and open polygon
   meshes; the default hole group "subdivision_hole" must exist on them (the native node refuses a
   missing hole group), so most cases name no hole group. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param

let box () = Box_generator.box ~connectivity:Box_generator.Box_quads ~consolidate_points:true
  ~normals:Box_generator.Box_no_normals ~size:(Rays_math.Vec3.create 2. 2. 2.) () |> get_ok
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:3 ~rows:3 ~size:2. () |> get_ok

(* The default hole group must exist: an empty primitive group named subdivision_hole. *)
let with_holes ?(members = fun _ -> false) g =
  let count = Geometry.primitive_count g in
  Geometry.with_group (Group.init ~owner:Group.Primitive ~name:"subdivision_hole" count members) g
  |> get_string_ok

let inputs = List.map (fun (label, g) -> label, [with_holes g]) [
  "box", box (); "grid", small_grid () ]

let text name value = name, P.Text_value value
let base = [text "hole_group" ""]
let cases = [
  "default", base;
  "depth 2", ("iterations", P.Int_value 2) :: base;
  "depth 3", ("iterations", P.Int_value 3) :: base ]
let () = register { key = "subdivide"; native = Sop.Nodes.Subdivide.factory; inputs; cases; ulps = 4;
  bench = None }
