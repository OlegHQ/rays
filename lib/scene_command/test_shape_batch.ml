(* A published batch is validated once: a scene that holds the same batch again (a moved transform
   over unchanged marks) must not scan its instances, which allocated about 230 bytes per instance. *)
open Scene_command

let () =
  let n = 20_000 in
  let builder = Shape_batch.Builder.create ~capacity:n () in
  for i = 0 to n - 1 do
    Shape_batch.Builder.circle builder ~x:(float i) ~y:1. ~radius:0.5 ()
  done;
  let batch = Shape_batch.Builder.publish builder in
  let scene dx = [| Render_ir.Push_transform {xx = 1.; xy = 0.; yx = 0.; yy = 1.; tx = dx; ty = 0.};
    Render_ir.Shapes batch; Render_ir.Pop_transform |] in
  let create dx = match Render_ir.Private.create_owned (scene dx) with
    | Ok _ -> () | Error _ -> assert false in
  create 0.;
  let before = Gc.allocated_bytes () in
  for i = 1 to 10 do create (float i) done;
  let per_scene = (Gc.allocated_bytes () -. before) /. 10. in
  assert (per_scene < 4096.);
  (* a tampered copy is still refused: the mark belongs to the batch that passed, not to its bytes *)
  let bad = Shape_batch.Private.copy (Shape_batch.Builder.publish builder) in
  Bytes.set_int32_le (Shape_batch.instances bad) 0 0x7fc00000l;
  assert (not (Shape_batch.Private.valid bad));
  print_endline "Shape_batch validation is remembered per published batch"
