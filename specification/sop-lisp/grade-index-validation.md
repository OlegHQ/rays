# C.5 grade/index integration

Status: native stable ordering, exact Int/Text, first-match lookup, ownership,
lazy errors, strict/reference state rollback, domains and actual JavaScript
runtime/workers pass. The all-byte fixture uses a checked list and typed map
within the existing 2,048 AST budget. The latest focused integration run is
`/tmp/rays-region-binding-focused9.log` (EXIT0), including recursive argument
storage, ordinary Float Product forcing and actual worker error locations.
Core variants were accepted in `77be0b5c`; implementation is `93f5528f`.
The corrected snapshot's native shipping check passed (session11075 EXIT0,
`/tmp/rays-bulk-array-native-ship2.log`). C.5 is complete. These capability
checks qualify no whole SOP port.

The integration adds canonical `array/grade` and `array/index_of`, two Core primitive tags, the
existing cached Core dispatch and the production JavaScript mirrors. No
Region instruction, new bank, dependency, geometry callback or public helper is
needed. The public API delta is the two closed Core primitive variants.

`(array/grade keys :descending false)` accepts Int, finite Float or Text arrays
and returns original indices in stable order. Descending changes comparator
orientation and retains input order for ties; it does not reverse a finished
permutation. Int values remain signed 63-bit, including values beyond 2^53.
Float ±0 compare equal; all Float keys must be finite. Text order and equality
use unsigned original bytes, including NUL, all 256 byte values and invalid
UTF-8. JavaScript reuses the accepted reversible text codec, comparing private
byte strings rather than UTF-16 or locale order. The output is a fresh Int array
with the keys count; input storage is borrowed and never sorted in place.

`(array/index_of keys queries)` accepts matching Int/Int or Text/Text arrays.
Each output slot is the first original key index or -1. Duplicate keys are
valid. The output follows query order and query count, including empty or
unequal lengths. The local specialized stdlib hash table is discarded after the
call; there is no persistent cache. Key equality stays exact, and results never
coerce Int keys through Float.

Ordinary argument evaluation/forcing, typed Source validation, lazy untaken
arms and state rollback keep their existing order. An empty query array does
not waive validation of a selected failing key argument. New operations do not
invent owner count origins: neither a sorted permutation nor a lookup result
inherits first-input topology identity. Conservative unknown origins retain
runtime zip/count checks; any later recognition must follow the keys count for
grade and the **queries** count for lookup. Pure bulk work has the existing
host cancellation boundary and no internal checkpoint. The source comment
records that ceiling and the shared bulk-checkpoint upgrade path.

A whole-array sort/lookup is not a per-element packed instruction. Strict
supported numeric/Text leaf producers and consumers remain compiled; unsupported
producers and dynamic per-row grade/lookup requests are refused. Independently
eligible Float regions may still qualify for GPU execution. This candidate
adds no GPU sort/lookup. Native cooked host Sources remain outside current 2D
web export; pure exported frames use the actual runtime and workers.

## Passed focused proof

The checks below pass in focused integration. No whole-port timings, allocation
claims, completion ticks or registration changes are made here.

- Direct native operations: stable ascending/descending ties, exact Int bounds,
  finite Float ±0/subnormals, arbitrary Text bytes, first-match/-1, empty and
  unequal lengths, 32769-element tails, fresh outputs and immutable inputs at
  domains 1/4/8. Independent list-sort/linear-lookup test oracles are used.
- Actual native RDK consumer comparisons: inverse grade ranks against scalar
  `Ordering.sort`, and lookup→compact→lookup dense first-occurrence piece IDs
  against `Attribute_ops.enumerate`, at domains 1/4/8.
- Strict Core/Executor vs interpreter: live supported producers/downstream maps,
  exact causes, unsupported producer refusal, per-row refusal, changed Source
  buffers/lengths, wrong Source types, lazy failures and transactional state.
- Count origins remain unknown for new whole-array outputs. Mixed keys/result
  maps keep two sources and runtime counts; queries never alias keys cardinality.
- Actual emitted JS frames, production runtime and null/1/8 worker pools:
  32769-element Int/Float/Text producers, all-byte Text grade/lookup, valid UTF-8
  whose byte order differs from UTF-16, exact errors/causes and unchanged input
  numeric/Text buffers. The test declares globbed runtime JS dependencies.
- Core fixture census grows from 93 to 95 and exercises malformed storage,
  NaN/±Inf refusal and native byte transport, without dropping prior cases.
- Actual editor Add_node defaults, typed cards, direct positional/descending
  edits, malformed edits and saved checked source round trips.

The shared launcher passed the focused checks:

```sh
opam exec -- _build/default/tools/check.exe @check @lib/flow/runtest @lib/flow_ir/runtest @lib/flow_sop/runtest @lib/flow_graph/runtest @lib/flow_web/runtest @lib/flow_gpu/runtest @tools/lisp/runtest @test/dependency_gate @test/test_workspace_shell @tools/api_manifest/runtest
```

The API and final native shipping integration checks passed.

These language primitives are not full Sort/Enumerate/Match implementations.
Selected groups, combined indices, spatial Morton keys, duplicate rejection,
per-piece local ranks, start/step overflow and SOP diagnostics remain authored
recipe requirements. Native Sort may inspect only selected Float keys, whereas
an ordinary cooked Float Source validates its full buffer before selection;
raw exceptional storage/error/cancellation parity is a separate prerequisite.
