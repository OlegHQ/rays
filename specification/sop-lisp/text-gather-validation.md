# Text gather evidence

This extends the numeric gather foundation `8319b320` with immutable Text
leaves. It does not register a SOP recipe. Public instruction declarations
were reviewed and accepted separately in `03437c73`. The measured Text
assignment below exceeds the whole-node speed threshold; no whole-node speed
qualification follows.

The instruction additions are `Text_const`, `Text_input`, `Text_uniform`,
`Text_gather` and `Text_select`. `Array_prepare` admits invariant Text arrays.
Text registers have a separate bank and Collect output storage; neither
`Packed_ops.scalar_width` nor the Value/Ty representation changes. Numeric
instructions, Float column sinks, reductions and GPU targets reject Text
registers. Unsupported Text transformations retain structured Core where
eligible; an explicit packed compilation request refuses them.

Native output arrays are fresh and share immutable source strings. Source and
table counts remain independent. Cartesian iteration leaves later sources
unevaluated after an empty outer source. Skips omit the body, while selected
reads preserve argument preparation, exact integer bounds, lane/chunk error
order, cause and transaction rollback. All host resolution stays on the
initial domain.

JavaScript retains the reversible byte transport committed in `082fb672`.
Workers stage immutable tables once per execution, produce only their kept
chunk's strings, and release staged references when all chunks finish.
The caller assembles a fresh result without numeric storage or Unicode
normalization. Numeric worker buffers remain shared typed arrays.

Initial typecheck request 17494 passed. Focused request 25951 passed Flow and
IR, including exact native byte strings, Text identity/uniform/select/gather,
typed helpers, empty Cartesian-source laziness and strict Core at one/four/eight
domains. The request exited one because the old JavaScript frame shim has no
region service; its Text leaf expectations are updated to exercise structured
frame printing, while `test_gather` exercises actual runtime regions/workers.
Further checks add two-source indexed assignment, changing captures/rebinding,
fusion, Product/skips, source errors and rollback. Request 46783 passed Flow,
IR, Graph, GPU, API and dependency checks. Its sole feature failure was the
JavaScript quoting of native Text inside a region-source fixture and packed
`Raise`: OCaml `%S` octal escapes are not valid strict JavaScript escapes.
Both now reuse the existing reversible Text codec rather than changing native
strings or expected diagnostics.

Final follow-up 60211 passed IR, Web, tools Lisp and API checks. Log:
`/tmp/rays-text-gather-final2.log`. The actual runtime and one/eight-worker pools
check immutable Text sources, constants, selected copying, lookup tables with
all 256 byte values, typed bounds, first failing lane/chunk, arbitrary-byte
causes and skips across chunk boundaries. Existing numeric region goldens and
worker proofs remained unchanged. The old frame shim exercises structured
Text printing; actual Text regions execute in the runtime tests, not in a
stand-in region interpreter.

The exported `.rays` fixture checks Text table transport, an actual drawing
frame, exact invalid-byte/NUL results and one/eight workers. The runtime fixture
also checks all byte values, bounds and competing errors. The graph regression
edits the existing `array/nth` index card inside a typed Text map.

Follow-up 31650 passed `@tools/lisp/test/runtest`, including the exported
Cartesian Text assignment with two independent sources and skips crossing
worker chunk boundaries. Actual runtime execution with one/eight workers
checks the 32,767 kept strings exactly. Log:
`/tmp/rays-text-gather-product-export.log` (the launcher reused the cached
successful target). Root follow-up 93275 passed the full native gate plus
catalog, API, source/menu, CLI and current tools fixtures. No further Text
source changes followed those checks.

## Cost check

Quiet request 90509 exited zero. Command:

```sh
opam exec -- _build/default/lib/flow_ir/test_gather.exe --bench-text
```

Log: `/tmp/rays-text-gather-bench.log`. Apple M1, OCaml 5.3.0, one million rows,
four immutable strings including invalid UTF-8 and NUL, negative indices
selecting the original Text source every fifth row. Direct strict Packed
Collect uses 1,024-row blocks and 16,384-row chunks. The measurements retain
three-sample medians after major GC; exact native result bytes pass before
each domain's samples. Allocations at four domains observe the initial domain
only and do not total worker allocations.

| Domains | Native seconds | Packed seconds | Ratio | Native allocated bytes | Packed allocated bytes |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | .006517 | .093700 | 14.377 | 8,000,168 | 97,162,496 |
| 4 | .006347 | .026132 | 4.117 | 8,000,168 | 31,549,528 |

Both rows exceed 2× the native indexed loop. These retained costs do not
qualify or authorize registration of Name From Groups or any other whole
node. The feature provides checked Text lookup execution, not a speed claim.

## Ordered guard allocation follow-up

After feature commit `d2cd9030` and Float-bank span commit `2870ff72`, the
optional `test_gather.exe --profile-text` mode repeatedly forces the same
million-row assignment for eight seconds on one domain. Request 55499 exited
zero: 62 forces in 8.031484 seconds, averaging 97,170,221 allocated bytes per
force. Log: `/tmp/rays-text-guard-profile-before.log`.

The ARM object listing `/tmp/rays-text-guard-baseline-arm.txt`, produced with
`otool -tvV`, shows a 40-byte predicate closure allocation inside each typed
`Guarded` invocation (`sub x27, x27, #0x28`). Its scanner reference is promoted
to the stack. The predicate's numeric reads and truth comparison are unboxed;
this evidence does not support a numeric truth-boxing explanation. Gather and
Text Collect execute each instruction for one lane at a time to preserve the
first selected error, so that closure is repeatedly constructed.

OS sample request 30748 also exited zero, writing
`/tmp/rays-text-guard-profile-before.sample.txt`. Its capture overlaps the
following benchmark's major GC, so its aggregate sample proportions are not
an exclusive profile of execution. The same run retained this median table;
use the earlier quiet 90509 table above as the clean feature baseline rather
than treating these sampled timings as a fresh uncontaminated baseline.

| Domains | Native seconds | Packed seconds | Ratio | Native allocated bytes | Packed allocated bytes |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | .010944 | .092999 | 8.498 | 8,000,168 | 97,170,312 |
| 4 | .006246 | .025880 | 4.143 | 8,000,168 | 31,552,264 |

The shared change moves the predicate helper to chunk scope and directly
checks a single-lane `Guarded` invocation before the span scanner. It checks
only that lane, short-circuits nested predicates in their original order and
dispatches the existing instruction body. Multi-lane spans and their cache
remain unchanged. The rebuilt ARM listing
`/tmp/rays-text-guard-after-arm.txt` shows the single-lane predicate call and
body dispatch without the former per-invocation closure allocation.

Combined focused request 92200 exited zero:

```sh
opam exec -- _build/default/tools/check.exe \
  @lib/flow_ir/runtest @lib/flow_web/runtest @lib/flow_sop/runtest \
  @lib/flow_sop/point_jitter_draft @lib/flow_sop/group_delete_draft \
  @lib/flow_sop/rename_attributes_draft @lib/flow_sop/set_color_draft
```

Log: `/tmp/rays-text-one-lane-guard-focused.log`. The added native regression
alternates nested Text guards across 32,768 rows and reaches a selected error
only at row 32,768 in a 32,769-row input. An invalid read in an untaken arm
stays unevaluated. Both fusion settings and one/four/eight domains match
reference bytes or the exact diagnostic code/message/cause. Existing numeric
gather, reductions, lazy errors, Text byte transport, actual JavaScript workers
and current SOP recipes also pass. No public API changed.

Quiet after-change request 99638 exited zero, using the same `--bench-text`
command and measurement protocol as 90509. Log:
`/tmp/rays-text-one-lane-guard-bench.log`.

| Domains | Native seconds | Packed seconds | Ratio | Native allocated bytes | Packed allocated bytes |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | .006353 | .079464 | 12.508 | 8,000,168 | 17,180,608 |
| 4 | .006478 | .022348 | 3.450 | 8,000,168 | 10,388,728 |

The one-domain allocation decreases by about 80 MB per force, consistent with
removing the repeated 40-byte predicate closures. Both speed ratios still
fail 2×. The original feature and sampled follow-up tables remain above;
this change does not qualify a whole port. The optional `--profile-text`
mode now ends after its repeated force loop, so later median samples cannot
spill into a subsequent OS capture. No production profiling hooks remain.

## Remaining dispatch profile

After guard commit `dba8d974`, unchanged-binary profile request 5676 completed
94 forces in 8.041067 seconds, averaging 17,180,515 bytes per force. Its OS
sample started near process exit and captured only 173 main-thread samples;
the short capture is retained at `/tmp/rays-text-dispatch-profile.sample.txt`
and is not presented as a five-second profile.

Follow-up 40879 starts the OS sample immediately after the profile marker in
one tool orchestration. Force loop and five-second OS sample 56725 both exited
zero. The full loop performed 77 forces in 8.003143 seconds, averaging
17,180,516 bytes per force. Logs are
`/tmp/rays-text-dispatch-profile-full.log` and
`/tmp/rays-text-dispatch-profile-full.sample.txt`. These sampled loop timings
are attribution evidence, not another quiet speed-gate table.

The full capture contains 2,724 main-thread samples. Explicit C-call subtrees
account for 344 samples under `Array.blit`/`caml_array_blit` and 142 under
`Array.fill`/`caml_array_fill`, including their barrier and thread-local work:
about 18% combined. Counting only leaf wrapper samples misses that work.
Conversely, the sampler shows some OCaml fill/blit ancestors above direct
Text bank stores; those ambiguous unwind paths are excluded from this
attribution. The largest leaf count is still typed instruction execution
(946 samples). Neither these counts nor the unboxed ARM predicate supports
attributing the remaining cost to numeric truth boxing.

This supports testing shared one-element stores in place of bulk fill/blit
calls, preserving the existing bulk path for longer spans. It does not
predict that such a cut alone will meet 2×. No subsequent executor change or
speed qualification follows from the profile itself.

The prepared follow-up uses three private typed fill helpers: a one-element
span writes directly to its Int/Float/Text bank; every other span retains
`Array.fill`. Constants, uniforms, frame values and accumulators share these
helpers. Contiguous `Int_input` similarly loads/stores one element directly
and retains `Array.blit` for longer spans. Float and Text inputs already use
direct typed stores. Existing finite checks and lazy uniform forcing remain
at their original call sites.

The roughly 18% sampled component is a ceiling for the work addressed by this
candidate, not a predicted end-to-end gain: bulk calls and their necessary
stores remain, and instruction dispatch is the largest measured component.
The added regression checks empty/single/block-tail/multi-block typed copies,
exact integers above 2^53, signed zero/subnormal Float bytes, arbitrary Text
bytes, and once-only initial-domain scalar uniforms at one/four/eight domains.
Source and tests are prepared while the Group Delete quiet window runs;
compilation, runnable proof and after-change timing remain pending.
## One-lane typed fill and copy measurements

Shared typed fills now directly store one lane for Int, Float and Text; longer
spans retain Array.fill. A contiguous one-lane Int input directly copies its
element; longer spans retain Array.blit. Request 35825 passed IR/Web and all
SOP/lowering checks. The regression covers empty/one/block/chunk boundaries,
exact large Int values, signed zeros, subnormals, byte Text, lazy initial-domain
uniform forcing and 1/4/8 domains. Existing error-order and untaken-arm cases
remain active.

Quiet request 92162 exited 0 with million-row native-byte preflight and the
same median-three force-only protocol. Domains 1: Native 0.006332 s / 8000168 B,
Packed 0.065951 s / 17211496 B, **10.416×**. Domains 4: Native 0.006226 s /
8000168 B, Packed 0.018644 s / 10396176 initial-domain B, **2.995×**. Compared
with 99638, Packed time fell from 0.079464/0.022348 s, roughly 17% in each
configuration. One-domain allocations rose 30888 B; the new local helpers
therefore do not claim allocation-free execution. Both unchanged 2× gates
still fail and no Text node is qualified. Log:
`/tmp/rays-text-one-lane-fill-bench.log`.

## Leading total-prefix experiment

The next candidate reuses the existing typed span executor for only the leading
proven-total instructions of Gather/Text Collect. The whitelist admits finite
constants, actual Int/Text array inputs or checked Int ranges, wrapping Int
arithmetic/bitwise operations, absolute value, exact comparisons/selections and
guards around these operations. Runtime input tags are inspected without
forcing additional values. A wrong tag stops batching instead of raising an
earlier error. Lazy uniforms/frame values, table preparation, indexing, float
loads/math, checked conversions/division/modulus/shifts, diagnostics and ordered
accumulators remain barriers. The entire suffix keeps reference lane order.

This avoids an error-cutoff algorithm: choosing the correct first diagnostic
would still allow later-row host resolution ahead of an earlier-row error.
Private total register writes have no such observable forcing or failure.
The new regression checks wrapping Int and native Text bytes across block/chunk
boundaries, malformed selected/untaken public-region storage and conflicting
row errors with fusion off/on and domains 1/4/8. Existing table forcing, rollback,
Product/skip, discarded sink and worker/export checks remain in the focused
suite. Request 69619 failed only the new fixture's nonexistent `int/abs`
spelling; the canonical `abs` declaration emits `Int_abs` for Int. Corrected
request 50119 exited 0 for IR, Web and FlowSop. The new malformed-storage and
earliest-row cases passed alongside existing source/cause/rollback and worker
checks. No public declaration changed.

Quiet request 72326 exited 0 using the same Apple M1 / OCaml 5.3.0 dev profile,
million-row native-byte preflight, block1024/chunk16384, strict Packed Collect,
median-three force-only protocol. No other build or timing process was active
before launch. The complete rows are:

| Domains | Native seconds / bytes | Packed seconds / bytes | Ratio |
|---|---|---|---|
| 1 | 0.006232 / 8,000,168 | 0.055121 / 17,211,544 | **8.845× FAIL** |
| 4 | 0.006342 / 8,000,168 | 0.015340 / 10,396,088 | **2.419× FAIL** |

Four-domain allocations observe the initial domain only. Compared with 92162,
Packed time fell from 0.065951/0.018644 seconds, approximately 16.4%/17.7%.
One-domain allocations rose 48 B and four-domain initial-domain allocations
fell 88 B; this change removes dispatch work rather than register-bank storage.
Both 2× gates remain unmet. This qualifies the shared semantic optimization,
not a whole Text node. Logs: `/tmp/rays-text-total-prefix-focused.log`,
`/tmp/rays-text-total-prefix-focused2.log`,
`/tmp/rays-text-total-prefix-bench.log`.

## Prepared-table incremental prefixes

The typed Collect executor extends its existing contiguous prefix per block.
After executing its previously proven-total instructions, it probes only tables
already published following successful type/storage/whole-table validation in
this execution. The first unresolved table remains at its original selected
row; the proof performs no lazy forcing, source resolution, validation, state
write, output publication or diagnostic. It may admit an already prepared
instruction, then a Text/Int/Float/vector read if its executed guard/index banks
prove every selected index in bounds. Inactive rows are not read. Each admitted
read uses the existing span executor before proof of the next instruction.

The first wrong tag, bad selected index, unknown capture or fallible operation
ends extension. The complete suffix remains lane-major, so an earlier row's
later table/cause failure still wins over a late bounds failure. Prepared cells
belong to one force and cannot carry a previous live table into the next force.
Concrete-table publication can safely be observed between workers; captured host
tables retain the existing initial-domain sequential forcing path. Source arrays
remain immutable, outputs private and ordered reductions/scans excluded.

The regression adds delayed-first-use, changed table contents/cardinality/live time
across repeated forces, and warmed-A late-bounds versus earlier-B raw-cause/state
rollback checks at block/chunk boundaries, with fusion off/on and domains1/4/8.
Existing type/finiteness, skip/Product, discarded sink, worker/export and numeric
parity proofs remain required. The Boolean proof adds a selected-index/guard
scan, and existing checked span reads remain; reduced dispatch may be offset by
this extra work. No speed prediction follows from static review.

Focused request67661 exited0 for `@lib/flow_ir/runtest @lib/flow_web/runtest
@lib/flow_sop/runtest`. The Text benchmark now prints full-precision timings
and an unrounded 2x verdict. Its million-row inputs, native-byte preflight,
median3 force-only protocol and one/four domains remain unchanged. Request97660
passed after that diagnostic change. Quiet request60246 completed both rows:

| Domains | Native seconds | Packed seconds | Ratio | 2x gate | Native bytes | Packed bytes |
| ---: | ---: | ---: | ---: | --- | ---: | ---: |
| 1 | 0.0063140392303466797 | 0.043770074844360352 | 6.9321829097911865 | FAIL | 8000168 | 17446008 |
| 4 | 0.0064108371734619141 | 0.012497186660766602 | 1.9493845066755922 | PASS | 8000168 | 10454744 |

The instruction trace shows all seven benchmark instructions are admitted once
the table has been published; it introduces no new math or lookup instruction.
Skipping an admitted preparation's already completed effect removes repeated
guard scans and table reads. The same full focused request56636 exited0;
quiet request4802 completed the same two rows after that refinement:

| Domains | Native seconds | Packed seconds | Ratio | 2x gate | Native bytes | Packed bytes |
| ---: | ---: | ---: | ---: | --- | ---: | ---: |
| 1 | 0.0064330101013183594 | 0.040699005126953125 | 6.3265880957675487 | FAIL | 8000168 | 17446008 |
| 4 | 0.0062489509582519531 | 0.011553764343261719 | 1.8489126287676458 | PASS | 8000168 | 10454216 |

Compared with baseline72326, Packed force time fell26.2% at one domain and
24.7% at four domains. Initial-domain allocations grew234,464 bytes at one
domain; four-domain counts exclude worker allocations. Apple M1 arm64,
OCaml5.3.0 development build, block1024/chunk16384, no concurrent builds or
benchmarks. Preparation cells remain execution-local. The last two-row baseline is72326:
Native/Packed 0.006232/0.055121 seconds (8.845×) at one domain and
0.006342/0.015340 seconds (2.419×) at four domains; both 2× failures remain.
The one-domain 2x failure remains; this improvement qualifies no whole Text
node. The separate integer-dispatch candidate remains unapplied. Logs:
`/tmp/rays-text-prepared-prefix-focused.log`,
`/tmp/rays-text-prepared-prefix-gather-focused.log`,
`/tmp/rays-text-prepared-prefix-bench.log`,
`/tmp/rays-text-prepared-prefix-trace-focused.log`,
`/tmp/rays-text-prepared-prefix-trace.log`,
`/tmp/rays-text-prepared-prefix-skip-ready-focused.log`,
`/tmp/rays-text-prepared-prefix-skip-ready-bench.log`.

Post-change `/usr/bin/sample` profile32859 covers3 seconds of the unchanged
one-domain `--profile-text` loop (handle83973, exit0). Its1,351 initial-domain
samples include267 executor,233 write-barrier,120 guard and43 bounds-proof
top-stack samples, with shared-array copying and GC also visible. These are
sampling counts, not benchmark percentages. The profile is diagnostic and
supplies no additional timing gate. Logs:
`/tmp/rays-text-prepared-prefix-profile.log`,
`/tmp/rays-text-prepared-prefix-sample.txt`. Scratch allocation and repeated
Text reference writes remain candidates for measurement; neither has changed.
