(** JavaScript for packed regions placed on the CPU. The frame-level printer
    joins this module in a later task. *)

val region : Flow_ir.Packed.t -> string
(** The source of [function region(inputs, uniforms, outputs, start, stop)],
    which runs iteration indices [start, stop) of one region over typed arrays
    and returns a status: [0] for success, [1] when a value is not finite
    (native [Packed.force]'s [Nonfinite], reported as [E_KERNEL]; outputs and
    state are then partly written and must be discarded). Arithmetic is 64-bit
    and follows [Packed.force] instruction by instruction, including the
    division/[mod]/[pow]/[sqrt] guards and the finite checks, and every
    instruction runs, reachable or not.

    - [inputs]: one [Float64Array] per source, packed with that source's width.
      For a product iteration of several sources each array must hold exactly
      its source's elements; the index space is the product of their lengths.
    - [uniforms]: one [Float64Array] per [uniform_widths] entry, then, as the
      last element, the frame array indexed by instruction slot (as
      [Packed.Private.inputs.frame]).
    - [outputs]: one [Float64Array] per output, the collecting kinds only, sized
      [kept * width] where [kept] is the iteration count minus skipped
      indices. A [Sum] or [Accumulate] region appends one state array of
      [width + 1] doubles: the accumulator components, then an initialized flag
      (0 or 1). The caller seeds it before the first range: a [Sum true] region
      starts at zeros with flag 1, [Sum false] at flag 0 (flag still 0 after
      an empty iteration means the integer 0), [Accumulate] at the seed
      components with flag 1. [Accumulate (_, true)] ([scan]) also collects.

    Covers every result kind: [Collect], [Sum] and [Accumulate], one or several
    outputs ([Collect] only), [Zip] and [Product] iteration, and [skip].
    Sums and accumulators fold elements strictly in index order, so successive
    ranges of one region must be run in ascending order with the same state
    array, never concurrently; only [Collect] ranges may run in parallel.
    Skipped indices are not evaluated and do not occupy an output slot. Noise
    permutation tables are embedded in the source. *)
