// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [0, 0, 1, 2, 0.5];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.lt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; l4 = input.t;
      at = 5; l5 = K[1];
      at = 6; l6 = rt.sub(l5, l4);
      at = 7; l3 = l6;
    } else {
      at = 8; l7 = input.t;
      at = 9; l8 = K[2];
      at = 10; l9 = rt.gt(l7, l8);
      at = 11; if (rt.truthy(l9)) {
        at = 12; l11 = input.t;
        at = 13; l12 = K[3];
        at = 14; l13 = rt.mul(l11, l12);
        at = 15; l10 = l13;
      } else {
        at = 16; l14 = input.t;
        at = 17; l15 = K[4];
        at = 18; l16 = rt.add(l14, l15);
        at = 19; l10 = l16;
      }
      at = 20; l3 = l10;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
