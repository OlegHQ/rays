# Web export measurements

## 2026-10-11 — Slice C native record boundary

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native executable, one
domain. Input: a record accumulator over 4,096 packed items, 30 changing
frames. One warmup, then the median wall time of three samples; allocated
bytes use `Gc.allocated_bytes`. No profiler was attached.

Build with `dune build lib/flow/test_workspace_eval.exe
lib/sop_catalog/flow_manifest.sexp`. Run from `_build/default/lib/flow`:

```sh
./test_workspace_eval.exe --bench-records
```

The baseline uses commit `00641a6f` in an isolated worktree with only the
benchmark's current `lib/flow/test_workspace_eval.ml` and its Dune test stanza
copied in. `--bench-records` exits before the normal test cases, so both runs
execute the same source and measurement against their own Flow library.

| Path | Wall seconds | Allocated bytes |
| --- | ---: | ---: |
| P1.5 native baseline | 0.076312 | 152,390,016 |
| Slice C native equality/coercion fixes | 0.058664 | 297,986,736 |

Wall time improved by about 23%; allocation grew by about 96%. This measures
the native evaluator boundary, not core loop execution. P1.6a must measure the
same input through a prepared core Executor after P1.7 and remove that
allocation regression before the phase review. No core performance claim is
made from these rows.

## 2026-10-11 — Deferred authored merge source tags

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native executable. One and
eight domains, grain 97. Eight copies of a box with 32 divisions per axis and
face groups, producing 98,304 primitives. Each sample cooks the same lowered
`sop/merge` with `:source_attribute "src" :source_base 10` in 20 fresh
sessions. One warmup sample, then median wall time of three samples, with
allocated bytes measured by `Gc.allocated_bytes`. No profiler was attached.

Build with `_build/default/tools/check.exe lib/flow_sop/test_merge_source.exe`.
Run from the repository root:

```sh
_build/default/lib/flow_sop/test_merge_source.exe --bench
```

The baseline ran before editing `lib/flow_sop/merge_source.ml`, with the same
new benchmark executable linked to the original two-merge implementation.
The replacement copies the geometry once and constructs only the additional
tag array. The normal test compares semantic geometry bytes (including
ordered attributes, groups and edge groups) against the original algorithm,
at one and eight domains, for fresh/existing tags, schema failures, an alias
of the internal tag, and an empty geometry. It also checks source ownership
and cancellation. `_build/default/tools/check.exe @lib/flow_sop/runtest`
passes without snapshot changes.

| Domains | Path | Wall seconds | Allocated bytes |
| ---: | --- | ---: | ---: |
| 1 | Two geometry merges | 0.138822 | 266,731,296 |
| 1 | One geometry merge | 0.071613 | 149,511,776 |
| 8 | Two geometry merges | 0.136539 | 290,884,728 |
| 8 | One geometry merge | 0.072171 | 160,389,592 |

On this input, one-domain wall time falls by 48% and allocation by 44%.
Eight-domain wall time falls by 47% and allocation by 45%; scheduling can
vary the pool's allocation count. This measurement covers the native SOP
cook and does not claim a browser or core-executor speedup.

## 2026-10-11 — Deferred private graph-pane split

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native executable in the
development profile, one domain. Input: a 2,001-node graph with a backward
wire every seventh node, a 1,000 × 700 viewport and an 11-point font. Frames
use five warmups and 100 measured iterations; creation uses five iterations,
repeated layout 20, and each command five. Values below are medians of three
process runs, with frame allocation measured by `Gc.allocated_bytes`. No
profiler was attached. Both paths use the same benchmark source.

Build and run from the repository root:

```sh
_build/default/tools/check.exe lib/pxui_graph/test_main.exe
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  _build/default/lib/pxui_graph/test_main.exe bench_scope_big
```

| Operation | Before ms | After ms | Before bytes/frame | After bytes/frame |
| --- | ---: | ---: | ---: | ---: |
| Initial `with_scope` | 21.802 | 22.151 | — | — |
| Repeated `with_scope` | 14.509 | 13.790 | — | — |
| Visible frame | 2.154 | 2.156 | 6,846,593 | 6,859,817 |
| 16 × 16 frame | 0.013 | 0.012 | 49,009 | 49,009 |
| `Point_all` | 0.392 | 0.380 | — | — |
| `Set_arg` edit | 27.289 | 27.192 | — | — |

State, commands and painting move into private modules; frame gestures stay
in `Scope_pane`. Moved bodies match the original byte for byte, public API
manifests compare equal, and all 455 graph-pane checks and the dependency
gate pass. Two tiny coordinate transforms remain local to painting and
gestures: exposing them across the opaque development-build boundary added
36,104 bytes per visible frame and 1,344 bytes per tiny frame. Keeping them
local reduces that increase to 13,224 bytes (0.19%) in the visible frame and
zero in the tiny frame. The timing differences are small; this is an
organizational change, with no claimed rendering speedup or native pixel
comparison.

## 2026-10-11 — Deferred private editor environment split

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native executable in the
development profile, one domain. Input: the existing 200-node switch/point
workspace benchmark, 1,200 × 760 logical points, default editor font. The
benchmark enters the object graph and measures 200 drag frames, one undo
frame and 200 alternating literal edits with their full editor updates. It
reports each row's median wall time and allocated bytes per frame. Rows
below are medians of three separate process runs before and after; no
profiler was attached. The executable and inputs are unchanged.

```sh
_build/default/tools/check.exe tools/bench_rays_editor.exe
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  _build/default/tools/bench_rays_editor.exe 200
```

| Operation | Before seconds | After seconds | Before bytes/frame | After bytes/frame |
| --- | ---: | ---: | ---: | ---: |
| Drag frame | 0.001830816 | 0.001840830 | 6,021,502 | 6,021,502 |
| Undo frame | 0.002362967 | 0.002382994 | 6,796,312 | 6,796,312 |
| Literal edit and frame | 0.001848936 | 0.001870871 | 5,491,403 | 5,491,403 |
| Literal edit excluding cook time | 0.001747847 | 0.001773119 | 5,491,403 | 5,491,403 |

View composition, state and source-file handling move into private modules,
with frame coordination and resource lifetime in `Environment`. All moved
bodies match the original byte for byte and public API manifests compare
equal. Window-free workspace shell/source, editor logic, scene synchronization,
text-pane and dependency checks pass. The source tests verify recovery
ownership, flush-on-close, preservation of unsaved edits, failed-write retry,
corrupt recovery refusal and reload behavior using writable temporary paths.
Some unrelated shell fixtures attempt recovery writes under the runner's
read-only home directory and report the existing autosave refusal.

Allocation is unchanged in every measured operation. Timing varies by
0.5–1.5% on this input; no speedup or native pixel comparison is claimed. An
initial after series overlapped test compilation and was discarded for the
timing comparison; the recorded series ran with no concurrent build or test.

## 2026-10-11 — Deferred scene index-length validation

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native executable in the
development profile, one domain. Input: 4,096 valid prepared Scene3 entries
per call, 2,000 calls per sample. One warmup, then median wall time and
`Gc.allocated_bytes` of three samples. No profiler was attached. The same
benchmark runs before and after adding the bounded index-length predicate.

```sh
_build/default/tools/check.exe lib/scene_execution/test_main.exe
_build/default/lib/scene_execution/test_main.exe bench_prepared_scene3
```

| Path | Wall seconds | Allocated bytes |
| --- | ---: | ---: |
| Unbounded index-length multiplication | 0.162403 | 66,048,096 |
| Bounded shared index-length validation | 0.168314 | 66,048,096 |

The new regression fails on the original code: an index count of
`1 lsl (Sys.int_size - 2)` is accepted with an empty index buffer because
multiplication by four wraps. The fix bounds the count before multiplication
and shares that predicate between preparation, render preflight, upload and
coalescing. Prepared validation now covers all family/sample combinations,
typed refusals and array/byte ownership. The existing mock GPU-vertex test
also checks malformed index buffers are refused before uploading anything,
with the release callback called exactly once. Both tests and the dependency
gate pass. Preparation time rises about 3.6% on this input; allocation is
unchanged. This measures validation alone and makes no GPU timing or pixel
claim.

## 2026-10-11 — Deferred Scene3 constant clear fields

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native executable in the
development profile, initial domain only. The unchanged cold-packing benchmark
stages 100,000 points with normals and indices, at 800 × 600 logical points.
Seven cold samples, no explicit warmup; median wall time and allocated bytes
are reported. No profiler was attached and no concurrent build/test ran during
either measurement. Each sample constructs its mesh and scene before timing.

```sh
_build/default/tools/check.exe tools/bench_scene3_packing.exe
_build/default/tools/bench_scene3_packing.exe 100000 7
```

| Scene3 representation | Median seconds | Bytes per cold pack |
| --- | ---: | ---: |
| Stored constant clear fields | 0.003663063 | 13,617,576 |
| Literal private accessors | 0.003749847 | 13,617,576 |

The output remains 3,600,000 vertex/attribute bytes and 400,000 index bytes.
The measurement excludes scene construction, so it does not measure the
smaller Scene3 record's allocation. Staging allocation is unchanged; the
2.4% timing difference does not establish a speedup. Public API manifests
compare equal. `@lib/rays/runtest` passes, including restored float32 packing
assertions in a test that previously only printed success. Its independent
f64 pixel oracle is now registered under `@runtest-native`, but the actual
attempt fails with "Metal has no system default device". Native pixel parity
and upload behavior remain unverified here.
