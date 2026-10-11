(* The native picture of a draw workspace as one PNG: the oracle of the browser presenter (plan P6.4, P6.5).
   Runs the core executor for FRAME fixed-step frames (dt 1/60, pointer (100, 100): the frames of
   web_parity.exe and tools/web/test/frames.mjs), adapts the last frame's mark table with Marks_scene and renders it
   offscreen at density 1. Image maps use native Image_kernel snapshots; --gpu-images uses the native
   Run/Image_sink display path as the oracle for discontinuous f32 pixel functions.
   usage: marks_shot DIR OUT.png WIDTH HEIGHT FRAME [--gpu-images]   (DIR holds sketch.rays) *)
module E = Flow.Eval
module C = Flow_ir.Core_exec

let () =
  if Array.length Sys.argv < 6 || Array.length Sys.argv > 7
    || (Array.length Sys.argv = 7 && Sys.argv.(6) <> "--gpu-images") then
    (prerr_endline "usage: marks_shot DIR OUT.png WIDTH HEIGHT FRAME [--gpu-images]"; exit 2);
  let gpu_images = Array.length Sys.argv = 7 && Sys.argv.(6) = "--gpu-images" in
  let dir = Sys.argv.(1) and output = Sys.argv.(2) in
  let width = int_of_string Sys.argv.(3) and height = int_of_string Sys.argv.(4) and frames = int_of_string Sys.argv.(5) in
  let size = width, height and dt = 1. /. 60. in
  let fail text = prerr_endline text; exit 1 in
  let _, doc = Web_export.load (Filename.concat dir "sketch.rays") in
  let lowered = match doc with
    | Error (d :: _) -> fail (Flow.Diagnostic.to_string d) | Error [] -> fail "does not check"
    | Ok doc -> (match Web_export.lower doc with Ok l -> l | Error d -> fail (Flow.Diagnostic.to_string d)) in
  let prepared = C.prepare lowered.program and state = E.create_state () and buffers = C.Buffers.create () in
  let image = function E.Deferred (_, id) -> Ok (id + 1)
    | _ -> Error (Flow.Diagnostic.error ~code:"E_IMAGE" "Expected an image plan node.") in
  let last = ref None in
  for i = 1 to frames do
    let live = { (Frame_input.at_time (float i *. dt)) with dt; frame = i; tick = i; size; pointer = (100., 100.) } in
    C.Buffers.clear buffers;
    let drawn = ref (Error (Flow.Diagnostic.error ~code:"E_CORE" "The draw program did not run.")) in
    (match lowered.root with
     | None -> drawn := C.draw ~image prepared ~live ~size ~buffers
     | Some root ->
         let execute r live = drawn := C.draw ~root:r ~image prepared ~live ~size ~buffers; Some (Ok (E.Int 0)) in
         ignore (E.Private.force_with_executor ~state ~execute (E.Residual root) ~live));
    last := Some !drawn
  done;
  let marks = match !last with Some (Ok m) -> m | Some (Error d) -> fail (Flow.Diagnostic.to_string d) | None -> fail "no frames" in
  let images = Hashtbl.create 8 in
  let get = function Ok v -> v | Error d -> fail (Flow.Diagnostic.to_string d) in
  let gpu = if gpu_images then Some (match Rays_execution.acquire_gpu () with Ok g -> g
    | Error e -> fail (Format.asprintf "%a" Rays_execution.pp_error e)) else None in
  let pipelines = Option.map (fun g -> Flow_gpu.Pipelines.create ~clock:Unix.gettimeofday (Rays_execution.gpu_device g)) gpu in
  let live = { (Frame_input.at_time (float frames *. dt)) with dt; frame=frames; tick=frames; size; pointer=(100.,100.) } in
  let resolve id = match Hashtbl.find_opt images id with Some image -> image | None ->
    let node = lowered.plan.nodes.(id - 1) in
    let args = List.map (fun (k, v) -> k, get (E.force ~state v ~live)) node.args in
    let int name fallback = match List.assoc_opt name args with Some (E.Int n) -> n | _ -> fallback in
    let width = int "width" 256 and height = int "height" 256 in
    let fn = match List.assoc "function" args with E.Fn fn -> fn | _ -> fail "Image needs a pixel function." in
    let kernel = get (Flow_sop.Image_kernel.prepare ~identity:0 ~width ~height ~fn ~sources:[] []) in
    let rgba = match gpu, pipelines with
      | Some gpu, Some pipelines ->
          let ir = Flow_ir.Executor.graph (Flow_sop.Image_kernel.program kernel) in
          let packed = match ir.nodes.(ir.roots.(0)).kind with
            | Flow_ir.Kernel {body=Packed_map p; _} -> p | _ -> fail "Image has no packed kernel." in
          let run = Flow_gpu.Run.create gpu pipelines (get (Flow_gpu.Emit.kernel packed)) in
          let sink = get (Flow_gpu.Image_sink.create gpu) in
          Fun.protect ~finally:(fun () -> Flow_gpu.Image_sink.close sink; Flow_gpu.Run.close run) (fun () ->
            let inputs = get (Flow_ir.Packed.Private.prepare ~state packed ~live) in
            let output = get (Flow_gpu.Run.dispatch run inputs) in
            let image = get (Flow_gpu.Image_sink.convert sink ~width ~height output) in
            match Ogpu.Backend.read_texture (Option.get (Flow_gpu.Image_sink.texture image)) ~bytes_per_row:(width * 4) with
            | Ok b -> b | Error e -> fail (Ogpu.Error.to_string e))
      | _ ->
          let context = match Sop.Context.create ~input:live () with Ok c -> c | Error e -> fail e in
          let cooked = match Sop.Node.Private.cook (Flow_sop.Image_kernel.node ~state kernel) context [||] with
            | Ok c -> c | Error d -> fail d.Sop.Diagnostic.message in
          let pixels = match Sop.Payload.image cooked.payload with Ok p -> p | Error d -> fail d.Sop.Diagnostic.message in
          Option.get (Sop.Image.Private.rgba8 pixels) in
    let image = match Rays.Image.upload_rgba ~width ~height ~rgba () with Ok i -> i | Error e -> fail e in
    Hashtbl.add images id image; image in
  let scene = match Marks_scene.scene ~buffers ~image:resolve marks with Ok s -> s | Error d -> fail (Flow.Diagnostic.to_string d) in
  let canvas = Rays.Canvas.create_exn ~width ~height in
  Rays.Canvas.render canvas scene;
  (match Rays.Canvas.save_png canvas output with Ok () -> () | Error e -> fail e);
  Rays.Canvas.destroy canvas;
  Hashtbl.iter (fun _ image -> Rays.Image.destroy image) images;
  Option.iter Flow_gpu.Pipelines.close pipelines;
  Option.iter Rays_execution.release_gpu gpu
