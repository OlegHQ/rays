# Kernel gather design and scheduling move

Status: C.2 is complete. Numeric implementation was accepted in `8319b320`,
with evidence in `gather-validation.md`; the required Text leaf extension is
verified in `text-gather-validation.md`. Its public API was accepted in
`03437c73`. C.2 is advanced before the Phase B review in `plan.md`. No whole
port or speed qualification follows from this foundation; the retained Text
timings still exceed 2× native. No build or benchmark was run for the original
audit below.

## Why C.2 belongs before the Phase B review

The plan schedules C.2 after B.R, but B.R waits for complete B.13 and B.14 ports.
Their existing drafts expose a shared indexed-data gap:

- Group Invert's test-only packed-word prototype performs genuine Lisp integer
  XOR and tail masking, then unpacks words in OCaml. An authored unpack map
  needs an exact integer lookup at `index / tile_width`. The current prototype
  is not a production word-source contract, and gather alone does not provide
  that contract or prove the whole-node speed gate. Retained measurements in
  `results.md` still fail that gate.
- Name From Groups assigns numeric group indices using packed kernels, then
  maps those indices into a captured Text inventory with `array/nth`.
  `nodes/name_from_groups.pending` already does this correctly through
  structured Core, but its million-element measured rows still fail the 2×
  gate. Numeric gather alone cannot accelerate its Text output.

Reviewed scheduling change: execute C.2 after B.1/B.2/B.3,
before B.13/B.14's final recipe gates; record B.13 and B.14's actual gather
dependencies. Keep its C.2 identity, CPU-only placement, original correctness
gate and unchecked status. B.R still requires complete ports and review.
The Text leaf extension below is an explicit subsequent requirement to address
Name From Groups rather than only numeric reindexing. This proposal advances
one shared prerequisite; it does not advance C.1 or every Phase C capability.

Current `point_jitter.pending` uses zipped numeric attributes and has no
`array/nth`; its demonstrated current blockers must not be relabelled as
gather. Gather can support future indexed recipes. Match Size's perimeter,
area and volume modes still require canonical triangulation and primitive
mapping from C.15 in addition to indexed reads; bounds-only fitting does not
establish those prerequisites. No mode may be omitted to bypass them.

## Original audit: existing path and the missing part

`Flow.Op` already declares `array/nth : (array a, int) -> a`.
`Value.array_get` supports Int, Text, Float and Vec2/3/4 arrays. Scalar Core's
`Array_nth`, its native executor and `prims.js` already implement indexed reads.
Structured Core can consequently run current Text assignment without a new
syntax or interpreter fallback.

The numeric region compiler rejects captured arrays as uniforms, has no gather
instruction, and checks scalar-only helper arguments. Ordinary `Input` and
`Int_input` read an iteration source at its zip/product induction index.
Those sources define count, strides and count-origin proofs. Appending a lookup
table there would truncate a zip or enlarge a Cartesian product and is wrong.

`Core_exec.block_loop` is not an alternative generic gather implementation:
it accepts Float scratch values and permits `Array_nth` only at its induction
item/index. Widening it separately for arbitrary exact integers and Text would
duplicate work already represented by the typed Packed runner.

## Smallest numeric representation

Reuse `Region.uniforms` and `uniform_names` as the table storage pool. They
already carry typed `Eval.value`, capture paths, residuals and Core argument
markers. Arrays become permitted table captures, never numeric scalar uniforms.
This avoids a second source pool, a new public `Value` or `Ty`, and new host
callbacks. Table length never participates in the region's iteration count.

Use a preparation instruction followed by typed reads, schematically:

```ocaml
Array_prepare of int
Gather of int * int * int * int
Int_gather of int * int
```

`Array_prepare` names a uniform-pool entry. `Gather` operands are its preparation
register, the exact integer index register, element width and component;
`Int_gather` takes preparation and index registers. The preparation register is
a compiler-internal array handle, not a scalar output. Numeric scratch need not
store an array: native execution can associate that register with its prepared
table entry, while JavaScript can hold the array view directly. Public region
validation must forbid exposing that handle as an output or consuming it with
numeric instructions. No handle is a published Flow value.

Preparation is necessary for ordinary argument/error order. Lower the table
argument and emit `Array_prepare` before lowering the index expression. Force
its selected table through the existing strict executor/resolver at that point;
only then run index instructions and the bounds-checked read. Otherwise an
invalid index calculation can incorrectly pre-empt a missing or malformed table.
The gather operand dependency retains preparation through sharing/fusion and
reachability passes. Both instructions inherit the existing branch guards.

Array entries may be concrete captured arrays, checked residual array
expressions or typed Core argument markers. They must be invariant with respect
to the current lane. Support array bindings, record paths, `let*` aliases and
checked helper array parameters using a compiler-only table expression. Do not
pass an array through `as_float`, `as_int` or scalar component extraction.
An array expression dependent on a lane, an accumulator, state or a correlated
product clause retains a typed qualification refusal. Nested producers must
compile strictly; an unsupported producer cannot be hidden in a table capture.

Constant-array plus constant-index calls can retain ordinary constant folding.
A Source descriptor is not a concrete constant: it must retain preparation and
resolution. `rebind` must update a table's current immutable capture through
its actual closure scope and record path, including changed Core arguments.
Fusion remaps uniform indices, preparation registers, index registers and
guards. It may materialize a computed lookup table once rather than fuse its
producer at the consumer's unrelated iteration index.

## Types, bounds and error sequencing

Initial numeric gathers cover Int, Float and Vec2/3/4. Int reads and indices use
native signed 63-bit banks; values above 2^53 never pass through Float. Width
and component are declared metadata, checked against the actual array storage
before reads. Empty tables are valid until a selected read attempts an index.

Use the existing `Op.Private.array_count`/`Value.array_get` contract as the
reference for index checks. Negative or oversized indices yield
`E_ARRAY_RANGE`, `array/nth needs a non-negative whole length.` A nonnegative
native index at or above table length yields `E_ARRAY_RANGE`,
`Array index is outside its length.` Do not convert a large integer to Float
before checking it, clamp it, wrap it or multiply by width before validating
the row. After row validation the storage-size invariant makes width/component
address arithmetic safe. Wrong or unresolved host storage retains its existing
typed resolver diagnostic and cause. Authored path/span reporting follows the
existing packed diagnostic/provenance boundary.

Untaken `if`/`cond`/`case` arms and skipped loop rows do not prepare tables or
evaluate indices. Unconditional bad bindings and selected bad branches still
fail. A skipped sink lane still evaluates its selected gather. Zero iterations
perform no body preparation. Array/table/index arguments retain their original
left-to-right evaluation order.

The current instruction-major block order cannot promise the reference's first
failing lane when different lanes fail at different operations. For programs
with gather, reuse the existing `execute slot instruction first last` bodies
in lane-major order rather than adding a second arithmetic implementation.
For concrete immutable tables, independent Collect chunks may run in Parallel;
store each chunk's first diagnostic and return the lowest chunk/lowest lane
failure after joining. Do not return the first worker to throw. This also
preserves an earlier division/conversion/explicit error ahead of a later
gather failure. Ordered reductions/scans stay ordered. Lazy host/live captures
remain on the initial domain under the existing guarded-capture rule; no
worker resolves geometry, mutates state or touches a Session.

This is a correctness-first scheduling choice with a known per-lane dispatch
cost. Measure it before proposing selected-lane preflight or chunk/vector
optimization; eager preflight can change lazy error precedence. There is no
2× performance claim in this design.

## Text is an explicit additional scope

Name From Groups requires Text table reads, Text identity inputs and a guarded
Text output. At the initial audit the packed register/result path had no Text
bank. Its structured Core route remained correct, but numeric C.2 alone could
not close that compilation gap or establish a whole-node speed qualification.

After the numeric gather proof, add only Text leaf storage to the same typed
runner for that B.14 draft: Text constant/input/uniform,
gather and select, with Text-array Collect. Array preparation is shared. Strings
are immutable references copied into a fresh owned output array; bytes including
embedded NUL, invalid native UTF-8 and signed opaque encodings are not normalized.
There is no Text arithmetic, general Text intrinsic lowering or Text reduction
in this extension. Keep `Packed_ops.scalar_width` numeric: teaching it that
Text is a Float-width-one value would silently contaminate shader packing.
Use explicit register-kind/output-kind metadata for the narrow Text bank and
type-check instruction operands. Refuse all Text regions on the GPU.

This adds a typed bank, not new surface syntax or types, and reuses the existing
guarded execution, counts and collection machinery. Keep its implementation and
acceptance evidence separate from the numeric proof. Numeric gather does not
satisfy the Text need by itself.

## Counts, ownership and host boundaries

Table shape/length is independent of iteration-source count and origin.
Tables do not acquire zip-count equality simply because they share a geometry
producer, owner or name; CSR offsets and values remain distinct cardinalities.
Rebinding a table does not change the result count. Source producers, argument
capture traversal and strict qualification must include tables even when an
output expression converts them to Float.

Materialize/resolve a selected immutable table once per execution and share
that execution-local reference. Do not build per-lane `Value.array_get` boxes,
duplicate dense arrays, store live values in a global cache or retain cooked
Session handles past the existing execution lifetime. Host read contracts
currently determine whether a source returns a copy or a borrowed descriptor;
gather must not weaken that ownership contract.

Existing numeric borrowed columns may be reused where the table's original
residual/term and host proof are available. An SoA table needs one logical row
count, equal lane spans and validated offset/stride, using the existing column
guards. Do not invent a count proof from flattened buffer length. Direct
immutable arrays can be read without another copy. If a capture lacks a proven
column adapter, materialize once through the existing resolver instead of
adding a gather-only host callback.

Ordinary numeric source validation still refuses nonfinite table data according
to its existing materialization contract. Borrowing must not skip that check
or conceal a bad unused row which ordinary source resolution would reject.
Opaque raw attribute transfer remains separate; use existing checked/sanitized
attribute sources when a recipe needs validity masks. Computed gathers publish
finite numeric results. All results are private until successful completion;
errors preserve state rollback and do not attach a partial attribute/group.

## JavaScript and shader targets

The existing scalar `array_nth` primitive remains the surface oracle. Its current
JavaScript `count` helper converts BigInt through Number; audit the native-limit
edge explicitly rather than copying that conversion into gather. If the scalar
mirror disagrees there, fix the shared index validation once with a regression.
Emitted regions prepare typed
immutable table views and bounds-check BigInt indices before converting a proven
in-range address to Number. Integer tables use BigInt64Array; numeric tables use
Float64Array with explicit width; optional Text leaves use string arrays.
Branch guards and argument preparation order mirror native. Return/throw the
existing exact diagnostic rather than turning every bounds failure into
`E_KERNEL`; the production runtime currently maps a nonzero generic region
status to that code and needs a gather-specific diagnostic transport using its
existing failure mechanism. No native fallback or SOP web-export claim follows.

`tools/lisp/web_export.ml` currently serializes only scalar uniforms. Extend its
fixed-capture checks and data placement to array table captures, using data.bin
views for dense numeric tables and decimal integer transport. Keep changing
captures accurately refused by the current fixed-capture web contract. Update
runtime invocation and worker transport with table metadata; no function or
host descriptor may cross the worker boundary.

Central `Packed.gpu_refusals` and explicit Metal/WGSL emitters must refuse every
gather/preparation instruction, including constant-looking tables and kernels
whose final output is Float. Integer or optional Text captures are also refused.
Use an `E_GPU_FORM` reason shared by placement and emission. No GPU gather or
float32 approximation is in this round.

## Affected-file map

| Boundary | Files and necessary change |
|---|---|
| Canonical eligibility | `lib/flow/op.ml`, `op.mli`: canonical gather capability for existing array/nth; `workspace.ml`: allow invariant array argument plus typed index in packed bodies without allowing arbitrary array-dependent kernels. Ordinary declaration/body stays the oracle. |
| Region schema | `lib/flow_ir/core.ml`, `core.mli`, `packed.ml`, `packed.mli`: instruction aliases, operands, handle/register validation, printing and optional Text kinds. Existing scalar Core Array_nth is retained. |
| Compilation/captures | `lib/flow_ir/core_region.ml`: table expressions, preparation ordering, helper array arguments, constant folding, rebinding, guards; `core_lower.ml`: current $core/argument and Invoke argument plumbing must include array captures. |
| Fusion/qualification | `lib/flow_ir/core_fuse.ml`: remap table/preparation dependencies without zip fusion; `flow_ir.ml`: strict captured-producer recursion and placement; `region_snapshot.ml`: instruction printer; review cost placement for CPU-only gather. |
| CPU execution | `lib/flow_ir/packed.ml`: execution-local lazy tables, exact address checks, lane/error order, columns and output allocation; `core_exec.ml`: retain structured Array_nth and route Invoke through the same Packed runner. |
| Targets | `lib/flow_gpu/emit.ml`, `lib/flow_web/wgsl.ml`: explicit refusals; `lib/flow_web/js.ml`: preparation/gather and optional Text emission. |
| Actual web execution | `tools/lisp/web_export.ml`, `tools/web/runtime/runtime.js`, existing worker/region pool transport: typed table capture placement and exact failure transport. `prims.js` scalar nth/typed array classes are reused; no node primitive added. |
| Focused checks | New `lib/flow_ir/test_gather.ml` and dune stanza; extend existing web/GPU emitter tests and direct native-to-JS region proof; existing `test_uniforms`, `test_core_lower` for changing captured/Core arguments. |
| Existing recipes | Run `test_group_invert`, `test_name_from_groups` after explicit authored use; keep recipes unregistered until their own whole gates pass. Numeric foundations need no SOP production-code change. |
| Contract/review | `specification/core.md`, `flow.md`, reviewed public API snapshot and approved plan scheduling entry. Reuse current array/nth card/Set_arg projection, adding a nested map edit regression rather than new syntax. |

The map includes files needing audit, not permission to rewrite each one.
Neither the schema nor a benchmark should acquire a node-name special case.

## Minimal runnable acceptance matrix

One focused native gather test and one emitted-JavaScript comparison should cover:

1. Int values beyond 2^53 and min/max signed63, Float signed zeros/subnormals,
   Vec2/3/4, repeated/reversed/permuted indices, tiny/zero/32,769-row maps and
   optional Text exact bytes. Reference, structured Core, strict Packed and
   unfused/fused results agree; CPU domains 1/4/8 match bytes.
2. Table length shorter/longer than iteration sources, independent CSR table
   lengths, Cartesian clauses and skipped rows. Counts remain the source's
   count; no truncation, fabricated count proof or aliasing of tables.
3. Negative, table-length, maximum-int and oversized indices, empty selected
   reads, invalid conversion, bad table type/shape/descriptor and nonfinite
   ordinary sources. Selected code/message/cause and failure order match the
   reference; no index multiplication overflow or invalid memory access.
4. Untaken bad table/index branches, selected failures, unconditional bad let,
   table failure before index failure, and competing errors in different lanes
   and chunks. Assert earliest reference failure at every domain count, atomic
   failure/rollback and finite checks for skipped sink lanes.
5. Captured arrays through records/aliases/helpers, actual Source resolution,
   Core $core/argument binding, changing live frames and template rebind. A
   counted resolver proves once-per-selected-execution materialization, no
   untaken resolution, initial-domain host work and no stale cross-frame table.
6. Proven borrowed columns versus ordinary arrays, nontrivial stride/offset,
   wrong lane count/span and unchanged source bytes; computed table producers
   compile strictly and unsupported captures refuse without interpreter retry.
7. Direct Js.region and actual exported rt.invoke exact integer/table/diagnostic
   transport, plus central/Metal/WGSL E_GPU_FORM refusal for Int- and Float-output
   kernels. Add existing array/nth nested map card/Pos1 edit proof.

After review/implementation, use the shared check launcher for focused
Flow/Graph/IR/GPU/Web/tools/dependency/API gates. Retain any failing whole-node
benchmarks. Measure numeric gathers and the optional Text assignment against
simple native indexed loops at one million rows, reporting machine, OCaml/profile,
grain, domains, wall time and initial-domain allocation caveats. Only then retry
the existing whole Group Invert/Name From Groups gates; no passing microbenchmark
substitutes for either complete port.
