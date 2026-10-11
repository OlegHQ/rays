(* Lowers a checked packed form (map, reduce, numeric loop, array/sum) to a core
   region. It reads terms; everything after it reads the region only. *)
module E = Flow.Eval
module W = Flow.Workspace
module V = Flow.Value
module Ty = Flow.Ty
open Core.Region

type expression = { registers : int array; constant : E.value option }
exception Unsupported
exception Compile_refused of Flow.Diagnostic.t

let width_of ty = match Flow.Packed_ops.scalar_width ty with
  | Some width -> width | None -> raise Unsupported
let components = function
  | E.Vec2 (x,y) -> [|x;y|] | Vec3 (x,y,z) -> [|x;y;z|]
  | Vec4 (x,y,z,w) -> [|x;y;z;w|] | value -> [|V.num value|]

let captured_value bindings name fields =
  let value = match List.assoc_opt name bindings with Some v -> v | None -> raise Unsupported in
  List.fold_left (fun value field -> match value, field with
    | E.Record fs, field | Struct (_, _, fs), field ->
        (match List.assoc_opt field fs with Some v -> v | None -> raise Unsupported)
    | E.Vec3 (x, _, _), "x" | Vec3 (_, x, _), "y" | Vec3 (_, _, x), "z" -> E.Float x
    | E.Vec2 (x,_), "x" | Vec2 (_,x), "y" -> E.Float x
    | E.Vec4 (x,_,_,_), "x" | Vec4 (_,x,_,_), "y"
    | Vec4 (_,_,x,_), "z" | Vec4 (_,_,_,x), "w" -> E.Float x
    | _ -> raise Unsupported) value fields

let count_of residual (s : W.term) = match s.node with
  | W.Ref_binding (name, fields) ->
      (try match captured_value (E.Private.residual_view residual).bindings name fields with
       | E.Float_array _ | Vec2_array _ | Vec3_array _ | Vec4_array _ as v -> Some (V.array_length v) | _ -> None
       with Unsupported -> None)
  | Op {op = ("array/float" | "array/vec3" | "array/range"); args; _} ->
      (match List.assoc_opt "count" args with
       | Some {node = W.Lit (Param.Int_value n); _} when n >= 0 -> Some n | _ -> None)
  | _ -> None

let count_of_sources iteration counts =
  let combine a b = match iteration with Zip -> min a b | Product ->
    if b <> 0 && a > max_int / b then raise Unsupported else a * b in
  if counts = [||] || (iteration = Product && Array.exists ((=) (Some 0)) counts) then Some 0
  else if Array.for_all Option.is_some counts then
    Some (Array.fold_left (fun n c -> combine n (Option.get c))
      (if iteration = Zip then max_int else 1) counts) else None

let rec pattern_names = function
  | W.Name name -> [name] | W.Keys names -> names | W.Seq ps -> List.concat_map pattern_names ps
let rec reads_names names (term : W.term) =
  let any = List.exists (reads_names names) and fields fs = List.map snd fs in
  match term.node with
  | W.Ref_binding (name, _) -> List.mem name names
  | Fn {params; body; _} ->
      let bound = List.concat_map (fun (p, _) -> pattern_names p) params in
      reads_names (List.filter (fun n -> not (List.mem n bound)) names) body
  | Let (bindings, body) ->
      let rec loop names = function
        | [] -> reads_names names body
        | (p, t) :: rest -> reads_names names t ||
            loop (List.filter (fun n -> not (List.mem n (pattern_names p))) names) rest in
      loop names bindings
  | Op {args; _} | Call {args; _} | Record args -> any (fields args)
  | Call_fn {args; _} -> any args
  | Graph_ref {inputs; _} -> any (fields inputs)
  | Vec ts | List_lit ts | Str ts | List_op (_, ts) | Hof (_, ts) -> any ts
  | Loop {accs; clauses; body; _} -> any (body :: fields (accs @ clauses))
  | State {init; step; _} -> any [init; step]
  | If (c, a, b) -> any [c; a; b]
  | Cond (arms, d) -> any (d :: List.concat_map (fun (a, b) -> [a; b]) arms)
  | Case (s, arms, d) -> any (s :: d :: fields arms)
  | Get (body, _) | Expanded {body; _} -> reads_names names body
  | Bypass call -> Option.fold ~none:false ~some:(reads_names names) (W.bypass_input call)
  | Assoc (r, args) -> any (r :: fields args)
  | Lit _ | Text _ | Nil | Time | Fn_ref _ -> false

let lower ?(fusion = true) ?(dynamic = false)
    ?(count_source = fun _ _ -> None) residual (term : W.term) =
  let view = E.Private.residual_view residual in
  let refuse ?(at = term) code message =
    raise (Compile_refused (Flow.Diagnostic.error ~span:at.form.span ~code message)) in
  try
    if view.previous then refuse "E_PACKED_STATE" "Previous-state values require reference evaluation.";
    if E.state_dependent (E.Residual residual) then
      refuse "E_PACKED_STATE" "State-dependent kernels require reference evaluation.";
    let function_body ?reduction (f : W.term) = match f.node with
      | W.Fn {capture = Some _; _} ->
          (match E.Private.eval_term residual f ~live:(Frame_input.at_time 0.) with
           | Ok (E.Fn fn) -> (match E.Private.function_body fn with
               | Some (params, body) -> params, body, E.Private.function_bindings fn
               | None -> refuse ~at:f "E_PACKED_FUNCTION" "Captured function has no instantiated packed body.")
           | Error d -> raise (Compile_refused d)
           | Ok _ -> refuse ~at:f "E_PACKED_FUNCTION" "Captured callable did not resolve to a function.")
      | W.Fn {params; body; _} -> params, body, view.bindings
      | W.Ref_binding (name, []) ->
          (match List.assoc_opt name view.bindings with
           | Some (E.Fn fn) -> (match E.Private.function_body fn with
               | Some (params, body) -> params, body, E.Private.function_bindings fn
               | None -> refuse ~at:f "E_PACKED_FUNCTION" ("Function " ^ name ^ " has no instantiated packed body."))
           | _ -> refuse ~at:f "E_PACKED_FUNCTION" ("Function binding " ^ name ^ " is unavailable."))
      | W.Fn_ref "+" when Option.is_some reduction ->
          (match Flow.Op.find ~extra:(E.Private.residual_ops residual) "+" Flow.Context.value with
           | Some op when Flow.Op.packed_kind op = Some (Flow.Op.Binary Add) ->
               let seed, source = Option.get reduction in
               let item_ty = match source.W.ty with Ty.Array ty -> ty | _ ->
                 refuse ~at:source "E_PACKED_TYPE" "Packed reduce requires a numeric array." in
               let arg name ty = {f with path=None;ty;node=W.Ref_binding(name,[])} in
               let body = {f with ty=term.ty;node=W.Op {op=op.name;
                 args=["a",arg "@accumulator" seed.W.ty;"b",arg "@item" item_ty];skip=[]}} in
               [W.Name "@accumulator",None;W.Name "@item",None],body,view.bindings
           | _ -> refuse ~at:f "E_PACKED_FUNCTION" "Packed named reduce requires canonical addition.")
      | W.Fn_ref name -> refuse ~at:f "E_PACKED_FUNCTION" ("Function value " ^ name ^ " has no instantiated packed body.")
      | _ -> refuse ~at:f "E_PACKED_FUNCTION" "Packed kernels require a function with an instantiated body." in
    let params, accumulator, body, sources, bindings, iteration, result, skip = match term.node with
      | W.Hof (`Map, f :: sources) ->
          let params, body, bindings = function_body f in
          params, None, body, sources, bindings, Zip, Collect, []
      | W.Hof (`Reduce, [f; seed; source]) ->
          let params, body, bindings = function_body ~reduction:(seed,source) f in
          (match params with
           | acc :: params -> params, Some acc, body, [source], bindings, Zip, Accumulate (seed, false), []
           | _ -> refuse "E_PACKED_FORM" "Packed reduce requires an accumulator parameter.")
      | W.Loop {kind; accs; clauses; body; skip; _} ->
          let accumulator, result = match kind, accs with
            | `For, [] -> None, Collect | `Sum, [] -> None, Sum false
            | (`Fold | `Scan), [p, seed] -> Some (p, None), Accumulate (seed, kind = `Scan)
            | _ -> refuse "E_PACKED_FORM" "Packed fold/scan requires exactly one accumulator." in
          List.map (fun (p, _) -> p, None) clauses, accumulator, body,
            List.map snd clauses, view.bindings, Product, result, skip
      | W.Op {op = "array/sum"; args = [_, source]; _} ->
          let ty = match source.ty with Ty.Array ty -> ty | _ ->
            refuse ~at:source "E_PACKED_TYPE" ("array/sum source is " ^ Ty.to_string source.ty ^ ", not an array.") in
          let body = {source with ty; node = W.Ref_binding ("@item", [])} in
          [W.Name "@item", None], None, body, [source], view.bindings, Zip, Sum true, []
      | _ -> refuse "E_PACKED_FORM" "Packed kernels require map, reduce, a numeric loop or array/sum." in
    let sources = Array.of_list sources in
    let binding_fn = match term.node with
      | W.Hof (_, {node = W.Ref_binding (name, []); _} :: _) -> Some name | _ -> None in
    let names = List.filter_map (function W.Name name, _ -> Some name | _ -> None)
      (params @ Option.to_list accumulator) in
    (* ponytail: correlated clauses stay interpreted; lower their changing source counts before tiling them. *)
    if iteration = Product && Array.exists (reads_names names) sources then
      refuse "E_PACKED_FORM" "Correlated product sources require reference evaluation.";
    let widths = Array.map (fun (s : W.term) -> match Flow.Packed_ops.array_width s.ty with
      | Some width -> width
      | None -> refuse ~at:s "E_PACKED_TYPE" ("Packed source must be a float/vector array, got " ^ Ty.to_string s.ty ^ ".")) sources in
    if Array.length sources <> List.length params then
      refuse "E_PACKED_FORM" (Printf.sprintf "Packed kernel has %d sources but %d parameters."
        (Array.length sources) (List.length params));
    let code = ref [] and size = ref 0 and uniforms = ref [] and nuniforms = ref 0 and uniform_names = ref [] in
    let emit instruction =
      (* ponytail: cap scratch at 512 KiB per block; measure larger bodies before raising it. *)
      if !size >= Flow.Packed_ops.register_limit then
        refuse "E_PACKED_LIMIT" (Printf.sprintf "Packed kernel exceeds %d registers." Flow.Packed_ops.register_limit);
      let id = !size in incr size; code := instruction :: !code;
      id in
    let literal ?(at = term) v =
      let data = match v with
        | E.Int _ | Float _ | Bool _ | Vec2 _ | Vec3 _ | Vec4 _ -> components v
        | _ -> refuse ~at "E_PACKED_TYPE" ("Packed constant has unsupported type " ^ Ty.to_string (V.ty_of v) ^ ".") in
      {registers = Array.map (fun f -> emit (Const f)) data; constant = Some v} in
    let input i width = {registers = Array.init width (fun j -> emit (Input (i, width, j))); constant = None} in
    let uniform at name v = match v with
      | E.Residual _ | E.Int _ | Float _ | Bool _ | Vec2 _ | Vec3 _ | Vec4 _ when dynamic || E.is_live v ->
          let ty = match v with E.Residual r -> (E.Private.residual_view r).term.ty | v -> V.ty_of v in
          let width = try width_of ty with Unsupported ->
            refuse ~at "E_PACKED_CAPTURE" ("Capture " ^ String.concat "." (fst name :: snd name)
              ^ " has unsupported type " ^ Ty.to_string ty ^ ".") in
          let i = !nuniforms in incr nuniforms; uniforms := v :: !uniforms;
          uniform_names := name :: !uniform_names;
          {registers = Array.init width (fun j -> emit (Uniform (i, j))); constant = None}
      | E.Int _ | Float _ | Bool _ | Vec2 _ | Vec3 _ | Vec4 _ -> literal ~at v
      | _ -> refuse ~at "E_PACKED_CAPTURE" ("Capture " ^ String.concat "." (fst name :: snd name)
          ^ " has unsupported type " ^ Ty.to_string (V.ty_of v) ^ ".") in
    let env = List.mapi (fun i (pattern, annotation) ->
      match pattern with
      | W.Name name when annotation = None || annotation = Some
          (match widths.(i) with 2 -> Ty.Vec2 | 3 -> Ty.Vec3 | 4 -> Ty.Vec4 | _ -> Ty.Float) ->
          name, input i widths.(i)
      | W.Name name -> refuse "E_PACKED_TYPE" (Printf.sprintf
          "Packed parameter %s annotation %s does not match its %d-component source."
          name (Option.fold ~none:"none" ~some:Ty.to_string annotation) widths.(i))
      | _ -> refuse "E_PACKED_FORM" "Packed parameters require name patterns.") params in
    let env = match accumulator, result with
      | Some (W.Name name, annotation), Accumulate (seed, _) ->
          if not (List.mem seed.ty [Ty.Float;Ty.Int;Ty.Vec2;Ty.Vec3;Ty.Vec4]) then
            refuse ~at:seed "E_PACKED_TYPE" ("Packed accumulator " ^ name ^ " has unsupported seed type " ^ Ty.to_string seed.ty ^ ".");
          let width = width_of seed.ty in
          if annotation <> None && annotation <> Some seed.ty
              && not (seed.ty = Ty.Int && annotation = Some Ty.Float) then
            refuse ~at:seed "E_PACKED_TYPE" (Printf.sprintf
              "Packed accumulator %s annotation %s does not match seed type %s."
              name (Option.fold ~none:"none" ~some:Ty.to_string annotation) (Ty.to_string seed.ty));
          (name, {registers = Array.init width (fun i -> emit (Accumulator i)); constant = None}) :: env
      | None, _ -> env | _ -> refuse "E_PACKED_FORM" "Packed accumulator requires a name pattern." in
    let captures = Hashtbl.create 16 in
    let captured at name fields = match Hashtbl.find_opt captures (name, fields) with
      | Some e -> e
      | None ->
          let value = try captured_value bindings name fields with Unsupported ->
            refuse ~at "E_PACKED_CAPTURE" ("Captured binding or field " ^ String.concat "." (name :: fields) ^ " is unavailable.") in
          let e = uniform at (name, fields) value in
          Hashtbl.add captures (name, fields) e; e in
    let field at e = function
      | "x" when Array.length e.registers >= 2 -> {registers = [|e.registers.(0)|]; constant = None}
      | "y" when Array.length e.registers >= 2 -> {registers = [|e.registers.(1)|]; constant = None}
      | "z" when Array.length e.registers >= 3 -> {registers = [|e.registers.(2)|]; constant = None}
      | "w" when Array.length e.registers = 4 -> {registers = [|e.registers.(3)|]; constant = None}
      | name -> refuse ~at "E_PACKED_TYPE" (Printf.sprintf "Component %s is unavailable on a %d-component packed value."
          name (Array.length e.registers)) in
    let component e i = e.registers.(if Array.length e.registers = 1 then 0 else i) in
    let rec expression env (t : W.term) =
      try match t.node with
      | W.Lit (Param.Int_value n) -> literal ~at:t (E.Int n)
      | Lit (Param.Float_value f) -> literal ~at:t (E.Float f)
      | Lit (Param.Bool_value b) -> literal ~at:t (E.Bool b)
      | Ref_binding (name, fields) ->
          (match List.assoc_opt name env with
           | Some e -> List.fold_left (field t) e fields
           | None ->
               (* A record may contain a deferred vector. Bind that vector as a
                  uniform before projecting its component. *)
               let direct = try ignore (captured_value bindings name fields); true
                 with Unsupported -> false in
               if direct then captured t name fields else
               match List.rev fields with
               | component :: prefix -> field t (captured t name (List.rev prefix)) component
               | [] -> refuse ~at:t "E_PACKED_CAPTURE" ("Captured binding " ^ name ^ " is unavailable."))
      | Time -> {registers = [|emit (Frame "t")|]; constant = None}
      | Vec ts when List.mem (List.length ts) [2;3;4] ->
          let components = List.map (expression env) ts in
          if not (List.for_all (fun e -> Array.length e.registers = 1) components) then
            refuse ~at:t "E_PACKED_TYPE" "Packed vector components must be scalar values.";
          {registers = Array.of_list (List.map (fun e -> e.registers.(0)) components); constant = None}
      | Get (value, f) -> field t (expression env value) f
      | Cond (arms, default) ->
          expression env (List.fold_right (fun (condition, yes) no ->
            {t with node = If (condition, yes, no)}) arms default)
      | Case (scrutinee, arms, default) ->
          let boolean (value : W.term) = {value with ty = Ty.Bool;
            node = Op {op = "not"; args = ["x", {value with ty = Ty.Bool;
              node = Op {op = "not"; args = ["x", value]; skip = []}}]; skip = []}} in
          expression env (List.fold_right (fun ((literal : Flow.Syntax.t), yes) no ->
            let value, ty = match literal.node with
              | Num s -> (Param.Float_value (float_of_string s), Ty.Float)
              | Sym ("true" | "false" as s) -> Param.Bool_value (s = "true"), Ty.Bool
              | _ -> refuse ~at:t "E_PACKED_FORM" "Packed case arms require numeric or boolean literals." in
            let right : W.term = {path = None; ty; node = Lit value; form = literal} in
            let left, right = if scrutinee.ty = Ty.Bool || ty = Ty.Bool then
              boolean scrutinee, boolean right else scrutinee, right in
            let condition = {t with ty = Ty.Bool;
              node = Op {op = "="; args = ["a", left; "b", right]; skip = []}} in
            {t with node = If (condition, yes, no)}) arms default)
      | If (condition, yes, no) ->
          (* ponytail: eager pure branches; nonfinite untaken arms rerun the reference.
             Add masked execution if such bodies appear in profiles. *)
          let condition = expression env condition in
          (match condition.constant with
           | Some v -> expression env (if V.truthy v then yes else no)
           | None ->
               let yes = expression env yes and no = expression env no in
               if Array.length condition.registers <> 1 then
                 refuse ~at:t "E_PACKED_TYPE" "Packed conditions require a scalar value.";
               let width = max (Array.length yes.registers) (Array.length no.registers) in
               {registers = Array.init width (fun i ->
                 emit (Select (condition.registers.(0), component yes i, component no i))); constant = None})
      | Op {op; args; _} ->
          let declaration, kind = match Flow.Op.find ~extra:(E.Private.residual_ops residual) op Flow.Context.value with
            | Some o -> (match Flow.Op.packed_kind o with
                | Some kind -> o, kind | None -> refuse ~at:t "E_PACKED_OPERATOR"
                    ("Operator " ^ op ^ " is not a canonical scalar declaration or validated packed intrinsic."))
            | _ -> refuse ~at:t "E_PACKED_OPERATOR" ("Operator " ^ op ^ " is unavailable.") in
          let expressions = List.map (fun (_, t) -> expression env t) args in
          if List.for_all (fun e -> Option.is_some e.constant) expressions && not declaration.live then
            literal ~at:t (declaration.body ~live:(Frame_input.at_time 0.)
              ~node:(fun name _ -> refuse ~at:t "E_PACKED_CONSTANT" ("Constant operator " ^ op ^ " attempted to create node " ^ name ^ "."))
              (List.map2 (fun (name, _) e -> name, Option.get e.constant) args expressions))
          else if declaration.live && args = [] && List.mem t.ty [Ty.Float; Ty.Int; Ty.Bool] then
            {registers = [|emit (Frame declaration.name)|]; constant = None}
          else begin
            let width = List.fold_left (fun n e -> max n (Array.length e.registers)) 1 expressions in
            if t.ty = Ty.Int then refuse ~at:t "E_PACKED_OPERATOR" ("Dynamic integer operation " ^ op ^ " requires reference evaluation.");
            let registers = match kind, expressions with
              | Flow.Op.Noise3, a::rest when Array.length a.registers=3 ->
                  let configuration=List.map2(fun (name,_) expression ->
                    name,match expression.constant with Some value->value|None->
                      refuse ~at:t "E_PACKED_CONSTANT" ("Noise configuration " ^ name ^ " must be constant."))
                    (List.tl args) rest in
                  let integer name default=Option.fold ~none:default ~some:V.int_of
                    (List.assoc_opt name configuration)in
                  let seed=integer "seed" 0 and octaves=integer "octaves" 1 in
                  if not (Flow.Packed_ops.supported_noise_octaves octaves) then
                    refuse ~at:t "E_PACKED_CONSTANT" (Printf.sprintf "Packed noise octaves must be 1 to 32, got %d." octaves);
                  [|emit (Noise3 (a.registers.(0), a.registers.(1), a.registers.(2), seed, octaves))|]
              | Flow.Op.Exact, [a] -> a.registers
              | Flow.Op.Length, [a] when Array.length a.registers = 3 ->
                  let square i = emit (Binary (Mul, a.registers.(i), a.registers.(i))) in
                  let xx = square 0 and yy = square 1 and zz = square 2 in
                  let xy = emit (Binary (Add, xx, yy)) in
                  let sum = emit (Binary (Add, xy, zz)) in
                  [|emit (Unary (Sqrt, sum))|]
              | Flow.Op.Binary op, [a; b] ->
                  Array.init width (fun i -> emit (Binary (op, component a i, component b i)))
              | Flow.Op.Unary op, [a] when width = 1 ->
                  [|emit (Unary (op, a.registers.(0)))|]
              | _ -> refuse ~at:t "E_PACKED_OPERATOR" (Printf.sprintf
                  "Dynamic operator %s has no packed instruction for %d arguments at width %d." op (List.length expressions) width) in
            {registers; constant = None}
          end
      | Let (bindings, result) ->
          let env = List.fold_left (fun env (p, t) -> match p with
            | W.Name n -> (n, expression env t) :: env
            | _ -> refuse ~at:t "E_PACKED_FORM" "Packed let bindings require name patterns.") env bindings in
          expression env result
      | Expanded {body; _} -> expression env body
      | Bypass call ->
          (match W.bypass_input call with
           | Some input when input.ty=t.ty
               || t.ty=Ty.Float && List.mem input.ty [Ty.Int;Bool] -> expression env input
           | Some input when List.mem t.ty [Ty.Vec2;Vec3;Vec4]
               && List.mem input.ty [Ty.Int;Float] ->
               let e=expression env input in
               {registers=Array.make (width_of t.ty) e.registers.(0);constant=None}
           | _ -> refuse ~at:t "E_PACKED_TYPE" "Bypass coercion requires reference evaluation.")
      | _ -> refuse ~at:t "E_PACKED_FORM" ("Unsupported packed body form " ^
          Option.value ~default:(Ty.to_string t.ty) (Flow.Syntax.head t.form) ^ ".")
      with V.Fail (code, message, span) ->
        raise (Compile_refused (Flow.Diagnostic.error ~span:(Option.value ~default:t.form.span span) ~code message)) in
    let output = (expression env body).registers in
    let result_ty = match term.ty with Ty.Array ty -> ty | ty -> ty in
    if not (List.mem result_ty [Ty.Float;Ty.Vec2;Ty.Vec3;Ty.Vec4]) then
      refuse "E_PACKED_TYPE" ("Packed result must be float or vector, got " ^ Ty.to_string result_ty ^ ".");
    let width = width_of result_ty in
    (match result with
     | Sum _ | Accumulate _ when not (List.mem body.ty [Ty.Float;Ty.Vec2;Ty.Vec3;Ty.Vec4]) ->
         refuse ~at:body "E_PACKED_TYPE" ("Packed reduction body has unsupported type " ^ Ty.to_string body.ty ^ ".")
     | _ -> ());
    (* array_init also broadcasts a scalar to the requested vector width. *)
    let output = if Array.length output = 1 && width > 1 then Array.make width output.(0) else output in
    if Array.length output <> width then refuse "E_PACKED_TYPE" (Printf.sprintf
      "Packed result has %d components but its type requires %d." (Array.length output) width);
    let counts = Array.map (count_of residual) sources in
    let count = try count_of_sources iteration counts with Unsupported ->
      refuse "E_PACKED_LIMIT" "Packed product source count exceeds the integer limit." in
    let rec paths sites (t : W.term) =
      let sites = match t.path with Some p -> (view.instance, p, view.iter) :: sites | None -> sites in
      let children = match t.node with
        | W.Vec ts -> ts | Get (t, _) | Expanded {body = t; _} -> [t]
        | Bypass call -> Option.to_list (W.bypass_input call)
        | If (a, b, c) -> [a;b;c] | Op {args; _} -> List.map snd args
        | Cond (arms, d) -> d :: List.concat_map (fun (a,b) -> [a;b]) arms
        | Case (s, arms, d) -> s :: d :: List.map snd arms
        | Let (bindings, result) -> result :: List.map snd bindings | _ -> [] in
      List.fold_left paths sites children in
    let sites = paths [view.instance, Option.value ~default:view.site term.path, view.iter] body in
    let sites = match term.node with
      | W.Hof (_, {node = Fn {zone; _}; _} :: _) -> (view.instance, zone, view.iter) :: sites
      | Hof (_, {node = Ref_binding (name, []); _} :: _) ->
          (match List.assoc_opt name view.bindings with Some (E.Fn f) ->
            (match E.Private.function_body f with Some (_, {path = Some p; _}) ->
              (view.instance, List.filteri (fun i _ -> i < List.length p - 1) p, view.iter) :: sites
            | _ -> sites) | _ -> sites)
      | _ -> sites in
    let skip = List.filter_map (fun tuple ->
      match List.rev tuple with
      | k :: prefix when List.rev prefix = view.iter -> Some k | _ -> None) skip
      |> List.sort_uniq Int.compare |> Array.of_list in
    let program = {residual; term; sources = Array.map (fun t -> residual, t) sources;
      widths; uniforms = Array.of_list (List.rev !uniforms);
      code = Array.of_list (List.rev !code);
      output; count; iteration; result; skip; stages = [residual, term]; fusion; dynamic; body; binding_fn;
      uniform_names = Array.of_list (List.rev !uniform_names); count_source;
      origin = None; sites} in
    Ok program
  with
  | Compile_refused d -> Error [d]
  | V.Fail (code, message, span) ->
      Error [Flow.Diagnostic.error ~span:(Option.value ~default:term.form.span span) ~code message]
  | Invalid_argument message -> Error [Flow.Diagnostic.error ~span:term.form.span ~code:"E_PACKED_LAYOUT"
      ("Packed layout is unsupported: " ^ message)]
  | Unsupported -> Error [Flow.Diagnostic.error ~span:term.form.span ~code:"E_PACKED_FORM"
      "Packed form requires reference evaluation."]
