// node workers.mjs WORKERS_JS GOLDEN_DIR
//
// Runs the region goldens of lib/flow_web/goldens through the worker pool (node:worker_threads behind the
// same adapter the browser uses) and requires the output to equal one single call byte for byte, at 1 and
// 8 workers, for a count that spans many 16,384-element chunks and is not a multiple of 1,024, one that is
// exactly three chunks, and one under the sequential cutoff. Also: a non-finite value reports status 1,
// and a page without cross-origin isolation gets one message and stops. Prints one "ok" line.

import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [workersPath, goldenDir] = process.argv.slice(2);
if (!workersPath || !goldenDir) { console.error('usage: node workers.mjs WORKERS_JS GOLDEN_DIR'); process.exit(2); }
const { createPool, checkIsolation, CHUNK } = await import(pathToFileURL(resolve(workersPath)).href);

const failures = [];
const check = (ok, what) => { if (!ok) failures.push(what); };

// name -> output widths (the goldens: arithmetic, noise, select have one output; two_outputs has widths 1 and 2)
const GOLDENS = { arithmetic: [1], noise: [1], select: [1], two_outputs: [1, 2] };
const uniforms = [Float64Array.of(0.5, 1.5, 2.5, 3.25, 4, 5, 6, 7)];
const makeInput = n => Float64Array.from({ length: n }, (_, i) => Math.sin(i * 0.37) * 40 + (i % 17));
const bytes = a => Buffer.from(a.buffer, a.byteOffset, a.byteLength);
const counts = [100003, 3 * CHUNK, 1000];

const pools = { 1: await createPool({ size: 1 }), 8: await createPool({ size: 8 }) };
for (const [name, widths] of Object.entries(GOLDENS)) {
  const source = readFileSync(join(goldenDir, `${name}.js`), 'utf8');
  const region = new Function(`${source}\nreturn region;`)();
  for (const n of counts) {
    const inputs = [makeInput(n)];
    const expected = widths.map(w => new Float64Array(n * w));
    const status = region(inputs, uniforms, expected, 0, n);
    for (const [size, pool] of Object.entries(pools)) {
      pool.load(name, source);
      const outputs = widths.map(w => pool.alloc(n * w));
      const got = await pool.collect(name, inputs, uniforms, outputs, n);
      check(got === status, `${name} n=${n} workers=${size}: status ${got} vs ${status}`);
      check(outputs.every((o, k) => bytes(o).equals(bytes(expected[k]))), `${name} n=${n} workers=${size}: bytes differ`);
    }
  }
}

// A non-finite value anywhere (here in the last chunk) is status 1.
{
  const source = readFileSync(join(goldenDir, 'arithmetic.js'), 'utf8'), n = 100003;
  const inputs = [makeInput(n)]; inputs[0][n - 5] = Infinity;
  const pool = pools[8]; pool.load('inf', source);
  check(await pool.collect('inf', inputs, uniforms, [pool.alloc(n)], n) === 1, 'non-finite status');
}

// Results do not depend on the order the workers finish: queue several calls at once.
{
  const source = readFileSync(join(goldenDir, 'noise.js'), 'utf8'), n = 5 * CHUNK + 7, pool = pools[8];
  pool.load('noise', source);
  const inputs = [makeInput(n)], region = pool.region('noise'), expected = new Float64Array(n);
  region(inputs, uniforms, [expected], 0, n);
  const outs = Array.from({ length: 4 }, () => pool.alloc(n));
  await Promise.all(outs.map(o => pool.collect('noise', inputs, uniforms, [o], n)));
  check(outs.every(o => bytes(o).equals(bytes(expected))), 'concurrent calls');
}
for (const pool of Object.values(pools)) pool.close();

// Cross-origin isolation: false -> one message on the page, nothing else.
{
  const page = { body: { textContent: '' } };
  check(checkIsolation({ crossOriginIsolated: false, document: page }) === false && /cross-origin isolation/.test(page.body.textContent), 'isolation message');
  check(checkIsolation({ crossOriginIsolated: true }) === true, 'isolated page starts');
}

if (failures.length) { console.error(failures.join('\n')); process.exit(1); }
console.log('workers: ok');
