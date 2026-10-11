(** Initial-domain execution of the structured frame core, using native primitive
    bodies. State statements need [root], the residual whose state plane they use. Unsupported region statements decline during staged migration. *)
val run : ?root:Flow.Eval.residual -> Core.program -> live:Frame_input.t ->
  (Flow.Eval.value, Flow.Diagnostic.t) result
