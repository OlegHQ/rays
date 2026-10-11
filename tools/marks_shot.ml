(* The native picture of a draw workspace as one PNG: the oracle of the browser presenter (plan P6.4, P6.5).
   Runs the core executor for FRAME fixed-step frames (dt 1/60, pointer (100, 100): the frames of
   web_parity.exe and tools/web/test/frames.mjs), adapts the last frame's mark table with Marks_scene and renders it
   offscreen at density 1.  usage: marks_shot DIR OUT.png WIDTH HEIGHT FRAME   (DIR holds sketch.rays) *)
module E = Flow.Eval
module C = Flow_ir.Core_exec

let () =
  if Array.length Sys.argv <> 6 then (prerr_endline "usage: marks_shot DIR OUT.png WIDTH HEIGHT FRAME"; exit 2);
  let dir = Sys.argv.(1) and output = Sys.argv.(2) in
  let width = int_of_string Sys.argv.(3) and height = int_of_string Sys.argv.(4) and frames = int_of_string Sys.argv.(5) in
  let size = width, height and dt = 1. /. 60. in
  let fail text = prerr_endline text; exit 1 in
  let _, doc = Web_export.load (Filename.concat dir "sketch.rays") in
  let lowered = match doc with
    | Error (d :: _) -> fail (Flow.Diagnostic.to_string d) | Error [] -> fail "does not check"
    | Ok doc -> (match Web_export.lower doc with Ok l -> l | Error d -> fail (Flow.Diagnostic.to_string d)) in
  let prepared = C.prepare lowered.program and state = E.create_state () and buffers = C.Buffers.create () in
  let last = ref None in
  for i = 1 to frames do
    let live = { (Frame_input.at_time (float i *. dt)) with dt; frame = i; tick = i; size; pointer = (100., 100.) } in
    C.Buffers.clear buffers;
    let drawn = ref (Error (Flow.Diagnostic.error ~code:"E_CORE" "The draw program did not run.")) in
    (match lowered.root with
     | None -> drawn := C.draw prepared ~live ~size ~buffers
     | Some root ->
         let execute r live = drawn := C.draw ~root:r prepared ~live ~size ~buffers; Some (Ok (E.Int 0)) in
         ignore (E.Private.force_with_executor ~state ~execute (E.Residual root) ~live));
    last := Some !drawn
  done;
  let marks = match !last with Some (Ok m) -> m | Some (Error d) -> fail (Flow.Diagnostic.to_string d) | None -> fail "no frames" in
  let scene = match Marks_scene.scene ~buffers marks with Ok s -> s | Error d -> fail (Flow.Diagnostic.to_string d) in
  let canvas = Rays.Canvas.create_exn ~width ~height in
  Rays.Canvas.render canvas scene;
  (match Rays.Canvas.save_png canvas output with Ok () -> () | Error e -> fail e);
  Rays.Canvas.destroy canvas
