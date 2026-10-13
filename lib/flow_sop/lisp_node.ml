module W = Flow.Workspace
module E = Flow.Eval
module N = Sop.Node

let cooked_inputs = Domain.DLS.new_key (fun () -> [])

let input index = match List.assoc_opt index (Domain.DLS.get cooked_inputs) with
  | Some payload -> Ok payload
  | None -> Error (Sop.Diagnostic.error ~code:"E_DATA_SOURCE"
      "A Lisp body input is only available while its node cooks")

let schema name fields normalizers =
  let field (f : Param.field_view) =
    let make kind default decode encode =
      Param.field ~name:f.name ~label:f.label ?description:f.description
        ~folder:f.folder ~impact:f.impact ~primary:f.primary ?unit:f.unit
        ?vec3:f.vec3 ~kind ~default
        ~get:(fun values -> decode (List.assoc f.name values))
        ~set:(fun value values -> List.map (fun (name, old) ->
          name, if name = f.name then encode value else old) values) () in
    match f.kind, f.default with
    | Param.Toggle_view, Bool_value default ->
        make Param.Toggle default (function Param.Bool_value v -> v | _ -> assert false)
          (fun v -> Param.Bool_value v)
    | Integer_view range, Int_value default ->
        make (Param.Integer range) default (function Param.Int_value v -> v | _ -> assert false)
          (fun v -> Param.Int_value v)
    | Floating_view range, Float_value default ->
        make (Param.Floating range) default (function Param.Float_value v -> v | _ -> assert false)
          (fun v -> Param.Float_value v)
    | Text_view, Text_value default ->
        let kind=match List.assoc_opt f.name normalizers with
          |None->Param.Text
          |Some normalize->Param.encoded ~equal:String.equal ~encode:Fun.id
              ~decode:(fun value->Result.map_error(fun(d:Flow.Diagnostic.t)->d.message)(normalize value)) in
        make kind default (function Param.Text_value v -> v | _ -> assert false)
          (fun v -> Param.Text_value v)
    | Choice_view labels, Choice_value default ->
        make (Param.choice ~equal:String.equal
          (Array.to_list (Array.map (fun label -> label, label) labels))) default
          (function Param.Choice_value v -> v | _ -> assert false)
          (fun v -> Param.Choice_value v)
    | _ -> invalid_arg ("Invalid Lisp parameter field " ^ f.name) in
  Param.schema ~name ~default:(List.map (fun (f : Param.field_view) -> f.name, f.default) fields)
    (List.map field fields)

let arguments fields values =
  let scalar = function
    | Param.Bool_value v -> E.Bool v | Int_value v -> E.Int v | Float_value v -> E.Float v
    | Text_value v | Choice_value v -> E.Text v in
  let fields = List.map (fun (f : Param.field_view) ->
    {f with current = List.assoc f.name values}) fields in
  match Port.parameters fields with
  | Error d -> invalid_arg (Flow.Diagnostic.to_string d)
  | Ok ports -> List.map (fun (p : Port.parameter) -> p.path,
      match Port.literal p with
      | Vector (x, y, z) -> E.Vec3 (x, y, z)
      | Scalar (Param.Bool_value v) -> E.Bool v
      | Scalar (Int_value v) -> E.Int v
      | Scalar (Float_value v) -> E.Float v
      | Scalar (Text_value v | Choice_value v) -> E.Text v) ports
      @ List.filter_map (fun (f : Param.field_view) ->
          if f.vec3=None then None else Some (f.name, scalar f.current)) fields

let node ?(unbound_function = false) ~operation ~version ~label ~fields ~normalizers ~source ~build inputs =
  let schema = schema "parameters" fields normalizers in
  Sop.Custom.node ~label ~operation ~schema ~values:(Param.default schema) inputs
    (fun ~label ~inputs ~parameters ->
      if unbound_function then
        N.Private.make ~label ~operation ~version ~parameters:source
          ~cook_mode:N.Generic ~dependencies:Sop.Context.Dependencies.static
          ~inputs:(Array.of_list inputs) (fun ~node_id:_ _ _ ->
            Error (Sop.Diagnostic.error ~code:"disconnected_input"
              "A Lisp function input needs its checked callable before cooking"))
      else
      let arguments = arguments fields parameters in
      let context = Result.get_ok (Sop.Context.create ()) in
      let body, dependencies, facts = build ~label ~context inputs arguments in
      let prepared = Atomic.make (Sop.Context.seed context, body) in
      let context_seeded = Sop.Context.Dependencies.mem Seed dependencies in
      N.Private.make ~label ~operation ~version ~parameters:source
        ~cook_mode:facts.N.cook_mode ~dependencies ~inputs:(Array.of_list inputs)
        (fun ~node_id:_ context payloads ->
          let seed, previous_body = Atomic.get prepared in
          let body = if not context_seeded || seed=Sop.Context.seed context then previous_body
            else let body,_,_ = build ~label ~context inputs arguments in
              Atomic.set prepared (Sop.Context.seed context,body); body in
          let previous = Domain.DLS.get cooked_inputs in
          Domain.DLS.set cooked_inputs (Array.to_list (Array.mapi (fun i payload -> i,payload) payloads));
          Fun.protect ~finally:(fun () -> Domain.DLS.set cooked_inputs previous) (fun () ->
            Result.bind (body context) (fun body ->
              (* The public node owns the cache entry. The body uses Session's
                 payload/instance rules with only per-cook sharing retained. *)
              let session = Result.get_ok (Sop.Session.create ~max_entries:0 ~max_payload_bytes:0) in
              Sop.Session.Private.set_parallel_override session (Some false);
              Fun.protect ~finally:(fun () -> Sop.Session.close session) (fun () ->
                Result.map (fun (output : Sop.Session.output) ->
                  N.Private.{payload=output.payload;diagnostics=output.diagnostics;instances=output.instances})
                  (Sop.Session.cook session ~context body)))))
      |> N.Private.with_facts facts)
