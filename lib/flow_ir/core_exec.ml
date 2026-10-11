module C = Core
module V = Flow.Value
module E = Flow.Eval

type state = {
  values : E.value array; builders : bool ref option array; calls : int array;
  live : Frame_input.t; root : E.residual option;
  force : (Packed.t -> (E.value, Flow.Diagnostic.t) result) option;
}
type prepared = { program : C.program; body : state -> unit }

let yes = V.Bool true and no = V.Bool false
let seal st n = Option.iter (fun writable -> writable:=false) st.builders.(n)

(* Resolved once per prepared program, not per executed statement. *)
let operator name = match Flow.Op.find ~extra:Operators.all name Flow.Context.value with
  | Some op -> op
  | None -> V.fail "E_CORE" ("Unsupported core primitive: " ^ name)
let apply_op op st args =
  op.Flow.Op.body ~live:st.live ~node:(fun _ _ -> V.fail "E_CORE" "Core primitives cannot create catalog nodes.") args

let generic_named name args =
  let op = lazy (operator name) in
  fun st -> apply_op (Lazy.force op) st (List.map (fun (n,i) -> n,st.values.(i)) args)

let primitive op args =
  let get st = List.map (fun (name,n) -> name,st.values.(n)) args in
  let first = match args with (_,n)::_ -> n | [] -> -1 in
  let seal_args = match op with C.Sequence_get | Sequence_length | Sequence_build -> false | _ -> true in
  let sealing st = if seal_args then List.iter (fun (_,n) -> seal st n) args in
  let a () = List.assoc "a" args and b () = List.assoc "b" args in
  let name = C.primitive_name op in
  let generic () =
    let op = lazy (operator name) in
    fun st -> apply_op (Lazy.force op) st (get st) in
  let body : state -> E.value = match op with
    | C.Coerce ty -> fun st -> V.coerce_to ty st.values.(first)
    | Truthy -> fun st -> V.Bool (V.truthy st.values.(first))
    | Show -> fun st -> V.Text (V.show_with Fun.id st.values.(first))
    | Text_concat -> fun st -> V.Text (String.concat "" (List.map (function _,V.Text s -> s
        | _ -> V.fail "E_TYPE" "Expected text.") (get st)))
    | Fail (code,message) -> fun _ -> V.fail code message
    | Remainder -> let a=a () and b=b () in
        fun st -> V.Float (V.fin "remainder" (Float.rem (V.num st.values.(a)) (V.num st.values.(b))))
    | Sequence_get -> generic_named "nth" args | Sequence_length -> generic_named "count" args
    | Sequence_build ->
        let count = List.assoc "count" args and width = List.assoc_opt "width" args in
        (* With a width the builder is packed storage, which has no list cap. *)
        fun st ->
          let count=V.int_of st.values.(count) in
          (match width with
           | None ->
               if count<0 || count>4096 then V.fail "E_ITER_BOUND" "Core list length exceeds its bound.";
               V.List (Array.make count V.No_geo)
           | Some width ->
               let width=V.int_of st.values.(width) in
               if count<0 || count>Sys.max_floatarray_length/width then
                 V.fail "E_ARRAY_RANGE" "Array length is outside native storage bounds.";
               let data=Array.make (count*width) 0. in
               (match width with 2 -> V.Vec2_array data | 3 -> Vec3_array data | 4 -> Vec4_array data
                | _ -> Float_array data))
    | Sequence_slice ->
        let list = List.assoc "list" args and first = List.assoc "first" args and count = List.assoc "count" args in
        fun st ->
          let xs=V.list_arg st.values.(list) in
          let first=V.int_of st.values.(first) and count=V.int_of st.values.(count) in
          if first<0 || count<0 || first>Array.length xs || count>Array.length xs-first then
            V.fail "E_LIST_RANGE" "A list slice must be within its source.";
          V.List (Array.sub xs first count)
    | Sequence_concat ->
        fun st ->
          let arrays=List.map (fun (_,n) -> V.list_arg st.values.(n)) args in
          let count=List.fold_left (fun n xs -> if Array.length xs>4096-n then
            V.fail "E_ITER_BOUND" "Core concatenation exceeds 4,096 values."; n+Array.length xs) 0 arrays in
          let xs=Array.make count V.No_geo and at=ref 0 in
          List.iter (fun part -> Array.blit part 0 xs !at (Array.length part);at:= !at+Array.length part) arrays;
          let ty=V.elem_ty xs in V.List (Array.map (V.coerce_to ty) xs)
    | Color_parse ->
        fun st ->
          let c=Operators.drawing_color st.values.(first) in
          V.Record ["r",Int c.r;"g",Int c.g;"b",Int c.b;"a",Int c.a]
    | Color_byte mode ->
        fun st ->
          let f=V.fin "color" (V.num st.values.(first)) in
          let f=match mode with C.Clamped -> max 0. (min 1. f) | Unclamped -> f in
          V.Int (max 0 (min 255 (int_of_float (f *. 255. +. 0.5))))
    | Numeric (Lt|Le|Gt|Ge|Eq|And|Or as compare) when List.map fst args=["a";"b"] ->
        (* The operators' own bodies, without building an argument list per call. *)
        let a=a () and b=b () in
        let test : E.value -> E.value -> bool = match compare with
          | Lt -> fun x y -> V.num x < V.num y | Le -> fun x y -> V.num x <= V.num y
          | Gt -> fun x y -> V.num x > V.num y | Ge -> fun x y -> V.num x >= V.num y
          | Eq -> fun x y -> V.num x = V.num y
          | And -> fun x y -> V.truthy x && V.truthy y | _ -> fun x y -> V.truthy x || V.truthy y in
        fun st -> if test st.values.(a) st.values.(b) then yes else no
    | Equal when List.map fst args=["a";"b"] ->
        let a=a () and b=b () in
        fun st -> (try if st.values.(a) = st.values.(b) then yes else no
          with Invalid_argument _ -> V.fail "E_TYPE" "Functions cannot be compared.")
    | Numeric _ when List.map fst args=["a";"b"] ->
        (match Flow.Op.arith name with
         | Some arithmetic -> let a=a () and b=b () in fun st -> arithmetic.apply st.values.(a) st.values.(b)
         | None -> generic ())
    | _ -> generic ()
  in
  fun st -> sealing st; body st

let prepare (program : C.program) =
  let constants = Array.map C.value_of_literal program.constants in
  let expression : C.expr -> state -> E.value = function
    | C.Constant n -> let v=constants.(n) in fun _ -> v
    | Local n -> fun st -> st.values.(n)
    | Call_index slot -> fun st -> let n=st.calls.(slot) in st.calls.(slot)<-n+1; V.Int n
    | Frame field ->
        let live = match field with
          | C.Dt -> Some "frame/dt" | Index -> Some "frame/index" | Width -> Some "frame/width"
          | Height -> Some "frame/height" | Pointer_x -> Some "pointer/x" | Pointer_y -> Some "pointer/y"
          | Input -> Some "frame/input" | Time | Tick -> None in
        (match field,live with
         | C.Time,_ -> fun st -> V.Float st.live.t
         | Tick,_ -> fun st -> V.Int st.live.tick
         | _,Some name -> let op = lazy (operator name) in fun st -> apply_op (Lazy.force op) st []
         | _ -> assert false)
    | Prim (op,args) -> primitive op args
    | Vec ns -> fun st ->
        (match List.map (fun n -> V.num st.values.(n)) ns with
        | [x;y] -> V.Vec2 (x,y) | [x;y;z] -> V.Vec3 (x,y,z) | [x;y;z;w] -> V.Vec4 (x,y,z,w)
        | _ -> V.fail "E_CORE" "Invalid vector width.")
    | Fields xs -> fun st -> V.Record (List.map (fun (name,n) -> seal st n;name,st.values.(n)) xs)
    | Items ns -> fun st ->
        let xs=Array.of_list (List.map (fun n -> seal st n;st.values.(n)) ns) in
        if Array.length xs>4096 then V.fail "E_ITER_BOUND" "Core list exceeds 4,096 values.";
        let ty=V.elem_ty xs in V.List (Array.map (V.coerce_to ty) xs)
    | Field (n,name) -> fun st -> match st.values.(n),name with
        | V.Vec2 (x,_),"x" | Vec2 (_,x),"y"
        | Vec3 (x,_,_),"x" | Vec3 (_,x,_),"y" | Vec3 (_,_,x),"z"
        | Vec4 (x,_,_,_),"x" | Vec4 (_,x,_,_),"y" | Vec4 (_,_,x,_),"z" | Vec4 (_,_,_,x),"w" -> V.Float x
        | Record xs,name -> (match List.assoc_opt name xs with Some v -> v | None -> V.fail "E_FIELD" "Missing core field.")
        | _ -> V.fail "E_FIELD" "Invalid core field." in
  let slot_key st n =
    let s=program.state_slots.(n) in
    s.source.instance,s.prefix @ s.zone,
    List.map (function C.Static_index i -> i | Local_index l -> V.int_of st.values.(l)) s.source.iter,
    s.plane=`Host in
  let state_root st = match st.root with Some r -> r
    | None -> V.fail "E_CORE_STATE" "Core state needs its residual's state." in
  let rec block statements =
    let run = Array.of_list (List.map statement statements) in
    fun st -> for i=0 to Array.length run-1 do run.(i) st done
  and statement (s : C.statement) =
    let guard (f : state -> unit) st =
      try f st with V.Fail (code,message,None) -> raise (V.Fail (code,message,s.source.span)) in
    guard (match s.node with
    | Assign (n,e) ->
        let value=expression e in
        let ownership = match e with Prim (Sequence_build,_) -> `Fresh | Local old -> `Alias old | _ -> `None in
        fun st ->
          let v=value st in
          st.builders.(n)<-(match ownership with `Fresh -> Some (ref true) | `Alias old -> st.builders.(old) | `None -> None);
          st.values.(n)<-v
    | Reset_call slot -> fun st -> st.calls.(slot)<-0
    | If {condition;yes;no} ->
        let yes=block yes and no=block no in
        fun st -> (if V.truthy st.values.(condition) then yes else no) st
    | Iterate {sequence;index;item;limit;body} ->
        let body=block body in
        fun st ->
          let source=st.values.(sequence) in
          let count=match source with V.List xs -> Array.length xs | source -> V.array_length source in
          if count>limit then V.fail "E_ITER_BOUND" "Core iteration exceeds its bound.";
          for i=0 to count-1 do
            st.values.(index)<-V.Int i;
            st.values.(item)<-(match source with V.List xs -> xs.(i) | source -> V.array_get source i);
            body st
          done
    | Counted {first;last;count;index;item;limit;init;body} ->
        let init=block init and body=block body in
        fun st ->
          let first=V.int_of st.values.(first) and last=V.int_of st.values.(last) in
          let length=max 0 (last-first) in
          if length>limit then V.fail "E_ITER_BOUND" "Core iteration exceeds its bound.";
          st.values.(count)<-V.Int length;
          init st;
          for i=0 to length-1 do
            st.values.(index)<-V.Int i;
            st.values.(item)<-V.Int (first+i);
            body st
          done
    | Store {sequence;index;value} ->
        fun st ->
          if not (Option.fold ~none:false ~some:(fun writable -> !writable) st.builders.(sequence)) then
            V.fail "E_CORE_OWNERSHIP" "Core stores require an unpublished local builder.";
          let i=V.int_of st.values.(index) in
          (match st.values.(sequence) with
           | V.Float_array data | Vec2_array data | Vec3_array data | Vec4_array data as packed ->
               if i<0 || i>=V.array_length packed then V.fail "E_LIST_RANGE" "Core store is outside its sequence.";
               V.array_put data (Array.length data/V.array_length packed) i st.values.(value)
           | _ ->
               let xs=V.list_arg st.values.(sequence) in
               if i<0 || i>=Array.length xs then V.fail "E_LIST_RANGE" "Core store is outside its sequence.";
               seal st value;
               xs.(i)<-st.values.(value))
    | State_read {slot;result;init;initial} ->
        let init=block init in
        fun st ->
          let instance,path,iter,host=slot_key st slot in
          st.builders.(result)<-None;
          st.values.(result)<-E.Private.state_read (state_root st) ~instance ~path ~iter ~host
            ~init:(fun () -> init st; st.values.(initial))
    | State_peek {slot;found;value} ->
        fun st ->
          let instance,path,iter,host=slot_key st slot in
          let pending=E.Private.state_peek (state_root st) ~instance ~path ~iter ~host in
          st.values.(found)<-V.Bool (Option.is_some pending);
          st.values.(value)<-Option.value ~default:V.No_geo pending
    | State_write {slot;value} ->
        fun st ->
          let instance,path,iter,host=slot_key st slot in
          seal st value;
          st.values.(value)<-E.Private.state_write (state_root st) ~instance ~path ~iter ~host st.values.(value)
    | Invoke {region;result;_} ->
        let (C.Region_ref packed)=program.regions.(region) in
        fun st ->
          st.builders.(result)<-None;
          (match (match st.force with Some force -> force packed | None -> Packed.force packed ~live:st.live) with
           | Ok v -> st.values.(result)<-v
           | Error (d : Flow.Diagnostic.t) -> raise (V.Fail (d.code,d.message,d.span)))) in
  {program; body=block program.body}

let attempt ?root ?force prepared ~live =
  let program=prepared.program in
  match Frame_input.validate live with
  | Error message -> Error (Flow.Diagnostic.error ~code:"E_FRAME" message)
  | Ok () ->
      let st = {values=Array.make (Array.length program.locals) E.No_geo;
        builders=Array.make (Array.length program.locals) None; calls=Array.make program.call_slots 0;
        live; root; force} in
      try prepared.body st;
        if Array.length program.results<>1 then V.fail "E_CORE" "Expected one core result.";
        Ok st.values.(program.results.(0))
      with V.Fail (code,message,span) -> Error (Flow.Diagnostic.error ?span ~code message)
        | Not_found | Invalid_argument _ | Failure _ -> Error (Flow.Diagnostic.error ~code:"E_CORE" "Invalid core program.")

(* Any failure restores the evaluation state and reports the tree walker's own diagnostic,
   as the closure tier's fallback does. Without a residual there is no walker to ask. *)
let execute ?root ?force prepared ~live = match root with
  | None -> attempt ?force prepared ~live
  | Some r ->
      let restore = E.Private.checkpoint r in
      (match (try attempt ~root:r ?force prepared ~live with Stack_overflow | Out_of_memory | Not_found ->
         Error (Flow.Diagnostic.error ~code:"E_CORE" "Core execution failed.")) with
       | Ok _ as ok -> ok
       | Error _ -> restore (); E.Private.rerun r)

let run ?root ?force program ~live = execute ?root ?force (prepare program) ~live
