(** The development server of [rays-lisp web --watch] (plan P6.6): re-export a [.rays] file when its text
    changes and serve the output directory over HTTP on 127.0.0.1 with the cross-origin isolation headers the
    worker pool needs. Standard library and [unix] only. *)

val digest : (string * string) list -> string
(** SHA-256 of an export's files (path and contents, in order): the body of [/version]. The export is
    deterministic, so the digest changes exactly when the output does. *)

val run : ?port:int -> dir:string -> file:string -> export:(unit -> ((string * string) list, unit) result) -> unit -> unit
(** Export once ([export] prints its own diagnostics) into [dir]; if that is refused, exit 1. Then print
    ["serving http://127.0.0.1:PORT/"] and loop forever: poll the SHA-256 of [file] every 0.5 s and, when it
    changes, [export] again. A refusal keeps the last good export. [port] defaults to 8000;
    0 picks a free port. Requests: [GET] only (405 otherwise); the file is looked up under [dir],
    and a path with [..] or outside [dir] is 404. [/version] is {!digest} of the last good export. Every response
    carries [Cross-Origin-Opener-Policy: same-origin] and [Cross-Origin-Embedder-Policy: require-corp]. *)

val write : string -> (string * string) list -> unit
(** Write an export's files under a directory (created as needed), each by a rename so a reader never sees half a file. *)
