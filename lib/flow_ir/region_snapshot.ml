(* Instruction-level snapshots of every packed program a test compiles. *)
module P = Flow_ir.Packed
let buffer = Buffer.create 4096

let instruction : P.instruction -> string = function
  | Const x -> Printf.sprintf "Const %h" x
  | Input (i, w, c) -> Printf.sprintf "Input %d %d %d" i w c
  | Uniform (i, c) -> Printf.sprintf "Uniform %d %d" i c
  | Frame name -> Printf.sprintf "Frame %S" name
  | Accumulator c -> Printf.sprintf "Accumulator %d" c
  | Binary (op, a, b) -> Printf.sprintf "Binary %s %d %d" (Flow.Packed_ops.(match op with
      | Add -> "Add" | Sub -> "Sub" | Mul -> "Mul" | Div -> "Div" | Mod -> "Mod" | Pow -> "Pow"
      | Min -> "Min" | Max -> "Max" | Lt -> "Lt" | Le -> "Le" | Gt -> "Gt" | Ge -> "Ge"
      | Eq -> "Eq" | And -> "And" | Or -> "Or")) a b
  | Unary (op, a) -> Printf.sprintf "Unary %s %d" (Flow.Packed_ops.(match op with
      | Sin -> "Sin" | Cos -> "Cos" | Sqrt -> "Sqrt" | Abs -> "Abs" | Not -> "Not")) a
  | Noise3 (x, y, z, seed, octaves) -> Printf.sprintf "Noise3 %d %d %d seed=%d octaves=%d" x y z seed octaves
  | Select (c, a, b) -> Printf.sprintf "Select %d %d %d" c a b

let ints a = "[" ^ String.concat ";" (Array.to_list (Array.map string_of_int a)) ^ "]"

let seen = Hashtbl.create 64

let record result =
  let entry = Buffer.create 256 in
  let add format = Printf.bprintf entry format in
  (match result with
  | Error (ds : Flow.Diagnostic.t list) ->
      List.iter (fun (d : Flow.Diagnostic.t) ->
        add "refused %s%s %S\n" d.code
          (match d.span with Some s -> Printf.sprintf " %d..%d" s.start s.finish | None -> "") d.message) ds;
      add "\n"
  | Ok packed ->
      let view = P.Private.view packed in
      add "program\n";
      Array.iteri (fun i x -> add "  r%d = %s\n" i (instruction x)) view.code;
      add "  widths %s\n  output %s\n  uniform_widths %s\n  collecting %b\n"
        (ints view.widths) (ints view.output) (ints view.uniform_widths) view.collecting;
      List.iter (fun (d : Flow.Diagnostic.t) -> add "  gpu_refusal %s %S\n" d.code d.message)
        (P.gpu_refusals packed);
      add "\n");
  let text = Buffer.contents entry in
  if not (Hashtbl.mem seen text) then (Hashtbl.add seen text (); Buffer.add_string buffer text)

let start () = Buffer.clear buffer; Hashtbl.reset seen; P.Private.trace := record

let finish name =
  P.Private.trace := ignore;
  let text = Buffer.contents buffer in
  match Sys.getenv_opt "REGION_SNAPSHOT_DIR" with
  | Some dir -> Out_channel.with_open_text (Filename.concat dir (name ^ ".txt")) (fun c -> output_string c text)
  | None ->
      let expected = In_channel.with_open_text (Filename.concat "snapshots" (name ^ ".txt")) In_channel.input_all in
      if expected <> text then begin
        Out_channel.with_open_text (name ^ ".actual") (fun c -> output_string c text);
        let a = String.split_on_char '\n' expected and b = String.split_on_char '\n' text in
        let rec first n = function
          | x :: xs, y :: ys when x = y -> first (n + 1) (xs, ys)
          | x :: _, y :: _ -> Printf.sprintf "line %d: expected %S, got %S" n x y
          | _ -> Printf.sprintf "length differs at line %d" n in
        failwith ("region snapshot " ^ name ^ " differs: " ^ first 1 (a, b))
      end
