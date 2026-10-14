(* sop/group_expand: one geometry input. Every fixture gets a "group" and a "collision" group on each
   owner (the default cook needs "group"). The last fixtures are bumped grids (so normal spread
   cuts the growth) with an int/float boundary attribute per owner and an "N" vec3 per owner. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let i n = P.Int_value n
let s v = P.Text_value v
let c v = P.Choice_value v
let b v = P.Bool_value v
let f v = P.Float_value v

let with_positions geometry fn =
  let view = Packed.Float3.Private.view (Geometry.positions geometry) in
  let count = Array.length view.x in
  let x = Array.make count 0. and y = Array.make count 0. and z = Array.make count 0. in
  for k = 0 to count - 1 do
    let a, bb, cc = fn view.x.(k) view.y.(k) view.z.(k) in x.(k) <- a; y.(k) <- bb; z.(k) <- cc
  done;
  Geometry.create ~positions:(Packed.Float3.of_owned ~x ~y ~z |> get_string_ok) ~topology:(Geometry.topology geometry) ()
  |> get_string_ok

let bump x y _ = x, y, 0.6 *. sin (x *. 1.7) *. cos (y *. 1.3) +. (if x > 0.5 && y > 0.3 then 0.5 else 0.)

let decorate geometry =
  let counts = [Group.Point, Geometry.point_count geometry; Group.Vertex, Geometry.vertex_count geometry;
                Group.Primitive, Geometry.primitive_count geometry] in
  let g = List.fold_left (fun g (owner, count) ->
    let g = Geometry.with_group (Group.init ~owner ~name:"group" count (fun k -> k mod 7 = 0 || k mod 19 = 5)) g
      |> get_string_ok in
    Geometry.with_group (Group.init ~owner ~name:"collision" count (fun k -> k mod 4 < 2 && k mod 9 <> 0)) g
    |> get_string_ok) geometry counts in
  let topology = Geometry.topology g in
  let index = Topology_index.create topology in
  let g = Geometry.with_edge_group (Edge_group.init ~topology ~index ~name:"group" (fun k -> k mod 9 = 0)) g
    |> get_string_ok in
  let g = Geometry.with_edge_group (Edge_group.init ~topology ~index ~name:"collision" (fun k -> k mod 5 < 2)) g
    |> get_string_ok in
  let n_of = function Attribute.Point -> Geometry.point_count g | Vertex -> Geometry.vertex_count g
    | Primitive -> Geometry.primitive_count g | Detail -> 1 in
  List.fold_left (fun g owner ->
    let n = n_of owner in
    let plane scale = Array.init n (fun k -> float (k mod 5) *. scale -. 0.4) in
    let add name storage g = Geometry.with_attribute (Attribute.create_owned ~owner ~name storage |> get_string_ok) g
      |> get_string_ok in
    g |> add "region" (Attribute.Int (Array.init n (fun k -> (k / 6) mod 2)))
      |> add "tint" (Attribute.Float (Array.init n (fun k -> if k mod 8 < 4 then 0. else 1.)))
      |> add "N" (Attribute.Float3 (Packed.Float3.of_owned ~x:(plane 0.5) ~y:(plane (-0.25))
           ~z:(Array.init n (fun k -> if k mod 6 = 0 then 0. else 1.)) |> get_string_ok)))
    g [Attribute.Point; Vertex; Primitive]

let grid_of connectivity columns rows =
  Plane_generators.grid ~connectivity ~columns ~rows ~size:6. () |> get_ok
let inputs = List.map (fun (l, gs) -> l, List.map decorate gs) standard_inputs @ List.map (fun (l, g) -> l, [decorate g]) [
  "bump-triangles", with_positions (grid_of Grid_triangles 9 7) bump;
  "bump-quads", with_positions (grid_of Grid_quads 12 10) bump ]

let owners = ["Points"; "Vertices"; "Primitives"; "Edges"]
let base owner = ["owner", c owner]
let cases =
  List.concat_map (fun owner ->
    List.map (fun (label, changes) -> owner ^ "/" ^ label, base owner @ changes) ([
      "default", [];
      "steps 2", ["steps", i 2];
      "steps 4 renamed", ["steps", i 4; "name", s " grown "];
      "shrink 1", ["steps", i (-1)];
      "shrink 3", ["steps", i (-3)];
      "steps 0", ["steps", i 0; "name", s "copy"];
      "huge", ["steps", i 100];
      "huge shrink", ["steps", i (-100)];
      "flood", ["flood", b true];
      "flood steps 0", ["flood", b true; "steps", i 0];
      "same name", ["name", s "group"];
      "other group", ["group", s "collision"];
      "ordered group", ["group", s "a"; "steps", i 2];
      "padded ordered", ["group", s "dest_a"; "steps", i 0];
      "missing group", ["group", s "nope"];
      "blank group", ["group", s " "];
      "flood shrink", ["flood", b true; "steps", i (-1)];
      "min int", ["steps", i min_int] ]
    @ (if owner = "Edges" then ["step attribute", ["step_attribute", s "depth"]]
       else [ "step attribute", ["step_attribute", s "depth"; "steps", i 3];
              "step attribute shrink", ["step_attribute", s " depth "; "steps", i (-2)];
              "step attribute flood", ["step_attribute", s "depth"; "flood", b true];
              "step attribute existing", ["step_attribute", s "region"; "steps", i 2];
              "step attribute zero", ["step_attribute", s "depth"; "steps", i 0] ])
    @ (if owner = "Primitives" then [
        "share edges", ["primitive_connectivity", c "Share edges"];
        "share edges 3", ["primitive_connectivity", c "Share edges"; "steps", i 3; "step_attribute", s "d"];
        "share edges shrink", ["primitive_connectivity", c "Share edges"; "steps", i (-2)];
        "share edges flood", ["primitive_connectivity", c "Share edges"; "flood", b true] ]
       else [])
    @ (if owner = "Points" || owner = "Primitives" then begin
        let edges = if owner = "Primitives" then ["primitive_connectivity", c "Share edges"] else [] in
        [ "spread small", ["normal_spread", f 0.2; "steps", i 3];
          "spread mid flood", ["normal_spread", f 0.6; "flood", b true; "step_attribute", s "d"];
          "spread zero", ["normal_spread", f 0.; "steps", i 2];
          "spread shrink ignored", ["normal_spread", f 0.3; "steps", i (-2)];
          "normal attribute point", ["use_normal_attribute", b true; "normal_owner", c "Point"; "normal_spread", f 0.5; "steps", i 2];
          "normal attribute vertex", ["use_normal_attribute", b true; "normal_owner", c "Vertex"; "normal_spread", f 1.2; "steps", i 2];
          "normal attribute primitive", ["use_normal_attribute", b true; "normal_owner", c "Primitive"; "normal_spread", f 0.9; "flood", b true];
          "normal attribute pi", ["use_normal_attribute", b true; "normal_owner", c "Point"];
          "normal attribute named", ["use_normal_attribute", b true; "normal_name", s "vec3"; "normal_spread", f 1.0];
          "normal attribute missing", ["use_normal_attribute", b true; "normal_name", s "nope"; "normal_spread", f 1.0];
          "normal attribute wrong type", ["use_normal_attribute", b true; "normal_name", s "float"; "normal_spread", f 1.0];
          "boundary region", edges @ ["connectivity_attributes", s "point\tregion"; "steps", i 3];
          "boundary tint", edges @ ["connectivity_attributes", s "point\ttint"; "flood", b true];
          "boundary vertex", edges @ ["connectivity_attributes", s "vertex\tregion"; "steps", i 3];
          "boundary primitive", edges @ ["connectivity_attributes", s "primitive\tregion"; "steps", i 2];
          "boundary shrink", edges @ ["connectivity_attributes", s "point\tregion"; "steps", i (-2)];
          "boundary two", edges @ ["connectivity_attributes", s "point\tregion\nprimitive\ttint"; "steps", i 2];
          "boundary tolerance", edges @ ["connectivity_attributes", s "point\ttint"; "connectivity_tolerance", f 2.; "steps", i 3];
          "boundary bad owner", edges @ ["connectivity_attributes", s "bogus\tx"];
          "boundary combined", edges @ ["connectivity_attributes", s "point\tregion"; "normal_spread", f 0.8; "steps", i 4] ]
        @ List.concat_map (fun collision_owner -> List.map (fun (label, changes) ->
            Printf.sprintf "collision %s %s" collision_owner label,
            edges @ ["use_collision", b true; "collision_owner", c collision_owner] @ changes) [
          "grow", ["steps", i 3];
          "flood", ["flood", b true];
          "allow boundary", ["steps", i 3; "collision_allow_boundary", b true];
          "contain", ["collision_contain", b true; "flood", b true];
          "contain allow", ["collision_contain", b true; "collision_allow_boundary", b true; "steps", i 4];
          "shrink", ["steps", i (-2)];
          "shrink contain", ["steps", i (-3); "collision_contain", b true];
          "steps zero", ["steps", i 0];
          "missing", ["collision_group", s "nope"];
          "with spread", ["normal_spread", f 0.9; "steps", i 3; "step_attribute", s "d"] ]) owners
      end else [
        "constraint refused", ["normal_spread", f 0.5];
        "collision refused", ["use_collision", b true];
        "boundary refused", ["connectivity_attributes", s "point\tregion"] ])
    @ (if owner = "Primitives" then [
        "collision needs share edges", ["use_collision", b true];
        "boundary needs share edges", ["connectivity_attributes", s "point\tregion"] ] else [])))
    owners
  @ [ "blank normal name unused", ["normal_name", s " "; "steps", i 2];
      "blank collision name", ["use_collision", b true; "collision_group", s " "];
      "edge contain", ["use_collision", b true; "collision_contain", b true];
      "blank normal name", ["use_normal_attribute", b true; "normal_name", s " "];
      "edge step attribute", ["owner", c "Edges"; "step_attribute", s "d"];
      "flood shrinking", ["flood", b true; "steps", i (-2)] ]
let bench () =
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> get_ok in
  let g = Geometry.with_group (Group.init ~owner:Group.Point ~name:"group" (Geometry.point_count grid)
      (fun k -> k mod 5003 = 0)) grid |> get_string_ok in
  [g], ["steps", i 8]
let () = register { key = "group_expand"; native = Sop.Nodes.Group_expand.factory; inputs; cases; ulps = 4;
  bench = Some bench }
