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
  const program = { regions: [{ source: 'function region(i, u, o, s, e) { return 7; }' }], frame(input, state, rt) { seen.push(input); state[0] = (state[0] ?? 0) + 1; return 'done'; } };
  const rt = R.createRuntime(program, { now: () => clock, size: [800, 600] });
  rt.input.push(dom('keydown', { key: 'x' }), rect);
  clock = 100.25; same(await rt.stepFrame(), 'done', 'step result');
  clock = 105; await rt.stepFrame();   // dt is capped at 0.1 (also on the first frame), t is wall time
  same(seen.map(s => [s.frame, s.tick, s.t, s.dt]), [[1, 1, 0.25, 0.1], [2, 2, 5, 0.1]], 'real time');
  same([seen[0].keys, seen[1].keys, seen[0].size], [['x'], ['x'], [800, 600]], 'step input');
  same(rt.slots, [2], 'slots persist across frames');
  same(rt.region(0)([], [], [], 0, 0), 7, 'region from the table');
  rt.load({ regions: [], frame() {} }); same(rt.slots, [], 'reload resets slots');
  const fixed = R.createRuntime(program, { fixedDt: 0.5, now: () => clock }); seen = [];
  await fixed.stepFrame(); await fixed.stepFrame();
  same(seen.map(s => [s.frame, s.tick, s.t, s.dt]), [[1, 1, 0.5, 0.5], [2, 2, 1, 0.5]], 'fixed clock: t = count * dt');
  await fixed.stepFrame({ pointer: [9, 8], events: [R.eventRecord('closed')] });
  same([seen[2].pointer, kinds(seen[2]), seen[2].frame], [[9, 8], ['closed'], 3], 'override');
  let threw = false; try { R.createRuntime(program, { fixedDt: 0 }); } catch { threw = true; }
  same(threw, true, 'fixedDt must be positive');
}

// ---- the frame module contract: frame(input, state, rt), rt services, rollback, invoke ----
{
  const region = `function region(inputs, uniforms, outputs, start, stop) {
    for (let i = start; i < stop; i++) outputs[0][i] = inputs[0][i] * uniforms[0][0] + uniforms[1][0];
    return 0; }`;
  const bytes = new Float64Array([1, 2, 3, 4]).buffer;
  const program = { regions: [{ source: region, count: 4, kept: 4, inputs: [[0, 4]], uniforms: [[10]], frame: [[0, "t"]], length: 1, width: 1, kernel: null }],
    async frame(input, state, rt) {
      rt.marks.push({ type: "marker" });
      const cells = state[0] ??= new Map();
      let c = cells.get("k");
      if (c === undefined) cells.set("k", c = { value: 5, pending: undefined, stamp: input.frame });
      if (c.stamp !== input.frame) { if (c.pending !== undefined) c.value = c.pending; c.pending = undefined; c.stamp = input.frame; }   // as the printed `cell` helper
      if (input.frame === 2) { c.pending = 99; throw new rt.Fail("E_TEST", "boom"); }
      c.pending = c.value + 1;
      return [rt.add(1n, 2n), rt.marks.length, await rt.invoke(0, []), rt.image === undefined];
    } };
  const rt = R.createRuntime(program, { fixedDt: 0.5, data: bytes });
  const [sum, marks, array] = await rt.stepFrame();
  same([sum, marks, array.width, Array.from(array.data)], [3n, 1, 1, [10.5, 20.5, 30.5, 40.5]], "frame module: prims, marks, invoke");
  let code = null; try { await rt.stepFrame(); } catch (e) { code = e.code; }
  same([code, rt.slots[0].get("k").pending === undefined, rt.slots[0].get("k").value], ["E_TEST", true, 6], "a thrown frame drops its pending writes");
  same(rt.marks.length, 1, "marks are emptied before each frame");
}


// ---- reload: watch() against a fake server, rt.load, and gpu.update (plan P6.7) ----
// Generated images: scalar frame captures, shared references, static reuse and reload invalidation.
{
  const calls = [];
  const images = {
    0: { kind: 'map', kernel: 'image0', animated: true, frame: [[2, 't']], args: { regions: [], frame: input => [BigInt(input.size[0]), 3n, input.t, input.t > 0] } },
    1: { kind: 'map', kernel: 'image1', animated: false, frame: [], args: { regions: [], frame: () => [5n, 7n, Float64Array.of(1, 2, 3)] } },
  };
  const program = { regions: [], images, async frame(input, state, rt) { return [await rt.image(0), await rt.image(0), await rt.image(1)]; } };
  const rt = R.createRuntime(program, { fixedDt: 0.5, size: [65, 3], gpu: { poll() {}, image: (id, args) => calls.push([id, args]) } });
  same(await rt.stepFrame(), [1, 1, 2], 'shared image resource identity');
  same(calls[0], ['image0', { width: 65, height: 3, uniforms: { 'uniform:0': 0.5, 'uniform:1': 1, 'frame:2:t': 0.5 } }], 'image scalar captures use this frame');
  same(calls[1][1].uniforms['uniform:0'], Float64Array.of(1, 2, 3), 'image vector capture');
  await rt.stepFrame({ size: [97, 3] });
  same([calls.length, calls[2][1].width, rt.counts], [3, 97, { invoke: 0, gpu: 3 }], 'shared and static images do not repeat dispatch');
  rt.load(program); await rt.stepFrame();
  same(calls.length, 5, 'reload invalidates static and animated images');
  const noGpu = R.createRuntime(program, { fixedDt: 0.5 });
  let code; try { await noGpu.stepFrame(); } catch (e) { code = e.code; }
  same(code, 'E_IMAGE', 'generated image needs the GPU');
}

// ---- reload: watch() against a fake server, rt.load, and gpu.update (plan P6.7) ----
{
  globalThis.compiles = [];
  const region = name => `globalThis.compiles.push(${JSON.stringify(name)});\nfunction region(i, u, o, s, e) { return ${JSON.stringify(name)}; }`;
  const make = (tag, sources) => ({ tag, regions: sources.map(source => ({ source })), frame() { return tag; } });
  const programs = { 1: make('A', [region('r0'), region('r1')]), 2: make('B', [region('r0'), region('r1b')]), 3: make('C', [region('r0'), region('r1b')]) };
  const state = { version: '1', requests: [], status: 200 };
  const fetchFake = async url => {
    const u = new URL(url); state.requests.push(u.pathname + u.search);
    if (u.pathname === '/version') return { ok: state.status === 200, text: async () => `${state.version}\n` };
    const v = u.searchParams.get('v');
    if (u.pathname === '/data.bin') return { ok: true, arrayBuffer: async () => new Float64Array([+v]).buffer };
    if (u.pathname === '/kernels.json') return { ok: true, json: async () => ({ kernels: [], v }) };
    throw new Error(`unexpected ${url}`);
  };
  const imports = [];
  const load = async url => { imports.push(url); return programs[new URL(url).searchParams.get('v')]; };
  const tables = [];
  const rt = R.createRuntime(programs[1], { fixedDt: 0.5 });
  rt.gpu = { poll() {}, update: async t => { tables.push(t.v); } };
  const w = R.watch(rt, { fetch: fetchFake, load, base: 'http://localhost:9/', interval: 0 });
  same([rt.region(0)(), rt.region(1)()], ['r0', 'r1'], 'reload: first program regions');
  rt.slots[0] = 'old';
  same(await w.poll(), false, 'reload: the first poll takes the baseline');
  same(await w.poll(), false, 'reload: an unchanged version does nothing');
  same(imports, [], 'reload: nothing imported yet');
  state.version = '2';
  same(await w.poll(), true, 'reload: a new version reloads');
  same([rt.program.tag, rt.slots, rt.reloads, new Float64Array(rt.data)[0], tables, imports],
    ['B', [], 1, 2, ['2'], ['http://localhost:9/program.js?v=2']], 'reload: program swapped, slots reset, data and kernels refetched');
  same([rt.region(0)(), rt.region(1)()], ['r0', 'r1b'], 'reload: regions come from the new program');
  same(globalThis.compiles, ['r0', 'r1', 'r1b'], 'reload: only the region whose text changed is compiled again');
  state.version = '3';
  await w.poll();
  same([rt.region(0)(), rt.region(1)(), globalThis.compiles.length, rt.reloads], ['r0', 'r1b', 3, 2], 'reload: identical regions are not recompiled');
  // a frame still runs the new program
  same(await rt.stepFrame(), 'C', 'reload: the frame is the new one');
  // not served by the watch server: stop silently
  const quiet = [];
  const origError = console.error; console.error = (...a) => quiet.push(a);
  state.status = 404; state.requests.length = 0;
  const ticking = R.watch(rt, { fetch: fetchFake, load, base: 'http://localhost:9/', interval: 5 });
  await new Promise(r => setTimeout(r, 120));
  same([state.requests.length, quiet], [1, []], 'reload: /version 404 stops polling, silently');
  const broken = R.watch(rt, { fetch: async () => { throw new TypeError('fetch failed'); }, load, interval: 5 });
  await new Promise(r => setTimeout(r, 60));
  same(quiet, [], 'reload: a fetch error stops polling, silently');
  console.error = origError; ticking.stop(); broken.stop();
}
{
  // gpu.update compiles only the kernels whose text changed
  let modules = 0, released = 0;
  globalThis.GPUBufferUsage = { STORAGE: 128, COPY_DST: 8 }; globalThis.GPUShaderStage = { COMPUTE: 4 };
  const device = { lost: new Promise(() => {}), addEventListener() {}, limits: {}, queue: { writeBuffer() {} },
    createShaderModule: () => { modules++; return { getCompilationInfo: async () => ({ messages: [] }) }; },
    createBindGroupLayout: () => ({}), createPipelineLayout: () => ({}), createComputePipelineAsync: async () => ({}),
    createBuffer: () => ({ destroy() { released++; } }), destroy() {} };
  const win = { navigator: { gpu: { requestAdapter: async () => ({ requestDevice: async () => device }) } } };
  const { createGpu } = await import(new URL('./gpu.js', pathToFileURL(resolve(path))).href);
  const kernel = (id, source, seeds = []) => ({ id, entry: `e_${id}`, source, interface: [], table_seeds: seeds, tables: seeds.map(() => [0]), uniform_layout: [], uniform_bytes: 16, input_widths: [], output_widths: [] });
  const gpu = await createGpu({ kernels: [kernel('k0', 'a'), kernel('k1', 'b', [31])] }, { win });
  same(modules, 2, 'gpu.update: every kernel compiled at load');
  const k0 = gpu.kernels.get('k0').pipeline;
  await gpu.update({ kernels: [kernel('k0', 'a'), kernel('k1', 'b2', [31]), kernel('k2', 'c')] });
  same([modules, gpu.kernels.get('k0').pipeline === k0, [...gpu.kernels.keys()], released], [4, true, ['k0', 'k1', 'k2'], 1], 'gpu.update: only changed and new kernels compile; the old table is released');
  await gpu.update({ kernels: [kernel('k0', 'a')] });
  same([modules, [...gpu.kernels.keys()]], [4, ['k0']], 'gpu.update: an unchanged table compiles nothing, dropped kernels go');
}

{
  // GPU attribute regions (P6.4a): a kernel group runs once per frame, or once per load without a frame fact; its inputs
  // are uploaded once; the value is a packed array of device references; the frame never touches the CPU region.
  const calls = [], uploads = [];
  const gpu = { poll() {}, upload: a => { uploads.push(a.length); return { destroy() {} }; },
    dispatch: (id, o) => calls.push([id, o.count, Object.keys(o.uniforms).sort(), o.uniforms['frame:3:t'], o.inputs.length]) };
  const bytes = new Float64Array(8).buffer;
  const region = { source: '', count: 4, kept: 4, inputs: [[0, 4]], uniforms: [[7]], frame: [[3, 't']], length: 4, width: 3, kernel: 'g0', gpu: { output: 0 } };
  const steady = { source: '', count: 4, kept: 4, inputs: [[0, 4]], uniforms: [], frame: [], length: 4, width: 1, kernel: 'g1', gpu: { output: 0 } };
  const program = { regions: [region, steady],
    gpu: { g0: { count: 4, inputs: [[0, 4]], uniforms: [[7]], frame: [[3, 't']] }, g1: { count: 4, inputs: [[0, 4]], uniforms: [], frame: [] } },
    async frame(input, state, rt) { return [await rt.gpuArray(0), await rt.gpuArray(0), await rt.gpuArray(1)]; } };
  const errors = [];
  const rt = R.createRuntime(program, { fixedDt: 0.5, data: bytes, gpu, gpuErrors: errors });
  const [a, b, c] = await rt.stepFrame();
  same([a.width, a.data, b.data, c.data, calls.length, uploads, rt.counts],
    [3, { gpu: 'g0', output: 0, length: 12 }, { gpu: 'g0', output: 0, length: 12 }, { gpu: 'g1', output: 0, length: 4 }, 2, [4, 4], { invoke: 0, gpu: 2 }], 'gpu: one dispatch per group per frame, device references');
  same(calls[0], ['g0', 4, ['frame:3:t', 'uniform:0'], 0.5, 1], 'gpu: uniforms by layout name, frame facts from the frame');
  await rt.stepFrame();
  same([calls.length, calls[2][3], uploads.length], [3, 1, 2], 'gpu: the frame-rate group runs again, the steady one does not, inputs stay uploaded');
  rt.load(program); await rt.stepFrame();
  same([calls.length, uploads.length], [5, 4], 'gpu: a reload runs every group again with fresh inputs');
  errors.push({ code: 'E_KERNEL', message: 'GPU output contains a nonfinite value.' });
  let code = null; try { await rt.stepFrame(); } catch (e) { code = e.code; }
  same([code, errors.length], ['E_KERNEL', 0], 'gpu: a status word of an earlier dispatch fails the next frame');
  const bare = R.createRuntime(program, { data: bytes });
  let none = null; try { await bare.stepFrame(); } catch (e) { none = e.code; }
  same(none, 'E_KERNEL', 'gpu: a GPU region without a device is an error, never a silent CPU run');
}

// Reload cannot destroy a texture while an asynchronous image drawing still uses it, or let
// the next frame start with a partly replaced program/device table.
{
  let releaseFrame, releaseUpdate, updates = 0, version = '1';
  const drawing = new Promise(resolve => { releaseFrame = resolve; });
  const updating = new Promise(resolve => { releaseUpdate = resolve; });
  const before = { regions: [], async frame() { await drawing; return 'old'; } };
  const after = { regions: [], frame() { return 'new'; } };
  const rt = R.createRuntime(before, { fixedDt: 0.5, gpu: { poll() {}, async update() { updates++; await updating; } } });
  const w = R.watch(rt, { interval: 0, load: async () => after,
    fetch: async () => ({ ok: true, text: async () => version, arrayBuffer: async () => new ArrayBuffer(0), json: async () => ({ kernels: [] }) }) });
  await w.poll();
  const first = rt.stepFrame(); version = '2'; const reload = w.poll();
  await new Promise(resolve => setTimeout(resolve, 0));
  same(updates, 0, 'reload waits for the image drawing to finish');
  releaseFrame(); await first;
  await new Promise(resolve => setTimeout(resolve, 0));
  const second = rt.stepFrame();
  same([updates, rt.current.frame], [1, 1], 'the next frame waits for resource replacement');
  releaseUpdate(); await reload;
  same(await second, 'new', 'the next frame uses the complete replacement program');
}

if (failures.length) { console.error(failures.join('\n')); process.exit(1); }
console.log('runtime: ok');
