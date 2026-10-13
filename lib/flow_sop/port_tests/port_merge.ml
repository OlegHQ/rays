(* sop/merge: any number of geometry inputs. Fixtures hold one, two and three inputs with
   matching, mismatched (missing attributes, extra groups) and padded attribute/group sets. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let get_s = get_string_ok
let float_attr name owner k g =
  let n = match owner with Attribute.Point -> Geometry.point_count g | Vertex -> Geometry.vertex_count g
    | Primitive -> Geometry.primitive_count g | Detail -> 1 in
  Geometry.with_attribute (Attribute.create_owned ~name ~owner
    (Attribute.Float (Array.init n (fun i -> float (i + k) /. 3.))) |> get_s) g |> get_s
let int_attr name k g =
  let n = Geometry.primitive_count g in
  Geometry.with_attribute (Attribute.create_owned ~name ~owner:Attribute.Primitive
    (Attribute.Int (Array.init n (fun i -> i + k))) |> get_s) g |> get_s
let group name owner phase g =
  let n = match owner with Group.Point -> Geometry.point_count g | Vertex -> Geometry.vertex_count g
    | Primitive -> Geometry.primitive_count g in
  Geometry.with_group (Group.init ~owner ~name n (fun i -> i mod 2 = phase)) g |> get_s
let small c r = Plane_generators.grid ~connectivity:Grid_quads ~columns:c ~rows:r ~size:2. () |> get_ok
let a () = grid () |> float_attr "h" Attribute.Point 0 |> group "a" Group.Primitive 0 |> group "p" Group.Point 1
let b () = small 3 2 |> float_attr "h" Attribute.Point 5 |> group "a" Group.Primitive 1
let c () = small 1 4 |> float_attr "h" Attribute.Point 9 |> group "other" Group.Vertex 0
let line () = polygon_polyline () |> float_attr "h" Attribute.Point 2 |> group "a" Group.Primitive 0
(* Mismatched attribute schemas are an error in native merge and cannot be a gate fixture (an
   erroring default cook has no cache entry); test_concat covers them. Group sets that differ
   are padded, so they are fixtures here. *)
let inputs = [
  "one", [a ()]; "two", [a (); b ()]; "three", [a (); b (); c ()];
  "empty+points", [points 0; points 3]; "reordered", [c (); b (); a ()];
  "mixed-kinds", [line (); line (); line ()]; "tag-existing", [int_attr "src" 7 (b ()); int_attr "src" 1 (c ())];
  "single-point", [points 1; points 1; points 0] ]
let cases = [
  "tag", ["source_attribute", P.Text_value "src"];
  "tag_base", ["source_attribute", P.Text_value "src"; "source_base", P.Int_value 5];
  "tag_trimmed", ["source_attribute", P.Text_value "  src  "; "source_base", P.Int_value (-3)];
  "tag_blank", ["source_attribute", P.Text_value "   "];
  "base_only", ["source_base", P.Int_value 9];
  "tag_existing_name", ["source_attribute", P.Text_value "h"] ]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:500 ~rows:500 ~size:8. () |> get_ok in
  let n = Geometry.point_count g in
  let g = Geometry.with_attribute (Attribute.create_owned ~name:"h" ~owner:Attribute.Point
    (Attribute.Float (Array.init n float)) |> get_s) g |> get_s in
  [g; g; g], ["source_attribute", P.Text_value "src"]
let () = register { key = "merge"; native = Sop.Nodes.Merge.factory; inputs; cases; ulps = 4; bench = Some bench }
