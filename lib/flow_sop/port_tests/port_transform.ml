(* sop/transform: one geometry input (pending draft nodes/transform.pending). Finite inputs only:
   native error codes for non-finite attribute data are an open contract question. *)
open Port_gate
module P = Param
let fl name x = name, P.Float_value x
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let ch name value = name, P.Choice_value value
let vec prefix (x, y, z) = [fl (prefix ^ "_x") x; fl (prefix ^ "_y") y; fl (prefix ^ "_z") z]
let trs = vec "translate" (0.3, -0.7, 1.1) @ vec "rotate" (0.4, -0.9, 1.3) @ vec "scale" (1.5, 0.6, 2.)
let cases =
  [ "translate", vec "translate" (1., 2., 3.);
    "rotate", vec "rotate" (0.5, -0.3, 1.2);
    "scale", vec "scale" (2., 0.5, 1.5);
    "uniform", [fl "uniform_scale" 2.5];
    "uniform zero", [fl "uniform_scale" 0.];
    "shear", [fl "shear_xy" 0.5; fl "shear_xz" (-0.3); fl "shear_yz" 0.7] @ trs;
    "pivot", vec "pivot" (1., -2., 0.5) @ vec "rotate" (0.8, 0.2, -0.5);
    "pivot rotation", vec "pivot_rotation" (0.3, 0.6, -0.9) @ vec "pivot" (0.5, 0.5, 0.) @ trs;
    "invert", [bo "invert" true] @ trs;
    "invert singular", [bo "invert" true; fl "uniform_scale" 0.];
    "singular drops N", [fl "uniform_scale" 0.];
    "scale zero axis", vec "scale" (1., 0., 1.);
    "preserve length", [bo "preserve_normal_length" true] @ vec "scale" (2., 1., 0.5) @ vec "rotate" (0.2, 0.3, 0.4);
    "recompute", [bo "recompute_normals" true] @ trs;
    "recompute preserve", [bo "recompute_normals" true; bo "preserve_normal_length" true] @ trs;
    "group a", [tx "group" "a"] @ trs;
    "group padded", [tx "group" " a "] @ trs;
    "group b vertex", [ch "group_owner" "Vertex"; tx "group" "a"] @ trs;
    "group primitive", [ch "group_owner" "Primitive"; tx "group" "a"] @ trs;
    "group edge", [ch "group_owner" "Edge"; tx "group" "a"] @ trs;
    "group missing", [tx "group" "nope"];
    "group missing prim", [ch "group_owner" "Primitive"; tx "group" "nope"];
    "group recompute", [tx "group" "a"; bo "recompute_normals" true] @ trs;
    "matrix", [ch "mode" "Matrix"; fl "m00" 2.; fl "m01" 0.5; fl "m03" 1.; fl "m12" (-1.); fl "m11" 0.5;
               fl "m21" 0.25; fl "m23" (-2.)] ;
    "matrix perspective", [ch "mode" "Matrix"; fl "m30" 0.1; fl "m31" 0.2; fl "m33" 2.];
    "matrix w zero", [ch "mode" "Matrix"; fl "m33" 0.; fl "m03" 1.];
    "matrix singular", [ch "mode" "Matrix"; fl "m00" 0.; fl "m11" 0.];
    "matrix group", [ch "mode" "Matrix"; fl "m00" 3.; tx "group" "a"];
    "matrix ignores trs", [ch "mode" "Matrix"] @ trs;
    "matrix invert ignored", [ch "mode" "Matrix"; bo "invert" true; fl "m00" 2.] ]
  @ List.map (fun o -> "order " ^ o, [ch "order" o] @ trs @ vec "pivot" (0.5, 0., -1.) @ [fl "shear_xy" 0.4])
      ["SRT"; "STR"; "RST"; "RTS"; "TSR"; "TRS"]
  @ List.map (fun o -> "rotation order " ^ o,
      [ch "rotation_order" o] @ trs @ vec "pivot_rotation" (0.7, -0.4, 0.2))
      ["XYZ"; "XZY"; "YXZ"; "YZX"; "ZXY"; "ZYX"]
let bench () = [points 1_000_000], trs
let () = register { key = "transform"; native = Sop.Nodes.Transform.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
