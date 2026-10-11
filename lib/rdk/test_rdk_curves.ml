open Rays
open Rdk
open Rdk_test_support

let get_ok = function Ok value -> value | Error _ -> fail "unexpected error"

let curves ~cylinder_curve ~positions ~triangle_geometry =
  let swept_edge_geometry = cylinder_curve
      |> Group_mesh.group_edges ~name:"centerline_edges" |> get_ok
      |> Sweep_circle.run ~sides:8 ~radius:0.1 |> get_ok in
  let swept_edge_group = Geometry.find_edge_group "centerline_edges"
      swept_edge_geometry |> Option.get in
  if Edge_group.cardinality swept_edge_group <> 32
     || Edge_group.length swept_edge_group <> 64 then
    fail "sweep did not propagate selected centerline edges longitudinally";
  let scaled_spine = Line_geometry.polyline [|(0.,0.,0.); (2.,0.,0.); (4.,0.,0.)|]
      |> get_ok in
  let wire_scale = Attribute.create_owned ~name:"wire_scale"
      ~owner:Attribute.Point (Attribute.Float [|1.; 2.; 0.5|]) |> get_ok in
  let scaled_spine = Geometry.with_attribute wire_scale scaled_spine |> get_ok in
  let scaled_wire = Sweep_circle.run ~grain:1 ~sides:8
      ~scale_attribute:"wire_scale" ~radius:0.25 scaled_spine |> get_ok in
  let scaled_positions = Packed.Float3.Private.view
      (Geometry.positions scaled_wire) in
  let ring_radius point =
    let output = point * 8 in
    let dx = scaled_positions.x.(output) -. (float_of_int point *. 2.)
    and dy = scaled_positions.y.(output)
    and dz = scaled_positions.z.(output) in
    sqrt ((dx *. dx) +. (dy *. dy) +. (dz *. dz)) in
  if abs_float (ring_radius 0 -. 0.25) > 1e-12
      || abs_float (ring_radius 1 -. 0.5) > 1e-12
      || abs_float (ring_radius 2 -. 0.125) > 1e-12 then
    fail "sweep point scale attribute";
  let capped_wire = Sweep_circle.run ~grain:1 ~sides:8
      ~scale_attribute:"wire_scale" ~caps:true ~cap_group:"caps"
      ~radius:0.25 scaled_spine |> get_ok in
  let capped_topology = Geometry.topology capped_wire in
  let capped_points = Packed.Float3.Private.view (Geometry.positions capped_wire) in
  let cap_normal_x primitive =
    let first, _ = Topology.primitive_vertex_range capped_topology primitive in
    let point local = Topology.point_of_vertex capped_topology (first + local) in
    let a = point 0 and b = point 1 and c = point 2 in
    let aby = capped_points.y.(b) -. capped_points.y.(a)
    and abz = capped_points.z.(b) -. capped_points.z.(a)
    and acy = capped_points.y.(c) -. capped_points.y.(a)
    and acz = capped_points.z.(c) -. capped_points.z.(a) in
    (aby *. acz) -. (abz *. acy) in
  let cap_group = Geometry.find_group ~owner:Group.Primitive "caps" capped_wire
      |> Option.get in
  if Geometry.point_count capped_wire <> 24
      || Geometry.primitive_count capped_wire <> 18
      || Geometry.vertex_count capped_wire <> 80
      || Topology.primitive_size capped_topology 16 <> 8
      || Topology.primitive_size capped_topology 17 <> 8
      || cap_normal_x 16 >= 0. || cap_normal_x 17 <= 0.
      || Group.cardinality cap_group <> 2
      || Geometry.find_attribute ~owner:Attribute.Vertex "N" capped_wire = None
      then fail "sweep cap topology/winding/group/hard normals";
  (match Sweep_circle.run ~cap_group:"caps" ~radius:0.1 scaled_spine with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "sweep accepted a cap group without caps");
  (match Sweep_circle.run ~scale_attribute:"missing" ~radius:0.1 scaled_spine with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "sweep accepted a missing scale attribute");
  let invalid_wire_scale = Attribute.create_owned ~name:"wire_scale"
      ~owner:Attribute.Point (Attribute.Float [|1.; -1.; 1.|]) |> get_ok in
  let invalid_scaled_spine = Geometry.with_attribute invalid_wire_scale
      scaled_spine |> get_ok in
  (match Sweep_circle.run ~scale_attribute:"wire_scale" ~radius:0.1
      invalid_scaled_spine with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "sweep accepted a negative point scale");
  let resampled_closed = cylinder_curve
      |> Group_mesh.group_edges ~name:"curve_edges" |> get_ok
      |> Resample_curves.run ~segments:8 |> get_ok in
  let resampled_closed_group = Geometry.find_edge_group "curve_edges"
      resampled_closed |> Option.get in
  if Edge_group.cardinality resampled_closed_group <> 8
     || Edge_group.length resampled_closed_group <> 8 then
    fail "closed resample did not propagate selected edge intervals";
  let open_curve = Line_geometry.polyline [|(0.,0.,0.); (1.,0.,0.); (2.,0.,0.);
      (3.,0.,0.)|] |> get_ok in
  let open_index = Topology_index.create (Geometry.topology open_curve) in
  let middle_edge = Topology_index.find_edge open_index ~a:1 ~b:2 |> Option.get in
  let middle_group = Edge_group.init ~topology:(Geometry.topology open_curve)
      ~index:open_index ~name:"middle_edge" (fun edge -> edge = middle_edge) in
  let resampled_partial = Geometry.with_edge_group middle_group open_curve |> get_ok
      |> Resample_curves.run ~segments:6 |> get_ok in
  let resampled_partial_group = Geometry.find_edge_group "middle_edge"
      resampled_partial |> Option.get in
  if Edge_group.cardinality resampled_partial_group <> 2
     || Edge_group.length resampled_partial_group <> 6 then
    fail "resample partial edge-interval propagation";
  let line_point_id = Attribute.create_owned ~name:"line_point_id"
      ~owner:Attribute.Point (Attribute.Int [|10; 11; 12; 13|]) |> get_ok
  and line_corner_id = Attribute.create_owned ~name:"line_corner_id"
      ~owner:Attribute.Vertex (Attribute.Int [|0; 1; 2; 3; 4; 5|]) |> get_ok
  and line_face_id = Attribute.create_owned ~name:"line_face_id"
      ~owner:Attribute.Primitive (Attribute.Int [|20; 21|]) |> get_ok
  and line_detail_id = Attribute.create_owned ~name:"line_detail_id"
      ~owner:Attribute.Detail (Attribute.Int [|30|]) |> get_ok
  and line_points = Group.init ~owner:Group.Point ~name:"line_points" 4
      (fun point -> point land 1 = 0)
  and line_corners = Group.init ~owner:Group.Vertex ~name:"line_corners" 6
      (fun vertex -> vertex = 0)
  and line_faces = Group.init ~owner:Group.Primitive ~name:"line_faces" 2
      (fun primitive -> primitive = 1) in
  let line_source = Geometry.create ~positions
      ~topology:(Geometry.topology triangle_geometry)
      ~attributes:[line_point_id; line_corner_id; line_face_id; line_detail_id]
      ~groups:[line_points; line_corners; line_faces] () |> get_ok
      |> Group_mesh.group_edges ~name:"all_source_edges" |> get_ok in
  let line_index = Topology_index.create (Geometry.topology line_source) in
  let diagonal = Topology_index.find_edge line_index ~a:0 ~b:2 |> Option.get
  and top = Topology_index.find_edge line_index ~a:2 ~b:3 |> Option.get in
  let selected_lines = Edge_group.init ~topology:(Geometry.topology line_source)
      ~index:line_index ~name:"selected_lines"
      (fun edge -> edge = diagonal || edge = top) in
  let line_source = Geometry.with_edge_group selected_lines line_source |> get_ok in
  let converted domains = Parallel.run ~domains (fun () ->
    Curve_topology.convert_line ~grain:1 ~length_attribute:"length" line_source |> get_ok) in
  let converted_one = converted 1 and converted_many = converted 4 in
  let converted_topology = Topology.Private.view (Geometry.topology converted_one)
  and converted_many_topology = Topology.Private.view
      (Geometry.topology converted_many) in
  let line_lengths = Geometry.find_attribute ~owner:Attribute.Primitive "length"
      converted_one |> Option.get
      |> Attribute.get (Attribute.key ~name:"length"
           ~owner:Attribute.Primitive Attribute.float) |> Option.get in
  if converted_topology.vertex_points <> [|0;1; 0;2; 0;3; 1;2; 2;3|]
      || converted_topology.vertex_points <> converted_many_topology.vertex_points
      || Geometry.primitive_count converted_one <> 5
      || not (near_array [|1.; sqrt 2.; 1.; 1.; 1.|] line_lengths)
      || Geometry.positions converted_one != Geometry.positions line_source then
    fail "Convert Line ordering/cardinality/length/domain behavior";
  if Geometry.find_attribute ~owner:Attribute.Point "line_point_id" converted_one
       = None
      || Geometry.find_attribute ~owner:Attribute.Detail "line_detail_id"
           converted_one = None
      || Geometry.find_attribute ~owner:Attribute.Vertex "line_corner_id"
           converted_one <> None
      || Geometry.find_attribute ~owner:Attribute.Primitive "line_face_id"
           converted_one <> None
      || Geometry.find_group ~owner:Group.Point "line_points" converted_one = None
      || Geometry.find_group ~owner:Group.Vertex "line_corners" converted_one
           <> None
      || Geometry.find_group ~owner:Group.Primitive "line_faces" converted_one
           <> None then
    fail "Convert Line payload ownership policy";
  let selected_output = Geometry.find_edge_group "selected_lines" converted_one
      |> Option.get in
  if Edge_group.length selected_output <> 5
      || Edge_group.cardinality selected_output <> 2
      || not (Edge_group.mem 1 selected_output)
      || not (Edge_group.mem 4 selected_output) then
    fail "Convert Line native edge provenance";
  let connected_selected domains = Parallel.run ~domains (fun () ->
    Curve_topology.convert_line ~grain:1 ~edges:selected_lines ~connect_path:true
      ~maximum_distance:0. ~remove_unused_points:true
      ~length_attribute:"path_length" line_source |> get_ok) in
  let connected_one = connected_selected 1
  and connected_many = connected_selected 4 in
  let connected_topology = Topology.Private.view
      (Geometry.topology connected_one)
  and connected_many_topology = Topology.Private.view
      (Geometry.topology connected_many) in
  let path_lengths = Geometry.find_attribute ~owner:Attribute.Primitive
      "path_length" connected_one |> Option.get
      |> Attribute.get (Attribute.key ~name:"path_length"
           ~owner:Attribute.Primitive Attribute.float) |> Option.get in
  if connected_topology.vertex_points <> connected_many_topology.vertex_points
      || connected_topology.primitive_offsets
           <> connected_many_topology.primitive_offsets
      || not (Bytes.equal connected_topology.primitive_kinds
           connected_many_topology.primitive_kinds)
      || Geometry.point_count connected_one <> 3
      || Geometry.primitive_count connected_one <> 1
      || connected_topology.vertex_points <> [|0;1;2|]
      || not (near_array [|1. +. sqrt 2.|] path_lengths)
      || Geometry.find_attribute ~owner:Attribute.Point "line_point_id"
           connected_one = None
      || Geometry.find_attribute ~owner:Attribute.Detail "line_detail_id"
           connected_one = None
      || Geometry.find_attribute ~owner:Attribute.Vertex "line_corner_id"
           connected_one <> None
      || Geometry.find_attribute ~owner:Attribute.Primitive "line_face_id"
           connected_one <> None
      || Geometry.find_group ~owner:Group.Point "line_points" connected_one = None
      || Geometry.find_group ~owner:Group.Vertex "line_corners" connected_one
           <> None
      || Geometry.find_group ~owner:Group.Primitive "line_faces" connected_one
           <> None then
    fail "Convert Line connected-path topology/length/payload/domain behavior";
  let connected_edges = Geometry.find_edge_group "selected_lines" connected_one
      |> Option.get in
  if Edge_group.length connected_edges <> 2
      || Edge_group.cardinality connected_edges <> 2 then
    fail "Convert Line connected-path native edge provenance";
  let loop = Plane_generators.circle ~segments:8 ~radius:1. () |> get_ok in
  let open_loop = Curve_topology.convert_line ~connect_path:true ~maximum_distance:0. loop
      |> get_ok
  and closed_loop = Curve_topology.convert_line ~connect_path:true ~maximum_distance:0.
      ~make_isolated_loops_closed:true loop |> get_ok in
  if Geometry.primitive_count open_loop <> 1
      || Geometry.vertex_count open_loop <> 9
      || Topology.primitive_kind (Geometry.topology open_loop) 0
           <> Topology.Open_polyline
      || Geometry.primitive_count closed_loop <> 1
      || Geometry.vertex_count closed_loop <> 8
      || Topology.primitive_kind (Geometry.topology closed_loop) 0
           <> Topology.Polygon then
    fail "Convert Line isolated-loop path mode";
  let empty_lines = Edge_group.init ~topology:(Geometry.topology line_source)
      ~index:line_index ~name:"empty_lines" (fun _ -> false) in
  let empty_output = Curve_topology.convert_line ~edges:empty_lines ~connect_path:true
      line_source |> get_ok
  and empty_compact = Curve_topology.convert_line ~edges:empty_lines ~connect_path:true
      ~remove_unused_points:true line_source |> get_ok in
  if Geometry.point_count empty_output <> 4
      || Geometry.primitive_count empty_output <> 0
      || Geometry.point_count empty_compact <> 0
      || Geometry.primitive_count empty_compact <> 0 then
    fail "Convert Line empty path selection/compaction";
  (match Curve_topology.convert_line ~edges:middle_group line_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Convert Line accepted an edge group from another topology");
  let overflowing_line = Line_geometry.polyline
      [|(-.max_float,0.,0.); (max_float,0.,0.)|] |> get_ok in
  (match Curve_topology.convert_line ~length_attribute:"length" overflowing_line with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Convert Line published a non-finite length attribute");
  (match Curve_topology.convert_line ~connect_path:true ~maximum_distance:Float.nan
      line_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Convert Line path mode accepted a non-finite distance");
  (match Curve_topology.convert_line ~connect_path:true ~maximum_distance:(-1.) line_source
      with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Convert Line path mode accepted a negative distance");
  (match Curve_topology.convert_line ~connect_path:true ~length_attribute:" " line_source
      with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Convert Line path mode accepted an empty length name");
  let overflowing_path = Line_geometry.polyline
      [|(0.,0.,0.); (max_float,0.,0.); (0.,1.,0.)|] |> get_ok in
  (match Curve_topology.convert_line ~connect_path:true ~maximum_distance:0.
      ~length_attribute:"length" overflowing_path with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Convert Line published a non-finite accumulated path length");
  let cancelled_convert_path = Cancel.create () in
  Cancel.cancel cancelled_convert_path;
  (match Curve_topology.convert_line ~cancel:cancelled_convert_path ~connect_path:true
      line_source with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "cancelled Convert Line path mode published geometry");
  let carve_source = Line_geometry.polyline [|(0.,0.,0.); (1.,0.,0.); (3.,0.,0.);
      (6.,0.,0.)|] |> get_ok in
  let carve_weight = Attribute.create_owned ~name:"curve_weight"
      ~owner:Attribute.Point (Attribute.Float [|0.; 10.; 30.; 60.|]) |> get_ok
  and carve_vertex_id = Attribute.create_owned ~name:"corner_id"
      ~owner:Attribute.Vertex (Attribute.Int [|0; 1; 2; 3|]) |> get_ok in
  let carve_source = carve_source |> Geometry.with_attribute carve_weight |> get_ok
      |> Geometry.with_attribute carve_vertex_id |> get_ok in
  let carve_index = Topology_index.create (Geometry.topology carve_source) in
  let selected_middle_edge = Topology_index.find_edge carve_index ~a:1 ~b:2
      |> Option.get in
  let carve_edges = Edge_group.init ~topology:(Geometry.topology carve_source)
      ~index:carve_index ~name:"middle" (fun edge -> edge = selected_middle_edge) in
  let carve_source = Geometry.with_edge_group carve_edges carve_source |> get_ok in
  let carve_source_bytes = geometry_bytes carve_source in
  let carved domains = Parallel.run ~domains (fun () ->
    Curve_ops.carve_curves ~grain:1 ~first:0.2 ~last:0.6 carve_source |> get_ok) in
  let carved_one = carved 1 and carved_many = carved 4 in
  let carved_positions = Packed.Float3.Private.view (Geometry.positions carved_one) in
  check (geometry_bytes carved_one = geometry_bytes carved_many
      && near_array [|1.2;3.;3.6|] carved_positions.x
      && Geometry.vertex_count carved_one = 3
      && Geometry.primitive_count carved_one = 1)
    "Curve Carve arc-length endpoints/topology/complete domain exactness";
  let carved_edge_group = Geometry.find_edge_group "middle" carved_one
      |> Option.get in
  if Edge_group.length carved_edge_group <> 2
      || Edge_group.cardinality carved_edge_group <> 1 then
    fail "Curve Carve native edge-interval propagation";
  let parameter_carved = Curve_ops.carve_curves ~relative_arc_length:false
      ~first:0.25 ~last:0.75 carve_source |> get_ok in
  let parameter_positions = Packed.Float3.Private.view
      (Geometry.positions parameter_carved) in
  if not (near_array [|0.75; 1.; 3.; 3.75|] parameter_positions.x) then
    fail "Curve Carve uniform-edge parameterization";
  let breakpoint_carved domains = Parallel.run ~domains (fun () ->
    Curve_ops.carve_curves ~grain:1 ~relative_arc_length:false ~first:0.2 ~last:0.8
      ~only_at_breakpoints:true carve_source |> get_ok) in
  let breakpoint_one = breakpoint_carved 1
  and breakpoint_many = breakpoint_carved 4 in
  check (geometry_bytes breakpoint_one = geometry_bytes breakpoint_many
      && (Packed.Float3.Private.view (Geometry.positions breakpoint_one)).x = [|1.;3.|]
      && Geometry.vertex_count breakpoint_one = 2
      && Geometry.primitive_count breakpoint_one = 1)
    "Curve Carve breakpoint-only endpoints/topology/domain exactness";
  let breakpoint_segments domains = Parallel.run ~domains (fun () ->
    Curve_ops.carve_curves ~grain:1 ~relative_arc_length:false ~first:0. ~last:1.
      ~only_at_breakpoints:true ~cut_at_all_internal_breakpoints:true
      carve_source |> get_ok) in
  let segments_one = breakpoint_segments 1
  and segments_many = breakpoint_segments 4 in
  let segment_topology = Topology.Private.view (Geometry.topology segments_one)
  and segment_positions = Packed.Float3.Private.view
      (Geometry.positions segments_one) in
  if Geometry.primitive_count segments_one <> 3
      || Geometry.vertex_count segments_one <> 6
      || segment_topology.primitive_offsets <> [|0;2;4;6|]
      || not (near_array [|0.;1.; 1.;3.; 3.;6.|] segment_positions.x)
      || not (equal_positions segments_one segments_many)
      || Edge_group.cardinality (Geometry.find_edge_group "middle" segments_one
           |> Option.get) <> 1 then
    fail "Curve Carve cut-at-all polygon breakpoints/domain behavior";
  let breakpoint_extract = Curve_ops.carve_curves ~relative_arc_length:false
      ~first:0.1 ~last:1. ~only_at_breakpoints:true ~extract_points:true
      ~divisions:99 carve_source |> get_ok
  and all_breakpoint_extract = Curve_ops.carve_curves ~relative_arc_length:false
      ~first:0.1 ~last:1. ~only_at_breakpoints:true
      ~cut_at_all_internal_breakpoints:true ~extract_points:true ~divisions:99
      carve_source |> get_ok in
  let breakpoint_extract_positions = Packed.Float3.Private.view
      (Geometry.positions breakpoint_extract)
  and all_breakpoint_extract_positions = Packed.Float3.Private.view
      (Geometry.positions all_breakpoint_extract) in
  if Geometry.primitive_count breakpoint_extract <> 0
      || not (near_array [|1.;6.|] breakpoint_extract_positions.x)
      || not (near_array [|1.;3.;6.|] all_breakpoint_extract_positions.x) then
    fail "Curve Carve breakpoint extraction outer/all behavior";
  let breakpoint_outside = Curve_ops.carve_curves ~relative_arc_length:false
      ~first:0.2 ~last:0.8 ~only_at_breakpoints:true
      ~keep:Curve_ops.Outside carve_source |> get_ok in
  let breakpoint_outside_positions = Packed.Float3.Private.view
      (Geometry.positions breakpoint_outside) in
  if Geometry.primitive_count breakpoint_outside <> 2
      || not (near_array [|0.;1.; 3.;6.|] breakpoint_outside_positions.x)
      || Edge_group.cardinality (Geometry.find_edge_group "middle"
           breakpoint_outside |> Option.get) <> 0 then
    fail "Curve Carve breakpoint outside pieces";
  let empty_breakpoint_inside = Curve_ops.carve_curves ~relative_arc_length:false
      ~first:0.34 ~last:0.6 ~only_at_breakpoints:true carve_source |> get_ok
  and empty_breakpoint_outside = Curve_ops.carve_curves ~relative_arc_length:false
      ~first:0.34 ~last:0.6 ~only_at_breakpoints:true
      ~keep:Curve_ops.Outside carve_source |> get_ok in
  if Geometry.point_count empty_breakpoint_inside <> 0
      || Geometry.primitive_count empty_breakpoint_inside <> 0
      || not (equal_positions empty_breakpoint_outside carve_source)
      || (Topology.Private.view (Geometry.topology empty_breakpoint_outside)).vertex_points
           <> (Topology.Private.view (Geometry.topology carve_source)).vertex_points then
    fail "Curve Carve empty breakpoint interval behavior";
  let arc_breakpoints = Curve_ops.carve_curves ~first:0.1 ~last:0.9
      ~only_at_breakpoints:true carve_source |> get_ok in
  if not (near_array [|1.;3.|]
      (Packed.Float3.Private.view (Geometry.positions arc_breakpoints)).x) then
    fail "Curve Carve relative-arc breakpoint interval";
  let mixed_positions = Packed.Float3.Private.of_owned_exn
      ~x:[|0.;1.;2.;3.; 0.;1.;0.; 5.;6.;5.5|]
      ~y:[|0.;0.;0.;0.; 2.;2.;3.; 2.;2.;3.|] ~z:(Array.make 10 0.) in
  let mixed_topology = Topology.create_owned ~point_count:10
      ~vertex_points:[|0;1;2;3; 4;5;6; 7;8;9|]
      ~primitive_offsets:[|0;4;7;10|]
      ~primitive_kinds:[|Topology.Open_polyline; Topology.Polygon;
        Topology.Closed_polyline|] |> get_ok in
  let mixed_point_id = Attribute.create_owned ~name:"mixed_point"
      ~owner:Attribute.Point (Attribute.Int (Array.init 10 Fun.id)) |> get_ok
  and mixed_vertex_id = Attribute.create_owned ~name:"mixed_vertex"
      ~owner:Attribute.Vertex (Attribute.Int (Array.init 10 Fun.id)) |> get_ok
  and mixed_primitive_id = Attribute.create_owned ~name:"mixed_primitive"
      ~owner:Attribute.Primitive (Attribute.Int [|10;20;30|]) |> get_ok
  and mixed_first_u = Attribute.create_owned ~name:"first_u"
      ~owner:Attribute.Primitive (Attribute.Float [|0.25;Float.nan;Float.nan|])
      |> get_ok
  and mixed_second_u = Attribute.create_owned ~name:"second_u"
      ~owner:Attribute.Primitive (Attribute.Float [|0.5;Float.nan;Float.nan|])
      |> get_ok
  and mixed_even = Group.init ~owner:Group.Point ~name:"mixed_even" 10
      (fun point -> point land 1 = 0)
  and carve_first = Group.init ~owner:Group.Primitive ~name:"carve_first" 3
      (fun primitive -> primitive = 0) in
  let mixed = Geometry.create ~positions:mixed_positions ~topology:mixed_topology
      ~attributes:[mixed_point_id; mixed_vertex_id; mixed_primitive_id;
        mixed_first_u; mixed_second_u]
      ~groups:[mixed_even; carve_first] () |> get_ok
      |> Group_mesh.group_edges ~name:"mixed_edges" |> get_ok in
  let mixed_bytes = geometry_bytes mixed in
  let mixed_carved domains = Parallel.run ~domains (fun () ->
    Curve_ops.carve_curves ~grain:1 ~primitives:carve_first
      ~relative_arc_length:false ~first:0.25 ~last:0.75 mixed |> get_ok) in
  let mixed_one = mixed_carved 1 and mixed_many = mixed_carved 4 in
  let mixed_view = Topology.Private.view (Geometry.topology mixed_one)
  and mixed_result_positions = Packed.Float3.Private.view
      (Geometry.positions mixed_one) in
  check (geometry_bytes mixed_one = geometry_bytes mixed_many
      && Geometry.point_count mixed_one = 14
      && mixed_view.vertex_points = [|10;11;12;13;4;5;6;7;8;9|]
      && mixed_view.primitive_offsets = [|0;4;7;10|]
      && Array.sub mixed_result_positions.x 10 4 = [|0.75;1.;2.;2.25|])
    "Curve Carve mixed topology/endpoints/complete domain exactness";
  let mixed_edges = Geometry.find_edge_group "mixed_edges" mixed_one
      |> Option.get
  and mixed_even_output = Geometry.find_group ~owner:Group.Point "mixed_even"
      mixed_one |> Option.get in
  if Edge_group.length mixed_edges <> 9
      || Edge_group.cardinality mixed_edges <> 9
      || Group.length mixed_even_output <> 14
      || Group.cardinality mixed_even_output <> 7 then
    fail "Curve Carve mixed selection group/native-edge ancestry";
  let attributed_carve domains = Parallel.run ~domains (fun () ->
    Curve_ops.carve_curves ~grain:1 ~primitives:carve_first
      ~relative_arc_length:false ~first:0. ~last:1.
      ~first_attribute:"first_u" ~last_attribute:"second_u" mixed |> get_ok) in
  let attributed_one = attributed_carve 1
  and attributed_many = attributed_carve 4 in
  let attributed_topology = Topology.Private.view
      (Geometry.topology attributed_one)
  and attributed_many_topology = Topology.Private.view
      (Geometry.topology attributed_many)
  and attributed_positions = Packed.Float3.Private.view
      (Geometry.positions attributed_one) in
  if Geometry.point_count attributed_one <> 13
      || Geometry.vertex_count attributed_one <> 9
      || attributed_topology.primitive_offsets <> [|0;3;6;9|]
      || attributed_topology.vertex_points <> [|10;11;12; 4;5;6; 7;8;9|]
      || attributed_topology.vertex_points
           <> attributed_many_topology.vertex_points
      || not (equal_positions attributed_one attributed_many)
      || not (near_array [|0.75;1.;1.5|]
           (Array.sub attributed_positions.x 10 3)) then
    fail "Curve Carve primitive parameter replace/domain behavior";
  let scaled_carve = Curve_ops.carve_curves ~primitives:carve_first
      ~relative_arc_length:false ~first:0.5 ~last:1.
      ~first_attribute:"first_u" ~last_attribute:"second_u"
      ~attribute_mode:Curve_ops.Scale mixed |> get_ok in
  let scaled_positions = Packed.Float3.Private.view
      (Geometry.positions scaled_carve) in
  if Geometry.point_count scaled_carve <> 13
      || not (near_array [|0.375;1.;1.5|]
           (Array.sub scaled_positions.x 10 3))
      || (Topology.Private.view (Geometry.topology scaled_carve)).vertex_points
           <> [|10;11;12; 4;5;6; 7;8;9|] then
    fail "Curve Carve primitive parameter scale behavior";
  let attributed_extract domains = Parallel.run ~domains (fun () ->
    Curve_ops.carve_curves ~grain:1 ~primitives:carve_first
      ~relative_arc_length:false ~first_attribute:"first_u"
      ~last_attribute:"second_u" ~extract_points:true ~divisions:2 mixed
      |> get_ok) in
  let attributed_extract_one = attributed_extract 1
  and attributed_extract_many = attributed_extract 4 in
  let attributed_extract_positions = Packed.Float3.Private.view
      (Geometry.positions attributed_extract_one) in
  if Geometry.point_count attributed_extract_one <> 12
      || Geometry.vertex_count attributed_extract_one <> 6
      || Geometry.primitive_count attributed_extract_one <> 2
      || not (near_array [|0.75;1.5|]
           (Array.sub attributed_extract_positions.x 10 2))
      || not (equal_positions attributed_extract_one attributed_extract_many)
      || (Topology.Private.view (Geometry.topology attributed_extract_one)).vertex_points
           <> (Topology.Private.view
                 (Geometry.topology attributed_extract_many)).vertex_points then
    fail "Curve Carve primitive parameter extraction/domain behavior";
  let attributed_pieces = Curve_ops.carve_curves ~primitives:carve_first
      ~relative_arc_length:false ~first_attribute:"first_u"
      ~last_attribute:"second_u" ~keep:Curve_ops.Inside_and_outside mixed
      |> get_ok in
  let attributed_piece_topology = Topology.Private.view
      (Geometry.topology attributed_pieces) in
  if Geometry.primitive_count attributed_pieces <> 5
      || Geometry.vertex_count attributed_pieces <> 14
      || attributed_piece_topology.primitive_offsets <> [|0;2;5;8;11;14|]
  then fail "Curve Carve primitive parameters on all cut pieces";
  (match Curve_ops.carve_curves ~primitives:carve_first
      ~first_attribute:"missing" mixed with
   | Error error when Error.code error = "invalid_geometry"
       && String.length (Error.message error) > 0 -> ()
   | _ -> fail "Curve Carve accepted a missing primitive parameter attribute");
  (match Curve_ops.carve_curves ~primitives:carve_first
      ~first_attribute:"mixed_primitive" mixed with
   | Error error when Error.code error = "invalid_geometry"
       && String.length (Error.message error) > 0 -> ()
   | _ -> fail "Curve Carve accepted a non-float primitive parameter attribute");
  (match Curve_ops.carve_curves ~primitives:carve_first
      ~first_attribute:"mixed_point" mixed with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Carve accepted a point parameter attribute");
  let carve_closed = Group.init ~owner:Group.Primitive ~name:"carve_closed" 3
      (fun primitive -> primitive = 2) in
  (match Curve_ops.carve_curves ~primitives:carve_closed
      ~first_attribute:"first_u" ~last_attribute:"second_u" mixed with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Carve accepted a selected non-finite parameter");
  let attributed_breakpoint = Curve_ops.carve_curves ~primitives:carve_first
      ~relative_arc_length:false ~first_attribute:"first_u"
      ~last_attribute:"second_u" ~only_at_breakpoints:true
      ~extract_points:true mixed |> get_ok in
  if not (near_array [|1.|]
      (Array.sub (Packed.Float3.Private.view
        (Geometry.positions attributed_breakpoint)).x 10 1)) then
    fail "Curve Carve primitive attributes with breakpoint extraction";
  let carve_none = Group.init ~owner:Group.Primitive ~name:"carve_none" 3
      (fun _ -> false) in
  if (Curve_ops.carve_curves ~primitives:carve_none ~first:0.2 ~last:0.8 mixed
      |> get_ok) != mixed then
    fail "Curve Carve empty selection did not preserve identity";
  let carve_polygon = Group.init ~owner:Group.Primitive ~name:"carve_polygon" 3
      (fun primitive -> primitive = 1) in
  (match Curve_ops.carve_curves ~primitives:carve_polygon ~first:0.2 ~last:0.8 mixed with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Carve accepted a selected polygon");
  (match Curve_ops.carve_curves ~primitives:mixed_even ~first:0.2 ~last:0.8 mixed with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Carve accepted a point selection");
  let short_primitive_group = Group.init ~owner:Group.Primitive ~name:"short" 2
      (fun _ -> true) in
  (match Curve_ops.carve_curves ~primitives:short_primitive_group ~first:0.2 ~last:0.8
      mixed with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Carve accepted a mismatched primitive selection");
  (match Curve_ops.carve_curves ~grain:0 ~first:0.2 ~last:0.8 carve_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Carve accepted zero grain");
  let extreme_carve = Line_geometry.polyline
      [|(-5e307,0.,0.); (5e307,0.,0.)|] |> get_ok
      |> Curve_ops.carve_curves ~first:0.25 ~last:0.75 |> get_ok in
  let extreme_positions = Packed.Float3.Private.view
      (Geometry.positions extreme_carve) in
  if not (near_array [|(-2.5e307);2.5e307|] extreme_positions.x) then
    fail "Curve Carve did not preserve a representable extreme interpolation";
  let overflowing_carve = Line_geometry.polyline
      [|(-.max_float,0.,0.); (max_float,0.,0.)|] |> get_ok in
  (match Curve_ops.carve_curves ~first:0.25 ~last:0.75 overflowing_carve with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Carve accepted an unrepresentable segment length");
  let extracted domains = Parallel.run ~domains (fun () ->
    Curve_ops.carve_curves ~grain:1 ~primitives:carve_first
      ~relative_arc_length:false ~first:0.25 ~last:0.75
      ~extract_points:true ~divisions:3 mixed |> get_ok) in
  let extracted_one = extracted 1 and extracted_many = extracted 4 in
  let extracted_topology = Topology.Private.view
      (Geometry.topology extracted_one)
  and extracted_positions = Packed.Float3.Private.view
      (Geometry.positions extracted_one) in
  check (geometry_bytes extracted_one = geometry_bytes extracted_many
      && Geometry.point_count extracted_one = 13
      && extracted_topology.vertex_points = [|4;5;6;7;8;9|]
      && extracted_topology.primitive_offsets = [|0;3;6|]
      && Array.sub extracted_positions.x 10 3 = [|0.75;1.5;2.25|])
    "Curve Carve extraction samples/unselected topology/domain exactness";
  let extracted_edges = Geometry.find_edge_group "mixed_edges" extracted_one
      |> Option.get in
  if Edge_group.length extracted_edges <> 6
      || Edge_group.cardinality extracted_edges <> 6 then
    fail "Curve Carve point extraction unselected edge ancestry";
  let extracted_kept = Curve_ops.carve_curves ~primitives:carve_first
      ~relative_arc_length:false ~first:0.25 ~last:0.75
      ~extract_points:true ~divisions:3 ~keep_original:true mixed |> get_ok in
  if Geometry.point_count extracted_kept <> 13
      || Geometry.primitive_count extracted_kept <> 3
      || Geometry.vertex_count extracted_kept <> 10
      || Edge_group.cardinality (Geometry.find_edge_group "mixed_edges"
           extracted_kept |> Option.get) <> 9 then
    fail "Curve Carve point extraction keep-original behavior";
  let extracted_only = Curve_ops.carve_curves ~relative_arc_length:false
      ~first:0. ~last:1. ~extract_points:true ~divisions:4 carve_source
      |> get_ok in
  if Geometry.point_count extracted_only <> 4
      || Geometry.vertex_count extracted_only <> 0
      || Geometry.primitive_count extracted_only <> 0
      || Attribute.length (Geometry.find_attribute ~owner:Attribute.Vertex
           "corner_id" extracted_only |> Option.get) <> 0
      || Edge_group.length (Geometry.find_edge_group "middle" extracted_only
           |> Option.get) <> 0 then
    fail "Curve Carve extraction-only empty topology/payload";
  let repeated_extract = Curve_ops.carve_curves ~relative_arc_length:false
      ~first:0.5 ~last:0.5
      ~extract_points:true ~divisions:2 carve_source |> get_ok in
  let repeated_positions = Packed.Float3.Private.view
      (Geometry.positions repeated_extract) in
  if not (near_array [|2.;2.|] repeated_positions.x) then
    fail "Curve Carve repeated single-parameter extraction";
  (match Curve_ops.carve_curves ~extract_points:true ~divisions:0 carve_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Carve extraction accepted zero divisions");
  let outside = Curve_ops.carve_curves ~relative_arc_length:false ~first:0.25
      ~last:0.75 ~keep:Curve_ops.Outside carve_source |> get_ok in
  let outside_topology = Topology.Private.view (Geometry.topology outside)
  and outside_positions = Packed.Float3.Private.view (Geometry.positions outside) in
  if Geometry.primitive_count outside <> 2
      || outside_topology.primitive_offsets <> [|0;2;4|]
      || not (near_array [|0.;0.75;3.75;6.|] outside_positions.x) then
    fail "Curve Carve keep-outside open pieces";
  let all_pieces domains = Parallel.run ~domains (fun () ->
    Curve_ops.carve_curves ~grain:1 ~relative_arc_length:false ~first:0.25 ~last:0.75
      ~keep:Curve_ops.Inside_and_outside carve_source |> get_ok) in
  let pieces_one = all_pieces 1 and pieces_many = all_pieces 4 in
  let pieces_topology = Topology.Private.view (Geometry.topology pieces_one)
  and pieces_many_topology = Topology.Private.view (Geometry.topology pieces_many)
  and pieces_positions = Packed.Float3.Private.view (Geometry.positions pieces_one) in
  if Geometry.primitive_count pieces_one <> 3
      || pieces_topology.primitive_offsets <> [|0;2;6;8|]
      || pieces_topology.vertex_points <> pieces_many_topology.vertex_points
      || not (near_array [|0.;0.75; 0.75;1.;3.;3.75; 3.75;6.|]
           pieces_positions.x)
      || Edge_group.length (Geometry.find_edge_group "middle" pieces_one
           |> Option.get) <> 5
      || Edge_group.cardinality (Geometry.find_edge_group "middle" pieces_one
           |> Option.get) <> 1 then
    fail "Curve Carve keep-inside-and-outside topology/edge/domain behavior";
  let divided_inside domains = Parallel.run ~domains (fun () ->
    Curve_ops.carve_curves ~grain:1 ~relative_arc_length:false ~first:0.25 ~last:0.75
      ~divisions:3 carve_source |> get_ok) in
  let divided_one = divided_inside 1 and divided_many = divided_inside 4 in
  let divided_topology = Topology.Private.view (Geometry.topology divided_one)
  and divided_positions = Packed.Float3.Private.view
      (Geometry.positions divided_one) in
  check (geometry_bytes divided_one = geometry_bytes divided_many
      && divided_topology.primitive_offsets = [|0;3;5;8|]
      && near_array [|0.75;1.;1.5;1.5;2.5;2.5;3.;3.75|] divided_positions.x)
    "Curve Carve divided interval ordering/topology/domain exactness";
  let divided_edges = Geometry.find_edge_group "middle" divided_one
      |> Option.get
  and divided_edges_many = Geometry.find_edge_group "middle" divided_many
      |> Option.get in
  let divided_edge_members_equal = ref
      (Edge_group.length divided_edges = Edge_group.length divided_edges_many) in
  for edge = 0 to Edge_group.length divided_edges - 1 do
    if Edge_group.mem edge divided_edges <> Edge_group.mem edge divided_edges_many
    then divided_edge_members_equal := false
  done;
  check !divided_edge_members_equal
    "Curve Carve divided edge membership differs by domain count";
  let divided_all = Curve_ops.carve_curves ~relative_arc_length:false ~first:0.25
      ~last:0.75 ~divisions:3 ~keep:Curve_ops.Inside_and_outside carve_source
      |> get_ok in
  if Geometry.primitive_count divided_all <> 5
      || (Topology.Private.view (Geometry.topology divided_all)).primitive_offsets
           <> [|0;2;5;7;10;12|]
      || not (near_array
           [|0.;0.75; 0.75;1.;1.5; 1.5;2.5; 2.5;3.;3.75; 3.75;6.|]
           (Packed.Float3.Private.view (Geometry.positions divided_all)).x) then
    fail "Curve Carve divided inside-and-outside ordering";
  (match Curve_ops.carve_curves ~divisions:0 carve_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Carve cut accepted zero divisions");
  let closed_cut_source = Line_geometry.polyline ~closed:true [|(0.,0.,0.); (1.,0.,0.);
      (1.,1.,0.); (0.,1.,0.)|] |> get_ok
      |> Group_mesh.group_edges ~name:"closed_cut_edges" |> get_ok in
  let closed_outside = Curve_ops.carve_curves ~relative_arc_length:false ~first:0.25
      ~last:0.75 ~keep:Curve_ops.Outside closed_cut_source |> get_ok in
  let closed_outside_topology = Topology.Private.view
      (Geometry.topology closed_outside) in
  if Geometry.primitive_count closed_outside <> 1
      || closed_outside_topology.vertex_points <> [|0;1;2|]
      || Geometry.vertex_count closed_outside <> 3
      || Edge_group.cardinality (Geometry.find_edge_group "closed_cut_edges"
           closed_outside |> Option.get) <> 2 then
    fail "Curve Carve closed complement seam path";
  let closed_all = Curve_ops.carve_curves ~relative_arc_length:false ~first:0.25
      ~last:0.75 ~keep:Curve_ops.Inside_and_outside closed_cut_source |> get_ok in
  if Geometry.primitive_count closed_all <> 2
      || Geometry.vertex_count closed_all <> 6
      || Edge_group.cardinality (Geometry.find_edge_group "closed_cut_edges"
           closed_all |> Option.get) <> 4 then
    fail "Curve Carve closed inside/complement pieces";
  let closed_breakpoint_outside = Curve_ops.carve_curves
      ~relative_arc_length:false ~first:0.2 ~last:0.8
      ~only_at_breakpoints:true ~keep:Curve_ops.Outside closed_cut_source
      |> get_ok in
  let closed_breakpoint_topology = Topology.Private.view
      (Geometry.topology closed_breakpoint_outside) in
  if Geometry.primitive_count closed_breakpoint_outside <> 1
      || closed_breakpoint_topology.vertex_points <> [|0;1;2|]
      || Edge_group.cardinality (Geometry.find_edge_group "closed_cut_edges"
           closed_breakpoint_outside |> Option.get) <> 2 then
    fail "Curve Carve closed breakpoint seam complement";
  let closed_breakpoint_edges = Curve_ops.carve_curves
      ~relative_arc_length:false ~first:0.2 ~last:0.8
      ~only_at_breakpoints:true ~cut_at_all_internal_breakpoints:true
      ~keep:Curve_ops.Outside closed_cut_source |> get_ok in
  if Geometry.primitive_count closed_breakpoint_edges <> 2
      || Geometry.vertex_count closed_breakpoint_edges <> 4
      || Edge_group.cardinality (Geometry.find_edge_group "closed_cut_edges"
           closed_breakpoint_edges |> Option.get) <> 2 then
    fail "Curve Carve closed cut-at-all breakpoint complement";
  let mixed_outside = Curve_ops.carve_curves ~primitives:carve_first
      ~relative_arc_length:false ~first:0.25 ~last:0.75
      ~keep:Curve_ops.Outside mixed |> get_ok in
  let mixed_outside_group = Geometry.find_group ~owner:Group.Primitive
      "carve_first" mixed_outside |> Option.get
  and mixed_outside_edges = Geometry.find_edge_group "mixed_edges" mixed_outside
      |> Option.get in
  check (Geometry.primitive_count mixed_outside = 4
      && geometry_bytes carve_source = carve_source_bytes
      && geometry_bytes mixed = mixed_bytes
      && Group.length mixed_outside_group = 4
      && Group.cardinality mixed_outside_group = 2
      && Group.mem 0 mixed_outside_group && Group.mem 1 mixed_outside_group
      && Edge_group.length mixed_outside_edges = 8
      && Edge_group.cardinality mixed_outside_edges = 8)
    "Curve Carve outside intervals retain ordinary/native-edge ancestry";
  let join_positions = Packed.Float3.Private.of_owned_exn
      ~x:[|0.; 1.; 2.; 3.; 4.; 10.; 11.|]
      ~y:(Array.make 7 0.) ~z:(Array.make 7 0.) in
  let join_topology = Tb.create ~point_count:7 () in
  Tb.add_open_polyline join_topology [|0; 1; 2|];
  Tb.add_open_polyline join_topology [|4; 3; 2|];
  Tb.add_open_polyline join_topology [|5; 6|];
  let join_corner_id = Attribute.create_owned ~name:"join_corner"
      ~owner:Attribute.Vertex (Attribute.Int (Array.init 8 Fun.id)) |> get_ok
  and join_piece = Attribute.create_owned ~name:"join_piece"
      ~owner:Attribute.Primitive (Attribute.Int [|10; 20; 30|]) |> get_ok
  and join_tagged = Group.init ~owner:Group.Primitive ~name:"tagged" 3
      (fun primitive -> primitive = 1) in
  let join_source = Geometry.create ~positions:join_positions
      ~topology:(Tb.freeze join_topology)
      ~attributes:[join_corner_id; join_piece] ~groups:[join_tagged] () |> get_ok
      |> Group_mesh.group_edges ~name:"join_edges" |> get_ok in
  let join_source_bytes = geometry_bytes join_source in
  let joined domains = Parallel.run ~domains (fun () ->
    Curve_topology.join_curves ~grain:1 join_source |> get_ok) in
  let joined_one = joined 1 and joined_many = joined 4 in
  let joined_topology = Topology.Private.view (Geometry.topology joined_one) in
  check (geometry_bytes joined_one = geometry_bytes joined_many
      && joined_topology.vertex_points = [|0;1;2;3;4;5;6|]
      && joined_topology.primitive_offsets = [|0;7|]
      && Attribute.storage (Geometry.find_attribute ~owner:Attribute.Vertex
          "join_corner" joined_one |> Option.get) = Attribute.Int [|0;1;2;4;3;6;7|])
    "Curve Join orientation/shared endpoint/corner ancestry/domain exactness";
  (match Geometry.find_group ~owner:Group.Primitive "tagged" joined_one with
   | Some group when Group.cardinality group = 1 -> ()
   | _ -> fail "Curve Join primitive-group union policy");
  let joined_edges = Geometry.find_edge_group "join_edges" joined_one
      |> Option.get in
  if Edge_group.length joined_edges <> 6
      || Edge_group.cardinality joined_edges <> 5 then
    fail "Curve Join original/generated native edge policy";
  let connected_only = Curve_topology.join_curves ~only_connected:true join_source |> get_ok in
  if Geometry.primitive_count connected_only <> 2
      || Geometry.vertex_count connected_only <> 7 then
    fail "Curve Join only-connected chain partition";
  let closest_positions = Packed.Float3.Private.of_owned_exn
      ~x:[|0.;1.; 10.;11.; 3.;2.; 12.;11.|]
      ~y:(Array.make 8 0.) ~z:(Array.make 8 0.) in
  let closest_topology = Tb.create ~point_count:8 () in
  Tb.add_open_polyline closest_topology [|0;1|];
  Tb.add_open_polyline closest_topology [|2;3|];
  Tb.add_open_polyline closest_topology [|4;5|];
  Tb.add_open_polyline closest_topology [|6;7|];
  let closest_corner = Attribute.create_owned ~name:"closest_corner"
      ~owner:Attribute.Vertex (Attribute.Int (Array.init 8 Fun.id)) |> get_ok
  and closest_piece = Attribute.create_owned ~name:"closest_piece"
      ~owner:Attribute.Primitive (Attribute.Int [|10;20;30;40|]) |> get_ok in
  let closest_source = Geometry.create ~positions:closest_positions
      ~topology:(Tb.freeze closest_topology)
      ~attributes:[closest_corner; closest_piece] () |> get_ok
      |> Group_mesh.group_edges ~name:"closest_edges" |> get_ok in
  let closest_source_bytes = geometry_bytes closest_source in
  let globally_joined domains = Parallel.run ~domains (fun () ->
      Curve_topology.join_curves ~grain:1 ~connect_closest_ends:true closest_source
      |> get_ok) in
  let globally_joined_one = globally_joined 1
  and globally_joined_many = globally_joined 4 in
  let globally_joined_topology = Topology.Private.view
      (Geometry.topology globally_joined_one) in
  check (geometry_bytes globally_joined_one = geometry_bytes globally_joined_many
      && globally_joined_topology.vertex_points = [|0;1;5;4;2;3;6|]
      && globally_joined_topology.primitive_offsets = [|0;7|])
    "Curve Join closest ends/connected seam/domain exactness";
  let closest_components = Curve_topology.join_curves ~connect_closest_ends:true
      ~only_connected:true ~tolerance:0. closest_source |> get_ok in
  if Geometry.primitive_count closest_components <> 3
      || Geometry.vertex_count closest_components <> 7 then
    fail "Curve Join global closest-end connected-component partition";
  let closest_subgroups = Curve_topology.join_curves ~connect_closest_ends:true
      ~group_size:2 closest_source |> get_ok in
  let closest_subgroup_topology = Topology.Private.view
      (Geometry.topology closest_subgroups) in
  if Geometry.primitive_count closest_subgroups <> 2
      || closest_subgroup_topology.primitive_offsets <> [|0;4;7|]
      || closest_subgroup_topology.vertex_points <> [|0;1;5;4;2;3;6|] then
    fail "Curve Join global closest-end fixed subgroup policy";
  let authored_order = Group.ordered ~owner:Group.Primitive
      ~name:"authored_order" ~length:4 [|2;0;3|] |> get_ok in
  let authored_join = Curve_topology.join_curves ~primitives:authored_order
      ~orient_closest:false closest_source |> get_ok in
  let authored_topology = Topology.Private.view
      (Geometry.topology authored_join) in
  if authored_topology.primitive_offsets <> [|0;2;8|]
      || authored_topology.vertex_points <> [|2;3;4;5;0;1;6;7|] then
    fail "Curve Join ignored ordered primitive-group traversal";
  let picked_ends = [|
      { Curve_topology.primitive = 2; end_ = Curve_topology.Join_curve_start };
      { Curve_topology.primitive = 0; end_ = Curve_topology.Join_curve_start };
      { Curve_topology.primitive = 3; end_ = Curve_topology.Join_curve_end };
    |] in
  let picked_join domains = Parallel.run ~domains (fun () ->
    Curve_topology.join_curves ~grain:1 ~picked_ends closest_source |> get_ok) in
  let picked_one = picked_join 1 and picked_many = picked_join 4 in
  let picked_topology = Topology.Private.view (Geometry.topology picked_one) in
  check (geometry_bytes picked_one = geometry_bytes picked_many
      && picked_topology.vertex_points = [|2;3;5;4;0;1;7;6|]
      && picked_topology.primitive_offsets = [|0;2;8|])
    "Curve Join picked ends preserve unselected curves/orientation/domain exactness";
  let picked_subgroups = Curve_topology.join_curves ~picked_ends ~group_size:2
      closest_source |> get_ok in
  let picked_subgroup_topology = Topology.Private.view
      (Geometry.topology picked_subgroups) in
  if picked_subgroup_topology.primitive_offsets <> [|0;2;6;8|]
      || picked_subgroup_topology.vertex_points <> [|2;3;5;4;0;1;6;7|] then
    fail "Curve Join picked subgroup-root outgoing-end behavior";
  if (Curve_topology.join_curves ~picked_ends:[||] closest_source |> get_ok) != closest_source
  then fail "Curve Join rebuilt an empty picked-end selection";
  (match Curve_topology.join_curves ~primitives:authored_order ~picked_ends closest_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Join accepted primitive selection with picked ends");
  (match Curve_topology.join_curves ~picked_ends ~connect_closest_ends:true closest_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Join accepted picked ends with closest-end ordering");
  (match Curve_topology.join_curves ~picked_ends:[|
      { Curve_topology.primitive = 1; end_ = Curve_topology.Join_curve_start };
      { Curve_topology.primitive = 1; end_ = Curve_topology.Join_curve_end }|] closest_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Join accepted a duplicate picked primitive");
  (match Curve_topology.join_curves ~picked_ends:[|
      { Curve_topology.primitive = 4; end_ = Curve_topology.Join_curve_start }|] closest_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Join accepted an out-of-bounds picked primitive");
  let ordered_subgroups = Curve_topology.join_curves ~group_size:2 closest_source |> get_ok in
  let ordered_subgroup_topology = Topology.Private.view
      (Geometry.topology ordered_subgroups) in
  if ordered_subgroup_topology.primitive_offsets <> [|0;4;8|]
      || ordered_subgroup_topology.vertex_points <> [|0;1;2;3;5;4;7;6|] then
    fail "Curve Join input-order subgroup root/continuation orientation";
  let retained_join = Curve_topology.join_curves ~keep_originals:true join_source |> get_ok in
  (match Geometry.find_group ~owner:Group.Primitive "tagged" retained_join with
   | Some group when Group.cardinality group = 2
       && Group.mem 1 group && Group.mem 3 group -> ()
   | _ -> fail "Curve Join Keep Primitives group union ancestry");
  let retained_edges = Geometry.find_edge_group "join_edges" retained_join
      |> Option.get in
  if Edge_group.length retained_edges <> 6
      || Edge_group.cardinality retained_edges <> 5 then
    fail "Curve Join Keep Primitives native-edge ancestry";
  (match Curve_topology.join_curves ~group_size:0 join_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Join accepted a non-positive subgroup size");
  let random_curve_count = 257 and random_point_count = 514 in
  let random_x = Array.make random_point_count 0.
  and random_y = Array.make random_point_count 0.
  and random_z = Array.make random_point_count 0. in
  for primitive = 0 to random_curve_count - 1 do
    let base = float_of_int primitive *. 1e-4 in
    let x = float_of_int ((primitive * 97) mod 257) +. base
    and y = float_of_int ((primitive * 53) mod 251) +. (base *. 0.7)
    and z = float_of_int ((primitive * 29) mod 241) +. (base *. 0.3) in
    random_x.(primitive * 2) <- x;
    random_y.(primitive * 2) <- y;
    random_z.(primitive * 2) <- z;
    random_x.((primitive * 2) + 1) <- x +. 0.013;
    random_y.((primitive * 2) + 1) <- y -. 0.017;
    random_z.((primitive * 2) + 1) <- z +. 0.019
  done;
  let random_topology = Topology.create_owned ~point_count:random_point_count
      ~vertex_points:(Array.init random_point_count Fun.id)
      ~primitive_offsets:(Array.init (random_curve_count + 1)
        (fun primitive -> primitive * 2))
      ~primitive_kinds:(Array.make random_curve_count Topology.Open_polyline)
      |> get_ok in
  let random_source = Geometry.create
      ~positions:(Packed.Float3.Private.of_owned_exn
        ~x:random_x ~y:random_y ~z:random_z)
      ~topology:random_topology () |> get_ok in
  let random_result = Curve_topology.join_curves ~grain:7 ~connect_closest_ends:true
      random_source |> get_ok in
  let expected_points = Array.make random_point_count 0
  and used = Bytes.make random_curve_count '\000' in
  expected_points.(0) <- 0;
  expected_points.(1) <- 1;
  Bytes.set used 0 '\001';
  let current = ref 1 in
  for order = 1 to random_curve_count - 1 do
    let best = ref (-1) and best_distance = ref infinity in
    for endpoint = 0 to random_point_count - 1 do
      if Bytes.get used (endpoint lsr 1) = '\000' then begin
        let distance =
          let dx = random_x.(!current) -. random_x.(endpoint)
          and dy = random_y.(!current) -. random_y.(endpoint)
          and dz = random_z.(!current) -. random_z.(endpoint) in
          let scale = max (abs_float dx) (max (abs_float dy) (abs_float dz)) in
          if scale = 0. then 0.
          else
            let x = dx /. scale and y = dy /. scale and z = dz /. scale in
            scale *. sqrt ((x *. x) +. (y *. y) +. (z *. z)) in
        if distance < !best_distance
            || distance = !best_distance && (!best < 0 || endpoint < !best)
        then begin best := endpoint; best_distance := distance end
      end
    done;
    let primitive = !best lsr 1 and reverse = !best land 1 = 1 in
    Bytes.set used primitive '\001';
    let output = order * 2 in
    expected_points.(output) <- (primitive * 2) + if reverse then 1 else 0;
    expected_points.(output + 1) <- (primitive * 2) + if reverse then 0 else 1;
    current := expected_points.(output + 1)
  done;
  if (Topology.Private.view (Geometry.topology random_result)).vertex_points
      <> expected_points then
    fail "Curve Join endpoint k-d tree disagrees with brute-force greedy order";
  let wrapped_join = Curve_topology.join_curves ~wrap:true join_source |> get_ok in
  let wrapped_edges = Geometry.find_edge_group "join_edges" wrapped_join
      |> Option.get in
  if Topology.primitive_kind (Geometry.topology wrapped_join) 0
      <> Topology.Closed_polyline || Edge_group.length wrapped_edges <> 7
      || Edge_group.cardinality wrapped_edges <> 5 then
    fail "Curve Join wrap/generated edge policy";
  (match Curve_topology.join_curves triangle_geometry with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Join accepted polygon geometry");
  (match Curve_topology.join_curves ~tolerance:nan join_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Join accepted a non-finite tolerance");
  let extreme_join = Mesh_merge.run [
      Line_geometry.polyline [|(-.max_float,0.,0.); (-.max_float,1.,0.)|] |> get_ok;
      Line_geometry.polyline [|(max_float,0.,0.); (max_float,1.,0.)|] |> get_ok;
    ] |> get_ok |> Curve_topology.join_curves |> get_ok in
  if Geometry.vertex_count extreme_join <> 4 then
    fail "Curve Join mishandled overflowing finite endpoint distance";
  let extreme_global = Mesh_merge.run [
      Line_geometry.polyline [|(-.max_float,0.,0.); (-.max_float,1.,0.)|] |> get_ok;
      Line_geometry.polyline [|(max_float,0.,0.); (max_float,1.,0.)|] |> get_ok;
    ] |> get_ok |> Curve_topology.join_curves ~connect_closest_ends:true |> get_ok in
  if Geometry.vertex_count extreme_global <> 4 then
    fail "global closest Curve Join mishandled overflowing finite distance";
  let invalid_join_positions = Packed.Float3.Private.of_owned_exn
      ~x:[|0.;1.;Float.nan;3.|] ~y:(Array.make 4 0.) ~z:(Array.make 4 0.) in
  let invalid_join_topology = Topology.create_owned ~point_count:4
      ~vertex_points:[|0;1;2;3|] ~primitive_offsets:[|0;2;4|]
      ~primitive_kinds:(Array.make 2 Topology.Open_polyline) |> get_ok in
  let invalid_join = Geometry.create ~positions:invalid_join_positions
      ~topology:invalid_join_topology () |> get_ok in
  (match Curve_topology.join_curves ~connect_closest_ends:true invalid_join with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "global closest Curve Join accepted a non-finite endpoint");
  (match Curve_ops.carve_curves ~first:0.5 ~last:0.5 carve_source with
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Carve accepted an empty interval");
  let point_only_carve = Line_geometry.points [|(2.,3.,4.)|] in
  if (Curve_ops.carve_curves ~first:0.2 point_only_carve |> get_ok) != point_only_carve
  then fail "Curve Carve rebuilt point-only geometry";
  (match Curve_ops.carve_curves ~last:0.9 triangle_geometry with
   | Ok _ -> fail "Curve Carve accepted polygon geometry"
   | Error error when Error.code error = "invalid_geometry" -> ()
   | _ -> fail "Curve Carve polygon diagnostic code");
  let cancelled_curve = Cancel.create () in
  Cancel.cancel cancelled_curve;
  (match Curve_ops.carve_curves ~cancel:cancelled_curve ~first:0.1 carve_source with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "Curve Carve ignored cancellation");
  (match Curve_topology.join_curves ~cancel:cancelled_curve join_source with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "Curve Join ignored cancellation");
  (match Curve_topology.convert_line ~cancel:cancelled_curve line_source with
   | Error error when Error.code error = "cancelled" -> ()
   | _ -> fail "Convert Line ignored cancellation");
  check (geometry_bytes join_source = join_source_bytes
      && geometry_bytes closest_source = closest_source_bytes)
    "Curve Join mutated source geometry during successful/refused/cancelled operations";
  ()
