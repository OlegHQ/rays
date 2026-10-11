open Rays
module M = Scene_command.Marks
module B = Scene_command.Shape_batch.Builder
module V = Flow.Value

let color (c : int32) =
  let channel shift = Int32.(to_int (logand (shift_right_logical c shift) 0xffl)) in
  Color.rgba (channel 24) (channel 16) (channel 8) (channel 0)
let rgba (c : Color.t) = (Int32.of_int ((c.r lsl 24) lor (c.g lsl 16) lor (c.b lsl 8) lor c.a))

(* An attribute as a function of the instance index; a buffer is looked up once. *)
let data buffers (b : M.buffer) = Flow_ir.Core_exec.Buffers.find buffers b.id
let pairs buffers = function
  | M.Constant p -> fun _ -> p
  | Buffer b -> let d = data buffers b in fun i -> d.(b.width * i), d.(b.width * i + 1)
let floats buffers = function
  | M.Constant x -> fun _ -> x
  | Buffer b -> let d = data buffers b in fun i -> d.(i)
let colours buffers = function
  | M.Constant c -> fun _ -> c
  | Buffer b -> let d = data buffers b in
      fun i -> rgba (Flow_ir.Operators.drawing_color (V.Vec3 (d.(3*i), d.(3*i+1), d.(3*i+2))))

let int_coordinate x =
  if not (Float.is_finite x) || x >= float max_int || x < float min_int
  then V.fail "E_DRAW_RANGE" "A drawing coordinate must fit an integer." else int_of_float x

let shapes buffers count (kind : M.kind) =
  let b = B.create ~capacity:count () in
  (match kind with
   | Rect {position; size; fill; stroke; _} ->
       let position = pairs buffers position and size = pairs buffers size
       and fill = colours buffers fill and stroke = colours buffers stroke in
       for i = 0 to count - 1 do
         let x, y = position i and width, height = size i in
         B.rect b ~x ~y ~width ~height ~fill:(fill i) ~stroke:(stroke i) ()
       done
   | Circle {position; radius; fill; stroke; stroke_width} ->
       let position = pairs buffers position and radius = floats buffers radius
       and fill = colours buffers fill and stroke = colours buffers stroke
       and stroke_width = floats buffers stroke_width in
       for i = 0 to count - 1 do
         let x, y = position i in
         B.circle b ~x ~y ~radius:(radius i) ~fill:(fill i) ~stroke:(stroke i) ~stroke_width:(stroke_width i) ()
       done
   | Line {position; end_; stroke; stroke_width} ->
       let position = pairs buffers position and end_ = pairs buffers end_
       and color = colours buffers stroke and width = floats buffers stroke_width in
       for i = 0 to count - 1 do
         let x0, y0 = position i and x1, y1 = end_ i in
         B.line b ~x0 ~y0 ~x1 ~y1 ~color:(color i) ~width:(width i)
       done
   | Point _ -> assert false);
  Scene.Private.shapes (B.publish b)

(* Points truncate to integers and merge by colour in Ink, as draw/points always did. *)
let points buffers count position fill =
  let position = pairs buffers position and ink = color fill in
  let batch = Ink.create () in
  for i = 0 to count - 1 do
    let x, y = position i in
    Ink.rect batch (int_coordinate x) (int_coordinate y) 1 1 ink
  done;
  Ink.take batch

let scene ~buffers ?image marks =
  let fail code message = Error (Flow.Diagnostic.error ~code message) in
  match M.validate marks with
  | Error message -> fail "E_DRAW_RANGE" message
  | Ok () ->
      (* Open pushes, innermost first, each with the nodes drawn inside it, newest first. *)
      let stack = ref [] and top = ref [] in
      let add node = top := node :: !top in
      let open_ close = stack := (close, !top) :: !stack; top := [] in
      let close () = match !stack with
        | (wrap, outer) :: rest -> stack := rest; top := wrap (List.rev !top) :: outer
        | [] -> assert false in
      let integer x = int_coordinate x in
      try
        Array.iter (function
          | M.Mark_set {count; kind = Point {position; fill}} ->
              Option.iter add (points buffers count position fill)
          | Mark_set {count; kind} -> add (shapes buffers count kind)
          | Geometry {vertices; indices; color} -> add (Scene.Private.geometry {vertices; indices; color})
          | Image {resource; x; y; scale; angle} ->
              (match image with
               | Some resolve -> add (Scene.image (resolve resource) ~at:(x, y) ~scale ~angle ())
               | None -> V.fail "E_IMAGE" "Drawing images need an environment-owned image resolver.")
          | Text {x; y; size; color = c; text} -> add (Scene.text ~at:(x, y) ~color:(color c) ~size text)
          | Push_transform {xx; xy; yx; yy; tx; ty} ->
              open_ (Scene.Private.transform {Scene_command.Render_ir.xx; xy; yx; yy; tx; ty})
          | Push_clip {x; y; width; height} ->
              let x = integer x and y = integer y and w = integer width and h = integer height in
              open_ (Scene.clip ~at:(x, y) ~w ~h)
          | Pop_transform | Pop_clip -> close ()) marks;
        Ok (List.rev !top)
      with V.Fail (code, message, span) -> Error (Flow.Diagnostic.error ?span ~code message)
         | Invalid_argument message | Failure message -> fail "E_DRAW_RANGE" message
