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
let primitives = Core_fixtures.primitives
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
let regions = Core_fixtures.regions
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
      verify "core" (I.Executor.force program ~live)) times
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
