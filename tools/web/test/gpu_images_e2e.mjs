// Generated images: actual exported pages, GPU-resident RGBA8 and native Image_kernel pixels.
// node gpu_images_e2e.mjs LISP_EXE MARKS_SHOT_EXE ROOT
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { chromeAvailable, ISOLATION, launch, serve } from './chrome.mjs';
import { compare, decodePng } from './png.mjs';

const [lisp, shot, root] = process.argv.slice(2).map(p => resolve(p));
if (!chromeAvailable()) { console.log('gpu_images_e2e: skipped (Google Chrome not found)'); process.exit(0); }
const synthetic = `(workspace images
  (graph picture :context draw
    (let* [p (image/map (fn [uv] [(- (* uv.x 2) 0.5) uv.y 0.5 0.5])
                  :width (frame/width) :height (frame/height))
           s (image/map (fn [uv] [(/ 0.5 255) (/ 1.5 255) (/ 2.5 255) (/ 127.5 255)]) :width 3 :height 5)]
      (draw/merge (draw/background "#142030")
        (draw/image p)
        (draw/translate [4 3 0] (draw/image p :at [10 7 0] :scale 0.5 :angle 0.4))
        (draw/image s :at [2 2 0] :scale 3)))))`;
const cases = [
  { name: 'synthetic', dir: null, sizes: [[65, 43], [97, 51]], frames: 3, perFrame: 1, static: 1 },
  { name: 'flow_contours', dir: 'sketches/flow_contours', sizes: [[640, 480], [800, 600]], frames: 3, perFrame: 6, static: 0 },
  { name: 'flow_image_kernel', dir: 'sketches/flow_image_kernel', sizes: [[320, 280]], frames: 3, perFrame: 1, static: 0 },
  { name: 'flow_shader', dir: 'sketches/flow_shader', sizes: [[760, 760]], frames: 3, perFrame: 19, static: 6 },
];
const read = dir => Object.fromEntries(readdirSync(dir, { recursive: true }).filter(f => statSync(join(dir, f)).isFile())
  .map(f => ['/' + f, readFileSync(join(dir, f))]));
const page = (sizes, frames) => `<!doctype html><body style="margin:0"><canvas id="c"></canvas>
<script type="module">
import { start } from './runtime/runtime.js';
import * as program from './program.js';
window.__result = (async () => {
  const canvas = document.getElementById('c');
  const sizes = ${JSON.stringify(sizes)};
  canvas.style.width = sizes[0][0] + 'px'; canvas.style.height = sizes[0][1] + 'px';
  const data = await (await fetch('data.bin')).arrayBuffer();
  const rt = await start(canvas, program, { fixedDt: 1 / 60, data });
  if (!rt) return { unavailable: true };
  rt.halt(); rt.presenter.dpr = 1;
  const results = [], references = [];
  for (let round = 0; round < sizes.length; round++) {
    const [W, H] = sizes[round];
    for (let i = 0; i < ${frames}; i++) await rt.stepFrame({ size: [W, H], pointer: [100, 100] });
    await rt.gpu.flush();
    rt.presenter.present(rt.marks, [W, H]);
    const g = new OffscreenCanvas(W, H).getContext('2d', { willReadFrequently: true });
    g.drawImage(canvas, 0, 0);
    results.push({ raw: Array.from(g.getImageData(0, 0, W, H).data), counts: { ...rt.counts }, frame: rt.current.frame });
    const image = Object.values(program.images)[0].kernel;
    const texture = rt.gpu.imageTexture(image).texture;
    await rt.stepFrame({ size: [W, H] });
    references.push(texture === rt.gpu.imageTexture(image).texture);
  }
  const table = await (await fetch('kernels.json')).json();
  const old = rt.gpu.imageTexture(Object.values(program.images)[0].kernel).texture;
  await rt.gpu.update(table); rt.load(program);
  await rt.stepFrame({ size: sizes.at(-1) }); await rt.gpu.flush();
  const reloaded = old !== rt.gpu.imageTexture(Object.values(program.images)[0].kernel).texture;
  const bounds = [];
  for (const width of [0, -1, 1.5, Infinity, rt.gpu.device.limits.maxTextureDimension2D + 1]) {
    try { rt.gpu.image(Object.values(program.images)[0].kernel, { width, height: 1, uniforms: {} }); }
    catch (e) { bounds.push(e.code); }
  }
  let ties = null;
  const t = Object.values(program.images).map(i => rt.gpu.imageTexture(i.kernel)).find(t => t.w === 3 && t.h === 5);
  if (t) {
    const device = rt.gpu.device, buffer = device.createBuffer({ size: 256 * 5, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
    const encoder = device.createCommandEncoder();
    encoder.copyTextureToBuffer({ texture: t.texture }, { buffer, bytesPerRow: 256 }, [3, 5]);
    device.queue.submit([encoder.finish()]); await buffer.mapAsync(GPUMapMode.READ);
    ties = Array.from(new Uint8Array(buffer.getMappedRange()).slice(0, 4)); buffer.unmap(); buffer.destroy();
  }
  return { results, references, reloaded, bounds, ties, errors: [...rt.presenter.errors, ...rt.gpuErrors.map(e => e.message)] };
})().catch(e => ({ failure: String(e.stack ?? e) }));
</script>`;
const wait = '(async () => { while (!window.__result) await new Promise(r => setTimeout(r, 50)); return window.__result; })()';
for (const c of cases) {
  const tmp = mkdtempSync(join(tmpdir(), 'gpu-images-'));
  let dir = c.dir;
  if (!dir) { dir = join(tmp, 'src'); mkdirSync(dir); writeFileSync(join(dir, 'sketch.rays'), synthetic); }
  execFileSync(lisp, ['web', join(dir, 'sketch.rays'), '-o', join(tmp, 'out')], { cwd: root, stdio: 'inherit' });
  const files = read(join(tmp, 'out')); files['/test.html'] = page(c.sizes, c.frames);
  const server = await serve(files, ISOLATION), browser = await launch(server.url + 'test.html');
  let r;
  try { r = await browser.evaluate(wait); } finally { browser.close(); server.close(); }
  if (r.unavailable) { console.error('gpu_images_e2e: WebGPU unavailable'); process.exit(3); }
  assert(!r.failure, r.failure);
  assert.deepEqual(r.errors, [], `${c.name}: GPU validation`);
  assert(r.references.every(Boolean), `${c.name}: unchanged dimensions must reuse texture`);
  assert(r.reloaded, `${c.name}: reload must replace image storage`);
  assert.deepEqual(r.bounds, Array(5).fill('E_IMAGE'));
  if (c.name === 'synthetic') assert.deepEqual(r.ties, [0, 2, 2, 128], 'RGBA8 rounding must use ties to even');
  for (let round = 0; round < c.sizes.length; round++) {
    const [W, H] = c.sizes[round], got = r.results[round];
    execFileSync(shot, [dir, join(tmp, 'native.png'), String(W), String(H), String(got.frame), ...(['flow_contours', 'flow_shader'].includes(c.name) ? ['--gpu-images'] : [])], { cwd: root, stdio: 'inherit' });
    const native = decodePng(join(tmp, 'native.png')), m = compare(Buffer.from(got.raw), native.data, W * H);
    if (!m.ok) {
      const differences = [];
      for (let i = 0; i < W * H; i++) {
        const d = Math.max(...[0, 1, 2].map(k => Math.abs(got.raw[i * 4 + k] - native.data[i * 4 + k])));
        if (d > 8 && differences.length < 25) differences.push([i % W, Math.floor(i / W), d]);
      }
      console.log('first differences', differences);
    }
    console.log(`${m.ok ? 'ok' : 'FAIL'} ${c.name} ${W}x${H} frame ${got.frame}: ${m.over} pixels differ by >8, worst ${m.worst}, mean ${m.mean.toFixed(4)}; ${got.counts.gpu} GPU dispatches, ${got.counts.invoke} CPU invokes`);
    assert(m.ok, `${c.name}: native pixel parity`);
    assert.equal(got.counts.invoke, 0);
    assert.equal(got.counts.gpu, got.frame * c.perFrame + c.static);
  }
}

// Exercise the actual watch command, browser imports and resident pixels. Changing a scalar
// capture leaves WGSL unchanged but must import the new argument module instead of its cached predecessor.
{
  const tmp = mkdtempSync(join(tmpdir(), 'image-watch-')), source = join(tmp, 'sketch.rays');
  const sketch = factor => `(workspace live (graph picture :context draw
    (let* [bias (* t ${factor})]
      (draw/image (image/map (fn [uv] [(+ uv.x bias) uv.y 0.5 1]) :width 13 :height 9)))))`;
  writeFileSync(source, sketch(0.1));
  const proc = spawn(lisp, ['web', '--watch', source, '-o', join(tmp, 'out'), '--port', '0'], { cwd: root });
  let log = '', err = '', browser;
  proc.stderr.on('data', d => { err += d; });
  try {
    const url = await new Promise((res, reject) => {
      const timer = setTimeout(() => reject(new Error('watch startup: ' + err)), 10000);
      proc.stdout.on('data', d => { log += d; const m = /serving (http:\/\/\S+)/.exec(log); if (m) { clearTimeout(timer); res(m[1]); } });
      proc.on('exit', () => { clearTimeout(timer); reject(new Error('watch exited: ' + err)); });
    });
    browser = await launch(url);
    const ready = async test => {
      for (let i = 0; i < 100; i++) {
        if (await browser.evaluate(test).catch(() => false)) return;
        await new Promise(r => setTimeout(r, 100));
      }
      throw new Error('browser watch timeout: ' + err);
    };
    await ready('Boolean(window.__rays?.current)');
    await browser.evaluate(`(() => { __rays.halt(); const id = Object.values(__rays.program.images)[0].kernel;
      window.originalPipeline = __rays.gpu.kernels.get(id).pipeline; return true; })()`);
    await new Promise(r => setTimeout(r, 600));   // establish /version baseline
    writeFileSync(source, sketch(0.4));
    await ready('(__rays.reloads ?? 0) === 1');
    const r = await browser.evaluate(`(async () => {
      const rt = __rays, id = Object.values(rt.program.images)[0].kernel;
      await rt.stepFrame({ t: 0.5, size: [13, 9] }); await rt.gpu.flush();
      const rgba = await rt.gpu.readback(id + ':out0');
      return { red: rgba[0], samePipeline: rt.gpu.kernels.get(id).pipeline === window.originalPipeline,
        errors: [...rt.presenter.errors, ...rt.gpuErrors], reloads: rt.reloads };
    })()`);
    assert(Math.abs(r.red - (0.5 / 13 + 0.2)) < 1e-6, 'watch must update live captures');
    assert(r.samePipeline, 'capture-only edits reuse the pixel pipeline');
    assert.deepEqual(r.errors, []);
    const version = await (await fetch(new URL('version', url))).text();
    writeFileSync(source, '(workspace broken');
    await new Promise(r => setTimeout(r, 1200));
    assert.equal(await (await fetch(new URL('version', url))).text(), version, 'refusal keeps the last successful image export');
    assert.match(err, /web: refused/);
    console.log('ok image watch: live captures reload, pipeline reused, refused edit keeps last good export');
  } finally { browser?.close(); proc.kill(); }
}
