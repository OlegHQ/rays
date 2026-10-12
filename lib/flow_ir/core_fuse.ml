(* Fusion on regions: a map-like region absorbs the Collect + Zip regions that feed
   it when their counts or origins agree, sharing equal instructions, within the
   register limit. Declining leaves the region unfused; it never fails. *)
module E = Flow.Eval
module W = Flow.Workspace
open Core.Region

(* An accumulating register program: instructions equal up to registers share one
   register, and exceeding the register limit raises [Core_region.Unsupported]. *)
type builder = {
  emit : instruction -> int; append_source : (E.residual * W.term) -> int -> int;
  append_uniforms : E.value array -> int;
  append_code : Core.Region.t -> (int -> int -> int -> int) -> int -> int array array;
  finish : unit -> (E.residual * W.term) array * int array * E.value array * instruction array }
let builder () =
  let sources = ref [] and widths = ref [] and nsources = ref 0 in
  let uniforms = ref [] and nuniforms = ref 0 and code = ref [] and ncode = ref 0 in
  let shared = Hashtbl.create 64 and emitted = Hashtbl.create 64 in
  let emit instruction =
    let key = Core_region.instruction_key instruction in
    match Hashtbl.find_opt shared key with
    | Some id -> id
    | None ->
        if !ncode >= Flow.Packed_ops.register_limit then raise Core_region.Unsupported;
        let id = !ncode in incr ncode; code := instruction :: !code;
        Hashtbl.add emitted id instruction;
        Hashtbl.add shared key id; id in
  let append_source source width =
    let i = !nsources in incr nsources; sources := source :: !sources; widths := width :: !widths; i in
  let append_uniforms values =
    let offset = !nuniforms in
    Array.iter (fun v -> incr nuniforms; uniforms := v :: !uniforms) values; offset in
  let append_code p input uniform =
    let registers = Array.make (Array.length p.code) 0 in
    Array.iteri (fun i instruction ->
      let at n = registers.(n) in
      let rec remap instruction = match instruction with
        | Input (source, width, component) ->
            let register=input source width component in
            if Core.Region.integer_register (Hashtbl.find emitted register) then Convert (To_float,register)
            else Hashtbl.find emitted register
        | Int_input source ->
            let instruction=Hashtbl.find emitted (input source 1 0) in
            if not (Core.Region.integer_register instruction) then raise Core_region.Unsupported;
            instruction
        | Uniform (n, component) -> Uniform (uniform + n, component)
        | Array_prepare(n,ty) -> Array_prepare(uniform+n,ty)
        | Gather(a,i,w,c) -> Gather(at a,at i,w,c)
        | Int_gather(a,i) -> Int_gather(at a,at i)
        | Int_uniform n -> Int_uniform (uniform+n)
        | Binary (op, a, b) -> Binary (op, at a, at b)
        | Int_binary (op,a,b) -> Int_binary(op,at a,at b)
        | Int_compare (op,a,b) -> Int_compare(op,at a,at b)
        | Unary (op, a) -> Unary (op, at a)
        | Int_abs a -> Int_abs(at a) | Convert (op,a) -> Convert(op,at a)
        | Noise3 (a, b, c, seed, octaves) -> Noise3 (at a, at b, at c, seed, octaves)
        | Rand_at(seed,index) -> Rand_at(at seed,at index)
        | Fma(a,b,c) -> Fma(at a,at b,at c)
        | Checked_mul(p,a,b) -> Checked_mul(p,at a,at b)
        | Checked_fma(p,a,b,c) -> Checked_fma(p,at a,at b,at c)
        | Select (a, b, c) -> Select (at a, at b, at c)
        | Int_select (a,b,c) -> Int_select(at a,at b,at c)
        | Guarded (guards,body) ->
            Guarded(List.map(fun(c,yes)->at c,yes)guards,remap body)
        | instruction -> instruction in
      registers.(i) <- (match instruction with
        | Input (s,w,c) ->
            let register=input s w c in
            if Core.Region.integer_register (Hashtbl.find emitted register) then emit(Convert(To_float,register)) else register
        | Int_input s ->
            let register=input s 1 0 in
            if not (Core.Region.integer_register (Hashtbl.find emitted register)) then raise Core_region.Unsupported;
            register
        | _ -> emit(remap instruction))) p.code;
    Array.map (Array.map (Array.get registers)) p.outputs in
  let finish () = Array.of_list (List.rev !sources), Array.of_list (List.rev !widths),
    Array.of_list (List.rev !uniforms), Array.of_list (List.rev !code) in
  {emit; append_source; append_uniforms; append_code; finish}

let rec source_region ~dynamic ~count_source ((residual : E.residual), (term : W.term)) = match term.node with
  | W.Ref_binding (name, []) ->
      (match List.assoc_opt name (E.Private.residual_view residual).bindings with
       | Some (E.Residual r) -> source_region ~dynamic ~count_source (r, (E.Private.residual_view r).term)
       | _ -> None)
  | _ -> Core_region.lower ~dynamic ~count_source residual term |> Result.to_option |> Option.map fuse
and fuse (t : Core.Region.t) : Core.Region.t =
  if t.skip <> [||] || (t.iteration = Product && Array.length t.sources <> 1) then t else
  let children = Array.map (source_region ~dynamic:t.dynamic ~count_source:t.count_source) t.sources in
  let origins = Array.mapi (fun i -> function
    | Some p -> p.origin | None -> let r, s = t.sources.(i) in t.count_source r s) children in
  let origin = if origins <> [||] && Option.is_some origins.(0)
      && Array.for_all ((=) origins.(0)) origins then origins.(0) else None in
  let counts = Array.mapi (fun i -> function
    | Some p -> p.count | None -> let r, s = t.sources.(i) in Core_region.count_of r s) children in
  let count = if Array.for_all Option.is_some counts && counts <> [||] then
    Some (Array.fold_left (fun n c -> min n (Option.get c)) max_int counts) else t.count in
  let t = {t with count; origin = (match t.result with Collect -> origin | _ -> None)} in
  let can_fuse = function
    | Some p when p.result = Collect && p.iteration = Zip && p.skip = [||] && Array.length p.outputs = 1 ->
        Array.length t.sources = 1 || (Option.is_some p.count && p.count = count)
          || (Option.is_some origin && p.origin = origin)
    | _ -> false in
  if not (Array.exists can_fuse children) then t else
  try
    let b = builder () in
    let stages = ref t.stages and sites = ref t.sites in
    let inputs = Array.mapi (fun i child ->
      if can_fuse child then begin
        let p = Option.get child in
        let inputs = Array.mapi (fun i source -> b.append_source source p.widths.(i)) p.sources in
        let uniform = b.append_uniforms p.uniforms in
        stages := !stages @ p.stages;
        sites := p.sites @ !sites;
        (b.append_code p (fun i width component -> b.emit
          (if (snd p.sources.(i)).W.ty=Flow.Ty.Array Flow.Ty.Int then Int_input inputs.(i)
           else Input (inputs.(i), width, component))) uniform).(0)
      end else begin
        let source = b.append_source t.sources.(i) t.widths.(i) in
        Array.init t.widths.(i) (fun component -> b.emit
          (if (snd t.sources.(i)).W.ty=Flow.Ty.Array Flow.Ty.Int then Int_input source
           else Input (source, t.widths.(i), component)))
      end) children in
    let uniform = b.append_uniforms t.uniforms in
    let outputs = b.append_code t (fun i _ component -> inputs.(i).(component)) uniform in
    let sources, widths, uniforms, code = b.finish () in
    {t with sources; widths; uniforms; code; outputs; iteration = Zip; stages = !stages; sites = !sites}
  with Core_region.Unsupported -> t


(* Sibling regions of one mark set: Collect + Zip regions of equal static count or origin
   become one region with every output, sharing equal instructions. [None] when they do not
   agree or the register limit declines; the regions then stay separate. *)
let merge (regions : Core.Region.t list) : Core.Region.t option = match regions with
  | [] -> None
  | first :: _ ->
      let one (r : Core.Region.t) = r.result = Collect && r.iteration = Zip && r.skip = [||]
        && Array.length r.outputs = 1 && r.dynamic = first.dynamic in
      let same_count (r : Core.Region.t) = (Option.is_some first.count && r.count = first.count)
        || (Option.is_some first.origin && r.origin = first.origin) in
      if not (List.for_all (fun r -> one r && same_count r) regions) then None else
      try
        let b = builder () in
        let outputs = List.map (fun (r : Core.Region.t) ->
          let inputs = Array.mapi (fun i source -> b.append_source source r.widths.(i)) r.sources in
          let uniform = b.append_uniforms r.uniforms in
          (b.append_code r (fun i width component -> b.emit
            (if (snd r.sources.(i)).W.ty=Flow.Ty.Array Flow.Ty.Int then Int_input inputs.(i)
             else Input (inputs.(i), width, component))) uniform).(0))
          regions in
        let sources, widths, uniforms, code = b.finish () in
        Some {first with sources; widths; uniforms; code; outputs = Array.of_list outputs;
          stages = List.concat_map (fun (r : Core.Region.t) -> r.stages) regions;
          sites = List.concat_map (fun (r : Core.Region.t) -> r.sites) regions}
      with Core_region.Unsupported -> None
