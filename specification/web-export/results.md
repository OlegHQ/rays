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

## 2026-10-11 — P1.12a core residual coverage after the repair

Command: `RAYS_CORE_COVERAGE=1 _build/default/tools/check.exe @test/test_workspace_ir`
(`EXIT=0`), as for P1.12. Machine: Apple M1, OCaml 5.3.0, domains 1 and 8. Same
inputs and counting rule as the P1.12 entry.

| Workspace | Lowered | Refused |
| --- | ---: | ---: |
| examples/audio | 27 | 0 |
| examples/basic | 6 | 0 |
| examples/drawing | 1,825 | 0 |
| examples/file_dialog | 30 | 0 |
| examples/generative | 14 | 0 |
| examples/noise | 14 | 0 |
| examples/particles | 10 | 0 |
| examples/pxui | 7 | 0 |
| examples/recursive_rectangles | 33 | 0 |
| sketches/flow_contours | 5 | 0 |
| sketches/flow_image | 0 | 0 |
| sketches/flow_image_kernel | 1 | 0 |
| sketches/flow_particles_gpu | 10 | 0 |
| sketches/flow_shader | 24 | 0 |
| sketches/flow_vectors | 3 | 0 |

Total: 2,009 lowered, 0 refused (P1.12 counted 1,963 lowered and 46 refused: the
same 2,009 residuals, all lowered now). No intended refusals remain for the 15
workspaces. Still declined by name, outside the corpus: packed `sort-by`, packed
`for`/`scan` collects, a `ref` with overrides, `color/hsla`.

## 2026-10-11 — P1.14 core executor speed-up (target not met)

Command: `_build/default/tools/check.exe tools/bench_core.exe`, then
`_build/default/tools/bench_core.exe` three times. Machine, input and method as in the
P1.13 entry (Apple M1, OCaml 5.3.0, one domain, 200,000 evaluations per sample, median of three
samples, then the median of three runs; load average about 3 from other processes). Before = the
tree at P1.12a (`941a9cee`), measured again at the start of this task.

| Row | Before ns/eval | Before bytes/eval | After ns/eval | After bytes/eval |
| --- | ---: | ---: | ---: | ---: |
| tree walker | 913.5 | 5,336 | 887.2 | 5,240 |
| closure tier | 129.9 | 1,880 | 119.5 | 1,784 |
| core | 378.1 | 3,208 | 166.7 | 2,096 |
| core/closure | 2.92 | | 1.39 | |

The gate (at most 1.1) is not met. What changed, in order of effect (ratio after each, same bench):

1. Executor hot path: builders, ownership sealing and the evaluation-state checkpoint are skipped for
   programs with no list builder, state slot or region; Float `+ - *`, `sin` and `cos` on two Floats skip the
   generic operator dispatch (anything else, and any non-finite result, runs the operator's own body);
   `Frame_input.validate` no longer allocates; the hook builds its region callback only for programs
   with regions. 2.92 to 1.95.
2. A straight-line program of Float arithmetic on the frame time (`+ - * sin cos sqrt`, at most 64
   steps) compiles once to postfix code on a flat float stack (`Core_exec.prepare`). A non-finite step
   falls back to the general statements, so diagnostics are unchanged. 1.95 to 1.39.

Remaining hot spot: the executor round trip, about 40 ns over the closure tier. The core program itself
is about 33 ns (of which `sin` is about 12); the rest is the hook (state snapshot, `r.live`, two
exception handlers, the cached-program lookup and optional-argument boxing), where the closure tier
calls one cached closure. Closing it needs the evaluator to hold the prepared program on the
residual instead of asking the executor each time. That is a change to `lib/flow/eval.ml` and
its hook contract, not to the core program, so it is left for a later task.

## 2026-10-11 — P1.14a prepared core program on the residual (target not met)

Command: `_build/default/tools/check.exe tools/bench_core.exe`, then `_build/default/tools/bench_core.exe` three
times. Machine, input and method as in P1.14 (Apple M1, OCaml 5.3.0, one domain, 200,000 evaluations per sample,
median of three samples, median of three runs); load average 3 to 4.5 (not quiet). Before = `5fd386f5`.

| Row | Before ns/eval | Before bytes/eval | After ns/eval | After bytes/eval |
| --- | ---: | ---: | ---: | ---: |
| tree walker | 887.2 | 5,240 | 896.9 | 5,280 |
| closure tier | 119.5 | 1,784 | 119.6 | 1,824 |
| core | 166.7 | 2,096 | 151.2 | 1,960 |
| core/closure | 1.39 | | 1.26 | |

(Individual runs: 1.25, 1.26, 1.26; an earlier quieter series of the same tree gave 1.24.) The gate (at most 1.1) is not met.

Changes, in order of effect: (1) `Eval.residual.core` holds the executor's prepared program with the owner token
of the `Executor.program` that filled it; `force_res` calls it directly, without the state snapshot, the second
exception handler, the cached-program lookup or optional-argument boxing (1.39 to 1.31; a first version
without the owner check broke `test_frame_kernel`'s own hook, which shows the slot must be per executor).
(2) the postfix scalar path skips `Frame_input.validate` (it reads only `t`; an invalid frame ends in the walker's
result anyway), is lifted out of the closure allocating `general`, and uses unchecked stack accesses (1.31 to 1.25).
What remains, about 30 ns, is the postfix interpreter (nine dispatches and `sin`) against the closure tier's tree.

## 2026-10-11 — P1.14b postfix superinstructions and whole-frame cost (regression found)

Commands: `_build/default/tools/check.exe tools/bench_core.exe`; micro rows with
`_build/default/tools/bench_core.exe` (seven runs); whole frames with
`_build/default/tools/bench_core.exe frames .` (`frames ROOT [WORKSPACE-SUFFIX]`). Machine: Apple M1,
OCaml 5.3.0, dune dev profile, one domain, load average 2.0 to 4.3 from other virtual machines (not quiet).

**Micro (a).** Postfix code gained operand-inline instructions (`Add_k`/`Sub_k`/`Mul_k` with a constant right
operand, `Add_t`/`Sub_t`/`Mul_t` with the time) and sizes its stack to the program's depth: the example has six
dispatches instead of eight. Seven runs, same expression and method as P1.13:

| Row | ns/eval median | bytes/eval |
| --- | ---: | ---: |
| tree walker | 888.4 | 5,280 |
| closure tier | 119.7 | 1,824 |
| core | 146.9 | 1,912 |
| core/closure | 1.23 (min 1.21, max 1.25) | |

The 1.1 gate is not met; the 1.25 review threshold is met (from 1.26).

**Whole frames.** A throwaway whole-frame comparison (walker, closure, core; 15 eligible workspaces, forcing every value
and rendering each draw graph at fixed steps) found core faster on seven workspaces (up to 9x), equal on six, and slower
on `examples/particles` (about 2.3x, 4.5 ms against 2.0 ms per frame) and `examples/drawing` (about 1.07x). Before the
repairs below they were 5.0x and 2.0x. Causes found by profiling: per-call arrays sized by the program's locals on the
major heap, a handler per statement, sealing on scalar locals, loop-invariant constants re-assigned per iteration,
generic dispatch for `array/nth`, `array/count` and `frame/*`. Repaired in `Core_exec` (pooled locals for programs over
256 locals, lazily allocated builders, one handler per block, invariants set at loop entry, direct operators). What
remains in particles is the interpreter itself (10,000 elements times about 50 statements per map). The owner waived
further performance work; the comparison tool was not kept.

## 2026-10-11 — P2.8 kernels through core regions

Commands: `_build/default/tools/bench_core.exe kernels` and `_build/default/tools/bench_gpu.exe`. Machine: Apple M1,
OCaml 5.3.0, dune dev profile, load average 6.5 to 8.5 from other work (not quiet, one run only, no noise chasing).
"switch" is `Packed.Private.core_regions`. Compile is `Packed.compile` of an already checked residual (median of
three samples of 2,000 calls); force is one `Packed.force` of the compiled kernel (median of three samples).
Forcing runs the same register program either way, so differences in the force column are noise.

| Case | switch | domains | compile us | force ms |
| --- | --- | ---: | ---: | ---: |
| map 1,024 | off | 1 | 1.46 | 0.038 |
| map 1,024 | off | 8 | 1.46 | 0.043 |
| map 1,024 | on | 1 | 2.19 | 0.043 |
| map 1,024 | on | 8 | 2.19 | 0.042 |
| map 1,000,000 | off | 1 | 2.18 | 19.283 |
| map 1,000,000 | off | 8 | 2.18 | 11.231 |
| map 1,000,000 | on | 1 | 2.38 | 22.039 |
| map 1,000,000 | on | 8 | 2.38 | 10.346 |
| fused maps 1,000,000 | off | 1 | 4.42 | 20.020 |
| fused maps 1,000,000 | off | 8 | 4.42 | 10.605 |
| fused maps 1,000,000 | on | 1 | 4.27 | 20.045 |
| fused maps 1,000,000 | on | 8 | 4.27 | 10.819 |
| sum 1,000,000 | off | 1 | 1.11 | 18.003 |
| sum 1,000,000 | off | 8 | 1.11 | 18.080 |
| sum 1,000,000 | on | 1 | 1.28 | 18.028 |
| sum 1,000,000 | on | 8 | 1.28 | 18.117 |

Compile with the switch on is slower for three of four cases (map 1,024 +50 percent, map 1,000,000 +9, sum +15; fused
pair -3); the absolute cost is under a microsecond and runs once per kernel, not per frame. Recorded in
`DEFERRED.md`; not optimized. `bench_gpu.exe` (Metal emission is unchanged by the switch): noise kernel, 1,024 /
65,536 / 1,000,000 elements, total seconds with readback 0.000188 / 0.002917 / 0.037077, display (no readback)
0.000153 / 0.001235 / 0.017531; pipeline compile 0.008152 s once.

## P4.13: draw rows against the P4.1 baseline (2026-10-11)

Commands: `_build/default/tools/bench_marks.exe` (CPU path, `Drawing.render_prepared`) and
`_build/default/lib/rays_editor/native_qualification/bench_marks_gpu.exe` (new; GPU positions, qualification
policy, same call plus the kernel dispatches with their completion and status read, not the render pass).
Apple M1, OCaml 5.3.0, dune dev profile, load average 6 to 9 from other agents (one run per row set, no noise
chasing). The baseline is `bench_marks.exe` built at 4ad9125a (P4.1), run in a worktree just before the "after"
run. The P4.1 ledger line quoted 160 ms for animated circles 1M; the same build measured 137 ms here, so
differences under about 15 percent on the animated rows are noise.

CPU path, ms and bytes allocated per frame (median of 8 frames, 3 at 1M):

| kind | mode | n | P4.1 ms | P4.1 bytes | now ms | now bytes |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| circles | static | 100,000 | 0.000 | 1,072 | 0.000 | 1,136 |
| circles | animated | 100,000 | 14.230 | 59,520,696 | 14.284 | 59,521,400 |
| rects | static | 100,000 | 0.001 | 1,072 | 0.001 | 1,136 |
| rects | animated | 100,000 | 14.156 | 58,720,760 | 14.226 | 58,721,320 |
| translate | moving | 100,000 | 4.795 | 32,006,408 | 0.004 | 6,768 |
| circles | static | 1,000,000 | 0.001 | 1,072 | 0.003 | 1,136 |
| circles | animated | 1,000,000 | 136.736 | 609,771,680 | 152.723 | 605,866,648 |
| rects | static | 1,000,000 | 0.001 | 1,072 | 0.003 | 1,136 |
| rects | animated | 1,000,000 | 135.987 | 601,771,936 | 136.081 | 601,771,080 |
| translate | moving | 1,000,000 | 48.871 | 320,006,408 | 0.006 | 6,768 |

The moving translate no longer scales with the count (P4.10): a static region runs once, an unchanged mark set
keeps its scene node, and the renderer skips the byte comparison of a batch it already holds. The animated CPU rows
are unchanged, as expected: P4.9 only changes sets that have a GPU attribute.

GPU positions (`bench_marks_gpu.exe`; "radius" is a per-instance radius or size from a second GPU region, "fill" a
per-instance CPU colour buffer, "per-instance" both; "uniform" is what the removed `gpu_circles` arm served):

| kind | style | 100,000 ms | 100,000 bytes | 1,000,000 ms | 1,000,000 bytes | 1M against uniform |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| circles | uniform | 1.260 | 4,025,848 | 8.858 | 40,025,776 | 1.0x |
| circles | radius | 1.602 | 6,025,904 | 12.299 | 60,025,832 | 1.4x |
| circles | fill | 7.327 | 18,825,688 | 70.252 | 188,025,616 | 7.9x |
| circles | per-instance | 7.744 | 20,825,744 | 73.664 | 208,025,672 | 8.3x |
| rects | uniform | 1.234 | 4,025,872 | 9.079 | 40,025,800 | 1.0x |
| rects | radius | 2.326 | 10,025,872 | 19.051 | 100,025,800 | 2.1x |
| rects | fill | 7.334 | 18,825,712 | 70.232 | 188,025,640 | 7.7x |
| rects | per-instance | 8.404 | 24,825,712 | 80.350 | 248,025,640 | 8.8x |

The plan target (per-instance within 2 times the uniform-style GPU row at 1,000,000) is missed: 8.3x for circles and
8.8x for rects. The "radius" and "fill" rows attribute it: a per-instance extent on the GPU costs 1.4x and 2.1x, the
per-instance fill costs 7.7 to 7.9x. The fill is a CPU region (a `map` over 1,000,000 vec3 colours) that
`Marks_scene` converts element by element through `drawing_color` into packed words, because a colour attribute
cannot be a GPU region yet. Recorded in `DEFERRED.md`; not optimized. Against the CPU path (animated circles 1M,
153 ms), per-instance GPU circles are 2.1x faster and allocate 2.9x less.

## P4.7 attribute fusion (2026-10-11)

Command: `_build/default/tools/bench_core.exe attributes`. Apple M1, OCaml 5.3.0, dune dev profile, load average 4.9 8.7 10.6
(other agents running; one run, no noise chasing). Input: a `draw/circles` graph with a position map
`[(* i t) (sin (+ i t)) 0]` and a fill map `[(sin t) (/ i n) (cos (* i t))]` over `(array/range 1000000)`, both
frame-rate, both vec3. "Separate" is two `Packed.force` calls of the two kernels; "fused" is one `Packed.force_all` of
the two-output region `Flow_ir.optimize` builds from the mark set. Median of three samples, milliseconds per frame.

| Case | domains | separate ms | fused ms | speedup |
| --- | ---: | ---: | ---: | ---: |
| circles position + fill, 1,000,000 | 1 | 92.710 | 72.554 | 1.28x |
| circles position + fill, 1,000,000 | 8 | 62.769 | 41.577 | 1.51x |

Fused is faster: the shared `i`, `t` registers are computed once and the output pass is one loop. No `DEFERRED.md`
entry.

## 2026-10-11 — P6.3 first real compile of the WGSL kernels (Chrome, Metal WebGPU)

Command: `dune build @qualification-web` (rule in `tools/dune`; runs `test_wgsl.exe --write-kernel-table` then
`node tools/web/test/gpu_check.mjs`; exit 3 = WebGPU unavailable, a missing node or Chrome is a printed skip).
Browser: Google Chrome 154.0.8037.98 (user agent `HeadlessChrome/154.0.0.0`), macOS on Apple M1. Adapter:
`vendor apple`, `architecture metal-3`, not a fallback adapter, `maxStorageBuffersPerShaderStage` 8,
`maxComputeWorkgroupsPerDimension` 65535. Flags: `--headless=new` only. Probed `--headless=new`, plus
`--enable-unsafe-webgpu`, plus `--use-angle=metal`: all three give the same adapter, so nothing more is passed.
(Non-headless with an off-screen window was not needed.)

Every kernel in the table compiles (`getCompilationInfo` has no messages, `createComputePipelineAsync` resolves):
no WGSL printer bug was found, goldens unchanged. Each kernel runs on 1,000 elements of
`sin(0.37 i) * 40 + (i mod 17)` rounded to f32 (negative and positive, not a multiple of 64) with `t = 1.5`, and is
compared with the CPU region on the same input (the matching `goldens/*.js`; for `ops` the `Js.region` text in the
table).

| Kernel | Covers | Tolerance | Worst abs error | Result |
| --- | --- | --- | ---: | --- |
| arithmetic | +, *, uniform, bitcast constants | 1e-5 * max(1, abs cpu) | 3.8e-6 | pass |
| select | comparison, select | 1e-5 relative | 1.2e-7 | pass |
| two_outputs | two output buffers of width 1 and 2 | 1e-5 relative | 1.9e-6 | pass |
| noise | 3-octave `noise3`, seed 31, table upload | 1e-4 absolute | 2.6e-7 | pass |
| ops (not a golden) | mod, pow, guarded `/`, sqrt, min, max, sin, cos, and, or, not, <, <=, >, >=, = | 1e-5 relative | 2.3e-5 on values of order 100 | pass |

Tolerances: the GPU rounds each operation to f32 and the CPU region runs f64 on the same f32 inputs, so 1e-5
relative is far above the few-ulp (6e-8) expectation; noise gets 1e-4 absolute because its f32 coordinates (up to
about 80 after octave scaling) are off by about 8e-6 and the gradient slope is at most about 3. Observed errors are
one to two orders below both. `sin`/`cos` are the WebGPU implementation's (the spec allows a loose error); they
agreed to 2e-5 absolute at values near 100 here, which is Metal's, so another browser or GPU may differ more.

Host behavior checked in the same run: a finite f32 input that overflows (3e38 * 2) is not reported in the
dispatching frame and arrives as one `E_KERNEL` after `flush` (the next-frame status word); an infinite input is
rejected on upload with `E_KERNEL`; growing the count replaces the output buffer (the old one destroyed). A
corrupted kernel (`var<unifor>`) fails the load with `WGSL error in kernel ...: 3:27 unresolved address space`,
so the harness does detect compile errors. Three consecutive runs agreed. Not yet covered: pixels (P6.8), a second
browser, workgroup counts above the dispatch limit, the 128 MiB storage binding limit.

## P5.13: frame parity of the web export under node (2026-10-11)

Command, from the repository root after `dune build tools/web_parity.exe`:

    _build/default/tools/web_parity.exe examples/audio examples/basic examples/drawing examples/file_dialog \
      examples/generative examples/noise examples/particles examples/pxui examples/recursive_rectangles \
      sketches/flow_contours sketches/flow_image sketches/flow_image_kernel sketches/flow_particles_gpu \
      sketches/flow_shader sketches/flow_vectors

Machine: Apple M1, node v24.19.0, 24 s wall. Each workspace is exported as `rays-lisp web` does, run natively
(`Core_exec.draw`) and under node (`program.js`, `runtime.js` from the export) for 120 fixed-step frames
(dt 1/60, 640x480, pointer (100, 100), no buttons or keys), CPU regions on the main thread. Marks are compared per
frame: structure, colours, counts, indices and text exactly, floats within 1e-6; a buffer of more than 4,096
numbers by length, first and last 256 numbers and sum.

| Workspace | Result | Notes |
| --- | --- | --- |
| examples/audio | pass | 1,200 mark entries over 120 frames |
| examples/basic | pass | state, frame facts, `str`, text marks |
| examples/drawing | refused `E_WEB_LOWER` at 105:3 | the draw graph exceeds the core lowering's 2,048-node residual budget (`Core_draw.lower` returns `budget`); native draws it through the old arms. A larger budget or splitting the residual is a lowering task |
| examples/file_dialog | pass | the draw graph only; the host effects live in a `host` graph that is not exported |
| examples/generative | pass | 4.3 MB of marks |
| examples/noise | pass | |
| examples/particles | pass | 10,000 particles in state, element-by-element loops through prims.js |
| examples/pxui | pass | |
| examples/recursive_rectangles | pass | |
| sketches/flow_contours | refused `E_WEB_IMAGE` at 77:3 | a `draw/image` of an image graph; the web has no host image resolver, and an image graph is a GPU pixel kernel |
| sketches/flow_image | refused `E_WEB_IMAGE` at 5:3 | same |
| sketches/flow_image_kernel | refused `E_WEB_IMAGE` at 7:3 | same |
| sketches/flow_particles_gpu | pass | one collecting region of 1,000,000 elements (`data.bin` 7.6 MB), run on the CPU |
| sketches/flow_shader | refused `E_WEB_IMAGE` at 67:3 | same |
| sketches/flow_vectors | pass | scalar program, no arrays |

Ten pass, five are refused with a span, none fails. The image refusals point at the draw graph (the lowered
`draw/image` statement carries no span of its own). No refusal is for a host effect: `host/quit`, `host/dialog`,
`host/play`, `host/save_png` and `audio/synth` live in `host` graphs, outside the exported draw graph.
Before this task three bugs were fixed on the way: the printer refused every `not`, the kernel-table JSON writer
escaped UTF-8 bytes one by one, and `prims.js` `sequence_build` ignored the packed width.

**Addendum 2026-10-11 (P6.4a).** The native draw lowering budget was raised to 32,768 (P5.13a) and the exporter
has no budget constant of its own (`Web_export.lower` calls `Core_draw.lower`), so `examples/drawing` now
exports. The same command over all 15 workspaces, after the GPU-attribute change below: 11 pass (120 frames each), 4 are
refused `E_WEB_IMAGE` (`sketches/flow_contours` 77:3, `flow_image` 5:3, `flow_image_kernel` 7:3, `flow_shader` 67:3), 0 fail. Only
the `examples/drawing` row changes: pass, an event-driven state machine over records.
`sketches/flow_particles_gpu` still passes, but its region is now a GPU region (node has no GPU, so the harness
answers `rt.gpuArray` with the CPU value; `frames.mjs`).

## P6.7: reload of a served export in headless Chrome (2026-10-11)

Command, from the repository root after `dune build tools/lisp/lisp.exe`:

    node tools/web/test/reload_check.mjs _build/default/tools/lisp/lisp.exe sketches/flow_vectors/sketch.rays

(or `dune build @qualification-web`, which also runs the WebGPU kernel check). Machine: Apple M1, Google Chrome
154.0.8037.98 with `--headless=new`, node v24.19.0. The script copies the sketch to a temporary file, starts
`rays-lisp web --watch FILE -o DIR --port 0`, opens `http://127.0.0.1:PORT/`, waits for a cross-origin-isolated
page with a running runtime (`window.__rays`), sets `window.__marker`, changes the circle radius `24` to `31` in
the file, and waits for `__rays.reloads === 1`.

Result: ok. The page swapped its program (`__rays.program.frame` now holds `31n` and no `24n`) with no navigation
(`window.__marker` survived, one navigation entry), marks kept being produced, and 1.5 s later there was still
exactly one reload. Reload protocol: the runtime polls `/version` every 0.5 s; the first answer is the baseline;
a different answer re-imports `program.js?v=VERSION`, refetches `data.bin?v=` and `kernels.json?v=`, calls
`gpu.update` (only kernels whose WGSL, entry, bindings or noise seeds changed are compiled) and `rt.load` (fresh
state slots, region sources compiled once per text, workers sent only changed sources, canvas kept); a 404 or a
fetch error on `/version` stops polling silently. The node test `tools/web/test/runtime.mjs` covers the same
protocol with a fake server (version change swaps the program and resets slots, an unchanged region is not
compiled again, `gpu.update` compiles only changed kernels, a 404 or fetch error stops silently).
Fixed on the way: `createRuntime` read the original program for `region(k)` and the worker load after `rt.load`,
so a reload kept running the old regions.

## 2026-10-11: browser presenter, pixels in real Chrome (P6.4, P6.5)

Machine: Apple M1, Google Chrome 154 `--headless=new` (Metal WebGPU adapter), node 24. Gate: `dune build
@qualification-web` (`tools/web/test/present_check.mjs`, `present_e2e.mjs`; native oracle `tools/marks_shot.exe`:
core executor, `Marks_scene`, `Canvas` at density 1).

Hand-built tables (`present_check.mjs`, 100x100 points, dpr 1 unless noted; canvas read back with `drawImage` in the
submitting task): 76 checks, 0 failures at colour tolerance 2/255. Every probe is at least 2 device pixels from an
edge, so antialiasing never enters. Cases: rect fill and stroke (9 probes), stroke only (4), circle fill and stroke
(8), circle with per-instance position/radius/float-colour buffers (5), line constant and per-instance end/width (9),
geometry, an empty geometry and a point set with truncated positions (6), push/pop transform and nested clips (12),
rotation matrix (4), blend add/alpha with a zero-alpha mark (5), image upright and rotated by pi (6), text (ink
bounding box and colour), text at dpr 2 (canvas 200x80), and dpr 2 shapes (6).

End to end (`present_e2e.mjs`): `rays-lisp web` export, served with COOP/COEP, runtime.js with the worker pool,
5 fixed frames (dt 1/60, pointer (100, 100), 640x480), `present`, read back, against `marks_shot` at the same
frames. Metric: largest channel difference per pixel; pass when at most 0.5% of the pixels outside text differ by
more than 8 and none by more than 64.

| Workspace | Entries | Pixels outside text differing by > 8 | Worst | Mean |
| --- | --- | --- | --- | --- |
| `sketches/flow_vectors` | 2 | 0 of 307,200 | 1 | 0.0000 |
| `examples/basic` | 3 | 0 of 300,060 | 0 | 0.0000 |

Both are also loaded as `index.html` (`start`, real clock, rAF) and run with marks and a screenshot.

Text is not exact. `basic`'s line box: Chrome's `ui-monospace` ink spans x 13..183, y 14..26; native SDL_ttf
(SFNSMono) x 13..190, y 16..27, 1.27 times the brightness. Text boxes are therefore compared by total brightness
(ratio within 0.5..2) and excluded from the per-pixel metric. Not covered: image entries from an export
(`draw/image` is refused `E_WEB_IMAGE`, so only the hand-built table reaches them; `start` has no resolver, so
`presenter` takes `images(resource)`), blend entries (the compiler emits none; hand-built only), clip entries
(no draw operator emits one yet), and the mark kinds beyond what the two workspaces draw (hand-built tables cover them).

Mismatch found, left alone: native rotates an image about the wrong pivot when the angle is not a multiple of pi
(`image_command` computes `tx = px - xx*px - xy*py` with `xy = -sin`, while `Render_ir` applies `yx` to y in x'),
so a 90 degree image leaves the screen. The presenter reproduces the native matrix (marks.md keeps both signs), and
the test uses pi, where the two agree. `lib/` was off limits for this task.
Fixed on the way: a probe taken at a width-2 line's end showed 218, not 255: coverage `0.5 - d/px` with `px = |fwidth|`
is the native line shader's, not a port error.

## 2026-10-11: GPU attribute regions in real Chrome (P6.4a)

Machine: Apple M1, Google Chrome 154 `--headless=new` (Metal WebGPU adapter), node 24. Gate: `dune build
@qualification-web` (`tools/web/test/gpu_marks_e2e.mjs`; oracle `tools/marks_shot.exe`, the core executor in f64 and
`Canvas` at density 1). Two workspaces are exported with `rays-lisp web`, served with COOP/COEP, and run in Chrome with
one `GPUDevice` shared by `gpu.js` and `present.js` (no worker pool is needed: no region runs on the CPU), 5 fixed
frames (dt 1/60, 640x480 or the sketch's 800x600, pointer (100, 100)), then `present`, read back and compared.
Metric: largest channel difference per pixel; pass when at most 0.5% of the pixels differ by more than 8 and none by more
than 64 (the metric of `present_e2e.mjs`, now `compare` in `png.mjs`).

| Workspace | Attributes on the GPU | Kernels | Pixels differing by > 8 | Worst | Mean | GPU dispatches / CPU invokes |
| --- | --- | --- | --- | --- | --- | --- |
| synthetic (2,048 circles, a `draw/circles` with animated positions and radii, static colours) | positions and radii, fused; the colours are a static CPU buffer | `k0`, 2 outputs | 0 of 307,200 | 1 | 0.0007 | 5 / 0 |
| `sketches/flow_particles_gpu` (1,000,000 circles, noise positions) | positions | `k0`, 1 output | 0 of 480,000 | 1 | 0.0190 | 5 / 0 |

Both results are read from `window.__rays.counts` of the same page (`counts.gpu` = one dispatch per frame, `counts.invoke`
= CPU invocations of regions, 0); the mark table's position `buffer` is the device reference `{gpu, output, length}`
and never a `Float64Array`. The real `index.html` (`start`: one device, worker pool, rAF loop) also runs both with
0 CPU invokes and a growing `counts.gpu` (about 170 dispatches in 3 s). f32 against f64 positions did not move a pixel
by more than 1 level in either picture; a one-million-circle picture of radius 0.3 is 0.28 px of coverage per circle,
so an error would show as many pixels at once. Static-rate kernels (no frame fact) are dispatched once per load by
construction (`runtime.mjs`); the static stage folds a frame-independent region to a constant first, so none of the corpus
reaches that path.

## 2026-10-11: browser pixel parity of the served export, `examples/particles` (P6.8)

Command, from the repository root: `dune build @qualification-web` (rule in `tools/dune`), which runs
`tools/web_shot.exe lisp/lisp.exe marks_shot.exe web/test/web_shot.mjs ../examples/particles 800 600 1 30 120`.
Machine: Apple M1, Google Chrome 154.0.8037.98 `--headless=new` (Metal WebGPU adapter), node 24.19.0.

What runs: `marks_shot` renders the native picture of fixed-step frames 1, 30 and 120 (core executor, `Marks_scene`,
`Canvas` at density 1; dt 1/60, pointer (100, 100), 800x600). `web_shot.exe` starts `rays-lisp web --watch
examples/particles/sketch.rays -o DIR --port 0` (127.0.0.1, COOP/COEP), and `web_shot.mjs` opens the served page in
Chrome. The page runs `start` (one `GPUDevice`, worker pool, presenter, watcher). The script then halts the rAF loop
(`__rays.halt()`), resets the state slots (`__rays.load(__rays.program)`) and drives `__rays.stepFrame` itself with
the fixed clock (`t = frame/60`, `dt = 1/60`, `frame = tick = frame`, size 800x600, no events, keys or buttons) from
frame 1 to 120, presenting at dpr 1 and reading the canvas back (`drawImage` then `toDataURL`) at the three frames.

Tolerance: largest channel difference per pixel; a frame passes when at most 0.5% of its pixels differ by more than 8
and none by more than 64 (`compare` in `tools/web/test/png.mjs`, the metric of the P6.4 pixel checks).

| Frame | Pixels differing by > 8 | Worst | Mean |
| --- | --- | --- | --- |
| 1 | 0 of 480,000 | 0 | 0.0000 |
| 30 | 0 of 480,000 | 0 | 0.0000 |
| 120 | 0 of 480,000 | 0 | 0.0000 |

Each frame is 2 mark entries (the background polygon and one point set of 10,000 particles); the particles live in
state and are computed by frame-level loops in f64, so web and native positions agree to the last bit and the picture
is exact. Counters: 0 CPU region invocations and 0 GPU dispatches (nothing in this program is a region). The three web
PNGs are kept beside the native ones in the temporary directory only when the check fails.
Exit codes of `web_shot.exe`: 0 pass or skipped (a missing node or Chrome prints why), 1 mismatch, 2 usage, 3 WebGPU
unavailable (checked with `WEB_SHOT_CHROME_FLAGS="--headless=new --disable-gpu --disable-features=WebGPU"`, which gives
"WebGPU is present but no GPU adapter is available" and exit 3), 4 a tool or the page failed.

## 2026-10-11: all 15 eligible workspaces in the browser (P6.R)

Command: `node tools/web/test/open_all.mjs _build/default/tools/lisp/lisp.exe . <the 15 directories>` (also in
`@qualification-web`). Machine: Apple M1, Chrome 154 `--headless=new`, node 24. Each workspace is exported as
`rays-lisp web` does, served with COOP/COEP, and its `index.html` is opened (`start`: one device, worker pool,
presenter, rAF loop with the real clock). Pass: at least 5 frames within 20 s, still advancing 0.5 s later (about 30
more frames), no failed frame (`__rays.error`), no presenter error, a non-empty mark table.

| Workspace | Result | Frames after about 0.5 s | Mark entries | Region work |
| --- | --- | --- | --- | --- |
| examples/audio | opened | 10 then 40 | 10 | none |
| examples/basic | opened | 9 then 39 | 3 | none |
| examples/drawing | opened | 8 then 38 | 292 | none |
| examples/file_dialog | opened | 8 then 38 | 4 | none |
| examples/generative | opened | 9 then 39 | 10 | none |
| examples/noise | opened | 10 then 40 | 2 | none |
| examples/particles | opened | 11 then 41 | 2 | none |
| examples/pxui | opened | 10 then 40 | 3 | none |
| examples/recursive_rectangles | opened | 7 then 37 | 8 | none |
| sketches/flow_contours | refused `E_WEB_IMAGE` at 77:3 | | | |
| sketches/flow_image | refused `E_WEB_IMAGE` at 5:3 | | | |
| sketches/flow_image_kernel | refused `E_WEB_IMAGE` at 7:3 | | | |
| sketches/flow_particles_gpu | opened | 8 then 38 | 2 | 38 GPU dispatches, 0 CPU invokes |
| sketches/flow_shader | refused `E_WEB_IMAGE` at 67:3 | | | |
| sketches/flow_vectors | opened | 10 then 40 | 2 | none |

11 open, 4 are refused with a code and a span, none fails. Unlike `web_parity.exe` (node: marks against the native
executor), this checks the real page: workers, one WebGPU device, presenter, `start`'s loop.

## P7.3 browser numbers

Date 2026-10-11. Machine: Apple M1 (16 GB, macOS 27.0.1), integrated GPU through Chrome's Metal WebGPU adapter;
Google Chrome 154.0.0.0 `--headless=new`, node 24.19. Load averages while measuring: 3.8 to 17 (other agents were
building and benchmarking; `uptime` before the first run: 17.0, after the last: 3.8), so read the numbers as
indicative. Canvas 900x700, dpr 1.

Workspaces: copies of `sketches/million_marks/sketch.rays` (not edited in the checkout) with `count` 10000 or 1000000.
animated = as checked in (marks drift with `t`, one dispatched GPU kernel). static = the drift term removed, so the
export folds the region to a constant CPU buffer (24 MB at 1M) that the presenter currently re-uploads every frame:
measured as it is. panning = static marks with the pan offset `(* 100 (sin t))` in place of `view.x`, so only the
transform changes (regions may not capture pointer state, `E_WEB_CAPTURE`).

Command per case (`DIR` holds the variant's `sketch.rays`):
`_build/default/tools/web_shot.exe --time 300 _build/default/tools/lisp/lisp.exe _build/default/tools/marks_shot.exe tools/web/test/web_shot.mjs DIR 900 700`

`--time N` skips the native render and comparison. Phase 1: the page's own rAF loop runs, the interval between
consecutive `presenter.present` calls is recorded for N frames ("rAF"; headless Chrome paces it at 60 Hz, 16.7 ms,
and the loop does not wait for the GPU). Phase 2: the loop is halted and N frames are driven by hand, each timed as
`stepFrame` + `present` + `await device.queue.onSubmittedWorkDone()` ("uncapped", the real per-frame cost). Load =
`performance.now()` at the first presented frame (navigation start; includes module load, device, worker pool, data.bin
fetch). Compile = `createGpu` around shader-module and pipeline creation (`gpu.compileMs`).

| Marks | Case | rAF median / p95 ms | Uncapped median / p95 / mean ms | Load ms | Compile ms | counts (invoke, gpu) |
| --- | --- | --- | --- | --- | --- | --- |
| 10,000 | static | 16.5 / 22.7 | 1.93 / 2.43 / 2.07 | 254 | 0.0 (no kernel) | 0, 0 |
| 10,000 | panning | 16.7 / 21.2 | 2.00 / 2.50 / 2.11 | 255 | 0.0 (no kernel) | 0, 0 |
| 10,000 | animated | 16.5 / 23.0 | 1.17 / 1.49 / 1.22 | 264 | 2.3 | 0, 607 |
| 1,000,000 | static | 23.7 / 34.3 | 34.1 / 40.1 / 35.4 | 311 | 0.0 (no kernel) | 0, 0 |
| 1,000,000 | panning | 23.5 / 32.0 | 39.5 / 41.3 / 38.6 | 295 | 0.0 (no kernel) | 0, 0 |
| 1,000,000 | animated | 21.3 / 43.5 | 29.9 / 32.7 / 30.3 | 297 | 14.8 | 0, 605 |

`gpu` counts both phases (about 300 frames each plus frames the loop ran while the page started); no case runs a CPU
region (`invoke` 0) and none reports a presenter error.

Findings:
- 10,000 marks cost about 1 to 2 ms per frame in every case: the 60 Hz cap, not the work, sets the rAF numbers.
- 1,000,000 marks cost 30 to 40 ms per frame (25 to 33 fps uncapped). The rAF median (21 to 24 ms) is below the
  uncapped cost because the rAF loop does not wait for the GPU between frames; the uncapped column is the honest one.
- The static and panning cases at 1M are not faster than animated (34 and 39 against 30 ms): the 24 MB CPU buffer is
  re-uploaded every frame, which costs more than dispatching the drift kernel and keeping its output on the GPU.
  Recorded in `DEFERRED.md` (presenter cache of CPU attribute buffers by array identity).
- Kernel compile is 2.3 ms (10,000) and 14.8 ms (1,000,000): the kernel text is the same apart from the count, and the cause of the
  difference was not investigated; either is far below load time (250 to 310 ms).

## P7.2 native numbers

Machine: Apple M1 (8 cores), macOS 27.0.1, OCaml 5.3.0, dune default profile. Date 2026-10-11. Load average is the
1-minute value from `uptime` when the 300-frame run started. Other agents shared the machine (load 1.6 to 5.0).

Workspaces: `sketches/million_marks/sketch.rays` (not edited) and scratch copies in
`/private/tmp/claude-501/-Users-snowbear-WORK-GIT-rays/961730dd-cb7d-4b51-bb31-2fda1a4140a6/scratchpad/p72/`, each
checked with `_build/default/tools/lisp/lisp.exe check`:
- 10,000 marks: `count 1000000` changed to `count 10000`.
- static: the drift term `(* 0.1 (sin (+ t (* x 6.0))))` replaced by `0.0`, so no mark reads `t`.
- panning: static, and the translate x `view.x` replaced by `(* 100.0 (sin t))`, so the transform changes each frame
  and the marks do not.
- animated: as checked in (marks drift with `t`).

Each variant is compiled to an executable with the link line dune uses for `sketches/million_marks/main.exe`
(captured from `dune rules`), so it runs the same workspace code path. There is no `rays-lisp run` subcommand and no
harness takes a `.rays` file, so the method is:
- Wall frame time: `(median wall at 300 frames - median wall at 1 frame) / 299`, 3 runs each, wall from perl
  `Time::HiRes`. The 1-frame run cancels startup and the first frame.
- CPU per frame: the same subtraction on `user + sys` from `/usr/bin/time -p`, one run each. This leaves out GPU
  execution and waiting on the display.
- Bytes per frame: `(allocated_words at 300 - allocated_words at 1) * 8 / 299` from the `OCAMLRUNPARAM=v=0x400`
  summary at exit (OCaml heap only, not Metal memory). Run-1 values; the three runs agree within 0.1 percent.

Commands (`P=/private/tmp/claude-501/-Users-snowbear-WORK-GIT-rays/961730dd-cb7d-4b51-bb31-2fda1a4140a6/scratchpad`):
`RAYS_MAX_FRAMES=300 OCAMLRUNPARAM=v=0x400 $P/p72/bin/<case>.exe` and the same with `RAYS_MAX_FRAMES=1`, where
`<case>` is `static_10k`, `static_1m`, `panning_10k`, `panning_1m`, `animated_10k` or `animated_1m`. Each executable is
built with `bash $P/build_variant.sh <case>`. Timing is `$P/measure.sh <cases>` (wall) and `$P/cpu.sh <cases>`
(CPU, `/usr/bin/time -p`).

| Marks | Case | Frame ms (wall, median of 3) | CPU ms per frame | Bytes per frame | Load (1 min) |
| --- | --- | ---: | ---: | ---: | ---: |
| 10,000 | static | 16.66 | 3.7 | 302,297 | 1.56 |
| 10,000 | panning | 16.73 | 6.4 | 1,883,692 | 2.14 |
| 10,000 | animated | 16.68 | 4.1 | 360,968 | 3.45 |
| 1,000,000 | static | 33.85 | 4.3 | 301,993 | 2.51 |
| 1,000,000 | panning | 49.56 | 51.6 | 233,420,712 | 5.03 |
| 1,000,000 | animated | 33.40 | 5.4 | 357,910 | 2.82 |

Vsync caveat: every wall value is a whole multiple of the 60 Hz interval (16.7 ms): 1x for the 10,000 rows, 2x for
1M static and animated (33.4 ms), 3x for 1M panning (50 ms). The wall column is therefore the display cap, an upper
bound quantized to 16.7 ms steps, not the cost. The CPU column is the better estimate of per-frame work, and it
excludes GPU execution.

Findings:
- 10,000 marks: about 3.7 to 6.4 ms of CPU per frame; the 16.7 ms wall time is the display cap.
- 1,000,000 animated and static: about 4 to 5 ms of CPU per frame and about 0.3 MB allocated per frame, independent of
  the count. The marks are computed on the GPU or kept out of the OCaml heap, so per-frame CPU does not scale with 1M.
- 1,000,000 panning is the expensive case: about 52 ms of CPU and 233 MB allocated per frame, against 1.9 MB at 10,000.
  Only the transform changes, yet the mark set is rebuilt each frame, so per-frame work scales with the count. This
  contradicts the P4.10 intent (a transform change must not redo CPU work on an unchanged batch). Not investigated or
  fixed in this entry; it is a candidate for a follow-up task.
- The 1-frame runs of static and panning at 1M take about 22 s and allocate about 79 GB (`allocated_words` near 9.9e9),
  against 0.4 s for animated at 1M. The subtraction removes this first-frame cost, but it is unexplained and worth a look.

### Addendum 2026-10-11: both findings traced

Finding B (panning, 52 ms and 233 MB per frame) was not a mark rebuild. `Marks_scene` kept its scene node (a debug
counter showed 4 cache misses in 200 frames, all on frame 1). The cost was after it: a moved `draw/translate` makes
a new scene, `Scene.stage_scene2_layer` misses its cache, and `stage_materialized` calls
`Render_ir.create_internal`, which ran `Shape_batch.Private.valid` over every instance (boxed float reads,
`Shape_batch.float`/`loop` in `sample`) of a batch it already held. The P4.10 bench (`tools/bench_marks.ml`) stops at
`Drawing.render_prepared`, so it never reached the staging. Fix (4decc9f0): a published batch remembers that it
validated (`checked`). `lib/scene_command/test_shape_batch.ml` asserts that restaging an unchanged 20,000-instance
batch allocates under 4 KB (fails without the fix).

Remeasured with `cpu.sh`/`build_variant.sh`, same method as above (one run each, load 2.5 to 3):

| Marks | Case | CPU ms per frame, before | CPU ms per frame, after | Bytes per frame, before | Bytes per frame, after |
| --- | --- | ---: | ---: | ---: | ---: |
| 1,000,000 | panning | 51.6 | 3.0 | 233,420,712 | 321,000 |

Finding A (first frame 22 s, 79 GB for static and panning at 1M, not changed): `sample` shows the time in
`Flow.Eval` (`ev`, `apply_op`, `Op.find`, `List.mem`, `caml_compare`): the static stage walks the whole `map` over
1,000,000 indices with the tree walker, about 22 microseconds and 79 KB per element. A map that reads `t` becomes a
residual and runs as a kernel (0.4 s). Not fixed here; the change is in `DEFERRED.md` (web export section). After the
B fix the 1-frame panning run is still 23.1 s real, 9.93e9 allocated words.

### Addendum 2026-10-11: where the 1.7 GB of a static 1,000,000-mark start went

Cumulative OCaml allocation (`OCAMLRUNPARAM=v=0x400`, all domains), 1 frame, peak from `/usr/bin/time -l`, M1, load 4 to
6, scratch executables built with the link line above (`static_alloc/build.sh`), dune dev profile:

| 1,000,000 marks | Wall s (1 frame) | Allocated MB | Peak RSS MB | Peak footprint MB | Per extra frame (300 vs 1) |
| --- | ---: | ---: | ---: | ---: | ---: |
| static, before | 0.83 | 1,680 | 578 | 511 | not measured |
| static, after | 0.85 | 1,032 | 565 | 496 | 295 KB |
| panning, before | 1.28 | 1,680 | 580 | 513 | 318 KB |
| panning, after | 1.27 | 1,032 | 563 | 496 | 314 KB |
| animated, before and after | 0.88 / 0.79 | 214 | 257 | 202 | 351 KB |

Evidence: `Gc.Memprof` (sampling 1e-4 words, 16-frame stacks, prelude prepended to the generated `.ml`; it sees the main
domain only, which allocates the bulk) and `Gc.allocated_bytes` printed at each call of `Flow_ir.static_map`. Findings:
- Three static evaluations of the same workspace per start, each with its own 4,096-element walk and its own kernel run:
  `Contexts.of_workspace` from `Core_setup.workspace_doc`, `Contexts.of_workspace` from `Workspace.declared_camera`, and
  `Contexts.window`. Each costs about 140 MB of main-domain allocation (the walked head, the 24 MB output, the
  per-chunk register scratch). That is about 420 MB, the largest remaining part.
- `Packed.force_all` built a closure per element (`Array.iteri (fun k registers -> ...)` inside the loop over
  elements): about 112 bytes an element, 336 MB over the three forces. Fixed with a counted loop.
- `Shape_batch.Private.valid` and `Builder.append` used local closures that return floats, which box them: 262 MB
  at 1,000,000 instances (ocamlopt without flambda does not unbox across a local closure). Fixed with top-level
  `[@inline]` accessors.
- Left, all result-sized or per-mark: copies of the 64-byte-per-instance batch (`Builder.create`, `publish`'s `Bytes.sub`,
  the lowering `Bytes.copy`, `ui_index_bytes`, the upload `Bytes.concat`: about 380 MB), and the CPU marks builder's
  tuples and boxed floats per mark (`Marks_scene.pairs`, `Builder.style`, `circle`: about 170 MB).

Not reached: under 150 MB needs the three evaluations to become one (a cache across `Contexts.of_workspace` and
`Contexts.window`, which today each receive their own checked workspace) and the static marks to go to the GPU or be built
without the intermediate copies. Both are design changes, not allocation fixes. Test: `lib/flow_ir/test_static_map`
bounds the marginal allocation of a static map at 64 bytes an element on one domain (155 before, 43 after).

### Addendum 2026-10-12: one evaluation a start, one copy of a static batch

Before = `07dc39f7`, after = this branch. Variants and method as above (`static`, `panning`, `animated` at 1,000,000 and
10,000 marks, built with dune's link line for `sketches/million_marks/main.exe`), plus `examples/basic` and
`examples/particles` (`lisp.exe` as dune builds it). Both sets of executables were kept and run alternately, one before, one
after, per round, in one session: Apple M1, dune dev profile, 1-minute load 2.2 to 9.5 from other agents (each run's
load is in the logs; 3.7 to 9.5 during the 1-frame set, 2.2 to 6.3 during the 300-frame sets). One frame: `OCAMLRUNPARAM=v=0x400 RAYS_MAX_FRAMES=1 /usr/bin/time -l APP`, wall from
perl `Time::HiRes`, one unlogged warm-up, median of 5. Scripts and logs are in
`/private/tmp/claude-501/-Users-snowbear-WORK-GIT-rays/961730dd-cb7d-4b51-bb31-2fda1a4140a6/scratchpad/sm/` (`build.sh`,
`measure.sh`, `summary.pl`, `steady.pl`, `bench.sh`, `runs/one.txt`, `runs/many.txt`, `runs/long.txt`).

| Case | Wall s, 1 frame | CPU s (user + sys) | Allocated MB | Peak RSS MB | Peak footprint MB |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1,000,000 static | 0.812 to 0.608 | 1.48 to 0.77 | 1,032.1 to 288.1 | 565.4 to 375.5 | 496.6 to 306.4 |
| 1,000,000 panning | 0.814 to 0.620 | 1.50 to 0.77 | 1,032.1 to 288.2 | 564.5 to 376.8 | 495.8 to 307.9 |
| 1,000,000 animated | 0.413 to 0.388 | 0.32 to 0.30 | 213.8 to 93.0 | 257.9 to 206.1 | 202.1 to 150.3 |
| 10,000 static | 0.392 to 0.330 | 0.35 to 0.27 | 356.1 to 144.6 | 147.5 to 145.3 | 78.6 to 76.5 |
| 10,000 panning | 0.396 to 0.329 | 0.35 to 0.27 | 356.2 to 144.7 | 146.9 to 145.4 | 78.0 to 76.7 |
| 10,000 animated | 0.297 to 0.293 | 0.23 to 0.24 | 42.6 to 40.6 | 142.0 to 142.6 | 73.4 to 73.9 |
| `examples/basic` | 0.291 to 0.295 | 0.23 to 0.23 | 36.5 to 36.4 | 140.5 to 140.7 | 68.3 to 68.6 |
| `examples/particles` | 0.345 to 0.314 | 0.29 to 0.27 | 169.7 to 99.7 | 159.2 to 159.0 | 89.1 to 89.0 |

Noise. Allocation is exact (the five runs agree to 0.01 percent). Wall spreads 0.01 to 0.02 s over five runs and CPU is
reported in steps of 0.01 s. Peak RSS and footprint spread about 1.3 MB between runs of one executable, and the same
executable's median moved by as much between sets (10,000 animated before: 142.0, 141.9 and 140.6 MB in three sets). The
three rows where the after median is the higher one are inside that: repeated with 10 runs each, 10,000 animated is
0.296 to 0.297 s, 0.23 to 0.23 s CPU, RSS 141.9 (140.9 to 142.2) to 142.2 (141.0 to 142.7), and `examples/basic` is
0.296 to 0.297 s, RSS 140.5 (140.1 to 140.8) to 140.7 (139.7 to 141.0); a third set of 7 gave 10,000 animated RSS 140.6
to 140.7 and footprint 73.2 to 73.4. The OCaml heap of that case is not larger (`top_heap_words` 1.50 to 1.53 M before,
1.41 to 1.52 M after).

Frames, P7.2 method (`(300 frames - 1 frame) / 299`, medians; 7 runs at 300 frames for the 1M rows and the 10,000 rows):

| Case | CPU ms per frame, before | after | Bytes per frame, before | after | Wall ms per frame |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1,000,000 static | 4.35 (4.31 to 4.52) | 4.41 (4.28 to 4.45) | 298,827 | 298,815 | 33.49 to 33.55 |
| 1,000,000 panning | 4.48 (4.31 to 4.75) | 4.62 (4.52 to 4.75) | 317,874 | 317,793 | 33.49 to 33.46 |
| 1,000,000 animated | 5.65 (5.28 to 5.95) | 5.55 (5.35 to 5.65) | 355,904 | 355,951 | 33.50 to 33.51 |
| 10,000 static | 4.05 (3.95 to 4.35) | 3.98 (3.88 to 4.11) | 302,645 | 299,127 | 16.73 to 16.70 |
| 10,000 panning | 4.21 (4.08 to 4.41) | 4.21 (3.98 to 4.41) | 314,121 | 314,111 | 16.74 to 16.71 |
| 10,000 animated | 5.12 (4.55 to 5.25) | 5.18 (5.02 to 5.25) | 358,961 | 358,985 | 16.71 to 16.75 |

Wall is the display cap, as before. The subtraction carries the noise of its 1-frame term (CPU in 0.01 s steps, so
0.03 ms a frame a step, and the before start does 0.7 s more work), which is all of the 1M panning difference: the
300-frame totals are 2.84 s of CPU before and 2.15 after, and between 300 and 600 frames (3 runs of 600, startup cancelled
exactly) a frame costs 4.53 ms before and 4.47 after for panning, 4.30 and 4.20 for static, with 307,094 and 307,370, 288,050
and 288,098 bytes. Bytes per frame move in steps of about 3,550 between runs of one executable (a megabyte that falls in
frame 1 or later), so the columns are equal within one step; the 1M animated runs span 355,857 to 355,974 on both sides.

Benches, same alternation (`tools/bench_marks.exe` 7 runs, `bench_marks_gpu.exe` 3 runs, medians, load 2.2 to 5.8):

| `bench_marks` row | ms before | ms after | Bytes before | Bytes after |
| --- | ---: | ---: | ---: | ---: |
| circles static 100,000 and 1,000,000 | 0.000, 0.001 | 0.000, 0.001 | 1,136 | 1,136 |
| rects static 100,000 and 1,000,000 | 0.001, 0.001 | 0.001, 0.001 | 1,136 | 1,136 |
| circles animated 100,000 | 12.375 | 11.745 | 51,331,680 | 38,531,648 |
| rects animated 100,000 | 12.380 | 12.000 | 50,531,632 | 40,931,512 |
| circles animated 1,000,000 | 118.524 | 112.317 | 513,428,264 | 385,427,856 |
| rects animated 1,000,000 | 119.241 | 113.292 | 505,427,968 | 409,428,400 |
| translate moving 100,000 | 0.004 (0.003 to 0.006) | 0.005 (0.004 to 0.006) | 6,792 | 6,792 |
| translate moving 1,000,000 | 0.006 (0.005 to 0.015) | 0.007 (0.005 to 0.016) | 6,792 | 6,792 |

The translate rows time one frame with a microsecond clock, so a median moves by a whole microsecond. The same frame in a
loop of 20,000 (a scratch copy of the row linked against each library set, median of 9 samples, 3 runs): 1.424, 1.426,
1.433 microseconds before and 1.435, 1.431, 1.419 after at 100,000; 1.436, 1.423, 1.429 and 1.432, 1.433, 1.422 at
1,000,000; 6,696 bytes in all. `bench_marks_gpu.exe`: every row allocates the same bytes before and after (8,026,488 for
circles uniform at 1,000,000, 24,059,056 for moving both), and the times are within 3 percent either way (circles at
1,000,000: uniform 4.611 to 4.655, per-instance 4.689 to 4.647, moving both 13.824 to 13.842; rects: 4.621 to 4.599,
4.721 to 4.630, 14.056 to 13.940).

Where it went (`Gc.Memprof`, initial domain, `static` 1M, one frame; before 1,044 MB, after 291 MB):

| Part | Before MB | After MB |
| --- | ---: | ---: |
| Static evaluation (4,096 walked elements about 85, the 24 MB output, `array/range` 8) | 421 (three: 142, 140, 139) | 144 (one) |
| Kernel register scratch on the initial domain (one array a chunk) | 65 | 21 |
| `Marks_scene`: the batch (64 MB; sampled) | 62 | 66 |
| `Marks_scene`: `publish` copy, tuples and boxed floats per mark | 260 | 0 |
| Lowering: batch copy 68, index table 24 and its closures 58, index copy 24 | 174 | 24 |
| Upload: joined indices and uniforms | 24 | 0 |
| Catalog digest, editor, pipelines | 38 | 36 |

1. One evaluation a start. `Workspace.run` built the document three times: for the window (`Contexts.window`), for the
   camera (`declared_camera`) and in the editor. It builds it once, reads the window from that document's plan
   (`Contexts.document_window`, equal to `Contexts.window` on the 43 checked-in files that open) and the camera from its
   scene, and hands it to the editor (`?opened`, private). A hand-over, not a cache: the reference is dropped when the
   editor takes it, and an edit, a save and a reload lower their text as before. This is the whole gain of the 10,000
   rows and of `examples/particles`.
2. `Shape_batch.Builder.publish` gives a full builder's storage to the batch (an append past a full buffer already moved
   to a new one, so a published batch stays immutable), and `circles`, `rects`, `lines` write a whole set from the
   attribute arrays. The dev profile compiles opaque, so every float handed to `circle` from `Marks_scene` was boxed;
   `Marks_scene` uses the whole-set writers for a set with constant colours.
3. Lowering draws from the batch's own bytes (it copied them), writes the index table with a plain loop and shares it
   with a batch that needs all of it, and the first upload writes indices and uniforms apart.

Not reached: 250 MB and 260 MB of peak RSS. What a static 1M start still allocates is one evaluation (the walker's 4,096
elements are the contract), the 64-byte instances once and the indices once; its peak RSS over the animated variant
(375 against 206) is the batch on the CPU and again on the GPU (128 MB against 12 MB of device positions), the 24 MB
static array, and about 30 MB of garbage not yet swept. Getting under that means no 64-byte instances, and the two routes
that avoid them do not keep the pixels. As a GPU region the positions would be binary32 results, not the walker's. As
host buffers of the `Marks` family they are the walker's values, but the shader adds the radius in binary32: with the
sketch's static positions as a host buffer beside a GPU radius, 85 of 630,000 pixels differ from the `Shape_batch`
picture at 2,000 marks, 643 at 20,000, 1,676 at 200,000 and 466 at 1,000,000, each by one step of one channel
(`marks.md`, "Routing"). `DEFERRED.md` has the step that would do it exactly.

Tests: `test/test_workspace_start` (`@runtest-native`: a 1M static start is 1 evaluation, was 3, and under 400 bytes a
mark on the initial domain, 280 against about 1,040; a file that differs from the built text reloads and the host
graph names a picture after the file's static value, 2 evaluations), `test/test_workspace_doc` (window of the opened
document on every checked-in file), `lib/scene_command/test_shape_batch` (a full builder publishes in under 1 KB and
the batch survives later appends; whole-set writers equal one call an instance over strides 0, 2 and 3, with the same
refusal at the same instance, and allocate under 4 KB for 50,000 circles), `lib/rays_editor/marks_scene_test` (eleven
constant-colour sets equal their mark-by-mark batches, five of them refusals; 64.0 bytes a mark for 100,000 static
circles, about 330 before), `lib/rays_execution/test_shapes_lowering` (`@runtest-native`: 24.5 bytes an instance on the
first frame of a 100,000-instance batch, about 170 before, 0.3 after). Region, draw, JS, WGSL and Metal snapshots and
the parity goldens are unchanged.

## P7.4 evaluation

Date 2026-10-11. Every number below is copied from the section named in its table, or counted by the commands
listed under table 4 on this date. Nothing was re-measured. A value that is not in results.md is written "not recorded".

### 1. Meaning preserved

| Check | Source section | Scope | Result | Worst difference | Pixels differing by more than 8 |
| --- | --- | --- | --- | --- | --- |
| Node vs native marks, 120 frames | P5.13, addendum (P6.4a) | 15 workspaces | 11 pass, 4 refused `E_WEB_IMAGE`, 0 fail | n/a (floats within 1e-6, rest exact) | n/a |
| Hand-built pixel tables (`present_check.mjs`) | P6.4 | 76 checks, 100x100 | 0 failures at colour tolerance 2/255 | not recorded (tolerance 2, not the 8 metric) | not recorded |
| End to end, `sketches/flow_vectors` | P6.4 | 5 frames, 307,200 px | pass | 1 | 0 of 307,200 |
| End to end, `examples/basic` | P6.4 | 5 frames, 300,060 px outside text | pass | 0 | 0 of 300,060 |
| Synthetic 2,048 circles, GPU positions and radii | P6.4a | 5 frames, 307,200 px | pass | 1 | 0 of 307,200 |
| `sketches/flow_particles_gpu`, 1,000,000 circles on the GPU | P6.4a | 5 frames, 480,000 px | pass | 1 | 0 of 480,000 |
| `examples/particles`, frame 1 | P6.8 | 800x600 vs `marks_shot` | pass | 0 | 0 of 480,000 |
| `examples/particles`, frame 30 | P6.8 | same | pass | 0 | 0 of 480,000 |
| `examples/particles`, frame 120 | P6.8 | same | pass | 0 | 0 of 480,000 |

The P5.13 main table (10 pass, 5 refused) is superseded by its addendum (11 pass, 4 refused). The pixel gate is at
most 0.5% of pixels above 8 and none above 64. Text is excluded from the per-pixel counts: P6.4 compares text boxes
by total brightness because Chrome's ink differs from SDL_ttf's. Image, blend and clip entries are not reached by an
export (P6.4 "Not covered"), so no row here covers them.

### 2. Coverage

| Workspace | Export (P5.13, addendum) | Node parity, 120 frames (P5.13, addendum) | Opens in Chrome (P6.R) |
| --- | --- | --- | --- |
| `examples/audio` | yes | pass | opened |
| `examples/basic` | yes | pass | opened |
| `examples/drawing` | yes | pass (refused `E_WEB_LOWER` before the P5.13a budget raise) | opened |
| `examples/file_dialog` | yes | pass | opened |
| `examples/generative` | yes | pass | opened |
| `examples/noise` | yes | pass | opened |
| `examples/particles` | yes | pass | opened |
| `examples/pxui` | yes | pass | opened |
| `examples/recursive_rectangles` | yes | pass | opened |
| `sketches/flow_contours` | refused `E_WEB_IMAGE` 77:3 | not run (not exported) | refused at export |
| `sketches/flow_image` | refused `E_WEB_IMAGE` 5:3 | not run (not exported) | refused at export |
| `sketches/flow_image_kernel` | refused `E_WEB_IMAGE` 7:3 | not run (not exported) | refused at export |
| `sketches/flow_particles_gpu` | yes | pass | opened |
| `sketches/flow_shader` | refused `E_WEB_IMAGE` 67:3 | not run (not exported) | refused at export |
| `sketches/flow_vectors` | yes | pass | opened |

Totals: 11 export and pass parity and open; 4 are refused with a code and a span; 0 fail.

### 3. Run-time cost

| Marks | Case | Native CPU ms/frame (P7.2) | Native bytes/frame (P7.2) | Browser uncapped median ms/frame (P7.3) | Browser load ms (P7.3) | Browser compile ms (P7.3) |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 10,000 | static | 3.7 | 302,297 | 1.93 | 254 | 0.0 (no kernel) |
| 10,000 | panning | 6.4 | 1,883,692 | 2.00 | 255 | 0.0 (no kernel) |
| 10,000 | animated | 4.1 | 360,968 | 1.17 | 264 | 2.3 |
| 1,000,000 | static | 4.3 | 301,993 | 34.1 | 311 | 0.0 (no kernel) |
| 1,000,000 | panning | 51.6 | 233,420,712 | 39.5 | 295 | 0.0 (no kernel) |
| 1,000,000 | animated | 5.4 | 357,910 | 29.9 | 297 | 14.8 |

Native CPU excludes GPU execution, and native wall time is left out because every wall value is a multiple of the
60 Hz vsync interval, so it is a cap, not a cost (P7.2). Both sets come from the same Apple M1 under shared-machine
load (native 1-minute load 1.56 to 5.03, browser 3.8 to 17), so the numbers are indicative; browser load is measured
from navigation start and has no native counterpart. The native and browser columns are different measurements and
no ratio between them is given.

### 4. Lines shared against lines per target

| Target | Files counted | Lines |
| --- | --- | ---: |
| Shared: `lib/flow_ir` library modules (`.ml` and `.mli`) | 10 modules | 4,674 |
| Native-only: `lib/flow_gpu` library modules | 5 modules | 615 |
| Web-only: `lib/flow_web` library modules | 5 modules | 894 |
| Web-only: `tools/web/runtime` (`*.js`, `*.wgsl`) | 7 files (6 `.js`, 1 `.wgsl`) | 1,480 |
| Native total (shared + native-only) | | 5,289 |
| Web total (shared + web-only, both rows) | | 7,048 |
| Tests: `lib/flow_ir` `test_*.ml`, plus `core_fixtures.ml` and `region_snapshot.ml` | 2,349 + 176 + 65 | 2,590 |
| Tests: `lib/flow_gpu` `test_*.ml` | | 856 |
| Tests: `lib/flow_web` `test_*.ml` | | 537 |
| Tests: `tools/web/test/*.mjs` | | 1,408 |
| Tests total | | 5,391 |

Commands, from the repository root:

    find lib/flow_ir -maxdepth 1 \( -name '*.ml' -o -name '*.mli' \) ! -name 'test_*' ! -name core_fixtures.ml ! -name region_snapshot.ml | xargs wc -l | tail -1
    find lib/flow_gpu -maxdepth 1 \( -name '*.ml' -o -name '*.mli' \) ! -name 'test_*' | xargs wc -l | tail -1
    find lib/flow_web -maxdepth 1 \( -name '*.ml' -o -name '*.mli' \) ! -name 'test_*' | xargs wc -l | tail -1
    wc -l tools/web/runtime/*.js tools/web/runtime/*.wgsl | tail -1
    find lib/flow_ir -maxdepth 1 -name 'test_*.ml' | xargs wc -l | tail -1
    wc -l lib/flow_ir/core_fixtures.ml lib/flow_ir/region_snapshot.ml | tail -1
    find lib/flow_gpu -maxdepth 1 -name 'test_*.ml' | xargs wc -l | tail -1
    find lib/flow_web -maxdepth 1 -name 'test_*.ml' | xargs wc -l | tail -1
    find tools/web/test -maxdepth 1 -name '*.mjs' | xargs wc -l | tail -1

The shared set is the library's `(modules ...)` list in `lib/flow_ir/dune`. `core_fixtures.ml` and
`region_snapshot.ml` are excluded because only test stanzas link them. The literal `find` with only
`! -name 'test_*'` gives 4,915, which includes them. Goldens (`*.expected`, `*.metal`, `goldens/*`, `snapshots/*`)
are data and are not counted. These are line counts, not a measure of complexity.

## 2026-10-11 addendum: native teardown footprint, and what a frame retained

`DEFERRED.md` listed `runtime_native_qualification` as unstable ("physical footprint did not plateau", about 21 MB
over a 9 MB "SDL window baseline", at every commit back to `d88c46b`). It was a real leak, in Rays, in three parts.
Machine: Apple M1, macOS 27.0.1, OCaml 5.3.0, dune dev profile (the Metal bridge is built `-O0`), 1-minute load 3 to
10 from another agent's builds. Footprint is `/usr/bin/footprint -p PID -f bytes` after `Gc.full_major`. Before =
`49c0f65d`.

Method. A scratch executable (not kept) looped one lifecycle at a time and printed the footprint: SDL only
(`Sdl3.Init.init`, window, Metal view, destroy, quit), `Runtime.create`/`destroy`, and N rendered frames of one
triangle in a hidden window followed by `destroy`. `heap -s`, `vmmap -summary` and `footprint` of the 72-cycle loop
at cycles 16, 48 and 71 named what grew; `leaks --trace=ADDRESS` named the owner; `OBJC_DEBUG_MISSING_POOLS=YES` under
`lldb` (breakpoint on `objc_autoreleaseNoPool`, `bt`) named the caller.

Evidence. At cycle 71 the heap held 77 `SDL3Window`, 77 `SDL3_cocoametalview`, 77 `CAMetalLayer` (one per window ever
closed) and 602 `AGXG13GFamilyCommandBuffer` with their 601 render-pass descriptors and encoders (one per frame of
the 600-frame scenario run before the loop). `leaks --trace` gave one owner for a window and a command buffer alike:
`'_main_thread' + 568 --> <@autoreleasepool content>`, the initial thread's root autorelease page. An OCaml program
has no Cocoa run loop, so nothing ever drains that page: an object autoreleased outside a pool of the stub's own is
retained for the life of the process.

1. `lib/sdl3/sdl3_cocoa.c`, `rays_window_plain_titlebar`: `setTitlebarAppearsTransparent:` and
   `setTitleVisibility:` ran with no pool and autoreleased the `NSWindow` about 95 times and its title-bar views (682
   of the 746 reports on the initial thread in one lifecycle). No closed window was ever deallocated: 385 KiB each.
   The test's "SDL window baseline" loop goes through the same function, so it measured Rays, not SDL.
2. `lib/metal/metal_bridge.mm`: `object_of_handle` returned its object unretained, which ARC autoreleases when the
   return-value handshake fails (always at `-O0`); 28 handwritten stubs had no pool (`-contents` in the buffer copies
   autoreleases the buffer: it returns an inner pointer; so did the release-queue drain), nor had the generated
   `presentDrawable:` call. Each frame left its command buffer, encoder, pass descriptor, drawable and every written
   buffer retained: 4.0 KiB of footprint per frame, and the GPU memory of the buffers with them (the 13 to 29 MB
   `IOAccelerator` step the loop showed after a scenario had run).
3. `lib/metal/metal.ml`: every child handle registered a `Gc.finalise` closure that held its parent's lifetime
   record. The frame's command buffer and its encoder were therefore promoted at every minor collection and needed two
   major cycles to go; with the default `space_overhead` the major heap then grows with the frame count instead of
   settling (no major collection completed between frames 8,000 and 16,000 in one run).

Fixes: the three Cocoa helper functions bracket themselves with `objc_autoreleasePoolPush`/`Pop`; handle lookups
return retained, the handwritten stubs open a pool (`Autorelease_pool` guard) and `presentDrawable:` is `pool = true`;
child finalisers are `Gc.finalise_last` closures over the `destroyed` flag and the parent's dependent counter, not
the records.

| Measurement | Before | After |
| --- | ---: | ---: |
| Qualification loop, floor of cycles 24-47 and of 48-71, KiB | 59,408 and 80,929 | 35,296 and 35,296 |
| Qualification growth between the floors, KiB (three runs after) | 21,521 (and 20,048, 22,624) | 0, 16, 48 |
| "SDL window baseline" the test subtracted, KiB | 9,280 | 0 |
| SDL-only lifecycle, KiB per lifecycle (cycles 8 to 48) | 385 | 2.4 |
| `Runtime.create`/`destroy`, KiB per lifecycle (cycles 8 to 80) | 412 | 0 (24,896 at 8, 24,688 at 80) |
| Footprint after 600 / 6,000 frames and `destroy`, KiB | 37,792 / 59,520 | 28,640 / 28,848 at 24,000 (a full major every 1,000 frames) |
| Per rendered frame, KiB | 4.02 | 0 |
| Objects autoreleased with no pool, initial thread, one lifecycle and two frames | 746 | 0 |
| The same, `examples/particles`, 30 frames | 2,006 | 0 |
| OCaml heap, no forced collection: footprint after 24,000 frames and `destroy`, KiB | 40,064 | 30,416 |
| The same after 96,000 frames and `destroy`, KiB | 65,200 | 30,096 |
| The same during the run, at frame 4,000 and at 24,000, KiB | 37,392 and 46,464 | 36,400 and 36,912 |
| During a 96,000-frame run, at frame 16,000 and at 96,000, KiB | not sampled | 36,592 and 36,592 |
| Major collections completed in 24,000 frames (in 96,000) | 19 | 27 (68) |

The middle step alone (parts 1 and 2 fixed, `Gc.finalise` kept) still grew 0.35 KiB per frame with no forced
collection: 40,064 KiB after 24,000 frames, 47,952 after 48,000, 65,200 after 96,000. `Gc.Memprof` (promotion
callback) attributed the promoted words to `Metal.Command_buffer.create_owned` (its `Hashtbl.create 16`, the
finaliser closures and the lifetime record) and `Render_encoder.create_owned`.

Frame cost is unchanged. Offscreen 64x64 target, 2,000 frames per sample, median of five samples, third of three
alternating before/after pairs (the quietest): one draw 266.5 against 266.0 microseconds per frame, 64 draws with
changing vertex bytes 453.2 against 453.0; 16,032 and 252,288 bytes allocated per frame in both.

Tests. `runtime_native_qualification` is unchanged (its baseline loop and its 4,096 KiB bound included) and passes:
growth 0 to 48 KiB against a measured baseline of 0 to 64. New `runtime_autorelease`
(`lib/runtime/native_qualification`, `@runtest-native` and `@qualification`) runs two window lifecycles with frames,
readback, resize, cursor, text input and background, and two offscreen ones, in a child with
`OBJC_DEBUG_MISSING_POOLS=YES`, and fails on any report from the initial thread: 773 with the Cocoa fix reverted, 454
with the bridge fix reverted, 0 now. `examples/pxui`, `sketches/million_marks` and `examples/pathtracer` report 0
by hand as well. `dune build @runtest-native` passes.

## 2026-10-11 addendum: per-instance GPU mark colours (P4.13 gate)

Command: `_build/default/lib/rays_editor/native_qualification/bench_marks_gpu.exe` (same method as P4.13: one
`Drawing.render_prepared` with GPU positions under the qualification policy, median of 5 frames at 1,000,000, wall
milliseconds and bytes allocated per frame; the render pass is not included). Apple M1, OCaml 5.3.0, dune dev
profile, 1-minute load 4.3 to 7.7 (another agent building). Before = `49c0f65d` libraries under the new bench source;
the three "moving" rows are new and make the per-instance attribute read `t`, so it is a region of every frame.
"kernels" is the number of GPU runners the frame used.

| kind | style | before ms | before bytes | kernels | after ms | after bytes | kernels | after against uniform |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| circles | uniform | 10.511 | 40,025,808 | 1 | 4.608 | 8,026,472 | 1 | 1.0x |
| circles | radius | 15.602 | 60,025,864 | 1 | 4.769 | 8,026,552 | 1 | 1.0x |
| circles | fill | 78.331 | 188,025,648 | 1 | 4.908 | 8,026,376 | 1 | 1.1x |
| circles | per-instance | 83.222 | 208,025,704 | 1 | 4.701 | 8,026,456 | 1 | 1.0x |
| circles | moving radius | 21.077 | 80,041,848 | 2 | 9.446 | 16,042,512 | 2 | 2.0x |
| circles | moving fill | 122.982 | 269,956,200 | 1 | 9.272 | 16,042,864 | 2 | 2.0x |
| circles | moving both | 148.119 | 308,003,432 | 2 | 14.349 | 24,059,072 | 3 | 3.1x |
| rects | uniform | 10.415 | 40,025,832 | 1 | 4.844 | 8,026,384 | 1 | 1.0x |
| rects | radius | 24.136 | 100,025,832 | 1 | 4.733 | 8,026,416 | 1 | 1.0x |
| rects | fill | 78.545 | 188,025,672 | 1 | 4.705 | 8,026,288 | 1 | 1.0x |
| rects | per-instance | 91.941 | 248,025,672 | 1 | 4.833 | 8,026,320 | 1 | 1.0x |
| rects | moving radius | 20.756 | 80,042,424 | 2 | 9.786 | 16,042,976 | 2 | 2.0x |
| rects | moving fill | 123.720 | 266,018,040 | 1 | 9.296 | 16,042,776 | 2 | 1.9x |
| rects | moving both | 142.444 | 306,034,216 | 2 | 14.452 | 24,059,536 | 3 | 3.0x |

At 100,000 the after rows are 0.66 (uniform), 0.82 (per-instance), 1.44 (moving fill) and 2.08 ms (moving both).

The P4.13 gate (per-instance within 2 times the uniform row at 1,000,000) is met: 1.0x for circles and rects, from
7.9x and 8.8x in the same run. What the note in `DEFERRED.md` guessed was half of it. Three causes, three changes:

1. The bench's per-instance radius, size and fill do not read `t`: they are static regions, computed once on the CPU
   and not placed on the GPU (the frame uses one kernel, the positions; the P4.13 note took the radius for a second
   GPU region). `Marks_scene.gpu_set` nevertheless converted every host attribute of a device set on every frame
   (1,000,000 colours through `drawing_color` into words: 148 MB and 68 ms; a radius or size array into float32).
   Now the bytes of a host array are kept while the array is physically the previous frame's, so they are neither
   converted nor uploaded again (`Rays_execution.gpu_marks` already skipped identical bytes).
2. A colour could not be a device attribute, so a fill that does read `t` ran as a CPU region and was converted the
   same way (123 ms). `fill`, `stroke` and `color` are now offered like positions (`Core_exec.device_regions`),
   `Core_marks.colour_attr` and `Marks.validate` accept a device colour of width 3, and `gpu_marks` sets the shader's
   colour mode 1 (float r, g, b) for it. The web export already placed colour regions on the GPU; this is the native
   half.
3. `array/range` boxed a value per index (40 bytes each): 40 MB and about 5 ms a frame for the inline
   `(array/range 1000000)` every kernel of the bench reads. It fills its array directly (8 MB). That is the whole
   change of the uniform row.

Remaining, and why "moving both" is 3x: each frame-rate attribute is its own kernel dispatch on native (the draw
program invokes its regions one by one; `Core_fuse.merge` is used by the web export only), and each dispatch
evaluates, packs and uploads its inline static source again (the 8 MB a kernel still allocates), about 4.7 ms at
1,000,000. A source bound once (`(let* [indices (array/range n)] ...)`, as `sketches/million_marks` does) is a
constant the kernels share and do not upload again.

Correctness: `test_workspace_gpu_marks` (`@lib/rays_editor/runtest-native`) now draws radii, a rect fill and a line
colour that read `t` on the GPU beside host sizes and line ends, requires 8 kernels for its two drawings and equal
pixels with the CPU path at three times; `test_core_marks` checks which attributes become device buffers and the
length refusal; `test_marks` the validation of a device colour. Draw snapshots (CPU scenes) are unchanged.

## 2026-10-11 addendum: a static packed map at startup (P7.2 finding A)

`sketches/million_marks` with its drift term removed (`(* 0.1 (sin (+ t (* x 6.0))))` replaced by `0.0`, so no mark
reads `t`), at 1,000,000 and at 100,000 marks, built as an application with the rule of `examples/particles/dune`
(`rays-lisp ml`, `rays_editor`). Method as in P7.2: one frame, `RAYS_MAX_FRAMES=1 OCAMLRUNPARAM=v=0x400
/usr/bin/time -p APP`, `allocated_words` from the runtime summary. Apple M1, OCaml 5.3.0, dune dev profile,
1-minute load 5.4 to 7.3 (another agent building). Before = `aea5037d`.

| Marks | First frame, before: real s / user s / allocated words | After |
| --- | --- | --- |
| 1,000,000 static | 23.45 / 22.41 / 9,916,402,236 (79.3 GB) | 1.21 / 1.83 / 212,004,045 (1.7 GB) |
| 100,000 static | 3.31 / 2.54 / 996,502,231 | 0.73 / 0.45 / 62,358,449 |
| 100,000 animated (the drift kept: a GPU kernel) | 2.48 / 0.21 / 8,204,333 | unchanged path |

Cause, as the P7.2 addendum found: the static stage walked the whole `map` with the tree walker (`Flow.Eval.hof`,
`Map` arm), and it did so twice a start (`Flow_ir.qualify_workspace` for the lowering, and
`Editor_document.Contexts.window`, which evaluates the whole workspace to read the settings graph).

The proposal in `DEFERRED.md` was to defer such a map as a `Static`-rate residual. Not done that way: every consumer
that needs the concrete array at static time would have had to be deferred or refused with it. Instead the static
stage keeps its meaning and the map is made by the region it would be at frame rate. For a static packed `map` of
more than 4,096 elements the walker evaluates the first 4,096 elements as before; then a host callback
(`Flow.Eval.Private.static_with_kernels ~bulk`, supplied by `Flow_ir.static_map`: `Packed.compile` and
`Packed.force` when the residual reads no frame fact and no state) may return the whole array. The evaluator takes
it only when it is a packed array of the map's kind and length whose first 4,096 elements equal the walked ones bit
for bit; otherwise, and whenever the region refuses the form or fails, the walker evaluates the rest, so values and
diagnostics are the walker's. `Flow_ir.static` is `Eval.static` with that callback; `qualify_workspace` and
`Contexts.window` use it. What is left of the 1.2 s is the 4,096 walked elements, twice, and the kernel.

One observable difference, documented in `core.md` and `eval.mli`: records made inside such a map cover its first
4,096 elements. The walker alone kept visiting later elements until a path inside a branch had 4,096 records of its
own; a path every element reaches has the same 4,096 either way.

The walker itself, same day: `Op.find ~extra` scanned the workspace's operator list (the whole SOP catalog in the
editor) at each of its three tries for every operator application. The evaluation state now holds `Op.finder ops`,
the same lookup with the list indexed once. Plain `Flow.Eval.static ~record:true` of the 100,000-mark static
workspace through `Web_export.load` (scratch timer, median of three): 1.049 s and 2.62 GB before, 0.695 s and
2.49 GB after. 43 percent of what it still allocates is the context record `sub` copies for every argument.

Tests: `lib/flow/test_workspace_eval` (the callback is offered only maps over 4,096 elements, once each; a correct
array is used as it is; a refusal, a wrong prefix, another length or kind are walked; records and call indices equal
the plain evaluation; a failure past element 4,096 is the walker's; a map that reads `t` is never offered) and
`lib/flow_ir/test_static_map` (`Flow_ir.static` and `qualify_workspace` equal `Eval.static` bit for bit on seven
maps, among them the hash of `million_marks`; equal diagnostics; 200,000 elements in under two seconds of processor
time).

## 2026-10-11 addendum: constant attribute buffers in the browser (P7.3)

Workspaces and command as in P7.3 (`web_shot.exe --time 300 LISP marks_shot.exe tools/web/test/web_shot.mjs DIR
900 700`; `sketches/million_marks` with the drift term removed, and the same with the pan `(* 100.0 (sin t))`),
headless Chrome 154 on Apple M1, 1-minute load 3.1 to 3.5 with the corpus sweep running beside it. Before = the
exporter built at `aea5037d` (its embedded runtime), after = the same exporter with the new `present.js` and
`runtime.js`. Uncapped milliseconds per frame (`stepFrame` + `present` + `onSubmittedWorkDone`), 300 frames.

| Marks | Case | Before, median / p95 | After, median / p95 |
| --- | --- | --- | --- |
| 1,000,000 | static | 33.08 / 35.83 | 26.83 / 29.99 |
| 1,000,000 | panning | 33.30 / 35.50 | 26.84 / 27.88 |
| 10,000 | static | 1.25 / 1.52 | 1.13 / 1.25 |

The presenter made a new GPU buffer and converted and wrote 12 MB for the static positions on every frame. An
attribute array that is a view of `presenter.constants` (`data.bin`; the runtime sets it at start and on a reload)
is now converted and uploaded once and kept by byte offset and element count; a new `data.bin` releases what was
kept, and any other CPU array (a region's output, a fresh array each invoke) is uploaded per frame as before. What
remains at 1,000,000 is the draw itself: the static case now costs less than the animated one of P7.3 (29.9 ms),
which dispatches a kernel as well.

`tools/web/test/present_check.mjs` (`@qualification-web`, real Chrome) draws one table three times from views of a
`data.bin`, then with a second `data.bin`, then with views of a buffer that is not `data.bin`: kept uploads 2, 2,
2, 4, 4 and per-frame uploads 1, 2, 3, 4, 7, with the pixels of each.

The other web bullet of `DEFERRED.md`, kernel inputs uploaded again on each dispatch, was already closed by P6.4a
(`31915438`): `runtime.js` `gpuRun` uploads a kernel group's inputs once per load (`gpu.upload`) and passes the
buffers to `dispatch`, and a static group runs once. `tools/web/test/runtime.mjs` asserts it ("the frame-rate
group runs again, the steady one does not, inputs stay uploaded"). `gpu.dispatch` converts an input only when it is
handed a plain array, which the tests do. The bullet is removed.

## Generated-image export repair: P6.4b/P6.4c (2026-10-11)

Before: the exporter refused every `draw/image`, including generated `image/map` pixels, with
`E_WEB_IMAGE` and a misleading host-resolver message. After: `flow_contours`, `flow_image_kernel` and
`flow_shader` export to live WebGPU images. The sketch sources and native rendering code are unchanged.
File-backed images, `image/noise` and `image/render` remain explicit export refusals.

Machine: Apple M1, macOS 27.0.1, node v24.19.0, headless Chrome 154, Metal WebGPU adapter.
Fixed step 1/60, pointer (100,100), DPR 1. The metric is unchanged: at most 0.5% of pixels differ by more
than 8 in any RGB channel, no difference above 64. Native image pixels come from `Flow_sop.Image_kernel`;
the contour and shader fixtures use its native `Flow_gpu.Run`/`Image_sink` display path. These have hard
predicates and quantized bands whose f64 CPU snapshots can differ visibly from their existing f32 display.
Synthetic and gradient fixtures retain the independent native CPU snapshot oracle.

| Fixture | Logical size | Frame | Pixels differing by >8 | Worst channel difference | Mean pixel difference | GPU producer dispatches | CPU invokes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| synthetic, alpha/transform/clamp/ties | 65×43 | 3 | 0 | 1 | 0.0007 | 4 | 0 |
| same, after resize | 97×51 | 7 | 0 | 0 | 0.0000 | 8 | 0 |
| flow_contours | 640×480 | 3 | 0 | 1 | 0.0002 | 18 | 0 |
| same, after resize | 800×600 | 7 | 0 | 1 | 0.0002 | 42 | 0 |
| flow_image_kernel | 320×280 | 3 | 0 | 3 | 1.5657 | 3 | 0 |
| flow_shader | 760×760 | 3 | 0 | 1 | 0.0000 | 63 | 0 |

The synthetic fixture shares an animated image between two draws and has one static image. Its producer
counts prove sharing and static reuse. RGBA8 bytes for the ties fixture are exactly `[0,2,2,128]`. The test
also checks texture identity across unchanged dimensions, replacement after reload, and `E_IMAGE` for
zero/negative/fractional/nonfinite/over-limit dimensions. All generated pixels stay on the shared device
in production; the test alone reads pixels for comparison.

The first UV implementation used plain f32 division. Against native GPU contours at 640×480, 96 pixels
differed by >8, worst 215. Refining the quotient with the multiplication residual (`fma`) reduced that to
0 pixels >8, worst 1. This corrects hardware division rounding rather than weakening the metric. WGSL
allows division error of 2.5 ULP ([floating-point accuracy](https://www.w3.org/TR/WGSL/#floating-point-accuracy));
the test pins the resulting hard-edge parity on this adapter.

Actual `web --watch` integration: a capture-only edit changes the core-compiled argument module, the browser
uses the new capture in resident pixels, the unchanged pixel pipeline is reused, and a refused subsequent
edit leaves `/version` and the last successful export intact. Content-addressed module filenames prevent
the browser's ES-module cache from keeping stale capture computations.

Commands (repository root):

```sh
_build/default/tools/check.exe @lib/flow_web/runtest @tools/lisp/test/runtest @tools/runtest
_build/default/tools/check.exe @qualification-web
node tools/web/test/gpu_images_e2e.mjs _build/default/tools/lisp/lisp.exe _build/default/tools/marks_shot.exe .
_build/default/tools/web_parity.exe examples/audio examples/basic examples/drawing examples/file_dialog examples/generative examples/noise examples/particles examples/pxui examples/recursive_rectangles sketches/flow_contours sketches/flow_image sketches/flow_image_kernel sketches/flow_particles_gpu sketches/flow_shader sketches/flow_vectors
_build/default/tools/check.exe --ship
_build/default/tools/check.exe @lib/flow_gpu/runtest-native
```

All prior web qualification checks pass: WGSL execution/nonfinite handling, presenter probes, GPU marks,
constant uploads, reload, and particles at frames 1/30/120. The 15-workspace corpus now has 14 successful
exports and 120-frame mark comparisons, one explicit `E_WEB_IMAGE` refusal (`flow_image`, `image/noise`),
and no browser failures. Both export runs of `flow_contours` are byte-identical; no UV array enters `data.bin`.
All 86 previous JS frame goldens and previous WGSL goldens remain unchanged.

Shipping (`@all`, `@runtest`, `@smoke`, `git diff --check`) exits 0. The native workspace IR sweep passes
43 standard files and 13 fixtures at four times with one/eight domains; one custom-catalog executable is
checked separately. Native GPU kernel and image qualification checks exit 0, including ties/clipping,
live colors, reuse/resize, stale generations, resident image/mesh consumers and ownership.

## Remaining image producers: P6.4d/P6.4e (2026-10-12)

`image/load`, `image/noise` and `image/render` now export. Loaded files are decoded at build time by the
same SDL3_image decoder as native, including EXIF orientation, and bundled as straight-alpha RGBA8 bytes
in `data.bin`. The browser needs neither the source file nor its codec. Paths must be known at export
time and retain native working-directory resolution. Missing/invalid files return `E_WEB_IMAGE` before
writing output. Unbounded runtime file paths cannot be packaged into a standalone application and are
refused explicitly. Existing unsupported pixel-body and region diagnostics remain in force.

Noise uses the existing JavaScript double-precision noise implementation and native RGBA8 ties-even
conversion, preserving defaults, `:frequency`/`:freq`, negative seeds and the full integer seed value.
Rendered images use the same WebGPU presenter with an owned transparent RGBA8 target at DPR 1, including
recursively resolved images, CPU/GPU regions, transforms and alpha. Target dimensions govern backgrounds;
frame facts inside a drawing still describe the main frame. Every emitted module shares folds by the
native instance/path/plane identity. Nested CPU regions use the shared worker pool and old regions are
retired on reload. Text retains the existing browser-font parity limits recorded in P6.5.

Machine and metric as in P6.4b/P6.4c: Apple M1, macOS 27.0.1, Node 24.19.0, Chrome 154 Metal WebGPU,
fixed dt 1/60, pointer (100,100), DPR 1. At most 0.5% of pixels may differ by >8, none by >64; this metric
is unchanged. Native snapshots use the native decoder, `Sop.Image_nodes.noise`, and `Drawing`/Metal Canvas.
The native oracle advances image folds on each frame and resolves shared child images once per frame.

| New fixture | Size | Frame | Pixels differing by >8 | Worst RGB channel difference | GPU dispatches | CPU region invokes |
| --- | --- | --- | --- | --- | --- | --- |
| flow_image | 640×480 | 3 | 0 | 0 | 0 | 0 |
| loaded: PNG, JPEG, BMP, GIF, QOI, WebP, TGA, EXIF JPEG | 256×160 | 3 | 0 | 0 | 0 | 0 |
| live noise, alias and negative/wide seeds | 65×43 | 3 | 0 | 0 | 0 | 0 |
| live noise after resize | 97×51 | 7 | 0 | 0 | 0 | 0 |
| nested render/map/noise, transparent transforms and static target | 65×43 | 3 | 0 | 0 | 1 | 0 |
| nested render after resize | 97×51 | 7 | 0 | 0 | 1 | 0 |
| shared fold in main drawing, image dimensions and offscreen drawing | 65×43 | 3 | 0 | 0 | 3 | 0 |
| shared fold after resize | 97×51 | 7 | 0 | 0 | 7 | 0 |
| offscreen GPU regions plus a 32,768-element CPU worker region | 65×43 | 3 | 0 | 0 | 6 | 3 |

All nine new pictures match RGB byte for byte. The six existing generated-image comparisons retain their
P6.4b/P6.4c results (contours worst 1, gradient worst 3); RGBA ties remain `[0,2,2,128]`. Production counts
prove that each static producer runs once per load and each shared animated producer once per frame.
Unchanged dimensions reuse textures; resized dimensions replace them. Both generated-image and generic
offscreen-target APIs return `E_IMAGE` for zero, negative, fractional, nonfinite and over-limit dimensions.

The actual watch command reloads a scalar capture while reusing its unchanged pixel pipeline, then an
asset-only edit changes resident RGBA bytes to `[200,100,50,255]`. A corrupt image leaves `/version` and
the last successful export intact; repairing it actually re-exports the same deterministic bundle.
Malformed sketch text also preserves the last good bundle. A gated runtime test proves that replacement
waits for an asynchronous drawing and that the next frame waits for replacement to finish.

Validation, from the repository root:

```sh
_build/default/tools/check.exe @lib/flow_web/runtest @tools/lisp/test/runtest @tools/runtest @qualification-web
_build/default/tools/check.exe --ship
_build/default/tools/web_parity.exe examples/audio examples/basic examples/drawing examples/file_dialog examples/generative examples/noise examples/particles examples/pxui examples/recursive_rectangles sketches/flow_contours sketches/flow_image sketches/flow_image_kernel sketches/flow_particles_gpu sketches/flow_shader sketches/flow_vectors
```

All pass. The entire 15-workspace corpus exports, runs 120 frames with matching native mark tables and
opens/continues in Chrome without errors. All prior GPU, presenter, reload, particle and image checks
remain green. Shipping includes `@all`, `@runtest`, `@smoke` and `git diff --check`. No native product code
or WGSL golden changes; six JS frame goldens change only for asynchronous image resolution or background
target size. `flow_web` retains its portable dependency boundary; SDL decoding stays in the export tool.
