// Browser runtime, part 1: input translation, the frame record, state slots and the frame loop.
// Hand-written and the same for every sketch; the compiler emits only `program.js`.
//
// Program module (assumed contract, to be matched by the frame printer):
//   export const regions = { id: "function region(inputs, uniforms, outputs, start, stop) {...}" }
//   export async function frame(input, rt)    // input: the record below; may also be synchronous
// `rt` (see createRuntime) owns the state slot array `rt.slots` (undefined = absent, so a read runs the
// initializer), the region table and, when given, the worker pool. DOM access is only in `start`.
//
// Logical points: coordinates are CSS pixels relative to the canvas rectangle, never device pixels.
// Event shapes follow the native `frame/input` (lib/flow/op.ml:104-135 `event_fields`, `event_value`)
// and `Frame_input.t` (lib/frame_input/frame_input.mli:21-24). Held sets and ordering follow
// lib/rays/input_state.ml and lib/rays_editor/live_frame.ml. Values use prims.js's representation
// (Int = BigInt, Record = Map, Vec3 = Float64Array).

// ---- event records: op.ml:104-107 event_fields, defaults at op.ml:131-134 ----
const ZERO = { text: () => '', int: () => 0n, float: () => 0, vec3: () => new Float64Array(3), list: () => [] };
export const EVENT_FIELDS = [['kind', 'text'], ['key', 'text'], ['button', 'text'], ['position', 'vec3'],
  ['delta', 'vec3'], ['text', 'text'], ['start', 'int'], ['length', 'int'], ['paths', 'list'], ['error', 'text'],
  ['id', 'int'], ['width', 'int'], ['height', 'int'], ['phase', 'text'], ['time', 'float'], ['scale', 'float']];
export const eventRecord = (kind, fields = {}) => new Map(EVENT_FIELDS.map(([name, type]) =>
  [name, name === 'kind' ? kind : name in fields ? fields[name] : ZERO[type]()]));
const point = (x, y) => Float64Array.of(x, y, 0);   // op.ml:109 `point`

// ---- names ----
// Native button names, live_frame.ml:17-18. Held order is the OCaml variant order (input.ml:12-17).
const BUTTONS = ['left', 'right', 'middle', 'x1', 'x2'];
const DOM_BUTTON = ['left', 'middle', 'right', 'x1', 'x2'];   // MouseEvent.button 0..4
// live_frame.ml:3-12. Held keys are `KeySet.elements`, i.e. polymorphic `compare` on Input.key
// (input_state.ml:4,115): constant constructors in declaration order, then KeyChar by char, then Unknown.
const NAMED = ['up', 'down', 'left', 'right', 'space', 'enter', 'escape', 'backspace', 'tab', 'shift', 'ctrl',
  'alt', 'meta', ...Array.from({ length: 12 }, (_, i) => `f${i + 1}`), 'home', 'end', 'pageup', 'pagedown',
  'insert', 'delete'];
const DOM_KEY = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right', ' ': 'space',
  Enter: 'enter', Escape: 'escape', Backspace: 'backspace', Tab: 'tab', Shift: 'shift', Control: 'ctrl',
  Alt: 'alt', Meta: 'meta', Home: 'home', End: 'end', PageUp: 'pageup', PageDown: 'pagedown',
  Insert: 'insert', Delete: 'delete' };
export const keyName = key => /^F([1-9]|1[0-2])$/.test(key) ? key.toLowerCase()
  : DOM_KEY[key] ?? ([...key].length === 1 ? key.toLowerCase() : null);   // null: not a native key, ignored
const keyRank = k => { const n = NAMED.indexOf(k); return n >= 0 ? [0, n, 0] : [1, 0, k.codePointAt(0)]; };
const byKey = (a, b) => { const x = keyRank(a), y = keyRank(b); return x[0] - y[0] || x[1] - y[1] || x[2] - y[2]; };

// ---- DOM event -> native event records ----
// `rect` is the canvas's getBoundingClientRect(). Returns the events one DOM event stands for, in order.
const WHEEL_UNIT = [100, 3, 1];   // deltaMode pixel/line/page per native wheel step (ambiguous, see report)
export function translate(e, rect) {
  const at = () => point(e.clientX - rect.left, e.clientY - rect.top);
  switch (e.type) {
    case 'pointermove': case 'mousemove': return [eventRecord('pointer-moved', { position: at() })];
    case 'pointerdown': case 'mousedown':
      return [eventRecord('pointer-pressed', { button: DOM_BUTTON[e.button] ?? 'left', position: at() })];
    case 'pointerup': case 'mouseup':
      return [eventRecord('pointer-released', { button: DOM_BUTTON[e.button] ?? 'left', position: at() })];
    case 'wheel': {   // DOM y grows downward, the native wheel y grows away from the user
      const u = WHEEL_UNIT[e.deltaMode] ?? 1;
      return [eventRecord('scrolled', { delta: point(e.deltaX / u, -e.deltaY / u) })];
    }
    case 'keydown': case 'keyup': {   // auto-repeat keydowns are events too, as SDL repeats are (runtime_input_sdl3.ml:20)
      const key = keyName(e.key);
      return key === null ? [] : [eventRecord(e.type === 'keydown' ? 'key-pressed' : 'key-released', { key })];
    }
    case 'resize': return [eventRecord('resized', { width: BigInt(Math.round(rect.width)), height: BigInt(Math.round(rect.height)) })];
    case 'blur': return [eventRecord('focus-lost')];
    default: return [];
  }
}

// The accumulator of input_state.ml:15-24: pointer and held sets persist, the event list is per frame.
export class Input {
  constructor(size = [1, 1]) { this.size = [...size]; this.pointer = [0, 0]; this.buttons = new Set(); this.keys = new Set(); this.events = []; }
  push(e, rect) {
    const events = e.type === 'pointercancel'   // native cancels one button; the browser cancels the pointer
      ? [...this.buttons].map(button => eventRecord('pointer-cancelled', { button })) : translate(e, rect);
    for (const ev of events) {
      const kind = ev.get('kind'), p = ev.get('position');
      if (kind === 'pointer-moved' || kind === 'pointer-pressed' || kind === 'pointer-released') this.pointer = [p[0], p[1]];
      if (kind === 'pointer-pressed') this.buttons.add(ev.get('button'));
      else if (kind === 'pointer-released' || kind === 'pointer-cancelled') this.buttons.delete(ev.get('button'));
      else if (kind === 'key-pressed') this.keys.add(ev.get('key'));
      else if (kind === 'key-released') this.keys.delete(ev.get('key'));
      else if (kind === 'focus-lost') { this.keys.clear(); this.buttons.clear(); }
      else if (kind === 'resized') this.size = [Number(ev.get('width')), Number(ev.get('height'))];
      this.events.push(ev);
    }
  }
  // The Frame_input.t fields (frame_input.mli:21-24) but the clock's; drains the events, keeps what is held.
  snapshot() {
    const events = this.events; this.events = [];
    return { size: [...this.size], pointer: [...this.pointer],
      buttons: [...this.buttons].sort((a, b) => BUTTONS.indexOf(a) - BUTTONS.indexOf(b)),
      keys: [...this.keys].sort(byKey), events };
  }
}

// The Lisp `frame/input` record (op.ml:110-112 frame_ty, 136-139 frame_value).
export const frameValue = f => new Map([['t', f.t], ['dt', f.dt], ['index', BigInt(f.frame)],
  ['width', BigInt(f.size[0])], ['height', BigInt(f.size[1])], ['pointer', point(f.pointer[0], f.pointer[1])],
  ['buttons', f.buttons], ['keys', f.keys], ['events', f.events]]);

// ---- the runtime object ----
// opts: now() seconds; fixedDt (finite > 0) selects the fixed clock; pool (workers.js); size [w,h].
// Clock as sketch.ml:211-212: the count increments first (frames start at 1); fixed: dt, t = count*dt;
// real time: dt = min(delta, 0.1) (time.ml:19), t = seconds since start. frame and tick are both the count.
export function createRuntime(program, { now = () => performance.now() / 1000, fixedDt, pool = null, size = [1, 1] } = {}) {
  if (fixedDt !== undefined && !(Number.isFinite(fixedDt) && fixedDt > 0)) throw new RangeError('fixedDt must be finite and positive');
  const origin = now(), compiled = new Map();
  let last = origin, count = 0;
  const rt = {
    program, pool, input: new Input(size), slots: [], frameValue,
    // A region as a function, compiled once per source text; calls run on the calling thread.
    region(id) {
      const source = program.regions[id];
      if (!compiled.has(source)) compiled.set(source, new Function(`${source}\nreturn region;`)());
      return compiled.get(source);
    },
    // Reload (P6.7): a new program, fresh slots, the canvas and the counters kept.
    load(next) { rt.program = next; rt.slots = []; compiled.clear(); },
    // Run one frame. `override` replaces fields of the live snapshot (Frame_input.t fields, `events` as
    // eventRecord Maps); the live events are drained either way. Resolves to program.frame's result.
    async stepFrame(override) {
      const t = now(), delta = Math.min(t - last, 0.1);
      last = t; count++;
      const dt = fixedDt ?? delta;
      const input = { ...rt.input.snapshot(), t: fixedDt !== undefined ? count * dt : t - origin, dt, frame: count, tick: count, ...override };
      return rt.program.frame(input, rt);
    },
  };
  return rt;
}

// ---- the DOM wiring: the only place that touches the page ----
export async function start(canvas, program, { fixedDt, pool, win = globalThis } = {}) {
  const rect = () => canvas.getBoundingClientRect();
  const rt = createRuntime(program, { fixedDt, pool: pool ?? null, size: [Math.round(rect().width), Math.round(rect().height)] });
  const push = e => rt.input.push(e, rect());
  for (const type of ['pointermove', 'pointerdown', 'pointerup', 'pointercancel']) canvas.addEventListener(type, e => {
    if (type === 'pointerdown') canvas.setPointerCapture?.(e.pointerId);
    push(e);
  });
  canvas.addEventListener('wheel', e => { e.preventDefault(); push(e); }, { passive: false });
  for (const type of ['keydown', 'keyup', 'blur']) win.addEventListener(type, push);
  new win.ResizeObserver(() => push({ type: 'resize' })).observe(canvas);
  let stopped = false;
  const loop = async () => {
    if (stopped) return;
    try { await rt.stepFrame(); } catch (error) { console.error(error); return; }
    win.requestAnimationFrame(loop);
  };
  rt.stop = () => { stopped = true; rt.pool?.close(); };
  win.requestAnimationFrame(loop);
  return rt;
}
