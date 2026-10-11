(** The web export: a checked workspace's draw graph, lowered to a core program and printed as the
    files of a standalone browser application (plan P5.10). *)

type lowered = {
  program : Flow_ir.Core.program;
  span : Flow.Diagnostic.span;  (** the draw graph *)
  root : Flow.Eval.residual option;  (** the residual whose state the program reads *)
}

val lower : Editor_document.Workspace_doc.t -> (lowered, Flow.Diagnostic.t) result
(** Run the static stage with graph inputs at their defaults and lower the first draw graph. A draw graph
    that reaches a [sop] or [scene] graph, a host effect or an image is refused with the span of the
    reference ([E_WEB_GRAPH], [E_WEB_HOST], [E_WEB_IMAGE]). *)

type files = (string * string) list
(** Relative path and contents, in a fixed order. *)

val files : Editor_document.Workspace_doc.t -> lowered -> (files, Flow.Diagnostic.t) result
(** The export of a lowered draw graph:
    - [program.js]: {!Flow_web.Js.frame} (packed-array constants are views into [rt.data]) followed by
      [export const regions], one object per core region: [source] ({!Flow_web.Js.region}), [count], [kept],
      [inputs] (pairs [offset, length] of doubles in [data.bin]), [uniforms], [frame] (pairs of instruction
      slot and frame-fact name: [t], [frame/dt], [frame/index], [frame/width], [frame/height]), [length]
      (instructions), [width] (components per element) and [kernel] (its id in [kernels.json], or [null]).
    - [program.map]: {!Flow_web.Js.frame_map}.
    - [kernels.json] and [kernels.wgsl]: the WGSL kernels of the regions legal on the web target (a static
      count of at least 1,024 and {!Flow_web.Target.region} empty), in the table [gpu.js] loads. A kernel that
      the frame can use without reading its value is dispatched by the runtime and its region is not invoked on
      the CPU: a region whose every [Invoke] result is defined once and used only as the positions, radii, sizes,
      colours, [from] or [to] of rect, circle and line sets, whose sets' region attributes all qualify, has
      [kernel] and [gpu: {output}] in the region table, [rt.gpuArray(k)] in the frame, and an entry of
      [export const gpu = {id: {count, inputs, uniforms, frame}}], the kernel's inputs and captures. Attributes of
      one set with equal count and rate are merged by {!Flow_ir.Core_fuse.merge} into one kernel with an output
      each (id of the first member). Any other region is invoked on the CPU, since a frame that reads a value
      would need an in-frame readback, which is illegal on the web.
    - [data.bin]: little-endian doubles; offsets are multiples of 8.
    - [index.html] and [runtime/*.js].
    Refused: an image ([E_WEB_IMAGE]), a region that is not a collecting single-output one
    ([E_WEB_REGION]), or one whose inputs change from frame to frame ([E_WEB_CAPTURE]), each with a span. *)

val load : string -> string * (Editor_document.Workspace_doc.t, Flow.Diagnostic.t list) result
(** The text of a [.rays] file and its checked document (imports read beside it). *)
