// Launches the local Google Chrome headless against a tiny localhost server and evaluates an expression in
// the page over the DevTools protocol (raw WebSocket, node 22+; no npm). Shared by gpu_check.mjs (P6.3) and
// the browser pixel parity harness (P6.8). `--headless=new` alone gives a working Metal WebGPU adapter on
// Apple Silicon (probed 2026-10-11: no --enable-unsafe-webgpu or --use-angle needed).
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import http from 'node:http';
import { tmpdir } from 'node:os';

export const CHROME = process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
export const chromeAvailable = () => existsSync(CHROME);
const TYPES = { html: 'text/html', js: 'text/javascript', mjs: 'text/javascript', json: 'application/json', wgsl: 'text/plain' };

// files: { '/path': string | Buffer }; headers: extra response headers (ISOLATION below). Returns {url, close()}. localhost is a secure context, which WebGPU needs.
export async function serve(files, headers = {}) {
  const server = http.createServer((req, res) => {
    const body = files[new URL(req.url, 'http://x').pathname];
    if (body === undefined) { res.statusCode = 404; return res.end(); }
    for (const [name, value] of Object.entries(headers)) res.setHeader(name, value);
    res.setHeader('content-type', TYPES[req.url.split('.').pop()] ?? 'text/html');
    res.end(body);
  });
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  return { url: `http://localhost:${server.address().port}/`, close: () => server.close() };
}

// Opens `url` in a fresh Chrome profile. Returns {evaluate(expression) -> value (awaits promises), close()}.
export async function launch(url, flags = ['--headless=new']) {
  const dir = mkdtempSync(`${tmpdir()}/chrome-`);
  const chrome = spawn(CHROME, [...flags, '--no-first-run', '--no-default-browser-check', '--remote-debugging-port=0',
    `--user-data-dir=${dir}`, url], { stdio: ['ignore', 'ignore', 'pipe'] });
  let log = '';
  const endpoint = await new Promise((resolve, reject) => {
    chrome.stderr.on('data', d => { log += d; const m = /ws:\/\/\S+/.exec(log); if (m) resolve(m[0]); });
    chrome.on('exit', () => reject(new Error(`Chrome exited early: ${log}`)));
    setTimeout(() => reject(new Error(`Chrome did not report a DevTools port: ${log}`)), 20000);
  });
  const port = new URL(endpoint).port;
  let page;
  for (let i = 0; i < 50 && !page; i++) {
    page = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find(t => t.type === 'page' && t.url.startsWith('http'));
    if (!page) await new Promise(r => setTimeout(r, 100));
  }
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(r => { socket.onopen = r; });
  let id = 0;
  const waiting = new Map();
  socket.onmessage = m => { const j = JSON.parse(m.data); waiting.get(j.id)?.(j); };
  const call = (method, params) => new Promise(resolve => { waiting.set(++id, resolve); socket.send(JSON.stringify({ id, method, params })); });
  return {
    call,
    async evaluate(expression) {
      let j;   // the first navigation can destroy the context under us: retry
      for (let tries = 0; tries < 20; tries++) {
        j = await call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
        if (!/context was destroyed|default execution context/.test(j.error?.message ?? '')) break;
        await new Promise(r => setTimeout(r, 200));
      }
      if (j.error || j.result.exceptionDetails) throw new Error(JSON.stringify(j.error ?? j.result.exceptionDetails));
      return j.result.result.value;
    },
    close() { socket.close(); chrome.kill(); setTimeout(() => rmSync(dir, { recursive: true, force: true }), 500); },
  };
}

// What the worker pool needs (workers.js checkIsolation); pass as serve's second argument.
export const ISOLATION = { 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' };
