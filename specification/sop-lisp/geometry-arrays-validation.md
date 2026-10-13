# C.1 geometry arrays — focused and shipping gates passed

2026-10-13, Apple M1, OCaml 5.3 development profile. The implementation is in
`flow_sop`, the ordinary graph/editor paths and the JavaScript geometry host
protocol. C.1 adds no whole SOP port: 14/128 remain accepted. Its focused gate
advances the milestone count from 20/60 to 21/60.

## Construction and ownership

`sop/topology` returns owned exact Int copies of vertex points, primitive
offsets and kind codes (0 polygon, 1 open polyline, 2 closed polyline).
`sop/mesh` requires four keyword arrays: Vec3 points and Int vertex points,
primitive offsets and kinds. The implementation calls existing native
`Topology.create_owned` and `Geometry.create`. Native integer planes are copied;
coordinates are split into owned planes. No attributes, groups or instances
are implied by these four inputs.

Point layout/finiteness is checked before kinds and native topology validation.
Invalid kinds report `E_TOPOLOGY_KIND`; native validator messages are preserved
under `E_TOPOLOGY`. Selected errors retain code, message and cause. Untaken
branches remain lazy. Retained live/state/zone arrays use the existing execution
boundary and forked host-state snapshots, with no interpreter retry after a
strict compiled failure.

The five fixtures contain plain topology and finite P. Ordinary Flow arrays
retain their finite-value contract; C.1 does not establish a raw NaN/Inf position
transport or solve the separate AoS/SoA maximum-count difference. Payload
preservation needs explicit payload construction or C.3 remapping.

## Actual focused evidence

The final shared-launcher request was:

```sh
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy OCAMLRUNPARAM=b \
  opam exec -- _build/default/tools/check.exe \
  @lib/flow_sop/runtest @lib/flow_graph/runtest @lib/flow_ir/runtest \
  @lib/flow_web/runtest @tools/lisp/test/runtest @test/dependency_gate \
  @tools/api_manifest/runtest @test/test_workspace_shell
```

Process 57033 completed with EXIT 0; log `/tmp/rays-c1-focused11.log`.

The final native-video shipping request 54530 completed with EXIT 0:

```sh
OCAMLRUNPARAM=b opam exec -- _build/default/tools/check.exe --ship
```

Log `/tmp/rays-c1-native-ship.log` includes all 14 accepted whole-node tests,
the strengthened cache tests and the complete workspace IR sweep: 43 standard
files, one custom-catalog executable and 13 fixtures, with cooked payload
comparisons at domains 1/8. The launcher also completes `@all`, `@runtest`,
native smoke and `git diff --check`. Earlier request 91290 used dummy video,
failed native smoke startup and exposed the Lisp source-key cache regression;
the shared fix and fresh-oracle cache assertions pass in request 50009 and this
final shipping run. Those failures remain recorded in `results.md`.

- Five native fixtures: empty, shared polygons with a free point, repeated open
  polyline, closed polyline and mixed nonmanifold kinds. Full geometry bytes
  match both direct-array and authored topology/P reconstruction, reference
  and compiled execution, domains 1/4/8 and grains 1/97/4096.
- A 32,769-point authored packed identity map preserves signed zero and
  actual subnormal bytes across the same domains/grains. The strengthened
  `Float.next_after 0. 1.` fixture passes in request 25298 (its unrelated live
  cache assertion failed separately). Helpers, captured topology
  records and typed function arguments also reconstruct exactly.
- Caller mutation of input arrays and query-result mutation cannot alter the
  constructed/native geometry. Topology queries have distinct vertex,
  primitive and primitive-plus-one count origins through direct Get and
  captured record fields.
- Topology-only captures ignore changed coordinates and changed values in an
  existing unread attribute, carry fresh unread components on cache hits and
  invalidate on topology changes. Attribute-layout changes retain the ordinary
  write-cache miss required for output structure.
- Native validator order/messages, exact integers above 2^53, invalid kinds,
  missing/wrong geometry, cancellation, lazy errors and selected causes pass.
  Live/state inputs, zone element captures and failed-cook state rollback pass.
- Cards expose all mesh keywords and three topology outputs. Checked Set_arg,
  Connect, malformed-edit atomic refusal and typed Int defaults pass. The real
  editor menu inserts a valid empty mesh; its source cooks to native empty bytes.
- Native host fixtures and actual JavaScript functions agree for all five
  topologies and malformed point/topology cases. JavaScript ownership and
  signed-zero checks pass. Core primitive inventory is unchanged.
- The JS frame printer refuses an explicit host source with `E_WEB_SOURCE`.
  The production CLI refuses a draw graph reaching a SOP graph containing both
  operators with `E_WEB_GRAPH`, before writing output. A packed frame printer
  alone is not the production source-binding/export gate.

## Failures resolved before acceptance

Requests 11098, 99145 and 50114 found a fixture parenthesis, the existing private
reads function missing from its public interface, an ambiguous doc comment,
expected API-manifest drift, graph array inputs without defaults and an older
all-operator fixture without the four required mesh keywords. Each was fixed;
the single-function reads API addition was reviewed/promoted and committed
separately as `ed8eb646`.

Requests 58392, 67557 and 69439 found test-only issues: explicit named graphs
were treated as a default graph, the count-origin fixture used a nested Let
instead of a captured record, and a diagnostic used a non-variadic fail helper.
Requests 60569 and 92217 identified the packed-source/frame-printer distinction
above. Request 30324 exposed a nonexistent `array/length` spelling; it now uses
`array/count`. Request 61584 exposed the intended attribute-layout cache miss;
the test now separately checks unread value changes and layout changes.
No native oracle, numerical tolerance or performance gate was relaxed.

The C.1 dependency moves from B.R to completed B.1/B.2/B.4 foundations: Peak and
Match Size need C.1, so the old dependency formed B.10 → C.1 → B.R → B.10.
Indexed consuming recipes additionally require C.2. No construction timing or
whole-node 2× qualification is claimed by this language-capability gate.
