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

- Many `rdk`, `sop` and `scene_execution` tests were cut statement by statement when their
  subject was pruned. The survivors pass, but nobody has read what each one still covers.
  `test_scene_execution_metal`, `test_automatic_scratch` and `test_offscreen_metal` were cut
  twice.
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
  field instances (three non-finite cases each). Lisp's reader remains finite-only.
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
- Fields that are constant but still threaded: `Paint.scale/tx/ty` and the `Ui_batch`
  transform in `pxui`, `Scene3.depth_clear` and `stencil_clear`, the `Easy_camera` binding
  `key`, `Light.attenuation.linear`, the path tracer `scale`.
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

- No literal for a non-finite number.
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
