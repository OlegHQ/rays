(* sop/connectivity: one geometry input (pending draft nodes/connectivity.pending). *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value

let with_uv name ~three geometry =
  let topology = Topology.Private.view (Geometry.topology geometry) in
  let positions = Packed.Float3.Private.view (Geometry.positions geometry) in
  let vertices = Array.length topology.vertex_points in
  let u = Array.init vertices (fun v -> positions.x.(topology.vertex_points.(v))
    +. (if (v / 4) mod 64 >= 32 then 0.5 else 0.))
  and w = Array.init vertices (fun v -> positions.y.(topology.vertex_points.(v))) in
  let storage = if three then Attribute.Float3 (Packed.Float3.of_owned ~x:u ~y:w
      ~z:(Array.make vertices 0.) |> get_string_ok)
    else Attribute.Float2 (Packed.Float2.of_owned ~x:u ~y:w |> get_string_ok) in
  Geometry.with_attribute (Attribute.create_owned ~owner:Attribute.Vertex ~name storage |> get_string_ok) geometry
  |> get_string_ok

(* Three triangles share edge 0-1; a polyline, an isolated point and a double use. *)
let nonmanifold () =
  let topology = Topology.create_owned ~point_count:8
    ~vertex_points:[|0;1;2; 0;1;3; 1;0;4; 4;5; 6;6|] ~primitive_offsets:[|0;3;6;9;11;13|]
    ~primitive_kinds:[|Topology.Polygon; Polygon; Polygon; Open_polyline; Open_polyline|] |> get_string_ok in
  let g = Geometry.create ~positions:(Geometry.positions (points 8)) ~topology () |> get_string_ok in
  with_uv "uv" ~three:false (fixture_groups g)

let uv_grid ~three = with_uv "uv" ~three (fixture_groups (grid ()))
let inputs = standard_inputs @ [
  "uv-grid2", [uv_grid ~three:false]; "uv-grid3", [uv_grid ~three:true];
  "nonmanifold", [nonmanifold ()]]

(* Dropped cases (the gate cannot express them): the four construction-time refusals
   (UV with Points, UV with seams, point group with Primitives, name P with Points).
   Native refuses them in apply_parameters while the Lisp :validate clauses fire in
   Lower (E_LOWER), after the gate's checker step, which it reports as an accepted node. *)
let cases =
  List.concat_map (fun o -> [
    o ^ "/groups", [choice "owner" o; text "primitive_group" "a"];
    o ^ "/group-literal", [choice "owner" o; text "primitive_group" "literal *?[]^\\"];
    o ^ "/seam", [choice "owner" o; text "seam_group" "dest_a"];
    o ^ "/seam+group", [choice "owner" o; text "seam_group" "old_x"; text "primitive_group" "dest_a"];
    o ^ "/missing prim group", [choice "owner" o; text "primitive_group" "nothing"];
    o ^ "/missing seam", [choice "owner" o; text "seam_group" "nothing"];
    o ^ "/text", [choice "owner" o; choice "output" "Text"];
    o ^ "/text prefix", [choice "owner" o; choice "output" "Text"; text "text_prefix" "\195\169_"; text "name" "piece"];
    o ^ "/name", [choice "owner" o; text "name" " other "];
    o ^ "/blank name", [choice "owner" o; text "name" "  "];
    o ^ "/name N", [choice "owner" o; text "name" "float"] ]) ["Primitives"; "Points"]
  @ [ "prims/name P", [text "name" "P"];
      "prims/uv", [text "uv_attribute" "uv"];
      "prims/uv missing", [text "uv_attribute" "nothing"]; "points/point group", [choice "owner" "Points"; text "point_group" "a"];
      "points/point group+prim", [choice "owner" "Points"; text "point_group" "dest_a"; text "primitive_group" "a"];
      "points/point group+seam text", [choice "owner" "Points"; text "point_group" "old_x"; text "seam_group" "a";
        choice "output" "Text"];
      "points/missing point group", [choice "owner" "Points"; text "point_group" "nothing"];
      "prims/uv+group", [text "uv_attribute" "uv"; text "primitive_group" "a"];
      "prims/uv text", [text "uv_attribute" "uv"; choice "output" "Text"];
      "prims/uv wrong storage", [text "uv_attribute" "float"];
      "prims/uv vec4", [text "uv_attribute" "vec4"];
      "prims/uv vec3", [text "uv_attribute" "vec3"];
      "prims/uv vec2", [text "uv_attribute" "vec2"] ]

let bench () =
  [Plane_generators.grid ~connectivity:Grid_quads ~columns:1000 ~rows:1000 ~size:8. () |> get_ok], []
let () = register { key = "connectivity"; native = Sop.Nodes.Connectivity.factory; inputs; cases; ulps = 4;
  bench = Some bench }
