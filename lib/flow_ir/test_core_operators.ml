module E = Flow.Eval
module I = Flow_ir
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let bits x y = Int64.bits_of_float x = Int64.bits_of_float y
let rec same (a : E.value) (b : E.value) = match a,b with
  | Float x,Float y -> bits x y
  | Vec3 (a,b,c),Vec3 (x,y,z) -> bits a x && bits b y && bits c z
  | List a,List b -> Array.length a=Array.length b && Array.for_all2 same a b
  | a,b -> a=b
(* Every value-context scalar operator the closure compiler accepts, with at least one
   live expression. The coverage check below fails when an operator is added without a case. *)
let cases = [
  "frame/input","(count (get (frame/input) :keys))";
  "frame/dt","(+ (frame/dt) t)"; "frame/index","(* t (frame/index))";
  "frame/width","(* t (frame/width))"; "frame/height","(* t (frame/height))";
  "pointer/x","(+ t (pointer/x))"; "pointer/y","(+ t (pointer/y))";
  "pointer/down","(if (pointer/down) t 0.)"; "pointer/down","(if (pointer/down \"right\") t 0.)";
  "pointer/down","(if (pointer/down \"x1\") t 0.)"; "pointer/down","(if (pointer/down \"nope\") t 0.)";
  "key/down","(if (key/down \"space\") t 0.)"; "key/down","(if (key/down \"zzz\") t 0.)";
  "array/range","(array/nth (array/range 8) (+ 1 (int t)))";
  "array/float","(array/nth (array/float 4 t) 1)";
  "array/vec3","(array/nth (array/vec3 4 [t 1 2]) 2)";
  "array/count","(array/count (array/float (+ 3 (int t))))";
  "array/nth","(array/nth (array/range 8) (+ 2 (int t)))";
  "array/slice","(array/count (array/slice (array/range 10) (int t) 4))";
  "array/concat","(array/count (array/concat (array/range (+ 2 (int t))) (array/float 2)))";
  "array/sum","(array/sum (array/float 5 t))"; "array/sum","(array/sum (array/vec3 3 [t 1 2]))";
  "array/sum","(+ t (array/sum (array/float 0)))";
  "int/mul","(int/mul (int t) 3)"; "int/div","(int/div (int t) 2)"; "int/mod","(int/mod (int (* t 7)) 3)";
  "int/and","(int/and (int t) 6)"; "int/xor","(int/xor (int t) 5)";
  "length","(length [t 1 2])"; "equal?","(equal? t 1.)"; "exp","(exp t)"; "exact","(exact (+ t 1))";
  "+","(+ t 1)"; "-","(- t 1)"; "*","(* t 3)"; "/","(/ t 3)"; "mod","(mod t 0.7)"; "pow","(pow t 2)";
  "min","(min t 1)"; "max","(max t 1)"; "sin","(sin t)"; "cos","(cos t)"; "sqrt","(sqrt (+ t 1))";
  "floor","(floor t)"; "ceil","(ceil t)"; "round","(round t)"; "int","(int (* t 10))";
  "float","(float (int t))"; "abs","(abs t)";
  "<","(if (< t 1) 1. 0.)"; ">","(if (> t 1) 1. 0.)"; "<=","(if (<= t 1) 1. 0.)";
  ">=","(if (>= t 1) 1. 0.)"; "=","(if (= t 1) 1. 0.)"; "and","(if (and (> t 0) (< t 2)) 1. 0.)";
  "or","(if (or (> t 2) (< t 0)) 1. 0.)"; "not","(if (not (> t 1)) 1. 0.)";
  "value/rand","(value/rand t 1 2)";
  "value/hsv","(value/hsv (* t 0.37) 0.5 0.9)"; "value/hsv","(value/hsv (- 0 t) 1. 0.25)";
  "value/hsv","(value/hsv (* t 0.166) 0.7 0.8)"; "value/hsv","(value/hsv (+ t 5.) 0.3 1.)";
  "value/lerp","(value/lerp t 1 0.25)"; "value/lerp","(value/lerp (* t 1.3) 0.7 0.3)";
  "value/lerp","(value/lerp [t 1 2] [3 (* t 1.1) 5] (/ t 7))"; "value/polar","(value/polar t 2)";
  "range","(range (int (+ t 3)))"; "linspace","(linspace 0 t 5)"; "linspace","(linspace 0 (+ 1 t) 1)";
  "linspace","(linspace 1 t 0)"; "linspace","(linspace 0 t (int (* t 3)))";
  "count","(+ t (count (list 1 2 3)))"; "first","(first (list t 1 2))"; "first","(first (take (int t) (list t 1)))";
  "last","(+ t (last (list 1 2 3)))"; "last","(last (take (int t) (list t 1)))";
  "rest","(sum [x (rest (list t 1 2))] (* x t))"; "nth","(nth (list t 1 2) (int t))"; "reverse","(sum [x (reverse (list t 1 2))] (* x t))";
  "take","(sum [x (take 2 (list t 1 2))] (* x t))"; "drop","(sum [x (drop 1 (list t 1 2))] (* x t))";
]
let times = [-3.;-0.;0.;0.37;1.;1.9;3.;7.5]
let lives = List.concat_map (fun time ->
  let base=Frame_input.at_time time in
  [base; {base with buttons=["left";"x1"]; keys=["space";"a"]; pointer=(12.,37.); size=(640,480); frame=3; dt=0.125}]) times
let () =
  let covered=List.sort_uniq compare (List.map fst cases) in
  List.iter (fun (o : Flow.Op.t) ->
    if o.ctx=Flow.Context.value && o.shape=Flow.Op.Scalar && not (List.mem o.name covered) then
      failwith ("No core operator case for " ^ o.name)) (Flow.Op.of_context Flow.Context.value);
  let n=ref 0 and static=ref [] in
  List.iter (fun (name,body) ->
    let source="(workspace w (graph g :context value (let* [tested " ^ body ^ "] 0.)))" in
    let ws=match Flow.Workspace.check {Flow.Check.version=1;kinds=[]} (ok (Flow.Syntax.parse source)) with
      | Some ws,[] -> ws | _,ds -> failwith (body ^ ": " ^ String.concat "; " (List.map Flow.Diagnostic.to_string ds)) in
    let value=snd (List.hd (List.assoc ["g";"tested"] (ok (E.static ~record:true ws)).records)) in
    match value with E.Residual r -> begin
    let core=match I.Core_lower.lower r with Ok p -> p | Error n -> failwith (name ^ " " ^ body ^ ": refused " ^ n) in
    List.iter (fun live ->
      incr n;
      match I.Core_exec.run ~root:r core ~live,E.Private.force_reference value ~live with
      | Ok a,Ok b -> if not (same a b) then failwith (Printf.sprintf "%s at %g: %s <> %s" body live.t (match a,b with E.Vec3 (x,y,z),E.Vec3 (p,q,r) -> Printf.sprintf "%h %h %h / %h %h %h" x y z p q r | _ -> E.show a) (E.show b))
      | Error (a : Flow.Diagnostic.t),Error (b : Flow.Diagnostic.t) ->
          if a.code<>b.code then failwith (Printf.sprintf "%s at %g: %s <> %s" body live.t a.code b.code)
      | Ok a,Error b -> failwith (Printf.sprintf "%s at %g: %s but reference %s" body live.t (E.show a) b.code)
      | Error a,Ok b -> failwith (Printf.sprintf "%s at %g: %s but reference %s" body live.t a.code (E.show b))) lives end
    | _ -> static := body :: !static) cases;
  if !static<>[] then failwith ("Not live: " ^ String.concat " | " !static);
  Printf.printf "Core operators: every scalar value operator lowers and matches the walker bit for bit (%d cases)\n" !n
