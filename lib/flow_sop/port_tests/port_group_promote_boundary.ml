(* sop/group_promote_boundary: one geometry input. *)
open Rdk
open Port_gate
module P = Param
let i n = P.Int_value n
let s v = P.Text_value v
let c v = P.Choice_value v
let b v = P.Bool_value v
let f v = P.Float_value v
let owners = ["Points"; "Vertices"; "Primitives"; "Edges"]
let cases =
  List.concat_map (fun source -> List.concat_map (fun destination ->
    let base = ["source", c source; "destination", c destination; "group", s "a"] in
    let label what = Printf.sprintf "%s->%s %s" source destination what in
    [label "plain", base;
     label "unshared", base @ ["include_unshared_edges", b true];
     label "curve edges", base @ ["include_unshared_edges", b true; "include_all_unshared_curve_edges", b true];
     label "renamed keep", base @ ["name", s " moved "; "keep_original", b true];
     label "renamed", base @ ["name", s "dest_a"];
     label "same name", base @ ["name", s "a"]]
    @ (if destination = "Edges" then [label "attribute edges", base @ ["output_attribute", s "mask"]]
       else [label "attribute", base @ ["output_attribute", s "mask"]])
    @ List.map (fun (what, attributes) -> label what, base @ ["attributes", s attributes])
        ["float", "point\tfloat"; "all point", "point\t*"; "vec3 tol", "point\tvec3"; "primitive", "primitive\t*";
         "vertex", "vertex\tinteger"; "two", "point\tfloat\nprimitive\ttext"; "none", "point\tnomatch"]
    @ [label "tolerance", base @ ["attributes", s "point\tfloat"; "tolerance", f 3.]]
    @ (if destination = "Primitives" then [label "boundary points", base @ ["include_all_primitives_sharing_boundary_points", b true]]
       else [label "boundary points bad", base @ ["include_all_primitives_sharing_boundary_points", b true]])
    ) owners) owners
  @ ["missing", ["group", s "nope"]; "blank group", ["group", s " "];
     "blank name", ["group", s "a"; "name", s "   "; "output_attribute", s "x"];
     "curve without unshared", ["group", s "a"; "include_all_unshared_curve_edges", b true];
     "detail attribute", ["group", s "a"; "attributes", s "detail\t*"];
     "bad owner", ["group", s "a"; "attributes", s "bogus\tx"];
     "bad pattern", ["group", s "a"; "attributes", s "point\t["]]
(* Every fixture also gets a "group" group on each owner so the default case cooks. *)
let with_group_everywhere geometry =
  let put owner count g = Geometry.with_group (Group.init ~owner ~name:"group" count (fun i -> i mod 2 = 0)) g
    |> Rdk_test_support.get_string_ok in
  let g = geometry |> put Group.Point (Geometry.point_count geometry) |> put Group.Vertex (Geometry.vertex_count geometry)
    |> put Group.Primitive (Geometry.primitive_count geometry) in
  let topology = Geometry.topology g in
  let index = Topology_index.create topology in
  Geometry.with_edge_group (Edge_group.init ~topology ~index ~name:"group" (fun i -> i mod 2 = 0)) g
  |> Rdk_test_support.get_string_ok
let inputs = List.map (fun (label, geometries) -> label, List.map with_group_everywhere geometries) standard_inputs
let bench () =
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  [with_group_everywhere grid], ["source", c "Primitives"; "destination", c "Points"; "group", s "group"]
let () = register { key = "group_promote_boundary"; native = Sop.Nodes.Group_promote_boundary.factory; inputs;
  cases; ulps = 4; bench = Some bench }
