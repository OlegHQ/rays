(** Serializable structured frame programs. Locals and constants are numbered in
    authored traversal order. Values are immutable after publication. *)
type literal =
  | Int of int | Float of float | Bool of bool | Text of string
  | Vector of float array | List of literal array
  | Record of (string * literal) list
  | Array of { width : int; data : float array }
  | Empty_geometry

type integer = Mul | Div | Mod | And | Xor
type byte_mode = Clamped | Unclamped
type primitive =
  | Numeric of Flow.Packed_ops.binary | Math of Flow.Packed_ops.unary
  | Remainder | Exp | Floor | Ceil | Round | Int_convert | Float_convert
  | Integer of integer | Equal | Show | Text_concat
  | Sequence_length | Sequence_get | Sequence_build | Sequence_slice | Sequence_concat
  | Array_range | Array_float | Array_vec3 | Array_nth | Array_count | Array_slice | Array_concat
  | Rand | Noise3 | Color_parse | Color_byte of byte_mode
  | Coerce of Flow.Ty.t | Truthy | Fail of string * string

type frame_field = Time | Dt | Index | Tick | Width | Height | Pointer_x | Pointer_y | Input

type expr =
  | Constant of int | Local of int | Frame of frame_field
  | Call_index of int
  | Prim of primitive * (string * int) list
  | Vec of int list | Fields of (string * int) list | Items of int list
  | Field of int * string

type iteration = Static_index of int | Local_index of int
type source = {
  site : Flow.Workspace.path; owner : Flow.Workspace.path;
  instance : int; prefix : Flow.Workspace.path;
  iter : iteration list; span : Flow.Diagnostic.span option;
}

type statement = { id : int; source : source; node : statement_node }
and statement_node =
  | Assign of int * expr
  | Reset_call of int
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
  type instruction =
    | Const of float | Input of int * int * int
    | Uniform of int * int | Frame of string | Accumulator of int
    | Binary of Flow.Packed_ops.binary * int * int | Unary of Flow.Packed_ops.unary * int
    | Noise3 of int * int * int * int * int | Select of int * int * int
  type iteration = Zip | Product
  type result = Collect | Sum of bool | Accumulate of Flow.Workspace.term * bool
  type origin = Flow.Workspace.path * int list
  type count_source = Flow.Eval.residual -> Flow.Workspace.term -> origin option
  type t = {
    residual : Flow.Eval.residual; term : Flow.Workspace.term;
    sources : (Flow.Eval.residual * Flow.Workspace.term) array; widths : int array;
    uniforms : Flow.Eval.value array; uniform_names : (string * string list) array;
    code : instruction array; output : int array;
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
      | Eq -> "=" | And -> "and" | Or -> "or")
  | Math op -> (match op with Sin -> "sin" | Cos -> "cos" | Sqrt -> "sqrt" | Abs -> "abs" | Not -> "not")
  | Remainder -> "remainder" | Exp -> "exp" | Floor -> "floor" | Ceil -> "ceil" | Round -> "round"
  | Int_convert -> "int" | Float_convert -> "float"
  | Integer op -> "int/" ^ (match op with Mul -> "mul" | Div -> "div" | Mod -> "mod" | And -> "and" | Xor -> "xor")
  | Equal -> "equal?" | Show -> "show" | Text_concat -> "text/concat"
  | Sequence_length -> "sequence/length" | Sequence_get -> "sequence/get"
  | Sequence_build -> "sequence/build" | Sequence_slice -> "sequence/slice" | Sequence_concat -> "sequence/concat"
  | Array_range -> "array/range" | Array_float -> "array/float" | Array_vec3 -> "array/vec3"
  | Array_nth -> "array/nth" | Array_count -> "array/count" | Array_slice -> "array/slice" | Array_concat -> "array/concat"
  | Rand -> "value/rand" | Noise3 -> "noise3" | Color_parse -> "color/parse" | Color_byte _ -> "color/byte"
  | Coerce _ -> "coerce" | Truthy -> "truthy" | Fail _ -> "fail"

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
    | Array {width;data} -> out "array%d[" width;
        separated (fun x -> out "%s" (Flow.Lisp.float x)) (Array.to_list data); out "]"
    | Empty_geometry -> out "nil" in
  let expression = function
    | Constant n -> out "$%d" n | Local n -> local n | Frame f -> out "frame.%s" (frame_name f)
    | Call_index n -> out "call[%d]++" n
    | Prim (op,args) ->
        out "%s" (primitive_name op);
        (match op with Coerce ty -> out "<%s>" (Flow.Ty.to_string ty)
          | Color_byte Clamped -> out "<clamped>" | Color_byte Unclamped -> out "<unclamped>"
          | Fail (code,message) -> out "<%S %S>" code message | _ -> ());
        out "("; separated (fun (name,n) -> out "%S:" name; local n) args; out ")"
    | Vec ns -> out "vec["; separated local ns; out "]"
    | Fields xs -> out "record{"; separated (fun (name,n) -> out "%S:" name; local n) xs; out "}"
    | Items ns -> out "list["; separated local ns; out "]"
    | Field (n,name) -> local n; out ".%S" name in
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
      | Invoke {region;args;result} -> local result; out " = region[%d](" region; separated local args; out ")");
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
      (names r.widths) (names r.output) (Array.length r.uniforms) (names r.skip) (List.length r.stages);
    Array.iteri (fun i (x : Region.instruction) ->
      out "    r%d = " i;
      (match x with
       | Const f -> out "%s" (Flow.Lisp.float f)
       | Input (s, w, c) -> out "input[%d].%d/%d" s c w
       | Uniform (u, c) -> out "uniform[%d].%d" u c
       | Frame name -> out "frame.%s" name
       | Accumulator c -> out "accumulator.%d" c
       | Binary (op, a, b) -> out "%s(r%d r%d)" (primitive_name (Numeric op)) a b
       | Unary (op, a) -> out "%s(r%d)" (primitive_name (Math op)) a
       | Noise3 (x, y, z, seed, octaves) -> out "noise3(r%d r%d r%d seed=%d octaves=%d)" x y z seed octaves
       | Select (c, a, b) -> out "select(r%d r%d r%d)" c a b);
      out "\n") r.code) p.regions;
  statements 1 p.body;
  out "  return "; separated local (Array.to_list p.results); out "\n"
