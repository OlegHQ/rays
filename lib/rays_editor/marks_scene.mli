(** The adapter from the mark table ({!Scene_command.Marks}, [specification/marks.md]) to
    [Rays.Scene]. It builds the same [Shape_batch] records, geometry and transforms
    [Drawing] builds today, so the renderer sees the same commands. *)

val scene : buffers:Flow_ir.Core_exec.Buffers.t -> ?image:(int -> Rays.Image.t) -> Scene_command.Marks.t ->
  (Rays.Scene.t, Flow.Diagnostic.t) result
(** [buffers] is the table the marks' buffer ids refer to; [image] maps an [Image] entry's
    resource id to the host image ([E_IMAGE] when absent). A buffer value or constant a
    builder rejects is [E_DRAW_RANGE]; a nonfinite colour channel [E_NONFINITE]. *)
