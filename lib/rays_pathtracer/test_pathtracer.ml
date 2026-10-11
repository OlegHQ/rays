(* Smallest check that fails if the tracer breaks: a lit sphere over a floor
   must produce a non-flat image, and two accumulations from reset must be
   byte-identical (fixed seeds, fixed camera). *)
module P = Rays_pathtracer
let rgb = P.Linear_color.rgb

let get = function Ok v -> v | Error e -> failwith e
let pixels tracer = Bytes.copy (get (Rays.Image.Private.pixels (P.image tracer)))
let live_handles = let _, live = Ogpu.Impl.create_driver () in live

let run () =
  let initial_handles = live_handles () in
  let sphere = get (Result.map_error Rdk.Error.to_string
    (Rdk.Uv_sphere.run ~center:(Rays.Vec3.create 0. 1. 0.) ~segments:24 ~rings:12 ~radius:1. ())) in
  let floor = get (Result.map_error Rdk.Error.to_string
    (Rdk.Box_generator.box ~center:(Rays.Vec3.create 0. (-0.05) 0.) ~size:(Rays.Vec3.create 20. 0.1 20.) ())) in
  let scene =
    { P.objects =
        [ (sphere, P.material ~roughness:0.2 ~metallic:1. (rgb 0.9 0.7 0.4))
        ; (floor, P.material ~roughness:0.8 (rgb 0.6 0.6 0.6)) ]
    ; spheres = []; strands = []
    ; environment =
        { sky = rgb 0.5 0.6 0.8; ground = rgb 0.2 0.2 0.2
        ; panels = [ P.panel ~intensity:6. ~width:0.5 ~height:0.4 (Rays.Vec3.create 1. 2. 1.) ] }
    ; lights = [ P.rect_light ~intensity:20. ~size:(2., 2.) ~target:(Rays.Vec3.create 0. 0. 0.)
                   (Rays.Vec3.create (-2.) 5. 2.) ] } in
  match P.create ~spp:2 ~width:48 ~height:32 scene with
  | Error message when String.length message > 0 && Sys.getenv_opt "RAYS_REQUIRE_RAYTRACING" = None ->
      Printf.printf "pathtracer: skipped (%s)\n" message
  | Error message -> failwith message
  | Ok tracer ->
      let camera = Rays.Camera.perspective ~fov_y:0.9
        ~at:(Rays.Vec3.create 0. 2. 6.)
        ~target:(Rays.Vec3.create 0. 0.8 0.) () in
      let unsupported = Rays.Camera.orthographic ~height:4.
        ~at:(Rays.Camera.position camera)
        ~target:(Rays.Camera.target camera) () in
      (match P.render tracer unsupported with Error _ -> ()
       | Ok () -> failwith "orthographic path-tracer camera was accepted");
      assert (P.samples tracer = 0);
      let capture camera frames =
        (* Settle a camera change before resetting, so its preview cannot
           change the counted sample total in a deterministic comparison. *)
        for _ = 1 to 2 do get (P.render tracer camera); get (P.flush tracer) done;
        P.reset tracer;
        for _ = 1 to frames do get (P.render tracer camera); get (P.flush tracer) done;
        pixels tracer in
      let run () = capture camera 2 in
      let first = run () and second = run () in
      assert (first = second && Bytes.length first = 48 * 32 * 4);
      assert (P.samples tracer = 4);
      let distinct = Hashtbl.create 64 in
      for pixel = 0 to 48 * 32 - 1 do
        assert (Bytes.get first (pixel * 4 + 3) = '\255');
        Hashtbl.replace distinct (Bytes.get_int32_le first (pixel * 4)) ()
      done;
      assert (Hashtbl.length distinct > 8);
      let moved = Rays.Camera.with_position
        (Rays.Vec3.create 0.4 2. 6.) camera in
      get (P.render tracer moved); get (P.flush tracer);
      assert (P.samples tracer = 0);
      let varying_block = ref false in
      let preview = pixels tracer in
      for y = 0 to 15 do for x = 0 to 23 do
        let at dx dy = Bytes.get_int32_le preview (((2 * y + dy) * 48 + 2 * x + dx) * 4) in
        if at 0 0 <> at 1 0 || at 0 0 <> at 0 1 || at 0 0 <> at 1 1 then
          varying_block := true
      done done;
      assert !varying_block;
      P.reset tracer;
      get (P.render tracer camera); get (P.flush tracer);
      P.reset tracer;
      get (P.render tracer moved); get (P.flush tracer);
      get (P.render tracer moved); get (P.flush tracer);
      assert (P.samples tracer = 2);
      let matrix = Rays.Mat4.mul
        (Rays.Mat4.translation (Rays.Vec3.create 0.3 0. 0.))
        (Rays.Mat4.mul (Rays.Mat4.rotation_y 0.23)
          (Rays.Mat4.scaling (Rays.Vec3.create 1.3 0.8 1.1))) in
      let instanced = get (P.mesh_instanced ~prototype:(sphere, P.material (rgb 0.7 0.5 0.3)) [|matrix|]) in
      get (P.replace_mesh tracer instanced);
      get (P.render tracer camera); get (P.flush tracer);
      get (P.render tracer camera); get (P.flush tracer);
      let instanced_pixels = pixels tracer in
      let transformed = Rdk.Transform_ops.transform matrix sphere in
      get (P.replace_mesh tracer (get (P.mesh [transformed, P.material (rgb 0.7 0.5 0.3)])));
      get (P.render tracer camera); get (P.flush tracer);
      get (P.render tracer camera); get (P.flush tracer);
      let largest_difference = ref 0 in
      let transformed_pixels = pixels tracer in
      assert (Bytes.length instanced_pixels = Bytes.length transformed_pixels);
      Bytes.iteri (fun i value -> largest_difference := max !largest_difference
        (abs (Char.code value - Char.code (Bytes.get transformed_pixels i)))) instanced_pixels;
      assert (!largest_difference <= 2);
      get (P.queue_mesh tracer instanced);
      get (P.queue_mesh tracer (get (P.mesh [transformed, P.material (rgb 0.7 0.5 0.3)])));
      get (P.flush tracer);
      assert (P.samples tracer = 0);
      get (P.render tracer camera); get (P.flush tracer);
      assert (P.samples tracer = 0); (* an edit's first frame is a preview *)
      get (P.render tracer camera); get (P.flush tracer);
      let stable_handles = ref None in
      for index = 1 to 10 do
        let matrix = Rays.Mat4.mul
          (Rays.Mat4.translation (Rays.Vec3.create (float index *. 0.02) 0. 0.))
          (Rays.Mat4.scaling (Rays.Vec3.create 1.3 0.8 1.1)) in
        get (P.queue_mesh tracer
          (get (P.mesh_instanced ~prototype:(sphere, P.material (rgb 0.7 0.5 0.3)) [|matrix|])));
        get (P.flush tracer);
        if index = 1 then stable_handles := Some (live_handles ())
      done;
      assert (live_handles () <= Option.get !stable_handles);
      (* Depth of field: a lens blurs the image deterministically; a pinhole
         lens restores the exact pinhole frame. *)
      get (P.replace_mesh tracer (get (P.mesh [sphere, P.material ~roughness:0.2 ~metallic:1. (rgb 0.9 0.7 0.4); floor, P.material ~roughness:0.8 (rgb 0.6 0.6 0.6)])));
      let pinhole = run () in
      let lens = Rays.Camera.with_lens { Rays.Camera.aperture = 0.2;
        focus_distance = Some 2. } camera in
      let blur () = capture lens 16 in
      let blurred = blur () in
      assert (blurred <> pinhole && blur () = blurred);
      assert (run () = pinhole);
      P.destroy tracer;
      (* An instance structure only references its BLAS: without declaring
         it read each dispatch the device evicts it over time and a fresh
         frame gets darker. A large prototype instanced many times, rendered
         for a while, must light a fresh frame exactly as at the start. *)
      let big = get (Result.map_error Rdk.Error.to_string
        (Rdk.Uv_sphere.run ~center:Rays.Vec3.zero ~segments:96 ~rings:48 ~radius:0.4 ())) in
      let grid = Array.init 64 (fun i -> Rays.Mat4.translation
        (Rays.Vec3.create (float (i mod 8) -. 3.5) (float (i / 8) -. 3.5) 0.)) in
      let lattice = get (P.mesh_instanced ~prototype:(big, P.material ~roughness:0.6 (rgb 0.8 0.8 0.8)) grid) in
      let tracer = get (P.create ~spp:1 ~bounces:2 ~width:320 ~height:320
        { P.objects = [ (floor, P.material (rgb 0.5 0.5 0.5)) ]; spheres = []; strands = []
        ; environment = { sky = rgb 0.02 0.02 0.02; ground = rgb 0.02 0.02 0.02; panels = [] }
        ; lights = [ P.rect_light ~intensity:12. ~size:(8., 8.) ~target:Rays.Vec3.zero
                       (Rays.Vec3.create (-6.) 8. 8.) ] }) in
      get (P.replace_mesh tracer (get (P.scene_mesh [ Rays.Mat4.identity, lattice ])));
      let camera = Rays.Camera.perspective ~fov_y:0.7 ~at:(Rays.Vec3.create 0. 0. 12.)
        ~target:Rays.Vec3.zero () in
      let fresh () =
        P.reset tracer; get (P.render tracer camera); get (P.flush tracer);
        let sum = ref 0 in
        Bytes.iteri (fun i value -> if i mod 4 <> 3 then sum := !sum + Char.code value)
          (pixels tracer);
        assert (!sum > 0);
        !sum in
      let first = fresh () in
      for _ = 1 to 60 do get (P.render tracer camera); get (P.flush tracer) done;
      let later = fresh () in
      P.destroy tracer;
      if abs (later - first) * 50 > first then
        failwith (Printf.sprintf "instanced scene faded: fresh frame sum %d then %d" first later);
      print_endline "pathtracer: instance structure stays resident";
      print_endline "pathtracer: deterministic lit render ok";
      (* Furnace: an albedo-0.8 floor under a uniform white dome reflects
         exactly 0.8 along every path, which the ACES/2.2 resolve maps to 224.
         A zero-intensity panel exercises the MIS path (panel sampling plus the
         weighted BSDF escape) and must not change the mean. *)
      let furnace panels =
        let scene = { P.objects = [ (floor, P.material ~roughness:0.8 (rgb 0.8 0.8 0.8)) ]
          ; spheres = []; strands = []; environment = { sky = rgb 1. 1. 1.; ground = rgb 1. 1. 1.; panels }; lights = [] } in
        let tracer = get (P.create ~spp:4 ~width:32 ~height:32 scene) in
        let camera = Rays.Camera.perspective ~fov_y:0.5
          ~at:(Rays.Vec3.create 0. 4. 0.001)
          ~target:(Rays.Vec3.create 0. 0. 0.) () in
        for _ = 1 to 16 do get (P.render tracer camera); get (P.flush tracer) done;
        get (P.flush tracer);
        let sum = ref 0 in
        Bytes.iteri (fun i value -> if i mod 4 = 0 then sum := !sum + Char.code value)
          (pixels tracer);
        P.destroy tracer;
        float !sum /. 1024. in
      let plain = furnace [] in
      let mis = furnace [ P.panel ~intensity:0. ~width:0.9 ~height:0.6 ~softness:0.2 (Rays.Vec3.create 0.3 1. 0.2) ] in
      Printf.printf "pathtracer: furnace mean %.1f / %.1f (expected 224)\n" plain mis;
      assert (Float.abs (plain -. 224.) < 2.);
      assert (Float.abs (mis -. 224.) < 2.);
      (* Analytic sphere in the furnace: a white bounding-box sphere resolved
         by the intersection function table must conserve energy like the
         floor, which checks sphere hits, normals, and the table binding. *)
      let sphere_furnace =
        let scene = { P.objects = []; strands = [];
          spheres = [{ P.center = Rays.Vec3.zero; radius = 1.;
            sphere_material = P.material ~roughness:0.8 (rgb 0.8 0.8 0.8) }];
          environment = { P.sky = rgb 1. 1. 1.; ground = rgb 1. 1. 1.; panels = [] };
          lights = [] } in
        let tracer = get (P.create ~spp:4 ~width:32 ~height:32 scene) in
        (* Every corner ray must hit the sphere, rather than the white sky. *)
        let camera = Rays.Camera.perspective ~fov_y:0.2
          ~at:(Rays.Vec3.create 0. 0. 6.)
          ~target:(Rays.Vec3.create 0. 0. 0.) () in
        for _ = 1 to 16 do get (P.render tracer camera); get (P.flush tracer) done;
        get (P.flush tracer);
        let sum = ref 0 in
        Bytes.iteri (fun i value -> if i mod 4 = 0 then sum := !sum + Char.code value)
          (pixels tracer);
        P.destroy tracer;
        float !sum /. 1024. in
      Printf.printf "pathtracer: sphere furnace mean %.1f (expected 224)\n" sphere_furnace;
      assert (Float.abs (sphere_furnace -. 224.) < 2.);
      (* Per-instance materials and motion blur. Two emissive instances of one
         prototype: the left one red, the right one green, selected through the
         instance user id. With motion the right instance sweeps to the far
         right, so its rest position is only partly covered and the far
         position is hit at all, which a static build never does. *)
      let black = { P.sky = rgb 0. 0. 0.; ground = rgb 0. 0. 0.; panels = [] } in
      let scene = { P.objects = [ (sphere, P.material (rgb 0.5 0.5 0.5)) ]; spheres = []; strands = []
        ; environment = black; lights = [] } in
      let tracer = get (P.create ~spp:4 ~width:64 ~height:32 scene) in
      let place x = Rays.Mat4.translation (Rays.Vec3.create x 0. 0.) in
      let red = P.material ~emission:(rgb 4. 0. 0.) (rgb 0. 0. 0.)
      and green = P.material ~emission:(rgb 0. 4. 0.) (rgb 0. 0. 0.) in
      let static_mesh = get (P.mesh_instanced ~prototype:(sphere, P.material (rgb 0.5 0.5 0.5))
        ~materials:[| red; green |] [| place (-2.); place 2. |]) in
      let camera = Rays.Camera.perspective ~fov_y:0.9
        ~at:(Rays.Vec3.create 0. 1. 10.) ~target:(Rays.Vec3.create 0. 1. 0.) () in
      let capture mesh =
        get (P.replace_mesh tracer mesh); P.reset tracer;
        for _ = 1 to 32 do get (P.render tracer camera); get (P.flush tracer) done;
        pixels tracer in
      let static_pixels = capture static_mesh in
      let channel_at bytes point channel =
        let point = Option.get (Rays.Camera.world_to_screen ~viewport:(0,0,64,32) camera point) in
        let x = int_of_float point.x and y = int_of_float point.y in
        Char.code (Bytes.get bytes ((y * 64 + x) * 4 + channel)) in
      let left = Rays.Vec3.create (-2.) 1. 0. and right = Rays.Vec3.create 2. 1. 0.
      and end_point = Rays.Vec3.create 4.5 1. 0. in
      assert (channel_at static_pixels left 0 > 200 && channel_at static_pixels left 1 = 0);
      assert (channel_at static_pixels right 1 > 200 && channel_at static_pixels right 0 = 0);
      let moving = get (P.mesh_instanced ~prototype:(sphere, P.material (rgb 0.5 0.5 0.5))
        ~materials:[| red; green |] ~motion:[| place (-2.); place 4.5 |] [| place (-2.); place 2. |]) in
      let moving_pixels = capture moving in
      assert (channel_at static_pixels end_point 1 = 0);
      assert (channel_at moving_pixels end_point 1 > 0);
      assert (channel_at moving_pixels right 1 > 0 &&
        channel_at moving_pixels right 1 < channel_at static_pixels right 1);
      (match P.mesh_instanced ~prototype:(sphere, red) ~materials:[| red |] [| place 0.; place 1. |] with
       | Error _ -> () | Ok _ -> failwith "mismatched instance material count was accepted");
      (match P.mesh_instanced ~prototype:(sphere, red) ~motion:[| place 0. |] [| place 0.; place 1. |] with
       | Error _ -> () | Ok _ -> failwith "mismatched motion transform count was accepted");
      (* Strands need curve intersection; devices without it get a typed
         error rather than a silent miss. Metal reports curve support per GPU
         family (Apple9 and later), so both outcomes are checked. *)
      P.destroy tracer;
      print_endline "pathtracer: spheres, instance materials, motion ok";
      (* Every kernel specialization compiles and matches its declared
         interface, including the curve variants a device may never trace. *)
      let driver, _ = Ogpu.Impl.create_driver () in
      let device = get (Result.map_error Ogpu.Error.to_string (Ogpu.Backend.create_device driver)) in
      let source = In_channel.with_open_bin "pathtrace.metal" In_channel.input_all in
      let shader = get (Result.map_error Ogpu.Error.to_string (Ogpu.Shader.create
        { backend = "metal"; label = Some "pathtrace-shapes"; bytes = Bytes.of_string source
        ; entry_points = [ { Ogpu.Shader.name = "pathtrace"; stage = Compute } ]; bindings = [] })) in
      let library = get (Result.map_error Ogpu.Error.to_string (Ogpu.Backend.create_library device shader)) in
      let binding index kind = { Ogpu.Shader.group = 0; binding = index; kind; visibility = [ Compute ] } in
      let shapes = ref 0 in
      List.iter (fun ((instanced, motion, spheres, curves), scene) ->
        if not (motion && not instanced) && not (scene && (motion || not instanced)) then begin
          let interface =
            [ binding 0 Acceleration_structure; binding 1 Uniform_buffer ]
            @ List.map (fun index -> binding index Storage_buffer)
                ([ 2; 3 ] @ (if scene then [ 4 ] else [])
                 @ (if instanced then [ 5; 6; 7; 8; 9; 10 ] else [ 4; 5; 6; 7; 8; 9 ]) @ [ 11; 12; 13; 14 ]
                 @ (if spheres then [ 15 ] else []) @ (if curves then [ 17; 18; 19 ] else [])
                 @ if scene then [ 20 ] else [])
            @ (if spheres then [ binding 16 Intersection_table ] else [])
            @ [ binding 0 Storage_texture ] in
          let linked = if spheres then
            [ "sphere_hit_" ^ (if instanced then "i" else "f") ^ (if motion then "m" else "") ^ (if curves then "c" else "") ]
            else [] in
          let pipeline = get (Result.map_error Ogpu.Error.to_string
            (Ogpu.Backend.create_compute_pipeline_from library ~entry:"pathtrace"
               ~constants:[ ("INSTANCED", Bool instanced); ("MOTION", Bool motion); ("SPHERES", Bool spheres); ("CURVES", Bool curves); ("SCENE", Bool scene) ]
               ~interface ~linked ())) in
          get (Result.map_error Ogpu.Error.to_string (Ogpu.Backend.destroy_pipeline pipeline));
          incr shapes
        end)
        (List.concat_map (fun i -> List.concat_map (fun m -> List.concat_map (fun s -> List.concat_map (fun c -> [ ((i, m, s, c), false); ((i, m, s, c), true) ]) [ false; true ]) [ false; true ]) [ false; true ]) [ false; true ]);
      assert (!shapes = 16);
      let curves = Ogpu.Caps.has (Ogpu.Backend.capabilities device) Ray_tracing_curves in
      let strand_scene = { P.objects = []; spheres = [];
        strands = [{ P.points = [|Rays.Vec3.create (-0.6) 0. 0.; Rays.Vec3.zero;
          Rays.Vec3.create 0.6 0. 0.|]; thickness = 0.2;
          strand_material = P.material ~emission:(rgb 4. 0. 0.) (rgb 0. 0. 0.) }];
        environment = black; lights = [] } in
      (match P.create ~spp:1 ~width:32 ~height:32 strand_scene with
       | Error message when not curves ->
           assert (message = "path tracer strands need curve primitives, which this device does not intersect")
       | Error message -> failwith message
       | Ok strand_tracer ->
           Fun.protect ~finally:(fun () -> P.destroy strand_tracer) (fun () ->
             assert curves;
             let camera = Rays.Camera.perspective ~fov_y:0.5
               ~at:(Rays.Vec3.create 0. 0. 4.) ~target:Rays.Vec3.zero () in
             get (P.render strand_tracer camera); get (P.flush strand_tracer);
             let red = ref 0 in
             Bytes.iteri (fun i value -> if i mod 4 = 0 && Char.code value > 200 then incr red)
               (pixels strand_tracer);
             assert (!red > 0)));
      get (Result.map_error Ogpu.Error.to_string (Ogpu.Backend.destroy_library library));
      get (Result.map_error Ogpu.Error.to_string (Ogpu.Backend.destroy_device device));
      Printf.printf "pathtracer: %d kernel specializations compile\n" !shapes;
      let final_handles = live_handles () in
      Printf.printf "handle baseline %d final %d\n%!" initial_handles final_handles;
      assert (final_handles = initial_handles)
