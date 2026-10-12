// The frame primitives of specification/core.md and the image/noise host generator. No dependencies.
// Each export is named after its primitive: "+" add, "-" sub, "*" mul, "/" div, "<" lt, "<=" le,
// ">" gt, ">=" ge, "=" eq, "equal?" equal, and every "/" becomes "_" (int/mul -> int_mul).
//
// Values: Int = BigInt (63-bit signed), Float = Number, Bool = boolean, Text = string,
// Vec2/3/4 = Float64Array of length 2/3/4, List = Array, Record = Map (insertion = field order),
// packed array = PArray, empty geometry (sequence_build filler) = null.
// Static lowering parameters come first: coerce(type, v), color_byte(mode, v), fail(code, message).
// A type is "any" | "int" | "float" | "bool" | "text" | "vec2" | "vec3" | "vec4" | "other"
// | {list: type} | {record: [[name, type], ...]}; a mode is "clamped" | "unclamped".
// A native failure is thrown as Fail with the same code.

export class Fail extends Error { constructor(code, message) { super(message); this.code = code; } }
export class PArray { constructor(width, data) { this.width = width; this.data = data; } }

const err = (code, message) => { throw new Fail(code, message); };
const num = v => typeof v === 'number' ? v : typeof v === 'bigint' ? Number(v)
  : typeof v === 'boolean' ? +v : err('E_TYPE', 'Expected a number.');
const truth = v => typeof v === 'boolean' ? v : typeof v === 'bigint' ? v !== 0n
  : typeof v === 'number' ? v !== 0 : err('E_TYPE', 'Expected a bool.');
const fin = (name, x) => Number.isFinite(x) ? x : err('E_NONFINITE', `${name} produced a nonfinite value.`);
const toInt = (name, x) => Number.isFinite(x) && Math.abs(x) < 4e18 ? BigInt(Math.trunc(x))
  : err('E_NONFINITE', `${name} produced a nonfinite value.`);
const intOf = v => toInt('int', Math.floor(num(v) + 0.5));
const wrap = n => BigInt.asIntN(63, n);
const isVec = v => v instanceof Float64Array;
const isNum = v => typeof v === 'bigint' || typeof v === 'number';

// ---- arithmetic ----
function arith(name, f, a, b) {
  if (isVec(a) && a.length !== 3 || isVec(b) && b.length !== 3) {
    const w = (isVec(a) ? a : b).length;
    const lift = v => isVec(v) ? v : new Float64Array(w).fill(num(v));
    const x = lift(a), y = lift(b);
    if (x.length !== y.length) err('E_TYPE', 'Vector arithmetic needs matching widths or a number.');
    return Float64Array.from(x, (c, i) => fin(name, f(c, y[i])));
  }
  if (isVec(a) || isVec(b)) {
    const lift = v => isVec(v) ? v : new Float64Array(3).fill(num(v));
    const x = lift(a), y = lift(b);
    return Float64Array.from(x, (c, i) => fin(name, f(c, y[i])));
  }
  const r = fin(name, f(num(a), num(b)));
  return typeof a === 'bigint' && typeof b === 'bigint' && name !== '/' && name !== 'pow'
    ? toInt(name, Math.floor(r + 0.5)) : r;
}
export const add = (a, b) => arith('+', (x, y) => x + y, a, b);
export const sub = (a, b) => arith('-', (x, y) => x - y, a, b);
export const mul = (a, b) => arith('*', (x, y) => x * y, a, b);
export const div = (a, b) => arith('/', (x, y) => y === 0 ? 0 : x / y, a, b);
export const mod = (a, b) => arith('mod', (x, y) => y === 0 ? 0 : (x % y + y) % y, a, b);
export const pow = (a, b) => arith('pow', (x, y) => { const m = Math.abs(x); return m === 1 ? 1 : Math.pow(m, y); }, a, b);
export const min = (a, b) => arith('min', Math.min, a, b);
export const max = (a, b) => arith('max', Math.max, a, b);
export const remainder = (a, b) => fin('remainder', num(a) % num(b));
export const sin = x => fin('sin', Math.sin(num(x)));
export const cos = x => fin('cos', Math.cos(num(x)));
export const sqrt = x => Math.sqrt(Math.abs(num(x)));
export const exp = x => fin('exp', Math.exp(num(x)));
export const abs = x => typeof x === 'bigint' ? (x < 0n ? wrap(-x) : x) : Math.abs(num(x));
export const floor = x => toInt('floor', Math.floor(num(x)));
export const ceil = x => toInt('ceil', Math.ceil(num(x)));
export const round = x => {
  const v = num(x), t = Math.trunc(v);
  return toInt('round', Math.abs(v - t) >= 0.5 ? t + Math.sign(v) : t);
};
export const int = x => toInt('int', Math.trunc(num(x)));
export const float = x => num(x);
export const lt = (a, b) => num(a) < num(b);
export const le = (a, b) => num(a) <= num(b);
export const gt = (a, b) => num(a) > num(b);
export const ge = (a, b) => num(a) >= num(b);
export const eq = (a, b) => num(a) === num(b);
export const and = (a, b) => truth(a) && truth(b);
export const or = (a, b) => truth(a) || truth(b);
export const not = a => !truth(a);

// ---- signed 63-bit integers ----
const operand = v => typeof v === 'bigint' ? v : intOf(v);
const nonzero = (a, b) => { const x = operand(a), y = operand(b);
  return y === 0n ? err('E_RANGE', 'Integer division by zero.') : [x, y]; };
export const int_mul = (a, b) => wrap(operand(a) * operand(b));
export const int_div = (a, b) => { const [x, y] = nonzero(a, b); return wrap(x / y); };
export const int_mod = (a, b) => { const [x, y] = nonzero(a, b); return wrap(x % y); };
export const int_and = (a, b) => wrap(operand(a) & operand(b));
export const int_xor = (a, b) => wrap(operand(a) ^ operand(b));

// ---- equality, display, text ----
export function equal(a, b) {
  if (a === null || b === null) return a === b;
  if (typeof a !== 'object' || typeof b !== 'object') return a === b;
  const same = (x, y) => x.length === y.length && x.every((c, i) => c === y[i]);
  if (isVec(a)) return isVec(b) && same(a, b);
  if (a instanceof PArray) return b instanceof PArray && a.width === b.width && same(a.data, b.data);
  if (Array.isArray(a)) return Array.isArray(b) && a.length === b.length && a.every((c, i) => equal(c, b[i]));
  if (a instanceof Map) {
    if (!(b instanceof Map) || a.size !== b.size) return false;
    const x = [...a], y = [...b];
    return x.every(([k, c], i) => k === y[i][0] && equal(c, y[i][1]));
  }
  return false;
}

const bits = new DataView(new ArrayBuffer(8));
// Exact fixed-point text of a finite x >= 0: nearest-even from the binary64 ratio.
function fixed(x, places) {
  bits.setFloat64(0, x);
  const hi = bits.getUint32(0), exponent = (hi >>> 20) & 0x7ff;
  const fraction = (BigInt(hi & 0xfffff) << 32n) | BigInt(bits.getUint32(4));
  const m = exponent === 0 ? fraction : fraction | (1n << 52n), e = (exponent || 1) - 1075;
  const scaled = m * 10n ** BigInt(places);
  let q;
  if (e >= 0) q = scaled << BigInt(e);
  else {
    const d = 1n << BigInt(-e), twice = (scaled % d) * 2n;
    q = scaled / d;
    if (twice > d || (twice === d && (q & 1n))) q += 1n;
  }
  const s = q.toString().padStart(places + 1, '0');
  return s.slice(0, s.length - places) + '.' + s.slice(s.length - places);
}
function display(x) {
  if (Number.isNaN(x)) return 'NaN';
  if (!Number.isFinite(x)) return x > 0 ? 'Infinity' : '-Infinity';
  const ax = Math.abs(x), tail = fixed(ax, 40).split('.')[1];
  const tie = tail[4] === '5' && /^0*$/.test(tail.slice(5));
  const s = fixed(tie ? ax + 1e-6 : ax, 4).replace(/0+$/, '').replace(/\.$/, '');
  return x < 0 && s !== '0' ? '-' + s : s;
}
export function show(v) {
  if (v === null) return 'geometry';
  switch (typeof v) {
    case 'bigint': case 'boolean': return String(v);
    case 'number': return display(v);
    case 'string': return v;
  }
  if (isVec(v)) return '[' + Array.from(v, display).join(' ') + ']';
  if (Array.isArray(v)) return '[' + v.map(show).join(' ') + ']';
  if (v instanceof Map) return '{' + [...v].map(([k, x]) => ':' + k + ' ' + show(x)).join(' ') + '}';
  return `${Math.floor(v.data.length / v.width)} × ${['float', 'vec2', 'vec3', 'vec4'][v.width - 1]}`;
}
export const text_concat = (...parts) =>
  parts.map(p => typeof p === 'string' ? p : err('E_TYPE', 'Expected text.')).join('');

// ---- bounded lists ----
const list = v => Array.isArray(v) ? v : err('E_TYPE', 'Expected a list.');
function printG(x) { // C printf %g, for the one native message that uses it
  if (Number.isNaN(x)) return 'nan';
  if (!Number.isFinite(x)) return x > 0 ? 'inf' : '-inf';
  if (x === 0) return Object.is(x, -0) ? '-0' : '0';
  const [m, e] = x.toExponential(5).split('e'), p = +e;
  const trim = s => s.includes('.') ? s.replace(/0+$/, '').replace(/\.$/, '') : s;
  return p < -4 || p >= 6 ? trim(m) + 'e' + (p < 0 ? '-' : '+') + String(Math.abs(p)).padStart(2, '0')
    : trim(x.toFixed(5 - p));
}
export const sequence_length = l => BigInt(list(l).length);
export function sequence_get(l, index) {
  if (typeof index === 'number' && !Number.isInteger(index))
    err('E_LIST_RANGE', `nth index ${printG(index)} is not a whole number.`);
  const xs = list(l), i = intOf(index);
  return i < 0n || i >= BigInt(xs.length)
    ? err('E_LIST_RANGE', `nth index ${i} is out of range for a list of length ${xs.length}.`) : xs[Number(i)];
}
export function sequence_build(count, width) {
  const n = intOf(count);
  if (width !== undefined) { // packed storage: no list cap
    const w = Number(intOf(width));
    return n < 0n || n > MAX_LENGTH / BigInt(w) ? err('E_ARRAY_RANGE', 'Array length is outside native storage bounds.')
      : new PArray(w, new Float64Array(Number(n) * w));
  }
  return n < 0n || n > 4096n ? err('E_ITER_BOUND', 'Core list length exceeds its bound.') : new Array(Number(n)).fill(null);
}
export function sequence_slice(l, first, count) {
  const xs = list(l), f = intOf(first), c = intOf(count);
  return f < 0n || c < 0n || f > BigInt(xs.length) || c > BigInt(xs.length) - f
    ? err('E_LIST_RANGE', 'A list slice must be within its source.') : xs.slice(Number(f), Number(f + c));
}
const tyOf = v => typeof v === 'bigint' ? 'int' : typeof v === 'number' ? 'float'
  : typeof v === 'boolean' ? 'bool' : typeof v === 'string' ? 'text' : v === null ? 'other'
  : isVec(v) ? 'vec' + v.length : Array.isArray(v) ? { list: elementType(v) }
  : v instanceof PArray ? { array: ['float', 'vec2', 'vec3', 'vec4'][v.width - 1] }
  : { record: [...v].map(([k, x]) => [k, tyOf(x)]) };
function join(a, b) {
  if (JSON.stringify(a) === JSON.stringify(b)) return a;
  if (a === 'any') return b;
  if (b === 'any') return a;
  if ((a === 'int' || a === 'float') && (b === 'int' || b === 'float')) return 'float';
  for (const k of ['list', 'array'])
    if (a[k] && b[k]) { const t = join(a[k], b[k]); return t === null ? null : { [k]: t }; }
  if (a.record && b.record && a.record.length === b.record.length
      && a.record.every(([n]) => b.record.some(([m]) => m === n))) {
    const fields = a.record.map(([n, t]) => [n, join(t, b.record.find(([m]) => m === n)[1])]);
    return fields.some(f => f[1] === null) ? null : { record: fields };
  }
  return null;
}
const elementType = xs => xs.reduce((t, x) => join(t, tyOf(x)) ?? t, 'any');
export function sequence_concat(...lists) {
  const parts = lists.map(list);
  let n = 0;
  for (const p of parts) {
    if (p.length > 4096 - n) err('E_ITER_BOUND', 'Core concatenation exceeds 4,096 values.');
    n += p.length;
  }
  const xs = parts.flat(), ty = elementType(xs);
  return xs.map(x => coerce(ty, x));
}

// ---- coercion, truth, failure ----
export function coerce(ty, v) {
  switch (ty) {
    case 'int': return typeof v === 'number' ? toInt('int', Math.floor(v + 0.5)) : typeof v === 'boolean' ? BigInt(v) : v;
    case 'float': return typeof v === 'bigint' || typeof v === 'boolean' ? num(v) : v;
    case 'bool': return isNum(v) ? truth(v) : v;
    case 'vec2': case 'vec3': case 'vec4':
      return isNum(v) ? new Float64Array(+ty[3]).fill(num(v)) : v;
  }
  if (ty.list && Array.isArray(v)) return v.map(x => coerce(ty.list, x));
  if (ty.record && v instanceof Map) {
    return new Map([...v].map(([n, x]) => { const w = ty.record.find(([m]) => m === n);
      return [n, w ? coerce(w[1], x) : x]; }));
  }
  return v;
}
export const truthy = v => truth(v);
export const fail = (code, message) => err(code, message);

// ---- packed arrays ----
const MAX_LENGTH = 2n ** 54n - 1n; // Sys.max_floatarray_length
function count(name, v) {
  const n = num(v);
  return n < 0 || n !== Math.floor(n) || n > Number(MAX_LENGTH)
    ? err('E_ARRAY_RANGE', `${name} needs a non-negative whole length.`) : n;
}
function length(a) {
  if (!(a instanceof PArray)) err('E_ARRAY_TYPE', 'Expected a packed array.');
  if (a.width > 1 && a.data.length % a.width)
    err('E_ARRAY_TYPE', `Packed vec${a.width} storage has ${['', '', 'two', 'three', 'four'][a.width]} coordinates per element.`);
  return a.data.length / a.width;
}
function build(width, n, element) {
  if (BigInt(n) > MAX_LENGTH / BigInt(width)) err('E_ARRAY_RANGE', 'Array length is outside native storage bounds.');
  const data = new Float64Array(n * width);
  for (let i = 0; i < n; i++) {
    const v = element(i), at = i * width;
    if (width === 1) data[at] = fin('array', num(v));
    else if (isVec(v) && v.length === width) v.forEach((c, j) => { data[at + j] = fin('array', c); });
    else if (typeof v === 'bigint' || typeof v === 'number' || typeof v === 'boolean')
      data.fill(fin('array', num(v)), at, at + width);
    else err('E_ARRAY_TYPE', 'Packed array element has the wrong vector width.');
  }
  return new PArray(width, data);
}
export const array_range = n => build(1, count('array/range', n), i => i);
export const array_float = (n, value = 0) => build(1, count('array/float', n), () => value);
export const array_vec3 = (n, value = new Float64Array(3)) => build(3, count('array/vec3', n), () => value);
export const array_count = a => BigInt(length(a));
export function array_nth(a, index) {
  const i = count('array/nth', index), n = length(a);
  if (i >= n) err('E_ARRAY_RANGE', 'Array index is outside its length.');
  return a.width === 1 ? a.data[i] : a.data.slice(i * a.width, (i + 1) * a.width);
}
export function array_slice(a, first, n) {
  const f = count('array/slice', first), c = count('array/slice', n);
  if (!(a instanceof PArray)) err('E_TYPE', 'Expected a packed array.');
  const len = Math.floor(a.data.length / a.width);
  if (f > len || c > len - f) err('E_ARRAY_RANGE', 'An array slice must be within its source.');
  return new PArray(a.width, a.data.slice(f * a.width, (f + c) * a.width));
}
export function array_concat(a, b) {
  if (!(a instanceof PArray && b instanceof PArray && a.width === b.width))
    err('E_ARRAY_TYPE', 'Concatenated arrays must have the same element type.');
  const data = new Float64Array(a.data.length + b.data.length);
  data.set(a.data); data.set(b.data, a.data.length);
  return new PArray(a.width, data);
}

// ---- hash, noise, colour ----
export function value_rand(...keys) {
  const ks = keys.map(num);
  let h = 0x9e3779b9;
  for (const x of ks) {
    h = Math.imul(h ^ (Math.floor(x * 1000003) >>> 0), 0x85ebca6b) >>> 0;
    h = (h ^ (h >>> 13)) >>> 0;
    h = Math.imul(h, 0xc2b2ae35) >>> 0;
    h = (h ^ (h >>> 16)) >>> 0;
  }
  return (h % 1000000) / 1000000;
}

const U64 = (1n << 64n) - 1n, tables = new Map(); // at most 16 dynamic seeds
function permutation(seed) {
  const key = String(seed);
  if (tables.has(key)) return tables.get(key);
  let s = BigInt.asUintN(64, seed);
  const p = Array.from({ length: 256 }, (_, i) => i);
  for (let i = 255; i >= 1; i--) {
    s = (s + 0x9E3779B97F4A7C15n) & U64;
    let z = s ^ (s >> 30n); z = (z * 0xBF58476D1CE4E5B9n) & U64;
    z ^= z >> 27n; z = (z * 0x94D049BB133111EBn) & U64; z ^= z >> 31n;
    const j = Number(z % BigInt(i + 1));
    [p[i], p[j]] = [p[j], p[i]];
  }
  const table = Int32Array.from({ length: 512 }, (_, i) => p[i & 255]);
  if (tables.size >= 16) tables.delete(tables.keys().next().value);
  tables.set(key, table);
  return table;
}
// Low 8 bits of the native float-to-int conversion, which saturates at the int64 bounds.
const low8 = f => f >= 2 ** 63 ? 255 : f < -(2 ** 63) ? 0 : Number.isNaN(f) ? 0 : Number(BigInt.asUintN(8, BigInt(f)));
const fade = t => t * t * t * (t * (t * 6 - 15) + 10);
const lerp = (a, b, t) => a + t * (b - a);
function grad(hash, x, y, z) {
  hash &= 15;
  const u = hash < 8 ? x : y, v = hash < 4 ? y : hash === 12 || hash === 14 ? x : z;
  return ((hash & 1) === 0 ? u : -u) + ((hash & 2) === 0 ? v : -v);
}
function raw3(p, x, y, z) {
  const fx = Math.floor(x), fy = Math.floor(y), fz = Math.floor(z);
  const xi = low8(fx), yi = low8(fy), zi = low8(fz);
  x -= fx; y -= fy; z -= fz;
  const u = fade(x), v = fade(y), w = fade(z);
  const h = (a, b, c) => p[p[p[a] + b] + c];
  const x00 = lerp(grad(h(xi, yi, zi), x, y, z), grad(h(xi + 1, yi, zi), x - 1, y, z), u);
  const x10 = lerp(grad(h(xi, yi + 1, zi), x, y - 1, z), grad(h(xi + 1, yi + 1, zi), x - 1, y - 1, z), u);
  const x01 = lerp(grad(h(xi, yi, zi + 1), x, y, z - 1), grad(h(xi + 1, yi, zi + 1), x - 1, y, z - 1), u);
  const x11 = lerp(grad(h(xi, yi + 1, zi + 1), x, y - 1, z - 1), grad(h(xi + 1, yi + 1, zi + 1), x - 1, y - 1, z - 1), u);
  return lerp(lerp(x00, x10, v), lerp(x01, x11, v), w);
}
const clamp01 = v => v <= 0 ? 0 : v >= 1 ? 1 : v;
export function noise3(position, seed, octaves) {
  if (!(isVec(position) && position.length === 3)) err('E_TYPE', 'noise3 takes a vec3 position.');
  for (const c of position) fin('noise3 position', c);
  const configuration = v => typeof v === 'bigint' ? v : intOf(v);
  const s = seed === undefined ? 0n : configuration(seed), n = octaves === undefined ? 1n : configuration(octaves);
  if (n < 1n || n > 32n) err('E_NOISE_RANGE', 'Noise octaves are 1 to 32.');
  const p = permutation(s), [x, y, z] = position;
  const sample = f => clamp01((raw3(p, x * f, y * f, z * f) + 1) / 2);
  if (n === 1n) return fin('noise3', sample(1));
  let sum = 0, weights = 0, frequency = 1, amplitude = 1;
  for (let i = 0; i < Number(n); i++) {
    sum += sample(frequency) * amplitude; weights += amplitude;
    frequency *= 2; amplitude *= 0.5;
  }
  return fin('noise3', weights === 0 ? 0 : sum / weights);
}

// image/noise is the native 64-bit sample3 generator, not an f32 image/map approximation.
export function image_noise(width, height, frequency, seed) {
  if (!Number.isFinite(frequency) || frequency < 0) err('E_IMAGE', 'Noise frequency must be finite and nonnegative.');
  const p = permutation(typeof seed === 'bigint' ? seed : intOf(seed)), pixels = new Uint8Array(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    const sample = clamp01((raw3(p, (i % width) * frequency, Math.floor(i / width) * frequency, 0) + 1) / 2);
    if (!Number.isFinite(sample)) err('E_IMAGE', 'Image RGBA samples must be finite and within [0,1].');
    const q = sample * 255;
    const n = Math.floor(q), f = q - n, c = n + (f > 0.5 || (f === 0.5 && (n & 1)) ? 1 : 0);
    const offset = i * 4;
    pixels[offset] = c; pixels[offset + 1] = c; pixels[offset + 2] = c; pixels[offset + 3] = 255;
  }
  return pixels;
}

// Native float-to-int conversion of c*255+0.5: truncate, saturate at int64, keep 63 bits, clamp to a byte.
function byte(c) {
  const t = c * 255 + 0.5;
  if (Number.isNaN(t)) return 0n;
  const n = wrap(t >= 2 ** 63 ? 2n ** 63n - 1n : t <= -(2 ** 63) ? -(2n ** 63n) : BigInt(Math.trunc(t)));
  return n < 0n ? 0n : n > 255n ? 255n : n;
}
export const color_byte = (mode, v) => {
  const f = fin('color', num(v));
  return byte(mode === 'clamped' ? Math.max(0, Math.min(1, f)) : f);
};
const hexDigit = c => c >= 48 && c <= 57 ? c - 48 : (c | 32) >= 97 && (c | 32) <= 102 ? (c | 32) - 87 : -1;
function hexColor(text) {
  let b = [...new TextEncoder().encode(text)];
  if (b[0] === 35) b.shift();
  if (b.length === 3 || b.length === 4) b = b.flatMap(c => [c, c]);
  if (b.length !== 6 && b.length !== 8) err('E_DRAW_COLOR', 'Color.hex: expected #rgb, #rgba, #rrggbb, or #rrggbbaa');
  const channel = at => { // two hex digits, or one followed by '_'
    const high = hexDigit(b[at]), low = hexDigit(b[at + 1]);
    if (high < 0 || (low < 0 && b[at + 1] !== 95)) err('E_DRAW_COLOR', 'Color.hex: invalid hexadecimal digit');
    return BigInt(low < 0 ? high : high * 16 + low);
  };
  return [channel(0), channel(2), channel(4), b.length === 8 ? channel(6) : 255n];
}
export function color_parse(v) {
  let c;
  if (typeof v === 'string') c = hexColor(v);
  else if (isVec(v) && v.length === 3) {
    fin('blue', v[2]); fin('green', v[1]); fin('red', v[0]); // native checks right to left
    c = [byte(v[0]), byte(v[1]), byte(v[2]), 255n];
  } else if (Array.isArray(v) && v.length === 4) {
    const ch = [3, 2, 1, 0].map(i => fin('color', num(v[i]))).reverse();
    c = ch.map(byte);
  } else err('E_TYPE', 'A color is hex text, vec3 or (list r g b a).');
  return new Map([['r', c[0]], ['g', c[1]], ['b', c[2]], ['a', c[3]]]);
}

// Cook-context and geometry metadata host protocol. Geometry stays an immutable
// Map with an ordered attributes list; canonical positions live outside it.
export function sop_context_seed(namespace, context) {
  if (typeof namespace !== 'string' || !namespace.trim()) err('E_SEED_NAMESPACE', 'A context seed namespace must be nonblank.');
  if (!(context instanceof Map)) err('E_NODE_CONTEXT', 'Context seed is available inside a defnode body.');
  let identity = 0xcbf29ce484222325n;
  for (const byte of new TextEncoder().encode(`${namespace}:${context.get('label')}`))
    identity = BigInt.asUintN(64, (identity ^ BigInt(byte)) * 0x100000001b3n);
  const mixed = BigInt.asUintN(64, BigInt(context.get('seed')) ^ (identity * 0x9e3779b97f4a7c15n));
  return BigInt.asIntN(63, mixed ^ (mixed >> 32n));
}

function attributePattern(source) {
  const bytes = s => Array.from(new TextEncoder().encode(s), n => String.fromCharCode(n)).join('');
  const raw = bytes(source), terms = [];
  const whitespace = c => ' \t\n\r\f'.includes(c);
  let index = 0;
  while (index < raw.length) {
    while (index < raw.length && whitespace(raw[index])) index++;
    if (index === raw.length) break;
    let token = '', escaped = false;
    while (index < raw.length && (escaped || !whitespace(raw[index]))) {
      const c = raw[index++]; token += c;
      escaped = !escaped && c === '\\';
    }
    if (escaped) err('E_ATTR_PATTERN', 'Attribute_pattern: dangling backslash escape');
    terms.push(token);
  }
  const literal = c => `\\x${c.charCodeAt(0).toString(16).padStart(2, '0')}`;
  const compiled = terms.map((token, termIndex) => {
    const fail = message => err('E_ATTR_PATTERN', `Attribute_pattern: term ${termIndex + 1}: ${message}`);
    const excluded = token.startsWith('^');
    let i = excluded ? 1 : 0, pattern = '';
    if (i === token.length) fail('empty exclusion term');
    while (i < token.length) {
      const c = token[i++];
      if (c === '\\') {
        if (i === token.length) fail('dangling backslash escape');
        pattern += literal(token[i++]);
      } else if (c === '*') pattern += '[\\s\\S]*';
      else if (c === '?') pattern += '[\\s\\S]';
      else if (c === '[') {
        let close = i, escaped = false;
        while (close < token.length) {
          const ch = token[close];
          if (!escaped && ch === ']') break;
          escaped = !escaped && ch === '\\'; close++;
        }
        if (close === token.length) fail('unterminated character class');
        if (close === i) fail('empty character class');
        const negated = token[i] === '!' || token[i] === '^';
        if (negated) i++;
        if (i === close) fail('empty negated character class');
        let content = '';
        const character = () => {
          if (token[i] === '\\') { i++; if (i === close) fail('dangling class escape'); }
          return token[i++];
        };
        while (i < close) {
          const left = character();
          if (i + 1 < close && token[i] === '-') {
            i++; const right = character();
            if (left.charCodeAt(0) > right.charCodeAt(0)) fail('descending character-class range');
            content += `${literal(left)}-${literal(right)}`;
          } else content += literal(left);
        }
        pattern += `[${negated ? '^' : ''}${content}]`; i = close + 1;
      } else pattern += literal(c);
    }
    return { excluded, regex: new RegExp(`^(?:${pattern})$`) };
  });
  return name => {
    let selected = compiled.length === 0 || compiled[0].excluded;
    const text = bytes(name);
    for (const { excluded, regex } of compiled) if (regex.test(text)) selected = !excluded;
    return selected;
  };
}

export function sop_delete_attr(geometry, pattern, owner = 'point') {
  if (typeof pattern !== 'string' || !pattern.trim()) err('E_ATTR_NAME', 'An attribute pattern must be nonblank.');
  const matches = attributePattern(pattern);
  if (!['point', 'vertex', 'primitive', 'detail'].includes(owner))
    err('E_ATTR_OWNER', 'Attribute owner is point, vertex, primitive or detail.');
  if (!(geometry instanceof Map) || !Array.isArray(geometry.get('attributes')))
    err('E_TYPE', 'Attribute deletion requires geometry.');
  const attributes = geometry.get('attributes').filter(a => a.get('owner') !== owner || !matches(a.get('name')));
  if (attributes.length === geometry.get('attributes').length) return geometry;
  const result = new Map(geometry); result.set('attributes', attributes); return result;
}
