(** Frame lowering: literals, captured reads, scalar operations, vectors,
    patterned lets, branches, specialized/inlined callables, macros, bypasses,
    ordered record fields, text/display/equality, bounded lists, higher-order
    forms and structured product/accumulator loops.
    Unsupported forms/operators are named; no opaque operation survives. *)
val lower : Flow.Eval.residual -> (Core.program, string) result
