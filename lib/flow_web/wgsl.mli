(** WGSL compute kernels for packed regions: the web counterpart of
    [Flow_gpu.Emit], with the same refusals ([Packed.gpu_refusals]), binding
    numbering and uniform layout. Nothing here is compiled by a WebGPU
    implementation in the test suite; the first real compile is the browser
    run (plan P6.8). *)

type kind = Uniform_buffer | Storage_read | Storage_read_write
type binding = {group : int; binding : int; kind : kind}

type wgsl = private {
  source : string;
  entry : string;  (** Compute entry point, [kernel_<digest>], workgroup size 64. *)
  interface : binding list;
  (** Bindings in group 0, ascending. Input [i] is binding [i] (an input no
      reachable instruction reads has no binding), output [k] is binding
      [inputs + k], then the uniform block, the status word and, when the
      kernel uses noise, the permutation table. Inputs and the table are
      [Storage_read], outputs and the status word [Storage_read_write]. *)
  uniform_layout : (string * int * int) list;
  (** [(name, byte offset, width)] exactly as the Metal emitter lays them out:
      word 0 is the element count (u32), then [uniform:n] and [frame:slot:name]
      words hold f32 bit patterns. *)
  uniform_bytes : int;
  (** Metal's size rounded up to a multiple of 16: the block is an
      [array<vec4<u32>, n>] uniform buffer. *)
  table_seeds : int array;
  (** Noise seeds, ascending; seed [k]'s 512-entry [i32] permutation starts at
      table element [512*k]. *)
  output_widths : int array;
  input_widths : int array;
}

val kernel : ?image:bool -> Flow_ir.Packed.t -> (wgsl, Flow.Diagnostic.t) result
(** Elements are f32; dispatch [ceil(count/64)] workgroups in x. The status
    word becomes 1 when any computed value is not finite (exponent-bits test);
    the host zeroes it before dispatch and turns 1 into [E_KERNEL]. Dispatch is
    one-dimensional, so [count <= 64 * maxComputeWorkgroupsPerDimension].
    [image] replaces the sole vec2 source with pixel-center UV coordinates,
    using the [image:width] and [image:height] uniforms; output must be vec4.
    No UV storage buffer is allocated or uploaded. *)
