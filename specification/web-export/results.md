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
