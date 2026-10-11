# Deferred after the lean restructure

State on 2026-10-10: nothing is committed. `dune build @all`, `dune build @doc`,
`git diff --check` and window-free `dune runtest` pass. Restore points are the git refs
`refs/checkpoints/lean-0` (HEAD before the work) to `lean-6` (after renames and splits).

## Not verified

- `dune build @runtest-native` has not completed once. The only attempt was stopped after
  `test_workspace_ir.exe` ran for 15 minutes under `RAYS_SCENE3_FLOAT32_COMPARE`: the rule
  that replaced the old gallery-only float32 check sweeps every workspace. That rule
  (`test_scene3_float32_gallery` in `test/dune`) is now under `@qualification`, and the
  native run has not been repeated since.
  On 2026-10-11, the command suite's existing canvas-size check failed with
  `E_GPU: Ogpu_metal.Device.system_default: Metal has no system default device`
  in this managed runner (report: `/private/tmp/rays-canvas-size-debug/editor.txt`).
  Its assertion remains intact; native rendering gates still need a runner
  with an available Metal device.
- `dune build @smoke` and `@smoke-all` have not been run. `examples/particles` and
  `examples/procedural_modeling` now generate `lisp.exe` like the other examples (built,
  not launched).
- `@qualification` has not been run. The path tracer, runtime and OGPU changes from the
  optional-parameter removal are covered only by the build and the window-free tests.
- `lib/pxui/fixtures/kit_panel_2x.png` was regenerated after six widgets were deleted and
  was checked by eye only.
- The gallery shapes rebuilt in Lisp (`fibonacci`, `disc`, `gyroid`, the star as a
  `sop/sweep`) were not compared visually with the old OCaml ones.

## Tests that got weaker

- Restored, native verification pending 2026-10-11: offscreen and retained
  eviction tests now draw against black and compare the complete image to
  an independent white pixel expectation. The former white clear made a
  missing white draw indistinguishable; dense eviction also used its first
  frame as its oracle. The offscreen test now checks real retained replay,
  stable uploads after warm-up and wrong-version refusal. Both eviction
  tests require replay refusal after crossing resource capacity; preparation,
  replay and automatic draws keep the same clear, so clear mismatch cannot
  masquerade as eviction. Renderers are released on assertion failure.
  `test_retained_eviction` no longer prints success after both cases skip.
  Executable builds, portable scene-execution tests and the dependency gate
  pass. Direct native attempts explicitly skip all three cases for no Metal
  device; pixels, upload stability and eviction behavior remain unverified.
- Restored, native verification pending 2026-10-11: `test_gpu_draw` now
  dispatches its nonfinite/overflow circle cases and requires typed refusal.
  It renders the CPU-built and GPU-resident circles through the normal
  command walker at 1x/2x with an affine, clip and all six blends, comparing
  complete images across repeated frames and checking visible geometry.
  Valid retained replay, stale generation lowering/replay, updated tokens
  and lease-release lowering/replay are exercised, with a final handle
  baseline check. Retained versions follow the actual token stamp. These
  behaviors formerly appeared only in its success message. Typechecking,
  executable builds, portable scene-execution tests and the dependency gate
  pass. The native attempt fails at Metal device acquisition; pixel, GPU
  status and stale replay assertions remain unverified here.
- Restored, native verification pending 2026-10-11: native scene-execution
  blend, geometry, mixed-texture, mip/sampler and shadow cases, and runtime
  light/stencil cases now render all 600 frames. They formerly iterated the
  four labels `[1;2;60;600]` without advancing through the intervening frames.
  Existing pixel and upload-stability assertions run throughout. Runtime's
  formerly unused 65-light uniform now must return typed `Invalid_argument`
  without increasing uploaded bytes. After correcting a mechanical token
  join in the edit, typechecking, builds, portable runtime/scene-execution
  suites and the dependency gate pass. Actual native attempts cannot exercise
  these assertions: scene execution fails at Metal device acquisition and
  runtime lighting takes its existing startup-error skip.
- Restored, native verification pending 2026-10-11: automatic scratch's
  mixed Scene2/Scene3 case now verifies every RGBA pixel before and after a
  scissor edit, including the exposed white border. Exact hit/miss counters
  prove admission waits for two identical frames, the next frame replays,
  and a scissor edit invalidates/re-admits the plan. The shared renderer
  helper now destroys every case's renderer on assertion failure as well as
  success. Typechecking, executable builds, portable scene-execution tests
  and the dependency gate pass. All six native scratch cases explicitly
  skip with no device here, so neither pixels nor replay counts are verified.
- Restored, native verification pending 2026-10-11: `test_gpu_film` now
  captures a standalone tracer before creating the presenting coordinator
  and compares its complete frame with the shared-device tracer's texture
  readback. Explicit image readback and independently sampled Canvas pixels
  must match those same bytes. Sample counts, exact dimensions, three-slot
  texture publication and all existing lease/teardown checks remain. The
  standalone lease must also return to the original handle baseline before
  window creation. Typechecking, executable builds and the dependency gate
  pass; the forced native attempt fails at Metal device acquisition. This
  restores the documented assertions, without claiming native parity here.
- Restored, native verification pending 2026-10-11: Scene2 coordinate and
  dense-command tests previously bypassed drawing (the latter ignored both
  its IR and prepared draws). They now submit through the existing protected
  capture helper. Coordinate checks cover square/clip/circle pixel bounds at
  1x/2x and distinguish the circle from its bounding box. Dense checks render
  all counts/phases/repeats against independent command preparation, reject
  empty output and exercise retained transform ownership after another draw
  moves. Typechecking, executable builds and the dependency gate pass. Native
  coordinates takes its existing no-device skip; dense execution fails at
  Metal device acquisition. Pixel comparisons remain unverified.
- Restored, native verification pending 2026-10-11: `test_pathtracer` and
  `test_scene` now read actual GPU film bytes. Their formerly empty counters
  check deterministic/non-flat/opaque output, full-resolution previews,
  transformed-instance agreement, lens determinism, BLAS residence, floor
  and analytic-sphere furnaces, per-instance material/motion coverage, curve
  capability behavior, composed scenes, translated-object centroids, mixed
  geometry and converted-light irradiance. Typechecking and executable builds
  pass. Both forced native attempts fail at device acquisition because Metal
  has no system default device; numerical thresholds need native validation.
  The additional audit found `test_world.run` was a no-op and `test_parity.run`
  reported success without rendering; both now render, as recorded below.
- Restored, native verification pending 2026-10-11: `test_world` now renders
  the uniform furnace, a peaked map plus sun with MIS and BSDF-only sampling,
  16-spp variance against a converged reference, exact Color/Transparent miss
  pixels and a rect behind the camera reflected by a mirror sphere. It checks
  sample counts, readback lengths and handle teardown and restores the debug
  flag after each create. Furnace camera corners now stay inside the sphere
  (also corrected in `test_pathtracer`). Typechecking and builds pass; the
  forced native attempt fails at Metal device acquisition. Convergence bounds
  need native validation and no historical numerical result is reproduced here.
- Restored, native verification pending 2026-10-11: `test_parity` now renders
  all four built-in Worlds through both renderers, using the same RDK probe
  geometry and the existing `rdk_rays` bridge. Every matte/glossy probe checks
  positive mean luminance and compares that mean and its highlight centroid;
  the test also checks 1,024 accumulated samples, exact readback lengths and
  handle teardown. The newly explicit bounds (20% mean error, 8-pixel centroid
  distance) are provisional native qualification bounds, not recovered
  historical results. Typechecking, executable builds and the dependency
  gate pass. The forced native attempt fails at Metal device acquisition;
  raster/pathtracer agreement is unverified here.
- Restored 2026-10-11: `test_ui_pipeline` previously created and destroyed
  a native execution, then printed "matches Scene2" without drawing. It now
  captures the UI batch and independently constructed Scene2 geometry at 1x
  and 2x, verifies nonempty pixels and exact image lengths, and compares every
  channel except the original rectangle-corner allowance. Submissions are
  canceled on failure as well as consumed on success. The executable builds;
  this runner takes the existing no-Metal skip, so native parity is unverified.
- Fixed and verified 2026-10-11: `test_scene3_float32.run` formerly only
  printed a success message. It now checks the split float32 ABI, exact
  position/normal/index/color/UV words, geometry reuse across recoloring,
  attribute invalidation, repeated staging, fixed clears at all four sample
  counts and rejection of finite f64 values that overflow f32.
  `@lib/rays/runtest` passes. The existing independent f64 pixel comparison,
  recoloring upload check and coalescing comparison are now registered as
  `@lib/rays/test_scene3_float32_native`; its actual attempt fails because
  Metal has no system default device. No native pixel result is claimed.
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
  coverage, and native scene-execution tests remain unverified.
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
  pixel golden case still fails with no Metal device, so the full PXUI alias
  is not green here. The 200-node editor benchmark allocates about 92 KB less
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
  has a separate reviewed API promotion. Native pixels remain unverified.
- Fields that are constant but still threaded: the path tracer `scale`.
  Tracing confirms `dispatch_size` always returns scale 1, but removal still
  needs the native performance and pixel checks. This runner has neither a
  Metal device nor the optional Metal compiler toolchain: an actual
  `xcrun -sdk macosx metal -c lib/rays_pathtracer/pathtrace.metal` attempt
  fails with "cannot execute tool 'metal' due to missing Metal Toolchain".
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
- No kind that builds a polygon from explicit points (`poly_fill` returns a closed curve
  unchanged); the gallery star uses `sop/sweep :caps true` instead.
- Fixed and verified 2026-10-11: `Lisp_sop.node ~with_` accepts
  `"image/pixels", node` as an image-typed `(image/ext_pixels)` binding, using
  the existing immutable operator-extension API and normal checked lowering.
  The image node and its inputs retain their identity and are not cooked
  during lowering. `test_attr_from_image` now uses the Lisp surface for its
  channel/UV/domain cases; `@lib/sop/runtest` and `@lib/flow_sop/runtest` pass.
- What `chromatic_drift`, `pastel_flow` and `code_quadtree` need before a port is listed in
  `README.md`, "Not yet ported to Rays Lisp".

## Docs

- The proposal artifact has not been updated with the outcome. No path or
  link identifies it, and the 2026-10-11 local and connected Pages searches
  did not locate the lean-restructure proposal. The accessible Rays Page
  concerns the browser-compilation paper. Its content was left unchanged;
  the requested artifact's location is pending user clarification.
