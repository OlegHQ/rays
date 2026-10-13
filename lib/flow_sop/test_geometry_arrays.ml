open Rdk
open Rdk_test_support
module E = Flow.Eval
module L = Flow_sop.Lower
module Edit = Sop.Edit_graph
let flow = function Ok value->value|Error diagnostic->failwith(Flow.Diagnostic.to_string diagnostic)
let parse source=Flow.Syntax.parse source |>flow
let factories=Sop_catalog.Editor.factories
let with_session fn=
  let session=Sop.Session.create ~max_entries:64 ~max_payload_bytes:64_000_000 |>get_string_ok in
  Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->fn session)
let compile (lowered:L.t)=
  let graph=List.hd lowered.graphs in
  graph,Edit.compile_node graph.network.geometry ~node_id:(Option.get graph.root) |>get_string_ok
let cook session ?(domains=1) ?(grain=97) ?(time=0.) node=
  let context=Sop.Context.create ~domains ~grain ~time () |>get_string_ok in
  Sop.Session.cook session ~context node
let geometry=function
  |Ok(output:Sop.Session.output)->Result.get_ok(Sop.Payload.geometry output.payload)
  |Error diagnostic->failwith(Sop.Diagnostic.error_to_string diagnostic)
let fields geometry=
  let topology=Topology.Private.view(Geometry.topology geometry)
  and positions=Packed.Float3.Private.view(Geometry.positions geometry)in
  ["points",E.Vec3_array(Array.init(Array.length positions.x*3)(fun i->
      match i mod 3 with 0->positions.x.(i/3)|1->positions.y.(i/3)|_->positions.z.(i/3)));
   "vertex_points",E.Int_array(Array.copy topology.vertex_points);
   "primitive_offsets",E.Int_array(Array.copy topology.primitive_offsets);
   "kinds",E.Int_array(Array.init(Bytes.length topology.primitive_kinds)(fun i->Char.code(Bytes.get topology.primitive_kinds i)))]
let fixtures ()=
  let make count vertices offsets kinds=
    let topology=Topology.create_owned ~point_count:count ~vertex_points:vertices
      ~primitive_offsets:offsets ~primitive_kinds:kinds |>get_string_ok in
    let positions=Packed.Float3.Private.of_owned_exn ~x:(Array.init count float)
      ~y:(Array.init count(fun i->if i mod 2=0 then -0. else 0.25)) ~z:(Array.make count 2.)in
    Geometry.create ~positions ~topology () |>get_string_ok in
  [make 0 [||][|0|][||];make 5 [|0;1;2;2;1;3|][|0;3;6|][|Topology.Polygon;Polygon|];
   make 3 [|0;1;1;2;1|][|0;5|][|Topology.Open_polyline|];
   make 4 [|3;2;1;0|][|0;4|][|Topology.Closed_polyline|];
   make 6 [|0;1;2;0;1;3;1;0;4;0;1;5|][|0;3;6;9;12|]
     [|Topology.Polygon;Open_polyline;Closed_polyline;Polygon|]]
let arrays_source={|(workspace arrays
  (graph g :context sop [(points : (array vec3) (array/vec3 0))
    (vertex_points : (array int) (array/int 0))
    (primitive_offsets : (array int) (array/int 1)) (kinds : (array int) (array/int 0))]
    (sop/mesh :points points :vertex_points vertex_points
      :primitive_offsets primitive_offsets :kinds kinds)))|}
let arrays ?(reference=false) values=
  L.workspace ~reference ~factories ~inputs:["g",values](parse arrays_source) |>flow |>compile |>snd
let rebuild={|(let* [topology (sop/topology geo)]
  (sop/mesh :points (sop/attr geo :P) :vertex_points topology.vertex_points
    :primitive_offsets topology.primitive_offsets :kinds topology.kinds))|}
let lower ?(reference=false) source input=
  let factory=Edit.factory ~key:"ext_src" ~label:"Source" ~category:["Test"] ~arity:0(fun _->input)in
  L.workspace ~reference ~factories:(factory::factories)(parse source) |>flow
let ()=
  List.iter(fun expected->let input=fields expected and before=geometry_bytes expected in
    List.iter(fun reference->let node=arrays ~reference input in
      List.iter(fun domains->List.iter(fun grain->with_session(fun session->
        let actual=geometry(cook session ~domains ~grain node)in
        check(geometry_bytes actual=before)"C1 own-array mesh differs from native fixture";
        let warm=Sop.Session.stats session in
        ignore(cook session ~domains ~grain node);
        check((Sop.Session.stats session).misses=warm.misses)"C1 unchanged mesh cache missed")) [1;97;4096]) [1;4;8]) [false;true];
    List.iter(fun reference->
      let source=Printf.sprintf {|(workspace authored
        (defnode sop/rebuild [(geo : geometry)] %s)
        (graph g :context sop (sop/rebuild (sop/ext_src))))|} rebuild in
      let _,node=lower ~reference source (Lisp_sop.snapshot expected) |>compile in
      List.iter(fun domains->with_session(fun session->
        check(geometry_bytes(geometry(cook session ~domains node))=before)
          "C1 strict/reference authored topology/P reconstruction differs")) [1;4;8]) [false;true];
    (* Geometry construction owns native planes, even when Flow input arrays
       remain referenced by the caller after the successful cook. *)
    with_session(fun session->let actual=geometry(cook session(arrays input))in
      List.iter(function _,E.Int_array values when Array.length values>0->values.(0)<-99
        |_,E.Vec3_array values when Array.length values>0->values.(0)<-99.|_->())input;
      check(geometry_bytes actual=before)"C1 mesh retained a mutable Flow argument")) (fixtures());
  print_endline "C1 five plain geometries rebuild from owned arrays and authored topology/P at one/four/eight domains"

let ()=
  let n=32769 in
  let expected=Line_geometry.points(Array.init n(fun i->
    float i,(if i mod 2=0 then -0. else Float.next_after 0. 1.),-2.)) in
  let source={|(workspace packed_mesh
    (defnode sop/packed_mesh [(geo : geometry)]
      (let* [topology (sop/topology geo)]
        (sop/mesh :points (exact (map (fn [(position : vec3)] position) (sop/attr geo :P)))
          :vertex_points topology.vertex_points
          :primitive_offsets topology.primitive_offsets :kinds topology.kinds)))
    (graph g :context sop (sop/packed_mesh (sop/ext_src))))|} in
  List.iter(fun reference->let _,node=lower ~reference source(Lisp_sop.snapshot expected)|>compile in
    List.iter(fun domains->List.iter(fun grain->with_session(fun session->
      check(geometry_bytes(geometry(cook session ~domains ~grain node))=geometry_bytes expected)
        "C1 multi-block packed point reconstruction differs")) [1;97;4096]) [1;4;8]) [false;true];
  print_endline "C1 32769-point authored packed mesh preserves signed-zero/subnormal bytes across domains and grains"

let ()=
  let expected=List.nth(fixtures())1 in
  let source={|(workspace mesh_capture
    (defn topology_of :context sop [(geo : geometry)] (sop/topology geo))
    (defnode sop/mesh_capture [(geo : geometry) (field : (fn [vec3] vec3))]
      (let* [topology (topology_of geo)]
        (sop/mesh :points (exact (map field (sop/attr geo :P)))
          :vertex_points topology.vertex_points
          :primitive_offsets topology.primitive_offsets :kinds topology.kinds)))
    (graph g :context sop
      (sop/mesh_capture (sop/ext_src) (fn [(p : vec3)] p))))|} in
  List.iter(fun reference->let _,node=lower ~reference source(Lisp_sop.snapshot expected) |>compile in
    List.iter(fun domains->with_session(fun session->
      check(geometry_bytes(geometry(cook session ~domains node))=geometry_bytes expected)
        "C1 helper/record/typed function capture changed reconstructed geometry")) [1;8]) [false;true]

let ()=
  let original=List.nth(fixtures())1 in
  let evaluate expression=
    let source="(workspace query (graph g :context sop [(geo : geometry nil)] (let* [tested "^expression^"] geo)))"in
    let catalog=Flow_sop.Catalog.of_factories ~version:1 factories |>flow in
    let checked=match Flow_sop.Catalog.check_workspace ~ops:Flow_sop.Operators.all catalog(parse source)with
      |Some checked,[]->checked|_,diagnostics->failwith(String.concat ";"(List.map Flow.Diagnostic.to_string diagnostics))in
    let evaluation=E.static ~record:true ~inputs:["g",["geo",E.Deferred(Flow.Ty.geometry,7)]] checked |>flow in
    List.assoc["g";"tested"]evaluation.records |>List.hd |>snd in
  let resolver=Flow_sop.Attribute_kernel.resolve ~geometry:(fun id->if id=7 then Some original else None)in
  let queried=evaluate "(sop/topology geo)"in
  let live=Frame_input.at_time 0. in
  let expected=E.Record(List.tl(fields original))in
  let result=E.Private.force_reference ~resolve:resolver queried ~live |>flow in
  check(result=expected)"C1 topology kind codes or plane order differ";
  (match result with E.Record fields->List.iter(function _,E.Int_array a->Array.fill a 0(Array.length a)99|_->assert false)fields|_->assert false);
  check(E.Private.force_reference ~resolve:resolver queried ~live |>flow = expected)"C1 topology query mutated native storage";
  let source=Lisp_sop.snapshot original in
  let origins=List.map(fun component->
    let captured="(let* [topology (sop/topology geo)] (map (fn [(i : int)] i) topology."^component^"))" in
    let direct="(map (fn [(i : int)] i) (get (sop/topology geo) :"^component^"))" in
    let origin expression=
    let values=evaluate expression in
    check(Flow_sop.Attribute_kernel.sources values=[7])"C1 topology capture lost its geometry dependency";
    let program=Flow_sop.Attribute_kernel.prepare ~strict:true ~sources:[7][source]values |>flow in
    let packed=Array.find_map(fun(node:Flow_ir.node)->match node.kind with
      |Kernel{body=Packed_map packed;_}->Some packed|_->None)(Flow_ir.Executor.graph program).nodes |>Option.get in
    match Flow_ir.Packed.count_origin packed with Some origin->origin
    |None->fail("C1 topology count origin missing for "^expression) in
    let captured=origin captured and direct=origin direct in
    check(captured=direct)"C1 direct topology Get and captured field have different origins";
    captured)
    ["vertex_points";"primitive_offsets";"kinds"]in
  check(List.length(List.sort_uniq compare origins)=3)"C1 distinct topology plane counts share a false origin";
  List.iter(fun domains->Rays_math.Parallel.run ~domains(fun()->
    let program=Flow_ir.Executor.compile ~strict:true queried |>flow in
    check(Flow_ir.Executor.force ~strict:true ~resolve:resolver program ~live |>flow=expected)
      "C1 compiled topology differs from reference")) [1;8];
  (* A real compiled host source is refused by 2D export, rather than silently
     inventing browser geometry or routing through a native callback. *)
  let dynamic=evaluate "(if (= (frame/index) 0) (get (sop/topology geo) :kinds) (array/int 0))"in
  (match dynamic with E.Residual residual->
    let core=Flow_ir.Core_lower.lower ~strict:true residual |>get_string_ok in
    (match Flow_web.Js.frame core with Error d->check(d.code="E_WEB_SOURCE")"C1 cooked source changed web refusal"
      |Ok _->fail("C1 unexpectedly exported cooked geometry: "^Format.asprintf "%a" Flow_ir.Core.pp core))
    |_->fail "C1 dynamic test did not retain its source");
  print_endline "C1 topology copies, captured count origins and actual 2D host-source refusal are explicit"

let ()=
  let input=List.nth(fixtures())1 in
  let input=Geometry.with_attribute(Attribute.create_owned ~name:"unrelated" ~owner:Attribute.Point
    (Float(Array.make(Geometry.point_count input)0.)) |>get_string_ok)input |>get_string_ok in
  let values={|(workspace topology_cache (graph g :context sop [(geo : geometry nil)]
    (let* [tested (array/int 1 (array/count (get (sop/topology geo) :kinds)))] geo)))|} in
  let checked=match Flow.Workspace.check ~ops:Flow_sop.Operators.all
      {Flow.Check.version=1;kinds=[]}(parse values)with
    |Some checked,[]->checked|_,diagnostics->fail(String.concat ";"
        (List.map Flow.Diagnostic.to_string diagnostics)) in
  let value=E.static ~record:true ~inputs:["g",["geo",E.Deferred(Flow.Ty.geometry,7)]] checked |>flow
    |>fun evaluation->List.assoc["g";"tested"]evaluation.records |>List.hd |>snd in
  let node=Flow_sop.Attribute_kernel.node ~strict:true ~owner:Attribute.Detail ~kind:"int"
    ~source:"C1 topology" ~name:"primitive_count" ~values:value ~sources:[7] [Lisp_sop.snapshot input] in
  check((Sop.Node.facts node).reads=[])"C1 topology-only capture reads unrelated attributes";
  with_session(fun session->
    ignore(geometry(cook session node));
    let positions=Packed.Float3.Private.of_owned_exn ~x:(Array.make(Geometry.point_count input)8.)
      ~y:(Array.make(Geometry.point_count input)4.) ~z:(Array.make(Geometry.point_count input)2.) in
    let changed=Geometry.with_positions positions input |>get_string_ok in
    let changed=Geometry.with_attribute(Attribute.create_owned ~name:"unrelated" ~owner:Point
      (Float(Array.make(Geometry.point_count input)1.)) |>get_string_ok)changed |>get_string_ok in
    let source=Lisp_sop.snapshot changed in ignore(geometry(cook session source));
    let before=Sop.Session.stats session in
    let rebuilt source=Sop.Node.Private.adopt_identity ~source:node
      (Sop.Node.Private.rebuild_with_inputs node[|source|]) in
    let output=geometry(cook session(rebuilt source)) in
    check((Sop.Session.stats session).misses=before.misses)"C1 topology capture missed for position/attribute-only change";
    check(Packed.Float3.data_id(Geometry.positions output)=Packed.Float3.data_id positions)
      "C1 cached topology capture failed to carry fresh positions";
    (match Geometry.find_attribute ~owner:Point "unrelated" output |>Option.get |>Attribute.storage with
     |Float values->check(values=Array.make(Geometry.point_count input)1.)
         "C1 cached topology capture failed to carry fresh unread attribute values"|_->assert false);
    let changed=Geometry.with_attribute(Attribute.create_owned ~name:"added" ~owner:Point
      (Float(Array.make(Geometry.point_count input)2.)) |>get_string_ok)changed |>get_string_ok in
    let source=Lisp_sop.snapshot changed in ignore(geometry(cook session source));
    let before=Sop.Session.stats session in
    ignore(geometry(cook session(rebuilt source)));
    check((Sop.Session.stats session).misses=before.misses+1)
      "C1 changed attribute layout failed to invalidate the ordinary write cache";
    let changed=List.nth(fixtures())2 in
    let before=Sop.Session.stats session in
    let output=geometry(cook session(rebuilt(Lisp_sop.snapshot changed))) in
    check((Sop.Session.stats session).misses>before.misses)"C1 topology change did not invalidate query";
    match Geometry.find_attribute ~owner:Detail "primitive_count" output |>Option.get |>Attribute.storage with
    |Int values->check(values=[|1|])"C1 topology query carried stale count"|_->assert false)

let ()=
  let base=fields(List.nth(fixtures())1)in
  let replace key value=List.map(fun(name,old)->name,if name=key then value else old)base in
  let cases=["primitive_offsets",E.Int_array[||],"Topology: primitive offsets must contain the initial zero";
    "primitive_offsets",E.Int_array[|1;3;6|],"Topology: first primitive offset must be zero";
    "primitive_offsets",E.Int_array[|0;3;5|],"Topology: final primitive offset must equal vertex count";
    "kinds",E.Int_array[|0|],"Topology: primitive kind count must match primitive count";
    "vertex_points",E.Int_array[|0;1;2;2;1;9007199254740993|],"Topology: vertex references an invalid point";
    "primitive_offsets",E.Int_array[|0;7;6|],"Topology: primitive offsets are not ordered";
    "primitive_offsets",E.Int_array[|0;2;6|],"Topology: primitive has too few vertices for its kind"]in
  List.iter(fun(key,value,message)->List.iter(fun reference->
    let node=arrays ~reference(replace key value)in
    List.iter(fun domains->with_session(fun session->match cook session ~domains node with
      |Error d->check(d.code="E_TOPOLOGY" && d.message=message && d.cause=None)"C1 native topology error changed"
      |Ok _->fail "C1 malformed topology succeeded")) [1;8]) [false;true])cases;
  List.iter(fun kind->with_session(fun session->match cook session(arrays(replace "kinds"(E.Int_array[|kind;0|])))with
    |Error d->check(d.code="E_TOPOLOGY_KIND")"C1 invalid kind code diagnostic"
    |Ok _->fail "C1 invalid kind code succeeded")) [-1;3;9007199254740993];
  let resolver=Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->None) in
  List.iter(fun geometry->match resolver(E.Source("sop/topology",Flow.Ty.Array Int,
      ["geometry",geometry;"component",E.Text"vertex_points"]))with
    |Error d->check(d.code="E_DATA_SOURCE")"C1 missing/wrong geometry source changed diagnostic"
    |Ok _->fail "C1 unavailable geometry succeeded")
    [E.No_geo;E.Deferred(Flow.Ty.geometry,7);E.Deferred(Flow.Ty.Float,7)];
  List.iter(fun domains->with_session(fun session->
    let cancel=Sop.Context.Cancel.create() in Sop.Context.Cancel.cancel cancel;
    let context=Sop.Context.create ~domains ~cancel () |>get_string_ok in
    match Sop.Session.cook session ~context(arrays base)with
    |Error d->check(d.code="cancelled" || d.code="E_CANCELLED")"C1 cancelled constructor changed diagnostic"
    |Ok _->fail "C1 cancelled mesh succeeded")) [1;8];
  let source body=Printf.sprintf {|(workspace lazy_mesh
    (defnode sop/lazy_mesh [(geo : geometry)] %s)
    (graph g :context sop (sop/lazy_mesh (sop/ext_src))))|} body in
  let original=List.nth(fixtures())1 in
  List.iter(fun reference->
    let _,healthy=lower ~reference(source("(if false (sop/mesh :points (sop/attr geo \"missing\") :vertex_points (array/int 0) :primitive_offsets (array/int 0) :kinds (array/int 0)) "^rebuild^")"))(Lisp_sop.snapshot original) |>compile in
    with_session(fun session->check(geometry_bytes(geometry(cook session healthy))=geometry_bytes original)"C1 untaken mesh forced bad input");
    let _,bad=lower ~reference(source {|(sop/mesh :points (error "E_POINTS" "selected points" :cause "point cause")
      :vertex_points (array/int 0) :primitive_offsets (array/int 0) :kinds (array/int 0))|})(Lisp_sop.snapshot original) |>compile in
    with_session(fun session->match cook session bad with
      |Error d->check(d.code="E_POINTS" && d.message="selected points" && d.cause=Some"point cause")"C1 point error order/cause changed"
      |Ok _->fail "C1 selected point failure succeeded")) [false;true];
  print_endline "C1 native topology errors, exact Int validation, lazy untaken mesh and selected causes retain cook timing"

let ()=
  let catalog=Flow_sop.Catalog.of_factories ~version:1 factories |>flow in
  let checker=Flow_sop.Catalog.check_workspace ~ops:Flow_sop.Operators.all in
  let forms=parse {|(workspace cards (graph g :context sop
    (let* [src (sop/line :points 2) topology (sop/topology src)
      pts (array/vec3 0) vp (array/int 0) po (array/int 1) ks (array/int 0)
      mesh (sop/mesh :points pts :vertex_points vp :primitive_offsets po :kinds ks)] mesh)))|}in
  let checked=match checker catalog forms with Some checked,[]->checked|_->fail "C1 projection fixture did not check"in
  let projection=Flow_graph.Projection.of_graph catalog checked "g"in
  let mesh=Flow_graph.Projection.find projection["g";"mesh"] |>Option.get
  and topology=Flow_graph.Projection.find projection["g";"topology"] |>Option.get in
  check(List.map(fun(row:Flow_graph.Projection.row)->row.label)mesh.rows=["points";"vertex_points";"primitive_offsets";"kinds"])"C1 mesh card rows";
  check(topology.outputs=["vertex_points",Flow.Ty.Array Int;"primitive_offsets",Array Int;"kinds",Array Int])"C1 topology card outputs";
  List.iter(fun key->let value=parse(if key="points"then"(array/vec3 0)"else if key="primitive_offsets"then"(array/int 1)"else"(array/int 0)") |>List.hd in
    ignore(flow(Flow_graph.Flow_edit.apply_checked ~checker catalog forms
      (Set_arg{node=["g";"mesh"];key=Kw key;sub=[];value})))) ["points";"vertex_points";"primitive_offsets";"kinds"];
  ignore(flow(Flow_graph.Flow_edit.apply_checked ~checker catalog forms
    (Connect{node=["g";"mesh"];key=Kw"vertex_points";src="vp";iter=false})));
  let before=fst(Flow.Lisp.print forms)in
  check(Result.is_error(Flow_graph.Flow_edit.apply_checked ~checker catalog forms
    (Set_arg{node=["g";"mesh"];key=Kw"kinds";sub=[];value=parse"(array/text 0)" |>List.hd})))"C1 malformed edit accepted";
  check(fst(Flow.Lisp.print forms)=before)"C1 malformed edit changed prior source";
  check(Option.is_some(Flow_graph.Flow_edit.default_for(Flow.Ty.Array Int)"value"))"C1 Int array socket has no typed default";
  let starter=List.hd(parse "(sop/mesh :points (array/vec3 0) :vertex_points (array/int 0) :primitive_offsets (array/int 1) :kinds (array/int 0))") in
  ignore(flow(Flow_graph.Flow_edit.apply_checked ~checker catalog forms
    (Add_node{scope=["g"];name="empty_mesh";expr=starter})));
  let node=Lisp_sop.node(Flow.Lisp.flat starter) in
  with_session(fun session->check(geometry_bytes(geometry(cook session node))=geometry_bytes(List.hd(fixtures())))
    "C1 menu starter failed to cook the native empty mesh");
  List.iter(fun source->let _,ds=checker catalog(parse source)in
    check(ds<>[])"C1 missing/wrong keyword checked")
    ["(workspace bad (graph g :context sop (sop/mesh :points (array/vec3 0))))";
     "(workspace bad (graph g :context sop (sop/topology 3)))"];
  print_endline "C1 ordinary cards, typed defaults and checked keyword/connection edits retain prior source on refusal"

let ()=
  List.iter(fun expression->List.iter(fun reference->
    let source=Printf.sprintf {|(workspace animated (graph g :context sop
      (let* [coordinate %s]
        (sop/mesh :points (exact (map (fn [(i : int)] [coordinate 0.0 0.0]) (array/range 1 :type int)))
          :vertex_points (array/int 0) :primitive_offsets (array/int 1) :kinds (array/int 0)))))|} expression in
    let lowered=L.workspace ~reference ~factories(parse source) |>flow in
    let graph=List.hd lowered.graphs in
    let state=E.create_state()in
    let lane=Flow_sop.Value_lane.create ~state ()in
    with_session(fun session->List.iter(fun(time,dt)->
      let live={(Frame_input.at_time time)with dt;frame=int_of_float time;tick=int_of_float time}in
      let resolved=Flow_sop.Value_lane.resolve ~live lane ~time graph.network |>flow in
      let node=Edit.compile_node resolved.geometry ~node_id:(Option.get graph.root) |>get_string_ok in
      let stamp=E.state_stamp state in
      let context=Sop.Context.create ~domains:8 ~time ~input:live () |>get_string_ok in
      let actual=geometry(Sop.Session.cook session ~context node)in
      let expected=if expression="t"then time else dt in
      check(Packed.Float3.get(Geometry.positions actual)0=(expected,0.,0.))"C1 stale frame/state array";
      check(E.state_stamp state=stamp)"C1 cooked snapshot leaked mutable host state") [0.,0.25;1.,0.5;2.,0.125])) [false;true])
    ["t";"(state [previous 0.0] (+ previous (frame/dt)))"];
  let source={|(workspace mesh_zone (graph g :context sop
    (sop/merge (for [p (sop/point_list (sop/ext_src))]
      (sop/mesh :points (array/vec3 1 p) :vertex_points (array/int 0)
        :primitive_offsets (array/int 1) :kinds (array/int 0))))))|}in
  let expected=Line_geometry.points[|0.,0.,0.;2.,0.,0.;4.,0.,0.|]in
  List.iter(fun reference->let _,node=lower ~reference source(Lisp_sop.snapshot expected) |>compile in
    List.iter(fun domains->with_session(fun session->let actual=geometry(cook session ~domains node)in
      check(fields actual=fields expected)"C1 zone mesh lost element/state capture")) [1;8]) [false;true];
  print_endline "C1 retained live/state arrays and zone element captures stay byte-exact"

let ()=
  let source={|(workspace rollback (graph g :context sop
    (let* [step (state [previous 0.0] (+ previous (frame/dt)))]
      (sop/mesh :points (exact (map (fn [(i : int)]
        (if (> step 0.0) (error "E_MESH_STATE" "selected state" :cause "state cause") [0.0 0.0 0.0]))
        (array/range 1 :type int))) :vertex_points (array/int 0)
        :primitive_offsets (array/int 1) :kinds (array/int 0)))))|} in
  List.iter(fun reference->
    let lowered=L.workspace ~reference ~factories(parse source) |>flow in
    let graph=List.hd lowered.graphs and state=E.create_state() in
    let lane=Flow_sop.Value_lane.create ~state () in
    let live={(Frame_input.at_time 1.)with dt=0.5;frame=1;tick=1} in
    let network=Flow_sop.Value_lane.resolve ~live lane ~time:1. graph.network |>flow in
    let node=Edit.compile_node network.geometry ~node_id:(Option.get graph.root) |>get_string_ok in
    let stamp=E.state_stamp state in
    with_session(fun session->List.iter(fun domains->
      let context=Sop.Context.create ~domains ~time:1. ~input:live () |>get_string_ok in
      match Sop.Session.cook session ~context node with
      |Error d->check(d.code="E_MESH_STATE" && d.cause=Some"state cause")"C1 selected state cause changed";
          check(E.state_stamp state=stamp)"C1 failed mesh advanced supplied host state"
      |Ok _->fail "C1 selected state error succeeded") [1;8])) [false;true]
