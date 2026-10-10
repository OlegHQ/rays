# Web export measurements

## 2026-10-11 — Slice C native record boundary

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native executable, one
domain. Input: a record accumulator over 4,096 packed items, 30 changing
frames. One warmup, then the median wall time of three samples; allocated
bytes use `Gc.allocated_bytes`. No profiler was attached.

Build with `dune build lib/flow/test_workspace_eval.exe
lib/sop_catalog/flow_manifest.sexp`. Run from `_build/default/lib/flow`:

```sh
./test_workspace_eval.exe --bench-records
```

The baseline uses commit `00641a6f` in an isolated worktree with only the
benchmark's current `lib/flow/test_workspace_eval.ml` and its Dune test stanza
copied in. `--bench-records` exits before the normal test cases, so both runs
execute the same source and measurement against their own Flow library.

| Path | Wall seconds | Allocated bytes |
| --- | ---: | ---: |
| P1.5 native baseline | 0.076312 | 152,390,016 |
| Slice C native equality/coercion fixes | 0.058664 | 297,986,736 |

Wall time improved by about 23%; allocation grew by about 96%. This measures
the native evaluator boundary, not core loop execution. P1.6a must measure the
same input through a prepared core Executor after P1.7 and remove that
allocation regression before the phase review. No core performance claim is
made from these rows.

## 2026-10-11 — Deferred authored merge source tags

Machine: managed Darwin arm64 runner, OCaml 5.3.0 native executable. One and
eight domains, grain 97. Eight copies of a box with 32 divisions per axis and
face groups, producing 98,304 primitives. Each sample cooks the same lowered
`sop/merge` with `:source_attribute "src" :source_base 10` in 20 fresh
sessions. One warmup sample, then median wall time of three samples, with
allocated bytes measured by `Gc.allocated_bytes`. No profiler was attached.

Build with `_build/default/tools/check.exe lib/flow_sop/test_merge_source.exe`.
Run from the repository root:

```sh
_build/default/lib/flow_sop/test_merge_source.exe --bench
```

The baseline ran before editing `lib/flow_sop/merge_source.ml`, with the same
new benchmark executable linked to the original two-merge implementation.
The replacement copies the geometry once and constructs only the additional
tag array. The normal test compares semantic geometry bytes (including
ordered attributes, groups and edge groups) against the original algorithm,
at one and eight domains, for fresh/existing tags, schema failures, an alias
of the internal tag, and an empty geometry. It also checks source ownership
and cancellation. `_build/default/tools/check.exe @lib/flow_sop/runtest`
passes without snapshot changes.

| Domains | Path | Wall seconds | Allocated bytes |
| ---: | --- | ---: | ---: |
| 1 | Two geometry merges | 0.138822 | 266,731,296 |
| 1 | One geometry merge | 0.071613 | 149,511,776 |
| 8 | Two geometry merges | 0.136539 | 290,884,728 |
| 8 | One geometry merge | 0.072171 | 160,389,592 |

On this input, one-domain wall time falls by 48% and allocation by 44%.
Eight-domain wall time falls by 47% and allocation by 45%; scheduling can
vary the pool's allocation count. This measurement covers the native SOP
cook and does not claim a browser or core-executor speedup.
