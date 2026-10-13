module E = Flow.Eval
module I = Flow_ir
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let workspace body =
  match Flow.Workspace.check {Flow.Check.version=1;kinds=[]}
    (ok (Flow.Syntax.parse ("(workspace w (graph g :context value (let* [tested " ^ body ^ "] 0.)))"))) with
  | Some ws,[] -> ws | _,ds -> failwith (body ^ ": " ^ String.concat "; " (List.map Flow.Diagnostic.to_string ds))
let same_bits a b = Int64.bits_of_float a=Int64.bits_of_float b
let same_result a b = match a,b with
  | Ok (E.Float a),Ok (E.Float b) -> same_bits a b
  | Ok a,Ok b -> a=b
  | Error (a : Flow.Diagnostic.t),Error b -> a=b | _ -> false
(* The core itself fails on these, and the executor must answer with the walker's own
   diagnostic (message and span) rather than a core one. *)
let failing = [
  "division by zero","(int/div (int (+ 10 t)) (int (* t 0)))",[1.;2.];
  "out-of-range nth","(nth (list t 1 2) (+ 5 (int t)))",[0.;1.5];
  "non-finite result","(exp (* t 100000.))",[1.;3.];
  "list slice","(first (take (int t) (list t 1)))",[0.;0.5];
  "authored error","(error (str \"E_RULES_\" (int t)) (str \"exact é日本😀 \" t))",[1.;2.];
  "authored cause","(error \"E_CAUSE\" \"selected failure\" :cause (str \"reason é日本😀 \" t))",[1.;2.];
]
let differing = ref 0
let () =
  List.iter (fun (name,body,times) ->
    let value=snd (List.hd (List.assoc ["g";"tested"] (ok (E.static ~record:true (workspace body))).records)) in
    let r=match value with E.Residual r -> r | _ -> failwith (name ^ ": not live") in
    let prepared=I.Core_exec.prepare (match I.Core_lower.lower r with Ok p -> p | Error n -> failwith (name ^ ": refused " ^ n)) in
    List.iter (fun time ->
      let live=Frame_input.at_time time in
      let expected=E.Private.force_reference value ~live in
      assert (Result.is_error expected);
      (match I.Core_exec.execute prepared ~live with
       | Error d -> if not (same_result (Error d) expected) then incr differing
       | Ok _ -> failwith (name ^ ": the core should fail"));
      assert (same_result (I.Core_exec.execute ~root:r ~strict:true prepared ~live)
        (I.Core_exec.execute prepared ~live));
      let hooked=ref false in
      let execute r live = hooked:=true; Some (I.Core_exec.execute ~root:r prepared ~live) in
      let actual=E.Private.force_with_executor ~execute value ~live in
      assert !hooked;
      if not (same_result actual expected) then failwith (Printf.sprintf "%s at %g: diagnostic differs from the walker" name time)) times) failing;
  (* At least one core diagnostic differs from the walker's, so the rerun is observable. *)
  assert (!differing>0);
  (* A failure after a state write restores the plane before the walker answers. *)
  let value=List.hd (ok (E.static (workspace "(state [s 0.] (if (> t 0.6) (error \"E_RULES\" (str \"exact failure \" t) :cause \"state rollback\") (+ s 1.)))"))).states in
  let reference=E.create_state () and core=E.create_state () in
  let prepared=ref None and failures=ref 0 in
  let execute r live =
    let p=match !prepared with Some p -> p | None ->
      let p=I.Core_exec.prepare (Result.get_ok (I.Core_lower.lower r)) in prepared:=Some p; p in
    Some (I.Core_exec.execute ~root:r p ~live) in
  for frame=0 to 7 do
    let live={(Frame_input.at_time (float_of_int frame *. 0.25)) with frame} in
    let expected=E.Private.force_reference ~state:reference value ~live in
    let actual=E.Private.force_with_executor ~state:core ~execute value ~live in
    if Result.is_error expected then incr failures;
    if not (same_result actual expected) then failwith (Printf.sprintf "state frame %d" frame);
    assert (E.state_stamp core=E.state_stamp reference)
  done;
  assert (!failures>0);
  let reference=E.create_state () and strict=E.create_state () in
  let compiled=ok(I.Executor.compile ~strict:true value) in
  for frame=0 to 7 do
    let live={(Frame_input.at_time (float_of_int frame *. 0.25)) with frame} in
    let expected=E.Private.force_reference ~state:reference value ~live in
    (match I.Executor.force ~strict:true ~state:strict compiled ~live,expected with
     |Error actual,Error expected->assert(actual.code=expected.code && actual.message=expected.message && actual.cause=expected.cause)
     |actual,expected->assert(same_result actual expected));
    assert(E.state_stamp strict=E.state_stamp reference);
    assert(same_result (Ok(E.List(Array.of_list(E.Private.state_values strict))))
      (Ok(E.List(Array.of_list(E.Private.state_values reference)))))
  done;
  print_endline "Core errors: division by zero, range, non-finite and state rollback return the walker's diagnostic"

let () =
  let recorded body=snd(List.hd(List.assoc["g";"tested"]
    (ok(E.static ~record:true(workspace body))).records)) in
  let value=recorded "(if (> t 0.) (error (str \"E_TEXT_\" (int t)) (str \"é日本😀 \" t) :cause (str \"reason \" t)) \"safe\")" in
  let residual=match value with E.Residual r->r|_->assert false in
  let core=Result.get_ok(I.Core_lower.lower ~strict:true residual) in
  let compiled=ok(I.Executor.compile ~strict:true value) in
  List.iter(fun time->let live=Frame_input.at_time time in
    let expected=E.Private.force_reference value ~live in
    let check=function
      |Ok actual->assert(expected=Ok actual)
      |Error(d:Flow.Diagnostic.t)->(match expected with Error e->assert(d.code=e.code && d.message=e.message && d.cause=e.cause)|_->assert false) in
    check(I.Core_exec.run core ~live);check(I.Executor.force ~strict:true compiled ~live)) [-1.;1.;2.];
  (match E.static(workspace "(error \"E_LITERAL\" \"literal failure\" :cause \"literal cause\")") with
   |Error d->assert(d.code="E_LITERAL" && d.cause=Some "literal cause" && d.span<>None)
   |Ok _->assert false);
  List.iter(fun count->
    let value=recorded(Printf.sprintf "(map (fn [x] (if (> t 0.) (error \"E_PACKED_RULE\" \"exact é日本😀\" :cause \"selected packed cause\") x)) (array/range %d))" count) in
    let compiled=ok(I.Executor.compile ~strict:true value) in
    List.iter(fun time->let live=Frame_input.at_time time in
      let expected=E.Private.force_reference value ~live in
      List.iter(fun domains->Rays_math.Parallel.run ~domains(fun()->
        match I.Executor.force ~strict:true compiled ~live,expected with
        |Ok actual,Ok expected->assert(actual=expected)
        |Error actual,Error expected->assert(actual.code=expected.code && actual.message=expected.message && actual.cause=expected.cause)
        |_->assert false)) [1;8]) [-1.;1.]) [0;5001];
  let dynamic=recorded "(map (fn [x] (if (> t 0.) (error \"E_DYNAMIC\" (str x)) x)) (array/range 5001))" in
  (match I.Executor.compile ~strict:true dynamic with Error d->assert(d.code="E_KERNEL_FORM")|Ok _->assert false);
  assert(Result.is_ok(E.Private.force_reference dynamic ~live:(Frame_input.at_time(-1.))));
  print_endline "Authored errors: exact dynamic messages, lazy text/packed branches, empty inputs, rollback and dynamic packed refusal pass"
