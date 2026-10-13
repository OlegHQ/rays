# Complete bounded Points port and recipe audit

Prepared outside the worktree after review of
`/tmp/rays-points-whole-design.md`, then applied and tested by root. The complete
semantic recipe and fixed12 aggregate/36 small-count performance rows pass.
The initial two small-count failures remain evidence. Production registration,
manifest, whole-port integration and final native/shipping gates now pass.
Points is accepted as the sixteenth whole port. The native factory
remains the independent oracle; no Point_generate callback appears in the body.

## Exact scope and route

The target is `sop/points`/key points, a static zero-input Generator, runtime
operation point_generate, version1, label Point Generate, category Create/Point.
Its source at `lib/sop/shapes.ml:1354–1397` has exactly four fields:points Int50,
soft/hard1..50; generated_group Text empty; source_point_attribute Text
sourcepoint; source_index_attribute Text sourceindex. No extra modes, choices,
folders, primary flags or inputs are added. `sop/point_generate` is a separate
input-dependent three-mode kind and is never substituted or delegated to.

The full shared RDK implementation and helpers are in
`lib/rdk/gen/point_generate.ml:1–412`; relevant total planning, generated maps,
metadata and optional group creation are lines42–45,128–139,251–273,366–397.
Manifest evidence is `lib/sop_catalog/flow_manifest.sexp:1073–1091`; existing
SOP cases are `lib/sop/test_nodes.ml:4527–4547` and RDK origin/provenance checks
are `lib/rdk/test_point_generate.ml:71–82`.

The body uses separate constant-positive-zero Float planes, empty vertex/kind
Int arrays and offsets[0] through mesh_planes; writes source−1 then exact
source-index0..count−1 Int attributes; and optionally writes an unordered full
point-group mask. The writer order preserves native attribute insertion order.
All positions are bit-exact +0; there is no floating arithmetic or FMA on this
native route. No list buffer, raw IEEE escape, gather, SOP-specific callback,
new language primitive or dummy numeric map is needed. Strict structured Core
constant/source constructors are the genuine route, with reference/native
comparison instead of an interpreter fallback claim.

The single pure header validator preserves native order/messages:count1..50;
metadata blank or exactly P; duplicate names. Literal calls retain the existing
checker E_HARD_RANGE boundary, while Node parameter edits retain native hard
clamping before validation. Metadata names are checked but never trimmed. Only
generated_group uses native Support.optional_text normalization:trim to empty
means no group; a nonempty result is the stored trimmed name. Literal wildcard,
UTF8, escaped/control names, names with outer spaces, p versus P, group P and
group names equal to metadata names are not arbitrarily refused.

## Actual focused recipe checks

After review/application, root runs the existing shared launcher:

```
opam exec -- _build/default/tools/check.exe @lib/flow_sop/points_draft
```

Requests87416 and24819 EXIT0, followed by83851 EXIT0 after the shared concrete
executor optimization. Logs are `/tmp/rays-line-fixtures-points-focused2-20261013.log`,
`/tmp/rays-declaration-cone-focused2-20261013.log` and
`/tmp/rays-concrete-executor-focused3-20261013.log`. The initial loader appended
an outer workspace instead of its library children and failed E_FORM; root
unwrapped it exactly as production embedding does, without altering the body.

This exercises all50 accepted counts across empty/blank/trim-named group and
default/custom metadata branches, plus exact-byte name cases. Every case has
native/reference/strict output and domains1/4/8 at grains1/97/4096. It checks
positive-zero words, isolated-point topology, two Int attributes in raw-name
insertion order, exact provenance values, optional unordered full group,
native padding via geometry_bytes, no other attrs/groups/edge groups and no
acquired input/live dependency. Runtime identity, complete descriptor, actual
card/inspector and all four direct Flow_edit gestures are compared to native.
Follow-up source review adds two distinct raw metadata names with equal trimmed
spelling, plus non-ASCII whitespace-only names/group; these remain valid native
bytes rather than a reason to broaden trim. It also covers all four fields'
wrong-type source/edit refusals and asserts the literal E_HARD_RANGE code.
Unknown authored keywords remain checked errors; an unknown Node parameter
edit is the native Param.apply_all no-op and is compared separately.
One additional integer drive yields−1/29/59 at the three existing frames;
native and authored lanes must normalize these to the same1/29/50 field values.
Source save/read, actual Add_node starter, zero-input bypass, bad input/type/
keyword, literal count/name refusals and failed-edit atomicity are covered.

Node edits independently compare hard count clamping and exact native name
validator strings; every physical valid edit must add one public miss and warm
hit. Static seed/time/grain/domain and display relabel remain hits. Ignored raw
blank-group spelling remains in the parameter key. The ignored blank-group
edit additionally proves one public miss, unchanged geometry, the exact native
raw key and a subsequent warm hit. Int/Text/state drives use
the ordinary value lane and compare fields, keys, cooked bytes and caller state
against the native lane. Cancellation checks are already-cancelled cold cooks
only; this does not demonstrate dynamic mid-cook cancellation.

The recipe checks alone did not imply acceptance. The completed production
pairing, whole-port function and final gates are recorded below.

## Fixed bounded-kind performance applicability

Parent explicitly approved the design's aggregate protocol for this bounded
zero-input kind while keeping the native hard maximum50. That approval is gate
applicability only, not a measured pass or a port count. A single1M geometry is
impossible under this schema and is never claimed or manufactured by merging.
The approved complete fixed tables are:

| Table | Count/cook | Group modes | Name modes | Domains | Cold Sessions/sample | Rows | Points/sample |
| --- | --- | --- | --- | --- | ---: | ---: | --- |
| aggregate_1M_total | 50 | empty, whitespace-only, trim-to-named | default, valid raw UTF8/space names | 1/4 | 20,000 | 12 | **1,000,000 aggregate**, never one geometry |
| micro | 1/7/50 | same3 | same2 | 1/4 | 1,000 | 36 | 1,000/7,000/50,000 aggregate |

After focused semantics pass, reserve quiet CPU separately and root runs:

```
opam exec -- _build/default/lib/flow_sop/test_points_port.exe --bench-points-aggregate
opam exec -- _build/default/lib/flow_sop/test_points_port.exe --bench-points-micro
```

All native/reference/strict per-cook byte and cross-domain preflights occur
before timing. Both paths use grain4096, median3 samples of fresh cold Sessions
with identical settings. Session creation/close and full-major GC are outside
the clock; Context creation and the whole cook are inside. Each log records
per-cook count, aggregate total, cold Sessions/sample, batch elapsed seconds,
normalized per-cook elapsed seconds, initial-domain allocations/promoted/major
words and full-precision ratio with its unrounded unchanged2x predicate. Both
complete tables continue after failures and fail terminally if any row does
not satisfy ratio≤2; nonfinite ratios cannot accidentally pass. The count50
micro and aggregate rows are distinct predetermined protocols, not a failed-row
retry. No unchanged-code timing repetitions or row removal are authorized.

Complete actual measurements and all96 before/after rows are recorded in
`concrete-executor-validation.md`. Before: aggregate97105 EXIT0 all12PASS;
micro16504 EXIT2, two named-group/count1/domain1 failures. After a measured-code
change in shared Executor.force: aggregate80848 and micro91572 EXIT0, all12/36
rows pass. Maximum final ratios1.8258339810115973 and1.9819395082323927. No
threshold, count bound, row set or fallback was changed to obtain these passes.

Initial-domain counters are not aggregate worker allocation or peak RSS. Root
recorded compiler/profile/CPU/OS/machine, quiet reservation, exact logs and
terminal handles in concrete-executor-validation.md. Both complete tables pass;
these measurements establish the existing2x gate without a zero-allocation claim.
SOP/browser geometry export remains outside the current2D target; the existing
intrinsics' host JS twins do not imply a browser Points geometry export.

## Production acceptance

The same unchanged body is embedded as nodes/points.rays, with its native
catalog registration removed atomically. The input-dependent point_generate
registration remains. test_points_port now uses Catalog.sources alone and runs
under the normal runtest alias. test_lisp_ports additionally compares21 actual
production combinations, full identity/descriptor and native/reference bytes
at domains1/4/8 and grains1/97/4096.

The actual editor Core_add test inserts the real menu row, checks its card and
default fields/key, then cooks that inserted node against the native oracle at
all nine domain/grain settings. Initial61037 and32153 menu checks selected
Compact Points: existing sorting prioritizes display-label word matches over
key matches. The final test uses the existing Node_menu.Private.keys sorter
over the actual native+Lisp catalog and ArrowDown to the Points row. It changes
no product ranking. Final78026 EXIT0 is recorded in
/tmp/rays-points-real-menu-focused3-20261013.log.

Reviewed/promoted manifest: unchanged four-field declaration moved to the Lisp
section with body lisp/calls and digest7abb74934b958e68123090042534b754. The CLI
snapshot changes only catalog digest to
8c2fb554841c77bc3a09e9450d3273539af443902882f845576ede60dbdc39c1;
authored-source digest, rendered goldens and public API are unchanged.

Final focused74602 EXIT0: /tmp/rays-points-production-focused-final-20261013.log,
compiler/FlowSOP/SOP/catalog/CLI/editor/API/dependency checks. Native20324 EXIT0:
/tmp/rays-points-production-native-20261013.log, @runtest-native, including23
graph one/four-domain rendered parity. Ship5577 EXIT0:
/tmp/rays-points-production-ship-20261013.log, @all/@runtest/@smoke/diffcheck;
43 standard files,1 custom-catalog executable and13 fixtures pass the complete
four-frame/one-eight-domain payload and command sweep. No measured body or
execution path changed between the final48 timing rows and this promotion.

Accepted ports16/128 (12.5%),112 remaining; milestones24/60 (40%). C.7 remains
unchecked with only Line and Points complete,2/11 generators.
