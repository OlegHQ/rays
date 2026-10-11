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
  K ??= [-1000, 0n, 0n, 4096n, [0n, 1n], [0n, 1n, 2n], 4096n, 0n, 4n, true, false, 0n, 10n, 1n, 0n, 1n, 0n, 0n, 0n, 4096n, [0n, 1n], [0n, 1n, 2n], 4096n, 0n, 4n, true, false, 0n, 10n, 1n, 0n, 1n, 0n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25, l26, l27, l28, l29, l30, l31;
  let l32, l33, l34, l35, l36, l37, l38, l39, l40, l41, l42, l43, l44, l45, l46, l47;
  let l48, l49, l50, l51, l52, l53, l54, l55, l56, l57, l58, l59, l60, l61, l62, l63;
  let l64, l65, l66, l67, l68, l69, l70, l71, l72, l73, l74, l75, l76, l77, l78, l79;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; l4 = K[1];
      at = 5; l5 = l4;
      at = 6; l6 = K[2];
      at = 7; l7 = l6;
      at = 8; l8 = K[3];
      at = 9; l9 = rt.sequence_build(l8);
      at = 10; l10 = K[4];
      at = 11; {
        const s11 = l10, c11 = Array.isArray(s11) ? s11.length : Number(rt.array_count(s11));
        if (c11 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i11 = 0; i11 < c11; i11++) {
          l11 = BigInt(i11); l12 = Array.isArray(s11) ? s11[i11] : rt.array_nth(s11, i11);
          at = 12; l13 = K[5];
          at = 13; {
            const s13 = l13, c13 = Array.isArray(s13) ? s13.length : Number(rt.array_count(s13));
            if (c13 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
            for (let i13 = 0; i13 < c13; i13++) {
              l14 = BigInt(i13); l15 = Array.isArray(s13) ? s13[i13] : rt.array_nth(s13, i13);
              at = 14; l16 = K[6];
              at = 15; l17 = rt.ge(l5, l16);
              at = 16; if (rt.truthy(l17)) {
                at = 17; l19 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
                at = 18; l18 = l19;
              } else {
                at = 19; l20 = K[7];
                at = 20; l18 = l20;
              }
              at = 21; l21 = K[8];
              at = 22; l22 = rt.eq(l5, l21);
              at = 23; l23 = K[9];
              at = 24; l24 = rt.and(l23, l22);
              at = 25; l25 = K[10];
              at = 26; l26 = rt.or(l25, l24);
              at = 27; if (rt.truthy(l26)) {
                at = 28; l28 = K[11];
                at = 29; l27 = l28;
              } else {
                at = 30; l29 = K[12];
                at = 31; l30 = rt.mul(l29, l12);
                at = 32; l31 = rt.add(l30, l15);
                at = 33; l32 = input.t;
                at = 34; l33 = rt.add(l31, l32);
                at = 35; store(rt, l9, l7, l33);
                at = 36; l34 = K[13];
                at = 37; l35 = rt.add(l7, l34);
                at = 38; l7 = l35;
                at = 39; l36 = K[14];
                at = 40; l27 = l36;
              }
              at = 41; l37 = K[15];
              at = 42; l38 = rt.add(l5, l37);
              at = 43; l5 = l38;
            }
          }
        }
      }
      at = 44; l39 = K[16];
      at = 45; l40 = rt.sequence_slice(l9, l39, l7);
      at = 46; l41 = rt.sequence_concat(l40);
      at = 47; l3 = l41;
    } else {
      at = 48; l42 = K[17];
      at = 49; l43 = l42;
      at = 50; l44 = K[18];
      at = 51; l45 = l44;
      at = 52; l46 = K[19];
      at = 53; l47 = rt.sequence_build(l46);
      at = 54; l48 = K[20];
      at = 55; {
        const s55 = l48, c55 = Array.isArray(s55) ? s55.length : Number(rt.array_count(s55));
        if (c55 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i55 = 0; i55 < c55; i55++) {
          l49 = BigInt(i55); l50 = Array.isArray(s55) ? s55[i55] : rt.array_nth(s55, i55);
          at = 56; l51 = K[21];
          at = 57; {
            const s57 = l51, c57 = Array.isArray(s57) ? s57.length : Number(rt.array_count(s57));
            if (c57 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
            for (let i57 = 0; i57 < c57; i57++) {
              l52 = BigInt(i57); l53 = Array.isArray(s57) ? s57[i57] : rt.array_nth(s57, i57);
              at = 58; l54 = K[22];
              at = 59; l55 = rt.ge(l43, l54);
              at = 60; if (rt.truthy(l55)) {
                at = 61; l57 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
                at = 62; l56 = l57;
              } else {
                at = 63; l58 = K[23];
                at = 64; l56 = l58;
              }
              at = 65; l59 = K[24];
              at = 66; l60 = rt.eq(l43, l59);
              at = 67; l61 = K[25];
              at = 68; l62 = rt.and(l61, l60);
              at = 69; l63 = K[26];
              at = 70; l64 = rt.or(l63, l62);
              at = 71; if (rt.truthy(l64)) {
                at = 72; l66 = K[27];
                at = 73; l65 = l66;
              } else {
                at = 74; l67 = K[28];
                at = 75; l68 = rt.mul(l67, l50);
                at = 76; l69 = rt.add(l68, l53);
                at = 77; l70 = input.t;
                at = 78; l71 = rt.add(l69, l70);
                at = 79; store(rt, l47, l45, l71);
                at = 80; l72 = K[29];
                at = 81; l73 = rt.add(l45, l72);
                at = 82; l45 = l73;
                at = 83; l74 = K[30];
                at = 84; l65 = l74;
              }
              at = 85; l75 = K[31];
              at = 86; l76 = rt.add(l43, l75);
              at = 87; l43 = l76;
            }
          }
        }
      }
      at = 88; l77 = K[32];
      at = 89; l78 = rt.sequence_slice(l47, l77, l45);
      at = 90; l79 = rt.sequence_concat(l78);
      at = 91; l3 = l79;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
