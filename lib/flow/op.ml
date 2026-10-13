open Value
type signature = {
  pos : (string * Ty.t) list; opt : (string * Ty.t) list;
  rest : (string * Ty.t) option; kw : (string * Ty.t) list;
}
type shape = Scalar | Struct of { splice : bool }
type arithmetic = { apply : 'f 'r. ('f, 'r) Value.t -> ('f, 'r) Value.t -> ('f, 'r) Value.t }
type packed_kind = Binary of Packed_ops.binary | Unary of Packed_ops.unary
  | Integer of Packed_ops.integer | Integer_compare of Packed_ops.comparison
  | Convert of Packed_ops.conversion
  | Noise3 | Fma | Checked_mul | Checked_fma | Rand_at | Length | Dot | Cross | Normalize | Exact | Gather | Frame | Constant_only
type t = {
  name : string; ctx : Context.t; signature : signature;
  out : Ty.t list -> Ty.t;
  out_args : ((string * Ty.t * Param.value option) list -> Ty.t) option;
  any_num : bool;
  choices : (string * string list) list; shape : shape;
  live : bool;
  check : 'f 'r. (string * ('f, 'r) Value.t) list -> unit;
  body : 'f 'r. live:Frame_input.t -> node:(string -> (string * ('f, 'r) Value.t) list -> ('f, 'r) Value.t) ->
    (string * ('f, 'r) Value.t) list -> ('f, 'r) Value.t;
  category : string; arithmetic : arithmetic option;
  packed_extension : Packed_ops.extension option;
}
type implementation = { run : 'f 'r. name:string -> node:(string -> (string * ('f, 'r) Value.t) list -> ('f, 'r) Value.t) ->
  (string * ('f, 'r) Value.t) list -> ('f, 'r) Value.t }
type validation = { validate : 'f 'r. (string * string list) list -> (string * ('f, 'r) Value.t) list -> unit }
let max_iterations = 4096
let mk ?(ctx = Context.value) ?(opt = []) ?rest ?(kw = []) ?(any_num = false)
    ?(choices = []) ?(shape = Scalar) ?(check = { validate = fun _ _ -> () })
    ?(category = "Math") ?arithmetic name pos out (body : implementation) =
  { name; ctx; signature = {pos; opt; rest; kw}; out; out_args = None; any_num; choices; shape; live = false;
    check = (fun args -> check.validate choices args);
    body = (fun ~live:_ ~node args -> body.run ~name ~node args); category; arithmetic;
    packed_extension = None }
let fl = Ty.Float
let lst j ts = match List.nth_opt ts j with Some (Ty.List _ as t) -> t | _ -> Ty.List Ty.Any
let elm j ts = match lst j ts with Ty.List e -> e | _ -> Ty.Any
let binary name f =
  let arithmetic = { apply = fun a b -> Value.arith name f a b } in
  mk ~any_num:true ~arithmetic name ["a", fl; "b", fl] (fun ts ->
    match List.find_opt (fun ty -> List.mem ty [Ty.Vec2;Ty.Vec3;Ty.Vec4]) ts with
    | Some ty -> ty
    | None -> if name <> "/" && name <> "pow" && List.for_all ((=) Ty.Int) ts then Ty.Int else fl)
    {run = fun ~name ~node:_ args -> match List.map snd args with
      | [a;b] -> arithmetic.apply a b
      | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name}
let unary ~category name out = mk ~category name ["x", fl] out
let float_unary name operation = unary ~category:"Math" name (fun _ -> fl)
  {run=fun ~name ~node:_ args -> Float (fin name (operation (num (List.assoc "x" args))))}
let float_binary name operation = mk ~category:"Math" name ["a",fl;"b",fl] (fun _ -> fl)
  {run=fun ~name ~node:_ args -> Float (fin name
    (operation (num (List.assoc "a" args)) (num (List.assoc "b" args))))}
let dot3 (x,y,z) (a,b,c) =
  let xa = Sys.opaque_identity (x *. a)
  and yb = Sys.opaque_identity (y *. b)
  and zc = Sys.opaque_identity (z *. c) in
  (xa +. yb) +. zc
let compare_op ~category name = mk ~category name ["a", fl; "b", fl] (fun _ -> Ty.Bool)
let bool_op ~category name pos = mk ~category name pos (fun _ -> Ty.Bool)
let concrete f = function Residual _ -> () | v -> f v
let range_error msg = fail "E_RANGE" msg
let axis choices args = match List.assoc_opt "axis" args with
  | Some v -> concrete (function Text t when List.mem t (List.assoc "axis" choices) -> ()
      | _ -> range_error "Split axis is horizontal or vertical.") v
  | None -> ()
let one_of args key what choices = match List.assoc_opt key args with
  | Some v -> concrete (function Text t when List.mem t choices -> ()
      | _ -> range_error (Printf.sprintf "%s is %s." what (String.concat ", " choices))) v
  | None -> ()
let split_check choices args =
  axis choices args;
  let points key = match List.assoc_opt key args with
    | Some v -> concrete (fun v -> if num v < 1. then range_error "A fixed split size is 1 point or more.") v
    | None -> () in
  points "first_size"; points "second_size";
  if List.mem_assoc "first_size" args && List.mem_assoc "second_size" args then
    range_error "A split fixes one side: :first_size or :second_size."
let split_at_check choices args =
  axis choices args;
  match List.assoc_opt "ratio" args with
  | Some v -> concrete (fun v -> let r = num v in
      if r < 0.1 || r > 0.9 then range_error "Split ratio is 0.1–0.9.") v
  | None -> ()
let tile_check args =
  let n = List.length args in
  if n < 1 || n > 16 then range_error "A tile holds 1–16 panels."
let switch_check args =
  let n = List.length (List.filter (fun (k, _) -> k <> "active") args) in
  if n < 1 || n > 16 then range_error "A switch holds 1–16 layouts.";
  match List.assoc_opt "active" args with
  | Some v -> concrete (fun v -> let a = num v in
      if a < 0. || a >= float n then range_error "The active layout is 0 to the layout count minus one.") v
  | None -> ()
let structure ?(ctx = Context.editor) ?opt ?rest ?kw ?choices ?check ?(splice = false) name pos out =
  (* Deferred SOP element lists have no cooked element type during evaluation. *)
  let ty = if ctx = Context.sop then Ty.List Ty.Any else out [] in
  mk ~ctx ?opt ?rest ?kw ?choices ?check ~shape:(Struct {splice}) name pos out
    {run = fun ~name ~node:_ args -> Value.Struct (name, ty, args)}
let panel ?opt ?rest ?kw ?choices ?check ?splice name pos =
  structure ?opt ?rest ?kw ?choices ?check ?splice name pos (fun _ -> Ty.panel)
let leaf ?opt ?(kw = []) ?choices ?check name pos =
  panel ?opt ~kw:(kw @ ["focus", Ty.Bool]) ?choices ?check name pos
let hsv h s v =
  let h = Float.rem (Float.rem h 1. +. 1.) 1. in
  (* Separately rounded products, as in core.md: no contraction into fused multiply-add. *)
  let h6 = Sys.opaque_identity (h *. 6.) in
  let i = int_of_float (Float.floor h6) in
  let f = h6 -. float_of_int i in
  let p = v *. (1. -. s) and q = v *. (1. -. Sys.opaque_identity (f *. s))
  and t = v *. (1. -. Sys.opaque_identity ((1. -. f) *. s)) in
  match i mod 6 with
  | 0 -> (v, t, p) | 1 -> (q, v, p) | 2 -> (p, v, t) | 3 -> (p, q, v) | 4 -> (t, p, v)
  | _ -> (v, p, q)

let range lo hi =
  if hi - lo > max_iterations then
    failf "E_ITER_BOUND" "range %d‥%d exceeds 4,096 iterations." lo hi;
  List (Array.init (max 0 (hi - lo)) (fun i -> Int (lo + i)))

type frame_read = { read : 'f 'r. Frame_input.t -> (string * ('f, 'r) Value.t) list -> ('f, 'r) Value.t }
let frame_op ?opt name pos out read =
  let o = mk ?opt ~category:"Frame" name pos (fun _ -> out)
    {run = fun ~name:_ ~node:_ args -> read.read (Frame_input.at_time 0.) args} in
  {o with live = true; body = (fun ~live ~node:_ args -> read.read live args)}

let event_fields = ["kind", Ty.Text; "key", Ty.Text; "button", Ty.Text;
  "position", Ty.Vec3; "delta", Ty.Vec3; "text", Ty.Text; "start", Ty.Int;
  "length", Ty.Int; "paths", Ty.List Ty.Text; "error", Ty.Text; "id", Ty.Int;
  "width", Ty.Int; "height", Ty.Int; "phase", Ty.Text; "time", Ty.Float; "scale", Ty.Float]
let frame_ty = Ty.Record ["t", fl; "dt", fl; "index", Ty.Int;
  "width", Ty.Int; "height", Ty.Int; "pointer", Ty.Vec3;
  "buttons", Ty.List Ty.Text; "keys", Ty.List Ty.Text; "events", Ty.List (Ty.Record event_fields)]
let text_list xs = List (Array.of_list (List.map (fun s -> Text s) xs))
let event_value event =
  let point (x, y) = Vec3 (x, y, 0.) in
  let kind, fields = match event with
    | Frame_input.Key_pressed key -> "key-pressed", ["key", Text key]
    | Key_released key -> "key-released", ["key", Text key]
    | Pointer_moved (x, y) -> "pointer-moved", ["position", point (x, y)]
    | Pointer_pressed (b, p) -> "pointer-pressed", ["button", Text b; "position", point p]
    | Pointer_released (b, p) -> "pointer-released", ["button", Text b; "position", point p]
    | Pointer_cancelled b -> "pointer-cancelled", ["button", Text b]
    | Scrolled (x, y) -> "scrolled", ["delta", point (x, y)]
    | Text_input s -> "text-input", ["text", Text s]
    | Text_editing {text; start; length} -> "text-editing", ["text", Text text; "start", Int start; "length", Int length]
    | File_dropped s -> "file-dropped", ["text", Text s]
    | File_drag_moved (x, y) -> "file-drag-moved", ["position", point (x, y)]
    | File_drag_ended -> "file-drag-ended", []
    | Pinched x -> "pinched", ["scale", Float x]
    | File_dialog {id; result} -> "file-dialog", ("id", Int id) ::
        (match result with Ok xs -> ["paths", text_list xs] | Error s -> ["error", Text s])
    | Dialog_opened id -> "dialog-opened", ["id",Int id]
    | Resized (w, h) -> "resized", ["width", Int w; "height", Int h]
    | Focus_lost -> "focus-lost", [] | Closed -> "closed", []
    | Trackpad_scrolled {delta; phase; time} -> "trackpad-scrolled", ["delta", point delta; "phase", Text phase; "time", Float time] in
  Record (List.map (fun (name, ty) -> name, if name = "kind" then Text kind else
    match List.assoc_opt name fields with Some v -> v | None ->
      match ty with Ty.Int -> Int 0 | Float -> Float 0. | Vec3 -> Vec3 (0., 0., 0.)
      | List _ -> List [||] | _ -> Text "") event_fields)

let frame_value (f : Frame_input.t) = Record ["t", Float f.t; "dt", Float f.dt;
  "index", Int f.frame; "width", Int (fst f.size); "height", Int (snd f.size);
  "pointer", Vec3 (fst f.pointer, snd f.pointer, 0.); "buttons", text_list f.buttons;
  "keys", text_list f.keys; "events", List (Array.of_list (List.map event_value f.events))]

let frame = [
  frame_op "frame/input" [] frame_ty {read = fun f _ -> frame_value f};
  frame_op "frame/dt" [] fl {read = fun f _ -> Float f.dt};
  frame_op "frame/index" [] Ty.Int {read = fun f _ -> Int f.frame};
  frame_op "frame/width" [] Ty.Int {read = fun f _ -> Int (fst f.size)};
  frame_op "frame/height" [] Ty.Int {read = fun f _ -> Int (snd f.size)};
  frame_op "pointer/x" [] fl {read = fun f _ -> Float (fst f.pointer)};
  frame_op "pointer/y" [] fl {read = fun f _ -> Float (snd f.pointer)};
  frame_op ~opt:["button", Ty.Text] "pointer/down" [] Ty.Bool {read = fun f args ->
    match args with [] -> Bool (List.mem "left" f.buttons)
    | [_, Text button] ->
        if not (List.mem button ["left"; "right"; "middle"; "x1"; "x2"]) then
          fail "E_RANGE" "Pointer button is left, right, middle, x1 or x2.";
        Bool (List.mem button f.buttons)
    | _ -> fail "E_TYPE" "pointer/down takes a button name."};
  frame_op "key/down" ["key", Ty.Text] Ty.Bool {read = fun f args ->
    match args with [_, Text key] -> Bool (List.mem key f.keys)
    | _ -> fail "E_TYPE" "key/down takes a key name."};
]

let array_count ?(limit = Sys.max_floatarray_length) name v =
  let invalid () = failf "E_ARRAY_RANGE" "%s needs a non-negative whole length." name in
  match v with
  | Int n -> if n < 0 || n > limit then invalid () else n
  | _ ->
      let n = num v in
      if n < 0. || n <> Float.floor n || n > float limit then invalid ();
      let n = int_of_float n in if n > limit then invalid () else n
let range_type args = match List.find_opt (fun (name,_,_) -> name="type") args with
  | None -> Ty.Array Ty.Float
  | Some (_,_,Some (Param.Text_value "int")) -> Ty.Array Ty.Int
  | Some (_,_,Some (Param.Text_value "float")) -> Ty.Array Ty.Float
  | _ -> fail "E_ARRAY_TYPE" "Array range type is the literal int or float."
let constant_sample ty count value =
  let width=match ty with Ty.Vec2->2|Vec3->3|Vec4->4|_->1 in
  if List.mem ty [Ty.Float;Vec2;Vec3;Vec4] && count>Sys.max_floatarray_length/width then
    fail "E_ARRAY_RANGE" "Array length is outside native storage bounds.";
  array_init ty (min count 1) (fun _->value)
let constant_constructor = function
  | "array/int" -> Ty.Int,Int 0 | "array/text" -> Ty.Text,Text ""
  | "array/float" -> Ty.Float,Float 0. | "array/vec3" -> Ty.Vec3,Vec3(0.,0.,0.)
  | "array/vec4" -> Ty.Vec4,Vec4(0.,0.,0.,0.)
  | _ -> fail "E_ARRAY_TYPE" "Unknown constant array constructor."
let constant_descriptor name args =
  let ty,default=constant_constructor name in
  if List.exists(fun(key,_)->key<>"count" && key<>"value")args
    || List.length args<>List.length(List.sort_uniq String.compare(List.map fst args)) then
    fail "E_ARRAY_TYPE" "Malformed constant array constructor arguments.";
  let count=match List.assoc_opt "count" args with
    |Some count->array_count ~limit:(if ty=Ty.Int || ty=Ty.Text then Sys.max_array_length else Sys.max_floatarray_length) name count
    |None->fail "E_ARRAY_TYPE" "Constant array constructor needs count." in
  let sample=constant_sample ty count (Option.value ~default(List.assoc_opt "value" args)) in
  let value=if count=0 then default else array_get sample 0 in
  Source("$core/constant-array/"^name,Ty.Array ty,["count",Int count;"value",value])
module Private = struct
  let array_count = array_count
  let constant_array_descriptor = constant_descriptor
  type reduction = Sum | Minimum | Maximum
  let reduction_name = function Sum -> "sum" | Minimum -> "min" | Maximum -> "max"
  (* ponytail: global reductions scan sequentially; add qualified block extrema
     only if measurements make that scan a bottleneck. Segment rows already pool. *)
  let reduce_array ?(rows = fun ~start ~finish f -> for i=start to finish do f i done)
      operation ?offsets values =
    let count = array_length values in
    let offsets = Option.map (function Int_array offsets -> offsets
      | _ -> fail "E_ARRAY_TYPE" "Segment offsets must be an integer array.") offsets in
    let segments = match offsets with
      | None -> 1
      | Some offsets ->
        let n=Array.length offsets in
        if n=0 || offsets.(0)<>0 || offsets.(n-1)<>count then
          fail "E_ARRAY_OFFSETS" "Segment offsets must start at zero, be nondecreasing and end at the value count.";
        for i=1 to n-1 do
          if offsets.(i)<offsets.(i-1) then
            fail "E_ARRAY_OFFSETS" "Segment offsets must start at zero, be nondecreasing and end at the value count."
        done;
        n-1 in
    let range row = match offsets with None -> 0,count | Some offsets -> offsets.(row),offsets.(row+1) in
    let extrema_start first finish =
      if operation<>Sum && first=finish then fail "E_ARRAY_EMPTY" "An extremum needs at least one array value.";
      if operation=Sum then first else first+1 in
    match values with
    | Int_array values ->
      let apply = match operation with Sum -> ( + ) | Minimum -> min | Maximum -> max in
      let reduce first finish =
        let start=extrema_start first finish in
        let result=ref (if operation=Sum then 0 else values.(first)) in
        for i=start to finish-1 do result:=apply !result values.(i) done;
        !result in
      (match offsets with
       | None -> Int (reduce 0 count)
       | Some _ ->
         let result=Array.make segments 0 in
         rows ~start:0 ~finish:(segments-1) (fun row ->
           let first,finish=range row in result.(row)<-reduce first finish);
         Int_array result)
    | Float_array data | Vec2_array data | Vec3_array data | Vec4_array data ->
      let width=match values with Vec2_array _ -> 2 | Vec3_array _ -> 3 | Vec4_array _ -> 4 | _ -> 1 in
      let name="array/" ^ (if offsets=None then "" else "segment_") ^ reduction_name operation in
      let reduce first finish component =
        let start=extrema_start first finish in
        let result=ref (if operation=Sum then 0. else fin name data.(first*width+component)) in
        for i=start to finish-1 do
          let value=data.(i*width+component) in
          if not(Float.is_finite value) then ignore(fin name value);
          result:=(match operation with Sum -> !result+.value
            | Minimum -> Float.min !result value | Maximum -> Float.max !result value);
          if not(Float.is_finite !result) then ignore(fin name !result)
        done;
        !result in
      (match offsets with
       | None -> (match width with
           | 1 -> Float (reduce 0 count 0)
           | 2 -> Vec2 (reduce 0 count 0,reduce 0 count 1)
           | 3 -> Vec3 (reduce 0 count 0,reduce 0 count 1,reduce 0 count 2)
           | _ -> Vec4 (reduce 0 count 0,reduce 0 count 1,reduce 0 count 2,reduce 0 count 3))
       | Some _ ->
         if segments>Sys.max_floatarray_length/width then
           fail "E_ARRAY_RANGE" "Array length is outside native storage bounds.";
         let result=Array.make (segments*width) 0. in
         rows ~start:0 ~finish:(segments-1) (fun row ->
           let first,finish=range row in
           for component=0 to width-1 do
             result.(row*width+component)<-reduce first finish component
           done);
         (match width with 1 -> Float_array result | 2 -> Vec2_array result
          | 3 -> Vec3_array result | _ -> Vec4_array result))
    | _ -> fail "E_ARRAY_TYPE" "Array reductions need int, float or vector arrays."
end
let reduction_type segmented = function
  | Ty.Array (Ty.Int | Float | Vec2 | Vec3 | Vec4 as element) :: _ ->
      if segmented then Ty.Array element else element
  | Ty.Array Ty.Any :: _ -> if segmented then Ty.Array Ty.Any else Ty.Any
  | _ -> fail "E_ARRAY_TYPE" "Array reductions need int, float or vector arrays."
(* Ordered scatter owns only its zero-initialized result. Never regroup duplicate
   indices: that would change separately rounded floating additions.
   ponytail: one bulk scan is not internally cancellable, as for reductions;
   thread a shared execution checkpoint through bulk primitives if required. *)
let scatter_add indices values size =
  let indices=match indices with Int_array data->data
    |_->fail "E_ARRAY_TYPE" "Scatter indices must be an integer array." in
  let count=array_length values in
  let width=match values with Int_array _|Float_array _->1|Vec2_array _->2
    |Vec3_array _->3|Vec4_array _->4
    |_->fail "E_ARRAY_TYPE" "Scatter values must be int, float or vector arrays." in
  let integer=match values with Int_array _->true|_->false in
  let size=match size with Int _->array_count
      ~limit:(if integer then Sys.max_array_length else Sys.max_floatarray_length/width)
      "array/scatter_add" size
    |_->fail "E_ARRAY_TYPE" "Scatter size must be an integer." in
  if Array.length indices<>count then
    fail "E_ARRAY_COUNT" "Scatter indices and values must have equal lengths.";
  let index row=let index=indices.(row) in
    if index<0 || index>=size then fail "E_ARRAY_RANGE" "Scatter index is outside its output length.";
    index in
  match values with
  |Int_array values->
      let result=Array.make size 0 in
      for row=0 to count-1 do let index=index row in
        result.(index)<-result.(index)+values.(row)
      done;
      Int_array result
  |Float_array values|Vec2_array values|Vec3_array values|Vec4_array values->
      let result=Array.make(size*width) 0. in
      for row=0 to count-1 do let at=index row*width in
        for component=0 to width-1 do
          let value=fin "array/scatter_add" values.(row*width+component) in
          result.(at+component)<-fin "array/scatter_add" (result.(at+component)+.value)
        done
      done;
      (match width with 1->Float_array result|2->Vec2_array result
        |3->Vec3_array result|_->Vec4_array result)
  |_->assert false
let scatter_type = function
  |_::(Ty.Array (Ty.Int|Float|Vec2|Vec3|Vec4|Any) as values)::size::_ ->
      if size<>Ty.Int && size<>Ty.Any then fail "E_ARRAY_TYPE" "Scatter size must be an integer.";
      values
  |_->fail "E_ARRAY_TYPE" "Scatter values must be int, float or vector arrays."
(* These ordered whole-array operations share the reduction forcing boundary.
   ponytail: bulk scans have no internal cancellation checkpoint; thread the
   host execution checkpoint through bulk primitives if that ceiling matters. *)
let compact_mask = function
  |Int_array mask->
      let kept=ref 0 in
      Array.iter(fun value->if value=1 then incr kept else if value<>0 then
        fail "E_ARRAY_MASK" "Compact mask entries must be 0 or 1.")mask;
      let indices=Array.make !kept 0 and at=ref 0 in
      Array.iteri(fun index value->if value=1 then begin indices.(!at)<-index;incr at end)mask;
      Int_array indices
  |_->fail "E_ARRAY_TYPE" "Compaction needs an integer mask array."
let scan_sum = function
  |Int_array values->
      let count=Array.length values in
      if count>=Sys.max_array_length then
        fail "E_ARRAY_RANGE" "Scan output length is outside native storage bounds.";
      let offsets=Array.make(count+1)0 in
      for row=0 to count-1 do offsets.(row+1)<-offsets.(row)+values.(row) done;
      Int_array offsets
  |_->fail "E_ARRAY_TYPE" "Prefix sum needs an integer array."
let integer_array_type = function
  |[Ty.Array Ty.Int]|[Ty.Any]->Ty.Array Ty.Int
  |_->fail "E_ARRAY_TYPE" "This operation needs an integer array."
module Int_keys = Hashtbl.Make(struct type t=int let equal=Int.equal let hash=Hashtbl.hash end)
module Text_keys = Hashtbl.Make(struct type t=string let equal=String.equal let hash=Hashtbl.hash end)
(* Own only result/scratch, never the key arrays. Equal keys retain input order.
   ponytail: stdlib sorting/hash construction have no internal host cancellation
   checkpoint; thread a shared bulk checkpoint if that ceiling matters. *)
let grade keys descending =
  let count,compare=match keys with
    |Int_array values->Array.length values,(fun a b->Int.compare values.(a) values.(b))
    |Float_array values->
        Array.iter(fun value->ignore(fin "array/grade" value))values;
        Array.length values,(fun a b->Float.compare values.(a) values.(b))
    |Text_array values->Array.length values,(fun a b->String.compare values.(a) values.(b))
    |_->fail "E_ARRAY_TYPE" "Grade keys must be int, float or text arrays." in
  let order=Array.init count Fun.id in
  Array.stable_sort (if descending then (fun a b->compare b a)else compare)order;
  Int_array order
let index_of keys queries=match keys,queries with
  |Int_array keys,Int_array queries->
      let table=Int_keys.create(min(Array.length keys)65_536)in
      Array.iteri(fun i key->if not(Int_keys.mem table key)then Int_keys.add table key i)keys;
      Int_array(Array.map(fun key->Option.value ~default:(-1)(Int_keys.find_opt table key))queries)
  |Text_array keys,Text_array queries->
      let table=Text_keys.create(min(Array.length keys)65_536)in
      Array.iteri(fun i key->if not(Text_keys.mem table key)then Text_keys.add table key i)keys;
      Int_array(Array.map(fun key->Option.value ~default:(-1)(Text_keys.find_opt table key))queries)
  |_->fail "E_ARRAY_TYPE" "Index lookup needs matching int or text arrays."
let grade_type = function
  |[Ty.Array (Ty.Int|Float|Text|Any)]|[Ty.Any]->Ty.Array Ty.Int
  |_->fail "E_ARRAY_TYPE" "Grade keys must be int, float or text arrays."
let index_type = function
  |[Ty.Array Ty.Int;Ty.Array Ty.Int]|[Ty.Array Ty.Text;Ty.Array Ty.Text]
  |[Ty.Array (Ty.Int|Text|Any);Ty.Array Ty.Any]|[Ty.Array Ty.Any;Ty.Array (Ty.Int|Text)]
  |[Ty.Any;Ty.Array (Ty.Int|Text)]|[Ty.Array (Ty.Int|Text);Ty.Any]|[Ty.Any;Ty.Any]->Ty.Array Ty.Int
  |_->fail "E_ARRAY_TYPE" "Index lookup needs matching int or text arrays."
let reductions =
  [mk ~category:"Array" ~kw:["descending",Ty.Bool]
    "array/grade" ["keys",Ty.Array Ty.Any] grade_type
    {run=fun ~name:_ ~node:_ args->grade(List.assoc "keys" args)(Option.fold ~none:false ~some:truthy(List.assoc_opt "descending" args))};
   mk ~category:"Array" "array/index_of" ["keys",Ty.Array Ty.Any;"queries",Ty.Array Ty.Any] index_type
    {run=fun ~name:_ ~node:_ args->index_of(List.assoc "keys" args)(List.assoc "queries" args)};
   mk ~category:"Array" "array/compact" ["mask",Ty.Array Ty.Int] integer_array_type
    {run=fun ~name:_ ~node:_ args->compact_mask(List.assoc "mask" args)};
   mk ~category:"Array" "array/scan_sum" ["array",Ty.Array Ty.Int] integer_array_type
    {run=fun ~name:_ ~node:_ args->scan_sum(List.assoc "array" args)};
   mk ~category:"Array" "array/scatter_add"

    ["indices",Ty.Array Ty.Int;"values",Ty.Array Ty.Any;"size",Ty.Int] scatter_type
    {run=fun ~name:_ ~node:_ args->scatter_add (List.assoc "indices" args)
      (List.assoc "values" args) (List.assoc "size" args)}]
  @ List.map (fun operation ->
    let name="array/" ^ Private.reduction_name operation in
    mk ~category:"Array" name ["array",Ty.Array Ty.Any] (reduction_type false)
      {run=fun ~name:_ ~node:_ args -> Private.reduce_array operation (List.assoc "array" args)})
    [Private.Minimum;Maximum]
  @ List.map (fun operation ->
    let name="array/segment_" ^ Private.reduction_name operation in
    mk ~category:"Array" name ["values",Ty.Array Ty.Any;"offsets",Ty.Array Ty.Int] (reduction_type true)
      {run=fun ~name:_ ~node:_ args -> Private.reduce_array operation
        ~offsets:(List.assoc "offsets" args) (List.assoc "values" args)})
    [Private.Sum;Minimum;Maximum]
let constant_array ty count value =
  (* Validate one element through the shared packed-storage boundary. Empty
     arrays intentionally do not inspect their unused fill value. *)
  match constant_sample ty count value with
  | Int_array sample -> Int_array(Array.make count (if count=0 then 0 else sample.(0)))
  | Text_array sample -> Text_array(Array.make count (if count=0 then "" else sample.(0)))
  | Float_array sample -> Float_array(Array.make count (if count=0 then 0. else sample.(0)))
  | (Vec2_array sample|Vec3_array sample|Vec4_array sample) as array ->
      let width=match array with Vec2_array _->2|Vec3_array _->3|_->4 in
      let values=Array.make(count*width)0. in
      if count>0 then begin
        Array.blit sample 0 values 0 width;
        let filled=ref width in
        while !filled<Array.length values do
          let copied=min !filled (Array.length values - !filled) in
          Array.blit values 0 values !filled copied;
          filled:= !filled+copied
        done
      end;
      (match width with 2->Vec2_array values|3->Vec3_array values|_->Vec4_array values)
  | _->assert false
let arrays = [
  (let types=["float";"int";"text";"vec2";"vec3";"vec4"] in
   let message="Array capacity type is the literal int, text, float, vec2, vec3 or vec4." in
   let capacity = function
     | "int" | "text" -> Sys.max_array_length
     | "float" -> Sys.max_floatarray_length
     | "vec2" -> Sys.max_floatarray_length / 2
     | "vec3" -> Sys.max_floatarray_length / 3
     | "vec4" -> Sys.max_floatarray_length / 4
     | _ -> fail "E_ARRAY_TYPE" message in
   let op=mk ~category:"Array" ~kw:["type",Ty.Text] ~choices:["type",types]
     "array/max_length" [] (fun _->Ty.Int)
     {run=fun ~name:_ ~node:_ args ->Int(capacity(match List.assoc_opt "type" args with
       |None->"float"|Some(Text ty)->ty|_->fail "E_ARRAY_TYPE" message))} in
   {op with out_args=Some(fun args->
      (match List.find_opt(fun(name,_,_)->name="type")args with
       |None->()|Some(_,_,Some(Param.Text_value ty))->ignore(capacity ty)
       |_->fail "E_ARRAY_TYPE" message);Ty.Int)});

  (let op = mk ~category:"Array" ~kw:["type",Ty.Text] ~choices:["type",["float";"int"]]
    "array/range" ["count", Ty.Int] (fun _ -> Ty.Array fl)
    {run = fun ~name ~node:_ args ->
      (match List.assoc_opt "type" args with None | Some (Text ("int"|"float")) -> ()
       | _ -> fail "E_ARRAY_TYPE" "array/range type is float or int.");
      if List.assoc_opt "type" args = Some (Text "int") then
        Int_array (Array.init (array_count ~limit:Sys.max_array_length name (List.assoc "count" args)) Fun.id)
      else
      (* [array_init]'s result without a boxed value per index (40 bytes each at 1,000,000);
         [array_count] has already bounded the length, and an index is always finite. *)
      let data = Array.make (array_count name (List.assoc "count" args)) 0. in
      for i = 0 to Array.length data - 1 do Array.unsafe_set data i (float i) done;
      Float_array data} in {op with out_args=Some range_type});
  mk ~category:"Array" ~opt:["value",Ty.Int] "array/int" ["count",Ty.Int] (fun _ -> Ty.Array Ty.Int)
    {run=fun ~name ~node:_ args ->
      let value=Option.value ~default:(Int 0) (List.assoc_opt "value" args) in
      constant_array Ty.Int (array_count ~limit:Sys.max_array_length name (List.assoc "count" args)) value};
  mk ~category:"Array" ~opt:["value",Ty.Text] "array/text" ["count",Ty.Int] (fun _ -> Ty.Array Ty.Text)
    {run=fun ~name ~node:_ args ->
      let value=Option.value ~default:(Text "") (List.assoc_opt "value" args) in
      constant_array Ty.Text (array_count ~limit:Sys.max_array_length name (List.assoc "count" args)) value};
  mk ~category:"Array" ~opt:["value", fl] "array/float" ["count", Ty.Int] (fun _ -> Ty.Array fl)
    {run = fun ~name ~node:_ args ->
      let value = Option.value ~default:(Float 0.) (List.assoc_opt "value" args) in
      constant_array fl (array_count name (List.assoc "count" args)) value};
  mk ~category:"Array" ~opt:["value", Ty.Vec3] "array/vec3" ["count", Ty.Int] (fun _ -> Ty.Array Ty.Vec3)
    {run = fun ~name ~node:_ args ->
      let value = Option.value ~default:(Vec3 (0., 0., 0.)) (List.assoc_opt "value" args) in
      constant_array Ty.Vec3 (array_count name (List.assoc "count" args)) value};
  mk ~category:"Array" ~opt:["value",Ty.Vec4] "array/vec4" ["count",Ty.Int] (fun _ -> Ty.Array Ty.Vec4)
    {run = fun ~name ~node:_ args ->
      let value=Option.value ~default:(Vec4(0.,0.,0.,0.)) (List.assoc_opt "value" args) in
      constant_array Ty.Vec4 (array_count name (List.assoc "count" args)) value};
  mk ~category:"Array" "array/count" ["array", Ty.Array Ty.Any] (fun _ -> Ty.Int)
    {run = fun ~name:_ ~node:_ args -> Int (array_length (List.assoc "array" args))};
  mk ~category:"Array" "array/nth" ["array", Ty.Array Ty.Any; "index", Ty.Int]
    (function Ty.Array e :: _ -> e | _ -> Ty.Any)
    {run = fun ~name ~node:_ args -> array_get (List.assoc "array" args)
      (array_count ~limit:Sys.max_array_length name (List.assoc "index" args))};
  mk ~category:"Array" "array/slice" ["array",Ty.Array Ty.Any;"first",Ty.Int;"count",Ty.Int]
    (function (Ty.Array _ as ty)::_ ->ty|_->Ty.Array Ty.Any)
    {run=fun ~name ~node:_ args->
      let first=array_count name(List.assoc "first" args)and count=array_count name(List.assoc "count" args)in
      let slice width values=if first>Array.length values/width || count>Array.length values/width-first
        then fail "E_ARRAY_RANGE" "An array slice must be within its source.";
        Array.sub values (first*width)(count*width)in
      match List.assoc "array" args with Int_array xs->Int_array(slice 1 xs)
        |Text_array xs->Text_array(slice 1 xs)
        |Float_array xs->Float_array(slice 1 xs)
        |Vec2_array xs->Vec2_array(slice 2 xs)
        |Vec3_array xs->Vec3_array(slice 3 xs)|Vec4_array xs->Vec4_array(slice 4 xs)
        |_->fail "E_TYPE" "Expected a packed array."};
  mk ~category:"Array" "array/concat" ["first",Ty.Array Ty.Any;"second",Ty.Array Ty.Any]
    (function (Ty.Array _ as ty)::_ ->ty|_->Ty.Array Ty.Any)
    {run=fun ~name:_ ~node:_ args->match List.assoc "first" args,List.assoc "second" args with
      |Int_array a,Int_array b->Int_array(Array.append a b)
      |Text_array a,Text_array b->Text_array(Array.append a b)
      |Float_array a,Float_array b->Float_array(Array.append a b)
      |Vec2_array a,Vec2_array b->Vec2_array(Array.append a b)
      |Vec3_array a,Vec3_array b->Vec3_array(Array.append a b)
      |Vec4_array a,Vec4_array b->Vec4_array(Array.append a b)
      |_->fail "E_ARRAY_TYPE" "Concatenated arrays must have the same element type."};
  mk ~category:"Array" "array/sum" ["array", Ty.Array Ty.Any]
    (function Ty.Array e :: _ -> e | _ -> Ty.Any)
    {run = fun ~name:_ ~node:_ args ->
      let xs = List.assoc "array" args in
      match xs with
      | Text_array _ -> fail "E_TYPE" "array/sum adds numbers or matching-width vectors."
      | Int_array values -> Int (Array.fold_left (Packed_ops.integer_apply Packed_ops.Iadd) 0 values)
      | _ ->
      let sum = ref (match xs with Int_array _ -> Int 0 | Vec2_array _ -> Vec2 (0., 0.)
        | Vec3_array _ -> Vec3 (0., 0., 0.) | Vec4_array _ -> Vec4 (0., 0., 0., 0.) | _ -> Float 0.) in
      for i = 0 to array_length xs - 1 do sum := Value.arith "array/sum" ( +. ) !sum (array_get xs i) done;
      !sum};
]

let is_display_kind name = String.starts_with ~prefix:"draw/" name
  || String.starts_with ~prefix:"ui/" name

let draw_op ?rest ?kw name pos =
  mk ~ctx:Context.draw ?rest ?kw ~category:"Drawing" name pos (fun _ -> Ty.drawing)
    {run = fun ~name ~node args -> node name args}

let draw = [
  draw_op ~kw:["at",Ty.Vec3;"scale",Ty.Float;"angle",Ty.Float] "draw/image" ["image",Ty.image];
  draw_op "draw/background" ["color", Ty.Color];
  draw_op ~kw:["color", Ty.Color] "draw/point" ["at", Ty.Vec3];
  draw_op ~kw:["color", Ty.Color] "draw/points" ["positions", Ty.Array Ty.Vec3];
  draw_op ~kw:["color", Ty.Color; "width", Ty.Int] "draw/line" ["from", Ty.Vec3; "to", Ty.Vec3];
  draw_op ~kw:["fill", Ty.Color; "stroke", Ty.Color] "draw/rect" ["at", Ty.Vec3; "size", Ty.Vec3];
  draw_op ~kw:["fill", Ty.Color; "stroke", Ty.Color] "draw/circle" ["at", Ty.Vec3; "radius", Ty.Int];
  (* Noise and generative sketches need packed RGB; stroke widths remain uniform. *)
  draw_op ~kw:["radius", Ty.Any; "fill", Ty.Any; "stroke", Ty.Any] "draw/circles" ["positions", Ty.Array Ty.Vec3];
  draw_op ~kw:["fill", Ty.Any; "stroke", Ty.Any] "draw/rects" ["positions", Ty.Array Ty.Vec3; "sizes", Ty.Any];
  draw_op ~kw:["color", Ty.Any; "width", Ty.Float] "draw/lines" ["from", Ty.Array Ty.Vec3; "to", Ty.Array Ty.Vec3];
  draw_op ~kw:["color", Ty.Color; "size", Ty.Int] "draw/text" ["at", Ty.Vec3; "text", Ty.Text];
  draw_op "draw/translate" ["offset", Ty.Vec3; "drawing", Ty.drawing];
  draw_op "draw/rotate" ["angle", Ty.Float; "drawing", Ty.drawing];
  draw_op "draw/scale" ["factor", Ty.Any; "drawing", Ty.drawing];
  draw_op ~kw:["radius", Ty.Int; "fill", Ty.Color; "stroke", Ty.Color] "draw/rounded_rect" ["at", Ty.Vec3; "size", Ty.Vec3];
  draw_op ~kw:["fill", Ty.Color; "stroke", Ty.Color] "draw/polygon" ["points", Ty.Array Ty.Vec3];
  draw_op ~kw:["color", Ty.Color] "draw/polyline" ["points", Ty.Array Ty.Vec3];
  draw_op ~rest:("drawing", Ty.Any) "draw/merge" [];
]

let host_op ?kw ?choices name pos out =
  mk ~ctx:Context.host ?kw ?choices ~category:"Host" name pos (fun _->Ty.Named out)
    {run=fun ~name ~node args->node name args}
let host = [
  host_op "host/quit" ["when",Ty.Bool] "effect";
  host_op "host/save_png" ["path",Ty.Text;"when",Ty.Bool] "effect";
  host_op ~kw:["filters",Ty.Any;"default",Ty.Text]
    ~choices:["kind",["open_file";"open_files";"save_file";"open_folder"]]
    "host/dialog" ["kind",Ty.Text;"when",Ty.Bool] "effect";
  host_op ~kw:["volume",Ty.Float;"loops",Ty.Int] "host/play"
    ["sample",Ty.Named "sample";"when",Ty.Bool] "effect";
  host_op ~kw:["waveform",Ty.Text;"frequency",Ty.Float;"duration",Ty.Float;"volume",Ty.Float]
    ~choices:["waveform",["sine";"square";"triangle";"sawtooth"]] "audio/synth" [] "sample";
  host_op "audio/load" ["path",Ty.Text] "sample";
]
let integers = List.map(fun operation ->
  let name = Packed_ops.integer_name operation in
  mk ~category:"Integer" name ["a",Ty.Int;"b",Ty.Int] (fun _->Ty.Int)
    {run=fun ~name:_ ~node:_ args->
      let integer=function Int value->value|value->int_of value in
      let a=integer(List.assoc "a" args)and b=integer(List.assoc "b" args)in
      Int (Packed_ops.integer_apply operation a b)})
  Packed_ops.[Iadd; Isub; Imul; Idiv; Imod; Iand; Ior; Ixor; Ishl; Ishr]
  @ List.map (fun comparison ->
    let name = Packed_ops.comparison_name comparison in
    mk ~category:"Integer" name ["a",Ty.Int;"b",Ty.Int] (fun _ -> Ty.Bool)
      {run=fun ~name:_ ~node:_ args ->
        let integer=function Int value->value|value->int_of value in
        Bool (Packed_ops.comparison_apply comparison
          (integer (List.assoc "a" args)) (integer (List.assoc "b" args)))})
    Packed_ops.[Ilt; Ile; Igt; Ige; Ieq]

(* Constructor arguments remain typed values, including live fields; [node]
   creates the deferred payload instead of residualizing the whole call. *)
let images = [
  mk ~category:"Image" ~shape:(Struct {splice=false}) "image/load" ["path",Ty.Text] (fun _->Ty.image)
    {run=fun ~name ~node args->node name args};
  mk ~category:"Image" ~shape:(Struct {splice=false}) ~kw:["width",Ty.Int;"height",Ty.Int] "image/render"
    ["drawing",Ty.drawing] (fun _->Ty.image) {run=fun ~name ~node args->node name args};
  mk ~category:"Image" ~shape:(Struct {splice=false}) ~kw:["width",Ty.Int;"height",Ty.Int;"frequency",Ty.Float;"freq",Ty.Float;"seed",Ty.Int]
    "image/noise" [] (fun _->Ty.image) {run=fun ~name ~node args->node name args};
  mk ~category:"Image" ~shape:(Struct {splice=false}) ~kw:["width",Ty.Int;"height",Ty.Int]
    "image/map" ["function",Ty.Fn (Some {params=[Ty.Vec2];result=Ty.Vec4})]
    (fun _->Ty.image) {run=fun ~name ~node args->node name args};
]

let all = frame @ arrays @ reductions @ draw @ host @ integers @ images @ [
  float_unary "tan" tan;
  float_unary "asin" asin;
  float_unary "acos" acos;
  float_unary "log" log;
  float_unary "sign" (fun x -> if x > 0. then 1. else if x < 0. then -1. else x);
  float_binary "atan2" atan2;
  float_binary "hypot" Float.hypot;
  mk ~category:"Vector" "dot" ["a",Ty.Vec3;"b",Ty.Vec3] (fun _ -> fl)
    {run=fun ~name ~node:_ args ->
      Float (fin name (dot3 (comps (List.assoc "a" args)) (comps (List.assoc "b" args))))};
  mk ~category:"Vector" "cross" ["a",Ty.Vec3;"b",Ty.Vec3] (fun _ -> Ty.Vec3)
    {run=fun ~name ~node:_ args ->
      let x,y,z = comps (List.assoc "a" args) and a,b,c = comps (List.assoc "b" args) in
      let product x y = Sys.opaque_identity (x *. y) in
      Vec3 (fin name (Float.fma (-.z) b (product y c)),
        fin name (Float.fma (-.x) c (product z a)),
        fin name (Float.fma (-.y) a (product x b)))};
  mk ~category:"Vector" "normalize" ["vector",Ty.Vec3] (fun _ -> Ty.Vec3)
    {run=fun ~name ~node:_ args ->
      let x,y,z = comps (List.assoc "vector" args) in
      let size = fin name (sqrt (dot3 (x,y,z) (x,y,z))) in
      if size = 0. then Vec3 (0.,0.,0.)
      else let reciprocal = 1. /. size in
        Vec3 (fin name (x *. reciprocal),fin name (y *. reciprocal),fin name (z *. reciprocal))};
  mk ~category:"Vector" "length" ["vector", Ty.Vec3] (fun _ -> fl)
    {run = fun ~name ~node:_ args -> match List.assoc "vector" args with
      | Vec3 (x,y,z) ->
          (* Match the separately rounded Mul/Add instructions of packed kernels. *)
          let xx = Sys.opaque_identity (x *. x)
          and yy = Sys.opaque_identity (y *. y)
          and zz = Sys.opaque_identity (z *. z) in
          Float (fin name (sqrt ((xx +. yy) +. zz)))
      | _ -> fail "E_TYPE" "length needs a vec3."};
  mk ~category:"Math" "fma" ["a",Ty.Float;"b",Ty.Float;"c",Ty.Float] (fun _->Ty.Float)
    {run=fun ~name ~node:_ args ->
      let input n=fin name(num(List.assoc n args)) in
      let a=input "a" and b=input "b" and c=input "c" in
      Float(fin name(Float.fma a b c))};
  mk ~category:"Math" "float/mul_checked" ["a",Ty.Float;"b",Ty.Float]
    (fun _ -> Ty.Record ["value",Ty.Float;"valid",Ty.Bool])
    {run=fun ~name ~node:_ args ->
      let a=fin name(num(List.assoc "a" args)) and b=fin name(num(List.assoc "b" args)) in
      let value=Sys.opaque_identity(a *. b) in
      let valid=Float.is_finite value in
      Record ["value",Float(if valid then value else 0.);"valid",Bool valid]};
  mk ~category:"Math" "float/fma_checked" ["a",Ty.Float;"b",Ty.Float;"c",Ty.Float]
    (fun _ -> Ty.Record ["value",Ty.Float;"valid",Ty.Bool])
    {run=fun ~name ~node:_ args ->
      let input key=fin name(num(List.assoc key args)) in
      let a=input "a" and b=input "b" and c=input "c" in
      let value=Float.fma a b c in
      let valid=Float.is_finite value in
      Record ["value",Float(if valid then value else 0.);"valid",Bool valid]};
  mk ~category:"Random" "rand/at" ["seed",Ty.Int;"index",Ty.Int] (fun _->Ty.Float)
    {run=fun ~name:_ ~node:_ args -> match List.assoc "seed" args,List.assoc "index" args with
      | Int seed,Int index -> Float(Packed_ops.rand_at seed index)
      | _ -> fail "E_TYPE" "rand/at needs integer seed and index."};
  mk ~category:"Compare" "equal?" ["a",Ty.Any;"b",Ty.Any] (fun _->Ty.Bool)
    {run=fun ~name:_ ~node:_ args->try Bool(List.assoc "a" args=List.assoc "b" args)
      with Invalid_argument _->fail "E_TYPE" "Functions cannot be compared."};
  mk ~category:"Text" "text/blank?" ["text",Ty.Text] (fun _ -> Ty.Bool)
    {run=fun ~name:_ ~node:_ args -> match List.assoc "text" args with
      | Text s -> Bool (String.trim s = "")
      | _ -> fail "E_TYPE" "Expected text."};
  mk ~category:"Text" "text/trim" ["text",Ty.Text] (fun _ -> Ty.Text)
    {run=fun ~name:_ ~node:_ args -> match List.assoc "text" args with
      | Text text -> Text(String.trim text) | _ -> fail "E_TYPE" "Expected text."};
  mk ~category:"Text" "text/lower" ["text",Ty.Text] (fun _ -> Ty.Text)
    {run=fun ~name:_ ~node:_ args -> match List.assoc "text" args with
      | Text text -> Text(String.lowercase_ascii text) | _ -> fail "E_TYPE" "Expected text."};
  mk ~category:"Text" "text/repr" ["text",Ty.Text] (fun _ -> Ty.Text)
    {run=fun ~name:_ ~node:_ args -> match List.assoc "text" args with
      | Text text -> Text(Printf.sprintf "%S" text) | _ -> fail "E_TYPE" "Expected text."};
  mk ~category:"Value" ~kw:["cause",Ty.Text] "error" ["code",Ty.Text;"message",Ty.Text] (fun _ -> Ty.Any)
    {run=fun ~name:_ ~node:_ args -> match List.assoc "code" args,List.assoc "message" args with
      | Text code,Text message ->
          let cause=match List.assoc_opt "cause" args with None->None|Some(Text text)->Some text
            |_->fail "E_TYPE" "error cause must be text." in
          Value.raise_diagnostic(Diagnostic.error ?cause ~code message)
      | _ -> fail "E_TYPE" "error needs text code and message."};
  mk ~category:"Text" "text/table_decode" ["text",Ty.Text]
    (fun _ -> Ty.List (Ty.List Ty.Text))
    {run=fun ~name:_ ~node:_ args -> match List.assoc "text" args with
      | Text text -> (match Param.String_table.decode text with
          | Error message -> fail "E_TABLE" message
          | Ok rows -> List (Array.of_list (List.map (fun row ->
              List (Array.of_list (List.map (fun cell -> Text cell) row))) rows)))
      | _ -> fail "E_TYPE" "Expected text."};
  mk ~category:"Text" "text/table_encode" ["rows",Ty.List (Ty.List Ty.Text)]
    (fun _ -> Ty.Text)
    {run=fun ~name:_ ~node:_ args -> match List.assoc "rows" args with
      | List rows ->
          let rows=Array.to_list rows |> List.map(function
            | List cells -> Array.to_list cells |> List.map(function Text cell->cell
                | _->fail "E_TYPE" "Table cells must be text.")
            | _->fail "E_TYPE" "Table rows must be lists of text.") in
          Text (Param.String_table.encode rows)
      | _ -> fail "E_TYPE" "Expected a table of text cells."};
  unary ~category:"Math" "exp" (fun _->fl) {run=fun ~name ~node:_ args->
    Float(fin name(exp(num(List.assoc "x" args))))};
  mk ~category:"Convert" "exact" ["value", Ty.Any]
    (function ty :: _ -> ty | _ -> Ty.Any)
    {run = fun ~name ~node args ->
      let value = List.assoc "value" args in
      if Value.ty_of value = Ty.image then node name args else value};
  binary "+" (( +. ));
  binary "-" (( -. ));
  binary "*" (( *. ));
  binary "/" ((fun x y -> if y = 0. then 0. else x /. y));
  binary "mod" ((fun x y -> if y = 0. then 0. else Float.rem (Float.rem x y +. y) y));
  binary "pow" ((fun x y -> Float.pow (Float.abs x) y));
  binary "min" (Float.min);
  binary "max" (Float.max);
  unary ~category:"Math" "sin" (fun _ -> fl) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ x ] -> Float (fin name (sin (num x)))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  unary ~category:"Math" "cos" (fun _ -> fl) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ x ] -> Float (fin name (cos (num x)))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  unary ~category:"Math" "sqrt" (fun _ -> fl) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ x ] -> Float (sqrt (Float.abs (num x)))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  unary ~category:"Convert" "floor" (fun _ -> Ty.Int) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ x ] -> Int (to_int name (Float.floor (num x)))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  unary ~category:"Convert" "ceil" (fun _ -> Ty.Int) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ x ] -> Int (to_int name (Float.ceil (num x)))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  unary ~category:"Convert" "round" (fun _ -> Ty.Int) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ x ] -> Int (to_int name (Float.round (num x)))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  unary ~category:"Convert" "int" (fun _ -> Ty.Int) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ x ] -> Int (to_int name (Float.trunc (num x)))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  unary ~category:"Convert" "float" (fun _ -> fl) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ x ] -> Float (num x)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  unary ~category:"Math" "abs" (function Ty.Int :: _ -> Ty.Int | _ -> fl) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ Int n ] -> Int (abs n)
    | [ x ] -> Float (Float.abs (num x))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  compare_op ~category:"Compare" "<" { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ a; b ] -> Bool (num a < num b)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  compare_op ~category:"Compare" ">" { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ a; b ] -> Bool (num a > num b)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  compare_op ~category:"Compare" "<=" { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ a; b ] -> Bool (num a <= num b)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  compare_op ~category:"Compare" ">=" { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ a; b ] -> Bool (num a >= num b)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  compare_op ~category:"Compare" "=" { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ a; b ] -> Bool (num a = num b)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  bool_op ~category:"Compare" "and" [ "a", Ty.Bool; "b", Ty.Bool ] { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ a; b ] -> Bool (truthy a && truthy b)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  bool_op ~category:"Compare" "or" [ "a", Ty.Bool; "b", Ty.Bool ] { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ a; b ] -> Bool (truthy a || truthy b)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  bool_op ~category:"Compare" "not" [ "a", Ty.Bool ] { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ a ] -> Bool (not (truthy a))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"Math" ~rest:("key", fl) "value/rand" [] (fun _ -> fl)
    { run = fun ~name:_ ~node:_ args -> Float (hash (List.map (fun (_,v) -> num v) args)) };
  mk ~category:"Math" "value/hsv" [ "h", fl; "s", fl; "v", fl ] (fun _ -> Ty.Vec3) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ h; s; v ] -> let r, g, b = hsv (num h) (num s) (num v) in Vec3 (fin name r, fin name g, fin name b)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"Math" ~any_num:true "value/lerp" [ "a", fl; "b", fl; "u", fl ] (fun ts ->
    match ts with a :: b :: _ when a = Ty.Vec3 || b = Ty.Vec3 -> Ty.Vec3 | _ -> fl) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ a; b; u ] -> let u = num u in
      if is_vec a || is_vec b then begin
        let ax, ay, az = comps a and bx, by, bz = comps b in
        let l x y = Sys.opaque_identity (x *. (1. -. u)) +. Sys.opaque_identity (y *. u) in
        Vec3 (fin name (l ax bx), fin name (l ay by), fin name (l az bz))
      end else Float (fin name (Sys.opaque_identity (num a *. (1. -. u)) +. Sys.opaque_identity (num b *. u)))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"Math" ~opt:[ "height", fl ] "value/polar" [ "radius", fl; "angle", fl ] (fun _ -> Ty.Vec3) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | (r :: a :: h) -> let r = num r and a = num a in
      Vec3 (fin name (r *. cos a), (match h with [ h ] -> num h | _ -> 0.), fin name (r *. sin a))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"List" ~opt:[ "end", Ty.Int ] "range" [ "count", Ty.Int ] (fun _ -> Ty.List Ty.Int) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ n ] -> range 0 (int_of n)
    | [ a; b ] -> range (int_of a) (int_of b)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"List" "linspace" [ "from", fl; "to", fl; "count", Ty.Int ] (fun _ -> Ty.List fl) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ a; b; n ] -> let a = num a and b = num b and n = int_of n in
      if n > max_iterations then fail "E_ITER_BOUND" "linspace exceeds 4,096 values.";
      List (Array.init (max 0 n) (fun k ->
        Float (if n = 1 then a else a +. (b -. a) *. float_of_int k /. float_of_int (n - 1))))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"List" "count" [ "list", Ty.List Ty.Any ] (fun _ -> Ty.Int) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ l ] -> Int (Array.length (list_arg l))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"List" "first" [ "list", Ty.List Ty.Any ] (elm 0) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ l ] -> let xs = list_arg l in
      if xs = [||] then fail "E_LIST_RANGE" "first of an empty list." else xs.(0)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"List" "last" [ "list", Ty.List Ty.Any ] (elm 0) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ l ] -> let xs = list_arg l in
      if xs = [||] then fail "E_LIST_RANGE" "last of an empty list." else xs.(Array.length xs - 1)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"List" "rest" [ "list", Ty.List Ty.Any ] (lst 0) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ l ] -> let xs = list_arg l in
      List (if xs = [||] then xs else Array.sub xs 1 (Array.length xs - 1))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"List" "nth" [ "list", Ty.List Ty.Any; "index", Ty.Int ] (elm 0) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ l; i ] -> (match i with
       | Float f when not (Float.is_integer f) -> failf "E_LIST_RANGE" "nth index %g is not a whole number." f
       | _ -> ());
      let xs = list_arg l and i = int_of i in
      if i < 0 || i >= Array.length xs then
        failf "E_LIST_RANGE" "nth index %d is out of range for a list of length %d." i (Array.length xs)
      else xs.(i)
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"List" "reverse" [ "list", Ty.List Ty.Any ] (lst 0) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ l ] -> let xs = list_arg l in
      let n = Array.length xs in List (Array.init n (fun i -> xs.(n - 1 - i)))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"List" "take" [ "n", Ty.Int; "list", Ty.List Ty.Any ] (lst 1) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ n; l ] -> let xs = list_arg l and n = max 0 (int_of n) in List (Array.sub xs 0 (min n (Array.length xs)))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~category:"List" "drop" [ "n", Ty.Int; "list", Ty.List Ty.Any ] (lst 1) { run = fun ~name ~node:_ args ->
    match List.map snd args with
    | [ n; l ] -> let xs = list_arg l in
      let n = min (max 0 (int_of n)) (Array.length xs) in List (Array.sub xs n (Array.length xs - n))
    | _ -> failf "E_ARITY" "%s got the wrong number of inputs." name };
  mk ~ctx:Context.sop ~kw:[ "closed", Ty.Bool; "filled", Ty.Bool ] "sop/curve" [ "points", Ty.List Ty.Vec3 ] (fun _ -> Ty.geometry) { run = fun ~name ~node args -> node name args };
  structure ~ctx:Context.sop ~kw:[ "key", Ty.Text ] "sop/point_list" [ "geometry", Ty.geometry ] (fun _ -> Ty.List Ty.Vec3);
  structure ~ctx:Context.sop ~kw:[ "key", Ty.Text ] "sop/piece_list" [ "geometry", Ty.geometry ] (fun _ -> Ty.List Ty.geometry);
  structure ~splice:true ~ctx:Context.scene ~rest:("scene", Ty.scene) "scene/merge" [] (fun _ -> Ty.scene);
  structure ~ctx:Context.material ~kw:["name", Ty.Text; "color", Ty.Color;
    "roughness", Ty.Float; "emission", Ty.Color] "material/standard" [] (fun _ -> Ty.material);
  structure ~ctx:Context.world "world/none" [] (fun _ -> Ty.world);
  structure ~ctx:Context.editor ~kw:["effects",Ty.Any] "ui/workspace" [ "root", Ty.panel ] (fun _ -> Ty.editor);
  leaf ~kw:[ "look_through", Ty.Bool ] "ui/viewport" [ "scene", Ty.scene ];
  leaf "ui/canvas" ["drawing", Ty.drawing];
  leaf ~choices:["wires", ["rect"; "straight"]; "view", ["graph"; "list"; "text"]]
    ~check:{ validate = fun choices args -> one_of args "view" "A graph panel's view" (List.assoc "view" choices) }
    ~opt:["graph", Ty.Text] ~kw:["wires", Ty.Text; "view", Ty.Text] "ui/graph" [];
  leaf ~kw:[ "of", Ty.panel ] "ui/inspector" [];
  leaf ~kw:[ "of", Ty.panel ] "ui/spreadsheet" [];
  leaf "ui/outline" [];
  leaf ~kw:[ "of", Ty.panel ] "ui/list" [];
  leaf ~choices:["tab", ["selection"; "graph"; "document"]]
    ~check:{ validate = fun choices args -> one_of args "tab" "A lisp panel's tab" (List.assoc "tab" choices) }
    ~kw:[ "tab", Ty.Text; "of", Ty.panel ] "ui/lisp" [];
  leaf "ui/timeline" [];
  panel ~choices:["axis", ["horizontal"; "vertical"]] ~check:{ validate = split_check } ~kw:[ "first_size", Ty.Int; "second_size", Ty.Int ] "ui/split"
    [ "axis", Ty.Text; "first", Ty.panel; "second", Ty.panel ];
  panel ~choices:["axis", ["horizontal"; "vertical"]] ~check:{ validate = split_at_check } "ui/split-at" [ "axis", Ty.Text; "ratio", fl; "first", Ty.panel; "second", Ty.panel ];
  panel ~splice:true ~check:{ validate = fun _ args -> tile_check args } ~rest:("panel", Ty.panel) "ui/tile" [];
  panel "ui/floating" [ "panel", Ty.panel ];
  panel ~check:{ validate = fun _ args -> switch_check args } ~rest:("panel", Ty.panel) ~kw:["active", Ty.Int] "ui/switch" []
]

let table =
  let h = Hashtbl.create 64 in
  List.iter (fun o -> if Hashtbl.mem h o.name then invalid_arg ("Duplicate operator: " ^ o.name);
    Hashtbl.add h o.name o) all;
  h
let lookup extra name = match extra with
  | [] -> Hashtbl.find_opt table name
  | _ -> (match List.find_opt (fun op -> op.name = name) extra with
      | Some _ as op -> op | None -> Hashtbl.find_opt table name)
let find ?(extra = []) name ctx =
  match lookup extra name with
  | Some _ as o -> o
  | None -> (match lookup extra ("value/" ^ name) with
      | Some _ as o -> o
      | None -> lookup extra (Context.name ctx ^ "/" ^ name))
(* [find ~extra] for many names: the extras are indexed once (the first of a name wins, as in the
   list), where [find] scans the list for each of its three tries. Read-only once made. *)
let finder extra =
  let index = Hashtbl.create (2 * List.length extra + 1) in
  List.iter (fun op -> if not (Hashtbl.mem index op.name) then Hashtbl.add index op.name op) extra;
  let lookup name = match Hashtbl.find_opt index name with
    | Some _ as op -> op | None -> Hashtbl.find_opt table name in
  fun name ctx -> match lookup name with
    | Some _ as o -> o
    | None -> (match lookup ("value/" ^ name) with
        | Some _ as o -> o
        | None -> lookup (Context.name ctx ^ "/" ^ name))
let of_context ?(extra = []) ctx =
  let all = all @ extra in
  (if ctx = Context.value then [] else List.filter (fun o -> o.ctx = ctx) all)
  @ List.filter (fun o -> o.ctx = Context.value) all
let result_type op args = match op.out_args with
  | Some out -> out args
  | None ->
      let positional = List.map fst (op.signature.pos @ op.signature.opt) in
      op.out (List.filter_map (fun (name, ty, _) ->
        if List.mem name positional then Some ty else None) args)
let arith name = Option.bind (Hashtbl.find_opt table name) (fun o -> o.arithmetic)

let valid_extension op = match op.packed_extension with
  | None -> true
  | Some Packed_ops.Noise3 ->
      op.name = "noise3" && op.ctx = Context.value && op.shape = Scalar
      && not op.live && not op.any_num && op.arithmetic = None && op.out_args = None
      && op.signature.pos = ["position", Ty.Vec3]
      && op.signature.opt = [] && op.signature.rest = None
      && List.sort Stdlib.compare op.signature.kw = ["octaves", Ty.Int; "seed", Ty.Int]
      && (try op.out [Ty.Vec3] = Ty.Float
          with Value.Fail _ | Invalid_argument _ -> false)

let packed_kind op =
  if op.ctx <> Context.value || op.shape <> Scalar then None
  else if Option.fold ~none:false ~some:((==) op) (Hashtbl.find_opt table op.name) then
    match Packed_ops.binary op.name, Packed_ops.unary op.name with
    | Some binary, _ -> Some (Binary binary)
    | _, Some unary -> Some (Unary unary)
    | _ when Option.is_some (Packed_ops.integer op.name) -> Some (Integer (Option.get (Packed_ops.integer op.name)))
    | _ when Option.is_some (Packed_ops.comparison op.name) -> Some (Integer_compare (Option.get (Packed_ops.comparison op.name)))
    | _ when List.mem op.name ["float";"int";"floor";"ceil";"round"] ->
        Some (Convert (match op.name with "float" -> Packed_ops.To_float | "floor" -> Floor
          | "ceil" -> Ceil | "round" -> Round | _ -> Truncate))
    | _ when op.name = "length" -> Some Length
    | _ when op.name = "dot" -> Some Dot
    | _ when op.name = "cross" -> Some Cross
    | _ when op.name = "normalize" -> Some Normalize
    | _ when op.name = "fma" -> Some Fma
    | _ when op.name = "float/mul_checked" -> Some Checked_mul
    | _ when op.name = "float/fma_checked" -> Some Checked_fma
    | _ when op.name = "rand/at" -> Some Rand_at
    | _ when op.name = "exact" -> Some Exact
    | _ when op.name = "array/nth" -> Some Gather
    | _ when op.live -> Some Frame
    | _ -> Some Constant_only
  else match op.packed_extension with
    | Some Packed_ops.Noise3 when valid_extension op -> Some Noise3
    | _ -> None

let validate extra =
  let seen = Hashtbl.create 16 in
  List.find_map (fun op ->
    let valid = match String.split_on_char '/' op.name with
      | [name] -> Symbol.valid_name name && not (Symbol.reserved name)
      | [prefix; name] -> Symbol.valid_name prefix && Symbol.valid_name name
      | _ -> false in
    if not valid || Hashtbl.mem table op.name || Hashtbl.mem seen op.name then
      Some (Diagnostic.error ~code:"E_OP_DECLARATION" ("Invalid or duplicate extra operator " ^ op.name))
    else if not (valid_extension op) then
      Some (Diagnostic.error ~code:"E_OP_DECLARATION"
        ("Invalid packed capability for " ^ op.name ^
         ": noise3 requires a scalar value declaration with position:vec3, seed:int/octaves:int keywords and float result."))
    else (Hashtbl.add seen op.name (); None)) extra
