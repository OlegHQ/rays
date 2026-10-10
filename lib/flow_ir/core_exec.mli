(** Initial-domain execution of the structured frame core, using native primitive
    bodies. Unsupported state/region statements decline during staged migration. *)
val run : Core.program -> live:Frame_input.t ->
  (Flow.Eval.value, Flow.Diagnostic.t) result
