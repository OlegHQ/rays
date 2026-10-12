open Rdk
open Rdk_test_support
module E = Flow.Eval
module L = Flow_sop.Lower
module Edit = Sop.Edit_graph
module Session = Sop.Session
let flow_ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let factories = Sop_catalog.Editor.factories
let catalog = Flow_sop.Catalog.of_factories ~version:1 factories |> flow_ok
let source ?(columns = 33) ?(amp = "0.8") body = Printf.sprintf
  "(workspace kernel (graph g :context sop (let* [g (sop/grid :counts \"Point counts\" :connectivity \"Points\" :columns %d :rows 2) amp %s freq 0.16 result %s] result)))"
  columns amp body
let noise_body = "(sop/with_attr g :P (exact (map (fn [p n] (+ p (* n (* amp (noise3 (* p freq)))))) (sop/attr g :P) (sop/attr g :N))))"
let lower ?previous text =
  let forms = Flow.Syntax.parse text |> flow_ok in
  let compiled_ids = Option.map (fun (l : L.t) -> l.compiled_ids) previous
  and sites = Option.map (fun (l : L.t) -> l.sites) previous in
  match L.workspace ~factories ?compiled_ids ?sites forms with
  | Ok lowered -> lowered
  | Error d -> failwith (text ^ "\n" ^ Flow.Diagnostic.to_string d)
let compiled (l : L.t) =
  let graph = List.hd l.graphs in
  Edit.compile_node graph.network.geometry ~node_id:(Option.get graph.root) |> get_string_ok
let context ~domains time = Sop.Context.create ~domains ~time ~grain:257 () |> get_string_ok
let session () = Session.create ~max_entries:32 ~max_payload_bytes:(64 * 1024 * 1024) |> get_string_ok
let cook session ~domains ~time node = Session.cook session ~context:(context ~domains time) node
let geometry = function Ok (output : Session.output) -> (Result.get_ok (Sop.Payload.geometry output.payload))
  | Error d -> failwith (Sop.Diagnostic.error_to_string d)
let reference (l : L.t) node =
  let n = Array.find_opt (fun (n : E.node) -> n.kind = "sop/with_attr") l.plan.nodes |> Option.get in
  let values = List.assoc "values" n.args in
  let sources = match List.assoc "geometry" n.args with E.Deferred (_, id) ->
    id :: List.filter ((<>) id) (Flow_sop.Attribute_kernel.sources values) | _ -> assert false in
  Flow_sop.Attribute_kernel.node ~reference:true ~source:"reference"
    ~name:"P" ~values ~sources (Sop.Node.inputs node)
let stages program = Array.fold_left (fun count (node : Flow_ir.node) -> match node.kind with
  | Kernel {body = Packed_map p; _} -> max count (Flow_ir.Packed.stage_count p)
  | _ -> count) 0 (Flow_ir.Executor.graph program).nodes

let () =
  let positions=Packed.Float3.Private.of_owned_exn ~x:[|0.;1.;0.;2.|]
    ~y:[|0.;0.;1.;2.|] ~z:[|0.;0.;0.;0.|] in
  let topology=Topology.polygons_owned ~point_count:4 ~vertex_points:[|0;1;2|]
    ~primitive_offsets:[|0;3|] |> get_string_ok in
  let original=Geometry.create ~positions ~topology () |> get_string_ok in
  let before=geometry_bytes original in
  let input=Lisp_sop.snapshot original in
  let owners=[Attribute.Point,"point",4;Vertex,"vertex",3;Primitive,"primitive",1;Detail,"detail",1] in
  let value kind count =
    let floats width=Array.init (count*width) (fun i->if i mod 3=0 then -0. else float i+.0.125) in
    match kind with
    | "float"->E.Float_array(floats 1)|"vec2"->E.Vec2_array(floats 2)
    | "vec3"->E.Vec3_array(floats 3)|"vec4"->E.Vec4_array(floats 4)
    | "int"->E.Int_array(Array.init count (fun i->if i mod 2=0 then max_int else min_int))
    | "text"->E.Text_array(Array.init count(fun i->[|"";"é日本🐈";"a\nb \"q\"";"literal :keyword"|].(i mod 4)))
    | "float_array"|"int_array" ->
        (* Ragged rows include empty rows and a 16-element matrix row. *)
        let offsets=Array.make (count+1) 0 in
        for i=0 to count-1 do offsets.(i+1)<-offsets.(i)+(if i=0 then 16 else if i mod 2=0 then 2 else 0) done;
        let n=offsets.(count) in
        E.Record["offsets",E.Int_array offsets;"values",(if kind="float_array" then E.Float_array(floats 1 |> fun data->Array.init n (fun i->data.(i mod count)))
          else E.Int_array(Array.init n(fun i->max_int-i)))]
    | _->assert false in
  List.iter(fun(owner,owner_name,count)->List.iter(fun kind->
    let values=value kind count in
    let first=ref None in
    List.iter(fun domains->
      let session=session() in
      Fun.protect ~finally:(fun()->Session.close session)(fun()->
        let node values=Flow_sop.Attribute_kernel.node ~owner ~kind
          ~source:(owner_name^":"^kind) ~name:"typed" ~values ~sources:[0] [input] in
        let output=cook session ~domains ~time:0. (node values)|>geometry in
        let reread=if kind="float_array"||kind="int_array" then
          Printf.sprintf "(sop/attr geo :typed :owner %s :type %s)" owner_name kind else
          Printf.sprintf "(exact (map (fn [value] value) (sop/attr geo :typed :owner %s :type %s)))" owner_name kind in
        let authored=Lisp_sop.workspace_node ~with_:["source",Lisp_sop.snapshot output]
          (Printf.sprintf "(workspace typed_roundtrip (defnode sop/typed_roundtrip [(geo : geometry)] (sop/with_attr geo :copy %s :owner %s :type %s)) (graph g :context sop (sop/typed_roundtrip (sop/ext_source))))"
            reread owner_name kind) in
        let copied=cook session ~domains ~time:0. authored|>geometry in
        let expected=Geometry.find_attribute ~owner "typed" output|>Option.get
          |>Attribute.with_name "copy"|>get_string_ok in
        assert(geometry_bytes copied=geometry_bytes(Geometry.with_attribute expected output|>get_string_ok));
        let args=["geometry",E.Deferred(Flow.Ty.geometry,0);"attribute",E.Text"typed";
          "owner",E.Text owner_name;"type",E.Text kind] in
        let resolve value=Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some output) value |> flow_ok in
        let read=match kind with "float_array"|"int_array"->
          E.Record(List.map(fun component->component,resolve(E.Struct("sop/attr",Flow.Ty.Any,args@["component",E.Text component]))) ["offsets";"values"])
          |_->resolve(E.Struct("sop/attr",Flow.Ty.Any,args)) in
        assert(Marshal.to_string read [Marshal.No_sharing]=Marshal.to_string values [Marshal.No_sharing]);
        if kind="text" then begin
          let reference=Flow_sop.Attribute_kernel.node ~owner ~kind ~reference:true
            ~source:"text-reference" ~name:"copy"
            ~values:(E.Struct("sop/attr",Flow.Ty.Array Flow.Ty.Text,args))
            ~sources:[0] [Lisp_sop.snapshot output] in
          assert(geometry_bytes(cook session ~domains ~time:0. reference|>geometry)=geometry_bytes copied);
          let retained=geometry_bytes output in
          (match read with E.Text_array data->Array.fill data 0(Array.length data)"read-mutated"|_->assert false);
          assert(geometry_bytes output=retained);
          (match cook session ~domains ~time:0. (node(E.Float_array(Array.make count 0.))) with
            |Error d->assert(d.code="E_ATTR_TYPE")|Ok _->assert false)
        end;
        let wrong=if kind="text" then "float" else "text" in
        assert(resolve(E.Source("sop/has_attr",Flow.Ty.Bool,args))=E.Bool true);
        assert(resolve(E.Source("sop/has_attr",Flow.Ty.Bool,("type",E.Text wrong)::List.remove_assoc "type" args))=E.Bool false);
        assert(resolve(E.Source("sop/has_attr",Flow.Ty.Bool,("attribute",E.Text"missing")::List.remove_assoc "attribute" args))=E.Bool false);
        (match Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some output)
          (E.Struct("sop/attr",Flow.Ty.Any,("type",E.Text wrong)::List.remove_assoc "type" args)) with
          |Error d->assert(d.code="E_ATTR_TYPE")|Ok _->assert false);
        (match Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some output)
          (E.Struct("sop/attr",Flow.Ty.Any,("attribute",E.Text"missing")::List.remove_assoc "attribute" args)) with
          |Error d->assert(d.code="E_ATTR_TYPE")|Ok _->assert false);
        let bytes=geometry_bytes output in
        (match !first with None->first:=Some bytes|Some previous->assert(previous=bytes));
        assert(geometry_bytes original=before);
        let bad=match kind with "float_array"|"int_array"->
          (match values with E.Record fields->E.Record(("offsets",E.Int_array[|0|])::List.remove_assoc "offsets" fields)|_->assert false)
          |_->value kind (count+1) in
        (match cook session ~domains ~time:0. (node bad) with
          |Error d->assert(d.code="E_ATTR_COUNT")|Ok _->assert false);
        (match values with E.Record fields->
          let offsets=match List.assoc"offsets"fields with E.Int_array offsets->offsets|_->assert false in
          List.iter(fun(index,value)->let invalid=Array.copy offsets in invalid.(index)<-value;
            let values=E.Record(("offsets",E.Int_array invalid)::List.remove_assoc"offsets"fields) in
            match cook session ~domains ~time:0. (node values) with
            |Error d->assert(d.code="E_ATTR_COUNT")|Ok _->assert false)
            [0,1;count,(-1);count,max_int]
          |_->());
        let rec mutate=function
          |E.Int_array data->Array.fill data 0(Array.length data)0
          |E.Text_array data->Array.fill data 0(Array.length data)"mutated"
          |E.Float_array data|Vec2_array data|Vec3_array data|Vec4_array data->Array.fill data 0(Array.length data)99.
          |E.Record fields->List.iter(fun(_,v)->mutate v)fields|_->assert false in
        let fresh=value kind count in
        let owned=cook session ~domains ~time:0. (node fresh)|>geometry in
        let retained=geometry_bytes owned in
        mutate fresh;
        assert(geometry_bytes owned=retained && geometry_bytes original=before))) [1;8])
    ["float";"vec2";"vec3";"vec4";"int";"text";"float_array";"int_array"]) owners;
  print_endline "Typed attributes: all owners, tuple/Int/Text/CSR exact round trips, strict reads, queries and one/eight-domain bytes"

let () =
  let count=4097 in
  let positions=Packed.Float3.Private.of_owned_exn ~x:(Array.make count 0.)
    ~y:(Array.make count 0.) ~z:(Array.make count 0.) in
  let original=Geometry.create ~positions ~topology:(Topology.empty ~point_count:count)
    ~attributes:[Attribute.create_owned ~name:"name" ~owner:Attribute.Point
      (Text(Array.init count(fun i->if i mod 2=0 then "é日本" else "")))|>get_string_ok] ()|>get_string_ok in
  let text={|(workspace text_map
    (defnode sop/text_map [(geo : geometry)]
      (sop/with_attr geo :copy
        (map (fn [value] (str value " suffix")) (sop/attr geo :name :type text)) :type text))
    (graph g :context sop (sop/text_map (sop/ext_source))))|} in
  let expected=Geometry.with_attribute(Attribute.create_owned ~name:"copy" ~owner:Attribute.Point
    (Text(Array.init count(fun i->(if i mod 2=0 then "é日本" else "")^" suffix")))|>get_string_ok)original|>get_string_ok in
  List.iter(fun domains->let session=session() in
    Fun.protect ~finally:(fun()->Session.close session)(fun()->
      let node=Lisp_sop.workspace_node ~with_:["source",Lisp_sop.snapshot original] text in
      assert(geometry_bytes(cook session ~domains ~time:0. node|>geometry)=geometry_bytes expected))) [1;8];
  print_endline "Strict authored text attribute map preserves UTF-8 beyond 4096 elements at one/eight domains"

let () =
  let positions=Packed.Float3.Private.of_owned_exn ~x:[||] ~y:[||] ~z:[||] in
  let empty=Geometry.create ~positions ~topology:(Topology.empty ~point_count:0) ()|>get_string_ok in
  let input=Lisp_sop.snapshot empty in
  let cases count=["float",E.Float_array(Array.make count (-0.));
    "vec2",E.Vec2_array(Array.make(count*2)(-0.));"vec3",E.Vec3_array(Array.make(count*3)(-0.));
    "vec4",E.Vec4_array(Array.make(count*4)(-0.));"int",E.Int_array(Array.make count max_int);
    "text",E.Text_array(Array.make count "é日本");
    "float_array",E.Record["offsets",E.Int_array(Array.make(count+1)0);"values",E.Float_array[||]];
    "int_array",E.Record["offsets",E.Int_array(Array.make(count+1)0);"values",E.Int_array[||]]] in
  List.iter(fun(owner,count)->List.iter(fun(kind,values)->
    let node=Flow_sop.Attribute_kernel.node ~owner ~kind ~source:"empty-owner" ~name:"empty"
      ~values ~sources:[0] [input] in
    List.iter(fun domains->let session=session() in
      Fun.protect ~finally:(fun()->Session.close session)(fun()->
        let output=cook session ~domains ~time:0. node|>geometry in
        let attr=Geometry.find_attribute ~owner "empty" output|>Option.get in
        assert(Attribute.length attr=count && Geometry.point_count output=0);
        let value=Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some output)
          (E.Source("sop/has_attr",Flow.Ty.Bool,["geometry",E.Deferred(Flow.Ty.geometry,0);"attribute",E.Text"P"]))|>flow_ok in
        assert(value=E.Bool true))) [1;8])(cases count))
    [Attribute.Point,0;Vertex,0;Primitive,0;Detail,1];
  print_endline "Empty geometry retains zero owner counts, one detail row and canonical P presence"

let () =
  let checker=Flow_sop.Catalog.check_workspace ~ops:Flow_sop.Operators.all in
  let check forms=match checker catalog forms with
    |Some workspace,diagnostics when not(List.exists(fun(d:Flow.Diagnostic.t)->d.severity=Flow.Diagnostic.Error)diagnostics)->workspace
    |_,diagnostics->failwith(String.concat "\n"(List.map Flow.Diagnostic.to_string diagnostics)) in
  let forms=Flow.Syntax.parse {|(workspace typed_projection (graph g :context sop
    (let* [geo (sop/line) typed (sop/attr :owner point geo :P :type vec3)] geo)))|}|>flow_ok in
  let card workspace=Flow_graph.Projection.find (Flow_graph.Projection.of_graph catalog workspace "g") ["g";"typed"]|>Option.get in
  assert((card(check forms)).ty=Flow.Ty.Array Flow.Ty.Vec3);
  let edited,workspace=Flow_graph.Flow_edit.apply_checked ~checker catalog forms
    (Set_arg{node=["g";"typed"];key=Kw "type";sub=[];value=Flow.Syntax.make(Str "float")})|>flow_ok in
  assert((card workspace).ty=Flow.Ty.Array Flow.Ty.Float);
  assert((card(check edited)).ty=Flow.Ty.Array Flow.Ty.Float);
  let edited,workspace=Flow_graph.Flow_edit.apply_checked ~checker catalog edited
    (Set_arg{node=["g";"typed"];key=Kw "type";sub=[];value=Flow.Syntax.make(Str "text")})|>flow_ok in
  assert((card workspace).ty=Flow.Ty.Array Flow.Ty.Text);
  assert((card(check edited)).ty=Flow.Ty.Array Flow.Ty.Text);
  let forms=Flow.Syntax.parse {|(workspace typed_range (graph g :context host
    (let* [typed (array/range 4 :type int)] typed)))|}|>flow_ok in
  assert((card(check forms)).ty=Flow.Ty.Array Flow.Ty.Int);
  let _,workspace=Flow_graph.Flow_edit.apply_checked ~checker catalog forms
    (Set_arg{node=["g";"typed"];key=Kw "type";sub=[];value=Flow.Syntax.make(Str "float")})|>flow_ok in
  assert((card workspace).ty=Flow.Ty.Array Flow.Ty.Float);
  let forms=Flow.Syntax.parse {|(workspace dynamic_type (graph g :context sop
    (let* [geo (sop/line) typed (sop/attr geo :P :type (if true "vec3" "float"))] geo)))|}|>flow_ok in
  let _,diagnostics=Flow_sop.Catalog.check_workspace ~ops:Flow_sop.Operators.all catalog forms in
  assert(List.exists(fun(d:Flow.Diagnostic.t)->d.code="E_ATTR_TYPE")diagnostics);
  print_endline "Attribute/range type edits recheck graph projection; computed storage selectors are refused"

let () =
  let count=32769 in
  let positions=Packed.Float3.Private.of_owned_exn ~x:(Array.make count 0.)
    ~y:(Array.make count 0.) ~z:(Array.make count 0.) in
  let original=Geometry.create ~positions ~topology:(Topology.empty ~point_count:count) ()|>get_string_ok in
  let input=Lisp_sop.snapshot original in
  List.iter(fun(kind,width)->
    let values=Array.init(count*width)(fun i->if i mod 13=0 then -0. else float i*.0.125) in
    let value=match width with 1->E.Float_array values|2->E.Vec2_array values|_->E.Vec4_array values in
    let first=ref None in
    List.iter(fun domains->let session=session() in
      Fun.protect ~finally:(fun()->Session.close session)(fun()->
        let node=Flow_sop.Attribute_kernel.node ~strict:true ~kind ~source:"wide-multiblock"
          ~name:"wide" ~values:value ~sources:[0] [input] in
        let output=cook session ~domains ~time:0. node|>geometry in
        let read=Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some output)
          (E.Struct("sop/attr",Flow.Ty.Any,["geometry",E.Deferred(Flow.Ty.geometry,0);
            "attribute",E.Text"wide";"type",E.Text kind]))|>flow_ok in
        assert(Marshal.to_string read [Marshal.No_sharing]=Marshal.to_string value [Marshal.No_sharing]);
        let bytes=geometry_bytes output in
        (match !first with None->first:=Some bytes|Some previous->assert(previous=bytes)))) [1;8])
    ["float",1;"vec2",2;"vec4",4];
  print_endline "Float/Vec2/Vec4 multi-block owner writes and reads preserve signed-zero bytes at one/eight domains"

let () =
  let bare=Line_geometry.points [|0.,0.,0.;1.,0.,0.|] in
  let tuple count f=Packed.Float3.Private.of_owned_exn
    ~x:(Array.init count(fun i->let x,_,_=f i in x))
    ~y:(Array.init count(fun i->let _,y,_=f i in y))
    ~z:(Array.init count(fun i->let _,_,z=f i in z)) in
  let normal storage=Geometry.with_attribute
    (Attribute.create_owned ~owner:Point ~name:"N" storage|>get_string_ok) bare|>get_string_ok in
  List.iter(fun original->
    let node=Lisp_sop.workspace_node ~with_:["source",Lisp_sop.snapshot original]
      {|(workspace query_guard
       (defnode sop/query_guard [(geo : geometry)]
        (sop/with_attr geo :Cd (exact
          (if (sop/has_attr geo :N :type vec3)
            (map (fn [n] n) (sop/attr geo :N :type vec3))
            (array/vec3 2 [0.25 0.5 0.75])))))
       (graph g :context sop (sop/query_guard (sop/ext_source))))|} in
    assert((Sop.Node.facts node).reads=["N"]);
    let first=ref None in
    List.iter(fun domains->let session=session() in
      Fun.protect ~finally:(fun()->Session.close session)(fun()->
        let output=cook session ~domains ~time:0. node|>geometry in
        let expected=match Geometry.find_attribute ~owner:Point "N" original with
          |Some attribute->(match Attribute.Private.storage attribute with Float3 normals->normals
            |_->tuple 2(fun _->0.25,0.5,0.75))
          |None->tuple 2(fun _->0.25,0.5,0.75) in
        let actual=Geometry.find_attribute ~owner:Point "Cd" output|>Option.get
          |>Attribute.get(Attribute.key ~owner:Point ~name:"Cd" Attribute.float3)|>Option.get in
        for i=0 to 1 do assert(Packed.Float3.get actual i=Packed.Float3.get expected i) done;
        let bytes=geometry_bytes output in
        (match !first with None->first:=Some bytes|Some previous->assert(previous=bytes)))) [1;8])
    [bare;normal(Attribute.Float[|1.;2.|]);
      normal(Attribute.Float3(tuple 2(fun i->float i,1.,2.)))];
  print_endline "Cooked has_attr Bool selects lazy typed reads; missing/wrong normals keep explicit fallback and truthful reads"

let () =
  let positions=Packed.Float3.Private.of_owned_exn ~x:[|0.;1.;0.;2.|]
    ~y:[|0.;0.;1.;2.|] ~z:[|0.;0.;0.;0.|] in
  let topology=Topology.polygons_owned ~point_count:4 ~vertex_points:[|0;1;2|]
    ~primitive_offsets:[|0;3|]|>get_string_ok in
  let attribute owner name storage=Attribute.create_owned ~owner ~name storage|>get_string_ok in
  let csr=Packed.Float_array.create_owned ~offsets:[|0;16;16;18;18|]
    ~values:(Array.init 18 float)|>get_string_ok in
  let original=Geometry.create ~positions ~topology ~attributes:[
    attribute Point "scalar" (Float[|1.;2.;3.;4.|]);attribute Vertex "scalar" (Float[|1.;2.;3.|]);
    attribute Point "csr" (Float_array csr)] ()|>get_string_ok in
  let source=Lisp_sop.snapshot original in
  let owner_zip=Lisp_sop.node ~with_:["source",source]
    {|(let* [geo (sop/ext_source)] (sop/with_attr geo :out
      (exact (map (fn [p v] (+ p v))
        (sop/attr geo :scalar :type float :owner point)
        (sop/attr geo :scalar :type float :owner vertex))) :type float))|} in
  let csr_zip=Lisp_sop.node ~with_:["source",source]
    {|(let* [geo (sop/ext_source) csr (sop/attr geo :csr :type float_array)]
      (sop/with_attr geo :out (exact (map (fn [p offset] (+ p (float offset)))
        (sop/attr geo :scalar :type float) csr.offsets)) :type float))|} in
  List.iter(fun domains->let session=session() in
    Fun.protect ~finally:(fun()->Session.close session)(fun()->
      (match cook session ~domains ~time:0. owner_zip with Error d->assert(d.code="E_ATTR_COUNT")|Ok _->assert false);
      let output=cook session ~domains ~time:0. csr_zip|>geometry in
      let values=Geometry.find_attribute ~owner:Point "out" output|>Option.get
        |>Attribute.get(Attribute.key ~name:"out" ~owner:Point Attribute.float)|>Option.get in
      assert(values=[|1.;18.;19.;22.|]))) [1;8];
  print_endline "Packed count origins distinguish point/vertex counts and CSR offsets from owner rows"

let () =
  let fixture detail =
    let geometry = Line_geometry.points [|0., 0., 0.; 1., 0., 0.|] in
    let attribute owner name values = Attribute.create_owned ~owner ~name (Attribute.Float values)
      |> get_string_ok in
    List.fold_left (fun geometry attribute -> Geometry.with_attribute attribute geometry |> get_string_ok)
      geometry [attribute Point "N" [|1.; 2.|]; attribute Detail "N" [|detail|];
        attribute Point "Cd" [|0.5; 0.75|]] in
  let first = fixture 1. in
  let changed = Geometry.with_attribute
    (Attribute.create_owned ~owner:Detail ~name:"N" (Attribute.Float [|2.|]) |> get_string_ok)
    first |> get_string_ok in
  let node = Lisp_sop.node ~with_:["source", Lisp_sop.snapshot first]
    {|(sop/delete_attr (sop/ext_source) "N" :owner "point")|} in
  assert ((Sop.Node.facts node).reads=[]);
  List.iter (fun domains ->
    let session = session () in
    Fun.protect ~finally:(fun () -> Session.close session) (fun () ->
      ignore (cook session ~domains ~time:0. node |> geometry);
      let source = Lisp_sop.snapshot changed in
      ignore (cook session ~domains ~time:0. source |> geometry);
      let before = Session.stats session in
      let result = cook session ~domains ~time:0.
        (Sop.Node.Private.rebuild_with_inputs node [|source|]) |> geometry in
      assert ((Session.stats session).misses=before.misses && (Session.stats session).hits=before.hits+2);
      let expected = Attribute_ops.delete ~point_pattern:"N" changed |> get_ok in
      assert (geometry_bytes result=geometry_bytes expected);
      List.iter (fun pattern ->
        let node = Lisp_sop.node ~with_:["source", source]
          (Printf.sprintf "(sop/delete_attr (sop/ext_source) %S :owner \"point\")" pattern) in
        assert ((Sop.Node.facts node).reads=["*"] && (Sop.Node.facts node).writes=["*"]);
        let result = cook session ~domains ~time:0. node |> geometry in
        let expected = Attribute_ops.delete ~point_pattern:pattern changed |> get_ok in
        assert (geometry_bytes result=geometry_bytes expected)) ["N*"; "N Cd"; "^Cd"])) [1;8];
  print_endline "Attribute deletion: selective refresh carries same-name owners; patterns stay conservative at one/eight domains"

let () =
  List.iter (fun count ->
    let positions = Packed.Float3.Private.of_owned_exn
      ~x:(Array.make count 0.) ~y:(Array.make count 0.) ~z:(Array.make count 0.) in
    let original = Geometry.create ~positions ~topology:(Topology.empty ~point_count:count) ()
      |> get_string_ok in
    let before = geometry_bytes original in
    let input = Sop.Node.Private.make_geometry ~operation:"test.xyz_write" ~version:1
      ~parameters:"" ~cook_mode:Sop.Node.Generator
      ~dependencies:Sop.Context.Dependencies.static ~inputs:[||]
      (fun ~node_id:_ _ _ -> Ok Sop.Node.Private.{geometry=original;diagnostics=[];instances=None}) in
    let values = Array.init (count * 3) (fun j ->
      if j mod 17 = 0 then -0. else match j mod 3 with
      | 0 -> float_of_int (j / 3) +. 0.125
      | 1 -> -.float_of_int (j / 3) -. 0.25
      | _ -> float_of_int (j / 3) *. 0.5 +. 0.375) in
    let expected = Marshal.to_string values [Marshal.No_sharing] in
    let first = ref None in
    List.iter (fun domains ->
      let session = session () in
      Fun.protect ~finally:(fun () -> Session.close session) (fun () ->
        let source = Array.copy values in
        let node values = Flow_sop.Attribute_kernel.node ~source:"xyz-write"
          ~name:"Cd" ~values:(E.Vec3_array values) ~sources:[0] [input] in
        let output = cook session ~domains ~time:0. (node source) |> geometry in
        let packed = Geometry.find_attribute ~owner:Attribute.Point "Cd" output |> Option.get
          |> Attribute.get (Attribute.key ~name:"Cd" ~owner:Attribute.Point Attribute.float3)
          |> Option.get |> Packed.Float3.Private.view in
        for i = 0 to count - 1 do
          assert (Int64.bits_of_float packed.x.(i) = Int64.bits_of_float values.(3*i));
          assert (Int64.bits_of_float packed.y.(i) = Int64.bits_of_float values.(3*i+1));
          assert (Int64.bits_of_float packed.z.(i) = Int64.bits_of_float values.(3*i+2))
        done;
        let bytes = geometry_bytes output in
        (match !first with None -> first:=Some bytes | Some first -> assert (first=bytes));
        assert (Marshal.to_string source [Marshal.No_sharing]=expected);
        Array.fill source 0 (Array.length source) 99.;
        assert (geometry_bytes output=bytes && geometry_bytes original=before);
        let failure values code = match cook session ~domains ~time:0. (node values) with
          | Error d -> assert (d.code=code && geometry_bytes original=before)
          | Ok _ -> assert false in
        failure (Array.make (count*3+3) 0.) "E_ATTR_COUNT";
        if count>0 then begin
          let bad = Array.copy values in bad.(Array.length bad-1)<-Float.infinity;
          failure bad "E_NONFINITE"
        end)) [1;8]) [0;32769];
  print_endline "XYZ attribute writes: empty/multi-block, signed-zero/domain bytes, ownership and error immutability pass"

let () =
  List.iter (fun count ->
    let plane component=Array.init count (fun i ->
      if (i+component) mod 7=0 then -0. else float_of_int (i+component)*.0.125) in
    let positions=Packed.Float3.Private.of_owned_exn ~x:(plane 0) ~y:(plane 1) ~z:(plane 2) in
    let original=Geometry.create ~positions ~topology:(Topology.empty ~point_count:count) () |> get_string_ok in
    let before=geometry_bytes original in
    let input=Sop.Node.Private.make_geometry ~operation:"test.borrowed_planes" ~version:1
      ~parameters:"" ~cook_mode:Sop.Node.Generator ~dependencies:Sop.Context.Dependencies.static ~inputs:[||]
      (fun ~node_id:_ _ _ -> Ok Sop.Node.Private.{geometry=original;diagnostics=[];instances=None}) in
    let make name body=
      let lowered=lower (source (Printf.sprintf "(sop/with_attr g :%s (exact %s))" name body)) in
      let call=Array.find_opt (fun (n:E.node)->n.kind="sop/with_attr") lowered.plan.nodes |> Option.get in
      let id=match List.assoc "geometry" call.args with E.Deferred (_,id)->id|_->assert false in
      Flow_sop.Attribute_kernel.node ~strict:true ~source:body ~name
        ~values:(List.assoc "values" call.args) ~sources:[id] [input] in
    let session=session () in
    Fun.protect ~finally:(fun ()->Session.close session) (fun ()->
      List.iter (fun domains ->
        let output=cook session ~domains ~time:0. (make "P" "(map (fn [p] p) (sop/attr g :P))") |> geometry in
        assert (geometry_bytes output=before);
        let old=Packed.Float3.Private.view positions and fresh=Packed.Float3.Private.view (Geometry.positions output) in
        assert (old.x==fresh.x && old.y==fresh.y && old.z==fresh.z);
        let painted=cook session ~domains ~time:0. (make "Cd" "(map (fn [p] p) (sop/attr g :P))") |> geometry in
        let copied=Geometry.find_attribute ~owner:Attribute.Point "Cd" painted |> Option.get
          |> Attribute.get (Attribute.key ~name:"Cd" ~owner:Attribute.Point Attribute.float3) |> Option.get
          |> Packed.Float3.Private.view in
        assert (old.x!=copied.x && old.y!=copied.y && old.z!=copied.z);
        assert (Marshal.to_string [|old.x;old.y;old.z|] [Marshal.No_sharing]
          =Marshal.to_string [|copied.x;copied.y;copied.z|] [Marshal.No_sharing]);
        if count>1 then begin
          let short=make "P" "(map (fn [p q] p) (sop/attr g :P) (array/vec3 1))" in
          match cook session ~domains ~time:0. short with
          | Error d -> assert (d.code="E_ATTR_COUNT") | Ok _ -> assert false
        end;
        assert (geometry_bytes original=before)) [1;8])) [0;1;32769];
  print_endline "Borrowed exact planes: omitted-lane counts, shared P, owned attributes and signed-zero/domain bytes pass"

let () =
  let lowered=lower {|(workspace captures
    (graph mesh :context sop [(offset : float 0.015625)]
      (let* [geo (sop/box :consolidate_points true :center [(+ offset (* t 0.015625)) 0 0])
             p (reduce + [0 0 0] (sop/attr geo :P))
             picture (image/map (fn [uv] [(+ uv.x p.x) uv.y 0.5 1]) :width 7 :height 3)]
        (sop/attr_from_image geo picture :attribute "Cd")))
    (graph other :context sop (ref mesh :offset 0.03125)))|} in
  let graph=List.find(fun(g:L.graph)->g.name="mesh" && not g.default)lowered.graphs in
  let producer=Array.find_opt(fun(n:E.node)->n.kind="image/map" && n.inst=graph.instance)
      lowered.plan.nodes |> Option.get in
  let fn=match List.assoc "function" producer.args with E.Fn fn->fn|_->assert false in
  let sources=Flow_sop.Attribute_kernel.sources(E.Fn fn)in
  assert(List.length sources=1);
  let source=List.hd sources in
  let context=L.source_context lowered ~node:source |> flow_ok in
  assert(context.network==graph.network);
  let network,root=L.source_cone context ~node:source |> flow_ok in
  assert(List.length(Edit.inspect network.geometry)=1);
  assert(not(Flow_sop.Port.Map.is_empty network.drives));
  assert(Flow_sop.Network.Int_map.is_empty network.frame_nodes);
  assert(not(Flow_sop.Network.Int_map.is_empty context.network.frame_nodes));
  List.iter(fun context->match L.source_cone context ~node:source with
    |Error d->assert(d.code="E_DATA_SOURCE")|Ok _->assert false)
    [L.{context with compiled=Flow_sop.Network.Int_map.empty};
     L.{context with compiled=Flow_sop.Network.Int_map.singleton source (Sop.Node.Private.fresh_id())}];
  List.iter(fun id->match L.source_context lowered ~node:id with
    |Error d->assert(d.code="E_DATA_SOURCE")|Ok _->assert false)[-1;Array.length lowered.plan.nodes;producer.id];
  let resolve time=
    let live=Frame_input.at_time time in
    let lane=Flow_sop.Value_lane.create()in
    (* A whole-network resolution would call the deliberately absent image provider. *)
    let resolved=Flow_sop.Value_lane.resolve lane ~live ~time network |> flow_ok in
    Edit.compile_node resolved.geometry ~node_id:root |> get_string_ok in
  let input=resolve 0. in
  let kernel=Flow_sop.Image_kernel.prepare ~identity:1 ~width:7 ~height:3 ~fn ~sources [input] |> flow_ok in
  let bytes domains kernel=
    let session=session()in
    Fun.protect ~finally:(fun()->Session.close session)(fun()->
      let image=cook session ~domains ~time:0. (Flow_sop.Image_kernel.node kernel)
        |> Result.get_ok |> fun output->Sop.Payload.image output.payload |> Result.get_ok in
      Sop.Image.Private.rgba8 image |> Option.get)in
  let initial=bytes 1 kernel in
  assert(initial=bytes 8 kernel);
  if Char.code(Bytes.get initial 0)<>82 then
    failwith(Printf.sprintf "override first red: expected 82, got %d" (Char.code(Bytes.get initial 0)));
  let current=resolve 1. in
  assert(current!=input);
  assert(Flow_sop.Attribute_kernel.source_origins ~sources [current]
    =Flow_sop.Attribute_kernel.source_origins ~sources [input]);
  let rebound=Flow_sop.Image_kernel.with_inputs kernel [current] |> flow_ok in
  assert(Flow_sop.Image_kernel.program rebound==Flow_sop.Image_kernel.program kernel);
  let independently_prepared=Flow_sop.Image_kernel.prepare ~identity:2 ~width:7 ~height:3
    ~fn ~sources [current] |> flow_ok in
  let changed=bytes 1 rebound in
  assert(changed<>initial && changed=bytes 8 rebound && changed=bytes 1 independently_prepared);
  List.iter(fun inputs->match Flow_sop.Image_kernel.with_inputs kernel inputs with
    |Error d->assert(d.code="E_DATA_SOURCE")|Ok _->assert false)
    [[];[Lisp_sop.node {|(sop/box)|}]];
  let session=session()in
  Fun.protect ~finally:(fun()->Session.close session)(fun()->
    let original=cook session ~domains:1 ~time:0. input |> geometry in
    let transforms=[|Rays_math.Mat4.translation(Rays_math.Vec3.create 1. 0. 0.);
      Rays_math.Mat4.translation(Rays_math.Vec3.create 3. 0. 0.)|]in
    let packed=Sop.Node.Private.make_geometry ~operation:"test.capture.instances" ~version:1
      ~parameters:"" ~cook_mode:Sop.Node.Generator
      ~dependencies:Sop.Context.Dependencies.static ~inputs:[||]
      (fun ~node_id:_ _ _->Ok Sop.Node.Private.{geometry=original;diagnostics=[];instances=Some transforms})in
    let consumer=Flow_sop.Attribute_kernel.materialized_source packed in
    List.iter(fun domains->
      let output=cook session ~domains ~time:0. consumer |> Result.get_ok in
      assert(output.instances=None);
      let materialized=Sop.Payload.geometry output.payload |> Result.get_ok in
      let expected=Rdk.Instance_copy.materialize_instances ~transforms original |> get_ok in
      assert(Geometry.point_count materialized=2*Geometry.point_count original);
      assert(geometry_bytes materialized=geometry_bytes expected);
      let attribute=E.Struct("sop/attr",Flow.Ty.Array Flow.Ty.Vec3,
        ["geometry",E.Deferred(Flow.Ty.geometry,source);"attribute",E.Text "P"])in
      let positions=Flow_sop.Attribute_kernel.resolve ~geometry:(fun id->
        if id=source then Some materialized else None)attribute |> flow_ok in
      match positions with E.Vec3_array xs->assert(Array.length xs=6*Geometry.point_count original)|_->assert false)
      [1;8]);
  print_endline "image capture foundation: live override cone, no downstream image callback, shared program proof and materialized instance P pass"

let () =
  let text = "(workspace field (graph g :context sop
    (sop/iso_surface :field (fn [p] (- (length p) (+ 1 t)))
      :resolution [64 64 64] :min [-2.1 -2 -2] :max [2 2 2] :iso 0)))" in
  let lowered = lower text in
  let call = Array.find_opt (fun (n : E.node) -> n.kind = "sop/iso_surface")
      lowered.plan.nodes |> Option.get in
  let fn = match List.assoc "field" call.args with E.Fn fn -> fn | _ -> assert false in
  (* Independent index decomposition pins all 65^3 positions and x-fast order. *)
  let positions = Array.init (65 * 65 * 65 * 3) (fun j ->
    let i = j / 3 in
    let index = match j mod 3 with 0 -> i mod 65 | 1 -> (i / 65) mod 65 | _ -> i / (65*65) in
    (* x is a non-dyadic lattice: the probe must use the same fused multiply-add as the cook. *)
    if j mod 3 = 0 then Float.fma (float_of_int index) (4.1 /. 64.) (-2.1)
    else Float.fma (float_of_int index) (4. /. 64.) (-2.)) in
  let values = E.Private.map_function ~signature:Flow.Ty.{params = [Vec3]; result = Float}
      fn [E.Vec3_array positions] |> flow_ok in
  let program = Flow_sop.Attribute_kernel.prepare ~sources:[] [] values |> flow_ok in
  let ir = Flow_ir.Executor.graph program in
  let packed = match ir.nodes.(ir.roots.(0)).kind with
    | Flow_ir.Kernel {body = Packed_map packed; _} -> packed | _ -> assert false in
  assert (Flow_ir.Packed.static_count packed = Some (65 * 65 * 65));
  (* Separately rounded squares, as the Lisp primitives: arm64 ocamlopt would otherwise fuse a +. b *. c. *)
  let sq v = Sys.opaque_identity (v *. v) in
  List.iter (fun time ->
    let live = Frame_input.at_time time in
    let expected = Array.init (65 * 65 * 65) (fun i ->
      let x = positions.(3*i) and y = positions.(3*i+1) and z = positions.(3*i+2) in
      sqrt ((sq x +. sq y) +. sq z) -. (1. +. time)) in
    let reference = Flow_ir.Executor.force ~reference:true program ~live |> flow_ok in
    assert (reference = E.Float_array expected);
    let dense = Iso_surface.extract_dense ~resolution:(64,64,64)
        ~min:(Rays_math.Vec3.create (-2.1) (-2.) (-2.)) ~max:(Rays_math.Vec3.create 2. 2. 2.)
        ~iso:0. ~field:(Iso_surface.Field.custom (fun p ->
          sqrt ((sq p.(0) +. sq p.(1)) +. sq p.(2)) -. (1. +. time))) ()
      |> get_ok |> geometry_bytes in
    List.iter (fun domains ->
      let actual = Rays_math.Parallel.run ~domains (fun () ->
        Flow_ir.Packed.force packed ~live |> flow_ok) in
      assert (actual = reference);
      let cook_session = session () in
      Fun.protect ~finally:(fun () -> Session.close cook_session) (fun () ->
        assert (geometry_bytes (cook cook_session ~domains ~time (compiled lowered) |> geometry) = dense));
      let reference_lowered = L.workspace ~factories ~reference:true
          (Flow.Syntax.parse text |> flow_ok) |> flow_ok in
      let cook_session = session () in
      Fun.protect ~finally:(fun () -> Session.close cook_session) (fun () ->
        assert (geometry_bytes (cook cook_session ~domains ~time (compiled reference_lowered) |> geometry) = dense)))
      [1;8]) [0.;0.25];
  let forms = Flow.Syntax.parse text |> flow_ok in
  let checked, diagnostics = Flow.Workspace.check ~ops:Flow_sop.Operators.all catalog forms in
  assert (diagnostics = []);
  let pane = Flow_graph.Projection.of_graph catalog (Option.get checked) "g" in
  let surface = List.find (fun (n : Flow_graph.Projection.node) -> n.head = "sop/iso_surface") pane.nodes in
  assert (List.exists (fun (row : Flow_graph.Projection.row) -> row.label = "field") surface.rows);
  let zone = List.find (fun (n : Flow_graph.Projection.node) ->
    Option.fold ~none:false ~some:(fun (z : Flow_graph.Projection.zone) -> z.kind = Fn) n.zone) pane.nodes in
  assert (List.exists (fun (r : Flow_graph.Projection.rail_row) -> r.name = "p" && r.ty = Some Flow.Ty.Vec3)
    (Option.get zone.zone).rail);
  let calls = L.field_calls ~live:(Frame_input.at_time 0.25)
      ~resolve:(fun v -> Ok v) lowered in
  let forced_calls = ref 0 in
  let bulk_calls path outer = List.map (fun (offset, count, at) ->
    offset, count, (fun k -> incr forced_calls; at k)) (calls path outer) in
  let probe = Flow_graph.Probe.make ~live:(Frame_input.at_time 0.25) ~bulk_calls lowered.evaluated in
  let counts = Flow_graph.Probe.counts probe pane ~probe:(fun _ -> 0) in
  let count = match List.assoc_opt zone.path counts with
    | Some count -> count
    | None -> let scope, iter = E.Private.function_scope fn |> Option.get in
        failwith (Printf.sprintf "field probe: projection %s, function %s/%s, counts %s"
          (String.concat "/" zone.path) (String.concat "/" scope)
          (String.concat "," (List.map string_of_int iter))
          (String.concat ";" (List.map (fun (p,n) -> String.concat "/" p ^ ":" ^ string_of_int n) counts))) in
  assert (count = 65*65*65);
  let k = 16062 in
  let x = positions.(3*k) and y = positions.(3*k+1) and z = positions.(3*k+2) in
  let sample = sqrt ((sq x +. sq y) +. sq z) -. 1.25 in
  assert (Flow_graph.Probe.at probe (zone.path @ [":p"]) ~probes:[k] = Some (Value (E.Vec3 (x,y,z))));
  assert (Flow_graph.Probe.at probe (zone.path @ ["@result"]) ~probes:[k] = Some (Value (E.Float sample)));
  assert (!forced_calls = 1);
  let body = Flow_graph.Projection.find pane (zone.path @ ["@result"]) |> Option.get in
  ignore (Flow_graph.Probe.footer probe body ~probes:[k]);
  assert (!forced_calls <= 65);
  let forced = !forced_calls in
  ignore (Flow_graph.Probe.footer probe body ~probes:[k]);
  assert (!forced_calls = forced);
  ignore (Flow_graph.Flow_edit.apply_checked ~ops:Flow_sop.Operators.all catalog forms
    (Set_arg {node = surface.path; key = Kw "resolution"; sub = [];
      value = Flow.Syntax.parse "[8 9 7]" |> flow_ok |> List.hd}) |> flow_ok);
  print_endline "field SOP: complete grid kernel/reference/domain/mesh parity and graph gestures pass"

let () =
  (* Non-dyadic, off-centre samples expose accidental multiply/add contraction. *)
  let positions = Array.init (130 * 257 * 3 * 3) (fun j ->
    let i = j / 3 in
    match j mod 3 with
    | 0 -> Float.fma (float_of_int (i mod 130)) (5. /. 129.) (-2.)
    | 1 -> Float.fma (float_of_int ((i / 130) mod 257)) (3.5 /. 256.) (-1.5)
    | _ -> Float.fma (float_of_int (i / (130 * 257))) (2.7 /. 2.) (-1.)) in
  let prepare expression =
    let lowered = lower ("(workspace rounding (graph g :context sop
      (sop/iso_surface :field (fn [p] " ^ expression ^ ") :resolution [129 256 2]
        :min [-2 -1.5 -1] :max [3 2 1.7])))") in
    let call = Array.find_opt (fun (n : E.node) -> n.kind = "sop/iso_surface")
      lowered.plan.nodes |> Option.get in
    let fn = match List.assoc "field" call.args with E.Fn fn -> fn | _ -> assert false in
    let values = E.Private.map_function ~signature:Flow.Ty.{params = [Vec3]; result = Float}
      fn [E.Vec3_array positions] |> flow_ok in
    Flow_sop.Attribute_kernel.prepare ~sources:[] [] values |> flow_ok in
  let derived = prepare "(- (length (- p [0.2 -0.3 0.1])) (+ 0.8 t))"
  and primitives = prepare "(let* [q (- p [0.2 -0.3 0.1])]
    (- (sqrt (+ (+ (* q.x q.x) (* q.y q.y)) (* q.z q.z))) (+ 0.8 t)))" in
  let same_bits actual expected = match actual, expected with
    | E.Float_array actual, E.Float_array expected ->
        assert (Array.length actual = Array.length expected);
        Array.iteri (fun i value ->
          if Int64.bits_of_float value <> Int64.bits_of_float expected.(i) then
            failwith (Printf.sprintf "field length rounding differs at sample %d: %.17g / %.17g"
              i value expected.(i))) actual
    | _ -> assert false in
  List.iter (fun time ->
    let live = Frame_input.at_time time in
    let expected = Flow_ir.Executor.force ~reference:true primitives ~live |> flow_ok in
    same_bits (Flow_ir.Executor.force ~reference:true derived ~live |> flow_ok) expected;
    List.iter (fun domains -> Rays_math.Parallel.run ~domains (fun () ->
      List.iter (fun program ->
        same_bits (Flow_ir.Executor.force program ~live |> flow_ok) expected)
        [derived; primitives])) [1;8]) [0.;0.25];
  print_endline "field length: asymmetric lattice matches primitive/scalar/packed float64 bits"

let () =
  let text = "(workspace probe (graph g :context sop
    (let* [field (fn [p] p.x)
           preview (map field (array/vec3 2 [1 0 0]))
           a (sop/iso_surface :field field :resolution [1 1 1])
           b (sop/iso_surface :field field :resolution [2 1 1])]
      (sop/merge a b))))" in
  let lowered = lower text in
  let forms = Flow.Syntax.parse text |> flow_ok in
  let workspace, ds = Flow.Workspace.check ~ops:Flow_sop.Operators.all catalog forms in
  assert (ds = []);
  let pane = Flow_graph.Projection.of_graph catalog (Option.get workspace) "g" in
  let calls = L.field_calls ~live:(Frame_input.at_time 0.) ~resolve:(fun v -> Ok v) lowered in
  let selectors = calls ["g";"field"] [] in
  assert (List.map (fun (offset,count,_) -> offset,count) selectors = [0,8; 8,12]);
  let probe = Flow_graph.Probe.make ~bulk_calls:calls lowered.evaluated in
  assert (List.assoc ["g";"field"] (Flow_graph.Probe.counts probe pane ~probe:(fun _ -> 0)) = 22);
  List.iter (fun (k,expected) ->
    assert (Flow_graph.Probe.at probe ["g";"field";"@result"] ~probes:[k]
      = Some (Value (E.Float expected)))) [0,1.; 1,1.; 2,(-2.); 9,2.; 10,(-2.); 21,2.];
  assert (Flow_graph.Probe.at probe ["g";"field";"@result"] ~probes:[22] = None)

let () =
  let lowered = lower "(workspace probe_state (graph g :context sop
    (let* [total (state [s 0.0] (+ s 1.0))
           field (fn [p] (+ p.x total))]
      (sop/iso_surface :field field :resolution [1 1 1]))))" in
  let state = E.create_state () in
  let before = E.state_stamp state in
  let calls = L.field_calls ~state ~live:(Frame_input.at_time 1.) ~resolve:(fun v -> Ok v) lowered in
  let probe = Flow_graph.Probe.make ~state ~live:(Frame_input.at_time 1.) ~bulk_calls:calls lowered.evaluated in
  assert (Flow_graph.Probe.at probe ["g";"field";"@result"] ~probes:[0] = Some (Value (E.Float (-1.))));
  assert (E.state_stamp state = before)

let () =
  (* Real Lisp lowering, not a hand-built Readback IR: GPU callbacks run before
     worker cooking, and workers receive only an owned exact CPU snapshot. *)
  let count=2048 and calls=ref 0 and reads=ref 0 and time=ref 0. in
  let backend:Flow_ir.Gpu.backend={cost=(fun _ ~count:_->Some 0.);
    prepare=(fun _->assert(Domain.is_main_domain());Ok {
      run=(fun inputs->assert(Domain.is_main_domain());assert(inputs.count=count);
        incr calls;Ok {identity=1;count;width=3;stamp=Int64.of_int !calls;gpu_seconds=None});
      readback=(fun _->assert(Domain.is_main_domain());incr reads;
        Ok(E.Vec3_array(Array.init(count*3)(fun j->if j mod 3=0 then float(j/3)+. !time else 0.))))})} in
  let body wrap="(sop/with_attr g :P ("^wrap^
    "(map (fn [i] [(+ i t) 0 0]) (array/range 2048))))" in
  let exact=lower(source ~columns:1024 (body "exact ")) in
  let network=(List.hd exact.graphs).network in
  let lane=Flow_sop.Value_lane.create() in
  List.iter(fun t->time:=t;
    let resolved=Flow_ir.Gpu.with_backend backend(fun()->
      Flow_sop.Value_lane.resolve lane ~time:t network |> flow_ok) in
    let node=Edit.compile_node resolved.geometry ~node_id:(Option.get(List.hd exact.graphs).root)
      |>get_string_ok in
    List.iter(fun domains->let session=session()in
      Fun.protect ~finally:(fun()->Session.close session)(fun()->
        let positions=cook session ~domains ~time:t node |> geometry |>Geometry.positions in
        for i=0 to count-1 do assert(Packed.Float3.get positions i=(float i+.t,0.,0.))done)) [1;8]) [0.;0.5];
  assert(!calls=2 && !reads=2);
  let unmeasured={backend with cost=(fun _ ~count:_->None)}in
  ignore(Flow_ir.Gpu.with_backend unmeasured(fun()->Flow_sop.Value_lane.resolve
    (Flow_sop.Value_lane.create()) ~time:0.75 network)|>flow_ok);
  assert(!calls=2);
  time:=0.75;
  ignore(Flow_ir.Gpu.with_backend ~policy:Flow_ir.Gpu.Qualification unmeasured(fun()->
    Flow_sop.Value_lane.resolve (Flow_sop.Value_lane.create()) ~time:0.75 network)|>flow_ok);
  assert(!calls=3 && !reads=3);
  let baseline= !calls in
  let cpu=Flow_sop.Value_lane.create()in
  ignore(Flow_sop.Value_lane.resolve cpu ~time:1. network |>flow_ok);
  let reference=L.workspace ~factories ~reference:true
    (Flow.Syntax.parse(source ~columns:1024(body "exact "))|>flow_ok)|>flow_ok in
  ignore(Flow_ir.Gpu.with_backend backend(fun()->Flow_sop.Value_lane.resolve
    (Flow_sop.Value_lane.create()) ~time:1. (List.hd reference.graphs).network)|>flow_ok);
  assert(!calls=baseline);
  let unwrapped=Flow.Syntax.parse(source ~columns:1024
    "(sop/with_attr g :P (map (fn [i] [(+ i t) 0 0]) (array/range 2048)))") |> flow_ok in
  (match Flow.Workspace.check ~ops:Flow_sop.Operators.all catalog unwrapped with
    |None, ds->assert(List.exists(fun(d:Flow.Diagnostic.t)->d.code="E_APPROX_SINK")ds)
    |_->assert false)
let () =
  assert (Result.is_error (Flow_sop.Attribute_kernel.prepare ~sources:[0] [] E.No_geo));
  List.iter (fun (other, expected_stages) ->
    let body = "(let* [other " ^ other ^
      " a (map (fn [p] (+ p [t 0 0])) (sop/attr g :P))" ^
      " b (map (fn [p] (* p (+ t 1))) (sop/attr other :P))]" ^
      " (sop/with_attr g :P (exact (map (fn [left right] (+ left right)) a b))))" in
    let l = lower (source ~columns:1025 body) in
    let node = compiled l in
    let call = Array.find_opt (fun (n : E.node) -> n.kind = "sop/with_attr") l.plan.nodes |> Option.get in
    let values = List.assoc "values" call.args in
    let main = match List.assoc "geometry" call.args with E.Deferred (_, id) -> id | _ -> assert false in
    let sources = main :: List.filter ((<>) main) (Flow_sop.Attribute_kernel.sources values) in
    let inputs = Sop.Node.inputs node in
    let prepare inputs = Flow_sop.Attribute_kernel.prepare ~sources inputs values |> flow_ok in
    assert (stages (Flow_ir.Executor.compile values |> flow_ok) = 1);
    let program = prepare inputs in
    assert (stages program = expected_stages);
    if expected_stages = 3 && List.length inputs > 1 then begin
      let change field = List.mapi (fun i node -> if i = 0 then node else
        Sop.Node.Private.with_facts (field (Sop.Node.facts node)) node) inputs in
      assert (stages (prepare (change (fun facts -> {facts with topology = Changed}))) = 1);
      assert (stages (prepare (change (fun facts -> {facts with elementwise = None}))) = 1);
      assert (stages (prepare (change (fun facts -> {facts with elementwise = Primitives}))) = 3)
    end;
    let session = session () in
    Fun.protect ~finally:(fun () -> Session.close session) (fun () ->
      let source_geometries = List.map (fun input -> cook session ~domains:1 ~time:0. input |> geometry) inputs in
      let resolve = Flow_sop.Attribute_kernel.resolve ~geometry:(fun id ->
        Option.bind (List.find_index ((=) id) sources) (fun index -> List.nth_opt source_geometries index)) in
      List.iter (fun time ->
        let live = Frame_input.at_time time in
        let expected = E.Private.force_reference ~resolve values ~live |> flow_ok in
        List.iter (fun domains -> Rays_math.Parallel.run ~domains (fun () ->
          let actual = Flow_ir.Executor.force ~resolve program ~live |> flow_ok in
          assert (Marshal.to_string actual [Marshal.No_sharing] = Marshal.to_string expected [Marshal.No_sharing])))
          [1;8]) [0.;0.125;1.25;7.]))
    ["g", 3; "(sop/transform g :translate [0 0 1])", 3;
     "(sop/grid :counts \"Point counts\" :connectivity \"Points\" :columns 1025 :rows 2)", 1;
     "(sop/scatter (sop/grid) :count 2050 :seed 9)", 1]
let () =
  let empty = Kernel.generate_point_ranges 0 (fun ~first:_ ~last:_ ~x:_ ~y:_ ~z:_ -> ()) in
  let empty_input = Sop.Node.Private.make_geometry ~operation:"empty_fixture" ~version:1
    ~parameters:"" ~cook_mode:Sop.Node.Generator
    ~dependencies:Sop.Context.Dependencies.static ~inputs:[||]
    (fun ~node_id:_ _ _ -> Ok Sop.Node.Private.{geometry=empty; diagnostics=[]; instances=None}) in
  let empty_write = Flow_sop.Attribute_kernel.node ~source:"empty"
    ~name:"P" ~values:(E.Struct ("sop/attr", Flow.Ty.Array Flow.Ty.Vec3,
      ["geometry", E.Deferred (Flow.Ty.geometry,0); "attribute", E.Text "P"]))
    ~sources:[0] [empty_input] in
  let output = Sop.Node.Private.cook empty_write (context ~domains:8 0.) [|Sop.Payload.Geometry empty|] in
  (match output with Ok output -> assert (geometry_bytes (Result.get_ok (Sop.Payload.geometry output.payload)) = geometry_bytes empty)
    | Error d -> failwith (Sop.Diagnostic.error_to_string d));
  let cancel = Cancel.create () in
  Cancel.cancel cancel;
  let cancelled = Sop.Context.create ~cancel ~domains:1 () |> get_string_ok in
  (match Sop.Node.Private.cook empty_write cancelled [|Sop.Payload.Geometry empty|] with
   | Error d -> assert (d.code = "E_CANCELLED") | Ok _ -> assert false);
  List.iter (fun columns ->
    List.iter (fun amp ->
      let l = lower (source ~columns ~amp noise_body) in
      let node = compiled l and session = session () in
      Fun.protect ~finally:(fun () -> Session.close session) (fun () ->
        let ref_node = reference l node in
        List.iter (fun time ->
          let base = cook session ~domains:1 ~time (List.hd (Sop.Node.inputs node)) |> geometry in
          let before = geometry_bytes base in
          let amplitude = if amp = "0.8" then 0.8 else 0.8 +. time *. 0.1 in
          let native = Deform.noise_displace ~mode:Deform.Normal_3d ~seed:0
            ~amplitude ~frequency:0.16 base |> get_ok in
          List.iter (fun domains -> Rays_math.Parallel.run ~domains (fun () ->
            let output = cook session ~domains ~time node |> geometry in
            assert (List.exists (fun (report : Flow_ir.execution) -> report.tier = Cpu_kernel)
              (Flow_ir.Profile.executions l.profile));
            let reference = cook session ~domains ~time ref_node |> geometry in
            assert (geometry_bytes (output
              |> Geometry.without_attribute ~owner:Attribute.Point "N"
              |> Geometry.without_attribute ~owner:Attribute.Vertex "N") = geometry_bytes native);
            assert (geometry_bytes output = geometry_bytes reference);
            assert (Geometry.topology output == Geometry.topology base))) [1;8];
          assert (geometry_bytes base = before)) [0.;0.125;1.25;7.]))
      ["0.8"; "(+ 0.8 (* t 0.1))"]) [1; 511; 512; 1025; 8193];
  let l = lower (source noise_body) in
  let disconnected = lower "(workspace w (graph g :context sop (sop/with_attr nil :P (array/vec3 4))))" in
  let graph = List.hd disconnected.graphs in
  assert (Result.is_error (Edit.compile_node graph.network.geometry ~node_id:(Option.get graph.root)));
  let named_body = "(let* [f (fn [p n] (+ p (* n (* amp (noise3 (* p freq))))))] (sop/with_attr g :P (exact (map f (sop/attr g :P) (sop/attr g :N)))))" in
  let named = lower (source ~columns:1025 named_body) in
  let call = Array.find_opt (fun (n : E.node) -> n.kind = "sop/with_attr") named.plan.nodes |> Option.get in
  let program = Flow_ir.Executor.compile (List.assoc "values" call.args) |> flow_ok in
  assert (Array.exists (fun (node : Flow_ir.node) -> node.tier = Cpu_kernel && node.rate = Static)
    (Flow_ir.Executor.graph program).nodes);
  let session = session () in
  Fun.protect ~finally:(fun () -> Session.close session) (fun () ->
    let node = compiled named in
    let a = cook session ~domains:1 ~time:0. node |> geometry in
    let b = cook session ~domains:8 ~time:0. (reference named node) |> geometry in
    assert (geometry_bytes a = geometry_bytes b);
    let first = cook session ~domains:1 ~time:0. (compiled l) |> geometry |> geometry_bytes in
    let changed = lower ~previous:l (source ~amp:"1.8" noise_body) in
    let second = cook session ~domains:1 ~time:0. (compiled changed) |> geometry |> geometry_bytes in
    assert (first <> second);
    List.iter (fun (body, code) ->
      let l = lower (source body) in
      match cook session ~domains:1 ~time:0. (compiled l) with
      | Error d -> assert (d.code = code)
      | Ok _ -> failwith ("accepted " ^ code))
      ["(sop/with_attr g :P (array/vec3 1))", "E_ATTR_COUNT";
       "(sop/with_attr g :P (sop/attr g :missing))", "E_ATTR_TYPE"];
    let l = lower (source "(sop/with_attr g :Cd (exact (map (fn [p] (* p 0.5)) (sop/attr g :P))))") in
    let output = cook session ~domains:8 ~time:0. (compiled l) |> geometry in
    let cd = Geometry.find_attribute ~owner:Attribute.Point "Cd" output |> Option.get in
    assert (Attribute.length cd = Geometry.point_count output);
    let l = lower (source "(let* [painted (sop/with_attr g :Cd (sop/attr g :P))] (sop/with_attr painted :P (sop/attr painted :Cd)))") in
    let output = cook session ~domains:1 ~time:0. (compiled l) |> geometry in
    assert (Geometry.find_attribute ~owner:Attribute.Point "Cd" output <> None);
    let l = lower (source ~amp:"(state [a 0.8] (+ a 0.1))" noise_body) in
    let graph = List.hd l.graphs and lane = Flow_sop.Value_lane.create () in
    List.iter (fun frame ->
      let time = float frame *. 0.125 in
      let live = { (Frame_input.at_time time) with frame } in
      let resolved = Flow_sop.Value_lane.resolve ~live lane ~time graph.network |> flow_ok in
      let node = Edit.compile_node resolved.geometry ~node_id:(Option.get graph.root) |> get_string_ok in
      let context = Sop.Context.create ~input:live ~time ~frame:(Int64.of_int frame)
        ~domains:8 () |> get_string_ok in
      let output = Session.cook session ~context node |> geometry in
      let base = Session.cook session ~context (List.hd (Sop.Node.inputs node)) |> geometry in
      let amplitude = List.fold_left (fun a _ -> a +. 0.1) 0.8 (List.init (frame + 1) Fun.id) in
      let native = Deform.noise_displace ~mode:Deform.Normal_3d ~seed:0 ~amplitude ~frequency:0.16 base |> get_ok in
      assert (geometry_bytes (Geometry.without_attribute ~owner:Attribute.Point "N" output) = geometry_bytes native))
      [0;1;2]);
  let forms = Flow.Syntax.parse (source noise_body) |> flow_ok in
  let bare = lower (source "(with_attr g :P (attr g :P))") in
  assert (Array.exists (fun (n : E.node) -> n.kind = "sop/with_attr") bare.plan.nodes);
  let reader = lower (source "(let* [arrays (map sop/attr (list g) (list \"P\"))] (sop/with_attr g :P (first arrays)))") in
  let s = Session.create ~max_entries:32 ~max_payload_bytes:(64 * 1024 * 1024) |> get_string_ok in
  Fun.protect ~finally:(fun () -> Session.close s) (fun () ->
    let node = compiled reader in
    let original = cook s ~domains:1 ~time:0. (List.hd (Sop.Node.inputs node)) |> geometry in
    let copy = cook s ~domains:8 ~time:0. node |> geometry in
    assert (geometry_bytes original = geometry_bytes copy));
  let ws = match Flow.Workspace.check ~ops:Flow_sop.Operators.all catalog forms with
    | Some w, [] -> w | _ -> assert false in
  let pane = Flow_graph.Projection.of_graph catalog ws "g" in
  let result = Flow_graph.Projection.find pane ["g";"result"] |> Option.get in
  assert (List.map (fun (r : Flow_graph.Projection.row) -> r.label) result.rows = ["geometry";"attribute";"values";"owner";"type"]);
  let fn = List.find (fun (node : Flow_graph.Projection.node) ->
    Option.fold ~none:false ~some:(fun (zone : Flow_graph.Projection.zone) -> zone.kind = Fn) node.zone)
      pane.nodes in
  let rails = (Option.get fn.zone).rail in
  assert (List.for_all (fun name -> List.exists (fun (rail : Flow_graph.Projection.rail_row) ->
    rail.name = name && rail.ty = Some Flow.Ty.Vec3) rails) ["p"; "n"]);
  let large = lower (source ~columns:8193 ~amp:"(+ 0.8 (* t 0.1))" noise_body) in
  let probe_session = Session.create ~max_entries:32 ~max_payload_bytes:(64 * 1024 * 1024) |> get_string_ok in
  Fun.protect ~finally:(fun () -> Session.close probe_session) (fun () ->
    let node = compiled large in
    let base = cook probe_session ~domains:8 ~time:1.25 (List.hd (Sop.Node.inputs node)) |> geometry in
    let geometry_id = Array.find_opt (fun (n : E.node) -> n.kind = "sop/grid") large.plan.nodes
      |> Option.get |> fun n -> n.id in
    let reads = ref 0 in
    let resolve value = incr reads;
      Flow_sop.Attribute_kernel.resolve ~geometry:(fun id -> if id = geometry_id then Some base else None) value in
    let checked = match Flow.Workspace.check ~ops:Flow_sop.Operators.all catalog
      (Flow.Syntax.parse (source ~columns:8193 ~amp:"(+ 0.8 (* t 0.1))" noise_body) |> flow_ok) with
      | Some checked, ds when List.for_all (fun (d : Flow.Diagnostic.t) -> d.severity <> Error) ds -> checked
      | _, ds -> failwith (String.concat "\n" (List.map Flow.Diagnostic.to_string ds)) in
    let pane = Flow_graph.Projection.of_graph catalog checked "g" in
    let probe = Flow_graph.Probe.make ~time:1.25 ~resolve large.evaluated in
    assert (List.assoc fn.path
      (Flow_graph.Probe.counts probe pane ~probe:(fun _ -> 0)) = Geometry.point_count base);
    let body = Flow_graph.Projection.find pane (fn.path @ ["@result"]) |> Option.get in
    let before = geometry_bytes base in
    let footer = Flow_graph.Probe.footer probe body ~probes:[16001] in
    assert (footer.runs = Some (Geometry.point_count base));
    let expected = Deform.noise_displace ~mode:Deform.Normal_3d ~seed:0 ~amplitude:(0.8 +. 1.25 *. 0.1)
      ~frequency:0.16 base |> get_ok |> Geometry.positions |> fun p -> Packed.Float3.get p 16001 in
    let x, y, z = expected in
    assert (Flow_graph.Probe.at probe body.path ~probes:[16001] = Some (Flow_graph.Probe.Value (E.Vec3 (x, y, z))));
    assert (!reads = 2);
    ignore (Flow_graph.Probe.footer probe body ~probes:[16001]);
    assert (!reads = 2 && geometry_bytes base = before);
    let _, changed = Flow_graph.Flow_edit.apply_checked ~ops:Flow_sop.Operators.all catalog
      checked.source (Flow_graph.Flow_edit.Set_arg {node = body.path; key = Pos 0; sub = [];
        value = Flow.Syntax.make (Sym "n")}) |> flow_ok in
    let edited = E.static ~record:true changed |> flow_ok in
    let probe = Flow_graph.Probe.make ~time:1.25 ~resolve edited in
    assert ((Flow_graph.Probe.footer probe body ~probes:[16001]).value <> footer.value));
  let _, changed = Flow_graph.Flow_edit.apply_checked ~ops:Flow_sop.Operators.all catalog forms
    (Flow_graph.Flow_edit.Set_arg {node=["g";"result"]; key=Pos 1; sub=[];
      value=Flow.Syntax.make (Str "Cd")}) |> flow_ok in
  let pane = Flow_graph.Projection.of_graph catalog changed "g" in
  let result = Flow_graph.Projection.find pane ["g";"result"] |> Option.get in
  assert ((List.nth result.rows 1).expr |> Option.get |> Flow.Lisp.flat = "\"Cd\"");
  List.iter (fun (op : Flow.Op.t) ->
    assert (Flow.Op.validate [op] = None);
    let args = List.map (fun (name, ty) -> name, match ty with
      | Flow.Ty.Text -> E.Text "P" | Array _ -> E.Vec3_array [||]
      | _ when name="values" && op.name="sop/with_attr" -> E.Vec3_array [||]
      | _ -> E.Deferred (Flow.Ty.geometry,0)) op.signature.pos in
    op.check args;
    let result = op.body ~live:(Frame_input.at_time 0.)
      ~node:(fun _ _ -> E.Deferred (Flow.Ty.geometry,1)) args in
    assert (Flow.Ty.fits (Flow.Value.ty_of result) (op.out (List.map (fun (_,v) -> Flow.Value.ty_of v) args))))
    (List.filter (fun (op : Flow.Op.t) -> op.ctx = Flow.Context.sop) Flow_sop.Operators.all);
  print_endline "Cooked attribute kernel: native/reference/CPU parity, source ownership, cache invalidation, errors and graph edits passed"
