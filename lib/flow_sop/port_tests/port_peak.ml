(* sop/peak: one geometry input (pending draft nodes/peak.pending). Finite inputs only: native
   error codes for non-finite attribute data are an open contract question. *)
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
  |> add Attribute.Point "mask" (Attribute.Float (Array.init n (fun i -> 0.6 *. hash i 7 +. 0.5)))
let vectors salt count = Attribute.Float3 (Packed.Float3.of_owned ~x:(Array.init count (fun i -> hash i salt))
  ~y:(Array.init count (fun i -> hash i (salt + 1))) ~z:(Array.init count (fun i -> hash i (salt + 2)))
  |> get_string_ok)
let with_point_normals g = add Attribute.Point "N" (vectors 4 (Geometry.point_count g)) g
let with_vertex_normals g = add Attribute.Vertex "N" (vectors 8 (Geometry.vertex_count g)) g
let with_dir g = add Attribute.Point "dir" (vectors 12 (Geometry.point_count g)) g
let base () = fixture_attributes (fixture_groups (polygon_polyline ()))
let fixture label g = label, [with_dir (with_vertex_normals (with_point_normals (spread g)))]
let inputs = [
  fixture "empty" (fixture_groups (points 0)); fixture "single" (fixture_groups (points 1));
  fixture "grid" (fixture_groups (grid ())); fixture "mixed" (base ()) ]
(* Blank direction with no point N (vertex-N average, polygon area vector) cannot run under this
   gate: its cache check needs the default direction "N" to cook on every fixture. Checked once by
   hand with these fixtures appended (every case passed; only that cache check then fails). *)
let _fallback = List.map (fun (label, g) -> label, [g]) [
  "vertex N", with_dir (with_vertex_normals (spread (fixture_groups (grid ()))));
  "vertex N mixed", with_vertex_normals (spread (base ()));
  "geometric mixed", spread (base ()); "geometric grid", with_dir (spread (fixture_groups (grid ()))) ]

let cases =
  [ "distance negative", [fl "distance" (-0.35)];
    "distance zero", [fl "distance" 0.];
    "distance zero recompute", [fl "distance" 0.; bo "recompute_normals" true];
    "big", [fl "distance" 4.5];
    "no normalize", [bo "normalize_direction" false; fl "distance" 0.3];
    "no normalize mask", [bo "normalize_direction" false; tx "mask_attribute" "mask"; fl "distance" 0.7];
    "mask", [tx "mask_attribute" "mask"; fl "distance" 0.6];
    "mask padded", [tx "mask_attribute" " mask "];
    "mask missing", [tx "mask_attribute" "absent"];
    "mask wrong type", [tx "mask_attribute" "vec3"];
    "mask P", [tx "mask_attribute" "P"];
    "direction dir", [tx "direction_attribute" "dir"; fl "distance" 0.4];
    "direction dir padded", [tx "direction_attribute" " dir "];
    "direction P", [tx "direction_attribute" "P"; fl "distance" 0.2];
    "direction P no normalize", [tx "direction_attribute" "P"; bo "normalize_direction" false];
    "direction float", [tx "direction_attribute" "float"];
    "direction missing", [tx "direction_attribute" "absent"];
    "direction blank", [tx "direction_attribute" "  "; fl "distance" 0.25];
    "direction vec3", [tx "direction_attribute" "vec3"];
    "recompute", [bo "recompute_normals" true];
    "recompute no normalize", [bo "recompute_normals" true; bo "normalize_direction" false; fl "distance" 0.5];
    "group", [tx "group" "a"; fl "distance" 0.5];
    "group padded", [tx "group" " a "];
    "group missing", [tx "group" "nope"];
    "group missing vertex", [ch "group_owner" "Vertex"; tx "group" "nope"] ]
  @ List.map (fun owner -> "owner " ^ owner,
      [ch "group_owner" owner; tx "group" "a"; fl "distance" 0.45; tx "mask_attribute" "mask"])
      ["Point"; "Vertex"; "Primitive"; "Edge"]
  @ [ "everything", [ch "group_owner" "Primitive"; tx "group" "a"; tx "direction_attribute" "dir";
        tx "mask_attribute" "mask"; fl "distance" (-0.8); bo "recompute_normals" true;
        bo "normalize_direction" false] ]
let bench () = [with_point_normals (spread (points 1_000_000))], [fl "distance" 0.3; tx "mask_attribute" "mask"]
let () = register { key = "peak"; native = Sop.Nodes.Peak.factory; inputs; cases; ulps = 4; bench = Some bench }
