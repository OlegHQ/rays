(* sop/blast_by_attribute: one geometry input (pending draft).
   Fixtures add a float "mask", an int "imask", a "bad" float with infinity and a text "label"
   on points and primitives, so the default cache check cooks and every branch is reached.
   Dropped cases (the gate cannot express them: native refuses at construction, but the Lisp
   :validate fires only when the node is built, after the gate accepted the checked workspace):
   reversed range, blank output group, blank attribute, remove_unused_points with Points or
   Create group, and a non-finite width interval. *)
open Rdk
open Port_gate
module P = Param
let fields ?(attribute = "mask") ?(mode = "Below threshold") ?(threshold = 0.5) ?(minimum = 0.) ?(maximum = 1.)
    ?(center = 0.5) ?(width = 0.5) ?(group = "") ?(invert = false) ?(output = "Delete elements")
    ?(output_group = "selected") ?(remove = false) owner =
  ["owner", P.Choice_value owner; "attribute", P.Text_value attribute; "mode", P.Choice_value mode;
   "threshold", P.Float_value threshold; "minimum", P.Float_value minimum; "maximum", P.Float_value maximum;
   "center", P.Float_value center; "width", P.Float_value width; "group", P.Text_value group;
   "invert", P.Bool_value invert; "output", P.Choice_value output; "output_group", P.Text_value output_group;
   "remove_unused_points", P.Bool_value remove]
let with_masks geometry =
  List.fold_left (fun geometry owner ->
    let n = match owner with Attribute.Point -> Geometry.point_count geometry
      | _ -> Geometry.primitive_count geometry in
    let float i = float ((i * 7) mod 11) /. 10. -. 0.2 in
    let add name storage geometry = Geometry.with_attribute
      (Attribute.create_owned ~owner ~name storage |> Rdk_test_support.get_string_ok) geometry
      |> Rdk_test_support.get_string_ok in
    geometry |> add "mask" (Attribute.Float (Array.init n float))
    |> add "imask" (Attribute.Int (Array.init n (fun i -> i mod 3 - 1)))
    |> add "bad" (Attribute.Float (Array.init n (fun i -> if i mod 4 = 2 then Float.infinity else float i)))
    |> add "label" (Attribute.Text (Array.make n "x")))
    geometry [Attribute.Point; Attribute.Primitive]
let inputs = List.map (fun (label, gs) -> label, List.map with_masks gs) standard_inputs
let cases =
  List.concat_map (fun owner ->
    let name label changes = Printf.sprintf "%s/%s" owner label, changes in
    [ name "below" (fields owner); name "below-invert" (fields ~invert:true owner);
      name "below-threshold" (fields ~threshold:0.3 ~attribute:"imask" owner);
      name "range" (fields ~mode:"Range" ~minimum:0.2 ~maximum:0.6 owner);
      name "range-int" (fields ~mode:"Range" ~attribute:"imask" ~minimum:0. ~maximum:1. owner);
      name "width" (fields ~mode:"Center and width" ~center:0.4 ~width:0.4 owner);
      name "width-invert" (fields ~mode:"Center and width" ~invert:true owner);
      name "width-zero" (fields ~mode:"Center and width" ~width:0. owner);
      name "base" (fields ~group:"a" owner); name "base-dest" (fields ~group:"dest_a" ~invert:true owner);
      name "base-missing" (fields ~group:"nope" owner); name "base-trim" (fields ~group:" a " owner);
      name "group-output" (fields ~output:"Create group" owner);
      name "group-output-named" (fields ~output:"Create group" ~output_group:"a" ~mode:"Range" owner);
      name "remove" (fields ~remove:(owner = "Primitives") owner);
      name "missing-attribute" (fields ~attribute:"nope" owner);
      name "text-attribute" (fields ~attribute:"label" owner);
      name "nonfinite" (fields ~attribute:"bad" owner);
      name "nonfinite-based" (fields ~attribute:"bad" ~group:"a" owner);
      name "wrong-owner-attr" (fields ~attribute:"P" owner);
      name "all" (fields ~threshold:100. owner); name "none" (fields ~threshold:(-100.) owner)])
    ["Points"; "Primitives"]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  let g = with_masks g in
  [g], fields ~threshold:0.4 "Primitives"
let () = register { key = "blast_by_attribute"; native = Sop.Nodes.Blast_by_attribute.factory; inputs;
  cases; ulps = 4; bench = Some bench }
