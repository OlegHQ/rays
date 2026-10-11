open Rays

let run () =
  let live_handles=snd (Ogpu.Impl.create_driver ()) in
  let baseline=live_handles () in
  let plain=ref [] and packed=Ink.create () in
  let add node=plain:=node::!plain in
  for i=0 to 400 do
    let x=i*7 mod 119-4 and y=i*13 mod 121-4 in
    let color=if i mod 3=0 then Color.rgba 200 170 110 130
      else Color.rgb (i mod 255) 160 210 in
    Ink.rect packed x y 5 7 color;
    add (Scene.rect ~at:(x,y) ~w:5 ~h:7 ~fill:color ());
  done;
  let batch=Option.get (Ink.take packed) in
  let clipped=Ink.create ~ids:[|777L;778L|] ~version:2L ~clip:(3,5,112,107) () in
  Ink.rect clipped 0 0 128 128 Color.white;
  let clipped_batch=Option.get (Ink.take clipped) in
  let unclipped=Ink.create ~ids:[|777L;778L|] ~version:3L () in
  Ink.rect unclipped 0 0 128 128 Color.white;
  let unclipped_batch=Option.get (Ink.take unclipped) in
  let canvas=Canvas.create_exn ~width:128 ~height:128 in
  Fun.protect ~finally:(fun () -> Canvas.destroy canvas) (fun () ->
    let clip nodes=Scene.clip ~at:(3,5) ~w:112 ~h:107 nodes in
    Canvas.render canvas [Scene.clear Color.black;clip (List.rev !plain)];
    let expected=Canvas.pixels canvas in
    for _=1 to 4 do
      Canvas.render canvas [Scene.clear Color.black;clip [batch]];
      if Canvas.pixels canvas<>expected then failwith "packed painter order/pixel drift"
    done;
    Canvas.render canvas [Scene.clear Color.black;clipped_batch];
    if Canvas.pixel canvas ~x:0 ~y:0<>Some Color.black ||
       Canvas.pixel canvas ~x:3 ~y:5<>Some Color.white then failwith "internal segment clip";
    Canvas.render canvas [Scene.clear Color.black;unclipped_batch];
    if Canvas.pixel canvas ~x:0 ~y:0<>Some Color.white then failwith "segment clip reset");
  let after=live_handles () in
  if after<>baseline then failwith "ink native handle delta";
  print_endline "ink: exact native pixels vs Scene rect, alpha/order/clip, zero handle delta"
