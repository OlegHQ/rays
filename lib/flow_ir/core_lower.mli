(** Frame lowering: literals, captured reads, scalar operations, vectors,
    patterned lets, branches, specialized/inlined callables, macros, bypasses,
    ordered record fields, text/display/equality, bounded lists, higher-order
    forms and structured product/accumulator loops.
    Unsupported forms/operators are named; no opaque operation survives. *)
val lower : Flow.Eval.residual -> (Core.program, string) result

type draw_context = {
  value : Core.source -> Flow.Eval.value -> int;  (** the local holding a constant or residual value *)
  local : Flow.Ty.t -> int;
  emit : Core.source -> Core.statement_node -> unit;
}
val lower_draw : root:Flow.Eval.residual Lazy.t -> (draw_context -> unit) -> (Core.program, string) result
(** A program whose statements the callback writes, with no result. [root], forced only when a
    residual is lowered, stands for the evaluation (operators, definitions, state). *)
