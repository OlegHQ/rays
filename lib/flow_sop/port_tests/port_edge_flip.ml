(* sop/edge_flip: one geometry input. Fixtures carry a greedy edge group "pick" of edges that join two
   distinct polygons no other picked edge touches (flips succeed), plus the fixture groups "a" (every third
   edge: neighbouring picks share polygons) and "dest_a" for the refusals; shapes: quads, triangles, a
   pentagon beside a quad, a dart (concave flip), a non-manifold fan, the mixed polygon+polyline shape, point
   normals. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param

let curves ~x ~y ~z ~vertex_points ~offsets ~kinds =
  let topology = Topology.create_owned ~point_count:(Array.length x) ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:kinds |> get_string_ok in
  Geometry.create ~positions:(Packed.Float3.of_owned ~x ~y ~z |> get_string_ok) ~topology () |> get_string_ok
let polys ~x ~y ~z vertex_points offsets =
  curves ~x ~y ~z ~vertex_points ~offsets ~kinds:(Array.make (Array.length offsets - 1) Topology.Polygon)
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:4 ~rows:3 ~size:2. () |> get_ok
let triangles () = Plane_generators.grid ~connectivity:Grid_triangles ~columns:4 ~rows:3 ~size:2. () |> get_ok
(* a pentagon and a quad sharing the edge 1-2 *)
let pentagon_quad () = polys ~x:[|0.;2.;2.;1.;-0.5;4.;4.|] ~y:[|0.;0.;2.;3.;1.5;2.;0.|] ~z:(Array.make 7 0.)
  [|0;1;2;3;4; 2;1;6;5|] [|0;5;9|]
(* a dart: flipping its diagonal leaves the polygon (reflex corner) *)
let dart () = polys ~x:[|0.;2.;1.;1.|] ~y:[|0.;0.;0.5;-1.|] ~z:(Array.make 4 0.)
  [|0;3;1; 1;2;0|] [|0;3;6|]
let fan () = curves ~x:[|0.;1.;0.;0.;1.;2.;3.|] ~y:[|0.;0.;1.;-1.;2.;1.;0.|] ~z:(Array.make 7 0.)
  ~vertex_points:[|0;1;2; 1;0;3; 0;1;4; 2;3;5;6|] ~offsets:[|0;3;6;9;13|]
  ~kinds:[|Topology.Polygon; Polygon; Polygon; Closed_polyline|]
(* two triangles whose flipped diagonal has coincident endpoints *)
let coincident () = polys ~x:[|0.;1.;0.5;0.5|] ~y:[|0.;0.;1.;1.|] ~z:(Array.make 4 0.)
  [|0;1;2; 1;0;3|] [|0;3;6|]
(* the edge group "pick": greedy, each picked edge joins two polygons nobody else picked *)
let with_pick g =
  let topology = Geometry.topology g in
  let index = Topology_index.create topology in
  let view = Topology_index.Private.view index in
  let edges = Array.length view.edge_a in
  let used = Array.make (max 1 (Geometry.primitive_count g)) false in
  let pick = Array.make edges false in
  for e = 0 to edges - 1 do
    let first = view.edge_offsets.(e) in
    if view.edge_offsets.(e + 1) - first = 2 then begin
      let p = view.primitive_of_vertex.(view.edge_vertices.(first))
      and q = view.primitive_of_vertex.(view.edge_vertices.(first + 1)) in
      if p <> q && not used.(p) && not used.(q) then (used.(p) <- true; used.(q) <- true; pick.(e) <- true)
    end
  done;
  Geometry.with_edge_group (Edge_group.init ~topology ~index ~name:"pick" (fun e -> pick.(e))) g |> get_string_ok
let with_normals g =
  let n = Geometry.point_count g in
  let attribute = Attribute.create_owned ~owner:Attribute.Point ~name:"N"
    (Attribute.Float3 (Packed.Float3.Private.of_owned_exn ~x:(Array.init n (fun i -> float (i mod 3) *. 0.25))
       ~y:(Array.make n 1.) ~z:(Array.make n 0.))) |> get_string_ok in
  Geometry.with_attribute attribute g |> get_string_ok
let decorate g = with_pick (fixture_attributes (fixture_groups g))

let inputs = List.map (fun (label, g) -> label, [g]) [
  "empty", decorate (points 0); "single", decorate (points 1);
  "mixed", decorate (polygon_polyline ());
  "fan", decorate (fan ());
  "coincident", decorate (coincident ());
  "dart", decorate (dart ());
  "pentagon-quad", decorate (pentagon_quad ());
  "triangles-normals", with_normals (decorate (triangles ()));
  "grid-normals", with_normals (decorate (small_grid ()));
  "grid4225", decorate (grid ()) ]

let fields group cycles cva normals =
  ["group", P.Text_value group; "cycles", P.Int_value cycles; "cycle_vertex_attributes", P.Bool_value cva;
   "recompute_point_normals", P.Bool_value normals]
let cases =
  List.concat_map (fun (cycles, cva, normals) ->
    List.map (fun (label, group) -> Printf.sprintf "%d/%b/%b/%s" cycles cva normals label,
        fields group cycles cva normals)
      ["none", ""; "pick", "pick"; "padded pick", " pick "; "a", "a"; "dest", "dest_a"; "missing", "nothing"])
    [1, true, false; 1, false, true; 0, true, true; 2, true, true; 3, false, false; 5, true, true; 16, true, false]
  @ [ "literal", fields "literal *?[]^\\" 1 true false; "unicode", fields "\195\169\231\140\171" 1 true false ]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:500 ~rows:500 ~size:8. () |> get_ok in
  [with_pick g], fields "pick" 1 true false
let () = register { key = "edge_flip"; native = Sop.Nodes.Edge_flip.factory; inputs; cases; ulps = 4;
  bench = Some bench }
