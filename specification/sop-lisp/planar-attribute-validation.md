# Full planar attribute write validation

The existing full `sop/with_attr` writer now accepts exact Float-plane records
for vec2, vec3 and vec4. This is an extension of the accepted B.1 foundation,
needed by Grid's native planar normals and UVs. It accepts no whole SOP port or
new milestone: counts remain 16/128 ports and 25/60 milestones.

## Contract and shared paths

Records have exactly x/y, x/y/z or x/y/z/w, in any authored order. Concrete
fields are Float arrays. After canonical x/y/z/w cardinality checks, each
plane is finite-checked and copied into separately owned native storage. No
width-divided scalar capacity or interleaved native temporary is introduced.
Point P still requires vec3. Selected/default writes retain tuple-array values;
CSR, queries and native immutable storage transfers retain their contracts.

The existing Lower host path hydrates reached cooked Record sources in authored
order, checking cancellation and owner/type options before deferred hydration.
Host value validation still precedes the direct writer's count checks. Direct
writer malformed inputs retain count-before-finite behavior. The JavaScript
geometry protocol copies and interleaves only at its existing tuple boundary.
Its shared attribute-name check now uses existing byte-aware text_blank, fixing
NBSP/invalid-byte names across writer, query, has_attr and attr_checked callers.
SOP geometry stays outside the current 2D exporter.

## Runnable checks

Native independent plane construction checks all four owners and three widths,
0/1/6/32769 points, real 4225-point Quad geometry with 16384 vertices/4096
primitives, signed zero/subnormals/raw finite bits, untouched NaN/Text/matrix
metadata, ordered groups, canonical P and independently owned source/sibling
planes. Missing/extra/duplicate keys, wrong banks, canonical count priority,
finite errors and selected Record refusals are checked.

Actual strict/reference defnode cooks cover cooked sources, local Fn captures,
aliases, authored source ordering, repeated-child sharing, count rebinding,
lazy selected errors, all-owner source facts, component cache refresh, state
frames and geometry folds at domains 1/4/8 and grains 1/97/4096. Direct invocation
of the real structural node additionally checks Lower.call cancellation versus
invalid owner/type versus failing deferred Record fields, bypassing Session's
earlier cancellation guard. Invalid type is a marked internal typed-term
mutation; ordinary authored invalid types remain checker errors.

Graph checks cover Record/geometry cards, fields, sockets, connections, typed
atomic refusals, Add_node and save/reparse. The actual production menu inserts
and cooks the ordinary writer using its existing tuple-array defaults. Native
host fixtures compare JavaScript values and independent raw Text bytes; JS
checks source/output/sibling ownership, bank/width refusals and byte names.

## Fixed before/after measurement protocol

Machine: Apple M1 Macmini9,1, 16GiB, arm64; macOS 27.0.1 build 26A434;
OCaml 5.3.0, Dune 3.24.2, default dev profile. The frozen 175-line optional
bench_planar_attribute executable was built before writer changes. Both runs
used count 1,000,000, domains 1/4, grain 4096 and median 3. Agents were idle and no
Dune/build/timing jobs overlapped either measured run. Desktop/VM processes
remained. Fixtures, native/full-byte/error preflight, pool warmup and full-major
GC are outside timing. Each sample includes one new owned output. Allocation,
promoted and major counters cover the initial domain, not all workers or RSS.

Before 18164 EXIT0: /tmp/rays-planar-attribute-before-20261013.log.
After 86835 EXIT0: /tmp/rays-planar-attribute-after-20261013.log.
Immutable captures: /tmp/rays-planar-writer-before-20261013 (13 full-byte/error
files and 26 original timing files). The same harness used --after on that
directory without rewriting original captures. All 26 full-byte/native/domain
comparisons pass. The 18 retained rows cover full/selected tuple writers and
Float/Int CSR with exceptional untouched bytes and exact native Int bounds.
The 8 new rows compare the newly supported Record writer with independent native
plane construction; before did not time an unsupported Record call. Native
plane construction performs copying/installation without the writer's finite
validation. Retained after/before ratios range 0.872095–1.233498. New Record
writer/native-plane ratios measured in the after run range 3.282946–3.601610;
all exceed 2×.
These are direct foundation costs, not whole SOP performance gates. No whole
Grid/Circle acceptance or 2× speed claim is made. Complete tables follow.

## Final gates

Focused 19592 EXIT0: /tmp/rays-planar-attribute-focused8-20261013.log,
@check, FlowSop/FlowGraph runtest, actual native-to-JavaScript primitive checks,
production workspace shell, dependency/API gates and benchmark target build.
Native 39466 EXIT0: /tmp/rays-planar-attribute-native-20261013.log,
@runtest-native, including SOP render, workspace/runtime and export parity.
Shipping 18178 EXIT0: /tmp/rays-planar-attribute-ship-20261013.log,
@all/@runtest/@smoke and git diff --check. The final workspace sweep covers
43 standard files, 1 custom-catalog executable and 13 fixtures over four
frames at domains 1/8, comparing complete cooked payloads and render commands.

Initial 73362 found a newline-dependent printed-source assertion and an invalid
time-dependent geometry branch fixture. 12644 found reserved authored binding
name values. 45222/21039/7985/97353 exposed the checker's empty Let wrapper around
branch bodies in the malformed-host fixture; one temporary diagnostic build
also failed to unwrap Lisp.print's spans pair. The final fixture follows the
actual checked wrapper and verifies exactly one type argument is replaced.
No product branch restriction, error contract or comparison tolerance changed.


## All 18 retained writer rows

| Case | Domains | Before ms | After ms | After/before | Before bytes allocated | After bytes allocated | Before promoted/major words | After promoted/major words |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| full-vec2-attribute | 1 | 3.314018250 | 3.436088562 | 1.0368345323741006 | 16000896 | 16000896 | 0/2000002 | 0/2000002 |
| full-vec2-attribute | 4 | 1.192808151 | 1.222133636 | 1.0245852488506897 | 16048216 | 16048072 | 0/2000002 | 0/2000002 |
| full-vec3-attribute | 1 | 5.485057831 | 5.797863007 | 1.0570286012344605 | 24000888 | 24000888 | 0/3000003 | 0/3000003 |
| full-vec3-attribute | 4 | 1.896858215 | 2.058982849 | 1.0854700854700854 | 24047944 | 24050760 | 0/3000003 | 0/3000003 |
| full-vec4-attribute | 1 | 6.654977798 | 7.012844086 | 1.0537742270626589 | 32000904 | 32000904 | 0/4000004 | 0/4000004 |
| full-vec4-attribute | 4 | 2.380132675 | 2.479076385 | 1.0415706701392367 | 32047096 | 32047616 | 0/4000004 | 0/4000004 |
| full-vec3-P | 1 | 5.465984344 | 5.774974823 | 1.056529704265899 | 24000696 | 24000696 | 0/3000003 | 0/3000003 |
| full-vec3-P | 4 | 1.888990402 | 2.330064774 | 1.2334974125962388 | 24046272 | 24054632 | 0/3000003 | 0/3000003 |
| selected-retained-vec2-attribute | 1 | 4.594087601 | 4.611968994 | 1.0038922621827806 | 16001104 | 16001104 | 0/2000002 | 0/2000002 |
| selected-retained-vec2-attribute | 4 | 3.376007080 | 3.386020660 | 1.0029661016949152 | 16049776 | 16050048 | 0/2000002 | 0/2000002 |
| selected-retained-vec3-attribute | 1 | 6.165027618 | 6.371974945 | 1.0335679480238225 | 24001120 | 24001120 | 0/3000003 | 0/3000003 |
| selected-retained-vec3-attribute | 4 | 4.781961441 | 4.778862000 | 0.99935184723537918 | 24049432 | 24048976 | 0/3000003 | 0/3000003 |
| selected-retained-vec4-attribute | 1 | 7.831811905 | 8.263111115 | 1.0550701695637614 | 32001160 | 32001160 | 0/4000004 | 0/4000004 |
| selected-retained-vec4-attribute | 4 | 7.129907608 | 6.217956543 | 0.8720949673967564 | 32053520 | 32049904 | 0/4000004 | 0/4000004 |
| retained-csr-float_array | 1 | 5.495071411 | 5.497932434 | 1.0005206525511976 | 24000776 | 24000776 | 0/3000003 | 0/3000003 |
| retained-csr-float_array | 4 | 5.495786667 | 5.324125290 | 0.96876491258513731 | 24000776 | 24000776 | 0/3000003 | 0/3000003 |
| retained-csr-int_array | 1 | 6.655931473 | 6.718873978 | 1.0094566035032417 | 24000776 | 24000776 | 0/3000003 | 0/3000003 |
| retained-csr-int_array | 4 | 6.688833237 | 6.914854050 | 1.0337907681340224 | 24000776 | 24000776 | 0/3000003 | 0/3000003 |

## All 8 new Record rows versus original native planes

| Case | Domains | Before ms | After ms | After/before | Before bytes allocated | After bytes allocated | Before promoted/major words | After promoted/major words |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| new-plane-vec2-attribute | 1 | 0.480890274 | 1.706838608 | 3.5493306891422907 | 16000504 | 16001760 | 0/2000002 | 0/2000002 |
| new-plane-vec2-attribute | 4 | 0.514030457 | 1.707077026 | 3.320964749536178 | 16000504 | 16001760 | 0/2000002 | 0/2000002 |
| new-plane-vec3-attribute | 1 | 0.772953033 | 2.608060837 | 3.3741517581739666 | 24000496 | 24001944 | 0/3000003 | 0/3000003 |
| new-plane-vec3-attribute | 4 | 0.761032104 | 2.596139908 | 3.4113408521303259 | 24000496 | 24001944 | 0/3000003 | 0/3000003 |
| new-plane-vec4-attribute | 1 | 1.021862030 | 3.535032272 | 3.4594027064862343 | 32000512 | 32002440 | 0/4000004 | 0/4000004 |
| new-plane-vec4-attribute | 4 | 1.017093658 | 3.539085388 | 3.4796061884669478 | 32000512 | 32002440 | 0/4000004 | 0/4000004 |
| new-plane-vec3-P | 1 | 0.751972198 | 2.601146698 | 3.4590995561192135 | 24000336 | 24001752 | 0/3000003 | 0/3000003 |
| new-plane-vec3-P | 4 | 0.760793686 | 2.827167511 | 3.7160764650579754 | 24000336 | 24001752 | 0/3000003 | 0/3000003 |

## Native-plane costs measured in the after run for the 8 new rows

| Case | Domains | Native ms | Native allocated bytes | Writer/native |
| --- | ---: | ---: | ---: | ---: |
| new-plane-vec2-attribute | 1 | 0.486135483 | 16000504 | 3.5110348209906816 |
| new-plane-vec2-attribute | 4 | 0.473976135 | 16000504 | 3.6016096579476859 |
| new-plane-vec3-attribute | 1 | 0.751972198 | 24000496 | 3.4682942295497781 |
| new-plane-vec3-attribute | 4 | 0.755071640 | 24000496 | 3.4382696558257027 |
| new-plane-vec4-attribute | 1 | 1.026153564 | 32000512 | 3.444934944237918 |
| new-plane-vec4-attribute | 4 | 1.039981842 | 32000512 | 3.4030261348005504 |
| new-plane-vec3-P | 1 | 0.750064850 | 24000336 | 3.4678957406230135 |
| new-plane-vec3-P | 4 | 0.861167908 | 24000336 | 3.2829457364341086 |

## All 13 full-byte captures (equal at domains 1/4, before/after)

| Case | Bytes | MD5 | Error cases |
| --- | ---: | --- | ---: |
| full-vec2-attribute | 41000215 | 1fdd2e377a6f9be0e28bda3acd8e7a80 | 3 |
| full-vec3-attribute | 49000220 | 89fa2bbc13a903410a5d6578a6ec38ce | 3 |
| full-vec4-attribute | 57000225 | e4fc3570562dcbbb3c865c034ce00883 | 3 |
| full-vec3-P | 25000162 | 7905ab7b0356b85eb5ccb5721dcff460 | 3 |
| selected-retained-vec2-attribute | 41000215 | 7bfd03dccdd05f43499a1b867a670c96 | 4 |
| selected-retained-vec3-attribute | 49000220 | 87becbd80ca14dc60bff6a7832038603 | 4 |
| selected-retained-vec4-attribute | 57000225 | 3f2894504929083bdcc2a6de3475a6ba | 4 |
| retained-csr-float_array | 45967358 | f8a666850eb337492b9fb4cf9e722a2e | 3 |
| retained-csr-int_array | 40850499 | 6963de623aac5107b0f8e2a51700f405 | 2 |
| new-plane-vec2-attribute | 41000215 | 1fdd2e377a6f9be0e28bda3acd8e7a80 | 0 |
| new-plane-vec3-attribute | 49000220 | 89fa2bbc13a903410a5d6578a6ec38ce | 0 |
| new-plane-vec4-attribute | 57000225 | e4fc3570562dcbbb3c865c034ce00883 | 0 |
| new-plane-vec3-P | 25000162 | 7905ab7b0356b85eb5ccb5721dcff460 | 0 |
