# The shared Flow core

This is the compiler contract for the native and web targets of
[the web-export plan](web-export/plan.md). It introduces no Lisp syntax. The
checked workspace and the tree walker remain the language contract and the
native exactness oracle. A target prints or executes this core; it does not
walk `Workspace.term`, expand macros, or interpret Lisp operator names.

The frame primitive inventory below has **54 entries**. Region instruction
constructors, structured control, drawing statements and host intrinsics are
listed separately: none is a hidden primitive in a target's numeric runtime.
The P0.R review must confirm this inventory before product implementation.

## Two execution levels

The static stage evaluates frame-independent expressions with the tree walker,
using graph input defaults. Its data becomes constants, including packed arrays
and resource descriptions. It never serializes an OCaml closure, cache, SDL
object or GPU handle. The remaining checked expressions lower once to a frame
program and its regions.

The **frame program** runs on the initial native domain, or the browser's main
thread, once per logical frame. It reads one immutable input snapshot, computes
scalar and bounded structured data, advances state slots, invokes regions, and
produces ordered drawing statements and host effects. A static subexpression
is retained; a changed view transform must not recompute unchanged attributes.

A **region** is a pure numeric loop over packed arrays. It has explicit input
buffers, captured uniforms, an iteration domain, a numeric body and output
slots. Independent elements run in disjoint 1,024-element CPU blocks, through
the shared native pool or required web workers. GPU placement emits that body
as Metal or WGSL. Ordered reductions and accumulator loops preserve iteration
order; they are not parallel tree reductions. Text, lists of records, host
effects and frame state are not region values.

Native frame and CPU-region results must be bit-identical to the tree walker,
including coercions, evaluation order and integer/float tags. GPU regions have
the existing approximate numeric contract. The web frame and CPU-region
targets use double precision; they need not be bit-identical to native, but
integers, booleans, text and table structure are exact. Target-specific
rounding does not permit a different branch, list length or state identity.

## Program data and ownership

A frame program contains numbered locals, a typed constant table, structured
statements, result locals, a state-slot table and regions. Local and statement
numbers are assigned in source traversal order, not hash-table iteration
order. Every statement retains its authored path, graph instance, iteration
identity and half-open source byte span. Printers use these to generate
`program.map`; a diagnostic points to the original `.rays` form.

Inlining retains the callable's graph instance and prefix. A per-frame counter
slot supplies each invoked closure's next call index; only a selected branch
increments it. Constructing a local callable resets its slot, including each
loop iteration. Iteration identities contain static indices and local reads of
these call indices, so state inside an inlined function retains native keys.

The core contains data, not callbacks. A primitive is a closed member of the
inventory below with explicit operands and result layout. An intrinsic is a
closed effect/resource operation with target legality. Captures are constants,
locals, state reads or uniforms. Native compilation to closures is permitted
as an execution optimization after the core has been built; those closures
never become the representation consumed by another target.

Values are immutable when published. Sequence-building stores write only a
fresh, locally owned allocation. A published sequence, constant or previous
state value cannot be edited in place. Buffer ids belong to the caller's table;
they do not expose a backend buffer handle. Replaced GPU resources are released
by their owner, on the initial domain or browser main thread.

| Value | Layout and admissible uses |
| --- | --- |
| Float | One binary64 frame/CPU component; a binary32 GPU-region component. Non-finite inputs and results fail at the existing checked boundaries. |
| Int | The native signed 63-bit integer domain; distinct from Float even when their numeric values match. Explicit integer operations retain integer semantics. |
| Bool | One boolean frame value; region comparisons encode false as 0 and true as 1. |
| Text | A decoded string value; no quotes are added on a text read or concatenation. It stays at frame level. |
| Vec2, Vec3, Vec4 | Two, three or four floating components. Field names are static `x`, `y`, `z`, `w`; a scalar broadcast is explicit. |
| Record | Ordered, statically named fields. Nested records flatten to ordered field locals; layout retains names, nesting and field order for reconstruction, `show` and equality. |
| List | An element layout and a length no greater than 4,096; a static length or a bounded dynamic length. Elements may contain records, text and other bounded lists. |
| Packed array | Contiguous numeric storage, element width 1, 2, 3 or 4 and an element count. Counts may exceed 4,096. Lists and packed arrays remain different value kinds. |
| Image | A resource id and its description or producer, resolved by the host; no pixels or GPU handle are smuggled into a scalar value. |
| Drawing | An ordered sequence of drawing entries, possibly grouped by a transform. It is not a state value or a numeric region value. |
| Effect/sample | A typed intrinsic description, legal only when the target implements that intrinsic. |

Functions are compile-time callables: local `fn`, named `defn`, and operator
function references specialize and inline at their checked call sites. No
function survives as a stored frame, state, region or exported data value.
`Any` is a checker type, not permission for an unrestricted dynamic value VM;
lowering must resolve its layout or return a refusal. `nil` is empty geometry
in the source contract, not an empty numeric sequence; a reached geometry value
is refused by the web target.

## Structured control and lowering

Expressions are literals, local reads, primitive applications, vector/component
construction and statically laid-out structured values. Statements assign
locals, branch, loop, build a sequence, read/write a state slot, invoke a region,
append a draw entry or invoke an intrinsic. A branch or loop assigns its result
to explicit result locals. There are no jump offsets, bytecode opcodes or
general run-time function calls.

Counted iteration converts endpoints with the source's list-index rounding,
computes `max(0,last-first)` with native integer subtraction, checks its bound,
and initializes its result builder once before visiting items. The ordinal
index and `Int(first+index)` item are separate locals. The induction uses
integer arithmetic even above binary64's exact-integer range; it is structured
control, not a new frame primitive.

Arguments and fields evaluate in authored order, once. `let*` extends the
environment after each binding. Sequence destructuring checks the required
length, and record destructuring reads static keys. A dotted reference is a
chain of component/field reads; its missing-field diagnostic is `E_FIELD`.
`assoc` evaluates the record first and updates in authored order, preserving
existing field position, coercing an existing field to its prior layout, and
appending a new field at the end.
An existing reactive field is resolved before its tag controls coercion.
Nested coercion reads only old fields present in the replacement record;
unrelated captured fields remain lazy. Accumulator coercion follows the same
rule, with the numeric Int-to-Float widening described below.

Record construction and matching ordered branch layouts retain field locals;
reconstruction occurs only at a structured result or primitive operand. A
branch whose records have different field order retains that order in its
selected structured value. A joined numeric local may still hold an Int from
one branch: explicit Float coercion must convert it, and `assoc` must use the
selected old value's tag rather than the checker's joined type.

`if` evaluates its condition and only the selected branch. `cond` tests arms in
order and stops at the first true test. `case` evaluates its scrutinee once;
literal number comparisons use numeric values, text compares text, and a Bool
on either side requests boolean numeric truth conversion. The compiler
expands these cases with `=`, `equal?` and `truthy`; it must not substitute
structural equality for numeric case matching. `and` and `or` are ordinary
eager source operators: both operand expressions evaluate before the result
is formed.

Loops have explicit induction and accumulator locals. A list loop has at most
4,096 attempted iterations, including skipped iterations. Product clauses
nest in source order, with the last clause varying fastest; later sources may
depend on earlier bindings. `:skip` tuples keep their authored iteration
identity, avoid evaluating the skipped body, and advance the attempted index.
`for` collects results, `sum` adds them in order (an empty sum is `Int 0`),
`fold` returns its accumulator, and `scan` collects the updated accumulator
after each non-skipped step. An integer accumulator can widen to Float when
the next step is Float; that is different from the rounding used by `assoc`.

List `map` zips its inputs to their shortest length. `filter` retains source
order. `reduce` applies the function sequentially to the accumulator and each
item, returning its seed for empty input. `sort_by` computes a numeric key once
per item and orders stably by that key. Packed forms of these operations have
packed storage rather than the list cap; eligible pure numeric bodies become
regions. The checker still enforces `E_TIME_COUNT` where a live count could
change graph topology. A compiled bounded data loop does not relax that rule.

Frame list sorting expands to a stable bottom-up merge with locally owned
index buffers and one key evaluation per source element. Seeded record
accumulators retain their fields as locals; all next fields are read before
any old field is overwritten. Builders share a write permission across local
aliases. Embedding a builder in a record/list or storing it in another builder
seals it, and a store through any alias then fails with `E_CORE_OWNERSHIP`.

`Expanded` lowers its checked macro body. `Bypass` lowers only the first
positional input the checker selected and coerces it to the call result type;
it does not evaluate the bypassed operation's other inputs. `ref` specializes
a graph instance with its checked overrides/defaults and keeps the evaluator's
sharing and instance identity. Neither graph references nor macros become a
second target-side interpreter.

If native lowering cannot cover a form, it returns that form's name. During
the staged migration, execution continues through the existing path. If core
execution fails, the native caller reruns the tree walker to obtain its exact
diagnostic and span, with state restored before retry. Web export has no tree
walker fallback: an unsupported reached form is a source-located export
refusal and a non-zero exit, never a missing entry or a silent no-op.

## Frame primitive inventory

Each back end implements exactly these leaves. A parameter such as a type
layout, error span, or operation label is data fixed by lowering, not an
additional dynamically chosen Lisp operator. Structured sequence stores,
local assignments and component reads are core statements/expressions, not
unlisted calls in `prims.js`.

| Primitive names | Entries | Behavior |
| --- | ---: | --- |
| `+`, `-`, `*`, `/`, `mod`, `pow`, `min`, `max` | 8 | Numeric arithmetic with scalar/vector broadcasting and the source result tags. `/` and `mod` return zero for a zero divisor; `mod` is the double-remainder rule; `pow` uses the absolute base. Integer results of ordinary arithmetic pass through the double arithmetic and integer conversion boundary. |
| `remainder` | 1 | Raw floating remainder with the dividend's sign; used by color lowering. It must not add the divisor or repeat the remainder calculation as `mod` does, since that changes double rounding. A non-finite result fails with the operation's span. |
| `sin`, `cos`, `sqrt`, `exp`, `abs` | 5 | Scalar math; `sqrt` takes the absolute input. `abs` retains an Int input's tag. Non-finite results follow the source operator's finite check. |
| `floor`, `ceil`, `round`, `int`, `float` | 5 | Numeric conversion; explicit `int` truncates. `round` uses the source explicit-round rule, while type coercion to Int uses the separate coercion rule. |
| `<`, `<=`, `>`, `>=`, `=`, `and`, `or`, `not` | 8 | Numeric comparisons and numeric boolean truth. These are not generic string/array comparisons, nor JavaScript truthiness. |
| `int/mul`, `int/div`, `int/mod`, `int/and`, `int/xor` | 5 | Signed integer operations, including native integer overflow, division and remainder; zero integer divisor is `E_RANGE`. No 32-bit JavaScript bitwise truncation. |
| `equal?`, `show`, `text/concat` | 3 | Typed structural equality, source value display, and ordered text concatenation. `show` has display formatting, distinct from workspace source-number printing. |
| `sequence/length`, `sequence/get`, `sequence/build`, `sequence/slice`, `sequence/concat` | 5 | Element count, checked list element access, fresh bounded-list storage, checked copying slice, and ordered concatenation with the 4,096-element cap. Element layouts and nested record field order are explicit. Given an element width of 1 to 4, `sequence/build` allocates packed storage with no list cap, filled by the same ordered stores (the walker's `array_init` checks per element); that is how a packed `map` or `filter` whose body a region refuses is built, so the inventory stays at 54. |
| `array/range`, `array/float`, `array/vec3`, `array/nth`, `array/count`, `array/slice`, `array/concat` | 7 | The existing packed-array construction, indexing, length and copying operations. Count is in elements, not components; all products and offsets are checked before allocation or access. An array is not converted to a list. |
| `value/rand`, `noise3`, `color/parse`, `color/byte` | 4 | The deterministic keyed hash, seeded Perlin/fBm sample, source drawing-color decoding, and channel conversion. Static noise permutations become data; dynamic-seed caches are bounded to 16 entries. Color conversion preserves native byte quantization. |
| `coerce`, `truthy`, `fail` | 3 | Explicit checked source-value coercion, condition truth conversion, and a diagnostic with a code, message and source span. Coercion preserves record order and list element joins. |

Total: 8 + 1 + 5 + 5 + 8 + 5 + 3 + 5 + 7 + 4 + 3 = **54**.
The numeric, list and text models below fix the behavior of these leaves;
P0.R reviews them with the inventory.

Convenience operators lower to these leaves. For example `value/polar` is a
vector built from `*`, `cos`, `sin` and its optional height, `length` is an
ordered sum of component squares followed by `sqrt`, and `color/hsl` is
arithmetic, branches and `color/byte`. List `range`, `take`, `rest`, `reverse`,
`filter` and higher-order calls are sequence allocation/access plus structured
loops, not independent target runtime algorithms.

`color/gradient` first uses `color/parse` on each stop and refuses empty or
non-opaque stops with `E_DRAW_COLOR`. It clamps the position to [0,1], scales
by stop count minus one, selects the adjacent stops, interpolates each byte
with `left*(1-u)+right*u`, adds 0.5 and truncates, then divides RGB by 255.
A one-stop gradient returns that stop. `color/hsl` wraps hue in degrees to
[0,360), clamps saturation and lightness to [0,1], sets
`c=(1-abs(2*l-1))*s`, `x=c*(1-abs(remainder(h/60,2)-1))`, picks the six RGB
sectors, adds `l-c/2` to each channel, quantizes and divides by 255. Its alpha
is 255. These formulas are compiler rules shared by both targets.

## Numeric model

Frame and CPU-region floating arithmetic is IEEE-754 binary64. GPU regions
use binary32 inputs, uniforms, registers and outputs, as the existing Metal
emitter does. An instruction rounds to its own result precision before the
next instruction; lowering may not reassociate an ordered sum or introduce a
fused multiply/add that removes a rounding step. A GPU constant or uniform is
encoded by its binary32 bits. Converting a GPU attribute buffer to a CPU
consumer is an explicit readback/precision boundary, subject to target
legality; it is not an implicit float conversion.

Native Int has 63 signed bits: minimum -4,611,686,018,427,387,904 (`-2^62`),
maximum 4,611,686,018,427,387,903 (`2^62-1`). This range is distinct from the
checked float-to-int boundary: that conversion accepts only a finite double
with absolute value strictly less than `4e18`, then truncates toward zero.
An exact existing Int is not put through that narrower float boundary unless
the operator explicitly converts it to a double. Failures there are
`E_NONFINITE`, with the operator name in the message.

Number conversion maps Int to its rounded binary64 value, Bool to 0 or 1,
and Float to itself; any other value is `E_TYPE` ("Expected a number.").
Truth conversion accepts Bool unchanged and Int/Float unequal to zero;
all other kinds are `E_TYPE` ("Expected a bool."). Signed floating zero is
false. These conversions are not JavaScript's general `Number` or truthiness
on objects, strings and lists.

| Operation | Exact order and result |
| --- | --- |
| `int(x)` | Number conversion, truncate toward zero, checked float-to-int conversion; Int result. Thus `int(-2.7) = -2`. |
| `floor(x)`, `ceil(x)` | Number conversion, floor/ceiling, checked float-to-int conversion; Int result. |
| `round(x)` | Number conversion, nearest integer with an exact halfway case away from zero, then checked float-to-int conversion. `round(-2.5) = -3`. |
| Coercion to Int / `Value.int_of` | Number conversion, `floor(x + 0.5)` in binary64, then checked float-to-int conversion. This includes the rounding of the addition. Coercing `-2.5` gives `-2`. Bool-to-Int coercion directly gives 0 or 1. |
| `float(x)` | Number conversion; Float result, including an Int value rounded to binary64. |
| Ordinary `+`, `-`, `*`, `mod`, `min`, `max` | Convert both scalars to doubles, apply the operation, reject a non-finite result, then return Int only when both actual operands are Int. That Int result uses `floor(result + 0.5)` and the checked conversion. It is not exact integer arithmetic. |
| Ordinary `/` | Convert operands to doubles. If the divisor equals either signed zero, result is positive zero; otherwise divide. Reject a non-finite result and return Float. |
| Ordinary `mod` | If the divisor is zero, positive zero; otherwise `remainder(remainder(a,b) + b,b)`, in that order. This is not integer remainder and is not one remainder calculation. |
| Ordinary `pow` | `pow(abs(a),b)` with double operands; reject a non-finite result; Float result even for two Int inputs. |
| Vector arithmetic | Matching-width vectors apply the scalar floating operation in component order. A scalar numeric operand broadcasts to that width. Every result component is finite; result is a vector, not Int components. The checker rejects mismatched widths. |
| Scalar `sin`, `cos`, `exp` | Number conversion followed by scalar math and the named finite-result check; Float result. |
| Scalar `sqrt` | Number conversion followed by `sqrt(abs(x))`; Float result. Packed instructions additionally check every numeric result for finiteness. |
| Scalar `abs` | An Int input uses signed integer absolute value, retaining the native wrap at minimum Int (`abs(min_int) = min_int`); all other numeric inputs use floating absolute value and yield Float. |
| `<`, `<=`, `>`, `>=`, `=` | Compare converted doubles, even for two Int inputs. In particular, numeric `=` may equate distinct large integers after double rounding; structural `equal?` does not. |
| `and`, `or`, `not` | Operands have already evaluated in authored order. Truth-convert operands as the source operator does and produce Bool. `and`/`or` may short-circuit the second truth conversion, but never the evaluation of the second operand expression. |

For an `int/*` operand, an existing Int is used directly; a Float or Bool
passes through `Value.int_of`, not explicit `int` truncation. The five
operations then work in the signed 63-bit domain:

| Integer primitive | Behavior |
| --- | --- |
| `int/mul(a,b)` | Multiply exactly, keep the low 63 bits, interpret those bits as signed. `int/mul(max_int,2) = -2`. |
| `int/div(a,b)` | Signed quotient truncated toward zero. Zero divisor is `E_RANGE` ("Integer division by zero."). The overflow pair `min_int / -1` wraps to `min_int`. |
| `int/mod(a,b)` | Signed remainder `a - trunc(a/b)*b`, with the dividend's sign. Zero divisor has the same `E_RANGE`; `-7 mod 3 = -1`, `7 mod -3 = 1`, and `min_int mod -1 = 0`. |
| `int/and(a,b)` | Bitwise AND of their 63-bit two's-complement representations, then signed interpretation. |
| `int/xor(a,b)` | Bitwise XOR of those representations, then signed interpretation. `min_int xor max_int = -1`. |

The JavaScript target represents Int as `BigInt` and Float as `Number`.
Integer literals are emitted as decimal BigInt literals, never parsed through
Number first. `int/*` arithmetic wraps with `BigInt.asIntN(63, value)`; BigInt
division/remainder have the required truncation/sign, with explicit zero
checks and wrapping for quotient overflow. The target uses `Number(integer)`
only at the numeric-double conversion boundary. A checked Float-to-Int
conversion tests the finite/magnitude condition before creating a BigInt
from the truncated Number. Intermediate local tags, list joins and state
coercions remain explicit; a large integer must not lose bits on a field read,
in structural equality, in state, or in JSON fixture serialization. JSON
fixtures encode integers in decimal text with their Int tag.

`value/rand` is the keyed numeric hash, not mutable random state. Start at
unsigned 32-bit `h=0x9e3779b9`. For each numeric key in order, compute
`k=ToUint32(floor(key*1000003))`, then
`h=imul(h xor k,0x85ebca6b)`, `h=h xor (h >>> 13)`,
`h=imul(h,0xc2b2ae35)`, `h=h xor (h >>> 16)`. `imul` retains the low 32
bits; right shift is logical. `ToUint32` truncates a finite value modulo
`2^32` into [0,`2^32`); a non-finite value maps to zero, including overflow
of the key multiplication. The result is `(unsigned h mod 1000000)/1000000`.
JavaScript's 32-bit operations are appropriate for this hash only, not `int/*`.

Noise uses a seeded permutation of 0..255 duplicated to 512 entries, Perlin
gradient interpolation and optional ordered fBm. Static seed permutations
are exported as data. The dynamic permutation generator shuffles backwards
from index 255 to 1, taking the unsigned SplitMix64 output modulo index+1.
Its state adds `0x9e3779b97f4a7c15` modulo `2^64`, mixes with logical shifts
30, 27 and 31 and multipliers `0xbf58476d1ce4e5b9` and
`0x94d049bb133111eb`, also modulo `2^64`. Each generated index swaps two
entries; it does not consume a global generator.

For a sample, floor the position, use each integer lattice coordinate's low
8 bits and the permutation to select eight corner hashes. With `h=hash&15`,
gradient uses `u=x` if h<8 else y; `v=y` if h<4, x if h=12 or 14, else z;
bit 0 negates u and bit 1 negates v, then add. Fade is
`t*t*t*(t*(t*6-15)+10)`, with operations in that order. Interpolate by
`a+t*(b-a)`, along x for each corner pair, then y, then z. Map the raw result
with `(raw+1)/2` and clamp to [0,1]. Default seed is 0 and octaves is 1;
frame octaves outside 1..32 are `E_NOISE_RANGE`. fBm starts at frequency and
amplitude 1, adds sample*amplitude and amplitude to ordered sum/weights,
doubles frequency and halves amplitude each octave, then divides sum by
weights. Packed noise supports octaves 1..32 with a constant seed and constant
octave count; non-constant or out-of-range settings keep their current refusals.

## List model

The core represents lists of at most 4,096 elements. This is a representation
limit, not a new source-language rejection. Today `range`, `linspace`,
`concat` and non-packed product loops enforce `E_ITER_BOUND`, but a list
literal, a supplied list value or `frame/input` events is not universally
length-checked by the walker. An oversized value that survives static
evaluation must therefore decline native core lowering/execution and use
the native reference path; the web target must issue a source-located
list-limit refusal. It cannot drop events, truncate data or change the
walker's errors to enforce the core limit. A large static list that is wholly
consumed at compile time need not survive in the core.

| List producer/use | Length facts and lowering |
| --- | --- |
| Literal `list` | Its authored number of elements is known. Evaluate elements in order and join their actual element types, then coerce every element to that joined type. Static contents fold; otherwise build a fixed-length list. |
| `range(n)` / `range(a,b)` | Length is `max(0,n)` / `max(0,b-a)`. Static endpoints fold or unroll; input-dependent endpoints produce a bounded dynamic list. End is exclusive and elements are Int. Existing source bounds/overflow behavior remain the native oracle. |
| `linspace(a,b,n)` | Length `max(0,n)`; literal n gives a known count even when endpoints are live. For n=1 the single element is a; otherwise element k is `a+(b-a)*k/(n-1)` in source operation order. |
| `map` | List inputs zip to minimum count; known input counts make the result count known. It may be unrolled only within the lowering budget; otherwise use the same bounded structured loop. |
| `filter` | Result count depends on the predicate; live predicates imply live length even with a fixed source count. Preserve order and joined element layout. |
| `sort-by` / `reverse` | Count is the source count. Compute keys once and sort stably; reverse copies source elements in descending index order. |
| `concat` | Sum input counts, retain input/element order, join element types and coerce, then enforce the source 4,096 cap. No repeated append of an ever-growing prefix. |
| `take` / `drop` / `rest` | `take` retains the first min(max(0,n),length) elements; `drop` removes that many; `rest` removes one if present. A live n or live source length implies dynamic length. |
| `for` / `scan` | Product iteration count, minus skipped tuples, controls the collected length. Later clauses may depend on earlier items. List loops count attempted iterations for the 4,096 bound, including skips. |
| `fold` / `sum` / `reduce` | No collected output list except the accumulator's own data. Empty fold/reduce returns the seed; empty sum returns Int 0. Ordered accumulation and coercion/widening are preserved. |
| Frame events / state-held list fields | Bounded dynamic length when represented in core; the source frame/event and state identity rules still apply. Length is not made static merely by flattening a record. |

The checker distinguishes live values from live list lengths. Literal list
count is fixed even if elements mention t. Range/linspace counts are marked
live when their arguments are live; take/drop also inherit source-length
liveness. Branches, record fields, graph overrides and state propagate length
facts. `E_TIME_COUNT` rejects a live-length source in a `for` that would
produce graph nodes. A `sum` may consume a live length; `fold`/`scan` may
consume it when their accumulator is data, and packed data arrays may have
live lengths. Shape-producing calls that splice a live list retain the
checker's refusal. Core loops do not bypass checking.

A record element's flattened layout is ordered depth-first by authored field
order. For example `{:p vec2 :label text :style {:width int :visible bool}}`
has lanes `p.x`, `p.y`, `label`, `style.width`, `style.visible`, with their
scalar types. A list is a shared length plus one column per lane. Numeric
columns use the corresponding scalar storage; text and nested-list columns
hold their typed values/descriptors. A nested packed-array field is a buffer
reference/count/width, not thousands of copied scalar lanes. Column i at
row j always belongs to the same logical record, and filtering/slicing moves
all columns together. Layout metadata reconstructs field order, nesting and
component grouping for `show` and `equal?`. Published columns are immutable;
`assoc` on an element creates its changed value, without mutating the source.

`nth` checks a Float index for whole-numberness before conversion, then checks
the converted index against [0,length); failures are `E_LIST_RANGE`. A sequence
pattern requires at least its number of pattern elements (additional source
elements are permitted); shortage is `E_PATTERN`. Empty `first`/`last` fail
with `E_LIST_RANGE`; empty `rest` remains empty. Packed-array indexing instead
uses `E_ARRAY_RANGE`, non-negative whole numeric indices, and element widths.
Packed arrays never inherit the 4,096 list cap.

## Packed-array leaves

The seven array leaves use element counts. Widths 1/2/3/4 store floats or
interleaved vector components; array length divides storage length by width.
An imported vector storage length not divisible by its width is
`E_ARRAY_TYPE`. Input validation checks every stored component for finiteness.
This validation happens at the input boundary, not on every slice or read.

The count/index conversion first converts the source number to binary64,
then requires a non-negative whole value no greater than
`Sys.max_floatarray_length`; failure is `E_ARRAY_RANGE` with
"<operator> needs a non-negative whole length." It then truncates to Int.
This is distinct from `coerce` and the narrower `4e18` conversion. The native
maximum is the platform storage ceiling; exported counts also obey the
chosen target's allocation and dispatch limits, with located refusals before
allocation. Neither ceiling permits truncating a requested array.

| Leaf | Behavior |
| --- | --- |
| `array/range(count)` | Fresh width-1 storage containing Float values 0 through count-1. |
| `array/float(count,value)` | Fresh width-1 storage filled with the numeric value; omitted value is Float zero. |
| `array/vec3(count,value)` | Fresh width-3 storage; omitted value is Vec3 zero. A Vec3 fills its components; a scalar Int/Float/Bool broadcasts numerically. Other widths fail with `E_ARRAY_TYPE`. |
| `array/count(array)` | Int element count; non-array or malformed width is `E_ARRAY_TYPE`. |
| `array/nth(array,index)` | Convert index as above, require index < element count, and return Float or the matching vector. Out of bounds is `E_ARRAY_RANGE` ("Array index is outside its length."). |
| `array/slice(array,first,count)` | Convert first and count as above; require first <= length and count <= length-first. Copy the component range into fresh same-kind storage. An empty slice at length is legal. Range failure is `E_ARRAY_RANGE` ("An array slice must be within its source."); non-array is `E_TYPE`. |
| `array/concat(first,second)` | Both operands must have the exact same array kind/width; otherwise `E_ARRAY_TYPE` ("Concatenated arrays must have the same element type."). Copy first then second into fresh same-kind storage, checking target storage bounds. |

Allocation checks count <= maximum component count / width before multiplying.
Each constructed component passes the finite check named `array`. Width-1
construction accepts Int/Float/Bool through number conversion; vectors fail
there with `E_TYPE`. Generic region construction supports Vec2/3/4, broadcasts
numeric scalars, and rejects other element layouts with `E_ARRAY_TYPE`.
Zero-count construction does not examine the fill value's numeric contents;
its argument expression still evaluates. Slice/concat copy existing validated
storage without re-quantizing or coercing components. Published arrays are
immutable, including empty arrays.

## Coercion and color leaves

`coerce(wanted,value)` uses a statically supplied checker type. It is a
conversion rather than general validation: Any leaves the value unchanged;
Float to Int uses the coercion rounding above; Bool to Int gives 0/1;
Int/Bool to Float uses numeric conversion; Int/Float to Bool uses `truthy`.
Int/Float broadcasts to Vec2/3/4; Bool does not broadcast in this leaf.
List coercion recursively converts each element into fresh list storage.
Record coercion traverses the actual fields in their original order, converts
fields named in the wanted record, and retains unmatched fields unchanged.
It neither adds missing fields nor sorts them. All other pairs stay unchanged,
including packed arrays and already matching scalars/vectors. During native
staging a Residual stays unchanged until forced; a finished core value cannot
contain one. Layout checking by lowering must not invent a runtime coercion
error for a pair the source leaves unchanged.

`color/parse` returns four byte channels (Ints 0..255) from precisely these
source kinds:

- Text: remove one initial `#` if present. Length 3/4 doubles each character;
  resulting length must be 6/8, otherwise `E_DRAW_COLOR` with
  "Color.hex: expected #rgb, #rgba, #rrggbb, or #rrggbbaa". Each two-character
  channel is parsed in base 16, case insensitive. Besides two hex digits, the
  native integer parser accepts a hex digit followed by `_` as that single
  digit (e.g. `f_0000` is RGB 15,0,0). A leading underscore, sign or any other
  character fails with `E_DRAW_COLOR` ("Color.hex: invalid hexadecimal digit").
  Alpha defaults to 255. No whitespace trimming or named colors.
- Vec3: finite-check components named `red`, `green`, `blue`, then convert
  each through the unclamped-input byte path below; alpha is 255.
- List of exactly four elements: number-convert and finite-check each channel
  named `color`, then use the unclamped-input path, including alpha.

Every other kind, including Vec4 and lists of another length, is `E_TYPE`
("A color is hex text, vec3 or (list r g b a)."). Parsing does not first
coerce a Vec4 into a List. A color returned to Lisp is normalized by dividing
bytes by 255: Vec3 when alpha is 255, otherwise a four-Float List. `color/hsla`
always returns the four-Float List, even for opaque alpha.

`color/byte` has a static conversion mode chosen by the compiler:

1. **Clamped input** (HSL): clamp the finite channel to [0,1], multiply by 255,
   add 0.5, truncate toward zero, then clamp the integer to [0,255].
2. **Unclamped input** (Vec3/List color): multiply the finite channel by 255,
   add 0.5, perform the native Apple-Silicon float-to-integer conversion, then
   clamp the resulting signed 63-bit integer to [0,255]. It is not the checked
   `int` leaf. The intermediate double may overflow: truncate toward zero and
   saturate to signed 64-bit bounds, then keep the low 63 bits and interpret
   them as signed; NaN converts to zero. Positive overflow/infinity therefore
   becomes -1, negative overflow/infinity becomes zero. The input finite check
   still rejects an authored non-finite channel before this conversion.

For example native `Color.of_floats 1e20 (-1e20) 0.5 1.` is RGBA 0,0,128,255;
clamping inputs first would incorrectly make its red channel 255. This mode
also preserves ordinary slightly negative values and half-byte rounding.
JavaScript implements the signed conversion using BigInt after double
arithmetic, then `BigInt.asIntN(63, ...)`, with explicit saturation at +/-2^63.
This is a color leaf parameter, not an extra numeric language operator.

`value/hsv` is a compiler expansion, with hue in turns and no saturation/value
clamp or byte quantization. Set h to
`remainder(remainder(h,1)+1,1)`, i to trunc(floor(h*6)), and f to h*6-float(i).
Set p=v*(1-s), q=v*(1-f*s), t=v*(1-(1-f)*s). The i mod 6 sectors select
`(v,t,p)`, `(q,v,p)`, `(p,v,t)`, `(p,q,v)`, `(t,p,v)`, `(v,p,q)` in order.
Return Vec3 and finite-check its final channels named `value/hsv`.
`value/lerp` evaluates a,b,u once and computes `a*(1-u)+b*u`, retaining that
arithmetic order, returning Float or Vec3. A scalar partner broadcasts to
Vec3. Native Vec2/4 operands are unsupported here (`E_TYPE`), despite the
broader vector arithmetic contract. It does not clamp u; final components
are finite-checked named `value/lerp`. Neither expansion becomes a target leaf.

## Text, display and equality

Text values retain decoded contents, with no quoting, escaping, Unicode
normalization, case folding or trimming at runtime. `str` evaluates its
arguments in order, concretizes each, applies `show` and joins the results
with no separator. The exporter must preserve text contents through its
JavaScript string encoding; a value it cannot encode losslessly requires a
located refusal, not replacement characters. Text never enters a region.

| Value kind | `show` result |
| --- | --- |
| Int | Full signed base-10 integer, no exponent or floating conversion. |
| Float | The display-number rule below. |
| Bool | `true` or `false`. |
| Text | Its contents, without quotes. |
| Vec2/3/4 | `[` followed by display-formatted components separated by one space, then `]`. |
| List | `[` followed by recursively shown elements separated by one space, then `]`; empty is `[]`. |
| Record | `{` followed by ordered `:name value` pairs separated by one space, then `}`; empty is `{}`. |
| Packed array | Element count, space, multiplication sign, space, element name, e.g. `12 × vec3`. Storage component count is divided by width. |
| Residual in a diagnostic/debug display | `?`; frame program values are concretized before normal display. |
| Other native value | Its type spelling, e.g. `geometry`, `image`, `drawing`, `sample`, `fn`; this does not make the value legal for web export. |

Display-number formatting follows the actual `Value.show_with` implementation,
not the shorter intent comment in `value.ml` and not `Flow.Lisp.float`:

1. NaN displays `NaN`, positive/negative infinity `Infinity` / `-Infinity`.
   These spellings make debug display total; they do not allow non-finite
   numeric inputs or literals into a checked frame.
2. For a finite x, take its absolute binary64 magnitude. Format that magnitude
   to exactly 40 fractional decimal places with nearest-even rounding. A tie
   flag is true when fractional digit 5 is `5` and fractional digits 6..40
   are all zero (digits are counted starting at 1).
3. If flagged, add the binary64 value `1e-6` to the magnitude, rounding that
   addition to binary64. Otherwise retain the magnitude. Format the resulting
   double to exactly four fractional decimal places with nearest-even
   rounding, with a fixed decimal point and no exponent.
4. Remove trailing fractional zeroes and then an empty decimal point. Prefix
   `-` only when x<0 and the trimmed result is not `0`. Both signed zeros and
   a negative value rounded to zero display `0`.

A target can implement the fixed-format steps from the exact binary64 ratio:
decode sign/exponent/mantissa, scale the non-negative ratio by 10^places,
divide as integers, and increment the quotient if remainder exceeds half the
denominator, or equals half with an odd quotient. Decimal padding supplies
the specified fractional width. BigInt supplies these fixed-format steps in
JavaScript; Number supplies the intervening `+ 1e-6` exactly as above. Plain
`toFixed(4)`, `Math.round(x*10000)` or conversion back through Number is not a
complete implementation: large values switch to exponent notation, and the
native tie adjustment can disappear below an ULP.

Examples verified against the native implementation:

| Float | Display |
| --- | --- |
| `0.03125` | `0.0313` |
| `-0.03125` | `-0.0313` |
| `17179869184.03125` | `17179869184.0312` (the 1e-6 tie adjustment rounds away) |
| `1e21` | `1000000000000000000000` |
| `-0.0` | `0` |
| `0.00005` | `0.0001` |

Source-number printing remains separate: `Flow.Lisp.float` tries 15, 16,
then 17 significant digits until the result reads back as the same double,
expands any exponent to fixed decimal notation, and supplies a dot (`1.0`,
not `1`). Non-finite source-print input is `0.0`; a writer that needs to reject
it must do so before printing. Displaying `1.0` gives `1`; writing that
Float back to Lisp gives `1.0`. Neither printer is a reason to change the
other's contract.

`equal?` is typed structural equality, with no scalar numeric coercion.
Reactive fields in a captured list or record are concretized before comparison;
the evaluator's residual representation is never an equality operand.
Int 1 and Float 1.0 are unequal; Bool true and Int 1 are unequal. Floats compare
numerically within their Float tag, so positive and negative zero are equal;
NaN is unequal to itself. Vectors must have the same width and equal ordered
components. Lists/packed arrays must have the same value kind, element layout,
length and equal ordered elements/components. Records must have the same
ordered names and equal values: swapping two field pairs changes equality.
Text compares exact contents, not a collation order. Admissible finite core
data needs no pointer-identity rule. Native function comparison can fail with
`E_TYPE` ("Functions cannot be compared."); exported/core stored data does
not contain callable values. `=` and `case` numeric matching use the separate
numeric conversion rule, rather than substituting `equal?`.

## Region form

The initial body is exactly today's `Flow_ir.Packed.instruction` set, not a
new collection of shader operations:

| Instruction | Meaning |
| --- | --- |
| `Const(value)` | One numeric constant. |
| `Input(source,width,component)` | One component of the current element of a source array. |
| `Uniform(index,component)` | One component of a captured scalar/vector, forced once before dispatch. |
| `Frame(name)` | A numeric frame fact captured from the immutable input snapshot. |
| `Accumulator(component)` | One component of the prior accumulator; prevents independent GPU execution. |
| `Binary(op,a,b)` | A binary leaf over prior scalar slots. |
| `Unary(op,a)` | A unary leaf over a prior scalar slot. |
| `Noise3(x,y,z,seed,octaves)` | A seeded numeric sample; seed and octaves satisfy packed qualification. |
| `Select(condition,yes,no)` | Eagerly computed branch slots, selecting by condition unequal to zero. |

The binary set is `Add Sub Mul Div Mod Pow Min Max Lt Le Gt Ge Eq And Or`;
the unary set is `Sin Cos Sqrt Abs Not`. Booleans occupy numeric slots, vectors
occupy ordered groups of scalar slots, and instructions refer only to earlier
slots. The register limit is 64. A region carries its sources and widths,
`Zip` or `Product` iteration, captured uniforms, count/origin, skipped tuples,
result mode (`Collect`, `Sum`, or seeded `Accumulate`, with optional collection)
and output slots. Zip uses the shortest input; product uses source-order
strides. No inputs means no iterations. Outputs become an ordered list of
slot groups when several attributes are fused, with an explicit width for
each group. A single-output region keeps the existing instruction spelling.

Fusion may combine equal-count/equal-origin elementwise producers and several
outputs, with provenance retained. It declines when qualification or register
limits fail; it must not turn a valid unfused program into an error. Static
outputs may be retained independently from frame-rate outputs. Placement is
target legality plus measured cost, never a backend environment selector.

The existing `E_PACKED_*` refusals and their spans survive lowering. GPU
qualification also excludes ordered accumulators, unsupported noise settings,
non-finite/unrepresentable constants and disallowed forms. The web target adds
its device-limit and in-frame-readback checks; their limits are established
from the WebGPU specification in P5.4, not guessed here. An exact consumer
cannot secretly read a GPU buffer back during a browser frame.

## State slots and frame facts

A state-slot descriptor has the evaluator's graph instance, lexical
`prefix @ zone` path, iteration tuple and state plane. Numbering a slot does
not replace this identity. Native state keeps the existing serialized key so
`fork_state`, scrubbing and document transactions keep working.

At a new logical frame, the prior pending values merge into the before-state,
and pending writes clear. A state read uses that before-state or evaluates its
initializer if absent. The first write computes and coerces the step; later
reads of that state in the same frame return the same pending result. The
native host plane advances by input `tick`; the drawing plane advances by
`frame`. A changed source or a backwards frame resets the plane. A failed
document/frame transaction restores its complete prior state. Browser program
reload resets all slots, while keeping the canvas.

Stored state is data, recursively: no functions, deferred geometry, images,
drawings, layouts or other deferred nodes. Core lowering keeps call and loop
identity, including skipped iterations, instead of keying state by a transient
statement index alone.

Frame input is an intrinsic read of one immutable `Frame_input.t` snapshot:
`t`, `dt`, `frame`, `tick`, logical `size`, logical `pointer`, held `buttons`,
held `keys`, and ordered `events`. The Lisp `frame/input` view has `t`, `dt`,
`index`, `width`, `height`, `pointer`, `buttons`, `keys`, `events`; it does not
rename the host's internal `tick` into a Lisp field. Event records have the
fixed field layout from `Flow.Op.event_fields`, with empty/zero defaults for
fields absent in an event. Coordinates remain logical points. Device-pixel
conversion belongs only to the presenter.

## Drawing statements and intrinsics

The frame produces a painter-ordered mark table. A drawing statement names
its kind, count, attribute edges, constant or buffer attributes, and view
transform. Simple marks are rects, circles, lines and points; other entries
are images, whole-string text runs and nested transform/clip boundaries.
Transforms do not get baked into per-instance attributes. Per-instance size,
radius and color are present from the first contract, not only uniform styles.

The core preserves all existing draw operators. `draw/background` is a filled
canvas rectangle; `draw/merge` appends its inputs in order. `draw/translate`
uses the existing integer coordinate conversion, while rotation is radians
and scale is scalar or two components of a Vec3. Point/text/image positions
also use their existing integer conversion; packed rect/circle/line positions
remain floating point. Default ink is white, default circle radius is 1,
default line width is 1, and a rect/circle with neither fill nor stroke gets
white fill. A text run defaults to size 16; empty text emits no entry. An image
defaults to origin, scale 1 and angle 0; its scale is positive and finite.

Rounded rectangles and polygon/polyline paths retain their existing integer
coordinate, tessellation and stroke behavior. Their lowering must reuse pure
`Scene_command.Shape2` geometry (including indexed fill triangles and stroke
geometry) and carry it through the drawing contract; replacing a path with
overlapping analytic primitives would change translucent pixels. P3.2 must
include the geometry entry needed by P3.6 and its native serialization oracle.
No target reimplements tessellation or rasterizes these paths on a CPU.

`E_DRAW_LENGTH` guards all per-instance attribute cardinalities; missing
inputs are `E_DRAW_INPUT`, unknown draw kinds are `E_DRAW_KIND`, and invalid
coordinates/transforms are `E_DRAW_RANGE`. Color decoding keeps
`E_DRAW_COLOR` and its type errors. A count is an element count in every
attribute buffer. Resource entries resolve through an owned host resource
table; they never silently disappear when a resolver is absent.

| Intrinsic | Native target | Web target |
| --- | --- | --- |
| Frame input | Reads the captured logical snapshot. | Reads the translated DOM-event snapshot, with the same Lisp field layout. |
| Image load | Environment-owned SDL image decoding. | Browser image decoding, owned texture and linear sampling; unavailable assets fail explicitly. |
| Image noise | Seeded numeric image producer with owned image storage. | Shared numeric lowering/regions and an owned texture, preserving dimensions and channel layout. |
| Image map | Checked Vec2-to-Vec4 numeric producer over image dimensions. | The same region producer, placed for workers or WebGPU; no per-pixel target interpreter. |
| Text | Rasterizes the whole string with the native font service and presents the texture. | Rasterizes the whole string on a device-scaled text canvas and presents the texture. Font/pixel differences are tested under the browser qualification tolerance. |
| Host quit | The host's conditional quit effect. | Refused when reached: a browser page has no native application quit operation. |
| Host dialog | Native conditional dialog and its ordered result events. | Refused when reached: no native file/folder dialog contract. |
| Host save PNG | Conditional file write through the host. | Refused when reached: a browser download does not satisfy the named-file effect contract. |
| Host play / audio synth / audio load | Owned SDL audio resources, synth settings and conditional playback. | Refused when reached until this target has an explicit audio implementation; never a no-op. |
| Scene, SOP, world, material, PXUI/editor or unknown nominal operation | Remains in its existing native subsystem. | Refused if it contributes to the selected draw program. An unrelated native graph in the workspace does not block export. |

Legality is checked after selecting the draw roots and pruning unreachable
work. A pure data field obtained from a host-context graph is legal if its
actual dependencies are legal. Encountering an unsupported intrinsic is a
source-located refusal even if its run-time condition is currently false;
only a statically pruned branch is absent from the program. A corpus workspace
is either fully represented by its selected draw program or refused, never
partially exported to make a coverage count pass.

## Census rule table

P0.1 at `de565589` parses 45 files and identifies 15 structurally eligible draw
workspaces. It counts 114 distinct authored heads in draw/host/image/value
graphs and all definition/macro bodies. This includes function parameter
calls, macro templates and SOP definitions unused by a draw graph; it is not
the exported dependency closure. Counts change with authored source, but each
head must have its own row here. `primitive` refers to the inventory above;
`compiler rule` names its leaves/control, `region` names the packed numeric
form, `intrinsic` names a host boundary, and `refused on web` forbids a reached
operation. A user function/macro row is not a new runtime primitive.

| Head | Rule | Lowering / leaves |
| --- | --- | --- |
| `*` | primitive | `*` |
| `+` | primitive | `+` |
| `-` | primitive | `-` |
| `/` | primitive | `/` |
| `<` | primitive | `<` |
| `=` | primitive | `=` |
| `>` | primitive | `>` |
| `>=` | primitive | `>=` |
| `abs` | primitive | `abs` |
| `add-point` | compiler rule | Inline its checked body: `array/concat`, `array/vec3`, `assoc` field lowering, `+`, coercion. |
| `and` | primitive | `and`; eager arguments. |
| `array/concat` | primitive | `array/concat` |
| `array/count` | primitive | `array/count` |
| `array/nth` | primitive | `array/nth` |
| `array/range` | primitive | `array/range` |
| `array/slice` | primitive | `array/slice` |
| `array/vec3` | primitive | `array/vec3` |
| `assoc` | compiler rule | Ordered static field-local replacement/appending and `coerce`. |
| `audio/synth` | refused on web | Native audio-resource intrinsic; do not fabricate a sample id. |
| `case` | compiler rule | One scrutinee local, branches, `=`, `equal?`, `truthy`. |
| `ceil` | primitive | `ceil` |
| `color/gradient` | compiler rule | `color/parse`, `sequence/length`, `sequence/get`, `min`, `max`, `int`, `+`, `-`, `*`, `/`, branch and `fail`. |
| `color/hsl` | compiler rule | `remainder`, `min`, `max`, `abs`, `+`, `-`, `*`, `/`, `<`, `color/byte` and branches. |
| `concat` | compiler rule | Ordered `sequence/concat` and joined-element `coerce`. |
| `cond` | compiler rule | Ordered tests and branches through `truthy`. |
| `core` | compiler rule | Expand the macro; numeric leaves `let*`, `pow`, `mod`, `abs`, `+`, `-`, `*`, `/`, `max`. |
| `cos` | primitive | `cos` |
| `count` | compiler rule | `sequence/length` |
| `double` | compiler rule | Inline the checked definition: `*` and argument `coerce`. |
| `draw/background` | compiler rule | `color/parse`, frame size, rectangle drawing entry. |
| `draw/circle` | compiler rule | Radius/position locals, `color/parse`, circle entry, defaults. |
| `draw/circles` | compiler rule | Packed attribute edges, `array/count`, `color/parse`, checked circle mark set. |
| `draw/image` | intrinsic | Image-resource entry with checked transform; source image producer is lowered separately. |
| `draw/lines` | compiler rule | Packed endpoint/width/color edges, `array/count`, checks, line mark set. |
| `draw/merge` | compiler rule | Ordered drawing-entry concatenation, flattening drawing lists. |
| `draw/points` | compiler rule | Packed positions, `array/count`, integer point conversion, color, point entries. |
| `draw/rect` | compiler rule | Position/size locals, `color/parse`, rectangle entry, defaults. |
| `draw/rects` | compiler rule | Constant or packed size/color edges, `array/count`, checks, rectangle mark set. |
| `draw/rotate` | compiler rule | `fail` on non-finite angle, view-transform push/body/pop. |
| `draw/rounded_rect` | compiler rule | Integer position/size/radius, shared pure path geometry, drawing entry. |
| `draw/scale` | compiler rule | Scalar/component locals, `fail` on non-finite factors, view push/body/pop. |
| `draw/text` | intrinsic | `color/parse`, integer position/size, whole-string text entry. |
| `draw/translate` | compiler rule | Checked integer coordinate conversion, view push/body/pop. |
| `equal?` | primitive | `equal?` |
| `exact` | compiler rule | Identity precision boundary; web placement refuses an in-frame GPU readback. |
| `exp` | primitive | `exp` |
| `filter` | compiler rule | Inline predicate, ordered loop, `truthy`, `sequence/get`, `sequence/build`, copying retained items. Packed output retains packed layout. |
| `finish` | compiler rule | Inline checked definition: ordered field updates, `array/concat`, `array/vec3`, list access/build, `coerce`, branches. |
| `floor` | primitive | `floor` |
| `fn` | compiler rule | Specialize and inline the checked body at each call site; retain capture and call identity. |
| `fold` | region | Numeric packed seeded accumulator; otherwise bounded sequential frame loop with `coerce` and accumulator widening. |
| `for` | region | Numeric packed product/collect; otherwise bounded frame product loop with sequence build and access. |
| `frame/dt` | intrinsic | Snapshot Float `dt`. |
| `frame/height` | intrinsic | Snapshot logical size height, as Int. |
| `frame/index` | intrinsic | Snapshot Int `frame`. |
| `frame/input` | intrinsic | Snapshot record with the Lisp frame/event field layouts. |
| `frame/width` | intrinsic | Snapshot logical size width, as Int. |
| `get` | compiler rule | Static ordered record field/component read, `fail` for `E_FIELD`. |
| `glyph` | compiler rule | Expand macro to image region and draw image entry; `noise3`, arithmetic, comparisons, branches. |
| `grad` | compiler rule | Expand gradient macro: `+`, `-`, `*`, component reads. |
| `half` | compiler rule | Inline definition: `/` and argument `coerce`. |
| `haze` | compiler rule | Expand image-body macro: `pow`, `mod`, `max`, `+`, `-`, `*`, `/`. |
| `host/dialog` | refused on web | Native conditional dialog intrinsic and result-event boundary. |
| `host/play` | refused on web | Native conditional sample-playback intrinsic. |
| `host/quit` | refused on web | Native conditional quit intrinsic. |
| `host/save_png` | refused on web | Native conditional file-write intrinsic. |
| `if` | compiler rule | `truthy` and one selected structured branch. |
| `image/map` | region | Checked Vec2-to-Vec4 pixel body, explicit width/height and image-resource result. |
| `image/noise` | intrinsic | Seeded numeric image producer; lower its numeric work to the shared core/regions. |
| `inside` | compiler rule | Inline checked definition: component reads, `>=`, `<`, `+`, `and`. |
| `int` | primitive | `int` |
| `int/and` | primitive | `int/and` |
| `int/div` | primitive | `int/div` |
| `int/mod` | primitive | `int/mod` |
| `int/mul` | primitive | `int/mul` |
| `int/xor` | primitive | `int/xor` |
| `key/down` | compiler rule | Frame keys, ordered text membership with `sequence/length`, `sequence/get`, `equal?`. |
| `let*` | compiler rule | Ordered assignments, pattern reads and `coerce`. |
| `lines` | compiler rule | Expand contour macro to image region: `noise3`, arithmetic, `mod`, comparisons and branches. |
| `list` | compiler rule | Fresh `sequence/build`, ordered element stores and joined-layout `coerce`. |
| `make` | compiler rule | Specialize the callable parameter of `ring` and inline its checked body; SOP instantiations are refused on web. |
| `map` | region | Numeric packed zip/collect; otherwise inline body in bounded frame zip loop with sequence access/build. |
| `max` | primitive | `max` |
| `min` | primitive | `min` |
| `mod` | primitive | `mod` |
| `noise3` | primitive | `noise3`; also the region `Noise3` instruction. |
| `not` | primitive | `not` |
| `nth` | compiler rule | Checked index conversion, `sequence/get`; preserve `E_LIST_RANGE`. |
| `or` | primitive | `or`; eager arguments. |
| `palette-color` | compiler rule | Inline checked definition: `int/mul`, `int/and`, `int/xor`, `int/div`, `int/mod`, arithmetic, comparisons, branches and the `color/hsl` lowering. |
| `panel` | compiler rule | Expand shader macro to ordered image entries and pixel regions using its constituent macros. |
| `pointer/x` | intrinsic | Snapshot logical pointer x, as Float. |
| `pointer/y` | intrinsic | Snapshot logical pointer y, as Float. |
| `pow` | primitive | `pow` |
| `range` | compiler rule | Checked bounded count, `sequence/build`, integer induction locals; start inclusive, end exclusive. |
| `ref` | compiler rule | Checked graph specialization/sharing, input `coerce`; refuse a reached native-only context. Native lowering inlines the body of a `ref` without overrides in the graph's cached default instance (state keys are the graph's own, so every reference shares them); a `ref` with overrides is refused by name. |
| `rest` | compiler rule | `sequence/length`, `sequence/slice`, with an empty-list identity. |
| `reverse` | compiler rule | Ordered loop, `sequence/build`, `sequence/get` at length minus one minus index. |
| `rim` | compiler rule | Expand image-body macro: `pow`, `mod`, `abs`, `max`, arithmetic. |
| `ring` | compiler rule | Expand the shader macro or specialize the checked definition at its resolved call site; an instantiated SOP body is refused on web. |
| `scheme-hash` | compiler rule | Inline checked definition: `int/mul`, `int/and`, numeric conversion. |
| `sin` | primitive | `sin` |
| `sop/box` | refused on web | A geometry factory in a definition counted by the census, outside the 2D target. |
| `sop/merge` | refused on web | Native geometry composition; not a numeric sequence operation. |
| `sop/transform` | refused on web | Native geometry transform; not a drawing view transform. |
| `sop/uv_sphere` | refused on web | Native geometry factory. |
| `split-level` | compiler rule | Inline checked definition: packed slices/concatenation, nested maps, `value/rand`, arithmetic and numeric branches. |
| `sqrt` | primitive | `sqrt` |
| `state` | compiler rule | Identified state-slot read, init/step, `coerce`, transactional write. |
| `str` | compiler rule | Ordered `show` calls and `text/concat`. |
| `take` | compiler rule | Clamp count, `sequence/length`, `sequence/slice`. |
| `value/polar` | compiler rule | `*`, `cos`, `sin`, vector construction with optional height. |
| `value/rand` | primitive | `value/rand` |
| `values` | compiler rule | Static ordered record construction/field locals, used by a counted SOP definition. |

## Verification and sources

P0.6 checks this table against the live census. P0.R checks the primitive count
and semantics. The migration then proves native execution against the tree
walker, region instruction snapshots and unchanged Metal goldens, native draw
serialization snapshots, and native pixels. Web primitives have native-output
fixtures; CPU frames compare exact structure and attributes within 1e-6 over
120 fixed-step frames. Browser pixels and native/web performance have separate
qualification and measurement gates. A green scalar test cannot substitute for
those whole-program and presenter gates.

The source contracts read for this specification are `lib/flow/value.ml`
(arithmetic, coercions, display and arrays), `lib/flow/op.ml` (operators and
frame/event records), `lib/flow/eval.ml` (control, function identity and state),
`lib/flow/workspace.ml` (static count/type restrictions),
`lib/flow_ir/packed.ml` and `packed.mli` (regions and refusal codes),
`lib/flow_ir/operators.ml` (noise and colors), `lib/rays_math/color.ml`,
`noise.ml`, `rand.ml`, and `lib/rays_editor/drawing.ml` / `lib/rays/scene.ml`
(drawing defaults and coordinate conversion). The runnable census is
`dune build tools/core_census.exe && _build/default/tools/core_census.exe`.
