(* One scalar residual evaluated by the tree walker, the closure tier and the
   core executor. Median of three samples per row, one domain. *)
module E = Flow.Eval
module I = Flow_ir

let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let catalog = { Flow.Check.version = 0; kinds = [] }
let body = "(+ (* (sin t) 0.5) (* t t))"
let iterations = 200_000
let live = Frame_input.at_time 0.37

let check source = match Flow.Workspace.check catalog (ok (Flow.Syntax.parse source)) with
  | Some ws, ds when not (List.exists (fun (d : Flow.Diagnostic.t) -> d.severity = Error) ds) -> ws
  | _, ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds))

let with_switches ~compile ~core f =
  let old_compile = !(E.Private.compile_residuals) and old_core = !(E.Private.core_residuals) in
  Fun.protect ~finally:(fun () ->
    E.Private.compile_residuals := old_compile; E.Private.core_residuals := old_core)
    (fun () -> E.Private.compile_residuals := compile; E.Private.core_residuals := core; f ())

let median values =
  let sorted = Array.copy values in
  Array.sort Float.compare sorted;
  sorted.(Array.length sorted / 2)

let measure force =
  let sample () =
    Gc.full_major ();
    let bytes = Gc.allocated_bytes () and start = Unix.gettimeofday () in
    for _ = 1 to iterations do ignore (force ()) done;
    (Unix.gettimeofday () -. start) /. float iterations,
    (Gc.allocated_bytes () -. bytes) /. float iterations in
  let samples = Array.init 3 (fun _ -> sample ()) in
  median (Array.map fst samples), median (Array.map snd samples)

let () =
  let value = List.assoc "g" (ok (E.static (check ("(workspace w (graph g :context value " ^ body ^ "))")))).results in
  let program = ok (I.Executor.compile value) in
  let reference = E.Private.force_reference value ~live in
  let rows = List.map (fun (label, compile, core) -> with_switches ~compile ~core (fun () ->
    let force () = I.Executor.force program ~live in
    (match force (), reference with
     | Ok (E.Float a), Ok (E.Float b) when Int64.bits_of_float a = Int64.bits_of_float b -> ()
     | _ -> failwith (label ^ ": result differs from the reference walker"));
    let seconds, bytes = measure force in
    label, seconds, bytes)) [
      "tree walker", false, false;
      "closure tier", true, false;
      "core", true, true ] in
  Printf.printf "Scalar residual %s; %d evaluations per sample; domains 1; median of 3 samples\n"
    body iterations;
  List.iter (fun (label, seconds, bytes) ->
    Printf.printf "%-12s %12.1f ns/eval %10.1f allocated bytes/eval\n" label (seconds *. 1e9) bytes) rows;
  match rows with
  | [_, walker, _; _, closure, _; _, core, _] ->
      Printf.printf "core/closure ratio %.2f (walker/closure %.2f)\n" (core /. closure) (walker /. closure)
  | _ -> ()
