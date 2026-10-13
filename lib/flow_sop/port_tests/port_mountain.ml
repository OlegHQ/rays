(* sop/mountain: one geometry input (pending draft nodes/mountain.pending). Finite inputs only:
   native error codes for non-finite attribute data are an open contract question. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let fl name x = name, P.Float_value x
let it name n = name, P.Int_value n
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let ch name value = name, P.Choice_value value
let vec prefix (x, y, z) = [fl (prefix ^ "_x") x; fl (prefix ^ "_y") y; fl (prefix ^ "_z") z]

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
(* Default direction is blank: the grid and mixed fixtures exercise the polygon area vector, the
   vertex-N average and the point N. *)
let inputs = standard_inputs @ List.map (fun (label, g) -> label, [g]) [
  "grid spread area", with_dir (spread (fixture_groups (grid ())));
  "vertex N", with_dir (with_vertex_normals (spread (fixture_groups (grid ()))));
  "vertex N mixed", with_vertex_normals (spread (base ()));
  "point N mixed", with_dir (with_vertex_normals (with_point_normals (spread (base ()))));
  "area mixed", with_dir (spread (base ())) ]

let cases =
  [ "seed", [it "seed" 1234];
    "seed auto", [ch "seed_mode" "Auto"; it "seed" 77];
    "height", [fl "height" 0.37];
    "height zero", [fl "height" 0.];
    "no normalize", [bo "normalize_direction" false; fl "height" 0.8];
    "offset", vec "offset" (0.3, -1.2, 2.5);
    "frequency", vec "frequency" (0.7, 2.3, 1.4);
    "frequency zero", vec "frequency" (0., 0., 0.);
    "octaves 1", [it "octaves" 1];
    "octaves 8", [it "octaves" 8; fl "height" 0.6];
    "lacunarity", [fl "lacunarity" 3.1];
    "roughness", [fl "roughness" 0.8];
    "roughness 0", [fl "roughness" 0.];
    "roughness 1", [fl "roughness" 1.];
    "group", [tx "group" "a"];
    "group padded", [tx "group" " a "];
    "group missing", [tx "group" "nope"];
    "mask", [tx "mask_attribute" "mask"];
    "mask padded", [tx "mask_attribute" " mask "];
    "mask missing", [tx "mask_attribute" "absent"];
    "mask wrong type", [tx "mask_attribute" "vec3"];
    "mask P", [tx "mask_attribute" "P"];
    "direction", [tx "direction_attribute" "dir"];
    "direction padded", [tx "direction_attribute" " dir "];
    "direction P", [tx "direction_attribute" "P"];
    "direction missing", [tx "direction_attribute" "absent"];
    "direction float", [tx "direction_attribute" "float"];
    "direction no normalize", [tx "direction_attribute" "dir"; bo "normalize_direction" false];
    "height attribute new", [tx "height_attribute" "elevation"];
    (* " elevation " (padded) dropped: native declares the untrimmed name in its node facts and then
       fails its own write with E_NODE_FACTS (a native defect, not reproducible in Lisp). *)
    "height attribute existing", [tx "height_attribute" "float"];
    "height attribute wrong type", [tx "height_attribute" "vec3"];
    "height attribute P", [tx "height_attribute" "P"];
    "height attribute group", [tx "height_attribute" "float"; tx "group" "a"];
    "height attribute new group", [tx "height_attribute" "elevation"; tx "group" "a"];
    "recompute", [bo "recompute_normals" true];
    "recompute height zero", [bo "recompute_normals" true; fl "height" 0.];
    "everything", [tx "group" "a"; tx "direction_attribute" "dir"; tx "mask_attribute" "mask";
        tx "height_attribute" "elevation"; it "seed" 31; fl "height" 1.4; bo "recompute_normals" true;
        bo "normalize_direction" false; it "octaves" 6; fl "lacunarity" 2.4; fl "roughness" 0.6]
        @ vec "offset" (1., 2., 3.) @ vec "frequency" (1.5, 0.5, 2.) ]
let bench () = [with_point_normals (spread (points 1_000_000))], [fl "height" 0.5; it "octaves" 3]
let () = register { key = "mountain"; native = Sop.Nodes.Mountain.factory; inputs; cases; ulps = 4; bench = Some bench }
