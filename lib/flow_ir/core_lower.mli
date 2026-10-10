(** Initial lowering slice: the closure tier's literals, captured reads, scalar
    operations, Vec3, static lets, branches and bounded static-list sums/fors.
    Unsupported forms/operators are named; no opaque operation survives. *)
val lower : Flow.Eval.residual -> (Core.program, string) result
