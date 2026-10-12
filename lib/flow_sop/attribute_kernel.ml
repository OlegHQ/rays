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
    | Record fs | Struct (_, _, fs) | Source(_,_,fs) -> List.iter (fun (_, v) -> visit v) fs
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
      | Op {op=("sop/attr"|"sop/has_attr"|"sop/attr_type");args;_} ->
          (match Option.bind (List.assoc_opt "attribute" args) (lookup bindings),
              Option.bind (List.assoc_opt "geometry" args) (lookup bindings) with
           | Some (E.Text name), Some (E.Deferred (ty, id)) when Flow.Ty.is_geometry ty ->
               names := name :: !names; safe := id :: !safe
           | _ -> opaque := true)
      | Op {op=("sop/count"|"sop/edges"|"sop/group"|"sop/group_names"|"sop/group_order"|"sop/group_entries");args;_} ->
          (match Option.bind (List.assoc_opt "geometry" args) (lookup bindings) with
           | Some (E.Deferred (ty,id)) when Flow.Ty.is_geometry ty -> safe:=id::!safe
           | _ -> opaque:=true)
      | Op {op="sop/attr_names";args;_} ->
          names:="*"::!names;
          (match Option.bind(List.assoc_opt "geometry" args)(lookup bindings)with
           |Some(E.Deferred(ty,id))when Flow.Ty.is_geometry ty->safe:=id::!safe
           |_->opaque:=true)
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
    | E.Source (("sop/count"|"sop/edges"|"sop/group"|"sop/group_names"|"sop/group_order"|"sop/group_entries"),_,args) ->
        (match List.assoc_opt "geometry" args with
         | Some (E.Deferred (ty,_)) when Flow.Ty.is_geometry ty -> ()
         | _ -> opaque:=true)
    | E.Source("sop/attr_names",_,args) ->
        names:="*"::!names;
        (match List.assoc_opt "geometry" args with Some(E.Deferred(ty,_))when Flow.Ty.is_geometry ty->()
         |_->opaque:=true)
    | E.Struct ("sop/attr", _, args) | E.Source(("sop/attr"|"sop/has_attr"|"sop/attr_type"),_,args) ->
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
    | E.Record fields | E.Struct (_, _, fields) | E.Source(_,_,fields) -> List.iter (fun (_, value) -> visit safe value) fields
    | _ -> () in
  visit [] value;
  if !opaque then ["*"] else List.sort_uniq String.compare !names

let error code message = Error (Flow.Diagnostic.error ~code message)
let owner = function
  | "point" -> Ok A.Point | "vertex" -> Ok A.Vertex
  | "primitive" -> Ok A.Primitive | "detail" -> Ok A.Detail
  | _ -> error "E_ATTR_OWNER" "Attribute owner is point, vertex, primitive or detail."
let owner_name = function A.Point->"point"|Vertex->"vertex"|Primitive->"primitive"|Detail->"detail"
let value_type = function
  | "float" -> Ok Flow.Ty.(Array Float) | "int" -> Ok Flow.Ty.(Array Int)
  | "vec2" -> Ok Flow.Ty.(Array Vec2) | "vec3" -> Ok Flow.Ty.(Array Vec3)
  | "vec4" -> Ok Flow.Ty.(Array Vec4) | "text" -> Ok Flow.Ty.(Array Text)
  | "float_array" -> Ok Flow.Ty.(Record ["offsets",Array Int;"values",Array Float])
  | "int_array" -> Ok Flow.Ty.(Record ["offsets",Array Int;"values",Array Int])
  | _ -> error "E_ATTR_TYPE" "Attribute type is float, int, vec2, vec3, vec4, text, float_array or int_array."
let owner_count geometry = function
  | A.Point -> G.point_count geometry | Vertex -> G.vertex_count geometry
  | Primitive -> G.primitive_count geometry | Detail -> 1
let width = function "float"->1|"vec2"->2|"vec3"->3|"vec4"->4|_->0
let options args =
  let text key default code = match List.assoc_opt key args with
    | None->Ok default|Some(E.Text text)->Ok text|_->error code ("Attribute "^key^" must be text.") in
  Result.bind(text "owner" "point" "E_ATTR_OWNER")(fun name->
  Result.bind(owner name)(fun owner->
  Result.bind(text "type" "vec3" "E_ATTR_TYPE")(fun kind->
  Result.map(fun _->owner,kind)(value_type kind))))
let storage ~owner ~name geometry =
  if owner=A.Point && name="P" then Some (A.Float3 (G.positions geometry))
  else Option.map A.Private.storage (G.find_attribute ~owner name geometry)
let storage_kind = function
  | A.Float _->"float"|Int _->"int"|Float2 _->"vec2"|Float3 _->"vec3"
  | Float4 _->"vec4"|Text _->"text"|Float_array _->"float_array"|Int_array _->"int_array"
let columns = function
  | A.Float data -> Some [|data|]
  | Float2 data -> let p=Rdk.Packed.Float2.Private.view data in Some [|p.x;p.y|]
  | Float3 data -> let p=P.Private.view data in Some [|p.x;p.y;p.z|]
  | Float4 data -> let p=Rdk.Packed.Float4.Private.view data in Some [|p.x;p.y;p.z;p.w|]
  | _ -> None
let typed_storage ~owner ~name ~kind geometry =
  match storage ~owner ~name geometry with
  | Some storage when storage_kind storage=kind -> Ok storage
  | _ -> error "E_ATTR_TYPE" (owner_name owner ^ " attribute " ^ name ^ " is missing or is not " ^ kind ^ ".")
let ranges ~grain count f =
  let chunks = if count=0 then 0 else (count-1)/grain+1 in
  Rays_math.Parallel.for_ ~chunk_size:1 ~start:0 ~finish:(chunks-1) (fun chunk ->
    let first=chunk*grain in f ~first ~last:(min count (first+grain)))

let read ?component ~owner ~kind name geometry =
  Result.bind (typed_storage ~owner ~name ~kind geometry) (fun storage ->
  match columns storage with
  | None -> (match storage,component with
      | A.Int data,None -> Ok(E.Int_array(Array.copy data))
      | A.Text data,None -> Ok(E.Text_array(Array.copy data))
      | A.Float_array data,Some "offsets" -> Ok(E.Int_array(Array.copy (Rdk.Packed.Float_array.Private.view data).offsets))
      | A.Float_array data,Some "values" -> Ok(E.Float_array(Array.copy (Rdk.Packed.Float_array.Private.view data).values))
      | A.Int_array data,Some "offsets" -> Ok(E.Int_array(Array.copy (Rdk.Packed.Int_array.Private.view data).offsets))
      | A.Int_array data,Some "values" -> Ok(E.Int_array(Array.copy (Rdk.Packed.Int_array.Private.view data).values))
      | _ -> error "E_ATTR_TYPE" "This attribute storage requires its typed array foundation.")
  | Some planes ->
      let count = owner_count geometry owner and width=Array.length planes in
      if count>Sys.max_floatarray_length/width then error "E_ATTR_COUNT" "Attribute buffer exceeds array limits." else
      let values = Array.make (count * width) 0. in
      ranges ~grain:16_384 count (fun ~first ~last ->
        for i = first to last - 1 do
          for component=0 to width-1 do values.(i*width+component)<-planes.(component).(i) done
        done);
      Ok (match width with 1->E.Float_array values|2->E.Vec2_array values|3->E.Vec3_array values|_->E.Vec4_array values))

let resolve ~geometry = function
  | E.Struct ("sop/attr", _, args) | E.Source ("sop/attr", _, args) ->
      (match List.assoc_opt "geometry" args, List.assoc_opt "attribute" args with
       | Some (E.Deferred (ty, id)), Some (E.Text name) when Flow.Ty.is_geometry ty ->
           (match geometry id with Some geometry -> Result.bind (options args) (fun (owner,kind)->
             let component=match List.assoc_opt "component" args with Some(E.Text name)->Some name|_->None in
             read ?component ~owner ~kind name geometry)
            | None -> error "E_DATA_SOURCE" "Attribute source has not been cooked.")
       | _ -> error "E_ATTR_TYPE" "sop/attr needs geometry and an attribute name.")
  | E.Source("sop/has_attr",_,args) ->
      (match List.assoc_opt "geometry" args,List.assoc_opt "attribute" args with
       | Some(E.Deferred(ty,id)),Some(E.Text name) when Flow.Ty.is_geometry ty ->
           (match geometry id with None->error "E_DATA_SOURCE" "Attribute source has not been cooked."
            | Some geometry->Result.bind (options args) (fun(owner,_)->
                let requested=match List.assoc_opt "type" args with Some(E.Text kind)->Some kind|_->None in
                Ok(E.Bool(match storage ~owner ~name geometry with
                  |None->false|Some storage->Option.fold ~none:true ~some:((=)(storage_kind storage))requested))))
       | _->error "E_ATTR_TYPE" "sop/has_attr needs geometry and an attribute name.")
  | E.Source (("sop/count"|"sop/edges"),_,_) as source -> Topology_kernel.resolve ~geometry source
  | E.Source (("sop/attr_type"|"sop/attr_names"),_,_) as source -> Attribute_metadata.resolve ~geometry source
  | source -> Group_kernel.resolve ~geometry source

let make_storage kind planes = match kind with
  | "float" -> Ok (A.Float planes.(0))
  | "vec2" -> Result.map (fun data->A.Float2 data) (Rdk.Packed.Float2.of_owned ~x:planes.(0) ~y:planes.(1))
  | "vec3" -> Ok (A.Float3 (P.Private.of_shared_exn ~x:planes.(0) ~y:planes.(1) ~z:planes.(2)))
  | "vec4" -> Result.map (fun data->A.Float4 data) (Rdk.Packed.Float4.of_owned ~x:planes.(0) ~y:planes.(1) ~z:planes.(2) ~w:planes.(3))
  | _ -> Error "Unsupported floating attribute type"
let install ~owner ~kind name planes geometry =
  Result.map_error (Flow.Diagnostic.error ~code:"E_ATTR_TYPE")
    (Result.bind (make_storage kind planes) (fun storage ->
      if owner=A.Point && name="P" then match storage with
        | A.Float3 positions -> G.with_positions positions geometry
        | _ -> Error "Canonical point P requires vec3 storage."
      else Result.bind (A.create_owned ~name ~owner storage) (fun attr -> G.with_attribute attr geometry)))

let borrowed_storage ~geometry values =
  let descriptor = function
    | E.Struct("sop/attr",ty,args) | E.Source("sop/attr",ty,args) -> Some(ty,args)
    | _ -> None in
  let source args = match List.assoc_opt "geometry" args,List.assoc_opt "attribute" args with
    | Some(E.Deferred(ty,id)),Some(E.Text name) when Flow.Ty.is_geometry ty ->
        (match geometry id with
         |None->error "E_DATA_SOURCE" "Attribute source has not been cooked."
         |Some geometry->Result.bind(options args)(fun(owner,kind)->
           Result.map(fun storage->storage,owner_count geometry owner)
             (typed_storage ~owner ~name ~kind geometry)))
    |_->error "E_ATTR_TYPE" "sop/attr needs geometry and an attribute name." in
  match descriptor values with
  | Some (ty,args) -> Result.bind(source args)(fun(storage,count)->
      let component=List.assoc_opt "component" args in
      let result=match storage,component with
        |(A.Float_array _|A.Int_array _),None->error "E_ATTR_TYPE" "This attribute storage requires its typed array foundation."
        |storage,None->Ok(storage,count)
        |A.Float_array data,Some(E.Text "offsets") ->
            let data=(Rdk.Packed.Float_array.Private.view data).offsets in Ok(A.Int data,Array.length data)
        |A.Float_array data,Some(E.Text "values") ->
            let data=(Rdk.Packed.Float_array.Private.view data).values in Ok(A.Float data,Array.length data)
        |A.Int_array data,Some(E.Text "offsets") ->
            let data=(Rdk.Packed.Int_array.Private.view data).offsets in Ok(A.Int data,Array.length data)
        |A.Int_array data,Some(E.Text "values") ->
            let data=(Rdk.Packed.Int_array.Private.view data).values in Ok(A.Int data,Array.length data)
        |_->error "E_ATTR_TYPE" "This attribute storage requires its typed array foundation." in
      Result.bind result(fun(storage,count)->Result.bind(value_type(storage_kind storage))(fun actual->
        if ty<>Flow.Ty.Any && ty<>actual then error "E_DATA_SOURCE" "The host returned a data source of the wrong type."
        else Ok(Some(storage,count)))))
  | None -> (match values with
      |E.Record fields -> (match Option.bind(List.assoc_opt "offsets" fields)descriptor,
          Option.bind(List.assoc_opt "values" fields)descriptor with
        |Some(offset_ty,offsets),Some(value_ty,values) when List.assoc_opt "component" offsets=Some(E.Text "offsets")
            && List.assoc_opt "component" values=Some(E.Text "values")
            && List.remove_assoc "component" offsets=List.remove_assoc "component" values ->
            Result.bind(source(List.remove_assoc "component" offsets))(fun(storage,count)->
              let actual=match storage with A.Float_array _->Some Flow.Ty.(Array Float)
                |A.Int_array _->Some Flow.Ty.(Array Int)|_->None in
              match actual with
              |None->error "E_ATTR_TYPE" "This attribute storage requires its typed array foundation."
              |Some actual when (offset_ty=Flow.Ty.Any || offset_ty=Flow.Ty.(Array Int))
                  &&(value_ty=Flow.Ty.Any || value_ty=actual)->Ok(Some(storage,count))
              |Some _->error "E_DATA_SOURCE" "The host returned a data source of the wrong type.")
        |_->Ok None)
      |_->Ok None)

let write_source ~geometry ~owner ~kind name values target =
  Result.bind(borrowed_storage ~geometry values)(function
    |None->Ok None
    |Some(storage,count)->
        if storage_kind storage<>kind then error "E_ATTR_TYPE" ("sop/with_attr requires "^kind^" storage.")
        else if count<>owner_count target owner then error "E_ATTR_COUNT"
          (match kind with
           |"int"->"Integer attribute count differs from owner count."
           |"text"->"Text attribute count differs from owner count."
           |"float_array"|"int_array"->"CSR row count differs from owner count."
           |_->Printf.sprintf "%s needs %d %s values; got %d." name (owner_count target owner) (owner_name owner) count)
        else
          (* This transfers immutable RDK storage. Native storage transfers also
             retain nonfinite planes; computed numeric arrays remain checked. *)
          Result.map Option.some (Result.map_error(Flow.Diagnostic.error ~code:"E_ATTR_TYPE")
            (if owner=A.Point && name="P" then match storage with
               |A.Float3 positions->G.with_positions positions target
               |_->Error "Canonical point P requires vec3 storage."
             else Result.bind(A.create_owned ~name ~owner storage)(fun attribute->G.with_attribute attribute target))))
let write_storage ~owned_fields ~grain ~owner ~kind name values geometry =
  let owned storage = Result.map_error(Flow.Diagnostic.error ~code:"E_ATTR_TYPE")
    (Result.bind (A.create_owned ~name ~owner storage)(fun attr->G.with_attribute attr geometry)) in
  let count=owner_count geometry owner in
  match kind,values with
  | "int",E.Int_array data -> if Array.length data<>count then error "E_ATTR_COUNT" "Integer attribute count differs from owner count."
      else owned(A.Int(Array.copy data))
  | "text",E.Text_array data -> if Array.length data<>count then error "E_ATTR_COUNT" "Text attribute count differs from owner count."
      else owned(A.Text(Array.copy data))
  | ("float_array"|"int_array"),E.Record fields ->
      (match List.assoc_opt "offsets" fields,List.assoc_opt "values" fields with
       | Some(E.Int_array offsets),Some values ->
           if Array.length offsets<>count+1 then error "E_ATTR_COUNT" "CSR row count differs from owner count." else
           let offsets=if List.mem "offsets" owned_fields then offsets else Array.copy offsets in
           (match kind,values with
            | "float_array",E.Float_array data ->
                let index=ref(if List.mem "values" owned_fields then Array.length data else 0) in
                while !index<Array.length data && Float.is_finite data.(!index) do incr index done;
                if !index<Array.length data then error "E_NONFINITE" "Attribute values must be finite." else
                Result.bind (Result.map_error(Flow.Diagnostic.error ~code:"E_ATTR_COUNT")
                  (Rdk.Packed.Float_array.create_owned ~offsets
                    ~values:(if List.mem "values" owned_fields then data else Array.copy data))) (fun data->owned(A.Float_array data))
            | "int_array",E.Int_array data ->
                Result.bind(Result.map_error(Flow.Diagnostic.error ~code:"E_ATTR_COUNT")
                  (Rdk.Packed.Int_array.create_owned ~offsets
                    ~values:(if List.mem "values" owned_fields then data else Array.copy data))) (fun data->owned(A.Int_array data))
            | _->error "E_ATTR_TYPE" "CSR values do not match the requested storage type.")
       | _->error "E_ATTR_TYPE" "CSR attributes require integer offsets and typed values.")
  | _ ->
  let data = match kind,values with
    | "float",E.Float_array data|"vec2",E.Vec2_array data|"vec3",E.Vec3_array data|"vec4",E.Vec4_array data->Some data
    | _ -> None in
  match data with
  | Some values ->
      let count = owner_count geometry owner and width=width kind in
      if count>Sys.max_floatarray_length/width || Array.length values/width<>count || Array.length values mod width<>0 then
        error "E_ATTR_COUNT" (Printf.sprintf "%s needs %d %s values; got %d."
          name count (owner_name owner) (Array.length values / width))
      else
        let finite = Atomic.make true in
        let planes=Array.init width (fun _->Array.make count 0.) in
        ranges ~grain count (fun ~first ~last ->
          for i = first to last - 1 do
            for component=0 to width-1 do
              let value=values.(i*width+component) in
              if not(Float.is_finite value) then Atomic.set finite false;
              planes.(component).(i)<-value
            done
          done);
        if not (Atomic.get finite) then error "E_NONFINITE" "Attribute values must be finite."
        else install ~owner ~kind name planes geometry
  | None -> error "E_ATTR_TYPE" ("sop/with_attr requires " ^ kind ^ " storage.")

let write ~grain ~owner ~kind name values geometry =
  write_storage ~owned_fields:[] ~grain ~owner ~kind name values geometry

(* Strict Collect regions allocate and finite-check their result arrays on every
   force. Captured arrays, host sources and other structured expressions retain
   the ordinary copied-storage boundary. *)
let fresh_csr_fields program =
  let ir=Flow_ir.Executor.graph program in
  let rec fresh index=match ir.nodes.(index).kind with
    |Flow_ir.Kernel {body=Packed_map packed;_}->Flow_ir.Packed.elementwise packed
    |Kernel {body=Readback;_}->(match ir.nodes.(index).args with
        |[{node;_}]->fresh node|_->false)
    |_->false in
  match ir.nodes.(ir.roots.(0)).kind with
  |Kernel {body=Record_value _;_}->List.filter_map(fun(edge:Flow_ir.edge)->
      if List.mem edge.name ["offsets";"values"] && fresh edge.node then Some edge.name else None)
      ir.nodes.(ir.roots.(0)).args
  |_->[]

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
  let count_source residual (term : Flow.Workspace.term) =
    let bindings = (E.Private.residual_view residual).bindings in
    let edge, args = match term.node with
      | Get ({node=Op {op="sop/edges";args;_};_},("a"|"b")) ->
          true,Some(List.filter_map(fun(name,term)->Option.map(fun value->name,value)
            (captured bindings term))args)
      | Op {op=("sop/attr"|"sop/group" as operation);args;_} ->
          let resolved=List.map(fun(name,term)->name,
            (match term.Flow.Workspace.node with Text text->Some(E.Text text)|_->captured bindings term))args in
          (operation="sop/group" && List.assoc_opt "owner" resolved=Some(Some(E.Text "edge"))),
          (if List.exists(fun(name,value)->List.mem name ["owner";"type"] && value=None)resolved then None
          else Some(List.filter_map(fun(name,value)->Option.map(fun value->name,value)value)resolved))
      | _ -> (match captured bindings term with
          | Some (E.Struct("sop/attr",_,args) | E.Source("sop/attr",_,args)) -> false,Some args
          | Some (E.Source("sop/edges",_,args)) -> true,Some args
          | Some (E.Source("sop/group",_,args)) -> List.assoc_opt "owner" args=Some(E.Text "edge"),Some args
          | _ -> false,None) in
    let geometry=Option.bind args (List.assoc_opt "geometry") in
    Option.bind geometry (function
      | E.Deferred (ty, id) when Flow.Ty.is_geometry ty ->
          if edge then Option.map(fun origin->["@sop-edges";string_of_int origin],[])
            (List.assoc_opt id by_source)
          else Option.bind args (fun args -> match options args with
            | Ok(owner,kind) when List.mem kind ["float";"int";"vec2";"vec3";"vec4";"text"] ->
                Option.map (fun origin -> ["@sop-owner";owner_name owner;string_of_int origin], []) (List.assoc_opt id by_source)
            | Ok(owner,kind) when List.mem kind ["float_array";"int_array"] ->
                (match List.assoc_opt "component" args with
                 |Some(E.Text "offsets")->Option.map(fun origin->
                     ["@sop-csr-offsets";owner_name owner;string_of_int origin],[])(List.assoc_opt id by_source)
                 |Some(E.Text "values")->Option.bind(List.assoc_opt "attribute" args)(function
                     |E.Text name->Some(["@sop-csr-values";owner_name owner;name;kind;string_of_int id],[])|_->None)
                 |_->None)
            | _ -> None)
      | _ -> None) in
  Flow_ir.Executor.compile ?profile ?strict ?approx ?sink ~count_source values)

let borrowed_columns ~geometry residual term =
  let rec value = function
    | E.Struct ("sop/attr",_,args) | E.Source ("sop/attr",_,args) ->
        (match List.assoc_opt "geometry" args,List.assoc_opt "attribute" args with
         | Some (E.Deferred (ty,id)),Some (E.Text name) when Flow.Ty.is_geometry ty ->
             (match geometry id with
              | None -> error "E_DATA_SOURCE" "Attribute source has not been cooked."
              | Some geometry ->
                  Result.bind (options args) (fun (owner,kind) ->
                  Result.bind (typed_storage ~owner ~name ~kind geometry) (fun storage ->
                    Ok (Option.map (Array.map (fun data -> Flow_ir.Packed.{data;offset=0;stride=1})) (columns storage)))))
         | _ -> Ok None)
    | E.Residual r -> source r (E.Private.residual_view r).term
    | _ -> Ok None
  and source residual (term : Flow.Workspace.term) =
    let bindings=(E.Private.residual_view residual).bindings in
    match term.node with
    | Op {op="sop/attr";args;_} ->
        let argument name=Option.bind (List.assoc_opt name args) (fun t -> match t.Flow.Workspace.node with
          | Text text -> Some (E.Text text) | _ -> captured bindings t) in
        if List.exists(fun key->List.mem_assoc key args && argument key=None)["owner";"type"] then Ok None else
        (match argument "geometry",argument "attribute" with
         | Some geometry,Some attribute -> value (E.Struct ("sop/attr",term.ty,
             ["geometry",geometry;"attribute",attribute] @
             List.filter_map (fun key->Option.map(fun v->key,v)(argument key)) ["owner";"type"]))
         | _ -> Ok None)
    | Expanded {body;_} -> source residual body
    | Bypass body -> (match Flow.Workspace.bypass_input body with
        Some body -> source residual body | None -> Ok None)
    | _ -> (match captured bindings term with Some v -> value v | None -> Ok None) in
  source residual term

let write_planes ?state ?elems ~strict ~resolve ~geometry ~owner ~kind ~name program target ~live =
  match Flow_ir.Executor.packed_root program with
  | Some packed when Flow_ir.Packed.elementwise packed ->
      let region=Flow_ir.Packed.to_region packed in
      if width kind=0 || Array.length region.outputs<>1 || Array.length region.outputs.(0)<>width kind then Ok None else
      let original=P.Private.view (G.positions target) in
      let original=[|original.x;original.y;original.z|] in
      let count=owner_count target owner in
      let column_source=borrowed_columns ~geometry in
      let unchanged component register =
        if owner<>A.Point || kind<>"vec3" || name<>"P" then false else match region.code.(register) with
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
        if owner=A.Point && kind="vec3" && name="P" && data==original.(component) then None else Some data) planes|] in
      Result.bind (Flow_ir.Executor.force_into ?state ?elems ~strict ~resolve
        ~column_source ~count ~outputs program ~live) (function
        | None -> Ok None
        | Some () ->
            Result.map Option.some (install ~owner ~kind name planes target))
      |> Result.map_error (fun (d:Flow.Diagnostic.t) ->
          if d.code="E_ARRAY_COUNT" then {d with code="E_ATTR_COUNT"} else d)
  | _ -> Ok None

let prepare_constant ~kind values =
  let constructors=["array/int","int";"array/text","text";"array/float","float";
    "array/vec3","vec3";"array/vec4","vec4"] in
  let rec find seen residual (term:Flow.Workspace.term) = match term.node with
    | Expanded {body;_} -> find seen residual body
    | Op {op="exact";args=["value",body];_} -> find seen residual body
    | Ref_binding _ | Get _ ->
        (match captured (E.Private.residual_view residual).bindings term with
         |Some(E.Residual nested) when not(List.mem(E.Private.residual_id nested)seen)->
             find(E.Private.residual_id nested::seen)nested(E.Private.residual_view nested).term
         |_->None)
    | Op {op;args;_} when List.assoc_opt op constructors=Some kind -> Some(residual,op,args)
    | _->None in
  match values with
  | E.Residual residual ->
      (match find [E.Private.residual_id residual] residual (E.Private.residual_view residual).term with
       |None->None
       |Some(residual,operation,args)->
           let compile term=Flow_ir.Executor.compile ~strict:true
             (E.Residual(E.Private.with_bindings residual ~term [])) in
           match compile(List.assoc "count" args),Option.map compile(List.assoc_opt "value" args) with
           |Ok count,(None|Some(Ok _) as value)->
               Some(Option.get(Flow.Op.find operation Flow.Context.value),count,Option.map Result.get_ok value)
           |_->None)
  |_->None

let write_constant ?state ?elems ~resolve ~owner ~kind ~name prepared target ~live =
  match prepared with
  |None->Ok None
  |Some(op,count,value)->
           let force program=Flow_ir.Executor.force ?state ?elems ~strict:true ~resolve program ~live in
           Result.bind(force count)(function
             |E.Int count when count>0 && count=owner_count target owner
                 && (width kind=0 || count<=Sys.max_floatarray_length/width kind) ->
                 let value=match value with Some program->force program
                   |None->Ok(match kind with "int"->E.Int 0|"text"->E.Text""|"vec3"->E.Vec3(0.,0.,0.)
                     |"vec4"->E.Vec4(0.,0.,0.,0.)|_->E.Float 0.) in
                 Result.bind value (fun value->
                   (* The declared constructor validates its fill once. Every
                      plane is newly owned here; no captured array is adopted. *)
                   let sample=try Ok(op.Flow.Op.body ~live ~node:(fun _ _->assert false)
                     ["count",Flow.Value.Int 1;"value",value])
                     with Flow.Value.Fail(code,message,_)->error code message
                       |Flow.Value.Diagnostic_fail d->Error d in
                   Result.bind sample (fun sample->
                     let owned storage=Result.map_error(Flow.Diagnostic.error ~code:"E_ATTR_TYPE")
                       (Result.bind(A.create_owned ~name ~owner storage)(fun attribute->G.with_attribute attribute target)) in
                     let result=match sample with
                       |Flow.Value.Int_array data->owned(A.Int(Array.make count data.(0)))
                       |Text_array data->owned(A.Text(Array.make count data.(0)))
                       |Float_array data->install ~owner ~kind name [|Array.make count data.(0)|] target
                       |Vec3_array data|Vec4_array data->install ~owner ~kind name
                           (Array.map(Array.make count)data) target
                       |_->error "E_ATTR_TYPE" "Constant attribute constructor returned the wrong storage." in
                     Result.map Option.some result))
             |_->Ok None)

let node ?state ?(reference = false) ?(strict = false) ?elems ?profile ?(owner=A.Point) ?(kind="vec3") ~source ~name ~values ~sources inputs =
  let program = prepare ?profile ~strict ~sources inputs values in
  let owned_fields=if strict && not reference && List.mem kind ["float_array";"int_array"] then
    Result.fold ~ok:fresh_csr_fields ~error:(fun _->[]) program else [] in
  let constant = if reference then None else prepare_constant ~kind values in
  let parameters = source ^ ";" ^ owner_name owner ^ ";" ^ kind ^ ";" ^ name ^ ";" ^ Flow.Value.key_of ~residual:E.Private.residual_id values
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
          Result.bind (write_source ~geometry ~owner ~kind name values geometries.(0)) (fun borrowed ->
          Result.bind (match borrowed with Some _ -> Ok borrowed | None -> if reference then Ok None else
            Result.bind(write_constant ?state ?elems ~resolve ~owner ~kind ~name constant geometries.(0) ~live)
              (function Some geometry->Ok(Some geometry)|None->
                write_planes ?state ?elems ~strict ~resolve ~geometry ~owner ~kind ~name program geometries.(0) ~live))
            (fun direct -> if Sop.Context.cancelled context then error "E_CANCELLED" "Attribute kernel cancelled."
              else match direct with Some geometry -> Ok geometry | None ->
                Result.bind (Flow_ir.Executor.force ?state ?elems ~reference ~strict ~resolve program ~live)
                  (fun values -> if Sop.Context.cancelled context then
                      error "E_CANCELLED" "Attribute kernel cancelled."
                    else write_storage ~owned_fields ~grain:(Sop.Context.grain context) ~owner ~kind name values geometries.(0))))) in
      Result.map_error (fun (d : Flow.Diagnostic.t) -> Sop.Diagnostic.error ?cause:d.cause ~code:d.code d.message)
        (Result.map (fun geometry -> N.Private.{geometry; diagnostics = []; instances = None}) result)) in
  N.Private.with_facts { (N.facts node) with elementwise = (match owner with A.Point->N.Points|Primitive->Primitives|_->None);
    topology = N.Preserved; reads = reads values; writes = [name] } node
