(* sop/normals: one geometry input. Fixtures: the standard four, a randomised small grid and
   polygon+polyline with and without existing N on every owner (so selection merging, keep-zero and
   the unreversed smooth first pass are all exercised), and a collinear (zero-normal) mesh with N.
   Dropped: attribute names containing glob characters (the Lisp install deletes by pattern). *)
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
let spread geometry =
  let n = Geometry.point_count geometry in
  let plane salt scale count = Array.init count (fun i -> scale *. hash i salt) in
  Geometry.with_positions (Packed.Float3.of_owned ~x:(plane 1 2.5 n) ~y:(plane 2 2.5 n) ~z:(plane 3 2.5 n)
    |> get_string_ok) geometry |> get_string_ok
let vectors salt count = Attribute.Float3 (Packed.Float3.of_owned ~x:(Array.init count (fun i -> hash i salt))
  ~y:(Array.init count (fun i -> hash i (salt + 1))) ~z:(Array.init count (fun i -> hash i (salt + 2)))
  |> get_string_ok)
let with_normals g =
  g |> (fun g -> add Attribute.Point "N" (vectors 4 (Geometry.point_count g)) g)
    |> (fun g -> add Attribute.Vertex "N" (vectors 8 (Geometry.vertex_count g)) g)
    |> (fun g -> add Attribute.Primitive "N" (vectors 12 (Geometry.primitive_count g)) g)
    |> (fun g -> add Attribute.Detail "N" (vectors 16 1) g)
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:6 ~rows:6 ~size:4. () |> get_ok
let base () = fixture_attributes (fixture_groups (polygon_polyline ()))
let inputs = standard_inputs @ List.map (fun (label, g) -> label, [g]) [
  "zero normals N", with_normals (base ());
  "spread mixed", spread (base ());
  "spread mixed N", with_normals (spread (base ()));
  "spread grid", spread (fixture_groups (small_grid ()));
  "spread grid N", with_normals (spread (fixture_groups (small_grid ()))) ]

let owners = ["Point"; "Vertex"; "Primitive"; "Detail"]
let weightings = ["Vertex angle"; "Each vertex"; "Face area"]
let cases =
  List.concat_map (fun owner -> List.concat_map (fun weighting ->
    List.map (fun cusp -> Printf.sprintf "%s/%s/cusp %g" owner weighting cusp,
      [ch "owner" owner; ch "weighting" weighting; fl "cusp_angle" cusp])
      [3.141592653589793; 1.0; 0.]) weightings) owners
  @ List.concat_map (fun group_owner -> List.concat_map (fun owner ->
      List.map (fun group -> Printf.sprintf "%s group %S -> %s" group_owner group owner,
        [ch "group_owner" group_owner; tx "group" group; ch "owner" owner; fl "cusp_angle" 1.2])
        ["a"; "old_x"; " dest_a "]) owners)
    ["Point"; "Vertex"; "Primitive"; "Edge"]
  @ [ "missing group", [tx "group" "nothing"];
      "missing edge group", [ch "group_owner" "Edge"; tx "group" "nothing"];
      "keep zero", [bo "keep_original_zero" true];
      "keep zero point", [bo "keep_original_zero" true; ch "owner" "Point"];
      "keep zero primitive", [bo "keep_original_zero" true; ch "owner" "Primitive"];
      "keep zero detail", [bo "keep_original_zero" true; ch "owner" "Detail"];
      "keep zero group", [bo "keep_original_zero" true; tx "group" "a"; ch "owner" "Point"];
      "reverse", [bo "reverse" true];
      "reverse point group", [bo "reverse" true; ch "owner" "Point"; tx "group" "a"];
      "reverse vertex group cusp", [bo "reverse" true; tx "group" "a"; fl "cusp_angle" 0.8];
      "reverse primitive", [bo "reverse" true; ch "owner" "Primitive"];
      "reverse detail", [bo "reverse" true; ch "owner" "Detail"];
      "attribute", [tx "attribute" "n2"];
      "attribute point", [tx "attribute" "vec3"; ch "owner" "Point"];
      "attribute vertex", [tx "attribute" "vec3"; ch "owner" "Vertex"; tx "group" "a"];
      "attribute primitive", [tx "attribute" "vec3"; ch "owner" "Primitive"; bo "keep_original_zero" true];
      "attribute detail", [tx "attribute" "vec3"; ch "owner" "Detail"];
      "attribute float", [tx "attribute" "float"; ch "owner" "Point"];
      "attribute text", [tx "attribute" "text"; ch "owner" "Vertex"];
      "attribute blank", [tx "attribute" "  "];
      "cusp near pi", [fl "cusp_angle" 3.1415926535887];
      "cusp mid", [fl "cusp_angle" 1.5707963267948966; ch "weighting" "Each vertex"] ]

let bench () =
  let n = 1000 in
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:n ~rows:n ~size:8. () |> get_ok in
  [g], []
let () = register { key = "normals"; native = Sop.Nodes.Normal.factory; inputs; cases; ulps = 4; bench = Some bench }
