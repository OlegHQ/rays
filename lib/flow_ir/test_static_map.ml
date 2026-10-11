(* Flow_ir.static against Flow.Eval.static: a static packed map of more than 4,096 elements is
   made by its CPU kernel after the walker's first 4,096 elements, and the evaluation is the same
   value bit for bit, the same records and the same failure. *)
module E = Flow.Eval
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let checked body =
  let forms = ok (Flow.Syntax.parse ("(workspace w (graph g :context host " ^ body ^ "))")) in
  match Flow.Workspace.check {Flow.Check.version = 1; kinds = []} forms with
  | Some ws, [] -> ws
  | _, ds -> failwith (body ^ ": " ^ String.concat "; " (List.map Flow.Diagnostic.to_string ds))

let bits (v : E.value) = match v with
  | E.Float_array d | Vec2_array d | Vec3_array d | Vec4_array d -> Array.map Int64.bits_of_float d
  | _ -> failwith "a packed array"
let rec same (a : E.value) (b : E.value) = match a, b with
  | (E.Float_array _ | Vec2_array _ | Vec3_array _ | Vec4_array _), _ ->
      Flow.Value.ty_of a = Flow.Value.ty_of b && bits a = bits b
  | Record x, Record y -> List.length x = List.length y
      && List.for_all2 (fun (n, v) (m, w) -> n = m && same v w) x y
  | List x, List y -> Array.length x = Array.length y && Array.for_all2 same x y
  | Residual _, Residual _ -> true
  | _ -> a = b

let maps = [
  (* the hash of sketches/million_marks, without its drift *)
  "(let* [indices (array/range 20000) extent 300.0]
     (map (fn [i] (let* [h (fn [s] (abs (mod (* (sin (+ (* i 12.9898) (* s 78.233))) 43758.5453) 1.0)))
                         x (- (+ (h 1.0) (h 2.0)) 1.0) y (- (h 3.0) 0.5)]
                    [(* x extent) (* y extent) 0])) indices))";
  "(map (fn [i] (* (sqrt i) 0.5)) (array/range 4097))";
  "(let* [a (array/range 9000) b (map (fn [i] (+ i 0.5)) a)] (map (fn [x y] [(- y x) (* x y)]) a b))";
  "(let* [a (array/range 5000)] {:first (map (fn [i] (if (> (mod i 3) 1) (- 0 i) (/ i 7))) a)
                                 :second (map (fn [i] [i (cos i) (pow i 0.5) 1]) a)})";
  (* 4,096 elements and fewer are the walker's alone *)
  "(map (fn [i] (* i 3)) (array/range 4096))";
  (* forms the kernel refuses are walked to the end *)
  "(map (fn [i] (value/rand i 7)) (array/range 4200))";
  (* a map that reads the frame stays a residual *)
  "(map (fn [i] (+ i t)) (array/range 5000))";
]

let () =
  List.iter (fun body ->
    let ws = checked body in
    let walked = ok (E.static ~record:true ws) and fast = ok (Flow_ir.static ~record:true ws) in
    if not (same (List.assoc "g" walked.results) (List.assoc "g" fast.results)) then
      failwith ("Flow_ir.static differs from the walker for " ^ body);
    (* The same paths are recorded. A path every element reaches has the same 4,096 records; one
       inside a branch has those of the first 4,096 elements, where the walker alone would go on
       to later elements until that path had 4,096. *)
    let counts (r : E.t) = List.map (fun (path, values) -> path, List.length values) r.records in
    if List.map fst (counts walked) <> List.map fst (counts fast)
       || not (List.for_all2 (fun (_, w) (_, f) -> f <= w) (counts walked) (counts fast)) then
      failwith ("records differ for " ^ body);
    let branches =
      let rec at i = i + 4 <= String.length body && (String.sub body i 4 = "(if " || at (i + 1)) in at 0 in
    if not branches && counts walked <> counts fast then
      failwith ("records of a map without a branch differ for " ^ body);
    let qualified = snd (ok (Flow_ir.qualify_workspace ~record:true ws)) in
    if not (same (List.assoc "g" walked.results) (List.assoc "g" qualified.results)) then
      failwith ("qualify_workspace differs from the walker for " ^ body)) maps;
  (* A failure, before or after the walked elements, is the walker's diagnostic. *)
  List.iter (fun body ->
    let ws = checked body in
    match E.static ws, Flow_ir.static ws with
    | Error a, Error b -> if a <> b then failwith ("another diagnostic for " ^ body)
    | _ -> failwith ("expected a failure for " ^ body))
    [ "(map (fn [i] (exp (- i 4300))) (array/range 5200))";
      "(map (fn [i] (exp (+ i 700))) (array/range 5200))" ];
  (* It is the kernel that makes the elements past 4,096: the walker is not asked for them. The
     walker costs about 22 microseconds an element, so 200,000 elements in well under a second
     of processor time can only be the kernel. *)
  let ws = checked "(map (fn [i] [(sin i) (cos i) 0]) (array/range 200000))" in
  let started = Sys.time () in
  let fast = ok (Flow_ir.static ws) in
  let seconds = Sys.time () -. started in
  (match List.assoc "g" fast.results with
   | E.Vec3_array d -> assert (Array.length d = 600000 && d.(3 * 199999) = sin 199999.)
   | _ -> failwith "a vec3 array");
  if seconds > 2. then failwith (Printf.sprintf "a 200,000-element static map took %.2f s: it was walked" seconds);
  print_endline "Static maps: kernel-made values, records and failures equal the walker's"
