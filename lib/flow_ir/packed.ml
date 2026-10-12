module E = Flow.Eval
module W = Flow.Workspace
module V = Flow.Value
module Ty = Flow.Ty

type binary = Flow.Packed_ops.binary = Add | Sub | Mul | Div | Mod | Pow | Min | Max | Lt | Le | Gt | Ge | Eq | And | Or
type unary = Flow.Packed_ops.unary = Sin | Cos | Sqrt | Abs | Not
type instruction = Core.Region.instruction = Const of float | Input of int * int * int
  | Uniform of int * int | Frame of string | Accumulator of int
  | Binary of binary * int * int | Unary of unary * int | Noise3 of int * int * int * int * int
  | Select of int * int * int
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
let dependent_of code =
  let dependent = Array.make (Array.length code) false in
  Array.iteri (fun id -> function
    | Accumulator _ -> dependent.(id) <- true
    | Binary (_, a, b) -> dependent.(id) <- dependent.(a) || dependent.(b)
    | Unary (_, a) -> dependent.(id) <- dependent.(a)
    | Noise3 (a, b, c, _, _) | Select (a, b, c) -> dependent.(id) <- dependent.(a) || dependent.(b) || dependent.(c)
    | _ -> ()) code;
  dependent

let of_region (r : Core.Region.t) =
  let invalid message = Error [Flow.Diagnostic.error ~span:r.term.form.span ~code:"E_PACKED_LAYOUT" message] in
  let ok slot id = id >= 0 && id < slot in
  let operands_ok = ref true in
  Array.iteri (fun slot -> function
    | Input (input,width,component) ->
        if input<0 || input>=Array.length r.widths || width<>r.widths.(input)
          || component<0 || component>=width then operands_ok:=false
    | Binary (_, a, b) -> if not (ok slot a && ok slot b) then operands_ok := false
    | Unary (_, a) -> if not (ok slot a) then operands_ok := false
    | Noise3 (a, b, c, _, _) | Select (a, b, c) -> if not (ok slot a && ok slot b && ok slot c) then operands_ok := false
    | _ -> ()) r.code;
  if Array.length r.widths<>Array.length r.sources
    || not (Array.for_all (fun width->width>=1 && width<=4) r.widths) then
    invalid "Region inputs need matching sources and widths from 1 to 4."
  else if not !operands_ok then invalid "Region instruction reads an invalid input or a register defined later."
  else if Array.length r.code > Flow.Packed_ops.register_limit then
    invalid (Printf.sprintf "Region exceeds %d registers." Flow.Packed_ops.register_limit)
  else if r.outputs = [||] || (Array.length r.outputs > 1 && r.result <> Collect) then
    invalid "A region has one output, or several only when it collects."
  else if not (Array.for_all (Array.for_all (ok (Array.length r.code))) r.outputs) then invalid "Region output names a missing register."
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
    match t.code.(slot) with
    | Binary (_, a, b) -> use a; use b
    | Unary (_, a) -> use a
    | Select (a, b, c) | Noise3 (a, b, c, _, _) -> use a; use b; use c
    | _ -> ()
  end in
  Array.iter (Array.iter use) t.outputs;
  used

let finite_checks t =
  (* GPU qualification rejects nonfinite constants. These operations cannot
     introduce a nonfinite result; their operands are checked at their source. *)
  Array.map (function
    | Const _ | Select _ | Unary ((Abs | Sqrt | Not), _)
    | Binary ((Min | Max | Lt | Le | Gt | Ge | Eq | And | Or), _, _) -> false
    | _ -> true) t.code

let gpu_refusals t =
  let reasons = ref [] in
  let refuse message = reasons := Flow.Diagnostic.error ~code:"E_GPU_FORM" message :: !reasons in
  if t.result <> Collect || not (zipped t) || t.skip <> [||] then
    refuse "GPU kernels require Collect with Zip iteration and no skipped elements.";
  if Array.exists (function Accumulator _ -> true | _ -> false) t.code then
    refuse "Ordered accumulators stay on the CPU.";
  let used = output_reachable t in
  let bad_noise = ref false and bad_constant = ref false in
  Array.iteri (fun i instruction -> if used.(i) then match instruction with
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
               | _ -> E.Private.eval_term ~state ?elems ?resolve residual term ~live)) in
    let seed = match t.result with
      | Accumulate (seed, _) -> Some (get (E.Private.eval_term ~state ?elems ?resolve t.residual seed ~live))
      | _ -> None in
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
    let uniforms = force_uniforms ~strict ~state ?elems ?resolve ?measure t ~live in
    let frame = Array.map (function
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
    Array.iter (function
      |Binary (_,a,b)->use a;use b
      |Unary (_,a)->use a
      |Noise3 (a,b,c,_,_)|Select (a,b,c)->use a;use b;use c
      |_->()) t.code;
    Array.iter (Array.iter use) t.outputs;
    let omitted=Array.make (Array.length t.code) false in
    let scale register=match t.code.(register) with
      |Binary (Mul,a,b) when uses.(register)=1 ->
          let constant id=match t.code.(id) with Const _|Uniform _|Frame _->true|_->false in
          if constant b then Some (a,b) else if constant a then Some (b,a) else None
      |_->None in
    let noise_scale=Array.map (function
      |Noise3 (x,y,z,_,_)->(match scale x,scale y,scale z with
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
      let tables=Array.map(function Noise3(_,_,_,seed,_)->Some(Operators.noise_table seed)
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
      let execute dependent first last =
      for slot = 0 to Array.length t.code - 1 do
        let instruction = t.code.(slot) in
        if t.dependent.(slot) = dependent && not omitted.(slot) then begin
        let at = slot * block_size in
        match instruction with
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
             | Not -> for j = first to last - 1 do scratch.(at+j) <- if scratch.(a+j) = 0. then 1. else 0. done)
        end
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
    | Nonfinite | Unsupported -> Error (Flow.Diagnostic.error ~code:"E_KERNEL" "Kernel needs reference evaluation.")
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

and force_uniforms ?(strict = false) ~state ?elems ?resolve ?measure t ~live =
  let execute residual live =
    match compile_impl ~fusion:t.fusion ~dynamic:t.dynamic ~count_source:t.count_source
      residual (E.Private.residual_view residual).term with
    | Ok packed -> Some (force ~strict ~state ?elems ?resolve ?measure packed ~live)
    | Error _ -> None in
  match get (E.Private.force_with_executor ~state ?elems ?resolve ~compiled:false ~execute
    (E.List t.uniforms) ~live) with
  | E.List values -> Array.map components values
  | _ -> assert false

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
    Array.iter (function Uniform (index, component) ->
      uniform_widths.(index) <- max uniform_widths.(index) (component+1) | _ -> ()) t.code;
    {code=t.code; widths=t.widths; outputs=t.outputs; uniform_widths;
      collecting=(match t.result with Collect -> true | _ -> false);
      }
  type inputs = {arrays : float array array; uniforms : float array array;
    frame : float array; count : int}
  let prepare ?state ?resolve ?measure (t : t) ~live =
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
        | Ok program -> get (force ~state ?resolve program ~live)
        | Error _ -> get (E.Private.eval_term ~state ?resolve residual term ~live) in
      let arrays = Array.mapi (fun index (residual, term) ->
        match evaluate residual term, t.widths.(index) with
        | E.Float_array values, 1 | Vec2_array values, 2 | Vec3_array values, 3 | Vec4_array values, 4 -> values
        | _ -> V.fail "E_ARRAY_TYPE" "Kernel input changed its packed element type.") t.sources in
      let count = if arrays=[||] then 0 else Array.fold_left min max_int
        (Array.mapi (fun index values -> Array.length values / t.widths.(index)) arrays) in
      let uniforms = force_uniforms ~state ?resolve ?measure t ~live in
      let frame = Array.map (function
        | Frame "t" -> live.Frame_input.t
        | Frame name -> (match Flow.Op.find name Flow.Context.value with
            | Some op -> V.num (op.body ~live ~node:(fun _ _ -> raise Unsupported) [])
            | None -> raise Unsupported)
        | _ -> 0.) t.code in
      Ok {arrays; uniforms; frame; count}
    with Failed error -> Error error
      | Unsupported -> Error (Flow.Diagnostic.error ~code:"E_KERNEL" "Kernel inputs need reference evaluation.")
      | V.Fail (code,message,span) -> Error (Flow.Diagnostic.error ?span ~code message)
      | Invalid_argument message -> Error (Flow.Diagnostic.error ~code:"E_KERNEL" ("Kernel inputs need reference evaluation: " ^ message))
      | Out_of_memory -> Error (Flow.Diagnostic.error ~code:"E_ARRAY_MEMORY" "Frame data exceeds available memory."))
end
