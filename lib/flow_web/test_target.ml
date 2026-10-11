(* P5.4: web legality as diagnostics with spans: one refusing case per rule, and the web target in place. *)
open Flow_ir
module Target = Flow_web.Target

let has code (ds : Flow.Diagnostic.t list) =
  List.exists (fun (d : Flow.Diagnostic.t) -> d.code = code && d.span <> None) ds

let () =
  (* A legal kernel. *)
  let small = Test_program.compile "(map (fn [x] (+ x t)) (array/range 1024))" in
  assert (Target.region small ~count:(Some 1024) = []);
  assert (Target.region small ~count:(Some Target.max_elements) = []);
  (* Rule 1: more than eight storage buffers (one input, eight outputs, the status word). *)
  let many =
    let region = Packed.to_region small in
    let o = region.Core.Region.outputs.(0) in
    match Packed.of_region {region with Core.Region.outputs = Array.make 8 o} with
    | Ok p -> p | Error _ -> failwith "outputs" in
  let ds = Target.region many ~count:None in
  assert (has "E_WEB_BUFFERS" ds);
  (* Rule 2: more elements than one dispatch of 64-wide workgroups can cover. *)
  let ds = Target.region small ~count:(Some (Target.max_elements + 1)) in
  assert (List.map (fun (d : Flow.Diagnostic.t) -> d.code) ds = ["E_WEB_ELEMENTS"] && has "E_WEB_ELEMENTS" ds);
  (* The printer's own refusal passes through. *)
  let sum = Test_program.compile "(sum [x (array/range 1024)] (+ x t))" in
  assert (has "E_GPU_FORM" (Target.region sum ~count:(Some 1024)));
  (* Rule 3: an (exact x) read over a GPU producer, as native placement makes it. *)
  let node ?(ty = Flow.Ty.Float) ?(count = Count.Static 1) ?(args = []) ?(precision = Exact) name kind =
    let id = [name], [] in
    {id; ty; count; rate = Static; precision; kind; args; scope = []; invariant = false; provenance = [id]; tier = Interp} in
  let region = node ~ty:(Flow.Ty.Array Flow.Ty.Vec3) ~count:(Count.Static 1024) "region"
    (Kernel {body = Packed_map small; elementwise = true; requires_exact = true}) in
  let exact = node "exact" ~args:[{name = "value"; node = 0}]
    (Kernel {body = Readback; elementwise = true; requires_exact = false}) in
  let sink = node "sop" ~args:[{name = "value"; node = 1}] (Sink Sop_input) in
  let graph = {nodes = [|region; exact; sink|]; roots = [|2|]; groups = [||]} in
  let approximable = Flow.Workspace.Paths.of_list [["region"]] in
  let gpu_cost _ ~count:_ = Some 0. in
  let place target = match place ~approx:approximable ~gpu_cost ~target graph with Ok g -> g | Error d -> failwith d.message in
  let native = place Flow_ir.native in
  assert (native.nodes.(0).tier = Gpu && native.nodes.(1).tier = Gpu_readback);
  assert (has "E_WEB_READBACK" (Target.readback native));
  (* The web target keeps the region on the CPU, so nothing comes back. *)
  let web = place Target.web in
  assert (web.nodes.(0).tier <> Gpu && web.nodes.(1).tier <> Gpu_readback && Target.readback web = []);
  (* A legal region large enough for the GPU is still legal on the web target. *)
  assert (Target.web.legal region Gpu && not (Target.web.legal region Gpu_readback));
  assert (not (Target.web.legal {region with count = Count.Static (Target.max_elements + 1)} Gpu));
  print_endline "Web target: buffer, element and readback rules refuse with spans"
