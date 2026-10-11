function region(inputs, uniforms, outputs, start, stop) {
  const in0 = inputs[0];
  const out0 = outputs[0];
  const out1 = outputs[1];
  for (let i = start; i < stop; i++) {
    const o = i;
    const j0 = i;
    const r0 = in0[j0 * 1 + 0];
    const r1 = uniforms[0][1];
    const r2 = r0 + r1;
    if (!Number.isFinite(r2)) return 1;
    if (!Number.isFinite(r2)) return 1;
    out0[o * 1 + 0] = r2;
    if (!Number.isFinite(r0)) return 1;
    out1[o * 2 + 0] = r0;
    if (!Number.isFinite(r2)) return 1;
    out1[o * 2 + 1] = r2;
  }
  return 0;
}
