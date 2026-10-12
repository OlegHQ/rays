module E=Flow.Eval
module V=Flow.Value
module I=Flow_ir
module P=I.Packed
let ok=function Ok v->v|Error d->failwith(Flow.Diagnostic.to_string d)
let bytes v=Marshal.to_string v [Marshal.No_sharing]
let source ty : Flow.Op.t={I.Operators.noise3 with
  name="probe/table";packed_extension=None;
  signature={pos=[];opt=[];rest=None;kw=[]};out=(fun _->ty);
  shape=Flow.Op.Struct{splice=false};check=(fun _->());
  body=(fun ~live:_ ~node:_ _->Flow.Value.Source("probe/table",ty,[]))}
let fn ?(bindings="") ty body =
  let text="(workspace w (graph g :context value (let* [data (probe/table) "^bindings^" tested "^body^"] 0.0)))" in
  let ws=match Flow.Workspace.check ~ops:[source ty] {Flow.Check.version=1;kinds=[]}
    (ok(Flow.Syntax.parse text))with
    |Some ws,[]->ws|_,ds->failwith(String.concat "; "(List.map Flow.Diagnostic.to_string ds))in
  match snd(List.hd(List.assoc ["g";"tested"](ok(E.static ~record:true ws)).records))with
  |E.Fn fn->fn|_->assert false
let instantiate ?table ?bindings ty body indices =
  let fn=fn ?bindings ty body in
  let fn=match table with None->fn|Some table->E.Private.map_function_bindings
    (function E.Source("probe/table",_,_)->table|v->v)fn in
  ok(E.Private.map_function ~signature:Flow.Ty.{params=[Int];result=Option.get(elem ty)} fn
    [E.Int_array indices])
let packed ?(fusion=true) value=match value with
  |E.Residual r->(match P.compile_result ~fusion r(E.Private.residual_view r).term with
    |Ok p->p|Error ds->failwith(String.concat "; "(List.map Flow.Diagnostic.to_string ds)))
  |_->failwith "Expected a gathered residual"
let diagnostic=function Error (d:Flow.Diagnostic.t)->d|Ok _->failwith "Expected gather failure"
let same_error a b=let a=diagnostic a and b=diagnostic b in
  assert(a.Flow.Diagnostic.code=b.code && a.message=b.message && a.cause=b.cause)
let array ty count=match ty with
  |Flow.Ty.Int->E.Int_array(Array.init count(fun i->[|min_int;max_int;9007199254740993;0;-1|].(i mod 5)))
  |ty->let width=Option.get(Flow.Packed_ops.scalar_width ty)in
    let values=Array.init(count*width)(fun i->[|-0.;0.;Float.next_after 0. 1.;0.25; -0.75|].(i mod 5))in
    (match width with 1->E.Float_array values|2->Vec2_array values|3->Vec3_array values|_->Vec4_array values)
let recorded ty body=
  let text="(workspace w (graph g :context value (let* [data (probe/table) tested "^body^"] 0.0)))"in
  let ws=match Flow.Workspace.check ~ops:[source ty] Flow.Check.{version=1;kinds=[]}
    (ok(Flow.Syntax.parse text))with Some ws,[]->ws|_,ds->
      failwith(String.concat ";"(List.map Flow.Diagnostic.to_string ds))in
  snd(List.hd(List.assoc["g";"tested"](ok(E.static ~record:true ws)).records))
let ()=
  List.iter(fun ty->let table=array ty 7 in
    List.iter(fun count->
      let value=instantiate ~table (Flow.Ty.Array ty)
        "(fn [(index : int)] (let* [alias data] (array/nth alias (int/mod index 7))))"
        (Array.init count Fun.id)in
      let reference=ok(E.Private.force_reference value ~live:(Frame_input.at_time 0.25))in
      List.iter(fun fusion->let p=packed ~fusion value in
        assert(P.static_count p=Some count);
        assert(List.exists(fun d->d.Flow.Diagnostic.code="E_GPU_FORM")(P.gpu_refusals p));
        let executor=ok(I.Executor.compile ~strict:true value)in
        List.iter(fun domains->Rays_math.Parallel.run ~domains(fun()->
          assert(bytes(ok(P.force ~strict:true p ~live:(Frame_input.at_time 0.25)))=bytes reference);
          assert(bytes(ok(I.Executor.force ~strict:true executor ~live:(Frame_input.at_time 0.25)))=bytes reference))) [1;4;8]) [false;true])
      [0;1;13;32769]) [Flow.Ty.Int;Float;Vec2;Vec3;Vec4];
  let table=E.Int_array[|min_int;max_int;9007199254740993|]in
  let helper=instantiate ~table ~bindings:"lookup (fn [(table : (array int)) (index : int)] (array/nth table index))" (Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (lookup data (int/mod index 3)))"
    (Array.init 5001 Fun.id)in
  assert(bytes(ok(P.force ~strict:true(packed helper)~live:(Frame_input.at_time 0.)))=
    bytes(ok(E.Private.force_reference helper ~live:(Frame_input.at_time 0.))));
  List.iter(fun index->let value=instantiate ~table (Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (array/nth data index))"[|index|]in
    same_error(P.force ~strict:true(packed value)~live:(Frame_input.at_time 0.))
      (E.Private.force_reference value ~live:(Frame_input.at_time 0.))) [-1;3;Sys.max_array_length+1;max_int];
  let value=instantiate ~table (Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (if (int/lt index 0) 0 (array/nth data index)))"[|-1;0;1|]in
  assert(ok(P.force ~strict:true(packed value)~live:(Frame_input.at_time 0.))=E.Int_array[|0;min_int;max_int|]);
  (* A later lane's earlier instruction must not replace the first lane's error. *)
  let value=instantiate ~table (Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (let* [divisor (if (int/eq index 1) 0 1) before (int/div 1 divisor)] (array/nth data index)))"
    (Array.init 32769(fun i->if i=0 then 3 else 1))in
  List.iter(fun domains->Rays_math.Parallel.run ~domains(fun()->
    same_error(P.force ~strict:true(packed value)~live:(Frame_input.at_time 0.))
      (E.Private.force_reference value ~live:(Frame_input.at_time 0.))))[1;4;8];
  let value=instantiate ~table (Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (array/nth data index))"(Array.init 32769(fun i->if i=4 then 3 else if i=20000 then -1 else 0))in
  List.iter(fun domains->Rays_math.Parallel.run ~domains(fun()->
    same_error(P.force ~strict:true(packed value)~live:(Frame_input.at_time 0.))
      (E.Private.force_reference value ~live:(Frame_input.at_time 0.))))[1;4;8];
  (* Host tables resolve on the initial domain, once for the selected execution. *)
  let value=instantiate (Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (array/nth data (int/mod index 3)))"(Array.init 32769 Fun.id)in
  let calls=ref 0 and domain=Domain.self()in
  let resolve=function E.Source("probe/table",_,_)->assert(Domain.self()=domain);incr calls;Ok table
    |_->Error(Flow.Diagnostic.error ~code:"E_DATA_SOURCE" "Unexpected source")in
  List.iter(fun domains->calls:=0;Rays_math.Parallel.run ~domains(fun()->
    ignore(ok(P.force ~strict:true ~resolve(packed value)~live:(Frame_input.at_time 0.))));assert(!calls=1))[1;8];
  let repeated=instantiate(Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (int/add (array/nth data 0) (array/nth data (int/mod index 3))))"(Array.init 5001 Fun.id)in
  calls:=0;ignore(ok(P.force ~strict:true ~resolve(packed repeated)~live:(Frame_input.at_time 0.)));assert(!calls=1);
  let untouched=instantiate (Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (if (int/lt index 0) 0 (array/nth data index)))"[|-1|]in
  calls:=0;ignore(ok(P.force ~strict:true ~resolve(packed untouched)~live:(Frame_input.at_time 0.)));assert(!calls=0);
  let failing=function E.Source("probe/table",_,_)->Error(Flow.Diagnostic.error ~cause:"table first" ~code:"E_DATA_SOURCE" "Missing table")
    |_->assert false in
  let ordered=instantiate (Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (array/nth data (int/div index 0)))"[|0|]in
  same_error(P.force ~strict:true ~resolve:failing(packed ordered)~live:(Frame_input.at_time 0.))
    (E.Private.force_reference ~resolve:failing ordered ~live:(Frame_input.at_time 0.));
  (* Live term evaluation concretizes each let value, even an unused alias.
     That table position must remain ordered against an earlier/later error. *)
  List.iter(fun body->let value=instantiate(Flow.Ty.Array Flow.Ty.Int)body[|0|]in
    same_error(P.force ~strict:true ~resolve:failing(packed value)~live:(Frame_input.at_time 0.))
      (E.Private.force_reference ~resolve:failing value ~live:(Frame_input.at_time 0.)))
    ["(fn [(index : int)] (let* [alias data] 0))";
     "(fn [(index : int)] (let* [before (int/div index 0) alias data] (array/nth alias 0)))";
     "(fn [(index : int)] (let* [alias data after (int/div index 0)] (array/nth alias 0)))"];
  (* Handles cannot escape or be interpreted as scalar arithmetic in public regions. *)
  let region=P.to_region(packed value)in
  let prepare=Array.find_index(function I.Core.Region.Array_prepare _->true|_->false)region.code |>Option.get in
  assert(Result.is_error(P.of_region{region with outputs=[|[|prepare|]|]}));
  let input=Array.find_index(function I.Core.Region.Int_input _->true|_->false)region.code |>Option.get in
  let code=Array.copy region.code in
  code.(Array.length code-1)<-I.Core.Region.Int_gather(input,input);
  assert(Result.is_error(P.of_region{region with code}));
  let code=Array.copy region.code in
  code.(prepare)<-I.Core.Region.Guarded([input,true],code.(prepare));
  assert(Result.is_error(P.of_region{region with code}));
  let dependent=instantiate ~table (Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (array/nth (array/int (int/add index 1)) 0))"[|0;1|]in
  (match dependent with E.Residual r->assert(Result.is_error(P.compile_result r(E.Private.residual_view r).term))|_->assert false);
  let live=Frame_input.at_time 0.25 in
  (* Table counts are independent of Zip/Product counts and ordered accumulator steps. *)
  List.iter(fun body->let value=recorded(Flow.Ty.Array Flow.Ty.Int)body in
    let p=packed value and core=ok(I.Executor.compile ~strict:true value)in
    List.iter(fun table->let resolve=function E.Source("probe/table",_,_)->Ok table|_->assert false in
      let expected=E.Private.force_reference ~resolve value ~live in
      List.iter(fun domains->Rays_math.Parallel.run ~domains(fun()->
        assert(bytes(ok(P.force ~strict:true ~resolve p ~live))=bytes(ok expected));
        assert(bytes(ok(I.Executor.force ~strict:true ~resolve core ~live))=bytes(ok expected))))[1;4;8])
      [table;E.Int_array[|9007199254740993;min_int;max_int|]])
    ["(for [i (array/range 5001 :type int) j (array/range 3 :type int)] (int/add (array/nth data (int/mod i 3)) (int/add j (frame/index))))";
     "(array/sum (map (fn [i] (int/add (array/nth data (int/mod i 3)) (frame/index))) (array/range 5001 :type int)))";
     "(fold [a (frame/index)] [i (array/range 5001 :type int)] (int/add a (array/nth data (int/mod i 3))))";
     "(scan [a (frame/index)] [i (array/range 5001 :type int)] (int/xor a (array/nth data (int/mod i 3))))"];
  (* Iteration skips exclude the body, while discarded sinks still execute it. *)
  let value=recorded(Flow.Ty.Array Flow.Ty.Int)
    "(for [i (array/range 13 :type int)] :skip [4] (if (int/eq i 4) (array/nth data -1) (int/add (array/nth data (int/mod i 3)) (frame/index))))"in
  calls:=0;
  assert(bytes(ok(P.force ~strict:true ~resolve(packed value)~live))=
    bytes(ok(E.Private.force_reference ~resolve value ~live)));
  let value=instantiate ~table:(E.Float_array[|0.;-0.;1.|])(Flow.Ty.Array Flow.Ty.Float)
    "(fn [(index : int)] (array/nth data index))"[|3|]in
  same_error(P.force_into ~strict:true ~column_source:(fun _ _->Ok None)~count:1
    ~outputs:[|[|None|]|](packed value)~live)(E.Private.force_reference value ~live);
  (* Trust boundaries retain source type, unresolved descriptor and finite errors. *)
  List.iter(fun returned->let resolve _=Ok returned in
    same_error(P.force ~strict:true ~resolve(packed ordered)~live)
      (E.Private.force_reference ~resolve ordered ~live))
    [E.Float_array[|1.|];E.Source("probe/table",Flow.Ty.Array Flow.Ty.Int,[])];
  let bad=instantiate(Flow.Ty.Array Flow.Ty.Float)
    "(fn [(index : int)] (array/nth data index))"[|0|]in
  List.iter(fun x->let resolve _=Ok(E.Float_array[|x|])in
    same_error(P.force ~strict:true ~resolve(packed bad)~live)
      (E.Private.force_reference ~resolve bad ~live))[nan;infinity;neg_infinity];
  let empty=instantiate(Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (array/nth data index))"[||]in
  calls:=0;assert(ok(P.force ~strict:true ~resolve(packed empty)~live)=E.Int_array[||]);assert(!calls=0);
  (* Structured Core passes changing array arguments to the same compiled region. *)
  let forms=ok(Flow.Syntax.parse
    "(workspace w (graph g :context host [(table : (array int) (array/int 0))] (let* [nested {:table table}] (map (fn [i] (int/add (array/nth nested.table (int/mod i 3)) (frame/index))) (array/range 5001 :type int)))))")in
  let ws=match Flow.Workspace.check Flow.Check.{version=1;kinds=[]}forms with Some ws,[]->ws|_->assert false in
  let value=List.assoc"g"(ok(E.static ~inputs:["g",["table",table]]ws)).results in
  let core=ok(I.Executor.compile ~strict:true value)in
  assert(bytes(ok(I.Executor.force ~strict:true core ~live))=bytes(ok(E.Private.force_reference value ~live)));
  let changing=recorded(Flow.Ty.Array Flow.Ty.Int)
    "(let* [table (array/int 3 (int/add 9007199254740993 (frame/index))) nested {:table table}] (map (fn [i] (array/nth nested.table (int/mod i 3))) (array/range 5001 :type int)))"in
  let program=ok(I.Executor.compile ~strict:true changing)in
  List.iter(fun frame->let live={live with frame;tick=frame}in
    assert(bytes(ok(I.Executor.force ~strict:true program ~live))=
      bytes(ok(E.Private.force_reference changing ~live))))[0;42;9007199254740993];
  let residual=match changing with E.Residual r->r|_->assert false in
  let template=Option.get(P.compile_template residual(E.Private.residual_view residual).term)in
  let rebound=Option.get(P.rebind template residual)in
  assert(bytes(ok(P.force ~strict:true rebound ~live))=bytes(ok(E.Private.force_reference changing ~live)));
  (* An unsupported captured producer must never hide a tree-walker fallback. *)
  let value=recorded(Flow.Ty.Array Flow.Ty.Float)
    "(let* [table (map (fn [x] (value/rand x t)) (array/range 7))] (map (fn [i] (array/nth table i)) (array/range 7 :type int)))"in
  let p=packed value in
  (match P.force ~strict:true p ~live with Error d->
     assert(d.code="E_KERNEL_FORM" && d.message="Numeric node bodies must compile to packed kernels.")
   |Ok _->failwith "Unsupported table producer used reference evaluation");
  let borrowed=recorded(Flow.Ty.Array Flow.Ty.Float)
    "(map (fn [x] (array/nth data (int/mod (int x) 3))) (array/range 32769))"in
  let storage=Array.init(2*32769+1)(fun i->if i>=2 && i mod 2=0 then float((i-2)/2)else nan)in
  let original=bytes storage and output=Array.make 32769 0. in
  let resolve _=Ok(E.Float_array[|-0.;0.;0.25|])in
  ignore(ok(P.force_into ~strict:true ~resolve ~column_source:(fun _ _->Ok(Some[|P.{data=storage;offset=2;stride=2}|]))
    ~count:32769 ~outputs:[|[|Some output|]|](packed borrowed)~live));
  assert(bytes storage=original);
  assert(bytes(E.Float_array output)=bytes(ok(E.Private.force_reference ~resolve borrowed ~live)));
  let fold=recorded(Flow.Ty.Array Flow.Ty.Int)"(state [a 0] (int/add a 1))"in
  let bad=instantiate(Flow.Ty.Array Flow.Ty.Int)
    "(fn [(index : int)] (array/nth data index))"[|-1|]in
  List.iter(fun domains->Rays_math.Parallel.run ~domains(fun()->
    let state=E.create_state()and reference=E.create_state()in
    let before=E.state_stamp state in
    let resolve state _=ignore(ok(E.Private.force_reference ~state fold ~live));Ok table in
    same_error(P.force ~strict:true ~state ~resolve:(resolve state)(packed bad)~live)
      (E.Private.force_reference ~state:reference ~resolve:(resolve reference)bad ~live);
    assert(E.state_stamp state=before && E.state_stamp reference=before)))[1;8];
  print_endline "Numeric gather: independent tables, exact Int/vector bytes, lazy preparation, first-error order and one/four/eight domains pass"

let ()=if Array.exists((=)"--bench")Sys.argv then begin
  let count=1_000_000 and indices=Array.init 1_000_000 Fun.id in
  Printf.printf "Numeric gather: OCaml %s, direct strict Packed, block1024/chunk16384, million rows, median3; allocations observe the initial domain only\n%!"Sys.ocaml_version;
  List.iter(fun ty->let table=array ty 1021 in
    let value=instantiate ~table(Flow.Ty.Array ty)
      "(fn [(index : int)] (array/nth data (int/mod index 1021)))"indices in
    let p=packed value and width=Option.get(Flow.Packed_ops.scalar_width ty)in
    let native()=match table with
      |E.Int_array data->E.Int_array(Array.init count(fun i->data.(i mod 1021)))
      |_->let data=match table with E.Float_array a|Vec2_array a|Vec3_array a|Vec4_array a->a|_->assert false in
        let output=Array.make(count*width)0. in
        for i=0 to count-1 do Array.blit data (i mod 1021*width) output(i*width)width done;
        match width with 1->E.Float_array output|2->Vec2_array output|3->Vec3_array output|_->Vec4_array output in
    let measure f=let samples=Array.init 3(fun _->Gc.full_major();let before=Gc.allocated_bytes()and started=Unix.gettimeofday()in
      ignore(f());Unix.gettimeofday()-.started,Gc.allocated_bytes()-.before)in
      Array.sort(fun(a,_)(b,_)->Float.compare a b)samples;samples.(1)in
    List.iter(fun domains->Rays_math.Parallel.run ~domains(fun()->
      let run()=ok(P.force ~strict:true p ~live:(Frame_input.at_time 0.25))in
      assert(bytes(run())=bytes(native()));
      let nt,nb=measure native and pt,pb=measure run in
      Printf.printf "%s domains%d native %.6f/%.0fB packed %.6f/%.0fB ratio %.3f\n%!"
        (Flow.Ty.to_string ty)domains nt nb pt pb(pt/.nt)))[1;4])
    [Flow.Ty.Int;Float;Vec2;Vec3;Vec4]
end
