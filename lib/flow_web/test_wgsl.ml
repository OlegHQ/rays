(* Goldens for the WGSL printer. Regenerate with [test_wgsl.exe --write-goldens]
   from lib/flow_web. No WGSL compiler runs here; see the plan ledger (P5.3). *)
let () =
  let writing = Array.to_list Sys.argv = [Sys.argv.(0); "--write-goldens"] in
  List.iter (fun (name, program) ->
    let wgsl = Test_program.ok (Flow_web.Wgsl.kernel program) in
    let path = "goldens/" ^ name ^ ".wgsl" in
    if writing then Out_channel.with_open_bin path (fun channel -> output_string channel wgsl.source)
    else assert (In_channel.with_open_bin path In_channel.input_all = wgsl.source);
    (* The numbering the matching Metal goldens use. *)
    assert (List.map (fun (b : Flow_web.Wgsl.binding) -> b.binding) wgsl.interface
      = (match name with "noise" -> [0;1;2;3;4] | "two_outputs" -> [0;1;2;3;4] | _ -> [0;1;2;3]));
    assert (wgsl.uniform_bytes mod 16 = 0);
    assert (Digest.string wgsl.source = Digest.string (Test_program.ok (Flow_web.Wgsl.kernel program)).source))
    (Test_program.fixtures 1024 @ ["two_outputs", Test_program.two_outputs ()]);
  List.iter (fun source ->
    let program = Test_program.compile source in
    match Flow_ir.Packed.gpu_refusals program, Flow_web.Wgsl.kernel program with
    | reason :: _, Error emitted -> assert (reason.code = emitted.code && reason.message = emitted.message)
    | _ -> assert false)
    ["(sum [x (array/range 1024)] (+ x t))";
     "(for [x (array/range 1024)] :skip [0] (+ x t))"];
  print_endline "WGSL printer: goldens and shared refusals passed"
