// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
const store = (rt, s, index, value) => {
  const i = Number(rt.coerce("int", index));
  if (s instanceof rt.TextArray) {
    if (i < 0 || i >= s.data.length) rt.fail("E_LIST_RANGE", "Core store is outside its sequence.");
    if (typeof value !== 'string') rt.fail("E_ARRAY_TYPE", "Text arrays contain text values.");
    s.data[i] = value;
  } else if (s instanceof rt.PArray) {
    const n = s.data.length / s.width;
    if (i < 0 || i >= n) rt.fail("E_LIST_RANGE", "Core store is outside its sequence.");
    if (s.data instanceof BigInt64Array) {
      if (typeof value !== 'number' && typeof value !== 'bigint' && typeof value !== 'boolean')
        rt.fail("E_ARRAY_TYPE", "Packed integer arrays contain integer values.");
      s.data[i] = rt.coerce("int", value);
      return;
    }
    const comps = value instanceof Float64Array ? value : Array(s.width).fill(rt.float(value));
    if (comps.length !== s.width) rt.fail("E_ARRAY_TYPE", "Packed array element has the wrong vector width.");
    for (let j = 0; j < s.width; j++)
      s.data[i * s.width + j] = Number.isFinite(comps[j]) ? comps[j] : rt.fail("E_NONFINITE", "array produced a nonfinite value.");
  } else {
    if (i < 0 || i >= s.length) rt.fail("E_LIST_RANGE", "Core store is outside its sequence.");
    s[i] = value;
  }
};
export function frame(input, state, rt) {
  K ??= [-1000, 0n, 0n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; l4 = input.t;
      at = 5; l5 = K[1];
      at = 6; {
        const f6 = rt.coerce("int", l5), e6 = rt.coerce("int", l4), n6 = e6 > f6 ? e6 - f6 : 0n;
        if (n6 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l6 = n6;
        at = 7; l9 = rt.sequence_build(l6);
        for (let i6 = 0, c6 = Number(n6); i6 < c6; i6++) {
          const j6 = BigInt(i6); l7 = j6; l8 = f6 + j6;
          at = 8; store(rt, l9, l7, l8);
        }
      }
      at = 9; l3 = l9;
    } else {
      at = 10; l10 = input.t;
      at = 11; l11 = K[2];
      at = 12; {
        const f12 = rt.coerce("int", l11), e12 = rt.coerce("int", l10), n12 = e12 > f12 ? e12 - f12 : 0n;
        if (n12 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l12 = n12;
        at = 13; l15 = rt.sequence_build(l12);
        for (let i12 = 0, c12 = Number(n12); i12 < c12; i12++) {
          const j12 = BigInt(i12); l13 = j12; l14 = f12 + j12;
          at = 14; store(rt, l15, l13, l14);
        }
      }
      at = 15; l3 = l15;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
