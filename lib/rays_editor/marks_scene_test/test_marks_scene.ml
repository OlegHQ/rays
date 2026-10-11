(* Marks_scene against the scenes the per-kind drawing arms built (P3.13 removed them): the SHA-256
   of each draw graph's serialized command stream is the checked-in digest those arms produced. *)
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
let digests = [
  "f4ff989c22afb8f52ab260b54d17bb7891e07ab75f29b2de12f487f832f3d92a";
  "38167b07c39a01579645ef0d43fd6ec8c1b524edc07e49436d9754eecbb11d2c";
  "66494d0f3ffb1159cdf6fb629fbd8105e690fa96d3f4956f4edf8b52e7eba59f";
  "c3ffa1398d4a79818e0afa089e1131a048b20881dbf0858482fa7f0c28bfcffd";
  "23a418fc491c5d3a95aa3029d2113bf002423a4a78e65dfc8a71c79818b8c89b";
  "3b93ccef6bb7daa17148022b6a0fdac1b409ce7c2ad6a370c4797151e146a5d1";
  "ad94fa12ef2f1c84f45eca8b1b932f87465f51fe25c48b8aaa6bb34d8a9e5cc3";
  "1113c42cc2148b7eff360ec11fbdf7cd1735930475d0ccef8429d6a75d0118a5";
  "68ecc6c3903328f5dad628fb39ab2fdcbbd03b55ce2caac17cfd4f3b52693483";
  "71f685a283353a1f6081e6fa92ec9ad61674563f3ef8cf8d9e8309814bbef0f6";
  "14a723a3cffd08ceec72997d010416750af9e001bf15283d13d495d083f2faa2";
  "c0bcc14d631dc745aa86c73d3fff98fce242b956f3e8924e187d20d0267dcff6";
  "d175863740935e5233b0a46f97e47a31a8233830684c736b444fe95c1b666401";
  "5f1de8f73c12b33352bb627731d0c3cd347c07c818278f41d81fefd93bdbba37";
  "34a94c9916d7321808a516723e5d5b0d51ddaedbf6671ee96293b6e58b9fcd4a";
  "e560c7f427e139fcaf098f3993ff6ba3b3ac536391b2b8e504f56da2d52b4654";
  "53eee607276c67a0280cb9fcbb59e5ebc81e0f6502a82077c0c2bdc7d7323c8b";
  "be5ae462a1a643c5d900d9d932f21ea4369cd8b32e693d4a8dec9f9049a6b53f";
  "6b3831072362e57f0f8b90919a3f922911b46d54d87b1eaed1d45b82d3033a33";
  "27bae8d4612c790aac0527df20a81bc4f0f3d21d22f51e0e03834b948f5f89a9";
  "447a8178eb85cb3be6245c4d0ba5e559ef876fb7495596970eaa09f8b9b5fadb";
  "5de2d001b43fb50d2243d6b231c156f71c35b3bfe2f673e6dc357293d6c1748a";
  "db2db290db2f7d80a744b3625af71f1706e44b1d4d565f3d6373693427a6dbb8";
  "b967bc0170e57ab1d5239e87988c193dc731db361c815ff8edfd089fe9526c53";
  "382cc67de39df737faadf6e1e2d9927794967f6bfbe995cc1ec36e7d6401f90f";
  "bc9a96cc00caf757afb46c0b94ab6e514f8676ad396541d50171b303b82e9c73";
]
let new_scene body =
  let evaluation = ok (E.static (checked body)) in
  let program, root = Result.get_ok (Flow_ir.Core_draw.lower evaluation.plan (List.assoc "g" evaluation.results)) in
  let buffers = Buffers.create () in
  let marks = ok (Flow_ir.Core_exec.draw ?root (Flow_ir.Core_exec.prepare program) ~live ~size ~buffers) in
  ok (Marks_scene.scene ~buffers marks)
let () =
  assert (List.length digests = List.length pictures);
  List.iteri (fun i body ->
    let digest = Editor_document.Contexts.sha256 (Bytes.to_string (serialize (new_scene body))) in
    if digest <> List.nth digests i then failwith (Printf.sprintf "picture %d differs: %s" i body))
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
  Printf.printf "Marks_scene: %d draw graphs serialize to the digests of the removed arms; hand-built marks match\n"
    (List.length pictures)

(* A static batch under a moving translate is kept: a frame allocates the same at 10,000 and 100,000
   instances, and the kept batch draws what a fresh drawing draws. *)
let () =
  let size = (800, 600) in
  let prepare n =
    let source = Printf.sprintf "(workspace w (graph g :context draw (draw/translate [(* 10 (sin t)) 0 0] (draw/rects (map (fn [i] [(* (mod i 800) 1.0) (/ i 1250) 0]) (array/range %d)) [3 3 0] :fill \"#5aaaf0\"))))" n in
    let evaluation = ok (E.static (match Flow.Workspace.check {Flow.Check.version=0;kinds=[]} (ok (Flow.Syntax.parse source)) with
      | Some ws,[] -> ws | _,ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds)))) in
    ok (Rays_editor.Drawing.prepare ~states:evaluation.states evaluation.plan (List.assoc "g" evaluation.results)) in
  let frame prepared state i = ok (Rays_editor.Drawing.render_prepared ~state prepared
    ~live:{(Frame_input.at_time (float i /. 60.)) with frame = i; tick = i; size} ~size) in
  let allocated n =
    let prepared = prepare n and state = E.create_state () in
    ignore (frame prepared state 0); ignore (frame prepared state 1);
    let before = Gc.allocated_bytes () in
    ignore (frame prepared state 2);
    Gc.allocated_bytes () -. before in
  let small = allocated 10_000 and large = allocated 100_000 in
  if large > small +. 100_000. then
    failwith (Printf.sprintf "a moving translate over a static batch allocates with the count: %.0f bytes at 10,000, %.0f at 100,000" small large);
  let kept = prepare 2_000 and state = E.create_state () in
  ignore (frame kept state 0);
  assert (Bytes.equal (serialize (frame kept state 3)) (serialize (frame (prepare 2_000) (E.create_state ()) 3)));
  Printf.printf "Retention: a moving translate over a static batch allocates %.0f bytes at 10,000 instances and %.0f at 100,000\n" small large
