// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [-1000, 0, false, 0n, 8n, 0n, 2, 0n, 0, false, 0n, 8n, 0n, 2, 0n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25, l26, l27, l28, l29, l30, l31;
  let l32, l33, l34, l35, l36, l37, l38, l39, l40, l41, l42, l43, l44, l45, l46, l47;
  let l48, l49, l50, l51, l52, l53, l54, l55, l56, l57;
  let at = 0;
  const calls = new Int32Array(4);
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; calls[0] = 0;
      at = 5; l4 = K[1];
      at = 6; l5 = l4;
      at = 7; calls[1] = 0;
      at = 8; l6 = K[2];
      at = 9; l7 = l6;
      at = 10; l8 = K[3];
      at = 11; l9 = K[4];
      at = 12; {
        const f12 = rt.coerce("int", l8), e12 = rt.coerce("int", l9), n12 = e12 > f12 ? e12 - f12 : 0n;
        if (n12 > 4611686018427387903n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l10 = n12;
        for (let i12 = 0, c12 = Number(n12); i12 < c12; i12++) {
          const j12 = BigInt(i12); l11 = j12; l12 = f12 + j12;
          at = 13; if (rt.truthy(l7)) {
            at = 14; l14 = K[5];
            at = 15; l13 = l14;
          } else {
            at = 16; l15 = BigInt(calls[0]++);
            at = 17; l16 = input.t;
            at = 18; l17 = rt.add(l5, l16);
            at = 19; l18 = rt.coerce("float", l17);
            at = 20; l19 = rt.equal(l17, l18);
            at = 21; if (rt.truthy(l19)) {
              at = 22; l20 = l17;
            } else {
              at = 23; l21 = rt.coerce("float", l5);
              at = 24; l22 = rt.equal(l5, l21);
              at = 25; if (rt.truthy(l22)) {
                at = 26; l24 = rt.coerce("float", l17);
                at = 27; l23 = l24;
              } else {
                at = 28; l25 = rt.coerce("int", l17);
                at = 29; l23 = l25;
              }
              at = 30; l20 = l23;
            }
            at = 31; l26 = l20;
            at = 32; l27 = BigInt(calls[1]++);
            at = 33; l28 = K[6];
            at = 34; l29 = rt.gt(l26, l28);
            at = 35; l7 = l29;
            at = 36; l5 = l26;
            at = 37; l30 = K[7];
            at = 38; l13 = l30;
          }
        }
      }
      at = 39; l3 = l5;
    } else {
      at = 40; calls[2] = 0;
      at = 41; l31 = K[8];
      at = 42; l32 = l31;
      at = 43; calls[3] = 0;
      at = 44; l33 = K[9];
      at = 45; l34 = l33;
      at = 46; l35 = K[10];
      at = 47; l36 = K[11];
      at = 48; {
        const f48 = rt.coerce("int", l35), e48 = rt.coerce("int", l36), n48 = e48 > f48 ? e48 - f48 : 0n;
        if (n48 > 4611686018427387903n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l37 = n48;
        for (let i48 = 0, c48 = Number(n48); i48 < c48; i48++) {
          const j48 = BigInt(i48); l38 = j48; l39 = f48 + j48;
          at = 49; if (rt.truthy(l34)) {
            at = 50; l41 = K[12];
            at = 51; l40 = l41;
          } else {
            at = 52; l42 = BigInt(calls[2]++);
            at = 53; l43 = input.t;
            at = 54; l44 = rt.add(l32, l43);
            at = 55; l45 = rt.coerce("float", l44);
            at = 56; l46 = rt.equal(l44, l45);
            at = 57; if (rt.truthy(l46)) {
              at = 58; l47 = l44;
            } else {
              at = 59; l48 = rt.coerce("float", l32);
              at = 60; l49 = rt.equal(l32, l48);
              at = 61; if (rt.truthy(l49)) {
                at = 62; l51 = rt.coerce("float", l44);
                at = 63; l50 = l51;
              } else {
                at = 64; l52 = rt.coerce("int", l44);
                at = 65; l50 = l52;
              }
              at = 66; l47 = l50;
            }
            at = 67; l53 = l47;
            at = 68; l54 = BigInt(calls[3]++);
            at = 69; l55 = K[13];
            at = 70; l56 = rt.gt(l53, l55);
            at = 71; l34 = l56;
            at = 72; l32 = l53;
            at = 73; l57 = K[14];
            at = 74; l40 = l57;
          }
        }
      }
      at = 75; l3 = l32;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
