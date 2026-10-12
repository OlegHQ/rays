(** Cook-time connection between immutable geometry and packed Flow data. *)
val sources : Flow.Eval.value -> int list
val owner : string -> (Rdk.Attribute.owner, Flow.Diagnostic.t) result
val value_type : string -> (Flow.Ty.t, Flow.Diagnostic.t) result
val resolve : geometry:(int -> Rdk.Geometry.t option) ->
  Flow.Eval.value -> (Flow.Eval.value, Flow.Diagnostic.t) result
(** Resolve immutable cooked attributes and owner/type predicates, shared by
    kernels and reference probes. CSR reads expose typed offsets and values. *)

val source_origins : sources:int list -> Sop.Node.t list ->
  ((int * int) list, Flow.Diagnostic.t) result
(** The ordered source-to-topology-origin proof used by [prepare]. *)

val materialized_source : Sop.Node.t -> Sop.Node.t
(** A normal geometry consumer: cooking it through Session expands upstream
    packed instances at the existing input boundary. Retain it with its source. *)

val prepare : ?profile:Flow_ir.Profile.t -> ?strict:bool -> ?approx:Flow.Workspace.Paths.t -> ?sink:Flow_ir.sink ->
  sources:int list -> Sop.Node.t list -> Flow.Eval.value ->
  (Flow_ir.Executor.program, Flow.Diagnostic.t) result
(** Use instantiated, parameter-sensitive topology and elementwise facts to
    prove equal owner-array counts before dynamic multi-input fusion. CSR row
    offsets and flattened values use separate count origins. *)

val node : ?state:Flow.Eval.state -> ?reference:bool -> ?strict:bool ->
  ?elems:(string * Flow.Eval.value) list ->
  ?profile:Flow_ir.Profile.t ->
  ?owner:Rdk.Attribute.owner -> ?kind:string ->
  source:string -> name:string -> values:Flow.Eval.value -> sources:int list ->
  Sop.Node.t list -> Sop.Node.t
