// node web_shot.mjs URL DIR WIDTH HEIGHT FRAME...
//
// Pixel parity of the served page in a real browser (plan P6.8). URL is a `rays-lisp web --watch` server (the page runs
// `start`: one GPUDevice, worker pool, presenter, watcher). The rAF loop is halted, the state is reset (`rt.load`), and
// the frames are driven by hand with a fixed clock, as tools/marks_shot.exe does natively: dt 1/60, t = frame * dt,
// pointer (100, 100), no keys, buttons or events, size WIDTH x HEIGHT, dpr 1. At each listed FRAME the canvas is
// presented and read back to DIR/web_FRAME.png, and compared with DIR/native_FRAME.png by the metric of png.mjs.
// Exit: 0 all frames pass, 1 a mismatch, 3 WebGPU unavailable, 4 the page did not start.
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { launch } from './chrome.mjs';
import { compare, decodePng } from './png.mjs';

const [url, dir, w, h, ...frames] = process.argv.slice(2);
const [W, H] = [Number(w), Number(h)], wanted = frames.map(Number), last = Math.max(0, ...wanted), TIME = Number(process.env.WEB_SHOT_TIME ?? 0);
const browser = await launch(url, process.env.WEB_SHOT_CHROME_FLAGS?.split(' '));   // the flags are for testing the unavailable path
const wait = async (what, test, ms = 30000) => {
  const end = Date.now() + ms;
  while (Date.now() < end) { try { const v = await test(); if (v) return v; } catch { /* the page is not ready */ } await new Promise(r => setTimeout(r, 100)); }
  throw new Error(`timed out waiting for ${what}`);
};
let code = 0;
try {
  try {
    await wait('the page to start', () => browser.evaluate(`(globalThis.__rays?.presenter && document.readyState === 'complete')`));
  } catch (error) {
    const text = await browser.evaluate('document.body.innerText').catch(() => '');
    if (/WebGPU/.test(text)) { console.error(`web_shot: WebGPU unavailable: ${text.trim()}`); code = 3; } else { console.error(`web_shot: ${error.message} ${text.slice(0, 200)}`); code = 4; }
    throw code;
  }
  if (TIME) {   // P7.3 timing mode: no comparison
    const r = await browser.evaluate(`(async () => {
      const rt = __rays, p = rt.presenter, stats = a => { const s = [...a].sort((x, y) => x - y);
        return { median: s[s.length >> 1], p95: s[Math.floor(s.length * 0.95)], mean: s.reduce((x, y) => x + y, 0) / s.length }; };
      const times = [], present = p.present.bind(p);   // the page's own loop: intervals between presented frames
      p.present = (...a) => { times.push(performance.now()); return present(...a); };
      while (times.length < ${TIME} + 1) await new Promise(r => setTimeout(r, 50));
      const rafMs = times.slice(0, ${TIME} + 1).map((t, i, a) => t - a[i - 1]).slice(1);
      p.present = present; rt.halt(); await new Promise(r => setTimeout(r, 400));
      rt.load(rt.program); p.dpr = 1;
      const cost = [], dt = 1 / 60, device = rt.gpu.device;
      for (let f = 1; f <= ${TIME}; f++) {
        const a = performance.now();
        await rt.stepFrame({ t: f * dt, dt, frame: f, tick: f, pointer: [100, 100], size: [${W}, ${H}], events: [], keys: [], buttons: [] });
        p.present(rt.marks, [${W}, ${H}]); await device.queue.onSubmittedWorkDone();
        cost.push(performance.now() - a);
      }
      return { raf: stats(rafMs), uncapped: stats(cost), loadMs: rt.firstPresentMs, compileMs: rt.gpu.compileMs, counts: rt.counts, errors: p.errors, ua: navigator.userAgent };
    })()`);
    console.log('TIMING ' + JSON.stringify(r));
    if (r.errors.length) code = 1;
    throw code;
  }
  const shots = await browser.evaluate(`(async () => {
    const rt = __rays, out = {};
    rt.halt(); await new Promise(r => setTimeout(r, 400));   // let a frame in flight finish
    rt.load(rt.program);                                       // fresh state slots
    rt.presenter.dpr = 1;
    const dt = 1 / 60, g = document.createElement('canvas').getContext('2d', { willReadFrequently: true });
    for (let f = 1; f <= ${last}; f++) {
      await rt.stepFrame({ t: f * dt, dt, frame: f, tick: f, pointer: [100, 100], size: [${W}, ${H}], events: [], keys: [], buttons: [] });
      if (!${JSON.stringify(wanted)}.includes(f)) continue;
      rt.presenter.present(rt.marks, [${W}, ${H}]);
      g.canvas.width = rt.presenter.canvas.width; g.canvas.height = rt.presenter.canvas.height; g.drawImage(rt.presenter.canvas, 0, 0);
      out[f] = { png: g.canvas.toDataURL('image/png'), size: [g.canvas.width, g.canvas.height], marks: rt.marks.length };
    }
    return { out, errors: rt.presenter.errors, counts: rt.counts };
  })()`);
  for (const f of wanted) {
    const shot = shots.out[f];
    writeFileSync(join(dir, `web_${f}.png`), Buffer.from(shot.png.split(',')[1], 'base64'));
    const web = decodePng(join(dir, `web_${f}.png`)), native = decodePng(join(dir, `native_${f}.png`));
    if (web.width !== native.width || web.height !== native.height) { console.log(`FAIL frame ${f}: size ${web.width}x${web.height} against native ${native.width}x${native.height}`); code = 1; continue; }
    const m = compare(web.data, native.data, W * H);
    console.log(`${m.ok ? 'ok  ' : 'FAIL'} frame ${f}: ${m.over} of ${W * H} pixels differ by more than 8 (${(100 * m.fraction).toFixed(3)}%), worst ${m.worst}, mean ${m.mean.toFixed(4)}; ${shot.marks} mark entries`);
    if (!m.ok) code = 1;
  }
  if (shots.errors.length) { console.log('FAIL presenter errors: ' + shots.errors); code = 1; }
  console.log(`web_shot: CPU region invokes ${shots.counts.invoke}, GPU dispatches ${shots.counts.gpu}`);
} catch (error) { if (typeof error !== 'number') { console.error(`web_shot: ${error.stack ?? error}`); code = 4; } }
browser.close();
setTimeout(() => process.exit(code), 600);
