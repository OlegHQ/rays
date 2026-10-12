(* Private cooked topology-to-Flow boundary. Integer arrays are owned copies;
   topology indexing and its bounded cache remain in RDK. *)
val resolve : geometry:(int -> Rdk.Geometry.t option) ->
  Flow.Eval.value -> (Flow.Eval.value, Flow.Diagnostic.t) result
