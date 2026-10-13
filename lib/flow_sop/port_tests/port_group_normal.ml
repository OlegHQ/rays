(* sop/group_normal: one geometry input. *)
open Rdk
open Port_gate
module P = Param
let i n = P.Int_value n
let s v = P.Text_value v
let c v = P.Choice_value v
let b v = P.Bool_value v
let f v = P.Float_value v
let merges = ["Replace"; "Union"; "Intersection"; "Subtract"; "Exclusive or"]
let owners = ["Points"; "Primitives"; "Edges"]
let directions = ["up", []; "x", ["direction_x", f 1.; "direction_y", f 0.]; "diagonal", ["direction_x", f 1.; "direction_y", f 1.; "direction_z", f 0.5];
                  "down", ["direction_y", f (-1.)]; "huge", ["direction_x", f 1e300; "direction_y", f 1e300]]
let cases =
  List.concat_map (fun owner ->
    List.map (fun (label, d) -> Printf.sprintf "%s %s" owner label, ("owner", c owner) :: d) directions
    @ List.map (fun (label, changes) -> Printf.sprintf "%s %s" owner label, ("owner", c owner) :: changes) [
      "wide", ["spread_angle", f 3.141592653589793];
      "zero spread", ["spread_angle", f 0.];
      "narrow", ["spread_angle", f 0.1];
      "half pi", ["spread_angle", f 1.5707963267948966];
      "opposite", ["include_opposite", b true; "direction_y", f (-1.)];
      "opposite wide", ["include_opposite", b true; "spread_angle", f 2.];
      "named", ["normal_attribute", s "vec3"];
      "named missing", ["normal_attribute", s "nope"];
      "named wrong type", ["normal_attribute", s "float"];
      "no existing", ["use_existing_normal", b false];
      "base", ["base", s "a"; "spread_angle", f 3.];
      "base missing", ["base", s "nope"];
      "blank name", ["name", s " "]])
      owners
  @ List.concat_map (fun owner -> List.map (fun merge ->
      Printf.sprintf "%s merge %s" owner merge, ["owner", c owner; "name", s "a"; "merge", c merge; "spread_angle", f 3.]) merges) owners
  @ ["zero direction", ["direction_x", f 0.; "direction_y", f 0.; "direction_z", f 0.]]
(* Point and primitive "N" attributes (and a non-finite sibling) so the stored-normal paths run. *)
let with_normals geometry =
  let points = Geometry.point_count geometry and prims = Geometry.primitive_count geometry in
  let vec n = let x = Array.init n (fun k -> float (k mod 3) -. 1.) and y = Array.init n (fun k -> if k mod 4 = 0 then 0. else 1.)
    and z = Array.init n (fun k -> float (k mod 5) *. 0.25) in
    Attribute.Float3 (Packed.Float3.of_owned ~x ~y ~z |> Rdk_test_support.get_string_ok) in
  let put owner name n g = Geometry.with_attribute
    (Attribute.create_owned ~owner ~name (vec n) |> Rdk_test_support.get_string_ok) g |> Rdk_test_support.get_string_ok in
  geometry |> put Attribute.Point "N" points |> put Attribute.Primitive "normal" prims
let nonfinite () =
  let x = [|0.; Float.nan; 1.|] and y = [|0.; 0.; 0.|] and z = [|0.; 1.; 0.|] in
  let topology = Topology.create_owned ~point_count:3 ~vertex_points:[|0;1;2|] ~primitive_offsets:[|0;3|]
    ~primitive_kinds:[|Topology.Polygon|] |> Rdk_test_support.get_string_ok in
  Geometry.create ~positions:(Packed.Float3.of_owned ~x ~y ~z |> Rdk_test_support.get_string_ok) ~topology ()
  |> Rdk_test_support.get_string_ok
let inputs = standard_inputs @ ["normals", [with_normals (fixture_groups (polygon_polyline ()))];
  "grid normals", [with_normals (grid ())]; "nonfinite", [nonfinite ()]]
let bench () =
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  [grid], ["owner", c "Primitives"]
let () = register { key = "group_normal"; native = Sop.Nodes.Group_normal.factory; inputs; cases; ulps = 4; bench = Some bench }
