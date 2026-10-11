# Deferred after the lean restructure

State on 2026-10-10: nothing is committed. `dune build @all`, `dune build @doc`,
`git diff --check` and window-free `dune runtest` pass. Restore points are the git refs
`refs/checkpoints/lean-0` (HEAD before the work) to `lean-6` (after renames and splits).

## Not verified

- `dune build @runtest-native` passes natively (verified 2026-10-11, Apple M1, Metal 4,
  1920x1080 display, about 2 minutes). The earlier "no Metal device" and 15-minute
  `test_workspace_ir` notes are obsolete: that rule is under `@qualification` and completed
  there. The first run failed ten tests; causes and fixes are recorded under "Native
  verification findings" below.
- `@smoke` passes natively (verified 2026-10-11, 8 seconds): both examples open a window
  and exit under their frame limit.
- `@smoke-all` passes natively (verified 2026-10-11, 2m40s): all 42 applications launch one
  at a time under the shared `smoke_window` lock and exit under their frame limit.
- `@qualification` passes natively (verified 2026-10-11, M1). The first run took about 20
  minutes and failed only the non-GPU exhaustive catalog sweep (`switch.input` index choice
  had no perturbation case in the test; fixed); the rerun reused every other cached pass.
  This includes the path tracer tests, `test_parity` and the one/eight-domain workspace
  sweeps.
- `lib/pxui/fixtures/kit_panel_2x.png` is verified: `dune build @lib/pxui/runtest` passes
  natively (2026-10-11), including the overlays, zones, table and kit panel pixel parity
  cases. No golden was refreshed.
- Verified natively 2026-10-11: the gallery shape checker (`test_gallery_shapes_native`)
  compares complete RGBA captures from four views per shape against the independent OCaml
  inputs from `923dcecf^` and passes ("independent old inputs, four views, exact native
  pixels"). The earlier portable repairs (Sweep profile `[-z x 0]`, negative-Y backbone)
  stand.

## Tests that got weaker

- Fixed and verified 2026-10-11: the portable GPU-vertex ownership test now
  requires successful submission from both prepared versions and an actual
  `Some (true, 1)` retained replay. It formerly discarded those results,
  allowing a missed replay to pass alongside the stale-handle checks.
  `@lib/scene_execution/runtest` passes on the existing recording mock;
  no raster or native pixel result is implied.
- Restored and verified natively 2026-10-11: offscreen and retained eviction tests now draw
  against black and compare the complete image to an independent white pixel expectation.
  The former white clear made a missing white draw indistinguishable; dense eviction also
  used its first frame as its oracle. The offscreen test now checks real retained replay,
  stable uploads after warm-up and wrong-version refusal. Both eviction tests require
  replay refusal after crossing resource capacity; preparation, replay and automatic draws
  keep the same clear, so clear mismatch cannot masquerade as eviction. Renderers are
  released on assertion failure. `test_retained_eviction` no longer prints success after
  both cases skip. Executable builds, portable scene-execution tests and the dependency
  gate pass. All three pass natively; the retained-replay and offscreen clear fixes are under "Native verification findings".
- Restored and verified natively 2026-10-11: `test_gpu_draw` now dispatches its
  nonfinite/overflow circle cases and requires typed refusal. It renders the CPU-built and
  GPU-resident circles through the normal command walker at 1x/2x with an affine, clip and
  all six blends, comparing complete images across repeated frames and checking visible
  geometry. Valid retained replay, stale generation lowering/replay, updated tokens and
  lease-release lowering/replay are exercised, with a final handle baseline check. Retained
  versions follow the actual token stamp. These behaviors formerly appeared only in its
  success message.
- Restored and verified natively 2026-10-11: native scene-execution blend, geometry,
  mixed-texture, mip/sampler and shadow cases, and runtime light/stencil cases now render
  all 600 frames. They formerly iterated the four labels `[1;2;60;600]` without advancing
  through the intervening frames. Existing pixel and upload-stability assertions run
  throughout. Runtime's formerly unused 65-light uniform now must return typed
  `Invalid_argument` without increasing uploaded bytes.
- Restored and verified natively 2026-10-11: automatic scratch's mixed Scene2/Scene3 case
  now verifies every RGBA pixel before and after a scissor edit, including the exposed
  white border. Exact hit/miss counters prove admission waits for two identical frames, the
  next frame replays, and a scissor edit invalidates/re-admits the plan. The shared
  renderer helper now destroys every case's renderer on assertion failure as well as
  success.
- Restored and verified natively 2026-10-11: `test_gpu_film` now captures a standalone
  tracer before creating the presenting coordinator and compares its complete frame with
  the shared-device tracer's texture readback. Explicit image readback and independently
  sampled Canvas pixels must match those same bytes. Sample counts, exact dimensions,
  three-slot texture publication and all existing lease/teardown checks remain. The
  standalone lease must also return to the original handle baseline before window creation.

- Restored and verified natively 2026-10-11: Scene2 coordinate and dense-command tests
  previously bypassed drawing (the latter ignored both its IR and prepared draws). They now
  submit through the existing protected capture helper. Coordinate checks cover
  square/clip/circle pixel bounds at 1x/2x and distinguish the circle from its bounding
  box. Dense checks render all counts/phases/repeats against independent command
  preparation, reject empty output and exercise retained transform ownership after another
  draw moves. Pixel comparisons pass natively.
- Restored and verified natively 2026-10-11: `test_pathtracer` and `test_scene` now read
  actual GPU film bytes. Their formerly empty counters check deterministic/non-flat/opaque
  output, full-resolution previews, transformed-instance agreement, lens determinism, BLAS
  residence, floor and analytic-sphere furnaces, per-instance material/motion coverage,
  curve capability behavior, composed scenes, translated-object centroids, mixed geometry
  and converted-light irradiance. The additional audit found `test_world.run` was a no-op
  and `test_parity.run` reported success without rendering; both now render, as recorded
  below.
- Restored and verified natively 2026-10-11: `test_world` now renders the uniform furnace,
  a peaked map plus sun with MIS and BSDF-only sampling, 16-spp variance against a
  converged reference, exact Color/Transparent miss pixels and a rect behind the camera
  reflected by a mirror sphere. It checks sample counts, readback lengths and handle
  teardown and restores the debug flag after each create. Furnace camera corners now stay
  inside the sphere (also corrected in `test_pathtracer`). Measured natively: furnace
  223.19 (bound 224 +/- 2), converged mean difference 0.008, 16-spp RMSE MIS 0.954 against
  BSDF-only 3.253. No historical numerical result is reproduced.
- Restored and verified natively 2026-10-11: `test_parity` now renders all four built-in
  Worlds through both renderers, using the same RDK probe geometry and the existing
  `rdk_rays` bridge. Every matte/glossy probe checks positive mean luminance and compares
  that mean and its highlight centroid; the test also checks 1,024 accumulated samples,
  exact readback lengths and handle teardown. Measured natively: mean error 0.0-2.9% (bound 20%); highlight distance 0.3-4.3 px for
  seven probes and 12.75 px for the mirror-like neon corridor probe 1, whose 10%-of-peak
  highlight is 4-10 pixels among several neon strips. The highlight bound was 8 px
  (provisional) and is now 16 px, the probe disc radius; it still rejects a highlight on
  the wrong side of the sphere but is a weak check for that probe.
- Restored and verified natively 2026-10-11: `test_ui_pipeline` previously created and destroyed
  a native execution, then printed "matches Scene2" without drawing. It now
  captures the UI batch and independently constructed Scene2 geometry at 1x
  and 2x, verifies nonempty pixels and exact image lengths, and compares every
  channel except the original rectangle-corner allowance. Submissions are
  canceled on failure as well as consumed on success. It passes natively at 1x and 2x.
- Fixed and verified 2026-10-11: `test_scene3_float32.run` formerly only
  printed a success message. It now checks the split float32 ABI, exact
  position/normal/index/color/UV words, geometry reuse across recoloring,
  attribute invalidation, repeated staging, fixed clears at all four sample
  counts and rejection of finite f64 values that overflow f32.
  `@lib/rays/runtest` passes. The existing independent f64 pixel comparison,
  recoloring upload check and coalescing comparison are now registered as
  `@lib/rays/test_scene3_float32_native`; it passes natively (maximum f64/f32 channel
  difference 0).
- Many `rdk`, `sop` and `scene_execution` tests were cut statement by statement when their
  subject was pruned. The survivors pass, but nobody has read what each one still covers.
  `test_scene_execution_metal`, `test_automatic_scratch` and `test_offscreen_metal` were cut
  twice.
- Fixed and verified 2026-10-11: prepared Scene3 validation now rejects index
  counts whose byte lengths overflow, using the same bounded predicate as
  render preflight, mesh upload and coalescing. The regression failed before
  the fix. Tests now cover all eight Scene3 families at all four admitted
  sample counts, family/resource refusals, packed attribute guards, malformed
  meshes/extents/clears and copied entry arrays with borrowed byte resources.
  The mock render test checks refusal before any upload and exactly one
  release callback. `@lib/scene_execution/runtest` and the dependency gate
  pass. This validates preparation and command boundaries; the three native
  suites named above still require actual Metal execution.
- Verified 2026-10-11: `test_instances` compares complete geometry bytes at one and four
  domains below, at and above the default 16,384-point grain and across several chunks;
  it also checks output cardinalities and unchanged source geometry/transforms.
  `_build/default/lib/rdk/test_main.exe test_instances` and
  `_build/default/tools/check.exe @lib/rdk/test_mesh` pass. No grain option was restored.
- Verified 2026-10-11: the extracted `test_copy_to_points` now asserts the
  restriction, piece-matching and target-rule results that the old monolith
  only computed. It checks exact positions/topology, edge and ordinary groups,
  ragged payloads, owner-specific arithmetic, last-rule precedence (including
  `Nothing`), unchanged inputs and complete geometry bytes at one/four domains.
  `_build/default/lib/rdk/test_main.exe test_copy_to_points` and
  `@lib/rdk/runtest` pass. Target selections retain point-index order.
- Verified 2026-10-11: `test_rdk_attributes` uses every formerly unused
  result/fixture. Assertions cover pattern exclusions, dense mode ties,
  all four transfer owners, point/primitive interpolation and miss handling,
  source/target restrictions, surface barycentric interpolation and coincident
  primitive selection, unchanged inputs and complete one/four-domain bytes.
  The 128-query linear nearest-point oracle now actually queries both indexes
  and checks distances, indices and untouched output-slice sentinels.
  `_build/default/lib/rdk/test_main.exe test_rdk` and `@lib/rdk/runtest` pass.
- Verified 2026-10-11: `test_rdk_curves` now asserts all formerly unused
  carve/extract/divide/join results and the computed divided-edge comparison.
  Exact endpoints, topology, corner/group/edge ancestry, complete one/four-domain
  geometry bytes and unchanged sources are checked, including picked-end
  orientation and preservation of unselected curves. `@lib/rdk/runtest` passes.
- Verified 2026-10-11: the remaining formerly unused monolith results now
  check selected-point sort permutation/payload and unchanged input, duplicate
  vertex/primitive ancestry and cardinality, point-cloud boundary snapping,
  and Match Size's target positions. Sort, duplication and matching compare
  complete one/four-domain geometry bytes. No unused named result/fixture
  remains in the extracted monolith; `@lib/rdk/runtest` passes. The broader
  audit of other RDK, SOP and scene-execution tests remains open.
- Verified 2026-10-11: `test_attribute_generate` now compares complete
  one/four-domain bytes for uniform, direction/sphere/ramp/discrete,
  expanded-selection/Cauchy/text, quaternion noise and automatic remapping
  results, and checks unchanged sources. `test_deform` uses its formerly
  unused eight-domain height-noise result. `test_clean` checks both overlap
  policies' exact primitive/corner ancestry and one/four-domain bytes, with
  unchanged input. The unused SOP fuse average/union fixtures now exercise
  distinct colors and selected non-first cluster members, with explicit
  expected values and complete native/Lisp/factory/domain comparisons.
  `@lib/rdk/runtest` and `@lib/sop/test_nodes` pass. A lexical AST scan now
  finds no unreferenced named local binding (including underscore-prefixed
  names) in the RDK or SOP test files; that scan does not prove full behavioral
  coverage.
- Verified 2026-10-11: `test_materials` exercises the fixed 500ms carry budget
  with a live geometry input and a controlled 600ms preparation callback.
  The held-back preview preserves the original document/history; Escape
  cancels, release commits one `Put`, and one undo restores physical document
  identity. Updates synchronize through `~await:true` and counted frames;
  no zero-budget option, clock polling or new public hook was added.
  Build with `_build/default/tools/check.exe test/test_materials.exe`; run
  `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy _build/default/test/test_materials.exe`.
- Verified 2026-10-11: the existing SOP declaration and cache sweeps now check every
  floating field through `Node.apply_parameters`: NaN and both infinities must fail
  with a finite-value error, including after a valid edit, and leave the original
  node's parameters and key unchanged. The focused gate
  `_build/default/tools/check.exe @lib/sop/test_nodes` passes with 464,386 floating
  field instances (three non-finite cases each). Explicit non-finite Lisp
  literals remain refused at this parameter boundary.
- The gallery's own `--check-all` cook is gone; `test/test_workspace_ir` sweeps the gallery
  instead.

## Native verification findings

All on 2026-10-11, Apple M1, Metal 4. The listed native tests had been cut or written
without a device; each failure below was a test or product defect, not a flake.

- Fixed: `test_gpu_draw` "stale token". The Scene2 plan cache returned a cached plan for
  a structurally equal IR whose GPU shape token had gone stale, so lowering never
  revalidated it. Plans holding GPU shapes are no longer cached (`rays_execution`).
- Fixed: `test_offscreen_metal` "retained replay missed". A prepared render whose draws
  matched the admitted automatic plan replayed it without recording the prepared
  identity/version, so `replay_prepared_sampled_resources` returned `None`. The prepared
  key now claims the automatic plan (`scene_execution`).
- Fixed: path tracer handle leak (`test_scene`, `test_world`: baseline 0, final 2).
  Replacing a mesh with spheres destroyed the old sphere buffer while the intersection
  function table still bound it; `destroy_buffer` refused ("still owns 1 live dependent")
  and the error was ignored. `install_gpu` now rebinds every table to the new geometry
  first.
- Fixed tests that no longer matched pruned API: `test_offscreen` (initial clear and
  resize used removed `step`/`resize`; now `Private.step ~clear` and a second 5x4
  offscreen), `test_ink` (oracle still drew lines, outlines and fractional rects the
  packed `Ink` no longer has; unclipped batch uses its own `Ink`), `test_canvas_native`
  (restored from `923dcecf^`: render calls, `completed_source` and `camera_depth` cases;
  `set_pixel`, `font_text`, `Mesh.create_exn`, native stat fields and `Color.green/blue`
  adapted, the CPU-mutation case dropped with `set_pixel`), `test_runtime_visibility`
  (hide assertion without `Runtime.hide`), `test_sop_catalog_exhaustive` (index-choice
  fields such as `sop/switch :input` had no perturbation).
- Threshold changed with evidence: `test_scene` red-sphere pixels allowed green/blue
  below 20; the emissive sphere also reflects the sky, best pixel measured (252, 57, 66),
  41 pixels qualify with the bound at 100. `test_parity` highlight bound 8 to 16 px (above).
- Not reproduced: `runtime_live_resize` failed once ("a programmatic resize stalled the
  frame loop for 1016 ms") during the first run while other builds shared the machine,
  and passed in the second run and in `@qualification`. It is timing based; treat a
  recurrence under load as the host being busy until shown otherwise.
- The plateau test named in an old note (`test_offscreen`, "RSS did not plateau") passes:
  large transient image RSS 41392/41424/41424 KiB.
- `tools/api_manifest/api_stable.json` differs from `dev` at `flow_ir` `Core.statement_node`
  (a `Counted` case from commit `7cb1972d`, not from this work); needs `dune promote` in the
  main checkout.

## Leftovers still in the tree

- Test-only hooks kept because native tests, benches or pure tests use them: `Session`
  `Private` hooks, `Scene.Private.stage` and `to_ir`, `Mesh.Private.triangle_count`,
  `Predicates.Private.segment_triangle_code_packed`, runtime and execution counters.
- Optional parameters kept: those passed by PPX output (`Param.field`,
  `Edit_graph.factory_slots`), `Workspace.load ?ops`, `Ty.register ?color ?default`,
  `Shape_batch.Builder.circle ?stroke_width`, the 12 in `rays_editor/native_qualification`,
  and `Editor.create ?lights ?presets`.
- Removed and verified 2026-10-11: `Scene3.t` no longer stores constant
  `depth_clear` and `stencil_clear` fields. Its existing private accessors
  return 1 and 0; lowering and the public interface are unchanged. CPU
  staging tests cover the fixed values at every admitted sample count.
- Removed and verified 2026-10-11: PXUI's private `Paint.scale/tx/ty` and
  per-box `l_scale/l_tx/l_ty` arrays were always the root's identity values.
  Layout, hits, text, clips and input regions now use logical screen points
  directly, and painting no longer allocates/reapplies an identity `Ui_batch`
  transform per primitive. The four existing parity fixtures' complete
  instance bytes and batch descriptors match before/after at 1x and 2x.
  `test_ui`, `test_input`, `test_keyboard`, `test_table` and the new
  `test_ui_commands` pass; public API manifests compare equal. The existing
  pixel golden cases pass natively (2026-10-11), so the full PXUI alias is green. The 200-node editor benchmark allocates about 92 KB less
  per frame; commands and measurements are recorded in `results.md`.
- Removed and verified 2026-10-11: `Ui_batch` no longer stores an identity
  transform in its builder or batch records; the unused `xform` type and
  `Builder.set_xform` are removed. Wire clipping uses screen coordinates,
  and native lowering maps them directly to clip space. The new builder
  test checks exact coordinates, rejected offscreen chords, retained
  clipping, texture batching and immutable published data across reset.
  The eight PXUI fixture packets match before/after, comparing complete
  instances and all remaining batch fields. The lower-level interface
  removal is intentional; the high-level stable manifest does not cover
  `scene_command` and is unchanged by it. Native pixels still need Metal.
- Removed and verified 2026-10-11: Easy Camera's immutable default bindings
  are a direct left-orbit/middle-right-pan match. Its constant binding `key`,
  inaccessible interaction list, previous-key cache and unreachable drag
  Dolly branch are gone, along with the unused public `binding` and
  `interaction` types. Fly navigation still consumes held WASD/Shift keys.
  Focused tests cover modifiers, bounds/capture, density, reset/cancellation
  and fly speed; 128 public camera states match exactly before/after.
  `@lib/rays/runtest`, typechecking, the dependency gate and the editor input
  test pass. The idle and active benchmarks are recorded in `results.md`;
  the intended API removal has a separate reviewed manifest promotion.
- Removed and verified 2026-10-11: `Light.attenuation.linear` was always
  zero through its constructor and had no Lisp declaration. The OCaml record
  now stores constant/quadratic coefficients only; the native uniform ABI
  keeps its zero-filled reserved linear slots. Complete uniform buffers for
  all four light kinds and all four area sample counts match before/after.
  Constructor-validation and exact field-layout tests, `@lib/rays/runtest`,
  typechecking and dependency checks pass. The removed public record field
  has a separate reviewed API promotion.
- Fields that are constant but still threaded: the path tracer `scale`. Tracing confirms
  `dispatch_size` always returns scale 1, but removal still needs the native performance
  and pixel checks. The native path tracer tests now run (a Metal device is present), but the
  optional Metal compiler toolchain is missing: `xcrun -sdk macosx metal --version` fails
  with "cannot execute tool 'metal' due to missing Metal Toolchain" (checked 2026-10-11).
  The constant stays threaded; removal with before/after pixel equality and a benchmark
  needs `xcodebuild -downloadComponent MetalToolchain` first.
- `lib/sop/sop_topology.ml` keeps its prefix (`Topology` would shadow `Rdk.Topology`), and
  `Leader.keymap3` keeps its suffix (`Leader.keymap` is taken).
- `lib/rays` is still 30 modules: the editor is built on `Sketch`/`Frame`/`Scene`, and
  `examples/pathtracer` plus sketches `cube_cage`, `shattered_cube` and `voxel_wall` are
  still OCaml.
- Split and verified 2026-10-11: `lib/rdk/test_rdk.ml` is a 160-line fixture
  coordinator. Its pattern/line/kernel, attribute, modeling, UV, curve,
  measurement/merge/blur and Copy to Points checks live in seven subject
  modules (the largest was 925 lines at extraction). Every extracted body
  matched the original byte for byte, with the same call order and shared geometry values;
  `@lib/rdk/runtest` passes, including the existing one/four-domain cases.
- Split and verified 2026-10-11: the 2,682-line graph pane now keeps state,
  commands and painting in three private modules with explicit interfaces;
  `scope_pane.ml` keeps frame gestures. Every moved implementation body is
  unchanged, the public API manifest is identical, all 455 pane checks pass
  and the dependency gate passes. The 2,001-node frame benchmark is recorded
  in `specification/web-export/results.md`; its visible frame allocates 0.19%
  more, while the tiny pane retains its original allocation count.
- Split and verified 2026-10-11: the 941-line environment now has private
  view composition, model and source-file modules with explicit interfaces.
  The 399-line `environment.ml` retains frame coordination, presentation,
  crash reports and shutdown in their original order. Every implementation
  body is unchanged and the public API manifest is identical. Window-free
  editor logic, workspace shell/source, scene synchronization, text-pane and
  dependency gates pass, including recovery-file ownership and failed-write
  retry. The 200-node edit-frame benchmark retains every allocation count;
  measurements are in `specification/web-export/results.md`.
- Verified 2026-10-11: `_out/` is absent from this worktree; there is no stale
  output directory left to delete. The ignore rule remains for future PNG saves.

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

## Lisp gaps

- Fixed and verified 2026-10-11: explicit float literals `NaN`, `Infinity`,
  `-Infinity` now read, evaluate, print and round-trip with comments intact.
  `1e999` remains refused; lowercase `nan` and `inf` remain names. Checked
  graph edits and actual pane typing cover all three values, replacement by
  a finite value, unchanged scrubbing, and rejection by catalog fields (a
  scalar spelling of a vector parameter included). Floating parameter,
  integer conversion and packed-array boundaries keep their finite checks.
  The isolated Flow/graph gates and pane gesture test pass; the API change is
  only `Syntax.number_value` and the number field's opt-in `nonfinite` flag.
  Editor benchmark: 200 nodes, one domain, dev profile, 1,200 × 760, three
  medians before/after, `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
  _build/default/tools/bench_rays_editor.exe 200`. Drag 1.806021 → 1.806974 ms,
  undo 2.344131 → 2.336025 ms, scrub 1.842022 → 1.837015 ms, scrub excluding
  cook 1.741886 → 1.739025 ms. Bytes/frame remain 5,902,734 / 5,372,644 /
  5,372,644 for drag/scrub/scrub excluding cook; undo 6,677,352 → 6,677,208.
  Follow-up verified: `Lisp_sop.float` now uses this same printer. Five SOP
  refusal tests exercise explicit NaN and require `E_NONFINITE` at the
  parameter boundary, replacing the old unknown-name refusal or generic
  failure check. `@lib/sop/test_sop` passes; the shared helper's broader
  SOP and Flow-SOP gates also pass.
- Fixed and verified 2026-10-11: `(sop/curve points :filled true)` builds one polygon
  primitive from explicit points. `poly_fill` was not at fault: it fills one-sided boundary
  edges of polygon primitives, and `sop/curve` only made polylines, so there was nothing for it
  to fill. No new SOP kind (`sop/curve` is a lowered builtin; `filled` is a graph keyword row
  like `closed`). The gallery star is now `(sop/poly_extrude <filled curve> :distance 0.65)` on
  the original XZ points; `test/test_gallery_shapes` passes in both modes, including the exact
  native pixel comparison against the old polygon extrusion. Test: `test_nodes` (one 18-point
  polygon; extruded star has 20 primitives and volume 0.65 x star area).
- Fixed and verified 2026-10-11: `Lisp_sop.node ~with_` accepts
  `"image/pixels", node` as an image-typed `(image/ext_pixels)` binding, using
  the existing immutable operator-extension API and normal checked lowering.
  The image node and its inputs retain their identity and are not cooked
  during lowering. `test_attr_from_image` now uses the Lisp surface for its
  channel/UV/domain cases; `@lib/sop/runtest` and `@lib/flow_sop/runtest` pass.
- Checked 2026-10-11, none of `chromatic_drift`, `pastel_flow` or `code_quadtree` is portable:
  each still needs a subsystem that is not a small addition, so none was ported. The README list
  (updated the same day) states exactly what is missing: UI slider/button/undo ops and
  settings save/load (`chromatic_drift`, `pastel_flow`); a texture op for 3D surfaces and a
  PNG-sequence export (`chromatic_drift`); blend and depth control on `scene/` layers
  (`pastel_flow`); directory listing, text-file read, child processes and a text atlas
  (`code_quadtree`). The per-vertex colour/normal gap is partly closed (`sop/set_color`,
  `sop/normals`, `:filled` polygons), but a faithful port still needs the items above.

## Docs

- The proposal artifact has not been updated with the outcome. No path or
  link identifies it, and the 2026-10-11 local and connected Pages searches
  did not locate the lean-restructure proposal. The accessible Rays Page
  concerns the browser-compilation paper. Its content was left unchanged;
  the requested artifact's location is pending user clarification.
