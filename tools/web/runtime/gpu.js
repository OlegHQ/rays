// Browser runtime, part 3: WebGPU compute for regions placed on the GPU (plan P6.3).
// The same for every sketch. The host mirrors lib/flow_gpu/run.ml: owned buffers, uniform words, noise
// tables, the finite-f32 input check and the status word. Dispatch is one-dimensional, 64 per workgroup.
//
// Kernel table (JSON, written by the export command next to kernels.wgsl; for the golden fixtures by
// `test_wgsl.exe --write-kernel-table DIR`, which prints exactly what lib/flow_web/wgsl.ml returned):
//   { "kernels": [ {
//       "id": "k0",                    // call-site-independent name the program dispatches by
//       "entry": "kernel_<digest>",    // Wgsl.wgsl.entry
//       "source": "<WGSL>",            // Wgsl.wgsl.source (one module per kernel)
//       "interface": [ {"group":0,"binding":0,"kind":"read"|"read_write"|"uniform"} ... ],   // .interface
//       "uniform_layout": [ ["uniform:0", 4, 1], ["frame:1:t", 8, 1] ],   // [name, byte offset, width]
//       "uniform_bytes": 16,           // multiple of 16; word 0 (u32) is the element count, the rest f32 bits
//       "table_seeds": [31],           // noise seeds, ascending
//       "tables": [[...512 ints]],     // one permutation per seed, Rays_math.Noise.Private.permutation
//       "input_widths": [1],           // per input; an input no reachable instruction reads has no binding
//       "output_widths": [1]
//   } ] }
// Binding order is fixed by the printer: inputs (bound ones), outputs, uniforms, status, then the table.
//
// Surface: requestDevice(win) -> GPUDevice | null (the one device a page shares between this file and present.js; one
// plain message when WebGPU is missing), createGpu(table, {onError, win, device}) -> gpu | null (a device is requested
// when not given), gpu.upload(array) -> GPUBuffer (an input that stays on the device), gpu.dispatch(kernelId, {count, inputs, uniforms, id}) -> {count, outputs: [{id, buffer, width}]},
// gpu.poll() (call once per frame: reports status words of earlier dispatches), gpu.buffer(id),
// gpu.readback(id) (async, tests only), gpu.flush() (async: wait for all pending status words), gpu.dispose().
// `inputs[i]` is an array/typed array (finite after rounding to f32) or a GPUBuffer from an earlier dispatch;
// `uniforms` is keyed by uniform_layout name: a number, or an array for "uniform:n". `id` (default: the kernel
// id) names the call site; its buffers are `${id}:in${i}`, `${id}:out${k}`, `${id}:uniforms`, `${id}:status`,
// grown by doubling and destroyed when replaced, so an output handle is valid until the next dispatch of
// that call site. Errors are {code: 'E_KERNEL', message}; a status word of 1 arrives through onError on the
// poll after the work completes, never in the dispatching frame.

const WORKGROUP = 64;
const fail = message => { throw Object.assign(new Error(message), { code: 'E_KERNEL' }); };
const isBuffer = x => x && typeof x.mapAsync === 'function';
const KIND = { read: 'read-only-storage', read_write: 'storage', uniform: 'uniform' };

export async function requestDevice(win = globalThis) {
  const say = text => { if (win.document?.body) win.document.body.textContent = text; else console.error(text); };
  if (!win.navigator?.gpu) { say('This page needs WebGPU, which this browser does not provide. Use a recent Chrome, Edge or Safari.'); return null; }
  const adapter = await win.navigator.gpu.requestAdapter();
  if (!adapter) { say('WebGPU is present but no GPU adapter is available.'); return null; }
  return adapter.requestDevice();
}

export async function createGpu(table, { onError = e => console.error(e), win = globalThis, device } = {}) {
  device ??= await requestDevice(win);
  if (!device) return null;
  const U = globalThis.GPUBufferUsage;
  device.lost.then(info => onError({ code: 'E_KERNEL', message: `GPU device lost: ${info.message}` }));
  device.addEventListener('uncapturederror', e => onError({ code: 'E_KERNEL', message: e.error.message }));

  // Compile every kernel now, so a WGSL error is a load-time error naming the kernel.
  const kernels = new Map();
  const keyOf = k => JSON.stringify([k.source, k.entry, k.interface, k.table_seeds]);   // what a pipeline is built from
  const build = async k => {
    const module = device.createShaderModule({ code: k.source, label: k.id });
    const errors = (await module.getCompilationInfo()).messages.filter(m => m.type === 'error');
    if (errors.length) throw new Error(`WGSL error in kernel ${k.id}: ${errors.map(m => `${m.lineNum}:${m.linePos} ${m.message}`).join('; ')}`);
    const layout = device.createBindGroupLayout({ entries: k.interface.map(b =>
      ({ binding: b.binding, visibility: GPUShaderStage.COMPUTE, buffer: { type: KIND[b.kind] } })) });
    const pipeline = await device.createComputePipelineAsync({ label: k.id,
      layout: device.createPipelineLayout({ bindGroupLayouts: [layout] }), compute: { module, entryPoint: k.entry } });
    let tableBuffer = null;
    if (k.table_seeds.length) {
      tableBuffer = device.createBuffer({ size: k.table_seeds.length * 512 * 4, usage: U.STORAGE | U.COPY_DST });
      device.queue.writeBuffer(tableBuffer, 0, Int32Array.from(k.tables.flat()));
    }
    return { ...k, key: keyOf(k), layout, pipeline, tableBuffer };
  };
  for (const k of await Promise.all(table.kernels.map(build))) kernels.set(k.id, k);

  const owned = new Map();   // id -> {buffer, capacity, used}
  const own = (id, bytes, usage) => {
    let o = owned.get(id);
    if (!o || o.capacity < bytes) {
      o?.buffer.destroy();
      let capacity = Math.max(256, o?.capacity ?? 0);
      while (capacity < bytes) capacity *= 2;
      o = { buffer: device.createBuffer({ size: capacity, usage, label: id }), capacity, used: 0 };
      owned.set(id, o);
    }
    o.used = bytes;
    return o;
  };
  const pending = [];   // {staging, done, kernel}
  const maxBinding = device.limits.maxStorageBufferBindingSize;

  const gpu = {
    device, kernels,
    // Reload (plan P6.7): a new kernel table. A kernel whose WGSL, entry, bindings and noise seeds are unchanged
    // keeps its pipeline; only the others are compiled; a table the new one no longer uses is released.
    async update(next) {
      const built = await Promise.all(next.kernels.map(k => {
        const old = kernels.get(k.id);
        return old && old.key === keyOf(k) ? { ...old, ...k } : build(k);
      }));
      const keep = new Set(built.map(k => k.tableBuffer));
      for (const k of kernels.values()) if (!keep.has(k.tableBuffer)) k.tableBuffer?.destroy();
      kernels.clear();
      for (const k of built) kernels.set(k.id, k);
    },
    // An input that stays on the device between dispatches: the elements as f32 (finite), in a buffer the caller destroys.
    upload(array) {
      const f32 = Float32Array.from(array);
      for (let i = 0; i < f32.length; i++) if (!Number.isFinite(f32[i])) fail('GPU inputs must remain finite when represented as float32.');
      const buffer = device.createBuffer({ size: Math.max(16, f32.byteLength), usage: U.STORAGE | U.COPY_DST, label: 'input' });
      device.queue.writeBuffer(buffer, 0, f32);
      return buffer;
    },
    dispatch(kernelId, { count, inputs = [], uniforms = {}, id = kernelId }) {
      const k = kernels.get(kernelId);
      if (!k) fail(`Unknown GPU kernel ${kernelId}.`);
      gpu.poll();
      if (!Number.isInteger(count) || count < 0 || count >= 2 ** 32) fail('GPU count is not a 32-bit count.');
      const groups = Math.ceil(count / WORKGROUP);
      if (groups > device.limits.maxComputeWorkgroupsPerDimension) fail('GPU count exceeds the dispatch limit.');
      const outputs = k.output_widths.map((w, n) => ({ id: `${id}:out${n}`, width: w }));
      if (count === 0) return { count, outputs: outputs.map(o => ({ ...o, buffer: null })) };
      for (const w of [...k.output_widths, ...k.input_widths]) if (count * w * 4 > maxBinding) fail('GPU count exceeds native storage bounds.');
      // Uniform words (run.ml:78-91): count, then f32 bit patterns by layout name.
      const words = new DataView(new ArrayBuffer(k.uniform_bytes));
      words.setUint32(0, count, true);
      const put = (offset, v) => {
        const f = Math.fround(v);
        if (typeof v !== 'number' || !Number.isFinite(f)) fail('GPU inputs must remain finite when represented as float32.');
        words.setFloat32(offset, f, true);
      };
      for (const [name, offset, width] of k.uniform_layout) {
        const v = uniforms[name];
        if (v === undefined) fail(`GPU uniform ${name} missing.`);
        if (width === 1 && !Array.isArray(v) && !ArrayBuffer.isView(v)) put(offset, v);
        else if (v.length === width) for (let c = 0; c < width; c++) put(offset + c * 4, v[c]);
        else fail('GPU uniform type changed.');
      }
      const uniformBuffer = own(`${id}:uniforms`, k.uniform_bytes, U.UNIFORM | U.COPY_DST);
      device.queue.writeBuffer(uniformBuffer.buffer, 0, words.buffer);
      const status = own(`${id}:status`, 4, U.STORAGE | U.COPY_SRC | U.COPY_DST);
      device.queue.writeBuffer(status.buffer, 0, new Uint32Array(1));
      const entries = [];
      for (const b of k.interface) {
        const n = b.binding, ins = k.input_widths.length, outs = k.output_widths.length;
        if (n < ins) {   // a bound input
          const source = inputs[n], bytes = count * k.input_widths[n] * 4;
          if (isBuffer(source)) entries.push({ binding: n, resource: { buffer: source, size: bytes } });
          else {
            if (!source || source.length < count * k.input_widths[n]) fail('GPU input count changed.');
            const f32 = Float32Array.from({ length: bytes / 4 }, (_, i) => source[i]);
            for (let i = 0; i < f32.length; i++) if (!Number.isFinite(f32[i])) fail('GPU inputs must remain finite when represented as float32.');
            const o = own(`${id}:in${n}`, bytes, U.STORAGE | U.COPY_DST);
            device.queue.writeBuffer(o.buffer, 0, f32);
            entries.push({ binding: n, resource: { buffer: o.buffer, size: bytes } });
          }
        } else if (n < ins + outs) {
          const bytes = count * k.output_widths[n - ins] * 4;
          const o = own(outputs[n - ins].id, bytes, U.STORAGE | U.COPY_SRC | U.COPY_DST);
          outputs[n - ins].buffer = o.buffer;
          entries.push({ binding: n, resource: { buffer: o.buffer, size: bytes } });
        } else if (b.kind === 'uniform') entries.push({ binding: n, resource: { buffer: uniformBuffer.buffer, size: k.uniform_bytes } });
        else if (b.kind === 'read_write') entries.push({ binding: n, resource: { buffer: status.buffer, size: 4 } });
        else entries.push({ binding: n, resource: { buffer: k.tableBuffer } });
      }
      const staging = device.createBuffer({ size: 4, usage: U.MAP_READ | U.COPY_DST });
      const encoder = device.createCommandEncoder();
      const pass = encoder.beginComputePass();
      pass.setPipeline(k.pipeline);
      pass.setBindGroup(0, device.createBindGroup({ layout: k.layout, entries }));
      pass.dispatchWorkgroups(groups);
      pass.end();
      encoder.copyBufferToBuffer(status.buffer, 0, staging, 0, 4);
      device.queue.submit([encoder.finish()]);
      const entry = { staging, kernel: kernelId, done: false };
      entry.promise = staging.mapAsync(GPUMapMode.READ).then(() => { entry.done = true; }, () => { entry.done = true; entry.lost = true; });
      pending.push(entry);
      return { count, outputs };
    },
    // Reads the status words of dispatches whose work has finished; the rest wait for the next call.
    poll() {
      for (let i = 0; i < pending.length;) {
        const p = pending[i];
        if (!p.done) { i++; continue; }
        pending.splice(i, 1);
        if (!p.lost) {
          const flag = new Uint32Array(p.staging.getMappedRange())[0];
          p.staging.unmap();
          if (flag !== 0) onError({ code: 'E_KERNEL', message: 'GPU output contains a nonfinite value.', kernel: p.kernel });
        }
        p.staging.destroy();
      }
    },
    async flush() { await Promise.all(pending.map(p => p.promise)); gpu.poll(); },
    buffer: id => owned.get(id)?.buffer ?? null,
    // Tests only: a copy of the buffer's used bytes as f32. Production frames never read back.
    async readback(id) {
      const o = owned.get(id);
      if (!o) fail(`Unknown GPU buffer ${id}.`);
      const staging = device.createBuffer({ size: o.used, usage: U.MAP_READ | U.COPY_DST });
      const encoder = device.createCommandEncoder();
      encoder.copyBufferToBuffer(o.buffer, 0, staging, 0, o.used);
      device.queue.submit([encoder.finish()]);
      await staging.mapAsync(GPUMapMode.READ);
      const out = new Float32Array(staging.getMappedRange().slice(0));
      staging.destroy();
      return out;
    },
    dispose() { for (const o of owned.values()) o.buffer.destroy(); for (const k of kernels.values()) k.tableBuffer?.destroy(); owned.clear(); device.destroy(); },
  };
  return gpu;
}
