(* Pixel parity of the web export in a real browser (plan P6.8), under the alias @qualification-web.

   usage: web_shot LISP MARKS_SHOT WEB_SHOT_MJS DIR WIDTH HEIGHT FRAME...

   For each FRAME it renders the native picture of DIR/sketch.rays at that fixed-step frame (marks_shot: dt 1/60,
   pointer (100, 100)), starts the development server `rays-lisp web --watch` (127.0.0.1, cross-origin isolation
   headers), and has node drive the local Chrome (headless, WebGPU) through tools/web/test/web_shot.mjs: it loads
   the served page, steps the same fixed frames through window.__rays.stepFrame, and compares the canvas pixels
   (largest channel difference per pixel: at most 0.5% of the pixels above 8 and none above 64).

   `web_shot --time N LISP MARKS_SHOT WEB_SHOT_MJS DIR WIDTH HEIGHT` skips the native render and the comparison and
   reports timings instead (P7.3): rAF-paced frame intervals over N frames of the page's own loop, the uncapped cost
   of N hand-driven frames (stepFrame + present + queue.onSubmittedWorkDone), load time and kernel compile time.

   Exit: 0 pass or skipped (a missing node or Chrome prints why), 1 mismatch, 3 WebGPU unavailable in that Chrome,
   2 usage, 4 the page or a tool failed. *)
let chrome = Option.value (Sys.getenv_opt "CHROME") ~default:"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

let run program arguments = Sys.command (Filename.quote_command program arguments)

let () =
  let timing, argv = match Array.to_list Sys.argv with
    | program :: "--time" :: n :: rest -> Some n, program :: rest
    | argv -> None, argv in
  match argv with
  | _ :: lisp :: shot :: script :: dir :: width :: height :: frames ->
      if run "sh" ["-c"; "command -v node >/dev/null 2>&1"] <> 0 then (print_endline "web_shot: skipped (node not found)"; exit 0);
      if not (Sys.file_exists chrome) then (print_endline "web_shot: skipped (Google Chrome not found)"; exit 0);
      let tmp = Filename.temp_dir "web-shot-" "" in
      if frames = [] && timing = None then (prerr_endline "web_shot: no frames"; exit 2);
      List.iter (fun frame ->
        if run shot [dir; Filename.concat tmp ("native_" ^ frame ^ ".png"); width; height; frame] <> 0 then
          (prerr_endline "web_shot: the native render failed"; exit 4)) frames;
      let out_dir = Filename.concat tmp "out" in
      let read, write = Unix.pipe ~cloexec:true () in
      let server = Unix.create_process lisp [| lisp; "web"; "--watch"; Filename.concat dir "sketch.rays"; "-o"; out_dir; "--port"; "0" |]
          Unix.stdin write Unix.stderr in
      Unix.close write;
      let channel = Unix.in_channel_of_descr read in
      let port =
        let rec banner () = match In_channel.input_line channel with
          | None -> prerr_endline "web_shot: the development server did not start"; Unix.kill server Sys.sigterm; exit 4
          | Some line -> (try Scanf.sscanf line "serving http://127.0.0.1:%d/" Fun.id with Scanf.Scan_failure _ | End_of_file -> banner ()) in
        banner () in
      let url = Printf.sprintf "http://127.0.0.1:%d/" port in
      Printf.printf "web_shot: %s served at %s, frames %s at %sx%s\n%!" dir url (String.concat " " frames) width height;
      let code = (Option.iter (Unix.putenv "WEB_SHOT_TIME") timing; run "node" ([script; url; tmp; width; height] @ frames)) in
      Unix.kill server Sys.sigterm;
      ignore (Unix.waitpid [] server);
      (match code with
       | 0 -> print_endline "web_shot: ok"
       | 3 -> print_endline "web_shot: WebGPU is unavailable in this Chrome (exit 3)"
       | _ -> Printf.printf "web_shot: failed (exit %d); pictures kept in %s\n" code tmp);
      exit code
  | _ -> prerr_endline "usage: web_shot [--time N] LISP MARKS_SHOT WEB_SHOT_MJS DIR WIDTH HEIGHT FRAME..."; exit 2
