(** Immutable packed 2D primitives. Sixteen little-endian words per instance:
    bounds/endpoints (0..3), reserved (4..7), RGBA fill/stroke (8..9),
    kind (10: rect=0, circle=4, line=5), radius (11), stroke width (12),
    anti-alias flag (13), reserved (14..15). Coordinates are logical points. *)
type t
type gpu_token
val instance_bytes : int
val count : t -> int
val instances : t -> bytes
(* Read-only borrowed storage. *)
val gpu : t -> gpu_token option
module Private : sig
  val copy : t -> t
  val valid : t -> bool
  val gpu_token : identity:int -> count:int -> stamp:int64 -> gpu_token
  val gpu_identity : gpu_token -> int
  val gpu_count : gpu_token -> int
  val gpu_stamp : gpu_token -> int64
  val of_gpu : gpu_token -> t
end
module Builder : sig
  type batch = t
  type t
  val create : ?capacity:int -> unit -> t
  val circle : t -> x:float -> y:float -> radius:float ->
    ?fill:int32 -> ?stroke:int32 -> ?stroke_width:float -> unit -> unit
  val rect : t -> x:float -> y:float -> width:float -> height:float ->
    ?fill:int32 -> ?stroke:int32 -> unit -> unit
  val line : t -> x0:float -> y0:float -> x1:float -> y1:float ->
    color:int32 -> width:float -> unit

  (* Whole sets from packed arrays: [count] instances appended in index order, with the bytes,
     checks and failure of [circle], [rect] and [line] called once an instance with both colours
     given, and no allocation per instance. [floats] is the values and how many floats an
     instance takes; 0 repeats element 0 for every instance (a constant: two floats for a
     position, extent or end, one otherwise), and a third float an instance (a packed vec3) is
     ignored. An array shorter than its stride asks is [Invalid_argument]. *)
  type floats = float array * int
  val circles : t -> count:int -> position:floats -> radius:floats ->
    fill:int32 -> stroke:int32 -> stroke_width:floats -> unit
  val rects : t -> count:int -> position:floats -> size:floats ->
    fill:int32 -> stroke:int32 -> unit
  val lines : t -> count:int -> from:floats -> to_:floats -> color:int32 -> width:floats -> unit

  (* A builder filled to its capacity gives the batch its storage, otherwise a copy; later
     appends never change a published batch. *)
  val publish : t -> batch
end
