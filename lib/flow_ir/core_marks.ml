module C = Core
module V = Flow.Value
module E = Flow.Eval
module M = Scene_command.Marks

module Buffers = struct
  type t = { mutable next : int; table : (int, float array) Hashtbl.t }
  let create () = { next = 1; table = Hashtbl.create 8 }
  let clear t = t.next <- 1; Hashtbl.reset t.table
  let find t id = Hashtbl.find t.table id
  let add t data = let id = t.next in t.next <- id + 1; Hashtbl.replace t.table id data; id
end

type sink = { buffers : Buffers.t; size : int * int; image : (E.value -> int) option;
  mutable entries : M.entry list; mutable length : int }

let sink ?image ~size buffers = { buffers; size; image; entries = []; length = 0 }

let push sink entry =
  if sink.length >= M.max_entries then V.fail "E_DRAW_RANGE" "A drawing has too many entries.";
  sink.entries <- entry :: sink.entries; sink.length <- sink.length + 1

let finish sink =
  let marks = Array.of_list (List.rev sink.entries) in
  match M.validate marks with
  | Ok () -> marks
  | Error message -> V.fail "E_DRAW_RANGE" message

(* The conversions below are drawing.ml's, rule for rule. *)
let color = Operators.drawing_color
let rgba (c : Rays_math.Color.t) = Int32.of_int ((c.r lsl 24) lor (c.g lsl 16) lor (c.b lsl 8) lor c.a)
let white = 0xffffffffl
let ink v = match v with E.Vec3_array _ -> white | v -> rgba (color v)
let point v =
  let x, y, _ = V.comps v in
  let int x = if not (Float.is_finite x) || x >= float max_int || x < float min_int
    then V.fail "E_DRAW_RANGE" "A drawing coordinate must fit an integer." else int_of_float x in
  int x, int y
let pair v = let x, y, _ = V.comps v in x, y

let geometry sink (geometries : Scene_command.Render_ir.geometry array) =
  Array.iter (fun (g : Scene_command.Render_ir.geometry) ->
    push sink (M.Geometry {vertices = g.vertices; indices = g.indices; color = g.color})) geometries

let colors_length () = V.fail "E_DRAW_LENGTH" "Colors and positions have different lengths."
(* A packed colour array is per instance; anything else one constant. *)
let colour_attr sink count v : int32 M.attr = match v with
  | E.Vec3_array xs ->
      if Array.length xs <> 3 * count then colors_length ();
      Buffer {id = Buffers.add sink.buffers xs; count; width = 3}
  | v -> Constant (rgba (color v))
let check_colors count args = List.iter (fun key -> match List.assoc_opt key args with
  | Some (E.Vec3_array xs) when Array.length xs <> 3 * count -> colors_length ()
  | _ -> ()) ["fill"; "stroke"; "color"]

(* Packed positions keep their storage; any other array is read into pairs. *)
let points_attr sink v : int * (float * float) M.attr =
  let buffer n width data = n, M.Buffer {id = Buffers.add sink.buffers data; count = n; width} in
  match v with
  | E.Vec3_array xs -> buffer (Array.length xs / 3) 3 xs
  | Vec2_array xs -> buffer (Array.length xs / 2) 2 xs
  | _ ->
      let n = V.array_length v in
      let data = Array.make (2 * n) 0. in
      for i = 0 to n - 1 do let x, y = pair (V.array_get v i) in data.(2*i) <- x; data.(2*i+1) <- y done;
      buffer n 2 data

let one v : (float * float) M.attr = Constant (pair v)

let mark sink ~batch kind args (values : E.value array) =
  let args = List.map (fun (k, i) -> k, values.(i)) args in
  let arg key = match List.assoc_opt key args with Some v -> v | None -> V.failf "E_DRAW_INPUT" "draw needs %s." key in
  let style count =
    let get key = match List.assoc_opt key args with Some v -> colour_attr sink count v | None -> M.Constant 0l in
    get "fill", get "stroke" in
  let n_of_positions key = if batch then points_attr sink (arg key) else 1, one (arg key) in
  match kind with
  | C.Circle ->
      let n, position = n_of_positions (if batch then "positions" else "at") in
      let radius : float M.attr = if not batch then Constant (V.num (arg "radius")) else
        match arg "radius" with
        | E.Float_array xs ->
            if Array.length xs <> n then V.fail "E_DRAW_LENGTH" "Radii and positions have different lengths.";
            Buffer {id = Buffers.add sink.buffers xs; count = n; width = 1}
        | E.Int _ | Float _ as v -> Constant (V.num v)
        | _ -> V.fail "E_TYPE" "Radius is a number or packed float array." in
      check_colors n args;
      let fill, stroke = style n in
      push sink (M.Mark_set {count = n; kind = M.Circle {position; radius; fill; stroke; stroke_width = Constant 1.}})
  | Rect ->
      let n, position = n_of_positions (if batch then "positions" else "at") in
      let size : (float * float) M.attr = if not batch then one (arg "size") else
        match arg "sizes" with
        | E.Vec3_array xs ->
            if Array.length xs <> 3 * n then V.fail "E_DRAW_LENGTH" "Sizes and positions have different lengths.";
            Buffer {id = Buffers.add sink.buffers xs; count = n; width = 3}
        | E.Vec3 _ as v -> one v
        | _ -> V.fail "E_TYPE" "Sizes are a vec3 or packed vec3 array." in
      check_colors n args;
      let fill, stroke = style n in
      push sink (M.Mark_set {count = n; kind = M.Rect {position; size; fill; stroke; stroke_width = Constant 1.}})
  | Line ->
      let n, position = n_of_positions "from" in
      let end_ = if batch then begin
          let n', end_ = points_attr sink (arg "to") in
          if n' <> n then V.fail "E_DRAW_LENGTH" "Line endpoints have different lengths."; end_
        end else one (arg "to") in
      check_colors n args;
      push sink (M.Mark_set {count = n; kind = M.Line {position; end_;
        stroke = colour_attr sink n (arg "color"); stroke_width = Constant (V.num (arg "width"))}})

let path sink path args (values : E.value array) =
  let args = List.map (fun (k, i) -> k, values.(i)) args in
  let arg key = List.assoc key args in
  let opt key = Option.map (fun v -> rgba (color v)) (List.assoc_opt key args) in
  let points () = let xs = arg "points" in List.init (V.array_length xs) (fun i -> point (V.array_get xs i)) in
  match path with
  | C.Polygon -> let points = points () in
      geometry sink (Scene_command.Shape2.polygon points ~fill:(opt "fill") ~stroke:(opt "stroke"))
  | Polyline -> let points = points () in
      geometry sink [|Scene_command.Shape2.polyline points ~color:(ink (arg "color"))|]
  | Rounded_rect ->
      let width, height = point (arg "size") in
      let x, y = point (arg "at") in
      let radius = max 0 (min (V.int_of (arg "radius")) (min (abs width) (abs height) / 2)) in
      push sink (M.Push_transform {xx = 1.; xy = 0.; yx = 0.; yy = 1.; tx = float x; ty = float y});
      geometry sink (Scene_command.Shape2.rounded_rect ~width ~height ~radius ~fill:(opt "fill") ~stroke:(opt "stroke"));
      push sink M.Pop_transform

let compile : C.draw -> E.value array -> sink -> unit = function
  | C.Background c -> fun v sink ->
      let w, h = sink.size in
      geometry sink (Scene_command.Shape2.polygon [0, 0; w, 0; w, h; 0, h] ~fill:(Some (rgba (color v.(c)))) ~stroke:None)
  | Point {at; ink = i} -> fun v sink ->
      let x, y = point v.(at) in
      geometry sink (Scene_command.Shape2.polygon [x, y; x+1, y; x+1, y+1; x, y+1] ~fill:(Some (ink v.(i))) ~stroke:None)
  | Mark {mark = kind; args} -> fun v sink -> mark sink ~batch:false kind args v
  | Batch {mark = kind; args} -> fun v sink -> mark sink ~batch:true kind args v
  | Points {positions; ink = i} -> fun v sink ->
      let count, position = points_attr sink v.(positions) in
      push sink (M.Mark_set {count; kind = M.Point {position; fill = ink v.(i)}})
  | Path {path = p; args} -> fun v sink -> path sink p args v
  | Text_run {at; text; ink = i; size} -> fun v sink ->
      let text = match v.(text) with E.Text s -> s | _ -> V.fail "E_TYPE" "Drawing text is text." in
      if text <> "" then begin
        let x, y = point v.(at) in
        push sink (M.Text {x; y; size = V.int_of v.(size); color = ink v.(i); text})
      end
  | Image {source = (ty, id); at; scale; angle} -> fun v sink ->
      let resolve = match sink.image with Some resolve -> resolve
        | None -> V.fail "E_IMAGE" "Drawing images need an environment-owned image resolver." in
      let resource = resolve (E.Deferred (ty, id)) in
      let x, y = point v.(at) and scale = V.num v.(scale) and angle = V.num v.(angle) in
      if not (Float.is_finite scale && Float.is_finite angle) || scale <= 0. then
        V.fail "E_DRAW_RANGE" "Scene.image: invalid transform";
      push sink (M.Image {resource; x; y; scale; angle})
  | Push (C.Translate, i) -> fun v sink ->
      let x, y = point v.(i) in
      push sink (M.Push_transform {xx = 1.; xy = 0.; yx = 0.; yy = 1.; tx = float x; ty = float y})
  | Push (Rotate, i) -> fun v sink ->
      let a = V.fin "angle" (V.num v.(i)) in
      let c = cos a and s = sin a in
      push sink (M.Push_transform {xx = c; xy = s; yx = -.s; yy = c; tx = 0.; ty = 0.})
  | Push (Scale, i) -> fun v sink ->
      let x, y = match v.(i) with E.Vec3 (x, y, _) -> x, y | v -> let n = V.num v in n, n in
      let x = V.fin "scale" x and y = V.fin "scale" y in
      push sink (M.Push_transform {xx = x; xy = 0.; yx = 0.; yy = y; tx = 0.; ty = 0.})
  | Pop -> fun _ sink -> push sink M.Pop_transform
