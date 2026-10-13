// node prims.mjs FIXTURE_DIR PRIMS_JS_PATH
//
// Runs the native fixtures written by tools/core_fixtures.exe through the browser primitives
// (tools/web/runtime/prims.js). Each case is export(...static, ...args); its result must equal the
// native result: exact for Int, Text, Bool, structure and error code/message; floats within 1e-12
// relative (NaN matches NaN, infinities must match exactly). Prints one "ok" line, or every
// mismatch and exits 1. No dependencies.

import { readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [fixtureDir, primsPath] = process.argv.slice(2);
if (!fixtureDir || !primsPath) {
  console.error('usage: node prims.mjs FIXTURE_DIR PRIMS_JS_PATH');
  process.exit(2);
}

const prims = await import(pathToFileURL(resolve(primsPath)).href);
const { Fail, PArray, TextArray } = prims;
const TOLERANCE = 1e-12;

for (const [name, args, expected] of [
  ['sign', [-0], -0], ['sign', [0], 0], ['sign', [-Number.MIN_VALUE], -1],
  ['atan2', [-0, 1], -0], ['atan2', [0, -0], Math.PI],
  ['hypot', [-0, -0], 0], ['hypot', [Number.MIN_VALUE, Number.MIN_VALUE], Number.MIN_VALUE],
]) {
  if (!Object.is(prims[name](...args), expected)) throw new Error(`${name}: signed-zero/subnormal math mismatch`);
}

for (const [type, width] of [['float', 1], ['vec2', 2], ['vec3', 3], ['vec4', 4]]) {
  for (const bad of [NaN, Infinity, -Infinity]) {
    const data = Float64Array.from({ length: width * 3 }, (_, i) => i % width === 0 ? -0 : Number.MAX_VALUE);
    data[width - 1] = bad;
    data[width * 3 - 1] = Number.MIN_VALUE;
    const source = new PArray(width, data);
    const geometry = new Map([['attributes', [new Map([
      ['owner', 'point'], ['name', 'raw'], ['type', type], ['values', source],
    ])]]]);
    const result = prims.sop_attr_checked(geometry, 'raw', 'point', type);
    const values = result.get('values').data, valid = result.get('valid').data;
    if (valid[0] !== 0n || valid[1] !== 1n || valid[2] !== 1n || values === data)
      throw new Error('sop_attr_checked: validity or ownership mismatch');
    for (let i = 0; i < values.length; i++)
      if (!Object.is(values[i], i < width ? 0 : data[i]))
        throw new Error('sop_attr_checked: exact finite or sanitized bits mismatch');
    values.fill(99); valid.fill(99n);
    if (!Object.is(data[width - 1], bad)) throw new Error('sop_attr_checked: source mutation');
    const again = prims.sop_attr_checked(geometry, 'raw', 'point', type);
    if (again.get('valid').data[0] !== 0n || !Object.is(again.get('values').data[width], data[width]))
      throw new Error('sop_attr_checked: repeated query retained mutable results');
  }
}

for (const [type, width] of [['float', 1], ['vec2', 2], ['vec3', 3], ['vec4', 4]]) {
  const data = Float64Array.from({length: width * 3}, (_, i) => i % width === 0 ? -0 : Infinity);
  data[width - 1] = NaN;
  const input = new Map([['positions', new PArray(3, new Float64Array(9))],
    ['attributes', [new Map([['owner', 'point'], ['name', 'raw'], ['type', type], ['values', new PArray(width, data)]])]]]);
  const values = new PArray(width, Float64Array.from({length: width * 3}, (_, i) => i % width === 0 ? -0 : Number.MIN_VALUE));
  const selection = new PArray(1, BigInt64Array.from([0n, 1n, 0n]));
  const fallback = width === 1 ? -0 : Float64Array.from({length: width}, () => -0);
  const output = prims.sop_with_attr(input, 'raw', 'point', type, values, selection, fallback);
  const result = output.get('attributes').find(a => a.get('name') === 'raw').get('values').data;
  for (let i = 0; i < result.length; i++)
    if (!Object.is(result[i], i >= width && i < 2 * width ? values.data[i] : data[i]))
      throw new Error('sop_with_attr: exact selected or untouched bits mismatch');
  result.fill(99);
  if (!Object.is(data[width - 1], NaN) || !Object.is(values.data[0], -0) || selection.data[0] !== 0n)
    throw new Error('sop_with_attr: selected write mutated inputs');
  const missing = prims.sop_with_attr(new Map([['positions', input.get('positions')], ['attributes', []]]), 'raw', 'point', type, values, selection, fallback);
  const fresh = missing.get('attributes')[0].get('values').data;
  if (!Object.is(fresh[0], -0) || !Object.is(fresh[width], -0))
    throw new Error('sop_with_attr: selected default or fill lost negative zero');
}

// Cooked host masks arrive from valid native geometries; reject malformed
// storage at the JavaScript boundary before it can index the point result.
{
  const group = mask => new Map([['owner', 'vertex'], ['name', 'selected'], ['mask', mask]]);
  const geometry = mask => new Map([
    ['positions', new PArray(3, new Float64Array(9))],
    ['vertex_points', [0n, 1n, 2n]], ['primitive_offsets', [0n, 3n]],
    ['primitive_kinds', String.fromCharCode(0)], ['groups', [group(mask)]],
  ]);
  for (const [mask, code] of [
    [new PArray(1, new Float64Array(3)), 'E_GROUP_MASK'],
    [new PArray(1, new BigInt64Array(2)), 'E_GROUP_COUNT'],
    [new PArray(1, BigInt64Array.from([0n, 2n, 0n])), 'E_GROUP_MASK'],
  ]) {
    let failure;
    try { prims.sop_group(geometry(mask), 'selected', 'vertex', 'point'); }
    catch (e) { failure = e; }
    if (!(failure instanceof Fail) || failure.code !== code)
      throw new Error(`sop_group: malformed mask must report ${code}`);
  }
  const mask = new PArray(1, BigInt64Array.from([0n, 1n, 0n]));
  const input = geometry(mask), result = prims.sop_group(input, 'selected', 'vertex', 'point');
  if (result.data[0] !== 0n || result.data[1] !== 1n || result.data[2] !== 0n)
    throw new Error('sop_group: promoted membership mismatch');
  result.data.fill(99n);
  if (mask.data[1] !== 1n || prims.sop_group(input, 'selected', 'vertex', 'point').data[1] !== 1n)
    throw new Error('sop_group: promoted mask aliases native storage');
}

// C.1 uses ordinary immutable geometry host values. Construction and queries
// own their arrays; exact signed zero and exact integer kinds survive both.
{
  const points = new PArray(3, Float64Array.from([0, -0, 2, 1, 0.25, 2, 2, -0, 2]));
  const vertices = new PArray(1, BigInt64Array.from([0n, 1n, 2n]));
  const offsets = new PArray(1, BigInt64Array.from([0n, 3n]));
  const kinds = new PArray(1, BigInt64Array.from([0n]));
  const geometry = prims.sop_mesh(points, vertices, offsets, kinds);
  if (!Object.is(geometry.get('positions').data[1], -0)) throw new Error('sop_mesh: signed zero changed');
  const topology = prims.sop_topology(geometry);
  if (topology.get('kinds').data[0] !== 0n || topology.get('primitive_offsets').data[1] !== 3n)
    throw new Error('sop_topology: native kind/count mismatch');
  points.data.fill(99); vertices.data.fill(99n); offsets.data.fill(99n); kinds.data.fill(99n);
  for (const value of topology.values()) value.data.fill(99n);
  const again = prims.sop_topology(geometry);
  if (!Object.is(geometry.get('positions').data[1], -0) || again.get('vertex_points').data[0] !== 0n
      || again.get('primitive_offsets').data[1] !== 3n || again.get('kinds').data[0] !== 0n)
    throw new Error('sop_mesh/sop_topology: caller mutation changed immutable geometry');
  const int = values => new PArray(1, BigInt64Array.from(values));
  const expect = (code, fn) => {
    try { fn(); } catch (error) { if (error instanceof Fail && error.code === code) return; throw error; }
    throw new Error(`C1: expected ${code}`);
  };
  expect('E_TOPOLOGY_TYPE', () => prims.sop_mesh(new PArray(1, new Float64Array()), int([]), int([0n]), int([])));
  expect('E_ARRAY_TYPE', () => prims.sop_mesh(new PArray(3, Float64Array.of(1)), int([]), int([0n]), int([])));
  for (const bad of [NaN, Infinity, -Infinity])
    expect('E_NONFINITE', () => prims.sop_mesh(new PArray(3, Float64Array.of(bad, 0, 0)), int([]), int([0n]), int([])));
  expect('E_DATA_SOURCE', () => prims.sop_topology(null));
}

// ---- decoding the JSON encoding of core_fixtures.ml ----
const decodeFloat = v => {
  if (typeof v === 'number') return v;
  if (v && typeof v === 'object' && 'float' in v) {
    switch (v.float) {
      case 'NaN': return NaN;
      case 'Infinity': return Infinity;
      case '-Infinity': return -Infinity;
    }
  }
  throw new Error(`bad float encoding ${JSON.stringify(v)}`);
};
const decodeValue = v => {
  if (v === null || typeof v === 'boolean' || typeof v === 'string' || typeof v === 'number') return v;
  if (Array.isArray(v)) return v.map(decodeValue);
  if ('int' in v) return BigInt(v.int);
  if ('float' in v) return decodeFloat(v);
  if ('vec' in v) return Float64Array.from(v.vec, decodeFloat);
  if ('record' in v) return new Map(v.record.map(([name, x]) => [name, decodeValue(x)]));
  if ('array' in v && v.array === 'text') return new TextArray(v.data);
  if ('array' in v) return v.array === 'int'
    ? new PArray(1, BigInt64Array.from(v.data, BigInt))
    : new PArray(v.array, Float64Array.from(v.data, decodeFloat));
  throw new Error(`bad value encoding ${JSON.stringify(v)}`);
};
// A coerce type is not a value: {list: T} and {record: [[name, T]...]} carry types, not values.
const decodeType = t => {
  if (typeof t === 'string') return t;
  if ('list' in t) return { list: decodeType(t.list) };
  if ('record' in t) return { record: t.record.map(([name, x]) => [name, decodeType(x)]) };
  throw new Error(`bad type encoding ${JSON.stringify(t)}`);
};
const decodeStatic = (exportName, statics) =>
  statics.map((s, i) => (exportName === 'coerce' && i === 0 ? decodeType(s) : decodeValue(s)));

// ---- comparison: returns null when equal, else a description of the difference ----
const floatEqual = (a, b) => {
  if (Number.isNaN(a) || Number.isNaN(b)) return Number.isNaN(a) && Number.isNaN(b);
  if (!Number.isFinite(a) || !Number.isFinite(b)) return a === b;
  return Math.abs(a - b) <= TOLERANCE * Math.max(Math.abs(a), Math.abs(b));
};
const diff = (expected, got, path = '') => {
  const at = path ? ` at ${path}` : '';
  const mismatch = () => `${show(expected)} != ${show(got)}${at}`;
  if (expected === null || got === null) return expected === got ? null : mismatch();
  if (typeof expected === 'bigint' || typeof expected === 'boolean' || typeof expected === 'string')
    return expected === got ? null : mismatch();
  if (typeof expected === 'number')
    return typeof got === 'number' && floatEqual(expected, got) ? null : mismatch();
  if (expected instanceof Float64Array) {
    if (!(got instanceof Float64Array) || got.length !== expected.length) return mismatch();
    for (let i = 0; i < expected.length; i++)
      if (!floatEqual(expected[i], got[i])) return mismatch();
    return null;
  }
  if (expected instanceof PArray) {
    if (!(got instanceof PArray) || got.width !== expected.width || got.data.length !== expected.data.length)
      return mismatch();
    for (let i = 0; i < expected.data.length; i++)
      if (typeof expected.data[i] === 'bigint' ? expected.data[i] !== got.data[i]
        : typeof got.data[i] !== 'number' || !floatEqual(expected.data[i], got.data[i])) return mismatch();
    return null;
  }
  if (expected instanceof TextArray) return got instanceof TextArray
    && expected.data.length === got.data.length && expected.data.every((s, i) => s === got.data[i]) ? null : mismatch();
  if (Array.isArray(expected)) {
    if (!Array.isArray(got) || got.length !== expected.length) return mismatch();
    for (let i = 0; i < expected.length; i++) {
      const d = diff(expected[i], got[i], `${path}[${i}]`);
      if (d) return d;
    }
    return null;
  }
  if (expected instanceof Map) {
    if (!(got instanceof Map)) return mismatch();
    const ek = [...expected.keys()], gk = [...got.keys()];
    if (ek.length !== gk.length || ek.some((k, i) => k !== gk[i])) return mismatch();
    for (const k of ek) {
      const d = diff(expected.get(k), got.get(k), `${path}.${k}`);
      if (d) return d;
    }
    return null;
  }
  return `unsupported expected value ${String(expected)}`;
};
// Short rendering for reports; Int shows as 123n, vectors and arrays by content.
function show(v) {
  if (v === null || v === undefined) return String(v);
  if (typeof v === 'bigint') return `${v}n`;
  if (typeof v === 'number') return Object.is(v, -0) ? '-0' : String(v);
  if (typeof v === 'string') return JSON.stringify(v);
  if (typeof v === 'boolean') return String(v);
  if (v instanceof Fail) return `error ${v.code} ${JSON.stringify(v.message)}`;
  if (v instanceof Float64Array) return `vec[${Array.from(v).join(', ')}]`;
  if (v instanceof PArray) return `array/${v.width}[${Array.from(v.data).join(', ')}]`;
  if (v instanceof TextArray) return `array/text[${v.data.map(JSON.stringify).join(', ')}]`;
  if (Array.isArray(v)) return `[${v.map(show).join(', ')}]`;
  if (v instanceof Map) return `{${[...v].map(([k, x]) => `${k}: ${show(x)}`).join(', ')}}`;
  return String(v);
}

// Runs one case; returns null when it matches, else a mismatch string.
function checkCase(fn, exportName, expectedJson, c) {
  const statics = decodeStatic(exportName, c.static ?? []);
  const args = c.args.map(decodeValue);
  const want = c.result;
  let got;
  try {
    got = { value: fn(...statics, ...args) };
  } catch (e) {
    if (!(e instanceof Fail)) got = { exception: String(e) };
    else got = { error: { code: e.code, message: e.message, cause: e.cause } };
  }
  if (want && typeof want === 'object' && !Array.isArray(want) && 'error' in want) {
    const expectedError = want.error;
    if (!got.error) return `expected error ${expectedError.code} ${JSON.stringify(expectedError.message)}, got ${got.exception ? `exception ${got.exception}` : show(got.value)}`;
    if (got.error.code !== expectedError.code || got.error.message !== expectedError.message || got.error.cause !== expectedError.cause)
      return `expected error ${expectedError.code} ${JSON.stringify(expectedError.message)}, got error ${got.error.code} ${JSON.stringify(got.error.message)}`;
    return null;
  }
  if (got.error) return `expected ${show(decodeValue(want))}, got error ${got.error.code} ${JSON.stringify(got.error.message)}`;
  if (got.exception) return `expected ${show(decodeValue(want))}, got exception ${got.exception}`;
  const expected = decodeValue(want);
  const d = diff(expected, got.value);
  return d ? d : null;
}

// ---- driver ----
const files = readdirSync(fixtureDir).filter(f => f.endsWith('.json')).sort();
let cases = 0, failures = 0;
for (const file of files) {
  const fixture = JSON.parse(readFileSync(join(fixtureDir, file), 'utf8'));
  const fn = prims[fixture.export];
  if (typeof fn !== 'function') {
    console.log(`${file}: no export named ${fixture.export}`);
    failures++;
    continue;
  }
  fixture.cases.forEach((c, index) => {
    cases++;
    let problem;
    try {
      problem = checkCase(fn, fixture.export, fixture, c);
    } catch (e) {
      problem = `harness error ${e.message}`;
    }
    if (problem) {
      failures++;
      console.log(`${file} (${fixture.primitive}) case ${index}: ${problem}`);
    }
  });
}

if (failures > 0) {
  console.log(`FAIL ${failures} mismatches in ${cases} cases, ${files.length} primitives`);
  process.exit(1);
}
console.log(`ok ${cases} cases, ${files.length} primitives`);
