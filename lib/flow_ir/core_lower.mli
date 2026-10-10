(** Frame lowering: literals, captured reads, scalar operations, vectors,
    patterned lets, branches, specialized/inlined callables, macros, bypasses
    and bounded static-list sums/fors.
    Unsupported forms/operators are named; no opaque operation survives. *)
val lower : Flow.Eval.residual -> (Core.program, string) result
