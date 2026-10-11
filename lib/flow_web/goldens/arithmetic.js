function region(inputs, uniforms, outputs, start, stop) {
  const in0 = inputs[0];
  const out0 = outputs[0];
  for (let i = start; i < stop; i++) {
    const o = i;
    const j0 = i;
    const r0 = in0[j0 * 1 + 0];
    const r1 = 2;
    const r2 = r0 * r1;
    if (!Number.isFinite(r2)) return 1;
    const r3 = uniforms[0][3];
    const r4 = r2 + r3;
    if (!Number.isFinite(r4)) return 1;
    if (!Number.isFinite(r4)) return 1;
    out0[o * 1 + 0] = r4;
  }
  return 0;
}
