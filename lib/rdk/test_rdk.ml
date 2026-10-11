open Rays
open Rdk
open Rdk_test_support

let get_ok = function Ok value -> value | Error _ -> fail "unexpected error"

let check_identity_cache () =
  let module Cache = Rdk_core.Support.Identity_cache in
  let cache = Cache.create ~id:(fun (key : int ref) -> !key land 1) 2 in
  let builds = ref 0 in
  let get key = Cache.find_or_add cache key (fun () -> incr builds; !key) in
  let a = ref 1 and b = ref 2 and c = ref 3 and a' = ref 1 in
  ignore (get a); ignore (get a); ignore (get a');
  if !builds <> 2 then fail "Identity_cache must key by physical identity";
  ignore (get b); ignore (get c);
  if get a <> 1 || !builds <> 5 then
    fail "Identity_cache must evict first-in first-out at capacity";
  let keys = Rdk_core.Support.Key_map.(ints First) [| 5; 7; 5 |] |> Option.get
  and last = Rdk_core.Support.Key_map.(strings Last) [| "x"; "y"; "x" |] |> Option.get in
  if keys 5 <> 0 || keys 7 <> 1 || keys 9 <> -1 || last "x" <> 2 || last "z" <> -1 then
    fail "Support.Key_map lookup"

let run () =
  check_identity_cache ();
  Test_rdk_sources.patterns ();
  Test_rdk_sources.lines ();
  let builder = Packed.Float3.Builder.create 4 in
  Packed.Float3.Builder.set builder 0 0. 0. 0.;
  Packed.Float3.Builder.set builder 1 1. 0. 0.;
  Packed.Float3.Builder.set builder 2 1. 1. 0.;
  Packed.Float3.Builder.set builder 3 0. 1. 0.;
  let positions = Packed.Float3.Builder.freeze builder in
  let topology = Topology.polygons_owned ~point_count:4 ~vertex_points:[|0; 1; 2; 3|]
    ~primitive_offsets:[|0; 4|] |> get_ok in
  if Topology.vertex_count topology <> 4 || Topology.primitive_size topology 0 <> 4
  then fail "polygon CSR cardinality";
  let selected = Group.init ~owner:Group.Point ~name:"even" 4 (fun i -> i land 1 = 0) in
  let all = Group.init ~owner:Group.Point ~name:"all" 4 (fun _ -> true) in
  let odd = Group.difference all selected |> get_ok in
  if Group.cardinality odd <> 2 || Group.mem 0 odd || not (Group.mem 1 odd) then
    fail "packed group difference";
  let geometry = Geometry.create ~positions ~topology ~groups:[selected] () |> get_ok in
  if Group.cardinality selected <> 2 then fail "packed group cardinality";
  (match Attribute_ops.enumerate ~selection:selected ~owner:Attribute.Vertex
      ~name:"bad" geometry with
   | Error error when Error.code error = "invalid_enumeration" -> ()
   | _ -> fail "enumerate accepted a mismatched group owner");
  (match Attribute_ops.enumerate ~start:max_int ~step:1 ~owner:Attribute.Point
      ~name:"overflow" geometry with
   | Error error when Error.code error = "invalid_enumeration" -> ()
   | _ -> fail "enumerate accepted an overflowing integer sequence");
  let quad_mesh = Rdk_rays.Rays_mesh.to_mesh geometry |> get_ok in
  if Mesh.index_count quad_mesh <> 6 then fail "quad bridge triangulation";
  let extruded = Poly_extrude.run ~distance:2. geometry |> get_ok in
  if Geometry.point_count extruded <> 8
     || Geometry.primitive_count extruded <> 6
     || Geometry.vertex_count extruded <> 24
  then fail "poly extrude cardinality";
  if Mesh.index_count (Rdk_rays.Rays_mesh.to_mesh extruded |> get_ok) <> 36
  then fail "poly extrude bridge";
  (match Geometry.find_group ~owner:Group.Point "even" extruded with
   | Some group when Group.cardinality group = 4 -> ()
   | _ -> fail "poly extrude point group remap");
  let reserved_p = Attribute.create_owned ~name:"P" ~owner:Attribute.Point
      (Attribute.Float3 positions) |> get_ok in
  (match Geometry.create ~positions ~topology ~attributes:[reserved_p] () with
   | Error _ -> () | Ok _ -> fail "duplicate canonical P was accepted");
  (match Topology.polygons_owned ~point_count:2 ~vertex_points:[|0; 1|]
           ~primitive_offsets:[|0; 2|] with
   | Error _ -> () | Ok _ -> fail "undersized polygon was accepted");
  let triangle_builder = Tb.create ~point_count:4 () in
  Tb.add_triangle triangle_builder 0 1 2;
  Tb.add_triangle triangle_builder 0 2 3;
  let triangle_geometry = Geometry.create ~positions
      ~topology:(Tb.freeze triangle_builder) () |> get_ok in
  let point_ids = Attribute.create_owned ~name:"point_id" ~owner:Attribute.Point
      (Attribute.Int [|0; 1; 2; 3|]) |> get_ok in
  let sortable_points = Geometry.with_attribute point_ids geometry |> get_ok in
  let sortable_bytes = geometry_bytes sortable_points in
  let sorted domains = Parallel.run ~domains (fun () ->
    Ordering.sort ~grain:1 ~selection:selected ~descending:true
      ~owner:Ordering.Points ~key:Ordering.X sortable_points |> get_ok) in
  let sorted_points = sorted 1 and sorted_many = sorted 4 in
  let sorted_positions = Packed.Float3.Private.view (Geometry.positions sorted_points)
  and sorted_topology = Topology.Private.view (Geometry.topology sorted_points) in
  check (geometry_bytes sorted_points = geometry_bytes sorted_many
      && geometry_bytes sortable_points = sortable_bytes
      && sorted_positions.x = [|1.;1.;0.;0.|]
      && sorted_positions.y = [|1.;0.;0.;1.|]
      && sorted_topology.vertex_points = [|2;1;0;3|]
      && Attribute.storage (Geometry.find_attribute ~owner:Attribute.Point
          "point_id" sorted_points |> Option.get) = Attribute.Int [|2;1;0;3|])
    "selected point sort positions/topology/payload/domain exactness/unchanged input";
  (match Ordering.sort ~owner:Ordering.Points
      ~key:(Ordering.Attribute_component { name = "missing"; component = 0 })
      sortable_points with
   | Error error when Error.code error = "invalid_sort" -> ()
   | _ -> fail "sort accepted a missing key attribute");
  (match Ordering.sort ~selection:selected ~owner:Ordering.Primitives ~key:Ordering.X
      triangle_geometry with
   | Error error when Error.code error = "invalid_sort" -> ()
   | _ -> fail "sort accepted a mismatched selection owner");
  let vertex_ids = Attribute.create_owned ~name:"vertex_id"
      ~owner:Attribute.Vertex (Attribute.Int [|0; 1; 2; 3; 4; 5|]) |> get_ok
  and primitive_ids = Attribute.create_owned ~name:"primitive_id"
      ~owner:Attribute.Primitive (Attribute.Int [|10; 20|]) |> get_ok in
  let payload_source = triangle_geometry
      |> Geometry.with_attribute vertex_ids |> get_ok
      |> Geometry.with_attribute primitive_ids |> get_ok in
  let payload_bytes = geometry_bytes payload_source in
  let duplicate_payload domains = Parallel.run ~domains (fun () ->
    Instance_copy.duplicate ~grain:1 ~copies:2
      ~transform:(Mat4.translation (Vec3.create 2. 0. 0.)) payload_source |> get_ok) in
  let payload_one = duplicate_payload 1 and payload_many = duplicate_payload 4 in
  check (geometry_bytes payload_one = geometry_bytes payload_many
      && geometry_bytes payload_source = payload_bytes
      && Geometry.point_count payload_one = 12
      && Geometry.vertex_count payload_one = 18
      && Geometry.primitive_count payload_one = 6
      && Attribute.storage (Geometry.find_attribute ~owner:Attribute.Vertex
          "vertex_id" payload_one |> Option.get)
        = Attribute.Int (Array.init 18 (fun index -> index mod 6))
      && Attribute.storage (Geometry.find_attribute ~owner:Attribute.Primitive
          "primitive_id" payload_one |> Option.get)
        = Attribute.Int (Array.init 6 (fun index -> 10 + ((index land 1) * 10))))
    "duplicate vertex/primitive payload ancestry/cardinality/domain exactness";
  let duplicated = Instance_copy.duplicate ~grain:1 ~copies:2
      ~transform:(Mat4.translation (Vec3.create 2. 0. 0.)) sortable_points
      |> get_ok in
  (match Geometry.find_group ~owner:Group.Point "even" duplicated with
   | Some group when Group.cardinality group = 6 -> ()
   | _ -> fail "duplicate group replication");
  let duplicate_once = Instance_copy.duplicate ~copies:0 sortable_points |> get_ok in
  if Geometry.data_id duplicate_once <> Geometry.data_id sortable_points then
    fail "zero-copy duplicate was not identity";
  (match Instance_copy.duplicate ~copies:(-1) sortable_points with
   | Error error when Error.code error = "invalid_parameter" -> ()
   | _ -> fail "duplicate accepted a negative copy count");
  let weighted_triangles = Test_rdk_attributes.promotion ~geometry ~triangle_geometry in
  let (transfer_source, transfer_target) = Test_rdk_attributes.transfer ~geometry ~triangle_geometry in
  let shared_box = Test_rdk_modeling.modeling ~geometry ~positions ~selected ~triangle_geometry ~weighted_triangles in
  let (box, cylinder_curve, cylindrical, grid, strip, wrong_uv_geometry) = Test_rdk_uv.render_uv ~geometry ~positions ~selected ~shared_box ~topology ~triangle_geometry in
  Test_rdk_curves.curves ~cylinder_curve ~positions ~triangle_geometry;
  Test_rdk_uv.uv_errors ~cylinder_curve ~cylindrical ~geometry ~selected ~shared_box ~strip ~wrong_uv_geometry;
  let (compact_source, match_source, match_target) = Test_rdk_misc.measure_merge ~box ~grid ~selected ~triangle_geometry in
  Test_rdk_misc.blur ~grid;
  let cancelled = Cancel.create () in
  Cancel.cancel cancelled;
  (match Plane_generators.grid ~cancel:cancelled ~columns:256 ~rows:256 ~size:2. () with
   | Error error when Error.code error = "cancelled" -> ()
   | Error error -> fail ("unexpected cancellation code: " ^ Error.code error)
   | Ok _ -> fail "cancelled RDK operation published geometry");
  (match Fuse_grid.fuse ~cancel:cancelled ~tolerance:0. grid with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled fuse published geometry or wrong error");
  (match Mirror_geometry.run ~cancel:cancelled ~origin:Vec3.zero ~normal:Vec3.unit_x grid with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled mirror published geometry or wrong error");
  (match Plane_clip.clip ~cancel:cancelled ~origin:Vec3.zero ~normal:Vec3.unit_x grid with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled clip published geometry or wrong error");
  (match promote ~cancel:cancelled ~source:Attribute.Point
      ~destination:Attribute.Primitive ~name:"N" grid with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled attribute promotion published geometry or wrong error");
  (match Attribute_ops.transfer_points ~cancel:cancelled
      ~source:transfer_source ~target:transfer_target () with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled attribute transfer published geometry or wrong error");
  (match Attribute_ops.blur_points ~cancel:cancelled ~pattern:"P" grid with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled Attribute Blur published geometry or wrong error");
  (match Compact_points.run ~cancel:cancelled compact_source with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled point compaction published geometry or wrong error");
  (match Match_size.run ~cancel:cancelled ~target:match_target match_source with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled match size published geometry or wrong error");
  (match Ordering.sort ~cancel:cancelled ~owner:Ordering.Points ~key:Ordering.X grid with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled sort published geometry or wrong error");
  (match Instance_copy.duplicate ~cancel:cancelled ~copies:4 grid with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled duplicate published geometry or wrong error");
  (match Instance_copy.copy_to_points ~cancel:cancelled ~source:grid
      ~targets:(Line_geometry.points [|(0.,0.,0.)|]) () with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled Copy to Points published geometry or wrong error");
  Test_copy_to_points.run ();
  Test_rdk_sources.kernel ();
  print_endline "rdk tests passed"
