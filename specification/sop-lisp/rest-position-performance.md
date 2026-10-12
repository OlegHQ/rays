# Rest Position performance evidence

Rest Position remains an unregistered draft. Its native schema, parameter
edits, cache identity, errors and causes, exceptional stored planes,
compiled/reference output and domain/grain checks pass. The retained whole-node
timings below still include failures of the unchanged 2× port gate.

Measurements use Apple M1, OCaml 5.3.0, one million points, grain 4096 and
the median of three cold cooks in fresh sessions. The command is
`opam exec -- ./test_rest_position.exe --bench` from
`_build/default/lib/flow_sop`. Four-domain allocation counters cover the
initial domain only. Timings are microseconds in these tables; allocations
are bytes. Captured tables are retained, including failed attempts; available
complete logs are listed below. The borrowed-source baseline was captured by
benchmark session 69751.

| Version | Mode | Domains | Native µs | Lisp µs | Ratio | Native bytes | Lisp bytes |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Borrowed sources | Store | 1 | 10 | 35 | 3.500 | 11,488 | 38,872 |
| Borrowed sources | Store | 4 | 60 | 58 | 0.968 | 11,720 | 39,104 |
| Borrowed sources | Extract | 1 | 43 | 57 | 1.320 | 11,504 | 43,648 |
| Borrowed sources | Extract | 4 | 31 | 52 | 1.677 | 11,736 | 43,112 |
| Borrowed sources | Swap | 1 | 72 | 62 | 0.861 | 11,720 | 46,888 |
| Borrowed sources | Swap | 4 | 32 | 67 | 2.097 | 11,952 | 47,120 |

The borrowed-source implementation is `2002db78`, with its separate reviewed
API snapshot `97c1c610`. This removes the former dense attribute interleaving,
hashing and copying. The native operation transfers immutable storage, including
NaN payloads and infinities; computed numeric maps retain nonfinite refusal.

The lazy session/body-error change is `edae8274`. Its first timing failed,
then two unchanged-code quiet repeats were predetermined. Both complete repeats
also failed some cases; none of the three tables establishes the port gate.

| Trial | Mode | Domains | Native µs | Lisp µs | Ratio | Native bytes | Lisp bytes |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| First | Store | 1 | 18 | 30 | 1.658 | 11,488 | 37,560 |
| First | Store | 4 | 48 | 37 | 0.776 | 11,720 | 37,792 |
| First | Extract | 1 | 29 | 44 | 1.521 | 11,504 | 41,712 |
| First | Extract | 4 | 23 | 32 | 1.396 | 11,736 | 41,944 |
| First | Swap | 1 | 27 | 57 | 2.096 | 11,720 | 46,632 |
| First | Swap | 4 | 29 | 57 | 1.975 | 11,952 | 46,096 |
| Repeat 1 | Store | 1 | 37 | 24 | 0.652 | 11,488 | 37,560 |
| Repeat 1 | Store | 4 | 17 | 47 | 2.736 | 11,720 | 37,792 |
| Repeat 1 | Extract | 1 | 37 | 64 | 1.724 | 11,504 | 42,480 |
| Repeat 1 | Extract | 4 | 26 | 36 | 1.385 | 11,736 | 41,944 |
| Repeat 1 | Swap | 1 | 18 | 29 | 1.592 | 11,720 | 45,864 |
| Repeat 1 | Swap | 4 | 34 | 59 | 1.746 | 11,952 | 46,096 |
| Repeat 2 | Store | 1 | 14 | 33 | 2.356 | 11,488 | 37,560 |
| Repeat 2 | Store | 4 | 18 | 44 | 2.434 | 11,720 | 37,792 |
| Repeat 2 | Extract | 1 | 20 | 44 | 2.202 | 11,504 | 41,712 |
| Repeat 2 | Extract | 4 | 35 | 132 | 3.769 | 11,736 | 41,944 |
| Repeat 2 | Swap | 1 | 76 | 63 | 0.828 | 11,720 | 46,632 |
| Repeat 2 | Swap | 4 | 33 | 66 | 1.993 | 11,952 | 46,096 |

Logs: `/tmp/rays-rest-lazy-session-bench.log`,
`/tmp/rays-rest-lazy-session-repeat-1.log`,
`/tmp/rays-rest-lazy-session-repeat-2.log`.

Subsequent changes each received one quiet measurement. Source forcing is
`5e696b0d`, removing eager default state construction and avoiding temporary
state for concrete host sources. Cooked handles is `58846c82`, removing unused
snapshot nodes for already-cooked outputs. Prepared reuse is `7b05a97f`, reusing
the compiled body when its resolved geometry graph is physically unchanged.
Its live/state regression also fixed the wrapper's missing Input dependency.

| Version | Mode | Domains | Native µs | Lisp µs | Ratio | Native bytes | Lisp bytes |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Source forcing | Store | 1 | 13 | 25 | 1.944 | 11,488 | 34,648 |
| Source forcing | Store | 4 | 26 | 43 | 1.651 | 11,720 | 34,880 |
| Source forcing | Extract | 1 | 17 | 36 | 2.097 | 11,504 | 38,592 |
| Source forcing | Extract | 4 | 26 | 62 | 2.364 | 11,736 | 38,824 |
| Source forcing | Swap | 1 | 27 | 32 | 1.186 | 11,720 | 42,536 |
| Source forcing | Swap | 4 | 11 | 38 | 3.457 | 11,952 | 42,768 |
| Cooked handles | Store | 1 | 13 | 38 | 2.944 | 11,488 | 34,368 |
| Cooked handles | Store | 4 | 24 | 58 | 2.406 | 11,720 | 34,600 |
| Cooked handles | Extract | 1 | 30 | 60 | 2.000 | 11,504 | 38,800 |
| Cooked handles | Extract | 4 | 55 | 53 | 0.961 | 11,736 | 38,264 |
| Cooked handles | Swap | 1 | 24 | 45 | 1.871 | 11,720 | 41,696 |
| Cooked handles | Swap | 4 | 24 | 72 | 3.020 | 11,952 | 41,928 |
| Prepared reuse | Store | 1 | 15 | 49 | 3.270 | 11,488 | 33,040 |
| Prepared reuse | Store | 4 | 58 | 41 | 0.708 | 11,720 | 33,272 |
| Prepared reuse | Extract | 1 | 27 | 46 | 1.708 | 11,504 | 37,472 |
| Prepared reuse | Extract | 4 | 39 | 57 | 1.466 | 11,736 | 36,936 |
| Prepared reuse | Swap | 1 | 27 | 68 | 2.522 | 11,720 | 40,368 |
| Prepared reuse | Swap | 4 | 25 | 65 | 2.590 | 11,952 | 40,600 |

Logs: `/tmp/rays-rest-source-forcing-bench.log`,
`/tmp/rays-rest-cooked-handles-bench.log`,
`/tmp/rays-rest-prepared-reuse-bench.log`. Displayed times are rounded; ratios
use the original measurements. At this scale, quiet cold-cook timings still
vary substantially, so a passing case does not replace a failed complete gate.

## Wrapper profiling

The test-only `--profile` mode repeatedly clears the session and cooks Swap
for eight seconds. The loop completed 357,934 cooks, with a three-second OS
sample attached; no dense plane work appeared in the sampled execution. Its largest
symbolized leaves included association-list comparison, prepared Core statement
execution and source/session allocation. This is diagnostic evidence, not a
speed-gate trial. Logs: `/tmp/rays-rest-wrapper-profile-run.log`,
`/tmp/rays-rest-wrapper-sample.txt`.

Temporary scoped `Gc.allocated_bytes` probes then attributed one Swap cook:

| Stage | Allocated bytes | Scope |
| --- | ---: | --- |
| Value lane | 848 | Lane construction and resolution |
| Body resolution | 1,440 | Includes value lane and diagnostic printing |
| Body Session creation | 1,568 | New uncached inner session |
| Core execution | 23,640 | Compiled host/source statements |
| Body Session cook | 31,256 | Includes Core execution |

A second probe measured five `sop/has_attr` host statements at 1,040–1,136
bytes each and three attribute-write host statements at 3,000/3,392/3,304
bytes. Probe printing increases enclosing allocations, so the second Core
total is not compared with the first. All temporary production probes were
removed before focused validation. Logs: `/tmp/rays-rest-allocation-profile.log`,
`/tmp/rays-rest-source-allocation-profile.log`.

The measured fixes avoid the value lane only when the checked body has no
states, drives or frame nodes, and extend the existing state-free host forcing
path to nested source descriptors with recursively concrete leaf fields. Nested
descriptors reach the resolver unchanged. Residual fields, supplied evaluator
state and element environments retain the ordinary transactional path. Frame,
type, cause and unresolved-source checks remain in the shared boundary.

Focused request 84596 exited 0 for Flow, FlowSOP, the Rest and Group Invert
drafts, API stability and dependencies. It includes nested descriptor modern/
legacy representation, wrong output type, cause, invalid-frame and supplied-
state checks, plus the existing state rollback, body drives and context seed
regressions. No public declaration changed. Log:
`/tmp/rays-nested-source-static-lane-focused.log`.

The single quiet measurement after these fixes (request 76413, exit 0) still
fails the complete 2× gate. No unchanged-code repeat was taken.

| Mode | Domains | Native µs | Lisp µs | Ratio | Native bytes | Lisp bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Store | 1 | 42 | 125 | 2.977 | 11,488 | 32,168 |
| Store | 4 | 60 | 52 | 0.869 | 11,720 | 32,400 |
| Extract | 1 | 25 | 46 | 1.838 | 11,504 | 35,664 |
| Extract | 4 | 23 | 42 | 1.833 | 11,736 | 35,896 |
| Swap | 1 | 27 | 49 | 1.814 | 11,720 | 39,928 |
| Swap | 4 | 20 | 45 | 2.277 | 11,952 | 39,392 |

Log: `/tmp/rays-rest-nested-source-static-lane-bench.log`. The allocation
reduction is less than 2 KB per cook compared with prepared-body reuse. The
larger remaining source/session cost still needs a measured shared fix;
Rest Position stays unregistered.

## Repeated cooked-handle validation

A scoped single-cook diagnostic then found five validations of the same typed
geometry handle, id 0, in default Swap. Each Source force allocated 512 bytes
(528 on the first call), including temporary counter bookkeeping. There were
no image or other cooked-handle validations. This bounds the possible saving
at less than 2 KB; it does not explain the complete remaining wrapper cost.
All observers were removed. Log: `/tmp/rays-rest-cooked-handle-profile.log`.

The compiler now reuses checked immutable cooked handles in its existing
branch-scoped cache, keyed by exact type and handle id. Residuals use a separate
key variant. Existing branch copies retain dominance: a local initialized in
one arm does not escape into another arm or an unconditional later use. Each
execution still resolves its selected handles against that execution's fresh
host table. Named Source and Host_source queries are never memoized by this
change.

Semantic tests passed before the compiler change. The optimized tests assert
one check each for same-id geometry and image captures, independent repeated
Bool host queries, exact lazy unknown-handle errors and causes, changing live
selection, and a handle used both inside and after a branch. Fresh execution
continues to validate the selected handles. The tests use a host-resolved Bool
selector; the ordinary language prohibition on top-level time-selected
geometry is preserved.
