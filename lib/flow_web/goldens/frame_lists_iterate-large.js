// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [-1000, 0, 4500n, 0n, 1, 0, 4500n, 0n, 1];
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
      at = 6; l5 = l4;
      at = 7; l6 = input.t;
      at = 8; l7 = rt.int(l6);
      at = 9; l8 = K[2];
      at = 10; l9 = rt.add(l8, l7);
      at = 11; l10 = K[3];
      at = 12; {
        const f12 = rt.coerce("int", l10), e12 = rt.coerce("int", l9), n12 = e12 > f12 ? e12 - f12 : 0n;
        if (n12 > 4611686018427387903n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l11 = n12;
        for (let i12 = 0, c12 = Number(n12); i12 < c12; i12++) {
          const j12 = BigInt(i12); l12 = j12; l13 = f12 + j12;
          at = 13; l14 = BigInt(calls[0]++);
          at = 14; l15 = K[4];
          at = 15; l16 = rt.add(l5, l15);
          at = 16; l17 = rt.coerce("float", l16);
          at = 17; l18 = rt.equal(l16, l17);
          at = 18; if (rt.truthy(l18)) {
            at = 19; l19 = l16;
          } else {
            at = 20; l20 = rt.coerce("float", l5);
            at = 21; l21 = rt.equal(l5, l20);
            at = 22; if (rt.truthy(l21)) {
              at = 23; l23 = rt.coerce("float", l16);
              at = 24; l22 = l23;
            } else {
              at = 25; l24 = rt.coerce("int", l16);
              at = 26; l22 = l24;
            }
            at = 27; l19 = l22;
          }
          at = 28; l5 = l19;
        }
      }
      at = 29; l3 = l5;
    } else {
      at = 30; calls[1] = 0;
      at = 31; l25 = K[5];
      at = 32; l26 = l25;
      at = 33; l27 = input.t;
      at = 34; l28 = rt.int(l27);
      at = 35; l29 = K[6];
      at = 36; l30 = rt.add(l29, l28);
      at = 37; l31 = K[7];
      at = 38; {
        const f38 = rt.coerce("int", l31), e38 = rt.coerce("int", l30), n38 = e38 > f38 ? e38 - f38 : 0n;
        if (n38 > 4611686018427387903n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l32 = n38;
        for (let i38 = 0, c38 = Number(n38); i38 < c38; i38++) {
          const j38 = BigInt(i38); l33 = j38; l34 = f38 + j38;
          at = 39; l35 = BigInt(calls[1]++);
          at = 40; l36 = K[8];
          at = 41; l37 = rt.add(l26, l36);
          at = 42; l38 = rt.coerce("float", l37);
          at = 43; l39 = rt.equal(l37, l38);
          at = 44; if (rt.truthy(l39)) {
            at = 45; l40 = l37;
          } else {
            at = 46; l41 = rt.coerce("float", l26);
            at = 47; l42 = rt.equal(l26, l41);
            at = 48; if (rt.truthy(l42)) {
              at = 49; l44 = rt.coerce("float", l37);
              at = 50; l43 = l44;
            } else {
              at = 51; l45 = rt.coerce("int", l37);
              at = 52; l43 = l45;
            }
            at = 53; l40 = l43;
          }
          at = 54; l26 = l40;
        }
      }
      at = 55; l3 = l26;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
