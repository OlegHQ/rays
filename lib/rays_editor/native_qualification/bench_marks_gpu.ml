(* Drawing.render_prepared with GPU mark attributes (P4.13): circles and rects whose positions are a
   GPU region output, with uniform style (constant radius or size and fill: what the removed gpu_circles
   arm served) and per-instance style (radius or size from a second GPU region, fill a CPU colour
   buffer). Wall time and allocated bytes per frame, median of the frames run; the frame includes
   the kernel dispatches with their completion and status read, not the render pass.
   Run: _build/default/lib/rays_editor/native_qualification/bench_marks_gpu.exe *)
module L = Flow_sop.Lower
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let size = (800, 600)

let points n = Printf.sprintf "(map (fn [i] [(* (mod i 800) 1.0) (+ (/ i 1250) (* 5 (sin t))) 0]) (array/range %d))" n
let colours n = Printf.sprintf "(map (fn [i] [(/ (mod i 256) 255) 0.5 0.8]) (array/range %d))" n
(* [radius] and [fill] say which attributes are per instance: the extent (a second GPU region) and the
   fill (a CPU colour buffer). *)
let picture kind ~radius ~fill n =
  let extent_circle = if radius then Printf.sprintf "(map (fn [i] (+ 1 (mod i 4))) (array/range %d))" n else "2"
  and extent_rect = if radius then Printf.sprintf "(map (fn [i] [(+ 2 (mod i 3)) 3 0]) (array/range %d))" n else "[3 3 0]"
  and fill = if fill then colours n else "\"#5aaaf0\"" in
  match kind with
  | "circles" -> Printf.sprintf "(draw/circles %s :radius %s :fill %s)" (points n) extent_circle fill
  | _ -> Printf.sprintf "(draw/rects %s %s :fill %s)" (points n) extent_rect fill

let median a = let a = Array.copy a in Array.sort Float.compare a; a.(Array.length a / 2)

let measure kind (radius, fill) n =
  let lowered = Flow.Syntax.parse (Printf.sprintf "(workspace w (graph g :context draw %s))" (picture kind ~radius ~fill n))
    |> ok |> L.workspace ~factories:Sop_catalog.Editor.factories |> ok in
  let prepared = Drawing.prepare ~approx:lowered.approx ~states:lowered.states lowered.plan
    (List.assoc "g" lowered.evaluated.results) |> ok in
  let gpu = Workspace_gpu.create () in
  Workspace_gpu.qualification gpu;
  Fun.protect ~finally:(fun () -> Workspace_gpu.close gpu) (fun () ->
    let frames = if n >= 1_000_000 then 5 else 11 in
    let state = Flow.Eval.create_state () in
    let frame i = Workspace_gpu.with_backend gpu (fun () -> ok (Drawing.render_prepared ~state ~gpu:(Workspace_gpu.marks gpu) prepared
      ~live:{(Frame_input.at_time (float i /. 60.)) with frame = i; tick = i; size} ~size)) in
    ignore (frame 0);
    let samples = Array.init frames (fun i ->
      Gc.full_major ();
      let bytes = Gc.allocated_bytes () and start = Unix.gettimeofday () in
      ignore (frame (i + 1));
      Unix.gettimeofday () -. start, Gc.allocated_bytes () -. bytes) in
    let host, _, _, _, _ = Workspace_gpu.image_stats gpu in
    if host.runners_created = 0 then failwith "the region did not run on the GPU";
    median (Array.map fst samples), median (Array.map snd samples))

let () =
  Printf.printf "%-8s %-13s %9s | %10s %14s\n" "kind" "style" "n" "ms" "bytes";
  List.iter (fun n -> List.iter (fun kind ->
    List.iter (fun (name, style) ->
      let t, b = measure kind style n in
      Printf.printf "%-8s %-13s %9d | %10.3f %14.0f\n%!" kind name n (t *. 1e3) b)
      ["uniform", (false, false); "radius", (true, false); "fill", (false, true); "per-instance", (true, true)])
    ["circles"; "rects"]) [100_000; 1_000_000]
