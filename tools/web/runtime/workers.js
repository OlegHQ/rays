// Browser runtime, part 2: the worker pool over SharedArrayBuffer.
//
// A region is the source text `Js.region` emits ("function region(inputs, uniforms, outputs, start, stop)",
// returns 0, or 1 for a non-finite value). Same schedule as native `Packed.force`:
//   - blocks of 1,024 elements (packed.ml:208), 16 blocks per chunk (packed.ml:209), so a chunk is 16,384;
//   - only `Collect` regions run chunks in parallel (packed.ml:346: Parallel.for_ ~chunk_size:1 over the
//     chunks; parallel.ml:123-137 runs a range shorter than its chunk size, here one chunk, in the caller);
//   - Sum/Accumulate run one ascending range on the calling thread with one state array (packed.ml:347-354,
//     js.mli): `pool.region(id)(inputs, uniforms, outputs, 0, count)`.
// Workers are asynchronous, so `collect` returns a promise and a frame that uses it is `async`.
// Outputs must be SharedArrayBuffer-backed (`pool.alloc`); inputs are copied into shared memory if they are not.

export const CHUNK = 16 * 1024;

// Plain message, no fallback: the page needs cross-origin isolation for SharedArrayBuffer.
export function checkIsolation(g = globalThis) {
  if (g.crossOriginIsolated) return true;
  const message = 'This page needs cross-origin isolation (Cross-Origin-Opener-Policy: same-origin and '
    + 'Cross-Origin-Embedder-Policy: require-corp) to run. Serve it with those headers.';
  if (g.document?.body) g.document.body.textContent = message; else console.error(message);
  return false;
}

// The worker script, the same text under a browser Worker and node:worker_threads.
const WORKER = `
const port = typeof require === 'function' ? require('node:worker_threads').parentPort : self;
const listen = f => port.on ? port.on('message', f) : (port.onmessage = e => f(e.data));
const regions = new Map();
listen(m => {
  try {
    if (m.op === 'load') regions.set(m.id, new Function(m.source + '\\nreturn region;')());
    else port.postMessage({ status: regions.get(m.id)(m.inputs, m.uniforms, m.outputs, m.start, m.stop) });
  } catch (error) { port.postMessage({ error: String(error) }); }
});`;

// The one adapter: {post(message), onMessage(f), stop()}.
export async function spawnWorker() {
  if (typeof Worker === 'function') {
    const url = URL.createObjectURL(new Blob([WORKER], { type: 'text/javascript' })), w = new Worker(url);
    return { post: m => w.postMessage(m), onMessage: f => { w.onmessage = e => f(e.data); }, stop: () => { w.terminate(); URL.revokeObjectURL(url); } };
  }
  const { Worker: NodeWorker } = await import('node:worker_threads'), w = new NodeWorker(WORKER, { eval: true });
  return { post: m => w.postMessage(m), onMessage: f => w.on('message', f), stop: () => w.terminate() };
}

const shared = a => {
  if (a.buffer instanceof SharedArrayBuffer) return a;
  const copy = new Float64Array(new SharedArrayBuffer(a.byteLength)); copy.set(a); return copy;
};

export async function createPool({ size = Math.max(1, (globalThis.navigator?.hardwareConcurrency ?? 4) - 1), spawn = spawnWorker } = {}) {
  const slots = await Promise.all(Array.from({ length: size }, async () => {
    const slot = { w: await spawn(), done: null };
    slot.w.onMessage(m => { const f = slot.done; slot.done = null; f(m); });
    return slot;
  }));
  const sources = new Map(), compiled = new Map();
  let tail = Promise.resolve();
  const pool = {
    size,
    alloc: n => new Float64Array(new SharedArrayBuffer(n * 8)),
    // Register a region under `id`; the same text is a no-op. Compiles locally first, so a bad source throws here.
    load(id, source) {
      if (sources.get(id) === source) return;
      compiled.set(id, new Function(`${source}\nreturn region;`)());
      sources.set(id, source);
      for (const s of slots) s.w.post({ op: 'load', id, source });
    },
    region: id => compiled.get(id),
    // Run a Collect region over [0, count) -> 0 | 1. Calls are served in order.
    collect(id, inputs, uniforms, outputs, count) {
      const run = () => new Promise((resolve, reject) => {
        const chunks = Math.ceil(count / CHUNK);
        if (chunks <= 1) return resolve(compiled.get(id)(inputs, uniforms, outputs, 0, count));
        if (!outputs.every(o => o.buffer instanceof SharedArrayBuffer)) return reject(new TypeError('collect outputs must be pool.alloc arrays'));
        const ins = inputs.map(shared);
        let next = 0, left = chunks, status = 0, failure = null;
        const feed = slot => {
          if (next >= chunks) return;
          const start = next++ * CHUNK;
          slot.done = m => {
            if (m.error) { failure ??= m.error; left -= chunks - next; next = chunks; } else status |= m.status;
            if (--left === 0) failure ? reject(new Error(failure)) : resolve(status); else feed(slot);
          };
          slot.w.post({ op: 'run', id, inputs: ins, uniforms, outputs, start, stop: Math.min(count, start + CHUNK) });
        };
        slots.forEach(feed);
      });
      return tail = tail.then(run, run);
    },
    close() { for (const s of slots) s.w.stop(); },
  };
  return pool;
}
