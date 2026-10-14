(* sop/duplicate: one geometry input (pending draft). Fixtures carry point and vertex normals "N" next to the
   standard groups (ordered ones included), edge groups and attributes of every storage. *)
open Rdk
open Port_gate
module P = Param
let tx name v = name, P.Text_value v
let fl name v = name, P.Float_value v
let bl name v = name, P.Bool_value v
let it name v = name, P.Int_value v
let with_normals geometry =
  let add owner count geometry =
    let n = count geometry in
    let plane f = Array.init n f in
    Rdk_test_support.get_string_ok (Geometry.with_attribute (Rdk_test_support.get_string_ok
      (Attribute.create_owned ~owner ~name:"N" (Attribute.Float3 (Rdk_test_support.get_string_ok
        (Packed.Float3.of_owned ~x:(plane (fun i -> float (i mod 3) -. 1.)) ~y:(plane (fun i -> 0.5 +. float (i mod 5)))
           ~z:(plane (fun i -> if i mod 7 = 0 then 0. else -0.25))))))) geometry) in
  geometry |> add Attribute.Point Geometry.point_count |> add Attribute.Vertex Geometry.vertex_count
let inputs = List.map (fun (label, g) -> label, [with_normals g]) [
  "empty", fixture_groups (points 0); "single", fixture_groups (points 1);
  "grid4225", fixture_groups (grid ());
  "mixed", fixture_attributes (fixture_groups (polygon_polyline ()))]
let matrix changes = List.map (fun (k, v) -> fl k v) changes
let translate = matrix ["m03", 1.5; "m13", -0.5; "m23", 2.]
let rotate = matrix ["m00", 0.; "m01", -1.; "m10", 1.; "m11", 0.; "m03", 0.25]
let scale = matrix ["m00", 1.5; "m11", 0.5; "m22", 2.; "m13", 0.125]
let singular = matrix ["m00", 0.]
let projective = matrix ["m30", 0.1; "m33", 2.]
let cases =
  List.concat_map (fun (label, m) ->
    List.map (fun (suffix, changes) -> label ^ suffix, m @ changes)
      ["", [];
       "/copies3", [it "copies" 3];
       "/not_cumulative", [it "copies" 3; bl "cumulative" false];
       "/group", [it "copies" 2; tx "group" "a"];
       "/group_ordered", [it "copies" 2; tx "group" "dest_a"];
       "/group_not_cumulative", [it "copies" 2; tx "group" "a"; bl "cumulative" false];
       "/prefix", [it "copies" 2; tx "copy_group_prefix" "copy_"];
       "/prefix_group", [it "copies" 3; tx "group" "a"; tx "copy_group_prefix" " c "];
       "/prefix_preserve", [it "copies" 2; tx "copy_group_prefix" "a"; bl "preserve_groups" true];
       "/prefix_replace", [it "copies" 2; tx "copy_group_prefix" "dest_a"];
       "/prefix_preserve_ordered", [it "copies" 1; tx "copy_group_prefix" "dest_a"; bl "preserve_groups" true; tx "group" "a"]])
    ["translate", translate; "rotate", rotate; "scale", scale; "singular", singular; "projective", projective]
  @ [ "defaults", [];
      "zero_copies", [it "copies" 0];
      "zero_copies_prefix", [it "copies" 0; tx "copy_group_prefix" "p"];
      "many_copies", [it "copies" 12; "m03", P.Float_value 0.5];
      "group_missing", [tx "group" "nope"];
      "group_blank", [tx "group" "  "];
      "group_empty_selection", [tx "group" "a"; tx "copy_group_prefix" "p"; it "copies" 2];
      "group_literal", [tx "group" "literal \\*\\?\\[\\]\\^\\\\"; it "copies" 2];
      "group_unicode", [tx "group" "\195\169\231\140\171"; it "copies" 2];
      "prefix_blank", [tx "copy_group_prefix" "   "; it "copies" 2];
      "prefix_too_many", [tx "copy_group_prefix" "p"; it "copies" 5000];
      "prefix_invalid_name", [tx "copy_group_prefix" "a b"; it "copies" 2];
      "prefix_unicode", [tx "copy_group_prefix" "\195\169"; it "copies" 2] ]
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  [g], [it "copies" 1; fl "m03" 1.]
let () = register { key = "duplicate"; native = Sop.Nodes.Duplicate.factory; inputs; cases; ulps = 4; bench = Some bench }
