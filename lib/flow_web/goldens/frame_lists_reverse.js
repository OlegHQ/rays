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
  K ??= [-1000, 1n, 2n, 1n, 1n, 2n, 1n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; l4 = input.t;
      at = 5; l5 = K[1];
      at = 6; l6 = K[2];
      at = 7; l7 = rt.sequence_concat([l4], [l5], [l6]);
      at = 8; l8 = rt.sequence_length(l7);
      at = 9; l9 = rt.sequence_build(l8);
      at = 10; {
        const s10 = l7, c10 = Array.isArray(s10) ? s10.length : Number(rt.array_count(s10));
        if (c10 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i10 = 0; i10 < c10; i10++) {
          l10 = BigInt(i10); l11 = Array.isArray(s10) ? s10[i10] : rt.array_nth(s10, i10);
          at = 11; l12 = K[3];
          at = 12; l13 = rt.sub(l8, l12);
          at = 13; l14 = rt.sub(l13, l10);
          at = 14; store(rt, l9, l14, l11);
        }
      }
      at = 15; l3 = l9;
    } else {
      at = 16; l15 = input.t;
      at = 17; l16 = K[4];
      at = 18; l17 = K[5];
      at = 19; l18 = rt.sequence_concat([l15], [l16], [l17]);
      at = 20; l19 = rt.sequence_length(l18);
      at = 21; l20 = rt.sequence_build(l19);
      at = 22; {
        const s22 = l18, c22 = Array.isArray(s22) ? s22.length : Number(rt.array_count(s22));
        if (c22 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i22 = 0; i22 < c22; i22++) {
          l21 = BigInt(i22); l22 = Array.isArray(s22) ? s22[i22] : rt.array_nth(s22, i22);
          at = 23; l23 = K[6];
          at = 24; l24 = rt.sub(l19, l23);
          at = 25; l25 = rt.sub(l24, l21);
          at = 26; store(rt, l20, l25, l22);
        }
      }
      at = 27; l3 = l20;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
