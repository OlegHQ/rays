// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [0, 2, 1];
  let l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14;
  let at = 0;
  const calls = new Int32Array(1);
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; l4 = input.t;
      at = 5; l5 = K[1];
      at = 6; l6 = rt.mul(l4, l5);
      at = 7; calls[0] = 0;
      at = 8; l7 = input.t;
      at = 9; l8 = BigInt(calls[0]++);
      at = 10; l9 = rt.add(l7, l6);
      at = 11; l10 = BigInt(calls[0]++);
      at = 12; l11 = K[2];
      at = 13; l12 = rt.add(l11, l6);
      at = 14; l13 = rt.add(l9, l12);
      at = 15; l3 = l13;
    } else {
      at = 16; l14 = input.t;
      at = 17; l3 = l14;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
