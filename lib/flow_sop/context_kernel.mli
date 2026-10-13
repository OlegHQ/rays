(** Cook-context constants available to Lisp node bodies. *)
val depends : ?inputs:(string * Flow.Eval.value) list -> ?defs:Flow.Workspace.graph list -> Flow.Workspace.graph -> bool
val specialize : context:Sop.Context.t -> label:string -> Flow.Workspace.graph -> Flow.Workspace.graph

(* Own declaration and transitively referenced checked declarations/helpers. *)
val declaration_source : Flow.Workspace.t -> Flow.Workspace.node_definition -> string
