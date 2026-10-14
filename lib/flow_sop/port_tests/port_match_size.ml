(* sop/match_size: a source input and an optional target (pending draft nodes/match_size.pending).
   Fixtures with one geometry use the numeric target; fixtures with two use the target geometry.
   Source and target carry point and vertex N so the normal rescaling is compared too. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let fl name x = name, P.Float_value x
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let ch name value = name, P.Choice_value value

let hash i salt = float ((i * 7919 + salt * 104729 + 13) mod 1000) /. 500. -. 1.
let add owner name storage g = Geometry.with_attribute
  (Attribute.create_owned ~owner ~name storage |> get_string_ok) g |> get_string_ok
let vectors salt count = Attribute.Float3 (Packed.Float3.of_owned ~x:(Array.init count (fun i -> hash i salt))
  ~y:(Array.init count (fun i -> hash i (salt + 1))) ~z:(Array.init count (fun i -> hash i (salt + 2)))
  |> get_string_ok)
let with_normals g =
  add Attribute.Vertex "N" (vectors 8 (Geometry.vertex_count g))
    (add Attribute.Point "N" (vectors 4 (Geometry.point_count g)) g)
let spread geometry =
  let n = Geometry.point_count geometry in
  let plane salt scale count = Array.init count (fun i -> scale *. hash i salt) in
  Geometry.with_positions (Packed.Float3.of_owned ~x:(plane 1 2.5 n) ~y:(plane 2 1.5 n) ~z:(plane 3 0.75 n)
    |> get_string_ok) geometry |> get_string_ok
(* A group with no members: selecting it leaves no points, which native refuses (a case, not a default). *)
let empty_groups g =
  List.fold_left (fun g (owner, length) -> Geometry.with_group
    (Group.ordered ~owner ~name:"none" ~length [||] |> get_string_ok) g |> get_string_ok) g
    [Group.Point, Geometry.point_count g; Group.Vertex, Geometry.vertex_count g;
     Group.Primitive, Geometry.primitive_count g]
let mixed () = empty_groups (with_normals (fixture_attributes (fixture_groups (polygon_polyline ()))))
(* A small quad grid keeps --full short (the standard 64 x 64 one makes every case slow). *)
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:6 ~rows:5 ~size:8. () |> get_ok
let big_grid () = empty_groups (with_normals (fixture_groups (small_grid ())))
(* A planar affine image of the grid: its quads stay simple, so area and volume fits can measure it. *)
let moved_grid () =
  let g = fixture_groups (small_grid ()) in
  let n = Geometry.point_count g in
  let view = Packed.Float3.Private.view (Geometry.positions g) in
  let moved = Packed.Float3.of_owned
    ~x:(Array.init n (fun i -> 1.5 *. view.x.(i) +. 0.3))
    ~y:(Array.init n (fun i -> 0.5 *. view.y.(i) -. 1.))
    ~z:(Array.init n (fun i -> view.z.(i) +. 0.2 *. view.x.(i))) |> get_string_ok in
  empty_groups (with_normals (Geometry.with_positions moved g |> get_string_ok))
let inputs = [
  "single", [fixture_groups (points 1)];
  "mixed", [mixed ()];
  "grid", [big_grid ()];
  "mixed -> grid", [mixed (); moved_grid ()];
  "grid -> mixed", [moved_grid (); mixed ()];
  (* Scattered points make bowtie quads: native's ear clipper refuses them in metric fits. *)
  "scattered -> grid", [empty_groups (with_normals (spread (fixture_groups (small_grid ())))); moved_grid ()] ]

let cases =
  let owners = ["Point"; "Vertex"; "Primitive"; "Edge"] in
  List.map (fun o -> "move " ^ o, [ch "group_owner" o; tx "group" "a"]) owners
  @ List.map (fun o -> "source " ^ o, [ch "source_group_owner" o; tx "source_group" "a"]) owners
  @ List.map (fun o -> "target " ^ o, [ch "target_group_owner" o; tx "target_group" "a"]) owners
  @ [ "move padded", [tx "group" " a "];
      "move missing", [tx "group" "nope"];
      "move missing vertex", [ch "group_owner" "Vertex"; tx "group" "nope"];
      "source missing", [tx "source_group" "nope"];
      "source missing edge", [ch "source_group_owner" "Edge"; tx "source_group" "nope"];
      "target missing", [tx "target_group" "nope"];
      "target missing primitive", [ch "target_group_owner" "Primitive"; tx "target_group" "nope"];
      "source empty", [tx "source_group" "none"];
      "source empty prim", [ch "source_group_owner" "Primitive"; tx "source_group" "none"; ch "fit" "Match area"];
      "target empty", [tx "target_group" "none"];
      "move empty", [tx "group" "none"; fl "offset_x" 1.];
      "move empty vertex", [ch "group_owner" "Vertex"; tx "group" "none"; ch "fit" "Stretch"];
      "all groups",[tx "group" "a"; tx "source_group" "dest_a"; tx "target_group" "a"; ch "fit" "Stretch"];
      "all groups prims", [ch "group_owner" "Primitive"; tx "group" "a"; ch "source_group_owner" "Vertex";
        tx "source_group" "a"; ch "target_group_owner" "Edge"; tx "target_group" "a"; ch "fit" "Cover"] ]
  @ List.map (fun fit -> "fit " ^ fit, [ch "fit" fit])
      ["Translate only"; "Stretch"; "Contain"; "Cover"; "Match X"; "Match Y"; "Match Z";
       "Match perimeter"; "Match area"; "Match volume"]
  @ List.concat_map (fun fit -> [
      "fit " ^ fit ^ " prim groups", [ch "fit" fit; ch "source_group_owner" "Primitive"; tx "source_group" "a";
        ch "target_group_owner" "Primitive"; tx "target_group" "dest_a"];
      "fit " ^ fit ^ " source prim only", [ch "fit" fit; ch "source_group_owner" "Primitive"; tx "source_group" "a"];
      "fit " ^ fit ^ " point group", [ch "fit" fit; tx "source_group" "a"];
      "fit " ^ fit ^ " scaled", [ch "fit" fit; fl "scale" 1.75; fl "offset_y" 0.5] ])
      ["Match perimeter"; "Match area"; "Match volume"]
  @ List.concat_map (fun fit -> [
      "stretch axes " ^ fit, [ch "fit" fit; bo "scale_x" false];
      "axes y " ^ fit, [ch "fit" fit; bo "scale_y" false; bo "translate_y" false];
      "axes z " ^ fit, [ch "fit" fit; bo "scale_z" false; bo "translate_z" false; bo "translate_x" false];
      "justify " ^ fit, [ch "fit" fit; fl "justify_x" 0.5; fl "justify_y" (-1.); fl "justify_z" 0.25;
        fl "target_justify_x" (-0.5); fl "target_justify_y" 1.; fl "target_justify_z" 0.3];
      "auto " ^ fit, [ch "fit" fit; ch "target_justify_mode" "Auto"; fl "justify_x" 0.5; fl "justify_y" (-0.75);
        fl "target_justify_z" 0.9] ])
      ["Translate only"; "Stretch"; "Contain"; "Cover"; "Match Y"]
  @ List.map (fun name -> "set " ^ name, [fl name 0.5])
      ["justify_x"; "justify_y"; "justify_z"; "target_justify_x"; "target_justify_y"; "target_justify_z";
       "offset_x"; "offset_y"; "offset_z"; "scale"; "target_center_x"; "target_center_y"; "target_center_z";
       "target_size_x"; "target_size_y"; "target_size_z"]
  @ List.map (fun name -> "toggle " ^ name, [bo name false])
      ["translate_x"; "translate_y"; "translate_z"; "scale_x"; "scale_y"; "scale_z"]
  @ [ "stretch toggles", [ch "fit" "Stretch"; bo "scale_x" false; bo "scale_z" false; bo "translate_y" false];
      "numeric target", [ch "fit" "Stretch"; fl "target_center_x" 3.; fl "target_center_y" (-2.); fl "target_center_z" 1.;
        fl "target_size_x" 4.; fl "target_size_y" 0.5; fl "target_size_z" 7.];
      "numeric cover", [ch "fit" "Cover"; fl "target_size_x" 4.; fl "target_size_y" 0.5; fl "target_size_z" 7.];
      "scale zero", [fl "scale" 0.];
      "scale zero stretch", [ch "fit" "Stretch"; fl "scale" 0.];
      "size zero x stretch", [ch "fit" "Stretch"; fl "target_size_x" 0.];
      "size zero all", [fl "target_size_x" 0.; fl "target_size_y" 0.; fl "target_size_z" 0.];
      "size zero x match", [ch "fit" "Match X"; fl "target_size_x" 0.];
      "huge center", [fl "target_center_x" 1e308; fl "target_size_x" 1e308];
      "huge scale", [ch "fit" "Stretch"; fl "target_size_x" 1e300; fl "scale" 1e300; fl "offset_x" 1e300];
      "offset translate only", [ch "fit" "Translate only"; fl "offset_x" 3.; fl "offset_y" (-1.5); fl "offset_z" 0.25];
      "everything", [ch "group_owner" "Primitive"; tx "group" "a"; ch "fit" "Stretch"; fl "scale" 1.3;
        fl "offset_x" 0.5; fl "justify_x" (-0.5); fl "target_justify_y" 0.5; bo "translate_z" false;
        fl "target_center_x" 1.; fl "target_size_z" 3.] ]

let bench () = [spread (points 1_000_000)], [fl "target_size_x" 2.; fl "target_center_y" 1.]
let () = register { key = "match_size"; native = Sop.Nodes.Match_size.factory; inputs; cases; ulps = 4;
  bench = Some bench }
