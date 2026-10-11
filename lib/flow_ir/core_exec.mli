(** Initial-domain execution of the structured frame core, using native primitive
    bodies. State statements need [root], the residual whose state plane they use. A region runs through [force] (default [Packed.force]). *)
val run : ?root:Flow.Eval.residual ->
  ?force:(Packed.t -> (Flow.Eval.value, Flow.Diagnostic.t) result) -> Core.program -> live:Frame_input.t ->
  (Flow.Eval.value, Flow.Diagnostic.t) result
