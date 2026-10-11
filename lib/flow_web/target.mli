(** The web target for placement: what WebGPU can run, as diagnostics with spans.

    Limits are the WebGPU specification's defaults, which every adapter guarantees
    (https://www.w3.org/TR/webgpu/ section 3.6.2 "Limits", table of supported limits):
    [maxStorageBuffersPerShaderStage] is 8 and [maxComputeWorkgroupsPerDimension] is 65,535. *)

val max_storage_buffers : int
(** 8. Inputs, outputs, the status word and a noise table all count; the uniform block does not. *)

val max_elements : int
(** 64 * 65,535 = 4,194,240: dispatch is one-dimensional with [@workgroup_size(64)]. *)

val region : Flow_ir.Packed.t -> count:int option -> Flow.Diagnostic.t list
(** Why the region cannot run as a web kernel, each with the region's span: [E_GPU_FORM] (the printer's
    own refusal), [E_WEB_BUFFERS] (more than {!max_storage_buffers} storage buffers in one kernel),
    [E_WEB_ELEMENTS] (more than {!max_elements} elements in one dispatch; checked when [count] is known).
    Empty when the region is legal. *)

val readback : Flow_ir.t -> Flow.Diagnostic.t list
(** [E_WEB_READBACK] for every in-frame readback of a placed graph: a node placed on [Gpu_readback], or an
    [(exact x)] read whose producer is placed on the GPU, with the producing region's span. A graph placed
    with {!web} has none. *)

val web : Flow_ir.target
(** Legal GPU regions: a static count of at least 1,024 (as native) and [region = []]; marks as native;
    [Gpu_readback] never; every other tier legal. [cost] is the native one. *)
