let ok = function Ok value -> value | Error message -> failwith message
let check condition message = if not condition then failwith message

let parse text = match Flow.Syntax.parse text with
  | Ok forms -> forms | Error d -> failwith (Flow.Diagnostic.to_string d)
let lower ?(reference = false) text =
  match Flow_sop.Lower.workspace ~reference ~factories:Sop_catalog.Editor.factories (parse text) with
  | Error d -> failwith (Flow.Diagnostic.to_string d)
  | Ok lowered ->
      let graph = List.find (fun (graph : Flow_sop.Lower.graph) -> graph.default) lowered.graphs in
      ok (Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root))
let with_session fn =
  let session = ok (Sop.Session.create ~max_entries:64 ~max_payload_bytes:10_000_000) in
  Fun.protect ~finally:(fun () -> Sop.Session.close session) (fun () -> fn session)
let cook session ?(domains = 1) ?(grain = 97) ?(seed = 0L) node =
  match Sop.Session.cook session ~context:(ok (Sop.Context.create ~domains ~grain ~seed ())) node with
  | Ok output -> (match Sop.Payload.geometry output.payload with
      | Ok geometry -> geometry | Error d -> failwith (Sop.Diagnostic.error_to_string d))
  | Error d -> failwith (Sop.Diagnostic.error_to_string d)

let source = {|(workspace test
  (defnode sop/lisp_shift :label "Lisp shift" :category ["Deform"]
    :facts {:elementwise points :reads ["P"] :writes ["P"] :topology preserved :exact true}
    [(geo : geometry) (distance : float 0.5 :min -10 :max 10 :label "Distance")]
    (sop/with_attr geo :P (exact (map (fn [p] (+ p [distance 0.0 0.0]))
      (sop/attr geo :P)))))
  (graph g :context sop (sop/lisp_shift (sop/ext_src) :distance 2.0)))|}

let () = with_session (fun session ->
  let empty = Rdk.Line_geometry.points [||] in
  let node = Lisp_sop.workspace_node ~with_:["src", Lisp_sop.snapshot empty] source in
  check (Rdk_test_support.geometry_bytes (cook session node) = Rdk_test_support.geometry_bytes empty)
    "empty geometry changed through a Lisp map")

let () =
  let open Rdk in
  let positions = ok (Packed.Float3.of_owned
    ~x:[|-1.; 0.; 1.|] ~y:[|-0.; 0.; 0.|] ~z:[|2.; 3.; 4.|]) in
  let topology = ok (Topology.polygons_owned ~point_count:3
    ~vertex_points:[|0; 1; 2|] ~primitive_offsets:[|0; 3|]) in
  let attributes = List.map (fun (owner, name, storage) ->
    ok (Attribute.create_owned ~owner ~name storage)) [
    Attribute.Point, "weight", Attribute.Float [|0.25; 0.5; 0.75|];
    Attribute.Point, "id", Attribute.Int [|2; 1; 0|];
    Attribute.Point, "tag", Attribute.Text [|"one"; "two"; "three"|];
    Attribute.Point, "weights", Attribute.Float_array (ok (Packed.Float_array.create_owned
      ~offsets:[|0; 0; 2; 3|] ~values:[|0.25; 0.5; 0.75|]));
    Attribute.Vertex, "uv", Attribute.Float3 positions;
    Attribute.Primitive, "material", Attribute.Int [|7|]] in
  let groups = [ok (Group.ordered ~owner:Group.Point ~name:"ordered"
    ~length:3 [|2; 0|])] in
  let edge_groups = [Edge_group.init ~topology ~index:(Topology_index.create topology)
    ~name:"selected_edges" (fun i -> i = 0)] in
  let original = ok (Geometry.create ~positions ~topology ~attributes ~groups ~edge_groups ()) in
  let before = Rdk_test_support.geometry_bytes original in
  let expected = Kernel.edit_point_ranges ~grain:1 (fun ~first ~last ~x ~y ~z ->
    for i = first to last - 1 do
      x.(i) <- x.(i) +. 2.; y.(i) <- y.(i) +. 0.; z.(i) <- z.(i) +. 0.
    done) original |> Rdk_test_support.geometry_bytes in
  let node = Lisp_sop.workspace_node ~with_:["src", Lisp_sop.snapshot original] source in
  List.iter (fun domains -> List.iter (fun grain -> with_session (fun session ->
    check (Rdk_test_support.geometry_bytes (cook session ~domains ~grain node) = expected)
      "Lisp body changed topology, attributes or ordered groups";
    check (Rdk_test_support.geometry_bytes original = before)
      "Lisp body mutated its immutable input")) [1; 97]) [1; 4]

let () =
  let original = Lisp_sop.node "(sop/line :points 3)" in
  let node = Lisp_sop.workspace_node ~with_:["src", original] source in
  check (Sop.Node.operation node = "lisp_shift") "defnode must keep its operation";
  check (List.length (Sop.Node.inputs node) = 1) "body leaked into public inputs";
  check (List.map (fun (f : Param.field_view) -> f.name) (Sop.Node.parameter_fields node)
    = ["distance"]) "parameter schema was lost";
  let session = ok (Sop.Session.create ~max_entries:32 ~max_payload_bytes:1_000_000) in
  Fun.protect ~finally:(fun () -> Sop.Session.close session) (fun () ->
    let context = ok (Sop.Context.create ()) in
    let cook node = match Sop.Session.cook session ~context node with
      | Ok output -> (match Sop.Payload.geometry output.payload with
          | Ok geometry -> geometry
          | Error error -> failwith (Sop.Diagnostic.error_to_string error))
      | Error error -> failwith (Sop.Diagnostic.error_to_string error) in
    let input = cook original and first = cook node in
    let ix, iy, iz = Rdk.Packed.Float3.get (Rdk.Geometry.positions input) 0 in
    let x, y, z = Rdk.Packed.Float3.get (Rdk.Geometry.positions first) 0 in
    check (x = ix +. 2. && y = iy && z = iz) "body did not use authored parameters";
    check (cook node == first) "unchanged Lisp node missed the cache";
    let changed, _ = ok (Sop.Node.apply_parameters node ["distance", Param.Float_value 3.]) in
    check (Sop.Node.id changed = Sop.Node.id node) "parameter edit changed logical identity";
    let result = cook changed in
    check (result != first) "changed parameter hit old cache";
    let x, _, _ = Rdk.Packed.Float3.get (Rdk.Geometry.positions result) 0 in
    check (x = ix +. 3.) "parameter edit did not rebuild the Lisp body")

let controls = {|(workspace controls
  (defnode sop/all_controls
    [(geo : geometry)
     (enabled : bool true)
     (count : int 2 :min 1 :max 10 :hard_min 1)
     (amount : float 0.5 :min -10 :max 10 :hard_min -20 :hard_max 20)
     (tag : text "original")
     (mode : text "A" :kind choice :choices ["A" "B"])
     (offset : vec3 [1 2 3] :min -10 :max 10)]
    (let* [distance (+ (+ (+ (+ amount count)
      (if enabled 1.0 0.0)) (if (equal? tag "original") 0.0 10.0))
      (if (equal? mode "A") 0.0 20.0))]
      (sop/with_attr geo :P (exact
        (map (fn [p] (+ (+ p offset) [distance 0.0 0.0])) (sop/attr geo :P))))))
  (graph g :context sop (sop/all_controls (sop/line :kind "Points" :points 1))))|}

let () = with_session (fun session ->
  let node = lower controls in
  let first = cook session node in
  let position geometry = Rdk.Packed.Float3.get (Rdk.Geometry.positions geometry) 0 in
  check (position first = (4.5, 2., 3.)) "scalar and vector defaults did not reach the body";
  let before = Sop.Session.stats session in
  check (cook session node == first) "all-controls unchanged node missed cache";
  check ((Sop.Session.stats session).misses = before.misses) "unchanged body caused hidden public misses";
  let fields = Sop.Node.parameter_fields node in
  check (List.map (fun (f : Param.field_view) -> f.name) fields =
    ["enabled"; "count"; "amount"; "tag"; "mode"; "offset_x"; "offset_y"; "offset_z"])
    "parameter kinds lost declaration ordering";
  List.iter (fun (name, value, expected) ->
    let changed, effects = ok (Sop.Node.apply_parameters node [name, value]) in
    check (effects.cook && Sop.Node.id changed = Sop.Node.id node) (name ^ ": parameter edit lost identity");
    let before = Sop.Session.stats session in
    let result = cook session changed in
    check (position result = expected) (name ^ ": body ignored updated parameter");
    check ((Sop.Session.stats session).misses = before.misses + 1)
      (name ^ ": changed Lisp parameter must cause exactly one public miss");
    let before = Sop.Session.stats session in
    check (cook session changed == result && (Sop.Session.stats session).misses = before.misses)
      (name ^ ": repeated changed value missed cache")) [
    "enabled", Param.Bool_value false, (3.5, 2., 3.);
    "count", Param.Int_value 3, (5.5, 2., 3.);
    "amount", Param.Float_value 1.5, (5.5, 2., 3.);
    "tag", Param.Text_value "changed", (14.5, 2., 3.);
    "mode", Param.Choice_value "B", (24.5, 2., 3.);
    "offset_x", Param.Float_value 4., (7.5, 2., 3.);
    "offset_y", Param.Float_value 4., (4.5, 4., 3.);
    "offset_z", Param.Float_value 4., (4.5, 2., 4.)];
  List.iter (fun ((name, _) as change) -> check (Result.is_error (Sop.Node.apply_parameters node [change]))
    (name ^ ": parameter normalization accepted an invalid value")) [
      "amount", Param.Float_value nan; "amount", Param.Float_value infinity;
      "mode", Param.Choice_value "missing"];
  (* Inspector writes use the native Param clamp; authored Lisp is checked. *)
  let clamped, _ = ok (Sop.Node.apply_parameters node ["count", Param.Int_value 0]) in
  let count = List.find (fun (f : Param.field_view) -> f.name = "count")
    (Sop.Node.parameter_fields clamped) in
  check (count.current = Param.Int_value 1) "integer hard bound differs from native inspector normalization")

let () =
  (* The body would fail its node's hard range if evaluated before validation. *)
  let source = {|(workspace validate
    (defnode sop/validated
      :validate (> count 0) :code "E_POSITIVE" :message "count must be positive"
      [(count : int 1 :min -10 :max 10)]
      (sop/line :kind "Points" :points count))
    (graph g :context sop (sop/validated)))|} in
  let node = lower source in
  (match Sop.Node.apply_parameters node ["count", Param.Int_value 0] with
   | Error message -> check (Rdk_test_support.contains message "E_POSITIVE")
       "body ran before node validation"
   | Ok _ -> failwith "node validation did not reject edited value")

let () = with_session (fun session ->
  let optional = {|(workspace optional
    (defnode sop/optional [(geo : geometry :required false)]
      (if (equal? geo nil) (sop/line :kind "Points" :points 1) geo))
    (graph g :context sop (sop/optional)))|} in
  check (Rdk.Geometry.point_count (cook session (lower optional)) = 1)
    "absent optional slot did not become nil";
  List.iter (fun (slot, call, points) ->
    let text = Printf.sprintf {|(workspace rest
      (defnode sop/repeated [(geos : geometry %s :rest true)]
        (if (> (count geos) 0) (first geos) (sop/line :kind "Points" :points 1)))
      (graph g :context sop %s))|} slot call in
    let node = lower text in
    check (Rdk.Geometry.point_count (cook session node) = points) "rest-slot topology passthrough failed") [
      "", "(sop/repeated (sop/line :points 2) (sop/line :points 3))", 2;
      ":required false", "(sop/repeated)", 1;
      ":required false", "(sop/repeated (sop/line :points 3))", 3;
      ":required false", "(sop/repeated nil)", 1])

let () =
  let source = {|(workspace nested
    (defnode sop/inner [(geo : geometry) (distance : float 0.5)]
      (sop/with_attr geo :P (exact (map (fn [p] (+ p [distance 0.0 0.0])) (sop/attr geo :P)))))
    (defnode sop/outer [(geo : geometry) (distance : float 1.5)]
      (sop/inner geo :distance distance))
    (graph g :context sop (sop/outer (sop/line :kind "Points" :points 1))))|} in
  with_session (fun session ->
    let node = lower source in
    let geometry = cook session node in
    check (Rdk.Packed.Float3.get (Rdk.Geometry.positions geometry) 0 = (1.5, 0., 0.))
      "nested Lisp call lost its parameters";
    let before = Sop.Session.stats session in
    let node, _ = ok (Sop.Node.apply_parameters node ["distance", Param.Float_value 2.5]) in
    let geometry = cook session node in
    check (Rdk.Packed.Float3.get (Rdk.Geometry.positions geometry) 0 = (2.5, 0., 0.))
      "nested Lisp parameter edit did not recook";
    check ((Sop.Session.stats session).misses = before.misses + 1)
      "nested bodies leaked private cache nodes")

let () =
  let source = {|(workspace exact
    (defnode sop/shift [(geo : geometry) (distance : float 0.125)]
      (sop/with_attr geo :P (exact (map (fn [p] (+ p [distance -0.0 0.0])) (sop/attr geo :P)))))
    (graph g :context sop (sop/shift (sop/grid :columns 64 :rows 64))))|} in
  let baseline = with_session (fun session -> Rdk_test_support.geometry_bytes (cook session (lower source))) in
  List.iter (fun reference ->
    let node = lower ~reference source in
    List.iter (fun domains -> List.iter (fun grain ->
      with_session (fun session ->
        let geometry = cook session ~domains ~grain node in
        check (Rdk.Geometry.point_count geometry = 4_225) "exactness fixture cardinality changed";
        check (Rdk_test_support.geometry_bytes geometry = baseline)
          "Lisp geometry bytes differ by interpreter/kernel/domain/grain")) [1; 97; 4096]) [1; 4]) [false; true]

let () = List.iter (fun (keyword, call) -> with_session (fun session ->
  let source = Printf.sprintf {|(workspace typed_function
    (defnode sop/function_slot [(field : (fn [vec3] float) %s)]
      (sop/iso_surface :field field :resolution [4 4 4]))
    (graph g :context sop
      (let* [radius 0.7 field (fn [p] (- (length p) radius))]
        %s)))|} keyword call in
  let geometry = cook session (lower source) in
  let native = cook session (Lisp_sop.node
    "(sop/iso_surface :field (fn [p] (- (length p) 0.7)) :resolution [4 4 4])") in
  check (Rdk_test_support.geometry_bytes geometry = Rdk_test_support.geometry_bytes native)
    "typed function slot lost its callable or captures"))
  ["", "(sop/function_slot field)"; ":keyword true", "(sop/function_slot :field field)"]

let () = List.iter (fun (keyword, call) -> with_session (fun session ->
  let source = Printf.sprintf {|(workspace typed_image
    (defnode sop/image_slot [(geo : geometry) (picture : image %s)]
      (sop/attr_from_image geo :image picture))
    (graph g :context sop %s))|} keyword call in
  let geometry = cook session (lower source) in
  let native = cook session (Lisp_sop.node
    {|(sop/attr_from_image (sop/grid :columns 2 :rows 2 :uv_attribute "uv") :image (image/noise :width 2 :height 2))|}) in
  check (Rdk_test_support.geometry_bytes geometry = Rdk_test_support.geometry_bytes native)
    "typed image slot lost its cooked pixels")) [
    "", {|(sop/image_slot (sop/grid :columns 2 :rows 2 :uv_attribute "uv") (image/noise :width 2 :height 2))|};
    ":keyword true", {|(sop/image_slot (sop/grid :columns 2 :rows 2 :uv_attribute "uv") :picture (image/noise :width 2 :height 2))|}]

let () = with_session (fun session ->
  let body = {|(let* [local (fn [p] (- (length (+ p [0.25 0.0 0.0])) 0.45))]
    (sop/merge
      (sop/iso_surface :field field :resolution [4 4 4])
      (sop/iso_surface :field local :resolution [4 4 4])))|} in
  let source = Printf.sprintf {|(workspace distinct_functions
    (defnode sop/two_fields [(field : (fn [vec3] float))] %s)
    (graph g :context sop (sop/two_fields (fn [p] (- (length p) 0.7)))))|} body in
  let native = Printf.sprintf {|(let* [field (fn [p] (- (length p) 0.7))] %s)|} body in
  check (Rdk_test_support.geometry_bytes (cook session (lower source)) =
    Rdk_test_support.geometry_bytes (cook session (Lisp_sop.node native)))
    "outer function forwarding replaced a distinct local function")

let () = with_session (fun session ->
  let body call = Printf.sprintf {|(let* [base (sop/line :kind "Points" :points 1 :origin [0.7 0.0 0.0])
         sample {:radius (array/sum (sop/attr base :P))}
         field (fn [p] (- (length p) sample.radius.x))] %s)|} call in
  let source = Printf.sprintf {|(workspace cooked_capture
    (defnode sop/function_capture [(field : (fn [vec3] float))]
      (sop/iso_surface :field field :resolution [4 4 4]))
    (graph g :context sop %s))|} (body "(sop/function_capture field)") in
  let geometry = cook session (lower source) in
  let native = cook session (Lisp_sop.node (body
    "(sop/iso_surface :field field :resolution [4 4 4])")) in
  check (Rdk_test_support.geometry_bytes geometry = Rdk_test_support.geometry_bytes native)
    "function slot lost its outer cooked-geometry capture")

let () = with_session (fun session ->
  let body call = Printf.sprintf {|(let* [base (sop/line :kind "Points" :points 1 :origin [0.7 0.2 -0.1])
      sample {:offset (array/sum (sop/attr base :P))}
      field (fn [p] (+ p sample.offset))
      geo (sop/grid :columns 2 :rows 2)] %s)|} call in
  let native = cook session (Lisp_sop.node (body
    "(sop/with_attr geo :P (exact (map field (sop/attr geo :P))))")) in
  List.iter (fun call ->
    let source = Printf.sprintf {|(workspace map_capture
      (defnode sop/map_field [(geo : geometry) (field : (fn [vec3] vec3))]
        (sop/with_attr geo :P (exact (map field (sop/attr geo :P)))))
      (defnode sop/map_outer [(geo : geometry) (field : (fn [vec3] vec3))]
        (sop/map_field geo field))
      (graph g :context sop %s))|} (body call) in
    List.iter (fun reference ->
      let node = lower ~reference source in
      check (List.length (Sop.Node.inputs node) = 2)
        "forwarded function geometry leaked into public input slots";
      List.iter (fun domains -> with_session (fun session ->
        let geometry = cook session ~domains node in
        check (Rdk_test_support.geometry_bytes geometry = Rdk_test_support.geometry_bytes native)
          "map function slot confused its separate outer geometry capture with the input geometry";
        let before = Sop.Session.stats session in
        check (cook session ~domains node == geometry && (Sop.Session.stats session).misses = before.misses)
          "unchanged forwarded geometry capture missed the public cache")) [1; 4]) [false; true])
    ["(sop/map_field geo field)"; "(sop/map_outer geo field)"])

let () =
  let source = {|(workspace refused
    (defnode sop/unsupported_map [(geo : geometry)]
      (sop/with_attr geo :P (exact
        (map (fn [p] (if (equal? p [0.0 0.0 0.0]) p (+ p [1.0 0.0 0.0])))
          (sop/attr geo :P)))))
    (graph g :context sop (sop/unsupported_map (sop/grid :columns 2 :rows 2))))|} in
  match Flow_sop.Lower.workspace ~factories:Sop_catalog.Editor.factories (parse source) with
  | Error diagnostic -> check (diagnostic.code = "E_KERNEL_FORM")
      ("non-packed numeric Lisp body had an unrelated refusal: " ^ Flow.Diagnostic.to_string diagnostic)
  | Ok _ -> failwith "numeric Lisp body silently accepted an interpreter fallback"

let () = with_session (fun session ->
  let prefix call = Printf.sprintf {|(let* [base (sop/line :kind "Points" :points 1 :origin [0.7 0.2 -0.1])
    sample {:offset (array/sum (sop/attr base :P))}
    field (fn [p] (+ p sample.offset))
    other (fn [p] (- p sample.offset))
    geo (sop/grid :columns 2 :rows 2)] %s)|} call in
  let unchanged = cook session (Lisp_sop.node (prefix "geo")) in
  let mapped = cook session (Lisp_sop.node (prefix
    "(sop/with_attr geo :P (exact (map field (sop/attr geo :P))))")) in
  let twice = cook session (Lisp_sop.node (prefix
    "(sop/with_attr geo :P (exact (map field (map field (sop/attr geo :P)))))")) in
  let different = cook session (Lisp_sop.node (prefix
    "(sop/with_attr geo :P (exact (map other (map field (sop/attr geo :P)))))")) in
  let cases = [
    {|[(geo : geometry) (field : (fn [vec3] vec3) :required false)]|},
    {|(if (equal? field nil) geo (sop/with_attr geo :P (exact (map field (sop/attr geo :P)))))|},
    ["(sop/slots geo)", unchanged; "(sop/slots geo field)", mapped];
    {|[(geo : geometry) (fields : (fn [vec3] vec3) :rest true :required false)]|},
    {|(if (= (count fields) 0) geo
      (sop/with_attr geo :P (exact (map (first fields) (sop/attr geo :P)))))|},
    ["(sop/slots geo)", unchanged; "(sop/slots geo field field)", mapped;
      "(sop/slots geo (list field field))", mapped];
    {|[(geo : geometry) (fields : (fn [vec3] vec3) :rest true)]|},
    {|(let* [field (first fields) other (first (rest fields))]
      (sop/with_attr geo :P (exact (map other (map field (sop/attr geo :P))))))|},
    ["(sop/slots geo field field)", twice; "(sop/slots geo field other)", different];
    {|[(geo : geometry :required false) (field : (fn [vec3] vec3))]|},
    {|(let* [target (if (equal? geo nil) (sop/grid :columns 2 :rows 2) geo)]
      (sop/with_attr target :P (exact (map field (sop/attr target :P)))))|},
    ["(sop/slots nil field)", mapped];
    {|[(field : (fn [vec3] vec3)) (geos : geometry :rest true :required false)]|},
    {|(let* [target (if (= (count geos) 0) (sop/grid :columns 2 :rows 2) (first geos))]
      (sop/with_attr target :P (exact (map field (sop/attr target :P)))))|},
    ["(sop/slots field)",mapped;"(sop/slots field geo geo)",mapped]] in
  List.iter (fun (inputs, body, calls) -> List.iter (fun (call, expected) ->
    let source = Printf.sprintf {|(workspace repeated_functions
      (defnode sop/slots %s %s) (graph g :context sop %s))|} inputs body (prefix call) in
    let node = lower source in
    let geometry = cook session node in
    check (Rdk_test_support.geometry_bytes geometry = Rdk_test_support.geometry_bytes expected)
      ("typed callable slot changed bytes: " ^ call);
    let before = Sop.Session.stats session in
    check (cook session node == geometry && (Sop.Session.stats session).misses = before.misses)
      "unchanged optional/rest callable missed its cache") calls) cases)

let () = with_session (fun session ->
  let prefix call = Printf.sprintf {|(let* [geo (sop/grid :columns 2 :rows 2 :uv_attribute "uv")
    picture (image/noise :width 2 :height 2)] %s)|} call in
  let unchanged = cook session (Lisp_sop.node (prefix "geo")) in
  let textured = cook session (Lisp_sop.node (prefix
    {|(sop/attr_from_image geo :image picture :attribute "shade")|})) in
  List.iter (fun (slot,body,calls) -> List.iter (fun (call,expected) ->
    let source = Printf.sprintf {|(workspace repeated_images
      (defnode sop/images [(geo : geometry) %s] %s)
      (graph g :context sop %s))|} slot body (prefix call) in
    check (Rdk_test_support.geometry_bytes (cook session (lower source)) =
      Rdk_test_support.geometry_bytes expected) ("typed image slot changed bytes: " ^ call)) calls) [
    {|(picture : image :required false)|},
    {|(if (equal? picture nil) geo
      (sop/attr_from_image geo :image picture :attribute "shade"))|},
    ["(sop/images geo)",unchanged;"(sop/images geo picture)",textured];
    {|(pictures : image :rest true :required false)|},
    {|(if (= (count pictures) 0) geo
      (sop/attr_from_image geo :image (first pictures) :attribute "shade"))|},
    ["(sop/images geo)",unchanged;"(sop/images geo picture picture)",textured;
      "(sop/images geo (list picture picture))",textured]])
