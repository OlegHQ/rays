module W = Flow.Workspace

let map ?(select=Fun.id) transform (graph:W.graph) =
  let rec term (t:W.term) =
    let t=select t in
    let fields xs=List.map (fun (name,value) -> name,term value) xs in
    let patterns xs=List.map (fun (pattern,value) -> pattern,term value) xs in
    let node=match t.node with
      | W.Call c -> W.Call {c with args=fields c.args}
      | Op c -> Op {c with args=fields c.args}
      | Call_fn c -> Call_fn {c with args=List.map term c.args;body=Option.map term c.body}
      | Graph_ref g -> Graph_ref {g with inputs=fields g.inputs}
      | Let (bindings,body) -> Let (patterns bindings,term body)
      | State s -> State {s with init=term s.init;step=term s.step}
      | Loop l -> Loop {l with accs=patterns l.accs;clauses=patterns l.clauses;body=term l.body}
      | With_error(a,b) -> With_error(term a,term b)
      | Error_rows scope -> Error_rows{scope with rows=term scope.rows;mapper=term scope.mapper}
      | If (a,b,c) -> If (term a,term b,term c)
      | Cond (arms,default) -> Cond (List.map (fun (a,b)->term a,term b) arms,term default)
      | Case (value,arms,default) -> Case (term value,patterns arms,term default)
      | Fn f -> Fn {f with body=term f.body;capture=Option.map term f.capture}
      | Hof (kind,args) -> Hof (kind,List.map term args)
      | Vec args -> Vec (List.map term args)
      | List_lit args -> List_lit (List.map term args)
      | Record args -> Record (fields args)
      | Get (value,key) -> Get (term value,key)
      | Assoc (value,args) -> Assoc (term value,fields args)
      | Str args -> Str (List.map term args)
      | List_op (kind,args) -> List_op (kind,List.map term args)
      | Bypass value -> Bypass (term value)
      | Expanded e -> Expanded {e with body=term e.body}
      | Lit _ | Text _ | Nil | Time | Ref_binding _ | Fn_ref _ -> t.node in
    transform {t with node} in
  {graph with W.body=term graph.W.body;inputs=List.map (fun (n,ty,df)->n,ty,Option.map term df) graph.inputs}

let depends ?(inputs=[]) ?(defs=[]) (graph:W.graph) =
  let defaults=List.filter_map (fun (name,_,df)->Option.bind df (fun (t:W.term)->match t.node with
    | W.Lit (Param.Bool_value b)->Some (name,Flow.Eval.Bool b)
    | Lit (Int_value n)->Some (name,Flow.Eval.Int n)
    | Lit (Float_value f)->Some (name,Flow.Eval.Float f)
    | Text text->Some (name,Flow.Eval.Text text)|_->None)) graph.inputs in
  let found=ref false in
  let rec names = function
    | W.Name name -> [name]
    | Seq patterns -> List.concat_map names patterns
    | Keys names -> names in
  let remove patterns bindings =
    let bound=List.concat_map names patterns in
    List.filter (fun (name,_) -> not (List.mem name bound)) bindings in
  let rec known bindings (t:W.term) = match t.node with
    | W.Lit (Param.Bool_value b)->Some (Flow.Eval.Bool b)
    | Lit (Int_value n)->Some (Flow.Eval.Int n)
    | Lit (Float_value f)->Some (Flow.Eval.Float f)
    | Text text->Some (Flow.Eval.Text text)
    | Ref_binding (name,[])->List.assoc_opt name bindings
    | Op {op;args;_} when op<>"sop/context_seed" ->
        let rec values = function
          |[]->Some []
          |(key,value)::rest->Option.bind (known bindings value) (fun value->Option.map (fun rest->(key,value)::rest) (values rest)) in
        Option.bind (values args) (fun args->Option.bind (Flow.Op.find ~extra:Operators.all op Flow.Context.value) (fun op->
          try op.check args; Some (op.body ~live:(Frame_input.at_time 0.) ~node:(fun _ _->raise Exit) args)
          with Flow.Value.Fail _ | Flow.Value.Diagnostic_fail _ | Exit -> None))
    |_->None
  and scan bindings (body:W.term) =
    let select (t:W.term)=match t.node with
      | W.If (test,yes,no)->(match known bindings test with
          | Some (Flow.Eval.Bool true)->yes|Some (Bool false)->no|_->t)
      | Call_fn call ->
          (match List.find_opt (fun (d:W.graph) -> d.name=call.fn) defs with
           | Some helper ->
               let local=List.mapi (fun i (name,_,default) ->
                 let value=match List.nth_opt call.args i with
                   | Some argument -> known bindings argument
                   | None -> Option.bind default (known []) in
                 Option.map (fun value -> name,value) value) helper.inputs |> List.filter_map Fun.id in
               scan local (Option.value ~default:helper.body call.body)
           | None -> Option.iter (scan []) call.body);
          {t with node=Call_fn {call with body=None}}
      | Fn fn ->
          scan (remove (List.map fst fn.params) bindings) fn.body;
          {t with node=Fn {fn with body={fn.body with node=Nil}}}
      | Fn_ref name ->
          Option.iter (fun (helper:W.graph) -> scan [] helper.body)
            (List.find_opt (fun (d:W.graph) -> d.name=name) defs);
          t
      | Let (locals,body) ->
          let bindings=List.fold_left (fun bindings (pattern,value) ->
            scan bindings value;
            let local=match pattern,known bindings value with
              | W.Name name,Some value -> [name,value] | _ -> [] in
            local @ remove [pattern] bindings) bindings locals in
          scan bindings body;
          {t with node=Nil}
      | State state ->
          scan bindings state.init;
          scan (remove [state.binder] bindings) state.step;
          {t with node=Nil}
      | Loop loop ->
          List.iter (fun (_,value) -> scan bindings value) loop.accs;
          let bindings=remove (List.map fst loop.accs) bindings in
          let bindings=List.fold_left (fun bindings (pattern,value) ->
            scan bindings value; remove [pattern] bindings) bindings loop.clauses in
          scan bindings loop.body;
          {t with node=Nil}
      |_->t in
    ignore (map ~select (fun t -> (match t.W.node with
      | W.Op {op="sop/context_seed";_} -> found:=true | _->()); t)
      {graph with body;inputs=[]}) in
  let bindings=inputs@defaults in
  scan bindings graph.body;
  List.iter (fun (_,_,default) -> Option.iter (scan bindings) default) graph.inputs;
  !found

let specialize ~context ~label graph = map (fun t -> match t.W.node with
  | W.Op {op="sop/context_seed";args=["namespace",{node=W.Text namespace;_}];_} ->
      let seed=Operators.seed_for ~seed:(Sop.Context.seed context) ~namespace ~label in
      {t with node=W.Lit (Param.Int_value seed)}
  | W.Op {op="sop/context_seed";_} -> invalid_arg "E_SEED_NAMESPACE: Context seed requires a literal namespace."
  | _ -> t) graph
