(* Registrations run at link time in no fixed order relative to this module,
   so the work is deferred to at_exit. See port_gate.ml for usage. *)
let nodes_dir () =
  (* Prefer the source tree so a pending draft is read without a rebuild:
     <root>/_build/default/lib/flow_sop/port_tests/main.exe. *)
  let exe = Filename.dirname Sys.executable_name in
  let source = Filename.concat exe "../../../../../lib/flow_sop/nodes" in
  if Sys.file_exists source then source else Filename.concat exe "../nodes"

let main () =
  let dir = nodes_dir () in
  let args = List.tl (Array.to_list Sys.argv) in
  let bench = List.mem "--bench" args in
  let all = Port_gate.registered () in
  let selected = match List.filter (fun a -> a <> "--bench") args with
    | [] -> List.filter (fun (n : Port_gate.t) -> Sys.file_exists (Filename.concat dir (n.key ^ ".rays"))) all
    | key :: _ -> (match List.filter (fun (n : Port_gate.t) -> n.key = key) all with
        | [] -> Printf.eprintf "FAIL: no port registered for %S (registered: %s)\n" key
                  (String.concat " " (List.map (fun (n : Port_gate.t) -> n.key) all)); exit 2
        | l -> l) in
  if bench then print_endline "| key | domains | native s | lisp s | ratio |\n|---|---|---|---|---|";
  let failed = List.filter (fun (n : Port_gate.t) ->
    try if bench then not (Port_gate.run_bench ~dir n) else (Port_gate.run_gate ~dir n; false)
    with Failure m -> Printf.printf "FAIL %s\n%!" m; true
       | e -> Printf.printf "FAIL %s: exception %s\n%!" n.key (Printexc.to_string e); true) selected in
  if bench && failed <> [] then print_endline "SPEED GATE FAILED";
  if failed <> [] then (Printf.eprintf "port gate failed: %s\n" (String.concat " " (List.map (fun (n : Port_gate.t) -> n.key) failed)); exit 1)

let () = at_exit (fun () -> if Array.length Sys.argv >= 0 then main ())
