(* Scalar rows by default; `kernels` times packed kernels, `attributes` fused against separate mark attributes (the core-region switch is gone: compare against commit 035c1506^).
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

(* Attribute fusion: one two-output region against the two kernels it replaces. *)
let attributes () =
  let n = 1_000_000 in
  let ws = match Flow.Workspace.check catalog (ok (Flow.Syntax.parse (Printf.sprintf
    "(workspace w (graph g :context draw (let* [p (map (fn [i] [(* i t) (sin (+ i t)) 0]) (array/range %d))
      c (map (fn [i] [(sin t) (/ i %d) (cos (* i t))]) (array/range %d))] (draw/circles p :fill c))))" n n n))) with
    | Some ws, [] -> ws | _ -> failwith "graph does not check" in
  let evaluated = ok (E.static ~record:true ws) in
  let record name = match List.assoc ["g"; name] evaluated.records |> List.hd |> snd with
    | E.Residual r -> r | _ -> failwith "attribute did not defer" in
  let compile r = Option.get (I.Packed.compile r (E.Private.residual_view r).term) in
  let separate = [compile (record "p"); compile (record "c")] in
  let graph = ok (I.optimize (I.of_evaluation ws catalog evaluated)) in
  let set = Array.to_list graph.nodes |> List.find (fun (n : I.node) -> match n.kind with I.Marks _ -> true | _ -> false) in
  let fused = match I.attribute_edges graph set with
    | [(_, i); (_, j)] when i = j -> (match graph.nodes.(i).kind with
        | I.Kernel {body = I.Packed_map p; _} -> p | _ -> failwith "no region")
    | _ -> failwith "attributes were not fused" in
  Printf.printf "Attribute fusion at %d; median of 3 samples, milliseconds per frame\n" n;
  List.iter (fun domains ->
    let time f = Rays_math.Parallel.run ~domains (fun () -> time_median ~repeat:5 f) *. 1e3 in
    let sep = time (fun () -> List.iter (fun p -> ignore (ok (I.Packed.force p ~live))) separate)
    and fus = time (fun () -> ignore (ok (I.Packed.force_all fused ~live))) in
    Printf.printf "domains %d  separate %.3f  fused %.3f  (%.2fx)\n%!" domains sep fus (sep /. fus)) [1; 8]

(* Whole-frame core execution without a window or renderer; unchanged authored workspace. *)
let frames ?(fused=true) path =
  let source = ok (Flow.Syntax.parse (In_channel.with_open_bin path In_channel.input_all)) in
  let source = List.map (fun (form : Flow.Syntax.t) -> match form.node with
    | List (head :: name :: declarations) ->
        let declarations = List.filter (fun (declaration : Flow.Syntax.t) -> match declaration.node with
          | List (_ :: _ :: {node=Kw "context";_} :: {node=Sym ("editor"|"settings");_} :: _) -> false
          | _ -> true) declarations in
        {form with node=List (head :: name :: declarations)}
    | _ -> form) source in
  let ws = match Flow.Workspace.check ~ops:I.Operators.all catalog source with
    | Some ws, [] -> ws
    | _, ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds)) in
  let evaluation = ok (E.static ws) in
  let program, root = match I.Core_draw.lower evaluation.plan (snd (List.hd evaluation.results)) with
    | Ok p -> p | Error name -> failwith name in
  if Sys.getenv_opt "RAYS_BENCH_PRINT_CORE" = Some "1" then Format.printf "%a%!" I.Core.pp program;
  let prepared=I.Core_exec.prepare ~fused program in
  let sample () =
    let state=E.create_state () and buffers=I.Core_exec.Buffers.create () in
    let step i =
      let live={(Frame_input.at_time (float i /. 60.)) with dt=1. /. 60.; frame=i; tick=i; size=800,600} in
      I.Core_exec.Buffers.clear buffers;
      let drawn=ref None in
      (match root with
       | None -> drawn:=Some (I.Core_exec.draw prepared ~live ~size:live.size ~buffers)
       | Some root ->
           let execute r live =
             drawn:=Some (I.Core_exec.draw ~root:r prepared ~live ~size:live.size ~buffers);
             Some (Ok (E.Int 0)) in
           ignore (ok (E.Private.force_with_executor ~state ~execute (E.Residual root) ~live)));
      ignore (ok (Option.get !drawn)) in
    step 0;
    Gc.full_major ();
    let bytes=Gc.allocated_bytes () and start=Unix.gettimeofday () in
    for i=1 to 600 do step i done;
    (Unix.gettimeofday () -. start) /. 600., (Gc.allocated_bytes () -. bytes) /. 600. in
  let samples=Array.init 3 (fun _ -> sample ()) in
  Printf.printf "Core frame %s; blocks %b; 600 frames per sample, 800x600, domains 1; median of 3\n%.3f ms/frame %.0f allocated bytes/frame\n%!"
    path fused (median (Array.map fst samples) *. 1e3) (median (Array.map snd samples))

let () = match Sys.argv with
  | [|_; "frames"; path|] -> frames path
  | [|_; "frames"; path; "--boxed"|] -> frames ~fused:false path
  | [|_; "kernels"|] -> kernels ()
  | [|_; "attributes"|] -> attributes ()
  | _ -> scalar ()
