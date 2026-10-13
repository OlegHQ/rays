open Rdk

let () =
  let count = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 1_000_000 in
  if count < 2 then invalid_arg "at least two vertices required";
  List.iter (fun invalid ->
    let samples = List.init 7 (fun _ ->
      let vertices = Array.init count Fun.id in
      if invalid then vertices.(count - 1) <- count;
      let offsets = [|0; count|] and kinds = [|Topology.Open_polyline|] in
      Gc.full_major ();
      let before = Gc.quick_stat () and allocated = Gc.allocated_bytes () in
      let started = Unix.gettimeofday () in
      let result = Topology.create_owned ~point_count:count ~vertex_points:vertices
        ~primitive_offsets:offsets ~primitive_kinds:kinds in
      let elapsed = Unix.gettimeofday () -. started and after = Gc.quick_stat () in
      (match result with
       | Ok topology -> assert (not invalid && Topology.vertex_count topology = count
           && Topology.point_of_vertex topology (count - 1) = count - 1)
       | Error message -> assert (invalid && message = "Topology: vertex references an invalid point"));
      elapsed, Gc.allocated_bytes () -. allocated,
      after.promoted_words -. before.promoted_words, after.major_words -. before.major_words)
      |> List.sort (fun (a,_,_,_) (b,_,_,_) -> Float.compare a b) in
    let seconds, bytes, promoted, major = List.nth samples 3 in
    Printf.printf "topology vertices=%d case=%s domains=1 trials=7 median_seconds=%.9f allocated_bytes=%.0f promoted_words=%.0f major_words=%.0f\n%!"
      count (if invalid then "invalid_last" else "valid") seconds bytes promoted major)
    [false; true]
