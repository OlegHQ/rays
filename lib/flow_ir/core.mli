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
  | Prim of primitive * (string * int) list
  | Vec of int list | Fields of (string * int) list | Items of int list
  | Field of int * string

type source = {
  site : Flow.Workspace.path; owner : Flow.Workspace.path;
  instance : int; iter : int list; span : Flow.Diagnostic.span option;
}

type statement = { id : int; source : source; node : statement_node }
and statement_node =
  | Assign of int * expr
  | If of { condition : int; yes : statement list; no : statement list }
  | Iterate of { sequence : int; index : int; item : int; limit : int; body : statement list }
  | Store of { sequence : int; index : int; value : int }
  | State_read of { slot : int; result : int; init : statement list; initial : int }
  | State_write of { slot : int; value : int }
  | Invoke of { region : int; args : int list; result : int }

type state_slot = {
  source : source; prefix : Flow.Workspace.path; zone : Flow.Workspace.path;
  plane : [ `Frame | `Host ]; ty : Flow.Ty.t;
}
type region = Region_ref of Packed.t

type program = {
  constants : literal array; locals : Flow.Ty.t array;
  body : statement list; results : int array;
  state_slots : state_slot array; regions : region array;
}

val primitive_name : primitive -> string
val pp : Format.formatter -> program -> unit
(** Deterministic diagnostic printer, including every statement's source identity. *)
