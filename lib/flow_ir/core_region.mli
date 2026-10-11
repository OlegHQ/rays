(** Lowering of packed forms (map, reduce, numeric loop, array/sum) to core regions.
    Refusals keep [Packed]'s [E_PACKED_*] codes and spans. *)
exception Unsupported

val lower : ?fusion:bool -> ?dynamic:bool -> ?count_source:Core.Region.count_source ->
  Flow.Eval.residual -> Flow.Workspace.term -> (Core.Region.t, Flow.Diagnostic.t list) result
(** The unfused region of one form; [fusion] and [dynamic] are recorded on it. *)

(** Helpers shared with [Packed]. *)
val width_of : Flow.Ty.t -> int
val components : Flow.Eval.value -> float array
val captured_value : (string * Flow.Eval.value) list -> string -> string list -> Flow.Eval.value
val count_of : Flow.Eval.residual -> Flow.Workspace.term -> int option
val count_of_sources : Core.Region.iteration -> int option array -> int option
val reads_names : string list -> Flow.Workspace.term -> bool
