(* Heap-ordered single-source-set search over point/edge adjacency. Ties on
   distance are broken by the lower point index, so the pop order, the
   distances and the parents are a pure function of the inputs. *)

let search ?cancel ?(radius = infinity) ~point_edge_offsets ~point_edges
    ~edge_a ~edge_b ~lengths roots =
  let count = Array.length point_edge_offsets - 1 in
  let distances = Array.make count infinity and parents = Array.make count (-1) in
  (* An indexed decrease-key heap admits each point at most once. [positions]
     is -1 before insertion, a heap slot while queued, and -2 after pop. *)
  let heap_points = Array.make count 0 and heap_positions = Array.make count (-1)
  and heap_size = ref 0 in
  let less_point left right = distances.(left) < distances.(right)
      || (distances.(left) = distances.(right) && left < right) in
  let assign slot point =
    heap_points.(slot) <- point; heap_positions.(point) <- slot in
  let rec bubble_up slot point =
    if slot = 0 then assign 0 point
    else
      let parent = (slot - 1) / 2 and parent_point = heap_points.((slot - 1) / 2) in
      if less_point point parent_point then begin
        assign slot parent_point;
        bubble_up parent point
      end else assign slot point in
  let enqueue_or_decrease point =
    let slot = heap_positions.(point) in
    if slot = -1 then begin
      let slot = !heap_size in
      incr heap_size;
      bubble_up slot point
    end else if slot >= 0 then bubble_up slot point in
  let rec sift_down slot point =
    let left = (slot * 2) + 1 in
    if left >= !heap_size then assign slot point
    else
      let right = left + 1 in
      let child = if right < !heap_size
          && less_point heap_points.(right) heap_points.(left)
        then right else left in
      let child_point = heap_points.(child) in
      if less_point child_point point then begin
        assign slot child_point;
        sift_down child point
      end else assign slot point in
  let pop () =
    let point = heap_points.(0) in
    heap_positions.(point) <- -2;
    decr heap_size;
    if !heap_size > 0 then sift_down 0 heap_points.(!heap_size);
    point in
  Array.iteri (fun index point ->
    if index land 16_383 = 0 then Cancel.check_opt cancel;
    distances.(point) <- 0.;
    enqueue_or_decrease point) roots;
  let visits = ref 0 in
  while !heap_size > 0 do
    if !visits land 16_383 = 0 then Cancel.check_opt cancel;
    incr visits;
    let point = pop () in
    let distance = distances.(point) in
    if distance <= radius then
      for slot = point_edge_offsets.(point) to point_edge_offsets.(point + 1) - 1 do
        let edge = point_edges.(slot) in
        let a = edge_a.(edge) and b = edge_b.(edge) in
        let neighbor = if a = point then b else a in
        if neighbor <> point then begin
          let candidate = distance +. lengths.(edge) in
          if candidate <= radius && candidate < distances.(neighbor) then begin
            distances.(neighbor) <- candidate;
            parents.(neighbor) <- point;
            enqueue_or_decrease neighbor
          end
        end
      done
  done;
  distances, parents
