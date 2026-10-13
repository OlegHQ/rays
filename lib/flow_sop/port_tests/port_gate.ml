(* HOW TO PORT A SOP NODE (the whole verification is this directory).
   Porting a node adds exactly two files and edits no shared file:
     lib/flow_sop/nodes/<key>.pending   the draft defnode (rename to <key>.rays to accept)
     lib/flow_sop/port_tests/port_<key>.ml   one registration, see port_points.ml
   The dune file picks up every .ml here; the toplevel `Port_gate.register` runs at start.

   Registration: { key; native; inputs; cases; ulps; bench }
     native  the OCaml oracle factory, e.g. Sop.Nodes.Grid.factory
     inputs  (label, geometries) fixtures; one geometry per node input.
             no_input | standard_inputs (empty, single point, 4225-point quad grid, mixed
             polygon+polyline with point/vertex/primitive/edge groups and attributes of
             every owner/type) | your own list (use `fixture_*` helpers)
     cases   (label, parameter changes); "defaults" (no changes) is always added.
             Cover every parameter and every branch; changes are rendered as keywords.
     ulps    float tolerance against native (default 4; a larger one needs a stated reason)
     bench   Some (fun () -> geometries, changes) for the 1,000,000-element timing, or None

   Run (repo root, or `dune build --root .` in a worktree):
     dune build ./lib/flow_sop/port_tests/main.exe        then
     _build/default/lib/flow_sop/port_tests/main.exe KEY            gate, accepted or pending
     _build/default/lib/flow_sop/port_tests/main.exe KEY --bench    timing, fails above 2.0x
     _build/default/lib/flow_sop/port_tests/main.exe                every accepted node
     dune build @lib/flow_sop/port_tests/ports                      same, as a dune alias
   A pending node is checked with the catalog minus the native KEY plus <key>.pending.

   Checks, for each fixture x case:
     oracle        Lisp vs native cook: integer data/groups/names exactly, floats within
                   ulps (Rdk_test_support.close_geometry); a native error must be a Lisp
                   error with the same code; a native refusal at construction must be
                   refused by the checker/lowering.
     self          Lisp bytes (geometry_bytes) equal at domains 1/4 x grains 1/97/4096 and
                   between the reference interpreter and the CPU kernel tier.
   Once per node:
     parameters    Catalog.descriptor and Node.parameter_fields equal native's (every case)
     cache         parameter_key equals native's; a changed parameter misses a session
                   cache, an unchanged one hits
     refusals      every float parameter refuses nan/inf with native's exact error *)
open Rdk
open Rdk_test_support
module N = Sop.Node
module P = Param

type changes = (string * P.value) list
type t = {
  key : string;
  native : Sop.Edit_graph.factory;
  inputs : (string * Geometry.t list) list;
  cases : (string * changes) list;
  ulps : int;
  bench : (unit -> Geometry.t list * changes) option;
}

let registry : t list ref = ref []
let register node = registry := node :: !registry
let registered () = List.rev !registry

(* ---- fixtures ---- *)
let points count = Kernel.generate_point_ranges count (fun ~first ~last ~x ~y ~z ->
  for i = first to last - 1 do x.(i) <- float i *. 0.125; y.(i) <- -0.; z.(i) <- 0.25 done)
let polygon_polyline () =
  let topology = Topology.create_owned ~point_count:6 ~vertex_points:[|0;1;2;3;1;4;5|]
    ~primitive_offsets:[|0;4;7|] ~primitive_kinds:[|Topology.Polygon; Open_polyline|] |> get_string_ok in
  Geometry.create ~positions:(Geometry.positions (points 6)) ~topology () |> get_string_ok
let grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:64 ~rows:64 ~size:8. () |> get_ok
(* Groups "a", "dest_a", "old_x", a literal-glob name and a unicode name, on points,
   vertices, primitives and edges (ordered, reversed), plus a detail text attribute. *)
let fixture_groups geometry =
  let names = ["a", 0; "dest_a", 1; "old_x", 2; "literal *?[]^\\", 0; "\195\169\231\140\171", 1] in
  let put owner name phase geometry =
    let count = match owner with Group.Point -> Geometry.point_count geometry
      | Vertex -> Geometry.vertex_count geometry | Primitive -> Geometry.primitive_count geometry in
    let indices = List.filter (fun i -> i mod 3 = phase) (List.init count Fun.id) |> List.rev |> Array.of_list in
    Geometry.with_group (Group.ordered ~owner ~name ~length:count indices |> get_string_ok) geometry |> get_string_ok in
  let geometry = List.fold_left (fun g (name, phase) ->
    g |> put Group.Vertex name phase |> put Group.Point name phase |> put Group.Primitive name phase) geometry names in
  let topology = Geometry.topology geometry in
  let index = Topology_index.create topology in
  let geometry = List.fold_left (fun g (name, phase) -> Geometry.with_edge_group
    (Edge_group.init ~topology ~index ~name (fun i -> i mod 3 = phase)) g |> get_string_ok) geometry names in
  Geometry.with_attribute (Attribute.create_owned ~owner:Attribute.Detail ~name:"untouched"
    (Attribute.Text [|"UTF8"|]) |> get_string_ok) geometry |> get_string_ok
(* One attribute of every storage type on every owner. *)
let fixture_attributes geometry =
  List.fold_left (fun geometry owner ->
    let n = match owner with Attribute.Point -> Geometry.point_count geometry
      | Vertex -> Geometry.vertex_count geometry | Primitive -> Geometry.primitive_count geometry | Detail -> 1 in
    let values = Array.init n (fun i -> if i mod 2 = 0 then -0. else float i *. 0.125)
    and integers = Array.init n (fun i -> if i mod 2 = 0 then max_int else min_int) in
    let plane () = Array.copy values in
    List.fold_left (fun geometry (name, storage) -> Geometry.with_attribute
      (Attribute.create_owned ~owner ~name storage |> get_string_ok) geometry |> get_string_ok) geometry
      ["float", Attribute.Float values; "integer", Int integers; "text", Text (Array.make n "\195\169\231\140\171");
       "vec2", Float2 (Packed.Float2.of_owned ~x:(plane ()) ~y:(plane ()) |> get_string_ok);
       "vec3", Float3 (Packed.Float3.of_owned ~x:(plane ()) ~y:(plane ()) ~z:(plane ()) |> get_string_ok);
       "vec4", Float4 (Packed.Float4.of_owned ~x:(plane ()) ~y:(plane ()) ~z:(plane ()) ~w:(plane ()) |> get_string_ok);
       "float_rows", Float_array (Packed.Float_array.create_owned ~offsets:(Array.init (n + 1) Fun.id)
         ~values:(plane ()) |> get_string_ok);
       "int_rows", Int_array (Packed.Int_array.create_owned ~offsets:(Array.init (n + 1) Fun.id)
         ~values:(Array.copy integers) |> get_string_ok)])
    geometry [Attribute.Point; Vertex; Primitive; Detail]
let no_input = ["none", []]
let standard_inputs = List.map (fun (label, g) -> label, [g]) [
  "empty", fixture_groups (points 0); "single", fixture_groups (points 1);
  "grid4225", fixture_groups (grid ());
  "mixed", fixture_attributes (fixture_groups (polygon_polyline ()))]

(* ---- building nodes ---- *)
let checked = function Ok v -> v | Error d -> fail (Flow.Diagnostic.to_string d)
let errors ds = List.filter (fun (d : Flow.Diagnostic.t) -> d.severity = Error) ds
let render = function
  | P.Bool_value b -> string_of_bool b | Int_value n -> string_of_int n
  | Float_value f -> Flow.Lisp.float f
  | Text_value s | Choice_value s -> Flow.Lisp.flat (Flow.Syntax.make (Str s))
let snapshots geometries = List.map Lisp_sop.snapshot geometries

(* Everything that depends only on the node and one input fixture. *)
type ctx = { node : t; sources : Flow.Syntax.t list; factories : Sop.Edit_graph.factory list;
             catalog : Flow.Check.catalog; head : string; native_inputs : N.t list }
let key_of f = Sop.Edit_graph.factory_key f
let context ~dir node geometries =
  let accepted = Sys.file_exists (Filename.concat dir (node.key ^ ".rays")) in
  let others = List.filter (fun f -> key_of f <> node.key) Sop_catalog.Editor.factories in
  let sources = Flow_sop.Catalog.sources () |> checked in
  let sources =
    if accepted then (check (List.length others = List.length Sop_catalog.Editor.factories)
      (node.key ^ ": accepted but still registered in Sop_catalog.Editor.factories"); sources)
    else sources @ (In_channel.with_open_text (Filename.concat dir (node.key ^ ".pending"))
      In_channel.input_all |> Flow.Syntax.parse |> checked) in
  let natives = snapshots geometries in
  let inputs = List.mapi (fun i n -> Sop.Edit_graph.factory ~key:(Printf.sprintf "port_in%d" i)
    ~label:"Input" ~category:["Test"] ~arity:0 (fun _ -> n)) natives in
  let factories = inputs @ others in
  { node; sources; factories; native_inputs = natives;
    catalog = Flow_sop.Catalog.of_factories ~nodes:[] ~version:Flow_sop.Manifest.version factories |> checked;
    head = String.concat " " (List.mapi (fun i _ -> Printf.sprintf "(sop/port_in%d)" i) natives) }

let native ctx changes =
  Result.bind (Sop.Edit_graph.instantiate ctx.node.native ctx.native_inputs) (fun n ->
    Result.map fst (N.apply_parameters n changes))

(* Ok (fun ~reference -> node, lowered factories) or the checker/lowering refusal. *)
let lisp ctx changes =
  let words = String.concat " " (List.map (fun (k, v) -> ":" ^ k ^ " " ^ render v) changes) in
  let text = Printf.sprintf "(workspace port (graph g :context sop (sop/%s %s %s)))" ctx.node.key ctx.head words in
  match Flow.Syntax.parse text with
  | Error d -> Error (Flow.Diagnostic.to_string d)
  | Ok forms -> match Flow_sop.Catalog.check_workspace ~sources:ctx.sources ~ops:Flow_sop.Operators.all ctx.catalog forms with
    | Some w, ds when errors ds = [] ->
        let build reference = match Flow_sop.Lower.of_checked ~reference ~factories:ctx.factories w with
          | Error d -> Error (Flow.Diagnostic.to_string d)
          | Ok lowered -> let g = List.hd lowered.graphs in
              Result.map (fun n -> n, lowered.factories)
                (Sop.Edit_graph.compile_node g.network.geometry ~node_id:(Option.get g.root)) in
        Ok build
    | _, ds -> Error (String.concat "\n" (List.map Flow.Diagnostic.to_string (match errors ds with [] -> ds | e -> e)))

let with_session f =
  let s = Sop.Session.create ~max_entries:64 ~max_payload_bytes:512_000_000 |> get_string_ok in
  Fun.protect ~finally:(fun () -> Sop.Session.close s) (fun () -> f s)
let cook s domains grain node =
  let context = Sop.Context.create ~domains ~grain () |> get_string_ok in
  Result.bind (Sop.Session.cook s ~context node) (fun o -> Sop.Payload.geometry o.Sop.Session.payload)
let must = function Ok g -> g | Error d -> fail (Sop.Diagnostic.error_to_string d)

(* ---- checks ---- *)
let changed (v : P.field_view) = match v.kind, v.current with
  | P.Toggle_view, P.Bool_value b -> P.Bool_value (not b)
  | Integer_view r, Int_value n -> Int_value (if Some n = r.hard_max then n - 1 else n + 1)
  | Floating_view r, Float_value x -> Float_value (if Some x = r.hard_max then x -. 0.25 else x +. 0.25)
  | Text_view, Text_value s -> Text_value (s ^ "_changed")
  | Choice_view o, Choice_value s -> Choice_value (Option.get (Array.find_opt (( <> ) s) o))
  | _ -> fail (v.name ^ ": view and value disagree")

let cache_identity node =
  with_session (fun s ->
    let ok n = Result.is_ok (cook s 1 97 n) and misses () = (Sop.Session.stats s).misses in
    ignore (ok node); let before = misses () in ignore (ok node);
    check (misses () = before) "cache: equal parameters did not hit";
    List.iter (fun (v : P.field_view) ->
      let edited = fst (N.apply_parameters node [v.name, changed v] |> get_string_ok) in
      let before = misses () in let cooked = ok edited in
      check (misses () = before + 1) ("cache: changed " ^ v.name ^ " did not miss");
      ignore (ok edited);
      check (misses () = before + (if cooked then 1 else 2)) ("cache: edited " ^ v.name ^ " did not then hit"))
      (N.parameter_fields node))

let refusals ~native node =
  List.iter (fun (v : P.field_view) -> match v.kind, v.current with
    | P.Floating_view _, P.Float_value x -> List.iter (fun bad ->
        let probe n = N.apply_parameters n [v.name, P.Float_value (x +. 0.25); v.name, P.Float_value bad] in
        match probe node, probe native with
        | Error a, Error b -> check (a = b) ("refusal: " ^ v.name ^ " error differs from native: " ^ a ^ " / " ^ b)
        | _ -> fail ("refusal: " ^ v.name ^ " accepted a non-finite value"))
        [Float.nan; Float.infinity; Float.neg_infinity]
    | _ -> ()) (N.parameter_fields node)

let verify_case ~full ctx ulps label changes =
  let at what = Printf.sprintf "%s/%s: %s" ctx.node.key label what in
  let protect what f = try f () with Failure m -> fail (at what ^ ": " ^ m) in
  match native ctx changes, lisp ctx changes with
  | Error _, Error _ -> ()
  | Error m, Ok _ -> fail (at "oracle: native refused (" ^ m ^ ") but the Lisp node was accepted")
  | Ok _, Error m -> fail (at "oracle: Lisp refused a valid case: " ^ m)
  | Ok expected, Ok build ->
      let actual, _ = get_string_ok (build false) and walked, _ = get_string_ok (build true) in
      protect "parameters" (fun () -> check (N.parameter_fields actual = N.parameter_fields expected)
        "parameter_fields differ from native");
      protect "cache" (fun () -> check (N.parameter_key actual = N.parameter_key expected)
        "parameter_key differs from native");
      with_session (fun s -> match cook s 1 97 expected, cook s 1 97 actual with
        | Error e, Error g -> protect "oracle" (fun () -> check (e.code = g.code)
            ("error code " ^ g.code ^ " but native " ^ e.code))
        | Error e, Ok _ -> fail (at ("oracle: native error " ^ Sop.Diagnostic.error_to_string e ^ " but Lisp succeeded"))
        | Ok _, Error g -> fail (at ("oracle: Lisp error " ^ Sop.Diagnostic.error_to_string g ^ " but native succeeded"))
        | Ok e, Ok g ->
            protect "oracle" (fun () -> check (close_geometry ~ulps e g)
              (Printf.sprintf "Lisp differs from native beyond %d ulps" ulps));
            let bytes = geometry_bytes g in
            protect "self" (fun () ->
              check (geometry_bytes (must (cook s 1 97 walked)) = bytes) "reference interpreter differs from kernel tier";
              List.iter (fun (domains, grain) -> Sop.Session.clear s;
                check (geometry_bytes (must (cook s domains grain actual)) = bytes)
                  (Printf.sprintf "bytes differ at domains=%d grain=%d" domains grain)) (if full then [1, 1; 1, 97; 1, 4096; 4, 1; 4, 97; 4, 4096] else [4, 1; 4, 4096])))

let run_gate ~dir node =
  let cases = ("defaults", []) :: node.cases and count = ref 0 in
  List.iteri (fun i (fixture, geometries) ->
    let ctx = context ~dir node geometries in
    let tag what = fun f -> try f () with Failure m -> fail (Printf.sprintf "%s/%s: %s: %s" node.key fixture what m) in
    List.iter (fun (label, changes) -> incr count;
      tag label (fun () -> verify_case ~full:(label = "defaults") ctx node.ulps (fixture ^ "/" ^ label) changes)) cases;
    tag "defaults" (fun () ->
      let actual, factories = match lisp ctx [] with Ok b -> get_string_ok (b false) | Error m -> fail m in
      let expected = get_string_ok (native ctx []) in
      tag "cache" (fun () -> cache_identity actual);
      tag "refusals" (fun () -> refusals ~native:expected actual);
      if i = 0 then tag "parameters" (fun () ->
        let lisp_factory = List.find (fun f -> key_of f = node.key) factories in
        check (Flow_sop.Catalog.descriptor lisp_factory = Flow_sop.Catalog.descriptor node.native)
          "Catalog.descriptor differs from native")))
    node.inputs;
  Printf.printf "PASS %s: %d fixtures x %d cases\n%!" node.key (List.length node.inputs) !count

let run_bench ~dir node = match node.bench with
  | None -> Printf.printf "| %s | - | no bench registered | - | - |\n%!" node.key; true
  | Some build -> let geometries, changes = build () in
      let ctx = context ~dir node geometries in
      let actual = match lisp ctx changes with Ok b -> fst (get_string_ok (b false)) | Error m -> fail m
      and expected = get_string_ok (native ctx changes) in
      let sample domains n = List.init 3 (fun _ -> with_session (fun s -> Gc.full_major ();
        let t = Unix.gettimeofday () in ignore (must (cook s domains 4096 n)); Unix.gettimeofday () -. t))
        |> List.sort Float.compare |> fun l -> List.nth l 1 in
      List.fold_left (fun ok domains ->
        let nt = sample domains expected and lt = sample domains actual in
        Printf.printf "| %s | %d | %.6f | %.6f | %.3f |\n%!" node.key domains nt lt (lt /. nt);
        ok && lt /. nt <= 2.) true [1; 4]
