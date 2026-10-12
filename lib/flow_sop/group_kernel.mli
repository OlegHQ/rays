(* Cooked immutable group boundary; native RDK owns membership and order. *)
type owner = Ordinary of Rdk.Group.owner | Edge
val owner : string -> (owner, Flow.Diagnostic.t) result
val read : owner:owner -> name:string -> Rdk.Geometry.t -> (Flow.Eval.value, Flow.Diagnostic.t) result
val order : owner:owner -> name:string -> Rdk.Geometry.t -> (Flow.Eval.value, Flow.Diagnostic.t) result
val names : owner:owner -> pattern:string -> Rdk.Geometry.t -> (Flow.Eval.value, Flow.Diagnostic.t) result
val write : ?order:int array -> owner:owner -> name:string -> int array -> Rdk.Geometry.t ->
  (Rdk.Geometry.t, Flow.Diagnostic.t) result
val resolve : geometry:(int -> Rdk.Geometry.t option) -> Flow.Eval.value ->
  (Flow.Eval.value, Flow.Diagnostic.t) result
