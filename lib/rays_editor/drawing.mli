(** Native Scene lowering of Flow's typed deferred drawing plan. Uses the
    workspace evaluator and the environment's fold state. *)
type prepared
val prepare : ?profile:Flow_ir.Profile.t -> ?approx:Flow.Workspace.Paths.t ->
  ?states:Flow.Eval.value list -> Flow.Eval.plan -> Flow.Eval.value ->
  (prepared, Flow.Diagnostic.t) result
(** Prepare each drawing argument's IR program once for playback or export. *)

val render_prepared : ?state:Flow.Eval.state ->
  ?image:(Flow.Eval.value -> (Rays.Image.t, Flow.Diagnostic.t) result) ->
  ?gpu:(Flow_ir.Gpu.value -> radius:float -> fill:int32 -> stroke:int32 -> stroke_width:float ->
    (Scene_command.Shape_batch.gpu_token,Flow.Diagnostic.t)result) ->
  ?gpu_policy:Flow_ir.Gpu.policy -> prepared ->
  live:Frame_input.t -> size:int * int -> (Rays.Scene.t, Flow.Diagnostic.t) result
(** Runs the core draw path ({!Flow_ir.Core_exec}) into a mark table and adapts it with
    {!Marks_scene}; a lowering error is the diagnostic. [gpu]: a [draw/circles] over a GPU region
    output stays the backend token (replaced by P4.9). *)
