(** Node-owned schemas and cook identity for checked Lisp geometry bodies. *)
val input : int -> (Sop.Payload.t, Sop.Diagnostic.error) result
(** Immutable cooked input in the enclosing body's caller-domain scope. *)

val node :
  ?unbound_function:bool ->
  operation:string -> label:string -> fields:Param.field_view list ->
  normalizers:(string * (string -> (string, Flow.Diagnostic.t) result)) list ->
  source:string ->
  build:(label:string -> context:Sop.Context.t -> Sop.Node.t list -> (string * Flow.Eval.value) list ->
    (Sop.Context.t -> (Sop.Node.t, Sop.Diagnostic.error) result) *
    Sop.Context.Dependencies.t * Sop.Node.facts) ->
  Sop.Node.t list -> Sop.Node.t
