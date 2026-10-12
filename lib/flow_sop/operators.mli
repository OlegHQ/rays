(** Default immutable operator declarations owned by the SOP workspace host. *)
val all : Flow.Op.t list

val seed_for : seed:int64 -> namespace:string -> label:string -> int
(** Exact context-seed mixing used by [sop/context_seed], shared with host
    primitive fixtures. Names and labels are hashed as UTF-8 bytes. *)
