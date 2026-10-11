// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
let K;
export function frame(input, state, rt) {
  K ??= [1];
  let l0, l1, l2, l3, l4;
  let at = 0;
  try {
    at = 0; l0 = input.t;
    at = 1; l1 = input.t;
    at = 2; l2 = K[0];
    at = 3; l3 = rt.add(l1, l2);
    at = 4; l4 = Float64Array.of(rt.float(l0), rt.float(l3));
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l4;
}
