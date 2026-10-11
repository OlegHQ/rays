open Rays
open Rdk
open Rdk_test_support

let get_ok = function Ok value -> value | Error _ -> fail "unexpected error"

let run () =
  let target_positions = Line_geometry.points [|(10., 0., 0.); (0., 20., 0.)|] in
  let target_scale = Attribute.create_owned ~name:"scale" ~owner:Attribute.Point
      (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
        ~x:[|2.; 1.|] ~y:[|1.; 3.|] ~z:[|1.; 1.|])) |> get_ok in
  let half_turn = sqrt 0.5 in
  let target_orient = Attribute.create_owned ~name:"orient" ~owner:Attribute.Point
      (Attribute.Float4 (Packed.Float4.of_owned
        ~x:[|0.; 0.|] ~y:[|0.; 0.|] ~z:[|half_turn; 0.|]
        ~w:[|half_turn; 1.|] |> get_ok)) |> get_ok in
  let targets = target_positions |> Geometry.with_attribute target_scale |> get_ok
      |> Geometry.with_attribute target_orient |> get_ok in
  let prototype = Line_geometry.points [|(1., 0., 0.); (0., 1., 0.)|] in
  let copied domains = Parallel.run ~domains (fun () ->
    Instance_copy.copy_to_points ~grain:1 ~source:prototype ~targets () |> get_ok) in
  let copied_one = copied 1 and copied_many = copied 4 in
  if not (equal_positions copied_one copied_many)
     || Geometry.point_count copied_one <> 4
  then fail "copy-to-points domain determinism/cardinality";
  let copied_positions = Geometry.positions copied_one in
  let x0, y0, _ = Packed.Float3.get copied_positions 0
  and x1, y1, _ = Packed.Float3.get copied_positions 1
  and x2, y2, _ = Packed.Float3.get copied_positions 2
  and x3, y3, _ = Packed.Float3.get copied_positions 3 in
  if abs_float (x0 -. 10.) > 1e-12 || abs_float (y0 -. 2.) > 1e-12
     || abs_float (x1 -. 9.) > 1e-12 || abs_float y1 > 1e-12
     || abs_float (x2 -. 1.) > 1e-12 || abs_float (y2 -. 20.) > 1e-12
     || abs_float x3 > 1e-12 || abs_float (y3 -. 23.) > 1e-12
  then fail "copy-to-points scale/orient/translate";
  let axis_prototype = Line_geometry.points
      [|(1.,0.,0.); (0.,1.,0.); (0.,0.,1.)|] in
  let alignment_targets = Line_geometry.points [|(0.,0.,0.); (10.,0.,0.)|] in
  let target_n = Attribute.create_owned ~name:"N" ~owner:Attribute.Point
      (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
        ~x:[|1.;0.|] ~y:[|0.;1.|] ~z:[|0.;0.|])) |> get_ok
  and target_up = Attribute.create_owned ~name:"up" ~owner:Attribute.Point
      (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
        ~x:[|0.;0.|] ~y:[|0.;0.|] ~z:[|1.;0.|])) |> get_ok in
  let alignment_targets = alignment_targets
      |> Geometry.with_attribute target_n |> get_ok
      |> Geometry.with_attribute target_up |> get_ok in
  let aligned domains = Parallel.run ~domains (fun () ->
    Instance_copy.copy_to_points ~grain:1 ~source:axis_prototype
      ~targets:alignment_targets () |> get_ok) in
  let aligned_one = aligned 1 and aligned_many = aligned 4 in
  let aligned_positions = Packed.Float3.Private.view
      (Geometry.positions aligned_one) in
  if not (equal_positions aligned_one aligned_many)
      || not (near_array [|0.;0.;1.; 11.;10.;10.|] aligned_positions.x)
      || not (near_array [|1.;0.;0.; 0.;0.;1.|] aligned_positions.y)
      || not (near_array [|0.;1.;0.; 0.;-1.;0.|] aligned_positions.z) then
    fail "copy-to-points N/up and shortest-arc alignment/domain behavior";
  let priority_n = Attribute.create_owned ~name:"N" ~owner:Attribute.Point
      (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
        ~x:[|0.;0.|] ~y:[|1.;1.|] ~z:[|0.;0.|])) |> get_ok in
  let orient_priority_targets = targets |> Geometry.with_attribute priority_n
      |> get_ok in
  let orient_priority = Instance_copy.copy_to_points ~source:prototype
      ~targets:orient_priority_targets () |> get_ok in
  if not (equal_positions orient_priority copied_one) then
    fail "copy-to-points orient did not override N";
  let velocity = Attribute.create_owned ~name:"v" ~owner:Attribute.Point
      (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
        ~x:[|0.|] ~y:[|1.|] ~z:[|0.|])) |> get_ok
  and velocity_up = Attribute.create_owned ~name:"up" ~owner:Attribute.Point
      (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
        ~x:[|0.|] ~y:[|0.|] ~z:[|1.|])) |> get_ok in
  let velocity_target = Line_geometry.points [|(0.,0.,0.)|]
      |> Geometry.with_attribute velocity |> get_ok
      |> Geometry.with_attribute velocity_up |> get_ok in
  let velocity_copy = Instance_copy.copy_to_points ~source:axis_prototype
      ~targets:velocity_target () |> get_ok in
  let velocity_positions = Packed.Float3.Private.view
      (Geometry.positions velocity_copy) in
  if not (near_array [|-1.;0.;0.|] velocity_positions.x)
      || not (near_array [|0.;0.;1.|] velocity_positions.y)
      || not (near_array [|0.;1.;0.|] velocity_positions.z) then
    fail "copy-to-points velocity/up fallback alignment";
  let quarter_turn = sqrt 0.5 in
  let target_rot = Attribute.create_owned ~name:"rot" ~owner:Attribute.Point
      (Attribute.Float4 (Packed.Float4.of_owned
        ~x:[|0.|] ~y:[|0.|] ~z:[|quarter_turn|] ~w:[|quarter_turn|]
        |> get_ok)) |> get_ok
  and target_trans = Attribute.create_owned ~name:"trans" ~owner:Attribute.Point
      (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
        ~x:[|3.|] ~y:[|0.|] ~z:[|0.|])) |> get_ok
  and target_pivot = Attribute.create_owned ~name:"pivot" ~owner:Attribute.Point
      (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
        ~x:[|1.|] ~y:[|0.|] ~z:[|0.|])) |> get_ok
  and target_pscale = Attribute.create_owned ~name:"pscale" ~owner:Attribute.Point
      (Attribute.Float [|2.|]) |> get_ok in
  let stacked_target = Line_geometry.points [|(10.,0.,0.)|]
      |> Geometry.with_attribute target_rot |> get_ok
      |> Geometry.with_attribute target_trans |> get_ok
      |> Geometry.with_attribute target_pivot |> get_ok
      |> Geometry.with_attribute target_pscale |> get_ok in
  let pivot_normal = Attribute.create_owned ~name:"N" ~owner:Attribute.Point
      (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
        ~x:[|1.;1.|] ~y:[|0.;0.|] ~z:[|0.;0.|])) |> get_ok in
  let pivot_source = Line_geometry.points [|(1.,0.,0.); (2.,0.,0.)|]
      |> Geometry.with_attribute pivot_normal |> get_ok in
  let stacked domains = Parallel.run ~domains (fun () ->
    Instance_copy.copy_to_points ~grain:1 ~source:pivot_source ~targets:stacked_target ()
      |> get_ok) in
  let stacked_one = stacked 1 and stacked_many = stacked 4 in
  let stacked_positions = Packed.Float3.Private.view
      (Geometry.positions stacked_one)
  and stacked_normals = Geometry.find_attribute ~owner:Attribute.Point "N"
      stacked_one |> Option.get
      |> Attribute.get (Attribute.normal ~owner:Attribute.Point) |> Option.get
      |> Packed.Float3.Private.view
  and stacked_normals_many = Geometry.find_attribute ~owner:Attribute.Point "N"
      stacked_many |> Option.get
      |> Attribute.get (Attribute.normal ~owner:Attribute.Point) |> Option.get
      |> Packed.Float3.Private.view in
  if not (equal_positions stacked_one stacked_many)
      || not (near_array [|13.;13.|] stacked_positions.x)
      || not (near_array [|0.;2.|] stacked_positions.y)
      || not (near_array [|0.;0.|] stacked_positions.z)
      || not (near_array [|0.;0.|] stacked_normals.x)
      || not (near_array [|1.;1.|] stacked_normals.y)
      || not (near_array [|0.;0.|] stacked_normals.z)
      || stacked_normals.x <> stacked_normals_many.x
      || stacked_normals.y <> stacked_normals_many.y
      || stacked_normals.z <> stacked_normals_many.z then
    fail "copy-to-points pivot/scale/post-rotation/translation stack";
  let packed_transform values = Rdk.Packed.Float_array.create_owned
      ~offsets:[|0; Array.length values|] ~values |> get_ok in
  let target_transform = Attribute.create_owned ~name:"transform"
      ~owner:Attribute.Point (Attribute.Float_array (packed_transform
        [|2.;0.;0.;5.; 0.;3.;0.;6.; 0.;0.;4.;7.; 0.;0.;0.;1.|]))
      |> get_ok in
  let matrix_target = stacked_target |> Geometry.with_attribute target_transform
      |> get_ok in
  let matrix_copied domains = Parallel.run ~domains (fun () ->
    Instance_copy.copy_to_points ~grain:1 ~source:pivot_source ~targets:matrix_target ()
      |> get_ok) in
  let matrix_one = matrix_copied 1 and matrix_many = matrix_copied 4 in
  let matrix_positions = Packed.Float3.Private.view (Geometry.positions matrix_one)
  and matrix_normals = Geometry.find_attribute ~owner:Attribute.Point "N"
      matrix_one |> Option.get
      |> Attribute.get (Attribute.normal ~owner:Attribute.Point) |> Option.get
      |> Packed.Float3.Private.view
  and matrix_normals_many = Geometry.find_attribute ~owner:Attribute.Point "N"
      matrix_many |> Option.get
      |> Attribute.get (Attribute.normal ~owner:Attribute.Point) |> Option.get
      |> Packed.Float3.Private.view in
  if not (equal_positions matrix_one matrix_many)
      || not (near_array [|18.;20.|] matrix_positions.x)
      || not (near_array [|6.;6.|] matrix_positions.y)
      || not (near_array [|7.;7.|] matrix_positions.z)
      || not (near_array [|1.;1.|] matrix_normals.x)
      || not (near_array [|0.;0.|] matrix_normals.y)
      || not (near_array [|0.;0.|] matrix_normals.z)
      || matrix_normals.x <> matrix_normals_many.x
      || matrix_normals.y <> matrix_normals_many.y
      || matrix_normals.z <> matrix_normals_many.z then
    fail "copy-to-points affine transform override/normal/domain behavior";
  let singular_transform = Attribute.create_owned ~name:"transform"
      ~owner:Attribute.Point (Attribute.Float_array (packed_transform
        [|1.;0.;0.; 0.;1.;0.; 0.;0.;0.|])) |> get_ok in
  let singular_target = Line_geometry.points [|(0.,0.,0.)|]
      |> Geometry.with_attribute singular_transform |> get_ok in
  let singular_copy = Instance_copy.copy_to_points ~source:pivot_source
      ~targets:singular_target () |> get_ok in
  if Geometry.find_attribute ~owner:Attribute.Point "N" singular_copy <> None
  then fail "copy-to-points singular transform retained invalid normals";
  let malformed_transform = Attribute.create_owned ~name:"transform"
      ~owner:Attribute.Point (Attribute.Float_array (packed_transform
        [|1.;0.;0.;0.; 0.;1.;0.;0.; 0.;0.;1.;0.; 0.;0.;1.;1.|]))
      |> get_ok in
  let malformed_target = Line_geometry.points [|(0.,0.,0.)|]
      |> Geometry.with_attribute malformed_transform |> get_ok in
  (match Instance_copy.copy_to_points ~source:prototype ~targets:malformed_target () with
   | Error error when Error.code error = "invalid_attribute" -> ()
   | _ -> fail "copy-to-points accepted a projective transform matrix");
  let restricted_source = Mesh_merge.run [
      Line_geometry.polyline [|(0.,0.,0.); (1.,0.,0.)|] |> get_ok;
      Line_geometry.polyline [|(10.,0.,0.); (12.,0.,0.)|] |> get_ok]
      |> get_ok in
  let restricted_weight = Attribute.create_owned ~name:"weight"
      ~owner:Attribute.Point (Attribute.Float [|0.;1.;10.;12.|]) |> get_ok
  and restricted_id = Attribute.create_owned ~name:"piece_id"
      ~owner:Attribute.Primitive (Attribute.Int [|100;200|]) |> get_ok
  and restricted_detail = Attribute.create_owned ~name:"detail_id"
      ~owner:Attribute.Detail (Attribute.Int [|77|]) |> get_ok in
  let restricted_source = restricted_source
      |> Geometry.with_attribute restricted_weight |> get_ok
      |> Geometry.with_attribute restricted_id |> get_ok
      |> Geometry.with_attribute restricted_detail |> get_ok
      |> Group_mesh.group_edges ~name:"source_edges" |> get_ok in
  let source_second = Group.ordered ~owner:Group.Primitive ~name:"source_second"
      ~length:2 [|1|] |> get_ok in
  let restricted_source = Geometry.with_group source_second restricted_source
      |> get_ok in
  let restricted_targets = Line_geometry.points
      [|(0.,0.,0.); (0.,10.,0.); (0.,20.,0.)|] in
  let restricted_scale = Attribute.create_owned ~name:"pscale"
      ~owner:Attribute.Point (Attribute.Float [|1.;9.;2.|]) |> get_ok in
  let restricted_targets = Geometry.with_attribute restricted_scale
      restricted_targets |> get_ok in
  let target_outer = Group.ordered ~owner:Group.Point ~name:"target_outer"
      ~length:3 [|2;0|] |> get_ok in
  let restricted_source_bytes = geometry_bytes restricted_source
  and restricted_targets_bytes = geometry_bytes restricted_targets in
  let restricted domains = Parallel.run ~domains (fun () ->
    Instance_copy.copy_to_points ~grain:1 ~source_primitives:source_second
      ~target_points:target_outer ~source:restricted_source
      ~targets:restricted_targets () |> get_ok) in
  let restricted_one = restricted 1 and restricted_many = restricted 4 in
  let restricted_positions = Packed.Float3.Private.view
      (Geometry.positions restricted_one)
  and restricted_topology = Topology.Private.view
      (Geometry.topology restricted_one) in
  let restricted_group = Geometry.find_group ~owner:Group.Primitive
      "source_second" restricted_one |> Option.get
  and restricted_edges = Geometry.find_edge_group "source_edges" restricted_one
      |> Option.get in
  check (geometry_bytes restricted_one = geometry_bytes restricted_many
      && geometry_bytes restricted_source = restricted_source_bytes
      && geometry_bytes restricted_targets = restricted_targets_bytes
      && restricted_positions.x = [|10.;12.;20.;24.|]
      && restricted_positions.y = [|0.;0.;20.;20.|]
      && restricted_positions.z = Array.make 4 0.
      && restricted_topology.vertex_points = [|0;1;2;3|]
      && restricted_topology.primitive_offsets = [|0;2;4|]
      && Group.length restricted_group = 2
      && Group.cardinality restricted_group = 2
      && Edge_group.length restricted_edges = 2
      && Edge_group.cardinality restricted_edges = 2)
    "copy-to-points target point order/restrictions/topology/groups/domain exactness";
  let empty_targets = Group.init ~owner:Group.Point ~name:"none" 3
      (fun _ -> false) in
  let restricted_empty = Instance_copy.copy_to_points ~source_primitives:source_second
      ~target_points:empty_targets ~source:restricted_source
      ~targets:restricted_targets () |> get_ok in
  if Geometry.point_count restricted_empty <> 0
      || Geometry.primitive_count restricted_empty <> 0
      || Geometry.find_attribute ~owner:Attribute.Detail "detail_id"
           restricted_empty = None then
    fail "copy-to-points empty target restriction/detail preservation";
  let piece_targets = Line_geometry.points
      [|(0.,0.,0.); (0.,10.,0.); (0.,20.,0.); (0.,30.,0.)|]
    |> Geometry.with_attribute (Attribute.create_owned ~name:"piece_id"
         ~owner:Attribute.Point (Attribute.Int [|200;100;999;200|]) |> get_ok)
    |> get_ok
    |> Geometry.with_attribute (Attribute.create_owned ~name:"pscale"
         ~owner:Attribute.Point (Attribute.Float [|1.;2.;3.;1.|]) |> get_ok)
    |> get_ok
    |> Geometry.with_attribute (Attribute.create_owned ~name:"piece_profile"
         ~owner:Attribute.Point (Attribute.Float_array
           (Packed.Float_array.create_owned ~offsets:[|0;2;3;6;8|]
             ~values:[|0.;1.;2.;3.;4.;5.;6.;7.|] |> get_ok)) |> get_ok)
    |> get_ok in
  let piece_rules = Instance_copy.[{
      copy_target_pattern = "piece_profile";
      copy_target_owner = Copy_target_primitives;
      copy_target_operation = Copy_target_copy;
    }] in
  let piece_targets_bytes = geometry_bytes piece_targets in
  let piece_copy domains = Parallel.run ~domains (fun () ->
    Instance_copy.copy_to_points ~grain:1 ~piece_attribute:"piece_id"
      ~target_attributes:piece_rules ~source:restricted_source
      ~targets:piece_targets () |> get_ok) in
  let piece_one = piece_copy 1 and piece_many = piece_copy 4 in
  let piece_positions = Packed.Float3.Private.view
      (Geometry.positions piece_one)
  and piece_topology = Topology.Private.view (Geometry.topology piece_one) in
  let piece_profile = float_array_values ~owner:Attribute.Primitive
      ~name:"piece_profile" piece_one in
  check (geometry_bytes piece_one = geometry_bytes piece_many
      && geometry_bytes restricted_source = restricted_source_bytes
      && geometry_bytes piece_targets = piece_targets_bytes
      && piece_positions.x = [|10.;12.;0.;2.;10.;12.|]
      && piece_positions.y = [|0.;0.;10.;10.;30.;30.|]
      && piece_positions.z = Array.make 6 0.
      && piece_topology.vertex_points = [|0;1;2;3;4;5|]
      && piece_topology.primitive_offsets = [|0;2;4;6|]
      && piece_profile.offsets = [|0;2;3;5|]
      && piece_profile.values = [|0.;1.;2.;6.;7.|])
    "copy-to-points piece matching/target order/ragged payload/domain exactness";
  let point_piece_source = Line_geometry.polyline [|(0.,0.,0.); (1.,0.,0.)|]
      |> get_ok
      |> Geometry.with_attribute (Attribute.create_owned ~name:"point_piece"
           ~owner:Attribute.Point (Attribute.Text [|"left";"right"|])
           |> get_ok) |> get_ok in
  let point_piece_targets = Line_geometry.points [|(0.,0.,0.); (0.,5.,0.)|]
      |> Geometry.with_attribute (Attribute.create_owned ~name:"point_piece"
           ~owner:Attribute.Point (Attribute.Text [|"right";"left"|])
           |> get_ok) |> get_ok in
  let point_piece = Instance_copy.copy_to_points ~piece_attribute:"point_piece"
      ~source:point_piece_source ~targets:point_piece_targets () |> get_ok in
  let point_piece_positions = Packed.Float3.Private.view
      (Geometry.positions point_piece) in
  if Geometry.point_count point_piece <> 2
      || Geometry.vertex_count point_piece <> 0
      || Geometry.primitive_count point_piece <> 0
      || not (near_array [|1.;0.|] point_piece_positions.x)
      || not (near_array [|0.;5.|] point_piece_positions.y) then
    fail "copy-to-points point piece mixed-primitive/free-point behavior";
  let invalid_piece_targets = Line_geometry.points [|(0.,0.,0.)|]
      |> Geometry.with_attribute (Attribute.create_owned ~name:"bad_piece"
           ~owner:Attribute.Point (Attribute.Float [|1.|]) |> get_ok)
      |> get_ok in
  (match Instance_copy.copy_to_points ~piece_attribute:"bad_piece"
      ~source:restricted_source ~targets:invalid_piece_targets () with
   | Error error when Error.code error = "invalid_attribute" -> ()
   | _ -> fail "copy-to-points accepted a non-discrete piece attribute");
  let cancelled_piece = Cancel.create () in
  Cancel.cancel cancelled_piece;
  (match Instance_copy.copy_to_points ~cancel:cancelled_piece
      ~piece_attribute:"piece_id" ~source:restricted_source
      ~targets:piece_targets () with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "copy-to-points piece planning ignored cancellation");
  let wrong_source_owner = Group.init ~owner:Group.Point ~name:"wrong" 4
      (fun _ -> true)
  and wrong_target_owner = Group.init ~owner:Group.Primitive ~name:"wrong" 0
      (fun _ -> false) in
  (match Instance_copy.copy_to_points ~source_primitives:wrong_source_owner
      ~source:restricted_source ~targets:restricted_targets () with
   | Error error when Error.code error = "invalid_selection" -> ()
   | _ -> fail "copy-to-points accepted a point-owned source selection");
  (match Instance_copy.copy_to_points ~target_points:wrong_target_owner
      ~source:restricted_source ~targets:restricted_targets () with
   | Error error when Error.code error = "invalid_selection" -> ()
   | _ -> fail "copy-to-points accepted a primitive-owned target selection");
  let transfer_source = Line_geometry.polyline [|(0.,0.,0.); (1.,0.,0.)|] |> get_ok in
  let source_weight = Attribute.create_owned ~name:"weight" ~owner:Attribute.Point
      (Attribute.Float [|10.;20.|]) |> get_ok
  and source_corner = Attribute.create_owned ~name:"corner" ~owner:Attribute.Vertex
      (Attribute.Int [|1;2|]) |> get_ok
  and source_density = Attribute.create_owned ~name:"density"
      ~owner:Attribute.Primitive (Attribute.Float [|2.|]) |> get_ok
  and source_profile = Attribute.create_owned ~name:"profile"
      ~owner:Attribute.Point (Attribute.Float_array
        (Packed.Float_array.create_owned ~offsets:[|0;2;4|]
          ~values:[|10.;20.;30.;40.|] |> get_ok)) |> get_ok
  and source_disabled = Attribute.create_owned ~name:"disabled"
      ~owner:Attribute.Point (Attribute.Int [|7;8|]) |> get_ok in
  let transfer_source = transfer_source
      |> Geometry.with_attribute source_weight |> get_ok
      |> Geometry.with_attribute source_corner |> get_ok
      |> Geometry.with_attribute source_density |> get_ok
      |> Geometry.with_attribute source_profile |> get_ok
      |> Geometry.with_attribute source_disabled |> get_ok
      |> Geometry.with_group (Group.init ~owner:Group.Point ~name:"union_mask" 2
           (fun point -> point = 0)) |> get_ok
      |> Geometry.with_group (Group.init ~owner:Group.Vertex
           ~name:"intersect_mask" 2 (fun vertex -> vertex = 0)) |> get_ok
      |> Geometry.with_group (Group.init ~owner:Group.Primitive
           ~name:"subtract_mask" 1 (fun _ -> true)) |> get_ok in
  let transfer_targets = Line_geometry.points [|(0.,0.,0.); (0.,10.,0.)|] in
  let target_weight = Attribute.create_owned ~name:"weight" ~owner:Attribute.Point
      (Attribute.Float [|3.;4.|]) |> get_ok
  and target_corner = Attribute.create_owned ~name:"corner" ~owner:Attribute.Point
      (Attribute.Int [|100;200|]) |> get_ok
  and target_density = Attribute.create_owned ~name:"density" ~owner:Attribute.Point
      (Attribute.Float [|5.;7.|]) |> get_ok
  and target_label = Attribute.create_owned ~name:"label" ~owner:Attribute.Point
      (Attribute.Text [|"first";"second"|]) |> get_ok
  and target_gain = Attribute.create_owned ~name:"gain" ~owner:Attribute.Point
      (Attribute.Float [|2.;3.|]) |> get_ok
  and target_profile = Attribute.create_owned ~name:"profile"
      ~owner:Attribute.Point (Attribute.Float_array
        (Packed.Float_array.create_owned ~offsets:[|0;2;4|]
          ~values:[|1.;2.;3.;4.|] |> get_ok)) |> get_ok
  and target_disabled = Attribute.create_owned ~name:"disabled"
      ~owner:Attribute.Point (Attribute.Int [|100;200|]) |> get_ok in
  let transfer_targets = transfer_targets
      |> Geometry.with_attribute target_weight |> get_ok
      |> Geometry.with_attribute target_corner |> get_ok
      |> Geometry.with_attribute target_density |> get_ok
      |> Geometry.with_attribute target_label |> get_ok
      |> Geometry.with_attribute target_gain |> get_ok
      |> Geometry.with_attribute target_profile |> get_ok
      |> Geometry.with_attribute target_disabled |> get_ok
      |> Geometry.with_group (Group.init ~owner:Group.Point ~name:"union_mask" 2
           (fun point -> point = 1)) |> get_ok
      |> Geometry.with_group (Group.init ~owner:Group.Point
           ~name:"intersect_mask" 2 (fun point -> point = 1)) |> get_ok
      |> Geometry.with_group (Group.init ~owner:Group.Point
           ~name:"subtract_mask" 2 (fun point -> point = 1)) |> get_ok
      |> Geometry.with_group (Group.init ~owner:Group.Point ~name:"copy_mask" 2
           (fun point -> point = 1)) |> get_ok
      |> Geometry.with_group (Group.init ~owner:Group.Point
           ~name:"missing_multiply" 2 (fun point -> point = 1)) |> get_ok
      |> Geometry.with_group (Group.init ~owner:Group.Point
           ~name:"missing_subtract" 2 (fun point -> point = 1)) |> get_ok in
  let transfer_rules = Instance_copy.[
    { copy_target_pattern = "weight"; copy_target_owner = Copy_target_primitives;
      copy_target_operation = Copy_target_multiply };
    { copy_target_pattern = "weight"; copy_target_owner = Copy_target_points;
      copy_target_operation = Copy_target_add };
    { copy_target_pattern = "corner"; copy_target_owner = Copy_target_vertices;
      copy_target_operation = Copy_target_add };
    { copy_target_pattern = "density";
      copy_target_owner = Copy_target_primitives;
      copy_target_operation = Copy_target_subtract };
    { copy_target_pattern = "label"; copy_target_owner = Copy_target_primitives;
      copy_target_operation = Copy_target_copy };
    { copy_target_pattern = "gain"; copy_target_owner = Copy_target_points;
      copy_target_operation = Copy_target_subtract };
    { copy_target_pattern = "profile"; copy_target_owner = Copy_target_points;
      copy_target_operation = Copy_target_add };
    { copy_target_pattern = "disabled";
      copy_target_owner = Copy_target_primitives;
      copy_target_operation = Copy_target_copy };
    { copy_target_pattern = "disabled"; copy_target_owner = Copy_target_points;
      copy_target_operation = Copy_target_nothing };
    { copy_target_pattern = "union_mask"; copy_target_owner = Copy_target_points;
      copy_target_operation = Copy_target_add };
    { copy_target_pattern = "intersect_mask";
      copy_target_owner = Copy_target_vertices;
      copy_target_operation = Copy_target_multiply };
    { copy_target_pattern = "subtract_mask";
      copy_target_owner = Copy_target_primitives;
      copy_target_operation = Copy_target_subtract };
    { copy_target_pattern = "copy_mask";
      copy_target_owner = Copy_target_primitives;
      copy_target_operation = Copy_target_copy };
    { copy_target_pattern = "missing_multiply";
      copy_target_owner = Copy_target_points;
      copy_target_operation = Copy_target_multiply };
    { copy_target_pattern = "missing_subtract";
      copy_target_owner = Copy_target_points;
      copy_target_operation = Copy_target_subtract };
  ] in
  let transfer_source_bytes = geometry_bytes transfer_source
  and transfer_targets_bytes = geometry_bytes transfer_targets in
  let transferred domains = Parallel.run ~domains (fun () ->
    Instance_copy.copy_to_points ~grain:1 ~target_attributes:transfer_rules
      ~source:transfer_source ~targets:transfer_targets () |> get_ok) in
  let transferred_one = transferred 1 and transferred_many = transferred 4 in
  let transferred_profile = float_array_values ~owner:Attribute.Point
      ~name:"profile" transferred_one in
  check (geometry_bytes transferred_one = geometry_bytes transferred_many
      && geometry_bytes transfer_source = transfer_source_bytes
      && geometry_bytes transfer_targets = transfer_targets_bytes
      && Geometry.point_count transferred_one = 4
      && Geometry.vertex_count transferred_one = 4
      && Geometry.primitive_count transferred_one = 2
      && transferred_profile.offsets = [|0;2;4;6;8|]
      && transferred_profile.values = [|11.;22.;31.;42.;13.;24.;33.;44.|])
    "copy-to-points target arithmetic/ragged payload/domain exactness";
  List.iter (fun (owner, name, storage) ->
    let expected = Attribute.create_owned ~owner ~name storage |> get_ok in
    match Geometry.find_attribute ~owner name transferred_one with
    | Some actual -> check (equal_attribute expected actual)
        ("copy-to-points target attribute " ^ name)
    | None -> fail ("copy-to-points missing target attribute " ^ name))
    Attribute.[
      Point, "weight", Float [|13.;23.;14.;24.|];
      Vertex, "corner", Int [|101;102;201;202|];
      Primitive, "density", Float [|-3.;-5.|];
      Primitive, "label", Text [|"first";"second"|];
      Point, "gain", Float [|-2.;-2.;-3.;-3.|];
      Point, "disabled", Int [|7;8;7;8|]];
  check (Geometry.find_attribute ~owner:Attribute.Primitive "weight"
        transferred_one = None
      && Geometry.find_attribute ~owner:Attribute.Primitive "disabled"
        transferred_one = None)
    "copy-to-points last matching rule wins, including Nothing";
  let multiplied domains = Parallel.run ~domains (fun () ->
    Instance_copy.copy_to_points ~grain:1
      ~target_attributes:[List.hd transfer_rules]
      ~source:transfer_source ~targets:transfer_targets () |> get_ok) in
  let multiplied_one = multiplied 1 and multiplied_many = multiplied 4 in
  let expected = Attribute.create_owned ~owner:Attribute.Primitive
      ~name:"weight" (Attribute.Float [|3.;4.|]) |> get_ok in
  check (geometry_bytes multiplied_one = geometry_bytes multiplied_many
      && equal_attribute expected (Geometry.find_attribute
          ~owner:Attribute.Primitive "weight" multiplied_one |> Option.get))
    "copy-to-points multiply initializes a missing owner from the target";
  List.iter (fun (owner, name, length, members) ->
    match Geometry.find_group ~owner name transferred_one with
    | Some group -> check (Group.length group = length
        && Group.cardinality group = Array.length members
        && Array.for_all (fun index -> Group.mem index group) members)
        ("copy-to-points target group " ^ name)
    | None -> fail ("copy-to-points missing target group " ^ name))
    Group.[Point, "union_mask", 4, [|0;2;3|];
      Vertex, "intersect_mask", 4, [|2|];
      Primitive, "subtract_mask", 2, [|0|];
      Primitive, "copy_mask", 2, [|1|];
      Point, "missing_multiply", 4, [|2;3|];
      Point, "missing_subtract", 4, [||]];
  let incompatible_source = Geometry.with_attribute
      (Attribute.create_owned ~name:"corner" ~owner:Attribute.Point
        (Attribute.Text [|"a";"b"|]) |> get_ok) transfer_source |> get_ok in
  let incompatible_rule = Instance_copy.{ copy_target_pattern = "corner";
      copy_target_owner = Copy_target_points;
      copy_target_operation = Copy_target_add } in
  (match Instance_copy.copy_to_points ~target_attributes:[incompatible_rule]
      ~source:incompatible_source ~targets:transfer_targets () with
   | Error error when Error.code error = "invalid_attribute" -> ()
   | _ -> fail "copy-to-points accepted incompatible target arithmetic storage");
  let malformed_rule = Instance_copy.{ copy_target_pattern = "[unterminated";
      copy_target_owner = Copy_target_points;
      copy_target_operation = Copy_target_copy } in
  (match Instance_copy.copy_to_points ~target_attributes:[malformed_rule]
      ~source:transfer_source ~targets:transfer_targets () with
   | Error error when Error.code error = "invalid_attribute" -> ()
   | _ -> fail "copy-to-points accepted malformed target attribute pattern");
  let mismatched_profile = Attribute.create_owned ~name:"profile"
      ~owner:Attribute.Point (Attribute.Float_array
        (Packed.Float_array.create_owned ~offsets:[|0;1;2|]
          ~values:[|1.;2.|] |> get_ok)) |> get_ok in
  let mismatched_targets = Geometry.with_attribute mismatched_profile
      transfer_targets |> get_ok in
  let mismatched_rule = Instance_copy.{ copy_target_pattern = "profile";
      copy_target_owner = Copy_target_points;
      copy_target_operation = Copy_target_add } in
  (match Instance_copy.copy_to_points ~target_attributes:[mismatched_rule]
      ~source:transfer_source ~targets:mismatched_targets () with
   | Error error when Error.code error = "invalid_attribute" -> ()
   | _ -> fail "copy-to-points accepted mismatched target ragged row widths");
  let nonfinite_n = Attribute.create_owned ~name:"N" ~owner:Attribute.Point
      (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
        ~x:[|Float.nan|] ~y:[|0.|] ~z:[|1.|])) |> get_ok in
  let invalid_alignment = Line_geometry.points [|(0.,0.,0.)|]
      |> Geometry.with_attribute nonfinite_n |> get_ok in
  (match Instance_copy.copy_to_points ~source:prototype ~targets:invalid_alignment () with
   | Error error when Error.code error = "invalid_attribute" -> ()
   | _ -> fail "copy-to-points accepted a non-finite target N");
  let invalid_rot = Attribute.create_owned ~name:"rot" ~owner:Attribute.Point
      (Attribute.Int [|1|]) |> get_ok in
  let invalid_rot_target = Line_geometry.points [|(0.,0.,0.)|]
      |> Geometry.with_attribute invalid_rot |> get_ok in
  (match Instance_copy.copy_to_points ~source:prototype ~targets:invalid_rot_target () with
   | Error error when Error.code error = "invalid_attribute" -> ()
   | _ -> fail "copy-to-points accepted a non-quaternion target rot");
  let nonfinite_trans = Attribute.create_owned ~name:"trans"
      ~owner:Attribute.Point
      (Attribute.Float3 (Packed.Float3.Private.of_owned_exn
        ~x:[|Float.infinity|] ~y:[|0.|] ~z:[|0.|])) |> get_ok in
  let invalid_trans_target = Line_geometry.points [|(0.,0.,0.)|]
      |> Geometry.with_attribute nonfinite_trans |> get_ok in
  (match Instance_copy.copy_to_points ~source:prototype ~targets:invalid_trans_target () with
   | Error error when Error.code error = "invalid_attribute" -> ()
   | _ -> fail "copy-to-points accepted a non-finite target translation");
  List.iter (fun (one, four) ->
    check (geometry_bytes one = geometry_bytes four)
      "copy-to-points complete transform payload differs by domain count")
    [copied_one, copied_many; aligned_one, aligned_many;
      stacked_one, stacked_many; matrix_one, matrix_many];
  print_endline "RDK Copy to Points tests passed"
