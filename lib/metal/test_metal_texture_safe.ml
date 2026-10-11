open Metal
open Test_metal_support

let formats =
  Texture.
    [ A8_unorm; R8_unorm; R8_unorm_srgb; R8_snorm; R8_uint; R8_sint; R16_unorm; R16_snorm
    ; R16_uint; R16_sint; R16_float; Rg8_unorm; Rg8_unorm_srgb; Rg8_snorm; Rg8_uint; Rg8_sint
    ; B5g6r5_unorm; A1bgr5_unorm; Abgr4_unorm; Bgr5a1_unorm; R32_uint; R32_sint; R32_float
    ; Rg16_unorm; Rg16_snorm; Rg16_uint; Rg16_sint; Rg16_float; Rgba8_unorm; Rgba8_unorm_srgb
    ; Rgba8_snorm; Rgba8_uint; Rgba8_sint; Bgra8_unorm; Bgra8_unorm_srgb; Rgb10a2_unorm
    ; Rgb10a2_uint; Rg11b10_float; Rgb9e5_float; Bgr10a2_unorm; Bgr10_xr; Bgr10_xr_srgb
    ; Rg32_uint; Rg32_sint; Rg32_float; Rgba16_unorm; Rgba16_snorm; Rgba16_uint; Rgba16_sint
    ; Rgba16_float; Bgra10_xr; Bgra10_xr_srgb; Rgba32_uint; Rgba32_sint; Rgba32_float
    ; Bc1_rgba; Bc1_rgba_srgb; Bc2_rgba; Bc2_rgba_srgb; Bc3_rgba; Bc3_rgba_srgb; Bc4_r_unorm
    ; Bc4_r_snorm; Bc5_rg_unorm; Bc5_rg_snorm; Bc6h_rgb_float; Bc6h_rgb_ufloat; Bc7_rgba_unorm
    ; Bc7_rgba_unorm_srgb; Eac_r11_unorm; Eac_r11_snorm; Eac_rg11_unorm; Eac_rg11_snorm
    ; Eac_rgba8; Eac_rgba8_srgb; Etc2_rgb8; Etc2_rgb8_srgb; Etc2_rgb8a1; Etc2_rgb8a1_srgb
    ; Astc_4x4_srgb; Astc_5x4_srgb; Astc_5x5_srgb; Astc_6x5_srgb; Astc_6x6_srgb; Astc_8x5_srgb
    ; Astc_8x6_srgb; Astc_8x8_srgb; Astc_10x5_srgb; Astc_10x6_srgb; Astc_10x8_srgb
    ; Astc_10x10_srgb; Astc_12x10_srgb; Astc_12x12_srgb; Astc_4x4_ldr; Astc_5x4_ldr
    ; Astc_5x5_ldr; Astc_6x5_ldr; Astc_6x6_ldr; Astc_8x5_ldr; Astc_8x6_ldr; Astc_8x8_ldr
    ; Astc_10x5_ldr; Astc_10x6_ldr; Astc_10x8_ldr; Astc_10x10_ldr; Astc_12x10_ldr
    ; Astc_12x12_ldr; Astc_4x4_hdr; Astc_5x4_hdr; Astc_5x5_hdr; Astc_6x5_hdr; Astc_6x6_hdr
    ; Astc_8x5_hdr; Astc_8x6_hdr; Astc_8x8_hdr; Astc_10x5_hdr; Astc_10x6_hdr; Astc_10x8_hdr
    ; Astc_10x10_hdr; Astc_12x10_hdr; Astc_12x12_hdr; Gbgr422; Bgrg422; Depth16_unorm
    ; Depth32_float; Stencil8; Depth24_unorm_stencil8; Depth32_float_stencil8; X32_stencil8
    ; X24_stencil8
    ]

let bc_formats =
  Texture.
    [ Bc1_rgba; Bc1_rgba_srgb; Bc2_rgba; Bc2_rgba_srgb; Bc3_rgba; Bc3_rgba_srgb; Bc4_r_unorm
    ; Bc4_r_snorm; Bc5_rg_unorm; Bc5_rg_snorm; Bc6h_rgb_float; Bc6h_rgb_ufloat; Bc7_rgba_unorm
    ; Bc7_rgba_unorm_srgb
    ]

let eac_etc2_formats =
  Texture.
    [ Eac_r11_unorm; Eac_r11_snorm; Eac_rg11_unorm; Eac_rg11_snorm; Eac_rgba8; Eac_rgba8_srgb
    ; Etc2_rgb8; Etc2_rgb8_srgb; Etc2_rgb8a1; Etc2_rgb8a1_srgb
    ]

let astc_ldr_formats =
  Texture.
    [ Astc_4x4_srgb; Astc_5x4_srgb; Astc_5x5_srgb; Astc_6x5_srgb; Astc_6x6_srgb; Astc_8x5_srgb
    ; Astc_8x6_srgb; Astc_8x8_srgb; Astc_10x5_srgb; Astc_10x6_srgb; Astc_10x8_srgb
    ; Astc_10x10_srgb; Astc_12x10_srgb; Astc_12x12_srgb; Astc_4x4_ldr; Astc_5x4_ldr
    ; Astc_5x5_ldr; Astc_6x5_ldr; Astc_6x6_ldr; Astc_8x5_ldr; Astc_8x6_ldr; Astc_8x8_ldr
    ; Astc_10x5_ldr; Astc_10x6_ldr; Astc_10x8_ldr; Astc_10x10_ldr; Astc_12x10_ldr
    ; Astc_12x12_ldr
    ]

let astc_hdr_formats =
  Texture.
    [ Astc_4x4_hdr; Astc_5x4_hdr; Astc_5x5_hdr; Astc_6x5_hdr; Astc_6x6_hdr; Astc_8x5_hdr
    ; Astc_8x6_hdr; Astc_8x8_hdr; Astc_10x5_hdr; Astc_10x6_hdr; Astc_10x8_hdr; Astc_10x10_hdr
    ; Astc_12x10_hdr; Astc_12x12_hdr
    ]

let compressed_formats = bc_formats @ eac_etc2_formats @ astc_ldr_formats @ astc_hdr_formats

(* Block width, block height and bytes per block, written out here: the
   transfers below are accepted only when the binding agrees. *)
let compressed_layout format =
  let open Texture in
  match format with
  | Bc1_rgba | Bc1_rgba_srgb | Bc4_r_unorm | Bc4_r_snorm | Eac_r11_unorm | Eac_r11_snorm
  | Etc2_rgb8 | Etc2_rgb8_srgb | Etc2_rgb8a1 | Etc2_rgb8a1_srgb ->
      (4, 4, 8)
  | Bc2_rgba | Bc2_rgba_srgb | Bc3_rgba | Bc3_rgba_srgb | Bc5_rg_unorm | Bc5_rg_snorm
  | Bc6h_rgb_float | Bc6h_rgb_ufloat | Bc7_rgba_unorm | Bc7_rgba_unorm_srgb | Eac_rg11_unorm
  | Eac_rg11_snorm | Eac_rgba8 | Eac_rgba8_srgb ->
      (4, 4, 16)
  | Astc_4x4_srgb | Astc_4x4_ldr | Astc_4x4_hdr -> (4, 4, 16)
  | Astc_5x4_srgb | Astc_5x4_ldr | Astc_5x4_hdr -> (5, 4, 16)
  | Astc_5x5_srgb | Astc_5x5_ldr | Astc_5x5_hdr -> (5, 5, 16)
  | Astc_6x5_srgb | Astc_6x5_ldr | Astc_6x5_hdr -> (6, 5, 16)
  | Astc_6x6_srgb | Astc_6x6_ldr | Astc_6x6_hdr -> (6, 6, 16)
  | Astc_8x5_srgb | Astc_8x5_ldr | Astc_8x5_hdr -> (8, 5, 16)
  | Astc_8x6_srgb | Astc_8x6_ldr | Astc_8x6_hdr -> (8, 6, 16)
  | Astc_8x8_srgb | Astc_8x8_ldr | Astc_8x8_hdr -> (8, 8, 16)
  | Astc_10x5_srgb | Astc_10x5_ldr | Astc_10x5_hdr -> (10, 5, 16)
  | Astc_10x6_srgb | Astc_10x6_ldr | Astc_10x6_hdr -> (10, 6, 16)
  | Astc_10x8_srgb | Astc_10x8_ldr | Astc_10x8_hdr -> (10, 8, 16)
  | Astc_10x10_srgb | Astc_10x10_ldr | Astc_10x10_hdr -> (10, 10, 16)
  | Astc_12x10_srgb | Astc_12x10_ldr | Astc_12x10_hdr -> (12, 10, 16)
  | Astc_12x12_srgb | Astc_12x12_ldr | Astc_12x12_hdr -> (12, 12, 16)
  | _ -> fail "not a compressed format"

let read_shader_source =
  {|
#include <metal_stdlib>
using namespace metal;

kernel void texel_read(texture2d<uint, access::read> source [[texture(0)]],
                       device uint *result [[buffer(0)]]) {
  result[0] = source.read(uint2(0u, 0u)).x;
}

kernel void read_swizzle(texture2d<float, access::sample> source [[texture(0)]],
                         device uint4 *result [[buffer(0)]]) {
  constexpr sampler nearest_sampler(coord::pixel, filter::nearest);
  result[0] = uint4(round(source.sample(nearest_sampler, float2(0.5f)) * 255.0f));
}
|}

let read ?(mip_level = 0) texture ~region ~bytes_per_row ~bytes_per_image =
  Texture.read_bytes texture ~region ~mip_level ~slice:0 ~bytes_per_row ~bytes_per_image

(* The block layout of [format] as the transfer checks see it: a texture of
   two blocks by two reads with exactly two blocks a row and two rows, and
   with nothing less. *)
let expect_layout device format block_width block_height bytes_per_block =
  let width = 2 * block_width and height = 2 * block_height in
  match
    Texture.create ~device
      (Texture.descriptor_2d ~storage:Buffer.Shared ~usage:[ Texture.Shader_read ] ~format ~width
         ~height ())
  with
  | Error { kind = Native_error | Unsupported; _ } -> ()
  | Error error -> fail "%s" (Format.asprintf "%a" pp_error error)
  | Ok texture ->
      let region = full_region width height in
      let row = 2 * bytes_per_block in
      if Bytes.length (get (read texture ~region ~bytes_per_row:row ~bytes_per_image:(2 * row)))
         <> 2 * row
      then fail "Metal pixel-format block layout is wrong";
      reject Invalid_argument (read texture ~region ~bytes_per_row:(row - 1) ~bytes_per_image:(2 * row));
      reject Invalid_argument
        (read texture ~region ~bytes_per_row:(row - bytes_per_block)
           ~bytes_per_image:(2 * row));
      reject Invalid_argument (read texture ~region ~bytes_per_row:row ~bytes_per_image:((2 * row) - 1));
      get (Texture.destroy texture)

let test_format_matrix device queue =
  if List.length formats <> 130
     || List.length (List.sort_uniq compare formats) <> List.length formats
  then fail "Metal pixel-format inventory is incomplete or duplicated";
  if List.length compressed_formats <> 66 then
    fail "compressed Metal pixel-format test inventory is incomplete";
  let supports family = get (Device.supports_family device family) in
  let supports_metal4 = supports Device.Metal4 in
  let supports_eac_astc = supports Device.Apple2 || supports_metal4 in
  let supports_astc_hdr = supports Device.Apple6 || supports_metal4 in
  (* BC support has no query left; the first BC format decides, and every
     other one must agree with it. *)
  let small format =
    Texture.descriptor_2d ~storage:Buffer.Private ~usage:[ Texture.Shader_read ] ~format ~width:12
      ~height:12 ()
  in
  let supports_bc =
    match Texture.create ~device (small Texture.Bc1_rgba) with
    | Ok texture ->
        get (Texture.destroy texture);
        true
    | Error { kind = Unsupported; _ } -> false
    | Error error -> fail "%s" (Format.asprintf "%a" pp_error error)
  in
  let expects_compressed format =
    if List.mem format bc_formats then supports_bc
    else if List.mem format eac_etc2_formats then supports_eac_astc
    else if List.mem format astc_ldr_formats then supports_eac_astc
    else if List.mem format astc_hdr_formats then supports_astc_hdr
    else false
  in
  expect_layout device Texture.R8_sint 1 1 1;
  expect_layout device Texture.B5g6r5_unorm 1 1 2;
  expect_layout device Texture.Rgba32_uint 1 1 16;
  expect_layout device Texture.Gbgr422 2 1 4;
  if supports_bc then begin
    expect_layout device Texture.Bc1_rgba 4 4 8;
    expect_layout device Texture.Bc7_rgba_unorm 4 4 16
  end;
  if supports_eac_astc then expect_layout device Texture.Eac_r11_unorm 4 4 8;
  if supports_astc_hdr then expect_layout device Texture.Astc_10x6_hdr 10 6 16;
  without_handles "invalid special-format descriptors" (fun () ->
    reject Invalid_argument
      (Texture.create ~device (Texture.descriptor_2d ~format:Texture.Gbgr422 ~width:3 ~height:2 ()));
    reject Invalid_argument
      (Texture.create ~device
         { (Texture.descriptor_2d ~format:Texture.Bgrg422 ~width:4 ~height:4 ()) with
           mip_levels = 3
         });
    reject Invalid_argument
      (Texture.create ~device
         (Texture.descriptor_2d ~format:Texture.X32_stencil8 ~width:4 ~height:4 ()));
    reject Invalid_argument
      (Texture.create ~device
         (Texture.descriptor_2d ~format:Texture.X24_stencil8 ~width:4 ~height:4 ())));
  (* Depth24Unorm_Stencil8 is a desktop format: it is made or refused whole. *)
  without_handles "Depth24Unorm_Stencil8 probe" (fun () ->
    match
      Texture.create ~device
        (Texture.descriptor_2d ~format:Texture.Depth24_unorm_stencil8 ~width:4 ~height:4 ())
    with
    | Ok texture -> get (Texture.destroy texture)
    | Error { kind = Unsupported; _ } -> ()
    | Error error -> fail "%s" (Format.asprintf "%a" pp_error error));
  let supported_uncompressed = ref 0 and supported_compressed = ref 0 in
  List.iteri
    (fun index format ->
      if format <> Texture.X32_stencil8 && format <> Texture.X24_stencil8 then begin
        let compressed = List.mem format compressed_formats in
        let expected = expects_compressed format in
        let before = stats () in
        match Texture.create ~device (small format) with
        | Ok texture ->
            if compressed && not expected then
              fail "unsupported compressed format %d reached Metal" index;
            if compressed then incr supported_compressed else incr supported_uncompressed;
            if (Texture.descriptor texture).format <> format then
              fail "Metal changed pixel format at matrix index %d" index;
            get (Texture.destroy texture)
        | Error { kind = Unsupported; _ } when compressed && not expected ->
            if (stats ()).total_created <> before.total_created then
              fail "unsupported compressed format %d allocated a handle" index
        | Error error when compressed ->
            fail "compressed format %d contradicted its capability gate: %s" index
              (Format.asprintf "%a" pp_error error)
        | Error { kind = Native_error | Unsupported; _ } -> ()
        | Error error -> fail "%s" (Format.asprintf "%a" pp_error error)
      end)
    formats;
  if !supported_uncompressed < 48 then
    fail "device accepted only %d of 62 creatable uncompressed formats" !supported_uncompressed;
  let expected_compressed_count =
    (if supports_bc then List.length bc_formats else 0)
    + (if supports_eac_astc then List.length eac_etc2_formats + List.length astc_ldr_formats
       else 0)
    + if supports_astc_hdr then List.length astc_hdr_formats else 0
  in
  if !supported_compressed <> expected_compressed_count then
    fail "device accepted %d/%d capability-gated compressed formats" !supported_compressed
      expected_compressed_count;
  (* Encoded blocks go in through a blit and come back byte for byte, in a
     texture whose last block is partial in both directions. *)
  List.iteri
    (fun index format ->
      if expects_compressed format then begin
        let block_width, block_height, bytes_per_block = compressed_layout format in
        let width = (2 * block_width) - 1 and height = (2 * block_height) - 1 in
        let row_bytes = 2 * bytes_per_block in
        let image_bytes = 2 * row_bytes in
        let source =
          Bytes.init image_bytes (fun byte -> Char.chr (((index * 47) + (byte * 43)) land 0xff))
        in
        let texture =
          get
            (Texture.create ~device
               (Texture.descriptor_2d ~storage:Buffer.Shared ~usage:[ Texture.Shader_read ]
                  ~format ~width ~height ()))
        in
        let region = full_region width height in
        upload ~device ~queue texture ~region ~bytes_per_row:row_bytes source;
        if get (read texture ~region ~bytes_per_row:row_bytes ~bytes_per_image:image_bytes)
           <> source
        then fail "compressed format %d did not preserve its encoded blocks" index;
        get (Texture.destroy texture)
      end)
    compressed_formats;
  let compression_probe =
    if supports_bc then Some Texture.Bc1_rgba
    else if supports_eac_astc then Some Texture.Eac_rgba8
    else None
  in
  Option.iter
    (fun format ->
      let block_width, block_height, bytes_per_block = compressed_layout format in
      let width = (2 * block_width) - 1 and height = (2 * block_height) - 1 in
      let base =
        Texture.descriptor_2d ~storage:Buffer.Shared ~usage:[ Texture.Shader_read ] ~format ~width
          ~height ()
      in
      without_handles "invalid compressed descriptors" (fun () ->
        reject Invalid_argument
          (Texture.create ~device { base with kind = Texture.Texture_1d; height = 1 });
        reject Invalid_argument (Texture.create ~device { base with usage = [ Texture.Shader_write ] });
        reject Invalid_argument
          (Texture.create ~device { base with usage = [ Texture.Render_target ] }));
      let volume_supported =
        supports Device.Apple3 || supports Device.Mac2 || supports Device.Metal3
        || supports_metal4
      in
      let volume_descriptor =
        { base with
          kind = Texture.Texture_3d
        ; width = 8
        ; height = 8
        ; depth = 4
        ; storage = Buffer.Private
        }
      in
      if volume_supported then get (Texture.create ~device volume_descriptor) |> Texture.destroy |> get
      else
        without_handles "unsupported compressed volume" (fun () ->
          reject Unsupported (Texture.create ~device volume_descriptor));
      let texture = get (Texture.create ~device base) in
      let full = full_region width height in
      let row_bytes = 2 * bytes_per_block in
      let image_bytes = 2 * row_bytes in
      let compressed_bytes =
        Bytes.init image_bytes (fun index -> Char.chr ((index * 43) land 0xff))
      in
      (* A region that starts inside a block is refused on both paths. *)
      reject Invalid_argument
        (read texture
           ~region:{ full with x = 1; width = block_width }
           ~bytes_per_row:row_bytes ~bytes_per_image:image_bytes);
      upload ~device ~queue texture ~region:full ~bytes_per_row:row_bytes compressed_bytes;
      if get (read texture ~region:full ~bytes_per_row:row_bytes ~bytes_per_image:image_bytes)
         <> compressed_bytes
      then fail "compressed texture blocks did not round-trip exactly";
      get (Texture.destroy texture);
      let staging =
        get (Buffer.create ~device ~length:(Int64.of_int image_bytes) ~storage:Buffer.Shared ())
      in
      get (Buffer.write_bytes staging ~dst_offset:0L compressed_bytes);
      let destination = get (Texture.create ~device { base with storage = Buffer.Private }) in
      let commands = get (Command_buffer.create queue ()) in
      let blit = get (Blit_encoder.create commands) in
      let copy region =
        Blit_encoder.copy_buffer_to_texture blit ~source:staging ~source_offset:0L
          ~source_bytes_per_row:row_bytes ~source_bytes_per_image:image_bytes ~destination
          ~destination_slice:0 ~destination_level:0 ~destination_region:region
      in
      reject Invalid_argument (copy { full with y = 1; height = block_height });
      reject Invalid_argument (copy { full with x = 1; width = block_width });
      get (copy full);
      get (Blit_encoder.end_encoding blit);
      complete commands;
      get (Texture.destroy destination);
      get (Buffer.destroy staging))
    compression_probe;
  let transfer =
    get
      (Texture.create ~device
         (Texture.descriptor_2d ~storage:Buffer.Shared ~format:Texture.Rgba8_uint ~width:4
            ~height:2 ()))
  in
  let transfer_region = full_region 4 2 in
  let bytes = Bytes.init 32 (fun index -> Char.chr ((index * 29) land 0xff)) in
  upload ~device ~queue transfer ~region:transfer_region ~bytes_per_row:16 bytes;
  if get (read transfer ~region:transfer_region ~bytes_per_row:16 ~bytes_per_image:32) <> bytes
  then fail "integer pixel-format transfer did not round-trip exactly";
  get (Texture.destroy transfer);
  (match
     Texture.create ~device
       (Texture.descriptor_2d ~storage:Buffer.Shared ~format:Texture.Gbgr422 ~width:4 ~height:2 ())
   with
   | Error { kind = Native_error; _ } -> ()
   | Error error -> fail "%s" (Format.asprintf "%a" pp_error error)
   | Ok packed ->
       reject Invalid_argument
         (read packed
            ~region:{ x = 1; y = 0; z = 0; width = 2; height = 1; depth = 1 }
            ~bytes_per_row:4 ~bytes_per_image:4);
       let full = full_region 4 2 in
       let packed_bytes = Bytes.init 16 (fun index -> Char.chr ((index * 17) land 0xff)) in
       upload ~device ~queue packed ~region:full ~bytes_per_row:8 packed_bytes;
       if get (read packed ~region:full ~bytes_per_row:8 ~bytes_per_image:16) <> packed_bytes then
         fail "subsampled pixel-format transfer did not round-trip exactly";
       get (Texture.destroy packed));
  match
    Texture.create ~device
      (Texture.descriptor_2d ~storage:Buffer.Private
         ~usage:[ Texture.Render_target; Texture.Pixel_format_view ]
         ~format:Texture.Depth32_float_stencil8 ~width:4 ~height:4 ())
  with
  | Error { kind = Native_error; _ } -> ()
  | Error error -> fail "%s" (Format.asprintf "%a" pp_error error)
  | Ok depth_stencil ->
      if (Texture.descriptor depth_stencil).format <> Texture.Depth32_float_stencil8 then
        fail "Metal changed the combined depth/stencil format";
      get (Texture.destroy depth_stencil)

let test_swizzle_and_compression device queue =
  let base_swizzle : Texture.swizzle =
    { red = Texture.Red; green = Texture.One; blue = Texture.One; alpha = Texture.Green }
  in
  let swizzled ?(storage = Buffer.Shared) ?(usage = [ Texture.Shader_read ]) ~width ~height () =
    { (Texture.descriptor_2d ~storage ~usage ~format:Texture.Rgba8_unorm ~width ~height ()) with
      swizzle = base_swizzle
    }
  in
  let texture = get (Texture.create ~device (swizzled ~width:1 ~height:1 ())) in
  if (Texture.descriptor texture).swizzle <> base_swizzle then
    fail "base texture swizzle did not round-trip";
  upload ~device ~queue texture ~region:(full_region 1 1) ~bytes_per_row:4
    (Bytes.of_string "\010\020\030\040");
  let plain =
    get
      (Texture.create ~device
         (Texture.descriptor_2d ~storage:Buffer.Shared ~format:Texture.Rgba8_unorm ~width:1
            ~height:1 ()))
  in
  upload ~device ~queue plain ~region:(full_region 1 1) ~bytes_per_row:4
    (Bytes.of_string "\010\020\030\040");
  let output = get (Buffer.create ~device ~length:16L ~storage:Buffer.Shared ()) in
  let library = get (Library.compile_source ~device read_shader_source) in
  let function_ = get (Function.find ~library "read_swizzle") in
  let pipeline = get (Compute_pipeline.create function_) in
  let sample name source expected =
    let commands = get (Command_buffer.create queue ()) in
    let encoder = get (Compute_encoder.create commands) in
    get (Compute_encoder.set_pipeline encoder pipeline);
    get (Compute_encoder.set_texture encoder ~index:0 source);
    get (Compute_encoder.set_buffer encoder ~index:0 ~offset:0L output);
    get (Compute_encoder.dispatch_threads encoder ~threads:(1, 1, 1) ~threadgroup:(1, 1, 1));
    get (Compute_encoder.end_encoding encoder);
    complete commands;
    let bytes = get (Buffer.read_bytes output ~offset:0L ~length:16) in
    let actual = Array.init 4 (fun index -> Bytes.get_int32_le bytes (index * 4) |> Int32.to_int) in
    if actual <> expected then
      fail "%s texture swizzle: expected [%s], got [%s]" name
        (expected |> Array.to_list |> List.map string_of_int |> String.concat "; ")
        (actual |> Array.to_list |> List.map string_of_int |> String.concat "; ")
  in
  sample "identity" plain [| 10; 20; 30; 40 |];
  sample "base" texture [| 10; 255; 255; 20 |];
  get (Compute_pipeline.destroy pipeline);
  get (Function.destroy function_);
  get (Library.destroy library);
  get (Buffer.destroy output);
  get (Texture.destroy plain);
  get (Texture.destroy texture);
  without_handles "invalid writable swizzles" (fun () ->
    List.iter
      (fun usage ->
        reject Invalid_argument
          (Texture.create ~device (swizzled ~storage:Buffer.Private ~usage ~width:4 ~height:4 ())))
      [ [ Texture.Shader_write ]; [ Texture.Shader_atomic ] ]);
  let lossy_descriptor =
    { (Texture.descriptor_2d ~storage:Buffer.Private ~usage:[ Texture.Render_target ]
         ~format:Texture.Rgba8_unorm ~width:64 ~height:64 ())
      with
      compression = Texture.Lossy
    }
  in
  without_handles "invalid lossy texture descriptors" (fun () ->
    [ { lossy_descriptor with storage = Buffer.Shared }
    ; { lossy_descriptor with allow_gpu_optimized_contents = false }
    ; { lossy_descriptor with usage = [ Texture.Pixel_format_view ] }
    ; { lossy_descriptor with usage = [ Texture.Shader_write ] }
    ; { lossy_descriptor with usage = [ Texture.Shader_atomic ] }
    ; { lossy_descriptor with kind = Texture.Texture_1d; height = 1 }
    ; { lossy_descriptor with format = Texture.Rg11b10_float }
    ; { lossy_descriptor with format = Texture.Astc_4x4_ldr }
    ]
    |> List.iter (fun invalid -> reject Invalid_argument (Texture.create ~device invalid)));
  (* Lossy compression is an Apple8 feature: it is made there and refused,
     before any allocation, everywhere else. *)
  match Texture.create ~device lossy_descriptor with
  | Ok lossy ->
      if not (get (Device.supports_family device Device.Apple8)) then
        fail "lossy texture compression escaped its Apple8 hardware gate";
      if (Texture.descriptor lossy).compression <> Texture.Lossy then
        fail "lossy texture compression did not round-trip";
      get (Texture.destroy lossy)
  | Error { kind = Unsupported; _ } ->
      without_handles "unsupported lossy texture" (fun () ->
        reject Unsupported (Texture.create ~device lossy_descriptor))
  | Error error -> fail "%s" (Format.asprintf "%a" pp_error error)

let test_transfer_and_descriptors device queue =
  let texture_descriptor =
    { (Texture.descriptor_2d ~storage:Buffer.Shared
         ~usage:[ Texture.Shader_read; Texture.Pixel_format_view ]
         ~label:"Metal conformance texture" ~format:Texture.Rgba8_unorm ~width:4 ~height:4 ())
      with
      mip_levels = 3
    }
  in
  finalizer_releases "texture" ~count:1 (fun () ->
    ignore (get (Texture.create ~device texture_descriptor)));
  let texture = get (Texture.create ~device texture_descriptor) in
  if (Texture.descriptor texture).mip_levels <> 3 then fail "2D texture mip cardinality is wrong";
  if (Texture.descriptor texture).hazard_tracking <> Texture.Tracked then
    fail "direct texture resource properties are wrong";
  if (Texture.descriptor texture).label <> Some "Metal conformance texture" then
    fail "texture label did not round-trip";
  if not (Device.same (Texture.device texture) device) || Texture.destroyed texture then
    fail "texture identity is wrong";
  reject Parent_has_dependents (Device.destroy device);
  (* Rows of sixteen bytes carried at a pitch of twenty: the pad never reaches
     the texture and reads back as zero. *)
  let texture_bytes = Bytes.make 80 '\xee' in
  for row = 0 to 3 do
    for column_byte = 0 to 15 do
      Bytes.set_uint8 texture_bytes ((row * 20) + column_byte) ((row * 16) + column_byte)
    done
  done;
  let full = full_region 4 4 in
  upload ~device ~queue texture ~region:full ~bytes_per_row:20 texture_bytes;
  let texture_copy = get (read texture ~region:full ~bytes_per_row:20 ~bytes_per_image:80) in
  for row = 0 to 3 do
    for column_byte = 0 to 15 do
      let offset = (row * 20) + column_byte in
      if Bytes.get_uint8 texture_copy offset <> Bytes.get_uint8 texture_bytes offset then
        fail "texture byte transfer changed active pixel data"
    done;
    for padding = 16 to 19 do
      if Bytes.get_uint8 texture_copy ((row * 20) + padding) <> 0 then
        fail "texture read exposed uninitialized row padding"
    done
  done;
  let into = Bytes.make 64 '\xaa' in
  get
    (Texture.read_bytes_into texture ~region:full ~mip_level:0 ~slice:0 ~bytes_per_row:16
       ~bytes_per_image:64 ~destination:into);
  for row = 0 to 3 do
    if Bytes.sub into (row * 16) 16 <> Bytes.sub texture_bytes (row * 20) 16 then
      fail "texture read into caller storage changed pixel data"
  done;
  reject Invalid_argument
    (Texture.read_bytes_into texture ~region:full ~mip_level:0 ~slice:0 ~bytes_per_row:16
       ~bytes_per_image:64 ~destination:(Bytes.create 63));
  reject Invalid_argument (read texture ~region:full ~bytes_per_row:15 ~bytes_per_image:60);
  reject Invalid_argument (read texture ~region:full ~bytes_per_row:20 ~bytes_per_image:79);
  reject Invalid_argument (read texture ~region:full ~bytes_per_row:max_int ~bytes_per_image:max_int);
  reject Invalid_argument
    (read texture ~region:{ full with x = 3; width = 2 } ~bytes_per_row:8 ~bytes_per_image:32);
  reject Invalid_argument (read ~mip_level:3 texture ~region:full ~bytes_per_row:16 ~bytes_per_image:64);
  reject Invalid_argument
    (Texture.read_bytes texture ~region:full ~mip_level:0 ~slice:1 ~bytes_per_row:16
       ~bytes_per_image:64);
  let mip_region = full_region 2 2 in
  let mip_bytes = Bytes.init 16 (fun index -> Char.chr (index + 20)) in
  upload ~device ~queue ~level:1 texture ~region:mip_region ~bytes_per_row:8 mip_bytes;
  if get (read ~mip_level:1 texture ~region:mip_region ~bytes_per_row:8 ~bytes_per_image:16)
     <> mip_bytes
  then fail "texture mip transfer did not round-trip";
  if Bytes.sub (get (read texture ~region:full ~bytes_per_row:16 ~bytes_per_image:64)) 0 16
     <> Bytes.sub texture_bytes 0 16
  then fail "a mip upload overwrote the base level";
  let private_texture =
    get
      (Texture.create ~device
         (Texture.descriptor_2d ~storage:Buffer.Private ~usage:[ Texture.Render_target ]
            ~format:Texture.Bgra8_unorm ~width:4 ~height:4 ()))
  in
  reject Unsupported (read private_texture ~region:full ~bytes_per_row:16 ~bytes_per_image:64);
  get (Texture.destroy private_texture);
  without_handles "invalid texture descriptors" (fun () ->
    [ { texture_descriptor with width = 0 }
    ; { texture_descriptor with mip_levels = 9 }
    ; { texture_descriptor with kind = Texture.Texture_1d; height = 2; mip_levels = 1 }
    ; { texture_descriptor with sample_count = 2; mip_levels = 1 }
    ; { texture_descriptor with usage = [ Texture.Shader_read; Texture.Shader_read ] }
    ; { texture_descriptor with label = Some "invalid\000label" }
    ; { texture_descriptor with kind = Texture.Texture_buffer; height = 1; mip_levels = 1 }
    ; { texture_descriptor with kind = Texture.Texture_2d_array; mip_levels = 1 }
    ; { texture_descriptor with kind = Texture.Texture_cube; height = 2; mip_levels = 1 }
    ; { texture_descriptor with kind = Texture.Texture_3d; array_length = 2; mip_levels = 1 }
    ]
    |> List.iter (fun invalid -> reject Invalid_argument (Texture.create ~device invalid)));
  without_handles "texture label Metal refuses" (fun () ->
    reject Native_error (Texture.create ~device { texture_descriptor with label = Some "\255" }));
  if get (Device.supports_texture_sample_count device 2) then begin
    let multisample_texture =
      get
        (Texture.create ~device
           { texture_descriptor with
             kind = Texture.Texture_2d_multisample
           ; mip_levels = 1
           ; sample_count = 2
           ; storage = Buffer.Private
           ; usage = [ Texture.Render_target ]
           ; label = None
           })
    in
    reject Unsupported (read multisample_texture ~region:full ~bytes_per_row:16 ~bytes_per_image:64);
    get (Texture.destroy multisample_texture)
  end;
  let cube =
    get
      (Texture.create ~device
         { (Texture.descriptor_2d ~storage:Buffer.Shared ~format:Texture.Rgba8_unorm ~width:4
              ~height:4 ())
           with
           kind = Texture.Texture_cube
         })
  in
  (* A cube has six slices and no seventh. *)
  ignore
    (get
       (Texture.read_bytes cube ~region:full ~mip_level:0 ~slice:5 ~bytes_per_row:16
          ~bytes_per_image:64));
  reject Invalid_argument
    (Texture.read_bytes cube ~region:full ~mip_level:0 ~slice:6 ~bytes_per_row:16
       ~bytes_per_image:64);
  get (Texture.destroy cube);
  get (Texture.destroy texture);
  get (Texture.destroy texture);
  if not (Texture.destroyed texture) then fail "destroyed texture remained live";
  reject Destroyed (read texture ~region:full ~bytes_per_row:16 ~bytes_per_image:64)

(* The blit from a buffer: what it refuses, what it holds while encoded, and
   that a kernel then reads the copied texel. *)
let test_blit device queue =
  let texture =
    get
      (Texture.create ~device
         (Texture.descriptor_2d ~storage:Buffer.Private
            ~usage:[ Texture.Shader_read; Texture.Shader_write ]
            ~format:Texture.R8_uint ~width:4 ~height:4 ()))
  in
  let volume =
    get
      (Texture.create ~device
         { (Texture.descriptor_2d ~storage:Buffer.Private ~format:Texture.R8_uint ~width:1
              ~height:1 ())
           with
           kind = Texture.Texture_3d
         ; depth = 2
         })
  in
  let staging_bytes = Bytes.make 16 '\000' in
  Bytes.set staging_bytes 0 (Char.chr 37);
  let staging = get (Buffer.create ~device ~length:16L ~storage:Buffer.Shared ()) in
  get (Buffer.write_bytes staging ~dst_offset:0L staging_bytes);
  let region = full_region 4 4 in
  let commands = get (Command_buffer.create queue ()) in
  let blit = get (Blit_encoder.create commands) in
  reject Invalid_state (Blit_encoder.create commands);
  reject Invalid_state (Command_buffer.commit commands);
  let copy ?(source_offset = 0L) ?(bytes_per_row = 4) ?(bytes_per_image = 16)
      ?(destination = texture) ?(slice = 0) ?(level = 0) region =
    Blit_encoder.copy_buffer_to_texture blit ~source:staging ~source_offset
      ~source_bytes_per_row:bytes_per_row ~source_bytes_per_image:bytes_per_image ~destination
      ~destination_slice:slice ~destination_level:level ~destination_region:region
  in
  without_handles "refused blits" (fun () ->
    reject Invalid_argument (copy ~source_offset:(-1L) region);
    reject Invalid_argument
      (copy ~bytes_per_row:1 ~bytes_per_image:max_int ~destination:volume (full_region ~depth:2 1 1));
    reject Invalid_argument (copy ~bytes_per_row:3 region);
    reject Invalid_argument (copy ~bytes_per_image:15 region);
    reject Invalid_argument (copy ~source_offset:1L region);
    reject Invalid_argument (copy ~level:1 region);
    reject Invalid_argument (copy ~slice:1 region);
    reject Invalid_argument (copy { region with x = 1 });
    reject Invalid_argument (copy { region with width = 0 }));
  get (copy region);
  reject Parent_has_dependents (Buffer.destroy staging);
  reject Parent_has_dependents (Texture.destroy texture);
  get (Blit_encoder.end_encoding blit);
  reject Destroyed (copy region);
  reject Destroyed (Blit_encoder.end_encoding blit);
  complete commands;
  get (Buffer.destroy staging);
  let library = get (Library.compile_source ~device read_shader_source) in
  let read_function = get (Function.find ~library "texel_read") in
  let read_pipeline = get (Compute_pipeline.create read_function) in
  let output = get (Buffer.create ~device ~length:4L ~storage:Buffer.Shared ()) in
  let commands = get (Command_buffer.create queue ()) in
  let encoder = get (Compute_encoder.create commands) in
  get (Compute_encoder.set_pipeline encoder read_pipeline);
  reject Invalid_argument (Compute_encoder.set_texture encoder ~index:(-1) texture);
  reject Invalid_argument (Compute_encoder.set_texture encoder ~index:31 texture);
  get (Compute_encoder.set_texture encoder ~index:0 texture);
  get (Compute_encoder.set_buffer encoder ~index:0 ~offset:0L output);
  get (Compute_encoder.dispatch_threads encoder ~threads:(1, 1, 1) ~threadgroup:(1, 1, 1));
  get (Compute_encoder.end_encoding encoder);
  complete commands;
  let value = Bytes.get_int32_le (get (Buffer.read_bytes output ~offset:0L ~length:4)) 0 in
  if value <> 37l then fail "blitted texel read back as %ld, expected 37" value;
  get (Buffer.destroy output);
  get (Compute_pipeline.destroy read_pipeline);
  get (Function.destroy read_function);
  get (Library.destroy library);
  get (Texture.destroy volume);
  get (Texture.destroy texture)

let run () =
  match Device.system_default () with
  | Error _ -> print_endline "Metal texture safe: skipped (no device)"
  | Ok device ->
      let queue = get (Command_queue.create device) in
      test_format_matrix device queue;
      test_swizzle_and_compression device queue;
      test_transfer_and_descriptors device queue;
      test_blit device queue;
      get (Command_queue.destroy queue);
      get (Device.destroy device);
      ignore (settle_finalizers ~expected_live:0);
      print_endline
        "Metal texture safe: format matrix, compressed blocks, swizzle, lossy gate, transfers and blit passed"
