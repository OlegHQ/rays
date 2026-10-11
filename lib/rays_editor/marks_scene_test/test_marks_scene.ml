(* Marks_scene against the scene Drawing builds today: the serialized command stream of
   the same draw graph, evaluated both ways, is byte for byte the same. *)
open Rays
module E = Flow.Eval
module M = Scene_command.Marks
module Buffers = Flow_ir.Core_exec.Buffers
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let checked body =
  let forms = ok (Flow.Syntax.parse ("(workspace w (graph g :context draw " ^ body ^ "))")) in
  match Flow.Workspace.check {Flow.Check.version=1;kinds=[]} forms with
  | Some ws,[] -> ws | _,ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds))
let serialize scene = Scene_command.Render_ir.serialize (Result.get_ok (Scene.Private.to_ir scene))
let array3 = "(map (fn [i] [(* i 7.5) (+ 3 (* (* i t) 9)) 0]) (array/range 5))"
let pictures = [
  "(draw/background \"#14161c\")";
  "(draw/merge (draw/background \"#102030\") (draw/rect [1 2 0] [30 40 0]) (draw/rect [1.5 2 0] [3 4 0] :stroke \"#fff8\") (draw/rect [0 0 0] [5 5 0] :fill \"#f00\" :stroke \"#00f\"))";
  "(draw/circle [10.5 20 0] 4)";
  "(draw/circle [10 20 0] (+ 4 (* 2 (sin t))) :fill \"#5aaaf080\" :stroke \"#000\")";
  "(draw/line [0 0 0] [5 5.5 0])";
  "(draw/line [0 0 0] [5 5 0] :color \"#0f0\" :width 3)";
  "(draw/point [3.9 -4.9 0] :color \"#abc\")";
  "(draw/translate [1.9 -2.5 0] (draw/merge (draw/point [0 0 0]) (draw/rotate (* t 40) (draw/scale 2 (draw/point [1 1 0])))))";
  "(draw/rotate (* t 4) (draw/translate [10 10 0] (draw/scale [2 3 0] (draw/rect [0 0 0] [4 4 0]))))";
  "(draw/scale [2 3 0] (draw/background \"#000\"))";
  "(draw/circles " ^ array3 ^ ")";
  "(let* [p " ^ array3 ^ " r (map (fn [i] (* i 0.5)) (array/range 5))] (draw/circles p :radius r :stroke \"#fff\"))";
  "(let* [p " ^ array3 ^ " c (map (fn [i] [(/ i 5) 0.5 0.25]) (array/range 5))] (draw/circles p :radius 3 :fill c))";
  "(let* [p " ^ array3 ^ "] (draw/rects p [10 10 0] :fill \"#f00\"))";
  "(let* [p " ^ array3 ^ " c (map (fn [i] [(/ i 5) 0 0]) (array/range 5)) s (map (fn [i] [i 1 0]) (array/range 5))] (draw/rects p s :fill c :stroke \"#123\"))";
  "(let* [p " ^ array3 ^ "] (draw/lines p (map (fn [q] [q.y q.x 0]) p) :width 2))";
  "(let* [p " ^ array3 ^ " c (map (fn [i] [(/ i 5) 0 1]) (array/range 5))] (draw/lines p p :color c))";
  "(let* [p " ^ array3 ^ "] (draw/merge (draw/points p :color \"#1e1e1e\") (draw/points p)))";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 0))] (draw/merge (draw/circles p) (draw/rects p [1 1 0]) (draw/points p) (draw/lines p p)))";
  "(draw/rounded_rect [4 5 0] [60 40 0] :radius 8 :fill \"#123\" :stroke \"#fff\")";
  "(draw/rounded_rect [4 5 0] [60 40 0])";
  "(draw/translate [3 4 0] (draw/rounded_rect [4 5 0] [-60 40 0] :radius 80 :stroke \"#f0f\"))";
  "(draw/polygon (map (fn [i] [i (* i i) 0]) (array/range 4)) :stroke \"#fff\")";
  "(draw/polygon (map (fn [i] [i (* i i) 0]) (array/range 4)))";
  "(draw/polyline (map (fn [i] [i (* i i) 0]) (array/range 4)) :color \"#f0f\")";
  "(draw/merge (draw/text [1 2 0] \"\") (draw/circle [5 5 0] 2 :fill \"#fff\"))";
]
let size = 200, 100
let live = {(Frame_input.at_time 0.25) with size}
let old_scene body =
  let evaluation = ok (E.static (checked body)) in
  let prepared = ok (Rays_editor.Drawing.prepare ~states:evaluation.states evaluation.plan (List.assoc "g" evaluation.results)) in
  ok (Rays_editor.Drawing.render_prepared prepared ~live ~size)
let new_scene body =
  let evaluation = ok (E.static (checked body)) in
  let program, root = Result.get_ok (Flow_ir.Core_draw.lower evaluation.plan (List.assoc "g" evaluation.results)) in
  let buffers = Buffers.create () in
  let marks = ok (Flow_ir.Core_exec.draw ?root (Flow_ir.Core_exec.prepare program) ~live ~size ~buffers) in
  ok (Marks_scene.scene ~buffers marks)
let () =
  List.iteri (fun i body ->
    let old_ir = serialize (old_scene body) and new_ir = serialize (new_scene body) in
    if not (Bytes.equal old_ir new_ir) then failwith (Printf.sprintf "picture %d differs: %s" i body))
    pictures;
  (* Hand-built marks against the Scene API. *)
  let none = Buffers.create () in
  let circle = M.Circle {position = Constant (1.5, 2.); radius = Constant 3.; fill = Constant 0xff0000ffl;
    stroke = Constant 0l; stroke_width = Constant 1.} in
  let angle = 10. in
  let marks = [|
    M.Mark_set {count = 1; kind = circle};
    Push_transform {xx = cos angle; xy = sin angle; yx = -. sin angle; yy = cos angle; tx = 0.; ty = 0.};
    Mark_set {count = 0; kind = Rect {position = Constant (0., 0.); size = Constant (1., 1.);
      fill = Constant 0l; stroke = Constant 0l; stroke_width = Constant 1.}};
    Pop_transform |] in
  let batch = Scene_command.Shape_batch.Builder.(let b = create () in
    circle b ~x:1.5 ~y:2. ~radius:3. ~fill:0xff0000ffl ~stroke:0l (); publish b) in
  let empty = Scene_command.Shape_batch.Builder.(publish (create ())) in
  let expected = [Scene.Private.shapes batch; Scene.rotate angle [Scene.Private.shapes empty]] in
  assert (Bytes.equal (serialize expected) (serialize (ok (Marks_scene.scene ~buffers:none marks))));
  (* A mark the contract rejects is an error, and so is an image without a resolver. *)
  assert (Result.is_error (Marks_scene.scene ~buffers:none [|M.Pop_transform|]));
  (match Marks_scene.scene ~buffers:none [|M.Image {resource = 1; x = 0; y = 0; scale = 1.; angle = 0.}|] with
   | Error d -> assert (d.code = "E_IMAGE") | Ok _ -> assert false);
  Printf.printf "Marks_scene: %d draw graphs serialize byte for byte as Drawing's scene; hand-built marks match\n"
    (List.length pictures)
