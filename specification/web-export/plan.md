# Web export: implementation plan

Task-level plan for compiling a Rays Lisp workspace into a standalone WebGPU
browser application. It is written so that a small model can take one task per
loop iteration. Every file and line reference was read at commit `923dcecf`
(2026-10-10). Implementation progress and verified gates are recorded in the
ledger at the end. Do not code against a name this file introduces until the
task that creates it is ticked there.

## The design in one page

Today four pieces of code read the checked term tree (`Flow.Workspace.term`):
the tree walker `Flow.Eval.ev`, the closure tier `Flow.Eval.compile`, the kernel
compiler `Flow_ir.Packed.compile_impl`, and the drawing lowering
`Rays_editor.Drawing`. Nothing they produce at run time is a program that can be
written to a file: closures, GPU handles and caches are not a representation.

The plan replaces the last three readers with one lowering to a **core**, which
both native and web run:

- **Frame level.** Runs once per frame on one thread. Values: 64-bit float,
  integer, boolean, text, fixed vectors, records (flattened to fields), bounded
  lists (at most 4,096), packed arrays, state slots. Structured `if` and bounded
  loops. It emits draw statements and host effects.
- **Region level.** A pure numeric loop body over packed arrays: today's packed
  program (`Flow_ir.Packed`), widened to several outputs. A region runs in
  parallel blocks on the CPU or as a compute shader.

An operator is lowered by a compiler rule into core primitives. Only primitives
are implemented per target, so the primitive list is the whole per-target cost.

The run-time drawing contract is a **mark table**: per mark set, one buffer per
attribute (position, size, fill, ...), in painter order, plus a view transform.
The compiler optimizes drawing on that form (attribute fusion, rate split, batch
merging, placement by target) before any target prints it.

Targets are printers over the core:

| Part | Native | Web |
| --- | --- | --- |
| Frame program | core executor in OCaml | emitted JavaScript module `program.js` |
| Region on CPU | `Packed.force` over `Parallel` | emitted JavaScript loop on web workers over `SharedArrayBuffer` |
| Region on GPU | Metal (`lib/flow_gpu/emit.ml`) | WGSL (`kernels.wgsl`) |
| Marks | Metal pipeline through OGPU | WebGPU pipeline in the fixed runtime |

The browser has a fixed, hand-written runtime (`runtime.js`: events, frame loop,
state slots, worker pool, WebGPU device, presenter) that is the same for every
sketch. The compiler emits only the program: `program.js`, `kernels.wgsl`,
`data.bin`, `program.map`, `index.html`.

Decisions already taken, not to be reopened by a task:

- The compiler emits static JavaScript and WGSL. No OCaml compiled to
  WebAssembly, no bytecode VM. Results need not be bit-identical between native
  and web; native core results must be bit-identical to the tree walker.
- Scope is the 2D canvas: `:context draw` graphs and the values that feed them.
  PXUI, the editor, `sop` and `scene` graphs and the path tracer are not
  exported (`AGENTS.md`, Direction).
- Web workers are required. The page needs cross-origin isolation; there is no
  single-threaded path.
- The web is a live viewport: `rays-lisp web --watch` re-exports on save and the
  page reloads the program. Fold state resets on reload. No scrub streaming, no
  HTML controls.
- The tree walker stays, as the compile-time evaluator of the static stage and
  as the oracle for every test.
- No new Lisp syntax.

## How to run the loop

Each task is one loop iteration for one model: it names its files, its change,
the command that proves it, and what to do when the proof fails. A task is done
only when its gate passes; a task whose gate cannot pass is reported, not worked
around.

### Which model takes which task

| Tag | Model | Kind of task |
| --- | --- | --- |
| **S** | Sonnet | A change that needs a design choice inside one module, or touches evaluation order, coercions or ownership: a lowering slice, the executor, a fusion rule, a renderer binding |
| **H** | Haiku | A mechanical change with an exact oracle: a snapshot, a golden, a printed table, a dune stanza, a gate rule |
| **R** | Sonnet, review | Reads a finished phase against its gate and the specification; changes only this file |

A Haiku task never decides semantics. If its oracle disagrees with its
instructions it stops and writes a note; the next Sonnet iteration picks it up.

### Loop rules

1. Read the ledger at the end of this file. Take the lowest-numbered unticked
   task whose **needs** are all ticked. One task per iteration, one commit per
   task.
2. Before editing, read the nested `AGENTS.md` of every directory in **files**.
3. Run the task's gate. If it fails twice after honest fixes, discard the
   working-tree changes, add a line `note: <what failed>` under the task in the
   ledger, commit only that, and stop.
4. Never weaken a test, refresh a golden or snapshot, or run `dune promote`
   unless the task says so by name.
5. Never delete an old path in the task that adds its replacement. Deletions are
   separate tasks after a review.
6. A task that measures appends a dated entry to
   `specification/web-export/results.md` (created by the first such task):
   command, machine, domains, input size, before and after.
7. On success, tick the task in the ledger in the same commit.
8. At the end of a phase the **R** task runs the phase gate and either ticks the
   phase or adds repair tasks (`P<n>.<k>a`) to the table and the ledger. The
   next phase does not start before that.

## Ground rules every task inherits

These restate the repository's rules (`AGENTS.md`). Where a task card and this
section disagree, stop and report.

### Commands

| Purpose | Command |
| --- | --- |
| Build the validation launcher, once per worktree | `dune build tools/check.exe` |
| Typecheck only | `dune build @check` |
| Focused tests | `_build/default/tools/check.exe @lib/<name>/runtest` |
| All default tests, no window | `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy _build/default/tools/check.exe` |
| Every workspace, IR against reference | `_build/default/tools/check.exe @test/test_workspace_ir` |
| The same with native pixels (opens a window) | `_build/default/tools/check.exe @test/test_workspace_pixels` |
| GPU and display tests | `_build/default/tools/check.exe @runtest-native` |
| End-of-phase check | `_build/default/tools/check.exe --ship` |
| API manifest after an intended `.mli` change | `dune build @tools/api_manifest/runtest`, then `dune promote`, as its own commit `Promote the API manifest for <what>` |

Never pass `--force` and never clean `_build`. In an isolated git worktree,
`dune` needs `--root .`, and `dune promote` acts on the main checkout, so a
worktree agent leaves the API manifest unpromoted and says so in its commit.

### Code rules

- Warnings are errors. Every new module has an `.mli`. Libraries stay wrapped.
  Build and test glue is OCaml under Dune, never Python.
- A new library or a new dependency edge is a boundary change: its `dune`; the
  `rules` (line 82), `only` (line 147) and injected-edge checks (lines 301-340)
  of `test/dependency_gate.ml`; the Libraries table and Dependency rules in
  `AGENTS.md`; and `specification/backend.md`.
- The token scan (`test/dependency_gate.ml:211-222`) rejects `RAYS_WEB`,
  `RAYS_BACKEND`, `RAYS_RENDERER`, `RAYS_HEADLESS`, `--backend`, `--renderer`,
  `--headless` and `Dynlink` under `lib`, `examples` and `sketches`. Do not use
  those strings there. `tools/` and `test/` are not scanned.
- GPU and SDL calls run on the initial domain. Parallel work uses
  `Rays_math.Parallel` only, and every parallel change ships a one-domain
  against eight-domain equality test.
- A task that finds it needs new Lisp syntax stops.
- Commit messages are imperative sentence case with an area prefix:
  `flow_ir: Lower scalar residuals to core`.

### Promotes and goldens

| File | When a task may promote or rewrite it |
| --- | --- |
| `tools/api_manifest/api_stable.json` | After an intended `.mli` change, as a separate commit |
| `sketches/dune.rays.inc` | Only in a task that adds or removes a `.rays` sketch |
| `lib/sop_catalog/flow_manifest.sexp` | Never in this plan |
| `lib/flow_gpu/goldens/*.metal` | Never. They prove kernels did not change |
| Snapshots this plan adds (P2.1, P3.1) | Never after the task that creates them |
| PXUI parity goldens (`RAYS_UPDATE_FIXTURES`) | Never |

### The switch pattern

Every replacement lands behind a switch modelled on
`Flow.Eval.compile_residuals` (`lib/flow/eval.ml:302`, exported at `:1260`): a
`bool ref`, default off, exported through `Private`. Tests run both settings. A
later task flips the default; a still later task, after a review, deletes the
old path and the switch.

### Where new code goes

| New thing | Location | May depend on |
| --- | --- | --- |
| Core types, lowering, native executor | `lib/flow_ir/core.ml`, `core_lower.ml`, `core_exec.ml` (add to `modules` in `lib/flow_ir/dune`) | `flow`, `param`, `rays_math`; `scene_command` from P3.3b |
| Run-time drawing contract | `lib/scene_command/marks.ml` | Nothing; `scene_command` has no dependencies |
| Marks to `Rays.Scene` adapter | `lib/rays_editor/marks_scene.ml`, listed in `private_modules` | What `rays_editor` already has |
| WGSL and JavaScript printers | new library `lib/flow_web` | `flow`, `flow_ir`, `param`, `rays_math`, `scene_command` |
| Browser runtime | `tools/web/runtime/*.js`, `*.wgsl` | Not OCaml; copied into the export |
| Export command, watcher, development server | `tools/lisp/lisp.ml` and siblings | As `tools/lisp/dune` allows; no HTTP under `lib/` |
| Benchmarks | `tools/bench_core.ml`, `tools/bench_marks.ml`, added to `bench-build` in `tools/dune` | |

The executor reaches `flow` through the existing `execute` hook on the evaluator
state (`lib/flow/eval.ml:118`, used at `:462`). Do not add a global hook and do
not make `flow` depend on `flow_ir`.

## Seams in today's code

Line numbers are from `923dcecf`. A task that finds a line has moved searches
for the named function.

### Per-frame execution

| Seam | Where | What a task needs to know |
| --- | --- | --- |
| Closure tier | `lib/flow/eval.ml:313` `fast_of`, `:337` `compile`, `:418` `force_res` | `compile` handles literals, `Time`, a 3-vector, field reads, scalar value ops, `Let` over constants, `If`, and `Sum`/`For` over a constant list of at most 4,096. Everything else raises `Unsupported` (`:296`). Budget of 2,048 nodes |
| Its switch | `eval.ml:302` `compile_residuals`; field `compiled_residuals` (`:119`) | The pattern to copy for `core_residuals` |
| Its error rule | `eval.ml:428-432` | Any run-time failure reruns the tree walker (`slow ()`), so the diagnostic and span are always the walker's. The core executor keeps this rule |
| Its exactness rule | `lib/flow/test_workspace_eval.ml:435-487` | Closure results are bit-identical to the walker: same operators, same order, same coercions; `Sum` of an empty list is `Int 0` |
| Executor hook | `eval.ml:118`, `:462` | How `flow_ir` injects an executor into `flow` without a dependency |
| Residual view | `eval.ml:1219-1228` `Private.residual_view` | Term, bindings and captures of a residual |
| Fold state | `eval.ml:170` `begin_frame`, `:666` `state_previous` | How folds are keyed and committed |
| Bounds | `eval.ml:646`, `:876` `E_ITER_BOUND`; `lib/flow/workspace.ml:882` `E_TIME_COUNT` | 4,096 everywhere |
| Kernel compiler | `lib/flow_ir/packed.ml:125` `compile_impl`, `:264-372` `expression` | Roots: `map`, `reduce`, `for`, `sum`, `fold`, `scan`, `array/sum`. Bodies: literals, references, vectors of 2 to 4, `Get`, `Let`, `If` as eager `Select`, `Cond`, `Case`, ops by `Op.packed_kind`. No records, lists, `Call_fn`, nested `fn`, `Str` or `State` |
| Its refusals | `packed.ml`: `E_PACKED_STATE`, `_FUNCTION`, `_FORM`, `_TYPE`, `_CAPTURE`, `_OPERATOR`, `_CONSTANT`, `_LIMIT`, `_LAYOUT`; `E_GPU_FORM` in `gpu_refusals` (`:43`) | `test_packed` pins these codes and their spans |
| Captures | `packed.ml:68` `captured_value`, `:215` `uniform` | A live or templated capture becomes `Uniform (i, j)`; a static one is inlined as `Const` |
| Fusion | `packed.ml:431` `fuse_maps` (called at `:416`) | Inlines `Collect` + `Zip` children of equal count or origin; register limit `Flow.Packed_ops.register_limit` (64) at `:203` |
| Block executor | `packed.ml:551` `force` | Blocks of 1,024 (`:616`), `Parallel.for_ ~chunk_size:1` for `Collect` (`:752`); sums and accumulators run sequentially in order. Non-finite raises `E_KERNEL` |
| Emitter interface | `Packed.Private.view`, `Private.inputs`; `lib/flow_gpu/emit.ml:53` | The only things the Metal emitter reads. `view` has `code`, `widths`, `output`, `uniform_widths`, `collecting` (the `zipped` and `skip` fields were removed by the refactor) |
| IR build | `lib/flow_ir/flow_ir.ml:441` `residual`, `:522` `of_evaluation` | `Packed_map` attached at `:488`; anything unsupported becomes `Reference`; display nodes become `Sink (Display kind)` (`:531`) |
| Placement | `flow_ir.ml:332` `place`; cost table `:133-160` | GPU needs a static count of at least 1,024, provenance in `approx`, no refusals, and a measured cost below the CPU's. `Cost.table` is no longer exported |
| Callers of the closure tier | `eval.ml:334`, `:428`, `:1233`, `:1260`; `flow_ir.ml:361`; `lib/flow/test_frame.ml:22-24`; `test_workspace_eval.ml:447-485` | The list the deletion task works from |

### Drawing

| Seam | Where | What a task needs to know |
| --- | --- | --- |
| Drawing lowering | `lib/rays_editor/drawing.ml:35` `render_prepared`; arms `:106-177` | A string match on node kind. Defaults for drawing operators live here, not in `Flow.Op`. The module moved here from `sketch_support`, which no longer exists |
| GPU eligibility | `drawing.ml:64`, `:127` | `draw/circles` with a `?gpu` callback, uniform radius, fill and stroke |
| Retention | `drawing.ml:19-33` (static test), `:53-54`, `:179`; `lib/rays_editor/environment.ml:69`, `:360` | A static node's scene is reused while size is unchanged |
| Callers | `lib/rays_editor/environment.ml:781-786`; `lib/rays_editor/rays_editor.ml:205-209` (`Workspace.export`, `:187`); `workspace_images.ml:31` | |
| Instance record | `lib/scene_command/shape_batch.ml:3`, `:17` | 64 bytes; kinds rect 0, circle 4, line 5 |
| Circle kernel | `lib/rays_execution/gpu_circles.ml:6`, `:63`; `lib/rays_editor/workspace_gpu.mli` `circles` | Fixed Metal source; one synchronous completion and status readback per dispatch |
| GPU vertex sources | `lib/scene_execution/scene_execution.ml:10` `register_gpu_vertices`, `:180` `resolve_gpu_vertices`, `:796`, `:869` signature, `:1228-1244` | One buffer per source, looked up by key and stamp |
| Shape shader | `lib/runtime/runtime_shaders.ml:18` `ui` | Shared with PXUI. Vertex pulling: `instance = vid/4`, reads `input + instance*64` (`:26-27`). Four vertices and six `Uint32` indices per instance, built on the CPU |
| Pipeline families | `scene_execution.ml:27` `pipeline_family`, `:260-272` `blends`, `families`, `pipeline_slot`; `lib/runtime/runtime.ml:368`, `:403`, `:426`, `:440`, `:498`, `:514` | Where a new family is declared and bound |
| Transform | `lib/rays_execution/rays_execution.ml:84` `write_affine`, `:607`, `:643` | Already a 24-byte uniform, not baked into instances. Clip is a scissor rect |
| Transform caveats | `drawing.ml:161`; `rays_execution.ml:638-640` | `draw/translate` snaps to integers. A changed batch reruns a byte comparison over all instances |
| Batching | `rays_execution.ml:616`; `scene_execution.ml:707` `coalesce_draws` | One draw per `Shapes` command at lowering; `coalesce_draws` merges later |
| Text | `lib/rays/scene.ml:166-171` `text_image` | A whole string is rasterized to an image by SDL_ttf and drawn as a quad |
| Frame facts | `lib/frame_input/frame_input.mli:2-24`; `lib/flow/op.ml:116`, `:148`, `:151` | `t`, `dt`, `frame`, `tick`, `size`, `pointer`, `buttons`, `keys`, `events`. The events list has live length |

### What the refactor at `923dcecf` removed

A task must not reach for these; the plan below replaces each.

| Gone | Replacement in this plan |
| --- | --- |
| `lib/sketch_support/` | `lib/rays_editor/drawing.ml`; new adapter in `lib/rays_editor/marks_scene.ml` |
| `specification/performance-log.md` | `specification/web-export/results.md` |
| `tools/bench_kernel.ml`, `bench_drawing.ml`, `bench_workspace_lower.ml` | `tools/bench_core.ml` (P1.13), `tools/bench_marks.ml` (P3.11). `tools/bench_gpu.ml` remains |
| `tools/workspace_parity.exe` as a command | `tools/workspace_parity.ml` is a library; `test/test_workspace_ir.ml` drives it over every workspace |
| `test/test_drawing.ml`, `lib/rays/test_shape_batch.ml`, `lib/rays_execution/test_gpu_circles.ml` | `@test/test_workspace_pixels`; `lib/rays_execution/test_dense_scene2.ml` and `test_gpu_draw.ml`; `lib/rays_editor/native_qualification/test_workspace_gpu_native.ml` |
| Library `procedural` | Renamed `sop` |

## Phase 0: core specification and census

Phase 0 writes no product code. It fixes what the core is, from a count of what
the checked-in workspaces use.

### The corpus

There are 45 `.rays` files. Fifteen have a `draw` graph, and none of those draw
graphs references a `sop` or `scene` graph. They are the web scope and the
parity corpus for every phase:

`examples/audio`, `basic`, `drawing`, `file_dialog`, `generative`, `noise`,
`particles`, `pxui`, `recursive_rectangles`; `sketches/flow_contours`,
`flow_image`, `flow_image_kernel`, `flow_particles_gpu`, `flow_shader`,
`flow_vectors`.

`flow_contours`, `flow_image` and `flow_particles_gpu` also hold `scene` or
`sop` graphs; only their draw graph is exported.

Head counts below were taken at `3baf0095` with a throwaway tokenizer; of the
fifteen files only `examples/basic` changed since (one line). P0.1 recounts.

| Finding | Evidence | Consequence for the core |
| --- | --- | --- |
| Records and field reads are everywhere | 216 dotted reads, 21 record literals, 21 `assoc` | Records are in the core, flattened to fields; keys are static |
| Lists are common and some have live length | `list` 20, `map` 16, `nth`, `count`, `concat`, `take`, `rest`, `reverse`, `filter`; frame events | A bounded list, capped at 4,096 |
| Text is computed per frame | `str` 7, `equal?` 49, `draw/text` with computed strings in 3 files | Text is a frame-level value; it never enters a region |
| State is the norm | `(state ...)` in 8 of 15 files | State slots are in the first lowering slices |
| Per-instance attributes are used | `draw/circles` with radius and fill arrays, `draw/rects` with sizes and fills, in 3 files | The mark contract carries per-instance size and colour from the start |
| Integer operators appear | `int` 30, `int/div` 19, `int/mul`, `int/and`, `int/xor`, `int/mod` | Integer width and overflow must be specified; OCaml's 63-bit `int` and JavaScript numbers differ |
| Host effects appear | `host/quit`, `host/dialog`, `host/play`, `host/save_png`, `audio/synth` | Each is an intrinsic with a per-target legality entry |

Smallest end-to-end target: `sketches/flow_vectors` (17 lines). Next:
`examples/basic` (state, frame facts, `str`, `draw/text`). Richest frame
program: `examples/drawing` (185 lines; an event-driven state machine over
records). Richest kernels: `sketches/flow_shader`.

### Tasks

| Id | M | Needs | Files | Do | Gate |
| --- | --- | --- | --- | --- | --- |
| P0.1 | H | | `tools/core_census.ml`, `tools/dune` | A tool that parses every `.rays` under `examples/`, `sketches/` and `specification/` with `Flow.Syntax.parse` and prints (a) each file's graph contexts and whether its draw graphs reach a `sop` or `scene` graph through `(ref ...)`, (b) the count of each head symbol inside `draw`, `host`, `image` and `value` graphs and top-level `defn` and `defmacro` bodies. Sorted, deterministic | `dune build tools/core_census.exe && _build/default/tools/core_census.exe` lists the 15 files above as eligible |
| P0.2 | S | P0.1 | `specification/core.md` | The specification: the two levels; value types; control forms; the region form (state that it is today's `Packed.instruction` set); state slots; draw statements; intrinsics. One table with a row for every head P0.1 prints and a column `rule`: `primitive`, `compiler rule` (naming the primitives it expands to), `region`, `intrinsic`, or `refused on web` | P0.R |
| P0.2a | S | P0.2, P0.7 | `specification/core.md` | P0.R repair: state the remaining leaf behavior without requiring a second reader to infer it from source: `color/parse` and both channel-conversion paths (including Apple-Silicon signed integer conversion for very large finite channels), packed-array defaults/index/count/layout checks, recursive `coerce`, and the `value/hsv` / `value/lerp` compiler expansions. Preserve the 54-leaf inventory; validate edge examples against the native bodies | P0.6 and native edge probes; P0.R |
| P0.3 | S | P0.2 | `specification/core.md` | Numeric model: frame-level floats are 64-bit; region floats are 32-bit on GPU and 64-bit on CPU as today; integer width and overflow for `int`, `int/div`, `int/mul`, `int/mod`, `int/and`, `int/xor`, from their bodies in `lib/flow/op.ml`, and what a JavaScript target must do to match | P0.R |
| P0.4 | S | P0.2 | `specification/core.md` | List model, from `E_TIME_COUNT` (`lib/flow/workspace.ml:882`) and `E_ITER_BOUND` (`eval.ml:646`, `:876`): which lists have static length (unrolled at lowering) and which are bounded dynamic lists; the element layout for a list of records | P0.R |
| P0.5 | S | P0.2 | `specification/core.md` | Text model, from `Value.show_with` (`lib/flow/value.ml:119`) and the float spelling rule (`specification/flow.md:693`, `:1455`). Specify `show` and `equal?` precisely enough to implement twice | P0.R |
| P0.6 | H | P0.2 | `tools/lisp/test/core_census.t`, `tools/lisp/test/dune` | A cram test: run the census tool, extract its head list, fail if any head has no row in the table of `specification/core.md` | `_build/default/tools/check.exe @tools/lisp/test/runtest` |
| P0.7 | H | P0.2 | `README.md`, `AGENTS.md`, `specification/flow.md` | Link `specification/core.md` from the README specification list (lines 213-224), the design-notes sentence in `AGENTS.md`, and `flow.md` section 14 | `git diff --check` |
| P0.R | R | P0.3 to P0.7, P0.2a | | Every census head has a rule; the primitive list is written out and counted; no rule says "same as OCaml" without stating the behaviour. Record the primitive count at the top of `core.md`. If the count is large enough that two targets would each be a second implementation, stop the loop and report | P0.6 passes |

## Phase 1: lowering and native executor

Phase 1 builds the frame level and runs it natively, slice by slice, behind a
switch, until the closure tier has nothing left to do. The oracle for every
slice is the tree walker: results are bit-identical, as the closure tier's are.

| Id | M | Needs | Files | Do | Gate |
| --- | --- | --- | --- | --- | --- |
| P1.1 | S | P0.R | `lib/flow_ir/core.ml`, `.mli`, `dune`, `test_core.ml` | The frame-level types from `specification/core.md`: expressions, statements, a program with numbered locals and state slots, and a `Region_ref` placeholder holding an existing `Packed.t`. A deterministic printer `Core.pp`. Test: three hand-built programs against inline expected strings | `@lib/flow_ir/runtest` |
| P1.2 | S | P1.1 | `lib/flow_ir/core_lower.ml`, `.mli`, `test_core_lower.ml` | `lower : Flow.Eval.residual -> (Core.program, string) result` for exactly the forms `Flow.Eval.compile` handles (`eval.ml:337` onward). Anything else returns `Error` with the form's name. Read captures through `Eval.Private.residual_view`. Test: `pp` expectations for the expressions in `test_workspace_eval.ml:435-487` | `@lib/flow_ir/runtest` |
| P1.2a | S | P1.4 | `core_lower.ml`, tests | Complete operator coverage within the initial forms: audit every `Context.value` scalar operator accepted by the old closure compiler, and add the remaining shared expansions (HSV, list convenience operations, packed sum, held-key/button membership). Preserve named refusal for reached values outside the core layout/size contract; do not add target-side operator dispatch | `@lib/flow_ir/runtest`; compare successful lowering and native bits against every old-closure operator case |
| P1.3 | S | P1.2 | `lib/flow_ir/core_exec.ml`, `.mli`, `flow_ir.ml`, `lib/flow/eval.ml`, `.mli` | A direct interpreter of frame-level core returning `Flow.Eval.value`, using the walker's operator bodies and coercions. Add `Flow.Eval.Private.core_residuals : bool ref`, default `false`. When set, a residual is offered to the executor through the `execute` hook before the closure tier; on `Error` or any exception, fall through unchanged | `@lib/flow/runtest` and `@lib/flow_ir/runtest`, no test changed |
| P1.4 | H | P1.3 | `lib/flow_ir/test_core_parity.ml`, `dune` | For each fixture and expression in `test_workspace_eval.ml:435-487`, force with `core_residuals` on, off, and with `compile_residuals` off; assert bit-equal values (copy `same_bits`) and equal diagnostics on the error cases | `@lib/flow_ir/runtest` |
| P1.5 | S | P1.4 | `core_lower.ml`, `core_exec.ml`, tests | Slice B: vectors of 2 and 4; `Cond`, `Case`; `Let` with destructuring patterns; `Call_fn` and local `Fn` by inlining the call site's checked body; `Expanded`; `Bypass`. `pp` and parity cases for each | `@lib/flow_ir/runtest` |
| P1.6 | S | P1.5 | same | Slice C: records (`Record`, `Get`, `Assoc`) flattened to locals; text, `Str` through the `show` primitive, `equal?` | same |
| P1.7 | S | P1.6 | same | Slice D: lists per `core.md`: `List_lit`, `range`, `nth`, `count`, `concat`, `take`, `rest`, `reverse`; `Hof` `Map`, `Filter`, `Reduce`, `Sort_by`; `Loop` `For`, `Fold`, `Scan`, `Sum` with `skip`. Keep `E_ITER_BOUND` at 4,096 and `Sum` of an empty list as `Int 0` | same |
| P1.8 | S | P1.7 | same, `lib/flow/eval.ml` | Slice E: `State` as slots, keeping the keys of `state_previous` (`eval.ml:666`) and `begin_frame` (`:170`) so `fork_state` and `transaction` still work. Frame operators and `frame/input` events as a bounded list of records | `@lib/flow/runtest` including `test_state` and `test_frame`, switch on and off |
| P1.9 | S | P1.8 | same | Slice F: packed-array operators outside regions (`array/range`, `array/vec3`, `array/nth`, `array/count`, `array/slice`, `array/concat`) as primitives; a packed `map`, `for`, `sum`, `fold` or `reduce` becomes a `Region_ref` that calls `Packed.force` unchanged | `@lib/flow_ir/runtest` including `test_frame_kernel` |
| P1.10 | S | P1.9 | `core_exec.ml` | The error rule: any failure inside the executor reruns the tree walker and returns its diagnostic, as `eval.ml:428-432` does. Parity cases for a division by zero, an out-of-range `nth`, a non-finite result | `@lib/flow_ir/runtest` |
| P1.11 | H | P1.10 | `tools/workspace_parity.ml`, `.mli` | In `Workspace_parity.check`, add a pass that repeats the existing IR-against-reference comparison with `core_residuals` set, restoring it afterwards. `test/test_workspace_ir.ml` then covers every workspace with no change | `_build/default/tools/check.exe @test/test_workspace_ir` |
| P1.12 | H | P1.11 | `tools/workspace_parity.ml`, `test/test_workspace_ir.ml` | Coverage report under an environment variable `RAYS_CORE_COVERAGE`: per workspace, residuals lowered against residuals that returned `Error`, with the form names. Paste the table for the 15 eligible workspaces into `results.md` | Zero `Error` for all 15, or the review adds slice tasks |
| P1.13 | H | P1.11 | `tools/bench_core.ml`, `tools/dune`, `results.md` | A new bench printing three rows for one scalar residual (the expression of the `Closure` row in `flow_ir.ml:133-160`): tree walker, closure tier, core. Add it to `bench-build`. Record the rows | Rows printed; entry present |
| P1.14 | S | P1.13 | `core_exec.ml` | Only if the core row is more than 1.1 times the closure row: compile a core program once into OCaml closures instead of interpreting it, keeping the interpreter as the test reference. Re-record | Core at most 1.1 times closure; P1.4 and P1.11 pass |
| P1.15 | S | P1.14 | `lib/flow/eval.ml` | Flip `core_residuals` to default `true` | All default tests, and `@test/test_workspace_ir` |
| P1.R | R | P1.15, P1.2a | | Run `--ship` and `@runtest-native`. Confirm P1.12 shows full coverage. Re-list the callers of `fast_of`, `closure_available` and `compile_residuals` for P1.16 | All green |
| P1.16 | S | P1.R | `lib/flow/eval.ml`, `.mli`, callers | Delete `compile`, `cnode`, `fast`, `fast_of` and both switches. Keep the `Closure` tier name in `Flow_ir.tier`, now meaning a core frame program, so placement tests are unchanged. Promote the API manifest in a second commit | `--ship` |

## Phase 2: kernels on the core

A region becomes a first-class part of the core, so `packed.ml` no longer walks
terms. Not one emitted instruction may change: the three Metal goldens and a new
instruction-level snapshot are the proof.

| Id | M | Needs | Files | Do | Gate |
| --- | --- | --- | --- | --- | --- |
| P2.1 | H | P1.R | `lib/flow_ir/test_region_snapshot.ml`, `lib/flow_ir/snapshots/*.txt`, `dune` | Before any change: for every program built in `lib/flow_ir/test_packed.ml` and `lib/flow_gpu/test_program.ml` (`fixtures`, `vector_fixtures`), and every kernel compiled from `examples/particles`, `sketches/flow_shader`, `flow_particles_gpu` and `flow_image_kernel`, print `Packed.Private.view` (`code`, `widths`, `output`, `uniform_widths`, `collecting`) and `Packed.gpu_refusals` to a text file and commit them. The test regenerates and diffs. Move `test_program.ml` where both tests can link it; do not copy it | `@lib/flow_ir/runtest` |
| P2.2 | S | P2.1 | `lib/flow_ir/core.ml`, `.mli` | Replace `Region_ref` with a real region: iteration (`Zip`, `Product`), sources, result (`Collect`, `Sum`, `Accumulate`), `skip`, a body of region-level expressions, captured uniforms, count and origin. Region expressions reuse `Flow.Packed_ops.binary` and `unary`. Extend `pp` | `@lib/flow_ir/runtest` |
| P2.3 | S | P2.2 | `core_lower.ml`, tests | Lower region roots and bodies to the new form, covering exactly what `Packed.expression` accepts (`packed.ml:264-372`). Refuse the rest with the same `E_PACKED_*` codes and spans | `test_packed` refusal cases pass against the new lowering |
| P2.4 | S | P2.3 | `lib/flow_ir/packed.ml` | `Packed.of_region : Core.region -> (t, Flow.Diagnostic.t list) result` builds the register program from a region instead of from terms. Behind a switch `core_regions`, route `compile_impl` through `core_lower` then `of_region` | P2.1 snapshots identical with the switch on |
| P2.5 | S | P2.4 | `packed.ml`, `core_lower.ml` | Captures and templates: `captured_value`, the live-or-dynamic `Uniform` rule, `compile_template` and `rebind` on regions. The template counts in `test_frame_kernel` must not change | `@lib/flow_ir/runtest` with the switch on |
| P2.6 | S | P2.5 | `packed.ml` or new `core_fuse.ml` | Fusion on regions: port `fuse_maps` (`packed.ml:431`) to combine a region with its `Collect` + `Zip` sources of equal count or origin, with the same common-subexpression rule and register limit | P2.1 snapshots identical with the switch on |
| P2.7 | H | P2.6 | none | Run with `core_regions` on and record: `@lib/flow_ir/runtest`, `@lib/flow_gpu/runtest` (Metal goldens), `@runtest-native` | All pass; goldens untouched in `git status` |
| P2.8 | H | P2.7 | `tools/bench_core.ml`, `results.md` | Add kernel rows: one `map` at 1,024 and 1,000,000, a fused pair of maps, a `sum` loop; each with the switch off and on, at 1 and 8 domains. Record `tools/bench_gpu.exe` too | No row regresses by more than 5 percent; otherwise a repair task |
| P2.9 | S | P2.8 | `packed.ml` | Flip `core_regions` to default on | `--ship` and `@runtest-native` |
| P2.R | R | P2.9 | | Snapshots and goldens are byte-identical in history since P2.1. List what in `packed.ml` is now dead | Phase gate |
| P2.10 | S | P2.R | `packed.ml`, `.mli` | Delete `expression`, `source_program` and the term-walking half of `compile_impl`; keep `force`, `Private.view`, `Private.inputs`, `gpu_refusals`. Promote the API manifest separately | `--ship` and `@runtest-native` |

## Phase 3: drawing on the core

The string match in `Rays_editor.Drawing` becomes lowering rules that emit draw
statements, and the run-time contract those statements fill is defined. The
picture must not change by one byte: the renderer is untouched in this phase and
an adapter feeds it.

| Id | M | Needs | Files | Do | Gate |
| --- | --- | --- | --- | --- | --- |
| P3.1 | H | P1.R | `test/test_draw_snapshot.ml`, `test/draw_snapshots/*`, `test/dune` | Before any change: for each of the 15 eligible workspaces, at fixed-step frames 0, 1 and 30 with a pinned size and pointer, write the SHA-256 of `Scene_command.Render_ir.serialize` of the draw graph's scene, built with `Drawing.prepare` and `Drawing.render_prepared` as `Rays_editor.Workspace.export` does (`rays_editor.ml:187-209`). No GPU callback. The test regenerates and diffs | `_build/default/tools/check.exe @test/runtest` |
| P3.2 | S | P0.R | `specification/marks.md` | The run-time contract: a frame is an ordered mark table. An entry is a mark set (kind: rect, circle, line, point; count; per attribute a constant or a buffer reference with width; attributes: position, size or radius, fill, stroke, stroke width), indexed path geometry produced by the existing pure `Scene_command.Shape2` helpers, an image, a text run, or a push or pop of view transform or clip. The geometry entry is required for P3.6's rounded-rectangle/polygon/polyline native serialization and pixel parity; preserve fill/stroke order and do not approximate paths by overlapping marks. Units (logical points), colour encoding, defaults taken from `drawing.ml`, the cap on count, painter order | P3.R |
| P3.3 | S | P3.2 | `lib/scene_command/marks.ml`, `.mli`, `test_marks.ml`, `dune` | The contract as pure data with no dependencies: types, a validity check, and a stable little-endian `serialize` in the style of `Render_ir.serialize`. A buffer reference is an abstract integer id plus count and width | `@lib/scene_command/runtest` |
| P3.3b | H | P3.3 | `lib/flow_ir/dune`, `test/dependency_gate.ml`, `AGENTS.md`, `specification/backend.md` | Boundary change: `flow_ir` may depend on `scene_command` (a leaf with no dependencies). Add it to `flow_ir`'s entry in `only`, to the Dependency rules sentence and Libraries row in `AGENTS.md`, and to `backend.md`. `flow_ir` still never reaches `rays`, the `gpu` group or any UI library | `_build/default/tools/check.exe @test/runtest` |
| P3.4 | S | P3.3b, P1.R | `lib/flow_ir/core.ml`, `core_lower.ml`, tests | Draw statements in the core and lowering rules, slice 1: `draw/background`, `draw/rect`, `draw/circle`, `draw/line`, `draw/point`, `draw/merge`, `draw/translate`, `draw/rotate`, `draw/scale`. Move each default out of `drawing.ml` into its rule (fill white when neither fill nor stroke is given; stroke width 1; `draw/translate` rounds to integers; `E_DRAW_RANGE`) | `pp` expectations; `@lib/flow_ir/runtest` |
| P3.5 | S | P3.4 | same | Slice 2: `draw/circles`, `draw/rects`, `draw/lines`, `draw/points` with constant or per-instance attributes, keeping `E_DRAW_LENGTH` and `E_DRAW_INPUT` | same |
| P3.6 | S | P3.5 | same | Slice 3: `draw/text`, `draw/image`, `draw/rounded_rect`, `draw/polygon`, `draw/polyline`; `E_DRAW_KIND` for anything else | same |
| P3.7 | S | P3.6 | `lib/flow_ir/core_exec.ml` | The executor produces a `Scene_command.Marks.t` for a draw graph. CPU attribute arrays are registered as buffer ids in a per-frame table the caller owns | `@lib/flow_ir/runtest` |
| P3.8 | S | P3.7 | `lib/rays_editor/marks_scene.ml`, `.mli`, `dune` | Adapter from `Marks.t` to `Rays.Scene`, building `Shape_batch` records exactly as `drawing.ml:83-104` does, so the renderer sees the same commands. No renderer change. List it in `private_modules` | Unit test comparing `Render_ir.serialize` for hand-built marks |
| P3.9 | S | P3.8 | `lib/rays_editor/drawing.ml`, `.mli` | Behind a switch `core_drawing`, `render_prepared` runs the core path and the adapter instead of its own arms. Keep the retention rules (`drawing.ml:19-33`, `:53-54`, `:179`) | P3.1 snapshots identical with the switch on |
| P3.10 | S | P3.9 | `drawing.ml`, `marks_scene.ml`, `lib/rays_editor/workspace_gpu.ml` | The GPU path through the contract: a circle mark set whose position is a GPU region output and whose other attributes are constants resolves to the existing `Workspace_gpu.circles` token (`drawing.ml:127`). Nothing else changes yet | `@runtest-native` (includes `test_workspace_gpu_native`) and `@test/test_workspace_pixels`, switch on |
| P3.11 | H | P3.10 | `tools/bench_marks.ml`, `tools/dune`, `results.md` | A new bench: `Drawing.render_prepared` for `draw/circles` and `draw/rects` at 10,000, 100,000 and 1,000,000, static and animated, switch off and on; wall time and allocated bytes per frame. Add to `bench-build`. Record | No row regresses by more than 5 percent; otherwise a repair task |
| P3.12 | S | P3.11 | `drawing.ml` | Flip `core_drawing` to default on | `--ship` and `@runtest-native` |
| P3.R | R | P3.12 | | P3.1 snapshots unchanged since they were taken. `specification/marks.md` matches `marks.mli` | Phase gate |
| P3.13 | S | P3.R | `drawing.ml`, `.mli` | Delete the per-kind arms and the switch; `Drawing` keeps only retention and the call into the core path. Update `specification/flow.md`, "Frame data and native 2D drawings" (line 1340) | `--ship` and `@runtest-native` |

## Phase 4: draw optimization and target placement

This is where pictures get faster: mark attributes are read by the shader
straight from kernel outputs, kernels gain several outputs, and placement learns
about marks and targets. Some tasks here change the renderer, so each ships with
a pixel-parity test against the path it replaces.

| Id | M | Needs | Files | Do | Gate |
| --- | --- | --- | --- | --- | --- |
| P4.1 | H | P3.R | `tools/bench_marks.ml`, `results.md` | Baseline rows at 100,000 and 1,000,000: circles with per-instance radius and fill, rects with per-instance size and fill, and a static batch under a changing `draw/translate`. Record | Rows printed; entry present |
| P4.2 | S | P4.1 | `lib/runtime/runtime_shaders.ml`, `lib/runtime/runtime.ml`, `lib/scene_execution/scene_execution.ml`, `.mli` | A new pipeline family `Marks`, leaving the `Ui` family and its shader untouched (`test_ui_parity` pins them). Its vertex stage reads position, size and colour from three separate buffers by `vid / 4` and applies the same affine uniform as `Ui`. Its fragment stage is the rect, circle and line cases of the `Ui` shader. Touch `pipeline_family` (`scene_execution.ml:27`), `families` and `pipeline_slot` (`:261-272`), and every `Ui` arm in `runtime.ml` (`:368`, `:403`, `:426`, `:440`, `:498`, `:514`). Read `lib/runtime/AGENTS.md` and `lib/ogpu/AGENTS.md` first | `@check`; exercised by P4.4 |
| P4.3 | S | P4.2 | `scene_execution.ml`, `.mli`, `lib/rays_execution/rays_execution.ml`, `.mli` | A registered GPU vertex source may carry several buffers: `register_gpu_vertices` (`scene_execution.ml:10`), `resolve_gpu_vertices` (`:180`), the bindings appended at `:1228-1244`, and the signatures at `:796` and `:869` covering every buffer id | `@lib/scene_execution/runtest`, `@lib/rays_execution/runtest` |
| P4.4 | S | P4.3 | `lib/rays_execution/test_marks_native.ml`, `dune` | Pixel parity, native: the same marks through `Shape_batch` and through the `Marks` family at 63, 64, 65 and 100,000 instances, for rect, circle and line, with and without stroke. Model it on `lib/rays_execution/test_dense_scene2.ml` | `@runtest-native` |
| P4.5 | S | P2.R | `lib/flow_ir/packed.ml`, `.mli`, `core.ml`, `lib/flow_gpu/emit.ml`, `run.ml` | Several outputs per region: `Private.view.output` becomes a list of output slot arrays, each with its width. `Packed.force` returns one packed array per output. The Metal emitter declares one output buffer per output. A single-output program prints exactly as before | P2.1 snapshots identical after a mechanical reformat stated in the commit; the three Metal goldens identical; a new golden `two_outputs.metal`; a `test_packed` case at 1 and 8 domains |
| P4.6 | S | P4.5 | `lib/flow_ir/flow_ir.ml` | Marks as IR nodes: replace `Sink (Display kind)` for mark sets with a node that names its attribute edges. Every pass (`share`, `hoist`, `prune`, `fuse`, `place`) carries it; provenance is the drawing call's path | `test_ir` unchanged plus new cases |
| P4.7 | S | P4.6 | `flow_ir.ml` or `core_fuse.ml` | Attribute fusion: when the regions feeding one mark set's attributes have equal count or origin, fuse them into one region with several outputs. Decline at the register limit; never fail | New `test_ir` cases; a `bench_core` row comparing fused against separate kernels at 1,000,000, recorded |
| P4.8 | S | P4.7 | `flow_ir.ml` | Rate split per attribute: an attribute whose region is static is computed once and its buffer kept; only frame-rate attributes rerun. Build on `hoist` and the `rate` field | Test: static positions with animated colour run the position region once over 10 frames (count with `Flow_ir.Profile`) |
| P4.9 | S | P4.4, P4.8 | `lib/rays_editor/marks_scene.ml`, `workspace_gpu.ml`, `rays_execution.ml` | Route a mark set whose attributes are GPU region outputs to the `Marks` family with those buffers bound directly. CPU attributes are uploaded to buffers of the same layout. `gpu_circles` is no longer called | P4.4, `@runtest-native` and `@test/test_workspace_pixels`. P3.1 snapshots are not the oracle here; if they change, the commit says why and the review decides |
| P4.10 | S | P4.9 | `rays_execution.ml` | A transform change must not redo CPU work on an unchanged batch: keep the transform out of the instance comparison (`:638-640`) and out of the mesh identity, so a new affine rewrites 24 bytes only. Keep integer snapping of `draw/translate` | The P4.1 moving-transform row at 1,000,000 improves and is recorded; allocations per frame do not scale with count |
| P4.11 | S | P4.9 | `rays_execution.ml`, `scene_execution.ml` | Batch merging: neighbouring mark sets with the same family, blend and clip become one draw, painter order kept. Read `coalesce_draws` (`scene_execution.ml:707`) first; extend it if it already covers the case | Pixel parity with interleaved sets; draw-call count asserted |
| P4.12 | S | P4.6 | `flow_ir.ml`, `.mli` | `place` takes a `target`: a legality predicate over nodes and a cost table. The native target reproduces today's decisions exactly. Mark sets are placed like kernels: GPU when every attribute region is GPU-legal | `test_ir` placement cases unchanged; new cases for a test-only target that forbids readback |
| P4.13 | H | P4.9 | `results.md` | Re-record the P4.1 rows | Per-instance circles and rects at 1,000,000 are within 2 times the uniform-style GPU row |
| P4.R | R | P4.13 | | Run `--ship`, `@runtest-native`. Decide from the P4.13 numbers whether a culling task is warranted; this plan includes none by default | Phase gate |
| P4.14 | H | P4.R | `lib/rays_execution/gpu_circles.ml`, `.mli`, `dune`, `test_gpu_draw.ml`, `rays_execution.ml`, `.mli`, `lib/rays_editor/workspace_gpu.ml`, `.mli`, `drawing.mli`, `environment.ml` | Delete `gpu_circles`, its registration (`rays_execution.ml:42`), `Workspace_gpu.circles` and the `?gpu` callback (`environment.ml:785`). Promote the API manifest separately | `--ship` and `@runtest-native` |

## Phase 5: web back ends

Phase 5 adds printers and nothing else: the core, regions and the mark contract
exist and native runs them. The JavaScript primitives are the only place
semantics are written a second time.

| Id | M | Needs | Files | Do | Gate |
| --- | --- | --- | --- | --- | --- |
| P5.1 | H | P4.R | `lib/flow_web/dune`, `flow_web.ml`, `.mli`, `test/dependency_gate.ml`, `AGENTS.md`, `specification/backend.md`, `specification/metal.md` | New empty library `flow_web`. In the gate: `rules` (never reaches `rays`, `sop`, `rdk`, `flow_sop`, `flow_gpu`, `rays_editor`, `pxui`, `pxui_shell`, `pxui_graph`, `editor_document`, `sop_catalog`, or the `gpu` group), `only` (`flow`, `flow_ir`, `param`, `rays_math`, `scene_command`), `upper`, and an injected-edge check beside the others (`:301-340`). Add its row to the Libraries table. In `backend.md` and `metal.md` (line 6), one sentence each: web export is a separate compiler target, not a fallback | `_build/default/tools/check.exe @test/runtest` |
| P5.2 | S | P5.1 | `lib/flow_web/wgsl.ml`, `.mli` | `Wgsl.kernel : Flow_ir.Packed.t -> (wgsl, Flow.Diagnostic.t) result`, mirroring `lib/flow_gpu/emit.ml` case by case over `Private.view`. Differences: inputs and outputs are `var<storage>` arrays of `f32`; constants and uniforms use `bitcast<f32>`; the finite check is an exponent-bits test; the status word is `atomic<u32>`; `@workgroup_size(64)`; division, `mod`, `pow` and `sqrt` keep the guards `emit.ml` has. Return the same binding interface and uniform layout | `@check` |
| P5.3 | H | P5.2 | `lib/flow_web/test_wgsl.ml`, `goldens/*.wgsl`, `dune` | Goldens for the programs behind `arithmetic.metal`, `noise.metal`, `select.metal` and `two_outputs.metal`, from the shared `test_program.ml` | `@lib/flow_web/runtest` |
| P5.4 | S | P5.2 | `wgsl.ml`, `lib/flow_ir/flow_ir.ml` | Web legality for regions, as diagnostics with spans: too many storage buffers in one kernel; too many elements in one dispatch; any in-frame readback (`Gpu_readback`, `(exact x)` over a GPU producer). The two numeric limits are not taken from memory: the task reads them from the WebGPU specification's default limits and cites the section in a comment. Expose it as the `legal` part of a `web` target for `place` | `@lib/flow_web/runtest`, one refusing case each |
| P5.5 | S | P5.1 | `lib/flow_web/js.ml`, `.mli` | `Js.frame : Flow_ir.Core.program -> string`: the frame level as one JavaScript module exporting `frame(input, state, rt)`. Structured control maps one to one. Locals are `let`. Primitives are calls on `rt`. Draw statements append to `rt.marks`. State slots are `state[i]`. Emit a side table from statement index to source span | `@check` |
| P5.6 | H | P5.5 | `lib/flow_web/test_js.ml`, `goldens/*.js` | One golden per core construct, from the `pp` fixtures of phases 1 and 3, plus goldens for `sketches/flow_vectors` and `examples/basic` | `@lib/flow_web/runtest` |
| P5.7 | S | P5.5 | `js.ml` | `Js.region : Flow_ir.Packed.t -> string`: a function `(inputs, uniforms, outputs, start, stop)` over typed arrays for one block range, for regions placed on the CPU. Same instruction cases as `wgsl.ml`, 64-bit floats | Goldens added to P5.6 |
| P5.8 | S | P0.R | `tools/web/runtime/prims.js`, `tools/core_fixtures.ml`, `tools/dune` | The primitive library named in `specification/core.md` and nothing more. Alongside, an OCaml tool that writes, for each primitive, a JSON file of inputs and the native results | `dune build tools/core_fixtures.exe` |
| P5.9 | H | P5.8 | `tools/lisp/test/web_prims.t`, `tools/web/test/prims.mjs` | A cram test that runs the fixtures through `prims.js` under `node` and compares: exact for integers, text and booleans; within 1e-12 relative for floats. Skip with a clear message if `node` is absent | `@tools/lisp/test/runtest` |
| P5.10 | S | P5.4, P5.7 | `tools/lisp/lisp.ml`, `tools/lisp/dune`, `specification/flow.md` section 12 | Subcommand `rays-lisp web FILE -o DIR`, beside `check`, `ml`, `source`, `dune`, `fmt` (`lisp.ml:103-109`): check, run the static stage with graph inputs at their defaults, lower, place for the web target, then write `program.js`, `kernels.wgsl`, `data.bin`, `program.map`, `index.html` and copy `tools/web/runtime/`. A refusal prints the diagnostic with its span and exits non-zero. Output is byte-deterministic | `dune build tools/lisp/lisp.exe` |
| P5.11 | H | P5.10 | `tools/lisp/test/web.t` | Cram test modelled on `test/lisp_build.t`: export `sketches/flow_vectors`, list the files, check a second run is byte-identical, and check a workspace whose draw graph references a `sop` graph is refused with a span | `@tools/lisp/test/runtest` |
| P5.12 | S | P5.10 | `tools/web_parity.ml`, `tools/web/test/frames.mjs`, `tools/dune` | Frame parity without a browser: export a workspace, run `frame` under `node` for 120 fixed-step frames with CPU regions only, and dump each frame's mark table as JSON. The OCaml side dumps the same from the core executor. Compare attributes within 1e-6 and structure exactly | `_build/default/tools/web_parity.exe sketches/flow_vectors examples/basic` passes |
| P5.13 | H | P5.12 | `results.md` | Run P5.12 over all 15 eligible workspaces and record the table: passes, refusals with their diagnostic codes, failures | Every workspace passes or is refused with a span; failures become repair tasks |
| P5.R | R | P5.13 | | Count lines in `prims.js` and compare the primitive list with `specification/core.md`. Anything in `prims.js` that is not a listed primitive is a second implementation and moves into a lowering rule | Phase gate |

## Phases 6 and 7: presenter, live loop, demonstration

Phase 6 is the only hand-written JavaScript of any size, written once for every
sketch. Phase 7 produces the numbers for the paper.

| Id | M | Needs | Files | Do | Gate |
| --- | --- | --- | --- | --- | --- |
| P6.1 | S | P5.R | `tools/web/runtime/runtime.js` | Frame loop and input. Build the frame input record with the fields of `Frame_input.t` (`lib/frame_input/frame_input.mli:2-24`): `t`, `dt`, `frame`, `tick`, `size`, `pointer`, `buttons`, `keys`, and the ordered event list with the record shapes the native `frame/input` gives (`lib/flow/op.ml:116-151`). Logical points, not device pixels. Own the state slot array | `node` unit test of event translation from synthetic DOM-like events |
| P6.2 | S | P6.1 | `tools/web/runtime/workers.js` | Worker pool over `SharedArrayBuffer`. Same schedule as native: blocks of 1,024, results written to disjoint ranges. At start, if `crossOriginIsolated` is false, show one plain message and stop | `node` test with `worker_threads`: a region's output equals the single-call output byte for byte at 1 and 8 workers |
| P6.3 | S | P6.1 | `tools/web/runtime/gpu.js` | WebGPU: request the device; compile every kernel in `kernels.wgsl` at load with `createComputePipelineAsync`; per dispatch, write uniforms, bind inputs and outputs, dispatch, and check the status word on the next frame. Buffers are owned by id and destroyed when replaced | Manual browser check recorded in `results.md`; automated in P6.8 |
| P6.4 | S | P6.3 | `tools/web/runtime/present.js`, `marks.wgsl` | The presenter for `Marks`: a WGSL port of the `Marks` family shader from P4.2, the view transform as a uniform, clip as a scissor rect, the blend factors of `scene_execution.ml:260`, painter order as given | Automated in P6.8 |
| P6.5 | S | P6.4 | `present.js` | Text and images. Text: rasterize the whole string on a 2D canvas at the device pixel ratio and draw it as a textured quad, as the native path does (`lib/rays/scene.ml:166-171`). Images: decode with the browser, draw as a textured quad with a linear sampler | Automated in P6.8 |
| P6.6 | S | P5.10 | `tools/lisp/web_server.ml`, `.mli`, `lisp.ml` | `rays-lisp web --watch FILE`: poll the file's SHA-256 every 0.5 s as `lib/rays_editor/source_file.ml` does (`interval`, line 13), re-export on change, and serve the output directory on localhost with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. Serve `/version` as the export digest. Standard library and `unix` only | Cram test starts the server on a free port, fetches `/version` and a file with an OCaml client, and checks both headers |
| P6.7 | H | P6.6 | `tools/web/runtime/runtime.js` | Reload: poll `/version` every 0.5 s; when it changes, re-import `program.js`, recompile only kernels whose text changed, reset state slots, keep the canvas | Manual check recorded: save in the native editor, the page updates |
| P6.8 | S | P6.5, P6.7 | `tools/web_shot.ml`, `test/dune` | Pixel parity in a real browser, under a new alias `@qualification-web`: launch the local Chrome headless with WebGPU against the development server, capture the canvas for `examples/particles` at fixed-step frames, and compare with the native fixed-step export within a stated tolerance. If headless WebGPU is unavailable, the tool says so and exits with a distinct code | `dune build @qualification-web` |
| P6.R | R | P6.8 | | All 15 eligible workspaces open in the browser or are refused at export. `--ship` is green. No file under `lib/` mentions HTTP | Phase gate |
| P7.1 | S | P6.R | `sketches/<demo>/sketch.rays`, `sketches/dune.rays.inc` | The demonstration workspace, scaffolded with `dune exec tools/new_example.exe -- --sketch <demo>` and written with the `write-rays-lisp` skill: marks from data, axes, pan and zoom from pointer and key state, at one million marks. No new operators. Promote `dune.rays.inc` | `rays-lisp check` and `rays-lisp web` both succeed |
| P7.2 | H | P7.1 | `results.md` | Native numbers: frame time and bytes per frame for the demo, static, panning and animated, at 10,000 and 1,000,000 marks | Entry present with commands |
| P7.3 | S | P7.1 | `tools/web_shot.ml` | Browser numbers for the same six cases, from `requestAnimationFrame` deltas over 300 frames, plus load time and kernel compile time | Entry present with browser, GPU and machine named |
| P7.4 | H | P7.3 | `results.md` | The evaluation tables: meaning preserved (P5.13, P6.8), coverage (15 workspaces), run-time cost (P7.2, P7.3), lines shared against lines per target (`wc -l` over `flow_ir`, `flow_gpu`, `flow_web`, `tools/web`) | Tables filled |

## Unknowns that gate later tasks

None of these was verified while writing the plan. The task named resolves it;
until then the tasks after it are provisional.

| Unknown | Why it matters | Resolved by |
| --- | --- | --- |
| How small the primitive list really is | It is the whole per-target cost | P0.R records the count |
| Integer semantics of the `int/*` operators | OCaml integers are 63-bit; JavaScript numbers are doubles | P0.3 |
| Whether `show` can match the native float printer in JavaScript | `draw/text` output would differ visibly | P0.5, then P5.9 |
| Whether an interpreted core is fast enough natively | The closure tier it replaces is compiled OCaml closures | P1.13; P1.14 is the fallback |
| Whether state keys can stay identical under slots | `fork_state`, `transaction` and reload depend on them | P1.8 |
| Whether `Workspace_parity.check` can toggle a switch cleanly | It is the corpus-wide oracle for phases 1 to 3 | P1.11 |
| Whether placement yields `Gpu` for width-1 outputs and non-position attributes | The GPU arm today serves positions only | P4.7, P4.9 |
| Whether `coalesce_draws` already merges mark batches | Batch merging may half-exist | P4.11 |
| WebGPU default limits | Legality on the web target; the earlier draft quoted them from memory | P5.4 |
| Headless Chrome with WebGPU on the build machine | Without it, browser pixel parity is manual | P6.8 |
| `Parallel.for_` sequential cutoff | The worker pool should use the same threshold | P6.2 reads `lib/rays_math/parallel.ml` |

### Left out on purpose

- Culling, level of detail and density aggregation. P4.R decides from
  measurements whether to add a culling task.
- `sop` and `scene` graphs, the path tracer, PXUI and the editor in the browser.
- Streaming scrubs, state kept across reloads, HTML controls.
- Any new Lisp syntax.

## Ledger

95 tasks: 63 for Sonnet, 25 for Haiku, 7 reviews. Phases 0 to 4 are 68 of them
and touch no browser code. Tick a task in the commit that completes it; add
`note:` lines under a task that stopped.

Phase 0
- [x] P0.1 H
  Gate: `dune build tools/core_census.exe && _build/default/tools/core_census.exe`
  passed on 2026-10-10: 45 files, exactly the 15 expected eligible workspaces.
  `--self-check` passed; two complete census runs were byte-identical.
  Additional `@tools/runtest` exposed an existing `pxui_shell` API-manifest
  mismatch (explicit signatures in source, module aliases in the manifest);
  the manifest was not promoted.
- [x] P0.2 S
  Specification includes both execution levels, state/drawing/intrinsics and
  54 frame primitives. On 2026-10-11 the census/table audit found exactly
  114 unique lowering rows with no missing/extra heads; whitespace passed.
  These task commits are in /private/tmp/rays-web-export-progress while the
  shared checkout's .git is read-only; a bundle preserves their history.
- [x] P0.2a S
  Remaining leaf clauses now state color parsing/quantization, packed-array
  construction/access/copying, recursive coercion and HSV/lerp expansions.
  Native edge probes and P0.6 passed on 2026-10-11, including huge finite
  channels, trailing hex underscores, zero-count unused fills, empty endpoint
  slices, width/range refusals, record order and unclamped HSV/lerp values.
- [x] P0.3 S
  Numeric contract checked against Value/Op/Packed and native probes on
  2026-10-11: signed 63-bit wrapping, quotient/remainder signs, distinct
  explicit/coercion rounding and BigInt target boundaries.
- [x] P0.4 S
  List contract checked against Workspace/Eval/Frame_input on 2026-10-11:
  static/live lengths, product/skip bounds, flattened record columns and
  oversized-source fallback/refusal; no new universal language cap.
- [x] P0.5 S
  Display and equality contract checked against native probes on 2026-10-11:
  typed/ordered equality, fixed-format tie adjustment and large-value spelling.
  In particular show(17179869184.03125) is 17179869184.0312.
- [x] P0.6 H
  Gate: `_build/default/tools/check.exe @tools/lisp/test/runtest` passed in the
  shared source tree on 2026-10-11. The new cram case checks the live corpus
  and proves that an added unknown head fails the coverage gate. The same run
  included `@lib/flow/runtest`, which passed without changing its tests.
- [x] P0.7 H
  Links to `specification/core.md` added to README, the repository design-notes
  paragraph and Flow section 14. `git diff --check` passed on 2026-10-11.
- [x] P0.R R
  Review on 2026-10-11: P0.6 passes, all 114 census heads have one rule, and
  the 54 primitive names/counts are explicit. The scalar/list/text/state
  boundaries are consistent with the native probes. Most leaves reuse existing
  native bodies or stdlib operations; structured control and operator expansions
  remain shared compiler work, rather than target-side Lisp interpretation.
  Repair P0.2a is required before this phase passes: color, array and coercion
  leaves still need complete behavior clauses. A native channel-conversion
  probe showed `int_of_float 1e20 = -1` and `int_of_float (-1e20) = 0` on this
  Apple-Silicon OCaml switch, so clamping before conversion would change pixels.
  P3.2 now explicitly includes the indexed geometry required by P3.6; its
  omission would otherwise make the native path snapshot gate impossible.
  Re-review after P0.2a on 2026-10-11 passed: 114 unique census rules,
  54 explicit frame leaves, complete numeric/list/text/color/array/coercion
  clauses, and P0.6 green. The inventory is bounded scalar/storage work;
  operator expansions and control stay in the shared lowering, so two target
  runtimes do not require two Lisp interpreters. Phase 1 may start.

Phase 1
- [x] P1.1 S
  Core data types, closed primitive inventory, source identities and deterministic
  printer added. Three hand-built scalar/branch/loop-and-state programs pass
  inline printer expectations. `@lib/flow_ir/runtest` passed on 2026-10-11.
- [x] P1.2 S
  Initial lowering slice and reviewed printer expectations for all eleven
  closure-tier expressions added. Static folding, captured residual sharing,
  branch scope and unrolled iteration identities are explicit core data.
  `@lib/flow_ir/runtest` passed on 2026-10-11. Scalar operations outside the
  current leaf/expansion coverage decline by name; P1.2a records that remaining
  operator work and must pass before the phase review.
- [ ] P1.2a S
- [x] P1.3 S
  Direct core execution and the default-off evaluator-owned switch added.
  Native leaves reuse existing operator bodies/coercions. Executor caches
  successful/refused immutable residual identities with capacity 64.
  Hook errors/exceptions restore state before the existing path retries.
  Unchanged `@lib/flow/runtest` and `@lib/flow_ir/runtest` passed on 2026-10-11.
- [x] P1.4 H
  All five existing fixtures and eleven scalar expressions compared under core,
  closure and reference settings at six times. Additional failing expressions
  compare exact diagnostics; 358 successful direct core executions match native
  bits. Hook success/decline/error/exception cases assert entry and state rollback.
  `@lib/flow_ir/runtest` passed on 2026-10-11 without refreshing expectations.
- [ ] P1.5 S
- [ ] P1.6 S
- [ ] P1.7 S
- [ ] P1.8 S
- [ ] P1.9 S
- [ ] P1.10 S
- [ ] P1.11 H
- [ ] P1.12 H
- [ ] P1.13 H
- [ ] P1.14 S
- [ ] P1.15 S
- [ ] P1.R R
- [ ] P1.16 S

Phase 2
- [ ] P2.1 H
- [ ] P2.2 S
- [ ] P2.3 S
- [ ] P2.4 S
- [ ] P2.5 S
- [ ] P2.6 S
- [ ] P2.7 H
- [ ] P2.8 H
- [ ] P2.9 S
- [ ] P2.R R
- [ ] P2.10 S

Phase 3
- [ ] P3.1 H
- [ ] P3.2 S
- [ ] P3.3 S
- [ ] P3.3b H
- [ ] P3.4 S
- [ ] P3.5 S
- [ ] P3.6 S
- [ ] P3.7 S
- [ ] P3.8 S
- [ ] P3.9 S
- [ ] P3.10 S
- [ ] P3.11 H
- [ ] P3.12 S
- [ ] P3.R R
- [ ] P3.13 S

Phase 4
- [ ] P4.1 H
- [ ] P4.2 S
- [ ] P4.3 S
- [ ] P4.4 S
- [ ] P4.5 S
- [ ] P4.6 S
- [ ] P4.7 S
- [ ] P4.8 S
- [ ] P4.9 S
- [ ] P4.10 S
- [ ] P4.11 S
- [ ] P4.12 S
- [ ] P4.13 H
- [ ] P4.R R
- [ ] P4.14 H

Phase 5
- [ ] P5.1 H
- [ ] P5.2 S
- [ ] P5.3 H
- [ ] P5.4 S
- [ ] P5.5 S
- [ ] P5.6 H
- [ ] P5.7 S
- [ ] P5.8 S
- [ ] P5.9 H
- [ ] P5.10 S
- [ ] P5.11 H
- [ ] P5.12 S
- [ ] P5.13 H
- [ ] P5.R R

Phases 6 and 7
- [ ] P6.1 S
- [ ] P6.2 S
- [ ] P6.3 S
- [ ] P6.4 S
- [ ] P6.5 S
- [ ] P6.6 S
- [ ] P6.7 H
- [ ] P6.8 S
- [ ] P6.R R
- [ ] P7.1 S
- [ ] P7.2 H
- [ ] P7.3 S
- [ ] P7.4 H
