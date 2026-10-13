(* Pure array-in, array-out graph algorithms (E.1-E.3). They never read
   geometry: the adjacency arrives as the record [sop/adjacency] returns (or a
   CSR row record for coloring), so the same call is a JavaScript host twin. *)
module E = Flow.Eval

exception Refuse of string * string
let refuse code message = raise (Refuse (code, message))

let int_array record name = match List.assoc_opt name record with
  | Some (E.Int_array values) -> values
  | _ -> refuse "E_GRAPH_ADJACENCY" ("Graph adjacency needs the integer array " ^ name ^ ".")

let record = function
  | Some (E.Record fields) -> fields
  | _ -> refuse "E_GRAPH_ADJACENCY" "Graph adjacency must be a record of integer arrays."

(* CSR rows: monotone offsets from zero to the value count, values in range. *)
let check_rows label ~rows ~limit offsets values =
  if Array.length offsets <> rows + 1 || offsets.(0) <> 0 || offsets.(rows) <> Array.length values then
    refuse "E_GRAPH_ADJACENCY" (label ^ " offsets must start at zero and end at the value count.");
  for row = 0 to rows - 1 do
    if offsets.(row + 1) < offsets.(row) then
      refuse "E_GRAPH_ADJACENCY" (label ^ " offsets must be monotone.")
  done;
  Array.iter (fun value ->
    if value < 0 || value >= limit then refuse "E_GRAPH_ADJACENCY" (label ^ " value is out of range."))
    values

(* The point/edge part of a sop/adjacency record. *)
let point_graph adjacency =
  let fields = record adjacency in
  let point_edge_offsets = int_array fields "point_edge_offsets"
  and point_edges = int_array fields "point_edges"
  and edge_a = int_array fields "edge_a" and edge_b = int_array fields "edge_b" in
  if Array.length point_edge_offsets = 0 then
    refuse "E_GRAPH_ADJACENCY" "Graph adjacency point_edge_offsets must hold the point count plus one.";
  let points = Array.length point_edge_offsets - 1 and edges = Array.length edge_a in
  if Array.length edge_b <> edges then
    refuse "E_GRAPH_ADJACENCY" "Graph adjacency edge_a and edge_b differ in length.";
  Array.iter (fun p -> if p < 0 || p >= points then
    refuse "E_GRAPH_ADJACENCY" "Graph adjacency edge endpoint is out of range.") edge_a;
  Array.iter (fun p -> if p < 0 || p >= points then
    refuse "E_GRAPH_ADJACENCY" "Graph adjacency edge endpoint is out of range.") edge_b;
  check_rows "Graph adjacency point_edges" ~rows:points ~limit:edges point_edge_offsets point_edges;
  points, edges, point_edge_offsets, point_edges, edge_a, edge_b

let binary_mask label count = function
  | Some (E.Int_array mask) when Array.length mask = count ->
      Array.iter (fun bit -> if bit <> 0 && bit <> 1 then
        refuse "E_GRAPH_MASK" (label ^ " holds only 0 and 1.")) mask;
      mask
  | _ -> refuse "E_GRAPH_MASK" (label ^ " is an integer array with one entry per edge.")

let shortest_paths args =
  let points, edges, point_edge_offsets, point_edges, edge_a, edge_b =
    point_graph (List.assoc_opt "adjacency" args) in
  let lengths = match List.assoc_opt "lengths" args with
    | Some (E.Float_array lengths) when Array.length lengths = edges -> lengths
    | _ -> refuse "E_GRAPH_LENGTH" "Graph lengths is a float array with one entry per edge." in
  Array.iter (fun length -> if not (length >= 0.) then
    refuse "E_GRAPH_LENGTH" "Graph lengths must not be negative.") lengths;
  let roots = match List.assoc_opt "roots" args with
    | Some (E.Int_array roots) -> roots
    | _ -> refuse "E_GRAPH_ROOT" "Graph roots is an integer array of point indices." in
  Array.iter (fun root -> if root < 0 || root >= points then
    refuse "E_GRAPH_ROOT" "Graph root is not a point index.") roots;
  let radius = match List.assoc_opt "radius" args with
    | None -> infinity
    | Some (E.Float radius) when radius >= 0. -> radius
    | Some _ -> refuse "E_GRAPH_RADIUS" "Graph radius is a non-negative float." in
  let distances, parents = Rdk.Shortest_paths.search ~radius ~point_edge_offsets ~point_edges
    ~edge_a ~edge_b ~lengths roots in
  (* Flow floats are finite: a point outside every root's reach reports -1. *)
  Array.map (fun d -> if d = infinity then -1. else d) distances, parents

let color args =
  let fields = record (List.assoc_opt "adjacency" args) in
  let offsets = int_array fields "offsets" and neighbors = int_array fields "values" in
  if Array.length offsets = 0 then
    refuse "E_GRAPH_ADJACENCY" "Graph adjacency offsets must hold the node count plus one.";
  let nodes = Array.length offsets - 1 in
  check_rows "Graph adjacency" ~rows:nodes ~limit:nodes offsets neighbors;
  let order = match List.assoc_opt "order" args with
    | Some (E.Int_array order) -> order
    | _ -> refuse "E_GRAPH_ORDER" "Graph order is an integer array of node indices." in
  let seen = Array.make nodes false in
  Array.iter (fun node ->
    if node < 0 || node >= nodes then refuse "E_GRAPH_ORDER" "Graph order holds a node outside the graph.";
    if seen.(node) then refuse "E_GRAPH_ORDER" "Graph order lists a node twice.";
    seen.(node) <- true) order;
  let colors = Rdk.Graph_color.greedy ~offsets ~neighbors order in
  colors, 1 + Array.fold_left max (-1) colors

let chains args =
  let points, edges, _, _, edge_a, edge_b = point_graph (List.assoc_opt "adjacency" args) in
  let selected = match List.assoc_opt "mask" args with
    | None -> fun _ -> true
    | mask -> let mask = binary_mask "Graph chains mask" edges mask in fun edge -> mask.(edge) = 1 in
  match Rdk.Poly_path.chains ~point_count:points ~edge_a ~edge_b selected with
  | Ok result -> result
  | Error message -> refuse "E_GRAPH_CHAINS" message

let resolve = function
  | E.Source (name, _, args) ->
      (try
         let component = match List.assoc_opt "component" args with
           | Some (E.Text component) -> component
           | _ -> refuse "E_DATA_SOURCE" "Graph source requires a component." in
         let unknown () = refuse "E_DATA_SOURCE" "Unknown graph component." in
         match name with
         | "graph/shortest_paths" ->
             let distance, parent = shortest_paths args in
             Ok (match component with "distance" -> E.Float_array distance
               | "parent" -> E.Int_array parent | _ -> unknown ())
         | "graph/color" ->
             let colors, count = color args in
             Ok (match component with "color" -> E.Int_array colors
               | "count" -> E.Int count | _ -> unknown ())
         | "graph/chains" ->
             let offsets, values, closed = chains args in
             Ok (match component with "offsets" -> E.Int_array offsets
               | "values" -> E.Int_array values | "closed" -> E.Int_array closed
               | _ -> unknown ())
         | _ -> refuse "E_DATA_SOURCE" "Unknown graph data source."
       with Refuse (code, message) -> Error (Flow.Diagnostic.error ~code message))
  | _ -> Error (Flow.Diagnostic.error ~code:"E_DATA_SOURCE" "Unknown graph data source.")
