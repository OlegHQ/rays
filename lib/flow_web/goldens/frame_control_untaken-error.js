// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [0, 1];
  let l0, l1, l2, l3, l4, l5, l6, l7;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = K[0];
    at = 2; l2 = rt.gt(l0, l1);
    at = 3; if (rt.truthy(l2)) {
      at = 4; l4 = input.t;
      at = 5; l5 = K[1];
      at = 6; l6 = rt.add(l4, l5);
      at = 7; l3 = l6;
    } else {
      at = 8; l7 = rt.fail("E_NONFINITE", "exp produced a nonfinite value.");
      at = 9; l3 = l7;
    }
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l3;
}
