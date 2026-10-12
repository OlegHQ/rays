(** Lowering rules of the draw operators: a draw graph's plan and root value become a core
    program of draw statements, with no result, in painter order. The second component is a
    residual to run it with (state reads need one), absent when nothing is live.
    A drawing chosen by a live value is refused as ["draw_dynamic"], an image that is not a
    plan node as ["draw_image"]. *)
val lower : ?region_allowed:(Core.Region.t -> bool) -> Flow.Eval.plan -> Flow.Eval.value ->
  (Core.program * Flow.Eval.residual option, string) result
