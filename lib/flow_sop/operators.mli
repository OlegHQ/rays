(** Default immutable operator declarations owned by the SOP workspace host. *)
val all : Flow.Op.t list

val seed_for : ?salt:int -> seed:int64 -> namespace:string -> label:string -> unit -> int
(** Exact context-seed mixing used by [sop/context_seed], shared with host
    primitive fixtures. [salt] (default 0) is its low 63 bits xor-ed into the identity before mixing. Names and labels are hashed as UTF-8 bytes. *)
