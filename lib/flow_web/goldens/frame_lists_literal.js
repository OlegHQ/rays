// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [-1000, -1000, 1n, 2, [], -1000, 1n, 2, []];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; l4 = input.t;
      at = 5; l5 = K[1];
      at = 6; l6 = rt.gt(l4, l5);
      at = 7; if (rt.truthy(l6)) {
        at = 8; l8 = input.t;
        at = 9; l9 = K[2];
        at = 10; l10 = K[3];
        at = 11; l11 = rt.sequence_concat([l8], [l9], [l10]);
        at = 12; l7 = l11;
      } else {
        at = 13; l12 = K[4];
        at = 14; l7 = l12;
      }
      at = 15; l3 = l7;
    } else {
      at = 16; l13 = input.t;
      at = 17; l14 = K[5];
      at = 18; l15 = rt.gt(l13, l14);
      at = 19; if (rt.truthy(l15)) {
        at = 20; l17 = input.t;
        at = 21; l18 = K[6];
        at = 22; l19 = K[7];
        at = 23; l20 = rt.sequence_concat([l17], [l18], [l19]);
        at = 24; l16 = l20;
      } else {
        at = 25; l21 = K[8];
        at = 26; l16 = l21;
      }
      at = 27; l3 = l16;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
