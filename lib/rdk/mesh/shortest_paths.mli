(** Shortest paths over the unique-edge graph of a {!Topology_index}. *)

val search :
  ?cancel:Cancel.t ->
  ?radius:float ->
  point_edge_offsets:int array ->
  point_edges:int array ->
  edge_a:int array ->
  edge_b:int array ->
  lengths:float array ->
  int array ->
  float array * int array
(** [search ~point_edge_offsets ~point_edges ~edge_a ~edge_b ~lengths roots]
    returns [(distances, parents)], one entry per point. [lengths] holds one
    non-negative length per edge. Roots have distance [0.] and parent [-1];
    points not reached within [radius] (default unbounded) keep [infinity] and
    parent [-1]. Equal distances are settled by the lower point index, and a
    point's parent is the first settled neighbour that gave its final
    distance. Roots must be valid point indices. *)
