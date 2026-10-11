module E = Flow.Eval
module I = Flow_ir
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let rec same (a : E.value) (b : E.value) = match a,b with
  | Float a,Float b -> Int64.bits_of_float a=Int64.bits_of_float b
  | List a,List b -> Array.length a=Array.length b && Array.for_all2 same a b
  | Record a,Record b -> List.length a=List.length b && List.for_all2 (fun (n,a) (m,b) -> n=m && same a b) a b
  | a,b -> a=b
let cases = [
  "literal","(if (> t -1000.) (list t 1 2.) (list))";
  "range","(range t)";
  "range-two","(range (- t 2.) (+ t 3.))";
  "range-large-integers","(range (+ 9007199254740992. (* t 2.)) (+ (+ 9007199254740992. (* t 2.)) 6.))";
  "take","(take t (list 0 1 2))";
  "drop","(drop t (list 0 1 2))";
  "rest","(rest (list t))";
  "reverse","(reverse (list t 1 2))";
  "concat","(concat (list t 1) (list 2 3.))";
  "nth","(nth (list 1 2 3) t)";
  "count","(count (range t))";
  "map","(map (fn [x] (+ x t)) (range 1000))";
  "map-zip","(map (fn [x y z] (+ (+ x y) (+ z t))) (list 1 2 3) (list 4) (list 5 6))";
  "map-tags","(map (fn [x] (if (> t 0.) x (float x))) (range 3))";
  "map-empty","(map (fn [x] (/ t 0.)) (range 0))";
  "filter","(filter (fn [x] (> x t)) (range 8))";
  "reduce","(reduce (fn [a x] (+ a (* x t))) 0 (range 1024))";
  "reduce-tags","(reduce (fn [a x] (+ a x)) 0 (list t 0.25))";
  "reduce-widened-tag","(reduce (fn [a x] (if (> x 0.) 1.5 2)) 0 (list t 0))";
  "reduce-record","(reduce (fn [a x] (assoc a :n (+ a.n t))) {:n 0.} (range 3))";
  "reduce-record-int","(reduce (fn [a x] (assoc a :n (+ a.n t))) {:n 0} (range 3))";
  "reduce-empty","(reduce (fn [a x] (/ t 0.)) 0 (range 0))";
  "sort","(sort-by (fn [x] (- t x)) (range 12))";
  "sort-stable","(sort-by (fn [x] (+ t x.k)) (list {:k 2 :id 0} {:k 1 :id 1} {:k 2 :id 2} {:k 1 :id 3}))";
  "sort-empty","(sort-by (fn [x] (/ t 0.)) (range 0))";
  "for-large","(for [i (range 1000)] (+ i t))";
  "for-live-items","(for [i (list t (+ t 1.))] (* i t))";
  "for-product","(for [i (range 2) j (range 3)] :skip [4] (+ (+ (* 10 i) j) t))";
  "for-dependent","(for [i (range 3) j (range i)] (+ (+ (* 10 i) j) t))";
  "for-lazy-source","(for [i (range 0) j (list (/ t 0.))] t)";
  "for-skip","(for [i (range 4)] :skip [0 1 2 3] (/ t 0.))";
  "sum-dynamic","(sum [i (range t)] (* i t))";
  "sum-product","(sum [i (range 4) j (range 3)] (+ (+ i j) t))";
  "sum-bound","(sum [i (range t) j (range 2)] t)";
  "fold","(fold [a 0] [i (range 1000)] (+ a t))";
  "fold-record","(fold [a {:x 0. :y 1.}] [i (range 4)] (assoc a :x (+ a.x t) :y a.x))";
  "fold-record-packed","(fold [a {:n 0.}] [i (array/range 4096)] (assoc a :n (+ a.n t)))";
  "scan","(scan [a 0] [i (range 4)] (+ a t))";
  "scan-record","(scan [a {:n 0}] [i (range 3)] (assoc a :n (+ a.n t)))";
  "nested-skip","(for [i (range 3)] (for [j (range 2)] :skip [[1 0] [2 1]] (+ (+ (* 10 i) j) t)))";
  "captured-list-count","(let* [xs (list t (/ t 0.))] (+ (count xs) t))";
  "captured-list-nth","(let* [xs (list t 1)] (nth xs 0))";
  "captured-list-lazy","(let* [xs (list t (/ t 0.))] (nth xs 0))";
  "captured-list-map","(let* [xs (list t 1) ys (map (fn [x] (+ x 1.)) xs)] (if (> t -1000.) ys ys))";
  "captured-list-reduce","(let* [xs (list t 1)] (reduce + 0 xs))";
  "captured-list-ignored","(let* [xs (list t (/ t 0.)) ys (map (fn [x] 1) xs)] (+ (first ys) t))";
  "list-accumulator","(fold [a (list 0)] [i (range 2)] (list (+ (nth a 0) t)))";
  "empty-list-accumulator","(fold [a (list)] [i (range 1)] (list t 0.5))";
  "empty-list-accumulator-tags","(fold [a (list)] [i (range 2)] (if (> i 0) (list 1) (list t)))";
]
let check (name,body) =
  let tested=if String.starts_with ~prefix:"captured-" name then body
    else "(if (> t -1000.) " ^ body ^ " " ^ body ^ ")" in
  let source="(workspace w (graph g :context value (let* [tested " ^ tested ^ "] 0.)))" in
  let ws=match Flow.Workspace.check {Flow.Check.version=1;kinds=[]} (ok (Flow.Syntax.parse source)) with
    | Some ws,[] -> ws | _,ds -> failwith (name ^ ": " ^ String.concat "; " (List.map Flow.Diagnostic.to_string ds)) in
  let r=match snd (List.hd (List.assoc ["g";"tested"] (ok (E.static ~record:true ws)).records)) with
    | E.Residual r -> r | _ -> failwith (name ^ ": expected residual") in
  let core=match I.Core_lower.lower r with Ok p -> p | Error n -> failwith (name ^ ": refused " ^ n) in
  assert (Format.asprintf "%a" I.Core.pp core = Format.asprintf "%a" I.Core.pp (Result.get_ok (I.Core_lower.lower r)));
  let program=ok (I.Executor.compile (E.Residual r)) in
  List.iter (fun time ->
    let live=Frame_input.at_time time in
    let expected=E.Private.force_reference (E.Residual r) ~live in
    let verify actual = match actual,expected with
      | Ok actual,Ok expected when same actual expected -> ()
      | Error a,Error b when a.Flow.Diagnostic.code=b.Flow.Diagnostic.code -> ()
      | _ -> let show=function Ok v -> E.show v | Error d -> Flow.Diagnostic.to_string d in
          failwith (Printf.sprintf "%s at %g: %s <> %s" name time (show actual) (show expected)) in
    verify (E.force (E.Residual r) ~live);
    verify (I.Core_exec.run core ~live);
    List.iter (fun enabled ->
      let previous= !(E.Private.core_residuals) in
      Fun.protect ~finally:(fun () -> E.Private.core_residuals:=previous) (fun () ->
        E.Private.core_residuals:=enabled;verify (I.Executor.force program ~live))) [false;true])
    [-3.;-2.5;-0.;0.;0.37;1.;1.9;3.;8.;4096.;4097.]
let () = List.iter check cases;print_endline "Core lists: direct/reference/closure/executor parity passed"

let () =
  let module C=I.Core in
  let source : C.source = {site=["builder"];owner=[];instance=0;prefix=[];iter=[];span=None} in
  let statement id node : C.statement = {id;source;node} in
  let program body : C.program =
    {constants=[|Int 2;Int 0;Int 7;List [|Int 0;Int 0|]|];
     locals=[|Flow.Ty.Int;List Int;Int;Int;List Int;Record ["xs",List Int]|];
     body;results=[|1|];state_slots=[||];regions=[||];call_slots=0} in
  let init=[statement 0 (Assign (0,Constant 0));statement 1 (Assign (1,Prim (Sequence_build,["count",0])));
    statement 2 (Assign (2,Constant 1));statement 3 (Assign (3,Constant 2))] in
  let store=statement 4 (Store {sequence=1;index=2;value=3}) in
  let live=Frame_input.at_time 0. in
  assert (I.Core_exec.run (program (init @ [store])) ~live = Ok (E.List [|Int 7;No_geo|]));
  List.iter (fun body -> match I.Core_exec.run (program body) ~live with
    | Error d -> assert (d.code="E_CORE_OWNERSHIP")
    | Ok _ -> failwith "A published or constant sequence accepted a store")
    [init @ [statement 5 (Assign (4,Local 1));statement 6 (Assign (5,Fields ["xs",4]));store];
     [statement 0 (Assign (1,Constant 3));statement 1 (Assign (2,Constant 1));
      statement 2 (Assign (3,Constant 2));store]];
  print_endline "Core list stores: local builder ownership and alias publication passed"
