(* Scalar rows by default; `kernels` times packed kernels (the core-region switch is gone: compare against commit 035c1506^).
   One scalar residual evaluated by the tree walker and the core executor. Median of three samples per row, one domain. *)
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

let scalar () =
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

(* Packed kernels: compile cost (microseconds) and force time per call, switch off and on, 1 and 8 domains. *)
let kernel_residual body =
  let ws = Flow.Workspace.check ~ops:I.Operators.all catalog
      (ok (Flow.Syntax.parse ("(workspace w (graph g :context value (let* [tested " ^ body ^ "] 0.0)))"))) in
  match ws with
  | Some ws, [] ->
      (match List.assoc ["g"; "tested"] (ok (E.static ~record:true ws)).records |> List.hd |> snd with
       | E.Residual r -> r
       | _ -> failwith "kernel did not defer")
  | _ -> failwith "kernel does not check"

let time_median ~repeat f =
  let sample () =
    let start = Unix.gettimeofday () in
    for _ = 1 to repeat do f () done;
    (Unix.gettimeofday () -. start) /. float repeat in
  median (Array.init 3 (fun _ -> sample ()))

let kernels () =
  let map n = Printf.sprintf "(map (fn [x] (+ (* x 2) t)) (array/range %d))" n in
  let cases = [
    "map 1,024", map 1024, 4000;
    "map 1,000,000", map 1_000_000, 5;
    "fused maps 1,000,000", Printf.sprintf "(map (fn [y] (* y 0.5)) %s)" (map 1_000_000), 5;
    "sum 1,000,000", "(sum [x (array/range 1000000)] (* x t))", 5 ] in
  Printf.printf "Packed kernels; median of 3 samples; compile in microseconds, force in milliseconds\n";
  Printf.printf "%-22s %-6s %12s %12s\n" "case" "domains" "compile us" "force ms";
  List.iter (fun (label, body, repeat) ->
    let r = kernel_residual body in
    let term = (E.Private.residual_view r).term in
    let compile = time_median ~repeat:2000 (fun () -> ignore (I.Packed.compile r term)) in
      let packed = Option.get (I.Packed.compile r term) in
      List.iter (fun domains ->
        let force = Rays_math.Parallel.run ~domains (fun () ->
          time_median ~repeat (fun () -> ignore (ok (I.Packed.force packed ~live)))) in
        Printf.printf "%-22s %-6d %12.2f %12.3f\n%!" label domains
          (compile *. 1e6) (force *. 1e3)) [1; 8]) cases

let () = if Array.length Sys.argv > 1 && Sys.argv.(1) = "kernels" then kernels () else scalar ()
