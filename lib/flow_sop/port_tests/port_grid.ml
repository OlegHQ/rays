(* sop/grid: zero-input generator (pending draft nodes/grid.pending). *)
open Port_gate
module P = Param
let ch name value = name, P.Choice_value value
let it name n = name, P.Int_value n
let fl name x = name, P.Float_value x
let tx name value = name, P.Text_value value
let xyz prefix (x, y, z) = [fl (prefix ^ "_x") x; fl (prefix ^ "_y") y; fl (prefix ^ "_z") z]
let connectivities = ["Points"; "Rows"; "Columns"; "Rows and columns"; "Quads"; "Triangles";
  "Alternating triangles"; "Reverse triangles"]
let orientations = ["XY"; "XZ"; "YZ"; "Custom axes"]
let custom = xyz "horizontal" (0.25, -0.5, 0.75) @ xyz "vertical" (0.75, 0.5, -0.25)
let dims c r = [it "columns" c; it "rows" r]
let matrix = List.concat_map (fun counts -> List.concat_map (fun connectivity ->
  List.map (fun orientation ->
    Printf.sprintf "%s/%s/%s" counts connectivity orientation,
    [ch "counts" counts; ch "connectivity" connectivity; ch "orientation" orientation]
    @ dims 3 3 @ custom)
    orientations) connectivities) ["Divisions"; "Point counts"]
let modes = List.concat_map (fun w -> List.map (fun h ->
  Printf.sprintf "width=%s/height=%s" w h,
  [ch "width_mode" w; ch "height_mode" h; ch "orientation" "Custom axes"; fl "size" 1.5]
  @ dims 4 2 @ custom) ["Explicit"; "Auto"]) ["Explicit"; "Auto"]
let parameters = [
  "columns", dims 5 4 @ [ch "counts" "Point counts"];
  "rows", dims 4 5;
  "size/auto", [ch "width_mode" "Auto"; fl "size" 2.0] @ dims 3 3;
  "size/explicit", [ch "width_mode" "Explicit"; fl "size" 2.0] @ dims 3 3;
  "width/height", [fl "width" 2.75; fl "height" 0.625] @ dims 3 3;
  "center", xyz "center" (-2.5, 1.25, -0.75) @ dims 3 3;
  "rotation", [fl "rotation" 0.37] @ dims 3 3;
  "rotation/custom", [ch "orientation" "Custom axes"; fl "rotation" (-1.2)] @ custom @ dims 3 3;
  "uv/st", [tx "uv_attribute" "st"] @ dims 3 3;
  "uv/unicode", [tx "uv_attribute" "\195\169uv"] @ dims 3 3;
  "minimum/points", [ch "counts" "Point counts"; ch "connectivity" "Points"] @ dims 1 1;
  "minimum/divisions", [ch "connectivity" "Quads"] @ dims 1 1;
  "minimum/rows", [ch "counts" "Point counts"; ch "connectivity" "Rows"] @ dims 2 1;
  "minimum/columns", [ch "counts" "Point counts"; ch "connectivity" "Columns"] @ dims 1 2;
  "minimum/rows-and-columns", [ch "counts" "Point counts"; ch "connectivity" "Rows and columns"] @ dims 2 2;
  "error/size0", [fl "size" 0.] @ dims 3 3;
  "error/width0", [ch "width_mode" "Explicit"; fl "width" (-0.)] @ dims 3 3;
  "error/height0-auto", [ch "height_mode" "Auto"; fl "height" 0.] @ dims 3 3;
  "error/zero-horizontal", [ch "orientation" "Custom axes"] @ xyz "horizontal" (0., 0., 0.) @ dims 3 3;
  "error/parallel-axes", [ch "orientation" "Custom axes"] @ xyz "horizontal" (1., 0., 0.)
    @ xyz "vertical" (1., 0., 0.) @ dims 3 3;
  "error/too-few-points", [ch "counts" "Point counts"; ch "connectivity" "Quads"] @ dims 1 3;
  "error/max-rotation", [fl "rotation" Float.max_float] @ dims 3 3;
]
let cases = ("defaults", []) :: List.map (fun (name, c) -> name, c) parameters @ matrix @ modes
let bench () = [], dims 1000 1000
let () = register { key = "grid"; native = Sop.Nodes.Grid.factory; inputs = no_input;
  cases; ulps = 4; bench = Some bench }
