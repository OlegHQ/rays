module E = Flow.Eval
module C = Core

(* The lowering rules of the draw operators. A rule names the inputs it needs, supplies the
   defaults (white ink and fill, width 1) and writes statements; every check of a value is the
   executor's. *)
let white = E.Vec3 (1., 1., 1.)

exception Missing of string
exception Refused of string

let rec find_residual : E.value -> E.residual option = function
  | E.Residual r -> Some r
  | List xs -> Array.find_map find_residual xs
  | Record fields | Struct (_, _, fields) -> List.find_map (fun (_, v) -> find_residual v) fields
  | _ -> None

let lower (plan : E.plan) (value : E.value) =
  let root = find_residual value |> function
    | Some r -> Some r
    | None -> Array.find_map (fun (n : E.node) -> List.find_map (fun (_, v) -> find_residual v) n.args) plan.nodes in
  let build (ctx : Core_lower.draw_context) =
    let none : C.source = {site = []; owner = []; instance = 0; prefix = []; iter = []; span = None} in
    let fail source code message =
      let n = ctx.local Flow.Ty.Any in
      ctx.emit source (C.Assign (n, Prim (Fail (code, message), []))) in
    let rec drawing = function
      | E.List xs -> Array.iter drawing xs
      | E.Deferred (Flow.Ty.Named "drawing", id) when id >= 0 && id < Array.length plan.nodes -> node plan.nodes.(id)
      | E.Residual _ -> raise (Refused "draw_dynamic")
      | _ -> fail none "E_TYPE" "The canvas needs a Drawing value."
    and node (n : E.node) =
      let source : C.source = {site = n.site; owner = n.site; instance = n.inst; prefix = [];
        iter = List.map (fun i -> C.Static_index i) n.iter; span = None} in
      if n.ty <> Flow.Ty.drawing then fail source "E_TYPE" "The canvas needs a Drawing node." else
      (* The data inputs, in written order, as drawing.ml forces them. *)
      let data = match n.kind with
        | "draw/merge" -> []
        | "draw/translate" | "draw/rotate" | "draw/scale" -> List.filter (fun (k, _) -> k <> "drawing") n.args
        | "draw/image" -> List.filter (fun (k, _) -> k <> "image") n.args
        | _ -> n.args in
      let locals = List.map (fun (k, v) -> k, ctx.value source v) data in
      let need key = match List.assoc_opt key locals with
        | Some n -> n | None -> raise (Missing (Printf.sprintf "%s needs %s." n.kind key)) in
      let optional key = List.assoc_opt key locals in
      let default key v = match optional key with Some n -> n | None -> ctx.value source v in
      let emit d = ctx.emit source (C.Draw d) in
      let style () =
        let fill = optional "fill" and stroke = optional "stroke" in
        let fill = if fill = None && stroke = None then Some (ctx.value source white) else fill in
        List.filter_map (fun (k, v) -> Option.map (fun n -> k, n) v) ["fill", fill; "stroke", stroke] in
      let push transform key =
        let operand = need key in
        emit (C.Push (transform, operand));
        (match List.assoc_opt "drawing" n.args with
         | Some v -> drawing v
         | None -> raise (Missing (Printf.sprintf "%s needs drawing." n.kind)));
        emit C.Pop in
      try match n.kind with
        | "draw/background" -> emit (Background (need "color"))
        | "draw/point" ->
            let at = need "at" in emit (Point {at; ink = default "color" white})
        | "draw/rect" ->
            let at = need "at" in let size = need "size" in
            emit (Mark {mark = Rect; args = ["at", at; "size", size] @ style ()})
        | "draw/circle" ->
            let at = need "at" in let radius = need "radius" in
            emit (Mark {mark = Circle; args = ["at", at; "radius", radius] @ style ()})
        | "draw/line" ->
            let from = need "from" in let dest = need "to" in
            emit (Mark {mark = Line; args = ["from", from; "to", dest;
              "color", default "color" white; "width", default "width" (E.Float 1.)]})
        | "draw/circles" ->
            let positions = need "positions" in
            emit (Batch {mark = Circle; args = ["positions", positions;
              "radius", default "radius" (E.Float 1.)] @ style ()})
        | "draw/rects" ->
            let positions = need "positions" in let sizes = need "sizes" in
            emit (Batch {mark = Rect; args = ["positions", positions; "sizes", sizes] @ style ()})
        | "draw/lines" ->
            let from = need "from" in let dest = need "to" in
            emit (Batch {mark = Line; args = ["from", from; "to", dest;
              "color", default "color" white; "width", default "width" (E.Float 1.)]})
        | "draw/points" ->
            let positions = need "positions" in emit (Points {positions; ink = default "color" white})
        | "draw/text" ->
            let at = need "at" in let text = need "text" in
            emit (Text_run {at; text; ink = default "color" white; size = default "size" (E.Int 16)})
        | "draw/image" ->
            let source = match List.assoc_opt "image" n.args with
              | Some (E.Deferred (ty, id)) -> ty, id
              | Some _ -> raise (Refused "draw_image")
              | None -> raise (Missing (Printf.sprintf "%s needs image." n.kind)) in
            emit (Image {source; at = default "at" (E.Vec3 (0., 0., 0.));
              scale = default "scale" (E.Float 1.); angle = default "angle" (E.Float 0.)})
        | "draw/rounded_rect" ->
            let at = need "at" in let size = need "size" in
            emit (Path {path = Rounded_rect; args = ["at", at; "size", size;
              "radius", default "radius" (E.Int 0)] @ style ()})
        | "draw/polygon" ->
            let points = need "points" in emit (Path {path = Polygon; args = ["points", points] @ style ()})
        | "draw/polyline" ->
            let points = need "points" in
            emit (Path {path = Polyline; args = ["points", points; "color", default "color" white]})
        | "draw/translate" -> push C.Translate "offset"
        | "draw/rotate" -> push C.Rotate "angle"
        | "draw/scale" -> push C.Scale "factor"
        | "draw/merge" -> List.iter (fun (_, v) -> drawing v) n.args
        | kind -> fail source "E_DRAW_KIND" (Printf.sprintf "No native drawing implementation for %s." kind)
      with Missing message -> fail source "E_DRAW_INPUT" message in
    drawing value in
  match Core_lower.lower_draw ~root:(lazy (Option.get root)) build with
  | Ok program -> Ok (program, root)
  | Error name -> Error name
  | exception Refused name -> Error name
