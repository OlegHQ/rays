module E = Flow.Eval
module M = Scene_command.Marks
module Buffers = Flow_ir.Core_exec.Buffers
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let checked body =
  let forms = ok (Flow.Syntax.parse ("(workspace w (graph g :context draw " ^ body ^ "))")) in
  match Flow.Workspace.check {Flow.Check.version=1;kinds=[]} forms with
  | Some ws,[] -> ws | _,ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds))
let pictures = [
  "(draw/background \"#14161c\")";
  "(draw/merge (draw/rect [1 2 0] [30 40 0]) (draw/rect [1 2 0] [3 4 0] :stroke \"#fff\") (draw/rect [0 0 0] [5 5 0] :fill \"#f00\" :stroke \"#00f\"))";
  "(draw/circle [10.5 20 0] 4)";
  "(draw/circle [10 20 0] (+ 4 (* 2 (sin t))) :fill \"#5aaaf080\")";
  "(draw/line [0 0 0] [5 5 0])";
  "(draw/line [0 0 0] [5 5 0] :color \"#0f0\" :width 3)";
  "(draw/point [3.9 -4.9 0] :color \"#abc\")";
  "(draw/translate [1.9 -2.5 0] (draw/merge (draw/point [0 0 0]) (draw/rotate 0.5 (draw/scale 2 (draw/point [1 1 0])))))";
  "(draw/scale [2 3 0] (draw/background \"#000\"))";
  "(let* [p (map (fn [i] [(* i 10) (* i t) 0]) (array/range 3))] (draw/circles p))";
  "(let* [p (map (fn [i] [(* i 10) (* i t) 0]) (array/range 3)) r (map (fn [i] (* i 0.5)) (array/range 3))] (draw/circles p :radius r :stroke \"#fff\"))";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 3))] (draw/rects p [10 10 0] :fill \"#f00\"))";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 3)) c (map (fn [i] [(/ i 4) 0 0]) (array/range 3)) s (map (fn [i] [i 1 0]) (array/range 3))] (draw/rects p s :fill c))";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 3))] (draw/lines p p :width 2))";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 3))] (draw/points p :color \"#1e1e1e\"))";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 0))] (draw/merge (draw/circles p) (draw/points p)))";
  "(draw/text [12.7 12 0] \"hi\" :color \"#abc\" :size 20)";
  "(draw/text [12 12 0] \"\")";
  "(draw/rounded_rect [4 5 0] [60 40 0] :radius 8 :fill \"#123\")";
  "(draw/rounded_rect [4 5 0] [60 40 0])";
  "(draw/polygon (map (fn [i] [i (* i i) 0]) (array/range 4)) :stroke \"#fff\")";
  "(draw/polyline (map (fn [i] [i (* i i) 0]) (array/range 4)) :color \"#f0f\")";
]
let errors = [
  "(let* [p (map (fn [i] [i 0 0]) (array/range 3)) r (map (fn [i] 1.0) (array/range 2))] (draw/circles p :radius r))", "E_DRAW_LENGTH";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 3)) c (map (fn [i] [0.5 0 0]) (array/range 2))] (draw/rects p [1 1 0] :fill c))", "E_DRAW_LENGTH";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 3)) q (map (fn [i] [i 0 0]) (array/range 2))] (draw/lines p q))", "E_DRAW_LENGTH";
  "(draw/rect [0 0 0] [-1 1 0])", "E_DRAW_RANGE";
  "(draw/point [1e30 0 0])", "E_DRAW_RANGE";
  "(draw/image (image/noise))", "E_IMAGE";
]
let float x = Printf.sprintf "%h" x
let dump () =
  let buffer = Buffer.create 4096 in
  let fmt = Format.formatter_of_buffer buffer in
  let out f = Format.fprintf fmt f in
  List.iteri (fun i body ->
    out "picture %d: %s\n" i body;
    let evaluation = ok (E.static (checked body)) in
    let program, root = Result.get_ok (Flow_ir.Core_draw.lower evaluation.plan (List.assoc "g" evaluation.results)) in
    let prepared = Flow_ir.Core_exec.prepare program in
    let buffers = Buffers.create () in
    let live = {(Frame_input.at_time 0.25) with size = (200, 100)} in
    let marks = ok (Flow_ir.Core_exec.draw ?root prepared ~live ~size:(200, 100) ~buffers) in
    let attr show = function
      | M.Constant v -> "const " ^ show v
      | Buffer {id; count; width} ->
          Printf.sprintf "buffer %d count=%d width=%d [%s]" id count width
            (String.concat " " (Array.to_list (Array.map float (Buffers.find buffers id)))) in
    let pair (x, y) = float x ^ "," ^ float y and ink c = Printf.sprintf "%08lx" c and one = float in
    Array.iter (fun entry -> match entry with
      | M.Mark_set {count; kind} ->
          (match kind with
           | Rect {position; size; fill; stroke; stroke_width} ->
               out "  rect %d position=%s size=%s fill=%s stroke=%s width=%s\n" count (attr pair position)
                 (attr pair size) (attr ink fill) (attr ink stroke) (attr one stroke_width)
           | Circle {position; radius; fill; stroke; stroke_width} ->
               out "  circle %d position=%s radius=%s fill=%s stroke=%s width=%s\n" count (attr pair position)
                 (attr one radius) (attr ink fill) (attr ink stroke) (attr one stroke_width)
           | Line {position; end_; stroke; stroke_width} ->
               out "  line %d from=%s to=%s color=%s width=%s\n" count (attr pair position) (attr pair end_)
                 (attr ink stroke) (attr one stroke_width)
           | Point {position; fill} -> out "  point %d position=%s fill=%s\n" count (attr pair position) (ink fill))
      | Geometry {vertices; indices; color} ->
          out "  geometry %s vertices=[%s] indices=[%s]\n" (ink color)
            (String.concat " " (Array.to_list (Array.map float vertices)))
            (String.concat " " (Array.to_list (Array.map string_of_int indices)))
      | Image _ -> out "  image\n"
      | Text {x; y; size; color; text} -> out "  text %d,%d size=%d %s %S\n" x y size (ink color) text
      | Push_transform {xx; xy; yx; yy; tx; ty} ->
          out "  push %s %s %s %s %s %s\n" (float xx) (float xy) (float yx) (float yy) (float tx) (float ty)
      | Pop_transform -> out "  pop\n"
      | Push_clip _ -> out "  push-clip\n" | Pop_clip -> out "  pop-clip\n") marks) pictures;
  List.iter (fun (body, code) ->
    let evaluation = ok (E.static (checked body)) in
    let program, root = Result.get_ok (Flow_ir.Core_draw.lower evaluation.plan (List.assoc "g" evaluation.results)) in
    match Flow_ir.Core_exec.draw ?root (Flow_ir.Core_exec.prepare program) ~live:(Frame_input.at_time 0.)
            ~size:(10, 10) ~buffers:(Buffers.create ()) with
    | Error d -> assert (d.code = code); out "error %s: %s\n" d.code d.message
    | Ok _ -> failwith ("expected " ^ code ^ " for " ^ body)) errors;
  Format.pp_print_flush fmt ();
  Buffer.contents buffer
let () =
  let actual = dump () in
  if Array.length Sys.argv = 2 && Sys.argv.(1) = "--print" then print_string actual
  else if actual <> In_channel.with_open_bin "core_marks.expected" In_channel.input_all
  then failwith ("Core marks changed:\n" ^ actual)
