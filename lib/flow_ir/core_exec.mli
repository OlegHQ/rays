(** Initial-domain execution of the structured frame core, using native primitive
    bodies. State statements need [root], the residual whose state plane they use.
    A region runs through [force] (default [Packed.force]). With [root], any failure
    restores the evaluation state and returns the tree walker's result for that
    residual, so its diagnostic and span are the walker's. *)
type prepared
(** A program with its statements, constants and operators resolved once. *)

val prepare : ?fused:bool -> Core.program -> prepared
(* [~fused:false] runs every program through the general statements: the reference for the
   scalar fast path and pure packed Counted block kernels. *)
val has_regions : prepared -> bool  (* the program invokes a region, so [execute] needs a [force] *)
val fast : prepared -> (Frame_input.t -> (Flow.Eval.value, Flow.Diagnostic.t) result) option
(* Stateless attempt for the evaluator's owner-checked shortcut. Errors must reenter the
    normal evaluator to restore the walker's diagnostics. *)
val execute : ?root:Flow.Eval.residual ->
  ?force:(Packed.t -> (Flow.Eval.value, Flow.Diagnostic.t) result) ->
  ?resolve:(Flow.Eval.value -> (Flow.Eval.value, Flow.Diagnostic.t) result) -> prepared -> live:Frame_input.t ->
  (Flow.Eval.value, Flow.Diagnostic.t) result
val run : ?root:Flow.Eval.residual ->
  ?force:(Packed.t -> (Flow.Eval.value, Flow.Diagnostic.t) result) ->
  ?resolve:(Flow.Eval.value -> (Flow.Eval.value, Flow.Diagnostic.t) result) -> Core.program -> live:Frame_input.t ->
  (Flow.Eval.value, Flow.Diagnostic.t) result
(** [prepare] then [execute]. *)

module Buffers = Core_marks.Buffers
val draw : ?root:Flow.Eval.residual ->
  ?force:(Packed.t -> (Flow.Eval.value, Flow.Diagnostic.t) result) ->
  ?resolve:(Flow.Eval.value -> (Flow.Eval.value, Flow.Diagnostic.t) result) ->
  ?device:(Packed.t -> ((int * int * int) option, Flow.Diagnostic.t) result) ->
  ?image:(Flow.Eval.value -> (int, Flow.Diagnostic.t) result) -> prepared -> live:Frame_input.t ->
  size:int * int -> buffers:Buffers.t -> (Scene_command.Marks.t, Flow.Diagnostic.t) result
(** Run a draw program ({!Core_draw.lower}) into one mark table in painter order. CPU attribute
    arrays are registered in [buffers], which the caller owns, clears per frame and reads while
    it adapts the table. [root] is the residual whose state the program reads. [image] resolves
    an image node to a host resource id. A failure is the core's own diagnostic.

    [device] offers each region whose results are read only as the positions, sizes, radius,
    from, to, fill, stroke or color of a mark set (the others are the frame program's): [Some (token, count, width)]
    means the host ran it on the GPU, and the mark set carries a [Marks.Device] buffer whose id
    {!Buffers.device} resolves to [token]; [None] runs the region on the CPU as usual. *)
