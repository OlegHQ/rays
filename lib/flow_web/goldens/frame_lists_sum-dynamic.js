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
  K ??= [-1000, 0n, 0n, 0n, 0n, 4096n, 0n, 0n, 1n, 1n, 0n, 0n, 0n, 0n, 4096n, 0n, 0n, 1n, 1n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25, l26, l27, l28, l29, l30, l31;
  let l32, l33, l34, l35, l36, l37, l38, l39, l40, l41, l42, l43, l44, l45, l46, l47;
  let l48, l49, l50, l51, l52, l53, l54, l55, l56, l57, l58, l59, l60, l61;
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
      at = 9; l10 = K[2];
      at = 10; l11 = l10;
      at = 11; l12 = K[3];
      at = 12; l13 = l12;
      at = 13; l14 = K[4];
      at = 14; l15 = l14;
      at = 15; {
        const s15 = l9, c15 = Array.isArray(s15) ? s15.length : Number(rt.array_count(s15));
        if (c15 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i15 = 0; i15 < c15; i15++) {
          l16 = BigInt(i15); l17 = Array.isArray(s15) ? s15[i15] : rt.array_nth(s15, i15);
          at = 16; l18 = K[5];
          at = 17; l19 = rt.ge(l11, l18);
          at = 18; if (rt.truthy(l19)) {
            at = 19; l21 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 20; l20 = l21;
          } else {
            at = 21; l22 = K[6];
            at = 22; l20 = l22;
          }
          at = 23; l23 = input.t;
          at = 24; l24 = rt.mul(l17, l23);
          at = 25; l25 = K[7];
          at = 26; l26 = rt.eq(l13, l25);
          at = 27; if (rt.truthy(l26)) {
            at = 28; l27 = l24;
          } else {
            at = 29; l28 = rt.add(l15, l24);
            at = 30; l27 = l28;
          }
          at = 31; l15 = l27;
          at = 32; l29 = K[8];
          at = 33; l30 = rt.add(l13, l29);
          at = 34; l13 = l30;
          at = 35; l31 = K[9];
          at = 36; l32 = rt.add(l11, l31);
          at = 37; l11 = l32;
        }
      }
      at = 38; l3 = l15;
    } else {
      at = 39; l33 = input.t;
      at = 40; l34 = K[10];
      at = 41; {
        const f41 = rt.coerce("int", l34), e41 = rt.coerce("int", l33), n41 = e41 > f41 ? e41 - f41 : 0n;
        if (n41 > 4096n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l35 = n41;
        at = 42; l38 = rt.sequence_build(l35);
        for (let i41 = 0, c41 = Number(n41); i41 < c41; i41++) {
          const j41 = BigInt(i41); l36 = j41; l37 = f41 + j41;
          at = 43; store(rt, l38, l36, l37);
        }
      }
      at = 44; l39 = K[11];
      at = 45; l40 = l39;
      at = 46; l41 = K[12];
      at = 47; l42 = l41;
      at = 48; l43 = K[13];
      at = 49; l44 = l43;
      at = 50; {
        const s50 = l38, c50 = Array.isArray(s50) ? s50.length : Number(rt.array_count(s50));
        if (c50 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i50 = 0; i50 < c50; i50++) {
          l45 = BigInt(i50); l46 = Array.isArray(s50) ? s50[i50] : rt.array_nth(s50, i50);
          at = 51; l47 = K[14];
          at = 52; l48 = rt.ge(l40, l47);
          at = 53; if (rt.truthy(l48)) {
            at = 54; l50 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 55; l49 = l50;
          } else {
            at = 56; l51 = K[15];
            at = 57; l49 = l51;
          }
          at = 58; l52 = input.t;
          at = 59; l53 = rt.mul(l46, l52);
          at = 60; l54 = K[16];
          at = 61; l55 = rt.eq(l42, l54);
          at = 62; if (rt.truthy(l55)) {
            at = 63; l56 = l53;
          } else {
            at = 64; l57 = rt.add(l44, l53);
            at = 65; l56 = l57;
          }
          at = 66; l44 = l56;
          at = 67; l58 = K[17];
          at = 68; l59 = rt.add(l42, l58);
          at = 69; l42 = l59;
          at = 70; l60 = K[18];
          at = 71; l61 = rt.add(l40, l60);
          at = 72; l40 = l61;
        }
      }
      at = 73; l3 = l44;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
