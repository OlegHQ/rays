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
]
let differing = ref 0
let () =
  E.Private.core_residuals:=true;
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
      let hooked=ref false in
      let execute r live = hooked:=true; Some (I.Core_exec.execute ~root:r prepared ~live) in
      let actual=E.Private.force_with_executor ~execute value ~live in
      assert !hooked;
      if not (same_result actual expected) then failwith (Printf.sprintf "%s at %g: diagnostic differs from the walker" name time)) times) failing;
  (* At least one core diagnostic differs from the walker's, so the rerun is observable. *)
  assert (!differing>0);
  (* A failure after a state write restores the plane before the walker answers. *)
  let value=List.hd (ok (E.static (workspace "(state [s 0.] (if (> t 0.6) (nth (list 1 2) 9) (+ s 1.)))"))).states in
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
  print_endline "Core errors: division by zero, range, non-finite and state rollback return the walker's diagnostic"
