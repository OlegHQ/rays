// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [-1000, 0n, 0n, 3n, 0n, 0n, 3n];
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
      at = 6; l5 = l4;
      at = 7; l6 = K[2];
      at = 8; l7 = K[3];
      at = 9; {
        const f9 = rt.coerce("int", l6), e9 = rt.coerce("int", l7), n9 = e9 > f9 ? e9 - f9 : 0n;
        if (n9 > 4611686018427387903n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l8 = n9;
        for (let i9 = 0, c9 = Number(n9); i9 < c9; i9++) {
          const j9 = BigInt(i9); l9 = j9; l10 = f9 + j9;
          at = 10; l11 = BigInt(calls[0]++);
          at = 11; l12 = input.t;
          at = 12; l13 = rt.add(l5, l12);
          at = 13; l14 = rt.coerce("float", l13);
          at = 14; l15 = rt.equal(l13, l14);
          at = 15; if (rt.truthy(l15)) {
            at = 16; l16 = l13;
          } else {
            at = 17; l17 = rt.coerce("float", l5);
            at = 18; l18 = rt.equal(l5, l17);
            at = 19; if (rt.truthy(l18)) {
              at = 20; l20 = rt.coerce("float", l13);
              at = 21; l19 = l20;
            } else {
              at = 22; l21 = rt.coerce("int", l13);
              at = 23; l19 = l21;
            }
            at = 24; l16 = l19;
          }
          at = 25; l5 = l16;
        }
      }
      at = 26; l3 = l5;
    } else {
      at = 27; calls[1] = 0;
      at = 28; l22 = K[4];
      at = 29; l23 = l22;
      at = 30; l24 = K[5];
      at = 31; l25 = K[6];
      at = 32; {
        const f32 = rt.coerce("int", l24), e32 = rt.coerce("int", l25), n32 = e32 > f32 ? e32 - f32 : 0n;
        if (n32 > 4611686018427387903n) rt.fail("E_ITER_BOUND", "Core iteration exceeds its bound.");
        l26 = n32;
        for (let i32 = 0, c32 = Number(n32); i32 < c32; i32++) {
          const j32 = BigInt(i32); l27 = j32; l28 = f32 + j32;
          at = 33; l29 = BigInt(calls[1]++);
          at = 34; l30 = input.t;
          at = 35; l31 = rt.add(l23, l30);
          at = 36; l32 = rt.coerce("float", l31);
          at = 37; l33 = rt.equal(l31, l32);
          at = 38; if (rt.truthy(l33)) {
            at = 39; l34 = l31;
          } else {
            at = 40; l35 = rt.coerce("float", l23);
            at = 41; l36 = rt.equal(l23, l35);
            at = 42; if (rt.truthy(l36)) {
              at = 43; l38 = rt.coerce("float", l31);
              at = 44; l37 = l38;
            } else {
              at = 45; l39 = rt.coerce("int", l31);
              at = 46; l37 = l39;
            }
            at = 47; l34 = l37;
          }
          at = 48; l23 = l34;
        }
      }
      at = 49; l3 = l23;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
