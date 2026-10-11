(* Word accessors are top-level and inline: a local closure returning a float boxes it, which is
   an allocation per field per instance on a batch of a million. *)
let[@inline] word_float bytes at = Int32.float_of_bits (Bytes.get_int32_le bytes at)
let[@inline] set_float bytes at value = Bytes.set_int32_le bytes at (Int32.bits_of_float value)
let[@inline] finite_coordinate value = Float.is_finite value && abs_float value <= 3.4028234663852886e38
type gpu_token = { identity:int; count:int; stamp:int64 }
(* [checked] remembers that [valid] passed: a published batch is immutable, so a scene that holds the
   same batch again (a moved transform over unchanged marks) does not scan every instance again. *)
type t = { bytes:bytes; count:int; gpu:gpu_token option; mutable checked:bool }
let instance_bytes = 64
let count value = value.count
let instances value = value.bytes
let gpu value = value.gpu
module Private = struct
  let copy value = {value with bytes=Bytes.copy value.bytes}
  let valid value =
    match value.gpu with
    |Some token->value.count=token.count && Bytes.length value.bytes=0
    |None->
        value.checked ||
        Bytes.length value.bytes=value.count*instance_bytes &&
        let rec loop i = i=value.count ||
          let base=i*instance_bytes in
          let kind=Bytes.get_int32_le value.bytes (i*instance_bytes+40)in
          (kind=0l || kind=4l || kind=5l) &&
          Float.is_finite(word_float value.bytes (base+4*0)) && Float.is_finite(word_float value.bytes (base+4*1)) &&
          Float.is_finite(word_float value.bytes (base+4*2)) && Float.is_finite(word_float value.bytes (base+4*3)) &&
          Float.is_finite(word_float value.bytes (base+4*11)) && word_float value.bytes (base+4*11)>=0. &&
          Float.is_finite(word_float value.bytes (base+4*12)) && word_float value.bytes (base+4*12)>=0. &&
          Float.is_finite(word_float value.bytes (base+4*13)) && word_float value.bytes (base+4*13)>=0. &&
          (kind=5l || (word_float value.bytes (base+8)>=word_float value.bytes base && word_float value.bytes (base+12)>=word_float value.bytes (base+4))) && loop(i+1)
        in let ok = loop 0 in if ok then value.checked <- true; ok
  let gpu_token ~identity ~count ~stamp =
    if identity<=0 || count<0 || count>1_000_000 || stamp<0L then
      invalid_arg "Shape_batch.gpu_token: invalid identity, count or stamp";
    {identity; count; stamp}
  let gpu_identity value = value.identity
  let gpu_count (value:gpu_token) = value.count
  let gpu_stamp value = value.stamp
  let of_gpu (gpu:gpu_token) = {bytes=Bytes.empty; count=gpu.count; gpu=Some gpu; checked=false}
end
module Builder = struct
  type batch = t
  type t = { mutable bytes:bytes; mutable count:int }
  let create ?(capacity=256) () =
    if capacity<0 || capacity>1_000_000 then invalid_arg "Shape_batch capacity";
    {bytes=Bytes.create (max 1 capacity * instance_bytes); count=0}
  let append builder kind x0 y0 x1 y1 fill stroke stroke_width =
    if not (finite_coordinate x0 && finite_coordinate y0 && finite_coordinate x1 && finite_coordinate y1
                && finite_coordinate stroke_width)
       || stroke_width<0. then invalid_arg "Shape_batch: invalid coordinates";
    if builder.count>=1_000_000 then invalid_arg "Shape_batch: instance limit";
    let offset=builder.count*instance_bytes in
    if offset+instance_bytes>Bytes.length builder.bytes then begin
      let grown=Bytes.create (min (1_000_000*instance_bytes) (2*Bytes.length builder.bytes)) in
      Bytes.blit builder.bytes 0 grown 0 offset; builder.bytes<-grown
    end;
    Bytes.fill builder.bytes offset instance_bytes '\000';
    let bytes = builder.bytes in
    set_float bytes offset x0; set_float bytes (offset+4) y0; set_float bytes (offset+8) x1; set_float bytes (offset+12) y1;
    Bytes.set_int32_le builder.bytes (offset+32) fill;
    Bytes.set_int32_le builder.bytes (offset+36) stroke;
    Bytes.set_int32_le builder.bytes (offset+40) kind;
    set_float bytes (offset+48) stroke_width; set_float bytes (offset+52) 1.;
    builder.count<-builder.count+1
  let style fill stroke = match fill,stroke with None,None -> -1l,0l
    | _ -> Option.value ~default:0l fill,Option.value ~default:0l stroke
  let circle builder ~x ~y ~radius ?fill ?stroke ?(stroke_width=1.) () =
    if not (Float.is_finite radius) || radius<0. then invalid_arg "Shape_batch radius";
    let fill,stroke=style fill stroke in
    append builder 4l (x-.radius) (y-.radius) (x+.radius) (y+.radius) fill stroke
      (if stroke=0l then 0. else stroke_width)
  let rect builder ~x ~y ~width ~height ?fill ?stroke () =
    if not (Float.is_finite width && Float.is_finite height) || width<0. || height<0.
    then invalid_arg "Shape_batch extent";
    let fill,stroke=style fill stroke in
    append builder 0l x y (x+.width) (y+.height) fill stroke
      (if stroke=0l then 0. else 1.)
  let line builder ~x0 ~y0 ~x1 ~y1 ~color ~width =
    append builder 5l x0 y0 x1 y1 color 0l width
  let publish builder = {bytes=Bytes.sub builder.bytes 0 (builder.count*instance_bytes);
    count=builder.count; gpu=None; checked=false}
end
