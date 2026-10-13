(** Half-open byte offsets within the parsed source. *)
type span = { start : int; finish : int }
type severity = Error | Warning
type position = { line : int; col : int }
type trace = { node_id : int; label : string; operation : string }

type t = { code : string; severity : severity; position : position option;
  message : string; span : span option; cause : string option; hints : string list; trace : trace list }

val position_of_offset : string -> int -> position
(** The line and column of a byte offset, both counted from 1. *)

val error : ?span:span -> ?position:position -> ?cause:string -> ?hints:string list -> ?trace:trace list -> code:string -> string -> t
val warning : ?span:span -> code:string -> string -> t
val to_string : t -> string

val report : file:string -> source:string -> t -> string
(** The OCaml compiler's format, so dune and editors jump to the line:
    [File "f", line N, characters A-B:] then [Error [CODE]: message] (or
    [Warning]). Lines count from 1, characters from 0 within the line; a span
    that leaves its line ends at the line's end; no span or position is line 1,
    characters 0-0. *)
