function region(inputs, uniforms, outputs, start, stop) {
  const fail = (code, message) => { const e = new Error(message); e.code = code; throw e; };
  const wrap = x => BigInt.asIntN(63, x);
  const convert = (name, x) => Number.isFinite(x) && Math.abs(x) < 4e18 ? BigInt(Math.trunc(x)) : fail('E_NONFINITE', name + ' produced a nonfinite value.');
  const divide = (a, b, mod) => b === 0n ? fail('E_RANGE', 'Integer division by zero.') : wrap(mod ? a % b : a / b);
  const shift = (a, b, right) => b < 0n || b > 62n ? fail('E_RANGE', 'Integer shift count must be within [0, 62].') : wrap(right ? BigInt.asUintN(63, a) >> b : a << b);
  const fade = (t) => t * t * t * (t * (t * 6 - 15) + 10);
  const lerp = (a, b, t) => a + t * (b - a);
  const grad = (hash, x, y, z) => {
    const h = hash & 15;
    const u = h < 8 ? x : y;
    const v = h < 4 ? y : ((h === 12 || h === 14) ? x : z);
    return ((h & 1) === 0 ? u : -u) + ((h & 2) === 0 ? v : -v);
  };
  const raw3 = (p, x, y, z) => {
    const fx = Math.floor(x), fy = Math.floor(y), fz = Math.floor(z);
    const xi = fx & 255, yi = fy & 255, zi = fz & 255;
    x = x - fx; y = y - fy; z = z - fz;
    const u = fade(x), v = fade(y), w = fade(z);
    const h000 = p[p[p[xi] + yi] + zi], h100 = p[p[p[xi + 1] + yi] + zi];
    const h010 = p[p[p[xi] + yi + 1] + zi], h110 = p[p[p[xi + 1] + yi + 1] + zi];
    const h001 = p[p[p[xi] + yi] + zi + 1], h101 = p[p[p[xi + 1] + yi] + zi + 1];
    const h011 = p[p[p[xi] + yi + 1] + zi + 1], h111 = p[p[p[xi + 1] + yi + 1] + zi + 1];
    const x00 = lerp(grad(h000, x, y, z), grad(h100, x - 1, y, z), u);
    const x10 = lerp(grad(h010, x, y - 1, z), grad(h110, x - 1, y - 1, z), u);
    const x01 = lerp(grad(h001, x, y, z - 1), grad(h101, x - 1, y, z - 1), u);
    const x11 = lerp(grad(h011, x, y - 1, z - 1), grad(h111, x - 1, y - 1, z - 1), u);
    return lerp(lerp(x00, x10, v), lerp(x01, x11, v), w);
  };
  const fbm = (p, x, y, z, octaves) => {
    let frequency = 1, amplitude = 1, sum = 0, weights = 0;
    for (let octave = 0; octave < octaves; octave++) {
      const sx = x * frequency, sy = y * frequency, sz = z * frequency;
      if (Number.isFinite(sx) && Number.isFinite(sy) && Number.isFinite(sz)
          && Number.isFinite(sum) && Number.isFinite(weights)) {
        const raw = (raw3(p, sx, sy, sz) + 1) * 0.5;
        sum = sum + (raw <= 0 ? 0 : raw >= 1 ? 1 : raw) * amplitude;
        weights = weights + amplitude;
        frequency = frequency * 2;
        amplitude = amplitude * 0.5;
      } else sum = NaN;
    }
    if (Number.isFinite(sum) && Number.isFinite(weights)) return weights === 0 ? 0 : sum / weights;
    return NaN;
  };
  const table31 = Int32Array.from([104,50,72,164,244,160,88,179,230,83,18,53,49,122,100,76,154,152,222,48,87,3,191,98,101,92,93,77,131,200,128,38,229,57,105,55,221,120,68,59,27,183,219,33,115,204,23,209,63,171,193,113,243,203,29,146,157,2,16,58,211,24,141,165,51,11,106,166,238,129,123,64,89,136,189,1,82,185,177,194,156,176,126,170,239,137,145,13,119,215,30,195,6,42,182,153,245,17,173,94,214,149,73,118,242,121,217,198,249,253,150,237,186,125,196,66,197,235,108,7,139,188,21,155,132,167,41,206,79,54,0,71,9,192,240,111,25,39,255,130,223,114,35,86,97,124,61,46,144,140,8,213,19,236,84,45,252,148,169,107,246,159,199,184,147,138,232,47,95,202,220,254,52,74,5,22,65,102,248,96,78,15,112,43,201,187,210,227,4,85,212,190,91,172,205,135,143,168,44,228,80,37,36,127,208,10,216,117,12,116,14,109,231,133,158,99,75,178,81,70,161,163,218,32,181,142,225,103,134,20,62,247,250,180,56,162,224,151,26,69,40,251,90,67,60,110,34,226,207,174,28,241,31,233,175,234,104,50,72,164,244,160,88,179,230,83,18,53,49,122,100,76,154,152,222,48,87,3,191,98,101,92,93,77,131,200,128,38,229,57,105,55,221,120,68,59,27,183,219,33,115,204,23,209,63,171,193,113,243,203,29,146,157,2,16,58,211,24,141,165,51,11,106,166,238,129,123,64,89,136,189,1,82,185,177,194,156,176,126,170,239,137,145,13,119,215,30,195,6,42,182,153,245,17,173,94,214,149,73,118,242,121,217,198,249,253,150,237,186,125,196,66,197,235,108,7,139,188,21,155,132,167,41,206,79,54,0,71,9,192,240,111,25,39,255,130,223,114,35,86,97,124,61,46,144,140,8,213,19,236,84,45,252,148,169,107,246,159,199,184,147,138,232,47,95,202,220,254,52,74,5,22,65,102,248,96,78,15,112,43,201,187,210,227,4,85,212,190,91,172,205,135,143,168,44,228,80,37,36,127,208,10,216,117,12,116,14,109,231,133,158,99,75,178,81,70,161,163,218,32,181,142,225,103,134,20,62,247,250,180,56,162,224,151,26,69,40,251,90,67,60,110,34,226,207,174,28,241,31,233,175,234]);
  const in0 = inputs[0];
  const out0 = outputs[0];
  for (let i = start; i < stop; i++) {
    const o = i;
    const j0 = i;
    let r0;
    r0 = Number(in0[j0 * 1 + 0]);
    if (!Number.isFinite(r0)) return 1;
    let r1;
    r1 = 0.02;
    let r2;
    r2 = r0 * r1;
    if (!Number.isFinite(r2)) return 1;
    let r3;
    r3 = uniforms[0][3];
    if (!Number.isFinite(r3)) return 1;
    let r4;
    r4 = 0.25;
    let r5;
    r5 = fbm(table31, r2, r3, r4, 3);
    if (!Number.isFinite(r5)) return 1;
    if (!Number.isFinite(r5)) return 1;
    out0[o * 1 + 0] = r5;
  }
  return 0;
}
