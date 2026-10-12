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
| C.15 | Full native Measure wrapper and kernel audit establishes topology/indexed position access and canonical n-gon triangulation with original-primitive mapping as prerequisites. The whole node moves from B.15 to C.15; no mode, registration or target is removed. | B.1/B.5/B.7/B.9/C.1/C.2 and a generic canonical triangulation + primitive mapping capability, then the complete port Verification gate. No implementation or completion claimed. |
| G.1–G.2 | Optional tasks; no placement evidence recorded here yet. | Measured placement and CPU/GPU tolerance checks. |

The typed integer/text/source Core API snapshot was accepted separately in
commit `621113d2` after API/dependency gate 37921 exited 0. Foundation
implementation has passed the final focused compiler, shipping, native and web
gates. B.1/B.2/B.3/B.8 are complete; B.7 and all remaining ports stay unchecked.

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

B.7's partial math gate 71202 passes the compiler's exact unfused oracle.
The independent native 4-ULP audit still fails 15 of 1,863 cases: fourteen
cross-product cancellations near zero and one matrix product at 16 ULP.
B.7 remains unchecked until that native parity gate passes.

An isolated JavaScript BigInt FMA prototype matches native `Float.fma` bits
for 10,011 cases. Explicit FMA therefore has a viable web implementation;
this does not authorize automatic Mul/Add contraction or change the current
unfused arithmetic policy. B.7's native four-ULP gate remains unresolved.

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

One of the 128 target nodes has completed its full Verification gate: the
complete `noise_displace` pilot. The remaining 127 ports are still required.
Do not fill timings, run counts, render parity or domain equality from estimates.
Each accepted row must cite the command and fixture, machine/domain setup,
OCaml/Lisp times and validation result before its plan checkbox is marked.

| Node | CPU oracle gate | 1/8 domains | Cache/refusals/UI | Native goldens | OCaml/Lisp time at 1,000,000 | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `noise_displace` pilot | Final pilot and legacy node gate 45407 passed at 4 ULP | 48781 passed, byte-exact strict reference | Schema/cache/refusals and real source/save/editor gates passed; label regression 45407 passed | Final 33890 passed; render fixtures unchanged; ml.t catalog digest expectation refreshed | Both modes 1/4 domains below 2×; table below | Complete in this port commit; A.6 and A.R passed |

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
