The web export: a draw graph becomes a standalone browser application. A second run is byte-identical.

  $ rays-lisp web ../../../sketches/flow_vectors/sketch.rays -o out
  $ find out -type f | sort
  out/data.bin
  out/index.html
  out/kernels.json
  out/kernels.wgsl
  out/program.js
  out/program.map
  out/runtime/gpu.js
  out/runtime/marks.wgsl
  out/runtime/present.js
  out/runtime/prims.js
  out/runtime/runtime.js
  out/runtime/shape2.js
  out/runtime/workers.js
  $ rays-lisp web ../../../sketches/flow_vectors/sketch.rays -o again
  $ diff -r out again && echo identical
  identical
  $ head -1 out/program.js
  // Rays web export: frame program. frame(input, state, rt); see lib/flow_web/js.mli.
  $ grep -c "export function frame" out/program.js
  1
  $ cmp out/runtime/prims.js ../../web/runtime/prims.js && echo "runtime is the checked-in one"
  runtime is the checked-in one

A packed-array program keeps its constants in data.bin, and the region table names them.

  $ rays-lisp web ../../../examples/particles/sketch.rays -o particles
  $ test -s particles/data.bin && grep -c "rt.data" particles/program.js
  1

A draw graph that reaches a sop graph is refused, with the span of the reference.

  $ cat > sop.rays <<'X'
  > (workspace w
  >   (graph geometry :context sop (sop/box))
  >   (graph picture :context draw
  >     (let* [g (ref geometry)]
  >       (draw/merge (draw/background "#080a10")
  >                   (draw/circle [10 10 0] 5)))))
  > X
  $ rays-lisp web sop.rays -o refused
  File "sop.rays", line 4, characters 13-27:
  Error [E_WEB_GRAPH]: The web export draws 2D canvas graphs only; this reaches the sop geometry.
  [1]
  $ test -e refused && echo written || echo nothing written
  nothing written

So is a draw image, which needs a host image resolver.

  $ rays-lisp web ../../../sketches/flow_image/sketch.rays -o image 2>&1 | sed -n 2p
  Error [E_WEB_IMAGE]: The web export cannot draw an image yet: a draw image needs a host image resolver.

A mark set whose attributes are GPU regions never invokes them on the CPU: the frame names a device array, and two
attributes of equal count and rate share one kernel with an output each.

  $ rays-lisp web ../../../sketches/flow_particles_gpu/sketch.rays -o gpu
  $ grep -c "rt.gpuArray(0)" gpu/program.js
  1
  $ grep -c "rt.invoke" gpu/program.js
  0
  [1]
  $ grep -c '^export const gpu = ' gpu/program.js
  1
  $ grep -o '"id":"k[0-9]*"' gpu/kernels.json
  "id":"k0"
  $ cat > fused.rays <<'X'
  > (workspace w
  >   (graph g :context draw
  >     (let* [p (map (fn [i] [(+ i t) i 0]) (array/range 2048))
  >            r (map (fn [i] (+ 1 (* 0.001 (+ i t)))) (array/range 2048))]
  >       (draw/circles p :radius r))))
  > X
  $ rays-lisp web fused.rays -o fused
  $ grep -o '"gpu": {[^}]*}' fused/program.js
  "gpu": {"output": 0}
  "gpu": {"output": 1}
  $ grep -c '"id":' fused/kernels.json
  1
  $ grep -o '"output_widths":\[[0-9,]*\]' fused/kernels.json
  "output_widths":[3,1]

The frame reading a region's value (here one element of it) keeps that region on the CPU: a read on the GPU would be
a readback in the frame, which the web cannot do.

  $ cat > read.rays <<'X'
  > (workspace w
  >   (graph g :context draw
  >     (let* [p (map (fn [i] [(+ i t) i 0]) (array/range 2048))]
  >       (draw/merge (draw/circles p :radius 2) (draw/circle (array/nth p 0) 3)))))
  > X
  $ rays-lisp web read.rays -o read
  $ grep -c "rt.gpuArray" read/program.js
  0
  [1]
  $ grep -c "rt.invoke(0" read/program.js
  1
