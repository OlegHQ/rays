module E = Flow.Eval
module I = Flow_ir
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let bits x y = Int64.bits_of_float x = Int64.bits_of_float y
let rec same (a : E.value) (b : E.value) = match a,b with
  | Float x,Float y -> bits x y
  | Vec3 (a,b,c),Vec3 (x,y,z) -> bits a x && bits b y && bits c z
  | List a,List b -> Array.length a=Array.length b && Array.for_all2 same a b
  | (Float_array a,Float_array b) -> Array.length a=Array.length b && Array.for_all2 bits a b
  | (Vec3_array a,Vec3_array b) -> Array.length a=Array.length b && Array.for_all2 bits a b
  | a,b -> a=b
let same_result a b = match a,b with
  | Ok a,Ok b -> same a b
  | Error (a : Flow.Diagnostic.t),Error (b : Flow.Diagnostic.t) -> a.code=b.code | _ -> false
(* Primitives are lowered inline; region forms must be the residual's own term. *)
let primitives = [
  "range","(array/nth (array/range 8) (int (* t 0.)))";
  "float","(array/float (+ 3 (int t)) 1.5)";
  "vec3","(array/nth (array/vec3 4) 2)";
  "count","(array/count (array/float (+ 3 (int t))))";
  "nth","(array/nth (array/range 8) (+ 2 (int t)))";
  "slice","(array/slice (array/range 10) (int t) 4)";
  "concat","(array/concat (array/range (+ 2 (int t))) (array/float 2))";
  "noise3","(noise3 [t (* t 0.5) 1.25] :seed 7 :octaves 3)";
  (* Packed higher-order forms a region refuses are built element by element, past the list cap. *)
  "packed-map-int","(map (fn [x] [(int x) (* x t) 0]) (array/range (+ 5000 (int t))))";
  "packed-map-zip","(map (fn [p v] (+ p (* v t))) (array/vec3 3 [1 2 3]) (array/vec3 3 [0.5 0.25 0.125]))";
  "packed-map-float","(map (fn [x] (floor (* x t))) (array/range 40))";
  "packed-map-empty","(map (fn [x] [x x x]) (array/range (int (* t 0.))))";
  "packed-filter","(filter (fn [x] (> (int x) (int (* t 10.)))) (array/range (+ 5000 (int t))))";
  "packed-filter-vec","(filter (fn [p] (> p.x t)) (map (fn [x] [x (* x 2.) 0]) (array/range 20)))";
]
(* Dense parameter sweeps: every colour sector and stop boundary, many roundings. *)
let sweeps = [
  "hsl-sectors","(color/hsl (* t 60.) 0.75 0.5)",List.init 161 (fun i -> float_of_int (i-40) *. 0.25);
  "hsl","(color/hsl (* t 37.31) (abs (sin (* t 1.7))) (abs (cos (* t 0.9))))",
    List.init 40000 (fun i -> float_of_int i *. 0.0137 -. 100.);
  "gradient","(color/gradient (list \"#101426\" \"#244a72\" \"#3ca6a6\" \"#f2d16b\" \"#f26444\") t)",
    List.init 2501 (fun i -> float_of_int (i-500) *. 0.001);
  "gradient-two","(color/gradient (list \"#000000\" \"#ffffff\") t)",List.init 2501 (fun i -> float_of_int i *. 0.0004);
  "gradient-one","(color/gradient (list \"#336699\") t)",[0.;0.5];
]
let regions = [
  "map","(map (fn [x] (+ (* x t) 1.)) (array/range 2048))";
  "for","(for [x (array/range 2048)] (* x t))";
  "sum","(sum [x (array/range 2048)] (* x t))";
  "array-sum","(array/sum (map (fn [x] (* x t)) (array/range 2048)))";
  "fold","(fold [a 0.] [x (array/range 2048)] (+ a (* x t)))";
  "reduce","(reduce (fn [a x] (+ a (* x t))) 0. (array/range 2048))";
  "nonfinite","(map (fn [x] (/ x (- t t))) (array/range 4))";
]
let times = [-3.;-0.;0.;0.37;1.;1.9;3.]
let check ?(times=times) ~region (name,body) =
  let tested=if region then body else "(if (> t -1000.) " ^ body ^ " " ^ body ^ ")" in
  let source="(workspace w (graph g :context value (let* [tested " ^ tested ^ "] 0.)))" in
  let ws=match Flow.Workspace.check ~ops:I.Operators.all {Flow.Check.version=1;kinds=[]} (ok (Flow.Syntax.parse source)) with
    | Some ws,[] -> ws | _,ds -> failwith (name ^ ": " ^ String.concat "; " (List.map Flow.Diagnostic.to_string ds)) in
  let value=snd (List.hd (List.assoc ["g";"tested"] (ok (E.static ~record:true ws)).records)) in
  let r=match value with E.Residual r -> r | _ -> failwith (name ^ ": expected residual") in
  let core=match I.Core_lower.lower r with Ok p -> p | Error n -> failwith (name ^ ": refused " ^ n) in
  let text=Format.asprintf "%a" I.Core.pp core in
  let has_region=Array.length core.regions>0 in
  if has_region<>region then failwith (name ^ ": region expectation\n" ^ text);
  let program=ok (I.Executor.compile value) in
  List.iter (fun time ->
    let live=Frame_input.at_time time in
    let expected=E.Private.force_reference value ~live in
    let verify label actual = if not (same_result actual expected) then
      failwith (Printf.sprintf "%s at %g (%s)" name time label) in
    (* A failing region declines to the packed path, so only successes compare with the walker. *)
    (match I.Core_exec.run core ~live,expected with
     | Ok a,Ok b -> if not (same a b) then failwith (Printf.sprintf "%s at %g (direct)" name time)
     | Error _,Error _ when not region -> ()
     | Error _,_ when region -> ()
     | _ -> failwith (Printf.sprintf "%s at %g (direct outcome)" name time));
    if not region || Result.is_ok expected then
      List.iter (fun enabled ->
        let previous= !(E.Private.core_residuals) in
        Fun.protect ~finally:(fun () -> E.Private.core_residuals:=previous) (fun () ->
          E.Private.core_residuals:=enabled;
          verify (if enabled then "core" else "closure") (I.Executor.force program ~live))) [false;true]) times
(* A workspace operator that reuses a shipped expansion's name keeps its own body: core declines it. *)
let () =
  let custom={I.Operators.noise3 with packed_extension=None;body=(fun ~live:_ ~node:_ _ -> E.Float 0.125)} in
  let source="(workspace w (graph g :context value (let* [tested (noise3 [t 0 0])] 0.)))" in
  let ws=match Flow.Workspace.check ~ops:[custom] {Flow.Check.version=1;kinds=[]} (ok (Flow.Syntax.parse source)) with
    | Some ws,[] -> ws | _,ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds)) in
  match snd (List.hd (List.assoc ["g";"tested"] (ok (E.static ~record:true ws)).records)) with
  | E.Residual r -> assert (I.Core_lower.lower r = Error "noise3")
  | _ -> failwith "expected residual"
let () =
  List.iter (check ~region:false) primitives;
  List.iter (fun (name,body,times) -> check ~times ~region:false (name,body)) sweeps;
  List.iter (check ~region:true) regions;
  print_endline "Core regions: packed-array primitives and Region_ref forms match the walker"
