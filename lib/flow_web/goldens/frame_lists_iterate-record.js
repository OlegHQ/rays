// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [-1000, 0, 0n, 3n, 0, 0n, 3n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25, l26, l27, l28, l29, l30, l31;
  let l32, l33, l34, l35, l36, l37, l38, l39, l40, l41, l42, l43, l44, l45, l46;
  let at = 0;
  const calls = new Int32Array(2);
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; calls[0] = 0;
      at = 5; l3 = K[1];
      at = 6; l4 = l3;
      at = 7; l5 = K[2];
      at = 8; l6 = K[3];
      at = 9; {
        const f9 = rt.coerce("int", l5), e9 = rt.coerce("int", l6), n9 = e9 > f9 ? e9 - f9 : 0n;
        if (n9 > 4611686018427387903n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l7 = n9;
        for (let i9 = 0, c9 = Number(n9); i9 < c9; i9++) {
          const j9 = BigInt(i9); l8 = j9; l9 = f9 + j9;
          at = 10; l10 = BigInt(calls[0]++);
          at = 11; l11 = input.t;
          at = 12; l12 = rt.add(l4, l11);
          at = 13; l13 = rt.coerce("float", l4);
          at = 14; l14 = rt.equal(l4, l13);
          at = 15; if (rt.truthy(l14)) {
            at = 16; l16 = rt.coerce("float", l12);
            at = 17; l15 = l16;
          } else {
            at = 18; l17 = rt.coerce("int", l12);
            at = 19; l15 = l17;
          }
          at = 20; l18 = rt.coerce("float", l4);
          at = 21; l19 = rt.equal(l4, l18);
          at = 22; if (rt.truthy(l19)) {
            at = 23; l21 = rt.coerce("float", l15);
            at = 24; l20 = l21;
          } else {
            at = 25; l22 = rt.coerce("int", l15);
            at = 26; l20 = l22;
          }
          at = 27; l23 = l20;
          at = 28; l4 = l23;
        }
      }
      at = 54; l45 = l4;
    } else {
      at = 29; calls[1] = 0;
      at = 30; l24 = K[4];
      at = 31; l25 = l24;
      at = 32; l26 = K[5];
      at = 33; l27 = K[6];
      at = 34; {
        const f34 = rt.coerce("int", l26), e34 = rt.coerce("int", l27), n34 = e34 > f34 ? e34 - f34 : 0n;
        if (n34 > 4611686018427387903n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l28 = n34;
        for (let i34 = 0, c34 = Number(n34); i34 < c34; i34++) {
          const j34 = BigInt(i34); l29 = j34; l30 = f34 + j34;
          at = 35; l31 = BigInt(calls[1]++);
          at = 36; l32 = input.t;
          at = 37; l33 = rt.add(l25, l32);
          at = 38; l34 = rt.coerce("float", l25);
          at = 39; l35 = rt.equal(l25, l34);
          at = 40; if (rt.truthy(l35)) {
            at = 41; l37 = rt.coerce("float", l33);
            at = 42; l36 = l37;
          } else {
            at = 43; l38 = rt.coerce("int", l33);
            at = 44; l36 = l38;
          }
          at = 45; l39 = rt.coerce("float", l25);
          at = 46; l40 = rt.equal(l25, l39);
          at = 47; if (rt.truthy(l40)) {
            at = 48; l42 = rt.coerce("float", l36);
            at = 49; l41 = l42;
          } else {
            at = 50; l43 = rt.coerce("int", l36);
            at = 51; l41 = l43;
          }
          at = 52; l44 = l41;
          at = 53; l25 = l44;
        }
      }
      at = 55; l45 = l25;
    }
    at = 56; l46 = new Map([["n", l45]]);
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l46;
}
