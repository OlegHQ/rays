module E = Flow.Eval
module G = Rdk.Geometry
module A = Rdk.Attribute
module P = Rdk.Packed.Float3
module N = Sop.Node
module Functions = Hashtbl.Make (struct
  type t = E.fn
  let equal = ( == )
  let hash = E.Private.function_id
end)
module Residuals = Hashtbl.Make (struct
  type t = E.residual
  let equal = ( == )
  let hash = E.Private.residual_id
end)

let sources value =
  let seen = Residuals.create 16 and functions = Functions.create 16 and ids = ref [] in
  let rec visit = function
    | E.Deferred (ty, id) when Flow.Ty.is_geometry ty -> ids := id :: !ids
    | Residual r ->
        if not (Residuals.mem seen r) then begin
          Residuals.add seen r ();
          (* Evaluator captures are already trimmed to lexically free bindings. *)
          List.iter (fun (_, v) -> visit v) (E.Private.residual_view r).bindings
        end
    | List vs -> Array.iter visit vs
    | Fn f when not (Functions.mem functions f) ->
        Functions.add functions f ();
        List.iter (fun (_, v) -> visit v) (E.Private.function_bindings f)
    | Record fs | Struct (_, _, fs) -> List.iter (fun (_, v) -> visit v) fs
    | _ -> () in
  visit value; List.sort_uniq Int.compare !ids

let reads value =
  let residuals = Residuals.create 16 and functions = Functions.create 16 in
  let names = ref [] and opaque = ref false in
  let rec lookup bindings (term : Flow.Workspace.term) = match term.node with
    | Text name -> Some (E.Text name)
    | Ref_binding (name, fields) -> List.fold_left (fun value field -> Option.bind value (function
        | E.Record fields | Struct (_, _, fields) -> List.assoc_opt field fields | _ -> None))
        (List.assoc_opt name bindings) fields
    | Get (term, field) -> Option.bind (lookup bindings term) (function
        | E.Record fields | Struct (_, _, fields) -> List.assoc_opt field fields | _ -> None)
    | Expanded {body; _} | Bypass body -> lookup bindings body
    | _ -> None in
  let checked_reads bindings term =
    let safe = ref [] and unsafe = ref [] in
    let rec scan (term : Flow.Workspace.term) =
      let all = List.iter scan and fields fields = List.iter (fun (_, term) -> scan term) fields in
      match term.node with
      | Op {op="sop/attr";args;_} ->
          (match Option.bind (List.assoc_opt "attribute" args) (lookup bindings),
              Option.bind (List.assoc_opt "geometry" args) (lookup bindings) with
           | Some (E.Text name), Some (E.Deferred (ty, id)) when Flow.Ty.is_geometry ty ->
               names := name :: !names; safe := id :: !safe
           | _ -> opaque := true)
      | Ref_binding _ when Flow.Ty.is_geometry term.ty ->
          (match lookup bindings term with Some (E.Deferred (_, id)) -> unsafe := id :: !unsafe | _ -> ())
      | Vec terms | List_lit terms | Str terms | List_op (_, terms) | Hof (_, terms) -> all terms
      | Op {args;_} | Call {args;_} | Record args -> fields args
      | Call_fn {args;_} -> all args
      | Graph_ref {inputs;_} -> fields inputs
      | Let (bindings, body) -> fields bindings; scan body
      | Loop {accs;clauses;body;_} -> fields accs; fields clauses; scan body
      | State {init;step;_} -> all [init;step]
      | If (condition, yes, no) -> all [condition;yes;no]
      | Cond (arms, default) -> List.iter (fun (condition, yes) -> all [condition;yes]) arms; scan default
      | Case (value, arms, default) -> scan value; fields arms; scan default
      | Fn {body;capture;_} -> Option.iter scan capture; scan body
      | Get (term,_) | Expanded {body=term;_} -> scan term
      | Bypass call -> Option.iter scan (Flow.Workspace.bypass_input call)
      | Assoc (record, updates) -> scan record; fields updates
      | Ref_binding _ | Lit _ | Text _ | Nil | Time | Fn_ref _ -> () in
    scan term;
    List.filter (fun id -> not (List.mem id !unsafe)) !safe in
  let rec visit safe = function
    | E.Struct ("sop/attr", _, args) ->
        (match List.assoc_opt "attribute" args, List.assoc_opt "geometry" args with
         | Some (E.Text name), Some (E.Deferred (ty, _)) when Flow.Ty.is_geometry ty ->
             names := name :: !names
         | _ -> opaque := true)
    | E.Deferred (ty, id) when Flow.Ty.is_geometry ty ->
        if not (List.mem id safe) then opaque := true
    | E.Residual residual when not (Residuals.mem residuals residual) ->
        Residuals.add residuals residual ();
        let view = E.Private.residual_view residual in
        let safe = checked_reads view.bindings view.term in
        List.iter (fun (_, value) -> visit safe value) view.bindings
    | E.Fn fn when not (Functions.mem functions fn) ->
        Functions.add functions fn ();
        let bindings = E.Private.function_bindings fn in
        let safe = match E.Private.function_body fn with
          | None -> opaque := true; []
          | Some (_, body) -> checked_reads bindings body in
        List.iter (fun (_, value) -> visit safe value) bindings
    | E.List values -> Array.iter (visit safe) values
    | E.Record fields | E.Struct (_, _, fields) -> List.iter (fun (_, value) -> visit safe value) fields
    | _ -> () in
  visit [] value;
  if !opaque then ["*"] else List.sort_uniq String.compare !names

let error code message = Error (Flow.Diagnostic.error ~code message)
let ranges ~grain count f =
  let chunks = if count=0 then 0 else (count-1)/grain+1 in
  Rays_math.Parallel.for_ ~chunk_size:1 ~start:0 ~finish:(chunks-1) (fun chunk ->
    let first=chunk*grain in f ~first ~last:(min count (first+grain)))

let read name geometry =
  let positions = if name = "P" then Some (G.positions geometry) else
    Option.bind (G.find_attribute ~owner:A.Point name geometry)
      (A.get (A.key ~name ~owner:A.Point A.float3)) in
  match positions with
  | None -> error "E_ATTR_TYPE" ("Point attribute " ^ name ^ " is missing or is not vec3.")
  | Some positions ->
      let p = P.Private.view positions in
      let count = G.point_count geometry in
      let values = Array.make (count * 3) 0. in
      ranges ~grain:16_384 count (fun ~first ~last ->
        for i = first to last - 1 do
          values.(i * 3) <- p.x.(i);
          values.(i * 3 + 1) <- p.y.(i);
          values.(i * 3 + 2) <- p.z.(i)
        done);
      Ok (E.Vec3_array values)

let resolve ~geometry = function
  | E.Struct ("sop/attr", _, args) ->
      (match List.assoc_opt "geometry" args, List.assoc_opt "attribute" args with
       | Some (E.Deferred (ty, id)), Some (E.Text name) when Flow.Ty.is_geometry ty ->
           (match geometry id with Some geometry -> read name geometry
            | None -> error "E_DATA_SOURCE" "Attribute source has not been cooked.")
       | _ -> error "E_ATTR_TYPE" "sop/attr needs geometry and an attribute name.")
  | _ -> error "E_DATA_SOURCE" "Unknown packed data source."

let write ~grain name values geometry = match values with
  | E.Vec3_array values ->
      let count = G.point_count geometry in
      if Array.length values <> count * 3 then
        error "E_ATTR_COUNT" (Printf.sprintf "%s needs %d point values; got %d."
          name count (Array.length values / 3))
      else
        let finite = Atomic.make true in
        let x = Array.make count 0.
        and y = Array.make count 0.
        and z = Array.make count 0. in
        ranges ~grain count (fun ~first ~last ->
          for i = first to last - 1 do
            let vx=values.(i*3) and vy=values.(i*3+1) and vz=values.(i*3+2) in
            if not (Float.is_finite vx && Float.is_finite vy && Float.is_finite vz) then
              Atomic.set finite false;
            x.(i)<-vx; y.(i)<-vy; z.(i)<-vz
          done);
        if not (Atomic.get finite) then error "E_NONFINITE" "Point attributes must be finite."
        else let storage = P.Private.of_owned_exn ~x ~y ~z in
          Result.map_error (Flow.Diagnostic.error ~code:"E_ATTR_TYPE")
            (if name="P" then G.with_positions storage geometry else
              Result.bind (A.create_owned ~name ~owner:A.Point (A.Float3 storage))
                (fun attr -> G.with_attribute attr geometry))
  | _ -> error "E_ATTR_TYPE" "sop/with_attr takes a packed vec3 array."

let source_origins ~sources inputs =
  if List.compare_lengths sources inputs <> 0 then
    error "E_DATA_SOURCE" "Attribute source ids and inputs must correspond."
  else
  let origins = Hashtbl.create 16 in
  let rec point_origin node =
    match Hashtbl.find_opt origins (N.id node) with
    | Some origin -> origin
    | None ->
        let facts = N.facts node in
        let input = match facts.cook_mode with
          | N.Duplicate_input i | In_place i | Instance_input i | Passthrough i -> Some i
          | _ -> None in
        let origin = match facts.topology, facts.elementwise, input with
          | N.Preserved, (N.Points | Primitives), Some i ->
              let inputs = N.Private.input_array node in
              if i >= 0 && i < Array.length inputs then point_origin inputs.(i) else N.id node
          | _ -> N.id node in
        Hashtbl.add origins (N.id node) origin; origin in
  Ok (List.combine sources inputs |> List.map (fun (id, node) -> id, point_origin node))

let materialized_source source =
  N.Private.make_geometry ~operation:"flow.capture" ~version:1 ~parameters:""
    ~cook_mode:N.Generic ~dependencies:Sop.Context.Dependencies.static
    ~inputs:[|source|] (fun ~node_id:_ _ geometries ->
      Ok N.Private.{geometry=geometries.(0);diagnostics=[];instances=None})

let rec captured bindings (term : Flow.Workspace.term) = match term.node with
    | Ref_binding (name, fields) ->
        List.fold_left (fun value field -> Option.bind value (function
          | E.Record fields | Struct (_, _, fields) -> List.assoc_opt field fields | _ -> None))
          (List.assoc_opt name bindings) fields
    | Get (term, field) -> Option.bind (captured bindings term) (function
        | E.Record fields | Struct (_, _, fields) -> List.assoc_opt field fields | _ -> None)
    | Bypass body | Expanded {body; _} -> captured bindings body
    | _ -> None

let prepare ?profile ?strict ?approx ?sink ~sources inputs values =
  Result.bind (source_origins ~sources inputs) (fun by_source ->
  let attribute_source = function
    | E.Struct ("sop/attr", _, args) -> List.assoc_opt "geometry" args | _ -> None in
  let count_source residual (term : Flow.Workspace.term) =
    let bindings = (E.Private.residual_view residual).bindings in
    let geometry = match term.node with
      | Op {op = "sop/attr"; args; _} -> Option.bind (List.assoc_opt "geometry" args) (captured bindings)
      | _ -> Option.bind (captured bindings term) attribute_source in
    Option.bind geometry (function
      | E.Deferred (ty, id) when Flow.Ty.is_geometry ty ->
          Option.map (fun origin -> ["@sop-points"; string_of_int origin], []) (List.assoc_opt id by_source)
      | _ -> None) in
  Flow_ir.Executor.compile ?profile ?strict ?approx ?sink ~count_source values)

let borrowed_columns ~geometry residual term =
  let rec value = function
    | E.Struct ("sop/attr",_,args) ->
        (match List.assoc_opt "geometry" args,List.assoc_opt "attribute" args with
         | Some (E.Deferred (ty,id)),Some (E.Text name) when Flow.Ty.is_geometry ty ->
             (match geometry id with
              | None -> error "E_DATA_SOURCE" "Attribute source has not been cooked."
              | Some geometry ->
                  let storage=if name="P" then Some (G.positions geometry) else
                    Option.bind (G.find_attribute ~owner:A.Point name geometry)
                      (A.get (A.key ~name ~owner:A.Point A.float3)) in
                  (match storage with
                   | None -> error "E_ATTR_TYPE" ("Point attribute " ^ name ^ " is missing or is not vec3.")
                   | Some storage ->
                       let p=P.Private.view storage in
                       Ok (Some (Array.map (fun data -> Flow_ir.Packed.{data;offset=0;stride=1})
                         [|p.x;p.y;p.z|]))))
         | _ -> Ok None)
    | E.Residual r -> source r (E.Private.residual_view r).term
    | _ -> Ok None
  and source residual (term : Flow.Workspace.term) =
    let bindings=(E.Private.residual_view residual).bindings in
    match term.node with
    | Op {op="sop/attr";args;_} ->
        let argument name=Option.bind (List.assoc_opt name args) (fun t -> match t.Flow.Workspace.node with
          | Text text -> Some (E.Text text) | _ -> captured bindings t) in
        (match argument "geometry",argument "attribute" with
         | Some geometry,Some attribute -> value (E.Struct ("sop/attr",term.ty,
             ["geometry",geometry;"attribute",attribute]))
         | _ -> Ok None)
    | Expanded {body;_} -> source residual body
    | Bypass body -> (match Flow.Workspace.bypass_input body with
        Some body -> source residual body | None -> Ok None)
    | _ -> (match captured bindings term with Some v -> value v | None -> Ok None) in
  source residual term

let write_planes ?state ?elems ~strict ~resolve ~geometry ~name program target ~live =
  match Flow_ir.Executor.packed_root program with
  | Some packed when Flow_ir.Packed.elementwise packed ->
      let region=Flow_ir.Packed.to_region packed in
      if Array.length region.outputs<>1 || Array.length region.outputs.(0)<>3 then Ok None else
      let original=P.Private.view (G.positions target) in
      let original=[|original.x;original.y;original.z|] in
      let count=G.point_count target in
      let column_source=borrowed_columns ~geometry in
      let unchanged component register =
        if name<>"P" then false else match region.code.(register) with
        | Flow_ir.Core.Region.Input (input,_,index) ->
            let residual,term=region.sources.(input) in
            (match column_source residual term with
             | Ok (Some columns) -> let column=columns.(index) in
                 column.data==original.(component) && column.offset=0 && column.stride=1
             | _ -> false)
        | _ -> false in
      let planes=Array.mapi (fun component register ->
        if unchanged component register then original.(component) else Array.make count 0.) region.outputs.(0) in
      let outputs=[|Array.mapi (fun component data ->
        if data==original.(component) then None else Some data) planes|] in
      Result.bind (Flow_ir.Executor.force_into ?state ?elems ~strict ~resolve
        ~column_source ~count ~outputs program ~live) (function
        | None -> Ok None
        | Some () ->
            let storage=P.Private.of_shared_exn ~x:planes.(0) ~y:planes.(1) ~z:planes.(2) in
            Result.map (fun geometry -> Some geometry)
              (Result.map_error (Flow.Diagnostic.error ~code:"E_ATTR_TYPE")
                (if name="P" then G.with_positions storage target else
                  Result.bind (A.create_owned ~name ~owner:A.Point (A.Float3 storage))
                    (fun attr -> G.with_attribute attr target))))
      |> Result.map_error (fun (d:Flow.Diagnostic.t) ->
          if d.code="E_ARRAY_COUNT" then {d with code="E_ATTR_COUNT"} else d)
  | _ -> Ok None

let node ?state ?(reference = false) ?(strict = false) ?elems ?profile ~source ~name ~values ~sources inputs =
  let program = prepare ?profile ~strict ~sources inputs values in
  let parameters = source ^ ";" ^ name ^ ";" ^ Flow.Value.key_of ~residual:E.Private.residual_id values
    ^ Option.fold ~none:"" ~some:(fun bindings -> Flow.Value.key_of
        ~residual:E.Private.residual_id (E.Record bindings)) elems
    ^ Option.fold ~none:"" ~some:E.state_stamp state in
  let node = N.Private.make_geometry ~label:("Write " ^ name) ~operation:"flow.with_attr" ~version:1
    ~parameters ~cook_mode:(N.Duplicate_input 0)
    ~dependencies:(if E.frame_dependent values then
        Sop.Context.Dependencies.one Sop.Context.Dependencies.Input
      else Sop.Context.Dependencies.static)
    ~inputs:(Array.of_list inputs)
    (fun ~node_id:_ context geometries ->
      let geometry id = Option.map (fun index -> geometries.(index))
        (List.find_index ((=) id) sources) in
      let resolve = resolve ~geometry in
      let result = if geometries = [||] then error "E_DATA_SOURCE" "Attribute write needs geometry."
        else if Sop.Context.cancelled context then error "E_CANCELLED" "Attribute kernel cancelled."
        else Result.bind program (fun program ->
          let live=Sop.Context.input context in
          Result.bind (if reference then Ok None else
            write_planes ?state ?elems ~strict ~resolve ~geometry ~name program geometries.(0) ~live)
            (fun direct -> if Sop.Context.cancelled context then error "E_CANCELLED" "Attribute kernel cancelled."
              else match direct with Some geometry -> Ok geometry | None ->
                Result.bind (Flow_ir.Executor.force ?state ?elems ~reference ~strict ~resolve program ~live)
                  (fun values -> if Sop.Context.cancelled context then
                      error "E_CANCELLED" "Attribute kernel cancelled."
                    else write ~grain:(Sop.Context.grain context) name values geometries.(0)))) in
      Result.map_error (fun (d : Flow.Diagnostic.t) -> Sop.Diagnostic.error ~code:d.code d.message)
        (Result.map (fun geometry -> N.Private.{geometry; diagnostics = []; instances = None}) result)) in
  N.Private.with_facts { (N.facts node) with elementwise = N.Points;
    topology = N.Preserved; reads = reads values; writes = [name] } node
