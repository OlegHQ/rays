(* E.1-E.3: graph/shortest_paths, graph/color and graph/chains against
   independent oracles and the RDK callers they wrap. *)
module E = Flow.Eval
module G = Rdk.Geometry
module T = Rdk.Topology
let ok = function Ok value -> value | Error message -> failwith message
let flow_ok = function Ok value -> value | Error d -> failwith (Flow.Diagnostic.to_string d)
let ok_error = function Ok value -> value | Error e -> failwith (Rdk.Error.to_string e)
let ints a = E.Int_array (Array.copy a)

let fixtures () =
  let topology points vertex_points primitive_offsets primitive_kinds =
    T.create_owned ~point_count:points ~vertex_points ~primitive_offsets ~primitive_kinds |> ok in
  ["empty", T.empty ~point_count:0;
   "shared-polygons", topology 5 [|0;1;2;2;1;3|] [|0;3;6|] [|T.Polygon;Polygon|];
   "open-repeated", topology 3 [|0;1;1;2;1|] [|0;5|] [|T.Open_polyline|];
   "closed", topology 4 [|3;2;1;0|] [|0;4|] [|T.Closed_polyline|];
   "mixed-nonmanifold", topology 6 [|0;1;2;0;1;3;1;0;4;0;1;5|]
     [|0;3;6;9;12|] [|T.Polygon;Open_polyline;Closed_polyline;Polygon|]]
  |> List.map (fun (name, topology) ->
    let count = T.point_count topology in
    let positions = Rdk.Packed.Float3.Private.of_owned_exn
      ~x:(Array.init count float) ~y:(Array.make count 0.) ~z:(Array.make count 0.) in
    name, (G.create ~positions ~topology () |> ok))

let evaluate geometry decls inputs body =
  let source = "(workspace graph (graph g :context sop [(geo : geometry nil) " ^ decls ^ "] (let* [tested "
    ^ body ^ "] geo)))" in
  let forms = Flow.Syntax.parse source |> flow_ok in
  let checked = match Flow.Workspace.check ~ops:Flow_sop.Operators.all {Flow.Check.version=1;kinds=[]} forms with
    | Some checked, [] -> checked
    | _, ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds)) in
  let value = Flow.Eval.static ~record:true
      ~inputs:["g",("geo",E.Deferred (Flow.Ty.geometry,7))::inputs] checked
    |> flow_ok |> fun evaluation -> List.assoc ["g";"tested"] evaluation.records |> List.hd |> snd in
  value, Flow_sop.Attribute_kernel.resolve ~geometry:(fun id -> if id=7 then Some geometry else None)

(* Reference interpreter and strict compiled tier agree with [expected] at one
   and eight domains. *)
let agree ?(decls="") ?(inputs=[]) geometry body expected =
  let value, resolve = evaluate geometry decls inputs body in
  let live = Frame_input.at_time 0.25 in
  let core = Flow_ir.Executor.compile ~strict:true value |> flow_ok in
  List.iter (fun domains -> Rays_math.Parallel.run ~domains (fun () ->
    assert (flow_ok (E.Private.force_reference ~resolve value ~live) = expected);
    assert (flow_ok (Flow_ir.Executor.force ~strict:true ~resolve core ~live) = expected))) [1;8]

let refused ?(decls="") ?(inputs=[]) geometry body code =
  let value, resolve = evaluate geometry decls inputs body in
  match E.Private.force_reference ~resolve value ~live:(Frame_input.at_time 0.) with
  | Error d -> assert (d.code = code)
  | Ok _ -> failwith ("expected " ^ code)

let view_of geometry = Rdk.Topology_index.Private.view (Rdk.Topology_index.create (G.topology geometry))

(* Textbook O(n^2) Dijkstra: settle the unsettled point of least (distance, index),
   relax strictly smaller candidates so the first settled neighbour is the parent. *)
let oracle_paths ?(radius=infinity) (view : Rdk.Topology_index.Private.view) lengths roots =
  let n = Array.length view.point_edge_offsets - 1 in
  let dist = Array.make n infinity and parent = Array.make n (-1) and settled = Array.make n false in
  Array.iter (fun r -> dist.(r) <- 0.) roots;
  let continue = ref true in
  while !continue do
    let best = ref (-1) in
    for p = 0 to n - 1 do
      if not settled.(p) && dist.(p) < infinity && (!best < 0 || dist.(p) < dist.(!best)) then best := p
    done;
    if !best < 0 then continue := false
    else begin
      let p = !best in
      settled.(p) <- true;
      for slot = view.point_edge_offsets.(p) to view.point_edge_offsets.(p + 1) - 1 do
        let e = view.point_edges.(slot) in
        let q = if view.edge_a.(e) = p then view.edge_b.(e) else view.edge_a.(e) in
        let candidate = dist.(p) +. lengths.(e) in
        if q <> p && candidate <= radius && candidate < dist.(q) then begin
          dist.(q) <- candidate; parent.(q) <- p
        end
      done
    end
  done;
  E.Record ["distance", E.Float_array (Array.map (fun d -> if d = infinity then -1. else d) dist);
            "parent", E.Int_array parent]

let shortest_paths () =
  List.iter (fun (_, geometry) ->
    let view = view_of geometry in
    let points = G.point_count geometry and edges = Array.length view.edge_a in
    List.iter (fun roots ->
      if roots <= points then
        List.iter (fun (lengths_lisp, lengths) ->
          agree geometry
            (Printf.sprintf "(graph/shortest_paths (sop/adjacency geo) %s (array/range %d :type int))"
               lengths_lisp roots)
            (oracle_paths view lengths (Array.init roots Fun.id)))
          [Printf.sprintf "(array/float %d 1.0)" edges, Array.make edges 1.;
           Printf.sprintf "(exact (map (fn [(i : int)] (float (int/add 1 (int/mod i 2)))) (array/range %d :type int)))"
             edges, Array.init edges (fun i -> float (1 + i mod 2))])
      [0;1;2]) (fixtures ());
  (* A radius cuts the search; malformed input is refused. *)
  let _, geometry = List.nth (fixtures ()) 3 in
  let view = view_of geometry in
  agree geometry "(graph/shortest_paths (sop/adjacency geo) (array/float 4 1.0) (array/int 1 0) :radius 1.5)"
    (oracle_paths ~radius:1.5 view (Array.make 4 1.) [|0|]);
  refused geometry "(graph/shortest_paths (sop/adjacency geo) (array/float 3 1.0) (array/int 1 0))" "E_GRAPH_LENGTH";
  refused geometry "(graph/shortest_paths (sop/adjacency geo) (array/float 4 -1.0) (array/int 1 0))" "E_GRAPH_LENGTH";
  refused geometry "(graph/shortest_paths (sop/adjacency geo) (array/float 4 1.0) (array/int 1 9))" "E_GRAPH_ROOT"

(* Neighbour rows of the three graphs Graph_color colors. *)
let neighbours_of geometry connectivity =
  let topology = T.Private.view (G.topology geometry) in
  let view = view_of geometry in
  let primitives = G.primitive_count geometry and points = G.point_count geometry in
  let rows count neighbours =
    let lists = Array.init count neighbours in
    let offsets = Array.make (count + 1) 0 in
    Array.iteri (fun i l -> offsets.(i + 1) <- offsets.(i) + List.length l) lists;
    offsets, Array.of_list (List.concat (Array.to_list lists)) in
  let range first last = List.init (last - first) (fun i -> first + i) in
  let primitive_vertices p = range topology.primitive_offsets.(p) topology.primitive_offsets.(p + 1) in
  let point_vertices q = List.map (fun at -> view.point_vertices.(at))
    (range view.point_offsets.(q) view.point_offsets.(q + 1)) in
  let polygon p = Bytes.get topology.primitive_kinds p = '\000' in
  match connectivity with
  | Rdk.Graph_color.Graph_primitives_by_point ->
      primitives, rows primitives (fun p -> List.concat_map (fun v ->
        List.map (fun w -> view.primitive_of_vertex.(w)) (point_vertices topology.vertex_points.(v)))
        (primitive_vertices p))
  | Graph_points_by_primitive ->
      points, rows points (fun q -> List.concat_map (fun v ->
        List.map (fun w -> topology.vertex_points.(w)) (primitive_vertices view.primitive_of_vertex.(v)))
        (point_vertices q))
  | Graph_primitives_by_edge ->
      primitives, rows primitives (fun p ->
        if not (polygon p) then []
        else List.concat_map (fun v ->
          let e = view.edge_of_vertex.(v) in
          if e < 0 then [] else
            List.filter_map (fun k ->
              let q = view.primitive_of_vertex.(view.edge_vertices.(k)) in
              if polygon q then Some q else None)
              (range view.edge_offsets.(e) view.edge_offsets.(e + 1)))
          (primitive_vertices p))

let color () =
  let decls = "(rows : {:offsets (array int) :values (array int)} {:offsets (array/int 1) :values (array/int 0)}) \
               (order : (array int) (array/int 0))" in
  List.iter (fun (_, geometry) ->
    List.iter (fun connectivity ->
      let count, (offsets, values) = neighbours_of geometry connectivity in
      let point_mode = connectivity = Rdk.Graph_color.Graph_points_by_primitive in
      let owner = if point_mode then Rdk.Group.Point else Rdk.Group.Primitive in
      List.iter (fun pick ->
        let selection = Option.map (fun pick ->
          let group = Rdk.Group.init ~owner ~name:"s" count pick in
          if point_mode then Rdk.Transform_ops.Selected_points group
          else Rdk.Transform_ops.Selected_primitives group) pick in
        let native = Rdk.Graph_color.run ?selection ~connectivity geometry |> ok_error in
        let colors = match G.find_attribute ~owner:(if point_mode then Rdk.Attribute.Point else Primitive)
            "color" native |> Option.map Rdk.Attribute.Private.storage with
          | Some (Rdk.Attribute.Int values) -> values | _ -> failwith "no colors" in
        let order = Array.of_list (List.filter (fun i -> match pick with None -> true | Some f -> f i)
          (List.init count Fun.id)) in
        agree ~decls geometry "(graph/color rows order)"
          ~inputs:["rows", E.Record ["offsets", ints offsets; "values", ints values]; "order", ints order]
          (E.Record ["color", ints colors; "count", E.Int (1 + Array.fold_left max (-1) colors)]))
        [None; Some (fun i -> i mod 2 = 0)])
      [Rdk.Graph_color.Graph_primitives_by_point; Graph_points_by_primitive; Graph_primitives_by_edge])
    (fixtures ());
  let _, geometry = List.nth (fixtures ()) 1 in
  let bad rows order code = refused ~decls ~inputs:["rows", rows; "order", order] geometry
    "(graph/color rows order)" code in
  let one = E.Record ["offsets", ints [|0;0|]; "values", ints [||]] in
  bad one (ints [|0;0|]) "E_GRAPH_ORDER";
  bad one (ints [|1|]) "E_GRAPH_ORDER";
  bad (E.Record ["offsets", ints [|0;1|]; "values", ints [|5|]]) (ints [|0|]) "E_GRAPH_ADJACENCY"

let chains () =
  List.iter (fun (_, geometry) ->
    let edges = Array.length (view_of geometry).edge_a in
    List.iter (fun pick ->
      let group = Option.map (fun pick -> Rdk.Edge_group.init ~topology:(G.topology geometry)
        ~index:(Rdk.Topology_index.create (G.topology geometry)) ~name:"m" pick) pick in
      let run closed = Rdk.Poly_path.run ?edges:group ~make_isolated_loops_closed:closed geometry |> ok in
      let open_run = T.Private.view (G.topology (run false))
      and closed_run = T.Private.view (G.topology (run true)) in
      let expected = E.Record ["offsets", ints open_run.primitive_offsets;
        "values", ints open_run.vertex_points;
        "closed", ints (Array.init (Bytes.length closed_run.primitive_kinds) (fun i ->
          if Bytes.get closed_run.primitive_kinds i = '\000' then 1 else 0))] in
      let mask = match pick with
        | None -> ""
        | Some _ -> Printf.sprintf
            " :mask (exact (map (fn [(i : int)] (if (int/eq (int/mod i 2) 0) 1 0)) (array/range %d :type int)))" edges in
      agree geometry ("(graph/chains (sop/adjacency geo)" ^ mask ^ ")") expected)
      [None; Some (fun e -> e mod 2 = 0)]) (fixtures ());
  let _, geometry = List.nth (fixtures ()) 3 in
  refused geometry "(graph/chains (sop/adjacency geo) :mask (array/int 3 1))" "E_GRAPH_MASK";
  refused geometry "(graph/chains (sop/adjacency geo) :mask (array/int 4 2))" "E_GRAPH_MASK"

let () =
  match Sys.argv with
  | [| _; "shortest_paths" |] -> shortest_paths ()
  | [| _; "color" |] -> color ()
  | [| _; "chains" |] -> chains ()
  | _ -> shortest_paths (); color (); chains ()
