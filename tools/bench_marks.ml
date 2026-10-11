(* Drawing.render_prepared for draw/circles and draw/rects, static and animated, through the core
   path. Wall time and allocated bytes per frame (median of the frames run). *)
module E = Flow.Eval

let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let catalog = { Flow.Check.version = 0; kinds = [] }
let size = (800, 600)

let check source = match Flow.Workspace.check catalog (ok (Flow.Syntax.parse source)) with
  | Some ws, ds when not (List.exists (fun (d : Flow.Diagnostic.t) -> d.severity = Error) ds) -> ws
  | _, ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds))

let points n animated =
  Printf.sprintf "(map (fn [i] [(* (mod i 800) 1.0) (+ (/ i 1250) %s) 0]) (array/range %d))"
    (if animated then "(* 5 (sin t))" else "0") n

let picture kind n animated =
  let p = points n animated in
  match kind with
  | "circles" -> Printf.sprintf "(draw/circles %s :radius 2 :fill \"#5aaaf0\")" p
  | _ -> Printf.sprintf "(draw/rects %s [3 3 0] :fill \"#5aaaf0\")" p

let median a = let a = Array.copy a in Array.sort Float.compare a; a.(Array.length a / 2)

let measure kind n animated =
  let source = Printf.sprintf "(workspace w (graph g :context draw %s))" (picture kind n animated) in
  let evaluation = ok (E.static (check source)) in
  let prepared = ok (Rays_editor.Drawing.prepare ~states:evaluation.states evaluation.plan
    (List.assoc "g" evaluation.results)) in
  let frames = if n >= 1_000_000 then 3 else 8 in
  let state = E.create_state () in
  let frame i = ok (Rays_editor.Drawing.render_prepared ~state prepared
    ~live:{(Frame_input.at_time (float i /. 60.)) with frame = i; tick = i; size} ~size) in
  ignore (frame 0);
  let samples = Array.init frames (fun i ->
    Gc.full_major ();
    let bytes = Gc.allocated_bytes () and start = Unix.gettimeofday () in
    ignore (frame (i + 1));
    Unix.gettimeofday () -. start, Gc.allocated_bytes () -. bytes) in
  median (Array.map fst samples), median (Array.map snd samples)

let () =
  Printf.printf "%-8s %-9s %9s | %12s %14s\n" "kind" "mode" "n" "ms" "bytes";
  List.iter (fun kind -> List.iter (fun animated -> List.iter (fun n ->
    let t, b = measure kind n animated in
    Printf.printf "%-8s %-9s %9d | %12.3f %14.0f\n%!" kind (if animated then "animated" else "static") n (t *. 1e3) b)
    [10_000; 100_000; 1_000_000]) [false; true]) ["circles"; "rects"]
