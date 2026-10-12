(* Instruction-level snapshots of every packed program a test compiles. *)
module P = Flow_ir.Packed
let buffer = Buffer.create 4096

let rec instruction : P.instruction -> string = function
  | Const x -> Printf.sprintf "Const %h" x
  | Input (i, w, c) -> Printf.sprintf "Input %d %d %d" i w c
  | Uniform (i, c) -> Printf.sprintf "Uniform %d %d" i c
  | Frame name -> Printf.sprintf "Frame %S" name
  | Accumulator c -> Printf.sprintf "Accumulator %d" c
  | Binary (op, a, b) -> Printf.sprintf "Binary %s %d %d" (Flow.Packed_ops.(match op with
      | Add -> "Add" | Sub -> "Sub" | Mul -> "Mul" | Div -> "Div" | Mod -> "Mod" | Pow -> "Pow"
      | Min -> "Min" | Max -> "Max" | Lt -> "Lt" | Le -> "Le" | Gt -> "Gt" | Ge -> "Ge"
      | Eq -> "Eq" | And -> "And" | Or -> "Or" | Atan2->"Atan2" | Hypot->"Hypot")) a b
  | Unary (op, a) -> Printf.sprintf "Unary %s %d" (Flow.Packed_ops.(match op with
      | Sin -> "Sin" | Cos -> "Cos" | Sqrt -> "Sqrt" | Abs -> "Abs" | Not -> "Not"
      |Tan->"Tan"|Asin->"Asin"|Acos->"Acos"|Exp->"Exp"|Log->"Log"|Sign->"Sign")) a
  | Noise3 (x, y, z, seed, octaves) -> Printf.sprintf "Noise3 %d %d %d seed=%d octaves=%d" x y z seed octaves
  | Select (c, a, b) -> Printf.sprintf "Select %d %d %d" c a b
  | Int_const n->Printf.sprintf "Int_const %d" n
  | Int_input n->Printf.sprintf "Int_input %d" n | Int_uniform n->Printf.sprintf "Int_uniform %d" n
  | Int_accumulator->"Int_accumulator"
  | Int_frame name->Printf.sprintf "Int_frame %S" name
  | Int_binary(op,a,b)->Printf.sprintf "Int_binary %s %d %d" (Flow.Packed_ops.integer_name op) a b
  | Int_compare(op,a,b)->Printf.sprintf "Int_compare %s %d %d" (Flow.Packed_ops.comparison_name op) a b
  | Int_abs a->Printf.sprintf "Int_abs %d" a
  | Int_select(c,a,b)->Printf.sprintf "Int_select %d %d %d" c a b
  | Convert(op,a)->Printf.sprintf "Convert %s %d" (match op with To_float->"float"|Truncate->"int"|Floor->"floor"|Ceil->"ceil"|Round->"round"|Coerce_int->"coerce:int"|Integer_result n->"int-result:"^n) a
  | Guarded(guards,body)->Printf.sprintf "Guarded %s (%s)" (String.concat ";" (List.map(fun(r,b)->Printf.sprintf "%d:%b" r b)guards))(instruction body)
  | Raise(ty,code,message)->Printf.sprintf "Raise %s %S %S"(Flow.Ty.to_string ty)code message

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
      add "  widths %s\n%s  uniform_widths %s\n  collecting %b\n"
        (ints view.widths)
        (String.concat "" (Array.to_list (Array.map (fun o -> "  output " ^ ints o ^ "\n") view.outputs)))
        (ints view.uniform_widths) view.collecting;
      List.iter (fun (d : Flow.Diagnostic.t) -> add "  gpu_refusal %s %S\n" d.code d.message)
        (P.gpu_refusals packed);
      add "\n");
  let text = Buffer.contents entry in
  if not (Hashtbl.mem seen text) then (Hashtbl.add seen text (); Buffer.add_string buffer text)

let start () =
  Buffer.clear buffer; Hashtbl.reset seen; P.Private.trace := record

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
