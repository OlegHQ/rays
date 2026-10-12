module E=Flow.Eval
module I=Flow_ir
module P=I.Packed
let ok=function Ok v->v|Error d->failwith(Flow.Diagnostic.to_string d)
let numeric=function
  |E.Int_array a->"BigInt64Array.from(["^String.concat ","(Array.to_list(Array.map(fun n->string_of_int n^"n")a))^"])"
  |v->let a=match v with E.Float_array a|Vec2_array a|Vec3_array a|Vec4_array a->a|_->assert false in
      "Float64Array.from(["^String.concat ","(Array.to_list(Array.map(fun x->
        if Int64.bits_of_float x=Int64.min_int then "-0" else Printf.sprintf "%.17g" x)a))^"])"
let fixture ty table indices body=
  let text="(workspace w (graph g :context host [(table : (array "^Flow.Ty.to_string ty^") (array/int 0)) (indices : (array int) (array/int 0))] (map (fn [(i : int)] "^body^") indices)))" in
  (* The supplied typed table is checked; its textual default has the same type. *)
  let default=match ty with Flow.Ty.Int->"(array/int 0)"|Float->"(array/float 0)"
    |Vec2->"(map (fn [i] [0 0]) (array/range 0))"|Vec3->"(array/vec3 0)"|_->"(array/vec4 0)" in
  let text=Str.global_replace(Str.regexp_string "(array/int 0)) (indices")(default^") (indices")text in
  let ws=match Flow.Workspace.check Flow.Check.{version=1;kinds=[]}(ok(Flow.Syntax.parse text))with
    |Some w,[]->w|_,ds->failwith(String.concat ";"(List.map Flow.Diagnostic.to_string ds)) in
  let value=List.assoc "g"(ok(E.static ~inputs:["g",["table",table;"indices",E.Int_array indices]]ws)).results in
  let r=match value with E.Residual r->r|_->failwith"Gather must remain live" in
  let p=match P.compile_result r(E.Private.residual_view r).term with
    |Ok p->p|Error ds->failwith(String.concat ";"(List.map Flow.Diagnostic.to_string ds))in
  value,p
let ()=
  let js=Buffer.create 1000000 in
  let path file="file://"^Filename.concat(Sys.getcwd())("../../tools/web/runtime/"^file)in
  Printf.bprintf js "import {createRuntime} from %S;import {createPool} from %S;\nconst bytes=a=>Buffer.from(a.buffer,a.byteOffset,a.byteLength);\n"(path"runtime.js")(path"workers.js");
  Buffer.add_string js "const pools=[null,await createPool({size:1}),await createPool({size:8})];try {\n";
  let live=Frame_input.at_time 0.25 in
  let section ty table indices body expected=
    let value,p=fixture ty table indices body in
    assert(P.gpu_refusals p<>[]);
    assert(Result.is_error(Flow_web.Wgsl.kernel p));
    let prepared=ok(P.Private.prepare_values p ~live)in
    let result=P.force ~strict:true p ~live in
    (match expected,result with Some _,Ok got->assert(Marshal.to_string got[]=Marshal.to_string(ok(E.Private.force_reference value ~live))[])|None,Error _->()|_->assert false);
    Buffer.add_string js "{\n";
    Printf.bprintf js "const arrays=[%s], captures=[%s];\n"
      (String.concat ","(Array.to_list(Array.map numeric prepared.arrays)))
      (String.concat ","(Array.to_list(Array.map numeric prepared.uniforms)));
    Buffer.add_string js "const data=new ArrayBuffer([...arrays,...captures].reduce((n,a)=>n+a.byteLength,0));let offset=0;const store=a=>{const spec=[offset,a.length,a instanceof BigInt64Array];new a.constructor(data,offset,a.length).set(a);offset+=a.byteLength;return spec};const inputs=arrays.map(store),uniforms=captures.map(a=>({table:store(a)}));\n";
    let r=P.to_region p in
    let facts=Array.to_list(Array.mapi(fun slot instr->match instr with
      |I.Core.Region.Frame name->Some(Printf.sprintf"[%d,%S,false]"slot name)
      |Int_frame name->Some(Printf.sprintf"[%d,%S,true]"slot name)|_->None)r.code)|>List.filter_map Fun.id in
    Printf.bprintf js "const program={regions:[{source:%S,count:%d,kept:%d,inputs,uniforms,frame:[%s],length:%d,width:%d,integer:%b}]};\n"
      (Flow_web.Js.region p)prepared.count prepared.count(String.concat ","facts)(Array.length r.code)
      (Array.length r.outputs.(0))(ty=Flow.Ty.Int);
    Buffer.add_string js "for(const pool of pools){const rt=createRuntime(program,{data,pool});rt.current={t:.25,dt:0,frame:0,size:[1,1]};\n";
    (match result with
     |Ok got->Printf.bprintf js "const expected=%s;const got=await rt.invoke(0,[]);if(!bytes(got.data).equals(bytes(expected)))throw Error('gather runtime bytes');\n"(numeric got)
     |Error d->Printf.bprintf js "try{await rt.invoke(0,[]);throw Error('gather accepted')}catch(e){if(e.code!==%S||e.message!==%S||e.cause!==%s)throw e}\n"d.code d.message(Option.fold ~none:"undefined" ~some:(Printf.sprintf"%S")d.cause));
    Buffer.add_string js "}\n}\n" in
  List.iter(fun ty->let width=Option.get(Flow.Packed_ops.scalar_width ty)in
    let table=if ty=Flow.Ty.Int then E.Int_array[|min_int;max_int;9007199254740993;0;-1;1;2|]
      else let data=Array.init(7*width)(fun i->[|-0.;0.;Int64.float_of_bits 1L;0.25;-0.75|].(i mod 5))in
        match ty with Float->E.Float_array data|Vec2->Vec2_array data|Vec3->Vec3_array data|_->Vec4_array data in
    let zero=if width=1 then "0"else "["^String.concat " "(List.init width(fun _->"0"))^"]" in
    section ty table(Array.init 32769 Fun.id)("(if (> t 0.) (array/nth table (int/mod i 7)) "^zero^")")(Some()))
    [Flow.Ty.Int;Float;Vec2;Vec3;Vec4];
  let table=E.Int_array[|min_int;max_int;9007199254740993|]in
  List.iter(fun index->section Flow.Ty.Int table[|index|]"(if (> t 0.) (array/nth table i) 0)"None)
    [-1;3;Sys.max_array_length+1;max_int];
  section Flow.Ty.Int table(Array.init 32769(fun i->if i=4 then 3 else if i=20000 then -1 else 0))
    "(if (> t 0.) (array/nth table i) 0)"None;
  section Flow.Ty.Int table(Array.init 32769(fun i->if i=0 then 3 else 1))
    "(let* [before (int/div 1 (if (int/eq i 1) 0 1))] (if (> t 0.) (array/nth table i) 0))"None;
  section Flow.Ty.Int table[|-1|]"(if (> t 0.) 0 (array/nth table i))"(Some());
  section Flow.Ty.Int table(Array.init 32769(fun i->if i=0 then 0 else -1))
    "(if (> t 0.) (if (int/eq i 0) (error \"E_LOOKUP\" \"first row\" :cause \"lookup cause\") (array/nth table i)) 0)"None;
  (* Malformed floating table spans and invalid unselected rows retain the
     same validation diagnostic as the native region trust boundary. *)
  let _,p=fixture Flow.Ty.Vec3(E.Vec3_array(Array.make 9 0.))[|0|]
    "(if (> t 0.) (array/nth table i) [0 0 0])"in
  let r=P.to_region p in
  let slot=Array.find_map(function I.Core.Region.Array_prepare(i,_)->Some i
    |Guarded(_,Array_prepare(i,_))->Some i|_->None)r.code|>Option.get in
  List.iter(fun data->let uniforms=Array.copy r.uniforms in uniforms.(slot)<-E.Vec3_array data;
    let bad=P.of_region{r with uniforms}|>Result.get_ok in
    let diagnostic=match P.force ~strict:true bad ~live with Error d->d|_->assert false in
    let prepared=ok(P.Private.prepare_values p ~live)in
    let frame=Array.map(function E.Float x->x|_->0.)prepared.frame in
    Buffer.add_string js "{\n";Buffer.add_string js(Flow_web.Js.region p);
    let data=if Array.exists Float.is_nan data then "Float64Array.of(0,0,0,0,NaN,0)"else numeric(E.Vec3_array data)in
    Printf.bprintf js "try{region([BigInt64Array.of(0n)],[%s,%s],[new Float64Array(3)],0,1);throw Error('bad table accepted')}catch(e){if(e.code!==%S||e.message!==%S)throw e}\n}\n"
      data(numeric(E.Float_array frame))diagnostic.code diagnostic.message)
    [[|0.;0.|];[|0.;0.;0.;0.;nan;0.|]];
  Printf.bprintf js "{const p=await import(%S);for(const index of [-1n,%sn,%sn]){try{p.array_nth(new p.PArray(1,BigInt64Array.of(1n)),index);throw Error('bad scalar lookup accepted')}catch(e){if(e.code!=='E_ARRAY_RANGE'||e.message!=='array/nth needs a non-negative whole length.')throw e}}}\n"
    (path"prims.js")(string_of_int(Sys.max_array_length+1))(string_of_int max_int);
  Buffer.add_string js "}finally{for(const pool of pools)pool?.close()}\nconsole.log('gather runtime: exact numeric tables, native errors and one/eight workers pass');\n";
  let path=Filename.temp_file "gather" ".mjs"in
  Out_channel.with_open_bin path(fun out->output_string out(Buffer.contents js));
  let status=Sys.command("node "^Filename.quote path)in Sys.remove path;assert(status=0)
