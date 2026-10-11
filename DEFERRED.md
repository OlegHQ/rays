# Deferred after the lean restructure

What is still open after the restructure of 2026-10-10 (commit `923dcecf`). A finished item is
deleted, not ticked.

## Tests that got weaker

- 2026-10-11: every test file was compared with its version before `923dcecf` and the tests
  whose subject survived are back. Four things were not restored and are the owner's call:
  - `test/sop_render_parity.ml` (23 SOP graphs cooked at one and four domains and exported as
    PNG, bytes compared) was written with the typed SOP constructors. It is not re-authored in
    Lisp; the cooks are compared with native RDK in `lib/sop/test_nodes.ml`.
  - `test/test_2d_ports.ml` compared eight Lisp ports with their OCaml `main.ml`. Those programs
    are deleted, so the ports are only compared with themselves across domain counts.
    `examples/particles` keeps an OCaml oracle in `test/test_drawing.ml`.
  - The path tracer's `RAYS_PATH_TRACER_EXACT_M1` digests were stale before the prune (the
    kernel's rect-light transport changed in `4fce19a5`); the rule that set the switch is
    removed. Today's frames hash to `f2d5db77d2304128e7b179ab29121798` (lit sphere) and
    `d6ad096a19f992493f21101954aac616` (instanced), unrecorded.
  - The Metal safe suites lost most of their statements to the binding prunes of 2026-09-26
    and 2026-10-06, before this restructure. They now cover the calls that are left; nobody
    compared them statement by statement with the versions before `0d136464`.
- `Shape_batch.Private.copy` copies the `checked` mark, so a copy of a validated batch is never
  scanned. The comment in `lib/scene_command/test_shape_batch.ml` says the mark belongs to the
  batch that passed; decide which is meant.
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
  - Measured again 2026-10-11 (M1, load 5 to 6, nothing changed in the executor): micro
    core 152 to 154 ns and 1,912 bytes per evaluation, walker 942 to 949 ns.
    `examples/particles` on the core path costs 3.8 ms of processor time and 12.9 MB
    allocated per frame (`marks_shot.exe examples/particles OUT 800 600 N`, user time and
    `allocated_words` at 601 frames minus 1 frame, over 600): 645 bytes for each of the
    20,000 element steps. Cause read from `Core_lower`: only a residual that is itself a
    packed `map` is tried as a region (`packed_region`); the two maps of particles are
    nested in a `state` step, whose sources are frame locals, so `hof` lowers them to
    `Counted` loops of boxed statements. The closure tier had the walker offer each inner
    map to the packed template tier (`Packed.compile_template`, still tested by
    `test_frame_kernel`). Next step: let a region take its arrays from frame locals
    (`Invoke`'s `args`, always `[]` today; `Packed.force` with given arrays; a template
    with no local-dependent uniform), emitted by `Core_lower.hof` for a packed map whose
    sources are arrays. It changes lowering goldens and the web `rt.invoke(k, args)`.
- The corpus sweep `@test/test_workspace_ir` takes 20 to 25 minutes since P1.11, because
  every comparison now runs with the core path off and on. After P1.16 there is one
  path; check the second pass is gone and the time is back down.
  - 2026-10-11, partly checked. The sweep executable over the 43 examples and sketches
    took 633 s real, 673 s user (M1, load 3 to 6, run by hand from `_build/default/test`,
    so the kit and the fixtures were not timed; no baseline was taken the same day). A
    `sample` taken while it was on `sketches/million_marks` shows the tree walker
    (`Eval.ev`, `apply_op`, `Op.find`): the reference forces of the 1,000,000-element map
    at four times and two domain counts, about 22 s each before the lookup change of the
    same day. That workspace, added in P7.2, is the likely bulk of the time now, not a
    second core pass. Next step: time the sweep with and without `million_marks`.
- Packed `map`/`filter` forms that `Packed.compile` refuses (dynamic `int`/`floor`, state,
  array captures; 40 residuals in the corpus) run as a counted frame-level loop over
  `Array_nth`, single-threaded, not as a region. Correct, not fast; widening
  `Packed.compile` would move them to parallel blocks or the GPU. The particles
  measurement and next step above are this bullet's too.
- Compiling a packed kernel through `Core_region.lower` and `of_region` (P2.4 to P2.6) costs
  more than walking the term: `tools/bench_core.exe kernels`, compile of one map over 1,024
  elements 1.46 to 2.19 microseconds (+50 percent), 1,000,000-element map 2.18 to 2.38 (+9),
  sum 1.11 to 1.28 (+15); fused pair unchanged. Likely cause: building the region record
  and then `of_region` (validation pass, `dependent` recomputation, a second record copy).
  Force time is unaffected. Once per kernel, not per frame, so left alone. Measured again
  2026-10-11 (one run, load 3.4 with the sweep beside it, no code change): 1.52, 2.27,
  4.39 (fused) and 1.37 (sum) microseconds, so the two maps are within 4 percent of the
  old numbers and the sum is 0.26 microseconds above.
- Native mark attributes are one kernel dispatch each (found closing P4.13, whose gate is met:
  `results.md`, 2026-10-11 addendum). A mark set whose radius and fill both read `t` beside GPU positions is
  three dispatches, 14.3 ms at 1,000,000 against 4.6 for one (`bench_marks_gpu.exe`, "moving both"). Two things
  are left. The draw program invokes its regions one by one, where the web export fuses the attributes of one
  set into one kernel (`Core_fuse.merge` in `tools/lisp/web_export.ml`, `groups`); the native counterpart is to
  merge the device-eligible `Invoke`s of one `Batch` in `Core_exec.prepare`. And a kernel whose source is an
  inline static expression (`(map f (array/range n))`) evaluates, packs and uploads that source on every
  dispatch (8 MB and most of the 4.7 ms): `Packed.Private.prepare` asks the walker for the source term each
  frame, and `Run.dispatch` only skips an upload when the array is physically the same. Keeping the value of a
  source the static stage could have finished (no frame fact, state, element or host source) per `Packed.t`
  would remove it; a source bound in a `let*` is already a shared constant.
- A static attribute array of the web export is still a constant of `data.bin` in binary64: 24 MB for the
  1,000,000 static marks of P7.3 (the presenter now uploads it once, `results.md`, 2026-10-11 addendum). Shipping
  it as binary32 was tried on paper and not done, for two reasons found in the code. The node parity
  (`tools/web_parity.ml`, `tools/web/test/frames.mjs`) compares every attribute buffer with the native binary64
  one within 1e-6, and a binary32 constant near 300 is off by up to 2e-5; and a kernel input cannot be binary32
  either, because under node the shim runs a GPU-placed region on the CPU from the same stored input
  (`frames.mjs`, `rt.gpuArray = k => rt.invoke(k, [])`). The step that removes the payload instead of halving
  it: let the export keep a large static `map` that only feeds mark attributes as a region (the static stage
  folds it to a constant today), so `gpuRun` dispatches it once per load and nothing is stored or uploaded but
  its inputs. That needs `Web_export.lower` to evaluate with such maps deferred (the `Needs_t` route in
  `Flow.Eval.hof`, for this caller only), to fall back to the folded program when a deferred region is not
  GPU-placed (a static CPU region would run every frame: `rt.invoke` keeps nothing), and `marks_shot` and
  `web_parity` to run the same lowered program.

## Known native test instability

2026-10-11: `runtime_native_qualification` failed with "physical footprint did not plateau beyond the SDL
window baseline" (growth about 21 MB over a 9 MB baseline, at every commit back to `d88c46b`). Attributed and
fixed at its cause; the test and its 4,096 KiB bound are unchanged and it now passes (growth 0 to 48 KiB,
measured baseline 0 to 64). Evidence, method and numbers: `specification/web-export/results.md`, "native
teardown footprint" addendum.

- What was retained: every `NSWindow` ever closed with its view tree (385 KiB per lifecycle), and every frame's
  Metal command buffer, encoder, pass descriptor, drawable and written buffers (4.0 KiB per frame). One owner for
  all of them (`leaks --trace`): the initial thread's root autorelease page. An OCaml program has no Cocoa run
  loop, so an object autoreleased outside a pool of the stub's own is never released.
- Which part of the cycle: window creation, not teardown. `rays_window_plain_titlebar` (`lib/sdl3/sdl3_cocoa.c`,
  called by `Sdl3.Window.create`) messaged AppKit with no pool and autoreleased the window about 95 times. The
  test's "SDL window baseline" loop goes through the same function, so the baseline was Rays too. The 21 MB the
  test saw on top was the scenario's 600 frames: buffers kept alive by the same page (the `IOAccelerator` rise
  from 13 to 29 MB between cycles 16 and 48).
- Fixed in `lib/sdl3/sdl3_cocoa.c` and `lib/metal/metal_bridge.mm` (a pool in every stub that messages
  Objective-C, handle lookups return retained, `presentDrawable:` pooled), and `lib/metal/metal.ml`
  (`Gc.finalise_last` for child handles: the OCaml heap grew 0.35 KiB per frame without it).
  `lib/runtime/native_qualification/runtime_autorelease` (`@runtest-native`) fails on any object the initial
  thread autoreleases with no pool in place.
- Next step, left to the owner because it changes the test: the baseline loop (`sdl_window_floor_growth`) now
  measures nothing, so it can go, and the bound can come down from 4,096 KiB (1,024 held with eight times the
  margin in six runs).
