// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [0n, 1n, 1n, 1n, 3n, 3n, 2n, 5n, 5n, 3n, 7n, 7n, 4n, 9n, 9n, 5n, 11n, 11n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24, l25, l26, l27, l28, l29, l30, l31;
  let l32, l33, l34, l35, l36, l37, l38, l39, l40, l41, l42, l43, l44, l45, l46, l47;
  let l48, l49, l50, l51, l52;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.add(l0, l1);
    at = 3; l3 = K[1];
    at = 4; l4 = rt.mul(l2, l3);
    at = 5; l5 = rt.sin(l4);
    at = 6; l6 = K[2];
    at = 7; l7 = rt.div(l5, l6);
    at = 8; l8 = input.t;
    at = 9; l9 = K[3];
    at = 10; l10 = rt.add(l8, l9);
    at = 11; l11 = K[4];
    at = 12; l12 = rt.mul(l10, l11);
    at = 13; l13 = rt.sin(l12);
    at = 14; l14 = K[5];
    at = 15; l15 = rt.div(l13, l14);
    at = 16; l16 = input.t;
    at = 17; l17 = K[6];
    at = 18; l18 = rt.add(l16, l17);
    at = 19; l19 = K[7];
    at = 20; l20 = rt.mul(l18, l19);
    at = 21; l21 = rt.sin(l20);
    at = 22; l22 = K[8];
    at = 23; l23 = rt.div(l21, l22);
    at = 24; l24 = input.t;
    at = 25; l25 = K[9];
    at = 26; l26 = rt.add(l24, l25);
    at = 27; l27 = K[10];
    at = 28; l28 = rt.mul(l26, l27);
    at = 29; l29 = rt.sin(l28);
    at = 30; l30 = K[11];
    at = 31; l31 = rt.div(l29, l30);
    at = 32; l32 = input.t;
    at = 33; l33 = K[12];
    at = 34; l34 = rt.add(l32, l33);
    at = 35; l35 = K[13];
    at = 36; l36 = rt.mul(l34, l35);
    at = 37; l37 = rt.sin(l36);
    at = 38; l38 = K[14];
    at = 39; l39 = rt.div(l37, l38);
    at = 40; l40 = input.t;
    at = 41; l41 = K[15];
    at = 42; l42 = rt.add(l40, l41);
    at = 43; l43 = K[16];
    at = 44; l44 = rt.mul(l42, l43);
    at = 45; l45 = rt.sin(l44);
    at = 46; l46 = K[17];
    at = 47; l47 = rt.div(l45, l46);
    at = 48; l48 = rt.add(l7, l15);
    at = 49; l49 = rt.add(l48, l23);
    at = 50; l50 = rt.add(l49, l31);
    at = 51; l51 = rt.add(l50, l39);
    at = 52; l52 = rt.add(l51, l47);
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l52;
}
