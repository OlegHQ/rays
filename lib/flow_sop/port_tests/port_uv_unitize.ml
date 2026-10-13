(* sop/uv_unitize: one geometry input. Fixtures are polygon-only with a vertex "uv" (a selected
   polyline errors under the default cook, which the cache check cannot accept, so the polyline error
   path and the non-finite UV error path are not covered), with discontinuities so Islands splits. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param

let grid_of connectivity columns rows =
  Plane_generators.grid ~connectivity ~columns ~rows ~size:4. () |> get_ok

(* UV from the point position with a per-primitive shift that cuts some edges apart. *)
let with_uv ?(cut = 3) geometry =
  let topology = Topology.Private.view (Geometry.topology geometry) in
  let positions = Packed.Float3.Private.view (Geometry.positions geometry) in
  let n = Array.length topology.vertex_points in
  let primitive_of = Array.make n 0 in
  for p = 0 to Array.length topology.primitive_offsets - 2 do
    for v = topology.primitive_offsets.(p) to topology.primitive_offsets.(p + 1) - 1 do primitive_of.(v) <- p done
  done;
  let shift v = if primitive_of.(v) mod cut = 0 then 0.3 else 0. in
  let x = Array.init n (fun v -> positions.x.(topology.vertex_points.(v)) *. 0.25 +. shift v)
  and y = Array.init n (fun v -> positions.y.(topology.vertex_points.(v)) *. 0.5 +. positions.z.(topology.vertex_points.(v)) *. 0.125
                                 -. shift v *. 0.5) in
  let uv = Attribute.create_owned ~owner:Attribute.Vertex ~name:"uv"
    (Attribute.Float2 (Packed.Float2.of_owned ~x ~y |> get_string_ok)) |> get_string_ok in
  Geometry.with_attribute uv geometry |> get_string_ok

let with_vertex_group geometry =
  let n = Geometry.vertex_count geometry in
  Geometry.with_group (Group.init ~owner:Group.Vertex ~name:"vseam" n (fun v -> v mod 5 = 1)) geometry |> get_string_ok

let flat geometry =
  (* Every corner at the same UV: a zero extent. *)
  let n = Geometry.vertex_count geometry in
  let uv = Attribute.create_owned ~owner:Attribute.Vertex ~name:"uv"
    (Attribute.Float2 (Packed.Float2.of_owned ~x:(Array.make n 0.25) ~y:(Array.make n (-0.5)) |> get_string_ok))
    |> get_string_ok in
  Geometry.with_attribute uv geometry |> get_string_ok

let decorate g = with_vertex_group (fixture_groups g)
let inputs = List.map (fun (label, g) -> label, [g]) [
  "quads", decorate (with_uv (grid_of Grid_quads 4 4));
  "quads-uncut", decorate (with_uv ~cut:1000000 (grid_of Grid_quads 3 3));
  "triangles", decorate (with_uv ~cut:2 (grid_of Grid_triangles 3 3));
  "flat", decorate (flat (grid_of Grid_quads 3 3));
  "empty", with_uv (fixture_groups (points 0));
  "grid4225", decorate (with_uv ~cut:5 (grid ())) ]

let fields mode uniform group seams =
  ["mode", P.Choice_value mode; "uniform", P.Bool_value uniform; "group", P.Text_value group;
   "seams", P.Text_value seams]
let cases =
  List.concat_map (fun mode ->
    List.concat_map (fun uniform ->
      List.concat_map (fun (glabel, group) ->
        List.map (fun (slabel, seams) -> Printf.sprintf "%s/%b/%s/%s" mode uniform glabel slabel,
          fields mode uniform group seams)
          ["none", ""; "edge", "a"; "vertex", "vseam"; "padded", " old_x "; "missing", "nothing"])
        ["all", ""; "a", "a"; "padded", " dest_a "; "missing", "nothing"])
      [true; false])
    ["Per face"; "Islands"]
  @ List.concat_map (fun mode -> [
      mode ^ "/tolerance big", ["mode", P.Choice_value mode; "tolerance", P.Float_value 0.4];
      mode ^ "/tolerance zero", ["mode", P.Choice_value mode; "tolerance", P.Float_value 0.];
      mode ^ "/other name", ["mode", P.Choice_value mode; "name", P.Text_value "other"];
      mode ^ "/blank name", ["mode", P.Choice_value mode; "name", P.Text_value "  "];
      mode ^ "/literal group", ["mode", P.Choice_value mode; "group", P.Text_value "literal *?[]^\\"];
      mode ^ "/unicode", ["mode", P.Choice_value mode; "group", P.Text_value "\195\169\231\140\171"] ])
    ["Per face"; "Islands"]
let bench () =
  [with_uv ~cut:7 (grid_of Grid_quads 700 700)], ["mode", P.Choice_value "Islands"]
let () = register { key = "uv_unitize"; native = Sop.Nodes.Uv_unitize.factory; inputs; cases; ulps = 4;
  bench = Some bench }
