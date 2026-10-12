(** Cook-context constants available to Lisp node bodies. *)
val depends : ?inputs:(string * Flow.Eval.value) list -> ?defs:Flow.Workspace.graph list -> Flow.Workspace.graph -> bool
val specialize : context:Sop.Context.t -> label:string -> Flow.Workspace.graph -> Flow.Workspace.graph
