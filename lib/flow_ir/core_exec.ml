module C = Core
module V = Flow.Value
module E = Flow.Eval

type state = {
  values : E.value array; mutable builders : bool ref option array;  (* allocated by the first builder, so a call that builds nothing pays nothing *) calls : int array;
  live : Frame_input.t; root : E.residual option;
  force : (Packed.t -> (E.value, Flow.Diagnostic.t) result) option;
}
(* A straight-line program of Float arithmetic on the frame time is one tree of unboxed
   operations. It only answers when every step is a finite Float; any other outcome
   (a non-finite step, an invalid frame) runs the general statements, which raise the
   operators' own diagnostics. *)
type tree = Const of float | Time | Add of tree * tree | Sub of tree * tree | Mul of tree * tree
  | Sin of tree | Cos of tree | Sqrt of tree
exception Non_finite
(* Postfix code on a flat float stack: no boxed intermediate floats. *)
type op = Push of float | Push_time | Add_op | Sub_op | Mul_op | Sin_op | Cos_op | Sqrt_op
  | Add_k of float | Sub_k of float | Mul_k of float | Add_t | Sub_t | Mul_t  (* right operand inline *)
let rec flatten tree rest = match tree with
  | Const c -> Push c :: rest | Time -> Push_time :: rest
  | Add (a,b) -> binary a b Add_op (fun c -> Add_k c) Add_t rest
  | Sub (a,b) -> binary a b Sub_op (fun c -> Sub_k c) Sub_t rest
  | Mul (a,b) -> binary a b Mul_op (fun c -> Mul_k c) Mul_t rest
  | Sin a -> flatten a (Sin_op :: rest) | Cos a -> flatten a (Cos_op :: rest)
  | Sqrt a -> flatten a (Sqrt_op :: rest)
and binary a b op konst time rest = match b with
  | Const c -> flatten a (konst c :: rest) | Time -> flatten a (time :: rest)
  | _ -> flatten a (flatten b (op :: rest))
let depth code = snd (List.fold_left (fun (d,m) op -> let d = match op with
  | Push _ | Push_time -> d+1 | Add_op | Sub_op | Mul_op -> d-1 | _ -> d in d, max m d) (0,0) code)
let code_value (code,size) t =
  let stack=Array.create_float size and top=ref 0 in
  for i=0 to Array.length code-1 do
    (match Array.unsafe_get code i with
     | Push c -> Array.unsafe_set stack !top c; incr top
     | Push_time -> Array.unsafe_set stack !top t; incr top
     | Sin_op -> let r=sin (Array.unsafe_get stack (!top-1)) in
         if not (Float.is_finite r) then raise Non_finite; Array.unsafe_set stack (!top-1) r
     | Cos_op -> let r=cos (Array.unsafe_get stack (!top-1)) in
         if not (Float.is_finite r) then raise Non_finite; Array.unsafe_set stack (!top-1) r
     | Sqrt_op -> Array.unsafe_set stack (!top-1) (sqrt (Float.abs (Array.unsafe_get stack (!top-1))))
     | Add_op -> decr top; let r=Array.unsafe_get stack (!top-1) +. Array.unsafe_get stack !top in
         if not (Float.is_finite r) then raise Non_finite; Array.unsafe_set stack (!top-1) r
     | Sub_op -> decr top; let r=Array.unsafe_get stack (!top-1) -. Array.unsafe_get stack !top in
         if not (Float.is_finite r) then raise Non_finite; Array.unsafe_set stack (!top-1) r
     | Mul_op -> decr top; let r=Array.unsafe_get stack (!top-1) *. Array.unsafe_get stack !top in
         if not (Float.is_finite r) then raise Non_finite; Array.unsafe_set stack (!top-1) r
     | Add_k c -> let r=Array.unsafe_get stack (!top-1) +. c in
         if not (Float.is_finite r) then raise Non_finite; Array.unsafe_set stack (!top-1) r
     | Sub_k c -> let r=Array.unsafe_get stack (!top-1) -. c in
         if not (Float.is_finite r) then raise Non_finite; Array.unsafe_set stack (!top-1) r
     | Mul_k c -> let r=Array.unsafe_get stack (!top-1) *. c in
         if not (Float.is_finite r) then raise Non_finite; Array.unsafe_set stack (!top-1) r
     | Add_t -> let r=Array.unsafe_get stack (!top-1) +. t in
         if not (Float.is_finite r) then raise Non_finite; Array.unsafe_set stack (!top-1) r
     | Sub_t -> let r=Array.unsafe_get stack (!top-1) -. t in
         if not (Float.is_finite r) then raise Non_finite; Array.unsafe_set stack (!top-1) r
     | Mul_t -> let r=Array.unsafe_get stack (!top-1) *. t in
         if not (Float.is_finite r) then raise Non_finite; Array.unsafe_set stack (!top-1) r)
  done;
  Array.unsafe_get stack 0

type prepared = { program : C.program; body : state -> unit;
  code : (op array * int) option;
  pool : E.value array option Atomic.t;  (* the locals of a large program, reused across calls: a fresh one is allocated on the major heap *)
  stateless : bool  (* no state slot and no region: a failure leaves the evaluation state untouched *) }

let yes = V.Bool true and no = V.Bool false
let seal st n = if Array.length st.builders>0 then Option.iter (fun writable -> writable:=false) st.builders.(n)

(* Resolved once per prepared program, not per executed statement. *)
let operator name = match Flow.Op.find ~extra:Operators.all name Flow.Context.value with
  | Some op -> op
  | None -> V.fail "E_CORE" ("Unsupported core primitive: " ^ name)
let apply_op op st args =
  op.Flow.Op.body ~live:st.live ~node:(fun _ _ -> V.fail "E_CORE" "Core primitives cannot create catalog nodes.") args

let generic_named name args =
  let op = lazy (operator name) in
  fun st -> apply_op (Lazy.force op) st (List.map (fun (n,i) -> n,st.values.(i)) args)

(* A local of a plain scalar type never holds a list builder, so it needs no ownership bookkeeping. *)
let plain : Flow.Ty.t -> bool = function Float | Int | Bool | Vec2 | Vec3 | Vec4 | Text -> true | _ -> false

let primitive ~track ~locals op args =
  let get st = List.map (fun (name,n) -> name,st.values.(n)) args in
  let first = match args with (_,n)::_ -> n | [] -> -1 in
  let seal_args = match op with C.Sequence_get | Sequence_length | Sequence_build -> false | _ -> true in
  let sealed = List.filter (fun (_,n) -> not (plain locals.(n))) args in
  let sealing st = List.iter (fun (_,n) -> seal st n) sealed in
  let a () = List.assoc "a" args and b () = List.assoc "b" args in
  let a_ key = List.assoc key args in
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
    | Array_count when List.map fst args=["array"] -> fun st -> V.Int (V.array_length st.values.(first))
    | Array_nth when List.map fst args=["array";"index"] ->
        (* A whole index inside native storage, as the operator checks; anything else is its own body. *)
        let array=a_ "array" and index=a_ "index" and slow=generic () in
        fun st -> (match st.values.(index) with
          | V.Int i when i>=0 && i<=Sys.max_floatarray_length -> V.array_get st.values.(array) i
          | _ -> slow st)
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
    | Numeric (Add|Sub|Mul as op) when List.map fst args=["a";"b"] ->
        (* Two Floats whose result is finite, without the generic dispatch; anything else is the operator's own body. *)
        (match Flow.Op.arith name with
         | Some arithmetic ->
             let a=a () and b=b () in
             let slow st = arithmetic.apply st.values.(a) st.values.(b) in
             (match op with
              | Add -> fun st -> (match st.values.(a),st.values.(b) with
                  | V.Float x,V.Float y -> let r=x +. y in if Float.is_finite r then V.Float r else slow st
                  | _ -> slow st)
              | Sub -> fun st -> (match st.values.(a),st.values.(b) with
                  | V.Float x,V.Float y -> let r=x -. y in if Float.is_finite r then V.Float r else slow st
                  | _ -> slow st)
              | _ -> fun st -> (match st.values.(a),st.values.(b) with
                  | V.Float x,V.Float y -> let r=x *. y in if Float.is_finite r then V.Float r else slow st
                  | _ -> slow st))
         | None -> generic ())
    | Math (Sin|Cos as op) ->
        let x=first and slow=generic () in
        (match op with
         | Sin -> fun st -> (match st.values.(x) with
             | V.Float v -> let r=sin v in if Float.is_finite r then V.Float r else slow st
             | _ -> slow st)
         | _ -> fun st -> (match st.values.(x) with
             | V.Float v -> let r=cos v in if Float.is_finite r then V.Float r else slow st
             | _ -> slow st))
    | Numeric _ when List.map fst args=["a";"b"] ->
        (match Flow.Op.arith name with
         | Some arithmetic -> let a=a () and b=b () in fun st -> arithmetic.apply st.values.(a) st.values.(b)
         | None -> generic ())
    | _ -> generic ()
  in
  if track && seal_args && sealed<>[] then fun st -> sealing st; body st else body

(* Each local is a tree and whether it is a Float: Int constants only meet a Float operand,
   where the operators convert them exactly as the general path does. *)
let scalar_tree (program : C.program) constants =
  if Array.length program.state_slots>0 || Array.length program.regions>0 || Array.length program.results<>1 then None else
  let locals=Array.make (Array.length program.locals) None in
  let operand = function Some v -> v | None -> raise Exit in
  try
    List.iter (fun (s : C.statement) -> match s.node with
      | Assign (n,e) ->
          locals.(n)<-Some (match e with
            | C.Constant k -> (match constants.(k) with V.Float f -> Const f,true | V.Int i -> Const (float_of_int i),false
                | _ -> raise Exit)
            | Frame Time -> Time,true
            | Local m -> operand locals.(m)
            | Prim (Numeric (Add|Sub|Mul as op),["a",a;"b",b]) ->
                let (x,fx),(y,fy)=operand locals.(a),operand locals.(b) in
                if not (fx || fy) then raise Exit;
                (match op with Add -> Add (x,y) | Sub -> Sub (x,y) | _ -> Mul (x,y)),true
            | Prim (Math (Sin|Cos|Sqrt as m),["x",x]) ->
                let x,_=operand locals.(x) in (match m with Sin -> Sin x | Cos -> Cos x | _ -> Sqrt x),true
            | _ -> raise Exit)
      | _ -> raise Exit) program.body;
    (match locals.(program.results.(0)) with
     | Some (t,true) -> let code=flatten t [] in if List.length code<=64 then Some (Array.of_list code, depth code) else None
     | _ -> None)
  with Exit -> None

let rec builds (statements : C.statement list) = List.exists (fun (s : C.statement) -> match s.node with
  | Assign (_,Prim (Sequence_build,_)) -> true
  | If {yes;no;_} -> builds yes || builds no
  | Iterate {body;_} -> builds body
  | Counted {init;body;_} -> builds init || builds body
  | State_read {init;_} -> builds init
  | _ -> false) statements

let prepare ?(fused=true) (program : C.program) =
  let track = builds program.body in
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
         | Dt,_ -> fun st -> V.Float st.live.dt | Index,_ -> fun st -> V.Int st.live.frame
         | Width,_ -> fun st -> V.Int (fst st.live.size) | Height,_ -> fun st -> V.Int (snd st.live.size)
         | Pointer_x,_ -> fun st -> V.Float (fst st.live.pointer) | Pointer_y,_ -> fun st -> V.Float (snd st.live.pointer)
         | Tick,_ -> fun st -> V.Int st.live.tick
         | _,Some name -> let op = lazy (operator name) in fun st -> apply_op (Lazy.force op) st []
         | _ -> assert false)
    | Prim (op,args) -> primitive ~track ~locals:program.locals op args
    | Vec ns -> fun st ->
        (match List.map (fun n -> V.num st.values.(n)) ns with
        | [x;y] -> V.Vec2 (x,y) | [x;y;z] -> V.Vec3 (x,y,z) | [x;y;z;w] -> V.Vec4 (x,y,z,w)
        | _ -> V.fail "E_CORE" "Invalid vector width.")
    | Fields xs -> fun st -> V.Record (List.map (fun (name,n) -> seal st n;name,st.values.(n)) xs)
    | Items ns -> fun st ->
        let xs=Array.of_list (List.map (fun n -> seal st n;st.values.(n)) ns) in
        if Array.length xs>4096 then V.fail "E_ITER_BOUND" "Core list exceeds 4,096 values.";
        let ty=V.elem_ty xs in V.List (Array.map (V.coerce_to ty) xs)
    | Field (n,name) ->
        let slow st = match st.values.(n),name with
        | V.Vec2 (x,_),"x" | Vec2 (_,x),"y"
        | Vec3 (x,_,_),"x" | Vec3 (_,x,_),"y" | Vec3 (_,_,x),"z"
        | Vec4 (x,_,_,_),"x" | Vec4 (_,x,_,_),"y" | Vec4 (_,_,x,_),"z" | Vec4 (_,_,_,x),"w" -> V.Float x
        | Record xs,name -> (match List.find_opt (fun (n,_) -> String.equal n name) xs with Some (_,v) -> v | None -> V.fail "E_FIELD" "Missing core field.")
        | _ -> V.fail "E_FIELD" "Invalid core field." in
        (match name with
         | "x" -> fun st -> (match st.values.(n) with V.Vec2 (x,_) | Vec3 (x,_,_) | Vec4 (x,_,_,_) -> V.Float x | _ -> slow st)
         | "y" -> fun st -> (match st.values.(n) with V.Vec2 (_,x) | Vec3 (_,x,_) | Vec4 (_,x,_,_) -> V.Float x | _ -> slow st)
         | _ -> slow) in
  let slot_keys = Array.map (fun (s : C.state_slot) ->
    let path=s.prefix @ s.zone and host=s.plane=`Host in
    if List.for_all (function C.Static_index _ -> true | Local_index _ -> false) s.source.iter then
      let iter=List.map (function C.Static_index i -> i | Local_index _ -> assert false) s.source.iter in
      fun _ -> s.source.instance,path,iter,host
    else fun st -> s.source.instance,path,
      List.map (function C.Static_index i -> i | Local_index l -> V.int_of st.values.(l)) s.source.iter,host)
    program.state_slots in
  let slot_key st n = slot_keys.(n) st in
  let state_root st = match st.root with Some r -> r
    | None -> V.fail "E_CORE_STATE" "Core state needs its residual's state." in
  let writes = Array.make (Array.length program.locals) 0 in
  let bump n = writes.(n)<-writes.(n)+1 in
  let rec count statements = List.iter (fun (s : C.statement) -> match s.node with
    | Assign (n,_) | State_write {value=n;_} | Invoke {result=n;_} -> bump n
    | Reset_call _ | Store _ -> ()
    | If {yes;no;_} -> count yes; count no
    | Iterate {index;item;body;_} -> bump index; bump item; count body
    | Counted {count=c;index;item;init;body;_} -> bump c; bump index; bump item; count init; count body
    | State_read {result;init;_} -> bump result; count init
    | State_peek {found;value;_} -> bump found; bump value) statements in
  count program.body;
  let hoisted (s : C.statement) = match s.node with
    | Assign (n,(Constant _ | Frame (Time|Dt|Index|Tick|Width|Height|Pointer_x|Pointer_y))) -> writes.(n)=1
    | _ -> false in
  let in_loop = ref false in
  (* Constants and frame facts a loop body sets once are set when the loop starts, not per iteration. *)
  let rec invariant statements = List.concat_map (fun (s : C.statement) -> match s.node with
    | Assign (n,e) when hoisted s -> [n, expression e]
    | If {yes;no;_} -> invariant yes @ invariant no
    | _ -> []) statements in
  let rec block statements =
    let statements = if !in_loop then List.filter (fun s -> not (hoisted s)) statements else statements in
    let run = Array.of_list (List.map statement statements)
    and spans = Array.of_list (List.map (fun (s : C.statement) -> s.source.span) statements) in
    (* The innermost block that sees an unlocated failure gives it its statement's span. *)
    fun st -> let i=ref 0 in
      try while !i<Array.length run do run.(!i) st; incr i done
      with V.Fail (code,message,None) -> raise (V.Fail (code,message,spans.(!i)))
  and loop_body body =
    let inner = !in_loop in in_loop := true;
    let run = block body in in_loop := inner;
    let setup = Array.of_list (invariant body) in
    (fun st -> Array.iter (fun (n,value) -> st.values.(n)<-value st) setup), run
  and plain_block statements =
    let inner = !in_loop in in_loop := false;
    let run = block statements in in_loop := inner; run
  and statement (s : C.statement) =
    (match s.node with
    | Assign (n,e) ->
        let value=expression e in
        let ownership = match e with Prim (Sequence_build,_) -> `Fresh | Local old -> `Alias old | _ -> `None in
        if not track || plain program.locals.(n) then fun st -> st.values.(n)<-value st else
        fun st ->
          let v=value st in
          (match ownership with
           | `Fresh -> if Array.length st.builders=0 then st.builders<-Array.make (Array.length program.locals) None;
               st.builders.(n)<-Some (ref true)
           | `Alias old -> if Array.length st.builders>0 then st.builders.(n)<-st.builders.(old)
           | `None -> if Array.length st.builders>0 then st.builders.(n)<-None);
          st.values.(n)<-v
    | Reset_call slot -> fun st -> st.calls.(slot)<-0
    | If {condition;yes;no} ->
        let yes=block yes and no=block no in
        fun st -> (if V.truthy st.values.(condition) then yes else no) st
    | Iterate {sequence;index;item;limit;body} ->
        let setup,body=loop_body body in
        fun st ->
          let source=st.values.(sequence) in
          let count=match source with V.List xs -> Array.length xs | source -> V.array_length source in
          if count>limit then V.fail "E_ITER_BOUND" "Core iteration exceeds its bound.";
          setup st;
          for i=0 to count-1 do
            st.values.(index)<-V.Int i;
            st.values.(item)<-(match source with V.List xs -> xs.(i) | source -> V.array_get source i);
            body st
          done
    | Counted {first;last;count;index;item;limit;init;body} ->
        let init=plain_block init and setup,body=loop_body body in
        fun st ->
          let first=V.int_of st.values.(first) and last=V.int_of st.values.(last) in
          let length=max 0 (last-first) in
          if length>limit then V.fail "E_ITER_BOUND" "Core iteration exceeds its bound.";
          st.values.(count)<-V.Int length;
          init st;
          setup st;
          for i=0 to length-1 do
            st.values.(index)<-V.Int i;
            st.values.(item)<-V.Int (first+i);
            body st
          done
    | Store {sequence;index;value} ->
        fun st ->
          if not (Option.fold ~none:false ~some:(fun writable -> !writable) (if Array.length st.builders>0 then st.builders.(sequence) else None)) then
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
        let init=plain_block init in
        fun st ->
          let instance,path,iter,host=slot_key st slot in
          if Array.length st.builders>0 then st.builders.(result)<-None;
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
          if Array.length st.builders>0 then st.builders.(result)<-None;
          (match (match st.force with Some force -> force packed | None -> Packed.force packed ~live:st.live) with
           | Ok v -> st.values.(result)<-v
           | Error (d : Flow.Diagnostic.t) -> raise (V.Fail (d.code,d.message,d.span)))) in
  {program; body=block program.body; code=if fused then scalar_tree program constants else None;
   pool=Atomic.make None; stateless=Array.length program.state_slots=0 && Array.length program.regions=0}

let has_regions prepared = Array.length prepared.program.regions>0

let general root force prepared live =
  let program=prepared.program in
  match Frame_input.validate live with
    | Error message -> Error (Flow.Diagnostic.error ~code:"E_FRAME" message)
    | Ok () ->
        let n=Array.length program.locals in
        let pooled=n>256 in
        let values=match (if pooled then Atomic.exchange prepared.pool None else None) with
          | Some values -> values | None -> Array.make n E.No_geo in
        let release () = if pooled then Atomic.set prepared.pool (Some values) in
        let st = {values;
          builders=[||]; calls=Array.make program.call_slots 0;
          live; root; force} in
        let result = try prepared.body st;
          if Array.length program.results<>1 then V.fail "E_CORE" "Expected one core result.";
          Ok st.values.(program.results.(0))
        with V.Fail (code,message,span) -> Error (Flow.Diagnostic.error ?span ~code message)
          | Not_found | Invalid_argument _ | Failure _ -> Error (Flow.Diagnostic.error ~code:"E_CORE" "Invalid core program.") in
        release (); result

let attempt ?root ?force prepared ~live =
  (* The postfix code reads only the time and every step is finite-checked, so frame facts it
     never reads need no validation: an invalid frame ends in the walker's own result anyway. *)
  match prepared.code with
  | None -> general root force prepared live
  | Some code -> (match code_value code live.t with r -> Ok (V.Float r)
      | exception Non_finite -> general root force prepared live)

(* Any failure restores the evaluation state and reports the tree walker's own diagnostic,
   as the closure tier's fallback does. Without a residual there is no walker to ask. *)
let execute ?root ?force prepared ~live = match root with
  | None -> attempt ?force prepared ~live
  | Some r ->
      let restore = if prepared.stateless then ignore else E.Private.checkpoint r in
      (match (try attempt ~root:r ?force prepared ~live with _ ->
         Error (Flow.Diagnostic.error ~code:"E_CORE" "Core execution failed.")) with
       | Ok _ as ok -> ok
       | Error _ -> restore (); E.Private.rerun r)

let run ?root ?force program ~live = execute ?root ?force (prepare program) ~live
