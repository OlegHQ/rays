(** Initial-domain execution of the structured frame core, using native primitive
    bodies. State statements need [root], the residual whose state plane they use.
    A region runs through [force] (default [Packed.force]). With [root], any failure
    restores the evaluation state and returns the tree walker's result for that
    residual, so its diagnostic and span are the walker's. *)
type prepared
(** A program with its statements, constants and operators resolved once. *)

val prepare : ?fused:bool -> Core.program -> prepared
(* [~fused:false] runs every program through the general statements: the reference for the scalar tree fast path. *)
val has_regions : prepared -> bool  (* the program invokes a region, so [execute] needs a [force] *)
val execute : ?root:Flow.Eval.residual ->
  ?force:(Packed.t -> (Flow.Eval.value, Flow.Diagnostic.t) result) -> prepared -> live:Frame_input.t ->
  (Flow.Eval.value, Flow.Diagnostic.t) result
val run : ?root:Flow.Eval.residual ->
  ?force:(Packed.t -> (Flow.Eval.value, Flow.Diagnostic.t) result) -> Core.program -> live:Frame_input.t ->
  (Flow.Eval.value, Flow.Diagnostic.t) result
(** [prepare] then [execute]. *)
