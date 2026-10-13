module P = Flow_ir.Packed
module S = Ogpu.Shader
type msl = {source : string; entry : string; interface : S.binding list;
  uniform_layout : (string * int * int) list; uniform_bytes : int;
  table_seeds : int array; output_widths : int array; input_widths : int array}
let names = Flow.Packed_ops.names
let perlin = {|float fade(float t) { return t*t*t*(t*(t*6.0f-15.0f)+10.0f); }
float blend(float a, float b, float t) { return a+t*(b-a); }
float gradient(int h, float x, float y, float z) {
  h &= 15;
  float u=h<8?x:y, v=h<4?y:((h==12||h==14)?x:z);
  return ((h&1)==0?u:-u)+((h&2)==0?v:-v);
}
float noise(float3 p, device const int* table) {
  if(!all(isfinite(p))) return as_type<float>(0x7fc00000u);
  float3 base=floor(p), q=p-base, f=float3(fade(q.x),fade(q.y),fade(q.z));
  int x=int(fmod(base.x,256.0f))&255, y=int(fmod(base.y,256.0f))&255, z=int(fmod(base.z,256.0f))&255;
  int a=table[x]+y, b=table[x+1]+y;
  int aa=table[a]+z, ab=table[a+1]+z, ba=table[b]+z, bb=table[b+1]+z;
  float x00=blend(gradient(table[aa],q.x,q.y,q.z),gradient(table[ba],q.x-1,q.y,q.z),f.x);
  float x10=blend(gradient(table[ab],q.x,q.y-1,q.z),gradient(table[bb],q.x-1,q.y-1,q.z),f.x);
  float x01=blend(gradient(table[aa+1],q.x,q.y,q.z-1),gradient(table[ba+1],q.x-1,q.y,q.z-1),f.x);
  float x11=blend(gradient(table[ab+1],q.x,q.y-1,q.z-1),gradient(table[bb+1],q.x-1,q.y-1,q.z-1),f.x);
  return clamp((blend(blend(x00,x10,f.y),blend(x01,x11,f.y),f.z)+1.0f)*0.5f,0.0f,1.0f);
}
float fbm(float3 p, int octaves, device const int* table) {
  float frequency=1.0f, amplitude=1.0f, sum=0.0f, weights=0.0f;
  for(int octave=0;octave<octaves;octave++) {
    sum+=noise(p*frequency,table)*amplitude; weights+=amplitude;
    frequency*=2.0f; amplitude*=0.5f;
  }
  return weights==0.0f?0.0f:sum/weights;
}
|}
exception Unsupported of string
let fail message = raise (Unsupported message)
let register index = "r" ^ string_of_int index
let rec guarded guards = function
  | P.Guarded (more, body) -> guarded (guards @ more) body
  | instruction -> guards, instruction
let binary operation a b =
  let infix operator = "(" ^ a ^ operator ^ b ^ ")" in
  match operation with
  | P.Add -> infix "+" | Sub -> infix "-" | Mul -> infix "*"
  | Div -> "(" ^ b ^ "==0.0f?0.0f:" ^ a ^ "/" ^ b ^ ")"
  | Mod -> "(" ^ b ^ "==0.0f?0.0f:fmod(fmod(" ^ a ^ "," ^ b ^ ")+" ^ b ^ "," ^ b ^ "))"
  | Pow -> "pow(fabs(" ^ a ^ ")," ^ b ^ ")"
  | Min -> "min(" ^ a ^ "," ^ b ^ ")" | Max -> "max(" ^ a ^ "," ^ b ^ ")"
  | Lt -> infix "<" | Le -> infix "<=" | Gt -> infix ">" | Ge -> infix ">=" | Eq -> infix "=="
  | And -> "(" ^ a ^ "!=0.0f&&" ^ b ^ "!=0.0f)"
  | Or -> "(" ^ a ^ "!=0.0f||" ^ b ^ "!=0.0f)"
  | Atan2 -> "atan2(" ^ a ^ "," ^ b ^ ")"
  | Hypot -> fail "Native-safe hypot is not supported by the Metal kernel target."
let unary operation a = match operation with
  | P.Sin -> "sin(" ^ a ^ ")" | Cos -> "cos(" ^ a ^ ")"
  | Sqrt -> "sqrt(fabs(" ^ a ^ "))" | Abs -> "fabs(" ^ a ^ ")" | Not -> "(" ^ a ^ "==0.0f)"
  | Tan -> "tan(" ^ a ^ ")"
  | Asin | Acos -> "(fabs(" ^ a ^ ")>1.0f?as_type<float>(0x7fc00000u):"
      ^ (if operation=P.Asin then "asin" else "acos") ^ "(" ^ a ^ "))"
  | Exp -> "exp(" ^ a ^ ")"
  | Log -> "(" ^ a ^ "<=0.0f?as_type<float>(0x7fc00000u):log(" ^ a ^ "))"
  | Sign -> "(" ^ a ^ ">0.0f?1.0f:(" ^ a ^ "<0.0f?-1.0f:" ^ a ^ "))"
let kernel program = try
  let view = P.Private.view program in
  (match P.gpu_refusals program with [] -> () | reason :: _ -> fail reason.message);
  let offset = ref 4 and uniform_layout = ref [] in
  let uniform name width =
    let first = !offset in offset := first+width*4;
    uniform_layout := (name,first,width) :: !uniform_layout; first/4 in
  let uniforms = Array.mapi (fun index width -> uniform ("uniform:" ^ string_of_int index) width) view.uniform_widths in
  let frames = Array.mapi (fun index instruction -> match snd (guarded [] instruction) with
    | P.Frame name -> uniform (Printf.sprintf "frame:%d:%s" index name) 1 | _ -> 0) view.code in
  let used = P.Private.output_reachable program in
  let finite_checks = P.Private.finite_checks program in
  let table_seeds = Array.to_list(Array.mapi(fun index instruction->index,snd(guarded [] instruction))view.code)
    |> List.filter_map (function
      | index,P.Noise3 (_,_,_,seed,_,_,_) when used.(index) ->
          Some seed | _ -> None) |> List.sort_uniq Int.compare |> Array.of_list in
  let table seed = match Array.find_index ((=) seed) table_seeds with Some index -> index*512 | None -> assert false in
  let body = Buffer.create 4096 in
  Array.iteri (fun slot instruction ->
    if used.(slot) then begin
    let guards,instruction=guarded [] instruction in
    let expression = match instruction with
      | P.Const value ->
          Printf.sprintf "as_type<float>(0x%lxu)" (Int32.bits_of_float value)
      | Input (input,width,component) -> Printf.sprintf "input%d[i*%d+%d]" input width component
      | Uniform (index,component) -> Printf.sprintf "as_type<float>(uniforms[%d])" (uniforms.(index)+component)
      | Frame _ -> Printf.sprintf "as_type<float>(uniforms[%d])" frames.(slot)
      | Accumulator _ -> assert false
      | Binary (op,a,b) -> binary op (register a) (register b)
      | Unary (op,a) -> unary op (register a)
      | Checked_mul _ | Checked_fma _ -> fail "Checked arithmetic requires binary64 overflow status."
      | Array_prepare _ | Gather _ | Int_gather _ -> fail "Indexed array reads stay on the CPU."
      | Text_const _ | Text_input _ | Text_uniform _ | Text_gather _ | Text_select _ -> fail "Text kernels stay on the CPU."
      | Select (condition,yes,no) -> Printf.sprintf "(%s!=0.0f?%s:%s)" (register condition) (register yes) (register no)
      | Noise3 (x,y,z,seed,octaves,_,_) -> Printf.sprintf "fbm(float3(%s,%s,%s),%d,table+%d)"
          (register x) (register y) (register z) octaves (table seed)
      | _ -> fail "Integer instructions and conversions are not supported by the Metal kernel target." in
    let indentation=if guards=[] then "  " else "    " in
    if guards=[] then Printf.bprintf body "  float r%d=%s;\n" slot expression else begin
      Printf.bprintf body "  float r%d=0.0f;\n" slot;
      Printf.bprintf body "  if(%s) {\n" (String.concat "&&" (List.map(fun(condition,selected)->
        Printf.sprintf "r%d%s0.0f" condition (if selected then "!=" else "=="))guards));
      Printf.bprintf body "    r%d=%s;\n" slot expression
    end;
    if finite_checks.(slot) then
      Printf.bprintf body "%sif(!isfinite(r%d)) atomic_store_explicit(status,1u,memory_order_relaxed);\n" indentation slot;
    if guards<>[] then Buffer.add_string body "  }\n"
    end) view.code;
  let outputs = Array.length view.outputs in
  let output_name k = if outputs = 1 then "output" else "output" ^ string_of_int k in
  Array.iteri (fun k registers -> Array.iteri (fun component slot ->
    Printf.bprintf body "  %s[i*%d+%d]=r%d;\n"
      (output_name k) (Array.length registers) component slot) registers) view.outputs;
  let count = Array.length view.widths in
  let arguments = Array.to_list (Array.mapi (fun index _ -> Printf.sprintf
    "device const float* input%d [[buffer(%d)]]" index index) view.widths)
    @ List.init outputs (fun k -> Printf.sprintf "device float* %s [[buffer(%d)]]" (output_name k) (count+k))
    @ [Printf.sprintf "constant uint* uniforms [[buffer(%d)]]" (count+outputs);
       Printf.sprintf "device atomic_uint* status [[buffer(%d)]]" (count+outputs+1)]
    @ (if table_seeds=[||] then [] else [Printf.sprintf "device const int* table [[buffer(%d)]]" (count+outputs+2)])
    @ ["uint i [[thread_position_in_grid]]"] in
  let prefix = "#include <metal_stdlib>\nusing namespace metal;\n" ^
    (if table_seeds=[||] then "" else perlin) in
  let signature = String.concat ",\n  " arguments in
  let body = "  if(i>=uniforms[0]) return;\n  if(i==0) atomic_fetch_or_explicit(status,0u,memory_order_relaxed);\n" ^ Buffer.contents body in
  let digest = Digest.to_hex (Digest.string (prefix ^ signature ^ body)) in
  let entry = "kernel_" ^ digest in
  let source = prefix ^ "kernel void " ^ entry ^ "(\n  " ^ signature ^ ") {\n" ^ body ^ "}\n" in
  let input_used=Array.make count false in
  Array.iteri(fun slot instruction->match snd(guarded [] instruction)with P.Input(input,_,_)when used.(slot)->input_used.(input)<-true|_->())view.code;
  let interface = List.init (count+outputs+2+(if table_seeds=[||] then 0 else 1)) Fun.id
    |>List.filter(fun binding->binding>=count || input_used.(binding))
    |>List.map(fun binding->S.{group=0;binding;kind=(if binding=count+outputs then Uniform_buffer else Storage_buffer);visibility=[Compute]})in
  Ok {source;entry;interface;uniform_layout=List.rev !uniform_layout;uniform_bytes= !offset;
    table_seeds;output_widths=Array.map Array.length view.outputs;input_widths=view.widths}
with Unsupported message -> Error (Flow.Diagnostic.error ~code:"E_GPU_FORM" message)
