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
  K ??= [-1000, 0n, 0n, 0n, 4096n, [0n, 1n, 2n, 3n], 4096n, 0n, 1n, 1n, 0n, 0n, 0n, 0n, 4096n, [0n, 1n, 2n, 3n], 4096n, 0n, 1n, 1n, 0n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25, l26, l27, l28, l29, l30, l31;
  let l32, l33, l34, l35, l36, l37, l38, l39, l40, l41, l42, l43, l44, l45, l46, l47;
  let l48, l49, l50, l51, l52, l53, l54, l55, l56, l57, l58, l59, l60, l61, l62, l63;
  let l64, l65, l66, l67, l68, l69;
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
      at = 9; l9 = l8;
      at = 10; l10 = K[4];
      at = 11; l11 = rt.sequence_build(l10);
      at = 12; l12 = K[5];
      at = 13; {
        const s13 = l12, c13 = Array.isArray(s13) ? s13.length : Number(rt.array_count(s13));
        if (c13 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i13 = 0; i13 < c13; i13++) {
          l13 = BigInt(i13); l14 = Array.isArray(s13) ? s13[i13] : rt.array_nth(s13, i13);
          at = 14; l15 = K[6];
          at = 15; l16 = rt.ge(l7, l15);
          at = 16; if (rt.truthy(l16)) {
            at = 17; l18 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 18; l17 = l18;
          } else {
            at = 19; l19 = K[7];
            at = 20; l17 = l19;
          }
          at = 21; l20 = input.t;
          at = 22; l21 = rt.add(l5, l20);
          at = 23; l22 = rt.coerce("float", l21);
          at = 24; l23 = rt.equal(l21, l22);
          at = 25; if (rt.truthy(l23)) {
            at = 26; l24 = l21;
          } else {
            at = 27; l25 = rt.coerce("float", l5);
            at = 28; l26 = rt.equal(l5, l25);
            at = 29; if (rt.truthy(l26)) {
              at = 30; l28 = rt.coerce("float", l21);
              at = 31; l27 = l28;
            } else {
              at = 32; l29 = rt.coerce("int", l21);
              at = 33; l27 = l29;
            }
            at = 34; l24 = l27;
          }
          at = 35; l5 = l24;
          at = 36; store(rt, l11, l9, l5);
          at = 37; l30 = K[8];
          at = 38; l31 = rt.add(l9, l30);
          at = 39; l9 = l31;
          at = 40; l32 = K[9];
          at = 41; l33 = rt.add(l7, l32);
          at = 42; l7 = l33;
        }
      }
      at = 43; l34 = K[10];
      at = 44; l35 = rt.sequence_slice(l11, l34, l9);
      at = 45; l36 = rt.sequence_concat(l35);
      at = 46; l3 = l36;
    } else {
      at = 47; l37 = K[11];
      at = 48; l38 = l37;
      at = 49; l39 = K[12];
      at = 50; l40 = l39;
      at = 51; l41 = K[13];
      at = 52; l42 = l41;
      at = 53; l43 = K[14];
      at = 54; l44 = rt.sequence_build(l43);
      at = 55; l45 = K[15];
      at = 56; {
        const s56 = l45, c56 = Array.isArray(s56) ? s56.length : Number(rt.array_count(s56));
        if (c56 > 4096) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        for (let i56 = 0; i56 < c56; i56++) {
          l46 = BigInt(i56); l47 = Array.isArray(s56) ? s56[i56] : rt.array_nth(s56, i56);
          at = 57; l48 = K[16];
          at = 58; l49 = rt.ge(l40, l48);
          at = 59; if (rt.truthy(l49)) {
            at = 60; l51 = rt.fail("E_ITER_BOUND", "Loop runs more than 4,096 iterations.");
            at = 61; l50 = l51;
          } else {
            at = 62; l52 = K[17];
            at = 63; l50 = l52;
          }
          at = 64; l53 = input.t;
          at = 65; l54 = rt.add(l38, l53);
          at = 66; l55 = rt.coerce("float", l54);
          at = 67; l56 = rt.equal(l54, l55);
          at = 68; if (rt.truthy(l56)) {
            at = 69; l57 = l54;
          } else {
            at = 70; l58 = rt.coerce("float", l38);
            at = 71; l59 = rt.equal(l38, l58);
            at = 72; if (rt.truthy(l59)) {
              at = 73; l61 = rt.coerce("float", l54);
              at = 74; l60 = l61;
            } else {
              at = 75; l62 = rt.coerce("int", l54);
              at = 76; l60 = l62;
            }
            at = 77; l57 = l60;
          }
          at = 78; l38 = l57;
          at = 79; store(rt, l44, l42, l38);
          at = 80; l63 = K[18];
          at = 81; l64 = rt.add(l42, l63);
          at = 82; l42 = l64;
          at = 83; l65 = K[19];
          at = 84; l66 = rt.add(l40, l65);
          at = 85; l40 = l66;
        }
      }
      at = 86; l67 = K[20];
      at = 87; l68 = rt.sequence_slice(l44, l67, l42);
      at = 88; l69 = rt.sequence_concat(l68);
      at = 89; l3 = l69;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
