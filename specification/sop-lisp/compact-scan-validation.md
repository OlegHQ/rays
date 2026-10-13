# Compaction and exclusive integer offsets integration

Status: native/reference/strict Core, derived-count origins, live sources,
immutable storage, state rollback, domains, geometry compositions and actual
JavaScript runtime/workers pass in focused integration. The latest run is
`/tmp/rays-region-binding-focused9.log` (EXIT0), including recursive argument
storage, ordinary Float Product forcing and actual worker error locations.
Core variants were accepted in `77be0b5c`. The corrected snapshot's final
shipping check is running in `/tmp/rays-bulk-array-native-ship2.log`.
No C.4 tick or whole SOP port is counted until that check finishes.

## Contract and existing path

`(array/compact mask)` takes an IntArray whose entries are exactly zero or one.
It validates entries in source order, counts the ones, then allocates the exact
fresh output and fills it with increasing original indices. Empty or all-zero
masks produce an empty IntArray. Any other entry fails `E_ARRAY_MASK`; non-Int
storage fails `E_ARRAY_TYPE`. Borrowed inputs are never changed.

`(array/scan_sum array)` takes an IntArray and returns exclusive offset
boundaries: `[3, 0, 2]` gives `[0, 3, 3, 5]`; the output includes both the initial
zero and terminal total. Empty input gives `[0]`. The result has n+1 entries,
not n. Before computing n+1 or allocating, n must be strictly below native Int
array capacity. Real small and multi-block arrays are tested; no gigantic array
is fabricated and no oversized-allocation experiment is claimed.

This convention comes from actual native consumers: `core/topology.ml` requires
initial zero and terminal vertex count; `curve/poly_path.ml` lines 239–246 build
point incidence offsets of length point_count+1; `curve/circle_from_edges.ml`
lines 257–261 build component boundaries from counts. Compaction matches
`mesh/compact_points.ml`'s ordered new-to-old retained-point indices. Counts and
indices can then drive ordinary gather maps and `sop/mesh` without a second scan
mode or a missing terminal-boundary append.

Scan is ordinary signed63 `int/add` arithmetic: negatives are allowed and
prefixes wrap at signed63 boundaries. Native/JS must retain values above 2^53
exactly; JS uses the existing BigInt `wrap`. Geometry/count consumers separately
validate nonnegative ordered offsets and cardinality. This primitive is not an
unchecked allocation planner and does not replace those trust boundaries.

Both are canonical Ops, two structured Core primitive tags, and JS exports.
Core_exec reuses its cached generic canonical body dispatch. There is no new
Op.Private helper, Region instruction, packed bank, Value/Ty shape, dependency,
SOP algorithm callback or interpreter retry. Strict input maps and downstream
maps/gathers use existing packed numeric execution; dynamic compact/scan inside
a per-row kernel is refused. Integer kernels remain CPU-only under central GPU
qualification and WGSL. Concrete CPU results can feed independently qualified
kernels. The current 2D exporter still refuses host-owned Source captures.

Output cardinality cannot inherit an input owner/count origin: compact's
cardinality is mask-dependent and scan is n+1. The tests assign an origin only
to the real dynamic host input, then assert derived map origins are absent and
mixed-input dynamic maps cannot collapse the materialization/fusion boundary.
Changed input buffers and lengths must be observed on every force.

The ponytail comment records the shared bulk-loop ceiling: Flow/Core has no
cancellation checkpoint inside these intrinsics. Existing host checks before
and after forcing remain. There is no mid-loop cancellation or native
cancellation/error race parity claim.

## Passed focused checks

- Native independent ordered oracles for compact and scan, exact min/max and
  >2^53 wrapping prefixes, all-zero/all-one/mixed masks, empty, 1, 13 and 32769
  inputs, fresh storage and source immutability at 1/4/8 domains.
- Strict Core/Executor versus reference for live maps, typed helper, downstream
  maps, compact→gather remapping, empty results and lazy invalid masks; refusal
  of unsupported child kernels and per-row dynamic compact/scan.
- Actual Source forcing/type/code/message/cause, changing buffers/lengths,
  untaken Source arms and supplied-state rollback. Count-origin and fused/unfused
  parity for direct, scan, compact and two-input maps.
- Real authored compact→gather→mesh and scan→mesh offsets, compared with native
  geometry bytes under strict/reference and domains 1/4/8, grains 1/97/4096.
- Actual emitted Js.frame with production createRuntime and null/1/8 worker
  pools, packed source maps, gathered remapping and downstream scans, byte
  comparisons and unchanged transported input buffers. Direct primitive
  fixtures cover malformed storage/masks plus Int boundary cases.
- Op cards have an IntArray socket/result; source-backed Pos0 edits, rejected
  malformed types and print/recheck preserve that contract. Actual editor menu
  Add-node uses its existing IntArray empty default, so no bespoke template is
  needed. Core fixture inventory 91→93 retains all prior cases.

The focused command passed after separate acceptance of the Core enum additions:

```
opam exec -- _build/default/tools/check.exe @check @lib/flow/runtest @lib/flow_ir/runtest @lib/flow_sop/runtest @lib/flow_graph/runtest @lib/flow_web/runtest @lib/flow_gpu/runtest @tools/lisp/runtest @test/dependency_gate @test/test_workspace_shell @tools/api_manifest/runtest
```

Production 2D export retains fixed-input admission. The emitted-frame proof
uses genuine computed Invoke arguments and compiled source preparers, without
reference-fed inputs or counts. It does not add native geometry export.
