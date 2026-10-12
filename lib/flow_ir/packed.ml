module E = Flow.Eval
module W = Flow.Workspace
module V = Flow.Value
module Ty = Flow.Ty

type binary = Flow.Packed_ops.binary = Add | Sub | Mul | Div | Mod | Pow | Min | Max | Lt | Le | Gt | Ge | Eq | And | Or | Atan2 | Hypot
type unary = Flow.Packed_ops.unary = Sin | Cos | Sqrt | Abs | Not | Tan | Asin | Acos | Exp | Log | Sign
type conversion = Core.Region.conversion = To_float | Truncate | Floor | Ceil | Round | Coerce_int | Integer_result of string
type instruction = Core.Region.instruction = Const of float | Input of int * int * int
  | Uniform of int * int | Frame of string | Accumulator of int
  | Binary of binary * int * int | Unary of unary * int | Noise3 of int * int * int * int * int
  | Select of int * int * int
  | Int_const of int | Int_input of int | Int_uniform of int | Int_frame of string | Int_accumulator
  | Int_binary of Flow.Packed_ops.integer * int * int
  | Int_compare of Flow.Packed_ops.comparison * int * int | Int_abs of int
  | Convert of conversion * int | Int_select of int * int * int
  | Guarded of (int * bool) list * instruction | Raise of Ty.t * string * string
type iteration = Core.Region.iteration = Zip | Product
type result = Core.Region.result = Collect | Sum of bool | Accumulate of W.term * bool
type origin = W.path * int list
type count_source = E.residual -> W.term -> origin option
type column = {data:float array;offset:int;stride:int}
type t = { residual : E.residual; term : W.term; sources : (E.residual * W.term) array;
  widths : int array; uniforms : E.value array; code : instruction array;
  dependent : bool array; outputs : int array array; count : int option;
  iteration : iteration; result : result; skip : int array;
  stages : (E.residual * W.term) list; fusion : bool; dynamic : bool;
  body : W.term; binding_fn : string option; uniform_names : (string * string list) array;
  count_source : count_source; origin : origin option;
  sites : (int * W.path * int list) list }
let rec operands = function
  | Binary (_,a,b) | Int_binary (_,a,b) | Int_compare (_,a,b) -> [a;b]
  | Unary (_,a) | Int_abs a | Convert (_,a) -> [a]
  | Noise3 (a,b,c,_,_) | Select (a,b,c) | Int_select (a,b,c) -> [a;b;c]
  | Guarded (guards,body) -> List.map fst guards @ operands body
  | _ -> []

let dependent_of code =
  let dependent = Array.make (Array.length code) false in
  let rec accumulator = function Accumulator _ | Int_accumulator -> true
    | Guarded (_,body) -> accumulator body | _ -> false in
  Array.iteri (fun id instruction -> dependent.(id) <- accumulator instruction
    || List.exists (fun r -> dependent.(r)) (operands instruction)) code;
  dependent

let rec typed_instruction = function
  | Int_const _ -> false (* compile-time configuration literals may be unused *)
  | Int_input _ | Int_uniform _ | Int_frame _ | Int_accumulator | Int_binary _ | Int_compare _
  | Int_abs _ | Convert _ | Int_select _ | Raise _ -> true
  | Guarded (_,body) -> typed_instruction body
  | _ -> false
let integer_program t = Array.exists typed_instruction t.code
  || Array.exists (Array.exists (fun r->Core.Region.integer_register t.code.(r))) t.outputs
  || Array.exists (fun (_,term)->term.W.ty=Ty.Array Ty.Int) t.sources

let binary_apply op x y = match op with
  | Add->x+.y | Sub->x-.y | Mul->x*.y | Div->if y=0. then 0. else x/.y
  | Mod->if y=0. then 0. else Float.rem (Float.rem x y+.y) y
  | Pow->Float.pow (Float.abs x) y | Min->Float.min x y | Max->Float.max x y
  | Lt->if x<y then 1. else 0. | Le->if x<=y then 1. else 0.
  | Gt->if x>y then 1. else 0. | Ge->if x>=y then 1. else 0.
  | Eq->if x=y then 1. else 0. | And->if x<>0. && y<>0. then 1. else 0.
  | Or->if x<>0. || y<>0. then 1. else 0.
  | Atan2->Float.atan2 x y | Hypot->Float.hypot x y
let unary_apply op x = match op with
  | Sin->sin x | Cos->cos x | Sqrt->sqrt (Float.abs x) | Abs->Float.abs x
  | Not->if x=0. then 1. else 0. | Tan->tan x | Asin->asin x | Acos->acos x
  | Exp->exp x | Log->log x | Sign->if x>0. then 1. else if x<0. then -1. else x
let convert_int op x = match op with
  | Truncate->V.to_int "int" (Float.trunc x) | Floor->V.to_int "floor" (Float.floor x)
  | Ceil->V.to_int "ceil" (Float.ceil x) | Round->V.to_int "round" (Float.round x)
  | Coerce_int->V.to_int "int" (Float.floor (x+.0.5))
  | Integer_result name->V.to_int name (Float.floor (x+.0.5)) | To_float->assert false

let of_region (r : Core.Region.t) =
  let invalid message = Result.Error [Flow.Diagnostic.error ~span:r.term.form.span ~code:"E_PACKED_LAYOUT" message] in
  let ok slot id = id >= 0 && id < slot in
  let operands_ok = ref true in
  let rec valid slot instruction =
    if not (List.for_all (ok slot) (operands instruction)) then operands_ok:=false;
    match instruction with
    | Input (input,width,component) ->
        if input<0 || input>=Array.length r.widths || width<>r.widths.(input)
          || component<0 || component>=width then operands_ok:=false
    | Int_input input ->
        if input<0 || input>=Array.length r.sources || input>=Array.length r.widths
          || r.widths.(input)<>1 || (snd r.sources.(input)).W.ty<>Ty.Array Ty.Int then operands_ok:=false
    | Uniform (input,component) ->
        if input<0 || input>=Array.length r.uniforms || component<0 || component>=4 then operands_ok:=false
    | Int_uniform input ->
        if input<0 || input>=Array.length r.uniforms then operands_ok:=false
        else let ty=match r.uniforms.(input) with E.Residual residual ->
            (E.Private.residual_view residual).term.ty | value -> V.ty_of value in
          if ty<>Ty.Int then operands_ok:=false
    | Accumulator component -> if component<0 || component>=4 then operands_ok:=false
    | Guarded (_,body) -> valid slot body
    | _ -> () in
  Array.iteri valid r.code;
  if Array.length r.widths<>Array.length r.sources
    || not (Array.for_all (fun width->width>=1 && width<=4) r.widths) then
    invalid "Region inputs need matching sources and widths from 1 to 4."
  else if not !operands_ok then invalid "Region instruction reads an invalid input or a register defined later."
  else if Array.length r.code > Flow.Packed_ops.register_limit then
    invalid (Printf.sprintf "Region exceeds %d registers." Flow.Packed_ops.register_limit)
  else if r.outputs = [||] || (Array.length r.outputs > 1 && r.result <> Collect) then
    invalid "A region has one output, or several only when it collects."
  else if not (Array.for_all (fun output -> Array.length output>=1 && Array.length output<=4
      && Array.for_all (ok (Array.length r.code)) output) r.outputs) then invalid "Region output needs 1 to 4 existing registers."
  else Ok {residual = r.residual; term = r.term; sources = r.sources; widths = r.widths;
    uniforms = r.uniforms; code = r.code; dependent = dependent_of r.code; outputs = r.outputs;
    count = r.count; iteration = r.iteration; result = r.result; skip = r.skip; stages = r.stages;
    fusion = r.fusion; dynamic = r.dynamic; body = r.body; binding_fn = r.binding_fn;
    uniform_names = r.uniform_names; count_source = r.count_source; origin = r.origin; sites = r.sites}

let to_region t : Core.Region.t =
  {residual = t.residual; term = t.term; sources = t.sources; widths = t.widths;
   uniforms = t.uniforms; uniform_names = t.uniform_names; code = t.code; outputs = t.outputs;
   count = t.count; origin = t.origin; iteration = t.iteration; result = t.result; skip = t.skip;
   stages = t.stages; fusion = t.fusion; dynamic = t.dynamic; count_source = t.count_source;
   body = t.body; binding_fn = t.binding_fn; sites = t.sites}

exception Unsupported = Core_region.Unsupported
let width_of = Core_region.width_of
let components = Core_region.components

let zipped t = t.iteration = Zip || Array.length t.sources = 1

let output_reachable t =
  let used = Array.make (Array.length t.code) false in
  let rec use slot = if not used.(slot) then begin
    used.(slot) <- true;
    List.iter use (operands t.code.(slot))
  end in
  Array.iter (Array.iter use) t.outputs;
  used

let rec unguarded = function Guarded (_,body) -> unguarded body | instruction -> instruction

let finite_checks t =
  (* GPU qualification rejects nonfinite constants. These operations cannot
     introduce a nonfinite result; their operands are checked at their source. *)
  Array.map (fun instruction -> match unguarded instruction with
    | Const _ | Select _ | Unary ((Abs | Sqrt | Not), _)
    | Binary ((Min | Max | Lt | Le | Gt | Ge | Eq | And | Or), _, _) -> false
    | _ -> true) t.code

let gpu_refusals t =
  let reasons = ref [] in
  let refuse message = reasons := Flow.Diagnostic.error ~code:"E_GPU_FORM" message :: !reasons in
  if integer_program t then refuse "Integer sources, uniforms and instructions stay on the CPU.";
  if Array.exists (fun instruction -> match unguarded instruction with Binary (Hypot,_,_) -> true | _ -> false) t.code then
    refuse "Hypot requires the CPU binary64 implementation.";
  if t.result <> Collect || not (zipped t) || t.skip <> [||] then
    refuse "GPU kernels require Collect with Zip iteration and no skipped elements.";
  if Array.exists (fun instruction -> match unguarded instruction with Accumulator _ | Int_accumulator -> true | _ -> false) t.code then
    refuse "Ordered accumulators stay on the CPU.";
  let used = output_reachable t in
  let bad_noise = ref false and bad_constant = ref false in
  Array.iteri (fun i instruction -> if used.(i) then match unguarded instruction with
    | Noise3 (_, _, _, _, octaves) ->
        if not (Flow.Packed_ops.supported_noise_octaves octaves) then bad_noise := true
    | Const value -> if not (Flow.Packed_ops.finite_float32 value) then bad_constant := true
    | _ -> ()) t.code;
  if !bad_noise then refuse "GPU noise supports 1 to 32 octaves.";
  if !bad_constant then
    refuse "Nonfinite float32 shader constants require reference evaluation.";
  List.rev !reasons

let compile_impl ?(fusion = true) ?(dynamic = false) ?(count_source = fun _ _ -> None) residual term =
  Result.bind (Core_region.lower ~fusion ~dynamic ~count_source residual term) (fun region ->
    of_region (if fusion then Core_fuse.fuse region else region))

let static_count t = t.count
let count_origin t = t.origin
let trace : ((t, Flow.Diagnostic.t list) Stdlib.result -> unit) ref = ref ignore
let traced result = !trace result; result
let compile_result ?fusion ?count_source r term = traced (compile_impl ?fusion ?count_source r term)
let compile ?fusion ?count_source r term = compile_result ?fusion ?count_source r term |> Result.to_option
let compile_template ?count_source r term =
  traced (compile_impl ~dynamic:true ?count_source r term) |> Result.to_option
let rebind t residual =
  Option.bind (Core_region.rebind (to_region t) residual) (fun region -> Result.to_option (of_region region))
let elementwise t = match t.result with Collect -> true | Sum _ | Accumulate _ -> false
let provenance t = List.sort_uniq compare t.sites
let stage_count t = List.length t.stages
let site t = let view = E.Private.residual_view t.residual in
  view.instance, Option.value ~default:view.site t.term.path, view.iter
let reference ?state ?elems ?resolve t ~live = E.Private.eval_term ?state ?elems ?resolve t.residual t.term ~live
exception Failed of Flow.Diagnostic.t
exception Nonfinite
let get = function Ok x -> x | Error d -> raise (Failed d)

let run_typed ?plane_outputs ?expected_count ~evaluate ~uniform ~seed t ~live =
  let inputs=Array.map (fun (r,term)->evaluate r term) t.sources in
  let lengths=Array.map V.array_length inputs in
  let count=if inputs=[||] then 0 else if t.iteration=Product && Array.exists ((=)0) lengths then 0 else
    Array.fold_left (fun n length->match t.iteration with Zip->min n length | Product->
      if length<>0 && n>max_int/length then V.fail "E_ARRAY_RANGE" "Kernel iteration count exceeds native bounds.";
      n*length) (if t.iteration=Zip then max_int else 1) lengths in
  let strides=Array.make (Array.length inputs) 1 in
  for i=Array.length inputs-2 downto 0 do strides.(i)<-strides.(i+1)*lengths.(i+1) done;
  let skip=Array.make count false in
  Array.iter(fun i->if i>=0 && i<count then skip.(i)<-true)t.skip;
  let kept=count-Array.fold_left(fun n b->if b then n+1 else n)0 skip in
  Option.iter(fun n->if n<>kept then V.fail "E_ARRAY_COUNT" "Column sink count differs from the kernel count.")expected_count;
  let collecting=match t.result with Collect|Accumulate(_,true)->true|_->false in
  let integer_outputs=Array.map(fun regs->Array.length regs=1 && Core.Region.integer_register t.code.(regs.(0)))t.outputs in
  Option.iter(fun outputs->
    if t.result<>Collect || Array.length outputs<>Array.length t.outputs then V.fail "E_ARRAY_TYPE" "Column sinks require matching Collect outputs.";
    Array.iteri(fun k lanes->
      if integer_outputs.(k) || Array.length lanes<>Array.length t.outputs.(k) then V.fail "E_ARRAY_TYPE" "Float column sinks cannot store integer outputs.";
      Array.iter(Option.iter(fun a->if Array.length a<>kept then V.fail "E_ARRAY_COUNT" "Column sink count differs from the kernel count."))lanes)outputs)plane_outputs;
  let outputs=Array.mapi(fun k registers->if not collecting || plane_outputs<>None then E.No_geo
    else V.array_init (if integer_outputs.(k) then Ty.Int else match Array.length registers with 2->Ty.Vec2|3->Ty.Vec3|4->Ty.Vec4|_->Ty.Float) kept (fun _->E.Int 0))t.outputs in
  let integer=Array.make (Array.length t.code) 0 and floats=Array.make (Array.length t.code) 0. in
  let banks=Array.map Core.Region.integer_register t.code in
  let numeric r=if banks.(r) then float integer.(r) else floats.(r) in
  let finite x=V.fin "packed" x in
  let uniforms=Array.map(fun value->lazy(uniform value))t.uniforms in
  let accumulator=ref (Option.value ~default:(if integer_outputs.(0) then E.Int 0 else E.Float 0.) seed) in
  let initialized=ref(match t.result with Sum zero->zero|_->true) and output_index=ref 0 in
  let tables=Hashtbl.create 8 in
  let noise seed=match Hashtbl.find_opt tables seed with Some n->n|None->let n=Rays_math.Noise.create seed in Hashtbl.add tables seed n;n in
  let scratch=Rays_math.Noise.Private.create_fbm3_scratch () in
  for index=0 to count-1 do if not skip.(index) then begin
    let source i=if t.iteration=Zip then index else index/strides.(i) mod lengths.(i) in
    let rec execute slot = function
      | Guarded(guards,body)->if List.for_all(fun(r,yes)->(numeric r<>0.)=yes)guards then execute slot body
      | Raise(_,code,message)->V.fail code message
      | Int_const n->integer.(slot)<-n | Const x->floats.(slot)<-finite x
      | Int_input i->(match V.array_get inputs.(i)(source i)with E.Int n->integer.(slot)<-n|_->V.fail "E_ARRAY_TYPE" "Kernel input changed its packed element type.")
      | Input(i,_,component)->floats.(slot)<-finite (components(V.array_get inputs.(i)(source i))).(component)
      | Int_uniform i->(match Lazy.force uniforms.(i)with E.Int n->integer.(slot)<-n|_->V.fail "E_ARRAY_TYPE" "Kernel uniform changed its integer type.")
      | Int_frame name->(match Flow.Op.find name Flow.Context.value with
          |Some op->(match op.body ~live ~node:(fun _ _->raise Unsupported)[]with E.Int n->integer.(slot)<-n|_->raise Unsupported)
          |None->raise Unsupported)
      | Uniform(i,c)->floats.(slot)<-finite(components(Lazy.force uniforms.(i))).(c)
      | Frame name->floats.(slot)<-finite(if name="t" then live.Frame_input.t else match Flow.Op.find name Flow.Context.value with Some op->V.num(op.body ~live ~node:(fun _ _->raise Unsupported)[])|None->raise Unsupported)
      | Int_accumulator->(match !accumulator with E.Int n->integer.(slot)<-n|_->assert false)
      | Accumulator c->floats.(slot)<-finite(components !accumulator).(c)
      | Int_binary(op,a,b)->integer.(slot)<-Flow.Packed_ops.integer_apply op integer.(a) integer.(b)
      | Int_compare(op,a,b)->floats.(slot)<-(if Flow.Packed_ops.comparison_apply op integer.(a) integer.(b)then 1. else 0.)
      | Int_abs a->integer.(slot)<-abs integer.(a)
      | Convert(To_float,a)->floats.(slot)<-finite(numeric a)
      | Convert(op,a)->integer.(slot)<-convert_int op (numeric a)
      | Int_select(c,a,b)->integer.(slot)<-integer.(if numeric c<>0. then a else b)
      | Select(c,a,b)->floats.(slot)<-finite(numeric(if numeric c<>0. then a else b))
      | Binary(op,a,b)->floats.(slot)<-finite(binary_apply op (numeric a)(numeric b))
      | Unary(op,a)->floats.(slot)<-finite(unary_apply op (numeric a))
      | Noise3(x,y,z,seed,octaves)->floats.(slot)<-finite(Rays_math.Noise.Private.fbm3_with_scratch scratch (noise seed) ~octaves ~lacunarity:2. ~gain:0.5 ~x:(numeric x)~y:(numeric y)~z:(numeric z)) in
    Array.iteri execute t.code;
    Array.iteri(fun k registers->
      let value=if integer_outputs.(k) then E.Int integer.(registers.(0)) else
        let xs=Array.map(fun r->finite(numeric r))registers in match xs with
        |[|x;y|]->E.Vec2(x,y)|[|x;y;z|]->E.Vec3(x,y,z)|[|x;y;z;w|]->E.Vec4(x,y,z,w)|_->E.Float xs.(0) in
      (match t.result with Collect->()|Accumulate _->accumulator:=value|Sum _->
        accumulator:=(if not !initialized then value else match !accumulator,value with
          |E.Int a,E.Int b when t.result=Sum true ->E.Int(Flow.Packed_ops.integer_apply Iadd a b)
          |a,b->V.arith "array/sum" (+.) a b));
      if collecting then match plane_outputs with
        |Some outputs->Array.iteri(fun c r->Option.iter(fun data->data.(!output_index)<-finite(numeric r))outputs.(k).(c))registers
        |None->(match outputs.(k)with E.Int_array data->V.int_array_put data !output_index value
          |E.Float_array data->V.array_put data 1 !output_index value
          |E.Vec2_array data->V.array_put data 2 !output_index value
          |E.Vec3_array data->V.array_put data 3 !output_index value
          |E.Vec4_array data->V.array_put data 4 !output_index value|_->assert false))t.outputs;
    initialized:=true;incr output_index
  end done;
  if plane_outputs<>None then [] else if collecting then Array.to_list outputs else
    [if kept=0 then match t.result,seed with Accumulate _,Some seed->seed|Sum false,_->E.Int 0|_-> !accumulator else !accumulator]

let ordered_add t =
  let output = t.outputs.(0) in
  let width = Array.length output in
  match t.result with
  | Accumulate (_, false) when width >= 1 && width <= 4 && t.iteration = Zip
      && Array.length t.sources = 1 && t.widths = [|width|] && Array.length t.skip = 0
      && Array.length t.code = 3 * width && Array.length t.dependent = 3 * width ->
      let matched = ref true in
      for k = 0 to width - 1 do
        if t.code.(k) <> Input (0, width, k) || t.dependent.(k)
          || t.code.(width+k) <> Accumulator k || not t.dependent.(width+k)
          || t.code.(2*width+k) <> Binary (Add, width+k, k) || not t.dependent.(2*width+k)
          || output.(k) <> 2*width+k then matched := false
      done;
      !matched
  | _ -> false

let rec run_all ?column_source ?plane_outputs ?expected_count ?state ?elems ?resolve ?measure ?(strict = false) t ~live =
  let state = Option.value ~default:(E.create_state ()) state in
  let work () =
    let rec evaluate residual (term : W.term) =
      let nested = match term.node with
        | W.Ref_binding (name, []) ->
            (match List.assoc_opt name (E.Private.residual_view residual).bindings with
             | Some (E.Residual r) -> let view = E.Private.residual_view r in Some (r, view.term)
             | _ -> None)
        | _ -> None in
      match nested with
      | Some (residual, term) -> evaluate residual term
      | None -> (match compile_impl ~fusion:t.fusion ~dynamic:t.dynamic ~count_source:t.count_source residual term with
          | Ok program -> force ~strict ~state ?elems ?resolve ?measure program ~live
          | Error _ ->
              (match strict, term.node with
               | true, (W.Hof ((`Map | `Reduce), _) | Loop _ | Op {op = "array/sum"; _}) ->
                   Error (Flow.Diagnostic.error ~code:"E_KERNEL_FORM"
                     "Numeric node bodies must compile to packed kernels.")
               | false, (W.Hof ((`Map | `Reduce), _) | Loop _ | Op {op = "array/sum"; _}) ->
                   E.Private.eval_term ~state ?elems ?resolve residual term ~live
               | _ -> uniform (E.Residual (E.Private.with_bindings residual ~term []))))
    and uniform value = E.Private.force_with_executor ~state ?elems ?resolve
      ~compiled:false ~strict ~execute:(fun residual _live ->
        Some (evaluate residual (E.Private.residual_view residual).term)) value ~live in
    let seed = match t.result with
      | Accumulate (seed, _) -> Some (get (evaluate t.residual seed))
      | _ -> None in
    (* ponytail: guarded live captures keep the sequential VM; parallel lazy
       captures need a separate preparation pass before workers use Eval state. *)
    let guarded_capture = Array.exists (function
      | Guarded (_, body) -> (match unguarded body with
          | Uniform (index, _) -> (match t.uniforms.(index) with
              | E.Float _ | Bool _ | Vec2 _ | Vec3 _ | Vec4 _ -> false
              | _ -> true)
          | _ -> false)
      | _ -> false) t.code in
    if integer_program t || guarded_capture then
      run_typed ?plane_outputs ?expected_count ~seed ~live t
        ~evaluate:(fun r term->get(evaluate r term))
        ~uniform:(fun value -> get (uniform value))
    else
    let borrowed=Array.map (fun (residual,term)->match column_source with
      |None->None|Some source->get (source residual term)) t.sources in
    let inputs = Array.mapi (fun i (residual, term) ->
      if borrowed.(i)<>None then [||] else
      let value = get (evaluate residual term) in
      match value, t.widths.(i) with
      | E.Float_array xs, 1 | Vec2_array xs, 2 | Vec3_array xs, 3 | Vec4_array xs, 4 -> xs
      | _ -> V.fail "E_ARRAY_TYPE" "Kernel input changed its packed element type.") t.sources in
    let columns=Array.mapi (fun i array->match borrowed.(i) with
      |None->Array.init t.widths.(i) (fun component->{data=array;offset=component;stride=t.widths.(i)})
      |Some columns->
          if Array.length columns<>t.widths.(i) then V.fail "E_ARRAY_TYPE" "Borrowed columns changed the packed element width.";
          columns) inputs in
    let lengths=Array.mapi (fun i columns->match borrowed.(i) with
      |None->Array.length inputs.(i)/t.widths.(i)
      |Some _->
          let length c=if c.stride<=0 || c.offset<0 || c.offset>Array.length c.data then
              V.fail "E_ARRAY_RANGE" "Borrowed column offset and stride must describe an in-bounds span."
            else if c.offset=Array.length c.data then 0 else
              1+(Array.length c.data-1-c.offset)/c.stride in
          let count=length columns.(0) in
          if not (Array.for_all (fun c->length c=count) columns) then
            V.fail "E_ARRAY_COUNT" "Borrowed components need the same element count.";
          count) columns in
    let count = if t.iteration = Product && Array.exists ((=) 0) lengths then 0 else
      Array.fold_left (fun a b -> match t.iteration with
      | Zip -> min a b | Product ->
          if b <> 0 && a > max_int / b then V.fail "E_ARRAY_RANGE" "Kernel iteration count exceeds native bounds.";
          a * b) (if t.iteration = Zip then max_int else 1) lengths in
    let count = if inputs = [||] then 0 else count in
    let strides = Array.make (Array.length inputs) 1 in
    if t.iteration = Product && count > 0 then
      for i = Array.length inputs - 2 downto 0 do strides.(i) <- strides.(i + 1) * lengths.(i + 1) done;
    let uniforms = Array.map (fun value -> components (get (uniform value))) t.uniforms in
    let frame = Array.map (fun instruction -> match unguarded instruction with
      | Frame "t" -> live.Frame_input.t
      | Frame name ->
          (match Flow.Op.find name Flow.Context.value with
           | Some op -> V.num (op.body ~live ~node:(fun _ _ -> raise Unsupported) [])
           | None -> raise Unsupported)
      | _ -> 0.) t.code in
    let started = Option.map (fun (clock, _) -> clock ()) measure in
    let widths = Array.map Array.length t.outputs in
    let width = widths.(0) in
    List.iter (fun (_, (term : W.term)) -> match term.ty with
      | Ty.Array ty ->
          let width = width_of ty in
          if count > Sys.max_floatarray_length / width then
            V.fail "E_ARRAY_RANGE" "Kernel intermediate exceeds native storage bounds."
      | _ -> ()) t.stages;
    let skip = Array.to_list t.skip |> List.filter (fun i -> i >= 0 && i < count) |> Array.of_list in
    let skipped_before n =
      let lo = ref 0 and hi = ref (Array.length skip) in
      while !lo < !hi do
        let mid = (!lo + !hi) / 2 in
        if skip.(mid) < n then lo := mid + 1 else hi := mid
      done; !lo in
    let kept = count - Array.length skip in
    Option.iter (fun expected->if kept<>expected then
      V.fail "E_ARRAY_COUNT" "Column sink count differs from the kernel count.") expected_count;
    let collecting = match t.result with Collect | Accumulate (_, true) -> true | _ -> false in
    if collecting && Array.exists (fun width -> kept > Sys.max_floatarray_length / width) widths then
      V.fail "E_ARRAY_RANGE" "Kernel output exceeds native storage bounds.";
    Option.iter (fun planes->
      if not collecting || t.result<>Collect || Array.length planes<>Array.length widths then
        V.fail "E_ARRAY_TYPE" "Column sinks require matching Collect outputs.";
      Array.iteri (fun k components->
        if Array.length components<>widths.(k) then V.fail "E_ARRAY_TYPE" "Column sink width differs from the output.";
        Array.iter (Option.iter (fun data->if Array.length data<>kept then
          V.fail "E_ARRAY_COUNT" "Column sink count differs from the kernel count.")) components) planes) plane_outputs;
    let outputs = Array.map (fun width -> Array.make (if collecting && plane_outputs=None then kept * width else 0) 0.) widths in
    let[@inline always] store k component index value=match plane_outputs with
      |Some planes->(match planes.(k).(component) with Some data->Array.unsafe_set data index value|None->())
      |None->Array.unsafe_set outputs.(k) (index*widths.(k)+component) value in
    let[@inline always] load input component index=let column=columns.(input).(component) in
      Array.unsafe_get column.data (column.offset+index*column.stride) in
    let accumulator = match seed with
      | Some (E.Vec2 _ | Vec3 _ | Vec4 _ as value) -> components value
      | Some v -> Array.make width (V.num v) | None -> Array.make width 0. in
    let initialized = ref (match t.result with Sum zero -> zero | _ -> true) in
    let ordered_add = ordered_add t in
    let uses=Array.make (Array.length t.code) 0 in
    let use id=uses.(id)<-uses.(id)+1 in
    Array.iter (fun instruction -> List.iter use (operands instruction)) t.code;
    Array.iter (Array.iter use) t.outputs;
    let omitted=Array.make (Array.length t.code) false in
    let rec guards = function Guarded (conditions, body) -> conditions @ guards body | _ -> [] in
    let guards = Array.map guards t.code in
    (* Scaling and sampling must have the same scope: moving an unconditional
       multiplication into an inactive noise branch would hide its overflow. *)
    let scale conditions register=match unguarded t.code.(register) with
      |Binary (Mul,a,b) when uses.(register)=1 && guards.(register)=conditions ->
          let constant id=match unguarded t.code.(id) with Const _|Uniform _|Frame _->true|_->false in
          if constant b then Some (a,b) else if constant a then Some (b,a) else None
      |_->None in
    let noise_scale=Array.mapi (fun slot instruction -> match unguarded instruction with
      |Noise3 (x,y,z,_,_)->(match scale guards.(slot) x,scale guards.(slot) y,scale guards.(slot) z with
        |Some (a,f),Some (b,g),Some (c,h) when f=g && g=h ->
            omitted.(x)<-true;omitted.(y)<-true;omitted.(z)<-true;
            Some (a,b,c,f)
        |_->None)
      |_->None) t.code in
    let collect_product=Array.map (Array.map (fun register->
      if t.result<>Collect || uses.(register)<>1 then None else
      match t.code.(register) with
      |Binary (Add,a,b)->
          let product base id=match t.code.(id) with
            |Binary (Mul,x,y) when uses.(id)=1->
                omitted.(id)<-true;omitted.(register)<-true;Some (base,x,y)
            |_->None in
          (match product a b with Some _ as p->p|None->product b a)
      |_->None)) t.outputs in
    (* A streaming SSA path for noise followed by scalar scaling and terminal
       vector products/additions. It depends only on register instructions;
       other expression graphs keep the block executor below. *)
    let exception Not_streaming in
    let streaming=try
      if t.result<>Collect || t.iteration<>Zip || skip<>[||] then raise Not_streaming;
      let allowed=Array.map (function Input _|Const _|Uniform _|Frame _->true|_->false) t.code in
      let input id=match t.code.(id) with Input (source,width,component)->source,width,component
        |_->raise Not_streaming in
      let scalar id=match t.code.(id) with Const _|Uniform _|Frame _->id|_->raise Not_streaming in
      let shared=ref None in
      let products=Array.mapi (fun k output->Array.mapi (fun component register->
        let base,a,b=match collect_product.(k).(component) with Some p->p|None->raise Not_streaming in
        let direction,scale=match t.code.(a),t.code.(b) with
          |Input _,_->input a,b|_,Input _->input b,a|_->raise Not_streaming in
        (match !shared with None->shared:=Some scale|Some old when old=scale->()|_->raise Not_streaming);
        allowed.(register)<-true;
        (match t.code.(register) with Binary (Add,x,y)->allowed.(if x=base then y else x)<-true|_->raise Not_streaming);
        input base,direction) output) t.outputs in
      let scale=match !shared with Some scale->scale|None->raise Not_streaming in
      let noise,amplitude=match t.code.(scale) with
        |Binary (Mul,a,b)->(match t.code.(a),t.code.(b) with
          |Noise3 _,_->a,scalar b|_,Noise3 _->b,scalar a|_->raise Not_streaming)
        |_->raise Not_streaming in
      allowed.(scale)<-true;allowed.(noise)<-true;
      let x,y,z,frequency=match t.code.(noise) with
        |Noise3 (x,y,z,_,1)->(match noise_scale.(noise) with
          |Some (a,b,c,f)->allowed.(x)<-true;allowed.(y)<-true;allowed.(z)<-true;
              input a,input b,input c,Some (scalar f)
          |None->input x,input y,input z,None)
        |_->raise Not_streaming in
      if not (Array.for_all Fun.id allowed) then raise Not_streaming;
      Some (noise,amplitude,x,y,z,frequency,products)
    with Not_streaming->None in
    let scalar_streaming=try
      if t.result<>Collect || t.iteration<>Zip || skip<>[||] || Option.is_some streaming then raise Not_streaming;
      let allowed=Array.map (function Input _|Const _|Uniform _|Frame _->true|_->false) t.code in
      let input id=match t.code.(id) with Input (i,w,c)->i,w,c|_->raise Not_streaming in
      let scalar id=match t.code.(id) with Const _|Uniform _|Frame _->id|_->raise Not_streaming in
      let scaled id=match t.code.(id) with
        |Binary (Mul,a,b)->(match t.code.(a),t.code.(b) with
          |Input _,_->allowed.(id)<-true;input a,Some (scalar b)
          |_,Input _->allowed.(id)<-true;input b,Some (scalar a)
          |_->raise Not_streaming)
        |Input _->input id,None
        |_->raise Not_streaming in
      let shared=ref None in
      let outputs=Array.map (Array.map (fun id->match t.code.(id) with
        |Input _->input id,None
        |Binary (Add,a,b)->
          let base,expression=match t.code.(a),t.code.(b) with
            |Input _,_->input a,b|_,Input _->input b,a|_->raise Not_streaming in
          (match !shared with None->shared:=Some expression|Some old when old=expression->()|_->raise Not_streaming);
          allowed.(id)<-true;base,Some expression
        |_->raise Not_streaming)) t.outputs in
      let root=match !shared with Some id->id|None->raise Not_streaming in
      let transform,a=match t.code.(root) with
        |Binary (Mul,a,b)->(match t.code.(a),t.code.(b) with
          |Binary (Sub,_,_),_->a,scalar b|_,Binary (Sub,_,_)->b,scalar a|_->raise Not_streaming)
        |_->raise Not_streaming in
      let gain,bias=match t.code.(transform) with Binary (Sub,a,b)->a,scalar b|_->raise Not_streaming in
      let noise,g=match t.code.(gain) with
        |Binary (Mul,a,b)->(match t.code.(a),t.code.(b) with
          |Noise3 _,_->a,scalar b|_,Noise3 _->b,scalar a|_->raise Not_streaming)
        |_->raise Not_streaming in
      allowed.(root)<-true;allowed.(transform)<-true;allowed.(gain)<-true;allowed.(noise)<-true;
      let x,y,z,f=match t.code.(noise) with
        |Noise3 (x,y,z,_,1)->
          let x,f=scaled x and y,h=scaled y in
          if f<>h then raise Not_streaming;
          let z=match t.code.(z) with Const z when z=0.->None
            |_->let z,h=scaled z in if h<>f then raise Not_streaming;Some z in
          x,y,z,f
        |_->raise Not_streaming in
      if not (Array.for_all Fun.id allowed) then raise Not_streaming;
      Some (noise,x,y,z,f,g,bias,a,outputs)
    with Not_streaming->None in
    let block_size = 1024 in
    let blocks = if count = 0 then 0 else (count - 1) / block_size + 1 in
    let blocks_per_chunk = 16 in
    let chunks = if blocks = 0 then 0 else (blocks - 1) / blocks_per_chunk + 1 in
    let chunk chunk =
      if ordered_add then begin
        let source = inputs.(0) in
        let first = chunk * blocks_per_chunk * block_size
        and last = min count ((chunk + 1) * blocks_per_chunk * block_size) - 1 in
        if width = 3 then begin
          let x = ref accumulator.(0) and y = ref accumulator.(1)
          and z = ref accumulator.(2) in
          for i = first to last do
            let offset = i * 3 in
            let next = !x +. source.(offset) in
            if not (Float.is_finite next) then raise Nonfinite;
            x := next;
            let next = !y +. source.(offset + 1) in
            if not (Float.is_finite next) then raise Nonfinite;
            y := next;
            let next = !z +. source.(offset + 2) in
            if not (Float.is_finite next) then raise Nonfinite;
            z := next
          done;
          accumulator.(0) <- !x;
          accumulator.(1) <- !y;
          accumulator.(2) <- !z
        end else
        for i = first to last do
          for component = 0 to width - 1 do
            let x = accumulator.(component) +. source.(i * width + component) in
            if not (Float.is_finite x) then raise Nonfinite;
            accumulator.(component) <- x
          done
        done
      end else begin
      let scratch = Array.make ((if Option.is_some streaming then (if plane_outputs=None then 1 else 2)
        else if Option.is_some scalar_streaming then 2 else Array.length t.code) * block_size) 0. in
      let noise_scratch=Rays_math.Noise.Private.create_fbm3_scratch () in
      let tables=Array.map(fun instruction -> match unguarded instruction with Noise3(_,_,_,seed,_)->Some(Operators.noise_table seed)
        |_->None)t.code in
      let contiguous = t.iteration=Zip && skip=[||] in
      let indices = if contiguous then [||] else Array.make block_size 0 in
      for block = chunk * blocks_per_chunk to min blocks ((chunk + 1) * blocks_per_chunk) - 1 do
      let start = block * block_size and limit = min count ((block + 1) * block_size) in
      let length,output_start = if contiguous then limit-start,start else
        let skipped = ref (skipped_before start) and length = ref 0 in
        for i = start to limit - 1 do
          if !skipped < Array.length skip && skip.(!skipped) = i then incr skipped
          else begin indices.(!length) <- i; incr length end
        done;
        !length,start-skipped_before start in
      let rec execute_instruction slot instruction first last =
        let at = slot * block_size in
        match instruction with
        | Guarded (conditions, body) ->
            let rec selected j = function
              | [] -> true
              | (register, yes) :: rest ->
                  (scratch.(register * block_size + j) <> 0.) = yes && selected j rest in
            let next = ref first in
            while !next < last do
              while !next < last && not (selected !next conditions) do incr next done;
              let first = !next in
              while !next < last && selected !next conditions do incr next done;
              if first < !next then execute_instruction slot body first !next
            done
        | Int_const n -> Array.fill scratch (at + first) (last - first) (float n)
        | Const x -> Array.fill scratch (at + first) (last - first) x
        | Input (input, width, component) ->
            let source = inputs.(input) in
            if borrowed.(input)<>None then
              for j=first to last-1 do
                let i=if contiguous then start+j else if t.iteration=Zip then indices.(j)
                  else indices.(j)/strides.(input) mod lengths.(input) in
                Array.unsafe_set scratch (at+j) (load input component i)
              done
            else if t.iteration=Zip && skip=[||] then
              for j=first to last-1 do
                (* Layouts were checked by [of_region], and Zip's count is the
                   shortest complete input. These spans are within both arrays. *)
                Array.unsafe_set scratch (at+j)
                  (Array.unsafe_get source ((start+j)*width+component))
              done
            else
            for j = first to last - 1 do
              let i = if t.iteration = Zip then indices.(j)
                else indices.(j) / strides.(input) mod lengths.(input) in
              scratch.(at + j) <- source.(i * width + component)
            done
        | Uniform (uniform, component) -> Array.fill scratch (at + first) (last - first) uniforms.(uniform).(component)
        | Frame _ -> Array.fill scratch (at + first) (last - first) frame.(slot)
        | Accumulator component ->
            for j = first to last - 1 do scratch.(at + j) <- accumulator.(component) done
        | Select (condition, yes, no) ->
            let condition = condition * block_size and yes = yes * block_size and no = no * block_size in
            for j = first to last - 1 do
              scratch.(at+j) <- scratch.((if scratch.(condition+j) <> 0. then yes else no) + j)
            done
        | Noise3 (x, y, z, _, octaves) ->
            let noise=Option.get tables.(slot)in
            let x,y,z,frequency=match noise_scale.(slot) with
              |Some (x,y,z,f)->x,y,z,scratch.(f*block_size+first)
              |None->x,y,z,1. in
            if octaves=1 then Rays_math.Noise.Private.sample3_into noise ~first ~last
              ~frequency
              ~x:scratch ~x_offset:(x * block_size) ~y:scratch ~y_offset:(y * block_size)
              ~z:scratch ~z_offset:(z * block_size) ~output:scratch ~output_offset:at ()
            else for j=first to last-1 do
              scratch.(at+j)<-Rays_math.Noise.Private.fbm3_with_scratch noise_scratch noise
                ~octaves ~lacunarity:2. ~gain:0.5
                ~x:(scratch.(x*block_size+j)*.frequency) ~y:(scratch.(y*block_size+j)*.frequency)
                ~z:(scratch.(z*block_size+j)*.frequency)
            done;
            if noise_scale.(slot)<>None then
              for j=first to last-1 do
                if not (Float.is_finite scratch.(at+j)) then raise Nonfinite
              done
        | Binary (operation, a, b) ->
            let a = a * block_size and b = b * block_size in
            (match operation with
             | Add -> for j = first to last - 1 do let x = Array.unsafe_get scratch (a+j) +. Array.unsafe_get scratch (b+j) in if not (Float.is_finite x) then raise Nonfinite; Array.unsafe_set scratch (at+j) x done
             | Sub -> for j = first to last - 1 do let x = scratch.(a+j) -. scratch.(b+j) in if not (Float.is_finite x) then raise Nonfinite; scratch.(at+j) <- x done
             | Mul -> for j = first to last - 1 do let x = Array.unsafe_get scratch (a+j) *. Array.unsafe_get scratch (b+j) in if not (Float.is_finite x) then raise Nonfinite; Array.unsafe_set scratch (at+j) x done
             | Div -> for j = first to last - 1 do let y = scratch.(b+j) in
                 let x = if y = 0. then 0. else scratch.(a+j) /. y in if not (Float.is_finite x) then raise Nonfinite; scratch.(at+j) <- x done
             | Mod -> for j = first to last - 1 do let y = scratch.(b+j) in
                 let x = if y = 0. then 0. else Float.rem (Float.rem scratch.(a+j) y +. y) y in
                 if not (Float.is_finite x) then raise Nonfinite; scratch.(at+j) <- x done
             | Pow -> for j = first to last - 1 do let x = Float.pow (Float.abs scratch.(a+j)) scratch.(b+j) in
                 if not (Float.is_finite x) then raise Nonfinite; scratch.(at+j) <- x done
             | Min -> for j = first to last - 1 do let x = Float.min scratch.(a+j) scratch.(b+j) in
                 if not (Float.is_finite x) then raise Nonfinite; scratch.(at+j) <- x done
             | Max -> for j = first to last - 1 do let x = Float.max scratch.(a+j) scratch.(b+j) in
                 if not (Float.is_finite x) then raise Nonfinite; scratch.(at+j) <- x done
             | (Atan2 | Hypot) -> for j=first to last-1 do
                 let x=binary_apply operation scratch.(a+j) scratch.(b+j) in
                 if not(Float.is_finite x)then raise Nonfinite;scratch.(at+j)<-x done
             | (Lt | Le | Gt | Ge | Eq | And | Or) ->
                 for j = first to last - 1 do
                   let x = scratch.(a+j) and y = scratch.(b+j) in
                   let result = match operation with
                     | Lt -> x < y | Le -> x <= y | Gt -> x > y | Ge -> x >= y | Eq -> x = y
                     | And -> x <> 0. && y <> 0. | Or -> x <> 0. || y <> 0.
                     | _ -> assert false in
                   scratch.(at+j) <- if result then 1. else 0.
                 done)
        | Unary (operation, a) ->
            let a = a * block_size in
            (match operation with
             | Sin -> for j = first to last - 1 do let x = sin scratch.(a+j) in if not (Float.is_finite x) then raise Nonfinite; scratch.(at+j) <- x done
             | Cos -> for j = first to last - 1 do let x = cos scratch.(a+j) in if not (Float.is_finite x) then raise Nonfinite; scratch.(at+j) <- x done
             | Sqrt -> for j = first to last - 1 do scratch.(at+j) <- sqrt (Float.abs scratch.(a+j)) done
             | Abs -> for j = first to last - 1 do scratch.(at+j) <- Float.abs scratch.(a+j) done
             | (Tan|Asin|Acos|Exp|Log|Sign) -> for j=first to last-1 do
                 let x=unary_apply operation scratch.(a+j)in
                 if not(Float.is_finite x)then raise Nonfinite;scratch.(at+j)<-x done
             | Not -> for j = first to last - 1 do scratch.(at+j) <- if scratch.(a+j) = 0. then 1. else 0. done)
        | Int_input _ | Int_uniform _ | Int_frame _ | Int_accumulator | Int_binary _ | Int_compare _
        | Int_abs _ | Convert _ | Int_select _ | Raise _ -> raise Unsupported in
      let execute dependent first last =
      for slot = 0 to Array.length t.code - 1 do
        if t.dependent.(slot) = dependent && not omitted.(slot) then
          execute_instruction slot t.code.(slot) first last
      done in
      match streaming with
      |Some (noise,amplitude,(xi,_,xc),(yi,_,yc),(zi,_,zc),frequency,products)->
          let scalar id=match t.code.(id) with
            |Const x->x|Uniform (i,c)->uniforms.(i).(c)|Frame _->frame.(id)|_->assert false in
          let x=columns.(xi).(xc) and y=columns.(yi).(yc) and z=columns.(zi).(zc) in
          Rays_math.Noise.Private.sample3_into (Option.get tables.(noise)) ~first:0 ~last:length
            ~x:x.data ~x_offset:(x.offset+start*x.stride) ~x_stride:x.stride
            ~y:y.data ~y_offset:(y.offset+start*y.stride) ~y_stride:y.stride
            ~z:z.data ~z_offset:(z.offset+start*z.stride) ~z_stride:z.stride
            ~frequency:(Option.fold ~none:1. ~some:scalar frequency) ~output:scratch ();
          let amplitude=scalar amplitude in
          for j=0 to length-1 do
            let noise=scratch.(j) in
            scratch.(j)<-noise*.amplitude;
            (* Multiplication cannot make NaN/infinity finite, so this check
               also rejects every nonfinite noise sample. *)
            if not (Float.is_finite scratch.(j)) then raise Nonfinite
          done;
          Array.iteri (fun k components->
            let width=Array.length components and output=outputs.(k) in
            if plane_outputs<>None then
              Array.iteri (fun component ((bi,_,bc),(di,_,dc))->
                let {data=base;offset=bo;stride=bs}=columns.(bi).(bc)
                and {data=direction;offset=doff;stride=ds}=columns.(di).(dc) in
                let destination=(Option.get plane_outputs).(k).(component) in
                for j=0 to length-1 do
                  scratch.(block_size+j)<-Array.unsafe_get direction (doff+(start+j)*ds)*.scratch.(j);
                  if not (Float.is_finite scratch.(block_size+j)) then raise Nonfinite;
                  let x=Array.unsafe_get base (bo+(start+j)*bs)+.scratch.(block_size+j) in
                  if not (Float.is_finite x) then raise Nonfinite;
                  (match destination with Some data->Array.unsafe_set data (output_start+j) x|None->())
                done) components
            else
            let vector=if width=3 then
              let (bi,bw,bx),(di,dw,dx)=components.(0)
              and (bj,bv,by),(dj,dv,dy)=components.(1)
              and (bk,bu,bz),(dk,du,dz)=components.(2) in
              if bi=bj && bj=bk && bw=bv && bv=bu && di=dj && dj=dk && dw=dv && dv=du
              then Some (bi,bw,bx,by,bz,di,dw,dx,dy,dz) else None
              else None in
            match vector with
            |Some (bi,bw,bx,by,bz,di,dw,dx,dy,dz)->
              let base=inputs.(bi) and direction=inputs.(di) in
              for j=0 to length-1 do
                let at=(output_start+j)*3 and b=(start+j)*bw and d=(start+j)*dw
                and scale=scratch.(j) in
                Array.unsafe_set output at (Array.unsafe_get direction (d+dx)*.scale);
                Array.unsafe_set output (at+1) (Array.unsafe_get direction (d+dy)*.scale);
                Array.unsafe_set output (at+2) (Array.unsafe_get direction (d+dz)*.scale);
                Array.unsafe_set output at (Array.unsafe_get base (b+bx)+.Array.unsafe_get output at);
                Array.unsafe_set output (at+1) (Array.unsafe_get base (b+by)+.Array.unsafe_get output (at+1));
                Array.unsafe_set output (at+2) (Array.unsafe_get base (b+bz)+.Array.unsafe_get output (at+2));
                (* A nonfinite product remains nonfinite after addition. Checking
                   the three sums therefore also rejects every invalid product. *)
                if not (Float.is_finite (Array.unsafe_get output at)
                  && Float.is_finite (Array.unsafe_get output (at+1))
                  && Float.is_finite (Array.unsafe_get output (at+2))) then raise Nonfinite
              done
            |None->
            Array.iteri (fun component ((bi,bw,bc),(di,dw,dc))->
              let base=inputs.(bi) and direction=inputs.(di) in
              for j=0 to length-1 do
                let at=(output_start+j)*width+component in
                Array.unsafe_set output at (Array.unsafe_get direction ((start+j)*dw+dc)*.scratch.(j));
                if not (Float.is_finite (Array.unsafe_get output at)) then raise Nonfinite;
                Array.unsafe_set output at (Array.unsafe_get base ((start+j)*bw+bc)+.Array.unsafe_get output at);
                if not (Float.is_finite (Array.unsafe_get output at)) then raise Nonfinite
              done) components) products
      |None when Option.is_some scalar_streaming ->
          let noise,(xi,_,xc),(yi,_,yc),z,frequency,gain,bias,amplitude,products=Option.get scalar_streaming in
          let scalar id=match t.code.(id) with
            |Const x->x|Uniform (i,c)->uniforms.(i).(c)|Frame _->frame.(id)|_->assert false in
          let x=columns.(xi).(xc) and y=columns.(yi).(yc) in
          let z,z_offset,z_stride=match z with
            |Some (i,_,c)->let z=columns.(i).(c) in z.data,z.offset+start*z.stride,z.stride
            |None->scratch,block_size,1 in
          Rays_math.Noise.Private.sample3_into (Option.get tables.(noise)) ~first:0 ~last:length
            ~x:x.data ~x_offset:(x.offset+start*x.stride) ~x_stride:x.stride
            ~y:y.data ~y_offset:(y.offset+start*y.stride) ~y_stride:y.stride
            ~z ~z_offset ~z_stride ~frequency:(Option.fold ~none:1. ~some:scalar frequency) ~output:scratch ();
          let gain=scalar gain and bias=scalar bias and amplitude=scalar amplitude in
          for j=0 to length-1 do
            scratch.(j)<-scratch.(j)*.gain;
            scratch.(j)<-scratch.(j)-.bias;
            scratch.(j)<-scratch.(j)*.amplitude;
            (* Mul/Sub/Mul propagate every invalid intermediate to the final
               scale. Stores retain each separate binary64 rounding. *)
            if not (Float.is_finite scratch.(j)) then raise Nonfinite
          done;
          Array.iteri (fun k components->
            let width=Array.length components and output=outputs.(k) in
            if plane_outputs<>None then
              Array.iteri (fun component ((bi,_,bc),expression)->
                let {data=base;offset;stride}=columns.(bi).(bc) in
                let destination=(Option.get plane_outputs).(k).(component) in
                match expression with
                |None->for j=0 to length-1 do
                    let x=Array.unsafe_get base (offset+(start+j)*stride) in
                    if not (Float.is_finite x) then raise Nonfinite;
                    (match destination with Some data->Array.unsafe_set data (output_start+j) x|None->())
                  done
                |Some _->for j=0 to length-1 do
                    let x=Array.unsafe_get base (offset+(start+j)*stride)+.scratch.(j) in
                    if not (Float.is_finite x) then raise Nonfinite;
                    (match destination with Some data->Array.unsafe_set data (output_start+j) x|None->())
                  done) components
            else
            Array.iteri (fun component ((bi,bw,bc),expression)->
              let base=inputs.(bi) in
              match expression with
              |None->for j=0 to length-1 do
                  let x=Array.unsafe_get base ((start+j)*bw+bc) in
                  if not (Float.is_finite x) then raise Nonfinite;
                  Array.unsafe_set output ((output_start+j)*width+component) x
                done
              |Some _->for j=0 to length-1 do
                  let at=(output_start+j)*width+component in
                  Array.unsafe_set output at (Array.unsafe_get base ((start+j)*bw+bc)+.scratch.(j));
                  if not (Float.is_finite (Array.unsafe_get output at)) then raise Nonfinite
                done) components) products
      |None->
      execute false 0 length;
      if t.result=Collect && plane_outputs<>None then
        Array.iteri (fun k registers->Array.iteri (fun component register->
          let source=register*block_size in
          (match collect_product.(k).(component) with
           |None->()
           |Some (base,a,b)->
             let base=base*block_size and a=a*block_size and b=b*block_size in
             for j=0 to length-1 do
               scratch.(source+j)<-scratch.(a+j)*.scratch.(b+j);
               if not (Float.is_finite scratch.(source+j)) then raise Nonfinite;
               scratch.(source+j)<-scratch.(base+j)+.scratch.(source+j)
             done);
          for j=0 to length-1 do
            let x=scratch.(source+j) in
            if not (Float.is_finite x) then raise Nonfinite;
            store k component (output_start+j) x
          done) registers) t.outputs
      else if t.result = Collect then
        Array.iteri (fun k registers ->
          let output=outputs.(k) in
          if Array.exists Option.is_some collect_product.(k) then
            Array.iteri (fun component product->
              let width=Array.length registers in
              match product with
              |Some (base,a,b)->
                  let base=base*block_size and a=a*block_size and b=b*block_size in
                  for j=0 to length-1 do
                    let at=(output_start+j)*width+component in
                    (* Store the product before adding: the array boundary preserves
                       its binary64 rounding, including cancellation and signed zero. *)
                    Array.unsafe_set output at (Array.unsafe_get scratch (a+j)*.Array.unsafe_get scratch (b+j));
                    if not (Float.is_finite (Array.unsafe_get output at)) then raise Nonfinite;
                    Array.unsafe_set output at (Array.unsafe_get scratch (base+j)+.Array.unsafe_get output at);
                    if not (Float.is_finite (Array.unsafe_get output at)) then raise Nonfinite
                  done
              |None->let source=registers.(component)*block_size in
                  for j=0 to length-1 do
                    let x=scratch.(source+j) in
                    if not (Float.is_finite x) then raise Nonfinite;
                    output.((output_start+j)*width+component)<-x
                  done) collect_product.(k)
          else if Array.length registers=3 then begin
            let x=registers.(0)*block_size and y=registers.(1)*block_size
            and z=registers.(2)*block_size in
            for j=0 to length-1 do
              let px=scratch.(x+j) and py=scratch.(y+j) and pz=scratch.(z+j) in
              if not (Float.is_finite px && Float.is_finite py && Float.is_finite pz) then raise Nonfinite;
              let at=(output_start+j)*3 in
              output.(at)<-px;output.(at+1)<-py;output.(at+2)<-pz
            done
          end else
            for component=0 to Array.length registers-1 do
              let source=registers.(component)*block_size and width=Array.length registers in
              for j=0 to length-1 do
                let x=scratch.(source+j) in
                if not (Float.is_finite x) then raise Nonfinite;
                output.((output_start+j)*width+component)<-x
              done
            done) t.outputs
      else
      for j = 0 to length - 1 do
        (match t.result with Accumulate _ -> execute true j (j + 1) | _ -> ());
        for k = 0 to Array.length t.outputs - 1 do
        let registers = t.outputs.(k) in
        let output = outputs.(k) and width = widths.(k) in
        for component = 0 to width - 1 do
          let x = scratch.(registers.(component) * block_size + j) in
          if not (Float.is_finite x) then raise Nonfinite;
          (match t.result with
           | Collect -> () | Accumulate _ -> accumulator.(component) <- x
           | Sum _ ->
               let total = if !initialized then accumulator.(component) +. x else x in
               if not (Float.is_finite total) then raise Nonfinite;
               accumulator.(component) <- total);
          if collecting then output.((output_start+j) * width + component) <- x
        done
        done;
        (match t.result with Sum _ -> initialized := true | _ -> ())
      done
      done end in
    (match t.result with
     | Collect -> Rays_math.Parallel.for_ ~chunk_size:1 ~start:0 ~finish:(chunks - 1) chunk
     | Sum _ | Accumulate _ ->
         (* The fixed tree composes ordered chunk spans, retaining reference additions
            instead of reassociating partial sums (which changes cancellation and signed zero). *)
         let rec ordered first last =
           if last - first = 1 then chunk first else if first < last then begin
             let middle = first + (last - first) / 2 in
             ordered first middle; ordered middle last
           end in
         ordered 0 chunks);
    let value = if plane_outputs<>None then [] else if collecting then Array.to_list (Array.mapi (fun k output -> match widths.(k) with
      | 2 -> E.Vec2_array output | 3 -> E.Vec3_array output | 4 -> E.Vec4_array output
      | _ -> E.Float_array output) outputs)
    else [match t.result, seed with
      | Accumulate _, Some seed when kept = 0 -> seed
      | Sum false, _ when kept = 0 -> E.Int 0
      | _ -> (match width with
          | 2 -> E.Vec2 (accumulator.(0), accumulator.(1))
          | 3 -> E.Vec3 (accumulator.(0), accumulator.(1), accumulator.(2))
          | 4 -> E.Vec4 (accumulator.(0), accumulator.(1), accumulator.(2), accumulator.(3))
          | _ -> E.Float accumulator.(0))] in
    Option.iter (fun (clock, report) -> report t ~seconds:(max 0. (clock () -. Option.get started)) ~reference:false) measure;
    value in
  let result = E.transaction state (fun () ->
    try Ok (work ()) with
    | Failed d -> Error d
    | Nonfinite -> Error (Flow.Diagnostic.error ~code:"E_NONFINITE" "Packed kernel produced a nonfinite result.")
    | Unsupported -> Error (Flow.Diagnostic.error ~code:"E_KERNEL" "Kernel needs reference evaluation.")
    | V.Fail (code, message, span) -> Error (Flow.Diagnostic.error ?span ~code message)
    | Invalid_argument message -> Error (Flow.Diagnostic.error ~code:"E_KERNEL" ("Kernel needs reference evaluation: " ^ message))
    | Out_of_memory -> Error (Flow.Diagnostic.error ~code:"E_ARRAY_MEMORY" "Frame data exceeds available memory.")) in
  match result with Ok _ -> result | Error _ when strict || plane_outputs<>None || Array.length t.outputs > 1 -> result | Error _ ->
    let started = Option.map (fun (clock, _) -> clock ()) measure in
    let result = reference ~state ?elems ?resolve t ~live in
    Option.iter (fun (clock, report) -> report t ~seconds:(max 0. (clock () -. Option.get started)) ~reference:true) measure;
    Result.map (fun value -> [value]) result

and force ?state ?elems ?resolve ?measure ?strict t ~live =
  match run_all ?state ?elems ?resolve ?measure ?strict t ~live with
  | Ok [value] -> Ok value
  | Ok _ -> Error (Flow.Diagnostic.error ~code:"E_KERNEL" "Program has several outputs; use force_all.")
  | Error _ as error -> error

let force_all ?state ?elems ?resolve ?measure ?strict t ~live =
  run_all ?state ?elems ?resolve ?measure ?strict t ~live

let force_into ?state ?elems ?resolve ?measure ?strict ~column_source ~count ~outputs t ~live =
  Result.map (fun _->()) (run_all ~column_source ~plane_outputs:outputs ~expected_count:count ?state ?elems ?resolve ?measure ?strict t ~live)

module Private = struct
  let trace = trace
  let ordered_add = ordered_add
  let output_reachable = output_reachable
  let finite_checks = finite_checks
  type view = {code : instruction array; widths : int array; outputs : int array array;
    uniform_widths : int array; collecting : bool; }
  let view (t : t) =
    let uniform_widths = Array.make (Array.length t.uniforms) 1 in
    let rec instruction = function Uniform (index, component) ->
      uniform_widths.(index) <- max uniform_widths.(index) (component+1)
      | Guarded (_,body) -> instruction body | _ -> () in
    Array.iter instruction t.code;
    {code=t.code; widths=t.widths; outputs=t.outputs; uniform_widths;
      collecting=(match t.result with Collect -> true | _ -> false);
      }
  type inputs = {arrays : float array array; uniforms : float array array;
    frame : float array; count : int}
  type value_inputs = {arrays : E.value array; uniforms : E.value array;
    frame : E.value array; count : int}
  let prepare_values ?state ?resolve ?measure (t : t) ~live =
    let state = Option.value ~default:(E.create_state ()) state in
    E.transaction state (fun () -> try
      let rec evaluate residual term =
        match term.W.node with
        | W.Ref_binding (name, []) ->
            (match List.assoc_opt name (E.Private.residual_view residual).bindings with
             | Some (E.Residual residual) -> evaluate residual (E.Private.residual_view residual).term
             | _ -> materialize residual term)
        | _ -> materialize residual term
      and materialize residual term =
        match compile_impl ~fusion:t.fusion ~dynamic:t.dynamic ~count_source:t.count_source residual term with
        | Ok program -> get (force ~state ?resolve ?measure program ~live)
        | Error _ -> get (E.Private.eval_term ~state ?resolve residual term ~live) in
      let arrays = Array.map (fun (residual,term) -> evaluate residual term) t.sources in
      Array.iteri (fun index value ->
        if V.ty_of value<>(snd t.sources.(index)).W.ty then
          V.fail "E_ARRAY_TYPE" "Kernel input changed its packed element type.") arrays;
      let count = if arrays=[||] then 0 else Array.fold_left min max_int
        (Array.map V.array_length arrays) in
      let execute residual _live = Some (Ok (evaluate residual (E.Private.residual_view residual).term)) in
      let uniforms = match get (E.Private.force_with_executor ~state ?resolve ~compiled:false ~execute
          (E.List t.uniforms) ~live) with E.List values -> values | _ -> assert false in
      let frame = Array.map (fun instruction -> match unguarded instruction with
        | Frame "t" -> E.Float live.Frame_input.t
        | Frame name | Int_frame name -> (match Flow.Op.find name Flow.Context.value with
            | Some op -> op.body ~live ~node:(fun _ _ -> raise Unsupported) []
            | None -> raise Unsupported)
        | _ -> E.Float 0.) t.code in
      Ok ({arrays; uniforms; frame; count} : value_inputs)
    with Failed error -> Error error
      | Unsupported -> Error (Flow.Diagnostic.error ~code:"E_KERNEL" "Kernel inputs need reference evaluation.")
      | V.Fail (code,message,span) -> Error (Flow.Diagnostic.error ?span ~code message)
      | Invalid_argument message -> Error (Flow.Diagnostic.error ~code:"E_KERNEL" ("Kernel inputs need reference evaluation: " ^ message))
      | Out_of_memory -> Error (Flow.Diagnostic.error ~code:"E_ARRAY_MEMORY" "Frame data exceeds available memory."))
  let prepare ?state ?resolve ?measure (t : t) ~live =
    if integer_program t then Error (Flow.Diagnostic.error ~code:"E_GPU_FORM"
      "Integer sources, uniforms and instructions stay on the CPU.") else
    Result.map (fun (values : value_inputs) ->
      let arrays=Array.map (function E.Float_array values | Vec2_array values
          | Vec3_array values | Vec4_array values -> values | _ -> assert false) values.arrays in
      ({arrays;uniforms=Array.map components values.uniforms;
        frame=Array.map V.num values.frame;count=values.count} : inputs))
      (prepare_values ?state ?resolve ?measure t ~live)
end
