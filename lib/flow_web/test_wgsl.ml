(* Goldens for the WGSL printer. Regenerate with [test_wgsl.exe --write-goldens]
   from lib/flow_web. [test_wgsl.exe --write-kernel-table DIR] writes DIR/kernels.json, the kernel table
   tools/web/runtime/gpu.js loads (format: its header); tools/web/test/gpu_check.mjs compiles the goldens for
   real in Chrome (plan P6.3, alias qualification-web). *)
let json_string s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter (function
    | '"' -> Buffer.add_string b "\\\"" | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n"
    | c when Char.code c < 32 || Char.code c > 126 -> Printf.bprintf b "\\u%04x" (Char.code c)
    | c -> Buffer.add_char b c) s;
  Buffer.add_char b '"'; Buffer.contents b
let json_list f items = "[" ^ String.concat "," (List.map f items) ^ "]"
let json_ints a = json_list string_of_int (Array.to_list a)
let kind_name = function
  | Flow_web.Wgsl.Uniform_buffer -> "uniform" | Storage_read -> "read" | Storage_read_write -> "read_write"
(* The noise tables are the ones the Metal host uploads (lib/flow_gpu/run.ml): 512 entries per seed. *)
let table_json (w : Flow_web.Wgsl.wgsl) =
  json_list (fun seed -> json_ints (Rays_math.Noise.Private.permutation (Rays_math.Noise.create seed)))
    (Array.to_list w.table_seeds)
let kernel_json ?(cpu = "") name (w : Flow_web.Wgsl.wgsl) =
  Printf.sprintf
    "{\"id\":%s,\"cpu\":%s,\"entry\":%s,\"source\":%s,\"interface\":%s,\"uniform_layout\":%s,\"uniform_bytes\":%d,\"table_seeds\":%s,\"tables\":%s,\"input_widths\":%s,\"output_widths\":%s}"
    (json_string name) (json_string cpu) (json_string w.entry) (json_string w.source)
    (json_list (fun (b : Flow_web.Wgsl.binding) -> Printf.sprintf "{\"group\":%d,\"binding\":%d,\"kind\":%s}" b.group b.binding (json_string (kind_name b.kind))) w.interface)
    (json_list (fun (n, o, width) -> Printf.sprintf "[%s,%d,%d]" (json_string n) o width) w.uniform_layout)
    w.uniform_bytes (json_ints w.table_seeds) (table_json w) (json_ints w.input_widths) (json_ints w.output_widths)

let () =
  let program=Test_program.compile
    "(map (fn [x] (if (> x t) (+ x 1.0) (exp (* x 1000.0)))) (array/range 16))"in
  let view=Flow_ir.Packed.Private.view program in
  let wgsl=Test_program.ok(Flow_web.Wgsl.kernel program)in
  let lines=String.split_on_char '\n' wgsl.source in
  let guarded=ref false in
  Array.iteri(fun slot->function
    |Flow_ir.Packed.Guarded(guards,Flow_ir.Packed.Unary(Exp,_))->
        guarded:=true;assert(guards<>[]);
        let assignment=Printf.sprintf "    r%d ="slot in
        let rec check=function
          |line::next::_ when String.starts_with ~prefix:assignment line->
              assert(next=Printf.sprintf "    if (!wfinite(r%d)) { atomicStore(&status, 1u); }"slot)
          |_::rest->check rest|[]->assert false in check lines
    |_->())view.code;
  assert !guarded;
  let nested=Test_program.compile
    "(map (fn [x] (if (> x t) (noise3 [(pow (+ x t) 2.0) t 0.0] :seed 31) (+ x t))) (array/range 16))"in
  let nested=Test_program.ok(Flow_web.Wgsl.kernel nested)in
  assert(nested.table_seeds=[|31|]);
  assert(List.exists(String.starts_with ~prefix:"fn wpow") (String.split_on_char '\n' nested.source));
  List.iter(fun source->
    let program=try Test_program.compile source with Invalid_argument message->failwith(source^": "^message)in
    match Flow_web.Wgsl.kernel program with Error d->assert(d.code="E_GPU_FORM")|Ok _->assert false)
    ["(map (fn [x] (+ (float x) t)) (array/range 16 :type \"int\"))";
     "(let* [offset (frame/index)] (map (fn [x] (+ x (float offset))) (array/range 16)))"]

let () =
  List.iter (fun body ->
    let program = Test_program.compile
      ("(map (fn [x] " ^ body ^ ") (array/range 1024))") in
    ignore (Test_program.ok (Flow_web.Wgsl.kernel program)))
    ["(tan (+ (* x 0.0001) t))"; "(atan2 x t)";
     "(asin (* (+ x t) 0.0001))"; "(acos (* (+ x t) 0.0001))";
     "(exp (* (+ x t) 0.0001))"; "(log (+ (+ x t) 1.0))"; "(sign (- x t))"];
  let hypot = Test_program.compile
    "(map (fn [x] (hypot x t)) (array/range 1024))" in
  (match Flow_web.Wgsl.kernel hypot with
   | Error d -> assert (d.code = "E_GPU_FORM")
   | Ok _ -> failwith "WGSL must refuse unsupported native-safe hypot");
  let writing = Array.to_list Sys.argv = [Sys.argv.(0); "--write-goldens"] in
  let programs = Test_program.fixtures 1024 @ ["two_outputs", Test_program.two_outputs ()] in
  (match Array.to_list Sys.argv with
   | [_; "--write-kernel-table"; dir] ->
       (* "ops" is not a golden: it only gives the browser check the operators the four fixtures never reach
          (mod, pow, division and sqrt guards, comparisons, and/or/not, min/max, sin/cos); "cpu" is its region. *)
       let ops = Test_program.compile "(map (fn [x] (+ (+ (+ (mod x 7.) (pow (abs (- x 40.)) 0.5)) (/ x (- x 3.)))
         (+ (+ (sqrt x) (min x t)) (+ (max (sin x) (cos t)) (+ (if (and (> x 3.) (not (>= x 90.))) 1. 0.) (if (or (<= x 2.) (= x 5.)) 2. 0.))))))
         (array/range 1024))" in
       let kernels = List.map (fun (name, program) -> kernel_json name (Test_program.ok (Flow_web.Wgsl.kernel program))) programs
         @ [kernel_json ~cpu:(Flow_web.Js.region ops) "ops" (Test_program.ok (Flow_web.Wgsl.kernel ops))]
         @ List.map (fun (name, body) ->
           let program = Test_program.compile ("(map (fn [x] " ^ body ^ ") (array/range 1024))") in
           kernel_json name (Test_program.ok (Flow_web.Wgsl.kernel program)))
           ["hidden_select", "(if (> x t) 0.0 (* x x))";
            "hidden_min", "(min (* x x) (+ t 1.0))";
            "safe", "(if (> x t) (sqrt (abs x)) (max (min x 1.0) 0.0))"] in
       Out_channel.with_open_bin (Filename.concat dir "kernels.json") (fun c ->
         output_string c ("{\"kernels\":[" ^ String.concat ",\n" kernels ^ "]}\n"));
       exit 0
   | _ -> ());
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
    programs;
  List.iter (fun source ->
    let program = Test_program.compile source in
    match Flow_ir.Packed.gpu_refusals program, Flow_web.Wgsl.kernel program with
    | reason :: _, Error emitted -> assert (reason.code = emitted.code && reason.message = emitted.message)
    | _ -> assert false)
    ["(sum [x (array/range 1024)] (+ x t))";
     "(map (fn [x] (cross [x t 0] [1 2 3])) (array/range 1024))";
     "(for [x (array/range 1024)] :skip [0] (+ x t))"];
  let pixels = List.assoc "vec4" (Test_program.vector_fixtures 1) in
  let image = Test_program.ok (Flow_web.Wgsl.kernel ~image:true pixels) in
  assert (image.input_widths = [||] && image.output_widths = [|4|]);
  assert (List.map (fun (b : Flow_web.Wgsl.binding) -> b.binding) image.interface = [0; 1; 2]);
  assert (List.exists (fun (name, _, _) -> name = "image:width") image.uniform_layout);
  assert (List.exists (fun (name, _, _) -> name = "image:height") image.uniform_layout);
  assert (Result.is_error (Flow_web.Wgsl.kernel ~image:true (snd (List.hd programs))));
  let hidden = Test_program.compile
    "(map (fn [x] (if (> x t) 0.0 (min (* x x) 1.0))) (array/range 1024))" in
  let source = (Test_program.ok (Flow_web.Wgsl.kernel hidden)).source in
  let lines = String.split_on_char '\n' source in
  let checks = Flow_ir.Packed.Private.finite_checks hidden in
  List.iteri (fun index line -> if String.starts_with ~prefix:"  let r" line then
    let slot = Scanf.sscanf line "  let r%d:" Fun.id in
    let guard = Printf.sprintf "  if (!wfinite(r%d)) { atomicStore(&status, 1u); }" slot in
    assert ((List.nth lines (index + 1) = guard) = checks.(slot))) lines;
  print_endline "WGSL printer: goldens and shared refusals passed"
