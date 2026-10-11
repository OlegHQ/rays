let max_storage_buffers = 8
let max_elements = 64 * 65535

let span_of packed =
  let term = (Flow_ir.Packed.to_region packed).Flow_ir.Core.Region.term in
  term.Flow.Workspace.form.span

let region packed ~count =
  let error code message = Flow.Diagnostic.error ~span:(span_of packed) ~code message in
  match Wgsl.kernel packed with
  | Error d -> [if d.span = None then {d with span = Some (span_of packed)} else d]
  | Ok kernel ->
      let buffers = List.length (List.filter (fun (b : Wgsl.binding) -> b.kind <> Wgsl.Uniform_buffer) kernel.interface) in
      (if buffers > max_storage_buffers then
         [error "E_WEB_BUFFERS" (Printf.sprintf "This kernel binds %d storage buffers; WebGPU guarantees %d per shader stage."
            buffers max_storage_buffers)] else [])
      @ (match count with
         | Some n when n > max_elements ->
             [error "E_WEB_ELEMENTS" (Printf.sprintf "This kernel runs %d elements in one dispatch; WebGPU guarantees %d."
                n max_elements)]
         | _ -> [])

let producer (ir : Flow_ir.t) (node : Flow_ir.node) =
  List.find_map (fun (e : Flow_ir.edge) -> match ir.nodes.(e.node).kind with
    | Flow_ir.Kernel {body = Packed_map p; _} -> Some (ir.nodes.(e.node), p)
    | _ -> None) node.args

let readback (ir : Flow_ir.t) =
  Array.to_list ir.nodes |> List.filter_map (fun (node : Flow_ir.node) ->
    match node.kind, producer ir node with
    | Flow_ir.Kernel {body = Readback; _}, Some (p, packed) when p.tier = Flow_ir.Gpu || node.tier = Gpu_readback ->
        Some (Flow.Diagnostic.error ~span:(span_of packed) ~code:"E_WEB_READBACK"
          "A web frame cannot read a GPU result back to the CPU.")
    | _ -> None)

let web : Flow_ir.target = {
  legal = (fun node tier -> match tier, node.kind, node.count with
    | Flow_ir.Gpu_readback, _, _ -> false
    | Gpu, Kernel {body = Packed_map packed; _}, Static count -> count >= 1024 && region packed ~count:(Some count) = []
    | Gpu, Marks _, _ -> true
    | Gpu, _, _ -> false
    | _ -> true);
  cost = Flow_ir.native.cost }
