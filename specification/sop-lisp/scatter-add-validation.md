# Ordered scatter-add integration

Status: native/reference/strict Core, source ownership, lazy errors, state
rollback, domains and actual JavaScript runtime/workers pass. The latest focused
integration run is `/tmp/rays-region-binding-focused9.log` (EXIT0), including
recursive argument storage, ordinary Float Product forcing and actual worker
error locations. Core variants were accepted in `77be0b5c`; implementation is
`93f5528f`. The corrected snapshot's native shipping check passed (session11075
EXIT0, `/tmp/rays-bulk-array-native-ship2.log`). C.4 is complete. Optional scatter
timings below have not run; these primitive checks qualify no whole SOP port.

## Boundary and reuse

`(array/scatter_add indices values size)` is a canonical value intrinsic and one
structured Core primitive. The Core executor reuses its existing cached
canonical `Op.body` dispatch; no public Op helper, Region instruction, new
packed bank, Value/Ty type, dependency, or native SOP callback is introduced.
Its three physical rows are IntArray, Array(Any), Int. Result checking restricts
the value element to Int/Float/Vec2/Vec3/Vec4 and size to Int (or unresolved
bottom Any); Text/records and Float sizes are refused. The actual card uses the
values' array element type, and direct edits recheck the source. The menu uses
a valid empty `(array/scatter_add (array/int 0) (array/float 0) 0)` starter.

The shared bulk loop allocates fresh zero-filled output, never changes inputs,
and updates source rows in order, then vector components x/y/z/w. Duplicate
indices retain separately rounded binary64 additions. Signed63 integers retain
ordinary `int/add` wrap, including values outside exact-double integer range;
JavaScript uses `BigInt.asIntN(63)` through the existing `wrap` helper.
Missing destinations are +0/Int0; empty input retains the requested output size.
This is an ordered scan even under a shared one/four/eight-domain pool, not
parallel atomics or reassociation. Its input maps can use existing strict packed
execution and the output can feed an ordinary map/gather. Variable scatter
inside a per-row numeric kernel remains an honest Packed compilation refusal;
there is no Metal/WGSL scatter emission. Materialized CPU scatter arrays can be
inputs to independently qualified GPU kernels.

## Validation, forcing and lifetime

Existing Eval/Core argument evaluation and source materialization keep authored
argument order. Host Sources validate their entire returned declared storage at
the existing resolver boundary before scatter. The loop then checks indices
storage, values' type/layout, size within the appropriate native width/count
bound, and equal indices/values cardinality. Structural/count errors precede
allocation and all row accesses. Each row checks its index before component
inputs and finite addition results. There is no global bounds pre-scan: a later
invalid index cannot replace an earlier overflowing sum, and an earlier invalid
index cannot be hidden by later overflow. The output is never published after
failure; ordinary diagnostic code/message/cause and state rollback apply.

Output count comes only from `size`; equal input counts do not provide an owner
or topology origin for it. Borrowed input descriptors are resolved/validated by
the ordinary source path, and each force reads the current host buffer. There
is no global scatter-result cache or borrowed output alias.

The private implementation has a ponytail comment for the existing bulk-loop
ceiling: Flow/Core exposes no cancellation token inside an intrinsic. Existing
host cancellation checks before/after forcing remain, as for B9 reductions;
there is no claim of mid-loop interruption or native cancellation/error race
parity. Native `Normal_ops.accumulate_points` is itself primitive/vertex-ordered
addition, so this supplies its ordinary finite accumulation building block.
Native raw IEEE accumulation/error masks and selected cancellation precedence
may require separate capabilities before a whole normal/Peak port passes.

## Passed focused acceptance

- FlowIR runnable check: exact independent ordered oracle and fresh output for
  Int/Float/Vec2/3/4; duplicates, signed zero, true subnormal and cancellation;
  0/1/13/32769 inputs and one/four/eight domains; Int min/max and >2^53 exactness;
  overflow before late bad index and inverse order; negative/huge indices and
  size/width limits, malformed counts/layout/type, NaN/+inf/-inf; strict child
  maps and rejection of unsupported producers/per-row scatter; source forcing
  order/type/cause, changed buffers on repeated forces and state rollback.
- Core operator inventory adds one live case. Native primitive fixture census
  grows 90 to 91, without deleting previous semantic/error cases. Native and
  JS host fixture comparisons include all numeric tags and malformed arrays.
- Actual emitted `Js.frame` runs with production `createRuntime` and pools
  null/one/eight workers, including genuine packed input maps. Exact bytes,
  lazy unselected errors, scatter overflow/cardinality/bounds diagnostics and
  unchanged transported input buffers are compared with the reference.
- Projection uses the ordinary Op card, direct size edit changes actual output,
  malformed index/value/size edits reject, and print/reparse retains checked
  source. Actual editor Add-node uses the valid empty source template.

After separate Core API acceptance, the shared launcher passed:

```
opam exec -- _build/default/tools/check.exe @check @lib/flow/runtest @lib/flow_ir/runtest @lib/flow_sop/runtest @lib/flow_graph/runtest @lib/flow_web/runtest @lib/flow_gpu/runtest @tools/lisp/runtest @test/dependency_gate @test/test_workspace_shell @tools/api_manifest/runtest
```

Production 2D export retains fixed-input admission; actual frame/runtime checks
use compiled preparation of computed arguments, without reference-fed arrays
or counts. Native geometry export is a separate target scope.

Optional quiet cost check uses the built `test_scatter.exe --bench`: fixed
1,000,000 Vec3 values, 100,000 destinations, duplicate indices, ordered reference
versus canonical primitive, three retained samples/median at 1/4/8 domains.
Input preparation and byte oracle are outside the timer. Main-domain GC counters
are reported and are not aggregate multi-domain allocation. Machine/profile
must be recorded alongside all rows; this draft contains no timing result or
2x whole-port claim.
