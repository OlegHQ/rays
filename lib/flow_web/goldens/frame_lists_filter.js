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
  K ??= [-1000, 8n, 0n, 0n, 8n, [0n, 1n, 2n, 3n, 4n, 5n, 6n, 7n], 1n, 0n, 0n, 0n, 8n, 0n, 0n, 8n, [0n, 1n, 2n, 3n, 4n, 5n, 6n, 7n], 1n, 0n, 0n, 0n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25, l26, l27, l28, l29, l30, l31;
  let l32, l33, l34, l35, l36, l37, l38, l39, l40, l41, l42, l43, l44, l45;
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
          at = 16; l17 = rt.gt(l14, l16);
          at = 17; if (rt.truthy(l17)) {
            at = 18; store(rt, l5, l7, l14);
            at = 19; l19 = K[6];
            at = 20; l20 = rt.add(l7, l19);
            at = 21; l7 = l20;
            at = 22; l21 = K[7];
            at = 23; l18 = l21;
          } else {
            at = 24; l22 = K[8];
            at = 25; l18 = l22;
          }
        }
      }
      at = 26; l23 = K[9];
      at = 27; l24 = rt.sequence_slice(l5, l23, l7);
      at = 28; l3 = l24;
    } else {
      at = 29; calls[1] = 0;
      at = 30; l25 = K[10];
      at = 31; l26 = rt.sequence_build(l25);
      at = 32; l27 = K[11];
      at = 33; l28 = l27;
      at = 34; l29 = K[12];
      at = 35; l30 = K[13];
      at = 36; {
        const f36 = rt.coerce("int", l29), e36 = rt.coerce("int", l30), n36 = e36 > f36 ? e36 - f36 : 0n;
        if (n36 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l31 = n36;
        for (let i36 = 0, c36 = Number(n36); i36 < c36; i36++) {
          const j36 = BigInt(i36); l32 = j36; l33 = f36 + j36;
          at = 37; l34 = K[14];
          at = 38; l35 = rt.sequence_get(l34, l33);
          at = 39; l36 = BigInt(calls[1]++);
          at = 40; l37 = input.t;
          at = 41; l38 = rt.gt(l35, l37);
          at = 42; if (rt.truthy(l38)) {
            at = 43; store(rt, l26, l28, l35);
            at = 44; l40 = K[15];
            at = 45; l41 = rt.add(l28, l40);
            at = 46; l28 = l41;
            at = 47; l42 = K[16];
            at = 48; l39 = l42;
          } else {
            at = 49; l43 = K[17];
            at = 50; l39 = l43;
          }
        }
      }
      at = 51; l44 = K[18];
      at = 52; l45 = rt.sequence_slice(l26, l44, l28);
      at = 53; l3 = l45;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
