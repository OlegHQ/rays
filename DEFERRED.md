# Deferred after the lean restructure

What is still open after the restructure of 2026-10-10 (commit `923dcecf`). A finished item is
deleted, not ticked.

## Tests that got weaker

- 2026-10-11: the `rdk`, `sop` and `scene_execution` tests are restored (the pre-prune tests are
  back wherever their subject survived). Outside those three libraries these files are still
  under 85% of their size before `923dcecf` and nobody has compared them with the old version:
  `lib/pxui/test_keyboard.ml`, `lib/rays/test_automatic_text_cache.ml`, `test_ink.ml`,
  `test_scene_rounded_cache.ml`, `test_world.ml`, `lib/rays_execution/test_dense_scene2.ml`,
  `lib/scene_command/test_display_list.ml`, `lib/rays_pathtracer/test_world.ml`,
  `test/test_editor_commands.ml`, the `lib/metal/test_metal_*_safe.ml` suites and
  `lib/runtime/resources/test_*`. The old versions of the first nine do not compile (`Frame`
  fields, `Display_list.Builder`, `Ink.line`, `World.irradiance`, `Editor3` and the like changed
  or went), so each is a hand port, as `test/test_rays.ml` was; the Metal and runtime suites
  were not tried.
- `runtime_live_resize` is wall-clock based: it failed once under machine load ("a programmatic
  resize stalled the frame loop for 1016 ms") and has passed since. Rerun it once before
  reading a failure as a regression.

## Lisp gaps

- Porting `chromatic_drift`, `pastel_flow` and `code_quadtree` to Lisp: dropped by owner
  (2026-10-11). The README lists what each would need.

## Known costs and behaviour changes to confirm

- Fixed and verified 2026-10-11: a `sop/merge` with `:source_attribute` merges
  geometry once and builds only the additional primitive tag array. Existing
  tags, attribute order, schema refusals and cancellation are preserved;
  `@lib/flow_sop/runtest` passes, including byte comparisons with the original
  two-merge implementation at one and eight domains. For 20 cooks of eight
  inputs / 98,304 output primitives, median time falls from 0.138822 to
  0.071613 seconds and allocation from 266,731,296 to 149,511,776 bytes at one
  domain. Command and both domain measurements are in
  `specification/web-export/results.md`.
- Confirmed 2026-10-11: `/ e` writes a `scene/world` member and a `sky` graph
  containing a sky and sun as one `Add World` history entry. Reopening the
  existing World preserves document identity; one undo restores the World-free
  document. `_build/default/tools/check.exe @test/test_world_command` passes.
- Confirmed 2026-10-11: World deletion follows the documented graph ownership
  rule: an unreferenced world graph is removed, while a graph another reference
  still uses stays unchanged. No `(world/none)` is written. This corrects the
  earlier note that every world graph remains. The creation, both deletion
  cases and reload parity pass under `@test/test_scene_sync`.
- Confirmed 2026-10-11: the gallery's two `W_SOFT_RANGE` warnings are advisory
  bounds of 64 for columns/rows, not hard limits. The authored values remain
  100 and cook to 10,201 points / 20,000 triangles. `@test/test_sop_catalog`
  checks the actual gallery's warning codes and this resolution without
  changing the example or its declared ranges.

## Deferred optimization (web export)

Benchmark gates in `specification/web-export/plan.md` were waived by the owner on
2026-10-11: correctness gates block, speed thresholds are recorded here and looked at
later. Numbers and commands are in `specification/web-export/results.md`.

- Core frame programs against the deleted closure tier (P1.14, P1.14a, P1.14b). Plan gate
  was core at most 1.1 times closure on one scalar residual (`tools/bench_core.exe`,
  expression `(+ (* (sin t) 0.5) (* t t))`, one domain, M1, background load about 4).
  Reached 1.26: core about 151 ns and 1,960 bytes, closure about 120 ns and 1,784 bytes
  per evaluation (walker about 890 ns). History: 2.92, then 1.39 after executor fast
  paths and a postfix scalar tier, then 1.26 after keeping the prepared program on the
  residual.
  - Remaining cost is the postfix interpreter itself, about 30 ns: nine dispatches plus
    `sin`. Not tried: superinstructions for constant and time operands, removing the
    per-call stack allocation, compiling a core program to OCaml closures as P1.14's card
    describes (the interpreter would stay as the test reference).
  - Region programs are not cached on the residual; only region-free programs use the
    slot, because a region's `force` closure captures per-call state.
  - Final micro ratio at P1.14b: 1.23 (core 146.9 ns, closure 119.7 ns).
  - Whole-frame time over the 15 eligible workspaces, core against closure, measured
    once before P1.16 (the bench mode was not kept): faster on 7, equal on 6, slower on
    2. `examples/particles` is about 2.3 times slower (4.5 ms against 2.0 ms per frame):
    its maps run about 10,000 elements times roughly 50 statements in the core
    interpreter. `examples/drawing` is about 1.07 times slower. The closure tier is gone
    after P1.16 (`3f1ff18c`); compare against a checkout of `3c1314b3`.
- The corpus sweep `@test/test_workspace_ir` takes 20 to 25 minutes since P1.11, because
  every comparison now runs with the core path off and on. After P1.16 there is one
  path; check the second pass is gone and the time is back down.
- Packed `map`/`filter` forms that `Packed.compile` refuses (dynamic `int`/`floor`, state,
  array captures; 40 residuals in the corpus) run as a counted frame-level loop over
  `Array_nth`, single-threaded, not as a region. Correct, not fast; widening
  `Packed.compile` would move them to parallel blocks or the GPU.
- Compiling a packed kernel through `Core_region.lower` and `of_region` (P2.4 to P2.6) costs
  more than walking the term: `tools/bench_core.exe kernels`, compile of one map over 1,024
  elements 1.46 to 2.19 microseconds (+50 percent), 1,000,000-element map 2.18 to 2.38 (+9),
  sum 1.11 to 1.28 (+15); fused pair unchanged. Likely cause: building the region record
  and then `of_region` (validation pass, `dependent` recomputation, a second record copy).
  Force time is unaffected. Once per kernel, not per frame, so left alone.
- `tools/web/runtime/gpu.js` re-uploads every kernel input on each dispatch (it converts to f32 and
  `writeBuffer`s the whole array); native skips sources whose stamp is unchanged. Static sources
  should be uploaded once and kept.
- Per-instance GPU marks (P4.13). Plan gate was per-instance circles and rects at 1,000,000 within 2 times
  the uniform-style GPU row (`lib/rays_editor/native_qualification/bench_marks_gpu.exe`, M1, load 6 to 9).
  Reached 8.3x (circles, 73.7 ms against 8.9) and 8.8x (rects, 80.4 against 9.1). A per-instance radius or size
  on the GPU costs 1.4x and 2.1x; a per-instance fill costs 7.7 to 7.9x. Likely cause: a colour attribute cannot
  be a GPU region yet, so the fill is a CPU `map` over 1,000,000 vec3 colours that `Marks_scene` converts through
  `drawing_color` into packed words (188 MB allocated per frame). The `Marks` shader already reads float rgb
  (fill mode 1); letting `fill`, `stroke` and `color` be `Marks.Device` buffers (a `Core_exec.device_regions`
  name list, `Marks.validate`, `Marks_scene.words`) would remove it. Still 2.1x faster than the CPU path
  (animated circles 1M, 153 ms).
- Static CPU attribute buffers are re-uploaded every frame by the web presenter (P7.3,
  `results.md`, `million_marks` with the drift removed, 1,000,000 marks, M1, headless Chrome 154,
  load 4 to 17): 34 ms per frame static and 39 ms panning against 30 ms for the animated GPU kernel
  case; 10,000 marks cost about 2 ms. Fix: cache the uploaded buffer by array identity in
  `present.js` (and a f64 `data.bin` is still 24 MB at 1M).
- A static packed `map` is evaluated by the tree walker at startup, not by a kernel (found in P7.2,
  `results.md`, `million_marks` with the drift term removed, 1,000,000 marks, M1): first frame about 22 s and
  79 GB allocated (`allocated_words` 9.9e9, about 22 microseconds and 79 KB per element), against 0.4 s when the
  map reads `t`. Root cause: `Flow.Eval.hof` (`lib/flow/eval.ml`, `Map` arm, `array_init e n (fun k ->
  concrete c (item k))`) runs the function through `ev`/`apply_op`/`call_fn` for every element whenever the
  static stage can finish it; only a `Needs_t` makes a residual that `Flow_ir.residual` (`lib/flow_ir/flow_ir.ml`)
  turns into a `Packed_map` kernel (GPU or block CPU tier). `sample` of the process shows `Eval.ev`,
  `Op.find`/`Hashtbl.find_opt` (the `"value/" ^ name` lookups), `List.mem` and `caml_compare` in the walker, nothing
  in a kernel. Fix I would make: in `hof`, when `st.time = None`, the output is `Ty.Array` and the element count is
  at least a threshold (say 4,096, the GPU's 1,024 minimum or `Packed` block size), raise the same exception that
  `Needs_t` raises so the map becomes a `Static`-rate residual, which `hoist`, `Core_exec.static_invokes` and
  `Flow_ir.compile_marks` already run once and keep. Not done: it changes which graphs finish in the static stage
  (a consumer that needs the concrete array, such as an `exact`, a host graph output or `array/length`
  feeding a graph parameter, would then fail with `E_EVAL` unless it is also deferred), so it needs a corpus pass
  (`@test/test_workspace_ir`, 20 to 25 minutes) and a rule for those consumers.

## Known native test instability

2026-10-11: `runtime_native_qualification` (`lib/runtime/native_qualification`, aliases
`qualification`, run directly as the built exe) fails with "native repeated teardown
physical footprint did not plateau beyond the SDL window baseline" on this machine
(M1, current macOS). It is deterministic and not a regression: HEAD `ac8466a1` three
runs gave growth 21088, 20960, 21024 KiB over baselines of about 9.4 MB; `99115fe8`
gave 21153 and 21233 KiB; `4c00087b` gave 21057 KiB; `d88c46b` fails too. The
growth is the same (about 21 MB) at every commit, so no recent change added it;
the check (floors of footprint over 72 create/destroy cycles) is
sensitive to the OS allocator, not to a Rays resource. Not investigated further and the
threshold is unchanged; do not use this test as a regression signal until the
footprint source is attributed (vmmap on the 72-cycle loop).
