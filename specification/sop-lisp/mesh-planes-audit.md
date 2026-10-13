# Typed Mesh coordinate planes

Applied after C.1 construction/query and diagnostic work. Focused request83367
EXIT0, `/tmp/rays-mesh-planes-focused6.log`, passes @check, Flow SOP/graph/web,
CLI/Core/JavaScript fixtures, actual workspace-shell insertion, API and dependency
gates. This prerequisite adds no whole SOP port or milestone. No benchmark or
registration removal is claimed. The original Mesh declaration remains unchanged.

## Minimal language boundary

The transparent x/y/z record is accepted by the additional fully typed generic
`sop/mesh_planes` intrinsic. Its four required keyword rows are `points` (exact
x/y/z Float-array record), `vertex_points`, `primitive_offsets` and `kinds` (Int
arrays). No new syntax or Value, Ty, Core, Packed instruction, dependency or
public interface is introduced. The normal typed signature produces actual
record socket types and default record fields. A narrow `out_args` check rejects
known extra fields that ordinary structural record fitting otherwise permits.
Runtime validation enforces exact fields and equal counts before native topology
construction. Existing error/bottom handling remains ordinary typed operation
handling; no new guaranteed-error analyzer or shared checker relaxation exists.

Before choosing this form, traced every current `out_args` and Any-signature
combination: array/range's literal output selector; attr/attr_checked/has_attr's
storage selector; polymorphic with_attr values/default; with_group order;
Mesh's required keyword validation; and the shared error producer. Using Any for
Mesh points would require distinguishing guaranteed errors from unknown Any
inputs, beyond the storage change. The separate intrinsic avoids that change
and preserves all existing helper and polymorphic producer behavior.

## Ownership and actual callers

Topology_kernel's shared Mesh implementation validates either existing AoS Vec3
storage or exact record planes, then kind codes and native create_owned topology.
It copies the evaluator's topology and coordinate arrays, never adopting reusable
Flow input buffers. Plane lengths retain the ordinary per-Float-array native
bound. Native plane construction never allocates a combined 3*n float buffer.
The old Vec3 constructor keeps its original layout, error and capacity contract.

All eight existing Lower Mesh recognition sites now share one local predicate:
source dependency discovery, retained argument preparation, node dispatch,
zone/template instantiation, live drive tracking, frame dependence and retained
state snapshot reconstruction. The same mesh_data record, strict preparation,
Frame input, source resolver, cancellation, facts and owned constructor code is
used. Attribute_kernel visitors already recurse through records and collect
precise P reads/source handles; no new owner or artificial count origin exists.
Three coordinate maps from one P source share its point-owner count. Geometry
construction only supplies positions and topology, as for C.1; attributes,
groups and instances are neither arguments nor promised preserved outputs.

The JavaScript host twin reuses the same topology validator and validates exact
Float planes, equal counts and finite point data before kind/topology errors.
Its existing geometry fixture transport is AoS: it allocates that host format
only after validation. This does not claim huge-browser capacity, SOP export, or
a native fallback. Current 2D compiler export still refuses geometry host calls.

## Runnable acceptance

Extended test_geometry_arrays covers all five native plain geometries and a
32769-point multi-block source reconstruction, strict/reference execution, domains
1/4/8, grains 1/97/4096, exact signed-zero/subnormal bytes, reusable input mutation,
warm cache, malformed counts/kinds/topology, finite input boundary errors, lazy
untaken branches, selected error/cause order, helper and typed Fn captures,
cancellation, supplied state rollback, frame/state changes and zone elements.
It checks concrete card/socket types, nested and whole keyword edits, connection,
valid menu starter, missing/extra/mis-typed edit refusal with prior source intact,
source print/save/read, precise read facts, geometry handles and point count
origins. Scalar capacity is proven through the existing count guard, without
allocating a machine-sized maximum array or adding a native count limit.

Production editor menu tests exercise the actual Add menu for both forms. Native
host fixtures execute the real lowered constructor for all five shapes and every
native topology error, exact large integer invalid reference, count mismatch and
NaN/+inf/-inf in each coordinate plane. JavaScript fixtures compare actual host
results; direct malformed-map/type/count and mutation checks complement them.
The Core host census adds mesh_planes without changing primitive inventory.

Passing focused command:

```sh
opam exec -- _build/default/tools/check.exe @check @lib/flow_sop/runtest @lib/flow_graph/runtest @lib/flow_web/runtest @tools/lisp/test/runtest @test/test_workspace_shell @tools/api_manifest/runtest @test/dependency_gate
```

The separate adapted Line draft retains its complete nine-field native schema,
all modes, exact explicit FMA order, cook errors, reference/domain/grain/editor/
cache checks and eight fixed million-point timing rows. Both representation and
whole-node speed must pass before registration removal; no timing claim exists.

## Static review history

Root's first static review found an invalid Record arm inside a tuple-option
match, and an unintended reversal of C.1's smallest-subnormal fixture from
Float.next_after to Float.min_float. The original uncompiled failed artifact is
retained at `/tmp/rays-mesh-planes-complete.failed-v1.patch`. The corrected draft
uses a tuple wildcard inside and distinct Record/other-storage arms outside;
it preserves the current C.1 fixture prefix verbatim. This is static correction,
not a typecheck or feature-pass claim.

`/tmp/rays-mesh-planes-complete.patch` targets current C.1. The composition
`/tmp/rays-mesh-planes-after-diagnostics.patch` targets current C.1 followed by
`/tmp/rays-diagnostics-rebased-combined.patch`. Both were statically checked for
applicability; the latter preserves Diagnostic_bridge and the Workspace/Core
With_error variants. No diagnostic source or public interface is replaced.

Actual integration requests22642/4780/55939/76466/76922 EXIT1 are retained in
`/tmp/rays-mesh-planes-focused1.log` through `focused5.log`. They caught draft
fixtures using a string child index instead of numeric map-value index1,
multiline printer-sensitive substring matching, missing required census
arguments, record-only `get` on a vector, graph-local name shadowing and fresh
snapshot identities in a supposedly shared-origin test. Those fixtures now
use ordinary checked gestures, valid typed sockets, vector components and one
shared immutable source. Their intended ownership/count/error assertions remain;
no production checker or numeric comparison was relaxed.
