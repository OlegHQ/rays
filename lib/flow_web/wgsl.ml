module P = Flow_ir.Packed
type kind = Uniform_buffer | Storage_read | Storage_read_write
type binding = {group : int; binding : int; kind : kind}
type wgsl = {source : string; entry : string; interface : binding list;
  uniform_layout : (string * int * int) list; uniform_bytes : int;
  table_seeds : int array; output_widths : int array; input_widths : int array}
let finite = {|fn wfinite(x: f32) -> bool { return (bitcast<u32>(x) & 0x7f800000u) != 0x7f800000u; }
|}
let power = {|fn wpow(a: f32, b: f32) -> f32 {
  let x = abs(a);
  if (x == 0.0) {
    if (b == 0.0) { return 1.0; }
    if (b > 0.0) { return 0.0; }
    let infinity = 0x7f800000u;
    return bitcast<f32>(infinity);
  }
  return pow(x, b);
}
|}
let perlin = {|fn wfade(t: f32) -> f32 { return t * t * t * (t * (t * 6.0 - 15.0) + 10.0); }
fn wblend(a: f32, b: f32, t: f32) -> f32 { return a + t * (b - a); }
fn wgrad(hash: i32, x: f32, y: f32, z: f32) -> f32 {
  let h = hash & 15;
  let u = select(y, x, h < 8);
  let v = select(select(z, x, h == 12 || h == 14), y, h < 4);
  return select(-u, u, (h & 1) == 0) + select(-v, v, (h & 2) == 0);
}
fn wnoise(p: vec3<f32>, o: i32) -> f32 {
  if (!(wfinite(p.x) && wfinite(p.y) && wfinite(p.z))) {
    let nan = 0x7fc00000u;
    return bitcast<f32>(nan);
  }
  let base = floor(p);
  let q = p - base;
  let f = vec3<f32>(wfade(q.x), wfade(q.y), wfade(q.z));
  let x = i32(base.x % 256.0) & 255;
  let y = i32(base.y % 256.0) & 255;
  let z = i32(base.z % 256.0) & 255;
  let a = table[o + x] + y;
  let b = table[o + x + 1] + y;
  let aa = table[o + a] + z;
  let ab = table[o + a + 1] + z;
  let ba = table[o + b] + z;
  let bb = table[o + b + 1] + z;
  let x00 = wblend(wgrad(table[o + aa], q.x, q.y, q.z), wgrad(table[o + ba], q.x - 1.0, q.y, q.z), f.x);
  let x10 = wblend(wgrad(table[o + ab], q.x, q.y - 1.0, q.z), wgrad(table[o + bb], q.x - 1.0, q.y - 1.0, q.z), f.x);
  let x01 = wblend(wgrad(table[o + aa + 1], q.x, q.y, q.z - 1.0), wgrad(table[o + ba + 1], q.x - 1.0, q.y, q.z - 1.0), f.x);
  let x11 = wblend(wgrad(table[o + ab + 1], q.x, q.y - 1.0, q.z - 1.0), wgrad(table[o + bb + 1], q.x - 1.0, q.y - 1.0, q.z - 1.0), f.x);
  return clamp((wblend(wblend(x00, x10, f.y), wblend(x01, x11, f.y), f.z) + 1.0) * 0.5, 0.0, 1.0);
}
fn wfbm(p: vec3<f32>, octaves: i32, o: i32) -> f32 {
  var frequency: f32 = 1.0;
  var amplitude: f32 = 1.0;
  var sum: f32 = 0.0;
  var weights: f32 = 0.0;
  for (var octave: i32 = 0; octave < octaves; octave++) {
    sum += wnoise(p * frequency, o) * amplitude;
    weights += amplitude;
    frequency *= 2.0;
    amplitude *= 0.5;
  }
  return select(sum / weights, 0.0, weights == 0.0);
}
|}
exception Unsupported of string
let fail message = raise (Unsupported message)
let register index = "r" ^ string_of_int index
let truth condition = "select(0.0, 1.0, " ^ condition ^ ")"
let binary operation a b =
  let infix operator = truth ("(" ^ a ^ operator ^ b ^ ")") in
  match operation with
  | P.Add -> "(" ^ a ^ " + " ^ b ^ ")" | Sub -> "(" ^ a ^ " - " ^ b ^ ")" | Mul -> "(" ^ a ^ " * " ^ b ^ ")"
  | Div -> "select(" ^ a ^ " / " ^ b ^ ", 0.0, " ^ b ^ " == 0.0)"
  | Mod -> "select(((" ^ a ^ " % " ^ b ^ ") + " ^ b ^ ") % " ^ b ^ ", 0.0, " ^ b ^ " == 0.0)"
  | Pow -> "wpow(" ^ a ^ ", " ^ b ^ ")"
  | Min -> "min(" ^ a ^ ", " ^ b ^ ")" | Max -> "max(" ^ a ^ ", " ^ b ^ ")"
  | Lt -> infix " < " | Le -> infix " <= " | Gt -> infix " > " | Ge -> infix " >= " | Eq -> infix " == "
  | And -> truth ("(" ^ a ^ " != 0.0 && " ^ b ^ " != 0.0)")
  | Or -> truth ("(" ^ a ^ " != 0.0 || " ^ b ^ " != 0.0)")
let unary operation a = match operation with
  | P.Sin -> "sin(" ^ a ^ ")" | Cos -> "cos(" ^ a ^ ")"
  | Sqrt -> "sqrt(abs(" ^ a ^ "))" | Abs -> "abs(" ^ a ^ ")" | Not -> truth ("(" ^ a ^ " == 0.0)")
let kernel program = try
  let view = P.Private.view program in
  (match P.gpu_refusals program with [] -> () | reason :: _ -> fail reason.message);
  let offset = ref 4 and uniform_layout = ref [] in
  let uniform name width =
    let first = !offset in offset := first+width*4;
    uniform_layout := (name,first,width) :: !uniform_layout; first/4 in
  let uniforms = Array.mapi (fun index width -> uniform ("uniform:" ^ string_of_int index) width) view.uniform_widths in
  let frames = Array.mapi (fun index -> function
    | P.Frame name -> uniform (Printf.sprintf "frame:%d:%s" index name) 1 | _ -> 0) view.code in
  let used = P.Private.output_reachable program in
  let word index = Printf.sprintf "uniforms[%d].%c" (index/4) "xyzw".[index mod 4] in
  let has operation = Array.exists Fun.id (Array.mapi (fun slot instruction -> used.(slot) && operation instruction) view.code) in
  let table_seeds = Array.to_list(Array.mapi(fun index instruction->index,instruction)view.code)
    |> List.filter_map (function
      | index,P.Noise3 (_,_,_,seed,_) when used.(index) -> Some seed | _ -> None)
    |> List.sort_uniq Int.compare |> Array.of_list in
  let table seed = match Array.find_index ((=) seed) table_seeds with Some index -> index*512 | None -> assert false in
  let body = Buffer.create 4096 in
  Array.iteri (fun slot instruction ->
    if used.(slot) then begin
    let expression = match instruction with
      | P.Const value -> Printf.sprintf "bitcast<f32>(0x%lxu)" (Int32.bits_of_float value)
      | Input (input,width,component) -> Printf.sprintf "input%d[i * %du + %du]" input width component
      | Uniform (index,component) -> Printf.sprintf "bitcast<f32>(%s)" (word (uniforms.(index)+component))
      | Frame _ -> Printf.sprintf "bitcast<f32>(%s)" (word frames.(slot))
      | Accumulator _ -> assert false
      | Binary (op,a,b) -> binary op (register a) (register b)
      | Unary (op,a) -> unary op (register a)
      | Select (condition,yes,no) -> Printf.sprintf "select(%s, %s, %s != 0.0)" (register no) (register yes) (register condition)
      | Noise3 (x,y,z,seed,octaves) -> Printf.sprintf "wfbm(vec3<f32>(%s, %s, %s), %d, %d)"
          (register x) (register y) (register z) octaves (table seed) in
    Printf.bprintf body "  let r%d: f32 = %s;\n" slot expression;
    Printf.bprintf body "  if (!wfinite(r%d)) { atomicStore(&status, 1u); }\n" slot
    end) view.code;
  let outputs = Array.length view.outputs in
  let output_name k = if outputs = 1 then "outbuf" else "outbuf" ^ string_of_int k in
  Array.iteri (fun k registers -> Array.iteri (fun component slot ->
    Printf.bprintf body "  %s[i * %du + %du] = r%d;\n"
      (output_name k) (Array.length registers) component slot) registers) view.outputs;
  let count = Array.length view.widths in
  let input_used=Array.make count false in
  Array.iteri(fun slot->function P.Input(input,_,_)when used.(slot)->input_used.(input)<-true|_->())view.code;
  let uniform_words = (!offset + 15) / 16 in
  let declarations = Buffer.create 512 in
  let declare binding kind decl =
    Printf.bprintf declarations "@group(0) @binding(%d) var%s: %s;\n" binding
      (match kind with Uniform_buffer -> "<uniform>" | Storage_read -> "<storage, read>"
       | Storage_read_write -> "<storage, read_write>") decl in
  let interface = ref [] in
  let bind binding kind decl = interface := {group=0;binding;kind} :: !interface; declare binding kind decl in
  Array.iteri (fun index used -> if used then bind index Storage_read (Printf.sprintf "input%d: array<f32>" index)) input_used;
  for k = 0 to outputs-1 do bind (count+k) Storage_read_write (output_name k ^ ": array<f32>") done;
  bind (count+outputs) Uniform_buffer (Printf.sprintf "uniforms: array<vec4<u32>, %d>" uniform_words);
  bind (count+outputs+1) Storage_read_write "status: atomic<u32>";
  if table_seeds <> [||] then bind (count+outputs+2) Storage_read "table: array<i32>";
  let prefix = Buffer.contents declarations ^ finite
    ^ (if has (function P.Binary (P.Pow,_,_) -> true | _ -> false) then power else "")
    ^ (if table_seeds=[||] then "" else perlin) in
  let signature = "(@builtin(global_invocation_id) gid: vec3<u32>)" in
  let body = "  let i = gid.x;\n  if (i >= uniforms[0].x) { return; }\n" ^ Buffer.contents body in
  let entry = "kernel_" ^ Digest.to_hex (Digest.string (prefix ^ signature ^ body)) in
  let source = prefix ^ "@compute @workgroup_size(64)\nfn " ^ entry ^ signature ^ " {\n" ^ body ^ "}\n" in
  Ok {source;entry;interface=List.rev !interface;uniform_layout=List.rev !uniform_layout;
    uniform_bytes=uniform_words*16;table_seeds;
    output_widths=Array.map Array.length view.outputs;input_widths=view.widths}
with Unsupported message -> Error (Flow.Diagnostic.error ~code:"E_GPU_FORM" message)
