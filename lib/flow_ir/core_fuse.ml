(* Fusion on regions: a map-like region absorbs the Collect + Zip regions that feed
   it when their counts or origins agree, sharing equal instructions, within the
   register limit. Declining leaves the region unfused; it never fails. *)
module E = Flow.Eval
module W = Flow.Workspace
open Core.Region

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
    | Some p when p.result = Collect && p.iteration = Zip && p.skip = [||] ->
        Array.length t.sources = 1 || (Option.is_some p.count && p.count = count)
          || (Option.is_some origin && p.origin = origin)
    | _ -> false in
  if not (Array.exists can_fuse children) then t else
  try
    let sources = ref [] and widths = ref [] and nsources = ref 0 in
    let uniforms = ref [] and nuniforms = ref 0 and code = ref [] and ncode = ref 0 in
    let stages = ref t.stages and sites = ref t.sites in
    let shared = Hashtbl.create 64 in
    let emit instruction =
      let key = Marshal.to_string instruction [Marshal.No_sharing] in
      match Hashtbl.find_opt shared key with
      | Some id -> id
      | None ->
          if !ncode >= Flow.Packed_ops.register_limit then raise Core_region.Unsupported;
          let id = !ncode in incr ncode; code := instruction :: !code;
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
        registers.(i) <- match instruction with
          | Input (source, width, component) -> input source width component
          | Uniform (n, component) -> emit (Uniform (uniform + n, component))
          | Binary (op, a, b) -> emit (Binary (op, at a, at b))
          | Unary (op, a) -> emit (Unary (op, at a))
          | Noise3 (a, b, c, seed, octaves) -> emit (Noise3 (at a, at b, at c, seed, octaves))
          | Select (a, b, c) -> emit (Select (at a, at b, at c))
          | instruction -> emit instruction) p.code;
      Array.map (Array.get registers) p.output in
    let inputs = Array.mapi (fun i child ->
      if can_fuse child then begin
        let p = Option.get child in
        let inputs = Array.mapi (fun i source -> append_source source p.widths.(i)) p.sources in
        let uniform = append_uniforms p.uniforms in
        stages := !stages @ p.stages;
        sites := p.sites @ !sites;
        append_code p (fun i width component -> emit (Input (inputs.(i), width, component))) uniform
      end else begin
        let source = append_source t.sources.(i) t.widths.(i) in
        Array.init t.widths.(i) (fun component -> emit (Input (source, t.widths.(i), component)))
      end) children in
    let uniform = append_uniforms t.uniforms in
    let output = append_code t (fun i _ component -> inputs.(i).(component)) uniform in
    {t with sources = Array.of_list (List.rev !sources); widths = Array.of_list (List.rev !widths);
      uniforms = Array.of_list (List.rev !uniforms); code = Array.of_list (List.rev !code);
      output; iteration = Zip; stages = !stages; sites = !sites}
  with Core_region.Unsupported -> t
