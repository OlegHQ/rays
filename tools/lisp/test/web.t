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

The built-in noise image exports with native seeded scalar arguments.

  $ rays-lisp web ../../../sketches/flow_image/sketch.rays -o image
  $ grep -c "kind: 'noise'" image/program.js
  1

Generated images export deterministically, with kernels and compiled live arguments, without UV data.

  $ rays-lisp web ../../../sketches/flow_contours/sketch.rays -o contours
  $ rays-lisp web ../../../sketches/flow_contours/sketch.rays -o contours_again
  $ diff -r contours contours_again && echo identical
  identical
  $ grep -c '"id":"image[0-9]*"' contours/kernels.json
  6
  $ test ! -s contours/data.bin && echo 'UVs are computed on the GPU'
  UVs are computed on the GPU
  $ rays-lisp web ../../../sketches/flow_image_kernel/sketch.rays -o image_kernel
  $ rays-lisp web ../../../sketches/flow_shader/sketch.rays -o shader

File images are decoded into the standalone bundle; nested render targets export deterministically.

  $ printf 'P3\n2 1\n255\n255 0 0 0 255 0\n' > pixels.ppm
  $ cat > loaded.rays <<'X'
  > (workspace w (graph picture :context draw
  >   (draw/image (image/render (draw/image (image/load "pixels.ppm")) :width 3 :height 5))))
  > X
  $ rays-lisp web loaded.rays -o loaded
  $ rays-lisp web loaded.rays -o loaded_again
  $ diff -r loaded loaded_again && echo identical
  identical
  $ test -s loaded/data.bin && grep -c "kind: 'load'" loaded/program.js
  1
  $ grep -c "kind: 'render'" loaded/program.js
  1

Missing or invalid assets fail before writing any export.

  $ printf 'bad image\n' > pixels.ppm
  $ rays-lisp web loaded.rays -o bad 2>&1 | sed -n 's/^Error \[\([^]]*\)\].*/\1/p'
  E_WEB_IMAGE
  $ test -e bad && echo written || echo nothing written
  nothing written
  $ rm pixels.ppm
  $ rays-lisp web loaded.rays -o missing 2>&1 | sed -n 's/^Error \[\([^]]*\)\].*/\1/p'
  E_WEB_IMAGE
  $ test -e missing && echo written || echo nothing written
  nothing written

A standalone application's file assets must be known at export time.

  $ cat > dynamic_path.rays <<'X'
  > (workspace w (graph picture :context draw
  >   (draw/image (image/load (str "image-" (frame/index) ".png")))))
  > X
  $ rays-lisp web dynamic_path.rays -o bad 2>&1 | sed -n 2p
  Error [E_WEB_IMAGE]: A standalone export needs image/load paths known at export time.

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
