# Scoped declaration cache validation

Production Line integration exposed an unrelated-helper invalidation: the public
Lisp factory key hashed every checked declaration, so editing a deformation helper
also recooked the upstream Line. The existing exact miss/hit assertions caught it.

`Context_kernel.declaration_source` now reuses its checked-term traversal to collect
the node's own declaration and transitively reached child declarations, helpers,
graph references and macros. It visits input defaults, validators, normalizers,
function references and specialized call bodies. Macro templates are followed
transitively because recursive expansion erases inner macro names from typed terms.
The digest prints selected forms in deterministic checked order. Supplied function
slots retain the existing conservative whole-source key for their captures.

Actual one/eight-domain session checks keep the prior sibling/helper assertions:
an ordinary parameter edit misses two nodes and hits two; a used helper edit misses
both consumers and Merge while upstream Line stays warm. New checks cover unrelated
helper/macro hits, transitive function references, child body/default/validation
changes, normalizer helpers and nested macro changes. Every result matches a fresh
session's full geometry bytes and then hits its warm cache.

The scoped native source fixture explicitly supplies its native catalog and empty
library source, preserving its isolation from newly embedded generators. This also
recompiled the consumer after the private Context_kernel interface changed; the
initial inconsistent-interface linker failure remains in the first log.

Passing request24819 EXIT0, `/tmp/rays-declaration-cone-focused2-20261013.log`:

```sh
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy opam exec -- _build/default/tools/check.exe @check @lib/flow_sop/runtest @lib/flow_sop/points_draft @lib/flow/runtest @lib/flow_graph/runtest @lib/flow_ir/runtest @test/dependency_gate @tools/api_manifest/runtest
```

Request98103 EXIT1 retains the initial linker failure; its actual cache regressions
already passed. No cache assertion, tolerance or speed gate was weakened. The API
gate passes without a stable snapshot change: Context_kernel is a private module.
This shared correction accepts no additional whole port or plan milestone.
