module E = Flow.Eval
module W = Flow.Workspace
module V = Flow.Value
module C = Core
module Names = Map.Make (String)
exception Unsupported of string
let refuse name = raise (Unsupported name)
type lowered = Known of E.value | Computed of int * Flow.Ty.t

let lower root =
  let constants = ref [] and locals = ref [] and next_constant = ref 0
  and next_local = ref 0 and next_statement = ref 0 in
  let budget = ref 2048 and active = Hashtbl.create 8 in
  let local ty = let n = !next_local in incr next_local; locals := ty :: !locals; n in
  let number () = let n = !next_statement in incr next_statement; n in
  let statement id source node : C.statement = {id;source;node} in
  let emit statements source ty expression =
    let n = local ty in
    statements := statement (number ()) source (Assign (n,expression)) :: !statements;
    Computed (n,ty) in
  let ensure statements source = function
    | Computed (n,_) -> n
    | Known value ->
        let value_literal = match C.literal_of_value value with Some v -> v | None -> refuse "capture" in
        let index = !next_constant in incr next_constant; constants := value_literal :: !constants;
        match emit statements source (V.ty_of value) (Constant index) with Computed (n,_) -> n | _ -> assert false in
  let primitive statements source ty op args =
    let args = List.map (fun (name,v) -> name,ensure statements source v) args in
    emit statements source ty (Prim (op,args)) in
  let known_values args =
    let rec all = function [] -> Some [] | (name,Known v)::xs ->
      Option.map (fun xs -> (name,v)::xs) (all xs) | _ -> None in all args in
  let field statements source ty value name = match value with
    | Known v ->
        let v = match v,name with
          | V.Record xs, name -> (match List.assoc_opt name xs with Some v -> v | None -> refuse "get")
          | Vec3 (x,_,_),"x" -> V.Float x | Vec3 (_,y,_),"y" -> Float y
          | Vec3 (_,_,z),"z" -> Float z
          | _ -> refuse "get" in Known v
    | Computed (n,value_ty) ->
        let ty = match value_ty with
          | Flow.Ty.Vec2 | Vec3 | Vec4 -> Flow.Ty.Float
          | Record fields -> Option.value ~default:ty (List.assoc_opt name fields)
          | _ -> ty in
        emit statements source ty (Field (n,name)) in
  let primitive_of_name name =
    match Flow.Packed_ops.binary name with Some op -> Some (C.Numeric op) | None ->
    match Flow.Packed_ops.unary name with Some op -> Some (C.Math op) | None ->
    match name with
    | "exp" -> Some C.Exp | "floor" -> Some Floor | "ceil" -> Some Ceil | "round" -> Some Round
    | "int" -> Some Int_convert | "float" -> Some Float_convert | "equal?" -> Some Equal
    | "int/mul" -> Some (Integer Mul) | "int/div" -> Some (Integer Div) | "int/mod" -> Some (Integer Mod)
    | "int/and" -> Some (Integer And) | "int/xor" -> Some (Integer Xor)
    | "array/range" -> Some Array_range | "array/float" -> Some Array_float | "array/vec3" -> Some Array_vec3
    | "array/nth" -> Some Array_nth | "array/count" -> Some Array_count | "array/slice" -> Some Array_slice
    | "array/concat" -> Some Array_concat | "value/rand" -> Some Rand
    | "nth" -> Some Sequence_get | "count" -> Some Sequence_length | _ -> None in
  let rec residual statements cache r =
    let id = E.Private.residual_id r in
    match Hashtbl.find_opt cache id with Some value -> value | None ->
    let view = E.Private.residual_view r in
    if view.previous then refuse "state";
    if Hashtbl.mem active id then refuse "cycle";
    Hashtbl.add active id ();
    Fun.protect ~finally:(fun () -> Hashtbl.remove active id) (fun () ->
      let env = Names.of_seq (List.to_seq (List.map (fun (name,v) -> name,Known v) view.bindings)) in
      let source : C.source = {site=view.site;owner=view.owner;instance=view.instance;iter=view.iter;span=None} in
      let value = term statements cache source env view.term in
      Hashtbl.add cache id value;
      value)
  and term statements cache source env (x : W.term) =
    decr budget; if !budget < 0 then refuse "budget";
    let source = {source with C.site=Option.value x.path ~default:source.site;span=Some x.form.span} in
    let compile = term statements cache source env in
    match x.node with
    | W.Lit (Param.Int_value n) -> Known (V.Int n)
    | Lit (Param.Float_value f) -> Known (V.Float f)
    | Lit (Param.Bool_value b) -> Known (V.Bool b)
    | Text s -> Known (V.Text s) | Nil -> Known V.No_geo
    | Time -> emit statements source Flow.Ty.Float (Frame Time)
    | Vec [a;b;c] ->
        let args = List.map compile [a;b;c] in
        (match args with
        | [Known a;Known b;Known c] -> Known (V.Vec3 (V.num a,V.num b,V.num c))
        | _ -> emit statements source x.ty (Vec (List.map (ensure statements source) args)))
    | Ref_binding (name,_) when String.starts_with ~prefix:"$elem:" name -> refuse "element"
    | Ref_binding (name,fields) ->
        let start = match Names.find_opt name env with Some (Known (V.Residual r)) -> residual statements cache r
          | Some v -> v | None -> refuse "binding" in
        List.fold_left (fun v name -> field statements source x.ty v name) start fields
    | Op {op;args;_} ->
        let o = match Flow.Op.find op Flow.Context.value with
          | Some o when o.ctx=Flow.Context.value && o.shape=Flow.Op.Scalar -> o | _ -> refuse op in
        let args = List.map (fun (n,t) -> n,compile t) args in
        (match known_values args with
        | Some values when not o.live ->
            Known (o.body ~live:(Frame_input.at_time 0.) ~node:(fun _ _ -> refuse op) values)
        | _ -> operation statements source x.ty op args)
    | Let (bindings,body) ->
        let env = List.fold_left (fun env (pattern,value) ->
          match pattern,term statements cache source env value with
          | W.Name name,(Known _ as v) -> Names.add name v env | _ -> refuse "let*") env bindings in
        term statements cache source env body
    | If (condition,yes,no) ->
        (match compile condition with
        | Known v -> compile (if V.truthy v then yes else no)
        | condition ->
            let condition = ensure statements source condition in
            let id = number () and result = local x.ty in
            let branch t =
              let body = ref [] in
              let value = ensure body source (term body (Hashtbl.copy cache) source env t) in
              body := statement (number ()) source (Assign (result,Local value)) :: !body;
              List.rev !body in
            let yes = branch yes in let no = branch no in
            statements := statement id source (If {condition;yes;no}) :: !statements;
            Computed (result,x.ty))
    | Loop {kind=(`For|`Sum) as kind;accs=[];clauses=[W.Name name,items];skip=[];body;_} ->
        let items = match compile items with Known (V.List xs) when Array.length xs <= 4096 -> xs
          | _ -> refuse (if kind=`For then "for" else "sum") in
        let values = Array.mapi (fun index item ->
          let source={source with C.iter=source.iter @ [index]} in
          term statements cache source (Names.add name (Known item) env) body) items in
        if Array.for_all (function Known _ -> true | _ -> false) values then
          let values = Array.map (function Known v -> v | _ -> assert false) values in
          Known (if kind=`For then
            let ty=V.elem_ty values in V.List (Array.map (V.coerce_to ty) values)
            else if Array.length values=0 then V.Int 0
            else Array.fold_left (V.arith "sum" ( +. )) values.(0) (Array.sub values 1 (Array.length values-1)))
        else if kind=`For then
          emit statements source x.ty (Items (Array.to_list (Array.map (ensure statements source) values)))
        else if Array.length values=0 then Known (V.Int 0)
        else Array.fold_left (fun acc v -> primitive statements source x.ty (Numeric Add) ["a",acc;"b",v])
          values.(0) (Array.sub values 1 (Array.length values-1))
    | node -> refuse (match node with
        | Vec _ -> "vector" | Lit _ -> "literal" | Call _ -> "call" | Call_fn _ -> "call_fn"
        | Fn_ref _ -> "fn_ref" | Graph_ref _ -> "ref" | State _ -> "state" | Loop {kind;_} ->
            (match kind with `For -> "for" | `Sum -> "sum" | `Fold -> "fold" | `Scan -> "scan")
        | Cond _ -> "cond" | Case _ -> "case" | Fn _ -> "fn" | Hof _ -> "higher_order"
        | List_lit _ -> "list" | Record _ -> "record" | Get _ -> "get" | Assoc _ -> "assoc"
        | Str _ -> "str" | List_op _ -> "list_op" | Bypass _ -> "bypass" | Expanded _ -> "expanded"
        | _ -> assert false)
  and operation statements source ty name args =
    let prim ty op args = primitive statements source ty op args in
    let arg key = List.assoc key args in
    let float v = prim Flow.Ty.Float Float_convert ["x",v] in
    let calc op a b = prim Flow.Ty.Float (Numeric op) ["a",a;"b",b] in
    let vec components = emit statements source Flow.Ty.Vec3 (Vec (List.map (ensure statements source) components)) in
    match primitive_of_name name with
    | Some op -> prim ty op args
    | None -> match name with
      | "exact" -> arg "value"
      | "frame/dt" -> emit statements source ty (Frame Dt)
      | "frame/width" -> emit statements source ty (Frame Width)
      | "frame/height" -> emit statements source ty (Frame Height)
      | "frame/index" -> emit statements source ty (Frame Index)
      | "frame/input" -> emit statements source ty (Frame Input)
      | "pointer/x" -> emit statements source ty (Frame Pointer_x)
      | "pointer/y" -> emit statements source ty (Frame Pointer_y)
      | "value/lerp" ->
          let u = float (arg "u") in
          let inverse = calc Sub (Known (V.Float 1.)) u in
          let blend a b = let left=calc Mul a inverse in let right=calc Mul b u in calc Add left right in
          if ty=Flow.Ty.Vec3 then
            let component v name =
              match v with Known (V.Vec3 _) -> field statements source Flow.Ty.Float v name
              | Known _ -> float v
              | Computed (_,Flow.Ty.Vec3) ->
                  field statements source Flow.Ty.Float v name
              | _ -> float v in
            vec (List.map (fun name -> let a=component (arg "a") name in let b=component (arg "b") name in blend a b) ["x";"y";"z"])
          else let a=float (arg "a") in let b=float (arg "b") in blend a b
      | "value/polar" ->
          let r=float (arg "radius") in let a=float (arg "angle") in
          let cosine=prim Flow.Ty.Float (Math Cos) ["x",a] in
          let sine=prim Flow.Ty.Float (Math Sin) ["x",a] in
          let x=calc Mul r cosine in let z=calc Mul r sine in
          vec [x;Option.value ~default:(Known (V.Float 0.)) (List.assoc_opt "height" args);z]
      | "length" ->
          let components=List.map (field statements source Flow.Ty.Float (arg "vector")) ["x";"y";"z"] in
          let squares=List.map (fun v -> calc Mul v v) components in
          (match squares with [x;y;z] ->
            let xy=calc Add x y in let sum=calc Add xy z in prim Flow.Ty.Float (Math Sqrt) ["x",sum]
          | _ -> assert false)
      | _ -> refuse name in
  try
    let body = ref [] in
    let result = residual body (Hashtbl.create 16) root in
    let view = E.Private.residual_view root in
    let source : C.source = {site=view.site;owner=view.owner;instance=view.instance;iter=view.iter;span=Some view.term.form.span} in
    let result = ensure body source result in
    Ok {C.constants=Array.of_list (List.rev !constants);locals=Array.of_list (List.rev !locals);
      body=List.rev !body;results=[|result|];state_slots=[||];regions=[||]}
  with Unsupported name -> Error name
    | V.Fail _ | Not_found | Invalid_argument _ | Failure _ -> Error "constant"
