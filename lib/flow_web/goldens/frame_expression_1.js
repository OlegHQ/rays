// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [6n, 0.69999999999999996];
  let l0, l1, l2, l3, l4, l5, l6;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.mul(l0, l1);
    at = 3; l3 = input.t;
    at = 4; l4 = K[1];
    at = 5; l5 = rt.mod(l3, l4);
    at = 6; l6 = rt.add(l2, l5);
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l6;
}
