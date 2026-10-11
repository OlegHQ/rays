module B=Ogpu.Backend
module C=Rays_execution.Private.Gpu_circles
let get=function Ok value->value|Error error->failwith(Format.asprintf"%a"Rays_execution.pp_error error)
let native_get=function Ok value->value|Error error->failwith(Ogpu.Error.to_string error)
let ()=
  let live=snd(Ogpu.Impl.create_driver())in
  let baseline=live()in
  List.iter(fun density->
    let execution=get(Rays_execution.create_offscreen{Rays_execution.
      logical_width=32;logical_height=24;drawable_width=32*density;drawable_height=24*density;
      title="GPU drawing parity";vsync=false;high_density=true})in
    let gpu=get(Rays_execution.acquire_gpu())in
    let sink=get(Rays_execution.Private.create_gpu_circles gpu)in
    let positions=native_get(B.create_buffer(Rays_execution.gpu_device gpu)
      {label=Some"GPU parity points";size=24L;usage=[Storage;Copy_dst]})in
    Fun.protect~finally:(fun()->Rays_execution.Private.close_gpu_circles sink;
      ignore(B.destroy_buffer positions);Rays_execution.release_gpu gpu;
      ignore(get(Rays_execution.destroy execution)))(fun()->
      let points=[|8.;8.;0.;20.;14.;0.|]and bytes=Bytes.create 24 in
      Array.iteri(fun index value->Bytes.set_int32_le bytes(index*4)(Int32.bits_of_float value))points;
      native_get(B.write_buffer positions~offset:0L bytes);
      let generation=ref 1 in
      let source stamp()=if !generation=stamp then Some positions else None in
      let conversion=native_get(C.create~device:(Rays_execution.gpu_device gpu)
        ~queue:(Rays_execution.gpu_queue gpu))in
      let expected=Fun.protect~finally:(fun()->C.close conversion)(fun()->
        let converted=native_get(C.dispatch conversion~source:positions~count:2~radius:2.5
          ~fill:0x12345678l~stroke:0xff00ff80l~stroke_width:3.)in
        let expected=Scene_command.Shape_batch.Builder.create()in
        for index=0 to 1 do Scene_command.Shape_batch.Builder.circle expected
          ~x:points.(index*3)~y:points.(index*3+1)~radius:2.5
          ~fill:0x12345678l~stroke:0xff00ff80l~stroke_width:3.()done;
        let expected=Scene_command.Shape_batch.Builder.publish expected in
        assert(native_get(B.read_buffer converted~offset:0L~length:128)=
          Scene_command.Shape_batch.instances expected);
        List.iter(fun(x,radius)->
          let bad=Bytes.copy bytes in Bytes.set_int32_le bad 0(Int32.bits_of_float x);
          native_get(B.write_buffer positions~offset:0L bad);
          match C.dispatch conversion~source:positions~count:2~radius
            ~fill:(-1l)~stroke:0l~stroke_width:1. with
          |Error{Ogpu.Error.kind=Invalid_argument;_}->()
          |_->failwith"GPU circle conversion accepted nonfinite expanded bounds")
          [infinity,1.;3.0e38,3.0e38];
        native_get(B.write_buffer positions~offset:0L bytes);expected)in
      let old=get(Rays_execution.Private.gpu_circles sink~source:(source !generation)
        ~count:2~radius:2.5~fill:0x12345678l~stroke:0xff00ff80l~stroke_width:3.)in
      let ir blend shapes=Result.get_ok(Scene_command.Render_ir.create
        Scene_command.Render_ir.[|Set_blend blend;
          Push_clip{x=2.;y=3.;width=25.;height=17.};
          Push_transform{xx=0.875;xy=(-0.2);yx=0.15;yy=1.125;tx=0.375;ty=0.125};
          Shapes shapes;Pop_transform;Pop_clip|])in
      let clear=0.125,0.25,0.375,1. in
      let capture ?identity ?version ir=
        let submission=get(Rays_execution.Private.begin_submission execution)in
        Fun.protect~finally:(fun()->Rays_execution.Private.cancel submission)(fun()->
          let batch=get(Rays_execution.Private.lower_scene2 submission~density
            ~resource:(fun _->None)ir)in
          get(Rays_execution.Private.step~clear ?identity ?version submission[batch]);
          let pixels=get(Rays_execution.capture execution)in
          assert(Bytes.length pixels=32*24*density*density*4);pixels)in
      let shapes=Scene_command.Shape_batch.Private.of_gpu old in
      List.iter(fun blend->
        let reference=capture(ir blend expected)in
        if blend=Scene_command.Render_ir.Replace then
          assert(Bytes.sub reference 0 4<>
            Bytes.sub reference((10*density*32*density+6*density)*4)4);
        for _=1 to 3 do assert(capture(ir blend shapes)=reference)done)
        Scene_command.Render_ir.[Replace;Alpha;Add;Multiply;Screen;Subtract];
      let stamp=Scene_command.Shape_batch.Private.gpu_stamp in
      let retained token=capture~identity:"gpu-circles"~version:(stamp token)
        (ir Replace(Scene_command.Shape_batch.Private.of_gpu token))in
      ignore(retained old);
      assert(get(Rays_execution.Private.replay~clear~identity:"gpu-circles"
        ~version:(stamp old) execution)=Some());
      let refuse_replay token=match Rays_execution.Private.replay~clear
        ~identity:"gpu-circles"~version:(stamp token) execution with
        |Error error when error.Rays_execution.kind=Backend&&error.message=
          Ogpu.Error.to_string(Ogpu.Error.make"Scene_execution.replay"Stale_handle
            "GPU vertices are stale or closed")->()
        |_->failwith"retained GPU circle replay accepted a stale source"in
      let refuse_lower token=
        let submission=get(Rays_execution.Private.begin_submission execution)in
        Fun.protect~finally:(fun()->Rays_execution.Private.cancel submission)(fun()->
          match Rays_execution.Private.lower_scene2 submission~density
            ~resource:(fun _->None)(ir Replace(Scene_command.Shape_batch.Private.of_gpu token))with
          |Error error when error.Rays_execution.kind=Resource&&
            error.message="GPU shapes are stale or closed"->()
          |_->failwith"GPU circle lowering accepted a stale token")in
      incr generation;
      refuse_replay old;refuse_lower old;
      let fresh=get(Rays_execution.Private.gpu_circles sink~source:(source !generation)
        ~count:2~radius:2.5~fill:0x12345678l~stroke:0xff00ff80l~stroke_width:3.)in
      assert(Scene_command.Shape_batch.Private.gpu_stamp old<Scene_command.Shape_batch.Private.gpu_stamp fresh);
      let reference=capture(ir Replace expected)in
      assert(retained fresh=reference);
      Rays_execution.release_gpu gpu;
      refuse_replay fresh;refuse_lower fresh;
      assert(Scene_execution.Private.gpu_vertex_count_for_test()=0)))
    [1;2];
  assert(live()=baseline);
  print_endline"GPU circles: exact native parity under transform, clip, six blends, Retina and stale output/lease guards"
