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
