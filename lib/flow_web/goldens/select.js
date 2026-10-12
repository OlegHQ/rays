function region(inputs, uniforms, outputs, start, stop) {
  const in0 = inputs[0];
  const out0 = outputs[0];
  for (let i = start; i < stop; i++) {
    const o = i;
    const j0 = i;
    const r0 = in0[j0 * 1 + 0];
    const r1 = uniforms[0][1];
    const r2 = (r0 < r1 ? 1 : 0);
    const r3 = 1;
    const r4 = r0 + r3;
    if (!Number.isFinite(r4)) return 1;
    const r5 = r0 - r3;
    if (!Number.isFinite(r5)) return 1;
    const r6 = r2 !== 0 ? r4 : r5;
    if (!Number.isFinite(r6)) return 1;
    out0[o * 1 + 0] = r6;
  }
  return 0;
}
