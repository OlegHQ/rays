// A minimal `rt` for running emitted frame programs (Js.frame) under node: the primitives of
// prims.js, a mark table, the Lisp frame record, and stand-ins for the runtime services the
// frame program calls. Tessellation is shaped, not computed: each geometry call returns the
// right number of empty geometry entries, so tests can compare entry structure.
import * as prims from '../runtime/prims.js';
import { frameValue } from '../runtime/runtime.js';

export function makeRt() {
  const entry = color => ({ type: 'geometry', vertices: new Float64Array(0), indices: new Int32Array(0), color });
  const styled = (fill, stroke) => [fill, stroke].filter(c => c !== null).length === 0 ? [entry(-1)]
    : [fill, stroke].filter(c => c !== null).map(entry);
  return {
    ...prims,
    marks: [],
    frameValue,
    image: () => 1,
    invoke: () => { throw new Error('the shim has no regions'); },
    polygon: (points, fill, stroke) => styled(fill, stroke),
    polyline: (points, color) => [entry(color)],
    rounded_rect: (w, h, r, fill, stroke) => styled(fill, stroke),
  };
}
