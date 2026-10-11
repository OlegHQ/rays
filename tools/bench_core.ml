(* One scalar residual evaluated by the tree walker and the core executor. Median of three samples per row, one domain. *)
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
  let rows = List.map (fun (label, force) ->
    (match force (), reference with
     | Ok (E.Float a), Ok (E.Float b) when Int64.bits_of_float a = Int64.bits_of_float b -> ()
     | _ -> failwith (label ^ ": result differs from the reference walker"));
    let seconds, bytes = measure force in
    label, seconds, bytes) [
      "tree walker", (fun () -> E.Private.force_reference value ~live);
      "core", (fun () -> I.Executor.force program ~live) ] in
  Printf.printf "Scalar residual %s; %d evaluations per sample; domains 1; median of 3 samples\n"
    body iterations;
  List.iter (fun (label, seconds, bytes) ->
    Printf.printf "%-12s %12.1f ns/eval %10.1f allocated bytes/eval\n" label (seconds *. 1e9) bytes) rows;
  match rows with
  | [_, walker, _; _, core, _] -> Printf.printf "walker/core ratio %.2f\n" (walker /. core)
  | _ -> ()
