// Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
export async function frame(input, state, rt) {
  let l0;
  let at = 0;
  try {
    at = 0; l0 = await rt.invoke(0, []);
  } catch (e) {
    if (e !== null && typeof e === "object" && e.statement === undefined) e.statement = at;
    throw e;
  }
  return l0;
}
