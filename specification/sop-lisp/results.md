# SOP Lisp implementation evidence

Started 2026-10-12 against checkout `79b52a0516acdce15ce2227926e9e5db22510d95`.
The approved [plan](plan.md) remains the scope: 128 target nodes, 31 retained
OCaml nodes and 3 wiring nodes. No port, performance result or phase review is
claimed by this initial census.

The intended public API snapshot was accepted separately in commit `9cea2e6b`
(`Accept Lisp SOP declaration and packed column APIs`), after promotion session
78317 and the API/catalog/dependency gate exited 0. That commit changes only
`tools/api_manifest/api_stable.json`; the implementation and pilot remain
separate changes, as required by the plan.
The Phase A integration was committed as `74efb1ee` before the production
pilot switch. It includes the source/checker/cache/editor integration and its
navigation/vocabulary tests; the actual pilot save fixture belongs to the
pilot commit.
The scoped phase-timing API snapshot was accepted separately as `e5ea583c`
(`Accept scoped phase timing API`). Its implementation retains exactly one
workspace evaluation/lowering invocation while attributing internal compilation
duration to that phase; the test also checks restoration after an exception.
The complete production pilot and Phase A review were committed as `32d64042`.
Final shipping session 83244 and native session 33890 both exited 0.
The typed attribute, integer, Text and random foundation was committed as
`5f27f258` after its shipping, native and web gates passed.

## Task evidence

The initial B.11 declaration census added B.4 owner counts as a prerequisite:
constant setters must create missing point, vertex, primitive and detail
attributes without reading a nonexistent attribute to discover its count.
Set Transform requires genuine 16-value CSR rows, including empty geometry;
Set Color additionally waits for B.5 group selection. Drafts retain all modes
and metadata; no setter registration has changed. Set Orient's extreme finite
components also expose a numeric boundary: native sum-of-squares overflow
normalizes to zero, while strict compiled arithmetic refuses the intermediate
infinity. That case remains a whole-port gate before registration changes.

B.6 reuses the existing metadata module and exact RDK rename/delete/swap
operations, preserving owner selection, conflict policy, ordered groups,
canonical P and exact edge-name error behavior. The shared table codec is now
`Param.String_table`, with the original native helpers retained as aliases.
Codec and metadata compilation checks passed (session 24395); this is
preparation evidence, not a completed metadata or setter port.

The initial B.12 boundary audit required Lisp-authored encoded parameter normalization. Native
`Param.Encoded` fields decode edits and re-encode their normalized values for
the schema view and cook key. A plain Text defnode field with a body decoder
does not preserve that boundary: equivalent owner/conflict tokens retain
different keys and malformed edits fail later. The generic declaration needs
validation and canonicalization at the parameter boundary before these whole
ports could ship; B.12 remained unchecked at that checkpoint. Its later whole
ports and completed encoded boundary are recorded below.

| Task | Current evidence | Remaining gate |
| --- | --- | --- |
| A.0 | The plan records all six decision baselines, using the explicitly decided answers and the other approved recommendations. | Complete: answers recorded. |
| A.1 | `opam exec -- _build/default/tools/check.exe @lib/rdk/test_support/runtest @test/lisp_sop/runtest` exited 0 (helper agent session 95253). `test_geometry_comparison.ml` checks equality at 0 ULP, one ULP at tolerance 1, rejection at 0, two ULP rejection at 1, and changed integer storage rejection at 4. | Complete: helper gates passed. |
| A.2 | The census checks all 128 target keys. `test_defnode.ml` covers typed/image/function/optional/rest slots, every supported metadata key, vector grouping, refusal shapes, recursion and an OCaml kind-name clash. `_build/default/tools/check.exe @lib/flow/runtest @lib/sop_catalog/runtest @test/dependency_gate` exited 0 after the final checker changes (session 29492); prior checker sessions 87642 and 6143 also passed. | Complete: reader/checker gates passed. |
| A.3 | Lowering keeps one public cache identity with zero retained internal entries; derives specialized facts; tests all Param edits with exactly one miss, nested/optional/rest nodes, physical Image/Fn slots and cooked captures, strict unsupported refusal without interpreter fallback, and reference/domain/grain exactness. `@lib/flow_sop/runtest @lib/flow_ir/runtest` passed (helper sessions 9823, 3589 and 55571). The last run covers strict typed-Fn lowering and geometry-zone element uniforms after forwarding `elems` to the packed executor. Attribute packing ownership/nonfinite/domain regressions passed (root session 92124). Injected-body cache identity passed (session 91419). Borrowed-plane host tests passed in `@lib/flow_sop/runtest` (root session 37000): 0/1/32769 elements, signed zero, one/eight domains, physically shared exact P planes, independently owned Cd planes, short-zip `E_ATTR_COUNT`, and immutable original bytes. Accepted optional/rest Fn slots and scoped helper context dependencies were repaired; refreshed `@lib/flow_sop/runtest @lib/flow/runtest @lib/flow_ir/runtest` exited 0 (session 93829), followed by root integration gate 80542. | Complete: focused lowering, cache, typed-slot and exactness gates passed. |
| A.4 | Shared `tools/lisp/embed.exe` embeds the source directory; the catalog injects definitions with disjoint IDs and the manifest records Lisp bodies and checked calls. Focused lowering/dependency tests passed (session 61578); focused dummy-driver editor tests passed (session 97387). Reviewed promoted metadata-only manifest diff: descriptions and non-Cook impact, digest `e3e6c69a267f17ee74791ce4f4adc112`. `@lib/sop_catalog/runtest @test/dependency_gate` exited 0 (sessions 95723, 14766); combined checker/catalog/dependency gate passed (session 29492). Source/edit/body-cache and keyword manifest regressions passed (session 91419). After the production switch, dummy-driver `@test/test_workspace_source @test/test_workspace_shell @test/test_sop_catalog @test/dependency_gate` exited 0 (session 21186): scalar scrub, structural gesture, atomic save and reopen retain the embedded definition while saving only authored calls. | Complete: focused integration and production source-boundary gates passed. |
| A.5 | `test_lisp_projection.ml` compares the Lisp and independent OCaml cards structurally, full inspector metadata, scalar/vector scrubs, parameter drives, bypass, nested cards and schema-change invalidation. Combined lowering/graph/editor gate exited 0 (session 89094); actual editor fallback-inspector editing and menu search/add passed (session 92998). Dummy-driver `@test/test_workspace_vocabulary @test/test_workspace_shell @test/test_sop_catalog @test/dependency_gate` exited 0 (session 16558), proving helper navigation filtering, completion refresh after declaration addition/removal, schema changes, reload and reducer undo/redo, actual menu interaction, and the combined factory registry. The production source/editor/catalog/dependency refresh exited 0 (session 21186). | Complete: focused card/menu/vocabulary/navigation and production source/editor gates passed. |
| A.6 | The complete pilot implements both noise modes and explicit/context seed selection. Its context-seed and attribute-delete prerequisites have moved forward from later work. Whole-mode geometry/domain/grain/cache/schema checks passed (checker agent session 60089). Real-parallel 32,769-point fixtures cover both modes at 1/4/8 domains and grains 97/4096, with 4-ULP oracle and byte-exact strict-reference comparisons after clearing the session (session 48781). The quiet one-million-point timing gate passed (session 59246, measurements below). Production now embeds `noise_displace.rays` and removes its native catalog registration while retaining `Sop.Nodes` as the oracle. The reviewed promoted manifest has digest `ef85cfb9f1560f4b8d7456cbcf6af521`; labels/defaults remain unchanged and the entry records a Lisp body. Production pilot/catalog/checker gates exited 0 (checker agent sessions 68500 and 99460); actual source-save/editor/catalog/dependency refresh passed (session 21186). Final pilot and legacy node gates passed after repairing the native factory's default cook-label protocol (session 45407), including relabel/cache/parameter-rebuild checks with ASCII and UTF-8 labels at context seeds 42 and 999. | Complete: full Verification and final shipping/native gates passed; committed with the production port. |
| A.R | `specification/sop.md` and `lib/sop_catalog/AGENTS.md` now describe the Lisp declaration alternative and runtime ownership. `specification/flow.md` describes `defnode`. Root focused `@API @test/dependency_gate @lib/flow/runtest @lib/flow_sop/runtest @test/test_rays_editor @test/test_workspace_start @runtest-native` exited 0 (session 36479), including actual native rendering/pathtracer gates. Native reruns 41613 and 34796 passed; the latter covers 23 SOP graphs with exact one/four-domain PNG comparisons. Render goldens remain unchanged. `opam exec -- _build/default/tools/check.exe @lib/flow_sop/runtest @lib/sop/test_nodes` exited 0 (session 86865), covering selective attribute/deletion facts and the combined native/Lisp factory census. Shipping runs 15355/25500 exposed narrow catalog injection and the generated-source digest expectation; fixes are recorded below. | Complete: final `check.exe --ship` (session 83244) and `@runtest-native` (session 33890) exited 0; committed with the production port. |
| B–E | Fourteen whole-node ports are complete: the pilot, all six B.11 setters and all seven B.12 metadata nodes. Their individual oracle, performance and production evidence is retained below. | The other 114 whole ports, remaining language capabilities and phase review gates remain required. |
| B.1 | Owner-aware Float/Vec2/Vec3/Vec4/Int/Text/CSR attributes, literal-selected result types and a cooked Boolean `sop/has_attr` predicate are implemented. Focused `@lib/flow_sop/runtest @tools/lisp/runtest` exited 0 (session 98738): all-owner strict/reference Text round trips, exact UTF-8/empty strings, copied read/write ownership, count/type errors, a strict 4,097-element authored text map, empty geometry/detail counts, exact one/eight-domain bytes, graph type edits through Text, numeric multi-block fixtures, distinct owner/CSR count origins and strict compiled lazy query guards pass. Native-to-JavaScript census including Text attributes passes 15,152 cases across 79 contracts. Shared structured Core resolves genuine host sources without interpreter fallback. No new port is claimed. | Complete: focused, shipping, native and web foundation gates passed; final commands and coverage below. |
| B.2 | The expanded native-to-JavaScript primitive census passes 15,029 cases across 78 contracts: all ten exact integer operations, five comparisons, typed integer construction/range/build/count/get/slice/concat/sum and the existing floating/host contracts. Signed bounds, values above 2^53, wrapping sums beyond 4,096 elements, invalid shifts, selectors and element types retain exact integer/error checks. The census exposed and repaired shared native range-selector and JavaScript integer builder/error boundaries. | Complete: focused, shipping, native and web foundation gates passed; final commands and coverage below. |
| B.4 | `test_topology_kernel` compares all four counts and canonical edge endpoints with native `Topology_index` on empty, shared polygon, repeated open curve, closed curve and mixed nonmanifold fixtures. Owned queries, exact integer writes beyond 2^53, cache refresh/invalidation and graph keyword gestures pass. Focused gate 63052 exited 0; combined language gate 42787 also passed. | Complete: stated focused language gate; final Phase B review remains pending. |
| B.5 | `test_group_kernel` covers all four owners, 0/1 masks, names/pattern escapes, ordered-empty versus unordered groups, invalid order/membership and unsupported ordered edges, immutable ownership, cache and actual live-frame sources. Focused gate 85800 and live state-fold check 68513 passed; combined language gate 42787 passed. | Complete: stated focused language gate; no group-node port is claimed. |
| B.6 | `test_metadata_kernel` covers all attribute owners and eight storages, canonical P, rename/delete/copy/move/swap conflicts and atomicity, ordered group union, missing edge names, unused groups, strict compiled queries and graph gestures. Native/JavaScript host census passes 16,598 cases across 105 exports. Focused `@lib/flow_sop/runtest @tools/lisp/test/runtest` gate 13786 exited 0, including one/eight domains and grains 97/4096. | Complete: stated language gate; the later B.12 encoded boundary and all seven whole-node ports are also complete. |
| B.7 | Exact scalar math/rounding and matrix/quaternion helper fixtures pass. Explicit native-order FMA fixes cross/matrix cancellation: native compound audit is 0/1,863 above four ULP; 5,001 rows match exact native/reference/strict CPU/JavaScript bytes at one/four/eight domains. The prior 15 unfused discrepancies remain recorded and ordinary arithmetic stays unfused. | Complete: final focused compiler/Web/GPU/catalog/CLI/API/dependency gate 54530 exited 0; unsupported exact binary64 FMA retains typed GPU refusal. |
| B.9 | `test_reductions` checks exact wrapping Int sums, Float/tuple extrema including signed zeros, ordered CSR sums, zero rows and malformed offsets, and 32,769 rows at one/eight domains without input mutation. Computed scalar/array/record/function captures use compiled Core region arguments; unresolved web region arguments select structured Core compilation. Focused gates 27645 and 42787 passed. | Complete: stated focused language gate; no dependent whole-node port is claimed. |
| B.11 | All six setters are embedded Lisp declarations with native factories retained as test oracles. Final Set Color passes the whole production oracle, metadata/cache/editor/refusal checks, raw Cd byte checks and all 78 fixed performance rows (maximum 1.7896493105836428×). | Complete: final production/native integration 8526 exited 0; evidence below. |
| B.12 | All seven metadata nodes are embedded Lisp declarations. Encoded normalization and canonical keys, every owner/storage/mode, exact errors, public cache identity and graph/editor gates passed. Swap is the final whole metadata port; all 212 fixed timing rows pass under the recorded precision protocols. | Complete: final production/native integration 90589 exited 0; individual evidence below. |
| C.15 | Full native Measure wrapper and kernel audit establishes topology/indexed position access and canonical n-gon triangulation with original-primitive mapping as prerequisites. The whole node moves from B.15 to C.15; no mode, registration or target is removed. | B.1/B.5/B.7/B.9/C.1/C.2 and a generic canonical triangulation + primitive mapping capability, then the complete port Verification gate. No implementation or completion claimed. |
| G.1–G.2 | Optional tasks; no placement evidence recorded here yet. | Measured placement and CPU/GPU tolerance checks. |

The typed integer/text/source Core API snapshot was accepted separately in
commit `621113d2` after API/dependency gate 37921 exited 0. Foundation
implementation has passed the final focused compiler, shipping, native and web
gates. At that foundation checkpoint B.1/B.2/B.3/B.8 were complete; B.7
remained unchecked until the later native-order helper correction below.

Final foundation shipping gate 39576 (`check.exe --ship`, log
`/tmp/rays-sop-lisp-phase-b-foundation-ship-2.log`) exited 0: all builds, tests,
smoke runs and diff checks passed, including 43 standard workspaces, one custom
catalog executable and 13 fixtures at four times and one/eight domains. Native
gate 59873 (`@runtest-native`, log
`/tmp/rays-sop-lisp-phase-b-native-final-2.log`) exited 0, including 23 SOP
graphs with byte-identical one/four-domain PNGs. Web qualification 47917 also
exited 0. No render PNG or path tracer digest was refreshed.

The final quiet pilot benchmark 24502 exited 0 after the shared compiler
changes. Machine, command, million-point size, grain 4096 and median-of-three
method match the pilot evidence below; four-domain allocations measure only
the main domain. All complete modes remain below the 2× cook-time ceiling.

| Mode | Domains | OCaml seconds | Lisp seconds | Lisp / OCaml | OCaml allocated bytes | Lisp allocated bytes |
| --- | --- | --- | --- | --- | --- | --- |
| Normal 3D | 1 | 0.032055 | 0.037070 | 1.156 | 24,107,808 | 25,768,256 |
| Normal 3D | 4 | 0.010761 | 0.010586 | 0.984 | 24,135,832 | 24,447,192 |
| Default height 2D | 1 | 0.015357 | 0.022616 | 1.473 | 8,078,088 | 9,749,856 |
| Default height 2D | 4 | 0.004686 | 0.006259 | 1.336 | 8,117,944 | 8,414,360 |

Benchmark log: `/tmp/rays-sop-lisp-phase-b-pilot-bench-final-quiet.log`.

Final focused gates 92981 (`@lib/flow_ir/runtest @lib/flow_sop/runtest
@lib/flow_web/runtest`) and 6927 (`@lib/flow_ir/runtest @lib/flow_web/runtest
@lib/flow/runtest @lib/flow_graph/runtest`) exited 0. Text maps and collecting
loops preserve 5,001/5,002 exact UTF-8 values, including multiple clauses,
skips and empty results, at one/eight domains and in emitted JavaScript.
Dependent inner Text collections retain their explicit strict Core refusal.
Strict Executor qualification now applies the existing recursive producer and
uniform check to every region inside structured Core; an accepted outer
reduction cannot hide an unsupported numeric producer inside a Text map.

The first broad runs exposed a placement error in a 13-element tick map inside
`million_marks`: declining CPU placement was reported as `E_CORE_REGION` after
starting the structured program. Core placement now declines before executing
any statement, while state remains untouched. The new recorded-call record
regression passes ordinary and strict execution at one/eight domains (14242).
The actual workspace passes 141 values at four times and one/eight domains
(34715). Temporary diagnostic storage was removed; a file filter remains for
focused workspace checks. The compiler snapshot loses the standalone nested
map that this earlier placement decline no longer compiles; no render golden
changed.

B.1's Text extension passes focused gate 98738 and host twins (15,152 cases,
79 contracts). Text arrays preserve exact decoded contents and immutable
ownership for point/vertex/primitive/detail, including empty owners and one
detail row. The all-owner strict/reference comparisons and 4,097-element
authored transformation use genuine typed arrays and compiled structured
Core; no numeric-kernel or interpreter fallback is claimed. Before any
production text-array port ships, its execution exception must be derived and
reviewed in the manifest, as the plan requires. There is no production Text
port yet, so this foundation does not alter that manifest.

The production source/editor gate was repeated after fixing shared completion
and catalog-order integration: dummy-driver `@test/test_workspace_source
@test/test_workspace_shell @test/test_text_pane @test/test_workspace_doc
@test/test_sop_catalog @test/dependency_gate` exited 0 (session 36116).
The exact existing completion and manifest assertions remain intact. Full-edit
reference checks now load embedded definitions through the same catalog checker
as the document; the full-versus-literal corpus still compares authored bytes,
plans, refusals and 43 checked-in documents' window settings.

## A.2 parameter census

The target keys were read from the plan's B–E inventory, including its A.6
pilot, rather than assuming every `sop/` manifest kind is a target. There are
128 distinct keys, and every key has a current manifest entry and source
declaration. The manifest snapshot is version `202609`, digest
`0535593a6c5ed90781b183492dcd22d7`.

A.4 now extends the manifest writer and reader to retain descriptions and
non-default parameter impact. The omission counts below describe the original
snapshot audited above; they are not a claim that the extended writer still
loses that metadata. The final promoted digest is recorded with A.4's gate.

The census used the existing `Flow.Syntax.parse` reader from the built Flow
library and OCaml `Str` for the plan/source annotations. The exact field names,
defaults, ranges, choice order, folder paths and vector-component indices remain
in [`flow_manifest.sexp`](../../lib/sop_catalog/flow_manifest.sexp). The source
records in [`shapes.ml`](../../lib/sop/shapes.ml),
[`attributes.ml`](../../lib/sop/attributes.ml),
[`groups.ml`](../../lib/sop/groups.ml) and
[`sop_topology.ml`](../../lib/sop/sop_topology.ml) provide validation and metadata
that the snapshot omits. `sweep_circle` deliberately shares the Polywire record
and schema (`Polywire.sweep_factory`); its manifest entry was counted separately.

| Requirement | Observed across the 128 target declarations |
| --- | ---: |
| Total scalar fields | 1,434 |
| Bool / int / float / text / choice fields | 191 / 95 / 532 / 384 / 232 |
| Numeric fields with at least one hard bound | 200 |
| Fields with a nonempty folder path | 834 |
| Primary fields | 37 |
| Fields with units | 3 |
| Vec3 presentation groups | 95 |
| Required / optional / rest / optional-rest slots | 124 / 19 / 1 / 2 |
| Source fields with descriptions omitted by the manifest | 8 |
| Encoded parameter fields exposed as text by the manifest | 12 |
| Nodes with a record-level `sop.validate` clause | 81 |

### Contract gaps the form must cover

1. The five manifest scalar kinds are sufficient for the present target field
   values, but the header must preserve soft and hard bounds separately, choice
   labels and order, description, folder, primary, unit and vec3 group/component
   metadata. `Param.field` also carries impact. All target fields have the
   default `Cook` impact; the explicit `View` fields belong to excluded
   `exploded_view`. Preserve the model's impact capability when defining the form.
2. The original snapshot omitted descriptions and impact. A.4 now preserves
   those through [`Manifest.field`](../../lib/flow_sop/manifest.ml) and
   [`Check.catalog_of_manifest`](../../lib/flow/check.ml). The promoted digest is
   recorded above; the eight target descriptions now survive the round trip.
3. `Param.Encoded` appears as plain `text` in `Param.view` and the manifest. Its
   deterministic encoder, decoder and validation remain source behavior.
   Twelve target fields depend on these: rename/swap attribute rules; group
   delete/rename/copy/promotions/ranges rules; group-combine steps; ordered-group
   indices; and three boundary-attribute rule fields. Their malformed-input
   refusals require Lisp validation/decoding, not merely a text parameter.
4. Ramp parameters are text recipes today, not a missing `Param.Ramp` kind:
   `attribute_remap.ramp`, `spiral.height_ramp` and `spiral.radius_ramp` have
   documented knot encodings and source validators. Preserving the header is
   separate from implementing knot evaluation in each Lisp body.
5. The 81 record-level validators cover coupled values, encoded recipes and
   special names; scalar bounds cannot replace them. The form needs checked
   validation clauses with the same construction-time refusal behavior.
6. Slot declarations need required, optional, rest and optional-rest forms,
   preserving slot positions and names. Most slots are geometry; `attr_from_image`
   also accepts an image and `iso_surface` accepts keyword `field` typed
   `fn(vec3)->float`. The Phase A form now accepts `:keyword true` on required
   non-rest function/image slots. It retains physical slot order separately
   from visible positional rows, and the manifest round trip covers both
   keyword types. The refreshed combined lowering/graph gate passed in session
   91419; later ports must retain each native call shape.
7. `set_transform` writes 16-float array-valued attributes, and
   `attribute_interpolate` handles array-valued attributes. B.1's proposed scalar
   attribute list does not express this storage. The authorized B.1 extension
   exposes `float_array`/`int_array` as records of integer CSR `offsets` and
   typed flattened `values`; 16-float transform rows use the same representation.
   Owner arrays, offsets and flattened values have distinct count origins.
   Text remains gated on B.3; no storage mode or node is dropped.
8. The inventory already calls out `Float.next_after` for `separate_pieces` and
   explicit `Float.fma` for `iso_surface`; neither is in B.8's proposed math
   list. Resolve these prerequisites before those ports and retain their oracles.
9. `Transform` and `Match_axis` preserve missing or non-Float3 normals. Strict
   typed reads cannot express that fallback alone; B.1 advances a genuine
   cooked `sop/has_attr` Boolean predicate with optional storage matching and
   lazy branches. It must report truthful attribute reads, including owner.
10. Matrix/quaternion recipes need native `hypot` behavior, and normal work must
    preserve vertex-owned normals. `uv_project` requires topology and indexed
    gather from C.1/C.2 plus segmented seam/pole reductions (language additions
    B1/B8/B11+C1/C2). Its whole port moves from B.15 to C.14. `match_axis` also advances
    its B1 typed vertex-N/query prerequisite. No mode is partially substituted.
11. The whole `measure` port moves from B.15 to C.15 after reading all three
    native modes and the SOP wrapper (`lib/sop/attributes.ml:236-290`,
    `lib/rdk/core/analysis.ml:75-239`, `487-519`). Perimeter follows each
    primitive's ordered vertex-to-point indices; area and signed volume use
    canonical ear clipping for n-gons. Signed volume anchors on the bounds of
    all points, including free and unselected points. Selection, both
    accumulations, existing values outside the selection, optional detail
    totals and native curve/degeneracy errors remain required. C.15 depends on
    B.1/B.5/B.7/B.9/C.1/C.2 plus generic canonical triangulation data with
    original-primitive mapping. The shared RDK ear clipper fixes projection,
    tolerances and emission order; a fan or an unverified `sop/triangulate`
    substitution is insufficient because its collapsed-quad shortcut differs
    (`lib/rdk/mesh/triangulate.ml:27-63`, `175-190`). A hidden measure callback
    would not provide the required language capability.

A pure OCaml inventory/task census accounts for all 128 target keys exactly
once, with no missing assignments or aliases: A.6 pilot 1, Phase B port tasks
42, Phase C 42, Phase D 31 and Phase E 12. The inventory counts include the
pilot under Phase B, giving B 43/C 42/D 31/E 12. C.15 remains unchecked and C.R
now includes it; both whole-node moves retain the original target count.

B.1's native-to-JavaScript host fixture check exited 0 after building
`tools/core_fixtures.exe` through the shared launcher: the generator followed
by `node tools/web/test/prims.mjs FIXTURES tools/web/runtime/prims.js` checked
10,780 cases across 66 primitive contracts. This includes owner-aware numeric,
integer and CSR reads/writes, exact BigInt payloads, count failures, strict
missing/type errors and presence predicates. Compiled lazy query guards now
pass separately in the full numeric attribute executable (session 79843).

The expanded integer census adds exact add/sub/or/shifts/comparisons and
integer build/range/count/get/slice/concat/sum, including values above 2^53,
signed bounds, wrapping prefixes and more than 4,096 elements. Its initial
nine runtime-boundary failures were repaired in shared native/JavaScript
functions. After focused build 22740, regenerating fixtures and running the
native-to-JavaScript twin command exited 0: **15,029 cases, 78 contracts**.
Error comparisons and exact integer checks remain unchanged. The combined
22740 alias request still failed two independent compiler/export regressions:
a 32,769-element floating sum sign mismatch in `test_uniforms`, and the
existing `flow_contours` web export refusing integer sources with `E_GPU_FORM`.
Its full B.1 numeric, random/noise and other SOP tests passed; no failed
expectation was promoted.

Focused browser repair passed build 90444 and real Chrome run 29357 for
`examples/generative` (frame 5→35, ten marks) and `examples/noise` (frame 7→37,
two marks), with no frame or presenter errors. Export metadata now derives
integer storage from consuming uniform banks and requires scalar width for
integer outputs. Region inputs/captures must pass the existing evaluator's
frame-dependency proof before becoming fixed export data; frame-dependent
sources retain compiled structured loops. This repairs noise's frozen
3,120-element position table against its real 3,600-element color table.
The shared JavaScript loop store preserves integer array elements, and the
presenter's numeric GPU boundary converts integer values explicitly. Runtime
Node tests pass. Earlier `flow_contours` image export refused integer
instructions in gate 38010; explicit floating pixel alpha and dimensions
resolved that refusal. Broad web run 45015 then exposed the native oracle's
dimension decoder silently substituting 256 for exact Float dimensions.
The decoder now accepts finite integral Float arguments, keeps defaults for
absent keys and rejects malformed values. Focused build 53253 and the existing
contour pixel harness (session 53682) exited 0: at 640×480/frame 3 and
800×600/frame 7, zero pixels differ by more than eight channel units, worst
channel difference one, mean 0.0002; dispatch counts remain 18/42 with zero
CPU invokes. No render golden or comparison threshold changed. Final
`opam exec -- _build/default/tools/check.exe @tools/qualification-web`
(session 47917, `/tmp/rays-sop-lisp-phase-b-web-final-2.log`) exited 0.
It covers GPU kernels/status and hidden overflow, actual exported browser
sketches, native pixel parity, generated/loaded/live/nested images, shared
state, render regions and watch reload/repair behavior.

Native image qualification's former overflow fixture selected a finite zero
and expected failure from its untaken branch. With lazy guarded execution,
that image must render successfully. The test now verifies its CPU/GPU render
parity and selects the overflow in a separate fixture, retaining both repeated
`E_KERNEL` assertions, recovery, resource ownership and exact domain checks.
Focused executable build 20046 and native run 23312 exited 0; all logged
resident image/canvas channel differences were zero. No error assertion or
render threshold was relaxed.

At B.7's partial math gate 71202, the compiler's exact unfused oracle passed.
The independent native 4-ULP audit failed 15 of 1,863 cases: fourteen
cross-product cancellations near zero and one matrix product at 16 ULP.
B.7 remained unchecked at that gate; the original failures are retained below.

An isolated JavaScript BigInt FMA prototype matches native `Float.fma` bits
for 10,011 cases. Explicit FMA therefore has a viable web implementation;
this does not authorize automatic Mul/Add contraction or change the current
unfused arithmetic policy. That prototype alone did not resolve the native gate.

The explicit `(fma a b c)` operator is now implemented in reference evaluation,
structured Core, strict packed CPU execution and JavaScript regions/primitives.
Focused gates 87456, 31523 and 65940 passed. The dedicated
`lib/flow_web/test_fma.ml` checks 10,010 finite triples across the full signed
exponent range against native `Float.fma` bits, including cancellation, signed
zero, subnormals, ties and finite overflow cancellation. Reference and CPU at
one/eight domains, emitted JavaScript and scalar primitives agree exactly.
Mixed integer captures and frame inputs, selected/unselected overflow, invalid
non-finite inputs and the exact binary64 GPU refusal are also checked. Ordinary
Mul/Add remain separate operations. This primitive gate alone did not complete
the native-order cross/matrix helpers or B.7.

The subsequent B.7 helper correction uses explicit FMA only at native sites
verified in Apple M1 / OCaml 5.3.0 object disassembly. Native Vec3 cross rounds
the first product before FMSUB subtracts the second product; native Mat4
multiplication performs four FMADD updates from positive zero. The scalar
`cross` operator, structured Core, strict regions and the two corresponding
prelude helpers now preserve those associations. Ordinary multiplication,
addition, dot and the other helpers keep their existing contracts.

Request 89458 passes the native compound audit with 0/1,863 components above
four ULP (maximum 1 ULP). The independent prior unfused oracle still records
all 15 discrepancies. Cross and matrix multiplication match native bits;
5,001-element strict reference/Core/packed/JavaScript proofs cover signed
zero, cancellation and tiny inputs at one/four/eight domains, plus overflow
refusal. The existing exact scalar math and rounding checks remain green.
Flow/Web/tools gate 50769 and corrected GPU gate 23690 passed. Exact binary64
FMA makes Cross a typed GPU refusal; existing shader and rendered goldens
remain unchanged. There is no automatic Mul/Add contraction or API change.
Final request 54530 exited 0 for `@lib/flow/runtest @lib/flow_ir/runtest
@lib/flow_sop/runtest @lib/flow_web/runtest @lib/flow_gpu/runtest
@lib/sop_catalog/runtest @tools/lisp/test/runtest @tools/api_manifest/runtest
@test/dependency_gate`. The preceding request 44967 failed only on the
concurrent, reviewed Transform catalog/CLI expectations; accepting those
node-owned expectations made the aggregate green. No arithmetic tolerance or
render baseline was relaxed. B.7's stated language gate is complete.

The focused `@lib/flow_sop/runtest` gate 2800 exited 0, including B.1's numeric
attribute regressions and B.8's random/noise foundations. B.8 checks 100,000
random integer keys (signed boundaries and values above 2^53), native/reference/
strict packed one/eight domains and emitted JavaScript with exact float bits;
typed prepared inputs use BigInt64Array. Its 300,054 noise samples cover seeds
0/1/42 and octaves 1/4/32, including 100,000 per octave at seed 42, with zero
native bit differences (maximum 0 ULP) and exact packed one/eight-domain bytes.
Invalid octaves 0/33 produce `E_NOISE_RANGE`. This does not resolve B.7's
independent native math failures or complete the B.1/B.3 foundation review.

The generic guarded floating executor's focused regressions pass at one/eight
domains, including lazy overflow, scaled-noise guard scopes, borrowed strided
columns and omitted output lanes. On Apple M1 / OCaml 5.3.0, one million scalar
elements with 21 registers and nested alternating guards, median of three
after one warm run, changed from 0.761815 s / 1,648,012,168 bytes to 0.153040 s /
43,751,592 bytes at one domain (4.98× faster), and from 0.413755 s /
1,648,012,168 bytes to 0.042226 s / 22,988,136 bytes at four domains (9.80×).
Allocation figures measure the main domain only. Command:
`opam exec -- _build/default/lib/flow_ir/test_packed.exe --bench-guarded`;
logs `/tmp/rays-sop-lisp-guard-before.log` and
`/tmp/rays-sop-lisp-guard-after-2.log`. Combined gate 68199 still failed newly
added text-array cases; these timings do not complete that gate.

The per-node table uses `b/i/f/t/c` for bool/int/float/text/choice field counts.
Vec3 groups count presentation groups, not additional fields. Slot types default
to geometry when omitted. A record validation entry does not include errors
inside the kernel or an encoded decoder; those remain part of each port audit.

The manifest part of the census can be rerun from the repository root with the
following OCaml script after building `lib/flow/flow.cma`. It fails if a target
key disappears or the inventory no longer contains exactly 128 unique targets.

```sh
ocaml -I +str \
  -I _build/default/lib/param/.param.objs/byte \
  -I _build/default/lib/frame_input/.frame_input.objs/byte \
  -I _build/default/lib/flow/.flow.objs/byte \
  str.cma _build/default/lib/param/param.cma \
  _build/default/lib/frame_input/frame_input.cma \
  _build/default/lib/flow/flow.cma -stdin <<'OCAML'
open Flow;;
let read path = let ch = open_in path in
  let s = really_input_string ch (in_channel_length ch) in close_in ch; s;;
let prop name xs = List.find (fun x -> Syntax.head x = Some name) xs
  |> Syntax.children |> List.tl;;
let atom x = match x.Syntax.node with Syntax.Str s -> s | _ -> assert false;;
let plan = read "specification/sop-lisp/plan.md";;
let first = Str.search_forward (Str.regexp_string "| `noise_displace` |") plan 0;;
let last = Str.search_forward (Str.regexp_string "### Stays OCaml") plan first;;
let inventory = String.sub plan first (last - first);;
let quoted s = let re = Str.regexp {|`\([^`]+\)`|} in
  let rec loop at acc = try ignore (Str.search_forward re s at);
    let key = Str.matched_group 1 s in loop (Str.match_end ()) (key :: acc)
    with Not_found -> List.rev acc in loop 0 [];;
let targets = String.split_on_char '\n' inventory
  |> List.filter (String.starts_with ~prefix:"| `")
  |> List.concat_map (fun row -> quoted (List.nth (String.split_on_char '|' row) 1));;
let () = assert (List.length targets = 128);
  assert (List.length (List.sort_uniq String.compare targets) = 128);;
let manifest = match Syntax.parse (read "lib/sop_catalog/flow_manifest.sexp") with
  Ok [x] -> x | _ -> failwith "manifest parse";;
let kinds = prop "kinds" (Syntax.children manifest);;
let fields = List.concat_map (fun key ->
  let kind = List.find (fun x -> atom (List.hd (prop "key" (Syntax.children x))) = key) kinds in
  prop "fields" (Syntax.children kind)) targets;;
let () = List.iter (fun name ->
  let count = List.filter (fun field ->
    Syntax.head (List.nth (Syntax.children field) 4) = Some name) fields |> List.length in
  Printf.printf "%s %d\n" name count) ["bool"; "int"; "float"; "text"; "choice"];;
OCAML
```

### All target declarations

| Node | Fields b/i/f/t/c | Vec3 groups | Slots | Description fields | Encoded kinds | Record validation |
| --- | --- | ---: | --- | ---: | --- | --- |
| `noise_displace` | 1/1/2/0/1 | 0 | in0:required | 0 | — | — |
| `match_axis` | 0/0/6/0/0 | 2 | in0:required | 0 | — | — |
| `transform` | 3/0/35/1/4 | 5 | in0:required | 0 | — | yes |
| `match_size` | 6/0/16/3/5 | 5 | input:required, target:optional | 0 | — | yes |
| `peak` | 2/0/1/3/1 | 0 | in0:required | 0 | — | yes |
| `mountain` | 2/2/9/4/1 | 2 | in0:required | 0 | — | yes |
| `bend` | 4/0/12/3/1 | 3 | in0:required | 0 | — | yes |
| `snap_to_grid` | 2/0/7/5/3 | 2 | in0:required | 2 | — | yes |
| `point_jitter` | 1/1/4/3/1 | 1 | in0:required | 0 | — | yes |
| `rest_position` | 0/0/0/3/2 | 0 | input:required, reference:optional | 0 | — | yes |
| `distance_from_target` | 0/0/7/3/5 | 2 | in0:required | 0 | — | yes |
| `uv_project` | 2/0/20/2/1 | 5 | in0:required | 0 | — | yes |
| `uv_transform` | 0/0/7/2/1 | 0 | in0:required | 0 | — | yes |
| `attr_from_image` | 0/0/0/2/1 | 0 | geometry:required, image:required:image | 0 | — | yes |
| `attribute_noise` | 1/2/17/3/5 | 4 | in0:required | 0 | — | yes |
| `attribute_noise_quaternion` | 0/2/3/4/1 | 1 | in0:required | 0 | — | yes |
| `attribute_remap` | 0/0/16/4/4 | 4 | in0:required | 1 | — | yes |
| `attribute_randomize` | 4/2/26/8/5 | 5 | in0:required | 0 | — | yes |
| `attribute_composite` | 1/0/5/6/1 | 0 | input:required, layer1:optional, layer2:optional, layer3:optional, layer4:optional, layers:optional-rest | 0 | — | yes |
| `attribute_fade` | 1/0/6/6/0 | 0 | input:required, start_source:optional, hold_source:optional | 2 | — | yes |
| `color_by_height` | 0/8/0/0/0 | 0 | in0:required | 0 | — | yes |
| `measure` | 0/0/0/3/2 | 0 | in0:required | 0 | — | — |
| `set_float` | 0/0/1/1/1 | 0 | in0:required | 0 | — | yes |
| `set_int` | 0/1/0/1/1 | 0 | in0:required | 0 | — | yes |
| `set_vector` | 0/0/3/1/1 | 1 | in0:required | 0 | — | yes |
| `set_orient` | 0/0/4/0/0 | 0 | in0:required | 0 | — | yes |
| `set_color` | 0/0/4/1/1 | 1 | in0:required | 0 | — | yes |
| `set_transform` | 0/0/16/0/0 | 0 | in0:required | 0 | — | yes |
| `swap_attributes` | 0/0/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `delete_attributes` | 1/0/0/4/0 | 0 | input:required, reference:optional | 0 | — | yes |
| `rename_attributes` | 0/0/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `delete_edge_group` | 0/0/0/1/0 | 0 | in0:required | 0 | — | — |
| `rename_edge_group` | 0/0/0/2/0 | 0 | in0:required | 0 | — | — |
| `group_delete` | 1/0/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `group_rename` | 0/0/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `group_combine` | 1/0/0/3/1 | 0 | in0:required | 0 | steps_parameter | — |
| `group_invert` | 0/0/0/2/2 | 0 | in0:required | 0 | — | — |
| `group_random` | 1/1/1/3/2 | 0 | in0:required | 0 | — | — |
| `group_bounds` | 0/0/7/2/4 | 2 | in0:required | 0 | — | — |
| `group_non_planar` | 0/0/1/2/1 | 0 | in0:required | 0 | — | — |
| `group_backface` | 0/0/3/2/1 | 1 | in0:required | 0 | — | — |
| `ordered_group` | 0/0/0/2/1 | 0 | in0:required | 0 | elements_parameter | yes |
| `groups_from_name` | 0/2/0/2/3 | 0 | in0:required | 0 | — | — |
| `name_from_groups` | 1/0/0/3/2 | 0 | in0:required | 0 | — | — |
| `material` | 0/0/7/2/0 | 2 | in0:required | 0 | — | — |
| `line` | 0/1/7/0/1 | 2 | — | 0 | — | — |
| `points` | 0/1/0/3/0 | 0 | — | 0 | — | yes |
| `circle` | 1/1/16/0/4 | 3 | — | 0 | — | yes |
| `grid` | 0/2/13/1/5 | 3 | — | 0 | — | yes |
| `box` | 1/3/10/2/3 | 3 | — | 0 | — | — |
| `uv_sphere` | 2/2/14/1/8 | 4 | — | 0 | — | yes |
| `torus` | 4/2/16/1/5 | 3 | — | 0 | — | yes |
| `tube` | 2/2/13/2/5 | 3 | — | 0 | — | yes |
| `platonic` | 0/0/10/1/4 | 3 | — | 0 | — | yes |
| `spiral` | 1/2/19/8/6 | 3 | — | 2 | — | yes |
| `bound` | 0/5/7/4/2 | 2 | in0:required | 0 | — | yes |
| `merge` | 0/1/0/1/0 | 0 | input:rest | 0 | — | — |
| `mirror` | 1/0/6/0/0 | 2 | in0:required | 0 | — | — |
| `duplicate` | 2/1/16/2/0 | 0 | in0:required | 0 | — | yes |
| `copy_to_points` | 1/0/0/4/0 | 0 | source:required, targets:required | 1 | — | yes |
| `reverse` | 0/1/0/1/1 | 0 | in0:required | 0 | — | — |
| `sort` | 2/3/3/3/2 | 0 | in0:required | 0 | — | — |
| `blast` | 2/0/0/1/2 | 0 | in0:required | 0 | — | — |
| `blast_by_attribute` | 2/0/5/3/3 | 0 | in0:required | 0 | — | yes |
| `compact_points` | 0/0/0/0/0 | 0 | in0:required | 0 | — | — |
| `rewire_vertices` | 3/0/0/3/2 | 0 | in0:required | 0 | — | yes |
| `ends` | 0/0/0/1/1 | 0 | in0:required | 0 | — | — |
| `resample` | 3/1/1/7/0 | 0 | in0:required | 0 | — | yes |
| `revolve` | 2/1/8/3/2 | 2 | in0:required | 0 | — | yes |
| `sweep` | 4/0/3/5/2 | 0 | backbone:required, cross_section:required | 0 | — | yes |
| `sweep_circle` | 9/4/8/13/0 | 0 | in0:required | 0 | — | yes |
| `polywire` | 9/4/8/13/0 | 0 | in0:required | 0 | — | yes |
| `point_generate` | 2/2/1/8/1 | 0 | in0:required | 0 | — | yes |
| `point_replicate` | 6/3/25/8/2 | 6 | input:required, custom_shape:optional | 0 | — | yes |
| `scatter` | 3/2/0/9/1 | 0 | in0:required | 0 | — | yes |
| `extract_point_from_curve` | 1/0/1/8/1 | 0 | in0:required | 0 | — | yes |
| `extract_centroid` | 0/0/0/3/2 | 0 | in0:required | 0 | — | yes |
| `separate_pieces` | 0/0/4/2/2 | 1 | in0:required | 0 | — | — |
| `enumerate` | 0/2/0/4/3 | 0 | in0:required | 0 | — | yes |
| `group_copy` | 2/0/0/1/1 | 0 | source:required, target:required | 0 | rules_parameter | — |
| `blend_shapes` | 0/0/4/6/3 | 0 | input:required, shape1:optional, shape2:optional, shape3:optional, shape4:optional, shapes:optional-rest | 0 | — | yes |
| `point_velocity` | 1/0/8/5/3 | 2 | input:required, previous:optional, next:optional | 0 | — | yes |
| `attribute_interpolate` | 3/0/3/13/4 | 0 | source:required, target:required | 0 | — | yes |
| `edge_transport_curves` | 2/0/0/2/5 | 0 | in0:required | 0 | — | yes |
| `iso_surface` | 1/0/10/0/0 | 3 | field:required:fn(vec3)->float | 0 | — | yes |
| `connectivity` | 0/0/0/6/2 | 0 | in0:required | 0 | — | yes |
| `normals` | 2/0/1/2/3 | 0 | in0:required | 0 | — | yes |
| `attribute_blur` | 1/1/5/4/2 | 0 | in0:required | 0 | — | yes |
| `smooth` | 1/1/5/5/3 | 0 | in0:required | 0 | — | yes |
| `attribute_laplacian` | 1/0/0/3/1 | 0 | in0:required | 0 | — | yes |
| `measure_curvature` | 0/1/1/7/1 | 0 | in0:required | 0 | — | yes |
| `polyframe` | 2/0/0/5/2 | 0 | in0:required | 0 | — | yes |
| `edge_relax` | 1/1/2/2/2 | 0 | source:required, reference:required | 0 | — | yes |
| `edge_equalize` | 0/1/1/2/1 | 0 | in0:required | 0 | — | yes |
| `edge_straighten` | 0/0/0/2/0 | 0 | in0:required | 0 | — | — |
| `circle_from_edges` | 1/0/4/2/0 | 1 | in0:required | 0 | — | yes |
| `crease` | 1/0/1/1/1 | 0 | in0:required | 0 | — | — |
| `edge_divide` | 1/1/0/1/0 | 0 | in0:required | 0 | — | — |
| `edge_cusp` | 1/0/0/1/0 | 0 | in0:required | 0 | — | — |
| `point_split` | 1/0/1/2/1 | 0 | in0:required | 0 | — | yes |
| `convert_line` | 4/0/1/2/0 | 0 | in0:required | 0 | — | — |
| `uv_auto_seam` | 2/0/2/5/0 | 0 | in0:required | 0 | — | yes |
| `uv_unitize` | 1/0/1/3/1 | 0 | in0:required | 0 | — | — |
| `promote_attributes` | 1/0/0/4/3 | 0 | in0:required | 0 | — | yes |
| `attribute_copy` | 1/0/0/8/2 | 0 | source:required, target:required | 0 | — | yes |
| `group_edges` | 4/0/4/2/2 | 0 | in0:required | 0 | — | — |
| `group_unshared` | 0/0/0/1/2 | 0 | in0:required | 0 | — | — |
| `group_edge_depth` | 0/1/0/2/1 | 0 | in0:required | 0 | — | — |
| `group_expand` | 5/1/2/6/4 | 0 | in0:required | 0 | boundary_attributes_parameter | yes |
| `group_boundary_components` | 0/2/0/1/1 | 0 | in0:required | 0 | — | — |
| `group_from_attribute_boundary` | 3/0/1/2/1 | 0 | in0:required | 0 | boundary_attributes_parameter | — |
| `group_promote_boundary` | 4/0/1/4/2 | 0 | in0:required | 0 | boundary_attributes_parameter | — |
| `group_promotions` | 0/2/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `group_normal` | 2/0/4/3/2 | 1 | in0:required | 0 | — | yes |
| `group_range` | 6/10/1/4/5 | 0 | in0:required | 0 | — | — |
| `group_ranges` | 0/0/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `distance_along_geometry` | 0/0/1/4/4 | 0 | in0:required | 0 | — | yes |
| `edge_transport` | 2/0/0/3/7 | 0 | in0:required | 0 | — | yes |
| `edge_transport_parent` | 2/0/0/3/6 | 0 | in0:required | 0 | — | yes |
| `group_find_path` | 2/0/0/3/3 | 0 | in0:required | 0 | — | — |
| `graph_color` | 2/0/0/4/2 | 0 | in0:required | 0 | — | yes |
| `poly_path` | 3/0/1/0/0 | 0 | in0:required | 0 | — | — |
| `carve` | 5/1/2/3/2 | 0 | in0:required | 0 | — | yes |
| `poly_bridge` | 5/2/1/3/2 | 0 | in0:required | 0 | — | yes |
| `poly_loft` | 5/0/1/2/1 | 0 | input:required, rest:optional | 0 | — | yes |
| `skin` | 5/0/1/2/1 | 0 | input:required, rest:optional | 0 | — | yes |
| `edge_flip` | 2/1/0/1/0 | 0 | in0:required | 0 | — | — |
| `subdivide` | 5/1/2/4/7 | 0 | input:required, creases:optional | 0 | — | yes |

## Port and measurement ledger

Four of the 128 target nodes have completed their full Verification gates:
`noise_displace`, `set_float`, `set_int` and `set_vector`. The remaining 124 ports are still required.
Do not fill timings, run counts, render parity or domain equality from estimates.
Each accepted row must cite the command and fixture, machine/domain setup,
OCaml/Lisp times and validation result before its plan checkbox is marked.

| Node | CPU oracle gate | 1/8 domains | Cache/refusals/UI | Native goldens | OCaml/Lisp time at 1,000,000 | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `noise_displace` pilot | Final pilot and legacy node gate 45407 passed at 4 ULP | 48781 passed, byte-exact strict reference | Schema/cache/refusals and real source/save/editor gates passed; label regression 45407 passed | Final 33890 passed; render fixtures unchanged; ml.t catalog digest expectation refreshed | Both modes 1/4 domains below 2×; table below | Complete in this port commit; A.6 and A.R passed |
| `set_float` | Authoritative all-owner native oracle 19797 and production 24674 passed | Exact strict/reference at 1/4/8 domains, grains 1/97/4096 | Factory/schema, every physical edit, public cache misses/hits, graph/inspector and refusals passed | 62289 passed; render fixtures unchanged; ml.t catalog digest only | Native/Lisp 0.000527/0.000175 s at 1 domain, 0.000212/0.000229 s at 4 domains; production table below | Complete in its separate port commit; B.11 remains incomplete |
| `set_int` | Authoritative all-owner native oracle 96226 and production 22235 passed | Exact strict/reference at 1/4/8 domains, grains 1/97/4096 | Factory/schema, every physical edit, public cache misses/hits, graph/inspector and refusals passed | 26730 passed; render fixtures unchanged; ml.t catalog digest only | Two fixed production repeats passed at both domain counts; initial 4-domain 2.559× outlier and all repeat timings retained below | Complete in its separate port commit; B.11 remains incomplete |
| `set_vector` | Authoritative all-owner native oracle 82998 and final combined 36060 passed | Exact strict/reference at 1/4/8 domains, grains 1/97/4096 | Factory/schema/vector grouping, every physical edit, public cache misses/hits, graph/inspector and refusals passed | 89432 passed; render fixtures unchanged; ml.t catalog digest only | Native/Lisp 0.002219/0.000468 s at 1 domain, 0.000540/0.000478 s at 4 domains; production table below | Complete in its separate port commit; B.11 remains incomplete |

## Moves and blocked modes

| Found during | Prerequisite / move | Gate status |
| --- | --- | --- |
| A.6 pilot audit | `sop/context_seed` exposes the cook's keyed seed inside a Lisp body, preserving its Seed context dependency. Parameter validators reject context seed directly or through a helper. The initial cook label is the kind key, while the declaration label remains menu/inspector text, matching native factories. | Direct/helper checker/IR regressions passed in 93829; final production seed, relabel and parameter-rebuild parity passed in 45407. |
| A.6 pilot audit | Owner/pattern `sop/delete_attr` advances the subset of B.6 required to invalidate point and vertex N after displacement. Literal names have no read dependency and named writes; patterns retain wildcard reads/writes. | Both pilot modes passed 60089; selective same-name owner/cache refresh and pattern conservatism passed 86865. Production source is registered; B.6 remains incomplete. |
| B.15 native prerequisite audit | `uv_project` moves whole to C.14 for topology/indexed gather and segmented seam/pole work. `measure` moves whole to C.15 for B.1/B.5/B.7/B.9/C.1/C.2 plus canonical native triangulation data and original-primitive mapping. C.R includes C.15. | Prerequisites recorded; both complete ports remain required and unchecked. No registration changed and all 128 target keys remain assigned exactly once. |

## A.6 pilot performance evidence

Quiet benchmark session 59246 exited 0 on Apple M1, OCaml 5.3.0, one million
points and grain 4096. From `lib/sop`, the command was
`opam exec -- ../../_build/default/lib/sop/test_lisp_ports.exe --bench`.
Each reported time is the median of three cold cooks using fresh sessions.
Four-domain allocation counts cover only the main domain.

| Mode and controls | Domains | OCaml seconds | Lisp seconds | Lisp / OCaml | OCaml allocated bytes | Lisp allocated bytes |
| --- | --- | --- | --- | --- | --- | --- |
| Normal 3D, amplitude 0.8, frequency 0.16 | 1 | 0.028841 | 0.032618 | 1.131 | 24,107,808 | 25,705,352 |
| Normal 3D, amplitude 0.8, frequency 0.16 | 4 | 0.008391 | 0.009430 | 1.124 | 24,131,664 | 24,476,824 |
| Default height 2D, amplitude 0.1, frequency 1 | 1 | 0.014198 | 0.020069 | 1.414 | 8,078,088 | 9,686,600 |
| Default height 2D, amplitude 0.1, frequency 1 | 4 | 0.004773 | 0.006412 | 1.343 | 8,132,456 | 8,554,072 |

Both complete modes are below the plan's 2× cook-time threshold. The later
production registration, shipping and native gates also passed, as recorded below.

## Phase A integration audit

The audit found that library injection crossed the authored-source boundary on
literal edits and that structural edits used the generic checker. The fixes
below are implemented. Focused source, editor and catalog checks and the actual
production-pilot save gate passed; final shipping and native checks also passed.

| Path / invariant | Current finding | Required evidence |
| --- | --- | --- |
| Embedded definitions stay out of saved user files | `Catalog.check_workspace` restores authored `checked.source` after checking the injected library. | `test_workspace_source.run_embedded_nodes` checks literal scrubbing, structural notes, atomic save and reopen without embedded definitions. Actual production source/editor gates 21186 and 36116 passed. |
| Narrow extension catalogs retain their language | Automatic source injection includes only embedded kinds registered in the requested catalog, with helpers/macros retained for selected definitions. Explicit `sources` overrides remain unconditional. | `test_open_domain` retains exact custom operator-list identity and asserts no unrelated embedded SOP definitions in its empty catalog. Its full editor-host fixture supplies production operators plus custom operators explicitly. `test_node_sources` tests empty catalog membership and unconditional explicit source injection. Final shipping session 83244 passed, including all 67 open-domain assertions and source-selection regressions. |
| Gestures keep the library available | `Flow_edit.apply_checked` accepts a checker callback for branch defaults and every candidate; `Workspace_doc` supplies `Catalog.check_workspace`. | `test_node_sources` checks a library-backed structural edit and printed-source reopen. `@lib/flow_sop/runtest @lib/flow_graph/runtest` exited 0 (session 91419). |
| Body identity survives authored-source restoration | `Lower` hashes authored forms plus checked definition, macro and node-body forms. | `test_node_sources` keeps authored text and public node ID unchanged while changing the injected body or an embedded macro helper, and requires changed output with exactly one public cache miss. Lowering/graph gate exited 0 (sessions 91419 and 73414). |
| Helper context dependencies use lexical scope | `Context_kernel.depends` binds helper formal names to actual scalar arguments, tracks sequential aliases, and removes function/loop/state binders from inherited known values. Unknown branches are scanned conservatively. | `test_node_sources` covers nested helper calls with an outer boolean of the same name, active/inactive helper branches and function-local names. An active seed helper changes output and causes exactly one public miss across context seeds; an inactive helper retains its hit. Checker/lowering/IR gate exited 0 (session 93829). |
| Specialized component facts remain truthful | Attribute kernels collect checked/captured attribute names and retain wildcard reads for opaque geometry uses. Literal deletion records no reads and its named write; deletion patterns retain wildcard reads/writes. Lisp wrappers derive body facts, preserve declared component order and retain a declared non-exact contract. | Same-name point/detail owner refresh, wildcard deletion and combined native/Lisp preserved-topology/domain census passed in session 86865. |
| Embedded helpers stay out of editable navigation | Navigator filters checked defns/macros by authored top-level form IDs, including the search view, while lowering retains them. | `test_workspace_source.run_library_navigation` checks normal/search rows hide injected helpers while retaining authored definitions. Refreshed dummy-driver editor gate passed (session 16558). |
| Local declaration completions follow the document | Shared vocabulary refresh compares operator and declaration schema identities on install, history/preset reduction and carry document adoption. Scalar scrubs reuse the same lazy vocabulary. | Actual editor reload/add/remove/schema changes and reducer undo/redo pass in `@test/test_workspace_vocabulary` (sessions 97286 and 16558). |
| Catalog/menu inventory survives registration removal | Catalog tests assemble the native and lowered Lisp factory lists, keeping the existing total-key, metadata, disconnected-instance and cache perturbation assertions. | Combined registry test passed before the production switch (97286 and 16558) and after it (21186 and 36116). `test_facts` now sweeps the same combined registry; 86865 passed. |
| Typed function libraries remain inspectable before connection | Default factories without a checked callable retain operation/schema identity and report `disconnected_input` on cook. Instantiated calls derive their facts and packed bodies from the actual function. | `test_node_sources` checks native keyword-Fn delegation, typed vec3-map calls, default factory catalog introspection, disconnected identity/schema and typed unbound cook refusal. Refreshed lowering/graph gate exited 0 after these checks. |

Early A.4 and A.5 sessions predate these source-boundary fixes. Combined
`@lib/flow_sop/runtest @lib/flow_graph/runtest` sessions 77216 and 79773 exited 1
on the ongoing A.3 function-capture regression; they are not passing evidence
for the phase review.
The later session 91419 passed both focused aliases, including the new body
cache, source/edit and keyword function/image manifest regressions. Actual
embedded-pilot save and catalog/editor checks after registration removal passed
in sessions 21186 and 36116. The refreshed editor/navigation/vocabulary and
dependency gate passed before the switch in session 16558.

The final seed mismatch was caused by using the declaration's display label as
the initial cook label rather than the native factory's stable kind key.
The implementation now follows the native label protocol. The pilot oracle
instantiates the genuine native factory and asserts equal initial labels; it
does not rewrite the oracle's label to mask the mismatch. Display-only relabel
and restored labels retain warm cache hits; parameter rebuilds after relabel
match the native namespace at both tested context seeds. The legacy node oracle
uses the approved four-ULP comparison only for native-versus-Lisp arithmetic;
one-versus-four-domain comparison remains byte-exact. Render fixtures remain
unchanged. The generated-source expectation in `tools/lisp/test/ml.t` was
reviewed and updated only for the catalog digest, from
`84f55bc3821897e594fda2cfcd03c76ee8ab2395d7de962686c7ba71d6bb1dbc` to
`f00fd3644c20c0baab5a1dca8e5ae455fea598adf20e438567a95f62e71920ec`.
The authored source digest, generated source text and refusal diagnostics are
unchanged; the catalog digest changed with the accepted production declaration.

The whole `uv_project` and `measure` moves to C.14/C.15 are accepted and retain
every mode and the 128-node target scope. The known array-valued
attribute, `next_after`, `fma`, encoded-decoder and partial-subdivide requirements
above must be resolved by implementation or an explicit recorded move. They are
scope requirements, not evidence that a node has been completed.

Final Phase A gates: `opam exec -- _build/default/tools/check.exe --ship`
(session 83244) exited 0 after the catalog membership fix and reviewed `ml.t`
catalog digest update. It includes `@all`, `@runtest`, `@smoke` and
`git diff --check`; the workspace IR sweep covered 43 standard files, one
custom-catalog executable and 13 fixtures at four times and domains 1/8.
`opam exec -- _build/default/tools/check.exe @runtest-native` (session 33890)
also exited 0, including 23 SOP graphs with byte-identical one/four-domain PNGs.
No native render golden was refreshed. Phase A is complete; B–E and G remain
required and unchecked.

## Typed integer kernel throughput diagnostic

The new runnable probe is `opam exec -- ./test_rand_at.exe --bench-rand`,
from `_build/default/lib/flow_sop`, after building with
`opam exec -- _build/default/tools/check.exe lib/flow_sop/test_rand_at.exe`.
It checks every output bit against native `Rand.float_at` before reporting
the median of three runs. Apple M1, arm64, OCaml 5.3.0; one million integer
indices, seed 42, native grain 4096. Four-domain allocations count only the
calling domain. These are kernel diagnostics during implementation, not a
whole-node performance qualification.

| Version | Domains | Native seconds | Strict packed seconds | Packed allocated bytes |
| --- | --- | --- | --- | --- |
| Before | 1 | 0.005378 | 0.226860 | 552,034,032 |
| Before | 4 | 0.001562 | 0.232287 | 552,034,032 |
| Cached frame/uniform values, direct packed loads/stores and indexed loops | 1 | 0.004505 | 0.165916 | 120,035,872 |
| Cached frame/uniform values, direct packed loads/stores and indexed loops | 4 | 0.001344 | 0.168545 | 120,035,872 |
| Typed block execution | 1 | 0.004429 | 0.084496 | 137,811,008 |
| Typed block execution | 4 | 0.001311 | 0.028506 | 58,403,280 |

The shared typed executor now avoids repeated frame-operator lookup, component
arrays and collection value boxes. Lazy frame/uniform reads still occur only
in selected branches. Typed block execution uses separate integer and float
banks; independent maps with concrete captures use the shared domain pool.
Ordered folds/scans and maps with deferred captures remain sequential. This
improves the original packed timings by 2.7 times at one domain and 8.1 times
at four domains, but remains above the native timing ceiling. No random-heavy
whole-node port is qualified by this diagnostic. Logs:
`/tmp/rays-rand-before.log`, `/tmp/rays-rand-after-scalar-final.log`,
`/tmp/rays-rand-after-block.log`.
Focused build 27805 passed. The final `test_packed`, `test_uniforms` and
`test_rand_at` executable checks all exited 0 (13656, 31240, 5259), including
strict guards, captured-uniform errors/rollback, exact integer boundaries,
100,000 native/reference/packed/JavaScript random keys and 300,054 noise samples.
The block executor's checks also passed (`test_packed` 95003,
`test_uniforms` 94995, `test_rand_at` 97358): 32,769-element exact integer maps,
mixed vector conversions, product iteration with skipped indices, wrapping
integer folds/scans and selected versus unselected arithmetic errors at one
and eight domains. The `rand/at` primitive's later exact native/reference/CPU/
JavaScript gates also passed (42787), including varying signed seed and index
arrays and lazy branches. It uses the shared signed-63-bit hash primitive,
avoiding a fresh boxed native seed for every element.

The separate `--bench-rand-primitive` probe has the same one-million-element,
median-of-three and exact-bit protocol. After replacing boxed output
initialization/collection with typed allocation and block copies, the quiet
run in `/tmp/rays-rand-primitive-output-block.log` exited 0:

| Primitive version | Domains | Native seconds | Strict packed seconds | Packed allocated bytes |
| --- | --- | --- | --- | --- |
| Shared hash, before output block copies | 1 | 0.004309 | 0.025193 | 67,349,088 |
| Shared hash, before output block copies | 4 | 0.001409 | 0.013373 | 40,763,240 |
| Shared hash, typed output block copies | 1 | 0.004380 | 0.012836 | 35,458,528 |
| Shared hash, typed output block copies | 4 | 0.001465 | 0.006546 | 21,166,248 |

The earlier primitive log is `/tmp/rays-rand-primitive-reuse-quiet.log`.
Independent packed/uniform/random regressions passed after the output change
(7929/58522/13094), preserving finite checks, lazy failures, exact signed
integers, skipped/product outputs and ordered folds/scans. This remains a
compiler microbenchmark; no whole random-heavy node is qualified by it.

Contiguous integer input blocks now use `Array.blit`, preserving indexed
product/skipped paths and guarded bounds. Build 29283 and independent packed,
uniform and random checks 59155/90162/68354 passed. The quiet follow-up probe
(`/tmp/rays-rand-primitive-input-blit.log`) reports native/packed seconds
0.004567/0.012516 at one domain and 0.001351/0.005992 at four, with packed
allocations 35,474,160/20,851,392 bytes. The small timing difference from the
previous run is not treated as a separate performance qualification.

The independent `test_packed.exe --bench-product` probe repeats a sixteen-value
float row across one million integer indices. It compares every output bit
against an independent `Array.blit` loop, then measures median-of-three
materializations (Apple M1, OCaml 5.3.0, initial-domain allocations). It is a
compiler diagnostic, not a qualified SOP port.

| Float input implementation | Domains | Native seconds | Packed seconds | Packed bytes |
| --- | ---: | ---: | ---: | ---: |
| Per-element value-returning finite check | 1 | 0.009566 | 0.362461 | 1,238,802,696 |
| Per-element value-returning finite check | 4 | 0.009444 | 0.100316 | 413,519,824 |
| Concrete input checked and stored without boxing | 1 | 0.009606 | 0.315407 | 982,802,696 |
| Concrete input checked and stored without boxing | 4 | 0.009480 | 0.087061 | 348,280,480 |

Logs: `/tmp/rays-product-before.log` (95676) and
`/tmp/rays-product-input-after.log` (74785), both exited 0. The shared input
loop now selects concrete Float/Vec storage once per instruction and checks
finite values before storing them directly in the float register bank.
Expanded regression 65808 passed scalar/vec3/vec4 Product inputs, signed zero,
integer/guard/error/skip cases and exact reference bytes at one/four/eight
domains. Uniform 41676 and native/reference/JavaScript random 54737 checks
also passed. Arithmetic remains the remaining allocation source in this probe.

Typed Collect vector outputs now choose the integer/float register bank once
per component and interleave directly, avoiding a boxed numeric return for
each float lane. Exact packed and uniform checks 90687/23794 both passed.
The separate `--bench-product-row` probe uses an already-computed live row,
matching the two-register Product shape observed in Set Transform. Quiet
38469 exited 0 (`/tmp/rays-product-row-after.log`): one domain native/packed
seconds 0.012400/0.195219 and packed bytes 182,563,272; four domains
0.010060/0.057069 and 147,507,032 bytes. Both remain above 2×. The remaining
per-item Product indexing cannot be counted as solved by lower allocations.

### Metadata codec and quaternion preparation

The unchanged native table codec now lives in `Param.String_table`; the former
`Sop.Support` helpers are aliases. Focused `@lib/param/runtest` and metadata
library compilation passed (session 24395). After adding typed pure
`text/table_encode`/`text/table_decode` declarations, structured Core lowering,
JavaScript mirrors and live nested-list forcing, the combined
`@lib/flow/runtest @lib/flow_ir/runtest @tools/lisp/runtest` gate exited 0
(session 15955). Empty tables/cells, escaped tabs/newlines/backslashes, UTF-8,
malformed escapes, trailing escapes and wrong input types are covered. This
codec capability does not supply the missing B.12 parameter canonicalization
boundary and does not complete B.6 or a metadata port.

Unsupported non-ASCII table escapes preserve the native decoder's legacy
first-UTF-8-byte diagnostic. That byte can be invalid UTF-8 inside the native
error string. The JavaScript mirror matches its transported/displayed form
using the standard UTF-8 replacement decoder; the native raw error bytes remain
unchanged. Unsupported `é` and emoji escape transport fixtures are explicit. Normal UTF-8
cells round-trip exactly.

Quaternion normalization now guards native norm overflow with quarter-scaled
squares, retaining the native identity threshold and signed-zero overflow
outputs without producing a nonfinite intermediate. The existing native math
audit at this stage remained 15/1,863 components above four ULP. The
helper threshold check passes 60 finite native cases, checking overflow and
signed zeros exactly and other finite components at the approved four-ULP
oracle tolerance. Strict packed/reference comparison on 32,769 elements is
byte-identical at one/eight domains (direct helper/kernel checks, session
79959), within the existing 64-register limit. These are prerequisites for
Set Orient; the five setter drafts remain unregistered and their complete
port Verification gates are still pending.

### Rest Position draft and cooked structural selection

The full `Motion.rest_position` and SOP wrapper were read before authoring
`nodes/rest_position.pending`. It keeps Store/Extract/Swap, None/If present/Always
normal policies, the optional reference, missing-rest fallback, Store-only
reference cardinality checks, wrong-storage refusals and native attribute
replacement order when names alias. Normal creation delegates to the existing
`sop/normals` kind. Nothing is embedded or registered.

`test_rest_position.ml` builds the draft and independent native factory. It
contains every mode/policy, absent and present references, empty/single/mixed,
4,225 and 32,769-point inputs, metadata/key comparisons, immutable inputs and
strict/reference/one/eight-domain/grain comparisons. Its executable builds
(38192), but the first runtime check fails with `E_LOWER: Graph sop/rest_position
does not return geometry`: a cooked count/presence condition produces a residual
geometry result, while the current structural lowering accepts only an already
chosen deferred root. The shared cook-time structural selection capability is
required; an eager branch selector or an interpreter fallback for numeric maps
would not satisfy it. The pending recipe has an explicit
`@lib/flow_sop/rest_position_draft` check and is not a passing port gate.

The shared cooked-selection compiler now gets beyond that refusal. Initial
testing found and fixed a zero-arity capture factory rebuilding a chained node
without its inputs; captures now use lazy snapshot proxies. Expanded runtime
10529 (`/tmp/rays-host-capture-rest-check.log`, build 61566) passed the complete
geometry loop: modes, normal policies, optional references, alias replacement
order, native four-ULP and strict/reference/domain/grain checks. These runs used
one/eight domains; the fixture now additionally requests four domains.
Canonical P as a stored-normal name is absent to the native ordinary-attribute
lookup, and Normals=None still allows blank/P output-normal names until a
selected Extract/Swap attempts to install them. The recipe preserves those
native branches rather than rejecting them early.

The expanded error gate then exposed the native adapter contract: the Session
message is `rest_position could not produce valid geometry` and the detailed
`rest_position [code]: reason` is its separate cause. The pending Lisp recipe
and tests now require a generic cause-bearing error boundary, including quoted
UTF-8/control names, error precedence and untaken malformed inputs. Parameter
edit/cache and million-point timing gates remain pending. No registration,
golden or whole-node completion has been claimed.

The generic diagnostic cause boundary is now implemented. Expanded gate 32522
passed native code/message/cause, all parameter edits and cache behavior,
typed input refusals, the real 65×65-point quad grid, and strict/reference
parity at one/four/eight domains with grains 1/97/4096.

Quiet benchmark 29581 exited 0; the 2× performance gate fails dramatically.
Command: `opam exec -- ../../_build/default/lib/flow_sop/test_rest_position.exe --bench`
from `lib/flow_sop`; log `/tmp/rays-rest-position-bench.log`. Apple M1,
OCaml 5.3.0, one million payload points, grain 4096, median of three fresh
cold Session cooks; allocations are measured on the initial domain.

| Mode | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Store | 1 | 0.000042 | 0.172309 | 4106.341 | 11,488 | 726,704,016 |
| Store | 4 | 0.000033 | 0.158454 | 4781.324 | 11,720 | 726,765,720 |
| Extract | 1 | 0.000034 | 0.344347 | 10171.099 | 11,504 | 1,453,371,256 |
| Extract | 4 | 0.000034 | 0.311690 | 9206.493 | 11,736 | 1,453,496,520 |
| Swap | 1 | 0.000063 | 0.500327 | 7948.955 | 11,720 | 2,180,039,632 |
| Swap | 4 | 0.000062 | 0.479159 | 7729.765 | 11,952 | 2,180,214,272 |

Native operations share existing attribute planes. Preserving those borrowed
values through shared structural compilation and attribute sinks is required;
copying them in a faster loop cannot satisfy the whole-node gate. No port
registration or completion tick is justified by this semantic draft.

### Five setter drafts: semantic proof and failed timing gate

`nodes/setters.pending` contains whole Set Float, Set Integer, Set Vector, Set
Orient and Set Transform declarations; native registration is unchanged. The
recipes use owner-specific topology counts, typed attributes and the guarded
quaternion helper. Transform emits the full 16-value CSR row through Cartesian
iteration over a literal Float array, without a dynamic gather prerequisite.
Focused executable checks passed (31091/76851 and refreshed 13786): every
owner, defaults, empty/single/mixed/32,769-point inputs, native labels/schema/cook
keys, four-ULP native oracle, exact strict/reference and one/eight-domain bytes
at grains 97/4096. Every physical parameter edit also passed native key/oracle
comparison, exactly one new public miss and subsequent warm hits (10604).

The initial cold-cook timing gate failed for all five drafts. Command:
`opam exec -- ./test_setters.exe --bench` from
`_build/default/lib/flow_sop`; log `/tmp/rays-sop-setters-bench.log`, session
33665 exited 0. Apple M1, OCaml 5.3.0, one million points, grain 4096, median of
three fresh-session cold cooks. Four-domain allocations count the initial
domain only. Values below are seconds and bytes, with the ratio Lisp/native.

| Draft | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---:|---:|---:|---:|---:|
| Set Float | 1 | 0.000213 | 0.007590 | 35.649 | 8,006,952 | 16,039,880 |
| Set Float | 4 | 0.000176 | 0.005424 | 30.785 | 8,007,184 | 16,078,840 |
| Set Integer | 1 | 0.000351 | 0.005245 | 14.935 | 8,007,008 | 16,023,168 |
| Set Integer | 4 | 0.000394 | 0.005206 | 13.217 | 8,007,240 | 16,023,400 |
| Set Vector | 1 | 0.000469 | 0.016928 | 36.096 | 24,007,080 | 48,042,408 |
| Set Vector | 4 | 0.000620 | 0.009971 | 16.079 | 24,007,312 | 48,041,912 |
| Set Orient | 1 | 0.001113 | 0.064356 | 57.825 | 32,007,032 | 445,408,640 |
| Set Orient | 4 | 0.000731 | 0.021155 | 28.940 | 32,007,264 | 139,961,536 |
| Set Transform | 1 | 0.015526 | 0.575963 | 37.097 | 136,007,824 | 1,360,019,760 |
| Set Transform | 4 | 0.015710 | 0.290624 | 18.499 | 136,008,056 | 943,526,304 |

The generic path constructs an intermediate packed array and then copies or
transposes it into attribute storage; Orient and Transform additionally
materialize constant maps/product iterations. This evidence motivates a
shared constructor/output path, not a setter-specific callback. B.11 remains
unchecked; Set Color also awaits its whole group-aware recipe and no setter
has been embedded or switched into the production catalog.

The shared array constructors now fill constant arrays directly, and the
attribute host prepares strict count/value programs once before cooking.
Validated constant output writes allocate their owned attribute planes
directly. Set Orient uses the genuine `array/vec4` constructor. Empty counts,
invalid counts, mismatched owner counts, live values and selected nonfinite
errors retain the original strict path and diagnostics. Refreshed checks
74614 (attribute output) and 25323 (whole setter semantics and every physical
parameter edit) exited 0; runtime operation/version also matches the native
factory.

The same quiet benchmark recipe then passed the 2× gate for four drafts;
Set Transform still fails. Log `/tmp/rays-sop-setters-bench-prepared.log`,
session 24009 exited 0. The million-point input, fresh sessions, median of
three, domains/grain and allocation convention are unchanged.

| Draft | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---:|---:|---:|---:|---:|
| Set Float | 1 | 0.000551 | 0.000188 | 0.341 | 8,006,952 | 8,025,288 |
| Set Float | 4 | 0.000302 | 0.000238 | 0.788 | 8,012,208 | 8,025,520 |
| Set Integer | 1 | 0.000411 | 0.000435 | 1.058 | 8,007,008 | 8,025,304 |
| Set Integer | 4 | 0.000404 | 0.000426 | 1.055 | 8,007,240 | 8,025,536 |
| Set Vector | 1 | 0.002164 | 0.001318 | 0.609 | 24,007,080 | 24,025,496 |
| Set Vector | 4 | 0.000567 | 0.000586 | 1.034 | 24,007,312 | 24,025,728 |
| Set Orient | 1 | 0.001583 | 0.000923 | 0.583 | 32,007,032 | 32,025,528 |
| Set Orient | 4 | 0.000745 | 0.000749 | 1.005 | 32,007,264 | 32,025,760 |
| Set Transform | 1 | 0.018025 | 0.355610 | 19.729 | 136,007,824 | 849,945,752 |
| Set Transform | 4 | 0.016709 | 0.150199 | 8.989 | 136,008,056 | 626,055,488 |

Transform still materializes a Cartesian loop and copies its CSR record.
The remaining optimization must follow the shared typed representation.
No setter registration changed; Set Color and the remaining whole-port
error, editor and shipping gates keep B.11 unchecked.

The actual Transform trace compiles both its integer offsets and its
Float-valued Cartesian product into packed programs; the product retains
its Int and Float sources. Strict forcing succeeds, so this is a measured
packed throughput/copying problem rather than an interpreter fallback.
After generic input and vector-output unboxing, the isolated whole-node
rerun 62960 exited 0. Same million-point cold-session methodology:
`opam exec -- ./test_setters.exe --bench-transform` from
`_build/default/lib/flow_sop`; log
`/tmp/rays-sop-set-transform-bench-unboxed.log`.

| Node | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---:|---:|---:|---:|---:|
| Set Transform | 1 | 0.017570 | 0.311506 | 17.729 | 136,007,824 | 594,012,208 |
| Set Transform | 4 | 0.015579 | 0.121583 | 7.804 | 136,008,056 | 556,980,792 |

This still fails the whole-node speed gate. The refreshed semantic checks
also cover a real 4,225-point quad grid, domains 1/4/8, grains 1/97/4096,
atomic blank/canonical-P rejection and affine/nonfinite boundary errors.
Session 13714 passed those checks and the constant-output ownership/error
regressions, but exited 1 for an in-flight omitted-vector graph gesture;
the corrected gesture passed in 97611. The aggregate failure is retained
as a failed gate rather than reported as an aggregate pass.

Integration checks now compare the complete default factory descriptors of
all five drafts with their native factories. The four speed-passing drafts
also compare graph cards and inspector rows, edit every physical field
through `Flow_edit`, cook the edits against native keys and geometry, and
exercise bypass. Build 49346 and direct `test_setters.exe` run 97611 exited
0. Omitted grouped-vector fields are edited as complete vectors with the
other components retained, matching the geometry inspector's gesture.
Production integration still requires embedding those declarations,
removing their native registrations, reviewing the generated manifest and
running the catalog/dependency/native gates. Render parity uses Set Float
in `edge_transport` and Set Integer in `separate_pieces`; material tests
also use Set Integer. No rendered fixture has been refreshed for these
unregistered drafts.

### Set Color whole-node draft

`nodes/set_color.pending` is an unregistered whole-node recipe. Focused gate
52215, `@lib/flow_sop/set_color_draft`, exited 0. It covers all four owners,
blank/trimmed/UTF-8 group names, partial/full/empty/ordered selections,
all eight existing `Cd` storage kinds, and native parameter metadata and
factory descriptors. The fixtures include mixed topology, empty geometry,
32,769 points and a real 4,225-point grid. Native geometry is within 4 ULP;
strict/reference and domains 1/4/8 with grains 1/97/4096 produce identical
bytes. Every physical parameter edit matches the native key and cook,
causes one public miss, then hits unchanged. Missing-group code, message
and optional cause match native diagnostics; owner/detail-group validation,
hard clamping and nonfinite parameter refusals are covered. Refreshed gate
23658 additionally passed a single-point input, native graph card and
inspector equality, every physical field's direct `Flow_edit` gesture and
native cook/key comparison, hard-bound refusal and bypass.

The million-point cold-cook gate **fails**. Session 77836 exited 0 for
`opam exec -- ../../_build/default/lib/flow_sop/test_set_color.exe --bench`
from `lib/flow_sop`; log `/tmp/rays-set-color-bench.log`. Apple M1,
OCaml 5.3.0, grain 4096, median of three fresh-session cold cooks. Selected
groups contain alternating points. Four-domain allocations count the
initial domain only; times are seconds and allocations are bytes.

| Existing Float4 Cd | Group | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---|---:|---:|---:|---:|---:|---:|
| absent | all | 1 | 0.001809 | 0.021348 | 11.802 | 32,007,712 | 64,024,768 |
| absent | all | 4 | 0.001387 | 0.011242 | 8.105 | 32,007,944 | 64,074,336 |
| absent | selected | 1 | 0.004147 | 0.179815 | 43.360 | 32,008,128 | 503,907,776 |
| absent | selected | 4 | 0.004262 | 0.073574 | 17.263 | 32,008,360 | 222,432,168 |
| present | all | 1 | 0.001465 | 0.015750 | 10.752 | 32,008,752 | 64,046,696 |
| present | all | 4 | 0.002051 | 0.011634 | 5.673 | 32,008,984 | 64,081,560 |
| present | selected | 1 | 0.008237 | 0.173761 | 21.095 | 32,009,360 | 503,913,616 |
| present | selected | 4 | 0.004840 | 0.080630 | 16.659 | 32,009,592 | 209,356,328 |

The residual/Core trace found the ungrouped constructor captured under
`(exact colors)`. The shared recognizer now unwraps exact and captured
residual bindings, preserving strict qualification, original error order,
empty-count laziness and newly owned planes. The direct and captured forms
passed the refreshed attribute regressions in 13714.

Latest quiet whole-node benchmark 58659 exited 0 after rebuilding the
current packed compiler (51230). Same methodology as above;
`opam exec -- ./test_set_color.exe --bench` from
`_build/default/lib/flow_sop`; log
`/tmp/rays-set-color-bench-exact-capture.log`.

| Existing Float4 Cd | Group | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---|---:|---:|---:|---:|---:|---:|
| absent | all | 1 | 0.001382 | 0.000759 | 0.549 | 32,007,712 | 32,039,368 |
| absent | all | 4 | 0.001488 | 0.000671 | 0.451 | 32,007,944 | 32,026,920 |
| absent | selected | 1 | 0.004060 | 0.152568 | 37.578 | 32,008,128 | 375,993,752 |
| absent | selected | 4 | 0.003985 | 0.060991 | 15.304 | 32,008,360 | 175,731,392 |
| present | all | 1 | 0.001867 | 0.001063 | 0.569 | 32,008,752 | 32,043,864 |
| present | all | 4 | 0.001372 | 0.001997 | 1.455 | 32,008,984 | 32,031,416 |
| present | selected | 1 | 0.004977 | 0.135692 | 27.264 | 32,009,360 | 375,999,592 |
| present | selected | 4 | 0.004760 | 0.060062 | 12.618 | 32,009,592 | 175,756,336 |

Ungrouped cooks now meet the speed limit. The whole node remains blocked:
The selected path compiles a packed map inside a structured conditional;
the attribute writer cannot offer that nested result to its direct plane
sink, and the map's previous-color input is materialized first. Shared
packed-output handling needs further work. The 2× limit is
unchanged, and this draft has not been registered.

### Shared compiler shipping checkpoint

Public declaration, typed execution, FMA and diagnostic APIs were reviewed and
accepted separately in commit `36a8c5cf`. Foundation shipping request 72847
ran `opam exec -- _build/default/tools/check.exe --ship`; log
`/tmp/rays-sop-lisp-foundation-ship.log`. It exited 1: the complete workspace
sweep passed (43 standard files and 13 fixtures), but the GPU operation test
still generated the old binary arity for the new three-input `fma`. The test
now uses valid FMA/random bodies and explicitly verifies their typed GPU
refusals; focused GPU request 82280 exited 0 with existing goldens unchanged.

Review identified and fixed additional Source attribute descriptor tracking,
editor diagnostic-cause conversions, and ASCII-only JavaScript metadata
policy normalization. These edits happened after the baseline compiled its
targets, so that baseline cannot validate them. Fresh attribute/drawing/web
regressions were required before the foundation source commit. Fresh SOP
request 87196 and Drawing request 7654b3 passed Source count/fusion/read facts,
malformed-handle guards, exact domain outputs and editor error causes/spans.
The root's valid-argument Drawing execution also exited 0. Fresh full shipping
request 21836 exited 0 in `/tmp/rays-sop-lisp-foundation-ship-final.log`,
including all 43 standard workspaces and 13 fixtures. At this checkpoint,
the prepared four setter production sources and authoritative oracle entry
remained outside the worktree; native registrations were unchanged.

### Cartesian row projection

Foundation source shipping passed and was committed as `b0323372` after the
separate API declaration commit. A generic packed Cartesian projection now
copies a checked Float row with `Array.blit`, using coarse disjoint output
ranges. It applies only to a two-input, two-instruction Collect program with
an unused concrete Int outer input and a Float row output; guards, skips,
arithmetic and other input types retain the block executor.

Build 46362, exact regression 65081 and focused IR request 28796 exited 0. Independent repeated-array
bytes, signed zeros, subnormals, empty inputs, selected NaN/Inf, omitted output
lanes and wrong input types agree with the ordinary block path at 1/4/8
domains. Existing packed diagnostics and snapshots also passed.

Quiet `test_packed.exe --bench-product-row` repeats 16 Float values over one
million outer indices, median of three materializations. On Apple M1:

| Domains | Native seconds | Packed seconds | Ratio | Packed allocated bytes |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.009826 | 0.013712 | 1.395 | 136,053,288 |
| 4 | 0.009328 | 0.009653 | 1.035 | 136,101,384 |

Log: `/tmp/rays-product-repeat-bench.log`. The previous two-register probe
took 0.195219/0.057069 seconds at 1/4 domains. This primitive now meets the
speed limit; that does not qualify a whole node.

Actual `test_setters.exe --bench-transform` (19154, exit 0), one million
points, grain 4096, median three cold sessions, still fails the whole-port
speed gate:

| Domains | Native seconds | Lisp seconds | Ratio | Lisp allocated bytes |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.020379 | 0.110583 | 5.426 | 547,557,488 |
| 4 | 0.016020 | 0.077010 | 4.807 | 544,994,128 |

Log: `/tmp/rays-transform-repeat-bench.log`. Remaining materialized CSR
arguments are rebuilt through a checked host-call graph and copied into
owned storage. Further shared work is required; Set Transform is unregistered.

### Set Float production port

After foundation commit `b0323372`, Set Float moved into the embedded
`nodes/set_float.rays` declaration. The existing `setter_constant` macro moved
once from the remaining setter draft into the prelude. The native catalog
registration was removed; `Sop.Nodes.Set_float.factory` remains the independent
oracle. Set Integer, Set Vector, Set Orient, Set Color and Set Transform are
still pending, so B.11 remains unchecked.

The authoritative `set_float` function in `lib/sop/test_lisp_ports.ml` passed
request 19797 before removing the native registration. It checks all four
owners, defaults and non-default parameters, empty/single/4,225-point grid,
mixed polygon/polyline and 32,769-point inputs, full factory/runtime metadata,
native 4-ULP geometry, exact reference/strict bytes, domains 1/4/8 at grains
1/97/4096, unchanged inputs, every physical parameter's cache identity and
non-finite/wrong-input/blank-name/canonical-P refusals.

Reviewed manifest digest `4c26f747931acd48875866372f08160d` preserves the
key, operation, aliases, label, category, slot and complete field metadata.
The entry moves into Lisp declaration order, replaces native facts with the
Lisp body/calls markers, and is the only kind changed. The generated-source
expectation `tools/lisp/test/ml.t` changes only its catalog digest to
`c285ced779a95de5fbc8a2f859be667ef2f39a74b659fea9f34cb81615a3aab7`.
Render fixtures remain unchanged.

Production focused request 24674 exited 0 for `@lib/sop/runtest`,
`@lib/flow_sop/runtest`, `@lib/sop_catalog/runtest` and
`@test/dependency_gate`. Its earlier run 18780 passed the production oracle
but failed a new group-test fixture's bare `any` literal; that fixture was
corrected without changing runtime behavior. Native request 62289 exited 0
for `@runtest-native`, including 23 SOP graphs with byte-identical one/four
domain PNGs. Generated-source request 63796 exited 0 for
`@tools/lisp/test/runtest` after accepting the digest-only expectation above.

Quiet production timing exited 0: `opam exec -- ./test_setters.exe
--bench-float` from `_build/default/lib/flow_sop`, log
`/tmp/rays-set-float-production-bench.log`. This uses the embedded declaration
with no Set Float body in the pending draft. Apple M1, OCaml 5.3.0,
1,000,000 points, grain 4096, median of three fresh-session cold cooks:

| Domains | Native seconds | Lisp seconds | Ratio | Native allocated bytes | Lisp allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.000527 | 0.000175 | 0.332 | 8,006,952 | 8,025,520 |
| 4 | 0.000212 | 0.000229 | 1.080 | 8,007,184 | 8,025,752 |

Four-domain allocation records the initial domain only. Both cold-cook ratios
pass the unchanged 2× gate. The Set Float port is complete in its separate
source commit; B.11 remains incomplete.

### Immutable attribute storage transfers

The reviewed public declaration snapshot is `97c1c610`. Core retains an
unchanged attribute query as `Source_descriptor` only for a cooked storage
consumer. Shared `Attribute_kernel.write_source` checks storage kind and
destination cardinality before adopting immutable planes. Numeric consumers
and computed arrays keep ordinary strict execution and finite checks. The
current 2D JavaScript target explicitly refuses the new cooked source form;
no SOP web-export support is claimed.

Focused checks 46311 (typecheck/FlowSOP), 25554 (IR/Web) and 71782 (Rest Position)
passed. The Rest oracle covers Store/Extract/Swap, all normal policies,
optional references, compiled/reference paths and 1/8 domains. Exceptional
NaN payloads, infinities, signed zeros and huge finite native values retain
exact bytes and physical unchanged-plane identity, without mutating inputs.
A computed identity map over those planes still raises `E_NONFINITE`.
Post-promotion API and tools request 48150 exited 0. This storage proof is
not a whole-node speed gate; Rest Position remains unregistered.

### Set Integer production port

Candidate request 96226 exited 0 for the authoritative `set_int` oracle,
loading the pending declarations explicitly while the global catalog kept
its native registration. The production `nodes/set_int.rays` addition and
native registration removal then happened together. Only this declaration
was removed from `setters.pending`; the shared prelude macro is reused.
`Sop.Nodes.Set_int.factory` remains the independent oracle.

The complete setter recipe covers all owners, defaults/non-defaults,
`max_int` without float coercion, the required geometry fixtures, full
factory/runtime schema, native geometry, exact strict/reference and 1/4/8
domain bytes at grains 1/97/4096, every physical field's edit/cache identity,
validation and wrong geometry types. Production request 22235 exited 0 for
SOP, FlowSOP, catalog, dependency and tools Lisp tests. Native request 26730
exited 0, including 23 SOP graphs with exact one/four-domain PNG parity.

Manifest digest `cb0e51368d5173e1c0f3fc8aa36368f7` changes only the Set
Integer entry's declaration order, native facts and Lisp body/calls markers;
all original metadata remains equal. Only `tools/lisp/test/ml.t`'s generated
catalog digest changed to
`0b65809322047391b13964d6dd8bc827013759862ee30f3b954ceb1863952adc`.
No render fixture changed. The first quiet production timing (17423, exit 0)
failed the four-domain 2× gate. Command: `opam exec -- ./test_setters.exe
--bench-int` from `_build/default/lib/flow_sop`; log
`/tmp/rays-set-int-production-bench.log`. Apple M1, OCaml 5.3.0, 1,000,000
points, grain 4096, median of three fresh-session cold cooks:

| Domains | Native seconds | Lisp seconds | Ratio | Native allocated bytes | Lisp allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.001521 | 0.000467 | 0.307 | 8,007,008 | 8,025,536 |
| 4 | 0.000773 | 0.001978 | 2.559 | 8,007,240 | 8,025,768 |

Four-domain allocation records the initial domain only. Earlier draft ratios
were 1.058/1.055. Two additional quiet invocations were predetermined to
investigate the variation, retaining every result and making no code change:

| Trial | Domains | Native seconds | Lisp seconds | Ratio |
| --- | ---: | ---: | ---: | ---: |
| repeat 1 | 1 | 0.001051 | 0.000507 | 0.482 |
| repeat 1 | 4 | 0.000420 | 0.000432 | 1.028 |
| repeat 2 | 1 | 0.000692 | 0.000399 | 0.577 |
| repeat 2 | 4 | 0.000469 | 0.000407 | 0.868 |

Logs: `/tmp/rays-set-int-production-repeat-1.log` and
`/tmp/rays-set-int-production-repeat-2.log`. Each trial uses the same median
of three cold cooks and identical allocations as the first run. Both fresh
repeat gates pass the unchanged 2× limit; the initial four-domain timing
spike remains recorded. Set Integer is complete in its separate source commit; B.11 remains
unchecked.

### Shared materialized writes and CSR finite scan

API commit `5e74832a` and implementation `5ec793b7` reuse the existing
owned-storage writer for already materialized cooked host-call arguments.
Focused FlowSOP request 50244 passed tuple/CSR ownership, instance expansion,
source diagnostics, cancellation and producer-before-count error precedence;
the accepted API manifest confirmation also passed. This route does not apply
to Set Transform's direct attribute node. Its unchanged production benchmark
after that change remained 7.224/4.680 times native at one/four domains.

The direct CSR writer used `Array.for_all Float.is_finite`, boxing every
double. A direct bounded scan preserves the same refusal code/message and
removes those allocations. Focused request 88831 exited 0, including the new
empty/finite/signed-zero/owned-storage and first/last NaN/infinity regression.
The earlier new-test `Geometry.empty` typo was corrected to the existing empty
point-geometry constructor before this successful gate.

Command: `opam exec -- ./test_setters.exe --bench-transform`, from
`_build/default/lib/flow_sop`, Apple M1, OCaml 5.3.0, 1,000,000 points,
grain 4096, median of three fresh-session cold cooks. Both benchmark
invocations exited 0. Logs: `/tmp/rays-transform-materialized-bench.log` and
`/tmp/rays-transform-unboxed-scan-bench.log`.

| Scan | Domains | Native seconds | Lisp seconds | Ratio | Native allocated bytes | Lisp allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Boxed | 1 | 0.015810 | 0.114206 | 7.224 | 136,007,824 | 547,510,488 |
| Boxed | 4 | 0.015019 | 0.070282 | 4.680 | 136,013,080 | 544,995,320 |
| Direct | 1 | 0.015856 | 0.071279 | 4.495 | 136,007,824 | 291,510,440 |
| Direct | 4 | 0.014908 | 0.034811 | 2.335 | 136,008,056 | 288,996,584 |

Four-domain allocations count the initial domain only. The direct scan
removes approximately 256 MB of temporary float boxes. Set Transform still
fails the unchanged 2× gate and remains unregistered. Generated CSR arrays
are still copied into owned native storage; no buffer-adoption proof is
claimed here.

### Fresh compiled CSR output storage

The shared attribute writer now proves fresh CSR fields from its existing
strict program graph: only Collect regions, optionally through exact readback,
qualify. It adopts their freshly allocated arrays after full program forcing.
Captured arrays, source queries and other structured expressions retain their
existing boundaries. Offset layout/owner count and cancellation still check;
no public API or SOP-specific recognition was added.

Focused request 79184 exited 0 for FlowSOP and the setter executable. New
Float/Int CSR cases cover empty, single and 32,769-point inputs, exact native
storage/reference/one-eight-domain bytes, immutable source geometry and
nonfinite producer-before-count errors. An initial test used an unsupported
`workspace_node ~reference` argument; the final test reuses the existing
reference lowering entry instead. Log:
`/tmp/rays-csr-owned-output-regression-fixed.log`.

The same quiet `test_setters.exe --bench-transform` command/fixture/machine
as above exited 0 after this change; median three cold sessions:

| Domains | Native seconds | Lisp seconds | Ratio | Native allocated bytes | Lisp allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.016754 | 0.036714 | 2.191 | 136,007,824 | 155,565,160 |
| 4 | 0.015171 | 0.018015 | 1.187 | 136,013,080 | 152,987,896 |

Log: `/tmp/rays-transform-owned-csr-bench.log`. The four-domain gate passes;
one domain still fails the unchanged 2× limit. Set Transform remains pending.
This run also includes the separately validated lazy state/source forcing
changes, so its timing difference is not attributed solely to buffer adoption.

### Set Vector production port

Candidate request 82998 exited 0 for the authoritative `set_vector` recipe
with explicitly loaded pending declarations and unchanged global native
registration. The production `nodes/set_vector.rays` addition and native
registration removal then happened together. Only Set Vector was removed
from the remaining draft; the prelude's shared constant setter macro is
reused. `Sop.Nodes.Set_vector.factory` remains the independent oracle.

The candidate checks all four owners, defaults/non-defaults, required
geometry fixtures, complete factory/runtime metadata, native 4-ULP geometry,
exact strict/reference and 1/4/8-domain bytes at grains 1/97/4096, unchanged
input geometry, every physical field's edit/cache identity, all float
non-finite refusals, wrong input types and name/P validation.

Reviewed manifest digest `74605783d22049a09c4cae625a8af185` changes only
Set Vector's declaration order, native facts and Lisp body/calls markers.
All fields, defaults, ranges, labels, folders and the `value` vector grouping
remain equal. The generated-source expectation in `tools/lisp/test/ml.t`
changes only its catalog hash to
`e019bed37cd3428461ece338de693d9c7fa5597a9bd00fb88a138cd5fc5e9e41`.
Production requests 32725 and 87384 passed the authoritative node recipes;
their aggregate failures were the copied old catalog expectation and a
subsequently corrected shared CSR fixture, respectively. Native request
89432 exited 0, including exact PNGs for 23 SOP graphs at one/four domains.
No rendered golden changed. Fresh combined request 36060 exited 0 for
`@lib/sop/runtest @lib/flow_sop/runtest @lib/sop_catalog/runtest`
`@tools/api_manifest/runtest @test/dependency_gate @tools/lisp/test/runtest`.
The production node recipe, graph/inspector gestures, schema, catalog,
CLI expectation, public API and dependency checks all pass together.

`opam exec -- ./test_setters.exe --bench-vector` from
`_build/default/lib/flow_sop` exited 0. Apple M1, OCaml 5.3.0,
1,000,000 points, grain 4096, median of three fresh-session cold cooks:

| Domains | Native seconds | Lisp seconds | Ratio | Native allocated bytes | Lisp allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.002219 | 0.000468 | 0.211 | 24,007,080 | 24,025,448 |
| 4 | 0.000540 | 0.000478 | 0.885 | 24,007,312 | 24,025,680 |

Four-domain allocations record the initial domain only. Both ratios pass
the unchanged 2× gate. The complete log is
`/tmp/rays-set-vector-production-bench.log`. B.11 stays unchecked while
the remaining whole setter ports are incomplete.

### Set Orient production port

Candidate request 18401 exited 0 for the authoritative `set_orient` recipe
with explicit pending declarations and unchanged native registration.
Production source `nodes/set_orient.rays` and native unregister were then
applied together; only Set Orient was removed from the pending declarations.
`Sop.Nodes.Set_orient.factory` remains the independent native oracle.

The recipe covers defaults and all physical parameter edits, zero and
ordinary quaternions, huge finite components, empty/single/grid/mixed/32,769
point geometry, native 4-ULP comparison, exact reference/strict and
1/4/8-domain bytes at grains 1/97/4096, metadata and cache identity,
non-finite parameter errors and wrong input types. The guarded shared
quaternion helper preserves native overflow and signed-zero behavior.
Reviewed manifest request 60728 and scoped promotion 26512 change only
declaration order, native facts and Lisp body/calls markers, with digest
`80b7a3be25fff983be87f27d139b6b0f`. Parameter labels, defaults, ranges,
slots and operation are unchanged. The rebuilt CLI catalog hash is
`b34b777fce2c4c63cb57b2c159cc08ffc23ad62197f33617aa05d951b72604f9`;
only that generated-source expectation line changes in `tools/lisp/test/ml.t`.
Production request 44932 exited 0 for `@lib/sop/runtest`
`@lib/flow_sop/runtest @lib/sop_catalog/runtest`
`@tools/api_manifest/runtest @test/dependency_gate @tools/lisp/test/runtest`.
This includes native graph-card/inspector parity and gestures for every
physical field, plus 60 quaternion overflow/threshold checks and exact
strict/reference bytes on 32,769 quaternions at one/eight domains.
Native request 7810 exited 0, including exact PNGs for 23 SOP graphs at
one/four domains. No rendered golden changed.

`opam exec -- ./test_setters.exe --bench-orient` from
`_build/default/lib/flow_sop` exited 0. Apple M1, OCaml 5.3.0,
1,000,000 points, grain 4096, median of three fresh-session cold cooks,
quaternion `[1 2 3 -4]`:

| Domains | Native seconds | Lisp seconds | Ratio | Native allocated bytes | Lisp allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.002353 | 0.000610 | 0.259 | 32,007,032 | 32,024,152 |
| 4 | 0.000631 | 0.000699 | 1.108 | 32,007,264 | 32,024,384 |

Four-domain allocations record the initial domain only. Both ratios pass
the unchanged 2× gate. The complete log is
`/tmp/rays-set-orient-production-bench.log`. B.11 stays unchecked while
Set Color and Set Transform remain incomplete.

### Exact integer-column scaling

The typed Packed runner recognizes a three-instruction Collect program that
multiplies one concrete Int column by a constant. It fills the fresh output
in one pass without register-bank copies. Source evaluation, count/type
validation, skip handling and all other programs retain their boundaries;
there is no SOP-specific callback or arithmetic change.

Focused request 83384 exited 0 for `@lib/flow_ir/runtest`
`@lib/flow_sop/runtest` and the setter executable. Regression cases cover
empty/single/32,769 rows, either operand order, zero/negative/extreme signed
constants, native wrapping, strict/reference and 1/4/8-domain exact bytes.
Skipped rows deliberately retain the general block path.

`opam exec -- ./test_packed.exe --bench-int-scale` from
`_build/default/lib/flow_ir`, Apple M1, OCaml 5.3.0, one million indices,
scale 16, median three runs, produced the following quiet measurements.
Both complete logs are retained: `/tmp/rays-int-scale-before.log` and
`/tmp/rays-int-scale-after.log`.

| Version | Domains | Native seconds | Packed seconds | Ratio | Native allocated bytes | Packed allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Before | 1 | 0.004234 | 0.012506 | 2.954 | 8,000,120 | 19,474,864 |
| Before | 4 | 0.003235 | 0.005918 | 1.829 | 8,000,120 | 16,968,656 |
| After | 1 | 0.003426 | 0.007466 | 2.179 | 8,000,120 | 16,009,784 |
| After | 4 | 0.003252 | 0.005497 | 1.690 | 8,000,120 | 16,055,432 |

The real Set Transform benchmark, unchanged fixture and median-three fresh
cold sessions, still fails the one-domain 2× port gate. Quiet log
`/tmp/rays-transform-int-scale-bench.log`:

| Domains | Native seconds | Lisp seconds | Ratio | Native allocated bytes | Lisp allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.015331 | 0.034930 | 2.278 | 136,007,824 | 152,098,752 |
| 4 | 0.014769 | 0.017140 | 1.161 | 136,008,056 | 152,137,632 |

This run includes the separately checked prepared-body reuse. Four-domain
allocations record the initial domain only. Source range arrays still
materialize; Set Transform remains pending and no gate is relaxed.

### Checked implicit integer ranges

The typed Packed runner consumes canonical integer `array/range` sources as
zero-based index views. Existing captured residual aliases are unwrapped;
count expressions execute in source order and use the existing shared
`Op.Private.array_count` validation. Other sources still materialize normally.
The general integer block loader, constant scaling and Cartesian row
projection consume these views; skipped, guarded and Product indices keep
their original semantics. No new value type, instruction or node callback
was introduced. The reviewed checked-length API snapshot is `d16c5f3c`;
its post-promotion API confirmation exited 0.

Focused request 89458 exited 0 for `@lib/flow_ir/runtest`
`@lib/flow_sop/runtest` and the setter executable. New exact reference/native
and 1/4/8-domain cases cover captured/changing counts, empty ranges,
Cartesian and guarded indices, skipped rows, negative and over-limit counts.
Existing mixed borrowed columns, sinks, producer errors, ordered folds and
state rollback checks remain green. This run also includes the separate
explicit-FMA helper wave and Transform's 16-field gesture/refusal extension.
Log: `/tmp/rays-int-range-view-focused.log`.

Quiet same-machine/fixture/median-three benchmarks exited 0. Apple M1,
OCaml 5.3.0, one million rows, grain 4096, fresh cold sessions for the
whole-node cook. Logs: `/tmp/rays-int-range-scale-bench.log` and
`/tmp/rays-transform-int-range-bench.log`.

| Program | Domains | Native seconds | Lisp/Packed seconds | Ratio | Native allocated bytes | Lisp/Packed allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Int scale 16 | 1 | 0.003299 | 0.002475 | 0.750 | 8,000,120 | 8,008,888 |
| Int scale 16 | 4 | 0.003239 | 0.001001 | 0.309 | 8,000,120 | 8,060,200 |
| Set Transform | 1 | 0.015546 | 0.017142 | 1.103 | 136,007,824 | 136,042,464 |
| Set Transform | 4 | 0.014676 | 0.009766 | 0.665 | 136,013,080 | 136,141,560 |

Both whole-node ratios pass the unchanged 2× gate. Removing two intermediate
range arrays eliminates approximately 16 MB from the real cook compared to
the preceding table. Four-domain allocations record the initial domain only.
This is compiler evidence; Set Transform stays pending until its production
switch, manifest/CLI and final native gates pass.

### Set Transform production port

Candidate request 87291 exited 0 for the authoritative `set_transform`
recipe with explicit pending declarations and unchanged native registration.
The source became `nodes/set_transform.rays` together with native unregister;
its body is unchanged. The completed five-setter draft file and its test
loader/dependency were removed. Tests now use the actual embedded library;
`Sop.Nodes.Set_transform.factory` remains the independent native oracle.
Actual embedded production oracle request 2683 also exited 0.

The recipe checks defaults and shear/translation, empty/single/4,225-point
grid/mixed/32,769-point geometry, exact attribute storage/topology/groups,
native 4-ULP geometry and exact strict/reference and 1/4/8-domain bytes at
grains 1/97/4096. Every physical matrix field has native schema/cache keys,
one public miss after edits and warm hits. Affine last-row edits stay valid
at `1e-13`; both signs outside the `1e-12` tolerance and NaN/±Inf in all
16 fields preserve native refusal diagnostics. The native graph/inspector
and all 16 direct gestures passed executable check 93670 after build 21739.
All production gates pass; B.11 stays unchecked while Set Color remains
incomplete.

Read-only manifest review 32749 and its scoped promotion preserve all
16 fields, defaults, labels, ranges, Matrix row folders, slot and operation.
Only declaration order, native facts and Lisp body/calls markers change;
the digest is `49f47151c9ab6a78486b97f3fccfa096`. The rebuilt CLI confirms
catalog hash `352bbc356f6f9db5251ed5a9f579f8f5c529025c90c3903ee183048994fcb771`;
`tools/lisp/test/ml.t` changes only that generated-source expectation line.
The shared FMA aggregate's initial expected catalog/CLI differences were
these pending node snapshots; no math or rendered golden was refreshed.
The settled shared foundation is `650c026c`; its final combined request
54530 exited 0 and kept the Transform snapshots outside that commit.
Production request 44563 exited 0 for `@lib/sop/runtest`
`@lib/flow_sop/runtest @lib/sop_catalog/runtest`
`@tools/api_manifest/runtest @test/dependency_gate @tools/lisp/test/runtest`.
The actual node recipe, five-setter graph/inspector tests, catalog, CLI,
public API and dependency checks pass together; the combined native/Lisp
facts census checks 16 registered Preserved nodes at one/eight domains.
Native request 55836 exited 0, including exact PNGs for 23 SOP graphs at
one/four domains. No rendered golden changed.

`opam exec -- ./test_setters.exe --bench-transform` from
`_build/default/lib/flow_sop` exited 0 after the production switch.
Apple M1, OCaml 5.3.0, 1,000,000 points, grain 4096, median of three
fresh-session cold cooks, matrix shear `m01=-2` and translation `m03=4`:

| Domains | Native seconds | Lisp seconds | Ratio | Native allocated bytes | Lisp allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.015957 | 0.016405 | 1.028 | 136,007,824 | 136,097,008 |
| 4 | 0.015009 | 0.009595 | 0.639 | 136,008,056 | 136,143,576 |

Four-domain allocations record the initial domain only. Both ratios pass
the unchanged 2× gate. The complete production log is
`/tmp/rays-set-transform-production-bench.log`; earlier failing shared
compiler measurements remain above as evidence of the optimization.

### Checked native attribute query foundation

`sop/attr_checked` is a generic query with the same geometry, name, owner and
literal numeric storage selectors as `sop/attr`. Its ordinary record contains
`values` and an exact integer `valid` mask. A row is valid only when every
component is finite. Valid rows retain their float64 bytes, including signed
zero and maximum finite values; invalid rows contain positive zero in every
component. Source arrays stay immutable and returned arrays are owned copies.
The original query, ordinary arithmetic and writers retain finite validation.
No SOP algorithm or selection policy is implemented by this host primitive.

Request 96857 exited 0 for `@lib/flow_sop/runtest @lib/flow/runtest`
`@lib/flow_ir/runtest @lib/flow_web/runtest @tools/api_manifest/runtest`
`@test/dependency_gate`; log `/tmp/rays-checked-attribute-focused4.log`.
Runnable tests cover Float/Vec2/Vec3/Vec4 on point, vertex, primitive and detail,
NaN payloads and both infinities, exact signed-zero/maximum-finite bits, empty
and 32,769-row buffers, owned result mutation, strict/reference parity and
one/eight domains. Authored defnodes write both fields through normal compiled
numeric maps. Named attribute read facts, lazy missing sources, fresh repeated
execution, uncooked source refusal, nonnumeric/computed storage refusal, record
card typing and geometry/name/owner/type gestures pass. Web's existing host
Source refusal remains unchanged; no public OCaml signature or golden changed.

This closes the safe input-classification part of Point Jitter's prerequisite,
not its whole-node gate. Controlled arithmetic overflow diagnostics and a
selected writer that preserves untouched native nonfinite bytes remain needed.
The read-only native audit also found differing policies in other deformers:
Bend accepts clamped infinities in active mask rows, Peak/Mountain report the
last bad index within the earliest failing grain range, and several nodes
preserve invalid unselected coordinates or normals. Those policies belong in
Lisp node bodies and must not be collapsed into this query's validity rule.
No additional whole-node or phase checkbox is marked by this foundation.

### Checked attribute Core and JavaScript host contract

The checked query also has its required `specification/core.md` intrinsic row
and JavaScript immutable-geometry host twin. `tools/core_fixtures.ml` adds 176
native/JavaScript query cases: every owner and all eight requested storage
kinds, missing and wrong storage, finite data, and all four numeric widths with
NaN and both infinities. Twelve additional JavaScript checks require exact
signed-zero, positive-zero replacement, maximum-finite and subnormal values,
integer validity, independent arrays, source immutability and fresh results.
These checks exercise the host protocol directly; the 2D exporter continues to
refuse reached host Sources.

Request 60554 exited 0 for `@tools/lisp/test/runtest`
`@lib/flow_web/runtest @lib/flow_sop/runtest`
`@tools/api_manifest/runtest @test/dependency_gate`. This includes
`web_prims.t` and `core_census.t`, with no fixture or catalog promotion.
Log: `/tmp/rays-checked-attribute-host-contract2.log`. The preceding host-contract
request 59880 also exited 0; request60554 adds the exact JavaScript bit checks.
Checked arithmetic and the selected raw-byte-preserving writer are still
required before Point Jitter or grouped Set Color can pass their whole gates.

### Selected numeric attribute writer Lisp and host contract

The separately reviewed API commit `b9abd271` supplies the generic immutable
selected writer. The Lisp `sop/with_attr` now exposes paired `:selection` and
`:default` rows for Float/Vec2/Vec3/Vec4 storage. Source discovery, frame/state
captures and read facts cover all three write arguments. Matching untouched
native rows retain exact bytes, including NaN payloads, infinities and signed
zero; absent or differently typed storage uses the explicit finite default.
Computed values remain finite checked, even when their selection bit is zero.
This is a general write boundary, with no Set Color or Point Jitter callback.

The shared regression exercises all numeric types and owners, empty and
multi-block writes, full/empty/alternating masks, wrong/missing storage,
invalid counts/bits/defaults, input immutability, captured foreign geometry
masks, changing live selections/defaults, and typed graph edits. A canonical
point-P regression replaces a NaN row while preserving untouched infinity,
signed zero and small finite values at one/eight domains in strict/reference
execution. Constant constructors retain their declared count, unused empty-fill
and producer error behavior before later selection arguments are forced.
The strict writer reuses its existing constant-constructor preparation when
that constructor is directly visible; reference execution retains its ordinary
path.

JavaScript implements the same selected host write. The existing Core fixture
sweep now includes selected writes over raw native nonfinite storage, matching
and missing targets, all owner/type pairs, mask count/bit failures and
nonfinite defaults. Additional exact-bit checks preserve negative zero,
subnormals and untouched nonfinite rows, and verify independent outputs.
The normative primitive census and Flow writer contract describe the keywords.

Validation: shared launcher session `43289` exited 0 for
`@lib/flow_sop/runtest @tools/lisp/test/runtest @lib/flow_web/runtest
@tools/api_manifest/runtest @test/dependency_gate`
(`/tmp/rays-selected-constant-second.log`). After the canonical-P regression,
session `58380` exited 0 for `@lib/flow_sop/runtest`
(`/tmp/rays-selected-positions-final2.log`). The Set Color draft alias, freshly
relinked in `81739`, independently passed its 72 raw-Cd cases, metadata,
errors, cache and graph gates.

This completes a shared language boundary, not another whole-node port.
Set Color remains unregistered: its actual grouped body still bypasses the
visible constant-constructor shortcut and retains the large allocation in a
fresh bounded diagnostic. Its failed full 78-row tables remain above, and
performance tracing continues. Completion stays six of 128 target nodes.

### Selected host dispatch and finite-scan allocation

The actual grouped Set Color body reaches a dynamic host call with an already
computed Vec4 array and a deferred group-mask source. The concrete writer
previously declined that source, then the fallback hydrated arguments and built
a fresh checked attribute node around the dense data. Descriptor trace
`57782` confirmed concrete Vec4/Int data at that new node and no constructor
residual; extending the visible-constructor recognizer could not solve it.

The common `Lower.call` boundary now reuses its existing source hydration in
authored argument order before dispatching a selected write with concrete
numeric values. It checks cancellation before hydration and preserves ordinary
host fallback handling. The selected writer also uses a direct finite scan,
removing one boxed Float callback argument per component. No node-specific
callback, new language operation or public signature was introduced.

The bounded `--trace-grouped` diagnostic uses 65,538 vertex elements on Apple
M1/OCaml 5.3, one domain, grain 4096, cold cooking. Whole allocation fell from
88,515,968 bytes / 0.030771 seconds to 8,942,520 bytes / 0.002896 seconds after
host hydration, then 4,747,928 bytes / 0.002131 seconds after the finite scan.
The standalone writer fell from 6,298,960 to 2,103,504 bytes. These are stage
samples, not million-element medians; commands and full tables stay in the
Set Color section above.

A 32,769-element cooked-branch regression executes the actual deferred-mask
host route at one/eight domains, checks selected output, and bounds cook
allocation below 512 bytes per element so rebuilding and serializing a dense
node cannot silently return. Generic selected/native/reference/error checks,
canonical raw P bytes and all 72 raw-Cd Set Color cases remain green.
Final shared launcher `86627` exited 0 for
`@lib/flow_sop/runtest @lib/flow_sop/set_color_draft`
(`/tmp/rays-selected-host-final.log`); `75121` also passed before the explicit
cancellation guard. `git diff --check` passed.

The complete million-element table `72712` exited 0 with all 78 rows retained.
Grouped allocation is now about 72 MB instead of 1.23 GB, but all 54 grouped
rows remain above the strict 2x speed gate (maximum 10.377x). The other 24 rows
pass that table; earlier failures are retained. Set Color remains unregistered
and the ledger stays six complete ports out of 128. The measured constructor
and selected writer loops remain the next performance work.

### Checked scalar arithmetic implementation

`float/mul_checked` and `float/fma_checked` are generic pure Lisp operators
returning `{value: float, valid: bool}`. Finite results retain exact bits;
overflow returns positive zero and false. Invalid inputs still refuse.
Ordinary multiplication and FMA keep their existing behavior. The compiler
uses ordinary record fields and guarded scalar result/status projections,
with no new Value representation or SOP callback. Metal/WGSL explicitly refuse
this binary64 status contract. Both CPU banks and JavaScript implement it.

The design and complete focused evidence are in
[`checked-arithmetic-design.md`](checked-arithmetic-design.md). Final request
`83484` exited 0 for `@check`, Flow/Graph/IR/GPU/Web/tool Lisp tests and the
dependency gate, including 32,769 byte-exact reference/Core/strict CPU one/eight
and JavaScript rows, scalar/native primitive census, lazy invalid branches,
malformed public-region inputs, captured helpers and graph edits. API review
accepted exactly the three intended interface changes in `c5521938`; the
API confirmation request exited 0 after promotion.

Point Jitter can now express native arithmetic validation and error sequencing
in its Lisp body. Its whole-node semantic and speed gates still have to pass;
no new SOP registration or whole-node completion is claimed here.

### Shared constant vector fill accepted

The generic `array/vec3` and `array/vec4` constructors now grow a validated
sample with overlapping bulk `Array.blit` calls rather than one tiny blit per
row. Regular Flow regression cases cover empty, single, uneven tails and
multi-block lengths through 32,769, including signed zero and subnormal bits.
Focused request 20157 exited 0 for `@lib/flow/runtest`,
`@lib/flow_sop/runtest`, `@lib/flow_sop/set_color_draft` and
`@tools/api_manifest/runtest` (`/tmp/rays-set-color-bulk-constructor-final.log`).

On Apple M1, OCaml 5.3, the bounded 65,538-element single-domain diagnostic
constructor took 0.000256 seconds and 2,097,616 allocated bytes, compared with
0.000675 seconds and the same allocation before the change. These are single
stage samples, not whole-node medians. The complete subsequent 78-row,
median-three Set Color table (request 73970) still failed 54 grouped rows,
with maximum ratio 8.542. Set Color stays unregistered; the port ledger remains
six of 128. Commands and the complete table are retained in the Set Color
section above.

### Shared selected writer copies then overlays

The numeric selected writer now initializes output planes with `Array.copy`
of matching old storage, or `Array.make` of each default component, then
patches only selected rows. Type/count/mask/finite validation still precedes
installation. Untouched raw NaN, infinity and signed-zero bits remain exact;
selected output planes are independent of the input. This is the shared
writer used by direct, deferred and Core host paths, not a Set Color callback.

Focused request 96907 exited 0 for `@lib/flow_sop/runtest` and
`@lib/flow_sop/set_color_draft` (`/tmp/rays-selected-copy-overlay.log`). It
covers numeric kinds and owners, canonical P, invalid inputs, authored source
order, live/cancellation and domain/grain parity, including all 72 Set Color
raw-component cases. At 65,538 Vertex elements the single-domain bounded
whole cook took 0.001537 seconds/4,747,880 allocated bytes, versus the preceding
bulk-constructor snapshot's 0.002053 seconds/4,747,928 bytes. Stage timings are
single samples; the complete table is the performance gate.

The complete median-three, million-point Set Color table, request 83150,
exited 0 (`/tmp/rays-set-color-copy-overlay-bench.log`). All 54 grouped rows
still exceed 2x, plus one Detail row: wrong-float Cd at four domains is 2.359x
(0.000028 native/0.000066 Lisp seconds). Maximum ratio across all 78 rows is
5.676x. Grouped allocation remains about 72 MB. Full rows are retained above;
Set Color stays unregistered and the ledger remains six of 128 ports.

### Delete Edge Group production port

Whole-node completion: `sop/delete_edge_group` now loads its checked Lisp body
from `lib/flow_sop/nodes/delete_edge_group.rays`, using the existing generic
`sop/delete_edge` primitive. The independent `Sop.Nodes.Delete_edge_group`
factory remains the oracle. This is port 7 of 128 (5.47%); the other 121 remain
required, and B.12 remains unchecked until its other six nodes pass.
The promoted catalog digest is `fafaf06693fe67896fcf22b27dbf357b`.
Default, schema, operation/version, slots and literal-name behavior are unchanged.

The authoritative `lib/sop/test_lisp_ports.ml` and regular Flow SOP tests cover
all eight attribute storages and four owners; ordered groups and mixed
polygon/polyline edges; empty, single, 4,225-point grid and 32,769-point geometry;
whitespace, glob-looking and UTF-8 literal names; raw canonical P with NaN
payloads and infinities; immutable input; exact reference/native parity at
1/4/8 domains and grains 1/97/4096; malformed parameters and inputs; cache
miss/hit and relabel identity. Graph tests compare the native and Lisp card and
inspector, edit the name directly, then actually cook the bypassed graph.

All commands use `opam exec -- _build/default/tools/check.exe`:

- `@lib/flow_sop/metadata_ports_draft`: terminal 39424, exit 0;
  `/tmp/rays-metadata-edge-focused2.log`.
- `@tools/api_manifest/runtest @lib/sop_catalog/runtest
  @lib/flow_sop/metadata_ports_draft @test/dependency_gate
  @test/test_workspace_source`: terminal 15070, exit 0;
  `/tmp/rays-delete-edge-group-confirm.log`. Initial production/API runs had
  intended generated differences; those were reviewed and promoted. Shared
  compiler APIs were accepted separately in commit `6bc7f726`.
- `@test/sop_render_parity @test/test_rays_editor`: terminal 40922, exit 0;
  `/tmp/rays-delete-edge-group-native.log`. All 23 native render graphs retain
  identical one/four-domain PNGs; actual editor and workspace tests pass.
- `@lib/sop/runtest @lib/flow_sop/runtest
  @lib/flow_sop/metadata_ports_draft @lib/sop_catalog/runtest
  @tools/api_manifest/runtest @test/test_workspace_source
  @test/dependency_gate`: terminal 4307, exit 0;
  `/tmp/rays-delete-edge-group-final.log`.
- Final actual bypass-cook regression: `@lib/flow_sop/runtest
  @lib/flow_sop/metadata_ports_draft`, terminal 47419, exit 0;
  `/tmp/rays-delete-edge-group-bypass.log`.

Performance command: from `_build/default/lib/flow_sop`,
`opam exec -- ./test_metadata_ports.exe --bench-edge`. Apple M1 arm64,
OCaml 5.3 development build; 1,000,000 points and 998,001 actual quads,
grain 4096. Each row first checks exact native/Lisp output, then takes the
median of three fresh cold sessions; major collection is outside timing.
Allocation counts are bytes on the initial domain (four-domain counts omit
worker allocations). The clean binary was built by terminal 39424, timestamp
2026-10-12 21:26:08. The acceptance run had no concurrent validation or timing
process; terminal 45820, exit 0, `/tmp/rays-delete-edge-group-bench2.log`.
All twelve rows meet the unchanged 2× gate; maximum 1.373×.

| Groups | Name | Domains | Native s | Lisp s | Ratio | Native bytes | Lisp bytes |
|---:|---|---:|---:|---:|---:|---:|---:|
| 0 | edges | 1 | .000022 | .000028 | 1.272 | 6688 | 13448 |
| 0 | edges | 4 | .000041 | .000027 | .657 | 6920 | 13680 |
| 0 | absent | 1 | .000022 | .000028 | 1.272 | 6688 | 13448 |
| 0 | absent | 4 | .000022 | .000030 | 1.355 | 6920 | 13680 |
| 1 | edges | 1 | .000026 | .000036 | 1.373 | 6872 | 13704 |
| 1 | edges | 4 | .000022 | .000030 | 1.370 | 7104 | 13936 |
| 1 | absent | 1 | .000047 | .000029 | .619 | 7008 | 13912 |
| 1 | absent | 4 | .000027 | .000035 | 1.301 | 7240 | 14144 |
| 8 | edges | 1 | .000051 | .000046 | .902 | 8824 | 16664 |
| 8 | edges | 4 | .000033 | .000036 | 1.094 | 9056 | 16896 |
| 8 | absent | 1 | .000029 | .000026 | .901 | 8912 | 16824 |
| 8 | absent | 4 | .000025 | .000032 | 1.288 | 9144 | 17056 |

The earlier run overlapped another agent's compiler validation and is retained
as diagnostic evidence, not acceptance: terminal 16353, exit 0,
`/tmp/rays-delete-edge-group-bench1.log`. Its complete table follows; the
verified contention was the reason for the quiet repeat.

| Groups | Name | Domains | Native s | Lisp s | Ratio | Native bytes | Lisp bytes |
|---:|---|---:|---:|---:|---:|---:|---:|
| 0 | edges | 1 | .000025 | .000031 | 1.250 | 6688 | 13448 |
| 0 | edges | 4 | .000026 | .000028 | 1.083 | 6920 | 13680 |
| 0 | absent | 1 | .000020 | .000034 | 1.702 | 6688 | 13448 |
| 0 | absent | 4 | .000028 | .000032 | 1.136 | 6920 | 13680 |
| 1 | edges | 1 | .000021 | .000031 | 1.477 | 6872 | 13704 |
| 1 | edges | 4 | .000021 | .000032 | 1.523 | 7104 | 13936 |
| 1 | absent | 1 | .000029 | .000027 | .926 | 7008 | 13912 |
| 1 | absent | 4 | .000020 | .000030 | 1.518 | 7240 | 14144 |
| 8 | edges | 1 | .000029 | .000027 | .934 | 8824 | 16664 |
| 8 | edges | 4 | .000024 | .000032 | 1.337 | 9056 | 16896 |
| 8 | absent | 1 | .000028 | .000039 | 1.390 | 8912 | 16824 |
| 8 | absent | 4 | .000034 | .000071 | 2.099 | 9144 | 17056 |

### Validated constant-array storage descriptors (shared foundation)

Focused request **19512** exited 0: `@lib/flow/runtest
@lib/flow_ir/runtest @lib/flow_sop/runtest
@lib/flow_sop/set_color_draft`. Log:
`/tmp/rays-constant-source-focused5.log`. No Set Color registration or
whole-node completion follows from this semantic gate.

The shared compiler retains canonical constant-array count/fill metadata
only when every Core use reaches a cooked storage consumer through simple
aliases. Numeric consumers, ambiguous aliases, record/state/loop-control
uses and returned arrays keep the dense path. Actual constructor count,
storage bounds and used fill validation run at the original Core statement;
count-zero does not validate the unused fill, and later argument failures
retain their order. Source resolution can materialize the same canonical
array when a host needs it. Selected/full writes allocate owned output planes
without a dense intermediate replacement array.

The regular tests cover actual count/bounds/empty/fill diagnostics, simple
aliases, mixed uses and ambiguous aliases, earlier constructor versus later
argument errors, empty/single/32,769 metadata, malformed internal source
fields/types, full/selected Float/Vec storage, exact Int/Text and immutable
native bytes at one/four/eight domains. Existing Set Color raw 72-case,
whole schema/cache/card/gesture and reference/domain checks remain green.

Feature file map: `lib/flow/op.ml` factors the canonical one-element check
and exposes `Op.Private.constant_array_descriptor`; `lib/flow_ir/core_lower.ml`
proves use eligibility and reuses `Source_descriptor`; `core_exec.ml` validates
metadata at the original statement; `lib/flow_sop/attribute_kernel.ml` and
`lower.ml` resolve or consume typed metadata at the existing writer boundary.
Regular regressions live in `lib/flow/test_op.ml`,
`lib/flow_ir/test_core_lower.ml` and `lib/flow_sop/test_attribute_kernel.ml`.
The public signatures were accepted with API-only commit **6bc7f726**;
`specification/core.md` records the source/error-order contract. Temporary
Point Jitter allocation hooks were removed from source before clean Set Color
relink; no performance claim uses an instrumented executable.

Measurement request **21014** exited 0 on the clean executable linked by
**90154** (`@lib/flow_sop/set_color_draft`, exit 0). The complete quiet table
uses median three fresh Sessions and cold cooks, one/four domains, grain
4096, one million ordinary-owner elements, and one Detail element on a
million-point input. Allocations are measured on the initial domain.
All 78 rows are retained below. **49 rows still exceed 2×**, with maximum
**3.414×**: all 18 selected rows, all 18 empty-group rows, 10 full-group rows
and three Detail microcases. Set Color remains unregistered and incomplete.
Full log: `/tmp/rays-set-color-constant-descriptor-bench.log`.

The bounded 65,538-Vertex diagnostic confirms the actual wrapper now avoids
the dense replacement: whole cold strict cook allocation falls from
4,747,880 B to **2,653,672 B**. The independent dense constructor remains
2,097,616 B. The group source uses 525,128 B and concrete selected writer
2,103,136 B. Single-sample wall times were respectively 0.001050 s for whole
cook, 0.000274 s for constructor, 0.000421 s for group source and 0.000751 s
for concrete writer. This diagnostic overlapped validation, so its wall times
are not quiet throughput acceptance. Log:
`/tmp/rays-set-color-constant-descriptor-stages.log`.

In the complete quiet table, grouped million-row allocation drops from about
72 MB in the copied-plane baseline to about **40 MB**, including the 32 MB
owned output and 8 MB selection mask. The remaining whole-node speed gate
is not satisfied by this allocation reduction. All previous tables remain
in the Set Color history above.

| Owner | Elements | Cd | Group | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---|---|---:|---:|---:|---:|---:|---:|
| Point | 1000000 | absent | all | 1 | 0.001364 | 0.000649 | 0.476 | 32010016 | 32032200 |
| Point | 1000000 | absent | all | 4 | 0.001335 | 0.000668 | 0.500 | 32010248 | 32032432 |
| Point | 1000000 | absent | selected | 1 | 0.003750 | 0.012803 | 3.414 | 32010432 | 40030352 |
| Point | 1000000 | absent | selected | 4 | 0.003786 | 0.009956 | 2.630 | 32010664 | 40086168 |
| Point | 1000000 | absent | full | 1 | 0.004875 | 0.013712 | 2.813 | 32010424 | 40030408 |
| Point | 1000000 | absent | full | 4 | 0.005092 | 0.009750 | 1.915 | 32010656 | 40076976 |
| Point | 1000000 | absent | empty | 1 | 0.002995 | 0.008771 | 2.929 | 32010424 | 40030344 |
| Point | 1000000 | absent | empty | 4 | 0.002870 | 0.008335 | 2.904 | 32010656 | 40083744 |
| Point | 1000000 | vec4 | all | 1 | 0.001177 | 0.000714 | 0.607 | 32010168 | 32033504 |
| Point | 1000000 | vec4 | all | 4 | 0.001210 | 0.000661 | 0.546 | 32010400 | 32033736 |
| Point | 1000000 | vec4 | selected | 1 | 0.004409 | 0.012589 | 2.855 | 32010776 | 40030688 |
| Point | 1000000 | vec4 | selected | 4 | 0.004312 | 0.010275 | 2.383 | 32011008 | 40078776 |
| Point | 1000000 | vec4 | full | 1 | 0.005388 | 0.014324 | 2.658 | 32010768 | 40030680 |
| Point | 1000000 | vec4 | full | 4 | 0.005728 | 0.009960 | 1.739 | 32011000 | 40077400 |
| Point | 1000000 | vec4 | empty | 1 | 0.003392 | 0.009382 | 2.766 | 32010768 | 40030680 |
| Point | 1000000 | vec4 | empty | 4 | 0.003917 | 0.009583 | 2.447 | 32011000 | 40067992 |
| Point | 1000000 | wrong_float | all | 1 | 0.001308 | 0.000718 | 0.549 | 32010168 | 32047240 |
| Point | 1000000 | wrong_float | all | 4 | 0.001336 | 0.000674 | 0.505 | 32010400 | 32033736 |
| Point | 1000000 | wrong_float | selected | 1 | 0.004006 | 0.012024 | 3.001 | 32010600 | 40030696 |
| Point | 1000000 | wrong_float | selected | 4 | 0.003843 | 0.009723 | 2.530 | 32010832 | 40078240 |
| Point | 1000000 | wrong_float | full | 1 | 0.004960 | 0.013824 | 2.787 | 32010592 | 40030688 |
| Point | 1000000 | wrong_float | full | 4 | 0.005019 | 0.009469 | 1.887 | 32010824 | 40078000 |
| Point | 1000000 | wrong_float | empty | 1 | 0.002899 | 0.008657 | 2.986 | 32010592 | 40030624 |
| Point | 1000000 | wrong_float | empty | 4 | 0.002858 | 0.008238 | 2.882 | 32010824 | 40083080 |
| Vertex | 1000000 | absent | all | 1 | 0.001199 | 0.000659 | 0.550 | 32010024 | 32032208 |
| Vertex | 1000000 | absent | all | 4 | 0.001220 | 0.000649 | 0.532 | 32010256 | 32032440 |
| Vertex | 1000000 | absent | selected | 1 | 0.003740 | 0.011960 | 3.198 | 32010440 | 40030352 |
| Vertex | 1000000 | absent | selected | 4 | 0.003755 | 0.010032 | 2.672 | 32010672 | 40077704 |
| Vertex | 1000000 | absent | full | 1 | 0.004954 | 0.013687 | 2.763 | 32010424 | 40030344 |
| Vertex | 1000000 | absent | full | 4 | 0.004828 | 0.009649 | 1.998 | 32010656 | 40076968 |
| Vertex | 1000000 | absent | empty | 1 | 0.002850 | 0.008743 | 3.068 | 32010432 | 40030408 |
| Vertex | 1000000 | absent | empty | 4 | 0.002884 | 0.008224 | 2.852 | 32010664 | 40083576 |
| Vertex | 1000000 | vec4 | all | 1 | 0.001232 | 0.000655 | 0.532 | 32010176 | 32047256 |
| Vertex | 1000000 | vec4 | all | 4 | 0.001193 | 0.000691 | 0.579 | 32010408 | 32033752 |
| Vertex | 1000000 | vec4 | selected | 1 | 0.004293 | 0.012472 | 2.905 | 32010784 | 40030624 |
| Vertex | 1000000 | vec4 | selected | 4 | 0.004293 | 0.011211 | 2.611 | 32011016 | 40074944 |
| Vertex | 1000000 | vec4 | full | 1 | 0.005697 | 0.014224 | 2.497 | 32010768 | 40030616 |
| Vertex | 1000000 | vec4 | full | 4 | 0.005494 | 0.009946 | 1.810 | 32011000 | 40077552 |
| Vertex | 1000000 | vec4 | empty | 1 | 0.003380 | 0.009220 | 2.728 | 32010776 | 40030616 |
| Vertex | 1000000 | vec4 | empty | 4 | 0.003370 | 0.008831 | 2.621 | 32011008 | 40083752 |
| Vertex | 1000000 | wrong_float | all | 1 | 0.001269 | 0.000673 | 0.530 | 32010176 | 32047256 |
| Vertex | 1000000 | wrong_float | all | 4 | 0.001274 | 0.000675 | 0.530 | 32010408 | 32033752 |
| Vertex | 1000000 | wrong_float | selected | 1 | 0.003782 | 0.011941 | 3.157 | 32010608 | 40030696 |
| Vertex | 1000000 | wrong_float | selected | 4 | 0.003734 | 0.010061 | 2.694 | 32010840 | 40077520 |
| Vertex | 1000000 | wrong_float | full | 1 | 0.005204 | 0.014298 | 2.748 | 32010592 | 40030624 |
| Vertex | 1000000 | wrong_float | full | 4 | 0.005144 | 0.009661 | 1.878 | 32010824 | 40084160 |
| Vertex | 1000000 | wrong_float | empty | 1 | 0.003071 | 0.008717 | 2.838 | 32010600 | 40030624 |
| Vertex | 1000000 | wrong_float | empty | 4 | 0.002876 | 0.008234 | 2.863 | 32010832 | 40083256 |
| Primitive | 1000000 | absent | all | 1 | 0.001376 | 0.000651 | 0.473 | 32010040 | 32045976 |
| Primitive | 1000000 | absent | all | 4 | 0.001242 | 0.000669 | 0.539 | 32010272 | 32032472 |
| Primitive | 1000000 | absent | selected | 1 | 0.003911 | 0.012109 | 3.096 | 32010456 | 40030376 |
| Primitive | 1000000 | absent | selected | 4 | 0.003873 | 0.009651 | 2.492 | 32010688 | 40078408 |
| Primitive | 1000000 | absent | full | 1 | 0.004862 | 0.013613 | 2.800 | 32010432 | 40030416 |
| Primitive | 1000000 | absent | full | 4 | 0.004851 | 0.009999 | 2.061 | 32010664 | 40076544 |
| Primitive | 1000000 | absent | empty | 1 | 0.003009 | 0.009091 | 3.021 | 32010440 | 40030352 |
| Primitive | 1000000 | absent | empty | 4 | 0.002882 | 0.008259 | 2.866 | 32010672 | 40082720 |
| Primitive | 1000000 | vec4 | all | 1 | 0.001174 | 0.000671 | 0.571 | 32010200 | 32047296 |
| Primitive | 1000000 | vec4 | all | 4 | 0.001426 | 0.000723 | 0.507 | 32010432 | 32033792 |
| Primitive | 1000000 | vec4 | selected | 1 | 0.005060 | 0.012669 | 2.504 | 32010808 | 40030720 |
| Primitive | 1000000 | vec4 | selected | 4 | 0.004555 | 0.010465 | 2.298 | 32011040 | 40078040 |
| Primitive | 1000000 | vec4 | full | 1 | 0.005411 | 0.014509 | 2.681 | 32010784 | 40030696 |
| Primitive | 1000000 | vec4 | full | 4 | 0.005345 | 0.009973 | 1.866 | 32011016 | 40077024 |
| Primitive | 1000000 | vec4 | empty | 1 | 0.003335 | 0.009173 | 2.751 | 32010792 | 40030632 |
| Primitive | 1000000 | vec4 | empty | 4 | 0.003400 | 0.009003 | 2.648 | 32011024 | 40096664 |
| Primitive | 1000000 | wrong_float | all | 1 | 0.001290 | 0.000728 | 0.564 | 32010200 | 32047296 |
| Primitive | 1000000 | wrong_float | all | 4 | 0.001233 | 0.000798 | 0.647 | 32010432 | 32033792 |
| Primitive | 1000000 | wrong_float | selected | 1 | 0.003755 | 0.012142 | 3.234 | 32010632 | 40030664 |
| Primitive | 1000000 | wrong_float | selected | 4 | 0.003773 | 0.009850 | 2.611 | 32010864 | 40078384 |
| Primitive | 1000000 | wrong_float | full | 1 | 0.004868 | 0.013834 | 2.842 | 32010608 | 40030640 |
| Primitive | 1000000 | wrong_float | full | 4 | 0.004900 | 0.009404 | 1.919 | 32010840 | 40077072 |
| Primitive | 1000000 | wrong_float | empty | 1 | 0.002967 | 0.008902 | 3.000 | 32010616 | 40030640 |
| Primitive | 1000000 | wrong_float | empty | 4 | 0.002912 | 0.008223 | 2.824 | 32010848 | 40083072 |
| Detail | 1 | absent | all | 1 | 0.000030 | 0.000039 | 1.302 | 10064 | 26360 |
| Detail | 1 | absent | all | 4 | 0.000027 | 0.000071 | 2.614 | 10296 | 27248 |
| Detail | 1 | vec4 | all | 1 | 0.000020 | 0.000050 | 2.500 | 10216 | 27088 |
| Detail | 1 | vec4 | all | 4 | 0.000025 | 0.000052 | 2.076 | 10448 | 27976 |
| Detail | 1 | wrong_float | all | 1 | 0.000025 | 0.000044 | 1.762 | 10216 | 27088 |
| Detail | 1 | wrong_float | all | 4 | 0.000026 | 0.000042 | 1.615 | 10448 | 27976 |

### Ordinary group-mask byte unpack (shared foundation)

`Group_kernel.read` now borrows immutable ordinary-group packed bytes once,
expands each byte into an owned integer mask, retains zero runs from
`Array.make`, and uses standard `Array.fill` for full bytes. Edge reads keep
the existing path. Group names, missing-group errors, owner cardinality,
explicit traversal order and source identity are unchanged. Every cooked
`sop/group` source uses this shared resolver in compiled/reference/callable
paths; no node-specific callback was added and no API changed.

Focused **15206** exited 0 with `@lib/flow_sop/runtest` and
`@lib/flow_sop/set_color_draft`. The regular group test covers empty and
tail counts 0/1/7/8/9/63/64/65/32,769, Point/Vertex/Primitive owners, reversed
explicit order, returned-array ownership and unchanged original bits/order/
data identity at one/four/eight domains. All existing Edge, raw 72-case Color,
schema/cache/UI and domain/grain tests pass. Log:
`/tmp/rays-group-byte-mask-focused.log`. `git diff --check` passes.

The direct `test_set_color.exe --bench-mask` attribution uses a million
Vertex elements, matching existing Float4 Cd, selected/full/empty groups,
one/four domains, grain 4096, median three freshly allocated results with
major GC before each sample. Mask resolution and descriptor selected-writer
execution are measured separately; these are direct host calls, not whole
Session cooks. Allocation counts are from the initial domain. Both runs
were quiet: baseline **22026** and after **50060**, both exit 0. Logs:
`/tmp/rays-color-mask-baseline.log`, `/tmp/rays-color-mask-after.log`.

Mask resolution drops from about 5.1–5.5 ms to 2.0–2.7 ms for selected/full
groups and to 1.1 ms for empty groups, while its required owned integer mask
remains about 8 MB. The separate writer remains material. This is a measured
shared cut; the unchanged whole-node 2× gate needs a fresh complete Color
table and Set Color remains unregistered. The preceding descriptor 78-row
table remains intact.

| Group | Domains | Stage | Before seconds | After seconds | Before bytes | After bytes |
|---|---:|---|---:|---:|---:|---:|
| selected | 1 | group_source | 0.005518 | 0.002695 | 8000968 | 8000936 |
| selected | 1 | descriptor_selected_writer | 0.007876 | 0.007547 | 32002272 | 32002272 |
| selected | 4 | group_source | 0.005125 | 0.001964 | 8001200 | 8001168 |
| selected | 4 | descriptor_selected_writer | 0.005012 | 0.005242 | 32049376 | 32050728 |
| full | 1 | group_source | 0.005069 | 0.002594 | 8000968 | 8000936 |
| full | 1 | descriptor_selected_writer | 0.009359 | 0.009158 | 32002272 | 32002272 |
| full | 4 | group_source | 0.005091 | 0.002580 | 8001200 | 8001168 |
| full | 4 | descriptor_selected_writer | 0.005066 | 0.004911 | 32049112 | 32050392 |
| empty | 1 | group_source | 0.005220 | 0.001121 | 8000968 | 8000936 |
| empty | 1 | descriptor_selected_writer | 0.004240 | 0.004015 | 32002272 | 32002272 |
| empty | 4 | group_source | 0.005114 | 0.001124 | 8001200 | 8001168 |
| empty | 4 | descriptor_selected_writer | 0.003872 | 0.003684 | 32046960 | 32055440 |

### Typed numeric helpers stay unboxed (shared foundation)

The preceding unregistered Point Jitter draft section retains the detailed
allocation-attribution diagnostics. Native-object inspection identified an
actual 16-byte float allocation
on both branches of the typed runner's numeric register reader. Every guard
test called that reader. The minimal generic change forces scalar reader,
arithmetic and checked-projection helpers inline, with an inline finite
predicate retaining the exact existing error code/message. Guard traversal,
integer banks, checked arithmetic order/opacity, selected errors, gather
ordering and source preparation are unchanged. The rebuilt ARM guard predicate
now loads or converts directly into a float register and compares it without
allocating a float box. Focused request 59212 exited 0 for the full Flow IR
suite and Point Jitter recipe, including all existing lazy/finite/status,
signed-zero, integer, gather, cause, domain and grain proofs
(`/tmp/rays-point-jitter-unboxed-focused.log`).

The before table is quiet request 8238
(`/tmp/rays-point-jitter-bench-first1.log`):

| Mode | Domains | Native seconds | Lisp seconds | Ratio | Native allocated bytes | Lisp allocated bytes |
|---|---:|---:|---:|---:|---:|---:|
| Defaults, no group | 1 | 0.021372 | 1.220160 | 57.091× | 72,015,704 | 4,678,113,184 |
| Defaults, no group | 4 | 0.008722 | 0.437272 | 50.134× | 35,885,280 | 1,431,068,528 |
| Selected group, mask/ID/pscale | 1 | 0.023941 | 1.505549 | 62.886× | 48,016,440 | 4,919,631,312 |
| Selected group, mask/ID/pscale | 4 | 0.007411 | 0.536836 | 72.438× | 30,171,592 | 1,531,346,296 |

Quiet request 28993 repeated those same four predetermined rows, with the
same median-three cold-cook harness and native/reference preflights, and exited
0 (`/tmp/rays-point-jitter-unboxed-bench-first.log`). Both runs use Apple M1,
OCaml 5.3.0 dev profile, a real 1,000,000-point/998,001-quad grid, domains 1/4
and grain 4096. Allocations at four domains cover the initial domain only.
All output checks pass. The after table is:

| Mode | Domains | Native seconds | Lisp seconds | Ratio | Native allocated bytes | Lisp allocated bytes |
|---|---:|---:|---:|---:|---:|---:|
| Defaults, no group | 1 | 0.021278 | 0.779768 | 36.646× | 72,015,704 | 612,604,368 |
| Defaults, no group | 4 | 0.010221 | 0.295018 | 28.864× | 36,675,288 | 358,899,544 |
| Selected group, mask/ID/pscale | 1 | 0.024053 | 1.005076 | 41.786× | 48,016,440 | 535,779,504 |
| Selected group, mask/ID/pscale | 4 | 0.009449 | 0.370817 | 39.244× | 31,062,944 | 354,419,112 |

The measured allocation cut is substantial, but all four rows still fail the
unchanged 2× gate. The original failed table remains above; the broader table
stays held. There is no node-specific optimization, public API change,
registration or whole-port performance claim.

### Numeric gather compiler foundation accepted

Invariant Int/Float/Vec2/Vec3/Vec4 `array/nth` now lowers through typed table
preparation and exact indexed reads in the existing compiler and CPU runner.
Tables remain independent of iteration counts. The shared primitive, graph
projection, reference semantics and existing error/ownership boundaries remain
the contract. JavaScript regions, the production runtime, worker transport and
actual exports carry exact numeric tables; Metal and WGSL explicitly refuse
these CPU operations. Reviewed public APIs were accepted in `6bc7f726`.

The detailed coverage, raw command references and complete ten-row native-loop
comparison are in `gather-validation.md`. Combined request 1029 passed the
IR/Web/Graph/GPU/tools/dependency/API gates; 40365 passed the expanded non-cram
proofs, and follow-up 11963 passed Flow and corrected actual exporter/CLI crams.
Source aliases and earlier/later failures retain live reference concretization
order, including unused let bindings. Exact integer exports above 2^53 execute
through real frames and one/eight-worker pools.

Quiet benchmark 45613 retains all ten slow rows (2.028–11.324× simple native
indexed loops). These establish a measured baseline, not a whole-node speed
qualification. No SOP port follows from this feature. C.2 remains unchecked
because Name From Groups still requires the separately specified Text leaf
extension; B.13/B.14 and all other original port gates remain required.

### Rename Edge Group production port

The authoritative declaration is now `nodes/rename_edge_group.rays`, with the
unchanged `from`/`into` Text defaults and labels, one required geometry slot,
and the generic `sop/rename_edge` body. The native registration is removed;
`Sop.Nodes.Rename_edge_group.factory` and `Geometry.rename_edge_group` remain
independent test oracles. This metadata-only operation reads literal edge-group
names and renames one ordered group. It does not read or change float data.
Equal names, missing sources, existing destinations and blank names retain
native code/message/cause and conflict-before-missing-source order; there is
no trimming or pattern interpretation.

The whole-port function in `lib/sop/test_lisp_ports.ml` loads actual embedded
production sources. Defaults and every physical parameter, empty/single/4,225
grid/mixed/32,769 inputs, reference and compiled cooks, domains 1/4/8, grains
1/97/4096, exact payload bytes/errors, immutable inputs, schema/operation/key,
public cache misses/hits, relabel identity and wrong input/parameter refusals
pass. The shared edge tests additionally cover all attribute storage types
and owners, group/attribute order, unusual literal names, raw NaN payloads,
infinities, direct graph edits, card/inspector parity and actual bypass cooks.
The preserved-facts sweep now supplies the default edge group rather than
excluding the newly precise declaration: 18 registered Preserved nodes pass
at one/eight domains.

Focused request 31093 exited 0 for `@lib/sop/runtest
@lib/flow_sop/runtest @lib/flow_sop/metadata_ports_draft
@lib/sop_catalog/runtest @test/dependency_gate`
(`/tmp/rays-rename-edge-focused3.log`). Earlier 83234/59840 failures identified
and corrected a test field accessor, the intended manifest promotion and the
missing default group in the facts fixture; the whole-port recipe already
passed in 59840. Promoted manifest digest:
`536ca411537394f6c4f3977b72a028d0`. The actual generated CLI catalog baseline
is `5005be4a79464f0cd37f03e63f6866439cbda8f6283609ac71749748b61bdd3d`;
follow-up 11963 passed its crams and Flow tests.

Full `@runtest-native`, `@test/test_workspace_source` and
`@tools/api_manifest/runtest` request 30232 exited 0
(`/tmp/rays-rename-edge-native.log`). This includes all native rendering,
editor/host/presentation tests, the 23 SOP graph one/four-domain PNG comparisons,
and real workspace source save/reopen/reload. No golden changed. This complete
native run also supplies the full-suite follow-up for Delete Edge Group, whose
earlier port evidence recorded focused native checks.

Both timing runs use Apple M1, OCaml 5.3.0 dev profile, a real million-point
grid with 998,001 quads, grain 4096 and domains 1/4. All twelve configurations
have a native/Lisp byte-or-error preflight before timing. Session creation and
close and full-major GC are outside each timed interval; allocations at four
domains cover only the initial domain. The median of three samples is reported.
Missing-source cooks are intentionally retained. Ratios use unrounded times.

The original quiet single-cook measurement, request 89904, exited 0 and is
retained in full (`/tmp/rays-rename-edge-bench.log`). Its 8-group existing-source
four-domain row failed the unchanged 2× gate:

| Groups | Source | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---:|---|---:|---:|---:|---:|---:|---:|
| 0 | edges | 1 | 0.000022 | 0.000025 | 1.129× | 6024 | 11944 |
| 0 | edges | 4 | 0.000022 | 0.000032 | 1.467× | 6256 | 12176 |
| 0 | absent | 1 | 0.000026 | 0.000023 | 0.890× | 6032 | 11952 |
| 0 | absent | 4 | 0.000021 | 0.000026 | 1.239× | 6264 | 12184 |
| 1 | edges | 1 | 0.000052 | 0.000031 | 0.596× | 7480 | 14408 |
| 1 | edges | 4 | 0.000024 | 0.000036 | 1.510× | 7712 | 14640 |
| 1 | absent | 1 | 0.000022 | 0.000028 | 1.272× | 6160 | 12152 |
| 1 | absent | 4 | 0.000022 | 0.000028 | 1.272× | 6392 | 12384 |
| 8 | edges | 1 | 0.000026 | 0.000030 | 1.145× | 9488 | 17424 |
| 8 | edges | 4 | 0.000024 | 0.000063 | **2.614×** | 9720 | 17656 |
| 8 | absent | 1 | 0.000023 | 0.000037 | 1.608× | 7056 | 13552 |
| 8 | absent | 4 | 0.000021 | 0.000032 | 1.523× | 7288 | 13784 |

These operations take microseconds, so the test harness adds a longer fixed
measurement: each sample times 1,000 separately created, fresh cold Sessions,
one cook in each Session, divided by 1,000. It never reuses a warm Session hit.
No production implementation changed between runs. This measures amortized
cold-cook throughput rather than isolated post-GC latency, reducing clock and
scheduling sensitivity while preserving the workload and strict bound. Build
32834 and quiet benchmark 34513 exited 0; all twelve predetermined rows pass,
maximum 1.858× (`/tmp/rays-rename-edge-batch-build.log`,
`/tmp/rays-rename-edge-batch-bench.log`). This is the acceptance timing table;
the failed isolated-latency result above remains part of the evidence.

| Groups | Source | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---:|---|---:|---:|---:|---:|---:|---:|
| 0 | edges | 1 | 0.000003 | 0.000004 | 1.510× | 5928 | 11848 |
| 0 | edges | 4 | 0.000003 | 0.000004 | 1.373× | 6160 | 12080 |
| 0 | absent | 1 | 0.000003 | 0.000005 | 1.858× | 5936 | 11856 |
| 0 | absent | 4 | 0.000003 | 0.000006 | 1.696× | 6168 | 12088 |
| 1 | edges | 1 | 0.000004 | 0.000006 | 1.566× | 7384 | 14312 |
| 1 | edges | 4 | 0.000004 | 0.000006 | 1.489× | 7616 | 14544 |
| 1 | absent | 1 | 0.000003 | 0.000005 | 1.802× | 6064 | 12056 |
| 1 | absent | 4 | 0.000003 | 0.000005 | 1.702× | 6296 | 12288 |
| 8 | edges | 1 | 0.000005 | 0.000007 | 1.459× | 9400 | 17336 |
| 8 | edges | 4 | 0.000005 | 0.000008 | 1.640× | 9632 | 17568 |
| 8 | absent | 1 | 0.000004 | 0.000005 | 1.468× | 6968 | 13464 |
| 8 | absent | 4 | 0.000004 | 0.000007 | 1.703× | 7200 | 13696 |

Reproduce timings from `_build/default/lib/flow_sop` with
`opam exec -- ./test_metadata_ports.exe --bench-rename-edge` and
`opam exec -- ./test_metadata_ports.exe --bench-rename-edge-batch` after linking
through the shared check launcher and draining competing CPU work. This port
brings the completed whole-node ledger to eight of 128. B.12 stays unchecked
until its other five metadata ports pass their own full recipes.

### Typed Collect guards reuse lazy active spans (shared prerequisite)

The typed CPU runner now reuses identical guard-list spans within a single
Collect block, excluding gather programs. The cache key includes the guard
list and exact interval, so nested and truncated invocations stay distinct.
First use retains the original predicate scan and executes each selected body
immediately; only a successfully completed invocation publishes its spans.
There is no eager evaluation of later predicates. Each block owns at most the
program's instruction count (64) cache entries, each bounded by the 1,024-lane
block, and discards the cache before the next block. Reducers, scans, folds,
gather preparation and lane-major gather execution retain their old routes.

Focused request 68597 exited 0 for `@lib/flow_ir/runtest
@lib/flow_sop/point_jitter_draft
_build/default/lib/flow_sop/test_point_jitter.exe`
(`/tmp/rays-point-jitter-guard-cache-focused3.log`). The added 32,769-row
regular regression compares strict execution with reference bytes at times
0, 0.25 and 1024.5, domains 1/4/8, both flat and deliberately nested guard
wrappers. It covers changing block predicates, truncated spans, checked
result/status projections, signed zero and an untaken error. Existing exact
integer, lazy diagnostic, gather and Point Jitter selected-error proofs pass.

Quiet first-four request 74683 exited 0 after every native/reference/strict
preflight, using the freshly linked 68597 binary. The fixture and protocol
match the earlier unboxed-helper table: Apple M1, OCaml 5.3.0 dev profile,
one million actual grid points and 998,001 quads, grain 4096, median of three
fresh-session cold cooks, domains 1/4. Four-domain allocation counters cover
only the initial domain. Log:
`/tmp/rays-point-jitter-guard-cache-bench-first.log`.

| Mode | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---:|---:|---:|---:|---:|
| defaults | 1 | 0.021215 | 0.579217 | **27.302×** | 72015704 | 617403680 |
| defaults | 4 | 0.007088 | 0.243064 | **34.293×** | 36477808 | 363725112 |
| selected optional inputs | 1 | 0.024350 | 0.697501 | **28.645×** | 48016440 | 732659608 |
| selected optional inputs | 4 | 0.007702 | 0.288948 | **37.515×** | 30270520 | 405668808 |

The corresponding earlier Lisp times were 0.779768, 0.295018, 1.005076 and
0.370817 seconds (request 28993, retained above). The cache cuts whole-cook
time by about 18–31%, but adds span storage: selected optional one-domain
allocation rises from 535,779,504 to 732,659,608 bytes. All four unchanged
2× gates still fail. This is shared execution evidence, not a Point Jitter
port acceptance; no registration, native removal or broader timing claim.

### Reversible Text byte transport prerequisite

The shared JSON/JavaScript literal printer and byte-oriented runtime boundaries
now preserve native invalid UTF-8 bytes with reversible isolated low surrogates.
Valid Unicode, embedded NUL, BOM and literal replacement characters retain
their identities; worker cloning preserves the representation. The printer
reuses the standard library decoder through a private module. No public API
shape or SOP primitive changes.

Dedicated codec proof 9358 passed, then exposed 15 existing primitive fixtures
whose native JSON writer had replaced byte-reversed Unicode with replacement
characters. The fixture writer now shares the same reversible transport; all
original semantic cases remain. Follow-up 56576 exited 0 for Web/tools/API and
dependency gates, including 17,552 primitive cases, all byte-value/malformed
UTF-8 round trips, native repr, one/eight-worker transport, existing web goldens
and actual frame checks. Detailed evidence and limitations are recorded in
`text-byte-transport.md`; log `/tmp/rays-text-codec-final.log`.

This is a prerequisite for the required Text kernel leaf extension. It does
not complete Text gather, Name From Groups or C.2.

### Selected mask validation uses an inline scan

The shared `Attribute_kernel.write_selected` scans integer selections with
a local while loop, reading each value once and stopping at the first value
other than zero or one. Destination/value cardinality and selection length
checks still precede this scan, which still precedes finite-value validation
and output allocation. Dense, validated constant-descriptor and cooked-source
callers use the same boundary, as do the native host fixtures for JavaScript
twins. No API or selection semantics change.

Focused **40734** exited 0 with `@lib/flow_sop/runtest` and
`@lib/flow_sop/set_color_draft`. The regular trust-boundary test includes a
last-element invalid mask together with a NaN replacement, preserving
`E_ATTR_SELECTION` priority over `E_NONFINITE`. Existing empty/count/type,
raw nonfinite untouched storage, cancellation, strict/reference, owner,
immutable input, domain/grain and cache/UI checks remain green. Fresh current
Color semantic/relink **1178** also exited 0. Logs:
`/tmp/rays-selected-mask-inline-focused.log`,
`/tmp/rays-selected-mask-inline-current.log`. `git diff --check` passes.

Quiet direct host attribution **41442** exited 0. The complete 24-row
comparison below retains baseline **55274** and uses the same million-Vertex
fixture, matching old Float4 Cd, one/four domains, grain 4096 and median
three samples with major GC before each sample. This separately measures
mask resolution, the actual validation scan, copying owned old planes and
the complete descriptor writer; allocation counts are initial-domain only.
Validation falls from roughly 2.0–2.7 ms to 0.7–0.8 ms. Selected/full/empty
writer times at one domain fall from 7.640/9.232/4.151 ms to
5.379/8.027/2.478 ms. Logs: `/tmp/rays-color-writer-attribution.log`,
`/tmp/rays-color-writer-inline-attribution.log`.

| Group | Domains | Stage | Before seconds | After seconds | Before bytes | After bytes |
|---|---:|---|---:|---:|---:|---:|
| selected | 1 | group_source | 0.001981 | 0.001938 | 8000936 | 8000936 |
| selected | 1 | selection_validation | 0.002668 | 0.000828 | 224 | 176 |
| selected | 1 | owned_plane_copy | 0.001357 | 0.002093 | 32000248 | 32000248 |
| selected | 1 | descriptor_selected_writer | 0.007640 | 0.005379 | 32002272 | 32002224 |
| selected | 4 | group_source | 0.002185 | 0.001925 | 8006192 | 8001168 |
| selected | 4 | selection_validation | 0.002676 | 0.000802 | 456 | 408 |
| selected | 4 | owned_plane_copy | 0.001222 | 0.001153 | 32000480 | 32000480 |
| selected | 4 | descriptor_selected_writer | 0.005457 | 0.003113 | 32013640 | 32049608 |
| full | 1 | group_source | 0.002663 | 0.002514 | 8000936 | 8000936 |
| full | 1 | selection_validation | 0.002022 | 0.000828 | 224 | 176 |
| full | 1 | owned_plane_copy | 0.001316 | 0.001173 | 32000248 | 32000248 |
| full | 1 | descriptor_selected_writer | 0.009232 | 0.008027 | 32002272 | 32002224 |
| full | 4 | group_source | 0.002522 | 0.002498 | 8001168 | 8001168 |
| full | 4 | selection_validation | 0.001894 | 0.000802 | 456 | 408 |
| full | 4 | owned_plane_copy | 0.001157 | 0.001216 | 32000480 | 32000480 |
| full | 4 | descriptor_selected_writer | 0.004731 | 0.003684 | 32049032 | 32048976 |
| empty | 1 | group_source | 0.001114 | 0.001156 | 8000936 | 8000936 |
| empty | 1 | selection_validation | 0.002222 | 0.000701 | 224 | 176 |
| empty | 1 | owned_plane_copy | 0.001372 | 0.001114 | 32000248 | 32000248 |
| empty | 1 | descriptor_selected_writer | 0.004151 | 0.002478 | 32002272 | 32002224 |
| empty | 4 | group_source | 0.001175 | 0.001123 | 8001168 | 8001168 |
| empty | 4 | selection_validation | 0.002372 | 0.000684 | 456 | 408 |
| empty | 4 | owned_plane_copy | 0.001280 | 0.001137 | 32000480 | 32000480 |
| empty | 4 | descriptor_selected_writer | 0.003985 | 0.002076 | 32054568 | 32055792 |

The unchanged quiet complete whole-node table **66283** exited 0 on the
fresh **1178** binary, with median three cold cooks/fresh Sessions, a million
ordinary-owner elements and one Detail element on a million-point input,
one/four domains and grain 4096. No other builds or timings ran during the
window. All 78 rows follow; all earlier tables remain intact.
**Seven rows still exceed 2×**: five full-group/one-domain cases, maximum
**2.091×**, and two Detail/one-domain microcases, maximum **2.759×**. All
selected-group and empty-group rows now pass. The whole gate remains unmet;
Set Color is unregistered and B.11 incomplete. No failed case was omitted.
Log: `/tmp/rays-set-color-inline-mask-bench.log`.

| Owner | Elements | Cd | Group | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---|---|---:|---:|---:|---:|---:|---:|
| Point | 1000000 | absent | all | 1 | 0.001173 | 0.000606 | 0.517 | 32010016 | 32032200 |
| Point | 1000000 | absent | all | 4 | 0.001281 | 0.000657 | 0.513 | 32015272 | 32032432 |
| Point | 1000000 | absent | selected | 1 | 0.003743 | 0.007349 | 1.963 | 32010432 | 40030272 |
| Point | 1000000 | absent | selected | 4 | 0.003764 | 0.004729 | 1.256 | 32010664 | 40078072 |
| Point | 1000000 | absent | full | 1 | 0.004823 | 0.010083 | 2.091 | 32010424 | 40030264 |
| Point | 1000000 | absent | full | 4 | 0.004917 | 0.005663 | 1.152 | 32010656 | 40076328 |
| Point | 1000000 | absent | empty | 1 | 0.002859 | 0.003071 | 1.074 | 32010424 | 40030264 |
| Point | 1000000 | absent | empty | 4 | 0.002837 | 0.002648 | 0.933 | 32010656 | 40083312 |
| Point | 1000000 | vec4 | all | 1 | 0.001155 | 0.000693 | 0.600 | 32010168 | 32047240 |
| Point | 1000000 | vec4 | all | 4 | 0.001224 | 0.000648 | 0.529 | 32010400 | 32033736 |
| Point | 1000000 | vec4 | selected | 1 | 0.004353 | 0.007650 | 1.757 | 32010776 | 40030544 |
| Point | 1000000 | vec4 | selected | 4 | 0.004425 | 0.005476 | 1.238 | 32011008 | 40082696 |
| Point | 1000000 | vec4 | full | 1 | 0.005519 | 0.010568 | 1.915 | 32010768 | 40030536 |
| Point | 1000000 | vec4 | full | 4 | 0.005332 | 0.006106 | 1.145 | 32011000 | 40078032 |
| Point | 1000000 | vec4 | empty | 1 | 0.003430 | 0.003581 | 1.044 | 32010768 | 40030536 |
| Point | 1000000 | vec4 | empty | 4 | 0.003343 | 0.003096 | 0.926 | 32011000 | 40083128 |
| Point | 1000000 | wrong_float | all | 1 | 0.001233 | 0.000634 | 0.514 | 32010168 | 32033504 |
| Point | 1000000 | wrong_float | all | 4 | 0.001258 | 0.000643 | 0.511 | 32010400 | 32033736 |
| Point | 1000000 | wrong_float | selected | 1 | 0.003790 | 0.006850 | 1.807 | 32010600 | 40030616 |
| Point | 1000000 | wrong_float | selected | 4 | 0.004003 | 0.004662 | 1.165 | 32010832 | 40078072 |
| Point | 1000000 | wrong_float | full | 1 | 0.005168 | 0.010075 | 1.950 | 32010592 | 40030608 |
| Point | 1000000 | wrong_float | full | 4 | 0.004964 | 0.005812 | 1.171 | 32010824 | 40077088 |
| Point | 1000000 | wrong_float | empty | 1 | 0.002910 | 0.003145 | 1.081 | 32010592 | 40030544 |
| Point | 1000000 | wrong_float | empty | 4 | 0.002897 | 0.002687 | 0.927 | 32010824 | 40084312 |
| Vertex | 1000000 | absent | all | 1 | 0.001400 | 0.000670 | 0.479 | 32010024 | 32045944 |
| Vertex | 1000000 | absent | all | 4 | 0.001218 | 0.000668 | 0.548 | 32010256 | 32032440 |
| Vertex | 1000000 | absent | selected | 1 | 0.003751 | 0.006832 | 1.821 | 32010440 | 40030272 |
| Vertex | 1000000 | absent | selected | 4 | 0.003775 | 0.004587 | 1.215 | 32010672 | 40077864 |
| Vertex | 1000000 | absent | full | 1 | 0.004797 | 0.009961 | 2.076 | 32010424 | 40030328 |
| Vertex | 1000000 | absent | full | 4 | 0.004926 | 0.005738 | 1.165 | 32010656 | 40076896 |
| Vertex | 1000000 | absent | empty | 1 | 0.002859 | 0.003060 | 1.070 | 32010432 | 40030328 |
| Vertex | 1000000 | absent | empty | 4 | 0.002838 | 0.002733 | 0.963 | 32010664 | 40082624 |
| Vertex | 1000000 | vec4 | all | 1 | 0.001276 | 0.000703 | 0.551 | 32010176 | 32033520 |
| Vertex | 1000000 | vec4 | all | 4 | 0.001265 | 0.000729 | 0.576 | 32010408 | 32033752 |
| Vertex | 1000000 | vec4 | selected | 1 | 0.004474 | 0.007315 | 1.635 | 32010784 | 40030544 |
| Vertex | 1000000 | vec4 | selected | 4 | 0.004238 | 0.005073 | 1.197 | 32011016 | 40077360 |
| Vertex | 1000000 | vec4 | full | 1 | 0.005316 | 0.010396 | 1.956 | 32010768 | 40030536 |
| Vertex | 1000000 | vec4 | full | 4 | 0.005403 | 0.006092 | 1.128 | 32011000 | 40077528 |
| Vertex | 1000000 | vec4 | empty | 1 | 0.003367 | 0.003528 | 1.048 | 32010776 | 40030600 |
| Vertex | 1000000 | vec4 | empty | 4 | 0.003362 | 0.003153 | 0.938 | 32011008 | 40084200 |
| Vertex | 1000000 | wrong_float | all | 1 | 0.001140 | 0.000731 | 0.641 | 32010176 | 32033520 |
| Vertex | 1000000 | wrong_float | all | 4 | 0.001346 | 0.000720 | 0.535 | 32010408 | 32033752 |
| Vertex | 1000000 | wrong_float | selected | 1 | 0.003866 | 0.006913 | 1.788 | 32010608 | 40030552 |
| Vertex | 1000000 | wrong_float | selected | 4 | 0.003789 | 0.004585 | 1.210 | 32010840 | 40078552 |
| Vertex | 1000000 | wrong_float | full | 1 | 0.005151 | 0.010159 | 1.972 | 32010592 | 40030544 |
| Vertex | 1000000 | wrong_float | full | 4 | 0.004986 | 0.005837 | 1.171 | 32010824 | 40077552 |
| Vertex | 1000000 | wrong_float | empty | 1 | 0.002896 | 0.003103 | 1.071 | 32010600 | 40030544 |
| Vertex | 1000000 | wrong_float | empty | 4 | 0.002855 | 0.002706 | 0.948 | 32010832 | 40075440 |
| Primitive | 1000000 | absent | all | 1 | 0.001282 | 0.000700 | 0.546 | 32010040 | 32045976 |
| Primitive | 1000000 | absent | all | 4 | 0.001217 | 0.000671 | 0.552 | 32010272 | 32032472 |
| Primitive | 1000000 | absent | selected | 1 | 0.003895 | 0.007033 | 1.806 | 32010456 | 40030296 |
| Primitive | 1000000 | absent | selected | 4 | 0.003741 | 0.004644 | 1.241 | 32010688 | 40078096 |
| Primitive | 1000000 | absent | full | 1 | 0.004952 | 0.010316 | 2.083 | 32010432 | 40030336 |
| Primitive | 1000000 | absent | full | 4 | 0.004928 | 0.005640 | 1.145 | 32010664 | 40077576 |
| Primitive | 1000000 | absent | empty | 1 | 0.002894 | 0.003342 | 1.155 | 32010440 | 40030272 |
| Primitive | 1000000 | absent | empty | 4 | 0.002877 | 0.002690 | 0.935 | 32010672 | 40083136 |
| Primitive | 1000000 | vec4 | all | 1 | 0.001256 | 0.000657 | 0.523 | 32010200 | 32033560 |
| Primitive | 1000000 | vec4 | all | 4 | 0.001303 | 0.000746 | 0.573 | 32010432 | 32033792 |
| Primitive | 1000000 | vec4 | selected | 1 | 0.004395 | 0.007343 | 1.671 | 32010808 | 40030576 |
| Primitive | 1000000 | vec4 | selected | 4 | 0.004217 | 0.005042 | 1.196 | 32011040 | 40078208 |
| Primitive | 1000000 | vec4 | full | 1 | 0.005446 | 0.011251 | 2.066 | 32010784 | 40030552 |
| Primitive | 1000000 | vec4 | full | 4 | 0.005447 | 0.006647 | 1.220 | 32011016 | 40078152 |
| Primitive | 1000000 | vec4 | empty | 1 | 0.003495 | 0.003610 | 1.033 | 32010792 | 40030552 |
| Primitive | 1000000 | vec4 | empty | 4 | 0.003582 | 0.003726 | 1.040 | 32011024 | 40123744 |
| Primitive | 1000000 | wrong_float | all | 1 | 0.001259 | 0.000703 | 0.558 | 32010200 | 32033560 |
| Primitive | 1000000 | wrong_float | all | 4 | 0.001168 | 0.000672 | 0.575 | 32010432 | 32033792 |
| Primitive | 1000000 | wrong_float | selected | 1 | 0.003721 | 0.006913 | 1.858 | 32010632 | 40030584 |
| Primitive | 1000000 | wrong_float | selected | 4 | 0.003686 | 0.004584 | 1.244 | 32010864 | 40078104 |
| Primitive | 1000000 | wrong_float | full | 1 | 0.004781 | 0.009921 | 2.075 | 32010608 | 40030560 |
| Primitive | 1000000 | wrong_float | full | 4 | 0.004850 | 0.005651 | 1.165 | 32010840 | 40077192 |
| Primitive | 1000000 | wrong_float | empty | 1 | 0.002875 | 0.003183 | 1.107 | 32010616 | 40030624 |
| Primitive | 1000000 | wrong_float | empty | 4 | 0.002888 | 0.002659 | 0.921 | 32010848 | 40084456 |
| Detail | 1 | absent | all | 1 | 0.000017 | 0.000040 | 2.366 | 10064 | 26360 |
| Detail | 1 | absent | all | 4 | 0.000020 | 0.000028 | 1.393 | 10296 | 27248 |
| Detail | 1 | vec4 | all | 1 | 0.000014 | 0.000038 | 2.759 | 10216 | 27088 |
| Detail | 1 | vec4 | all | 4 | 0.000028 | 0.000039 | 1.402 | 10448 | 27976 |
| Detail | 1 | wrong_float | all | 1 | 0.000023 | 0.000024 | 1.052 | 10216 | 27088 |
| Detail | 1 | wrong_float | all | 4 | 0.000027 | 0.000038 | 1.416 | 10448 | 27976 |

### Exact integer comparisons use native operand types (shared prerequisite)

`Packed_ops.comparison_apply` now annotates its two operands as `int`, matching
its existing interface. This changes neither the signed 63-bit comparison
contract nor its Op/Packed callers. Apple M1 disassembly before the annotation
shows every comparison case calling the polymorphic C comparison through
`caml_c_call`; afterwards all five cases use direct signed ARM `cmp`/`cset`
and return, without that C call. Assembly evidence:
`/tmp/rays-point-jitter-guard-cache-assembly.txt` and
`/tmp/rays-int-comparison-annotated-assembly.txt`.

Focused requests 11815 and 89572 ran `@lib/flow/runtest
@lib/flow_ir/runtest @lib/flow_sop/point_jitter_draft
_build/default/lib/flow_sop/test_point_jitter.exe`. Flow, the 1,952-case scalar
Core census, numeric packed/gather proofs and the full Point Jitter recipe
passed. The aggregate exited 1 on the concurrent Text leaf work: first a
stale zero-region assertion, then empty Cartesian Text source laziness and
bulk Text result handling. These failures are retained in
`/tmp/rays-point-jitter-int-comparison-focused.log` and
`/tmp/rays-point-jitter-int-comparison-focused2.log`. Final retry 94549 exited
0 for the same command after the Text fixes
(`/tmp/rays-point-jitter-int-comparison-focused3.log`), including exact
signed-integer boundaries, guarded execution, gather, Text leaves and the full
Point Jitter native/reference/domain/grain/error recipe. No public API or
mirror changed.

Quiet request 30465 exited 0 after the native/reference/strict preflights,
using the annotated executable linked by 89572. It uses the same protocol as
the post-guard-cache baseline 74683: Apple M1, OCaml 5.3.0 dev profile, one
million real grid points and 998,001 quads, grain 4096, median of three fresh
cold-session cooks, domains 1/4. Four-domain allocations cover only the
initial domain. Log: `/tmp/rays-point-jitter-int-comparison-bench-first.log`.

| Mode | Domains | Baseline Lisp seconds | Native seconds | Annotated Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---:|---:|---:|---:|---:|---:|
| defaults | 1 | 0.579217 | 0.020690 | 0.548117 | **26.492×** | 72015704 | 617593168 |
| defaults | 4 | 0.243064 | 0.006940 | 0.229277 | **33.036×** | 36279960 | 363795592 |
| selected optional inputs | 1 | 0.697501 | 0.025340 | 0.671244 | **26.489×** | 48016440 | 732849120 |
| selected optional inputs | 4 | 0.288948 | 0.007334 | 0.271113 | **36.967×** | 30171856 | 405743008 |

Whole Lisp time falls about 3.8–6.2% against the previous table. Allocation
stays close to that table, including its retained selected-case regression;
one-domain counts rise by approximately 190 KB per cook. All four unchanged
2× gates fail. No Point Jitter registration or native removal is claimed.

### Selected writes compute the row index once

The shared `Attribute_kernel.write_selected` computes the replacement row
index once per selected row, before the component loop. Dense arrays still
use `i * width`; validated constant descriptors still use row zero. Every
component receives the same value as before. Selection/type/count/finite
checks, raw unselected bytes, owned outputs, cancellation and authored
forcing order remain unchanged. No API or node registration changes.

Focused **34270** exited 0 for `@lib/flow_sop/runtest` and
`@lib/flow_sop/set_color_draft`. Fresh current-compiler Color relink and
semantic proof **15144** exited 0 before timing, including all owners/Cd
storage/group modes, native 4 ULP comparison, exact reference/domain bytes,
all 72 raw nonfinite selected/unselected cases at domains 1/4/8 and grains
1/97/4096, schema, cache, native inspector cards and every physical-field
gesture. Logs: `/tmp/rays-selected-row-index-focused2.log`,
`/tmp/rays-selected-row-index-current.log`. `git diff --check` passes.

Quiet direct-host attribution **92159** exited 0. The complete 24-row
comparison uses the same million-Vertex fixture with matching Float4 Cd,
one/four domains, grain 4096 and median three samples, with major GC before
each sample. Baseline **41442** already includes inline mask validation;
all earlier measurements remain intact. The descriptor writer at one domain
changes from 5.379/8.027/2.478 ms for selected/full/empty groups to
5.176/7.649/2.434 ms; four-domain values are 3.057/3.510/2.065 ms.
Writer allocation remains about 32 MB of owned planes; the mask is measured
separately. Allocation figures are initial-domain only. Logs:
`/tmp/rays-color-writer-inline-attribution.log`,
`/tmp/rays-color-writer-row-index-attribution.log`.

| Group | Domains | Stage | Before seconds | After seconds | Before bytes | After bytes |
|---|---:|---|---:|---:|---:|---:|
| selected | 1 | group_source | 0.001938 | 0.002393 | 8000936 | 8000936 |
| selected | 1 | selection_validation | 0.000828 | 0.000804 | 176 | 176 |
| selected | 1 | owned_plane_copy | 0.002093 | 0.001275 | 32000248 | 32000248 |
| selected | 1 | descriptor_selected_writer | 0.005379 | 0.005176 | 32002224 | 32002224 |
| selected | 4 | group_source | 0.001925 | 0.001893 | 8001168 | 8001168 |
| selected | 4 | selection_validation | 0.000802 | 0.000802 | 408 | 408 |
| selected | 4 | owned_plane_copy | 0.001153 | 0.001192 | 32000480 | 32000480 |
| selected | 4 | descriptor_selected_writer | 0.003113 | 0.003057 | 32049608 | 32049408 |
| full | 1 | group_source | 0.002514 | 0.002515 | 8000936 | 8000936 |
| full | 1 | selection_validation | 0.000828 | 0.000870 | 176 | 176 |
| full | 1 | owned_plane_copy | 0.001173 | 0.001132 | 32000248 | 32000248 |
| full | 1 | descriptor_selected_writer | 0.008027 | 0.007649 | 32002224 | 32002224 |
| full | 4 | group_source | 0.002498 | 0.002549 | 8001168 | 8001168 |
| full | 4 | selection_validation | 0.000802 | 0.000879 | 408 | 408 |
| full | 4 | owned_plane_copy | 0.001216 | 0.001116 | 32000480 | 32000480 |
| full | 4 | descriptor_selected_writer | 0.003684 | 0.003510 | 32048976 | 32049040 |
| empty | 1 | group_source | 0.001156 | 0.001108 | 8000936 | 8000936 |
| empty | 1 | selection_validation | 0.000701 | 0.000681 | 176 | 176 |
| empty | 1 | owned_plane_copy | 0.001114 | 0.001180 | 32000248 | 32000248 |
| empty | 1 | descriptor_selected_writer | 0.002478 | 0.002434 | 32002224 | 32002224 |
| empty | 4 | group_source | 0.001123 | 0.001101 | 8001168 | 8001168 |
| empty | 4 | selection_validation | 0.000684 | 0.000682 | 408 | 408 |
| empty | 4 | owned_plane_copy | 0.001137 | 0.001185 | 32000480 | 32000480 |
| empty | 4 | descriptor_selected_writer | 0.002076 | 0.002065 | 32055792 | 32056312 |

The unchanged quiet complete whole-node table **58089** exited 0 on the
fresh **15144** binary. It uses median three cold cooks with fresh Sessions,
a million ordinary-owner elements, one Detail element on a million-point
input, one/four domains and grain 4096. Other agents held all builds and
timings throughout the reserved window. All 78 predetermined configurations
remain below, including all failed rows. **Three ordinary one-domain cases
still exceed 2×**: Point/absent/selected 2.006×, Point/absent/full 2.005× and
Primitive/absent/full 2.052×. All Detail cases pass in this table. The gate
remains unmet; Set Color stays unregistered and B.11 incomplete. No repeated
or omitted configuration changes that conclusion. All previous tables are
retained. Log: `/tmp/rays-set-color-row-index-bench.log`.

| Owner | Elements | Cd | Group | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---|---|---:|---:|---:|---:|---:|---:|
| Point | 1000000 | absent | all | 1 | 0.001214 | 0.000605 | 0.498 | 32010016 | 32032200 |
| Point | 1000000 | absent | all | 4 | 0.001217 | 0.000613 | 0.504 | 32010248 | 32032432 |
| Point | 1000000 | absent | selected | 1 | 0.003759 | 0.007540 | 2.006 | 32010432 | 40030272 |
| Point | 1000000 | absent | selected | 4 | 0.003755 | 0.004562 | 1.215 | 32010664 | 40077552 |
| Point | 1000000 | absent | full | 1 | 0.004784 | 0.009592 | 2.005 | 32010424 | 40030264 |
| Point | 1000000 | absent | full | 4 | 0.005157 | 0.005624 | 1.091 | 32010656 | 40079632 |
| Point | 1000000 | absent | empty | 1 | 0.002860 | 0.003102 | 1.085 | 32010424 | 40030328 |
| Point | 1000000 | absent | empty | 4 | 0.002867 | 0.002705 | 0.943 | 32010656 | 40084408 |
| Point | 1000000 | vec4 | all | 1 | 0.001270 | 0.000660 | 0.520 | 32010168 | 32033504 |
| Point | 1000000 | vec4 | all | 4 | 0.001247 | 0.000678 | 0.543 | 32010400 | 32033736 |
| Point | 1000000 | vec4 | selected | 1 | 0.004238 | 0.007340 | 1.732 | 32010776 | 40030544 |
| Point | 1000000 | vec4 | selected | 4 | 0.004274 | 0.005102 | 1.194 | 32011008 | 40078704 |
| Point | 1000000 | vec4 | full | 1 | 0.005294 | 0.010230 | 1.932 | 32010768 | 40030536 |
| Point | 1000000 | vec4 | full | 4 | 0.005478 | 0.006216 | 1.135 | 32011000 | 40077648 |
| Point | 1000000 | vec4 | empty | 1 | 0.003466 | 0.003547 | 1.023 | 32010768 | 40030536 |
| Point | 1000000 | vec4 | empty | 4 | 0.003488 | 0.003168 | 0.908 | 32011000 | 40083544 |
| Point | 1000000 | wrong_float | all | 1 | 0.001172 | 0.000655 | 0.559 | 32010168 | 32033504 |
| Point | 1000000 | wrong_float | all | 4 | 0.001153 | 0.000671 | 0.582 | 32010400 | 32033736 |
| Point | 1000000 | wrong_float | selected | 1 | 0.003901 | 0.006644 | 1.703 | 32010600 | 40030552 |
| Point | 1000000 | wrong_float | selected | 4 | 0.003954 | 0.004996 | 1.264 | 32010832 | 40076952 |
| Point | 1000000 | wrong_float | full | 1 | 0.005032 | 0.009692 | 1.926 | 32010592 | 40030608 |
| Point | 1000000 | wrong_float | full | 4 | 0.005003 | 0.005534 | 1.106 | 32010824 | 40077608 |
| Point | 1000000 | wrong_float | empty | 1 | 0.002849 | 0.003164 | 1.111 | 32010592 | 40030608 |
| Point | 1000000 | wrong_float | empty | 4 | 0.003034 | 0.002630 | 0.867 | 32010824 | 40083232 |
| Vertex | 1000000 | absent | all | 1 | 0.001223 | 0.000662 | 0.541 | 32010024 | 32032208 |
| Vertex | 1000000 | absent | all | 4 | 0.001216 | 0.000667 | 0.549 | 32010256 | 32032440 |
| Vertex | 1000000 | absent | selected | 1 | 0.003810 | 0.006690 | 1.756 | 32010440 | 40030272 |
| Vertex | 1000000 | absent | selected | 4 | 0.003886 | 0.004728 | 1.217 | 32010672 | 40078528 |
| Vertex | 1000000 | absent | full | 1 | 0.005104 | 0.009607 | 1.882 | 32010424 | 40030264 |
| Vertex | 1000000 | absent | full | 4 | 0.004867 | 0.005822 | 1.196 | 32010656 | 40081472 |
| Vertex | 1000000 | absent | empty | 1 | 0.002867 | 0.003125 | 1.090 | 32010432 | 40030264 |
| Vertex | 1000000 | absent | empty | 4 | 0.002912 | 0.002656 | 0.912 | 32010664 | 40083344 |
| Vertex | 1000000 | vec4 | all | 1 | 0.001170 | 0.000665 | 0.568 | 32010176 | 32033520 |
| Vertex | 1000000 | vec4 | all | 4 | 0.001193 | 0.000663 | 0.556 | 32010408 | 32033752 |
| Vertex | 1000000 | vec4 | selected | 1 | 0.004344 | 0.007142 | 1.644 | 32010784 | 40030608 |
| Vertex | 1000000 | vec4 | selected | 4 | 0.004348 | 0.005087 | 1.170 | 32011016 | 40078128 |
| Vertex | 1000000 | vec4 | full | 1 | 0.005394 | 0.010370 | 1.923 | 32010768 | 40030600 |
| Vertex | 1000000 | vec4 | full | 4 | 0.005504 | 0.006185 | 1.124 | 32011000 | 40078256 |
| Vertex | 1000000 | vec4 | empty | 1 | 0.003356 | 0.003540 | 1.055 | 32010776 | 40030600 |
| Vertex | 1000000 | vec4 | empty | 4 | 0.003378 | 0.003455 | 1.023 | 32011008 | 40094432 |
| Vertex | 1000000 | wrong_float | all | 1 | 0.001311 | 0.000697 | 0.532 | 32010176 | 32033520 |
| Vertex | 1000000 | wrong_float | all | 4 | 0.001191 | 0.000651 | 0.547 | 32010408 | 32033752 |
| Vertex | 1000000 | wrong_float | selected | 1 | 0.003750 | 0.006772 | 1.806 | 32010608 | 40030552 |
| Vertex | 1000000 | wrong_float | selected | 4 | 0.003794 | 0.004829 | 1.273 | 32010840 | 40077736 |
| Vertex | 1000000 | wrong_float | full | 1 | 0.005213 | 0.009937 | 1.906 | 32010592 | 40030544 |
| Vertex | 1000000 | wrong_float | full | 4 | 0.005172 | 0.005743 | 1.110 | 32010824 | 40077488 |
| Vertex | 1000000 | wrong_float | empty | 1 | 0.003024 | 0.003219 | 1.064 | 32010600 | 40030544 |
| Vertex | 1000000 | wrong_float | empty | 4 | 0.002837 | 0.002640 | 0.931 | 32010832 | 40083176 |
| Primitive | 1000000 | absent | all | 1 | 0.001231 | 0.000658 | 0.534 | 32010040 | 32032240 |
| Primitive | 1000000 | absent | all | 4 | 0.001216 | 0.000661 | 0.543 | 32010272 | 32032472 |
| Primitive | 1000000 | absent | selected | 1 | 0.003790 | 0.006631 | 1.750 | 32010456 | 40030296 |
| Primitive | 1000000 | absent | selected | 4 | 0.003937 | 0.004630 | 1.176 | 32010688 | 40077528 |
| Primitive | 1000000 | absent | full | 1 | 0.004789 | 0.009825 | 2.052 | 32010432 | 40030272 |
| Primitive | 1000000 | absent | full | 4 | 0.004854 | 0.005587 | 1.151 | 32010664 | 40077400 |
| Primitive | 1000000 | absent | empty | 1 | 0.003006 | 0.003151 | 1.048 | 32010440 | 40030272 |
| Primitive | 1000000 | absent | empty | 4 | 0.002876 | 0.002667 | 0.927 | 32010672 | 40084280 |
| Primitive | 1000000 | vec4 | all | 1 | 0.001246 | 0.000748 | 0.600 | 32010200 | 32033560 |
| Primitive | 1000000 | vec4 | all | 4 | 0.001199 | 0.000647 | 0.540 | 32010432 | 32033792 |
| Primitive | 1000000 | vec4 | selected | 1 | 0.004303 | 0.007586 | 1.763 | 32010808 | 40030576 |
| Primitive | 1000000 | vec4 | selected | 4 | 0.004605 | 0.005212 | 1.132 | 32011040 | 40077048 |
| Primitive | 1000000 | vec4 | full | 1 | 0.005590 | 0.010224 | 1.829 | 32010784 | 40030552 |
| Primitive | 1000000 | vec4 | full | 4 | 0.005405 | 0.006263 | 1.159 | 32011016 | 40077312 |
| Primitive | 1000000 | vec4 | empty | 1 | 0.003368 | 0.003791 | 1.126 | 32010792 | 40030552 |
| Primitive | 1000000 | vec4 | empty | 4 | 0.003425 | 0.003216 | 0.939 | 32011024 | 40084936 |
| Primitive | 1000000 | wrong_float | all | 1 | 0.001247 | 0.000736 | 0.590 | 32010200 | 32033560 |
| Primitive | 1000000 | wrong_float | all | 4 | 0.001148 | 0.000725 | 0.632 | 32010432 | 32033792 |
| Primitive | 1000000 | wrong_float | selected | 1 | 0.003762 | 0.006619 | 1.759 | 32010632 | 40030648 |
| Primitive | 1000000 | wrong_float | selected | 4 | 0.003712 | 0.004899 | 1.320 | 32010864 | 40084448 |
| Primitive | 1000000 | wrong_float | full | 1 | 0.004864 | 0.009725 | 1.999 | 32010608 | 40030560 |
| Primitive | 1000000 | wrong_float | full | 4 | 0.004862 | 0.005573 | 1.146 | 32010840 | 40077592 |
| Primitive | 1000000 | wrong_float | empty | 1 | 0.002867 | 0.003160 | 1.102 | 32010616 | 40030560 |
| Primitive | 1000000 | wrong_float | empty | 4 | 0.003036 | 0.002759 | 0.909 | 32010848 | 40083400 |
| Detail | 1 | absent | all | 1 | 0.000024 | 0.000035 | 1.470 | 10064 | 26360 |
| Detail | 1 | absent | all | 4 | 0.000028 | 0.000033 | 1.188 | 10296 | 27248 |
| Detail | 1 | vec4 | all | 1 | 0.000026 | 0.000027 | 1.046 | 10216 | 27088 |
| Detail | 1 | vec4 | all | 4 | 0.000046 | 0.000037 | 0.803 | 10448 | 27976 |
| Detail | 1 | wrong_float | all | 1 | 0.000022 | 0.000032 | 1.457 | 10216 | 27088 |
| Detail | 1 | wrong_float | all | 4 | 0.000017 | 0.000025 | 1.444 | 10448 | 27976 |

### Full constant selections allocate their final planes directly

After existing type, cardinality, mask and finite/default validation, the
shared selected writer checks whether a validated constant descriptor has
an all-one selection. It allocates fresh final planes with `Array.make`,
skipping the copied/defaulted planes and subsequent overlay. Dense and
partial-mask values retain the existing path. The mask scan stops at its
first zero. Empty selections retain the existing zero-count semantics; no
API, authored evaluation order, error priority or SOP-specific callback is
added.

Focused **13423** exited 0 for `@lib/flow_sop/runtest` and
`@lib/flow_sop/set_color_draft`. Regular descriptor tests now cover all-zero,
all-one and alternating masks at counts 0/1/32769, domains 1/4/8, signed
zero and tiny values, immutable input and exact dense-writer bytes. A full
mask still rejects a NaN default, including at zero count. Existing
all-owner/raw-NaN storage, strict/reference, invalid type/count/mask,
cancellation, schema/cache and native card/inspector gesture tests remain
green, including all 72 selected/unselected raw Cd cases. Log:
`/tmp/rays-selected-constant-full-focused.log`. `git diff --check` passes.

Quiet whole-node table **41252** exited 0 on the fresh **13423** binary.
The unchanged 78 configurations use median three fresh cold Session cooks,
one/four domains, grain 4096, a million ordinary-owner elements and one
Detail element on a million-point input. Other agents held CPU validation
and timings throughout. All **72 ordinary cases pass**, maximum **1.784×**
(Point/absent/selected/one-domain). Detail/vec4/one-domain remains a failed
microcase at 23/52 microseconds, **2.281×**; the complete table and every
earlier failure remain retained below. The unchanged 2× gate is not claimed
from this table. Set Color remains unregistered pending the predetermined
all-six Detail amortized measurement and whole production gates. Log:
`/tmp/rays-set-color-constant-full-bench.log`.

| Owner | Elements | Cd | Group | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---|---|---:|---:|---:|---:|---:|---:|
| Point | 1000000 | absent | all | 1 | 0.001143 | 0.000625 | 0.547 | 32010016 | 32032200 |
| Point | 1000000 | absent | all | 4 | 0.001330 | 0.000640 | 0.481 | 32015272 | 32032432 |
| Point | 1000000 | absent | selected | 1 | 0.003747 | 0.006683 | 1.784 | 32010432 | 40030272 |
| Point | 1000000 | absent | selected | 4 | 0.004068 | 0.004569 | 1.123 | 32010664 | 40076608 |
| Point | 1000000 | absent | full | 1 | 0.004889 | 0.004653 | 0.952 | 32010424 | 40030208 |
| Point | 1000000 | absent | full | 4 | 0.004794 | 0.004623 | 0.964 | 32010656 | 40030376 |
| Point | 1000000 | absent | empty | 1 | 0.002903 | 0.003288 | 1.133 | 32010424 | 40030328 |
| Point | 1000000 | absent | empty | 4 | 0.003066 | 0.002967 | 0.968 | 32010656 | 40105576 |
| Point | 1000000 | vec4 | all | 1 | 0.001288 | 0.000713 | 0.554 | 32010168 | 32033504 |
| Point | 1000000 | vec4 | all | 4 | 0.001355 | 0.000648 | 0.478 | 32010400 | 32033736 |
| Point | 1000000 | vec4 | selected | 1 | 0.004525 | 0.007113 | 1.572 | 32010776 | 40030544 |
| Point | 1000000 | vec4 | selected | 4 | 0.004269 | 0.005078 | 1.189 | 32011008 | 40077800 |
| Point | 1000000 | vec4 | full | 1 | 0.005281 | 0.004638 | 0.878 | 32010768 | 40030520 |
| Point | 1000000 | vec4 | full | 4 | 0.005345 | 0.004666 | 0.873 | 32011000 | 40030752 |
| Point | 1000000 | vec4 | empty | 1 | 0.003641 | 0.003742 | 1.028 | 32010768 | 40030536 |
| Point | 1000000 | vec4 | empty | 4 | 0.004048 | 0.003246 | 0.802 | 32011000 | 40083232 |
| Point | 1000000 | wrong_float | all | 1 | 0.001216 | 0.000650 | 0.535 | 32010168 | 32033504 |
| Point | 1000000 | wrong_float | all | 4 | 0.001350 | 0.000696 | 0.516 | 32010400 | 32033736 |
| Point | 1000000 | wrong_float | selected | 1 | 0.003959 | 0.006869 | 1.735 | 32010600 | 40030552 |
| Point | 1000000 | wrong_float | selected | 4 | 0.003911 | 0.004893 | 1.251 | 32010832 | 40078576 |
| Point | 1000000 | wrong_float | full | 1 | 0.004833 | 0.004713 | 0.975 | 32010592 | 40030424 |
| Point | 1000000 | wrong_float | full | 4 | 0.004850 | 0.004614 | 0.951 | 32010824 | 40030656 |
| Point | 1000000 | wrong_float | empty | 1 | 0.002884 | 0.003228 | 1.119 | 32010592 | 40030608 |
| Point | 1000000 | wrong_float | empty | 4 | 0.002871 | 0.002662 | 0.927 | 32010824 | 40083864 |
| Vertex | 1000000 | absent | all | 1 | 0.001227 | 0.000675 | 0.550 | 32010024 | 32045944 |
| Vertex | 1000000 | absent | all | 4 | 0.001229 | 0.000661 | 0.538 | 32010256 | 32032440 |
| Vertex | 1000000 | absent | selected | 1 | 0.003774 | 0.006684 | 1.771 | 32010440 | 40030272 |
| Vertex | 1000000 | absent | selected | 4 | 0.003939 | 0.004561 | 1.158 | 32010672 | 40078120 |
| Vertex | 1000000 | absent | full | 1 | 0.004814 | 0.004609 | 0.957 | 32010424 | 40030208 |
| Vertex | 1000000 | absent | full | 4 | 0.004812 | 0.004666 | 0.970 | 32010656 | 40030376 |
| Vertex | 1000000 | absent | empty | 1 | 0.002856 | 0.003063 | 1.072 | 32010432 | 40030264 |
| Vertex | 1000000 | absent | empty | 4 | 0.002847 | 0.002636 | 0.926 | 32010664 | 40083096 |
| Vertex | 1000000 | vec4 | all | 1 | 0.001224 | 0.000751 | 0.614 | 32010176 | 32047256 |
| Vertex | 1000000 | vec4 | all | 4 | 0.001258 | 0.000686 | 0.545 | 32010408 | 32033752 |
| Vertex | 1000000 | vec4 | selected | 1 | 0.004703 | 0.007393 | 1.572 | 32010784 | 40030544 |
| Vertex | 1000000 | vec4 | selected | 4 | 0.004439 | 0.005718 | 1.288 | 32011016 | 40035528 |
| Vertex | 1000000 | vec4 | full | 1 | 0.005614 | 0.004677 | 0.833 | 32010768 | 40030520 |
| Vertex | 1000000 | vec4 | full | 4 | 0.005356 | 0.004684 | 0.875 | 32011000 | 40030752 |
| Vertex | 1000000 | vec4 | empty | 1 | 0.003377 | 0.003497 | 1.036 | 32010776 | 40030536 |
| Vertex | 1000000 | vec4 | empty | 4 | 0.003382 | 0.003217 | 0.951 | 32011008 | 40082360 |
| Vertex | 1000000 | wrong_float | all | 1 | 0.001229 | 0.000655 | 0.533 | 32010176 | 32047256 |
| Vertex | 1000000 | wrong_float | all | 4 | 0.001202 | 0.000723 | 0.601 | 32010408 | 32033752 |
| Vertex | 1000000 | wrong_float | selected | 1 | 0.003807 | 0.006685 | 1.756 | 32010608 | 40030552 |
| Vertex | 1000000 | wrong_float | selected | 4 | 0.003740 | 0.004539 | 1.214 | 32010840 | 40078200 |
| Vertex | 1000000 | wrong_float | full | 1 | 0.004999 | 0.004789 | 0.958 | 32010592 | 40030424 |
| Vertex | 1000000 | wrong_float | full | 4 | 0.004930 | 0.004628 | 0.939 | 32010824 | 40030656 |
| Vertex | 1000000 | wrong_float | empty | 1 | 0.002911 | 0.003240 | 1.113 | 32010600 | 40030608 |
| Vertex | 1000000 | wrong_float | empty | 4 | 0.002949 | 0.002846 | 0.965 | 32010832 | 40083280 |
| Primitive | 1000000 | absent | all | 1 | 0.001241 | 0.000671 | 0.541 | 32010040 | 32032240 |
| Primitive | 1000000 | absent | all | 4 | 0.001151 | 0.000666 | 0.579 | 32010272 | 32032472 |
| Primitive | 1000000 | absent | selected | 1 | 0.003750 | 0.006684 | 1.782 | 32010456 | 40030296 |
| Primitive | 1000000 | absent | selected | 4 | 0.003755 | 0.004640 | 1.236 | 32010688 | 40077160 |
| Primitive | 1000000 | absent | full | 1 | 0.005150 | 0.004764 | 0.925 | 32010432 | 40030152 |
| Primitive | 1000000 | absent | full | 4 | 0.004870 | 0.004613 | 0.947 | 32010664 | 40030384 |
| Primitive | 1000000 | absent | empty | 1 | 0.003189 | 0.003233 | 1.014 | 32010440 | 40030336 |
| Primitive | 1000000 | absent | empty | 4 | 0.002932 | 0.002857 | 0.974 | 32010672 | 40090960 |
| Primitive | 1000000 | vec4 | all | 1 | 0.001238 | 0.000670 | 0.541 | 32010200 | 32033560 |
| Primitive | 1000000 | vec4 | all | 4 | 0.001178 | 0.000766 | 0.650 | 32010432 | 32033792 |
| Primitive | 1000000 | vec4 | selected | 1 | 0.004391 | 0.007217 | 1.644 | 32010808 | 40030576 |
| Primitive | 1000000 | vec4 | selected | 4 | 0.004366 | 0.005162 | 1.182 | 32011040 | 40077704 |
| Primitive | 1000000 | vec4 | full | 1 | 0.005346 | 0.004661 | 0.872 | 32010784 | 40030600 |
| Primitive | 1000000 | vec4 | full | 4 | 0.005320 | 0.004602 | 0.865 | 32011016 | 40030768 |
| Primitive | 1000000 | vec4 | empty | 1 | 0.003381 | 0.003579 | 1.059 | 32010792 | 40030616 |
| Primitive | 1000000 | vec4 | empty | 4 | 0.003407 | 0.003170 | 0.930 | 32011024 | 40083456 |
| Primitive | 1000000 | wrong_float | all | 1 | 0.001189 | 0.000649 | 0.546 | 32010200 | 32047296 |
| Primitive | 1000000 | wrong_float | all | 4 | 0.001153 | 0.000677 | 0.587 | 32010432 | 32033792 |
| Primitive | 1000000 | wrong_float | selected | 1 | 0.003789 | 0.006588 | 1.739 | 32010632 | 40030584 |
| Primitive | 1000000 | wrong_float | selected | 4 | 0.003711 | 0.004696 | 1.265 | 32010864 | 40084000 |
| Primitive | 1000000 | wrong_float | full | 1 | 0.004938 | 0.004611 | 0.934 | 32010608 | 40030440 |
| Primitive | 1000000 | wrong_float | full | 4 | 0.004910 | 0.004613 | 0.939 | 32010840 | 40030672 |
| Primitive | 1000000 | wrong_float | empty | 1 | 0.002901 | 0.003301 | 1.138 | 32010616 | 40030560 |
| Primitive | 1000000 | wrong_float | empty | 4 | 0.002912 | 0.002725 | 0.936 | 32010848 | 40085080 |
| Detail | 1 | absent | all | 1 | 0.000023 | 0.000033 | 1.433 | 10064 | 26360 |
| Detail | 1 | absent | all | 4 | 0.000020 | 0.000025 | 1.250 | 10296 | 27248 |
| Detail | 1 | vec4 | all | 1 | 0.000023 | 0.000052 | 2.281 | 10216 | 27088 |
| Detail | 1 | vec4 | all | 4 | 0.000031 | 0.000041 | 1.323 | 10448 | 27976 |
| Detail | 1 | wrong_float | all | 1 | 0.000017 | 0.000027 | 1.569 | 10216 | 27088 |
| Detail | 1 | wrong_float | all | 4 | 0.000021 | 0.000036 | 1.716 | 10448 | 27976 |

The predetermined timer-resolution correction measures **all six** Detail
configurations (absent/matching Float4/wrong Float Cd, one/four domains),
not just the failed microcase. The protocol uses **1,000 fresh cold Sessions
per sample and median three samples** on the same million-point input and
grain 4096. Session creation/closure and major GC are outside the timer;
context creation and cook stay inside. Each configuration first checks
exact native geometry bytes outside timing. Fresh harness/semantic relink
**54249** exited 0, followed by quiet **92958**, exit 0, with other agents
holding all builds/timings. Logs: `/tmp/rays-set-color-detail-batch-focused.log`,
`/tmp/rays-set-color-detail-batch-bench.log`. Allocation is per cold cook,
initial-domain only. The earlier 78-row table including the 2.281× failure
remains above.

| Cd | Domains | Cold Sessions/sample | Native seconds/cook | Lisp seconds/cook | Ratio | Native bytes/cook | Lisp bytes/cook |
|---|---:|---:|---:|---:|---:|---:|---:|
| absent | 1 | 1000 | 0.000004695 | 0.000008615 | 1.835 | 9960 | 26256 |
| absent | 4 | 1000 | 0.000004652 | 0.000009084 | 1.953 | 10192 | 27144 |
| vec4 | 1 | 1000 | 0.000004715 | 0.000008854 | 1.878 | 10120 | 26992 |
| vec4 | 4 | 1000 | 0.000006077 | 0.000009346 | 1.538 | 10352 | 27880 |
| wrong_float | 1 | 1000 | 0.000004654 | 0.000009373 | 2.014 | 10120 | 26992 |
| wrong_float | 4 | 1000 | 0.000004690 | 0.000009231 | 1.968 | 10352 | 27880 |

**The whole speed gate remains unmet**: Detail/wrong Float/one-domain is
4.654/9.373 microseconds per cold cook, **2.014×**. All six predetermined
rows and all prior failed tables are retained; no case was removed or
repeated to obtain a passing result. Set Color remains unregistered and
B.11 incomplete. The shared all-one constant optimization has semantic
proof independently of this remaining whole-node speed failure.

### Delete Attributes production port

The authoritative declaration is `nodes/delete_attributes.rays`, with the
unchanged five physical fields, required `input` and optional `reference`,
labels, folders, defaults, operation and canonical parameter key. Its native
catalog registration is removed; `Sop.Nodes.Delete_attributes.factory` and
`Rdk.Attribute_ops.delete` remain the independent oracle. The old declaration
and its private validator are removed from `metadata.pending`.

The complete native wrapper and `attribute_lifecycle.ml` were reread. Native
validation compiles the original patterns before construction, while its cook
trims them. An escaped trailing space can therefore pass header validation
and become a dangling escape at cook time. The authored helper uses existing
Text trim/glob and structured error primitives to preserve that native
`invalid_attribute` code, message, cause and owner order; it adds no hidden
node callback. Initial expanded draft requests 50266/66929 exposed this
error-timing mismatch, 21242 passed the native cases but exposed a reserved
binding in the graph fixture, and corrected focused request 97097 exited 0.
All earlier failures remain in `/tmp/rays-delete-attributes-draft-focused*.log`.

The authoritative production function in `lib/sop/test_lisp_ports.ml` uses
only embedded `Catalog.sources()`, testing defaults/inverse, nine patterns
for each owner at both inverse settings, absent/empty/mixed references,
empty/single/4,225-grid/mixed-polygon-and-polyline/32,769-point inputs,
domains 1/4/8 and grains 1/97/4096. It compares exact geometry bytes and
complete native code/message/cause, strict reference, schema/descriptor,
operation/version/label/key, every physical-field rebuild, one public miss
and a subsequent warm hit, relabel identity, unchanged input bytes,
malformed glob rebuilds and wrong required/optional input types.
`test_metadata_ports.ml` additionally covers all four owners and eight
storage kinds, canonical P, name order and raw signed zeros, native
card/inspector structure, every field gesture, actual optional reference
connection/disconnection and bypass cooks. Its production graph check runs
in the ordinary `@lib/flow_sop/runtest` alias.

Production focused request 9711 ran `@lib/sop/runtest
@lib/flow_sop/runtest @lib/flow_sop/metadata_ports_draft
@lib/sop_catalog/runtest @test/dependency_gate`. All semantic/oracle checks
passed, including all three reference states and 465,782 native nonfinite
field instances; the aggregate exited 1 solely for the intended catalog
snapshot diff. The reviewed manifest moves the unchanged entry to the Lisp
section and adds `(body lisp)`/`(calls)`; its digest is
`2019eaed71f6bbcded648a345705a3bc`. Serialized promotion request 70512
accepted that exact manifest. CLI request 43021 reported the actual combined
digest `fff5af1db80ed5b3d2387e8da5fd5d0e1d2b2084e999cdadb24a55d1a18f5ba5`;
only that digest is updated in `tools/lisp/test/ml.t`.

Initial integration request 62750 ran the complete native suite successfully
but the aggregate exited 1 because an optional-slot catalog fixture still
searched the native-only factory list. All sibling slot-factory checks now
reuse its existing combined native/Lisp inventory. Focused catalog request
53925 exited 0, then final request 93275 exited 0 for `@runtest-native
@lib/sop/test_lisp_ports @lib/flow_sop/runtest @lib/sop_catalog/runtest
@tools/lisp/test/runtest @test/test_workspace_source @test/test_workspace_shell
@test/test_sop_catalog @tools/api_manifest/runtest @test/dependency_gate`.
This includes all native renderer/pathtracer/2D checks, 23 SOP graphs with
exact one/four-domain PNGs, the production source/save/menu/editor checks,
the actual CLI baseline, API and dependency gates. No render fixture was
refreshed. Logs: `/tmp/rays-delete-attributes-native-integration.log`,
`/tmp/rays-delete-attributes-catalog-followup.log` and
`/tmp/rays-delete-attributes-native-integration2.log`. This is the ninth
complete port; B.12 remains open for its other four metadata kinds.

Quiet timing request 30117 exited 0. The same authored body was measured
before moving its declaration into production. Apple M1, OCaml 5.3.0 dev,
1,000,000 grid points, 998,001 quads, eight attributes across the four owners,
grain 4096 and domains 1/4 were used. Ten fixed pattern/inverse modes times
absent/empty/selected references give all 60 configurations. Every row first
passes exact native geometry-byte preflight. A sample performs 1,000 fresh
cold Sessions; the median of three samples is reported. Session creation,
close and major GC are outside the clock; context creation and cook are
inside. No warm-session hits are reused, and the fixed batch amortizes timer
resolution for these metadata-only microsecond cooks. All other agents held
builds and timings for the complete window. Initial-domain allocations are
reported; four-domain totals are not claimed. All 60 unchanged 2× gates
pass, maximum 1.621×. Log: `/tmp/rays-delete-attributes-bench-first.log`.

| Mode | Reference | Domains | Cold Sessions/sample | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| default | absent | 1 | 1000 | 0.000005 | 0.000007 | 1.496 | 10736 | 19120 |
| default | absent | 4 | 1000 | 0.000005 | 0.000008 | 1.552 | 10968 | 19352 |
| inverse | absent | 1 | 1000 | 0.000005 | 0.000006 | 1.350 | 10688 | 18208 |
| inverse | absent | 4 | 1000 | 0.000005 | 0.000008 | 1.621 | 10920 | 18440 |
| point_pattern | absent | 1 | 1000 | 0.000007 | 0.000008 | 1.179 | 13216 | 21536 |
| point_pattern | absent | 4 | 1000 | 0.000008 | 0.000008 | 0.912 | 13448 | 21768 |
| vertex_pattern | absent | 1 | 1000 | 0.000006 | 0.000008 | 1.318 | 13216 | 21536 |
| vertex_pattern | absent | 4 | 1000 | 0.000006 | 0.000009 | 1.425 | 13448 | 21768 |
| primitive_pattern | absent | 1 | 1000 | 0.000006 | 0.000008 | 1.414 | 13216 | 21536 |
| primitive_pattern | absent | 4 | 1000 | 0.000006 | 0.000009 | 1.581 | 13448 | 21768 |
| detail_pattern | absent | 1 | 1000 | 0.000005 | 0.000008 | 1.424 | 13216 | 21536 |
| detail_pattern | absent | 4 | 1000 | 0.000006 | 0.000008 | 1.418 | 13448 | 21768 |
| all | absent | 1 | 1000 | 0.000006 | 0.000008 | 1.214 | 12904 | 20448 |
| all | absent | 4 | 1000 | 0.000006 | 0.000008 | 1.287 | 13136 | 20680 |
| all_inverse | absent | 1 | 1000 | 0.000007 | 0.000008 | 1.297 | 12952 | 21360 |
| all_inverse | absent | 4 | 1000 | 0.000006 | 0.000009 | 1.452 | 13184 | 21592 |
| exclusions | absent | 1 | 1000 | 0.000007 | 0.000010 | 1.383 | 16528 | 24584 |
| exclusions | absent | 4 | 1000 | 0.000007 | 0.000008 | 1.184 | 16760 | 24816 |
| exclusions_inverse | absent | 1 | 1000 | 0.000006 | 0.000009 | 1.383 | 16728 | 24880 |
| exclusions_inverse | absent | 4 | 1000 | 0.000007 | 0.000009 | 1.326 | 16960 | 25112 |
| default | empty | 1 | 1000 | 0.000006 | 0.000008 | 1.436 | 13336 | 23808 |
| default | empty | 4 | 1000 | 0.000007 | 0.000010 | 1.363 | 17888 | 28360 |
| inverse | empty | 1 | 1000 | 0.000006 | 0.000008 | 1.495 | 13288 | 22896 |
| inverse | empty | 4 | 1000 | 0.000007 | 0.000009 | 1.382 | 17840 | 27448 |
| point_pattern | empty | 1 | 1000 | 0.000007 | 0.000009 | 1.393 | 15816 | 26224 |
| point_pattern | empty | 4 | 1000 | 0.000008 | 0.000010 | 1.355 | 20368 | 30776 |
| vertex_pattern | empty | 1 | 1000 | 0.000007 | 0.000010 | 1.433 | 15816 | 26224 |
| vertex_pattern | empty | 4 | 1000 | 0.000008 | 0.000010 | 1.296 | 20368 | 30776 |
| primitive_pattern | empty | 1 | 1000 | 0.000009 | 0.000011 | 1.222 | 15816 | 26224 |
| primitive_pattern | empty | 4 | 1000 | 0.000008 | 0.000012 | 1.463 | 20368 | 30776 |
| detail_pattern | empty | 1 | 1000 | 0.000006 | 0.000010 | 1.473 | 15816 | 26224 |
| detail_pattern | empty | 4 | 1000 | 0.000008 | 0.000010 | 1.326 | 20368 | 30776 |
| all | empty | 1 | 1000 | 0.000006 | 0.000009 | 1.466 | 15504 | 25136 |
| all | empty | 4 | 1000 | 0.000007 | 0.000010 | 1.452 | 20056 | 29688 |
| all_inverse | empty | 1 | 1000 | 0.000006 | 0.000009 | 1.448 | 15552 | 26048 |
| all_inverse | empty | 4 | 1000 | 0.000008 | 0.000010 | 1.285 | 20104 | 30600 |
| exclusions | empty | 1 | 1000 | 0.000007 | 0.000010 | 1.381 | 19128 | 29272 |
| exclusions | empty | 4 | 1000 | 0.000008 | 0.000012 | 1.363 | 23680 | 33824 |
| exclusions_inverse | empty | 1 | 1000 | 0.000008 | 0.000011 | 1.470 | 19328 | 29568 |
| exclusions_inverse | empty | 4 | 1000 | 0.000009 | 0.000011 | 1.293 | 23880 | 34120 |
| default | selected | 1 | 1000 | 0.000007 | 0.000010 | 1.320 | 14968 | 25440 |
| default | selected | 4 | 1000 | 0.000009 | 0.000011 | 1.299 | 19552 | 30024 |
| inverse | selected | 1 | 1000 | 0.000006 | 0.000009 | 1.371 | 14768 | 25144 |
| inverse | selected | 4 | 1000 | 0.000007 | 0.000010 | 1.351 | 19352 | 29728 |
| point_pattern | selected | 1 | 1000 | 0.000007 | 0.000010 | 1.426 | 15888 | 26392 |
| point_pattern | selected | 4 | 1000 | 0.000008 | 0.000012 | 1.484 | 20472 | 30976 |
| vertex_pattern | selected | 1 | 1000 | 0.000007 | 0.000009 | 1.355 | 15688 | 26096 |
| vertex_pattern | selected | 4 | 1000 | 0.000007 | 0.000011 | 1.417 | 20272 | 30680 |
| primitive_pattern | selected | 1 | 1000 | 0.000007 | 0.000009 | 1.321 | 15888 | 26392 |
| primitive_pattern | selected | 4 | 1000 | 0.000008 | 0.000010 | 1.373 | 20472 | 30976 |
| detail_pattern | selected | 1 | 1000 | 0.000007 | 0.000010 | 1.449 | 15888 | 26392 |
| detail_pattern | selected | 4 | 1000 | 0.000007 | 0.000011 | 1.429 | 20472 | 30976 |
| all | selected | 1 | 1000 | 0.000006 | 0.000010 | 1.618 | 16176 | 26192 |
| all | selected | 4 | 1000 | 0.000008 | 0.000012 | 1.478 | 20760 | 30776 |
| all_inverse | selected | 1 | 1000 | 0.000008 | 0.000010 | 1.310 | 16224 | 27104 |
| all_inverse | selected | 4 | 1000 | 0.000008 | 0.000012 | 1.516 | 20808 | 31688 |
| exclusions | selected | 1 | 1000 | 0.000008 | 0.000010 | 1.381 | 19800 | 30328 |
| exclusions | selected | 4 | 1000 | 0.000009 | 0.000011 | 1.257 | 24384 | 34912 |
| exclusions_inverse | selected | 1 | 1000 | 0.000010 | 0.000011 | 1.160 | 20000 | 30624 |
| exclusions_inverse | selected | 4 | 1000 | 0.000009 | 0.000012 | 1.407 | 24584 | 35208 |

### Text gather compiler foundation accepted

C.2 now combines the numeric implementation `8319b320` with immutable Text
leaves. Public additions were reviewed separately in `03437c73`: five Text
instructions and `text_register`, without new Value/Ty storage or a numeric
Text width. The body compiler, separate bank, Collect ownership, fusion,
source/capture snapshots, strict Core execution, GPU refusal and actual
JavaScript/export/worker paths are recorded in
[text-gather-validation.md](text-gather-validation.md). Unsupported Text
transformations retain structured Core or explicit qualification refusals.

Final feature requests 60211 and 31650 exited 0, including actual one/eight
worker execution, arbitrary byte/NUL tables and causes, independent Text
Cartesian sources, skipped chunk boundaries and error ordering. Earlier
46783 passed Flow/Graph/GPU/dependency checks; its JavaScript quoting failure
is retained and fixed with the existing reversible codec. Root full-native,
production catalog/editor/source/CLI/API/dependency request 93275 exited 0.
Existing numeric region goldens and render fixtures remain unchanged.

Quiet million-row assignment request 90509 exited 0 with exact native bytes.
Median-three costs at one/four domains are 14.377×/4.117× the direct native
indexed loop, with all timings and initial-domain allocations retained in
the evidence document. These measurements do not qualify Name From Groups
or any other whole SOP. C.2's language checks are complete; the whole-node
2× gate and B.13/B.14 remain open. This acceptance excludes the independently
measured 43-line Float-span optimization in `Packed.run_typed`.

### Typed Float operands dispatch once per active span (shared prerequisite)

The typed CPU runner adds 43 lines specializing Float-bank Binary, Fma,
Checked_mul and Checked_fma instructions before their existing generic cases.
It chooses banks, operator and checked projection once per active span, then
loads the Float register array directly with precomputed operand offsets.
Mixed-bank cases remain unchanged. Guards, their lazy span cache, gather's
lane-major ordering, Text storage, folds and scans retain their existing
execution. Checked multiplication retains `Sys.opaque_identity` and its
separate rounding; FMA remains the explicit single-rounded operation.

Focused request 58211 exited 0 for `@lib/flow/runtest
@lib/flow_ir/runtest @lib/flow_web/runtest @lib/flow_sop/runtest
@lib/flow_sop/point_jitter_draft
_build/default/lib/flow_sop/test_point_jitter.exe`
(`/tmp/rays-point-jitter-float-spans-focused.log`). Existing tests cover mixed
FMA banks, checked native/reference/JavaScript bits, 32,769-element checked
projections, overflow followed by zero, lazy selected and untaken errors,
signed zero, exact integers, gather, Text, folds and domain identity. The full
Point Jitter native 4-ULP, strict/reference, domain/grain, immutable payload,
normal retention, parameter/cache and exact cause recipe passes.

ARM object evidence is retained in
`/tmp/rays-point-jitter-float-span-assembly.txt`. The direct Mul loop at
`0x9f98` loads two Float operands, multiplies, validates and stores without
per-lane bank selection or an operator jump. The checked product at `0xbfac`
still allocates its deliberate 16-byte opaque box before FMUL/store/reload;
this wave does not claim to remove that remaining cost.

Quiet same-protocol first-four request 90069 exited 0 after all preflights,
using the binary linked by 58211. Apple M1, OCaml 5.3.0 dev profile, one
million real grid points and 998,001 quads, grain 4096, median of three fresh
cold-session cooks, domains 1/4. Four-domain allocations cover only the
initial domain. Log: `/tmp/rays-point-jitter-float-spans-bench-first.log`.
The previous column is the retained Int-annotation table 30465.

| Mode | Domains | Previous Lisp seconds | Native seconds | Float-span Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---:|---:|---:|---:|---:|---:|
| defaults | 1 | 0.548117 | 0.020986 | 0.493282 | **23.505×** | 72015704 | 617676688 |
| defaults | 4 | 0.229277 | 0.009415 | 0.215462 | **22.885×** | 39436688 | 360730456 |
| selected optional inputs | 1 | 0.671244 | 0.025912 | 0.674611 | **26.035×** | 48016440 | 732932640 |
| selected optional inputs | 4 | 0.271113 | 0.007448 | 0.267212 | **35.877×** | 30072912 | 412091568 |

The default Lisp times fall about 10.0% and 6.0%. Selected optional times
change by +0.5% and −1.4%; the prior allocation regression remains. All four
unchanged 2× gates still fail. This is a shared execution improvement with
measured limits, not acceptance of a Point Jitter port. No registration or
native removal is claimed, and no unchanged-code repeat replaces this table.

### Ordered one-lane guards avoid repeated predicate allocations

The shared typed runner hoists its predicate closure once per chunk and
dispatches a single guarded lane directly without the interval scanner.
ARM evidence confirms removal of the former 40-byte per-invocation closure;
lazy nested predicates never inspect a later lane. Focused request 92200
passed IR, Web, FlowSOP and the Point Jitter, Group Delete, Rename Attributes
and Set Color drafts. A nested Text regression covers 32768/32769 rows,
untaken bad reads, exact error causes, both fusion modes and 1/4/8 domains.
No public API changed.

Quiet request 99638 retained million-row native preflight and median-three
timing: domains 1 Native 0.006353 s / 8000168 B, Packed 0.079464 s /
17180608 B, **12.508×**; domains 4 Native 0.006478 s / 8000168 B,
Packed 0.022348 s / 10388728 initial-domain B, **3.450×**. Roughly 80 MB
of one-domain allocations are removed against the original 90509 baseline,
but both 2× gates still fail. All prior tables and the contaminated sampled
profile caveat are preserved in [text-gather-validation.md](text-gather-validation.md).
Logs: `/tmp/rays-text-one-lane-guard-focused.log` and
`/tmp/rays-text-one-lane-guard-bench.log`. No whole port is qualified.

### One-row numeric writes validate and install owned planes directly

The actual Detail route is a dense Vec4 array through `Attribute_kernel.write_storage`, not the constant-source consumer. The shared writer now handles count one after the existing shape/count check: it checks each finite component in order, then installs fresh one-element planes. This avoids the atomic finite flag and parallel range dispatch. Counts zero and greater than one retain their existing paths; all ordinary and source-descriptor callers share this boundary. No API or node-specific callback was added.

Combined focused request **92200** exited 0 for FlowSOP, Set Color, IR, Web, Point Jitter, Group Delete and Rename Attributes. The regular XYZ writer regression now includes count one alongside zero and 32769, exact signed-zero/domain bytes, fresh ownership and count/nonfinite failure immutability. Existing all-owner/type/raw-72 and strict/reference/UI/cache proofs passed unchanged. Files: `lib/flow_sop/attribute_kernel.ml` and `lib/flow_sop/test_attribute_kernel.ml`; the draft harness remains outside this shared change.

Quiet actual-writer request **52627** exited 0, following the unchanged six-config baseline **87949**. Both use the same million-point input, dense one-row Vec4, domains one/four, grain 4096, median three samples of 1000 direct writes and GC outside timing. These measurements include owned-plane creation and geometry installation, with no Sessions. Allocations decrease in every row; five wall times decrease and the absent/one-domain outlier increases. Both outcomes are retained. Logs: `/tmp/rays-color-one-row-writer-before.log`, `/tmp/rays-color-one-row-writer-after.log`.

| Cd | Domains | Before seconds/write | After seconds/write | Before bytes | After bytes |
|---|---:|---:|---:|---:|---:|
| absent | 1 | 0.000000171 | 0.000000274 | 824 | 696 |
| absent | 4 | 0.000000309 | 0.000000099 | 1480 | 696 |
| vec4 | 1 | 0.000000165 | 0.000000103 | 824 | 696 |
| vec4 | 4 | 0.000000299 | 0.000000102 | 1480 | 696 |
| wrong_float | 1 | 0.000000166 | 0.000000096 | 824 | 696 |
| wrong_float | 4 | 0.000000298 | 0.000000097 | 1480 | 696 |

Quiet whole-cook request **1647** exited 0 on the freshly linked 92200 snapshot. This retains every predetermined Detail configuration, median three samples of 1000 fresh cold Sessions, million-point input, grain 4096 and native exact-byte preflight. Session create/close and GC remain outside the clock; context and cook remain inside. Four-domain allocations cover the initial domain. Earlier six-row failures and the unused constant-consumer cut remain above. Log: `/tmp/rays-set-color-one-row-detail-bench.log`.

| Cd | Domains | Native seconds | Lisp seconds | Printed ratio | Native bytes | Lisp bytes |
|---|---:|---:|---:|---:|---:|---:|
| absent | 1 | 0.000004535 | 0.000009071 | 2.000× | 9960 | 26128 |
| absent | 4 | 0.000004806 | 0.000009258 | 1.926× | 10192 | 26360 |
| vec4 | 1 | 0.000004579 | 0.000008513 | 1.859× | 10120 | 26864 |
| vec4 | 4 | 0.000004639 | 0.000009025 | 1.945× | 10352 | 27096 |
| wrong_float | 1 | 0.000004869 | 0.000009137 | 1.877× | 10120 | 26864 |
| wrong_float | 4 | 0.000005256 | 0.000010315 | 1.962× | 10352 | 27096 |

The absent/one-domain ratio prints 2.000 at three-decimal precision. The logged nine-decimal times cannot distinguish a pass from a slight failure at the exact 2× boundary; there is no unrounded predicate in this harness. This row is unresolved and is not accepted as passing. Set Color stays unregistered and B.11 incomplete. The isolated writer occupies only a small part of the whole cold cook, so the next diagnostic should profile that whole route rather than repeat unchanged timings or add another unmeasured writer branch.

### Encoded normalization retains workspace phase counts

The first production encoded-field port exposed a shared instrumentation gap:
normalizers evaluate their pure checked helper twice for canonicalization,
outside the existing suppressed node-body compilation scope. The bloom
workspace therefore reported extra workspace Evaluate invocations during
checked lowering. Original production request 67783 retained that failure
in `/tmp/rays-rename-attributes-production-focused.log`.

`Encoded_parameters.for_node` now uses the existing `Phase_timer.without`
around internal normalization. Canonicalization, idempotence checks, errors
and execution remain unchanged; their duration belongs to the surrounding
phase. Request 19605 passed every semantic test including bloom's unchanged
one-Evaluate/one-Lower assertion, with only the intended manifest diff.
The direct encoded parameter-edit regression also asserts zero workspace
Evaluate invocations and passed in request 11682. Logs:
`/tmp/rays-rename-attributes-production-focused2.log` and
`/tmp/rays-rename-attributes-native-integration.log`.

## Rename Attributes production port

The complete native wrapper and `attribute_lifecycle.rename` were read. The
Lisp recipe applies generic `sop/rename_attr` in encoded rule order; it adds no
node-specific host callback. Owner aliases and policies use native ASCII
trim/lower canonicalization. Every rewrite is validated before construction,
including a malformed later rule following an earlier cooked conflict. The
header keeps the native operation, label, category, slot, encoded Rules field
and default.

Combined focused gate **92200 exited 0**, including
`@lib/flow_sop/rename_attributes_draft`. The independent native factory proof
covers all four owners, Any aliases, skip/error/overwrite, literal and captured
wildcards, no-op/missing names, successive rewrites, ordered overwrites,
reserved point P and physical vertex P, empty-name cooked refusals, and exact
code/message/cause. It compares all eight storage types, ordered groups and
edge groups, raw NaN/Inf positions and attribute bytes, immutable inputs and
borrowed position/topology identity. Required inputs include empty, singleton,
a real 4,225-point quad grid, mixed polygon/polyline and 32,769 points. Strict
and reference cooks are byte identical to native at domains 1/4/8 and grains
1/97/4096. Rebuild refusals include malformed table escapes/rows, UTF-8 quoted
owners/policies, rewrite syntax, non-finite/wrong parameter types and wrong
geometry inputs. Every Rules edit has native canonical fields/key, one public
miss and a warm hit; relabeling preserves identity/key/cook. The native graph
card, full inspector and complete factory descriptor match, and direct Rules
and bypass gestures cook the expected bytes.

Quiet session **77401 exited 0** on the 92200 binary. All **50** native,
strict and reference million-point preflights passed; every measured ratio is
below the unchanged **2×** gate (maximum **1.806×**). These are metadata-only
cooks: the geometry has 1,000,000 points, 998,001 quad primitives, and twelve
physical Float attributes across all owners. Rename borrows their dense
payloads. Hardware: Apple M1, arm64, OCaml 5.3.0, Dune dev profile. Grain 4096;
wall time is the median of three samples of 1,000 fresh cold sessions, with
session creation excluded. Allocation is `Gc.allocated_bytes` on the initial
domain, including cook/output headers; multi-domain allocations are not a
whole-process total. All fifty rows are retained below. The accepted body is
embedded in `nodes/rename_attributes.rays`; its native catalog registration
is removed, while the native factory and RDK kernel remain test oracles.

Production request 67783 exposed an unused draft-test declaration and the
encoded-normalizer instrumentation gap recorded separately below. Request
19605 passed all semantic recipes after those fixes, including the normal
`lib/sop/test_lisp_ports.ml` function and required all-owner/raw fixtures;
only the intended manifest difference remained. The reviewed manifest
retains the entire parameter/slot/identity block and gains the Lisp body
marker; its digest is `59dcfe1be5f12f620e25c7b6214bc158`.

Full native request 11682 passed every render/editor/source/catalog/API
check with only the actual CLI catalog-hash snapshot difference. That
observed hash is `c1e072875e402532a4676f46daec9e9cfddd212f84ff43fe0425dda215ae10ee`.
After accepting that one-line snapshot, request **26067 exited 0** for
`@runtest-native @lib/sop/test_lisp_ports @lib/flow_sop/runtest
@lib/sop_catalog/runtest @tools/lisp/test/runtest @test/test_workspace_source
@test/test_workspace_shell @test/test_sop_catalog @tools/api_manifest/runtest
@test/dependency_gate`. Logs: `/tmp/rays-rename-attributes-production-focused2.log`,
`/tmp/rays-rename-attributes-native-integration.log` and
`/tmp/rays-rename-attributes-native-integration2.log`. Native PNGs and other
render goldens are unchanged. This is the **tenth** completed whole port:
**10/128 (7.8125%)**, with **118** still required. B.12 remains incomplete.

Command (from `lib/flow_sop`):
`opam exec -- ../../_build/default/lib/flow_sop/test_metadata_ports.exe --bench-rename-attributes`.
Logs: `/tmp/rays-text-one-lane-guard-focused.log` and
`/tmp/rays-rename-attributes-bench-before.log`.

| Mode | Domains | Native µs | Lisp µs | Ratio | Native bytes | Lisp bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| default | 1 | 5.062 | 9.140 | 1.806 | 12056 | 22480 |
| default | 4 | 6.220 | 11.211 | 1.802 | 12288 | 22712 |
| missing | 1 | 7.750 | 8.478 | 1.094 | 18520 | 27664 |
| missing | 4 | 6.245 | 9.565 | 1.532 | 18752 | 27896 |
| same | 1 | 7.195 | 9.546 | 1.327 | 21080 | 30224 |
| same | 4 | 8.280 | 9.661 | 1.167 | 21312 | 30456 |
| point_skip | 1 | 6.176 | 8.311 | 1.346 | 16480 | 25648 |
| point_skip | 4 | 6.258 | 8.483 | 1.356 | 16712 | 25880 |
| point_error | 1 | 5.162 | 7.137 | 1.383 | 14824 | 22096 |
| point_error | 4 | 5.951 | 7.485 | 1.258 | 15056 | 22328 |
| point_overwrite | 1 | 7.065 | 9.241 | 1.308 | 18168 | 27248 |
| point_overwrite | 4 | 7.129 | 9.347 | 1.311 | 18400 | 27480 |
| vertex_skip | 1 | 6.581 | 9.298 | 1.413 | 16192 | 25360 |
| vertex_skip | 4 | 6.096 | 9.146 | 1.500 | 16424 | 25592 |
| vertex_error | 1 | 5.103 | 6.967 | 1.365 | 14536 | 21816 |
| vertex_error | 4 | 5.806 | 7.805 | 1.344 | 14768 | 22048 |
| vertex_overwrite | 1 | 7.597 | 9.302 | 1.224 | 17880 | 26984 |
| vertex_overwrite | 4 | 7.222 | 10.769 | 1.491 | 18112 | 27216 |
| primitive_skip | 1 | 7.239 | 8.242 | 1.139 | 16200 | 25376 |
| primitive_skip | 4 | 7.622 | 9.513 | 1.248 | 16432 | 25608 |
| primitive_error | 1 | 6.449 | 7.824 | 1.213 | 14552 | 21832 |
| primitive_error | 4 | 5.536 | 7.513 | 1.357 | 14784 | 22064 |
| primitive_overwrite | 1 | 6.943 | 9.409 | 1.355 | 17904 | 27008 |
| primitive_overwrite | 4 | 7.337 | 12.174 | 1.659 | 18136 | 27240 |
| detail_skip | 1 | 7.885 | 9.896 | 1.255 | 16192 | 25360 |
| detail_skip | 4 | 6.028 | 9.079 | 1.506 | 16424 | 25592 |
| detail_error | 1 | 5.219 | 7.165 | 1.373 | 14536 | 21816 |
| detail_error | 4 | 5.738 | 7.485 | 1.304 | 14768 | 22048 |
| detail_overwrite | 1 | 7.764 | 9.471 | 1.220 | 17880 | 26984 |
| detail_overwrite | 4 | 8.255 | 10.434 | 1.264 | 18112 | 27216 |
| any_skip | 1 | 7.290 | 9.391 | 1.288 | 19744 | 28912 |
| any_skip | 4 | 6.815 | 9.199 | 1.350 | 19976 | 29144 |
| any_error | 1 | 5.074 | 6.822 | 1.345 | 14824 | 22096 |
| any_error | 4 | 6.303 | 7.271 | 1.154 | 15056 | 22328 |
| any_overwrite | 1 | 8.349 | 10.380 | 1.243 | 20280 | 29072 |
| any_overwrite | 4 | 7.421 | 10.866 | 1.464 | 20512 | 29304 |
| point_wildcard | 1 | 7.993 | 9.551 | 1.195 | 19192 | 28360 |
| point_wildcard | 4 | 8.949 | 10.713 | 1.197 | 19424 | 28592 |
| vertex_wildcard | 1 | 8.139 | 10.352 | 1.272 | 18872 | 28040 |
| vertex_wildcard | 4 | 7.922 | 12.175 | 1.537 | 19104 | 28272 |
| primitive_wildcard | 1 | 7.909 | 10.066 | 1.273 | 18880 | 28056 |
| primitive_wildcard | 4 | 7.604 | 10.685 | 1.405 | 19112 | 28288 |
| detail_wildcard | 1 | 8.509 | 10.822 | 1.272 | 18872 | 28040 |
| detail_wildcard | 4 | 7.552 | 10.304 | 1.364 | 19104 | 28272 |
| any_wildcard | 1 | 9.270 | 11.446 | 1.235 | 23920 | 33064 |
| any_wildcard | 4 | 9.274 | 11.327 | 1.221 | 24152 | 33296 |
| successive | 1 | 12.087 | 17.770 | 1.470 | 33760 | 50640 |
| successive | 4 | 12.144 | 17.120 | 1.410 | 33992 | 50872 |
| overwrite_order | 1 | 10.637 | 13.991 | 1.315 | 25120 | 40336 |
| overwrite_order | 4 | 9.243 | 13.097 | 1.417 | 25352 | 40568 |

### Group Delete candidate: all modes and no-op finalization

Native wrapper audit: `lib/sop/groups.ml:505-549`; kernel and local store
`lib/rdk/attrib/group_ops.ml:1809-1877,3836-3852`. The rule table retains
native owner aliases, encoded diagnostics and canonical keys. Group patterns
are compiled during cooking, blank patterns select nothing, and unused-group
selection counts ordinary and edge memberships. Metadata commits preserve
surviving group order, ordered indices, topology and all attribute storage.
The draft composes existing generic metadata primitives without calling the
old SOP body.

Original-body focused request 57986 exited 0 for
`@lib/flow_sop/metadata_ports_draft` and the benchmark executable. Log:
`/tmp/rays-group-delete-draft-focused.log`. Existing tests cover required
geometries, all eight attribute storage types, native schema/key/identity,
strict/reference/domain/grain bytes and causes, encoded refusals and every
physical parameter edit/cache. Additional Group Delete-only cases and graph
checks have been authored; their current focused validation is pending.

Quiet first full table request 46431 exited 0. Apple M1, OCaml 5.3.0 dev,
1,000,000 points, 998,001 quads, 12 groups across all four owners, grain 4096,
domains 1/4. Each sample uses 1,000 fresh cold sessions, median of three;
session creation/close and major GC are outside the clock. Every row first
passes exact native geometry-byte preflight. Four-domain allocation figures
cover the initial domain only. Log:
`/tmp/rays-group-delete-bench-before.log`.

| Mode | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---:|---:|---:|---:|---:|
| default | 1 | 0.000006 | 0.000007 | 1.287× | 14120 | 23128 |
| default | 4 | 0.000007 | 0.000012 | 1.677× | 14352 | 23360 |
| unused | 1 | 0.009196 | 0.009191 | 0.999× | 17424 | 26072 |
| unused | 4 | 0.009195 | 0.009209 | 1.002× | 17656 | 26304 |
| point | 1 | 0.000007 | 0.000011 | 1.590× | 18336 | 34584 |
| point | 4 | 0.000008 | 0.000011 | 1.343× | 18568 | 34816 |
| vertex | 1 | 0.000007 | 0.000011 | 1.516× | 18352 | 34600 |
| vertex | 4 | 0.000008 | 0.000011 | 1.476× | 18584 | 34832 |
| primitive | 1 | 0.000007 | 0.000016 | **2.343× — fails** | 18352 | 34608 |
| primitive | 4 | 0.000007 | 0.000012 | 1.687× | 18584 | 34840 |
| edge | 1 | 0.000008 | 0.000011 | 1.413× | 18384 | 34680 |
| edge | 4 | 0.000007 | 0.000012 | 1.766× | 18616 | 34912 |
| any | 1 | 0.000008 | 0.000010 | 1.366× | 17712 | 32464 |
| any | 4 | 0.000007 | 0.000011 | 1.503× | 17944 | 32696 |
| all | 1 | 0.000006 | 0.000010 | 1.642× | 15616 | 26616 |
| all | 4 | 0.000006 | 0.000009 | 1.403× | 15848 | 26848 |
| exclusions | 1 | 0.000007 | 0.000012 | 1.697× | 17264 | 30184 |
| exclusions | 4 | 0.000008 | 0.000011 | 1.294× | 17496 | 30416 |
| blank | 1 | 0.000007 | 0.000011 | 1.596× | 14200 | 30904 |
| blank | 4 | 0.000006 | 0.000009 | 1.613× | 14432 | 31136 |
| missing | 1 | 0.000006 | 0.000010 | 1.595× | 15240 | 31960 |
| missing | 4 | 0.000007 | 0.000010 | 1.454× | 15472 | 32192 |
| selected_unused | 1 | 0.009221 | 0.005835 | 0.633× | 17536 | 34568 |
| selected_unused | 4 | 0.009209 | 0.005820 | 0.632× | 17768 | 34800 |
| successive | 1 | 0.009203 | 0.005840 | 0.635× | 20432 | 67832 |
| successive | 4 | 0.009226 | 0.005846 | 0.634× | 20664 | 68064 |

25 of 26 rows pass the unchanged 2× gate. Primitive deletion at one domain
fails at 2.343×, so Group Delete remains unregistered and uncounted. Earlier
intermediate progress text incorrectly called the first 22 rows passing;
the complete-table audit found the missed row and corrected that statement.
All 26 measurements are retained here without an unchanged-code repeat.

The body has now been changed to execute its final unused-group deletion
only when `delete_unused` is true. The old body always performed a generic
metadata cook even when that option was false and the final operation did
nothing. Validation and a new full 26-row table are pending; this candidate
change does not claim that the remaining timing gate has passed.

## Group Delete production port

The full body is now in `nodes/group_delete.rays`: ordered generic group
deletion followed by unused-group deletion only when requested. The former
unconditional final no-op cook is removed; all native owner aliases, rule
order, cooked pattern failures, encoded diagnostics and Bool metadata remain.
The native catalog registration is removed with this declaration. The RDK
kernel and native SOP factory remain independent test oracles.

Focused requests 92200 and 78499 exited 0 before production extraction;
78499 covered Group Delete and Group Rename all-owner/raw-storage/error-order
cases and direct card/inspector edits and bypass cooks. The Group Delete
production function adds every required input plus ordered ordinary groups,
unused groups and raw floating attributes; the focused proof also covers all
eight storages, literal escaped names and exact causes at domains 1/4/8 and
grains 1/97/4096. Production raw-position and constructor precedence checks
are prepared; final integration remains pending until recorded below.

Quiet revised-body request 81739 exited 0. Same Apple M1/OCaml 5.3.0 dev,
1,000,000-point quad-grid, 998,001 quads, 12 groups/all four owners and
median-three samples of 1,000 fresh cold sessions as the retained negative
baseline above. Session creation/close and major GC stay outside the clock;
context creation and the whole cook stay inside. All 26 exact native-byte
preflights passed. Four-domain allocations observe the initial domain only.
Log: `/tmp/rays-group-delete-bench-after.log`.

| Mode | Domains | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
|---|---:|---:|---:|---:|---:|---:|
| default | 1 | 0.000006 | 0.000007 | 1.293× | 14120 | 19264 |
| default | 4 | 0.000007 | 0.000007 | 1.064× | 14352 | 19496 |
| unused | 1 | 0.009165 | 0.009196 | 1.003× | 17424 | 26072 |
| unused | 4 | 0.009197 | 0.009190 | 0.999× | 17656 | 26304 |
| point | 1 | 0.000009 | 0.000009 | 0.994× | 18336 | 27232 |
| point | 4 | 0.000008 | 0.000012 | 1.458× | 18568 | 27464 |
| vertex | 1 | 0.000009 | 0.000011 | 1.278× | 18352 | 27248 |
| vertex | 4 | 0.000007 | 0.000010 | 1.354× | 18584 | 27480 |
| primitive | 1 | 0.000008 | 0.000010 | 1.356× | 18352 | 27256 |
| primitive | 4 | 0.000007 | 0.000010 | 1.351× | 18584 | 27488 |
| edge | 1 | 0.000007 | 0.000012 | 1.568× | 18384 | 27304 |
| edge | 4 | 0.000008 | 0.000013 | 1.569× | 18616 | 27536 |
| any | 1 | 0.000007 | 0.000010 | 1.394× | 17712 | 26344 |
| any | 4 | 0.000008 | 0.000010 | 1.237× | 17944 | 26576 |
| all | 1 | 0.000007 | 0.000008 | 1.204× | 15616 | 23504 |
| all | 4 | 0.000006 | 0.000009 | 1.495× | 15848 | 23736 |
| exclusions | 1 | 0.000007 | 0.000009 | 1.231× | 17264 | 25544 |
| exclusions | 4 | 0.000007 | 0.000009 | 1.320× | 17496 | 25776 |
| blank | 1 | 0.000006 | 0.000008 | 1.322× | 14200 | 23176 |
| blank | 4 | 0.000006 | 0.000009 | 1.568× | 14432 | 23408 |
| missing | 1 | 0.000007 | 0.000010 | 1.521× | 15240 | 24232 |
| missing | 4 | 0.000006 | 0.000008 | 1.354× | 15472 | 24464 |
| selected_unused | 1 | 0.009219 | 0.005831 | 0.633× | 17536 | 34568 |
| selected_unused | 4 | 0.009212 | 0.005830 | 0.633× | 17768 | 34800 |
| successive | 1 | 0.009230 | 0.005828 | 0.631× | 20432 | 67832 |
| successive | 4 | 0.009221 | 0.005841 | 0.633× | 20664 | 68064 |

All 26 rows pass the unchanged 2× gate; the worst is 1.569×. The previously
failing primitive/one-domain row is 1.356×; the old 2.343× failure is retained
in the candidate table.

Production request 35825 passed all SOP tests (including the whole Group Delete
recipe), FlowSOP, both group drafts, IR/Web and the dependency gate; its only
failure was the intended catalog diff. The reviewed diff preserves operation,
slot, full fields/defaults/labels and output; the declaration moves to Lisp.
The promoted manifest digest is `2420a90dc3d2ca7e3240d62d51bfc657`.

Full integration request 57881 exited 0 for `@runtest-native`, the whole SOP
port recipe, FlowSOP/catalog/CLI, workspace source/shell, live node menu,
public API and dependency checks. The actual native suites executed in 36290;
57881 reused their successful results and ran the updated whole-port recipe
and CLI snapshot. The sole CLI change is `tools/lisp/test/ml.t` catalog hash
`f0d64222246d76c5a26d05323a658867ce426611b8534b68b9f2b4007fae919c`.
No render fixtures or public APIs changed. Logs are
`/tmp/rays-group-delete-production-focused.log` and
`/tmp/rays-group-delete-native-integration2.log`.

One verification concern remains recorded for phase review: 36290 also failed
the existing Rename Attributes comparison with no case context. Focused
diagnostic request 35016 and full request 57881 subsequently passed both
Rename Attributes and Group Delete. Read-only audits found no unordered
rename iteration or shared per-cook tables; the original mismatch remains
unexplained. The shared test now reports input counts, exact rule text,
domains/grain and digests, saves mismatched native/actual results under
`/tmp/rays-port-<key>-*.marshal`, and has a direct `--rename-attributes` entry
for reproducing this concern. The failed log is retained at
`/tmp/rays-group-delete-native-integration.log`; this paragraph does not claim
that the underlying issue was fixed.

Group Delete is completed port 11/128 (8.59%); 117 whole ports remain.
B.12 remains unchecked until all seven metadata ports and its boundary gate
are complete.

### Typed one-lane fills and copies retain bulk spans

The typed runner directly stores one-element Int/Float/Text fills and copies
one-element contiguous Int inputs, retaining original bulk operations for
longer spans. IR/Web/SOP/lowering request 35825 passed its new boundary,
lazy-source and exact-byte regression at 1/4/8 domains. No public API changed.

Quiet request 92162 exited 0. One million rows, strict Packed Collect, native
byte preflight and median-three force-only protocol: domains 1 Native
0.006332 s / 8000168 B, Packed 0.065951 s / 17211496 B, **10.416×**; domains 4
Native 0.006226 s / 8000168 B, Packed 0.018644 s / 10396176 initial-domain B,
**2.995×**. Packed times improve about 17% against 99638. The one-domain
allocation increase of 30888 B is retained; no allocation-free claim is made.
Both 2× gates still fail. Full measured profile/caveats and before/after
evidence are in `text-gather-validation.md`; no whole node is counted.
Log: `/tmp/rays-text-one-lane-fill-bench.log`.
## Group Rename whole recipe and candidate performance

Focused request **78499** exited 0 including `@lib/flow_sop/group_rename_draft`.
The draft uses the generic `sop/rename_group` operation and an ordered geometry
reduce, without a node-specific runtime callback. Native/reference/strict
results agree byte for byte, including error code/message/cause, over empty,
one, real 4225-point quad grid, mixed polygon/polyline, raw nonfinite payload,
and 32769-point inputs at domains 1/4/8 and grains 1/97/4096. Coverage includes
Point/Vertex/Primitive/Edge/Any, all skip/error/overwrite/union policies,
destination-first explicit union order, wildcard and successive snapshots,
escaped UTF8/backslash/space/bracket/star names, eager table/owner/conflict
refusals, cooked malformed rewrite and first-error precedence, immutable
inputs, native schema/identity/key, parameter edit/miss/hit/relabel behavior,
full descriptor/card/inspector projection, direct edits and bypass.

Quiet request **88378** exited 0 on the executable validated by 78499. Machine:
Apple M1 arm64, OCaml 5.3.0, Dune dev profile; no competing builds or timings.
Input is a real 1,000,000-point / 998,001-quad grid with 18 ordinary/edge groups,
including explicitly reverse-ordered membership. Each of the 68 rows first
checks large-input native/reference/strict bytes/errors. Wall time below is
the median of three whole-cook samples at grain 4096. Predetermined metadata
paths amortize each sample over 1000 fresh cold sessions; genuine dense union
paths use one fresh cold session to avoid retaining 1000 multi-million-element
ordered outputs. Session creation, node construction, preflight serialization,
and collection before a sample are outside the timer. Allocations are
`Gc.allocated_bytes` on the initial domain, not whole-process domain-4 totals.
All original measured rows are retained; the unchanged 2x gate passes all 68,
with the worst row `edge_skip` domain 1 at 1.856x. Raw output:
`/tmp/rays-group-rename-bench-before.log`.

| Mode | Domains | Cold sessions/sample | Native us | Lisp us | Ratio | Native bytes/cook | Lisp bytes/cook |
|---|---:|---:|---:|---:|---:|---:|---:|
| default | 1 | 1000 | 5.903 | 7.954 | 1.347 | 16056 | 22192 |
| default | 4 | 1000 | 7.150 | 9.726 | 1.360 | 16288 | 22424 |
| missing | 1 | 1000 | 8.001 | 10.593 | 1.324 | 25672 | 35832 |
| missing | 4 | 1000 | 7.688 | 10.660 | 1.387 | 25904 | 36064 |
| same | 1 | 1000 | 12.138 | 14.740 | 1.214 | 32960 | 43136 |
| same | 4 | 1000 | 10.919 | 14.484 | 1.326 | 33192 | 43368 |
| point_skip | 1 | 1000 | 9.137 | 10.470 | 1.146 | 22512 | 32688 |
| point_skip | 4 | 1000 | 7.622 | 10.858 | 1.425 | 22744 | 32920 |
| point_error | 1 | 1000 | 7.923 | 7.818 | 0.987 | 19336 | 27112 |
| point_error | 4 | 1000 | 7.299 | 9.935 | 1.361 | 19568 | 27344 |
| point_overwrite | 1 | 1000 | 10.438 | 11.632 | 1.114 | 26624 | 36720 |
| point_overwrite | 4 | 1000 | 9.496 | 12.891 | 1.357 | 26856 | 36952 |
| point_union | 1 | 1 | 414.133 | 450.134 | 1.087 | 152192 | 162272 |
| point_union | 4 | 1 | 238.895 | 169.039 | 0.708 | 160264 | 168608 |
| vertex_skip | 1 | 1000 | 8.748 | 11.029 | 1.261 | 22512 | 32688 |
| vertex_skip | 4 | 1000 | 10.256 | 12.162 | 1.186 | 22744 | 32920 |
| vertex_error | 1 | 1000 | 7.125 | 8.774 | 1.231 | 19336 | 27120 |
| vertex_error | 4 | 1000 | 7.296 | 8.486 | 1.163 | 19568 | 27352 |
| vertex_overwrite | 1 | 1000 | 9.797 | 11.663 | 1.190 | 26624 | 36736 |
| vertex_overwrite | 4 | 1000 | 9.054 | 11.610 | 1.282 | 26856 | 36968 |
| vertex_union | 1 | 1 | 1539.946 | 1613.140 | 1.048 | 526192 | 536280 |
| vertex_union | 4 | 1 | 694.036 | 556.946 | 0.802 | 555120 | 559488 |
| primitive_skip | 1 | 1000 | 9.835 | 11.436 | 1.163 | 22528 | 32712 |
| primitive_skip | 4 | 1000 | 9.517 | 10.954 | 1.151 | 22760 | 32944 |
| primitive_error | 1 | 1000 | 6.679 | 8.427 | 1.262 | 19528 | 27320 |
| primitive_error | 4 | 1000 | 6.636 | 9.280 | 1.398 | 19760 | 27552 |
| primitive_overwrite | 1 | 1000 | 12.405 | 18.149 | 1.463 | 26640 | 36752 |
| primitive_overwrite | 4 | 1000 | 10.481 | 11.993 | 1.144 | 26872 | 36984 |
| primitive_union | 1 | 1 | 437.021 | 454.903 | 1.041 | 151952 | 162048 |
| primitive_union | 4 | 1 | 189.066 | 190.020 | 1.005 | 159784 | 170544 |
| edge_skip | 1 | 1000 | 7.595 | 14.095 | 1.856 | 21936 | 32112 |
| edge_skip | 4 | 1000 | 7.938 | 10.736 | 1.352 | 22168 | 32344 |
| edge_error | 1 | 1000 | 6.559 | 7.977 | 1.216 | 19336 | 27112 |
| edge_error | 4 | 1000 | 6.404 | 8.933 | 1.395 | 19568 | 27344 |
| edge_overwrite | 1 | 1000 | 10.182 | 12.028 | 1.181 | 26088 | 36200 |
| edge_overwrite | 4 | 1000 | 10.829 | 12.871 | 1.189 | 26320 | 36432 |
| edge_union | 1 | 1 | 875.950 | 771.046 | 0.880 | 276344 | 286448 |
| edge_union | 4 | 1 | 320.911 | 368.118 | 1.147 | 289488 | 302552 |
| any_skip | 1 | 1000 | 12.747 | 10.796 | 0.847 | 27056 | 37232 |
| any_skip | 4 | 1000 | 8.969 | 10.894 | 1.215 | 27288 | 37464 |
| any_error | 1 | 1000 | 7.209 | 8.147 | 1.130 | 19336 | 27112 |
| any_error | 4 | 1000 | 7.082 | 8.059 | 1.138 | 19568 | 27344 |
| any_overwrite | 1 | 1000 | 11.218 | 12.717 | 1.134 | 30192 | 40016 |
| any_overwrite | 4 | 1000 | 10.848 | 13.815 | 1.274 | 30424 | 40248 |
| any_union | 1 | 1 | 3103.018 | 2983.093 | 0.961 | 1030536 | 1040352 |
| any_union | 4 | 1 | 1069.069 | 1205.206 | 1.127 | 1082656 | 1095808 |
| point_wildcard | 1 | 1000 | 10.255 | 13.181 | 1.285 | 27776 | 37952 |
| point_wildcard | 4 | 1000 | 10.473 | 13.644 | 1.303 | 28008 | 38184 |
| vertex_wildcard | 1 | 1000 | 11.447 | 12.362 | 1.080 | 27776 | 37952 |
| vertex_wildcard | 4 | 1000 | 12.339 | 16.651 | 1.349 | 28008 | 38184 |
| primitive_wildcard | 1 | 1000 | 11.397 | 12.099 | 1.062 | 27792 | 37976 |
| primitive_wildcard | 4 | 1000 | 11.598 | 14.214 | 1.226 | 28024 | 38208 |
| edge_wildcard | 1 | 1000 | 10.272 | 13.237 | 1.289 | 27104 | 37280 |
| edge_wildcard | 4 | 1000 | 10.367 | 12.642 | 1.219 | 27336 | 37512 |
| any_wildcard | 1 | 1000 | 12.375 | 15.732 | 1.271 | 34352 | 44512 |
| any_wildcard | 4 | 1000 | 12.754 | 15.008 | 1.177 | 34584 | 44744 |
| successive | 1 | 1000 | 16.050 | 21.640 | 1.348 | 48112 | 71312 |
| successive | 4 | 1000 | 16.890 | 22.783 | 1.349 | 48344 | 71544 |
| union_chain | 1 | 1 | 6095.171 | 6241.083 | 1.024 | 2039208 | 2059280 |
| union_chain | 4 | 1 | 2242.088 | 2723.932 | 1.215 | 2122528 | 2190376 |
| point_ordered_union | 1 | 1 | 4645.109 | 4638.910 | 0.999 | 5612312 | 5622440 |
| point_ordered_union | 4 | 1 | 4546.881 | 4131.079 | 0.909 | 5619624 | 5630608 |
| vertex_ordered_union | 1 | 1 | 17199.039 | 17543.077 | 1.020 | 22317664 | 22327808 |
| vertex_ordered_union | 4 | 1 | 16810.179 | 16901.016 | 1.005 | 22360472 | 22361200 |
| primitive_ordered_union | 1 | 1 | 4547.834 | 4504.919 | 0.991 | 5601152 | 5611296 |
| primitive_ordered_union | 4 | 1 | 4360.914 | 4332.066 | 0.993 | 5608024 | 5615040 |
| any_ordered_union | 1 | 1 | 26432.991 | 26714.087 | 1.011 | 33478024 | 33487952 |
| any_ordered_union | 4 | 1 | 25874.853 | 24825.096 | 0.959 | 33528112 | 33528712 |


Production integration now uses `nodes/group_rename.rays`, with unique helper
names and the original native header; rewrite errors remain at cook time.
Its native catalog registration and pending declaration were removed. Focused
request 7842 passed the complete SOP recipe, Flow_sop, candidate projection
and dependency checks; its only difference was the reviewed catalog manifest.
The manifest digest is `aaa406af3e1f7aed181887624251eda1`, preserving the node
key, operation, category, label, required slot, field schema/default and output.

Native integration request 28274 passed the whole-node recipes (including
Rename Attributes, Group Delete and Group Rename), native/editor/GPU rendering,
workspace, catalog, public API and dependency checks. Its only failure was the
expected CLI catalog hash; the observed hash
`ce0b4c3fc10c5efdacd72afc7ed84886e560c092974c7f69ed518e7627c6ffde`
was recorded in `tools/lisp/test/ml.t`. Request 23005 then exited 0 for the same
full alias set, reusing successful unchanged checks. Logs are
`/tmp/rays-group-rename-native-integration.log` and
`/tmp/rays-group-rename-native-integration2.log`. No render fixtures or public
API changed. Group Rename is whole port **12/128 (9.375%)**; 116 remain.
B.12 stays open until Swap Attributes completes. The earlier unexplained
Rename Attributes failure remains recorded under Group Delete for phase review;
this integration passed with the mismatch diagnostics enabled.

### Proven-total prefixes reuse typed spans

Gather/Text Collect now batches only its leading proven-total instructions
through the existing span executor. Fallible instructions and lazy captures
retain reference lane order; malformed actual input storage declines batching.
Private register writes preserve guarded forcing, first-error code/message/cause,
rollback, Product/skip, ordered accumulators and discarded sinks. Focused 69619
failed only a new fixture's `int/abs` spelling; canonical `abs` corrected it.
Request 50119 exited 0 for IR/Web/FlowSop with wrapping Int, arbitrary native Text
bytes, malformed selected/untaken storage and block/chunk error regressions at
domains 1/4/8 with fusion off/on. No public API changed.

Quiet 72326 exited 0: Apple M1, OCaml 5.3.0 dev profile, strict Packed Collect,
one million rows, exact native-byte preflight, median-three force-only timing.
Domain 1 Native 0.006232 s / 8000168 B, Packed 0.055121 s / 17211544 B,
**8.845× FAIL**; domain 4 Native 0.006342 s / 8000168 B, Packed 0.015340 s /
10396088 initial-domain B, **2.419× FAIL**. Compared with 92162, Packed time
improved approximately 16.4%/17.7%; allocation changes were +48 B/-88 B.
Both unchanged 2× gates remain unmet and no Text port is counted. Full protocol,
complete rows and retained failures are in `text-gather-validation.md`;
log `/tmp/rays-text-total-prefix-bench.log`.

### Unjournaled zero-retention sessions omit persistent cache work

The internal Lisp cooker retains no entries. Its ordinary, unjournaled path
now skips persistent key construction, lookup, insertion and the insertion-only
payload-component census. The per-cook memo, volatile predicate, miss counters,
input/result identities, delta/fact checks, cancellation and diagnostics retain
their existing behavior. A speculative worker with a journal still constructs
real keys and records cache reads/writes for ordered parent replay; positive
entry capacity with a zero byte budget also retains the existing cache path.
The two eager domain-default calls remain unchanged, so the native denominator
has not been optimized in this measurement.

Focused launcher **1345 exited 0**:
`opam exec -- _build/default/tools/check.exe @lib/sop/runtest @lib/flow_sop/runtest @lib/flow_sop/set_color_draft @test/dependency_gate`.
New regressions exercise zero-retention shared-DAG memoization, ordinary and
volatile parallel journals, reused physical IDs, packed-instance materialization,
post-cook cancellation and selective fact refusals. Existing retained-cache,
branch transaction, ownership, exact domain, typed error and authoritative
whole-port oracles passed. Color's existing raw 72 cases, all-owner/storage,
strict/reference, schema/cache and graph gestures also passed.
Log: `/tmp/rays-zero-retention-focused.log`.

Quiet **7462 exited 0** on the freshly linked executable:
`opam exec -- ./test_set_color.exe --bench-detail-batch`
from `_build/default/lib/flow_sop`. Apple M1, OCaml 5.3.0 dev profile; unchanged
million-point input and grain 4096; all six predetermined Detail configurations;
native-byte preflight; median three samples of 1000 fresh cold sessions. Session
creation/closing and major GC are outside the timer; context construction and
cook are inside. Allocation is measured on the initial domain. The gate uses
unrounded `Lisp time <= 2 * Native time` and all six flags are **PASS**.

| Existing Cd | Domains | Native s | Lisp s | Ratio | Native B | Lisp B | Gate |
|---|---:|---:|---:|---:|---:|---:|---|
| absent | 1 | 0.000004736900 | 0.000007426977 | 1.567898128 | 9960 | 21488 | PASS |
| absent | 4 | 0.000004714966 | 0.000007430077 | 1.575849515 | 10192 | 21720 | PASS |
| vec4 | 1 | 0.000004625797 | 0.000007817030 | 1.689877332 | 10120 | 22056 | PASS |
| vec4 | 4 | 0.000004823208 | 0.000008419991 | 1.745724172 | 10352 | 22288 | PASS |
| wrong float | 1 | 0.000004899979 | 0.000007411003 | 1.512456209 | 10120 | 22056 | PASS |
| wrong float | 4 | 0.000004745007 | 0.000007992983 | 1.684504070 | 10352 | 22288 | PASS |

Complete log: `/tmp/rays-set-color-zero-retention-detail-bench.log`.
All earlier six-row failures and the rounded boundary result remain above.
This shared optimization changes only `lib/sop/session.ml`, with regular checks
in `test_parallel_branches.ml` and `test_facts.ml`, and the internal-session
contract in `specification/sop.md`; no public API changed. Set Color remains
unregistered pending its complete current-runtime performance table and whole
production/native oracle gates. No 4-ULP thresholds, exact byte comparisons,
render goldens or target counts changed.

## Swap Attributes whole recipe and initial candidate performance

Focused **7245** exited 0 for `@lib/flow_sop/swap_attributes_draft` and
`@lib/flow_sop/runtest`; strengthened-fixture focused **19041** also exited 0.
The pending source uses the original native header and generic `sop/swap_attr`
inside an ordered geometry reduce. Its unique helpers preserve encoded
owner/method canonicalization and eager forward/backward rewrite validation
for every rule. There is no node-specific runtime callback or API change.

The strong candidate proof covers 320 rule configurations over empty, one,
real 4225-point quad grid, mixed polygon/polyline, raw NaN/Inf/-0 payload and
32769-point inputs. All four owners, swap/move/copy, all eight storages,
canonical Point P and other-owner physical P, missing source inverse fallback,
wildcard/same/successive overlaps, attribute order and immutable input bytes
agree with native and reference at domains 1/4/8 and grains 1/97/4096. Exact
constructor/cook code/message/cause and validation precedence, full native
schema/identity/key, edits/miss/hit/relabel, descriptor/card/inspector projection
and direct parameter/bypass gestures pass. Canonical P timing uses distinct
finite Float3 planes with a checked different data ID, exercising the native
position-change branch rather than aliasing the original position buffer.

Quiet **70484** completed all 212 rows and every large-input native/reference/
strict preflight, then exited 2 for the unchanged, unrounded `time > 2*native`
gate. Hardware: Apple M1 arm64, OCaml 5.3.0, Dune dev profile; no competing CPU
builds/timings. Input: real 1,000,000-point / 998,001-quad grid, three Float
attributes per owner (12 total), plus one separate Point Float3 column. Native
metadata slots share immutable storage regardless of the eight storage kinds;
the semantic fixture covers them all without an unnecessarily large timing
inventory. Wall times are medians of three fresh-cold whole-cook samples at
grain 4096. Session creation, node construction, preflight serialization and
GC before each sample are outside the timer. Allocations are initial-domain
`Gc.allocated_bytes`, not whole-process domain-4 totals. The fixed protocol
used 1000 cold sessions/sample for all 170 metadata rows and conservatively
one for all 42 canonical-P rows; both implementations use the same batch.

All 170 batched metadata rows pass, worst 1.7478277031736444x (default domain 1).
Three one-session P rows fail: `P_move_from` domain 4 at 2.0860927152317883x,
`P_move_inverse` domain 1 at 2.2857142857142856x, and `P_move_inverse` domain 4
at 2.2781456953642385x. Native and Lisp P allocations are only metadata-sized;
the RDK alias audit and compiled Lisp host route contain no dense copying or
numeric kernel. A separately authorized fixed sampling proof of ALL 42 P
rows, rather than a failed-row retry, is proposed; these first 212 results
remain retained regardless of its outcome. Raw log:
`/tmp/rays-swap-attributes-bench-before.log`.

| Mode | Domains | Cold sessions/sample | Native us | Lisp us | Unrounded ratio | Native bytes/cook | Lisp bytes/cook | Gate |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| default | 1 | 1000 | 5.131006241 | 8.968114853 | 1.7478277031736444 | 12568 | 21000 | PASS |
| default | 4 | 1000 | 5.871057510 | 8.510828018 | 1.4496243654822336 | 12800 | 21232 | PASS |
| point_swap_present | 1 | 1000 | 8.429050446 | 9.711027145 | 1.1520902868133733 | 25816 | 30528 | PASS |
| point_swap_present | 4 | 1000 | 10.292053223 | 10.720014572 | 1.0415817272053374 | 26048 | 30760 | PASS |
| point_swap_new | 1 | 1000 | 11.218070984 | 12.547016144 | 1.1184646773782199 | 25680 | 30392 | PASS |
| point_swap_new | 4 | 1000 | 8.969068527 | 10.952949524 | 1.2211914192296445 | 25912 | 30624 | PASS |
| point_swap_inverse | 1 | 1000 | 8.926868439 | 10.953187943 | 1.2269910795363497 | 28576 | 33288 | PASS |
| point_swap_inverse | 4 | 1000 | 9.153127670 | 10.455846786 | 1.1423250240941887 | 28808 | 33520 | PASS |
| point_swap_missing | 1 | 1000 | 7.161140442 | 9.597063065 | 1.3401584764948729 | 22616 | 27328 | PASS |
| point_swap_missing | 4 | 1000 | 7.310867310 | 9.150028229 | 1.2515653535090008 | 22848 | 27560 | PASS |
| point_swap_same | 1 | 1000 | 6.911039352 | 9.808063507 | 1.4191879118225412 | 20040 | 24752 | PASS |
| point_swap_same | 4 | 1000 | 7.646083832 | 8.810043335 | 1.1522294979731835 | 20272 | 24984 | PASS |
| point_swap_wildcard | 1 | 1000 | 9.398937225 | 11.260986328 | 1.1981127289330831 | 29008 | 33720 | PASS |
| point_swap_wildcard | 4 | 1000 | 9.656906128 | 11.309862137 | 1.1711682796760814 | 29240 | 33952 | PASS |
| point_swap_successive | 1 | 1000 | 12.826919556 | 18.273115158 | 1.4245910780669147 | 40824 | 55776 | PASS |
| point_swap_successive | 4 | 1000 | 13.669013977 | 18.562078476 | 1.3579676271541199 | 41056 | 56008 | PASS |
| point_move_present | 1 | 1000 | 9.130001068 | 11.919021606 | 1.3054786650650232 | 25424 | 30136 | PASS |
| point_move_present | 4 | 1000 | 9.366035461 | 9.961843491 | 1.0636136849607984 | 25656 | 30368 | PASS |
| point_move_new | 1 | 1000 | 8.949995041 | 9.414911270 | 1.0519459761847678 | 24976 | 29688 | PASS |
| point_move_new | 4 | 1000 | 10.796070099 | 10.396003723 | 0.96294333289165679 | 25208 | 29920 | PASS |
| point_move_inverse | 1 | 1000 | 7.282972336 | 8.136034012 | 1.1171309784921597 | 20312 | 25024 | PASS |
| point_move_inverse | 4 | 1000 | 6.695985794 | 8.183956146 | 1.2222182659782801 | 20544 | 25256 | PASS |
| point_move_missing | 1 | 1000 | 7.690906525 | 9.106159210 | 1.184016368032736 | 20800 | 25512 | PASS |
| point_move_missing | 4 | 1000 | 9.192943573 | 9.912014008 | 1.0782198246797032 | 21032 | 25744 | PASS |
| point_move_same | 1 | 1000 | 7.908105850 | 8.160114288 | 1.0318671048267962 | 20040 | 24752 | PASS |
| point_move_same | 4 | 1000 | 6.965875626 | 7.914066315 | 1.1361193825512546 | 20272 | 24984 | PASS |
| point_move_wildcard | 1 | 1000 | 8.924961090 | 11.651039124 | 1.3054442485441045 | 27232 | 31944 | PASS |
| point_move_wildcard | 4 | 1000 | 9.588003159 | 10.735034943 | 1.1196319781176178 | 27464 | 32176 | PASS |
| point_move_successive | 1 | 1000 | 12.028932571 | 15.713930130 | 1.3063445186609319 | 36672 | 50184 | PASS |
| point_move_successive | 4 | 1000 | 11.258125305 | 15.195131302 | 1.3497035154595509 | 36904 | 50416 | PASS |
| point_copy_present | 1 | 1000 | 8.610010147 | 11.507987976 | 1.3365823941516906 | 25688 | 30400 | PASS |
| point_copy_present | 4 | 1000 | 9.353160858 | 11.271953583 | 1.2051491205709917 | 25920 | 30632 | PASS |
| point_copy_new | 1 | 1000 | 8.477926254 | 10.066986084 | 1.1874349672375488 | 25632 | 30344 | PASS |
| point_copy_new | 4 | 1000 | 8.538961411 | 11.576175690 | 1.355688957140863 | 25864 | 30576 | PASS |
| point_copy_inverse | 1 | 1000 | 7.122039795 | 7.924079895 | 1.1126138189608998 | 20312 | 25024 | PASS |
| point_copy_inverse | 4 | 1000 | 7.348060608 | 7.962942123 | 1.0836794289422453 | 20544 | 25256 | PASS |
| point_copy_missing | 1 | 1000 | 6.697893143 | 8.296966553 | 1.2387427473035986 | 20800 | 25512 | PASS |
| point_copy_missing | 4 | 1000 | 7.734060287 | 9.572982788 | 1.2377693517062796 | 21032 | 25744 | PASS |
| point_copy_same | 1 | 1000 | 8.723974228 | 9.529113770 | 1.0922904539367604 | 20040 | 24752 | PASS |
| point_copy_same | 4 | 1000 | 7.628917694 | 8.640050888 | 1.1325395337208575 | 20272 | 24984 | PASS |
| point_copy_wildcard | 1 | 1000 | 9.704113007 | 11.025190353 | 1.1361358164217976 | 28864 | 33576 | PASS |
| point_copy_wildcard | 4 | 1000 | 12.409925461 | 11.016130447 | 0.8876870761368657 | 29096 | 33808 | PASS |
| point_copy_successive | 1 | 1000 | 13.570785522 | 17.019987106 | 1.2541637385804638 | 40536 | 55488 | PASS |
| point_copy_successive | 4 | 1000 | 12.850046158 | 17.498970032 | 1.3617826595172273 | 40768 | 55720 | PASS |
| vertex_swap_present | 1 | 1000 | 9.171962738 | 10.115861893 | 1.1029113595009099 | 24960 | 29672 | PASS |
| vertex_swap_present | 4 | 1000 | 8.622884750 | 10.159015656 | 1.1781458235407969 | 25192 | 29904 | PASS |
| vertex_swap_new | 1 | 1000 | 8.517980576 | 9.721040726 | 1.1412377193719039 | 24816 | 29528 | PASS |
| vertex_swap_new | 4 | 1000 | 8.261919022 | 11.592864990 | 1.4031685568349062 | 25048 | 29760 | PASS |
| vertex_swap_inverse | 1 | 1000 | 8.611917496 | 10.290145874 | 1.1948727886824837 | 26856 | 31568 | PASS |
| vertex_swap_inverse | 4 | 1000 | 9.022951126 | 12.161970139 | 1.3478927203065134 | 27088 | 31800 | PASS |
| vertex_swap_missing | 1 | 1000 | 7.633924484 | 8.219003677 | 1.0766419938161718 | 20888 | 25600 | PASS |
| vertex_swap_missing | 4 | 1000 | 7.002830505 | 9.037017822 | 1.2904807299468883 | 21120 | 25832 | PASS |
| vertex_swap_same | 1 | 1000 | 8.286952972 | 9.768962860 | 1.178836526842741 | 19176 | 23888 | PASS |
| vertex_swap_same | 4 | 1000 | 6.947994232 | 9.572029114 | 1.3776679706265873 | 19408 | 24120 | PASS |
| vertex_swap_wildcard | 1 | 1000 | 8.902072906 | 10.323047638 | 1.1596229042798223 | 26920 | 31632 | PASS |
| vertex_swap_wildcard | 4 | 1000 | 9.846210480 | 10.730028152 | 1.0897622160879461 | 27152 | 31864 | PASS |
| vertex_swap_successive | 1 | 1000 | 11.121034622 | 15.249967575 | 1.3712723764604995 | 36600 | 51064 | PASS |
| vertex_swap_successive | 4 | 1000 | 12.467861176 | 16.673088074 | 1.3372853482235056 | 36832 | 51296 | PASS |
| vertex_move_present | 1 | 1000 | 8.327960968 | 11.896848679 | 1.4285427998854854 | 24568 | 29280 | PASS |
| vertex_move_present | 4 | 1000 | 8.096933365 | 9.559154510 | 1.1805894997202675 | 24800 | 29512 | PASS |
| vertex_move_new | 1 | 1000 | 8.168935776 | 9.493112564 | 1.1620990572921228 | 24112 | 28824 | PASS |
| vertex_move_new | 4 | 1000 | 8.573055267 | 11.792898178 | 1.3755770621280383 | 24344 | 29056 | PASS |
| vertex_move_inverse | 1 | 1000 | 7.416963577 | 8.296966553 | 1.1186473367835672 | 19456 | 24168 | PASS |
| vertex_move_inverse | 4 | 1000 | 7.138013840 | 9.585142136 | 1.3428304218577776 | 19688 | 24400 | PASS |
| vertex_move_missing | 1 | 1000 | 8.126020432 | 9.122848511 | 1.1226711263679843 | 19936 | 24648 | PASS |
| vertex_move_missing | 4 | 1000 | 8.088827133 | 8.877038956 | 1.0974445132195596 | 20168 | 24880 | PASS |
| vertex_move_same | 1 | 1000 | 7.396936417 | 8.058071136 | 1.089379532634972 | 19176 | 23888 | PASS |
| vertex_move_same | 4 | 1000 | 6.749153137 | 7.900953293 | 1.170658471103575 | 19408 | 24120 | PASS |
| vertex_move_wildcard | 1 | 1000 | 10.053873062 | 10.246038437 | 1.0191135668381988 | 25744 | 30456 | PASS |
| vertex_move_wildcard | 4 | 1000 | 8.480072021 | 9.742021561 | 1.1488135402609088 | 25976 | 30688 | PASS |
| vertex_move_successive | 1 | 1000 | 10.874986649 | 17.725944519 | 1.6299739109464406 | 33712 | 47224 | PASS |
| vertex_move_successive | 4 | 1000 | 10.580062866 | 14.060020447 | 1.3289165314584461 | 33944 | 47456 | PASS |
| vertex_copy_present | 1 | 1000 | 8.200168610 | 11.253833771 | 1.3723905332325406 | 24832 | 29544 | PASS |
| vertex_copy_present | 4 | 1000 | 8.255004883 | 9.454011917 | 1.1452460720887245 | 25064 | 29776 | PASS |
| vertex_copy_new | 1 | 1000 | 9.256124496 | 9.600877762 | 1.0372459624449424 | 24768 | 29480 | PASS |
| vertex_copy_new | 4 | 1000 | 8.391857147 | 9.341955185 | 1.1132166600375022 | 25000 | 29712 | PASS |
| vertex_copy_inverse | 1 | 1000 | 6.659030914 | 8.033037186 | 1.2063372717508056 | 19456 | 24168 | PASS |
| vertex_copy_inverse | 4 | 1000 | 6.664991379 | 7.881164551 | 1.1824718297263459 | 19688 | 24400 | PASS |
| vertex_copy_missing | 1 | 1000 | 7.031917572 | 8.016824722 | 1.1400623855699465 | 19936 | 24648 | PASS |
| vertex_copy_missing | 4 | 1000 | 6.859064102 | 9.313106537 | 1.3577809447669367 | 20168 | 24880 | PASS |
| vertex_copy_same | 1 | 1000 | 7.253885269 | 7.987976074 | 1.1011996713229251 | 19176 | 23888 | PASS |
| vertex_copy_same | 4 | 1000 | 8.219957352 | 11.822938919 | 1.43832119964034 | 19408 | 24120 | PASS |
| vertex_copy_wildcard | 1 | 1000 | 8.902072906 | 10.298967361 | 1.156917885264342 | 26824 | 31536 | PASS |
| vertex_copy_wildcard | 4 | 1000 | 9.001016617 | 10.259866714 | 1.1398564352501788 | 27056 | 31768 | PASS |
| vertex_copy_successive | 1 | 1000 | 12.583971024 | 15.501976013 | 1.2318826850571227 | 36408 | 50872 | PASS |
| vertex_copy_successive | 4 | 1000 | 11.133909225 | 16.165018082 | 1.4518726311055912 | 36640 | 51104 | PASS |
| primitive_swap_present | 1 | 1000 | 8.091211319 | 9.420156479 | 1.164245513746059 | 24968 | 29680 | PASS |
| primitive_swap_present | 4 | 1000 | 8.331060410 | 9.326934814 | 1.1195375325530148 | 25200 | 29912 | PASS |
| primitive_swap_new | 1 | 1000 | 8.587121964 | 9.467124939 | 1.1024793847349861 | 24840 | 29552 | PASS |
| primitive_swap_new | 4 | 1000 | 8.288860321 | 10.312080383 | 1.2440890525225796 | 25072 | 29784 | PASS |
| primitive_swap_inverse | 1 | 1000 | 9.755134583 | 10.414123535 | 1.0675530354873399 | 26856 | 31568 | PASS |
| primitive_swap_inverse | 4 | 1000 | 9.088039398 | 10.056018829 | 1.1065113594627209 | 27088 | 31800 | PASS |
| primitive_swap_missing | 1 | 1000 | 6.737947464 | 8.002996445 | 1.1877499026927569 | 20904 | 25616 | PASS |
| primitive_swap_missing | 4 | 1000 | 8.525133133 | 7.972955704 | 0.93522946555919129 | 21136 | 25848 | PASS |
| primitive_swap_same | 1 | 1000 | 6.788969040 | 7.747888565 | 1.1412467076382791 | 19192 | 23904 | PASS |
| primitive_swap_same | 4 | 1000 | 6.644010544 | 8.032083511 | 1.2089209459216994 | 19424 | 24136 | PASS |
| primitive_swap_wildcard | 1 | 1000 | 9.735107422 | 10.016918182 | 1.0289478840125392 | 26936 | 31648 | PASS |
| primitive_swap_wildcard | 4 | 1000 | 8.671045303 | 10.213136673 | 1.1778437680442135 | 27168 | 31880 | PASS |
| primitive_swap_successive | 1 | 1000 | 11.235952377 | 15.112161636 | 1.3449827063042417 | 36616 | 51080 | PASS |
| primitive_swap_successive | 4 | 1000 | 11.934041977 | 16.159057617 | 1.3540305663769852 | 36848 | 51312 | PASS |
| primitive_move_present | 1 | 1000 | 8.321046829 | 9.778022766 | 1.1750952694765191 | 24576 | 29288 | PASS |
| primitive_move_present | 4 | 1000 | 8.281946182 | 9.274959564 | 1.1199009701471054 | 24808 | 29520 | PASS |
| primitive_move_new | 1 | 1000 | 7.786989212 | 9.022951126 | 1.1587214108569852 | 24136 | 28848 | PASS |
| primitive_move_new | 4 | 1000 | 8.213043213 | 9.171962738 | 1.1167556897352531 | 24368 | 29080 | PASS |
| primitive_move_inverse | 1 | 1000 | 6.666898727 | 7.727861404 | 1.1591388620677323 | 19456 | 24168 | PASS |
| primitive_move_inverse | 4 | 1000 | 6.881952286 | 7.719039917 | 1.1216351983370865 | 19688 | 24400 | PASS |
| primitive_move_missing | 1 | 1000 | 6.916046143 | 8.310079575 | 1.2015650854936568 | 19952 | 24664 | PASS |
| primitive_move_missing | 4 | 1000 | 6.803035736 | 8.043050766 | 1.1822737786500315 | 20184 | 24896 | PASS |
| primitive_move_same | 1 | 1000 | 6.633043289 | 7.889032364 | 1.1893533661622515 | 19192 | 23904 | PASS |
| primitive_move_same | 4 | 1000 | 7.727146149 | 8.006095886 | 1.0360999691453256 | 19424 | 24136 | PASS |
| primitive_move_wildcard | 1 | 1000 | 8.797883987 | 12.600898743 | 1.4322647082734883 | 25760 | 30472 | PASS |
| primitive_move_wildcard | 4 | 1000 | 9.000062943 | 10.159015656 | 1.1287716230893532 | 25992 | 30704 | PASS |
| primitive_move_successive | 1 | 1000 | 10.727882385 | 14.213085175 | 1.3248733220730731 | 33728 | 47240 | PASS |
| primitive_move_successive | 4 | 1000 | 10.416030884 | 14.817953110 | 1.4226103277787951 | 33960 | 47472 | PASS |
| primitive_copy_present | 1 | 1000 | 8.599042892 | 9.865045547 | 1.147225996062883 | 24840 | 29552 | PASS |
| primitive_copy_present | 4 | 1000 | 8.436918259 | 9.779930115 | 1.1591827507276684 | 25072 | 29784 | PASS |
| primitive_copy_new | 1 | 1000 | 11.172056198 | 10.213136673 | 0.91416803602296259 | 24792 | 29504 | PASS |
| primitive_copy_new | 4 | 1000 | 8.994102478 | 9.915113449 | 1.1024016541193937 | 25024 | 29736 | PASS |
| primitive_copy_inverse | 1 | 1000 | 6.747961044 | 9.611129761 | 1.4243013108151079 | 19456 | 24168 | PASS |
| primitive_copy_inverse | 4 | 1000 | 7.651090622 | 8.144855499 | 1.0645352279455298 | 19688 | 24400 | PASS |
| primitive_copy_missing | 1 | 1000 | 7.439136505 | 7.973194122 | 1.0717902698544965 | 19952 | 24664 | PASS |
| primitive_copy_missing | 4 | 1000 | 8.769035339 | 9.102106094 | 1.0379825992387166 | 20184 | 24896 | PASS |
| primitive_copy_same | 1 | 1000 | 6.838083267 | 8.766174316 | 1.2819636693281267 | 19192 | 23904 | PASS |
| primitive_copy_same | 4 | 1000 | 6.889104843 | 8.267879486 | 1.2001384322547153 | 19424 | 24136 | PASS |
| primitive_copy_wildcard | 1 | 1000 | 9.139060974 | 10.689973831 | 1.16970155483669 | 26840 | 31552 | PASS |
| primitive_copy_wildcard | 4 | 1000 | 8.870124817 | 11.349916458 | 1.2795667132566391 | 27072 | 31784 | PASS |
| primitive_copy_successive | 1 | 1000 | 11.193990707 | 18.220901489 | 1.62773955826287 | 36424 | 50888 | PASS |
| primitive_copy_successive | 4 | 1000 | 11.451005936 | 16.613960266 | 1.4508734306356574 | 36656 | 51120 | PASS |
| detail_swap_present | 1 | 1000 | 8.419990540 | 9.902000427 | 1.1760108732585794 | 24960 | 29672 | PASS |
| detail_swap_present | 4 | 1000 | 9.313821793 | 9.479999542 | 1.0178420581082812 | 25192 | 29904 | PASS |
| detail_swap_new | 1 | 1000 | 8.394002914 | 12.441873550 | 1.4822336467179822 | 24816 | 29528 | PASS |
| detail_swap_new | 4 | 1000 | 8.213043213 | 10.082006454 | 1.2275603808639108 | 25048 | 29760 | PASS |
| detail_swap_inverse | 1 | 1000 | 8.578062057 | 9.651899338 | 1.1251841351899718 | 26856 | 31568 | PASS |
| detail_swap_inverse | 4 | 1000 | 8.711099625 | 9.934902191 | 1.1404877247721488 | 27088 | 31800 | PASS |
| detail_swap_missing | 1 | 1000 | 6.998062134 | 8.289098740 | 1.1844848732624693 | 20888 | 25600 | PASS |
| detail_swap_missing | 4 | 1000 | 7.513999939 | 9.021997452 | 1.2006917121462115 | 21120 | 25832 | PASS |
| detail_swap_same | 1 | 1000 | 7.116079330 | 7.964134216 | 1.1191744563942776 | 19176 | 23888 | PASS |
| detail_swap_same | 4 | 1000 | 6.685018539 | 8.252859116 | 1.2345304754092514 | 19408 | 24120 | PASS |
| detail_swap_wildcard | 1 | 1000 | 10.644912720 | 12.762069702 | 1.1988890879770648 | 26920 | 31632 | PASS |
| detail_swap_wildcard | 4 | 1000 | 9.121179581 | 10.807037354 | 1.184828920197611 | 27152 | 31864 | PASS |
| detail_swap_successive | 1 | 1000 | 12.068986893 | 15.552997589 | 1.2886746607139328 | 36600 | 51064 | PASS |
| detail_swap_successive | 4 | 1000 | 12.113094330 | 16.471862793 | 1.3598393890485376 | 36832 | 51296 | PASS |
| detail_move_present | 1 | 1000 | 7.869005203 | 10.130882263 | 1.2874412967732161 | 24568 | 29280 | PASS |
| detail_move_present | 4 | 1000 | 8.166074753 | 10.735034943 | 1.3145893550553271 | 24800 | 29512 | PASS |
| detail_move_new | 1 | 1000 | 8.105039597 | 9.800195694 | 1.2091484041770848 | 24112 | 28824 | PASS |
| detail_move_new | 4 | 1000 | 9.027004242 | 9.888887405 | 1.0954783159896464 | 24344 | 29056 | PASS |
| detail_move_inverse | 1 | 1000 | 6.641149521 | 7.956981659 | 1.1981331897325436 | 19456 | 24168 | PASS |
| detail_move_inverse | 4 | 1000 | 7.111072540 | 7.861137390 | 1.1054784416281098 | 19688 | 24400 | PASS |
| detail_move_missing | 1 | 1000 | 6.586074829 | 7.992982864 | 1.2136185925282363 | 19936 | 24648 | PASS |
| detail_move_missing | 4 | 1000 | 6.989955902 | 8.306026459 | 1.1882802373968211 | 20168 | 24880 | PASS |
| detail_move_same | 1 | 1000 | 7.776021957 | 8.875846863 | 1.1414379886555266 | 19176 | 23888 | PASS |
| detail_move_same | 4 | 1000 | 7.073879242 | 8.749961853 | 1.2369396697000337 | 19408 | 24120 | PASS |
| detail_move_wildcard | 1 | 1000 | 8.975028992 | 10.071992874 | 1.1222239931994475 | 25744 | 30456 | PASS |
| detail_move_wildcard | 4 | 1000 | 9.297132492 | 10.212898254 | 1.0984998076676498 | 25976 | 30688 | PASS |
| detail_move_successive | 1 | 1000 | 10.837078094 | 15.772104263 | 1.4553834646015753 | 33712 | 47224 | PASS |
| detail_move_successive | 4 | 1000 | 11.620998383 | 14.508008957 | 1.2484305116737107 | 33944 | 47456 | PASS |
| detail_copy_present | 1 | 1000 | 8.536100388 | 9.677171707 | 1.1336759489428261 | 24832 | 29544 | PASS |
| detail_copy_present | 4 | 1000 | 8.587121964 | 9.781837463 | 1.1391287447594189 | 25064 | 29776 | PASS |
| detail_copy_new | 1 | 1000 | 9.320974350 | 10.581970215 | 1.1352858421793068 | 24768 | 29480 | PASS |
| detail_copy_new | 4 | 1000 | 8.365869522 | 9.927988052 | 1.1867251845307647 | 25000 | 29712 | PASS |
| detail_copy_inverse | 1 | 1000 | 6.687164307 | 7.925987244 | 1.1852538505419281 | 19456 | 24168 | PASS |
| detail_copy_inverse | 4 | 1000 | 10.210990906 | 9.429931641 | 0.92350798543009238 | 19688 | 24400 | PASS |
| detail_copy_missing | 1 | 1000 | 6.599187851 | 8.134126663 | 1.2325951082047761 | 19936 | 24648 | PASS |
| detail_copy_missing | 4 | 1000 | 6.762981415 | 7.920026779 | 1.1710851018825355 | 20168 | 24880 | PASS |
| detail_copy_same | 1 | 1000 | 7.004022598 | 8.358955383 | 1.1934506586785583 | 19176 | 23888 | PASS |
| detail_copy_same | 4 | 1000 | 7.226943970 | 8.765935898 | 1.2129519662179995 | 19408 | 24120 | PASS |
| detail_copy_wildcard | 1 | 1000 | 9.455919266 | 11.146068573 | 1.178739819974282 | 26824 | 31536 | PASS |
| detail_copy_wildcard | 4 | 1000 | 8.980989456 | 10.394811630 | 1.1574238763970373 | 27056 | 31768 | PASS |
| detail_copy_successive | 1 | 1000 | 11.091947556 | 15.419006348 | 1.3901081185650106 | 36408 | 50872 | PASS |
| detail_copy_successive | 4 | 1000 | 11.067867279 | 16.070842743 | 1.4520270561371766 | 36640 | 51104 | PASS |
| P_swap_same | 1 | 1 | 28.848648071 | 28.133392334 | 0.97520661157024791 | 18288 | 23000 | PASS |
| P_swap_same | 4 | 1 | 30.994415283 | 34.093856812 | 1.1000000000000001 | 18520 | 23232 | PASS |
| P_swap_from | 1 | 1 | 39.100646973 | 47.922134399 | 1.225609756097561 | 25352 | 30064 | PASS |
| P_swap_from | 4 | 1 | 35.047531128 | 41.007995605 | 1.1700680272108843 | 25584 | 30296 | PASS |
| P_swap_from_existing | 1 | 1 | 35.047531128 | 51.975250244 | 1.4829931972789117 | 25424 | 30136 | PASS |
| P_swap_from_existing | 4 | 1 | 37.908554077 | 41.007995605 | 1.0817610062893082 | 25656 | 30368 | PASS |
| P_swap_into | 1 | 1 | 30.040740967 | 38.862228394 | 1.2936507936507937 | 25424 | 30136 | PASS |
| P_swap_into | 4 | 1 | 32.901763916 | 41.007995605 | 1.2463768115942029 | 25656 | 30368 | PASS |
| P_swap_wrong_into | 1 | 1 | 30.994415283 | 41.007995605 | 1.323076923076923 | 18096 | 22424 | PASS |
| P_swap_wrong_into | 4 | 1 | 51.021575928 | 40.054321289 | 0.78504672897196259 | 18328 | 22656 | PASS |
| P_swap_wrong_from | 1 | 1 | 35.047531128 | 36.954879761 | 1.0544217687074831 | 18096 | 22424 | PASS |
| P_swap_wrong_from | 4 | 1 | 34.093856812 | 36.954879761 | 1.083916083916084 | 18328 | 22656 | PASS |
| P_swap_inverse | 1 | 1 | 33.855438232 | 53.167343140 | 1.5704225352112675 | 27576 | 32288 | PASS |
| P_swap_inverse | 4 | 1 | 34.093856812 | 46.968460083 | 1.3776223776223777 | 27808 | 32520 | PASS |
| P_move_same | 1 | 1 | 30.994415283 | 35.047531128 | 1.1307692307692307 | 18288 | 23000 | PASS |
| P_move_same | 4 | 1 | 31.948089600 | 39.100646973 | 1.2238805970149254 | 18520 | 23232 | PASS |
| P_move_from | 1 | 1 | 40.054321289 | 42.200088501 | 1.0535714285714286 | 25352 | 30064 | PASS |
| P_move_from | 4 | 1 | 36.001205444 | 75.101852417 | 2.0860927152317883 | 25584 | 30296 | FAIL |
| P_move_from_existing | 1 | 1 | 32.901763916 | 30.994415283 | 0.94202898550724634 | 25416 | 30128 | PASS |
| P_move_from_existing | 4 | 1 | 41.961669922 | 47.206878662 | 1.125 | 25648 | 30360 | PASS |
| P_move_into | 1 | 1 | 32.186508179 | 31.948089600 | 0.99259259259259258 | 24960 | 29672 | PASS |
| P_move_into | 4 | 1 | 33.855438232 | 41.961669922 | 1.2394366197183098 | 25192 | 29904 | PASS |
| P_move_wrong_into | 1 | 1 | 38.862228394 | 37.908554077 | 0.97546012269938653 | 18080 | 22408 | PASS |
| P_move_wrong_into | 4 | 1 | 36.954879761 | 35.047531128 | 0.94838709677419353 | 18312 | 22640 | PASS |
| P_move_wrong_from | 1 | 1 | 35.047531128 | 44.822692871 | 1.2789115646258504 | 24696 | 29408 | PASS |
| P_move_wrong_from | 4 | 1 | 34.093856812 | 39.815902710 | 1.1678321678321679 | 24928 | 29640 | PASS |
| P_move_inverse | 1 | 1 | 25.033950806 | 57.220458984 | 2.2857142857142856 | 19264 | 23976 | FAIL |
| P_move_inverse | 4 | 1 | 36.001205444 | 82.015991211 | 2.2781456953642385 | 19496 | 24208 | FAIL |
| P_copy_same | 1 | 1 | 24.080276489 | 40.054321289 | 1.6633663366336633 | 18288 | 23000 | PASS |
| P_copy_same | 4 | 1 | 27.894973755 | 34.093856812 | 1.2222222222222223 | 18520 | 23232 | PASS |
| P_copy_from | 1 | 1 | 39.100646973 | 36.954879761 | 0.94512195121951215 | 25352 | 30064 | PASS |
| P_copy_from | 4 | 1 | 82.969665527 | 42.200088501 | 0.50862068965517238 | 25584 | 30296 | PASS |
| P_copy_from_existing | 1 | 1 | 35.047531128 | 33.855438232 | 0.96598639455782309 | 25416 | 30128 | PASS |
| P_copy_from_existing | 4 | 1 | 62.942504883 | 40.054321289 | 0.63636363636363635 | 25648 | 30360 | PASS |
| P_copy_into | 1 | 1 | 38.146972656 | 37.908554077 | 0.99375000000000002 | 25344 | 30056 | PASS |
| P_copy_into | 4 | 1 | 40.054321289 | 45.061111450 | 1.125 | 25576 | 30288 | PASS |
| P_copy_wrong_into | 1 | 1 | 30.994415283 | 45.061111450 | 1.4538461538461538 | 18144 | 22472 | PASS |
| P_copy_wrong_into | 4 | 1 | 46.968460083 | 35.047531128 | 0.74619289340101524 | 18376 | 22704 | PASS |
| P_copy_wrong_from | 1 | 1 | 36.954879761 | 36.001205444 | 0.97419354838709682 | 24696 | 29408 | PASS |
| P_copy_wrong_from | 4 | 1 | 56.028366089 | 46.968460083 | 0.83829787234042552 | 24928 | 29640 | PASS |
| P_copy_inverse | 1 | 1 | 28.133392334 | 36.001205444 | 1.2796610169491525 | 19264 | 23976 | PASS |
| P_copy_inverse | 4 | 1 | 25.987625122 | 31.948089600 | 1.2293577981651376 | 19496 | 24208 | PASS |


Swap Attributes remains pending with its native registration intact. No port
completion, catalog/CLI/render rebaseline, target-count increment or API
promotion follows from this failed first timing table.


### Fixed all42 canonical-P precision proof

Root authorized this sampling amendment after tracing every canonical-P branch,
before its outcome was known. RDK `swap_store` keeps immutable storage handles;
`position_attribute`, `Attribute.create_owned` and `Attribute.with_name` wrap
the existing planes. `swap_set_position` changes the Float3 handle, and
`Geometry.Private.with_positions_and_attributes_owned` validates counts/layout
without copying or scanning its dense payload. The distinct `old_vec3` planes
still exercise actual position replacement. The Lisp structural Core route
borrows its cooked snapshot handle, calls generic `Attribute_metadata.swap`,
and reaches that same RDK kernel. It has no numeric region, dense array
constructor or deep clone; the measured 19–31KB native/Lisp metadata allocation
is consistent with that route, rather than a 24MB position copy.

The initial all212 table and all three failures remain above. The amendment
selects every one of the predetermined 21 `P_` configurations, including
previous passes and failures, at both domains 1 and 4: ALL42 rows. Both native
and whole strict Lisp now use 1000 fresh cold sessions per sample, median of
three samples. All170 already-batched metadata rows retain their original
evidence. Input, distinct planes, profile, grain4096, session construction and
GC boundaries, exact preflights, per-cook initial-domain allocation and the
unrounded `time > 2*native` gate remain identical. No runtime implementation
changed. Command, from `lib/flow_sop`:

`opam exec -- ../../_build/default/lib/flow_sop/test_metadata_ports.exe --bench-swap-attributes-p-batch`

Focused **7446** exited0 for `@lib/flow_sop/swap_attributes_draft`, retaining
the complete semantic/schema/cache/graph proof. Reserved quiet **9439** exited0
after every million-point native/reference/strict preflight and final
`swap_attributes_gate rows=42 failures=0 p_batch=true`.
Raw log: `/tmp/rays-swap-attributes-p-batch-bench.log`.

All42 pass; exact maximum 1.4869351484212519x (P_swap_wrong_into domain 1).

| Mode | Domains | Cold sessions/sample | Native us | Lisp us | Unrounded ratio | Native bytes/cook | Lisp bytes/cook | Gate |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| P_swap_same | 1 | 1000 | 6.385087967 | 7.471084595 | 1.1700832679884994 | 18152 | 22864 | PASS |
| P_swap_same | 4 | 1000 | 6.536960602 | 8.608818054 | 1.3169450725800569 | 18384 | 23096 | PASS |
| P_swap_from | 1 | 1000 | 8.672952652 | 10.143041611 | 1.1695027077549001 | 25216 | 29928 | PASS |
| P_swap_from | 4 | 1000 | 12.373209000 | 11.314868927 | 0.91446519066612708 | 25448 | 30160 | PASS |
| P_swap_from_existing | 1 | 1000 | 10.189056396 | 10.033130646 | 0.98469674279296149 | 25288 | 30000 | PASS |
| P_swap_from_existing | 4 | 1000 | 8.106946945 | 11.245965958 | 1.3872011293121194 | 25520 | 30232 | PASS |
| P_swap_into | 1 | 1000 | 9.350776672 | 9.598970413 | 1.0265425803161654 | 25288 | 30000 | PASS |
| P_swap_into | 4 | 1000 | 8.496999741 | 10.529041290 | 1.2391481242459101 | 25520 | 30232 | PASS |
| P_swap_wrong_into | 1 | 1000 | 6.304979324 | 9.375095367 | 1.4869351484212519 | 17960 | 22288 | PASS |
| P_swap_wrong_into | 4 | 1000 | 6.242036819 | 8.124113083 | 1.301516366830908 | 18192 | 22520 | PASS |
| P_swap_wrong_from | 1 | 1000 | 6.366968155 | 6.929159164 | 1.0882980715221868 | 17960 | 22288 | PASS |
| P_swap_wrong_from | 4 | 1000 | 5.919933319 | 7.287025452 | 1.2309303262182845 | 18192 | 22520 | PASS |
| P_swap_inverse | 1 | 1000 | 8.956909180 | 10.183095932 | 1.1368984241908007 | 27440 | 32152 | PASS |
| P_swap_inverse | 4 | 1000 | 9.107112885 | 11.292934418 | 1.2400125661029373 | 27672 | 32384 | PASS |
| P_move_same | 1 | 1000 | 6.422042847 | 7.918834686 | 1.233070983070983 | 18152 | 22864 | PASS |
| P_move_same | 4 | 1000 | 6.465911865 | 8.114099503 | 1.2549041297935104 | 18384 | 23096 | PASS |
| P_move_from | 1 | 1000 | 8.731126785 | 9.927034378 | 1.1369705906447121 | 25216 | 29928 | PASS |
| P_move_from | 4 | 1000 | 8.928060532 | 10.087013245 | 1.1298101316527358 | 25448 | 30160 | PASS |
| P_move_from_existing | 1 | 1000 | 9.567975998 | 9.790897369 | 1.0232986967680846 | 25280 | 29992 | PASS |
| P_move_from_existing | 4 | 1000 | 9.382009506 | 10.385990143 | 1.1070112576554598 | 25512 | 30224 | PASS |
| P_move_into | 1 | 1000 | 8.057117462 | 10.203123093 | 1.266349056045452 | 24824 | 29536 | PASS |
| P_move_into | 4 | 1000 | 10.330915451 | 10.857105255 | 1.0509335118044816 | 25056 | 29768 | PASS |
| P_move_wrong_into | 1 | 1000 | 7.459878922 | 7.426023483 | 0.99546166384352319 | 17944 | 22272 | PASS |
| P_move_wrong_into | 4 | 1000 | 6.652116776 | 8.244991302 | 1.2394537830185299 | 18176 | 22504 | PASS |
| P_move_wrong_from | 1 | 1000 | 8.187055588 | 9.671211243 | 1.1812807594862984 | 24560 | 29272 | PASS |
| P_move_wrong_from | 4 | 1000 | 10.162115097 | 11.909961700 | 1.1719963400042233 | 24792 | 29504 | PASS |
| P_move_inverse | 1 | 1000 | 6.533145905 | 8.231878281 | 1.2600175169695642 | 19128 | 23840 | PASS |
| P_move_inverse | 4 | 1000 | 6.712913513 | 7.844209671 | 1.1685253587157269 | 19360 | 24072 | PASS |
| P_copy_same | 1 | 1000 | 6.826877594 | 8.814096451 | 1.2910875183348467 | 18152 | 22864 | PASS |
| P_copy_same | 4 | 1000 | 6.530046463 | 8.066177368 | 1.2352404249881339 | 18384 | 23096 | PASS |
| P_copy_from | 1 | 1000 | 8.589029312 | 10.318040848 | 1.2013046495489244 | 25216 | 29928 | PASS |
| P_copy_from | 4 | 1000 | 8.523941040 | 10.004997253 | 1.173752517341687 | 25448 | 30160 | PASS |
| P_copy_from_existing | 1 | 1000 | 9.268999100 | 10.647058487 | 1.1486740232013786 | 25280 | 29992 | PASS |
| P_copy_from_existing | 4 | 1000 | 8.532047272 | 9.654998779 | 1.1316157156429889 | 25512 | 30224 | PASS |
| P_copy_into | 1 | 1000 | 8.391141891 | 10.311126709 | 1.2288109106407159 | 25208 | 29920 | PASS |
| P_copy_into | 4 | 1000 | 8.838891983 | 9.782075882 | 1.1067083861570417 | 25440 | 30152 | PASS |
| P_copy_wrong_into | 1 | 1000 | 5.832195282 | 7.143974304 | 1.2249202845229334 | 18008 | 22336 | PASS |
| P_copy_wrong_into | 4 | 1000 | 6.014823914 | 7.405996323 | 1.2312906294593309 | 18240 | 22568 | PASS |
| P_copy_wrong_from | 1 | 1000 | 11.231899261 | 10.873079300 | 0.96805349182763734 | 24560 | 29272 | PASS |
| P_copy_wrong_from | 4 | 1000 | 9.397983551 | 11.271953583 | 1.1994012887513319 | 24792 | 29504 | PASS |
| P_copy_inverse | 1 | 1000 | 6.883144379 | 8.634805679 | 1.2544856252164875 | 19128 | 23840 | PASS |
| P_copy_inverse | 4 | 1000 | 7.045984268 | 8.079051971 | 1.1466179406490036 | 19360 | 24072 | PASS |

This qualifies the candidate sampling gate together with the initial170 metadata rows; production registration, whole SOP oracle, manifest/CLI/native integration and target-count changes remain parent-owned and unclaimed here.

### Swap production integration

The 37-line declaration is now embedded as `nodes/swap_attributes.rays`;
its OCaml catalog registration is removed and the last `metadata.pending`
draft file is deleted. The real `Sop.Nodes.Swap_attributes` factory remains
the independent whole-port oracle. The normal metadata projection alias now
includes Swap. Declaration checks require exactly one embedded Lisp definition
for each of all seven metadata kinds, comparing their native schemas and menu
identities. The whole-port runner adds mandatory empty, single, 4,225-point
and mixed inputs plus every storage/owner/method, exceptional P and numeric
planes, canonical P conflicts, successive rules, literal Unicode/escaped names,
native refusals, cache edits, relabels and reference/domain/grain bytes.

The accepted timing matrix combines all 170 original batch1000 metadata rows
with all 42 fixed batch1000 canonical-P rows above. Both matrices use the
unchanged 2x unrounded gate and native/reference million-point byte preflights.
The three original batch1 failures remain recorded above. No failed-row subset
was retimed and no runtime or native denominator was changed for this proof.

Production focused handle26574 exited1: the integration initially left a
reference to the deleted draft `source`, an unused whole-port function before
its runner call was added, and the expected manifest diff. The corrected
handle88033 ran all whole recipes, candidate proof, Color raw72 proof and
catalog/lowering checks successfully; it exited1 only because the dependency
scanner raced the newly built Color executable's initially dangling build-tree
link. The final native run below reran that scan successfully; the scanner and
its rules were not changed.

Full integration handle99047 exited1 only for the expected generated CLI
catalog hash. Handle90589 then exited0 for the same complete alias set:
`@runtest-native @lib/sop/test_lisp_ports @lib/flow_sop/runtest
@lib/flow_sop/metadata_ports_draft @lib/flow_sop/swap_attributes_draft
@lib/flow_sop/metadata_ports_large @lib/sop_catalog/runtest
@tools/lisp/test/runtest @test/test_workspace_source @test/test_workspace_shell
@test/test_sop_catalog @tools/api_manifest/runtest @test/dependency_gate`.
The 5,001-row encoded normalize/rebuild/cook checks pass for every table-driven
metadata kind. All thirteen whole recipes pass. Native render, editor, source,
API and dependency checks pass. The older intermittent Rename Attributes
failure remains an unresolved phase-review item; these runs did not reproduce
it and do not claim to fix it.

Reviewed/promoted manifest digest: `987ce6c924bf01aea508ee6e0a6f7243`.
The Swap schema/operation/slots remain identical; its body marker and ordering
change as it becomes Lisp. The only golden fixture changed in this port is
`tools/lisp/test/ml.t`, replacing its generated catalog hash with
`bc7f2cc05f2b6d18dd2150ad71494cf54622e8b440b24b569d79e3a5c0b0ae6a`.
No rendered golden or public API manifest changed.
Logs: `/tmp/rays-swap-attributes-production-focused.log`,
`/tmp/rays-swap-attributes-production-focused2.log`,
`/tmp/rays-swap-attributes-native-integration.log` and
`/tmp/rays-swap-attributes-native-integration2.log`.

Swap is whole port13 of128. All seven B.12 metadata ports are complete;
115 whole ports remain and the remaining phase groups stay required.

## Set Color whole recipe and candidate performance

After shared zero-retention Session optimization `09681744`, the complete
predetermined 78-row Color matrix was rerun quietly with the unchanged body
and native oracle. Root strengthened the existing harness to compare exact
native/reference/strict million-input bytes in every row, print full-precision
seconds/ratios and an unrounded 2x verdict, retain every failing row until the
end, and assert the complete row count. The 72 dense Point/Vertex/Primitive
rows retain batch1; all six one-element Detail rows use the already audited
batch1000 cold-session precision protocol. One shared runner also supplies
`--bench-detail-batch`, avoiding a second implementation of the sampling loop.

Focused Color proof in handle88033 passed all owners, group modes and eight
storage variants; all 72 selected/unselected exceptional channel cases are
byte-exact with native/reference/strict at domains1/4/8 and grains1/97/4096.
Each physical field edit preserves native keys and one public miss/warm hit;
card/inspector rows and every field gesture match the native declaration.
These candidate checks do not alone qualify the production port.

Quiet handle67437 exited0 with `set_color_gate rows=78 failures=0`.
Command: `opam exec -- ./test_set_color.exe --bench` from
`_build/default/lib/flow_sop`. Full log:
`/tmp/rays-set-color-full78-current-bench.log`.
Machine: Apple M1 arm64, OCaml5.3 development build, grain4096, domains1/4.
Each row uses the median of three samples. Input has1,000,000 points; dense
target owner counts are also1,000,000; Detail has one element. Native and Lisp
use identical session retention settings. Fresh Sessions and their close plus
full-major GC are outside the clock; Context creation and whole cold cook are
inside. Allocations observe the initial domain, so worker allocations at four
domains may be undercounted. No native denominator or eager domain-default
behavior was changed. All historical Color failure tables remain retained.
Maximum unrounded ratio:1.7896493105836428x, Vertex/absent/selected/domain1.
The following table retains all78 original measurements without rounding:

| Owner | Cd | Group | Domains | Cold sessions | Native seconds | Lisp seconds | Ratio | Native bytes | Lisp bytes |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Point | absent | "" | 1 | 1 | 0.0014779567718505859 | 0.00061893463134765625 | 0.41877722213260204 | 32010056 | 32027824 |
| Point | absent | "" | 4 | 1 | 0.0011827945709228516 | 0.00075411796569824219 | 0.6375730699455755 | 32010288 | 32028056 |
| Point | absent | "selected" | 1 | 1 | 0.0038399696350097656 | 0.0066888332366943359 | 1.7418974295293679 | 32010472 | 40026592 |
| Point | absent | "selected" | 4 | 1 | 0.0037748813629150391 | 0.0049071311950683594 | 1.2999431566980357 | 32010704 | 40069864 |
| Point | absent | "full" | 1 | 1 | 0.0048820972442626953 | 0.0046479701995849609 | 0.95204375640963035 | 32010464 | 40026464 |
| Point | absent | "full" | 4 | 1 | 0.0048491954803466797 | 0.0046899318695068359 | 0.96715669403608828 | 32010696 | 40026696 |
| Point | absent | "empty" | 1 | 1 | 0.0028700828552246094 | 0.0031421184539794922 | 1.0947831865758431 | 32010464 | 40026584 |
| Point | absent | "empty" | 4 | 1 | 0.0028970241546630859 | 0.0026829242706298828 | 0.92609661756234052 | 32010696 | 40078704 |
| Point | vec4 | "" | 1 | 1 | 0.0012669563293457031 | 0.00068902969360351562 | 0.5438464433571697 | 32010208 | 32028376 |
| Point | vec4 | "" | 4 | 1 | 0.0012698173522949219 | 0.00064182281494140625 | 0.50544498685692829 | 32010440 | 32028608 |
| Point | vec4 | "selected" | 1 | 1 | 0.0043058395385742188 | 0.0071489810943603516 | 1.6602990033222591 | 32010816 | 40026768 |
| Point | vec4 | "selected" | 4 | 1 | 0.0045440196990966797 | 0.0054101943969726562 | 1.1906186053832835 | 32011048 | 40073008 |
| Point | vec4 | "full" | 1 | 1 | 0.0055699348449707031 | 0.0046849250793457031 | 0.84110949405016688 | 32010808 | 40026744 |
| Point | vec4 | "full" | 4 | 1 | 0.0055229663848876953 | 0.00469207763671875 | 0.84955752212389379 | 32011040 | 40026976 |
| Point | vec4 | "empty" | 1 | 1 | 0.0037569999694824219 | 0.0037841796875 | 1.0072344206117527 | 32010808 | 40026760 |
| Point | vec4 | "empty" | 4 | 1 | 0.0034861564636230469 | 0.0031881332397460938 | 0.91451237860757761 | 32011040 | 40079232 |
| Point | wrong_float | "" | 1 | 1 | 0.0011780261993408203 | 0.00076007843017578125 | 0.64521351953045947 | 32010208 | 32028376 |
| Point | wrong_float | "" | 4 | 1 | 0.001194000244140625 | 0.00067591667175292969 | 0.56609424920127793 | 32010440 | 32028608 |
| Point | wrong_float | "selected" | 1 | 1 | 0.0038409233093261719 | 0.0066130161285400391 | 1.721725636250776 | 32010640 | 40026776 |
| Point | wrong_float | "selected" | 4 | 1 | 0.00380706787109375 | 0.0045859813690185547 | 1.2045966933867736 | 32010872 | 40075008 |
| Point | wrong_float | "full" | 1 | 1 | 0.0049719810485839844 | 0.0046079158782958984 | 0.92677663757552509 | 32010632 | 40026648 |
| Point | wrong_float | "full" | 4 | 1 | 0.0049178600311279297 | 0.0047020912170410156 | 0.95612546662141851 | 32010864 | 40026880 |
| Point | wrong_float | "empty" | 1 | 1 | 0.0028669834136962891 | 0.0032219886779785156 | 1.1238253638253639 | 32010632 | 40026768 |
| Point | wrong_float | "empty" | 4 | 1 | 0.0028529167175292969 | 0.0026481151580810547 | 0.92821327093431394 | 32010864 | 40079936 |
| Vertex | absent | "" | 1 | 1 | 0.0012729167938232422 | 0.00069212913513183594 | 0.54373478179434354 | 32010064 | 32027824 |
| Vertex | absent | "" | 4 | 1 | 0.0012719631195068359 | 0.00072193145751953125 | 0.56757263355201504 | 32010296 | 32028056 |
| Vertex | absent | "selected" | 1 | 1 | 0.0037868022918701172 | 0.0067770481109619141 | 1.7896493105836428 | 32010480 | 40026592 |
| Vertex | absent | "selected" | 4 | 1 | 0.0037708282470703125 | 0.0046579837799072266 | 1.2352680829539706 | 32010712 | 40074552 |
| Vertex | absent | "full" | 1 | 1 | 0.0048670768737792969 | 0.0046651363372802734 | 0.9585088664641912 | 32010464 | 40026464 |
| Vertex | absent | "full" | 4 | 1 | 0.0048830509185791016 | 0.0047209262847900391 | 0.96679849616717939 | 32010696 | 40026696 |
| Vertex | absent | "empty" | 1 | 1 | 0.0029110908508300781 | 0.0031850337982177734 | 1.094103194103194 | 32010472 | 40026584 |
| Vertex | absent | "empty" | 4 | 1 | 0.0028889179229736328 | 0.0026609897613525391 | 0.92110258314764382 | 32010704 | 40079504 |
| Vertex | vec4 | "" | 1 | 1 | 0.0011961460113525391 | 0.00068497657775878906 | 0.57265297986844732 | 32010216 | 32028384 |
| Vertex | vec4 | "" | 4 | 1 | 0.0012381076812744141 | 0.00070500373840332031 | 0.56942037357981901 | 32010448 | 32028616 |
| Vertex | vec4 | "selected" | 1 | 1 | 0.0044682025909423828 | 0.0073058605194091797 | 1.6350781708553439 | 32010824 | 40026768 |
| Vertex | vec4 | "selected" | 4 | 1 | 0.0050609111785888672 | 0.0051181316375732422 | 1.0113063551137702 | 32011056 | 40074864 |
| Vertex | vec4 | "full" | 1 | 1 | 0.0057649612426757812 | 0.004795074462890625 | 0.83176178660049627 | 32010808 | 40026744 |
| Vertex | vec4 | "full" | 4 | 1 | 0.0053708553314208984 | 0.0046122074127197266 | 0.85874728104052911 | 32011040 | 40026976 |
| Vertex | vec4 | "empty" | 1 | 1 | 0.0035848617553710938 | 0.0039548873901367188 | 1.103218941207768 | 32010816 | 40026760 |
| Vertex | vec4 | "empty" | 4 | 1 | 0.0034818649291992188 | 0.0032930374145507812 | 0.9457682826622843 | 32011048 | 40080232 |
| Vertex | wrong_float | "" | 1 | 1 | 0.0011889934539794922 | 0.00067114830017089844 | 0.56446761580108284 | 32010224 | 32028392 |
| Vertex | wrong_float | "" | 4 | 1 | 0.0012798309326171875 | 0.00070905685424804688 | 0.55402384500745161 | 32010456 | 32028624 |
| Vertex | wrong_float | "selected" | 1 | 1 | 0.0038139820098876953 | 0.0066370964050292969 | 1.7402012877414514 | 32010656 | 40026784 |
| Vertex | wrong_float | "selected" | 4 | 1 | 0.0040259361267089844 | 0.0050649642944335938 | 1.2580836195665048 | 32010888 | 40070616 |
| Vertex | wrong_float | "full" | 1 | 1 | 0.0050089359283447266 | 0.0046629905700683594 | 0.93093436146413444 | 32010640 | 40026656 |
| Vertex | wrong_float | "full" | 4 | 1 | 0.0050680637359619141 | 0.0052599906921386719 | 1.0378698781577833 | 32010872 | 40026888 |
| Vertex | wrong_float | "empty" | 1 | 1 | 0.0028810501098632812 | 0.0030989646911621094 | 1.075637206223105 | 32010648 | 40026776 |
| Vertex | wrong_float | "empty" | 4 | 1 | 0.0028810501098632812 | 0.0026690959930419922 | 0.92643164515061238 | 32010880 | 40080232 |
| Primitive | absent | "" | 1 | 1 | 0.0013341903686523438 | 0.00077509880065917969 | 0.58095067905646891 | 32010088 | 32027856 |
| Primitive | absent | "" | 4 | 1 | 0.0012190341949462891 | 0.00066709518432617188 | 0.54723254449442593 | 32010320 | 32028088 |
| Primitive | absent | "selected" | 1 | 1 | 0.00385284423828125 | 0.0066218376159667969 | 1.7186881188118812 | 32010504 | 40026624 |
| Primitive | absent | "selected" | 4 | 1 | 0.0038270950317382812 | 0.0050318241119384766 | 1.3147894343384001 | 32010736 | 40081032 |
| Primitive | absent | "full" | 1 | 1 | 0.0048549175262451172 | 0.0046401023864746094 | 0.95575308156951333 | 32010480 | 40026480 |
| Primitive | absent | "full" | 4 | 1 | 0.0051410198211669922 | 0.0046679973602294922 | 0.90799053934981222 | 32010712 | 40026712 |
| Primitive | absent | "empty" | 1 | 1 | 0.0028738975524902344 | 0.0031378269195556641 | 1.0918367346938775 | 32010488 | 40026600 |
| Primitive | absent | "empty" | 4 | 1 | 0.0029211044311523438 | 0.0029780864715576172 | 1.0195070192621614 | 32010720 | 40077992 |
| Primitive | vec4 | "" | 1 | 1 | 0.0012688636779785156 | 0.00068688392639160156 | 0.54133784291619691 | 32010240 | 32028408 |
| Primitive | vec4 | "" | 4 | 1 | 0.0012099742889404297 | 0.00067496299743652344 | 0.55783251231527098 | 32010472 | 32028640 |
| Primitive | vec4 | "selected" | 1 | 1 | 0.0042579174041748047 | 0.0073180198669433594 | 1.7186852567332997 | 32010848 | 40026800 |
| Primitive | vec4 | "selected" | 4 | 1 | 0.0045011043548583984 | 0.0058329105377197266 | 1.2958843159065629 | 32011080 | 40074040 |
| Primitive | vec4 | "full" | 1 | 1 | 0.0057260990142822266 | 0.0047810077667236328 | 0.83495024357746594 | 32010824 | 40026760 |
| Primitive | vec4 | "full" | 4 | 1 | 0.0053548812866210938 | 0.0046639442443847656 | 0.87097061442564561 | 32011056 | 40026992 |
| Primitive | vec4 | "empty" | 1 | 1 | 0.0034928321838378906 | 0.0038690567016601562 | 1.1077133105802048 | 32010832 | 40026776 |
| Primitive | vec4 | "empty" | 4 | 1 | 0.0033290386199951172 | 0.0032207965850830078 | 0.96748549738594858 | 32011064 | 40080064 |
| Primitive | wrong_float | "" | 1 | 1 | 0.0012979507446289062 | 0.00068402290344238281 | 0.5270022042615724 | 32010240 | 32028408 |
| Primitive | wrong_float | "" | 4 | 1 | 0.0012531280517578125 | 0.00064516067504882812 | 0.51484018264840181 | 32010472 | 32028640 |
| Primitive | wrong_float | "selected" | 1 | 1 | 0.0037379264831542969 | 0.0066239833831787109 | 1.7721010332950631 | 32010672 | 40026808 |
| Primitive | wrong_float | "selected" | 4 | 1 | 0.0038900375366210938 | 0.0046379566192626953 | 1.1922652610934052 | 32010904 | 40074344 |
| Primitive | wrong_float | "full" | 1 | 1 | 0.0049161911010742188 | 0.0047800540924072266 | 0.97230843840931136 | 32010648 | 40026664 |
| Primitive | wrong_float | "full" | 4 | 1 | 0.0048708915710449219 | 0.0046300888061523438 | 0.95056289769946156 | 32010880 | 40026896 |
| Primitive | wrong_float | "empty" | 1 | 1 | 0.0029079914093017578 | 0.0030989646911621094 | 1.0656718865294745 | 32010656 | 40026784 |
| Primitive | wrong_float | "empty" | 4 | 1 | 0.0031220912933349609 | 0.0029959678649902344 | 0.9596029018709431 | 32010888 | 40112216 |
| Detail | absent | "" | 1 | 1000 | 4.8139095306396482e-06 | 7.6060295104980471e-06 | 1.5800108959437373 | 9968 | 21496 |
| Detail | absent | "" | 4 | 1000 | 4.765987396240234e-06 | 7.5278282165527348e-06 | 1.5794897448724363 | 10200 | 21728 |
| Detail | vec4 | "" | 1 | 1000 | 5.6409835815429688e-06 | 9.2539787292480469e-06 | 1.6404902789518174 | 10120 | 22056 |
| Detail | vec4 | "" | 4 | 1000 | 5.258083343505859e-06 | 7.9450607299804683e-06 | 1.5110184093588466 | 10352 | 22288 |
| Detail | wrong_float | "" | 1 | 1000 | 4.6348571777343753e-06 | 7.5948238372802735e-06 | 1.6386316872427982 | 10120 | 22056 |
| Detail | wrong_float | "" | 4 | 1000 | 4.9099922180175784e-06 | 7.9970359802246098e-06 | 1.6287268136350392 | 10352 | 22288 |

### Set Color production integration

The whole recipe is now embedded as `nodes/set_color.rays`; its native catalog
registration is removed and its original factory remains the independent
oracle. The retained Color alias is included in regular `runtest`, with one
shared action rather than a duplicate run. `test_lisp_ports.ml` now contains
the whole Color function and exercises the mandatory fixtures, all owners,
group modes, eight Cd storage types, combined raw NaN/Inf channel fixtures,
physical parameter refusals and Detail-group/Edge header rebuild errors.
Reference and strict CPU results agree exactly at every required domain/grain;
the dedicated Color test retains every physical field edit/cache and direct
card/inspector gesture check.

Focused production handle67069 passed the whole Color oracle and all Color
language/cache/editor checks; its only failure was the intended manifest diff.
The reviewed manifest preserves every default, range, label, category, vector
group and slot, replacing native facts with the Lisp body marker and no calls.
Promoted digest: `15828e467da54640d73dc4d51dae5337`.
Fresh native integration handle9249 passed all fourteen whole-port oracles,
native rendering, editor/workspace, API and dependency checks. Its only failure
was the observed generated CLI catalog hash. Updating that hash to
`1bd5f5054049352418b1d9e7f3aaa7a2fd31b0a045e7ade0d751588d1ddc4c9f`
made the same complete integration request, handle8526, exit0:

```sh
opam exec -- _build/default/tools/check.exe @runtest-native \
  @lib/sop/test_lisp_ports @lib/flow_sop/runtest @lib/flow_sop/set_color_draft \
  @lib/sop_catalog/runtest @tools/lisp/test/runtest \
  @test/test_workspace_source @test/test_workspace_shell @test/test_sop_catalog \
  @tools/api_manifest/runtest @test/dependency_gate
```

Logs: `/tmp/rays-set-color-production-focused.log`,
`/tmp/rays-set-color-native-integration.log`,
`/tmp/rays-set-color-native-integration2.log`. The only refreshed golden is
`tools/lisp/test/ml.t`'s generated catalog hash; rendered PNGs, film digests and
public API remain unchanged. No semantic, arithmetic or performance threshold
was relaxed. The preceding fixed 78-row quiet performance proof uses the same
body and shared runtime as this production declaration.

Set Color is whole port14 of128. All six B.11 setters and seven B.12 metadata
ports are complete; 114 whole ports remain. The plan has20 of60 milestones
complete; remaining phase and review gates stay required.

## Prepared-table prefixes for typed gathers

The shared typed Collect executor now extends its contiguous total prefix
through execution-local tables already published after full validation, and
through reads whose executed guard/index banks prove every selected index in
bounds. Proof resolves no capture, changes no state and raises no diagnostic.
The first unknown table, wrong tag, bad selected index or fallible instruction
leaves the entire suffix in reference lane order. Admitted reads use the
existing checked executor. An admitted preparation is skipped because its
already completed publication is its only effect. No source buffer is changed,
no partial result is published, and reductions/scans retain their old order.

The new runnable regression delays first table use by two blocks and keeps
invalid inactive indices after warming; changes live table content/count across
forces; and conflicts a warmed table's late bad index with an earlier second
table's raw-byte cause and state changes. Fusion off/on, domains1/4/8, both
error orders and block/chunk boundaries preserve reference bytes, resolver
calls on the initial domain and rollback. Existing numeric/type/finiteness,
skip/Product, discarded sink, real Web/export/worker and SOP checks also pass.

Focused67661 exited0 for `@lib/flow_ir/runtest @lib/flow_web/runtest
@lib/flow_sop/runtest`. The standalone Text benchmark's diagnostic now prints
full-precision timings and unrounded 2x verdicts; focused97660 passed after
that change. A request for the nonexistent `test_gather` alias failed before
compilation and was corrected to `@lib/flow_ir/runtest`; no check was skipped.
Diagnostic `--trace-text` reuses `Core.pp` and shows the same seven authored
instructions; focused62620 and trace89187 exited0. The refinement that skips
already completed preparation passed the same full focused request56636.

Quiet protocol: Apple M1 arm64, OCaml5.3.0 development build, million rows,
strict Packed Collect, block1024/chunk16384, median3 force-only, unchanged
native-byte preflight and one/four domains. Source preparation and full-major
GC are outside the measured force. No concurrent build or benchmark ran.
Four-domain allocations observe only the initial domain. Every row is retained:

| Experiment | Domains | Native seconds | Packed seconds | Ratio | 2x gate | Native bytes | Packed bytes |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| Prior total prefix72326 | 1 | 0.006232 | 0.055121 | 8.845 | FAIL | 8000168 | 17211544 |
| Prior total prefix72326 | 4 | 0.006342 | 0.015340 | 2.419 | FAIL | 8000168 | 10396088 |
| Prepared tables60246 | 1 | 0.0063140392303466797 | 0.043770074844360352 | 6.9321829097911865 | FAIL | 8000168 | 17446008 |
| Prepared tables60246 | 4 | 0.0064108371734619141 | 0.012497186660766602 | 1.9493845066755922 | PASS | 8000168 | 10454744 |
| Skip ready prepare4802 | 1 | 0.0064330101013183594 | 0.040699005126953125 | 6.3265880957675487 | FAIL | 8000168 | 17446008 |
| Skip ready prepare4802 | 4 | 0.0062489509582519531 | 0.011553764343261719 | 1.8489126287676458 | PASS | 8000168 | 10454216 |

Handles60246/4802 completed the harness with exit0; their one-domain 2x
failures remain. The historical baseline printed rounded timings/ratios;
new rows retain full precision. Relative to72326, Packed force time fell26.2%
at one domain and24.7% at four domains. One-domain allocations grew234,464 B.
This runtime improvement qualifies no whole Text port: one domain is still
above2x and each dependent node still requires its complete recipe/mode matrix.
The separate integer-dispatch and dense-bank allocation ideas remain unapplied.

Profile83973 ran the unchanged one-domain `--profile-text` loop and exited0;
`/usr/bin/sample` handle32859 sampled3 seconds and exited0. Its1,351 main-thread
samples show executor, reference write-barrier, guard/bounds scans, array copying
and GC work. The profile is diagnostic evidence, not another timing gate.

Logs: `/tmp/rays-text-prepared-prefix-focused.log`,
`/tmp/rays-text-prepared-prefix-gather-focused.log`,
`/tmp/rays-text-prepared-prefix-bench.log`,
`/tmp/rays-text-prepared-prefix-trace-focused.log`,
`/tmp/rays-text-prepared-prefix-trace.log`,
`/tmp/rays-text-prepared-prefix-skip-ready-focused.log`,
`/tmp/rays-text-prepared-prefix-skip-ready-bench.log`,
`/tmp/rays-text-prepared-prefix-profile.log`,
`/tmp/rays-text-prepared-prefix-sample.txt`. Contract and proof details are in
`text-gather-validation.md`. No API, shader, generated manifest or golden changes.

## Source group membership promoted to affected points

`(sop/group geometry :name "selected" :owner vertex :as_owner point)` now
returns an owned point-length Int mask. The source owner still determines
lookup; omitting the new optional keyword preserves the existing source mask.
The private resolver reuses `Rdk_core.Element_selection.promote` and the existing
byte-mask unpacker. There is no new geometry algorithm, node callback, public
module or dependency edge. Point/vertex/primitive/edge sources use native
Include-any incidence, including repeated corners, shared/reversed edges,
self-loops and isolated points. Traversal order remains `sop/group_order`'s
source-owner contract. Other promotion targets are refused.

The count-origin visitor covers direct authored calls and captured Source
descriptors. Promoted edge/vertex/primitive masks share the point origin with
P, while unpromoted masks retain their own origin. A three-stage map fusion
check proves this distinction and compares strict execution with reference
bytes. Unknown targets cannot supply a count proof. Optional target rows
project and support direct set/disconnect gestures; sibling group operations
do not inherit the keyword. Normative Flow and Core contracts are updated.

Focused request53971 failed compilation because the initial outside draft used
the nonexistent `Rdk.Element_selection` re-export. Using the existing core
module fixed that without an API addition. Request63202 then passed the native
promotion and graph checks but failed an added fusion fixture's `E_SHADOW`
names. Distinct lambda names corrected the fixture. Full focused request53805
exited0:

```
opam exec -- _build/default/tools/check.exe @lib/flow/runtest @lib/flow_sop/runtest @lib/flow_web/runtest @tools/lisp/test/runtest @test/dependency_gate
```

Tests cover empty/1/7/8/9/32769-point tails, all four source owners,
empty/full/alternating/boundary membership, explicit order, missing/wrong-owner
lookup, foreign edge topology refusal, owned copies and immutable geometry.
Native promotion agrees at domains1/4/8 and grains1/97/4096; authored query
execution agrees with the reference and count-origin fusion remains exact.
JavaScript host fixtures execute all five native topologies, exact Unicode
names and target/type errors. Shared host name validation now uses native
ASCII whitespace, and source type/geometry/name error precedence matches the
native resolver. Extra JavaScript checks reject noninteger, wrong-length and
nonbinary masks and prove result ownership. Final boundary/API request60486
exited0 for `@tools/lisp/test/runtest @lib/flow_web/runtest
@tools/api_manifest/runtest`; no golden or API changes were required.

Benchmark22037 exited0, including exact preflight/postflight masks in every
row. Apple M1 arm64, OCaml5.3.0 dev; one million points, 999999 vertices,
333333 disjoint triangles and one isolated point; alternating source masks;
warmed shared incidence/edge indices; median3 calls with Gc.full_major outside
the timer. The native oracle calls shared promotion then Array.init membership;
the query uses the same promotion plus existing byte unpacking. Allocations
below count the initial domain only. No overlapping agent tools or builds ran;
external QEMU processes were active (44.2% and9.6% CPU in the preflight snapshot).
These are helper measurements, not whole-port or idle-machine qualification.

| Source | Domains | Native seconds | Query seconds | Query/native | Native bytes | Query bytes |
| --- | --- | --- | --- | --- | --- | --- |
| Point | 1 | 0.0052800178527832031 | 0.0020589828491210938 | 0.38995755441163188 | 8000432 | 8001232 |
| Point | 4 | 0.0052268505096435547 | 0.0018911361694335938 | 0.36181179583086254 | 8000432 | 8001232 |
| Vertex | 1 | 0.013342857360839844 | 0.010154008865356445 | 0.76100707597741402 | 8126056 | 8126856 |
| Vertex | 4 | 0.0074379444122314453 | 0.0045139789581298828 | 0.60688527743052212 | 8173288 | 8177072 |
| Primitive | 1 | 0.013930082321166992 | 0.010699987411499023 | 0.7681209030071714 | 8126056 | 8126856 |
| Primitive | 4 | 0.0075621604919433594 | 0.0043950080871582031 | 0.58118418563591656 | 8172416 | 8173456 |
| Edge | 1 | 0.015276908874511719 | 0.012288093566894531 | 0.80435732567576002 | 8126128 | 8126928 |
| Edge | 4 | 0.0079739093780517578 | 0.0047259330749511719 | 0.59267454029002842 | 8168832 | 8172608 |

Reproduce with `_build/default/lib/flow_sop/test_group_kernel.exe
--bench-promotion` after the focused build. Logs:
`/tmp/rays-group-point-promotion-focused.log`,
`/tmp/rays-group-point-promotion-focused2.log`,
`/tmp/rays-group-point-promotion-focused3.log`,
`/tmp/rays-group-point-promotion-boundary.log`,
`/tmp/rays-group-point-promotion-bench.log`.
Existing host cancellation checks remain; this adds no cancellation-granularity
claim. C1 topology construction, IEEE computed arrays, normal fallbacks and
native diagnostic mapping remain separate prerequisites. B.5 remains complete;
whole completion stays14/128 and20/60 milestones.

## Private IEEE arithmetic experiment and actual JavaScript proof

2026-10-13, Apple M1 arm64, OCaml5.3 development profile, Node24.19.0.
Outside-only source and retained logs are `/tmp/rays-ieee-proof`; no production
API, descriptor, policy or registration is accepted by this experiment.
The actual checker/residual/Core_region/SSA compiler drives an independent
scalar walk and the existing Packed borrowed-column/owned-plane runner.
Native RDK uses domains1/4/8 and grains1/97/4096; CPU uses domains1/4/8 with
its existing1024-lane blocks and16-block chunk schedule. Raw32769-row fixtures
exercise multiple chunks, ordinary finite controls and selected/untaken causes.

Build-4 and native-3 EXIT0; actual32769-point distance→ordered maximum→mask
matches native/scalar/CPU words, including successful Inf distances and NaN
masks. Identity/division/sqrt/explicit FMA/separately rounded Mul+Add cover
14^3 combinations of signed zero, subnormal/normal bounds, infinities and signed
quiet/signalling NaN payloads, repeated over32769 rows. No isNaN equivalence
replaces exact bit comparisons. Constant-policy tests retain arithmetic in SSA
rather than ordinary finite constant folding.

Final Node arithmetic4 EXIT0 (`js-arithmetic-4.log`, diagnostic elapsed~0.32s):
43904 primary native words,43904 held-out changed NaN-payload words,10011
independent finite FMA words and32769 actual serialized SSA distance/mask rows.
The private raw-word engine derives496 operand-category NaN selectors and
checks payloads excluded from training; it has no per-input expected-word
lookup. OCaml5.3 Float.min/max sign-dependent operand selection is mirrored
exactly, including unchanged signalling NaNs. Finite FMA reuses the existing
BigInt implementation. Unmapped forms explicitly refuse E_WEB_IEEE_BITS.
Failed Node derivation attempts1–3 are retained (abs sign clearing, native
min/max behavior and unnecessary comparison derivation); final checks pass
without changing expected words. The earlier transport-only arithmetic-refusal
check remains recorded and is not counted as arithmetic proof.

Production work still needs opaque raw results/ownership, closed instruction
policy propagation through IR/cache/fusion, full reference dispatch, generic
source consumption, GPU refusal and actual language/graph boundaries. The
proof has no port/performance/architecture-portability qualification and no
milestone count increment. The full current scope stays128 ports/60 milestones.

## Lisp declaration cache keys preserve unchanged siblings

2026-10-13. The C.1 shipping run process91290 exposed a pre-existing broad cache
regression after Set Color became a Lisp body: `test_workspace_live` expected
three downstream misses for a transform scrub and observed four. A sibling
Set Color call with unchanged parameters/input also missed because the shared
public factory source digest included the edited workspace call.

The shared Lower fix keys ordinary Lisp factories on checked declarations,
helpers and macros, retaining existing separate parameter/cooked-input keys.
Supplied function slots keep the conservative whole-source key so closure/body
capture invalidation is not lost. All declarations still conservatively
invalidate ordinary factories; that known ceiling has a ponytail comment.
A new one/eight-domain test requires an unchanged sibling to hit after a call
edit and both dependent bodies to miss after a helper-body edit, comparing
fresh-oracle geometry bytes.

The first focused shared-launcher request process25298 completed EXIT1:
Flow SOP (including new cache and actual subnormal fixtures), API and dependency
checks pass, but the existing live-workspace test observes two misses, not three.
Set Color's inferred component facts do not read P: after the shared source-key
fix, its existing cached Cd delta carries the fresh transformed positions.
Only Transform and Merge need a real cook; upstream/sibling nodes and both color
nodes hit. The live test now requires exactly two misses/four hits and adds full
fresh-oracle geometry-byte equality plus a changed-output assertion to rule out
stale P. This updates the cache expectation to the existing component contract;
it does not relax output correctness. Request50009 completes EXIT0 with the
strengthened Flow SOP/live-workspace/API/dependency gate;
log `/tmp/rays-lisp-declaration-cache-focused2.log`.
The first ship run91290 is EXIT1 and also used dummy video settings
and failed native smoke startup for that reason; the final shipping check must
use native video. C.1's earlier focused request57033 is separately EXIT0.
The strengthened packed fixture now uses actual `Float.next_after 0. 1.`
subnormals; the earlier `Float.min_float` spelling represented the smallest
positive normal, so its earlier success alone did not prove subnormal coverage.

## C.1 owned topology queries and mesh construction

2026-10-13. The complete C.1 focused gate passes. Full details and retained
failure history are in [geometry-arrays-validation.md](geometry-arrays-validation.md).
`Topology_kernel` wraps existing native owned topology/geometry construction;
the ordinary typed operators, retained Lower arrays, graph edits, editor menu
and JavaScript geometry host protocol carry the capability. No new Core
instruction, topology algorithm, dependency or SOP-specific callback is added.

The final focused launcher request covers Flow SOP/graph/IR/web, CLI cram,
dependency/API gates and the actual editor menu. Process57033 EXIT0;
`/tmp/rays-c1-focused11.log`. Five native plain-topology/P fixtures match complete
geometry bytes at domains1/4/8, grains1/97/4096, direct arrays and authored
reconstruction, strict compiled and reference execution. A32769-point authored
packed map preserves signed zero/small-normal bytes; the strengthened actual
subnormal fixture also passes in request25298 (its unrelated live cache assertion
failed separately). Input/query ownership, captured/direct
distinct counts, warm caches, fresh unread components, topology/attribute-layout
invalidation, native validator order/messages,
exact Int values above2^53, kinds, cancellation, lazy causes, live/state/zone
captures and failed-state rollback pass. Mesh/topology cards, typed Int defaults,
checked keyword/connection edits and production menu insertion pass. Actual
native→JavaScript fixtures cover both host heads and malformed inputs.

An explicit host source is refused by the JS frame printer E_WEB_SOURCE;
the production 2D CLI rejects a reached SOP graph containing both operators
E_WEB_GRAPH before writing output. Earlier packed-printer assertions were
incorrect because that printer expects region source bindings separately.
No numeric/error/cache oracle was relaxed. The public existing reads helper
needed by mesh facts was accepted separately in ed8eb646.

C.1 moves to B.1/B.2/B.4 prerequisites to remove the B.10→C.1→B.R→B.10 cycle;
indexed consumers additionally need C.2. C.1 constructs only explicit topology
and finite Flow points. Attribute/group/instance remap, raw NaN/Inf point
transport and maximum-count AoS/SoA parity remain separate work. There is no
whole-port or 2× performance qualification in this capability gate.
Accepted ports remain14/128; accepted milestones advance20/60→21/60.

Final native-video shipping request54530 completes EXIT0 with
`OCAMLRUNPARAM=b opam exec -- _build/default/tools/check.exe --ship`;
log `/tmp/rays-c1-native-ship.log`. All14 whole-node tests, strengthened cache
tests and the complete workspace IR sweep pass:43 standard files,1 custom
catalog executable,13 fixtures, cooked payload comparisons at domains1/8.
The launcher completes @all/@runtest/native smoke/git diff --check. Earlier
dummy-video shipping request91290 failed native smoke and exposed the shared
Lisp cache issue; focused cache request50009 and this final shipping check
pass after the reviewed source-key fix and stronger fresh-oracle assertions.

## Lazy diagnostic scopes and native row selection

2026-10-13. `with_error` is a mapping-only scope: pure record-to-record mapping
always rethrows a reached typed error; success leaves the mapper untaken, and
cancellation and unrelated host exceptions bypass it. Direct geometry/image
results complete inside the scope and retain their original handle. Structured
Core uses independent protected/mapper blocks; reference evaluation, graph
projection/checked gestures and emitted JavaScript share the behavior. Lossless
Flow/SOP adapters retain code/message/cause/hints/ordered trace. Existing Flow
span/position are retained; SOP has no corresponding location fields.

`error_rows` validates a complete immutable Int 0/1 mask. Empty/all-zero masks
return nil with no handler/host lookup. Failing masks invoke a pure
Int-to-diagnostic mapper once and always throw; the index never becomes a
successful numeric result. `first` is host-independent; `range-last` uses a
private host-bound cook grain and selects the last failing row in the first
failing grain range. Real checked raw-attribute masks exercise the JavaScript
geometry-host twin at grains1/97/4096. The current 2D emitter supports first
and explicitly refuses range-last; no authored grain getter, SOP callback,
Packed instruction, GPU fallback or automatic numeric contraction is added.

Focused shared request54421 EXIT0, `/tmp/rays-diagnostics-focused9.log`, covers
@check, Flow/IR/graph/SOP/web, CLI cram, API and dependency gates. Strengthened
unused native-child and called-local-helper checks pass in request65107 EXIT0,
`/tmp/rays-diagnostics-focused10.log`, covering Flow IR/SOP. Native Peak/Mountain
selected code/message/cause/hints match reference and strict compiled unused
validation at domains1/4/8, grains1/97/4096. Successful caches ignore grain.
Deferred child tests require one cook, preserve raw UTF-8/cause bytes, hints and
ordered native trace, and keep disabled children/mappers untaken. Pure tests
cover nested nil, full diagnostic envelopes with and without a cause, malformed
mapping, mapper failure, cancellation, unrelated exceptions,32769-element
strict numeric work and nested/policy edits. Actual emitted JavaScript agrees
without refreshing existing goldens; typed worker failures preserve envelopes
below/above chunk size at one/eight workers. The four intended public interface
changes are reviewed and the API manifest is promoted, with implementation and
acceptance to be committed together before any consuming port.

Failed requests59256/60539/57727/47660/92093/98630 and row request55420,
plus focused attempt8, are retained in `/tmp/rays-diagnostics-focused1.log`
through `focused6.log`, `focused8.log` and `/tmp/rays-diagnostics-row7.log`.
They exposed an ambiguous Workspace record
inference, a missed test visitor, fixtures with invalid value-graph results or
missing input defaults/keyword names, nonexistent fixture constructors and a
private exception fixture assuming the wrong envelope representation. Real
production gaps were also corrected: nested nil completion now skips a host
lookup; the shared exception helper keeps location/hints/trace without a cause;
unused residual diagnostic bindings retain the enclosing let for execution,
including called local helpers. The native Peak oracle caught the formerly
skipped validation. No native oracle, numeric tolerance or error-order gate was
relaxed. Initial host-independent mask validation has no native cancellation
token; Session entry/completion and failing host selection protect their
boundaries. Its validation-latency ceiling is explicit in code and specification.

Native-video shipping request3786 EXIT1 finished its full workspace sweep:
43 standard files, one custom-catalog executable and13 fixtures. Its only
reported failure was the missing text-completion entry for `with_error`;
`/tmp/rays-diagnostics-native-ship1.log`. Both new special forms now have
completion documentation. Request84192 EXIT0 confirms the completion fix, API
and dependency gates; `/tmp/rays-diagnostics-completion-focused.log`.
Final native shipping request72554 EXIT0 passes with that fix;
`/tmp/rays-diagnostics-native-ship2.log`. Its full workspace sweep covers43
standard files, one custom-catalog executable and13 fixtures; native examples,
all default tests, the build and whitespace check pass. These capabilities add no whole SOP
port and tick no additional milestone:14/128 ports and21/60 milestones remain.
## Typed Mesh coordinate-plane integration

2026-10-13. `sop/mesh_planes` accepts an exact x/y/z Float-array record and
the three required Int topology arrays. It reuses the owned Mesh boundary,
copies every retained input plane and preserves native scalar-array capacity
without allocating a combined3*n Float buffer. All Lower Mesh callers share
the same recognition predicate for source discovery, live/state, zone and
factory reconstruction. The JavaScript host twin validates exact planes and
uses the existing topology boundary. This adds no SOP port or milestone.

Focused request83367 EXIT0, `/tmp/rays-mesh-planes-focused6.log`, covers @check,
Flow SOP/graph/web, CLI/Core/JavaScript fixtures, actual workspace-shell Add,
API and dependency gates. Five plain topologies and32769 points match exact
native/reference bytes at domains1/4/8 and grains1/97/4096, including signed
zeros/subnormals, immutable ownership, source read/count facts, warm caches,
lazy errors/causes, typed helper captures, cancellation and failed-state rollback.
No golden, public interface, registration or performance gate changes.

Requests22642/4780/55939/76466/76922 EXIT1 exposed invalid draft test gestures,
printer-sensitive matching, missing typed census defaults, vector field access,
name shadowing and separately created snapshot identities. Logs focused1–5
are retained. Corrected tests keep the original native and ownership assertions;
the ordinary checker and numeric contract remain unchanged. Whole counts remain
14/128 ports and21/60 milestones.

## Lossless byte strings in workspace source

2026-10-13: canonical Lisp printing now escapes the printer's three reserved
span-marker bytes as exact three-digit decimal string escapes. The shared
reader accepts byte escapes `\000`–`\255` and rejects malformed or out-of-range
escapes; raw span-marker bytes remain refused in workspace source. Existing
string printing and golden fixtures keep their established representation.

The runnable checks preserve all 256 bytes through flat/pretty printing and
reading, validate all 256 decimal escapes, reject six malformed escapes, and
exercise an actual typed Text-array card edit, source save, reload and graph
projection. `/tmp/rays-string-bytes-focused2.log` records EXIT 0 for the shared
launcher with `@lib/flow/runtest @lib/flow_graph/runtest`. The first draft graph
fixture used value context (which requires a Float result); it was corrected to
the established host context before this passing run. No gate was loosened.
This is a shared source correctness fix, with no new whole-node port or milestone.

## Exact node versions and strict state context

2026-10-13: `defnode :version` is an exact nonnegative integer literal, defaults
to 1 and reaches both normal and disconnected-callable runtime nodes. Parameter
rebuilds and relabelling preserve it; the existing SOP session key already reads
runtime version. No extra parameter or generated manifest row is introduced.
Checks include default/0/2/max_int, malformed and duplicate metadata, actual
lowering and cook reuse, unchanged schemas/parameter keys, real card edits and
saved source. The first draft inspected the first embedded definition; the test
now selects the declared `sop/test_encoded` explicitly.

Strict Core execution now retains its residual's state context. `execute`/`run`
accept `strict`; a compiled failure restores state and returns its diagnostic
without entering the walker. Ordinary fallback behavior remains. The executor
supplies root and strict independently. A regression makes walker fallback
observable, and eight strict state frames compare values, diagnostics, stamps
and rollback contents to the reference. All three pending array-family state
regressions also pass, without qualifying their browser integration.

`/tmp/rays-c45-native-focused5.log` and
`/tmp/rays-defnode-version-focused2.log` completed with EXIT 1 solely for their
then-pending intended API snapshot. Their functional aliases passed: native
Flow/IR/SOP/graph, catalog, CLI, workspace shell and dependency checks as recorded
by each command. After scoped API promotion, `/tmp/rays-strict-state-focused.log`
records EXIT 0 for `@check @lib/flow_ir/runtest @tools/api_manifest/runtest`.
The two public version fields and strict Core calls have a separate API acceptance
commit; the five array primitive tags remain an unstaged, pending integration.
No new whole-node port or plan milestone is counted here.

## Shared topology validation and applied whole Line draft (pending)

Whole-port acceptance remains **14/128** and plan acceptance **21/60**. Line is
an applied `.pending` draft; the native factory remains registered. The full
scope, both modes, default four-ULP gate and strict 2x speed gate are retained.

`@check @lib/flow_sop/line_draft` passed (focused6), with byte-exact native and
reference comparison across domains 1/4/8 and grains 1/97/4096, both modes,
one/two/4225/32769/100001 points, extreme directions, exact endpoints, native
errors/cancellation, all schema fields, cache keys and warm hits, card/inspector
and every physical edit. Zero-input bypass is refused with native E_BYPASS.
Real native and Lisp value lanes agree for live time and accumulated retained
state, with repeat-frame and cook state isolation. The reserved interpolation
binding was renamed from `t` to `fraction`; tests preserve context-time syntax.

The eight fixed million-point rows failed two four-domain curve cases at
2.750253293x and 2.744239401x. Profiling the shared public topology constructor
found its callback scan significant. A local tail-recursive scan now preserves
the exact validation order, short circuit, messages and API. The runnable
`tools/bench_topology.ml` checks valid and last-invalid public results while
timing seven samples, with construction outside the measured validation.

Apple M1 arm64, OCaml 5.3.0, Dune dev, one domain, 1,000,000 vertices:

| Constructor validation | Before seconds | After seconds | Before/after allocated bytes | Promoted/major words |
| --- | ---: | ---: | ---: | ---: |
| Valid open polyline | 0.003259182 | 0.001287937 | 632 / 592 | 0 / 0 |
| Invalid last vertex | 0.002113104 | 0.000811815 | 504 / 464 | 0 / 0 |

All agents paused during measurement; desktop/VM background processes remained.
Command: `opam exec -- _build/default/tools/bench_topology.exe 1000000`.
Logs: `/tmp/rays-topology-benchmark-before.log`,
`/tmp/rays-topology-benchmark-after.log`, both exit 0.
The focused RDK and Flow SOP suite plus Line draft passed in
`/tmp/rays-topology-validation-focused1.log` (exit 0), using the shared
check launcher with `tools/bench_topology.exe @lib/flow_sop/line_draft
@lib/flow_sop/runtest @lib/rdk/runtest` under dummy SDL.

After the shared scan, six of eight Line rows still pass; four-domain curve
ratios remain **2.284607746x** and **2.126230508x**, so Line remains unaccepted.
`line-port-audit.md` records both full tables and allocation counters. The
follow-up executable printed all eight rows before exit 2, with full million
point native/reference/domain byte preflight intact. Remaining work is the
shared constructor cost and atomic production registration/source integration;
no points-only substitution, weakened speed threshold, or count increment.

## Native Rewire baseline and rejected integer-copy shortcut (2026-10-13)

Whole-port acceptance remains **14/128** and plan acceptance **21/60**.
No payload-remap/concat production change or new whole SOP is accepted here.

Before changing Rewire's shared edge-ancestry consumer, the new runnable
`tools/bench_rewire_payload.exe` captured complete native output byte strings
for five fixed public `Rewire_vertices.run` cases. Fixtures include repeated
shared triangle edges, coalesced OR ancestry, Point compaction, ordered groups,
raw exceptional Float/P words, arbitrary Text bytes, immutable Detail data and
Vertex provenance. Independent counts/corners/group assertions and full-byte
one/four-domain comparisons passed; all seven timed outputs per row also matched
and left source bytes unchanged.

Build: `opam exec -- _build/default/tools/check.exe tools/bench_rewire_payload.exe`
(`/tmp/rays-rewire-benchmark-build1.log`, exit0). Actual baseline:

```sh
opam exec -- _build/default/tools/bench_rewire_payload.exe \
  --record /tmp/rays-rewire-before-bytes-20261013 \
  --machine 'Apple M1 Macmini9,1 16GiB macOS arm64' --profile dev \
  --revision 6e684d5e49d29a7302dd8955a038d097c31d9568 \
  > /tmp/rays-rewire-payload-before.log 2>&1
```

Root session32239 exited0. RDK was unchanged from that revision. All three agents
paused and acknowledged before timing, then were released immediately afterward;
no other root validation or benchmark ran during the table. Ordinary desktop/VM
background activity remained. OCaml5.3.0, grain4096, seven-sample medians;
699052 points,1048578 corners,349526 primitives per source. Source construction,
pool startup, serialization and byte validation are outside timing; changed
outputs create fresh target topology. Counters are initial-domain only, and heap
high-water is process-lifetime, not per-call peak. Allocation columns describe
that row's median-time sample; the original log retains all70 samples.

| Case | Domains | Median seconds | Allocated bytes | Promoted bytes | Major bytes |
|---|---:|---:|---:|---:|---:|
| no_edges_permute | 1 | 0.007125854 | 19926920 | 0 | 19923024 |
| no_edges_permute | 4 | 0.005103827 | 19976728 | 0 | 19923024 |
| edges_metadata_only | 1 | 0.009342909 | 16781416 | 0 | 16777264 |
| edges_metadata_only | 4 | 0.007108927 | 16829896 | 0 | 16777264 |
| edges_permute | 1 | 0.167464018 | 274821464 | 856 | 232872904 |
| edges_permute | 4 | 0.119697094 | 274935504 | 2128 | 232874176 |
| edges_coalesce | 1 | 0.164947033 | 235499800 | 856 | 210328488 |
| edges_coalesce | 4 | 0.130802870 | 235609608 | 2128 | 210329760 |
| edges_coalesce_compact | 1 | 0.204488039 | 293020320 | 1160 | 267847856 |
| edges_coalesce_compact | 4 | 0.158887863 | 293355056 | 2432 | 267849128 |

The later factoring must relink this same harness and use `--verify` with these
saved full byte strings, identical fixtures/trials/grain. No before/after speed
claim is made until that paired run exists. Mesh_merge factoring needs a separate
public-path baseline; this Rewire table does not cover it.

The Line curve-copy hypothesis was also measured before a production change.
`opam exec -- _build/default/tools/bench_topology.exe 1000000 --copy` completed
session71291 exit0 (`/tmp/rays-integer-copy-benchmark1.log`) with all agents paused
and acknowledged. Seven-sample one-domain medians were0.001564980sec for
`Array.copy` and0.043588877sec for the typed allocation/for-loop copy, both
8000328 allocated bytes,0 promoted words and1000001 major words. The harness
checks exact values, distinct ownership and mutation isolation. Keep the standard
library implementation; the typed loop does not solve Line's failed whole
performance gate.

Current integration evidence, still pending acceptance: the shared lowering fix
uses real factory parameter paths to distinguish live geometry/rest inputs from
parameter drives. The actual 5001-item SOP map/static-filter collection passed
native full-byte, child-cook, reference, domains1/4/8 and grains1/97/4096 checks.
Known 5001-handle Core map/filter captures passed strict/reference comparisons
at times0,0.25,0.75,1 after adding builder sharing. Their ordinary Int-list refusal
exposed a recursive selector expansion on a >4096-element index list; the shared
selector now refuses before recursive expansion. The diagnostic run90992 exited0.
The corresponding broader gate and emitted region-argument worker proof still
need to finish before capability/milestone acceptance. The geometry time-shape
checker refusals and strict4ULP/2× whole-port gates remain unchanged.

## Bulk-array runtime proof and separate API acceptance (2026-10-13)

Accepted whole ports remain **14/128**, and accepted plan milestones **21/60**.
C.4 and C.5 remain unticked pending the remaining integration review. No port
performance gate, API tolerance, parser budget or collection bound is relaxed.

`77be0b5c` separately accepts the intended closed Core variants:
`Array_max_length`, `Array_scatter_add`, `Array_compact`, `Array_scan_sum`,
`Array_grade`, `Array_index_of`. No other public module changes in the snapshot.
The reviewed CLI fixture adds only the copied `runtime/region_bindings.js` file.

Actual focused integration:

```
opam exec -- _build/default/tools/check.exe @check @lib/flow/runtest @lib/flow_ir/runtest @lib/flow_sop/runtest @lib/flow_graph/runtest @lib/flow_web/runtest @lib/flow_gpu/runtest @tools/lisp/runtest @test/dependency_gate @test/test_workspace_shell @tools/api_manifest/runtest
```

`/tmp/rays-region-binding-focused6.log` terminated EXIT 1 **only** on the two
reviewed expected fixture updates, now promoted. Functional checks passed:
native/reference/strict Core and domains; source ownership/count origins/state
rollback; actual geometry compositions; cards/menu/source edits; actual emitted
JavaScript frames with production runtime and null/one/eight worker pools.
The new region-binding check executes changing counts 0/13/5001/32769 and tails,
Int/Float/Text/Vec2/3/4, real computed Invoke inputs, nested producers, lazy
tables/causes, signed63 and recursive nonfinite argument validation. Inputs and
counts are never supplied from reference results. All-byte Text remains within
the existing 2,048 AST budget. Fixed-input CLI export admission is unchanged.

Native 5001-element geometry map/filter lowering and actual SOP collection
proofs pass. Known cooked captures share one builder outside the loop; ordinary
oversized value lists still refuse. The dynamic ordinary-list selector now
refuses before recursively recreating an equally oversized index list. Live
geometry rest arguments no longer become invalid parameter drives.

Parallel read-only review identified remaining cases requiring runnable proof:
nested Int PArray width validation; worker transport of capture statement
locations; plain-Float Product preparation eagerly reading a later source after
an empty first source and forcing captures for zero iterations. Typed Product
already suppresses those reads. Native/reference semantics require suppression.
Before changing the native Float hot path, the existing Product benchmark will
record a genuine Float-bank before/after cost with unchanged fixtures/trials.

The broad native shipping run is in progress in
`/tmp/rays-bulk-array-native-ship1.log`; no terminal result is claimed here.

## Bulk-array boundary closure — 2026-10-13

The previous snapshot's native shipping run completed: session56174 EXIT0,
`/tmp/rays-bulk-array-native-ship1.log`. Its 43 standard workspaces, one custom
catalog executable and 13 fixtures passed the IR sweep; existing accepted whole
SOP ports and finite native smoke checks remained green.

Three review findings are now corrected in shared execution boundaries:

- Ordinary Float-bank Cartesian Product evaluates inputs in written order and
  suppresses later producer/borrowed-source callbacks after an empty input.
  Zero-iteration execution does not force body captures. Zip still reaches all
  inputs; malformed reached borrowed columns retain their original refusal.
- Recursive JavaScript argument validation checks every physical PArray layout,
  including Int width3 and unknown Float width5 nested inside Lists/Records.
  Valid mixed lists retain native widening/fallback typing and exact signed63
  leaves; selected arguments are validated even for empty output.
- Actual workers preserve a capture preparer's statement location in the error
  envelope before the outer frame can assign its Invoke location. Code, message,
  raw-byte cause and statement are compared across null/one/eight-worker pools
  and small/multiblock outputs.

Focused command (dummy SDL video/audio):

```
opam exec -- _build/default/tools/check.exe @check @lib/flow/runtest @lib/flow_ir/runtest @lib/flow_sop/runtest @lib/flow_graph/runtest @lib/flow_web/runtest @lib/flow_gpu/runtest @tools/lisp/runtest @test/dependency_gate @test/test_workspace_shell @tools/api_manifest/runtest
```

Session95283 EXIT0, `/tmp/rays-region-binding-focused9.log`. The preceding run
exposed a test type annotation and then different OCaml empty-array block tags;
the regression now compares cardinality and every binary64 element bit, rather
than Marshal's internal empty block representation. Actual JS boundary/worker
checks ran and passed in `/tmp/rays-region-binding-focused7.log`; Dune retained
those successful unchanged checks in the final focused invocation. No semantic
oracle, tolerance, worker count, fixture or strict execution requirement was
dropped.

Measured the existing genuine Float-bank Product before and after the native
fix using the same `test_packed.exe --bench-float-product`: 1,000,000 outer rows
×16 inner rows, four instructions, fusion disabled, exact independent native
preflight, median3, domains1/4. Apple M1 Macmini9,1, 16GiB, macOS arm64,
OCaml5.3.0/Dune dev. All three agents acknowledged a quiet window before each
direct built-executable run and were released immediately after it terminated.
This does not claim machine-wide desktop inactivity.

| domains | before packed seconds | after packed seconds | before bytes | after bytes |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 0.168021 | 0.167417 | 181999456 | 181999400 |
| 4 | 0.072880 | 0.066169 | 147004768 | 147579000 |

Before session6481 EXIT0, `/tmp/rays-float-product-before-20261013.log`; after
session60312 EXIT0, `/tmp/rays-float-product-after-20261013.log`. Allocation is
initial-domain only. These timings show no observed slowdown for the fix;
the generic packed/native ratios remain17.327× and6.876× after it, so they do
not qualify a whole SOP port or relax the2× gate.

The corrected snapshot's final native `check.exe --ship` is running as
session11075, `/tmp/rays-bulk-array-native-ship2.log`. Its terminal result must
be recorded before C.4/C.5 are checked. Accepted ports remain14/128 and completed
milestones21/60. Circle and payload remap/concat remain unaccepted candidates.

## C.4/C.5 accepted — final native integration (2026-10-13)

The corrected compiler snapshot `93f5528f` passed native
`opam exec -- _build/default/tools/check.exe --ship`: session11075 EXIT0,
`/tmp/rays-bulk-array-native-ship2.log`. This ran `@all`, `@runtest`, the finite
native smoke checks and `git diff --check`. The workspace IR sweep passed all
43 standard workspaces, one custom-catalog executable and 13 fixtures, with
four times and domains1/8; existing14 accepted whole ports remained green.
The same running handle was retained throughout; no build was restarted merely
because its workspace sweep took longer than a tool observation window.

Together with the focused EXIT0 and actual worker proof recorded above, this
closes the stated C.4/C.5 language gates. Native/reference/Core checks include
domains1/4/8, immutable buffers, exact Int values/wrap above2^53, stable equal
keys, byte-Text ordering, missing/first-match lookup, lazy failures and state
rollback. C.4 additionally has actual compact/scan geometry compositions and
ordered scatter failure precedence; graph/menu/save gestures and native/JS
fixtures passed. Actual generated frames use compiled Invoke arguments/source
preparers and null/one/eight-worker pools, not reference-fed inputs or counts.
The three review findings (recursive storage, Float Product forcing and worker
statement provenance) are corrected and tested.

Task C.4 (compact/scan/scatter) and C.5 (grade/index) are now checked in the plan.
Completed milestones:23/60 (38.3%). Accepted whole ports:14/128 (10.9%), with
114 remaining. No whole Sort, Enumerate, Merge, Line, Circle or other pending
port is counted from language capability checks. The whole-node native4ULP and
2× speed gates remain unchanged. Pure bulk intrinsics retain their documented
host cancellation boundary; no internal cancellation checkpoint is claimed.

Next integration candidates are generic payload remap/concat and whole
generators. Read-only remap review found a native/JS early-malformed-ancestry
cancellation-order mismatch; the frozen follow-up preserves native deferred
invalid reporting through both validation scans. It remains unbuilt/unaccepted.
Points design preserves the native hard maximum50; its fixed proposed timings
label aggregate1M output as20,000 cold50-point cooks, separately from36 micro
rows. Both retain every row and the unrounded2× gate; no single1M Points
geometry, widened schema or substituted sibling implementation is claimed.

## Shared topology validation and original Merge baseline (2026-10-13)

Measured original public `Topology.create_owned` on the unchanged native
implementation, then changed only its large pure vertex-reference scan to
stable65536-row blocks using the existing Parallel pool. All cheap prefix
guards still precede the scan; offsets/kinds follow the joined Boolean result.
Single-block inputs remain sequential, and invalid first vertices retain an
immediate refusal. Owned input planes, Flow's copies and trusted native
generator constructors remain unchanged. Later malformed blocks may still
scan concurrently; the code records that rejection-latency ceiling.

Actual original and final medians,1M vertices, seven samples:

| case | domains | before seconds | final seconds | before allocated bytes | final allocated bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| valid | 1 | 0.001051188 | 0.001350880 | 592 | 840 |
| invalid first | 1 | 0.000000000 | 0.000000000 | 464 | 472 |
| invalid at65536 | 1 | 0.000051975 | 0.000761986 | 464 | 712 |
| invalid last | 1 | 0.000782013 | 0.000815868 | 464 | 712 |
| valid | 4 | 0.000795841 | 0.000280857 | 592 | 5424 |
| invalid first | 4 | 0.000000954 | 0.000000000 | 464 | 472 |
| invalid at65536 | 4 | 0.000056028 | 0.000275135 | 464 | 5232 |
| invalid last | 4 | 0.000793934 | 0.000298023 | 464 | 5240 |

Before EXIT0 `/tmp/rays-topology-validation-before-20261013.log`; intermediate
EXIT0 `/tmp/rays-topology-validation-after-20261013.log`; final first-guard
correction EXIT0 `/tmp/rays-topology-validation-after-first-guard-20261013.log`.
These measurements support four-domain valid-scan improvement, while retaining
the observed one-domain valid and later-malformed cost increases. Zero printed
time is timer resolution, not proof of zero work. Allocation is initial-domain
only; promoted/major words were zero in these stage samples.

Focused final check session22795 EXIT0:
`@lib/rdk/test_core @lib/flow_sop/line_draft @test/dependency_gate` plus benchmark
relink. `/tmp/rays-topology-validation-focused4.log`. Shared constructors retain
exact1/4/8-domain topology planes, input identity/immutability, empty/cutoff/block/
tail cases and every simultaneous-invalid guard/vertex/offset/kind precedence.
The unchanged complete8-row Line table now passes seven rows but still fails
default curve/domain4 at2.007166650. Session35225 EXIT2,
`/tmp/rays-line-topology-after-cwd-20261013.log`; exact native/reference/domain
preflights passed. All failures remain evidence; Line remains unaccepted.

Original public Mesh_merge baseline captured before its payload factoring:
session75750 EXIT0, `/tmp/rays-merge-payload-before-20261013.log`, full exclusive
byte snapshots `/tmp/rays-merge-payload-before-bytes-20261013`.
Native revision2054a1c42e814cb7b9b4813fb87c7990e6787918, Apple M1 Macmini9,1,
16GiB, macOS27.0.1 arm64, OCaml5.3.0/Dune dev. Eight fixed cases×domains1/4,
grain4096, seven samples, public Merge every sample. Full outputs and immutable
sources matched; four exact schema/group/edge/Detail errors and two empty
outputs were retained. Source preparation/pool startup/serialization/GC were
outside timing. Every agent acknowledged each quiet window and was released
after the terminal results; desktop/VM inactivity is not claimed.

| case | d1 median seconds | d4 median seconds |
| --- | ---: | ---: |
| plain repeated | 0.004865170 | 0.002671957 |
| raw matching | 0.021144867 | 0.020828009 |
| reordered schema | 0.015522957 | 0.015444040 |
| real empty | 0.010159016 | 0.010483027 |
| padded union | 0.015304089 | 0.015285969 |
| exact groups | 0.021564007 | 0.020860910 |
| provenance generated | 0.015646935 | 0.015496016 |
| provenance retained | 0.015644073 | 0.015632153 |

The complete log retains all samples, initial-domain allocation/promoted/major
bytes, process-lifetime heap high-water and full byte sizes. Plain control has
699056 points/1048584 vertices/349528 primitives; full four-block raw cases have
65552 points/98328 vertices/32776 primitives. Ordered-empty/all-owner groups,
edge membership, exact arbitrary Text bytes, signed zero/subnormal/Inf/distinct
NaNs, all storage/CSR/matrix rows and source-tag retention/generation are real
fixtures. After concat factoring, relink the SAME harness and `--verify` the
SAME directory with unchanged sizes/trials/grain. This qualifies no whole Merge
port. Accepted counts remain14/128 ports and23/60 milestones.
