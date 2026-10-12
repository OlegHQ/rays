Invariant lookup tables are independent of the mapped source count. The generated export
transports numeric captures through data.bin and executes the actual runtime and worker pool.

  $ cat > gather.rays <<'X'
  > (workspace gather (graph picture :context draw
  >   (let* [table (map (fn [i] [(+ i 0.25) (- i 1.0) -0.0]) (array/range 7))
  >          positions (map (fn [(i : int)] (+ (array/nth table (int/mod i 7)) [t 0.0 0.0])) (array/range 32769 :type int))]
  >     (draw/points positions :color "#ffffff"))))
  > X
  $ rays-lisp web gather.rays -o gather
  $ printf '{"type":"module"}\n' > gather/package.json
  $ cat > gather.mjs <<'X'
  > import {readFileSync} from 'node:fs';
  > import * as program from './gather/program.js';
  > import {createRuntime} from './gather/runtime/runtime.js';
  > import {createPool} from './gather/runtime/workers.js';
  > const file=readFileSync('gather/data.bin'),data=file.buffer.slice(file.byteOffset,file.byteOffset+file.byteLength);
  > const region=program.regions.findIndex(r=>r.source.includes('const table ='));
  > if(region<0||program.regions[region].count!==32769||!program.regions[region].uniforms.some(u=>u.table))throw Error('lookup capture transport');
  > for(const size of [0,1,8]){const pool=size?await createPool({size}):null;
  >   try{const rt=createRuntime(program,{data,pool});rt.current={t:.25,dt:0,frame:0,size:[1,1]};
  >     const out=(await rt.invoke(region,[])).data;
  >     for(let i=0;i<32769;i++){const row=i%7;if(out[i*3]!==row+.5||out[i*3+1]!==row-1||!Object.is(out[i*3+2],0))throw Error('lookup export bytes '+i)}
  >     await rt.stepFrame({t:.25,frame:1});if(rt.counts.gpu!==0||rt.marks.length===0)throw Error('lookup actual frame');
  >   }finally{pool?.close()}}
  > console.log('lookup export: data.bin, actual frames, one/eight workers and CPU placement pass');
  > X
  $ node gather.mjs
  lookup export: data.bin, actual frames, one/eight workers and CPU placement pass

Integer lookup captures keep their low bits through the actual exported data writer.

  $ cat > integer.rays <<'X'
  > (workspace gather (graph picture :context draw
  >   (let* [table (array/int 3 9007199254740993)
  >          samples (map (fn [(i : int)] (int/add (array/nth table (int/mod i 3)) (frame/index))) (array/range 32769 :type int))]
  >     (draw/text [0 0 0] (str (array/nth samples 0))))))
  > X
  $ rays-lisp web integer.rays -o integer
  $ printf '{"type":"module"}\n' > integer/package.json
  $ cat > integer.mjs <<'X'
  > import {readFileSync} from 'node:fs';import * as program from './integer/program.js';
  > import {createRuntime} from './integer/runtime/runtime.js';import {createPool} from './integer/runtime/workers.js';
  > const file=readFileSync('integer/data.bin'),data=file.buffer.slice(file.byteOffset,file.byteOffset+file.byteLength);
  > const region=program.regions.findIndex(r=>r.source.includes('const table ='));
  > if(region<0||!program.regions[region].integer||!program.regions[region].uniforms.some(u=>u.table?.[2]))throw Error('integer table transport');
  > for(const size of [0,1,8]){const pool=size?await createPool({size}):null;try{
  >   const rt=createRuntime(program,{data,pool});rt.current={t:.25,dt:0,frame:2,size:[1,1]};
  >   const values=(await rt.invoke(region,[])).data;if(!(values instanceof BigInt64Array)||values.some(n=>n!==9007199254740995n))throw Error('integer table bits');
  >   await rt.stepFrame({t:.25,frame:2});if(rt.marks.find(m=>m.type==='text')?.text!=='9007199254740995')throw Error('integer table frame');
  > }finally{pool?.close()}}
  > console.log('integer lookup export: exact signed63 data and actual frame pass');
  > X
  $ node integer.mjs
  integer lookup export: exact signed63 data and actual frame pass
