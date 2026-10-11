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
    | Binary (_, a, b) -> if not (ok slot a && ok slot b) then operands_ok := false
    | Unary (_, a) -> if not (ok slot a) then operands_ok := false
    | Noise3 (a, b, c, _, _) | Select (a, b, c) -> if not (ok slot a && ok slot b && ok slot c) then operands_ok := false
    | _ -> ()) r.code;
  if not !operands_ok then invalid "Region instruction reads a register defined later."
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

let rec force_all ?state ?elems ?resolve ?measure t ~live =
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
          | Ok program -> force ~state ?elems ?resolve ?measure program ~live
          | Error _ -> E.Private.eval_term ~state ?elems ?resolve residual term ~live) in
    let seed = match t.result with
      | Accumulate (seed, _) -> Some (get (E.Private.eval_term ~state ?elems ?resolve t.residual seed ~live))
      | _ -> None in
    let inputs = Array.mapi (fun i (residual, term) ->
      let value = get (evaluate residual term) in
      match value, t.widths.(i) with
      | E.Float_array xs, 1 | Vec2_array xs, 2 | Vec3_array xs, 3 | Vec4_array xs, 4 -> xs
      | _ -> V.fail "E_ARRAY_TYPE" "Kernel input changed its packed element type.") t.sources in
    let lengths = Array.mapi (fun i a -> Array.length a / t.widths.(i)) inputs in
    let count = if t.iteration = Product && Array.exists ((=) 0) lengths then 0 else
      Array.fold_left (fun a b -> match t.iteration with
      | Zip -> min a b | Product ->
          if b <> 0 && a > max_int / b then V.fail "E_ARRAY_RANGE" "Kernel iteration count exceeds native bounds.";
          a * b) (if t.iteration = Zip then max_int else 1) lengths in
    let count = if inputs = [||] then 0 else count in
    let strides = Array.make (Array.length inputs) 1 in
    if t.iteration = Product && count > 0 then
      for i = Array.length inputs - 2 downto 0 do strides.(i) <- strides.(i + 1) * lengths.(i + 1) done;
    let uniforms = force_uniforms ~state ?resolve ?measure t ~live in
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
    let collecting = match t.result with Collect | Accumulate (_, true) -> true | _ -> false in
    if collecting && Array.exists (fun width -> kept > Sys.max_floatarray_length / width) widths then
      V.fail "E_ARRAY_RANGE" "Kernel output exceeds native storage bounds.";
    let outputs = Array.map (fun width -> Array.make (if collecting then kept * width else 0) 0.) widths in
    let accumulator = match seed with
      | Some (E.Vec2 _ | Vec3 _ | Vec4 _ as value) -> components value
      | Some v -> Array.make width (V.num v) | None -> Array.make width 0. in
    let initialized = ref (match t.result with Sum zero -> zero | _ -> true) in
    let ordered_add = ordered_add t in
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
      let scratch = Array.make (Array.length t.code * block_size) 0. in
      let noise_scratch=Rays_math.Noise.Private.create_fbm3_scratch () in
      let tables=Array.map(function Noise3(_,_,_,seed,_)->Some(Operators.noise_table seed)
        |_->None)t.code in
      let indices = Array.make block_size 0 in
      for block = chunk * blocks_per_chunk to min blocks ((chunk + 1) * blocks_per_chunk) - 1 do
      let start = block * block_size and limit = min count ((block + 1) * block_size) in
      let skipped = ref (skipped_before start) and length = ref 0 in
      for i = start to limit - 1 do
        if !skipped < Array.length skip && skip.(!skipped) = i then incr skipped
        else begin indices.(!length) <- i; incr length end
      done;
      let length = !length and output_start = start - skipped_before start in
      let execute dependent first last =
      for slot = 0 to Array.length t.code - 1 do
        let instruction = t.code.(slot) in
        if t.dependent.(slot) = dependent then begin
        let at = slot * block_size in
        match instruction with
        | Const x -> Array.fill scratch (at + first) (last - first) x
        | Input (input, width, component) ->
            let source = inputs.(input) in
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
            if octaves=1 then Rays_math.Noise.Private.sample3_into noise ~first ~last
              ~x:scratch ~x_offset:(x * block_size) ~y:scratch ~y_offset:(y * block_size)
              ~z:scratch ~z_offset:(z * block_size) ~output:scratch ~output_offset:at ()
            else for j=first to last-1 do
              scratch.(at+j)<-Rays_math.Noise.Private.fbm3_with_scratch noise_scratch noise
                ~octaves ~lacunarity:2. ~gain:0.5
                ~x:scratch.(x*block_size+j) ~y:scratch.(y*block_size+j) ~z:scratch.(z*block_size+j)
            done
        | Binary (operation, a, b) ->
            let a = a * block_size and b = b * block_size in
            (match operation with
             | Add -> for j = first to last - 1 do let x = scratch.(a+j) +. scratch.(b+j) in if not (Float.is_finite x) then raise Nonfinite; scratch.(at+j) <- x done
             | Sub -> for j = first to last - 1 do let x = scratch.(a+j) -. scratch.(b+j) in if not (Float.is_finite x) then raise Nonfinite; scratch.(at+j) <- x done
             | Mul -> for j = first to last - 1 do let x = scratch.(a+j) *. scratch.(b+j) in if not (Float.is_finite x) then raise Nonfinite; scratch.(at+j) <- x done
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
      execute false 0 length;
      for j = 0 to length - 1 do
        (match t.result with Accumulate _ -> execute true j (j + 1) | _ -> ());
        Array.iteri (fun k registers ->
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
        done) t.outputs;
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
    let value = if collecting then Array.to_list (Array.mapi (fun k output -> match widths.(k) with
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
  match result with Ok _ -> result | Error _ when Array.length t.outputs > 1 -> result | Error _ ->
    let started = Option.map (fun (clock, _) -> clock ()) measure in
    let result = reference ~state ?elems ?resolve t ~live in
    Option.iter (fun (clock, report) -> report t ~seconds:(max 0. (clock () -. Option.get started)) ~reference:true) measure;
    Result.map (fun value -> [value]) result

and force ?state ?elems ?resolve ?measure t ~live =
  match force_all ?state ?elems ?resolve ?measure t ~live with
  | Ok [value] -> Ok value
  | Ok _ -> Error (Flow.Diagnostic.error ~code:"E_KERNEL" "Program has several outputs; use force_all.")
  | Error _ as error -> error

and force_uniforms ~state ?elems ?resolve ?measure t ~live =
  let execute residual live =
    match compile_impl ~fusion:t.fusion ~dynamic:t.dynamic ~count_source:t.count_source
      residual (E.Private.residual_view residual).term with
    | Ok packed -> Some (force ~state ?elems ?resolve ?measure packed ~live)
    | Error _ -> None in
  match get (E.Private.force_with_executor ~state ?elems ?resolve ~compiled:false ~execute
    (E.List t.uniforms) ~live) with
  | E.List values -> Array.map components values
  | _ -> assert false

module Private = struct
  let trace = trace
  let ordered_add = ordered_add
  let output_reachable = output_reachable
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
