module E = Flow.Eval
module C = Flow_ir.Core
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let checked body =
  let forms = ok (Flow.Syntax.parse ("(workspace w (graph g :context value " ^ body ^ "))")) in
  match Flow.Workspace.check {Flow.Check.version=1;kinds=[]} forms with
  | Some ws,[] -> ws | _,ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds))
let expressions = [
  "(sum [k (range 6)] (/ (sin (* (+ t k) (+ (* 2 k) 1))) (+ (* 2 k) 1)))";
  "(let* [a 3 b (* a 2)] (+ (* t b) (mod t 0.7)))";
  "(if (> (sin t) 0.2) (pow t 2) (- 0 t))";
  "(let* [v [(* t 2) (+ t 1) (min t 3)]] (+ v.x v.y))";
  "(nth (for [i (range 4)] (* i t)) 2)";
  "(sum [x (for [i (range 4)] (+ (* i t) 1))] (* x 2))";
  "(sum [i (range 5)] (sum [j (range 3)] (* (+ t i) j)))";
  "(let* [a t a1 (+ a a) a2 (+ a1 a1) a3 (+ a2 a2)] (* a3 0.5))";
  "(let* [c (value/lerp [1 2 3] [t 0 1] 0.25)] c.z)";
  "(sum [i (range 0)] t)";
  "(/ t 0)";
]
let dump () =
  let buffer = Buffer.create 4096 in
  let fmt = Format.formatter_of_buffer buffer in
  List.iteri (fun i body ->
    Format.fprintf fmt "expression %d: %s\n" i body;
    let evaluation = ok (E.static (checked body)) in
    let rec value : E.value -> unit = function
      | Residual r ->
          (match Flow_ir.Core_lower.lower r with
          | Ok program ->
              let printed = Format.asprintf "%a" C.pp program in
              assert (printed = Format.asprintf "%a" C.pp (Result.get_ok (Flow_ir.Core_lower.lower r)));
              Format.fprintf fmt "%s" printed
          | Error name ->
              assert (not (E.Private.closure_available r));
              Format.fprintf fmt "refused %s\n" name)
      | List xs -> Array.iter value xs
      | Record xs -> List.iter (fun (_,v) -> value v) xs
      | v -> Format.fprintf fmt "constant %s\n" (E.show v) in
    value (List.assoc "g" evaluation.results)) expressions;
  Format.pp_print_flush fmt ();
  Buffer.contents buffer
let () =
  let actual = dump () in
  (if Array.length Sys.argv=2 && Sys.argv.(1)="--print" then print_string actual
  else begin
    let expected=In_channel.with_open_bin "core_lower.expected" In_channel.input_all in
    if actual <> expected then failwith ("Core lowering changed:\n" ^ actual)
  end);
  List.iter (fun (body,name) ->
    match List.assoc "g" (ok (E.static (checked body))).results with
    | E.Residual r -> assert (Flow_ir.Core_lower.lower r = Error name)
    | _ -> assert false)
    ["(array/sum (map (fn [x] (+ x t)) (array/range 4)))","packed_higher_order"];
  let observed=ref false in
  ignore (ok (E.Private.static_with_kernels ~observe:(fun r ->
    match (E.Private.residual_view r).term.node with
    | Flow.Workspace.Loop {kind=`Fold;_} ->
        observed:=true;
        let program=Result.get_ok (Flow_ir.Core_lower.lower r) in
        List.iter (fun time ->
          let live=Frame_input.at_time time in
          assert (Flow_ir.Core_exec.run program ~live = E.Private.force_reference (E.Residual r) ~live))
          [0.;0.37;2.]
    | _ -> ()) (checked "(fold [s 0.] [i (range 2)] (+ s (+ t i)))")));
  assert !observed;
  assert (C.literal_of_value (E.Residual (match List.assoc "g" (ok (E.static (checked "(+ t 1)"))).results with
    E.Residual r -> r | _ -> assert false)) = None)
