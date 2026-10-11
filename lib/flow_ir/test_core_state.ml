module E = Flow.Eval
module I = Flow_ir
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let check ?(extra="") body =
  let forms = ok (Flow.Syntax.parse ("(workspace w " ^ extra ^ " (graph g :context value " ^ body ^ "))")) in
  match Flow.Workspace.check {Flow.Check.version=1;kinds=[]} forms with
  | Some ws,[] -> ws | _,ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds))
let bits x y = Int64.bits_of_float x = Int64.bits_of_float y
let rec same_bits (a : E.value) (b : E.value) = match a,b with
  | Float x,Float y -> bits x y
  | List xs,List ys -> Array.length xs=Array.length ys && Array.for_all2 same_bits xs ys
  | Record fs,Record gs -> List.length fs=List.length gs && List.for_all2 (fun (n,a) (m,b) -> n=m && same_bits a b) fs gs
  | a,b -> a=b
let same a b = match a,b with
  | Ok a,Ok b -> same_bits a b
  | Error (a : Flow.Diagnostic.t),Error (b : Flow.Diagnostic.t) -> a.code=b.code && a.span=b.span | _ -> false
let cases = [
  "counter","(state [s 0.] (+ s t))";
  "integer","(state [s 0] (+ s 1))";
  "record","(state [s {:n 0 :m 1.}] (assoc s :n (+ s.n 1) :m (* s.m 1.5)))";
  "record-keys","(state [s {:n 0 :m 1.}] (let* [{:keys [n m]} s] {:n (+ n 1) :m (* m 2.)}))";
  "two-reads","(let* [a (state [s 0] (+ s 1)) b (state [s 10] (+ s 2))] (+ a b))";
  "same-read-twice","(let* [a (state [s 0] (+ s 1))] (+ a a))";
  "loop","(for [i (range 3)] (state [s 0.] (+ s (* i t))))";
  "function","(let* [f (fn [x] (state [s 0.] (+ s x)))] (+ (f 1.) (f t)))";
  "event-records","(state [n 0] (+ n (reduce (fn [a e] (if (equal? e.key \"a\") (+ a 1) a)) 0 (get (frame/input) :events))))";
  "events","(state [n 0] (+ n (count (get (frame/input) :events))))";
  "list","(state [s (list)] (if (< (count s) 3) (concat s (list t)) s))";
  "error","(state [s 0.] (if (> t 0.6) (/ t 0) (+ s 1.)))";
  "coerced","(state [s 0.] (if (> t 0.6) 2 (+ s t)))";
]
(* A [ref] re-runs the referenced graph in its own instance: the state it reads is shared. *)
let refs = [
  "ref","(graph counter :context value (state [s 0.] (+ s t)))","(let* [a (ref counter)] (+ a (* a 2.)))";
  "ref-record","(graph model :context host (state [m {:n 0 :flag 0}] (assoc m :n (+ m.n 1) :flag (if (> t 0.6) 1 0))))",
    "(+ (get (ref model) :n) (get (ref model) :flag))";
]
let live frame =
  {(Frame_input.at_time (float_of_int frame *. 0.25)) with frame; tick=frame;
   events=if frame mod 2=1 then [Key_pressed "a"; Key_pressed "b"] else []}
let () =
  let used=ref 0 and refused=ref [] and failed=ref [] in
  List.iter (fun (name,extra,body) ->
    let evaluation=ok (E.static (check ~extra ("(let* [v " ^ body ^ "] 0.)"))) in
    let values=List.map snd evaluation.results @ evaluation.states in
    let reference=E.create_state () and core=E.create_state () in
    let execute r live = match I.Core_lower.lower r with
      | Ok program ->
          let result=I.Core_exec.run ~root:r program ~live in
          (match result with
           | Ok _ -> incr used
           | Error d -> if name<>"error" then failed := (name ^ ": " ^ d.code ^ " " ^ d.message) :: !failed);
          Some result
      | Error n -> refused := (name ^ ": " ^ n) :: !refused; None in
    for frame=0 to 7 do
      let live=live frame in
      List.iter (fun v ->
        let expected=E.Private.force_reference ~state:reference v ~live in
        let actual=
          let old= !(E.Private.core_residuals) in
          Fun.protect ~finally:(fun () -> E.Private.core_residuals:=old) (fun () ->
            E.Private.core_residuals:=true;
            E.Private.force_with_executor ~state:core ~execute v ~live) in
        if not (same actual expected) then failwith (Printf.sprintf "%s frame %d" name frame);
        if E.state_stamp core<>E.state_stamp reference then failwith (Printf.sprintf "%s frame %d: state stamp\n%s\n%s" name frame (String.concat ";" (List.map (fun v -> Flow.Value.show_with Fun.id v) (E.Private.state_values core))) (String.concat ";" (List.map (fun v -> Flow.Value.show_with Fun.id v) (E.Private.state_values reference))))) values
    done) (List.map (fun (name,body) -> name,"",body) cases @ refs);
  if !refused<>[] || !failed<>[] then failwith (String.concat "; " (!refused @ !failed));
  assert (!used>0);
  Printf.printf "Core state: slots, pending writes, keys, errors and rollback match the walker (%d executions)\n" !used
