(* sop/snap_to_grid: one geometry input (pending draft nodes/snap_to_grid.pending). Finite inputs only:
   native error codes for non-finite attribute data are an open contract question. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let fl name x = name, P.Float_value x
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
  let vectors salt count = Attribute.Float3 (Packed.Float3.of_owned ~x:(plane salt 1. count)
    ~y:(plane (salt + 1) 1. count) ~z:(plane (salt + 2) 1. count) |> get_string_ok) in
  Geometry.with_positions (Packed.Float3.of_owned ~x:(plane 1 2.5 n) ~y:(plane 2 2.5 n) ~z:(plane 3 2.5 n)
    |> get_string_ok) geometry |> get_string_ok
  |> add Attribute.Point "weight" (Attribute.Float (Array.init n (fun i -> 1.5 +. hash i 7)))
  |> add Attribute.Point "N" (vectors 4 n)
  |> add Attribute.Vertex "N" (vectors 8 (Geometry.vertex_count geometry))
let base () = fixture_attributes (fixture_groups (polygon_polyline ()))
let inputs = standard_inputs @ List.map (fun (label, g) -> label, [g]) [
  "grid spread", spread (fixture_groups (grid ()));
  "mixed spread", spread (base ()) ]

let rule_tab = "float\taverage\t"
let weighted_rule = "float\tweighted_average\tweight"
let cases =
  [ "spacing", vec "spacing" (0.7, 1.9, 0.45);
    "spacing coarse", vec "spacing" (3., 3., 3.);
    "spacing zero", vec "spacing" (0., 1., 1.);
    "offset", vec "offset" (0.25, 0.5, 0.75);
    "offset one", vec "offset" (1., 1., 1.);
    "offset out of range", vec "offset" (1.5, 0., 0.);
    "offset negative", vec "offset" (-0.25, 0., 0.);
    "round down", [ch "rounding" "Down"] @ vec "spacing" (0.8, 0.8, 0.8);
    "round up", [ch "rounding" "Up"] @ vec "spacing" (0.8, 0.8, 0.8) @ vec "offset" (0.3, 0.3, 0.3);
    "round nearest", vec "spacing" (0.6, 0.35, 0.9) @ vec "offset" (0.1, 0.9, 0.5);
    "limit", [bo "limit_distance" true; fl "max_distance" 0.1] @ vec "spacing" (1., 1., 1.);
    "limit off value ignored", [fl "max_distance" 0.1];
    "limit zero", [bo "limit_distance" true; fl "max_distance" 0.];
    "limit big", [bo "limit_distance" true; fl "max_distance" 9.] @ vec "spacing" (2., 2., 2.);
    "group", [tx "group" "a"] @ vec "spacing" (0.7, 0.7, 0.7);
    "group padded", [tx "group" " a "] @ vec "spacing" (0.7, 0.7, 0.7);
    "group missing", [tx "group" "nope"];
    "snapped group", [tx "snapped_group" "snapped"] @ vec "spacing" (0.7, 0.7, 0.7);
    "snapped group padded", [tx "snapped_group" " snapped "] @ vec "spacing" (0.7, 0.7, 0.7);
    "snapped group nothing moved", [tx "snapped_group" "snapped"] @ vec "spacing" (1e-9, 1e-9, 1e-9);
    "snapped group existing", [tx "snapped_group" "a"] @ vec "spacing" (0.7, 0.7, 0.7);
    "snapped group same as group", [tx "group" "a"; tx "snapped_group" "a"] @ vec "spacing" (0.7, 0.7, 0.7);
    "snapped group limited", [tx "snapped_group" "snapped"; bo "limit_distance" true; fl "max_distance" 0.2];
    "fuse", [bo "fuse_points" true] @ vec "spacing" (3., 3., 3.);
    "fuse nothing", [bo "fuse_points" true] @ vec "spacing" (1e-9, 1e-9, 1e-9);
    "fuse group", [bo "fuse_points" true; tx "group" "a"] @ vec "spacing" (3., 3., 3.);
    "fuse snapped group", [bo "fuse_points" true; tx "snapped_group" "snapped"] @ vec "spacing" (3., 3., 3.);
    "fuse snapped same group", [bo "fuse_points" true; tx "group" "a"; tx "snapped_group" "a"]
      @ vec "spacing" (3., 3., 3.);
    "fuse average numeric", [bo "fuse_points" true; ch "attributes" "Average numeric"] @ vec "spacing" (3., 3., 3.);
    "fuse limit", [bo "fuse_points" true; bo "limit_distance" true; fl "max_distance" 0.5]
      @ vec "spacing" (3., 3., 3.);
    "attribute rule", [bo "fuse_points" true; tx "attribute_rules" rule_tab] @ vec "spacing" (3., 3., 3.);
    "group rule", [bo "fuse_points" true; tx "group_rules" "a*\tunion"] @ vec "spacing" (3., 3., 3.);
    "rules not fused", [tx "attribute_rules" rule_tab; tx "group_rules" "a*\tunion"];
    "attribute rule bad columns", [tx "attribute_rules" "float\taverage"];
    "attribute rule bad method", [tx "attribute_rules" "float\tbogus\t"];
    "attribute rule weighted no weight", [tx "attribute_rules" "float\tweighted_sum\t"];
    "attribute rule weighted", [bo "fuse_points" true; tx "attribute_rules" weighted_rule] @ vec "spacing" (3., 3., 3.);
    "attribute rule bad glob", [tx "attribute_rules" "[\taverage\t"];
    "group rule bad columns", [tx "group_rules" "a\tunion\textra"];
    "group rule bad method", [tx "group_rules" "a\tbogus"];
    "table bad escape", [tx "group_rules" "a\\x\tunion"] ]
  @ List.map (fun position -> "fuse position " ^ position,
      [bo "fuse_points" true; ch "position" position; tx "weight_attribute" "weight"] @ vec "spacing" (3., 3., 3.))
      ["First"; "Least point"; "Greatest point"; "Average"; "Minimum"; "Maximum"; "Mode"; "Median"; "Sum";
       "Sum squares"; "Root mean square"; "Weighted average"; "Weighted sum"; "Minimum weight"; "Maximum weight"]
  @ [ "weighted no attribute", [bo "fuse_points" true; ch "position" "Weighted average"] @ vec "spacing" (3., 3., 3.);
      "weight missing", [bo "fuse_points" true; ch "position" "Weighted sum"; tx "weight_attribute" "absent"]
        @ vec "spacing" (3., 3., 3.);
      "everything", [bo "fuse_points" true; tx "group" "a"; ch "rounding" "Up"; bo "limit_distance" true;
        fl "max_distance" 1.5; ch "position" "Weighted average"; tx "weight_attribute" "weight";
        ch "attributes" "Average numeric"; tx "snapped_group" "snapped"; tx "attribute_rules" rule_tab;
        tx "group_rules" "a*\tunion"] @ vec "spacing" (2.2, 1.7, 3.1) @ vec "offset" (0.4, 0.2, 0.6) ]
let bench () = [points 1_000_000], vec "spacing" (0.3, 0.3, 0.3) @ vec "offset" (0.1, 0.2, 0.3)
let () = register { key = "snap_to_grid"; native = Sop.Nodes.Snap_to_grid.factory; inputs; cases; ulps = 4;
  bench = Some bench }
