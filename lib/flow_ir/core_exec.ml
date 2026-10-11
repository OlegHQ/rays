module C = Core
module V = Flow.Value
module E = Flow.Eval
let run ?root ?force program ~live =
  let values = Array.make (Array.length program.C.locals) Flow.Eval.No_geo in
  let builders = Array.make (Array.length program.C.locals) None in
  let calls = Array.make program.call_slots 0 in
  let get n = values.(n) in
  let seal n = Option.iter (fun writable -> writable:=false) builders.(n) in
  let apply name args = match Flow.Op.find ~extra:Operators.all name Flow.Context.value with
    | Some op -> op.body ~live ~node:(fun _ _ -> V.fail "E_CORE" "Core primitives cannot create catalog nodes.") args
    | None -> V.fail "E_CORE" ("Unsupported core primitive: " ^ name) in
  let primitive op args =
    let first () = snd (List.hd args) in
    match op with
    | C.Coerce ty -> V.coerce_to ty (first ())
    | Truthy -> V.Bool (V.truthy (first ()))
    | Show -> V.Text (V.show_with Fun.id (first ()))
    | Text_concat -> V.Text (String.concat "" (List.map (function _,V.Text s -> s
        | _ -> V.fail "E_TYPE" "Expected text.") args))
    | Fail (code,message) -> V.fail code message
    | Remainder -> V.Float (V.fin "remainder" (Float.rem (V.num (List.assoc "a" args)) (V.num (List.assoc "b" args))))
    | Sequence_get -> apply "nth" args | Sequence_length -> apply "count" args
    | Sequence_build ->
        let count=V.int_of (List.assoc "count" args) in
        if count<0 || count>4096 then V.fail "E_ITER_BOUND" "Core list length exceeds its bound.";
        V.List (Array.make count V.No_geo)
    | Sequence_slice ->
        let xs=V.list_arg (List.assoc "list" args) in
        let first=V.int_of (List.assoc "first" args) and count=V.int_of (List.assoc "count" args) in
        if first<0 || count<0 || first>Array.length xs || count>Array.length xs-first then
          V.fail "E_LIST_RANGE" "A list slice must be within its source.";
        V.List (Array.sub xs first count)
    | Sequence_concat ->
        let arrays=List.map (fun (_,v) -> V.list_arg v) args in
        let count=List.fold_left (fun n xs -> if Array.length xs>4096-n then
          V.fail "E_ITER_BOUND" "Core concatenation exceeds 4,096 values."; n+Array.length xs) 0 arrays in
        let xs=Array.make count V.No_geo and at=ref 0 in
        List.iter (fun part -> Array.blit part 0 xs !at (Array.length part);at:= !at+Array.length part) arrays;
        let ty=V.elem_ty xs in V.List (Array.map (V.coerce_to ty) xs)
    | Color_parse ->
        let c=Operators.drawing_color (first ()) in
        V.Record ["r",Int c.r;"g",Int c.g;"b",Int c.b;"a",Int c.a]
    | Color_byte mode ->
        let f=V.fin "color" (V.num (first ())) in
        let f=match mode with C.Clamped -> max 0. (min 1. f) | Unclamped -> f in
        V.Int (max 0 (min 255 (int_of_float (f *. 255. +. 0.5))))
    | _ -> apply (C.primitive_name op) args in
  let expression = function
    | C.Constant n -> C.value_of_literal program.constants.(n)
    | Local n -> get n
    | Call_index slot -> let n=calls.(slot) in calls.(slot)<-n+1; V.Int n
    | Frame field ->
        (match field with C.Time -> V.Float live.t | Tick -> V.Int live.tick
        | Dt -> apply "frame/dt" [] | Index -> apply "frame/index" []
        | Width -> apply "frame/width" [] | Height -> apply "frame/height" []
        | Pointer_x -> apply "pointer/x" [] | Pointer_y -> apply "pointer/y" [] | Input -> apply "frame/input" [])
    | Prim (op,args) ->
        (match op with C.Sequence_get | Sequence_length | Sequence_build -> ()
         | _ -> List.iter (fun (_,n) -> seal n) args);
        primitive op (List.map (fun (name,n) -> name,get n) args)
    | Vec ns -> (match List.map (fun n -> V.num (get n)) ns with
        | [x;y] -> V.Vec2 (x,y) | [x;y;z] -> V.Vec3 (x,y,z) | [x;y;z;w] -> V.Vec4 (x,y,z,w)
        | _ -> V.fail "E_CORE" "Invalid vector width.")
    | Fields xs -> V.Record (List.map (fun (name,n) -> seal n;name,get n) xs)
    | Items ns ->
        let xs=Array.of_list (List.map (fun n -> seal n;get n) ns) in
        if Array.length xs>4096 then V.fail "E_ITER_BOUND" "Core list exceeds 4,096 values.";
        let ty=V.elem_ty xs in V.List (Array.map (V.coerce_to ty) xs)
    | Field (n,name) -> match get n,name with
        | V.Vec2 (x,_),"x" | Vec2 (_,x),"y"
        | Vec3 (x,_,_),"x" | Vec3 (_,x,_),"y" | Vec3 (_,_,x),"z"
        | Vec4 (x,_,_,_),"x" | Vec4 (_,x,_,_),"y" | Vec4 (_,_,x,_),"z" | Vec4 (_,_,_,x),"w" -> V.Float x
        | Record xs,name -> (match List.assoc_opt name xs with Some v -> v | None -> V.fail "E_FIELD" "Missing core field.")
        | _ -> V.fail "E_FIELD" "Invalid core field." in
  let state_root () = match root with Some r -> r
    | None -> V.fail "E_CORE_STATE" "Core state needs its residual's state." in
  let slot_key n =
    let s=program.C.state_slots.(n) in
    s.source.instance,s.prefix @ s.zone,
    List.map (function C.Static_index i -> i | Local_index l -> V.int_of (get l)) s.source.iter,
    s.plane=`Host in
  let rec execute statements =
    List.iter (fun (s : C.statement) ->
      try match s.node with
      | Assign (n,e) ->
          let value=expression e in
          builders.(n)<-(match e with Prim (Sequence_build,_) -> Some (ref true)
            | Local old -> builders.(old) | _ -> None);
          values.(n)<-value
      | Reset_call slot -> calls.(slot)<-0
      | If {condition;yes;no} -> execute (if V.truthy (get condition) then yes else no)
      | Iterate {sequence;index;item;limit;body} ->
          let source=get sequence in
          let count=match source with V.List xs -> Array.length xs | source -> V.array_length source in
          if count>limit then V.fail "E_ITER_BOUND" "Core iteration exceeds its bound.";
          for i=0 to count-1 do
            values.(index)<-V.Int i;
            values.(item)<-(match source with V.List xs -> xs.(i) | source -> V.array_get source i);
            execute body
          done
      | Counted {first;last;count;index;item;limit;init;body} ->
          let first=V.int_of (get first) and last=V.int_of (get last) in
          let length=max 0 (last-first) in
          if length>limit then V.fail "E_ITER_BOUND" "Core iteration exceeds its bound.";
          values.(count)<-V.Int length;
          execute init;
          for i=0 to length-1 do
            values.(index)<-V.Int i;
            values.(item)<-V.Int (first+i);
            execute body
          done
      | Store {sequence;index;value} ->
          if not (Option.fold ~none:false ~some:(fun writable -> !writable) builders.(sequence)) then
            V.fail "E_CORE_OWNERSHIP" "Core stores require an unpublished local builder.";
          let xs=V.list_arg (get sequence) and i=V.int_of (get index) in
          if i<0 || i>=Array.length xs then V.fail "E_LIST_RANGE" "Core store is outside its sequence.";
          seal value;
          xs.(i)<-get value
      | State_read {slot;result;init;initial} ->
          let instance,path,iter,host=slot_key slot in
          builders.(result)<-None;
          values.(result)<-E.Private.state_read (state_root ()) ~instance ~path ~iter ~host
            ~init:(fun () -> execute init; get initial)
      | State_peek {slot;found;value} ->
          let instance,path,iter,host=slot_key slot in
          let pending=E.Private.state_peek (state_root ()) ~instance ~path ~iter ~host in
          values.(found)<-V.Bool (Option.is_some pending);
          values.(value)<-Option.value ~default:V.No_geo pending
      | State_write {slot;value} ->
          let instance,path,iter,host=slot_key slot in
          seal value;
          values.(value)<-E.Private.state_write (state_root ()) ~instance ~path ~iter ~host (get value)
      | Invoke {region;result;_} ->
          let (C.Region_ref packed)=program.regions.(region) in
          builders.(result)<-None;
          (match (match force with Some force -> force packed | None -> Packed.force packed ~live) with
           | Ok v -> values.(result)<-v
           | Error (d : Flow.Diagnostic.t) -> raise (V.Fail (d.code,d.message,d.span)))
      with V.Fail (code,message,None) -> raise (V.Fail (code,message,s.source.span))) statements in
  match Frame_input.validate live with
  | Error message -> Error (Flow.Diagnostic.error ~code:"E_FRAME" message)
  | Ok () ->
      try execute program.body;
        if Array.length program.results<>1 then V.fail "E_CORE" "Expected one core result.";
        Ok (get program.results.(0))
      with V.Fail (code,message,span) -> Error (Flow.Diagnostic.error ?span ~code message)
        | Not_found | Invalid_argument _ | Failure _ -> Error (Flow.Diagnostic.error ~code:"E_CORE" "Invalid core program.")
