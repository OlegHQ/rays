@group(0) @binding(0) var<storage, read> input0: array<f32>;
@group(0) @binding(1) var<storage, read_write> outbuf: array<f32>;
@group(0) @binding(2) var<uniform> uniforms: array<vec4<u32>, 1>;
@group(0) @binding(3) var<storage, read_write> status: atomic<u32>;
fn wfinite(x: f32) -> bool { return (bitcast<u32>(x) & 0x7f800000u) != 0x7f800000u; }
@compute @workgroup_size(64)
fn kernel_e2ce66b5dc20ad352100c31efab9ce29(@builtin(global_invocation_id) gid: vec3<u32>) {
  let i = gid.x;
  if (i >= uniforms[0].x) { return; }
  let r0: f32 = input0[i * 1u + 0u];
  if (!wfinite(r0)) { atomicStore(&status, 1u); }
  let r1: f32 = bitcast<f32>(uniforms[0].y);
  if (!wfinite(r1)) { atomicStore(&status, 1u); }
  let r2: f32 = select(0.0, 1.0, (r0 < r1));
  let r3: f32 = bitcast<f32>(0x3f800000u);
  let r4: f32 = (r0 + r3);
  if (!wfinite(r4)) { atomicStore(&status, 1u); }
  let r5: f32 = (r0 - r3);
  if (!wfinite(r5)) { atomicStore(&status, 1u); }
  let r6: f32 = select(r5, r4, r2 != 0.0);
  outbuf[i * 1u + 0u] = r6;
}
