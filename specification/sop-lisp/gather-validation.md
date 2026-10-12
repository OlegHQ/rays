# Numeric gather evidence

Scope: invariant Int/Float/Vec2/3/4 tables in existing `array/nth` numeric
kernels. Text banks, lane-dependent tables and GPU execution are excluded.
No whole SOP registration or C.2 completion tick follows from these results.
The declaration API was reviewed separately in `6bc7f726`.

The combined launcher request 1029 passed on October 12, 2026:

```sh
opam exec -- _build/default/tools/check.exe \
  @lib/flow_ir/runtest @lib/flow_web/runtest @lib/flow_graph/runtest \
  @lib/flow_gpu/runtest @tools/lisp/test/runtest \
  @test/dependency_gate @tools/api_manifest/runtest
```

Log: `/tmp/rays-gather-full6.log`. Native checks cover exact signed63 extremes
and values beyond 2^53, Float signed zero/subnormals, all vector widths,
zero/tiny/multiblock maps, fused/unfused programs, aliases, typed helper array
arguments, nested records, changing frame-built captures, template rebinding,
independent Product/Zip counts and ordered sum/fold/scan. Reference, strict
Packed and structured Core agree at one/four/eight domains. Captured host
tables resolve on the initial domain once per selected execution. Checks retain
empty/untaken laziness, source-before-index errors, first failing lane/chunk,
wrong/unresolved/nonfinite sources, malformed handles and guard dominance,
iteration skips, discarded sinks, strided borrowed input ownership, strict
unsupported-producer refusal and state rollback after a resolver advances state.

The JavaScript proof runs emitted regions through the actual runtime and
one/eight-worker pools, comparing typed-array bytes with native results. It
checks bounds at negative, row-count, native-limit and signed63-limit indices,
competing errors, preserved cause, malformed spans and nonfinite unused rows.
The shared scalar BigInt index conversion checks the native ceiling before
converting a proven nonnegative value to Number. The exporter cram builds a
real `.rays` drawing, reads its `data.bin` table views and executes its actual
frame and runtime at one/eight workers. Metal/WGSL refuse all preparations and
reads through the shared `E_GPU_FORM` boundary. Existing array/nth cards retain
their positional edit gesture, including inside a map function zone.

Follow-up request 40365 passed the IR/Web/Graph/GPU, API and dependency checks,
including unused-alias and earlier/later index-error ordering. The overall
request exited one because the CLI catalog baseline changed with the Rename
Edge Group port and the new integer exporter fixture used a reserved binding
name. Both test inputs were corrected. Follow-up request 11963 passed
`@tools/lisp/test/runtest @lib/flow/runtest`, including the actual exported
integer table, signed63 bytes and one/eight-worker frames. Its log is
`/tmp/rays-gather-final-export.log`; the checked CLI baseline comes from the
fresh request 40365 tool output. No compiler changes followed the combined gate.
Live reference evaluation concretizes each evaluated term, including unused
let binding values; array preparation retains that evaluation position.

## Baseline measurement

Quiet request 45613 exited zero. Command:

```sh
opam exec -- _build/default/lib/flow_ir/test_gather.exe --bench
```

Log: `/tmp/rays-gather-numeric-bench.log`. Apple M1, OCaml 5.3.0, one million
output rows, 1,021-row immutable table, ascending integer indices modulo 1,021,
median of three unchanged-code samples. Direct strict Packed uses 1,024-row
blocks and 16,384-row chunks; no placement/profile selector is involved. Each
case first asserts byte equality against the simple native indexed loop.
GC is completed before each sample. Allocations at four domains observe the
initial domain only and are not a total worker allocation measurement.
This binary predates the subsequent shared typed-runner arithmetic optimization.

| Type | Domains | Native seconds | Packed seconds | Ratio | Native allocated bytes | Packed allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Int | 1 | .003837 | .043449 | 11.324 | 8,000,152 | 13,543,720 |
| Int | 4 | .003859 | .012390 | 3.211 | 8,000,152 | 9,443,960 |
| Float | 1 | .005906 | .042894 | 7.263 | 8,000,120 | 13,543,720 |
| Float | 4 | .005910 | .011988 | 2.028 | 8,000,120 | 9,444,712 |
| Vec2 | 1 | .006272 | .055163 | 8.795 | 16,000,120 | 22,657,296 |
| Vec2 | 4 | .006350 | .015617 | 2.459 | 16,000,120 | 17,839,368 |
| Vec3 | 1 | .006816 | .068316 | 10.023 | 24,000,120 | 31,677,080 |
| Vec3 | 4 | .006753 | .019408 | 2.874 | 24,000,120 | 25,994,664 |
| Vec4 | 1 | .007984 | .082611 | 10.347 | 32,000,120 | 40,696,864 |
| Vec4 | 4 | .007665 | .024344 | 3.176 | 32,000,120 | 34,397,816 |

Every baseline row exceeds 2× the simple loop. This is retained cost evidence,
not a speed qualification or permission to register a whole-node recipe.
Computed gathers preserve checked lane/error semantics; raw unchanged attribute
transfer uses its separate existing borrowed-storage boundary.
