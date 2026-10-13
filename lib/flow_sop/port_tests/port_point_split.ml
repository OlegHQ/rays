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
      "unmatched", fields ~attributes:"nothing" () ]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> get_ok in
  [g], fields ~attributes:"" ()
let () = register { key = "point_split"; native = Sop.Nodes.Point_split.factory; inputs; cases; ulps = 4;
  bench = Some bench }
