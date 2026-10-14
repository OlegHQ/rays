(* sop/point_split: one geometry input. The default Attributes pattern "*" selects seam mode on any fixture
   with vertex or primitive attributes or groups, so the gate's default cook exercises the seam mode that the
   draft does not implement (see nodes/point_split.pending). *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param

let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:3 ~rows:3 ~size:2. () |> get_ok
let decorate g = fixture_attributes (fixture_groups g)
let inputs = List.map (fun (label, g) -> label, [decorate g]) [
  "empty", points 0; "single", points 1; "mixed", polygon_polyline (); "grid", small_grid (); "grid4225", grid () ]

let fields ?(owner = "Point") ?(group = "") ?(attributes = "*") ?(tolerance = 0.) ?(promote = false) () =
  ["group_owner", P.Choice_value owner; "group", P.Text_value group; "attributes", P.Text_value attributes;
   "tolerance", P.Float_value tolerance; "promote_attributes", P.Bool_value promote]
let cases =
  List.concat_map (fun (olabel, owner) ->
    List.map (fun (glabel, group) -> Printf.sprintf "plain/%s/%s" olabel glabel,
      fields ~owner ~group ~attributes:"" ())
      ["all", ""; "a", "a"; "dest", "dest_a"; "missing", "nothing"])
    ["point", "Point"; "vertex", "Vertex"; "primitive", "Primitive"]
  @ [ "seam default", fields (); "seam tolerance", fields ~tolerance:0.3 ();
      "seam names", fields ~attributes:"float vec3" (); "seam promote", fields ~promote:true ();
      "seam group", fields ~owner:"Vertex" ~group:"a" ~attributes:"a dest_a" ();
      "unmatched", fields ~attributes:"nothing" ();
      "seam integer", fields ~attributes:"integer" ();
      "seam text", fields ~attributes:"text" ();
      "seam integer text", fields ~attributes:"integer text" ();
      "seam float", fields ~attributes:"float" ();
      "seam float tolerance small", fields ~attributes:"float" ~tolerance:0.05 ();
      "seam float tolerance wide", fields ~attributes:"float" ~tolerance:0.6 ();
      "seam float tolerance full", fields ~attributes:"float vec2 vec3 vec4" ~tolerance:1. ();
      "seam vec tolerance", fields ~attributes:"vec2 vec3" ~tolerance:0.2 ();
      "seam discrete tolerance", fields ~attributes:"integer text" ~tolerance:0.4 ();
      "seam integer before float", fields ~attributes:"integer float" ~tolerance:0.3 ();
      "seam rows", fields ~attributes:"float_rows int_rows" ();
      "seam rows tolerance", fields ~attributes:"float_rows int_rows" ~tolerance:0.3 ();
      "seam groups", fields ~attributes:"a dest_a old_x" ();
      "seam groups tolerance", fields ~attributes:"a dest_a" ~tolerance:0.5 ();
      "seam literal group", fields ~attributes:"literal\\ \\*\\?\\[\\]\\^\\\\" ();
      "seam exclusion", fields ~attributes:"* ^float ^vec*" ();
      "seam owner point group", fields ~owner:"Point" ~group:"a" ~attributes:"integer" ();
      "seam owner vertex group", fields ~owner:"Vertex" ~group:"a" ~attributes:"integer" ();
      "seam owner primitive group", fields ~owner:"Primitive" ~group:"dest_a" ~attributes:"integer float" ();
      "seam owner vertex group tolerance", fields ~owner:"Vertex" ~group:"old_x" ~attributes:"float vec3" ~tolerance:0.3 ();
      "seam owner primitive all", fields ~owner:"Primitive" ~group:"a" ~attributes:"*" ~tolerance:0.1 ();
      "seam missing group", fields ~owner:"Vertex" ~group:"nothing" ~attributes:"integer" ();
      "seam edge owner", fields ~owner:"Edge" ~attributes:"integer" ();
      "seam edge owner group", fields ~owner:"Edge" ~group:"a" ~attributes:"integer" ();
      "promote integer", fields ~attributes:"integer" ~promote:true ();
      "promote float vec", fields ~attributes:"float vec2 vec3 vec4" ~promote:true ();
      "promote text", fields ~attributes:"text" ~promote:true ();
      "promote rows", fields ~attributes:"float_rows int_rows" ~promote:true ();
      "promote groups only", fields ~attributes:"a dest_a" ~promote:true ();
      "promote mixed pattern", fields ~attributes:"integer a" ~promote:true ();
      "promote group selection", fields ~owner:"Vertex" ~group:"a" ~attributes:"integer float" ~promote:true ();
      "promote tolerance", fields ~attributes:"float vec3" ~promote:true ~tolerance:0.3 ();
      "promote conflict", fields ~attributes:"float" ~promote:true ();
      "promote plain", fields ~attributes:"" ~promote:true ();
      "tolerance plain", fields ~attributes:"" ~tolerance:0.5 ();
      "bad pattern", fields ~attributes:"[" ();
      "blank pattern spaces", fields ~attributes:"   " ();
      "pattern trailing space", fields ~attributes:"integer  " () ]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> get_ok in
  [g], fields ~attributes:"" ()
let () = register { key = "point_split"; native = Sop.Nodes.Point_split.factory; inputs; cases; ulps = 4;
  bench = Some bench }
