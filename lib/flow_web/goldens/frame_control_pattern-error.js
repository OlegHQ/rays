// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [0, 0n, 1n, 3n, 0n, 0n, 1n, 2n];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15;
  let l16, l17, l18, l19, l20, l21, l22, l23, l24;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; l4 = input.t;
      at = 5; l5 = K[1];
      at = 6; l6 = rt.add(l4, l5);
      at = 7; l7 = input.t;
      at = 8; l8 = K[2];
      at = 9; l9 = rt.add(l7, l8);
      at = 10; l10 = rt.sequence_concat([l6], [l9]);
      at = 11; l11 = rt.sequence_length(l10);
      at = 12; l12 = K[3];
      at = 13; l13 = rt.lt(l11, l12);
      at = 14; if (rt.truthy(l13)) {
        at = 15; l15 = rt.fail("E_PATTERN", "Not enough elements to destructure.");
        at = 16; l14 = l15;
      } else {
        at = 17; l16 = K[4];
        at = 18; l14 = l16;
      }
      at = 19; l17 = K[5];
      at = 20; l18 = rt.sequence_get(l10, l17);
      at = 21; l19 = K[6];
      at = 22; l20 = rt.sequence_get(l10, l19);
      at = 23; l21 = K[7];
      at = 24; l22 = rt.sequence_get(l10, l21);
      at = 25; l23 = rt.add(l18, l20);
      at = 26; l3 = l23;
    } else {
      at = 27; l24 = input.t;
      at = 28; l3 = l24;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
