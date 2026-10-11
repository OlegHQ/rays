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
      (** Exact integer induction after the source's endpoint conversion.
          Assign max(0,last-first) to count, check limit, run init once, then
          run body with ordinal index and Int(first+index) item. *)
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
(* A region: a pure numeric loop body over packed arrays, as a register program
    (instruction [n] defines register [n] from earlier registers). *)
module Region : sig
  type instruction =
    | Const of float | Input of int * int * int  (** source, width, component *)
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

val primitive_name : primitive -> string
val literal_of_value : Flow.Eval.value -> literal option
val value_of_literal : literal -> Flow.Eval.value
val pp : Format.formatter -> program -> unit
(** Deterministic diagnostic printer, including every statement's source identity. *)
