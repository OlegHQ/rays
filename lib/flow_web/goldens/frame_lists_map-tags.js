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
  K ??= [-1000, 3n, 0n, 0n, 3n, [0n, 1n, 2n], 0, 3n, 0n, 0n, 3n, [0n, 1n, 2n], 0];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25, l26, l27, l28, l29, l30, l31;
  let l32, l33, l34, l35, l36, l37, l38, l39;
  let at = 0;
  const calls = new Int32Array(2);
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; calls[0] = 0;
      at = 5; l4 = K[1];
      at = 6; l5 = rt.sequence_build(l4);
      at = 7; l6 = K[2];
      at = 8; l7 = l6;
      at = 9; l8 = K[3];
      at = 10; l9 = K[4];
      at = 11; {
        const f11 = rt.coerce("int", l8), e11 = rt.coerce("int", l9), n11 = e11 > f11 ? e11 - f11 : 0n;
        if (n11 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l10 = n11;
        for (let i11 = 0, c11 = Number(n11); i11 < c11; i11++) {
          const j11 = BigInt(i11); l11 = j11; l12 = f11 + j11;
          at = 12; l13 = K[5];
          at = 13; l14 = rt.sequence_get(l13, l12);
          at = 14; l15 = BigInt(calls[0]++);
          at = 15; l16 = input.t;
          at = 16; l17 = K[6];
          at = 17; l18 = rt.gt(l16, l17);
          at = 18; if (rt.truthy(l18)) {
            at = 19; l19 = l14;
          } else {
            at = 20; l20 = rt.float(l14);
            at = 21; l19 = l20;
          }
          at = 22; store(rt, l5, l12, l19);
        }
      }
      at = 23; l21 = rt.sequence_concat(l5);
      at = 24; l3 = l21;
    } else {
      at = 25; calls[1] = 0;
      at = 26; l22 = K[7];
      at = 27; l23 = rt.sequence_build(l22);
      at = 28; l24 = K[8];
      at = 29; l25 = l24;
      at = 30; l26 = K[9];
      at = 31; l27 = K[10];
      at = 32; {
        const f32 = rt.coerce("int", l26), e32 = rt.coerce("int", l27), n32 = e32 > f32 ? e32 - f32 : 0n;
        if (n32 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l28 = n32;
        for (let i32 = 0, c32 = Number(n32); i32 < c32; i32++) {
          const j32 = BigInt(i32); l29 = j32; l30 = f32 + j32;
          at = 33; l31 = K[11];
          at = 34; l32 = rt.sequence_get(l31, l30);
          at = 35; l33 = BigInt(calls[1]++);
          at = 36; l34 = input.t;
          at = 37; l35 = K[12];
          at = 38; l36 = rt.gt(l34, l35);
          at = 39; if (rt.truthy(l36)) {
            at = 40; l37 = l32;
          } else {
            at = 41; l38 = rt.float(l32);
            at = 42; l37 = l38;
          }
          at = 43; store(rt, l23, l30, l37);
        }
      }
      at = 44; l39 = rt.sequence_concat(l23);
      at = 45; l3 = l39;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
