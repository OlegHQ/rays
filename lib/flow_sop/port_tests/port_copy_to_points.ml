(* sop/copy_to_points: source and targets. The source carries every attribute storage on every owner, the
   standard groups (ordered ones, edge groups) and point/vertex normals; the target fixtures each carry one
   family of frame attributes (pscale/scale, orient, N with or without up, v, rot, trans/pivot, 9- and
   16-wide transform rows), so every branch of the frame rule meets a case. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let tx name v = name, P.Text_value v
let bo name v = name, P.Bool_value v

let plane f n = Array.init n f
let float3 n fx fy fz = Attribute.Float3 (get_string_ok (Packed.Float3.of_owned ~x:(plane fx n) ~y:(plane fy n) ~z:(plane fz n)))
let float4 n fx fy fz fw =
  Attribute.Float4 (get_string_ok (Packed.Float4.of_owned ~x:(plane fx n) ~y:(plane fy n) ~z:(plane fz n) ~w:(plane fw n)))
let put owner name storage geometry =
  get_string_ok (Geometry.with_attribute (get_string_ok (Attribute.create_owned ~owner ~name storage)) geometry)
let with_normals geometry =
  let add owner count geometry =
    let n = count geometry in
    put owner "N" (float3 n (fun i -> float (i mod 3) -. 1.) (fun i -> 0.5 +. float (i mod 5))
      (fun i -> if i mod 7 = 0 then 0. else -0.25)) geometry in
  geometry |> add Attribute.Point Geometry.point_count |> add Attribute.Vertex Geometry.vertex_count
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:3 ~rows:3 ~size:2. () |> get_ok
let mixed () = with_normals (fixture_attributes (fixture_groups (polygon_polyline ())))
let grid_source () = with_normals (fixture_attributes (fixture_groups (small_grid ())))

(* five targets at distinct places; the groups of the standard fixtures give them point groups *)
let base_targets () = fixture_groups (Kernel.generate_point_ranges 5 (fun ~first ~last ~x ~y ~z ->
  for i = first to last - 1 do x.(i) <- float i *. 1.5; y.(i) <- 0.25 *. float (i * i); z.(i) <- -1. +. float i done))
let pscale g = put Attribute.Point "pscale" (Attribute.Float [|1.; 2.; 0.5; -1.; 0.|]) g
let scale g = put Attribute.Point "scale" (float3 5 (fun i -> 1. +. float i) (fun i -> 2. -. 0.25 *. float i) (fun _ -> 0.5)) g
let orient g = put Attribute.Point "orient" (float4 5 (fun i -> 0.1 *. float i) (fun _ -> 0.2) (fun i -> 0.3 -. 0.1 *. float i)
  (fun i -> if i = 4 then 0. else 1.)) g
let zero_orient g = put Attribute.Point "orient" (float4 5 (fun _ -> 0.) (fun _ -> 0.) (fun _ -> 0.) (fun _ -> 0.)) g
let normal g = put Attribute.Point "N" (float3 5 (fun i -> [|0.; 1.; 0.; 3.; 0.2|].(i)) (fun i -> [|0.; 0.; 1.; 0.; 0.4|].(i))
  (fun i -> [|0.; 0.; -1.; -2.; 0.6|].(i))) g
let up g = put Attribute.Point "up" (float3 5 (fun i -> [|0.; 1.; 0.; 1.; 0.|].(i)) (fun i -> [|1.; 0.; 0.; 1.; 0.|].(i))
  (fun i -> [|0.; 0.; 1.; 0.; 0.|].(i))) g
let velocity g = put Attribute.Point "v" (float3 5 (fun i -> float i -. 2.) (fun _ -> 1.) (fun i -> 0.5 *. float i)) g
let rot g = put Attribute.Point "rot" (float4 5 (fun _ -> 0.) (fun i -> 0.3 *. float i) (fun _ -> 0.) (fun _ -> 1.)) g
let trans g = put Attribute.Point "trans" (float3 5 (fun i -> 0.5 *. float i) (fun _ -> -0.25) (fun _ -> 2.)) g
let pivot g = put Attribute.Point "pivot" (float3 5 (fun i -> 0.1 *. float i) (fun _ -> 0.5) (fun _ -> -0.5)) g
let matrix_rows width g =
  let row i =
    let a = [|1.; 0.5 *. float i; 0.; 0.; 2.; 0.25; 0.; 0.; 1. +. float i|] in
    if width = 9 then a
    else [|a.(0); a.(1); a.(2); 0.5 *. float i; a.(3); a.(4); a.(5); -1.; a.(6); a.(7); a.(8); 0.25; 0.; 0.; 0.; 1.|] in
  let rows = Array.init 5 row in
  let rows = if width = 16 then (rows.(3).(0) <- 0.; rows.(3).(1) <- 0.; rows.(3).(2) <- 0.; rows.(3).(4) <- 0.; rows.(3).(5) <- 0.;
    rows.(3).(6) <- 0.; rows.(3).(8) <- 0.; rows.(3).(9) <- 0.; rows.(3).(10) <- 0.; rows) else rows in
  put Attribute.Point "transform" (Attribute.Float_array (get_string_ok (Packed.Float_array.create_owned
    ~offsets:(Array.init 6 (fun i -> i * width)) ~values:(Array.concat (Array.to_list rows))))) g
let rule_targets () = fixture_groups (fixture_attributes (Kernel.generate_point_ranges 4 (fun ~first ~last ~x ~y ~z ->
  for i = first to last - 1 do x.(i) <- float i; y.(i) <- 0.5; z.(i) <- -. float i done)))
let mismatch_targets () = put Attribute.Point "integer" (Attribute.Float [|1.; 2.; 3.; 4.; 5.|]) (base_targets ())
let all_frame g = g |> pscale |> scale |> orient |> rot |> trans |> pivot

let targets = [
  "plain", base_targets ();
  "pscale", pscale (base_targets ());
  "scale", scale (base_targets ());
  "orient", orient (base_targets ());
  "orient_zero", zero_orient (base_targets ());
  "normal", normal (base_targets ());
  "normal_up", up (normal (base_targets ()));
  "velocity_up", up (velocity (base_targets ()));
  "rot", rot (base_targets ());
  "trans_pivot", pivot (trans (base_targets ()));
  "matrix16", matrix_rows 16 (base_targets ());
  "matrix9", matrix_rows 9 (base_targets ());
  "frames", all_frame (base_targets ());
  "mismatch", mismatch_targets ();
  "rules", rule_targets ()]
let sources = [ "mixed", mixed (); "grid", grid_source () ]
let ints a = Attribute.Int a
let texts a = Attribute.Text a
let piece_source () =
  grid_source ()
  |> put Attribute.Primitive "variant" (ints (Array.init 9 (fun i -> i mod 3)))
  |> put Attribute.Primitive "tag" (texts (Array.init 9 (fun i -> [|"a"; "b"; "c"|].(i mod 3))))
  |> put Attribute.Point "pvariant" (ints (Array.init 16 (fun i -> (i / 4) mod 2)))
  |> put Attribute.Point "ptag" (texts (Array.init 16 (fun i -> [|"x"; "y"|].((i / 4) mod 2))))
let piece_targets () =
  base_targets ()
  |> put Attribute.Point "variant" (ints [|0; 1; 2; 7; 1|])
  |> put Attribute.Point "tag" (texts [|"a"; "c"; "zz"; "b"; "a"|])
  |> put Attribute.Point "pvariant" (ints [|1; 0; 5; 1; 0|])
  |> put Attribute.Point "ptag" (texts [|"y"; "x"; "q"; "y"; "x"|])
  |> put Attribute.Point "nofloat" (Attribute.Float [|0.; 1.; 2.; 3.; 4.|])
let inputs = List.concat_map (fun (tl, t) -> List.map (fun (sl, s) -> sl ^ "<-" ^ tl, [s; t]) sources) targets
  @ ["pieces", [piece_source (); piece_targets ()]; "pieces from plain", [mixed (); piece_targets ()]; "pieces empty", [grid_source (); piece_targets ()]]

let rule p o op = String.concat "\t" [p; o; op]
let rules rs = tx "target_attributes" (String.concat "\n" rs)
let cases = [
  "piece variant", [tx "piece_attribute" "variant"];
  "piece tag", [tx "piece_attribute" "tag"];
  "piece point int", [tx "piece_attribute" "pvariant"];
  "piece point text", [tx "piece_attribute" "ptag"];
  "piece with groups", [tx "piece_attribute" "variant"; tx "source_group" "a"; tx "target_group" "a"];
  "piece with rules", [tx "piece_attribute" "variant"; rules [rule "float*" "points" "add"; rule "a" "primitives" "copy"]];
  "piece missing target", [tx "piece_attribute" "absent"];
  "piece wrong type", [tx "piece_attribute" "nofloat"];
  "piece blank", [tx "piece_attribute" "   "];
  "rules copy points", [rules [rule "*" "points" "copy"]];
  "rules copy vertices", [rules [rule "f*" "vertices" "copy"; rule "v*" "primitives" "copy"]];
  "rules add", [rules [rule "[fiv]*" "points" "add"]];
  "rules subtract", [rules [rule "[fiv]*" "vertices" "subtract"]];
  "rules multiply", [rules [rule "[fiv]*" "primitives" "multiply"; rule "text" "points" "copy"]];
  "rules last wins", [rules [rule "*" "points" "copy"; rule "float*" "points" "nothing"; rule "i*" "vertices" "add"]];
  "rules groups", [rules [rule "*" "points" "copy"; rule "a" "primitives" "add"]];
  "rules groups subtract", [rules [rule "dest*" "vertices" "subtract"; rule "a" "points" "multiply"]];
  "rules empty", [rules []];
  "rules bad owner", [rules [rule "*" "edges" "copy"]];
  "rules bad op", [rules [rule "*" "points" "scale"]];
  "rules bad pattern", [rules [rule "[" "points" "copy"]];
  "rules bad columns", [rules ["a\tb"]];
  "rules array add", [rules [rule "*rows" "points" "add"; rule "*rows" "vertices" "copy"]];
  "pack", [bo "pack" true];
  "source group", [tx "source_group" "a"];
  "source group ordered", [tx "source_group" "dest_a"];
  "target group", [tx "target_group" "a"];
  "target group ordered", [tx "target_group" "dest_a"];
  "both groups", [tx "source_group" "a"; tx "target_group" "dest_a"];
  "pack target group", [bo "pack" true; tx "target_group" "a"];
  "missing source group", [tx "source_group" "nope"];
  "missing target group", [tx "target_group" "nope"];
  "missing target group pack", [bo "pack" true; tx "target_group" "nope"];
  "pack with source group", [bo "pack" true; tx "source_group" "a"];
  "pack with piece", [bo "pack" true; tx "piece_attribute" "integer"];
  "literal group", [tx "source_group" "literal \\*\\?\\[\\]\\^\\\\"];
  "unicode group", [tx "target_group" "\195\169\231\140\171"] ]

let bench () =
  let source = Plane_generators.grid ~connectivity:Grid_quads ~columns:9 ~rows:9 ~size:1. () |> get_ok in
  let n = 10_000 in
  let targets = Kernel.generate_point_ranges n (fun ~first ~last ~x ~y ~z ->
    for i = first to last - 1 do x.(i) <- float (i mod 100); y.(i) <- float (i / 100); z.(i) <- 0. done) in
  [source; put Attribute.Point "pscale" (Attribute.Float (plane (fun i -> 0.5 +. float (i mod 3) *. 0.25) n)) targets], []
let () = register { key = "copy_to_points"; native = Sop.Nodes.Copy_to_points.factory; inputs; cases; ulps = 4; bench = Some bench }
