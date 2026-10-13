# Complete Line port and recipe audit

Line is accepted as a complete C.7 port after its semantic, performance,
production-menu, native and shipping gates. `Sop.Nodes.Line.factory` remains
the oracle; its catalog registration is removed alongside the production Lisp
source. The recipe uses
only the ordinary checked Lisp body and typed `sop/mesh_planes`; no Line callback or
generic host operation invokes `Line_geometry.line`.

## Complete native surface

Read `lib/sop/shapes.ml:123`, the PPX factory contract, the `line` manifest row,
`lib/rdk/gen/line_geometry.ml:15`, `Support.structured_rdk_error`, Param's
`normalize_value`, and existing native source/cook tests. The two modes are
`Polygon curve` and `Points`. Curve produces one open polyline with vertices
`0..points-1`, offsets `[0; points]`, kind byte 1. Points has no vertices or
primitives and has offsets `[0]`. Neither mode creates attributes, groups,
normals, instance payloads, or source ownership dependencies.

All nine physical schema fields are retained: kind, points, origin X/Y/Z,
direction X/Y/Z, length; origin/direction use the native grouped vec3 metadata.
Hard minimums clamp points below 1 to 1 and length below zero to zero. Soft
limits are inspector presentation only. Every float parameter rejects NaN and
both infinities before rebuilding. Curve with one point is accepted by the
schema and fails at cook. Zero direction likewise fails at cook. Points with
one point still computes and validates the otherwise unused endpoint.

The native error order is grain validity (owned by Context for SOP cooking),
mode minimum, finite inputs/nonnegative length, zero direction, finite endpoint,
then cancellable point generation. SOP errors preserve code
`invalid_parameter`, message `line could not produce valid geometry`, and cause
`line [invalid_parameter]: Rdk.Line_geometry.line: ...`. The draft supplies the
three reachable body error causes explicitly. Shared parameter normalization
and cancellation boundaries supply the other errors.

## Native arithmetic and exceptional values

Static `otool -tvV` inspection of the current Apple-Silicon native object
`_build/default/lib/rdk/gen/.rdk_gen.objs/native/rdk_gen__Line_geometry.o`
confirmed the actual sequence, rather than inferring it from OCaml source:

1. Scale is max absolute direction component. Divide each component by scale.
2. Rounded `sx*sx`, `fma(sy,sy,xx)`, `fma(sz,sz,previous)`, sqrt.
3. Divide each scaled component by magnitude, then multiply by length.
4. Endpoint coordinates use separately executed `fadd`.
5. Interior coordinates use `fmadd(displacement,t,origin)`.
6. Overwrite the first point with exact origin; overwrite the last with exact
   endpoint when there is more than one point.

The draft spells out both native magnitude FMAs and each interior FMA. Checked
FMA with multiplier 1 implements checked endpoint addition: multiplication by
one is exact for every finite binary64 value, so the final rounding and zero
sign match addition while overflow remains a Bool flag and finite placeholder.
That lets authored Lisp report the native endpoint cause without exposing a
nonfinite Value. Direction normalization uses scaling instead of `normalize`,
which would overflow squared norms and reject accepted native inputs.

For schema-accepted finite inputs, at least one scaled component has absolute
value 1, all have absolute value at most 1, and the magnitude is finite and
nonzero. Each displacement magnitude is bounded by finite length. A finite
endpoint and interpolation fraction in [0,1] bound interior fused results
between finite endpoints. Thus no accepted exceptional native plane requires
publishing NaN/Inf. The oracle retains subnormal, huge finite, signed-zero,
negative-zero length, mixed-exponent, endpoint cancellation, near-max origin,
and one-point unused-endpoint cases; this reasoning is not a runtime pass.

The original Vec3 draft had an explicit representation mismatch: for
`M = Sys.max_floatarray_length`, `n = M / 3 + 1` fits each native x/y/z
plane while `3 * n` cannot fit a Flow interleaved Vec3 array. The adapted
recipe collects three scalar Float arrays and passes them through the separate
fully typed `sop/mesh_planes` constructor. Both reference and strict CPU paths
therefore retain the scalar per-plane bound without introducing a Line-specific
limit, new Value/Core representation, or a native Line callback. The original
`sop/mesh` Vec3 signature and shared language Any/error rules remain unchanged.

Mesh Planes validates the exact x/y/z record, equal plane counts and finite
coordinates, then native kinds/topology in the existing order; it copies each
plane into owned native geometry. Its tests demonstrate scalar capacity without
attempting an impossible whole-machine allocation at the abstract maximum.
Actual allocation failures and whole-node speed remain explicit runtime gates,
not claims inferred from the capacity calculation. All eight original fixed
million-point performance rows are retained for the scalar-plane recipe.

## Prepared acceptance checks

`test_line_port.ml` checks both modes at 1/4/8 domains and grains 1/97/4096.
Native parity is deliberately byte-exact, stronger than the recipe's default
four-ULP allowance. Cases include defaults, each field's nondefault edit,
one/two/six/4225/32769/100001 points, scaled direction extremes, exact endpoint
overwrites, and complete topology. An empty geometry is not an input to this
zero-input generator; wrong positional geometry is refused rather than ignored.

Errors compare native code, message and cause across strict/reference execution
and all domain/grain combinations. Schema checks cover all field views,
factory descriptor, runtime label/operation/version, normalized keys, nonfinite
and invalid-choice atomic rollback, changed-parameter single public cache miss,
unchanged warm hit, context independence and display-only relabel. Source/card
checks cover source preservation and print/read round trip, every physical
Flow_edit gesture including vector components, native card/inspector metadata,
Add_node starter, the native zero-input bypass refusal, and malformed source
rollback. Authored live length and retained-state length exercise ordinary
value-lane rebuilding. The retained-state test compares the real native value
lane and checks accumulated frame dt, caller-state isolation during cooking,
and unchanged state on repeat resolution of the same frame.

The fixed performance table has eight rows: curve/points with default direction
and oblique nondefault origin/direction/length, each at 1 and 4 domains,
1,000,000 points, grain 4096. Three cold-session samples produce a median.
Preflight compares full native bytes, strict/reference bytes and domain bytes.
All rows print before a failing speed gate exits. Construction is outside the
cold cook timer, consistently with existing whole-node harnesses. Allocation
counters are initial-domain only at four domains. Promoted and major words are
also reported for the sample selected by wall-time median.

## Actual semantic and speed evidence

The focused semantic gate passed in `/tmp/rays-line-port-focused6.log`, and the
broader RDK/Flow SOP run passed in `/tmp/rays-topology-validation-focused1.log`:

```sh
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy opam exec -- _build/default/tools/check.exe @check @lib/flow_sop/line_draft
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy opam exec -- _build/default/tools/check.exe tools/bench_topology.exe @lib/flow_sop/line_draft @lib/flow_sop/runtest @lib/rdk/runtest
```

Two real draft-test errors were corrected: `t` is reserved context time and
cannot be an interpolation binding; a zero-input generator cannot bypass.
The state fixture originally expected dt alone instead of accumulated dt.
The native value-lane comparison confirms accumulation rather than weakening
the retained-state requirement.

On Apple M1 arm64, OCaml 5.3.0, Dune dev, 1,000,000 points, grain 4096,
three cold-session samples, all agents paused during timing:

| Mode | Domains | Original ratio | After shared topology scan | Native seconds after | Lisp seconds after |
| --- | ---: | ---: | ---: | ---: | ---: |
| Curve default direction | 1 | 1.108195381 | 0.862576983 | 0.005923033 | 0.005109072 |
| Curve default direction | 4 | **2.750253293 FAIL** | **2.284607746 FAIL** | 0.002400875 | 0.005485058 |
| Points default direction | 1 | 0.526475249 | 0.557164883 | 0.005102873 | 0.002843142 |
| Points default direction | 4 | 1.496219758 | 1.372334424 | 0.002113104 | 0.002899885 |
| Curve oblique | 1 | 1.051403475 | 0.841294592 | 0.006268978 | 0.005274057 |
| Curve oblique | 4 | **2.744239401 FAIL** | **2.126230508 FAIL** | 0.002736807 | 0.005819082 |
| Points oblique | 1 | 0.536208758 | 0.533747864 | 0.005023003 | 0.002681017 |
| Points oblique | 4 | 1.453358209 | 1.334101914 | 0.002068043 | 0.002758980 |

Logs: `/tmp/rays-line-port-benchmark1.log` and
`/tmp/rays-line-port-benchmark2.log`, both exit 2 after printing all eight rows.
The second table allocates about 32 MB for curves and 24 MB for Points on the
initial domain in both implementations; promoted words are zero, major words
are respectively 4,000,004 and 3,000,003. Desktop/VM background processes were
left running. The strict 2x gate still fails; no whole-port or C.7 tick follows.
The shared scan is measured independently by `tools/bench_topology.exe`.

Shared large-topology validation was subsequently split into65536-vertex blocks
using the existing pool, with sequential single-block scans and the original
first-vertex early refusal. Native/reference/domain/grain/card/cache/value-lane
checks still passed (`/tmp/rays-topology-validation-focused4.log`, EXIT0).
The unchanged eight-row cold-cook table was rerun after the parallel scan:

| Mode | Domains | Native seconds | Lisp seconds | Ratio / gate |
| --- | ---: | ---: | ---: | ---: |
| Curve default direction | 1 | 0.005836010 | 0.005178928 | 0.887409102 PASS |
| Curve default direction | 4 | 0.002362013 | 0.004740953 | **2.007166650 FAIL** |
| Points default direction | 1 | 0.005215883 | 0.002696037 | 0.516889884 PASS |
| Points default direction | 4 | 0.001904964 | 0.002830029 | 1.485607009 PASS |
| Curve oblique | 1 | 0.005976915 | 0.005200148 | 0.870038693 PASS |
| Curve oblique | 4 | 0.002397060 | 0.004698992 | 1.960314303 PASS |
| Points oblique | 1 | 0.005017996 | 0.002752066 | 0.548439207 PASS |
| Points oblique | 4 | 0.001912117 | 0.002744913 | 1.435536160 PASS |

Session35225 EXIT2, `/tmp/rays-line-topology-after-cwd-20261013.log`; all rows
were retained. An initial launch from the repository root failed before any
measurement because this harness reads its draft relative to the build
directory (`/tmp/rays-line-topology-after-20261013.log`). The table above used
the correct working directory and the unchanged1M/grain4096/median3/native
byte-exact preflight protocol. Main-domain allocations still match final
planes/indices (32MB curves,24MB Points); this is not total worker allocation.
The later first-vertex error-path correction was measured only in the native
constructor benchmark, without rerunning Line to seek a passing near-threshold
row. The full Line gate remains failed and no port is counted.

## Original draft integration checklist

At the original draft stage, remaining acceptance work was:

```sh
opam exec -- _build/default/tools/check.exe @check @lib/flow_sop/line_draft @lib/flow_sop/runtest @lib/sop/runtest @test/dependency_gate
cd _build/default/lib/flow_sop
opam exec -- ./test_line_port.exe --bench-line
```

Timing must use a quiet window. The applied code consists of `nodes/line.pending`,
one dedicated test, its draft alias, and this audit. No catalog mutation, registration removal,
manifest promotion, source save baseline, API change, or completion tick is
included. Root must first resolve actual compile/semantic/performance failures,
review the separate typed plane constructor and actual eight-row cost, and then perform the atomic production
rename/native-unregister and production catalog/source/menu/native shipping
gates. C.7 contains additional generators and cannot be ticked for Line alone.

## Final production recipe and integration evidence

After shared mesh-plane validation gained about30% at four domains, the unchanged
full eight-row table passed in request94760 EXIT0,
`/tmp/rays-line-mesh-plane-after-20261013.log`. All previous failures remain
above; the later rerun followed a measured implementation change.

Production review found an uncovered native allocation refusal. Native Line
validates direction and endpoint before Array.make; counts above native array
capacity raise Invalid_argument("Array.make"), wrapped by Session as
uncaught_node_exception / "a procedural node raised an exception while cooking".
The authored body now guards the Float capacity after endpoint validation and
before collectors, preserving that exact cause. Safe over-capacity/max_int,
zero-direction/endpoint precedence and pre-cancelled cases compare native and
strict/reference code/message/cause at domains1/4/8 and grains1/97/4096 without
allocating giant buffers. Request69170 EXIT0:
`/tmp/rays-line-capacity-focused-20261013.log`.

The candidate was renamed to nodes/line.rays and native catalog registration
removed together in the worktree. The dedicated recipe loads actual embedded
sources and runs under normal runtest/line_port. test_lisp_ports has its own
production zero-input Line oracle function. Scoped catalog fixtures explicitly
retain their native oracle rather than duplicate embedded declarations; the raw
checker boundary supplies its explicit native source factory. The shared
unrelated-helper cache issue was fixed separately with transitive declaration
keys and actual miss/hit regressions; no counter assertion was relaxed.

The promoted manifest moves only Line's declaration, retains all nine fields,
slots/outputs/operation/label/category, replaces native facts with body lisp and
empty calls, and updates its digest. tools/lisp/test/ml.t changes only catalog
digest; authored source digest/delimiter remain unchanged. No public API changed.

Final production timing request64751 EXIT0,
`/tmp/rays-line-production-final-benchmark-20261013.log`, after the shared
concrete Executor optimization and the capacity/production changes:

| Mode | Domains | Native seconds | Lisp seconds | Ratio / gate |
| --- | ---: | ---: | ---: | ---: |
| curve_default_direction | 1 | 0.005894899 | 0.005195141 | 0.881294237 PASS |
| curve_default_direction | 4 | 0.002596140 | 0.004115105 | 1.585085866 PASS |
| points_default_direction | 1 | 0.005117178 | 0.002747059 | 0.536830825 PASS |
| points_default_direction | 4 | 0.001899958 | 0.002122164 | 1.116953194 PASS |
| curve_oblique | 1 | 0.005975008 | 0.005739927 | 0.960655999 PASS |
| curve_oblique | 4 | 0.002691031 | 0.004607916 | 1.712323912 PASS |
| points_oblique | 1 | 0.005207062 | 0.002810001 | 0.539652015 PASS |
| points_oblique | 4 | 0.001848936 | 0.002315998 | 1.252611219 PASS |

All rows have the original1M-point/grain4096/median3 fresh-cold-session protocol
and byte-exact native/reference/domain preflights. Apple M1 Macmini9,1,16GiB,
arm64,macOS27.0.1 build26A434,OCaml5.3.0,Dune dev; all three agents paused and
acknowledged before measurement. Desktop/VM processes remained running. Main
allocation is about32MB curves/24MB Points; promoted words0 and major words
4,000,004/3,000,003. Initial-domain counters exclude worker allocation.

Focused production/compiler/CLI/catalog/API/dependency request83851 EXIT0:
`/tmp/rays-concrete-executor-focused3-20261013.log`. Native integration83712
EXIT0, `/tmp/rays-line-production-native-20261013.log`, covers @runtest-native;
no render golden changed. Shipping request99108 EXIT0,
`/tmp/rays-line-production-ship-20261013.log`, passes @all, @runtest, @smoke and
git diff --check, including the43 standard workspaces,1 custom-catalog executable
and13 fixtures at four times/domains1/8 with equal cooked payloads/render commands.

Source review found that existing PXUI menu-search tests cover native factories
only. The additional actual Core_add Line case presses /a, enters line and
confirms the produced source/card/embedded descriptor/default fields/key. It
compiles the real inserted node from the editor document and compares its full
default position/topology bytes and empty metadata/instances to native at1/4/8
domains, grains1/97/4096. Request11675 EXIT0,
`/tmp/rays-line-real-menu-focused-20261013.log`, covers that real shell gesture,
line_port, @check, catalog, API and dependency gates after the shipping sweep.

Accepted whole ports are15/128 (11.7%),113 remaining; milestones remain24/60.
Line is one of C.7's11 generators, so C.7 stays unchecked. The paired port
commit contains only Line's body/registration/oracle/menu/integration changes
and its two textual catalog/CLI snapshots; no other node or render golden is
refreshed or counted.
