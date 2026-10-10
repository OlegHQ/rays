module E = Flow.Eval
module W = Flow.Workspace
module V = Flow.Value
module C = Core
module Names = Map.Make (String)
exception Unsupported of string
let refuse name = raise (Unsupported name)
type lowered = Known of E.value | Computed of int * Flow.Ty.t
  | Record_fields of (string * lowered) list
  | Record_choice of lowered * lowered * lowered | Callable of callable
and callable =
  | Closure of { params : (W.pattern * Flow.Ty.t option) list; body : W.term;
      env : lowered Names.t; instance : int; prefix : W.path; zone : W.path; identity : int }
  | Named of { name : string; identity : int }

let lower root =
  let constants = ref [] and locals = ref [] and next_constant = ref 0
  and next_local = ref 0 and next_statement = ref 0 in
  let budget = ref 2048 and active = Hashtbl.create 8 in
  let calls = Hashtbl.create 8 and next_call = ref 0 and next_function = ref (-1) in
  let mixed_numeric = Hashtbl.create 8 in
  let new_identity () = let n= !next_function in decr next_function; n in
  let call_slot identity = match Hashtbl.find_opt calls identity with
    | Some n -> n | None -> let n= !next_call in incr next_call; Hashtbl.add calls identity n; n in
  let local ty = let n = !next_local in incr next_local; locals := ty :: !locals; n in
  let number () = let n = !next_statement in incr next_statement; n in
  let statement id source node : C.statement = {id;source;node} in
  let emit statements source ty expression =
    let n = local ty in
    if ty=Flow.Ty.Float && (match expression with
      | C.Prim (Numeric _,_) | Prim (Sequence_get,_) | Field _ -> true
      | Local old -> Hashtbl.mem mixed_numeric old | _ -> false) then
      Hashtbl.add mixed_numeric n ();
    statements := statement (number ()) source (Assign (n,expression)) :: !statements;
    Computed (n,ty) in
  let rec ensure statements cache source = function
    | Computed (n,_) -> n
    | Callable _ -> refuse "fn"
    | Known (V.Residual r) -> ensure statements cache source (residual statements cache r)
    | Known (V.Record fields) -> ensure statements cache source (Record_fields (List.map (fun (name,v) -> name,Known v) fields))
    | Record_choice (condition,yes,no) as value ->
        let condition=ensure statements cache source condition in
        let id=number () and result=local (type_of value) in
        let arm value =
          let body=ref [] and cache=Hashtbl.copy cache in
          let n=ensure body cache source value in
          body:=statement (number ()) source (Assign (result,Local n)) :: !body;
          List.rev !body in
        let yes=arm yes in let no=arm no in
        statements:=statement id source (If {condition;yes;no}) :: !statements;
        result
    | Record_fields fields ->
        let ty=Flow.Ty.Record (List.map (fun (name,v) -> name,type_of v) fields) in
        let fields=List.map (fun (name,v) -> name,ensure statements cache source v) fields in
        (match emit statements source ty (Fields fields) with Computed (n,_) -> n | _ -> assert false)
    | Known value ->
        let value_literal = match C.literal_of_value value with Some v -> v | None -> refuse "capture" in
        let index = !next_constant in incr next_constant; constants := value_literal :: !constants;
        match emit statements source (V.ty_of value) (Constant index) with Computed (n,_) -> n | _ -> assert false
  and primitive statements cache source ty op args =
    let args = List.map (fun (name,v) -> name,ensure statements cache source v) args in
    emit statements source ty (Prim (op,args))
  and known_values args =
    let rec all = function [] -> Some [] | (name,Known v)::xs when C.literal_of_value v <> None ->
      Option.map (fun xs -> (name,v)::xs) (all xs) | _ -> None in all args
  and field statements cache source ty value name = match resolve statements cache value with
    | Record_choice (condition,yes,no) as value ->
        let ty=match type_of value with Flow.Ty.Record fields ->
          Option.value ~default:ty (List.assoc_opt name fields) | _ -> ty in
        branch statements cache source ty condition
          (fun body cache -> field body cache source ty yes name)
          (fun body cache -> field body cache source ty no name)
    | Record_fields fields -> (match List.assoc_opt name fields with
        | Some v -> resolve statements cache v | None -> refuse "get")
    | Known v ->
        let v = match v,name with
          | V.Record xs, name -> (match List.assoc_opt name xs with Some v -> v | None -> refuse "get")
          | Vec2 (x,_),"x" -> V.Float x | Vec2 (_,y),"y" -> Float y
          | Vec3 (x,_,_),"x" -> V.Float x | Vec3 (_,y,_),"y" -> Float y
          | Vec3 (_,_,z),"z" -> Float z
          | Vec4 (x,_,_,_),"x" -> V.Float x | Vec4 (_,y,_,_),"y" -> Float y
          | Vec4 (_,_,z,_),"z" -> Float z | Vec4 (_,_,_,w),"w" -> Float w
          | _ -> refuse "get" in resolve statements cache (Known v)
    | Callable _ -> refuse "get"
    | Computed (n,value_ty) ->
        let ty = match value_ty with
          | Flow.Ty.Vec2 | Vec3 | Vec4 -> Flow.Ty.Float
          | Record fields -> Option.value ~default:ty (List.assoc_opt name fields)
          | _ -> ty in
        emit statements source ty (Field (n,name))
  and coerce statements cache source ty = function
    | Record_choice _ as value -> map_fields statements cache source value (fun body cache fields ->
        match coerce body cache source ty (Record_fields fields) with
        | Record_fields fields -> fields | _ -> fields)
    | Known value ->
        (try Known (V.coerce_to ty value)
         with V.Fail (code,message,_) -> primitive statements cache source ty (Fail (code,message)) [])
    | Record_fields fields as v -> (match ty with
        | Flow.Ty.Any -> v
        | Record wanted -> Record_fields (List.map (fun (name,v) -> name,
            match List.assoc_opt name wanted with
            | Some ty -> coerce statements cache source ty v | None -> v) fields)
        | _ -> v)
    | Callable _ as v when Flow.Ty.has_fn ty || ty=Flow.Ty.Any -> v
    | Callable _ -> refuse "fn"
    | Computed (n,have) as v when ty=Flow.Ty.Any || have=ty && not (Hashtbl.mem mixed_numeric n) -> v
    | value -> primitive statements cache source ty (Coerce ty) ["value",value]
  and source_of_view (view : E.Private.residual_view) : C.source =
    {site=List.filteri (fun i _ -> i >= List.length view.prefix) view.site;
     owner=view.owner;instance=view.instance;prefix=view.prefix;
     iter=List.map (fun n -> C.Static_index n) view.iter;span=None}
  and type_of = function
    | Known (V.Residual r) -> (E.Private.residual_view r).term.ty
    | Known v -> V.ty_of v | Computed (_,ty) -> ty | Callable _ -> Flow.Ty.Fn None
    | Record_fields fields -> Flow.Ty.Record (List.map (fun (name,v) -> name,type_of v) fields)
    | Record_choice (_,yes,no) -> Option.value ~default:Flow.Ty.Any (Flow.Ty.join (type_of yes) (type_of no))
  and primitive_of_name name =
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
    | "nth" -> Some Sequence_get | "count" -> Some Sequence_length | _ -> None
  and residual statements cache r =
    let id = E.Private.residual_id r in
    match Hashtbl.find_opt cache id with Some value -> value | None ->
    let view = E.Private.residual_view r in
    if view.previous then refuse "state";
    if Hashtbl.mem active id then refuse "cycle";
    Hashtbl.add active id ();
    Fun.protect ~finally:(fun () -> Hashtbl.remove active id) (fun () ->
      let env = Names.of_seq (List.to_seq (List.map (fun (name,v) -> name,Known v) view.bindings)) in
      let source = source_of_view view in
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
    | Record fields -> Record_fields (List.map (fun (name,t) -> name,compile t) fields)
    | Get (value,name) -> field statements cache source x.ty (compile value) name
    | Assoc (record,updates) ->
        let record=compile record in
        List.fold_left (fun record (name,t) ->
          let value=compile t in
          map_fields statements cache source record (fun body cache fields ->
            match List.assoc_opt name fields with
            | Some old ->
                let value=coerce_like body cache source old value in
                List.map (fun (n,v) -> n,if n=name then value else v) fields
            | None -> fields @ [name,value])) record updates
    | Str ts ->
        let values=List.map compile ts in
        let texts=List.map (fun value -> match value with
          | Known v when C.literal_of_value v <> None -> Known (V.Text (V.show_with Fun.id v))
          | _ -> primitive statements cache source Flow.Ty.Text Show ["value",value]) values in
        (match known_values (List.map (fun v -> "",v) texts) with
         | Some texts -> Known (V.Text (String.concat "" (List.map (fun (_,v) -> match v with V.Text s -> s | _ -> assert false) texts)))
         | None -> primitive statements cache source Flow.Ty.Text Text_concat (List.map (fun v -> "part",v) texts))
    | Time -> emit statements source Flow.Ty.Float (Frame Time)
    | Vec ts when List.length ts >= 2 && List.length ts <= 4 ->
        let args = List.map compile ts in
        (match known_values (List.map (fun v -> "",v) args) with
        | Some values -> Known (C.value_of_literal (Vector (Array.of_list (List.map (fun (_,v) -> V.num v) values))))
        | _ -> emit statements source x.ty (Vec (List.map (ensure statements cache source) args)))
    | Ref_binding (name,_) when String.starts_with ~prefix:"$elem:" name -> refuse "element"
    | Ref_binding (name,fields) ->
        let start = match Names.find_opt name env with Some v -> resolve statements cache v | None -> refuse "binding" in
        List.fold_left (fun v name -> field statements cache source x.ty v name) start fields
    | Op {op;args;_} ->
        let o = match Flow.Op.find ~extra:(E.Private.residual_ops root) op Flow.Context.value with
          | Some o when o.ctx=Flow.Context.value && o.shape=Flow.Op.Scalar -> o | _ -> refuse op in
        let args = List.map (fun (n,t) -> n,compile t) args in
        (match known_values args with
        | Some values when not o.live ->
            (try Known (o.body ~live:(Frame_input.at_time 0.) ~node:(fun _ _ -> refuse op) values)
             with V.Fail (code,message,_) -> primitive statements cache source x.ty (Fail (code,message)) [])
        | _ -> operation statements cache source x.ty op args)
    | Let (bindings,body) ->
        let env = List.fold_left (fun env (pattern,value) ->
          let value=term statements cache source env value in
          bind statements cache source env pattern value) env bindings in
        term statements cache source env body
    | If (condition,yes,no) ->
        branch statements cache source x.ty (compile condition)
          (fun body cache -> term body cache source env yes)
          (fun body cache -> term body cache source env no)
    | Cond (arms,default) ->
        let rec arms_lower statements cache = function
          | [] -> term statements cache source env default
          | (condition,value)::rest ->
              let condition=term statements cache source env condition in
              branch statements cache source x.ty condition
                (fun body cache -> term body cache source env value)
                (fun body cache -> arms_lower body cache rest) in
        arms_lower statements cache arms
    | Case (scrutinee,arms,default) ->
        let scrutinee=compile scrutinee in
        let rec arms_lower statements cache = function
          | [] -> term statements cache source env default
          | (lit,value)::rest ->
              let lit : E.value = match lit.Flow.Syntax.node with
                | Str s -> V.Text s | Sym s -> Bool (s="true")
                | Num s -> (match if String.contains s '.' then None else int_of_string_opt s with
                    | Some n -> Int n | None -> Float (float_of_string s))
                | _ -> refuse "case" in
              let condition=match scrutinee with
                | Known sv ->
                    let boolean=function V.Bool b -> b | v -> V.num v <> 0. in
                    Known (V.Bool (match sv,lit with
                      | Bool _,_ | _,Bool _ -> boolean sv=boolean lit
                      | Text a,Text b -> a=b
                      | (Int _|Float _),(Int _|Float _) -> V.num sv=V.num lit | _ -> false))
                | _ when type_of scrutinee=Flow.Ty.Bool || V.ty_of lit=Flow.Ty.Bool ->
                    let a=primitive statements cache source Flow.Ty.Bool Truthy ["value",scrutinee] in
                    let b=Known (V.Bool (V.truthy lit)) in
                    primitive statements cache source Flow.Ty.Bool Equal ["a",a;"b",b]
                | _ when List.mem (type_of scrutinee) [Flow.Ty.Int;Float]
                    && List.mem (V.ty_of lit) [Flow.Ty.Int;Float] ->
                    primitive statements cache source Flow.Ty.Bool (Numeric Eq) ["a",scrutinee;"b",Known lit]
                | _ -> primitive statements cache source Flow.Ty.Bool Equal ["a",scrutinee;"b",Known lit] in
              branch statements cache source x.ty condition
                (fun body cache -> term body cache source env value)
                (fun body cache -> arms_lower body cache rest) in
        arms_lower statements cache arms
    | Call_fn {fn;args;body} ->
        let values=List.map compile args in
        (match Names.find_opt fn env with
        | Some f -> call statements cache source x.ty body (as_callable source f) values
        | None -> definition statements cache source fn body values)
    | Fn_ref name ->
        let identity=new_identity () in
        statements := statement (number ()) source (Reset_call (call_slot identity)) :: !statements;
        Callable (Named {name;identity})
    | Fn {params;body;zone;capture} ->
        let closure=match capture with
          | Some original -> (match as_callable source (compile original) with
              | Closure cl -> Closure {cl with params;body}
              | Named n -> Closure {params;body;zone;env=Names.empty;instance=source.instance;
                  prefix=source.prefix;identity=n.identity})
          | None ->
              let identity=new_identity () in
              statements := statement (number ()) source (Reset_call (call_slot identity)) :: !statements;
              Closure {params;body;zone;env;instance=source.instance;prefix=source.prefix;identity} in
        Callable closure
    | Expanded {body;_} -> compile body
    | Bypass inner ->
        (match W.bypass_input inner with Some input -> coerce statements cache source inner.ty (compile input)
          | None -> refuse "bypass")
    | Loop {kind=(`For|`Sum) as kind;accs=[];clauses=[W.Name name,items];skip=[];body;_} ->
        let items = match compile items with Known (V.List xs) when Array.length xs <= 4096 -> xs
          | _ -> refuse (if kind=`For then "for" else "sum") in
        let values = Array.mapi (fun index item ->
          let source={source with C.iter=source.iter @ [Static_index index]} in
          term statements cache source (Names.add name (Known item) env) body) items in
        if Array.for_all (function Known _ -> true | _ -> false) values then
          let values = Array.map (function Known v -> v | _ -> assert false) values in
          Known (if kind=`For then
            let ty=V.elem_ty values in V.List (Array.map (V.coerce_to ty) values)
            else if Array.length values=0 then V.Int 0
            else Array.fold_left (V.arith "sum" ( +. )) values.(0) (Array.sub values 1 (Array.length values-1)))
        else if kind=`For then
          emit statements source x.ty (Items (Array.to_list (Array.map (ensure statements cache source) values)))
        else if Array.length values=0 then Known (V.Int 0)
        else Array.fold_left (fun acc v -> primitive statements cache source x.ty (Numeric Add) ["a",acc;"b",v])
          values.(0) (Array.sub values 1 (Array.length values-1))
    | node -> refuse (match node with
        | Vec _ -> "vector" | Lit _ -> "literal" | Call _ -> "call"
        | Graph_ref _ -> "ref" | State _ -> "state" | Loop {kind;_} ->
            (match kind with `For -> "for" | `Sum -> "sum" | `Fold -> "fold" | `Scan -> "scan")
        | Hof _ -> "higher_order"
        | List_lit _ -> "list" | List_op _ -> "list_op"
        | _ -> assert false)
  and resolve statements cache = function
    | Known (V.Residual r) -> residual statements cache r | v -> v
  and record_fields statements cache source value =
    match resolve statements cache value with
    | Record_fields fields -> fields
    | Known (V.Record fields) -> List.map (fun (name,v) -> name,Known v) fields
    | Computed (_,Flow.Ty.Record fields) as value ->
        List.map (fun (name,ty) -> name,field statements cache source ty value name) fields
    | _ -> refuse "record"
  and map_fields statements cache source value f =
    match resolve statements cache value with
    | Record_choice (condition,yes,no) -> branch statements cache source (type_of value) condition
        (fun body cache -> map_fields body cache source yes f)
        (fun body cache -> map_fields body cache source no f)
    | value -> Record_fields (f statements cache (record_fields statements cache source value))
  and coerce_like statements cache source old value =
    let old=resolve statements cache old and value=resolve statements cache value in
    match old,value with
    | Known old,Known value when C.literal_of_value old <> None && C.literal_of_value value <> None ->
        coerce statements cache source (V.ty_of old) (Known value)
    | _ when (match type_of old,type_of value with Flow.Ty.Record _,Record _ -> true | _ -> false) ->
        let old_fields=match type_of old with Flow.Ty.Record fs -> fs | _ -> assert false in
        map_fields statements cache source value (fun body cache fields ->
          List.map (fun (name,v) -> name,match List.assoc_opt name old_fields with
            | Some ty -> coerce_like body cache source (field body cache source ty old name) v
            | None -> v) fields)
    | Known old,_ -> coerce statements cache source (V.ty_of old) value
    | _ when type_of old=Flow.Ty.Float && List.mem (type_of value) [Flow.Ty.Int;Float;Bool] ->
        let is_float=primitive statements cache source Flow.Ty.Bool Equal
          ["a",old;"b",coerce statements cache source Flow.Ty.Float old] in
        branch statements cache source Flow.Ty.Float is_float
          (fun body cache -> coerce body cache source Flow.Ty.Float value)
          (fun body cache -> coerce body cache source Flow.Ty.Int value)
    | _ -> coerce statements cache source (type_of old) value
  and branch statements cache source ty condition yes no =
    match condition with
    | Known v -> (if V.truthy v then yes else no) statements cache
    | condition ->
        let condition=ensure statements cache source condition in
        let id=number () in
        if (match ty with Flow.Ty.Record _ -> false | _ -> true) then begin
          let result=local ty in
          if ty=Flow.Ty.Float then Hashtbl.add mixed_numeric result ();
          let arm lower =
            let body=ref [] and cache=Hashtbl.copy cache in
            let value=ensure body cache source (lower body cache) in
            body:=statement (number ()) source (Assign (result,Local value)) :: !body;
            List.rev !body in
          let yes=arm yes in let no=arm no in
          statements:=statement id source (If {condition;yes;no}) :: !statements;
          Computed (result,ty)
        end else begin
          let yes_body=ref [] and no_body=ref [] in
          let yes_cache=Hashtbl.copy cache and no_cache=Hashtbl.copy cache in
          let a=yes yes_body yes_cache in let b=no no_body no_cache in
          let fields = function Record_fields fs -> Some fs
            | Known (V.Record fs) -> Some (List.map (fun (n,v) -> n,Known v) fs)
            | _ -> None in
          let rec join ty a b = match fields a,fields b with
            | Some fs,Some gs when List.map fst fs=List.map fst gs ->
                Record_fields (List.map2 (fun (name,a) (_,b) ->
                  let ty=Option.value ~default:Flow.Ty.Any (Flow.Ty.join (type_of a) (type_of b)) in
                  name,join ty a b) fs gs)
            | _ when (match ty with Flow.Ty.Record _ -> true | _ -> false) ->
                Record_choice (Computed (condition,Flow.Ty.Bool),a,b)
            | _ ->
                let result=local ty in
                if ty=Flow.Ty.Float then Hashtbl.add mixed_numeric result ();
                let assign body cache v =
                  let value=ensure body cache source v in
                  body:=statement (number ()) source (Assign (result,Local value)) :: !body in
                assign yes_body yes_cache a; assign no_body no_cache b;
                Computed (result,ty) in
          let result=join ty a b in
          statements:=statement id source (If {condition;yes=List.rev !yes_body;no=List.rev !no_body}) :: !statements;
          result
        end
  and bind statements cache source env pattern value =
    match pattern with
    | W.Name name -> Names.add name value env
    | Keys keys ->
        let value=resolve statements cache value in
        List.fold_left (fun env name -> Names.add name (field statements cache source Flow.Ty.Any value name) env) env keys
    | Seq patterns ->
        let value=resolve statements cache value in
        let parts=match value with
          | Known v -> (match v with
              | V.List xs -> Array.to_list (Array.map (fun v -> Known v) xs)
              | Vec2 (x,y) -> [Known (Float x);Known (Float y)]
              | Vec3 (x,y,z) -> [Known (Float x);Known (Float y);Known (Float z)]
              | Vec4 (x,y,z,w) -> [Known (Float x);Known (Float y);Known (Float z);Known (Float w)]
              | _ -> refuse "pattern")
          | Computed (_,ty) -> (match ty with
              | Flow.Ty.Vec2 | Vec3 | Vec4 ->
                  let fields=match ty with Flow.Ty.Vec2 -> ["x";"y"] | Vec3 -> ["x";"y";"z"] | _ -> ["x";"y";"z";"w"] in
                  List.map (field statements cache source Flow.Ty.Float value) fields
              | List elem ->
                  let count=primitive statements cache source Flow.Ty.Int Sequence_length ["list",value] in
                  let short=primitive statements cache source Flow.Ty.Bool (Numeric Lt)
                    ["a",count;"b",Known (V.Int (List.length patterns))] in
                  ignore (branch statements cache source Flow.Ty.Int short
                    (fun body _ -> primitive body cache source Flow.Ty.Int (Fail ("E_PATTERN","Not enough elements to destructure.")) [])
                    (fun _ _ -> Known (V.Int 0)));
                  List.mapi (fun index _ -> primitive statements cache source elem Sequence_get
                    ["list",value;"index",Known (V.Int index)]) patterns
              | _ -> refuse "pattern")
          | Callable _ | Record_fields _ | Record_choice _ -> refuse "pattern" in
        if List.length parts < List.length patterns then refuse "pattern";
        let rec bind_all env patterns parts = match patterns,parts with
          | [],_ -> env | p::ps,v::vs -> bind_all (bind statements cache source env p v) ps vs
          | _ -> refuse "pattern" in
        bind_all env patterns parts
  and as_callable source = function
    | Callable f -> f
    | Known (V.Fn f) ->
        let identity=E.Private.function_id f in
        (match E.Private.function_body f,E.Private.function_origin f with
        | Some (params,body),Some (instance,prefix,zone) ->
            let env=Names.of_seq (List.to_seq (List.map (fun (n,v) -> n,Known v) (E.Private.function_bindings f))) in
            Closure {params;body;env;instance;prefix;zone;identity}
        | _ -> (match E.Private.function_name f with Some name -> Named {name;identity} | None -> refuse "fn"))
    | _ -> ignore source; refuse "fn"
  and call statements cache source ty specialized fn values =
    let identity=match fn with Closure cl -> cl.identity | Named n -> n.identity in
    let index=ensure statements cache source (emit statements source Flow.Ty.Int (Call_index (call_slot identity))) in
    let source={source with C.iter=source.iter @ [Local_index index]} in
    match fn with
    | Closure cl ->
        if List.compare_lengths cl.params values <> 0 then refuse "call_fn";
        let source={source with C.instance=cl.instance;prefix=cl.prefix;site=cl.zone;owner=cl.zone} in
        let env=List.fold_left2 (fun env (pattern,ty) value ->
          let value=match ty with None -> value | Some ty -> coerce statements cache source ty value in
          bind statements cache source env pattern value) cl.env cl.params values in
        term statements cache source env (Option.value specialized ~default:cl.body)
    | Named n ->
        (match E.Private.residual_definition root n.name with
        | Some _ -> definition statements cache source n.name specialized values
        | None ->
            let o=match Flow.Op.find ~extra:(E.Private.residual_ops root) n.name Flow.Context.value with
              | Some o when o.ctx=Flow.Context.value && o.shape=Flow.Op.Scalar -> o | _ -> refuse n.name in
            let names=Array.of_list (List.map fst (o.signature.pos @ o.signature.opt)) in
            let args=List.mapi (fun i v -> (if i<Array.length names then names.(i) else
                match o.signature.rest with Some (n,_) -> n | None -> refuse n.name),v) values in
            match known_values args with
            | Some args when not o.live -> Known (o.body ~live:(Frame_input.at_time 0.) ~node:(fun _ _ -> refuse n.name) args)
            | _ -> operation statements cache source ty n.name args)
  and definition statements cache source name specialized values =
    let declaration=match E.Private.residual_definition root name with Some d -> d | None -> refuse "call_fn" in
    if List.compare_lengths declaration.inputs values <> 0 then refuse "call_fn";
    let zone=["def:"^name] in
    let source={source with C.prefix=source.prefix @ source.site;site=zone;owner=zone} in
    let env=List.fold_left2 (fun env (name,ty,_) value ->
      Names.add name (coerce statements cache source ty value) env) Names.empty declaration.inputs values in
    term statements cache source env (Option.value specialized ~default:declaration.body)
  and operation statements cache source ty name args =
    let prim ty op args = primitive statements cache source ty op args in
    let arg key = List.assoc key args in
    let float v = prim Flow.Ty.Float Float_convert ["x",v] in
    let calc op a b = prim Flow.Ty.Float (Numeric op) ["a",a;"b",b] in
    let vec components = emit statements source Flow.Ty.Vec3 (Vec (List.map (ensure statements cache source) components)) in
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
              match v with Known (V.Vec3 _) -> field statements cache source Flow.Ty.Float v name
              | Known _ -> float v
              | Computed (_,Flow.Ty.Vec3) ->
                  field statements cache source Flow.Ty.Float v name
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
          let components=List.map (field statements cache source Flow.Ty.Float (arg "vector")) ["x";"y";"z"] in
          let squares=List.map (fun v -> calc Mul v v) components in
          (match squares with [x;y;z] ->
            let xy=calc Add x y in let sum=calc Add xy z in prim Flow.Ty.Float (Math Sqrt) ["x",sum]
          | _ -> assert false)
      | _ -> refuse name in
  try
    let body = ref [] in
    let cache=Hashtbl.create 16 in
    let result = residual body cache root in
    let view = E.Private.residual_view root in
    let source = { (source_of_view view) with C.span=Some view.term.form.span } in
    let result = ensure body cache source result in
    Ok {C.constants=Array.of_list (List.rev !constants);locals=Array.of_list (List.rev !locals);
      body=List.rev !body;results=[|result|];state_slots=[||];regions=[||];call_slots= !next_call}
  with Unsupported name -> Error name
    | V.Fail _ | Not_found | Invalid_argument _ | Failure _ -> Error "constant"
