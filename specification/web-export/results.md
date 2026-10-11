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

## 2026-10-11 — Deferred PXUI identity transforms

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native executable in the
development profile, one domain. Input: the unchanged 200-node editor
benchmark at 1,200 × 760 logical points, default font size 13. Each process
measures 200 drag frames, one undo and 200 alternating literal edits with
full editor updates. The rows below are medians of three separate process
runs before and after. No profiler or concurrent build/test during timing.

```sh
_build/default/tools/check.exe lib/pxui/test_main.exe tools/bench_rays_editor.exe
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  _build/default/tools/bench_rays_editor.exe 200
```

| Operation | Before seconds | After seconds | Before bytes/frame | After bytes/frame |
| --- | ---: | ---: | ---: | ---: |
| Drag frame | 0.001834869 | 0.001796961 | 6,021,502 | 5,929,718 |
| Undo frame | 0.002377033 | 0.002339125 | 6,796,312 | 6,704,496 |
| Literal edit and frame | 0.001862049 | 0.001842976 | 5,491,372 | 5,399,532 |
| Literal edit excluding cook time | 0.001758099 | 0.001734018 | 5,491,372 | 5,399,532 |

Removing constant layout/paint transforms and the repeated identity setter
reduces measured frame allocation by 91,784–91,840 bytes (1.4–1.7%). The
wall-time medians are 1.0–2.1% lower on this input; no general speedup is
claimed. The builder still supports transforms for its direct consumers.

The existing panel, overlays, zones and million-row table fixtures are
staged through the real painter at 1x and 2x. Complete packed instance bytes
and batch descriptors compare byte for byte before/after in all eight cases.
To reproduce a packet dump, set `RAYS_UI_COMMAND_DUMP` to an existing directory
and run the command below with the same font before and after a change:

```sh
SDL_VIDEODRIVER=dummy RAYS_UI_FONT=assets/fonts/DepartureMono-Regular.otf \
  _build/default/lib/pxui/test_main.exe test_ui_commands
```

The interaction, ordered-input, keyboard, table and command tests all pass.
Public API manifests compare equal and no pixel golden is updated. The full
`@lib/pxui/runtest` attempt fails only in pixel parity because Metal has no
system default device. Packet equality is CPU evidence; native golden
execution remains unverified.

## 2026-10-11 — Deferred Ui_batch constant transform

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native executable in the
development profile, one domain. Same unchanged 200-node editor benchmark,
1,200 × 760 logical points and font size 13. Three process runs before and
after; each measures 200 drag frames, one undo and 200 alternating literal
edits with full updates. The table gives medians of the three reported
medians and allocated bytes per frame. No profiler or concurrent build/test.

```sh
_build/default/tools/check.exe @lib/scene_command/runtest \
  lib/pxui/test_main.exe tools/bench_rays_editor.exe
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  _build/default/tools/bench_rays_editor.exe 200
```

| Operation | Before seconds | After seconds | Before bytes/frame | After bytes/frame |
| --- | ---: | ---: | ---: | ---: |
| Drag frame | 0.001799822 | 0.001808882 | 5,929,718 | 5,902,734 |
| Undo frame | 0.002331972 | 0.002345800 | 6,704,496 | 6,677,352 |
| Literal edit and frame | 0.001832008 | 0.001833916 | 5,399,532 | 5,372,644 |
| Literal edit excluding cook time | 0.001728058 | 0.001734018 | 5,399,532 | 5,372,644 |

The unused setter, transform type and builder/batch fields are removed.
Wire clipping uses screen points directly; native lowering keeps the same
logical-screen-to-clip-space affine. Allocation falls by 26,888–27,144 bytes
per frame (0.4–0.5%). Wall-time medians rise by 0.1–0.6% on this input; no
speedup is claimed. This benchmark measures editor updates, not GPU lowering.

The same eight fixture packets compare exactly before/after, with the
removed identity field omitted from the descriptor dump; all instance bytes
and remaining descriptor fields are compared. The new builder test checks
exact logical coordinates, outside-chord rejection, visible chord intervals,
clip and texture batches, reset and immutable published bytes. It passes
before and after the change. Typechecking, the dependency gate and all four
CPU interaction test cases pass. Native pixels remain unverified without
Metal; the pixel golden test is unchanged.

This intentionally removes the lower-level `Ui_batch.xform` and
`Builder.set_xform` interface. The stable manifest covers selected high-level
libraries and excludes `scene_command`; its generated text is unchanged by
this removal. Its gate still reports the separately pending P1.7 Core
signature, which has not been promoted.

## 2026-10-11 — Deferred Easy Camera fixed bindings

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native development profile,
one initial domain. Inputs: 512 prebuilt logical 320 × 240 frames cycling
held Shift/Ctrl keys; idle frames have no events. Active frames include a
key press, mouse press/move/release, with fixed orbit/pan buttons. Samples
run 500,000 idle or 100,000 active updates; one full sample warms the path,
then three samples report median wall time and allocated bytes. No profiler
or concurrent build/test during the recorded samples. No GPU work.

```sh
_build/default/tools/check.exe lib/rays/test_main.exe
_build/default/lib/rays/test_main.exe bench_easy_camera
```

| Path | Frames | Before seconds | After seconds | Before allocated bytes | After allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| Idle, alternating held keys | 500,000 | 0.007308960 | 0.001348972 | 72,000,096 | 96 |
| Orbit/pan drags with key events | 100,000 | 0.031363964 | 0.022171021 | 265,471,024 | 219,871,008 |

Removing the fixed binding list, unused modifier reconstruction and key
cache avoids idle camera copies; active updates allocate about 456 fewer
bytes per frame on this input. Wall time is lower in these short CPU samples;
this is not a general application or rendering speed claim. The 96 idle
bytes are sample overhead, not proof of zero allocation for all camera use.

The test independently checks fixed button behavior, all four modifiers,
logical half-open bounds, capture outside them, density parity, double-click
reset, cancellation and fly navigation's WASD/Shift/wheel contract.
Replaying 128 frames with orbit/pan, wheel, inertia and mixed key events
produces byte-identical public camera-state dumps before and after.
`@lib/rays/runtest`, typechecking, the dependency gate and the editor input
test pass. The editor input fixture reports the existing autosave refusal
under the runner's read-only home directory. The unused public `binding`
and `interaction` types are intentionally removed; their manifest change
is promoted separately from the pending P1.7 Core interface.

## 2026-10-11 — Deferred Light linear coefficient

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native development profile,
one initial domain. Input: 64 lights cycling directional, point, spot and
area kinds over one immutable triangle. Each of 5,000 calls creates a fresh
Scene3 wrapper and stages at 320 × 240 logical points, reusing the mesh
mirror and forcing new light uniforms. One full-sample warmup, then three
samples; median wall time and allocated bytes. No profiler, GPU operation
or concurrent build/test during either measurement.

```sh
_build/default/tools/check.exe lib/rays/test_main.exe
_build/default/lib/rays/test_main.exe bench_light
```

| Representation | Median seconds | Allocated bytes |
| --- | ---: | ---: |
| Stored zero linear coefficient | 0.030397892 | 106,000,096 |
| Constant/quadratic record | 0.029451132 | 106,000,096 |

Allocation is unchanged in staging. Light construction precedes the timer,
so the smaller attenuation record is not measured here. The 3.1% lower
wall-time median on this short CPU input does not establish a general
speedup. Reserved native ABI slots stay zero in the existing twenty-word
light layout; runtime shaders are unchanged.

The new test checks constructor refusals and all twenty words of each of
the four light kinds, including every area sample count. Complete 5,456-byte
uniform buffers match before/after in all four cases. CPU Rays tests,
typechecking, dependency checks and scene-tree light routing pass. Native
pixel behavior remains unverified without Metal. The public `linear`
record field is intentionally removed, with its own reviewed API promotion
separate from pending P1.7 changes.

## 2026-10-11 — P1.6a prepared core record fold

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native executable in the
development profile, one domain. Same input as the Slice C rows above: a
record accumulator over 4,096 packed items, 30 changing frames, one warmup,
median of three samples, `Gc.allocated_bytes`. The fold is prepared once
(`Executor.compile`, then a lowered and prepared `Core_exec.prepared` cached
per residual) and forced through `Executor.force` with `core_residuals` on.

Build with `dune build lib/flow_ir/test_core_records.exe`. Run from
`_build/default/lib/flow_ir`:

```sh
./test_core_records.exe --bench-records
```

| Path | Wall seconds | Allocated bytes |
| --- | ---: | ---: |
| P1.5 native baseline (walker) | 0.076312 | 152,390,016 |
| Slice C native equality/coercion fixes (walker) | 0.058664 | 297,986,736 |
| Core, per-call operator lookup and argument lists | 0.125018 | 411,017,136 |
| Core, statements prepared once, comparison and equality inline | 0.052119 | 84,631,776 |

The accumulator already lowers to field locals (no record is built per
iteration); the cost was the executor re-resolving operators and building an
argument list for every statement. Preparation resolves operators and shares
constants once per residual; comparisons, `and`/`or` and `equal?` run the
operators' own bodies on locals and return shared booleans. Against the P1.5
baseline the core path is 0.68 times the time and 0.56 times the bytes (limits
1.1 and 1.05). Values and diagnostics are unchanged: the Flow and Flow IR
focused gates pass. This is one input on one machine, not a general claim.

## 2026-10-11 — P1.12 core residual coverage

Command: `RAYS_CORE_COVERAGE=1 _build/default/tools/check.exe @test/test_workspace_ir`
(the same gate as P1.11, with the variable set; `EXIT=0`). Machine: Apple M1,
OCaml 5.3.0, domains 1 and 8. Input: the 15 eligible workspaces of the plan's
corpus, forced at times 0, 0.125, 1.25 and 7, each residual counted once per
workspace by its evaluator identity. "Lowered" is `Core_lower.lower` returning
`Ok`; "refused" is `Error`, and the form is the string it returned. Counts are
residuals the evaluator offers the executor, including the packed-kernel
handles it offers at the same hook. This is a count, not a timing.

| Workspace | Lowered | Refused | Refused forms (count) |
| --- | ---: | ---: | --- |
| examples/audio | 27 | 0 | |
| examples/basic | 6 | 0 | |
| examples/drawing | 1,824 | 1 | ref 1 |
| examples/file_dialog | 30 | 0 | |
| examples/generative | 8 | 6 | packed_higher_order 6 |
| examples/noise | 6 | 8 | packed_higher_order 8 |
| examples/particles | 4 | 6 | packed_higher_order 6 |
| examples/pxui | 5 | 2 | packed_higher_order 2 |
| examples/recursive_rectangles | 15 | 18 | packed_higher_order 17, color/hsl 1 |
| sketches/flow_contours | 5 | 0 | |
| sketches/flow_image | 0 | 0 | |
| sketches/flow_image_kernel | 1 | 0 | |
| sketches/flow_particles_gpu | 5 | 5 | noise3 4, packed_higher_order 1 |
| sketches/flow_shader | 24 | 0 | |
| sketches/flow_vectors | 3 | 0 | |

Total: 1,963 lowered, 46 refused across 7 of the 15 workspaces. The zero-error
target of P1.12 is not met; the refused forms are the input to a lowering slice.
The sweep itself passes, and the parity test is unchanged.

## 2026-10-11 — P1.13 core scalar residual bench

Command: `dune` builds the bench through `_build/default/tools/check.exe tools/bench_core.exe`
(in `bench-build`), then `_build/default/tools/bench_core.exe` run three times.
Machine: Apple M1, OCaml 5.3.0 native executable, default dune (dev) profile,
one domain. Input: one scalar residual `(+ (* (sin t) 0.5) (* t t))` evaluated
200,000 times per sample against the same frame input; the result is checked
bit-for-bit against the reference walker before timing. Each run reports the
median of three samples; the table is the median of the three runs. The cost
table in `lib/flow_ir/flow_ir.ml` names no expression for its closure row, so
this representative scalar expression was chosen. Allocation is
`Gc.allocated_bytes` per evaluation.

| Row | Wall ns per evaluation | Allocated bytes per evaluation |
| --- | ---: | ---: |
| tree walker (`compile_residuals` false, `core_residuals` false) | 940.2 | 5,336 |
| closure tier (`compile_residuals` true) | 132.6 | 1,880 |
| core (`core_residuals` true) | 391.8 | 3,208 |

Core/closure ratio 2.95 (walker/closure 7.1). The plan's threshold is 1.1, so
P1.14 (compile core programs to closures) is required; this entry does not
change the core executor.
