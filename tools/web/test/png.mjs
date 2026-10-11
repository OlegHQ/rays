// PNG (8-bit RGB or RGBA, no interlace) reader shared by the browser pixel checks.
import { readFileSync } from 'node:fs';
import { inflateSync } from 'node:zlib';

// A PNG file to {width, height, data: RGBA}.
export function decodePng(file) {
  const png = readFileSync(file);
  let pos = 8, width, height, type, idat = [];
  while (pos < png.length) {
    const length = png.readUInt32BE(pos), name = png.toString('latin1', pos + 4, pos + 8), body = png.subarray(pos + 8, pos + 8 + length);
    if (name === 'IHDR') { width = body.readUInt32BE(0); height = body.readUInt32BE(4); type = body[9]; if (body[8] !== 8 || body[12] !== 0) throw new Error('unsupported PNG'); }
    if (name === 'IDAT') idat.push(body);
    pos += 12 + length;
  }
  const bpp = type === 6 ? 4 : type === 2 ? 3 : (() => { throw new Error('PNG colour type ' + type); })();
  const raw = inflateSync(Buffer.concat(idat)), stride = width * bpp, out = Buffer.alloc(height * stride);
  for (let y = 0; y < height; y++) {
    const f = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[y * stride + x - bpp] : 0, b = y ? out[(y - 1) * stride + x] : 0, c = x >= bpp && y ? out[(y - 1) * stride + x - bpp] : 0;
      const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
      out[y * stride + x] = (line[x] + [0, a, b, (a + b) >> 1, pa <= pb && pa <= pc ? a : pb <= pc ? b : c][f]) & 255;
    }
  }
  const data = Buffer.alloc(width * height * 4, 255);
  for (let i = 0; i < width * height; i++) for (let k = 0; k < bpp; k++) data[i * 4 + k] = out[i * bpp + k];
  return { width, height, data };
}


// The pixel metric of the browser checks: per pixel the largest channel difference d (0..255). A picture passes when
// at most 0.5% of the pixels have d > 8 and none has d > 64. Different arithmetic (f32 GPU coverage and positions
// against the f64 core, ANGLE/Tint against MSL) moves antialiased edge pixels by a few levels; a wrong transform,
// snapping or colour moves whole regions by far more.
export function compare(got, native, count) {
  let over = 0, worst = 0, sum = 0;
  for (let i = 0; i < count; i++) {
    let d = 0;
    for (let k = 0; k < 3; k++) d = Math.max(d, Math.abs(got[i * 4 + k] - native[i * 4 + k]));
    if (d > 8) over++;
    worst = Math.max(worst, d); sum += d;
  }
  const fraction = over / count;
  return { over, worst, mean: sum / count, fraction, ok: fraction <= 0.005 && worst <= 64 };
}
