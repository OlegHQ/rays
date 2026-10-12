module E = Flow.Eval
module G = Rdk.Geometry
module Group = Rdk.Group
module Edge = Rdk.Edge_group
let ok = function Ok x -> x | Error message -> failwith message
let flow_ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let bytes = Rdk_test_support.geometry_bytes
let owners = ["point",Some Group.Point;"vertex",Some Vertex;"primitive",Some Primitive;"edge",None]
let count geometry = function
  | Some Group.Point -> G.point_count geometry | Some Vertex -> G.vertex_count geometry
  | Some Primitive -> G.primitive_count geometry
  | None -> Rdk.Topology_index.edge_count(Rdk.Topology_index.create(G.topology geometry))
let fixtures () =
  [Rdk.Topology.empty ~point_count:0;
   Rdk.Topology.create_owned ~point_count:4 ~vertex_points:[|0;1;2;2;1;0|]
     ~primitive_offsets:[|0;3;6|] ~primitive_kinds:[|Rdk.Topology.Polygon;Open_polyline|] |> ok]
  |>List.map(fun topology->let n=Rdk.Topology.point_count topology in
    G.create ~positions:(Rdk.Packed.Float3.Private.of_owned_exn ~x:(Array.init n float)
      ~y:(Array.make n 0.) ~z:(Array.make n 0.)) ~topology () |>ok)
let native_write ?order ~owner ~name mask geometry = match owner with
  | None -> assert(order=None);let topology=G.topology geometry in
      G.with_edge_group(Edge.init ~topology ~index:(Rdk.Topology_index.create topology) ~name
        (fun i->mask.(i)=1))geometry |>ok
  | Some owner ->let group=match order with
      | None->Group.init ~owner ~name (Array.length mask)(fun i->mask.(i)=1)
      | Some order->Group.ordered ~owner ~name ~length:(Array.length mask) order |>ok in
      G.with_group group geometry |>ok
let query geometry owner name component =
  Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some geometry)
    (E.Source((if component=None then "sop/group" else "sop/group_order"),
      Flow.Ty.Any,["geometry",E.Deferred(Flow.Ty.geometry,7);"owner",E.Text owner;"name",E.Text name]
        @Option.fold ~none:[] ~some:(fun component->["component",E.Text component])component)) |>flow_ok
let checked body =
  let forms=Flow.Syntax.parse("(workspace groups (graph g :context sop [(geo : geometry nil)] (let* [tested "^body^"] geo)))") |>flow_ok in
  match Flow.Workspace.check ~ops:Flow_sop.Operators.all {Flow.Check.version=1;kinds=[]} forms with
  | Some checked,[]->checked |_,ds->failwith(String.concat "; " (List.map Flow.Diagnostic.to_string ds))
let evaluated geometry body =
  let evaluated=E.static ~record:true ~inputs:["g",["geo",E.Deferred(Flow.Ty.geometry,7)]](checked body) |>flow_ok in
  let value=List.assoc["g";"tested"]evaluated.records |>List.hd |>snd in
  value,Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some geometry)
let exact geometry body expected =
  let value,resolve=evaluated geometry body in
  let program=Flow_ir.Executor.compile ~strict:true value |>flow_ok in
  List.iter(fun domains->Rays_math.Parallel.run ~domains(fun()->
    let live=Frame_input.at_time 0.25 in
    assert(flow_ok(E.Private.force_reference ~resolve value ~live)=expected);
    assert(flow_ok(Flow_ir.Executor.force ~strict:true ~resolve program ~live)=expected))) [1;8]
let create_session ()=Sop.Session.create ~max_entries:32 ~max_payload_bytes:1_000_000 |>ok
let cook session ?(time=0.) domains node =
  match Sop.Session.cook session ~context:(Sop.Context.create ~domains ~time () |>ok)node with
  | Ok output->Sop.Payload.geometry output.payload |>Result.get_ok
  | Error d->failwith(Sop.Diagnostic.error_to_string d)
let int_array data=Array.fold_left(fun array value->
  "(array/concat "^array^" (array/int 1 "^string_of_int value^"))") "(array/int 0 0)" data
let write_node geometry owner mask ?order () =
  Lisp_sop.node ~with_:["source",Lisp_sop.snapshot geometry]
    ("(sop/with_group (sop/ext_source) "^int_array mask^" :name \"selected\" :owner "^owner^
      Option.fold ~none:"" ~some:(fun order->" :order "^order)order^")")
let () =
  List.iter(fun geometry->List.iter(fun(owner,native_owner)->
    let n=count geometry native_owner in
    let mask=Array.init n(fun i->if i mod 2=0 then 1 else 0) in
    let expected=native_write ~owner:native_owner ~name:"selected" mask geometry in
    let node=write_node geometry owner mask () in
    assert((Sop.Node.facts node).cook_mode=Generic);
    assert((Sop.Node.facts node).reads=["*"] && (Sop.Node.facts node).writes=["*"]);
    let session=create_session() in
    Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
      List.iter(fun domains->let output=cook session domains node in
        assert(bytes output=bytes expected);
        exact output ("(sop/group geo :name \"selected\" :owner "^owner^")") (E.Int_array mask);
        exact output ("(sop/group_order geo :name \"selected\" :owner "^owner^")")
          (E.Record["ordered",E.Bool false;"indices",E.Int_array[||]]);
        let copy=Lisp_sop.workspace_node ~with_:["source",Lisp_sop.snapshot output]
          ("(workspace groups (defnode sop/test_mask_roundtrip [(geo : geometry)] (sop/with_group geo "^
            "(exact (map (fn [(value : int)] value) (sop/group geo :name \"selected\" :owner "^owner^"))) "^
            ":name \"selected\" :owner "^owner^" :order (sop/group_order geo :name \"selected\" :owner "^owner^"))) "^
            "(graph g :context sop (sop/test_mask_roundtrip (sop/ext_source))))") in
        assert(bytes(cook session domains copy)=bytes output)) [1;8]);
    (match native_owner with None->() |Some _->
      let selected=Array.to_list(Array.mapi(fun i value->i,value)mask) |>List.filter_map(fun(i,value)->if value=1 then Some i else None)
        |>List.rev |>Array.of_list in
      List.iter(fun(mask,order)->
        let expected=native_write ~owner:native_owner ~name:"selected" ~order mask geometry in
        let node=write_node geometry owner mask ~order:(int_array order)() in
        let session=create_session() in
        Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
          List.iter(fun domains->let output=cook session domains node in
            assert(bytes output=bytes expected);
            exact output ("(sop/group_order geo :name \"selected\" :owner "^owner^")")
              (E.Record["ordered",E.Bool true;"indices",E.Int_array order]);
            let copy=Lisp_sop.node ~with_:["source",Lisp_sop.snapshot output]
              ("(let* [geo (sop/ext_source)] (sop/with_group geo (sop/group geo :name \"selected\" :owner "^owner^") "^
                ":name \"selected\" :owner "^owner^" :order (sop/group_order geo :name \"selected\" :owner "^owner^")))") in
            assert(bytes(cook session domains copy)=bytes output)) [1;8]))
        [mask,selected;Array.make n 0,[||]]);
    assert(query expected owner "selected" None=E.Int_array mask);
    let owned=query expected owner "selected" None in
    (match owned with E.Int_array data->Array.fill data 0 n 0|_->assert false);
    assert(query expected owner "selected" None=E.Int_array mask)) owners)(fixtures());
  print_endline "Groups: native owner masks, stable/empty order and unordered round trips, strict queries, owned arrays and one/eight-domain bytes"

let () =
  let geometry=List.nth(fixtures())1 in
  let names=["wall_a";"wall_b";"wall_1";"floor";"literal*";"žarek"] in
  List.iter(fun(owner,native_owner)->
    let geometry=List.fold_left(fun g name->native_write ~owner:native_owner ~name
      (Array.make(count geometry native_owner)1)g)geometry names in
    List.iter(fun pattern->let compiled=Rdk.Attribute_pattern.compile pattern |>ok in
      exact geometry ("(sop/group_names geo "^fst(Flow.Lisp.print[Flow.Syntax.make(Str pattern)])^
        " :owner "^owner^")")
        (E.Text_array(Array.of_list(List.filter(Rdk.Attribute_pattern.matches compiled)names))))
      ["";"*";"wall*";"wall?";"wall_[a-b]";"wall_[!0-9]";"* ^wall*";"^wall* wall_b";"literal\\*";"ž*"])
    owners;
  let session=create_session() in
  Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
    let refused code node=match Sop.Session.cook session ~context:(Sop.Context.create() |>ok)node with
      |Error d->assert(d.code=code)|Ok _->assert false in
    List.iter(fun(owner,native_owner)->let n=count geometry native_owner in
      refused "E_GROUP_COUNT" (write_node geometry owner (Array.make(n+1)0)());
      refused "E_GROUP_MASK" (write_node geometry owner (Array.make n 2)());
      (match native_owner with
       |None->refused "E_GROUP_OWNER" (write_node geometry owner (Array.make n 0)~order:"(array/int 0 0)"())
       |Some _->List.iter(fun order->refused "E_GROUP_ORDER"
          (write_node geometry owner (Array.make n 1)~order:(int_array order)())) [[|n|];[|0;0|];[||]])) owners);
  let missing geometry=Flow_sop.Attribute_kernel.resolve ~geometry in
  let source name args=E.Source(name,Flow.Ty.Any,("geometry",E.Deferred(Flow.Ty.geometry,7))::args) in
  let refused code=function Error(d:Flow.Diagnostic.t)->assert(d.code=code)|Ok _->assert false in
  refused "E_DATA_SOURCE"(missing(fun _->None)(source "sop/group"["name",E.Text "missing"]));
  refused "E_GROUP_MISSING"(missing(fun _->Some geometry)(source "sop/group"["name",E.Text "missing"]));
  refused "E_GROUP_OWNER"(missing(fun _->Some geometry)(source "sop/group"["name",E.Text "missing";"owner",E.Text "detail"]));
  List.iter(fun pattern->refused "E_GROUP_PATTERN"
    (missing(fun _->Some geometry)(source "sop/group_names"["pattern",E.Text pattern]))) ["[";"\\";"[z-a]"];
  print_endline "Groups: native wildcard/escape/exclusion/name order and count/mask/order/owner/source refusals"

let () =
  let catalog=Flow_sop.Catalog.of_factories ~version:1 Sop_catalog.Editor.factories |>flow_ok in
  let checker=Flow_sop.Catalog.check_workspace ~ops:Flow_sop.Operators.all in
  let forms=Flow.Syntax.parse {|(workspace group_projection (graph g :context sop
    (let* [geo (sop/line) mask (sop/group geo :name "selected" :owner point)
      names (sop/group_names geo "wall*" :owner vertex)
      order (sop/group_order geo :name "selected" :owner primitive)
      result (sop/with_group geo mask :name "copy" :owner point)] result)))|} |>flow_ok in
  let checked=match checker catalog forms with Some checked,[]->checked|_,ds->failwith(String.concat "; "(List.map Flow.Diagnostic.to_string ds)) in
  let pane=Flow_graph.Projection.of_graph catalog checked "g" in
  List.iter(fun(binding,ty)->let node=Flow_graph.Projection.find pane["g";binding] |>Option.get in
    assert(node.ty=ty);assert(List.exists(fun(row:Flow_graph.Projection.row)->row.label="owner")node.rows))
    ["mask",Flow.Ty.Array Int;"names",Array Text;"order",Record["ordered",Bool;"indices",Array Int];"result",Flow.Ty.geometry];
  List.iter(fun binding->
    let _,checked=Flow_graph.Flow_edit.apply_checked ~checker catalog forms
      (Set_arg{node=["g";binding];key=Kw "owner";sub=[];value=Flow.Syntax.make(Sym "edge")}) |>flow_ok in
    let pane=Flow_graph.Projection.of_graph catalog checked "g" in
    let node=Flow_graph.Projection.find pane["g";binding] |>Option.get in
    let row=List.find(fun(row:Flow_graph.Projection.row)->row.label="owner")node.rows in
    assert(Flow.Lisp.flat(Option.get row.expr)="\"edge\"")) ["mask";"names";"order";"result"];
  let forms=Flow.Syntax.parse {|(workspace group_wire (graph g :context sop
    (let* [geo (sop/line) mask (sop/group geo :name "selected" :owner point)
      result (sop/with_group geo (array/int 0 0) :name "copy" :owner point)] result)))|} |>flow_ok in
  ignore(Flow_graph.Flow_edit.apply_checked ~checker catalog forms
    (Set_arg{node=["g";"result"];key=Pos 1;sub=[];value=Flow.Syntax.make(Sym "mask")}) |>flow_ok);
  List.iter(fun text->let _,diagnostics=checker catalog(Flow.Syntax.parse text |>flow_ok) in
    assert(List.exists(fun(d:Flow.Diagnostic.t)->d.severity=Error)diagnostics))
    ["(workspace bad (graph g :context sop (sop/with_group nil (array/int 0 0) :name \"x\" :order 2)))";
     "(workspace bad (graph g :context sop (sop/group nil :name \"\")))";
     "(workspace bad (graph g :context sop (sop/group nil :name \"x\" :owner detail)))"];
  print_endline "Group cards expose typed masks/name arrays/order records; owner and mask gestures recheck directly"

let () =
  let geometry=List.nth(fixtures())1 in
  let n=G.point_count geometry in
  let source mask=native_write ~owner:(Some Group.Point) ~name:"selected" mask geometry in
  let first=source(Array.make n 1) and second=source(Array.make n 0) in
  let node=Lisp_sop.node ~with_:["target",Lisp_sop.snapshot geometry;"source",Lisp_sop.snapshot first]
    "(sop/with_group (sop/ext_target) (sop/group (sop/ext_source) :name \"selected\") :name \"copy\")" in
  assert(List.length(Sop.Node.inputs node)=2);
  let expected=native_write ~owner:(Some Group.Point) ~name:"copy"(Array.make n 1)geometry in
  let session=create_session() in
  Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
    assert(bytes(cook session 1 node)=bytes expected);
    let before=Sop.Session.stats session in
    assert(bytes(cook session 8 node)=bytes expected);
    assert((Sop.Session.stats session).misses=before.misses);
    let inputs=Array.of_list(Sop.Node.inputs node) in
    inputs.(1)<-Lisp_sop.snapshot second;
    let changed=Sop.Node.Private.adopt_identity ~source:node(Sop.Node.Private.rebuild_with_inputs node inputs) in
    let expected=native_write ~owner:(Some Group.Point) ~name:"copy"(Array.make n 0)geometry in
    assert(bytes(cook session 8 changed)=bytes expected);
    assert((Sop.Session.stats session).misses>before.misses));
  let values,_=evaluated first "(sop/group geo :name \"selected\")" in
  let read=Flow_sop.Attribute_kernel.node ~owner:Rdk.Attribute.Point ~kind:"int" ~source:"group-query"
    ~name:"mark" ~values ~sources:[7] [Lisp_sop.snapshot first] in
  assert((Sop.Node.facts read).reads=[]);
  let session=create_session() in
  Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
    let assert_mask output mask=match G.find_attribute ~owner:Point "mark"output |>Option.get |>Rdk.Attribute.storage with
      |Int data->assert(data=mask)|_->assert false in
    assert_mask(cook session 1 read)(Array.make n 1);
    let before=Sop.Session.stats session in
    let changed=Sop.Node.Private.adopt_identity ~source:read
      (Sop.Node.Private.rebuild_with_inputs read [|Lisp_sop.snapshot second|]) in
    assert_mask(cook session 8 changed)(Array.make n 0);
    assert((Sop.Session.stats session).misses>before.misses));
  let n=5001 in
  let geometry=G.create ~positions:(Rdk.Packed.Float3.Private.of_owned_exn
    ~x:(Array.make n 0.) ~y:(Array.make n 0.) ~z:(Array.make n 0.))
    ~topology:(Rdk.Topology.empty ~point_count:n)() |>ok in
  let node=Lisp_sop.workspace_node ~with_:["source",Lisp_sop.snapshot geometry] {|(workspace live_groups
    (defnode sop/test_live_group [(geo : geometry)]
      (sop/with_group geo (exact (map (fn [(value : int)] (if (< t 0.5) value 0))
        (array/int (sop/count geo :points) 1))) :name "selected"))
    (graph g :context sop (sop/test_live_group (sop/ext_source))))|} in
  List.iter(fun domains->let session=create_session() in
    Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
      List.iter(fun(time,selected)->let output=cook session ~time domains node in
        assert(bytes output=bytes(native_write ~owner:(Some Group.Point) ~name:"selected"
          (Array.make n selected)geometry))) [0.,1;0.75,0;0.25,1])) [1;8];
  print_endline "Groups: captured geometry and group changes invalidate caches; warm hits and live strict multi-block masks preserve native bytes"

let () =
  let forms=Flow.Syntax.parse {|(workspace folded_group (graph g :context sop
    (let* [geo (sop/line) counter (state [previous 0] (int/add previous 1))]
      (sop/with_group geo (exact (map (fn [(value : int)]
        (if (int/eq (int/mod counter 2) 1) value 0)) (array/int (sop/count geo :points) 1)))
        :name "selected"))))|} |>flow_ok in
  List.iter(fun domains->
    let lowered=Flow_sop.Lower.workspace ~factories:Sop_catalog.Editor.factories forms |>flow_ok in
    let graph=List.hd lowered.graphs and lane=Flow_sop.Value_lane.create() in
    let session=create_session() in
    Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
      List.iter(fun frame->let time=float frame*.0.25 in
        let live={(Frame_input.at_time time)with frame} in
        let resolved=Flow_sop.Value_lane.resolve ~live lane ~time graph.network |>flow_ok in
        let node=Sop.Edit_graph.compile_node resolved.geometry ~node_id:(Option.get graph.root) |>ok in
        let context=Sop.Context.create ~input:live ~time ~frame:(Int64.of_int frame) ~domains() |>ok in
        let get node=match Sop.Session.cook session ~context node with
          |Ok output->Sop.Payload.geometry output.payload |>Result.get_ok
          |Error d->failwith(Sop.Diagnostic.error_to_string d) in
        let original=get(List.hd(Sop.Node.inputs node)) in
        let expected=native_write ~owner:(Some Group.Point) ~name:"selected"
          (Array.make(G.point_count original)((frame+1)mod 2))original in
        assert(bytes(get node)=bytes expected)) [0;1;2])) [1;8];
  print_endline "Group frame folds snapshot on the initial domain and recook exact masks at one/eight domains"
