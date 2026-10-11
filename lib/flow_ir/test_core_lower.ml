module E = Flow.Eval
module C = Flow_ir.Core
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let checked body =
  let forms = ok (Flow.Syntax.parse ("(workspace w (graph g :context value " ^ body ^ "))")) in
  match Flow.Workspace.check {Flow.Check.version=1;kinds=[]} forms with
  | Some ws,[] -> ws | _,ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds))
let expressions = Core_fixtures.lower_expressions
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
    ["(let* [a0 t " ^ String.concat " " (List.init 1100 (fun i -> Printf.sprintf "a%d (+ a%d t)" (i+1) i)) ^ "] a1100)","budget"];
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
