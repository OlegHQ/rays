(** Serializable structured frame programs. Locals and constants are numbered in
    authored traversal order. Values are immutable after publication. *)
type literal =
  | Int of int | Float of float | Bool of bool | Text of string
  | Vector of float array | List of literal array
  | Record of (string * literal) list
  | Array of { width : int; data : float array }
  | Int_array of int array
  | Text_array of string array
  | Empty_geometry

type integer = Flow.Packed_ops.integer = Iadd | Isub | Imul | Idiv | Imod | Iand | Ior | Ixor | Ishl | Ishr
type byte_mode = Clamped | Unclamped
type primitive =
  | Numeric of Flow.Packed_ops.binary | Math of Flow.Packed_ops.unary
  | Remainder | Exp | Floor | Ceil | Round | Int_convert | Float_convert
  | Integer of integer | Integer_compare of Flow.Packed_ops.comparison | Equal | Show | Text_concat | Text_blank
  | Text_trim | Text_lower | Text_repr | Text_table_decode | Text_table_encode
  | Text_split | Text_tokens | Text_to_float | Text_to_int
  | Sequence_length | Sequence_get | Sequence_build | Sequence_slice | Sequence_concat
  | Array_max_length | Array_range | Array_int | Array_text | Array_float | Array_vec3 | Array_vec4 | Array_nth | Array_count | Array_slice | Array_concat
  | Array_reduce of Flow.Op.Private.reduction | Array_segment of Flow.Op.Private.reduction
  | Array_scatter_add | Array_compact | Array_scan_sum | Array_grade | Array_index_of
  | Rand | Rand_at | Fma | Checked_mul | Checked_fma | Noise3 | Color_parse | Color_byte of byte_mode
  | Coerce of Flow.Ty.t | Truthy | Error | Fail of string * string | Fail_diagnostic of Flow.Diagnostic.t

type frame_field = Time | Dt | Index | Tick | Width | Height | Pointer_x | Pointer_y | Input

type expr =
  | Constant of int | Local of int | Frame of frame_field
  | Call_index of int
  | Source of Flow.Eval.value
  | Host_source of { name : string; ty : Flow.Ty.t; args : (string * int) list }
  | Source_descriptor of { name : string; ty : Flow.Ty.t; args : (string * int) list }
  | Prim of primitive * (string * int) list
  | Vec of int list | Fields of (string * int) list | Items of int list
  | Field of int * string

type iteration = Static_index of int | Local_index of int
type source = {
  site : Flow.Workspace.path; owner : Flow.Workspace.path;
  instance : int; prefix : Flow.Workspace.path;
  iter : iteration list; span : Flow.Diagnostic.span option;
}

(* Drawing statements: operands are locals holding the operator's own inputs, with every
   default already resolved by the lowering (Core_draw); the executor checks and encodes them. *)
type mark = Rect | Circle | Line
type transform = Translate | Rotate | Scale
type path = Rounded_rect | Polygon | Polyline
type draw =
  | Background of int
  | Point of { at : int; ink : int }
  | Mark of { mark : mark; args : (string * int) list }
  | Batch of { mark : mark; args : (string * int) list }
  | Points of { positions : int; ink : int }
  | Path of { path : path; args : (string * int) list }
  | Text_run of { at : int; text : int; ink : int; size : int }
  | Image of { source : Flow.Ty.t * int; at : int; scale : int; angle : int }
  | Push of transform * int
  | Pop

type statement = { id : int; source : source; node : statement_node }
and statement_node =
  | Draw of draw
  | Assign of int * expr
  | Reset_call of int
  | Protect of { body : statement list; value : int; failure : int;
      handler : statement list; mapped : int; result : int }
  | Diagnose_rows of { rows : int; policy : Flow.Workspace.diagnostic_policy; index : int;
      handler : statement list; diagnostic : int; result : int }
  | If of { condition : int; yes : statement list; no : statement list }
  | Iterate of { sequence : int; index : int; item : int; limit : int; body : statement list }
  | Counted of { first : int; last : int; count : int; index : int; item : int;
      limit : int; init : statement list; body : statement list }
  | Store of { sequence : int; index : int; value : int }
  | State_read of { slot : int; result : int; init : statement list; initial : int }
  | State_peek of { slot : int; found : int; value : int }
      (** [found] := whether this frame already holds a pending write; [value] := it. *)
  | State_write of { slot : int; value : int }
  | Invoke of { region : int; args : int list; result : int }

type state_slot = {
  source : source; prefix : Flow.Workspace.path; zone : Flow.Workspace.path;
  plane : [ `Frame | `Host ]; ty : Flow.Ty.t;
}
module Region = struct
  type projection = Value | Valid
  type conversion = Flow.Packed_ops.conversion = To_float | Truncate | Floor | Ceil | Round | Coerce_int | Integer_result of string
  type instruction =
    | Const of float | Input of int * int * int
    | Uniform of int * int | Frame of string | Accumulator of int
    | Binary of Flow.Packed_ops.binary * int * int | Unary of Flow.Packed_ops.unary * int
    | Noise3 of int * int * int * int * int | Fma of int * int * int | Rand_at of int * int | Select of int * int * int
    | Checked_mul of projection * int * int | Checked_fma of projection * int * int * int
    | Array_prepare of int * Flow.Ty.t
    | Gather of int * int * int * int | Int_gather of int * int
    | Text_const of string | Text_input of int | Text_uniform of int
    | Text_gather of int * int | Text_select of int * int * int
    | Int_const of int | Int_input of int | Int_uniform of int | Int_frame of string | Int_accumulator
    | Int_binary of Flow.Packed_ops.integer * int * int
    | Int_compare of Flow.Packed_ops.comparison * int * int | Int_abs of int
    | Convert of conversion * int | Int_select of int * int * int
    | Guarded of (int * bool) list * instruction
    | Raise of Flow.Ty.t * string * string * string option
  let rec integer_register = function
    | Int_const _ | Int_input _ | Int_uniform _ | Int_frame _ | Int_accumulator
    | Int_binary _ | Int_abs _ | Int_select _ | Int_gather _ | Raise (Flow.Ty.Int,_,_,_) -> true
    | Convert (To_float,_) -> false | Convert _ -> true
    | Guarded (_,instruction) -> integer_register instruction
    | _ -> false
  let rec text_register = function
    | Text_const _ | Text_input _ | Text_uniform _ | Text_gather _ | Text_select _
    | Raise (Flow.Ty.Text,_,_,_) -> true
    | Guarded (_,instruction) -> text_register instruction
    | _ -> false
  let rec operands = function
    | Binary (_,a,b) | Int_binary (_,a,b) | Int_compare (_,a,b) | Rand_at(a,b) | Checked_mul(_,a,b)
    | Gather(a,b,_,_) | Int_gather(a,b) | Text_gather(a,b) -> [a;b]
    | Unary (_,a) | Int_abs a | Convert (_,a) -> [a]
    | Noise3 (a,b,c,_,_) | Fma(a,b,c) | Select (a,b,c) | Int_select (a,b,c) | Text_select(a,b,c) | Checked_fma(_,a,b,c) -> [a;b;c]
    | Guarded (guards,instruction) -> List.map fst guards @ operands instruction
    | _ -> []
  type iteration = Zip | Product
  type result = Collect | Sum of bool | Accumulate of Flow.Workspace.term * bool
  type origin = Flow.Workspace.path * int list
  type count_source = Flow.Eval.residual -> Flow.Workspace.term -> origin option
  type t = {
    residual : Flow.Eval.residual; term : Flow.Workspace.term;
    sources : (Flow.Eval.residual * Flow.Workspace.term) array; widths : int array;
    uniforms : Flow.Eval.value array; uniform_names : (string * string list) array;
    code : instruction array;
    outputs : int array array; (* component registers of each output; [Collect] regions only may have several *)
    count : int option; origin : origin option;
    iteration : iteration; result : result; skip : int array;
    stages : (Flow.Eval.residual * Flow.Workspace.term) list;
    fusion : bool; dynamic : bool; count_source : count_source;
    body : Flow.Workspace.term; binding_fn : string option;
    sites : (int * Flow.Workspace.path * int list) list }
end
type region = Region.t

type program = {
  constants : literal array; locals : Flow.Ty.t array;
  body : statement list; results : int array;
  state_slots : state_slot array; regions : region array;
  call_slots : int;
}

let primitive_name = function
  | Numeric op -> (match op with
      | Add -> "+" | Sub -> "-" | Mul -> "*" | Div -> "/" | Mod -> "mod" | Pow -> "pow"
      | Min -> "min" | Max -> "max" | Lt -> "<" | Le -> "<=" | Gt -> ">" | Ge -> ">="
      | Eq -> "=" | And -> "and" | Or -> "or" | Atan2 -> "atan2" | Hypot -> "hypot")
  | Math op -> (match op with Sin -> "sin" | Cos -> "cos" | Sqrt -> "sqrt" | Abs -> "abs" | Not -> "not"
      | Tan -> "tan" | Asin -> "asin" | Acos -> "acos" | Exp -> "exp" | Log -> "log" | Sign -> "sign")
  | Remainder -> "remainder" | Exp -> "exp" | Floor -> "floor" | Ceil -> "ceil" | Round -> "round"
  | Int_convert -> "int" | Float_convert -> "float"
  | Integer op -> Flow.Packed_ops.integer_name op
  | Integer_compare op -> Flow.Packed_ops.comparison_name op
  | Equal -> "equal?" | Show -> "show" | Text_concat -> "text/concat"
  | Text_blank -> "text/blank?"
  | Text_trim -> "text/trim" | Text_lower -> "text/lower" | Text_repr -> "text/repr"
  | Text_table_decode -> "text/table_decode" | Text_table_encode -> "text/table_encode"
  | Text_split -> "text/split" | Text_tokens -> "text/tokens"
  | Text_to_float -> "text/to_float" | Text_to_int -> "text/to_int"
  | Array_reduce operation | Array_segment operation as primitive ->
      let suffix=match operation with Flow.Op.Private.Sum -> "sum" | Minimum -> "min" | Maximum -> "max" in
      "array/" ^ (match primitive with Array_segment _ -> "segment_" | _ -> "") ^ suffix
  | Array_grade -> "array/grade" | Array_index_of -> "array/index_of"
  | Array_compact -> "array/compact" | Array_scan_sum -> "array/scan_sum"
  | Array_scatter_add -> "array/scatter_add"
  | Sequence_length -> "sequence/length" | Sequence_get -> "sequence/get"
  | Sequence_build -> "sequence/build" | Sequence_slice -> "sequence/slice" | Sequence_concat -> "sequence/concat"
  | Array_max_length -> "array/max_length" | Array_range -> "array/range" | Array_int -> "array/int" | Array_float -> "array/float" | Array_vec3 -> "array/vec3" | Array_vec4 -> "array/vec4"
  | Array_text -> "array/text"
  | Array_nth -> "array/nth" | Array_count -> "array/count" | Array_slice -> "array/slice" | Array_concat -> "array/concat"
  | Rand -> "value/rand" | Rand_at -> "rand/at" | Fma -> "fma" | Noise3 -> "noise3" | Color_parse -> "color/parse" | Color_byte _ -> "color/byte"
  | Checked_mul -> "float/mul_checked" | Checked_fma -> "float/fma_checked"
  | Coerce _ -> "coerce" | Truthy -> "truthy" | Error -> "error" | Fail _ | Fail_diagnostic _ -> "fail"

let frame_name = function
  | Time -> "t" | Dt -> "dt" | Index -> "frame" | Tick -> "tick" | Width -> "width" | Height -> "height"
  | Pointer_x -> "pointer/x" | Pointer_y -> "pointer/y" | Input -> "input"

exception Not_literal
let literal_of_value value =
  let rec convert : Flow.Eval.value -> literal = function
    | Int n -> Int n | Float x -> Float x | Bool b -> Bool b | Text s -> Text s
    | Vec2 (x,y) -> Vector [|x;y|] | Vec3 (x,y,z) -> Vector [|x;y;z|]
    | Vec4 (x,y,z,w) -> Vector [|x;y;z;w|]
    | List xs when Array.length xs <= 4096 -> List (Array.map convert xs)
    | Record xs -> Record (List.map (fun (n,v) -> n,convert v) xs)
    | Int_array data -> Int_array data
    | Text_array data -> Text_array data
    | Float_array data -> Array {width=1;data} | Vec2_array data -> Array {width=2;data}
    | Vec3_array data -> Array {width=3;data} | Vec4_array data -> Array {width=4;data}
    | No_geo -> Empty_geometry | _ -> raise Not_literal in
  try Some (convert value) with Not_literal -> None

let rec value_of_literal : literal -> Flow.Eval.value = function
  | Int n -> Int n | Float x -> Float x | Bool b -> Bool b | Text s -> Text s
  | Vector [|x;y|] -> Vec2 (x,y) | Vector [|x;y;z|] -> Vec3 (x,y,z)
  | Vector [|x;y;z;w|] -> Vec4 (x,y,z,w)
  | List xs -> List (Array.map value_of_literal xs)
  | Record xs -> Record (List.map (fun (n,v) -> n,value_of_literal v) xs)
  | Int_array data -> Int_array data
  | Text_array data -> Text_array data
  | Array {width=1;data} -> Float_array data | Array {width=2;data} -> Vec2_array data
  | Array {width=3;data} -> Vec3_array data | Array {width=4;data} -> Vec4_array data
  | Empty_geometry -> No_geo | Vector _ | Array _ -> invalid_arg "Core.value_of_literal: width"

let pp fmt p =
  let out format = Format.fprintf fmt format in
  let separated render xs = List.iteri (fun i x -> if i > 0 then out " "; render x) xs in
  let local n = out "%%%d" n in
  let rec literal = function
    | Int n -> out "%d" n | Float f -> out "%s" (Flow.Lisp.float f)
    | Bool b -> out "%b" b | Text s -> out "%S" s
    | Vector xs -> out "vec["; separated (fun x -> out "%s" (Flow.Lisp.float x)) (Array.to_list xs); out "]"
    | List xs -> out "list["; separated literal (Array.to_list xs); out "]"
    | Record xs -> out "record{"; separated (fun (n,v) -> out "%S:" n; literal v) xs; out "}"
    | Int_array data -> out "array:int["; separated (fun n -> out "%d" n) (Array.to_list data); out "]"
    | Text_array data -> out "array:text["; separated (fun s -> out "%S" s) (Array.to_list data); out "]"
    | Array {width;data} -> out "array%d[" width;
        separated (fun x -> out "%s" (Flow.Lisp.float x)) (Array.to_list data); out "]"
    | Empty_geometry -> out "nil" in
  let expression = function
    | Constant n -> out "$%d" n | Local n -> local n | Frame f -> out "frame.%s" (frame_name f)
    | Call_index n -> out "call[%d]++" n
    | Source value -> out "source<%s>" (Flow.Ty.to_string (Flow.Value.ty_of value))
    | Host_source {name;ty;args}->out "host_source<%s %S>(" (Flow.Ty.to_string ty) name;
        separated (fun(name,n)->out "%S:" name;local n)args;out ")"
    | Source_descriptor {name;ty;args}->out "source_descriptor<%s %S>(" (Flow.Ty.to_string ty) name;
        separated (fun(name,n)->out "%S:" name;local n)args;out ")"
    | Prim (op,args) ->
        out "%s" (primitive_name op);
        (match op with Coerce ty -> out "<%s>" (Flow.Ty.to_string ty)
          | Color_byte Clamped -> out "<clamped>" | Color_byte Unclamped -> out "<unclamped>"
          | Fail (code,message) -> out "<%S %S>" code message
          | Fail_diagnostic d -> out "<%S %S cause=%S>" d.code d.message (Option.value ~default:"" d.cause)
          | _ -> ());
        out "("; separated (fun (name,n) -> out "%S:" name; local n) args; out ")"
    | Vec ns -> out "vec["; separated local ns; out "]"
    | Fields xs -> out "record{"; separated (fun (name,n) -> out "%S:" name; local n) xs; out "}"
    | Items ns -> out "list["; separated local ns; out "]"
    | Field (n,name) -> local n; out ".%S" name in
  let draw d = match d with
    | Background c -> out "draw/background "; local c
    | Point {at;ink} -> out "draw/point at="; local at; out " ink="; local ink
    | Mark {mark;args} | Batch {mark;args} ->
        let plural = match d with Batch _ -> "s" | _ -> "" in
        out "draw/%s%s" (match mark with Rect -> "rect" | Circle -> "circle" | Line -> "line") plural;
        List.iter (fun (name,n) -> out " %s=" name; local n) args
    | Points {positions;ink} -> out "draw/points positions="; local positions; out " ink="; local ink
    | Path {path;args} ->
        out "draw/%s" (match path with Rounded_rect -> "rounded_rect" | Polygon -> "polygon" | Polyline -> "polyline");
        List.iter (fun (name,n) -> out " %s=" name; local n) args
    | Text_run {at;text;ink;size} ->
        out "draw/text at="; local at; out " text="; local text; out " ink="; local ink; out " size="; local size
    | Image {source=(ty,id);at;scale;angle} ->
        out "draw/image %s#%d at=" (Flow.Ty.to_string ty) id; local at; out " scale="; local scale;
        out " angle="; local angle
    | Push (t,n) ->
        out "push %s " (match t with Translate -> "translate" | Rotate -> "rotate" | Scale -> "scale"); local n
    | Pop -> out "pop" in
  let path xs = out "["; separated (fun s -> out "%S" s) xs; out "]" in
  let source s =
    out " @"; path s.site; out " owner="; path s.owner; out " instance=%d iter=[" s.instance;
    separated (function Static_index n -> out "%d" n | Local_index n -> local n) s.iter; out "]";
    if s.prefix <> [] then (out " prefix="; path s.prefix);
    Option.iter (fun (s : Flow.Diagnostic.span) -> out " span=%d..%d" s.start s.finish) s.span in
  let rec statements depth xs =
    List.iter (fun s ->
      out "%s#%d " (String.make (depth * 2) ' ') s.id;
      let nested label xs = out "%s {\n" label; statements (depth+1) xs;
        out "%s}" (String.make (depth * 2) ' ') in
      (match s.node with
      | Assign (n,e) -> local n; out " = "; expression e
      | Reset_call n -> out "call[%d] <- 0" n
      | Protect {body;value;failure;handler;mapped;result}->
          local result;out " = protect ";nested "body" body;out " value=";local value;
          out " error=";local failure;out " ";nested "map" handler;out " value=";local mapped
      | Diagnose_rows {rows;policy;index;handler;diagnostic;result}->
          local result;out " = diagnose_rows ";local rows;out " policy=%s index="
            (match policy with Flow.Workspace.First->"first"|Range_last->"range-last");local index;
          out " ";nested "map" handler;out " diagnostic=";local diagnostic
      | If {condition;yes;no} -> out "if "; local condition; out " "; nested "then" yes;
          out " "; nested "else" no
      | Iterate {sequence;index;item;limit;body} -> out "iterate "; local sequence;
          out " index="; local index; out " item="; local item; out " limit=%d " limit; nested "do" body
      | Counted {first;last;count;index;item;limit;init;body} ->
          out "counted "; local first; out ".."; local last;
          out " count="; local count; out " index="; local index; out " item="; local item;
          out " limit=%d " limit; nested "init" init; out " "; nested "do" body
      | Store {sequence;index;value} -> local sequence; out "["; local index; out "] <- "; local value
      | State_read {slot;result;init;initial} -> local result; out " = state[%d] " slot;
          nested "init" init; out " value="; local initial
      | State_peek {slot;found;value} -> local found; out " = state[%d] pending " slot; local value
      | State_write {slot;value} -> out "state[%d] <- " slot; local value
      | Invoke {region;args;result} -> local result; out " = region[%d](" region; separated local args; out ")"
      | Draw d -> draw d);
      source s.source; out "\n") xs in
  out "core\n";
  if p.call_slots > 0 then out "  calls %d\n" p.call_slots;
  Array.iteri (fun n v -> out "  $%d = " n; literal v; out "\n") p.constants;
  Array.iteri (fun n ty -> out "  %%%d : %s\n" n (Flow.Ty.to_string ty)) p.locals;
  Array.iteri (fun n (s : state_slot) -> out "  state[%d] : %s plane=%s prefix=" n (Flow.Ty.to_string s.ty)
    (match s.plane with `Frame -> "frame" | `Host -> "host"); path s.prefix; out " zone="; path s.zone;
    source s.source; out "\n") p.state_slots;
  Array.iteri (fun n (r : Region.t) ->
    let names a = String.concat " " (Array.to_list (Array.map string_of_int a)) in
    out "  region[%d] %s %s count=%s widths=[%s] output=[%s] uniforms=%d skip=[%s] stages=%d\n" n
      (match r.iteration with Region.Zip -> "zip" | Product -> "product")
      (match r.result with Collect -> "collect" | Sum zero -> if zero then "sum0" else "sum"
        | Accumulate (_, scan) -> if scan then "scan" else "fold")
      (match r.count with Some c -> string_of_int c | None -> "?")
      (names r.widths) (String.concat " | " (Array.to_list (Array.map names r.outputs))) (Array.length r.uniforms) (names r.skip) (List.length r.stages);
    let rec instruction (x : Region.instruction) = match x with
       | Const f -> out "%s" (Flow.Lisp.float f)
       | Input (s, w, c) -> out "input[%d].%d/%d" s c w
       | Uniform (u, c) -> out "uniform[%d].%d" u c
       | Frame name -> out "frame.%s" name
       | Accumulator c -> out "accumulator.%d" c
       | Binary (op, a, b) -> out "%s(r%d r%d)" (primitive_name (Numeric op)) a b
       | Unary (op, a) -> out "%s(r%d)" (primitive_name (Math op)) a
       | Noise3 (x, y, z, seed, octaves) -> out "noise3(r%d r%d r%d seed=%d octaves=%d)" x y z seed octaves
       | Rand_at(seed,index) -> out "rand_at(r%d r%d)" seed index
       | Fma(a,b,c) -> out "fma(r%d r%d r%d)" a b c
       | Checked_mul(p,a,b) -> out "mul_checked.%s(r%d r%d)" (match p with Value->"value"|Valid->"valid") a b
       | Array_prepare(i,ty) -> out "array_prepare u%d:%s" i (Flow.Ty.to_string ty)
       | Gather(a,i,w,c) -> out "gather(r%d r%d width=%d component=%d)" a i w c
       | Int_gather(a,i) -> out "int_gather(r%d r%d)" a i
       | Text_const s -> out "text_const %S" s
       | Text_input i -> out "text_input in%d" i
       | Text_uniform i -> out "text_uniform u%d" i
       | Text_gather(a,i) -> out "text_gather(r%d r%d)" a i
       | Text_select(c,a,b) -> out "text_select(r%d r%d r%d)" c a b
       | Checked_fma(p,a,b,c) -> out "fma_checked.%s(r%d r%d r%d)" (match p with Value->"value"|Valid->"valid") a b c
       | Select (c, a, b) | Int_select (c,a,b) -> out "select(r%d r%d r%d)" c a b
       | Int_const n -> out "int:%d" n | Int_input i -> out "input:int[%d]" i
       | Int_uniform i -> out "uniform:int[%d]" i | Int_accumulator -> out "accumulator:int"
       | Int_frame name -> out "frame:int[%s]" name
       | Int_binary (op,a,b) -> out "%s(r%d r%d)" (Flow.Packed_ops.integer_name op) a b
       | Int_compare (op,a,b) -> out "%s(r%d r%d)" (Flow.Packed_ops.comparison_name op) a b
       | Int_abs a -> out "int:abs(r%d)" a
       | Convert (op,a) -> out "%s(r%d)" (match op with
           | To_float -> "float" | Truncate -> "int" | Floor -> "floor" | Ceil -> "ceil"
           | Round -> "round" | Coerce_int -> "coerce:int" | Integer_result name -> "int-result:"^name) a
       | Guarded (guards,body) -> out "guard[";
           separated (fun (c,yes)->out "r%d=%b" c yes) guards;out "] ";instruction body
       | Raise (ty,code,message,cause) -> out "error<%s %S %S" (Flow.Ty.to_string ty) code message;
           Option.iter(fun cause->out " cause=%S" cause)cause;out ">" in
    Array.iteri (fun i x ->out "    r%d = " i;instruction x;
      out "\n") r.code) p.regions;
  statements 1 p.body;
  out "  return "; separated local (Array.to_list p.results); out "\n"
