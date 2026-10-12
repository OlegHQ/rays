# Checked scalar arithmetic proposal

Status: implementation and focused compiler/runtime checks passed. The public
API was reviewed and accepted separately in `c5521938`. This shared numerical
boundary does not complete a whole-node port.

## Contract

Add two generic pure scalar operations:

```lisp
(float/mul_checked a b)       ; {:value float :valid bool}
(float/fma_checked a b c)     ; {:value float :valid bool}
```

Inputs must be finite, as for ordinary numeric operations. A finite result keeps
its exact binary64 bits, including signed zero and subnormal values, and returns
`valid = true`. An overflowing result returns positive zero and `valid = false`.
No nonfinite `Value`, published packed register or output buffer is produced.
Existing `*` and `fma` retain their current `E_NONFINITE` behavior.

The multiplication helper uses `Sys.opaque_identity (a *. b)` to establish a
separately rounded binary64 product. The fused helper uses `Float.fma a b c`.
An intermediate product that overflows inside a fused operation does not make
that operation invalid when cancellation produces a finite final result.

The result is an ordinary typed record. No new `Value` variant, result type,
host callback or SOP-specific arithmetic implementation is needed. Scalar
reference evaluation and structured Core can publish the record directly.

## Native Point Jitter sequencing

`lib/rdk/gen/point_jitter.ml` checks selection owner/count, parameter finiteness
and attribute names/storage before running the point kernel. Missing mask
attributes fail; missing `pscale` or integer identity attributes use defaults.

For each selected point, the native kernel first reads mask and point scale,
then computes the two multiplications in `scale * mask * pscale`. It rejects
nonfinite inputs or amplitude before sampling or updating coordinates. Failure
of the first multiplication must remain visible even when the next factor is
zero: replacing its invalid product with zero must not turn the chain valid.

After sampling, the proposed coordinate sequence uses the separately rounded
`sample * amplitude` followed by explicit FMA with axis scale and the original
coordinate, matching the draft's intended reproduction of native compiler
contraction. The native source expresses this as multiplication and addition,
so the compiled oracle remains the check for that reproduction. The
recipe must retain every applicable input and arithmetic validity flag.
Invalid unselected rows are ignored; invalid selected rows determine the lowest
point index, independent of domain count and grain.

The native failure is `invalid_attribute`, message
`point_jitter could not produce valid geometry`, with cause
`point_jitter [invalid_attribute]: Rdk_gen.Point_jitter.point_jitter: selected point N has non-finite input or output`.
The generic operations return status so Lisp can produce this existing
diagnostic through `error :cause` after finding the index. They do not know its
name, index or error text. Failure publishes no partially modified geometry.

Raw stored NaN/infinity is a separate boundary already covered by
`sop/attr_checked`: its finite replacement values and exact integer validity
mask survive ordinary source validation. Point Jitter must combine those masks
with arithmetic validity. Its selected writer must preserve unselected raw
planes; ordinary numeric reads and computed kernels remain finite checked.

## Minimal compiler representation

The region instruction stream has one destination register per instruction.
Use checked multiplication/FMA instructions with a `Value | Valid` projection:

```ocaml
Checked_mul of projection * int * int
Checked_fma of projection * int * int * int
```

Both projections use the existing float bank. `Valid` produces exactly zero or
one; `Value` produces the finite result or positive zero. Existing compiler-only
record fields connect these registers to `value` and `valid`. Guards wrap both
instructions through existing `Guarded` execution. Sharing keys must include
the projection and guards, and fusion must remap every operand.

This deliberately computes the pure arithmetic twice when both fields are
used. It avoids multi-destination SSA, status side tables, raw nonfinite
registers and a new executor representation. The ceiling is duplicate work,
especially the existing exact BigInt FMA in JavaScript. Measure before adding
an optimization; if necessary, co-compute adjacent matching Value/Valid pairs
in the existing block runner while preserving each instruction's guards and
the same numeric contract. No speed claim follows from this design.

`Core_region.literal` currently refuses constant records. It needs recursive
record lowering so constant checked calls compile through the same field path.
Packed outputs remain ordinary supported numeric types: the record is local
to a helper/map body, whose caller projects or combines its fields.

## Required mirrors and checks

Implementation must cover:

- Canonical `Flow.Op` declarations and `packed_kind`, pure reference bodies,
  typed result records and existing scalar input validation.
- Core scalar primitive tags, names/printing, `Core_lower` and `Core_exec`;
  region/Packed declarations, operands, validation/layout and instruction keys.
- `Core_region` dynamic and constant record fields, `Core_fuse` remapping,
  both Float and typed CPU block runners, guards and finite-check metadata.
- JavaScript scalar primitives and region emission. Reuse the existing exact
  FMA algorithm through a private raw-result helper; ordinary exported `fma`
  retains its current input/output checks, while checked FMA sanitizes overflow.
- Shared `E_GPU_FORM` refusal for both checked binary64 operations, including
  kernels whose final output is finite. Metal/WGSL float32 cannot determine
  their binary64 overflow status. No native GPU fallback is introduced.
- Core/native/JavaScript primitive census and fixtures, graph projection and a
  direct `Set_arg` gesture for the new scalar cards, plus specification/API
  review before accepting public declarations.

The focused numerical matrix must include maximum-float multiplication
overflow, invalid-first-product followed by zero, finite FMA cancellation of
an overflowing product (`max * 2 - max`), FMA output overflow, signed zero and
subnormal underflow. The inputs `1 + 2^-27` and `1 - 2^-27` distinguish a
separately rounded product of one from their fused product-minus-one of
`-2^-54`. Direct invalid scalar inputs retain `E_NONFINITE`.

Check constant records, each field separately, helper/record projection,
selected and untaken branches, and an unconditional checked let binding that
returns invalid status without throwing. Reference, strict packed, structured
Core and JavaScript must agree; CPU one/eight-domain outputs must match exact
bytes. Point Jitter then needs its complete selected/unselected raw and finite
overflow oracle, first-index/cause, atomic failure and whole-node timing gates.

## Implementation evidence

The root reviewed the three public interface changes and promoted only their
intended API manifest diff. API promotion exited 1 for that diff; confirmation
exited 0 (`/tmp/rays-checked-arithmetic-api-confirm.log`).

Shared-launcher request 83484 exited zero with `@check`,
`@lib/flow/runtest`, `@lib/flow_graph/runtest`, `@lib/flow_ir/runtest`,
`@lib/flow_gpu/runtest`, `@lib/flow_web/runtest`,
`@tools/lisp/test/runtest` and `@test/dependency_gate`.
The retained log is `/tmp/rays-checked-arithmetic-final.log`.

The checked-arithmetic test compares 32,769 rows byte for byte across reference,
structured Core, strict packed CPU at one/eight domains and emitted JavaScript.
It covers overflow status, finite fused cancellation, signed zero, subnormals,
constant records, captured helper fields and lazy branches. Malformed public
regions with NaN or either infinity still refuse selected checked operands;
untaken guards retain lazy execution. Both shader targets refuse the new
instructions. Scalar Core/operator census and native-to-JavaScript primitive
fixtures include the two declarations, bringing the Core inventory to 90.
Graph tests project both record-output cards and apply direct argument edits.

The implementation reuses canonical primitive dispatch for scalar Core and the
existing guarded Float/typed bank runners. The only public declaration changes
are `Flow.Op.packed_kind`, `Core.primitive`, `Core.Region.projection` and the
two corresponding region/Packed instruction variants. No arithmetic timing or
whole-node performance claim follows from these checks; the two-projection
duplicate-computation ceiling remains as described above.
