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

B.11's native declaration census adds B.4 owner counts as a prerequisite:
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

B.12 also requires Lisp-authored encoded parameter normalization. Native
`Param.Encoded` fields decode edits and re-encode their normalized values for
the schema view and cook key. A plain Text defnode field with a body decoder
does not preserve that boundary: equivalent owner/conflict tokens retain
different keys and malformed edits fail later. The generic declaration needs
validation and canonicalization at the parameter boundary before these whole
ports can ship; B.12 remains unchecked.

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
| B–E | No port evidence recorded here yet. | All language, port and phase review gates. |
| B.1 | Owner-aware Float/Vec2/Vec3/Vec4/Int/Text/CSR attributes, literal-selected result types and a cooked Boolean `sop/has_attr` predicate are implemented. Focused `@lib/flow_sop/runtest @tools/lisp/runtest` exited 0 (session 98738): all-owner strict/reference Text round trips, exact UTF-8/empty strings, copied read/write ownership, count/type errors, a strict 4,097-element authored text map, empty geometry/detail counts, exact one/eight-domain bytes, graph type edits through Text, numeric multi-block fixtures, distinct owner/CSR count origins and strict compiled lazy query guards pass. Native-to-JavaScript census including Text attributes passes 15,152 cases across 79 contracts. Shared structured Core resolves genuine host sources without interpreter fallback. No new port is claimed. | Complete: focused, shipping, native and web foundation gates passed; final commands and coverage below. |
| B.2 | The expanded native-to-JavaScript primitive census passes 15,029 cases across 78 contracts: all ten exact integer operations, five comparisons, typed integer construction/range/build/count/get/slice/concat/sum and the existing floating/host contracts. Signed bounds, values above 2^53, wrapping sums beyond 4,096 elements, invalid shifts, selectors and element types retain exact integer/error checks. The census exposed and repaired shared native range-selector and JavaScript integer builder/error boundaries. | Complete: focused, shipping, native and web foundation gates passed; final commands and coverage below. |
| B.4 | `test_topology_kernel` compares all four counts and canonical edge endpoints with native `Topology_index` on empty, shared polygon, repeated open curve, closed curve and mixed nonmanifold fixtures. Owned queries, exact integer writes beyond 2^53, cache refresh/invalidation and graph keyword gestures pass. Focused gate 63052 exited 0; combined language gate 42787 also passed. | Complete: stated focused language gate; final Phase B review remains pending. |
| B.5 | `test_group_kernel` covers all four owners, 0/1 masks, names/pattern escapes, ordered-empty versus unordered groups, invalid order/membership and unsupported ordered edges, immutable ownership, cache and actual live-frame sources. Focused gate 85800 and live state-fold check 68513 passed; combined language gate 42787 passed. | Complete: stated focused language gate; no group-node port is claimed. |
| B.6 | `test_metadata_kernel` covers all attribute owners and eight storages, canonical P, rename/delete/copy/move/swap conflicts and atomicity, ordered group union, missing edge names, unused groups, strict compiled queries and graph gestures. Native/JavaScript host census passes 16,598 cases across 105 exports. Focused `@lib/flow_sop/runtest @tools/lisp/test/runtest` gate 13786 exited 0, including one/eight domains and grains 97/4096. | Complete: stated language gate; B.12 encoded parameter boundary and seven whole-node ports remain pending. |
| B.7 | Exact scalar math/rounding and matrix/quaternion helper fixtures pass. Explicit native-order FMA fixes cross/matrix cancellation: native compound audit is 0/1,863 above four ULP; 5,001 rows match exact native/reference/strict CPU/JavaScript bytes at one/four/eight domains. The prior 15 unfused discrepancies remain recorded and ordinary arithmetic stays unfused. | Complete: final focused compiler/Web/GPU/catalog/CLI/API/dependency gate 54530 exited 0; unsupported exact binary64 FMA retains typed GPU refusal. |
| B.9 | `test_reductions` checks exact wrapping Int sums, Float/tuple extrema including signed zeros, ordered CSR sums, zero rows and malformed offsets, and 32,769 rows at one/eight domains without input mutation. Computed scalar/array/record/function captures use compiled Core region arguments; unresolved web region arguments select structured Core compilation. Focused gates 27645 and 42787 passed. | Complete: stated focused language gate; no dependent whole-node port is claimed. |
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
