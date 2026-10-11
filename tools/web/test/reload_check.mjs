// node reload_check.mjs RAYS_LISP SKETCH.rays
//
// End-to-end reload (plan P6.7) in headless Chrome: start `rays-lisp web --watch` on a temporary copy of the
// sketch, open the page, edit the file, and see the page swap its program without a navigation (a marker set on
// `window` survives; the runtime counts reloads in `__rays.reloads`). Needs Google Chrome (a missing Chrome is a
// printed skip); WebGPU is not needed (CPU regions only). Not part of runtest: alias qualification-web.
import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { chromeAvailable, launch } from './chrome.mjs';

const [lisp, sketch] = process.argv.slice(2);
if (!lisp || !sketch) { console.error('usage: node reload_check.mjs RAYS_LISP SKETCH.rays'); process.exit(2); }
if (!chromeAvailable()) { console.log('reload_check: skipped (Google Chrome not found)'); process.exit(0); }

const dir = mkdtempSync(`${tmpdir()}/rays-reload-`);
const file = `${dir}/live.rays`;
writeFileSync(file, readFileSync(sketch));   // not copyFileSync: it keeps a read-only mode
const server = spawn(lisp, ['web', '--watch', file, '-o', `${dir}/out`, '--port', '0'], { stdio: ['ignore', 'pipe', 'inherit'] });
let browser;
const finish = code => { browser?.close(); server.kill(); setTimeout(() => { rmSync(dir, { recursive: true, force: true }); process.exit(code); }, 600); };
const fail = message => { console.error(`reload_check: FAIL ${message}`); finish(1); };
const wait = async (what, test, ms = 20000) => {
  const end = Date.now() + ms;
  while (Date.now() < end) { try { const v = await test(); if (v) return v; } catch { /* the page is not ready */ } await new Promise(r => setTimeout(r, 100)); }
  throw new Error(`timed out waiting for ${what}`);
};
try {
  let out = '';
  const port = await new Promise((resolve, reject) => {
    server.stdout.on('data', d => { out += d; const m = /serving http:\/\/127\.0\.0\.1:(\d+)\//.exec(out); if (m) resolve(m[1]); });
    server.on('exit', () => reject(new Error(`server exited: ${out}`)));
    setTimeout(() => reject(new Error('server did not start')), 20000);
  });
  browser = await launch(`http://127.0.0.1:${port}/`);
  await wait('the first frames', () => browser.evaluate(`(globalThis.__rays?.input && globalThis.crossOriginIsolated && document.readyState === 'complete')`));
  const frame = () => browser.evaluate(`String(__rays.program.frame)`);
  const before = await frame();
  await browser.evaluate(`window.__marker = 'same page'; true`);
  // The radius 24 is a constant of the frame program; the edit changes it, hence program.js and the version.
  const text = readFileSync(file, 'utf8');
  if (!text.includes('at 24')) throw new Error('the sketch no longer has the radius 24');
  writeFileSync(file, text.replace('at 24', 'at 31'));
  await wait('a reload', () => browser.evaluate(`__rays.reloads === 1`));
  const after = await frame();
  const marker = await browser.evaluate(`window.__marker`);
  const navigations = await browser.evaluate(`performance.getEntriesByType('navigation').length`);
  if (before === after || !after.includes('31n') || after.includes('24n')) throw new Error('the page did not pick up the edit: ' + after.slice(0, 600));
  if (marker !== 'same page' || navigations !== 1) throw new Error('the page navigated');
  // frames still run, and an unchanged file reloads nothing more
  const frames = await browser.evaluate(`new Promise(r => setTimeout(() => r(__rays.marks.length > 0 ? __rays.reloads : -1), 1500))`);
  if (frames !== 1) throw new Error(`unexpected extra reload (${frames})`);
  console.log('reload_check: ok (edit picked up without a navigation, 1 reload)');
  finish(0);
} catch (error) { fail(error.message); }
