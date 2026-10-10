module E = Flow.Eval
module I = Flow_ir
module C = I.Core
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let offset = {(Option.get (Flow.Op.find "+" Flow.Context.value)) with
  name="test/offset";signature={pos=["value",Flow.Ty.Float];opt=[];rest=None;kw=["offset",Flow.Ty.Float]}}
let checked source = match Flow.Workspace.check ~ops:[offset] {Flow.Check.version=1;kinds=[]} (ok (Flow.Syntax.parse source)) with
  | Some ws,[] -> ws | _,ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds))
let workspace ?(defs="") ?(inputs="") body =
  "(workspace w " ^ defs ^ " (graph g :context value " ^ inputs ^ " (let* [tested " ^ body ^ "] 0.)))"
let residual source = match snd (List.hd (List.assoc ["g";"tested"] (ok (E.static ~record:true (checked source))).records)) with
  | E.Residual r -> r | _ -> failwith ("Expected a residual: " ^ source)
let lower r = match I.Core_lower.lower r with Ok p -> p | Error name -> failwith ("Core refused " ^ name)
let bits x y = Int64.bits_of_float x=Int64.bits_of_float y
let rec same (a : E.value) (b : E.value) = match a,b with
  | Float x,Float y -> bits x y
  | Vec2 (a,b),Vec2 (x,y) -> bits a x && bits b y
  | Vec3 (a,b,c),Vec3 (x,y,z) -> bits a x && bits b y && bits c z
  | Vec4 (a,b,c,d),Vec4 (x,y,z,w) -> bits a x && bits b y && bits c z && bits d w
  | List a,List b -> Array.length a=Array.length b && Array.for_all2 same a b
  | Record a,Record b -> List.length a=List.length b && List.for_all2 (fun (n,a) (m,b) -> n=m && same a b) a b
  | a,b -> a=b
let cases = [
  "vec2",workspace "[t (+ t 1.)]";
  "vec4",workspace "[t (+ t 1.) (- 0. t) (* t 2.)]";
  "cond",workspace "(cond (< t 0.) (- 0. t) (> t 1.) (* t 2.) :else (+ t 0.5))";
  "case-number",workspace "(case (int t) 0 10. 1 20. :else 30.)";
  "case-bool",workspace "(case t false 10. true 20. :else 30.)";
  "case-text",workspace "(case (if (> t 0.) \"a\" \"b\") \"b\" (- 0. t) :else (+ t 1.))";
  "case-rounding",workspace "(case (+ 9007199254740992 t) 9007199254740993 1. :else 2.)";
  "let-vector",workspace "(if (> t 0.) (let* [[x y] [t (* t 2.)]] (+ x y)) (- 0. t))";
  "let-vector4",workspace "(if (> t 0.) (let* [[x y z w] [t (+ t 1.) (- 0. t) (* t 2.)]] (+ x (+ y (+ z w)))) t)";
  "let-nested",workspace ~inputs:"[(r : (list vec2) (list [1. 2.] [3. 4.]))]"
    "(if (> t 0.) (let* [[[a b] [c d]] r] (+ t (+ a (+ b (+ c d))))) t)";
  "let-list",workspace "(if (> t 0.) (let* [[x y] (for [i (range 3)] (+ t i))] (+ x y)) t)";
  "let-keys",workspace ~inputs:"[(r : {:a float :b float} {:a 2. :b 3.})]"
    "(if (> t 0.) (let* [{:keys [a b]} r] (+ t (+ a b))) t)";
  "local-fn",workspace "(if (> t 0.) (let* [bias (* t 2.) f (fn [x] (+ x bias))] (+ (f t) (f 1.))) t)";
  "typed-fn",workspace "(if (> t -10.) (let* [f (fn [(x : int)] (+ x 1))] (f t)) 0)";
  "typed-vector-fn",workspace "(if (> t -10.) (let* [f (fn [(x : vec4)] x.w)] (f t)) 0.)";
  "pattern-fn",workspace "(if (> t 0.) (let* [f (fn [[x y]] (+ x y))] (f [t (* t 2.)])) t)";
  "named-fn",workspace ~defs:"(defn f :context value [(x : float) (bias : float 2.)] (+ x bias))"
    "(if (> t 0.) (f t) t)";
  "operator-fn",workspace ~defs:"(defn use2 :context value [(f : fn) (x : float) (y : float)] (f x y))"
    "(if (> t 0.) (use2 + t 2.) t)";
  "callable-argument",workspace ~defs:"(defn use :context value [(f : fn) (x : float)] (f x))"
    "(if (> t 0.) (let* [bias t f (fn [x] (+ x bias))] (use f t)) t)";
  "macro",workspace ~defs:"(defmacro twice [x] `(+ ~x ~x))"
    "(if (> t 0.) (twice t) t)";
  "bypass",workspace "(if (> t 0.) ^:bypass (+ t (exp 10000.)) t)";
  "bypass-keyword",workspace "(if (> t 0.) ^:bypass (test/offset :offset (exp 10000.) t) t)";
  "bypass-coercion",workspace ~defs:"(defn asint :context value [(x : float)] (int x))"
    "(if (> t -10.) ^:bypass (asint t) 0)";
  "pattern-error",workspace "(if (> t 0.) (let* [[x y z] (for [i (range 2)] (+ t i))] (+ x y)) t)";
  "untaken-error",workspace "(if (> t 0.) (+ t 1.) (exp 10000.))";
]
let dump () =
  String.concat "" (List.map (fun (name,source) ->
    let r=residual source in let core=lower r in
    let printed=Format.asprintf "%a" C.pp core in
    assert (printed=Format.asprintf "%a" C.pp (lower r));
    List.iter (fun time ->
      let live=Frame_input.at_time time in
      let expected=E.Private.force_reference (E.Residual r) ~live in
      match I.Core_exec.run core ~live,expected with
      | Ok actual,Ok expected ->
          if name="bypass" || name="bypass-keyword" then assert (same actual (E.Float time));
          if not (same actual expected) then failwith (name ^ ": value mismatch")
      | Error actual,Error expected -> assert (actual.code=expected.code)
      | _ -> failwith (name ^ ": result mismatch")) [-3.;-2.5;0.;0.37;1.;1.9;100.25];
    name ^ "\n" ^ printed) cases)
let () =
  let actual=dump () in
  if Array.length Sys.argv=2 && Sys.argv.(1)="--print" then print_string actual
  else begin
    let expected=In_channel.with_open_bin "core_control.expected" In_channel.input_all in
    if expected<>actual then failwith ("Core control print changed:\n" ^ actual)
  end;
  let r=residual (workspace "(if (> t -100.) (let* [f (fn [x] (+ x 1.)) n (if (> t 0.) (f t) 0.)] (+ n (f t))) t)") in
  let core=lower r in
  let rec last_call last statements = List.fold_left (fun last (s : C.statement) -> match s.node with
    | Assign (n,Call_index _) -> Some n
    | If {yes;no;_} -> last_call (last_call last yes) no
    | _ -> last) last statements in
  let index=Option.get (last_call None core.body) in
  let counts={core with C.results=[|index|]} in
  List.iter (fun (time,count) ->
    let live=Frame_input.at_time time in
    assert (ok (I.Core_exec.run counts ~live) = E.Int count);
    assert (ok (I.Core_exec.run counts ~live) = E.Int count)) [1.,1; -1.,0];
  if Array.length Sys.argv=1 then
    print_endline "Core control: direct vector/branch/pattern/call/macro/bypass parity and dynamic call identity passed"

let () =
  List.iter (fun body ->
    let r=residual (workspace body) in
    let core=lower r in
    let program=ok (I.Executor.compile (E.Residual r)) in
    List.iter (fun time ->
      let live=Frame_input.at_time time in
      assert (ok (I.Executor.force program ~live) = E.Float time);
      assert (ok (I.Core_exec.run core ~live) = E.Float time)) [0.;0.37;2.])
    ["^:bypass (+ t 5.)";"^:bypass (+ t (exp 10000.))";
     "^:bypass (test/offset :offset (exp 10000.) t)"]
