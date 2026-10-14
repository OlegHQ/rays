(** Cook-context constants available to Lisp node bodies. [depends ~op] is whether a reachable,
    unpruned call of the zero-state operator [op] (default [sop/context_seed]) remains. *)
val depends : ?op:string -> ?inputs:(string * Flow.Eval.value) list -> ?defs:Flow.Workspace.graph list -> Flow.Workspace.graph -> bool
val specialize : ?provenance:int -> context:Sop.Context.t -> label:string -> Flow.Workspace.graph -> Flow.Workspace.graph

(* Own declaration and transitively referenced checked declarations/helpers. *)
val declaration_source : Flow.Workspace.t -> Flow.Workspace.node_definition -> string

(* Authored source plus the declarations the checked workspace's graphs reach: the key of
   prepared kernels, instead of the whole library. *)
val kernel_source : Flow.Workspace.t -> string
