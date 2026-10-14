(* sop/separate_pieces: one geometry input (pending draft nodes/separate_pieces.pending).
   Fixtures: separate pieces with an isolated point (every owner/attribute kind), a grid whose single piece
   shares points and carries constant translations, a grid whose pieces share points (native refuses
   Separate and Move back through shared points), and pieces at 1e17 where the gap vanishes in rounding
   (representability refusal). Each carries int/text/float piece attributes and vec3 translations. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let fl name x = name, P.Float_value x
let tx name value = name, P.Text_value value
let ch name value = name, P.Choice_value value

let add owner name storage g = Geometry.with_attribute
  (Attribute.create_owned ~owner ~name storage |> get_string_ok) g |> get_string_ok
let hash i salt = float ((i * 7919 + salt * 104729 + 13) mod 1000) /. 500. -. 1.
let vec3 n salt = Attribute.Float3 (Packed.Float3.of_owned ~x:(Array.init n (fun i -> hash i salt))
  ~y:(Array.init n (fun i -> hash i (salt + 1))) ~z:(Array.init n (fun i -> hash i (salt + 2))) |> get_string_ok)
let const3 n x y z = Attribute.Float3 (Packed.Float3.of_owned ~x:(Array.make n x) ~y:(Array.make n y)
  ~z:(Array.make n z) |> get_string_ok)
let label k = Printf.sprintf "name%d" k
let polygons ~x ~y ~z vertex_points offsets =
  let topology = Topology.create_owned ~point_count:(Array.length x) ~vertex_points ~primitive_offsets:offsets
    ~primitive_kinds:(Array.make (Array.length offsets - 1) Topology.Polygon) |> get_string_ok in
  Geometry.create ~positions:(Packed.Float3.of_owned ~x ~y ~z |> get_string_ok) ~topology () |> get_string_ok
(* piece ids per primitive and per point, translations constant (constant) or varying *)
let decorate ?(constant = false) g prim_piece point_piece =
  let np = Geometry.point_count g and nq = Geometry.primitive_count g in
  g
  |> add Attribute.Primitive "piece" (Attribute.Int prim_piece)
  |> add Attribute.Point "piece" (Attribute.Int point_piece)
  |> add Attribute.Primitive "label" (Attribute.Text (Array.map label prim_piece))
  |> add Attribute.Point "label" (Attribute.Text (Array.map label point_piece))
  |> add Attribute.Primitive "fl" (Attribute.Float (Array.map float prim_piece))
  |> add Attribute.Point "fl" (Attribute.Float (Array.map float point_piece))
  |> add Attribute.Primitive "piece_translation" (if constant then const3 nq 0.25 (-0.5) 1.5 else vec3 nq 3)
  |> add Attribute.Point "piece_translation" (if constant then const3 np 0.25 (-0.5) 1.5 else vec3 np 6)

let separated () =
  let g = polygons
    ~x:[|0.;1.;1.;0.; 0.5;2.;1.; -3.;-2.;-2.;-3.; 10.;11.;10.5; 4.|]
    ~y:[|0.;0.;1.;1.; 0.2;0.2;1.5; 0.;0.;1.;1.; 5.;5.;6.; 4.|]
    ~z:[|0.;0.;0.;0.; 0.1;0.1;0.1; 0.;0.;0.;0.; 0.;0.;0.; 4.|]
    [|0;1;2;3; 4;5;6; 7;8;9;10; 11;12;13|] [|0;4;7;11;14|] in
  decorate g [|5;5;2;9|] [|5;5;5;5; 5;5;5; 2;2;2;2; 9;9;9; 2|]
let grid_single () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:4 ~rows:3 ~size:4. () |> get_ok in
  decorate ~constant:true g (Array.make (Geometry.primitive_count g) 4) (Array.make (Geometry.point_count g) 4)
let grid_shared () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:4 ~rows:3 ~size:4. () |> get_ok in
  decorate g (Array.init (Geometry.primitive_count g) (fun i -> i mod 3)) (Array.init (Geometry.point_count g) (fun i -> i mod 2))
let huge () =
  let g = polygons
    ~x:[|1e17;1e17;1e17; 2e17;2e17;2e17; 3e17;3e17;3e17|] ~y:[|0.;1.;1.; 0.;1.;1.; 0.;1.;1.|]
    ~z:(Array.make 9 0.) [|0;1;2; 3;4;5; 6;7;8|] [|0;3;6;9|] in
  decorate g [|0;1;2|] [|0;0;0;1;1;1;2;2;2|]

let inputs = [ "separated", [separated ()]; "single piece grid", [grid_single ()];
  "shared grid", [grid_shared ()]; "huge", [huge ()] ]

let owners = ["Point"; "Primitive"]
let cases =
  List.concat_map (fun o -> [
    "separate " ^ o, [ch "owner" o];
    o ^ " text piece", [ch "owner" o; tx "piece_attribute" "label"];
    o ^ " float piece", [ch "owner" o; tx "piece_attribute" "fl"];
    o ^ " missing piece", [ch "owner" o; tx "piece_attribute" "nope"];
    o ^ " axis y", [ch "owner" o; fl "axis_x" 0.; fl "axis_y" 1.];
    o ^ " axis diagonal", [ch "owner" o; fl "axis_x" 1.; fl "axis_y" 1.; fl "axis_z" 1.];
    o ^ " axis negative z", [ch "owner" o; fl "axis_x" 0.; fl "axis_z" (-2.)];
    o ^ " axis zero", [ch "owner" o; fl "axis_x" 0.];
    o ^ " gap zero", [ch "owner" o; fl "gap" 0.];
    o ^ " gap half", [ch "owner" o; fl "gap" 0.5];
    o ^ " gap large", [ch "owner" o; fl "gap" 1000.; fl "axis_x" 0.; fl "axis_y" (-1.)];
    o ^ " translation renamed", [ch "owner" o; tx "translation_attribute" "shift"];
    o ^ " translation over float", [ch "owner" o; tx "translation_attribute" "fl"];
    o ^ " translation padded", [ch "owner" o; tx "translation_attribute" " shift "];
    o ^ " piece padded", [ch "owner" o; tx "piece_attribute" " piece "];
    o ^ " blank piece name", [ch "owner" o; tx "piece_attribute" "  "];
    o ^ " blank translation name", [ch "owner" o; tx "translation_attribute" ""];
    o ^ " same names", [ch "owner" o; tx "translation_attribute" "piece"];
    o ^ " move back", [ch "owner" o; ch "mode" "Move back"];
    o ^ " move back renamed", [ch "owner" o; ch "mode" "Move back"; tx "translation_attribute" "shift"];
    o ^ " move back wrong type", [ch "owner" o; ch "mode" "Move back"; tx "translation_attribute" "fl"];
    o ^ " move back missing", [ch "owner" o; ch "mode" "Move back"; tx "translation_attribute" "nope"];
    o ^ " move back same names", [ch "owner" o; ch "mode" "Move back"; tx "piece_attribute" "piece_translation"];
    o ^ " move back ignores axis", [ch "owner" o; ch "mode" "Move back"; fl "axis_x" 0.; fl "axis_y" 0.];
    o ^ " move back text piece", [ch "owner" o; ch "mode" "Move back"; tx "piece_attribute" "label"] ])
    owners

(* 250000 disjoint quads in 1000 pieces of 250: 1M points, a 1000-step placement scan *)
let bench () =
  let quads = 250_000 in
  let x = Array.make (quads * 4) 0. and y = Array.make (quads * 4) 0. and z = Array.make (quads * 4) 0. in
  for i = 0 to quads - 1 do
    let ox = float (i mod 500) *. 1.5 and oy = float (i / 500) *. 1.5 in
    x.(4*i) <- ox; y.(4*i) <- oy;
    x.(4*i+1) <- ox +. 1.; y.(4*i+1) <- oy;
    x.(4*i+2) <- ox +. 1.; y.(4*i+2) <- oy +. 1.;
    x.(4*i+3) <- ox; y.(4*i+3) <- oy +. 1.;
    z.(4*i) <- 0.01 *. float (i mod 7)
  done;
  let g = polygons ~x ~y ~z (Array.init (quads * 4) (fun i -> i)) (Array.init (quads + 1) (fun i -> i * 4)) in
  let pieces = 1000 in
  let g = g |> add Attribute.Primitive "piece" (Attribute.Int (Array.init quads (fun i -> i / (quads / pieces)))) in
  [g], []
let node = { key = "separate_pieces"; native = Sop.Nodes.Separate_pieces.factory; inputs; cases;
  ulps = 4; bench = Some bench }
let () = register node
