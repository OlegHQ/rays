(* Prints web_runtime.ml: the files of tools/web/runtime embedded as OCaml strings, sorted by name, so the
   installed rays-lisp needs no source tree.  Usage: embed.exe FILE... *)
let () =
  let files = List.sort compare (List.tl (Array.to_list Sys.argv)) in
  print_string "let files = [\n";
  List.iter (fun f -> Printf.printf "  %S, %S;\n" (Filename.basename f) (In_channel.with_open_bin f In_channel.input_all)) files;
  print_string "]\n"
