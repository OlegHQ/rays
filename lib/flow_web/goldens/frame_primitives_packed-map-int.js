// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
const store = (rt, s, index, value) => {
  const i = Number(rt.coerce("int", index));
  if (s instanceof rt.PArray) {
    const n = s.data.length / s.width;
    if (i < 0 || i >= n) rt.fail("E_LIST_RANGE", "Core store is outside its sequence.");
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
  K ??= [-1000, 5000n, 3n, 0n, 0n, 0n, 5000n, 3n, 0n, 0n, 0n];
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
      at = 5; l4 = input.t;
      at = 6; l5 = rt.int(l4);
      at = 7; l6 = K[1];
      at = 8; l7 = rt.add(l6, l5);
      at = 9; l8 = rt.array_range(l7);
      at = 10; l9 = rt.array_count(l8);
      at = 11; l10 = K[2];
      at = 12; l11 = rt.sequence_build(l9, l10);
      at = 13; l12 = K[3];
      at = 14; l13 = l12;
      at = 15; l14 = K[4];
      at = 16; {
        const f16 = rt.coerce("int", l14), e16 = rt.coerce("int", l9), n16 = e16 > f16 ? e16 - f16 : 0n;
        if (n16 > 18014398509481983n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l15 = n16;
        for (let i16 = 0, c16 = Number(n16); i16 < c16; i16++) {
          const j16 = BigInt(i16); l16 = j16; l17 = f16 + j16;
          at = 17; l18 = rt.array_nth(l8, l17);
          at = 18; l19 = BigInt(calls[0]++);
          at = 19; l20 = rt.int(l18);
          at = 20; l21 = input.t;
          at = 21; l22 = rt.mul(l18, l21);
          at = 22; l23 = K[5];
          at = 23; l24 = Float64Array.of(rt.float(l20), rt.float(l22), rt.float(l23));
          at = 24; store(rt, l11, l17, l24);
        }
      }
      at = 25; l3 = l11;
    } else {
      at = 26; calls[1] = 0;
      at = 27; l25 = input.t;
      at = 28; l26 = rt.int(l25);
      at = 29; l27 = K[6];
      at = 30; l28 = rt.add(l27, l26);
      at = 31; l29 = rt.array_range(l28);
      at = 32; l30 = rt.array_count(l29);
      at = 33; l31 = K[7];
      at = 34; l32 = rt.sequence_build(l30, l31);
      at = 35; l33 = K[8];
      at = 36; l34 = l33;
      at = 37; l35 = K[9];
      at = 38; {
        const f38 = rt.coerce("int", l35), e38 = rt.coerce("int", l30), n38 = e38 > f38 ? e38 - f38 : 0n;
        if (n38 > 18014398509481983n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l36 = n38;
        for (let i38 = 0, c38 = Number(n38); i38 < c38; i38++) {
          const j38 = BigInt(i38); l37 = j38; l38 = f38 + j38;
          at = 39; l39 = rt.array_nth(l29, l38);
          at = 40; l40 = BigInt(calls[1]++);
          at = 41; l41 = rt.int(l39);
          at = 42; l42 = input.t;
          at = 43; l43 = rt.mul(l39, l42);
          at = 44; l44 = K[10];
          at = 45; l45 = Float64Array.of(rt.float(l41), rt.float(l43), rt.float(l44));
          at = 46; store(rt, l32, l38, l45);
        }
      }
      at = 47; l3 = l32;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
