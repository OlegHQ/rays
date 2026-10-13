(* Private cooked topology-to-Flow boundary. Integer arrays are owned copies;
   topology indexing and its bounded cache remain in RDK. *)
val resolve : geometry:(int -> Rdk.Geometry.t option) ->
  Flow.Eval.value -> (Flow.Eval.value, Flow.Diagnostic.t) result

(* Construction from concrete immutable Flow arrays. *)
val mesh : (string * Flow.Eval.value) list ->
  (Rdk.Geometry.t, Flow.Diagnostic.t) result

(* Exact payload transfer, retaining opaque raw native storage. *)
val remap : ?cancel:Rdk.Cancel.t -> grain:int -> source:Rdk.Geometry.t ->
  target:Rdk.Geometry.t -> (string * Flow.Eval.value) list ->
  (Rdk.Geometry.t, Flow.Diagnostic.t) result

(* Native merge of cooked geometries ([Rdk.Mesh_merge.run]); [source_attribute] and
   [source_base] are optional keyword fields of [args]. *)
val concat : ?cancel:Rdk.Cancel.t -> grain:int -> sources:Rdk.Geometry.t list ->
  (string * Flow.Eval.value) list -> (Rdk.Geometry.t, Flow.Diagnostic.t) result
