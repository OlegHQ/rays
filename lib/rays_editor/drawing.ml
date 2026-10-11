open Rays
module E = Flow.Eval
module V = Flow.Value
module I = Flow_ir.Executor
module C = Flow_ir.Core_exec

type prepared = {plan : E.plan; value : I.program; states : I.program; args : (string*I.program)list array;
  core : (C.prepared * E.residual option * C.Buffers.t, Flow.Diagnostic.t) result Lazy.t; whole : bool; circles : bool;
  mutable kept : ((int*int)*Scene.t) option}
let prepare ?profile ?(approx=Flow.Workspace.Paths.empty) ?(states = []) plan value =
  let ( let* ) = Result.bind in
  let root = value in
  let* value = I.compile ?profile value in
  let* states = I.compile ?profile (E.List (Array.of_list states)) in
  let args = Array.map (fun (node : E.node) ->
    List.fold_right(fun(name,value)result->let* rest=result in
      let* program=I.compile ?profile ~approx ~sink:(Flow_ir.Display node.kind) value in
      Ok((name,program)::rest))node.args(Ok[])) plan.E.nodes in
  match Array.find_opt Result.is_error args with
  | Some (Error d) -> Error d
  | _ ->
      let known=Array.make(Array.length plan.nodes)None in
      let rec static = function
        |E.Deferred(Flow.Ty.Named "drawing",id)->node id
        |E.Deferred _->false
        |E.List values->Array.for_all static values
        |E.Record fields|E.Struct(_,_,fields)->List.for_all(fun(_,value)->static value)fields
        |value->not(E.is_live value)
      and node id=match known.(id)with
        |Some value->value
        |None->known.(id)<-Some false;
            let value=List.for_all(fun(_,value)->static value)plan.nodes.(id).args in
            known.(id)<-Some value;value in
      Ok {plan; value; states; args = Array.map Result.get_ok args;
        core=lazy(match Flow_ir.Core_draw.lower plan root with
          |Ok(program,residual)->Ok(C.prepare program,residual,C.Buffers.create())
          |Error name->Error(Flow.Diagnostic.error ~code:"E_DRAW_KIND" (Printf.sprintf "The drawing cannot be lowered to the core path (%s)." name)));
        whole=static root; kept=None;
        circles=Array.exists(fun(node:E.node)->node.kind="draw/circles")plan.nodes}

(* The GPU circles path: a [draw/circles] whose positions are a GPU region output becomes the backend's
   token (the mark table has no GPU attribute until P4.9). It understands only lists, [draw/merge],
   [draw/background] and such circles; anything else asks for the core path with [fallback_code], and
   the transaction rolls the fold states back. *)
let fallback_code = "E_GPU_FALLBACK"

let render_gpu ~state ~gpu ~gpu_policy prepared ~live ~size:(width, height) =
  let plan = prepared.plan in
  E.transaction state (fun () ->
    let exception Stop of Flow.Diagnostic.t in
    let force program = match I.force ~state program ~live with Ok v -> v | Error d -> raise (Stop d) in
    let fallback () = raise (Stop (Flow.Diagnostic.error ~code:fallback_code "")) in
    let rgba value = let c = Flow_ir.Operators.drawing_color value in
      Int32.of_int ((c.r lsl 24) lor (c.g lsl 16) lor (c.b lsl 8) lor c.a) in
    let rec drawing = function
      | E.List values -> Array.to_list values |> List.concat_map drawing
      | E.Deferred (Flow.Ty.Named "drawing", id) when id >= 0 && id < Array.length plan.nodes ->
          let args = prepared.args.(id) in
          (match plan.nodes.(id).kind with
           | "draw/merge" -> List.concat_map (fun (_, program) -> drawing (force program)) args
           | "draw/background" -> (match List.assoc_opt "color" args with
               | None -> fallback ()
               | Some program -> [Scene.rect ~at:(0, 0) ~w:width ~h:height
                   ~fill:(Flow_ir.Operators.drawing_color (force program)) ()])
           | "draw/circles" ->
               let others = List.filter (fun (name, _) -> name <> "positions") args
                 |> List.map (fun (name, program) -> name, force program) in
               if not (List.for_all (fun key -> match List.assoc_opt key others with
                   | Some (E.Float_array _ | E.Vec3_array _ | E.List _) -> false | _ -> true)
                   ["radius"; "fill"; "stroke"]) then fallback ();
               (match List.assoc_opt "positions" args with
                | None -> fallback ()
                | Some program ->
                    match I.force_display ~state ~policy:gpu_policy program ~live with
                    | Error d -> raise (Stop d)
                    | Ok (I.Cpu _) -> fallback ()
                    | Ok (I.Gpu output) ->
                        if output.Flow_ir.Gpu.width <> 3 then V.fail "E_GPU" "Drawing circles need a width-three GPU array.";
                        let radius = match List.assoc_opt "radius" others with Some v -> V.num v | None -> 1. in
                        let colour key = Option.map rgba (List.assoc_opt key others) in
                        let fill, stroke = match colour "fill", colour "stroke" with
                          | None, None -> 0xffffffffl, 0l
                          | fill, stroke -> Option.value fill ~default:0l, Option.value stroke ~default:0l in
                        match gpu output ~radius ~fill ~stroke ~stroke_width:(if stroke = 0l then 0. else 1.) with
                        | Ok token -> [Scene.Private.shapes (Scene_command.Shape_batch.Private.of_gpu token)]
                        | Error d -> raise (Stop d))
           | _ -> fallback ())
      | _ -> fallback () in
    try
      ignore (force prepared.states);
      Ok (drawing (force prepared.value))
    with Stop d -> Error d
       | Invalid_argument message -> Error (Flow.Diagnostic.error ~code:"E_DRAW_RANGE" message)
       | V.Fail (code, message, _) -> Error (Flow.Diagnostic.error ~code message))

(* The draw program runs into a mark table which Marks_scene adapts. Retention is whole-program: a
   fully static draw graph is kept per size; the fold states still advance. *)
let render_core (program, root, buffers) ~state ?image prepared ~live ~size =
  let ( let* ) = Result.bind in
  E.transaction state (fun () ->
    let* _ = I.force ~state prepared.states ~live in
    match prepared.kept with
    | Some (kept, scene) when prepared.whole && kept = size -> Ok scene
    | _ ->
        C.Buffers.clear buffers;
        let images = ref [] and count = ref 0 in
        let image = Option.map (fun resolve value ->
          let* loaded = resolve value in
          images := loaded :: !images; incr count; Ok !count) image in
        let* marks = match root with
          | None -> C.draw ?image program ~live ~size ~buffers
          | Some root ->
              (* State reads need the residual's live frame, which the evaluator binds while it
                 offers the residual to its executor; the draw's own result rides out in a ref. *)
              let drawn = ref (Error (Flow.Diagnostic.error ~code:"E_CORE" "The draw program did not run.")) in
              let execute r live = drawn := C.draw ~root:r ?image program ~live ~size ~buffers;
                Some (Ok (E.Int 0)) in
              let* _ = E.Private.force_with_executor ~state ~execute (E.Residual root) ~live in
              !drawn in
        let table = Array.of_list (List.rev !images) in
        let* scene = Marks_scene.scene ~buffers ~image:(fun id -> table.(id - 1)) marks in
        if prepared.whole then prepared.kept <- Some (size, scene);
        Ok scene)

let render_prepared ?state ?image ?gpu ?gpu_policy prepared ~live ~size =
  let state = Option.value ~default:(E.create_state ()) state in
  let core () = match Lazy.force prepared.core with
    | Ok core -> render_core core ~state ?image prepared ~live ~size
    | Error d -> Error d in
  match gpu with
  | Some gpu when prepared.circles ->
      (match render_gpu ~state ~gpu ~gpu_policy:(Option.value ~default:Flow_ir.Gpu.Measured gpu_policy) prepared ~live ~size with
       | Error d when d.code = fallback_code -> core ()
       | result -> result)
  | _ -> core ()
