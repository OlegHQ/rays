// node runtime.mjs RUNTIME_JS
//
// Event translation, the held sets, per-frame ordering and the frame clock of tools/web/runtime/runtime.js,
// from synthetic DOM-like events. The expected records are written from the native shapes:
//   event fields and defaults      lib/flow/op.ml:104-107, 120-134 (event_fields, event_value)
//   the frame record               lib/flow/op.ml:108-112, 136-139 (frame_ty, frame_value), frame_input.mli:21-24
//   held buttons and keys, pointer lib/rays/input_state.ml:14-24, 115-116; names lib/rays_editor/live_frame.ml:3-18
//   the clock                      lib/rays/sketch.ml:211-212, lib/rays/time.ml:19
// Prints one "ok" line, or every mismatch and exits 1.

import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [path] = process.argv.slice(2);
if (!path) { console.error('usage: node runtime.mjs RUNTIME_JS'); process.exit(2); }
const R = await import(pathToFileURL(resolve(path)).href);

// ---- a printable form of values: Map -> {..}, Float64Array -> [..], BigInt -> 3n ----
const show = v => JSON.stringify(v, (_, x) => x instanceof Map ? Object.fromEntries(x) : x instanceof Float64Array ? [...x]
  : typeof x === 'bigint' ? `${x}n` : x);
const failures = [];
const same = (got, want, what) => { if (show(got) !== show(want)) failures.push(`${what}\n  got  ${show(got)}\n  want ${show(want)}`); };

// The expected event: every field of event_fields, zero/empty unless given (op.ml:131-134).
const ev = (kind, fields = {}) => ({ kind, key: '', button: '', position: [0, 0, 0], delta: [0, 0, 0], text: '', start: '0n',
  length: '0n', paths: [], error: '', id: '0n', width: '0n', height: '0n', phase: '', time: 0, scale: 0, ...fields });
same(R.EVENT_FIELDS.map(([n]) => n), Object.keys(ev('x')), 'field order');

const rect = { left: 10, top: 20, width: 640, height: 480 };
const dom = (type, more = {}) => ({ type, ...more });
const kinds = input => input.events.map(e => e.get('kind'));

// ---- translate: one event each ----
const t = (e) => R.translate(e, rect);
same(t(dom('pointermove', { clientX: 110, clientY: 70 })), [R.eventRecord('pointer-moved', { position: Float64Array.of(100, 50, 0) })], 'move record');
same(t(dom('pointermove', { clientX: 110, clientY: 70 })).map(e => Object.fromEntries(e)), [ev('pointer-moved', { position: [100, 50, 0] })], 'move');
same(t(dom('pointerdown', { button: 2, clientX: 15, clientY: 25 })).map(e => Object.fromEntries(e)), [ev('pointer-pressed', { button: 'right', position: [5, 5, 0] })], 'down right');
same(t(dom('pointerup', { button: 1, clientX: 10, clientY: 20 })).map(e => Object.fromEntries(e)), [ev('pointer-released', { button: 'middle' })], 'up middle');
same(t(dom('pointerdown', { button: 4, clientX: 10, clientY: 20 }))[0].get('button'), 'x2', 'x2');
same(t(dom('wheel', { deltaX: 50, deltaY: 100, deltaMode: 0 })).map(e => Object.fromEntries(e)), [ev('scrolled', { delta: [0.5, -1, 0] })], 'wheel pixels');
same(t(dom('wheel', { deltaX: 0, deltaY: -3, deltaMode: 1 }))[0].get('delta'), Float64Array.of(0, 1, 0), 'wheel lines');
same(t(dom('keydown', { key: 'a' })).map(e => Object.fromEntries(e)), [ev('key-pressed', { key: 'a' })], 'key a');
same(t(dom('keydown', { key: 'A', shiftKey: true }))[0].get('key'), 'a', 'key letters lowercase');
same(t(dom('keyup', { key: 'ArrowLeft' })).map(e => Object.fromEntries(e)), [ev('key-released', { key: 'left' })], 'key up left');
same(['Control', 'Shift', 'Alt', 'Meta', ' ', 'PageDown', 'F12', 'Escape'].map(R.keyName), ['ctrl', 'shift', 'alt', 'meta', 'space', 'pagedown', 'f12', 'escape'], 'key names');
same(t(dom('keydown', { key: 'Dead' })), [], 'unmapped key ignored');
same(t(dom('resize')).map(e => Object.fromEntries(e)), [ev('resized', { width: '640n', height: '480n' })], 'resize');
same(t(dom('blur')).map(e => Object.fromEntries(e)), [ev('focus-lost')], 'focus lost');

// ---- Input: ordering within a frame, held sets, pointer ----
const input = new R.Input([640, 480]), push = e => input.push(e, rect);
push(dom('keydown', { key: 'w' })); push(dom('keydown', { key: 'Shift' })); push(dom('keydown', { key: 'ArrowUp' }));
push(dom('keydown', { key: 'w', repeat: true }));   // auto-repeat is another event, not another held entry
push(dom('pointermove', { clientX: 60, clientY: 70 }));
push(dom('pointerdown', { button: 2, clientX: 70, clientY: 80 })); push(dom('pointerdown', { button: 0, clientX: 80, clientY: 90 }));
push(dom('wheel', { deltaX: 0, deltaY: 100, deltaMode: 0 }));
push(dom('keyup', { key: 'w' }));
let f = input.snapshot();
same(kinds(f), ['key-pressed', 'key-pressed', 'key-pressed', 'key-pressed', 'pointer-moved', 'pointer-pressed', 'pointer-pressed', 'scrolled', 'key-released'], 'event order');
same(f.keys, ['up', 'shift'], 'held keys, variant order');
same(f.buttons, ['left', 'right'], 'held buttons, variant order');
same(f.pointer, [70, 70], 'pointer follows the last pointer event');
same(f.size, [640, 480], 'size');
// A key list mixes named keys (declaration order) then characters then nothing else.
push(dom('keydown', { key: 'z' })); push(dom('keydown', { key: 'a' })); push(dom('keydown', { key: 'F3' })); push(dom('keydown', { key: 'Tab' }));
same(input.snapshot().keys, ['up', 'tab', 'shift', 'f3', 'a', 'z'], 'held keys: constructors then characters');
// Next frame: events drained, held state and pointer kept.
f = input.snapshot();
same([f.events.length, f.keys.length, f.buttons, f.pointer], [0, 6, ['left', 'right'], [70, 70]], 'held across frames');
push(dom('pointerup', { button: 2, clientX: 5, clientY: 6 }));
same(input.snapshot().buttons, ['left'], 'release removes a button');
push(dom('pointercancel'));
f = input.snapshot();
same([kinds(f), f.buttons], [['pointer-cancelled'], []], 'pointercancel cancels the held buttons');
push(dom('resize')); push(dom('blur'));
f = input.snapshot();
same([kinds(f), f.keys, f.buttons], [['resized', 'focus-lost'], [], []], 'focus loss clears held input');
same(input.snapshot().size, [640, 480], 'size from resized');

// ---- the Lisp frame/input record (op.ml:110-112, 136-139) ----
push(dom('keydown', { key: 'q' })); push(dom('pointermove', { clientX: 11, clientY: 22 }));
const value = R.frameValue({ ...input.snapshot(), t: 1.5, dt: 0.5, frame: 3, tick: 3 });
same([...value.keys()], ['t', 'dt', 'index', 'width', 'height', 'pointer', 'buttons', 'keys', 'events'], 'frame/input fields');
same([value.get('t'), value.get('dt'), value.get('index'), value.get('width'), value.get('height'), value.get('pointer'), value.get('keys')],
  [1.5, 0.5, 3n, 640n, 480n, Float64Array.of(1, 2, 0), ['q']], 'frame/input values');

// ---- the frame clock and the manual step (sketch.ml:211-212, time.ml:19) ----
{
  let clock = 100, seen = [];
  const program = { regions: { r: 'function region(i, u, o, s, e) { return 7; }' }, frame(input, rt) { seen.push(input); rt.slots[0] = (rt.slots[0] ?? 0) + 1; return 'done'; } };
  const rt = R.createRuntime(program, { now: () => clock, size: [800, 600] });
  rt.input.push(dom('keydown', { key: 'x' }), rect);
  clock = 100.25; same(await rt.stepFrame(), 'done', 'step result');
  clock = 105; await rt.stepFrame();   // dt is capped at 0.1 (also on the first frame), t is wall time
  same(seen.map(s => [s.frame, s.tick, s.t, s.dt]), [[1, 1, 0.25, 0.1], [2, 2, 5, 0.1]], 'real time');
  same([seen[0].keys, seen[1].keys, seen[0].size], [['x'], ['x'], [800, 600]], 'step input');
  same(rt.slots, [2], 'slots persist across frames');
  same(rt.region('r')([], [], [], 0, 0), 7, 'region from the table');
  rt.load({ regions: {}, frame() {} }); same(rt.slots, [], 'reload resets slots');
  const fixed = R.createRuntime(program, { fixedDt: 0.5, now: () => clock }); seen = [];
  await fixed.stepFrame(); await fixed.stepFrame();
  same(seen.map(s => [s.frame, s.tick, s.t, s.dt]), [[1, 1, 0.5, 0.5], [2, 2, 1, 0.5]], 'fixed clock: t = count * dt');
  await fixed.stepFrame({ pointer: [9, 8], events: [R.eventRecord('closed')] });
  same([seen[2].pointer, kinds(seen[2]), seen[2].frame], [[9, 8], ['closed'], 3], 'override');
  let threw = false; try { R.createRuntime(program, { fixedDt: 0 }); } catch { threw = true; }
  same(threw, true, 'fixedDt must be positive');
}

if (failures.length) { console.error(failures.join('\n')); process.exit(1); }
console.log('runtime: ok');
