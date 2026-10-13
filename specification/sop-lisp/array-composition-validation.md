# C.6 array composition validation

This extends the existing concat/slice primitives to invariant packed lookup
tables for all six physical arrays: Int, Float, Vec2, Vec3, Vec4 and Text.
The ordinary standalone Core copy operations remain the same. No new tag,
instruction, primitive census entry, public API or dependency was introduced.
It does not implement geometry repetition or qualify a whole SOP port.

## Implementation and discovered shared defects

Core_region uses the existing selected Array_prepare for canonical invariant
concat/slice. Its checked term preserves argument order, bounds, copying and
captured source reads. The same path admits invariant array/count as an exact
lazy Int uniform, needed by composed tables with changing source lengths.
Expressions referencing a current kernel parameter remain refused by the
region tier. Composed sources acquire no invented owner/count origin.

Both new composition and the existing invariant array-If shortcut previously
captured helper-local terms using the outer function's bindings. The shared
invariant_value helper now selects the active callable's own immutable captures.
Three checked-closure regressions keep outer data=[7] while the supplied helper
owns nine values of9. Concat returns9, array-If returns9/11 by time and composed
count returns18. The fixture partially binds a checked Fn parameter through the
existing compiled_function API. Graph-local shadowing, Fn graph inputs and
escaping Fn results remain refused; replacing a statically specialized known
helper is not a valid way to supply a different callable.

JavaScript's argument-free region Invokes formerly selected fixed metadata even
when their source/captures read frame facts. Each CPU Invoke now also uses the
existing scoped source/uniform frame-dependency checks to select real plans.
This covers fixed-length changing contents as well as changing cardinality.
Fixed regions keep their static metadata path; GPU Invokes retain their route.
No oracle outputs, artificial arguments or runtime metadata shims supply the
tests' source arrays. Scope-specific helper and count captures execute through
the actual emitted Core/region programs and runtime worker pool.

Graph defaults now construct Array Vec4 with the existing array/vec4 and Array
Vec2 with the existing map/Float array form. Both are checked through Add_node.

## Actual runnable coverage

Native primitive checks cover copying, input ownership, six tags, counts
0/1/13/4097/5001/32769, empty-at-end slices, concatenation order, signed native
Int bounds and values above2^53, signed zero, subnormal values, NUL/all256 bytes
and UTF8. Bounds/mixed-bank refusals retain their existing diagnostics.

Standalone Core, strict Executor, hoisted and directly nested gather tables
match reference bytes. Direct Packed qualification runs fusion on/off at
domains1/4/8. Host arrays change lengths/content13→3→0→13; selected missing,
cancelled, malformed/nonfinite source failures, table/index/alias order, empty
Product/Zip, untaken branches, caller-state rollback and source count origins
are checked. Scoped callable regressions run direct Packed/Core/Executor and
reference at counts0/13/32769, fusion on/off and domains1/8. Packed scratch blocks
are1024 elements; no fictitious configurable-grain claim is made.

The actual Node runtime executes51 programs over six frame settings with pools
null/1/8: all30 six-type composition forms, eight selected-error forms, one
fixed-count changing-source control and12 scoped-helper cases. Inputs come from
emitted producers; native reference results are comparison oracles only. Raw
Text is compared by reversible bytes. Primitive copy/malformed-bank tests and
shared WGSL/GPU refusals also pass. This is CPU JavaScript/worker evidence, not
a new SOP/browser geometry export claim.

Graph tests cover all typed cards, positional sockets, direct bounds/array
edits, nested Fn projection, Add_node defaults, save/reparse and atomic malformed
edits. Ordinary compiler/Web/GPU/graph/Flow checks retain their previous cases.

## Terminal gates and retained failures

Focused80564 EXIT0:
/tmp/rays-c6-array-composition-focused10-20261013.log; @check, FlowIR, FlowWeb,
FlowGraph, FlowGPU and Flow runtest, dependency gate and public API gate.
Native79782 EXIT0: /tmp/rays-c6-array-composition-native-20261013.log,
@runtest-native, including renderer/export/runtime parity.
Final shipping84732 EXIT0:
/tmp/rays-c6-array-composition-ship-20261013.log; @all/@runtest/@smoke/diffcheck,
including43 standard files,1 custom-catalog executable and13 fixtures across
four frames and domains1/8, complete cooked-payload and render-command parity.

Initial63548 failed on unsupported inline array/count and incomplete browser
region metadata. IR31594 exposed invalid graph shadow/escaping-Fn fixtures;
IR67384 refused function-valued graph inputs.87162 caught a statically
specialized helper that cannot be replaced by changing its capture. Those
fixtures were repaired at the real checked callable boundary. Focus45183
passed the first complete six-type proof.
Subsequent18728/93027/8664 helper-browser checks exposed inappropriate physical
bulk inputs and missing argument-free preparation.10742 found an overbroad
all-regions-zero-arguments assertion.80564 passed after the narrow shared
per-region frame-dependency fix and actual dynamic-capture regressions.
All original logs remain; no comparison tolerance, fallback or primitive
contract was weakened. API, catalog and render snapshots are unchanged.

C.6's language gate is complete. Accepted ports stay16/128 (12.5%),112 remaining;
milestones advance24/60→25/60 (41.7%). No whole SOP is accepted by this foundation.
