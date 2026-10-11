module E = Flow.Eval
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let checked body =
  let forms = ok (Flow.Syntax.parse ("(workspace w (graph g :context draw " ^ body ^ "))")) in
  match Flow.Workspace.check {Flow.Check.version=1;kinds=[]} forms with
  | Some ws,[] -> ws | _,ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds))
let pictures = [
  "(draw/background \"#14161c\")";
  "(draw/merge (draw/rect [1 2 0] [30 40 0]) (draw/rect [1 2 0] [3 4 0] :stroke \"#fff\") (draw/rect [0 0 0] [5 5 0] :fill \"#f00\" :stroke \"#00f\"))";
  "(draw/circle [10 20 0] 4)";
  "(draw/circle [10 20 0] (+ 4 (* 2 (sin t))) :fill \"#5aaaf0\")";
  "(draw/line [0 0 0] [5 5 0])";
  "(draw/line [0 0 0] [5 5 0] :color \"#0f0\" :width 3)";
  "(draw/point [3 4 0])";
  "(draw/point [3 4 0] :color \"#abc\")";
  "(draw/translate [1.9 -2.5 0] (draw/merge (draw/point [0 0 0]) (draw/rotate (* t 2) (draw/scale 2 (draw/point [1 1 0])))))";
  "(draw/scale [2 3 0] (draw/background \"#000\"))";
  "(let* [p (map (fn [i] [(* i 10) (* i t) 0]) (array/range 4))] (draw/circles p))";
  "(let* [p (map (fn [i] [(* i 10) (* i t) 0]) (array/range 4)) r (map (fn [i] (* i 0.5)) (array/range 4))] (draw/circles p :radius r :stroke \"#fff\"))";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 4))] (draw/rects p [10 10 0] :fill \"#f00\"))";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 4)) c (map (fn [i] [(/ i 4) 0 0]) (array/range 4))] (draw/rects p [10 10 0] :fill c))";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 4))] (draw/lines p p :width 2))";
  "(let* [p (map (fn [i] [i 0 0]) (array/range 4))] (draw/points p :color \"#1e1e1e\"))";
]
let dump () =
  let buffer = Buffer.create 4096 in
  let fmt = Format.formatter_of_buffer buffer in
  List.iteri (fun i body ->
    Format.fprintf fmt "picture %d: %s\n" i body;
    let evaluation = ok (E.static (checked body)) in
    (match Flow_ir.Core_draw.lower evaluation.plan (List.assoc "g" evaluation.results) with
     | Ok (program, root) ->
         Format.fprintf fmt "%a" Flow_ir.Core.pp program;
         Format.fprintf fmt "root %b\n" (Option.is_some root)
     | Error name -> Format.fprintf fmt "refused %s\n" name)) pictures;
  Format.pp_print_flush fmt ();
  Buffer.contents buffer
let () =
  let actual = dump () in
  if Array.length Sys.argv = 2 && Sys.argv.(1) = "--print" then print_string actual
  else if actual <> In_channel.with_open_bin "core_draw.expected" In_channel.input_all
  then failwith ("Core draw lowering changed:\n" ^ actual)
