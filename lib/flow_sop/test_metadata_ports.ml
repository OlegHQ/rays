(* Independent native factories remain the oracle for these unregistered drafts. *)
open Rdk
open Rdk_test_support
module N = Sop.Node
module P = Param
let flow_ok = function Ok value->value|Error diagnostic->fail(Flow.Diagnostic.to_string diagnostic)
let quoted value=Flow.Lisp.flat(Flow.Syntax.make(Str value))
let source=In_channel.with_open_bin "nodes/metadata.pending" In_channel.input_all |>Flow.Syntax.parse |>flow_ok
  |>List.concat_map(fun form->match form.Flow.Syntax.node with
    |List(_::_::children)when Flow.Syntax.head form=Some "workspace"->children|_->[form])
let sources=(Flow_sop.Catalog.sources()|>flow_ok)@source
let keys=["rename_attributes";"swap_attributes";"delete_attributes";"group_rename";"group_delete";"delete_edge_group";"rename_edge_group"]
let factories input reference =
  let snapshot key node=Sop.Edit_graph.factory ~key ~label:key ~category:["Test"] ~arity:0(fun _->node) in
  snapshot "metadata_input" input::snapshot "metadata_reference" reference::
  List.filter(fun factory->not(List.mem(Sop.Edit_graph.factory_key factory)keys))Sop_catalog.Editor.factories
let node ?(reference_node=None) ~reference input key keywords =
  let reference_input=Option.value ~default:input reference_node in
  let factories=factories input reference_input in
  let catalog=Flow_sop.Catalog.of_factories ~nodes:[] ~version:Flow_sop.Manifest.version factories |>flow_ok in
  let forms=Printf.sprintf "(workspace metadata (graph g :context sop (sop/%s (sop/metadata_input) %s)))" key keywords
    |>Flow.Syntax.parse |>flow_ok in
  let workspace=match Flow_sop.Catalog.check_workspace ~sources ~ops:Flow_sop.Operators.all catalog forms with
    |Some workspace,diagnostics when not(List.exists(fun(d:Flow.Diagnostic.t)->d.severity=Error)diagnostics)->workspace
    |_,diagnostics->fail(key^": "^String.concat "\n"(List.map Flow.Diagnostic.to_string diagnostics)) in
  let lowered=Flow_sop.Lower.of_checked ~reference ~factories workspace |>flow_ok in
  let graph=List.hd lowered.graphs in
  Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root)|>get_string_ok
let factory = function
  |"rename_attributes"->Sop.Nodes.Rename_attributes.factory
  |"swap_attributes"->Sop.Nodes.Swap_attributes.factory
  |"delete_attributes"->Sop.Nodes.Delete_attributes.factory
  |"group_rename"->Sop.Nodes.Group_rename.factory
  |"group_delete"->Sop.Nodes.Group_delete.factory
  |"delete_edge_group"->Sop.Nodes.Delete_edge_group.factory
  |"rename_edge_group"->Sop.Nodes.Rename_edge_group.factory
  |_ ->assert false
let native ?reference input key changes =
  let inputs=input::Option.to_list reference in
  let node=(if key="delete_attributes"then Sop.Edit_graph.instantiate_optional(factory key)[Some input;reference]
    else Sop.Edit_graph.instantiate(factory key)inputs)|>get_string_ok in
  fst(N.apply_parameters node changes |>get_string_ok)
let cook session domains grain node =
  let context=Sop.Context.create ~domains ~grain ()|>get_string_ok in
  match Sop.Session.cook session ~context node with
  |Ok output->Result.map_error(fun error->error.Sop.Diagnostic.code,error.message,error.cause)(Sop.Payload.geometry output.payload)
  |Error error->Error(error.Sop.Diagnostic.code,error.message,error.cause)
let same a b=match a,b with
  |Ok a,Ok b->geometry_bytes a=geometry_bytes b
  |Error a,Error b->a=b
  |_->false
let points count=Kernel.generate_point_ranges count(fun ~first ~last ~x ~y ~z->
  for index=first to last-1 do x.(index)<-float index;y.(index)<- -0.;z.(index)<-0.5 done)
let grid ()=
  let size=65 in
  let vertex_points=Array.init(64*64*4)(fun index->
    let cell=index/4 and corner=index mod 4 in
    let x=cell mod 64 and y=cell/64 in
    (y+(if corner>=2 then 1 else 0))*size+x+(if corner=1||corner=2 then 1 else 0)) in
  let topology=Topology.polygons_owned ~point_count:(size*size)~vertex_points
    ~primitive_offsets:(Array.init(64*64+1)(fun index->index*4))|>get_string_ok in
  Geometry.create ~positions:(Geometry.positions(points(size*size)))~topology()|>get_string_ok
let fixture ()=
  let topology=Topology.create_owned ~point_count:6 ~vertex_points:[|0;1;2;3;1;4;5|]
    ~primitive_offsets:[|0;4;7|] ~primitive_kinds:[|Topology.Polygon;Open_polyline|]|>get_string_ok in
  let geometry=Geometry.create ~positions:(Geometry.positions(points 6))~topology()|>get_string_ok in
  let add owner count geometry =
    let array value=Array.make count value in
    let csr=Packed.Float_array.create_owned ~offsets:(Array.init(count+1)(fun i->i*2)) ~values:(Array.make(count*2)(-0.))|>get_string_ok in
    let int_csr=Packed.Int_array.create_owned ~offsets:(Array.init(count+1)(fun i->i*2)) ~values:(Array.make(count*2)max_int)|>get_string_ok in
    let float3=Packed.Float3.of_owned ~x:(array 2.) ~y:(array(-0.)) ~z:(array 0.5)|>get_string_ok in
    List.fold_left(fun geometry(name,storage)->Geometry.with_attribute
      (Attribute.create_owned ~owner ~name storage|>get_string_ok)geometry|>get_string_ok)geometry
      ["old_float",Attribute.Float(array(-0.));"old_int",Int(array max_int);
       "old_vec2",Float2(Packed.Float2.of_owned ~x:(array(-0.))~y:(array 2.)|>get_string_ok);"old_vec3",Float3 float3;
       "old_vec4",Float4(Packed.Float4.of_owned ~x:(array(-0.))~y:(array 2.)~z:(array 3.)~w:(array 4.)|>get_string_ok);"old_text",Text(array "猫\t😀");
       "old_float_array",Float_array csr;"old_int_array",Int_array int_csr] in
  let geometry=List.fold_left(fun geometry(owner,count)->add owner count geometry)geometry
    [Attribute.Point,6;Vertex,7;Primitive,2;Detail,1] in
  let group owner count name indices=Group.ordered ~owner ~length:count ~name indices|>get_string_ok in
  let geometry=List.fold_left(fun geometry group->Geometry.with_group group geometry|>get_string_ok)geometry
    [group Group.Point 6 "old_points"[|4;1;3|];group Point 6 "target"[|2;4|];group Point 6 "unused"[||];
     group Vertex 7 "old_vertices"[|6;0|];group Primitive 2 "old_primitives"[|1|]] in
  let index=Topology_index.create(Geometry.topology geometry) in
  let edges=Edge_group.init ~topology:(Geometry.topology geometry)~index ~name:"edges"(fun edge->edge<2) in
  let geometry=Geometry.with_edge_group edges geometry|>get_string_ok in
  Geometry.with_edge_group(Edge_group.with_name "old_edges" edges)geometry|>get_string_ok
let table=Param.String_table.encode
let rules rows=":rules "^quoted(table rows),["rules",P.Text_value(table rows)]
let cases =
  List.map(fun key->key,"",[])keys
  @ List.map(fun policy->let keywords,changes=rules[[" ANY ";"old_*";"new_*";String.uppercase_ascii policy]] in
      "rename_attributes",keywords,changes)["skip";"error";"overwrite"]
  @ List.concat_map(fun owner->List.map(fun method_->let keywords,changes=rules[[owner;"old_*";"new_*";method_]] in
      "swap_attributes",keywords,changes)["copy";"move";"swap"])["POINTS";"vertices";"primitive";"detail"]
  @ List.map(fun policy->let keywords,changes=rules[["*";"old_*";"new_*";policy]] in
      "group_rename",keywords,changes)["skip";"error";"overwrite";"union"]
  @ [(let keywords,changes=rules[["points";"old_points";"target";"union"]]in "group_rename",keywords,changes);
     (let keywords,changes=rules[["any";"old_*";"mid_*";"skip"];["any";"mid_*";"new_*";"overwrite"]]in "rename_attributes",keywords,changes);
     (let keywords,changes=rules[["point";"old_float";"old_int";"swap"];["point";"old_int";"old_vec2";"swap"]]in "swap_attributes",keywords,changes);
     (let keywords,changes=rules[["any";"old_*";"mid_*";"union"];["any";"mid_*";"new_*";"overwrite"]]in "group_rename",keywords,changes);
     (let keywords,changes=rules[["point";"old_*"];["vertex";"old_*"];["edge";"edges"]]in "group_delete",keywords,changes);
     (let keywords,changes=rules[["any";"old_*"]]in "group_delete",keywords^" :delete_unused true",changes@["delete_unused",P.Bool_value true]);
     "group_delete",":delete_unused true",["delete_unused",P.Bool_value true];
     "delete_attributes",":point_pattern \"old_*\" :detail_pattern \"old_text\"",["point_pattern",P.Text_value "old_*";"detail_pattern",P.Text_value "old_text"];
     "delete_attributes",":delete_non_selected true :vertex_pattern \"old_int\"",["delete_non_selected",P.Bool_value true;"vertex_pattern",P.Text_value "old_int"];
     (let keywords,changes=rules[["point";"[";"x";"skip"]]in "group_rename",keywords,changes);
     (let keywords,changes=rules[["point";"["]]in "group_delete",keywords,changes);
     "rename_edge_group",":from \"missing\" :into \"missing\"",["from",P.Text_value "missing";"into",P.Text_value "missing"];
     "rename_edge_group",":into \"\"",["into",P.Text_value ""]]
let verify ()=
  List.iter(fun geometry->
    let before=geometry_bytes geometry and input=Lisp_sop.snapshot geometry in
    List.iter(fun(key,keywords,changes)->
      let actual=node ~reference:false input key keywords and reference=node ~reference:true input key keywords in
      let oracle=native input key changes in
      check(N.operation actual=N.operation oracle && N.version actual=N.version oracle)(key^": operation/version differs");
      check(N.label actual=N.label oracle)(key^": runtime label differs");
      check(N.parameter_fields actual=N.parameter_fields oracle)(key^": physical schema differs");
      check(N.parameter_key actual=N.parameter_key oracle)(key^": canonical encoded key differs");
      let session=Sop.Session.create ~max_entries:64 ~max_payload_bytes:64_000_000|>get_string_ok in
      Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
        let baseline=cook session 1 97 actual in
        check(same baseline(cook session 1 97 oracle))(key^": native bytes or error differs");
        check(same baseline(cook session 1 97 reference))(key^": strict/reference differs");
        List.iter(fun domains->List.iter(fun grain->Sop.Session.clear session;
          check(same baseline(cook session domains grain actual))(key^": worker/grain differs"))[1;97;4096])[1;4;8]);
      check(before=geometry_bytes geometry)(key^": input mutated"))cases)
    [points 0;points 1;fixture();grid();points 32769];
  print_endline "metadata ports: native schema/keys/operations, all owners/storages/policies and strict/reference/domain results passed"
let edits ()=
  let input=Lisp_sop.snapshot(fixture()) in
  List.iter(fun key->let actual=node ~reference:false input key "" and oracle=native input key [] in
    List.iter(fun(field:P.field_view)->
      let value=match field.current with
        |P.Bool_value value->P.Bool_value(not value)
        |Text_value _->Text_value(if field.name="rules"then
            table(if key="group_delete"then[[" POINTS ";"old_*"]]
              else[[" POINTS ";"old_*";"new_*";if key="swap_attributes"then" COPY "else" SKIP "]])
          else if field.name="from"then"old_edges"else if field.name="into"then"new_edges"else"old_*")
        |_->assert false in
      let edited=fst(N.apply_parameters actual[field.name,value]|>get_string_ok)
      and expected=fst(N.apply_parameters oracle[field.name,value]|>get_string_ok) in
      check(N.parameter_fields edited=N.parameter_fields expected && N.parameter_key edited=N.parameter_key expected)
        (key^": edited physical schema/key differs");
      let session=Sop.Session.create ~max_entries:32 ~max_payload_bytes:16_000_000|>get_string_ok in
      Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
        ignore(cook session 1 97 actual);let before=Sop.Session.stats session in
        let result=cook session 1 97 edited in let after=Sop.Session.stats session in
        check(after.misses=before.misses+1)(key^": parameter edit must miss once");
        check(same result(cook session 1 97 expected))(key^": edited native result differs");
        let before_warm=Sop.Session.stats session in
        ignore(cook session 1 97 edited);let warm=Sop.Session.stats session in
        check(warm.misses=before_warm.misses && warm.hits>before_warm.hits)(key^": edited warm cache missed")))
      (N.parameter_fields actual))keys;
  print_endline "metadata ports: every physical edit has native canonical schema/key and one public miss"
let declaration_metadata ()=
  let definitions=List.filter_map(fun form->if Flow.Syntax.head form=Some "defnode"
    then Some(Flow.Defnode.parse form|>flow_ok)else None)source in
  List.iter(fun(definition:Flow.Defnode.t)->
    let key=Flow.Check.short definition.kind.qualified in
    let native_factory=factory key in
    let catalog=Flow_sop.Catalog.of_factories ~nodes:[] ~version:1[native_factory]|>flow_ok in
    let kind=List.hd catalog.kinds in
    check(definition.kind.slots=kind.slots && definition.kind.parameters=kind.parameters && definition.kind.outputs=kind.outputs)
      (key^": declaration slots, full field metadata or output differs");
    check(definition.operation=Sop.Edit_graph.factory_operation native_factory && definition.label=Sop.Edit_graph.factory_label native_factory
      && definition.category=Sop.Edit_graph.factory_category native_factory)(key^": public factory identity/menu differs"))definitions
let invalid_parameters ()=
  let input=Lisp_sop.snapshot(fixture()) in
  List.iter(fun key->
    let actual=node ~reference:false input key "" and oracle=native input key [] in
    let rejected raw=
      let apply node=match N.apply_parameters node["rules",P.Text_value raw]with
        |Error message->Error message|Ok _->Ok() in
      let expected=apply oracle and observed=apply actual in
      check(expected=observed && Result.is_error observed)(key^": malformed encoded parameter diagnostic differs: "^quoted raw) in
    List.iter rejected ["point";"point\twrong\\q";"point\twrong\\";
      table(if key="group_delete"then[["WHAT 猫";"*"]]else[["WHAT 猫";"*";"*";"skip"]])];
    if key<>"group_delete"then rejected(table[["point";"*";"*";"WHAT \"猫\""]]);
    if key="rename_attributes"||key="swap_attributes"then rejected(table[["point";"[";"*";if key="swap_attributes"then"swap"else"skip"]]))
    ["rename_attributes";"swap_attributes";"group_rename";"group_delete"];
  print_endline "metadata ports: malformed encoded rows, owner/policy aliases and rebuild glob diagnostics match native"
let reference_input ()=
  let geometry=fixture() and reference_geometry=points 6 in
  let input=Lisp_sop.snapshot geometry and reference=Lisp_sop.snapshot reference_geometry in
  let keywords=":reference (sop/metadata_reference) :delete_non_selected true :point_pattern \"old_*\"" in
  let actual=node ~reference_node:(Some reference)~reference:false input "delete_attributes"keywords
  and oracle=native ~reference input "delete_attributes"["delete_non_selected",P.Bool_value true;"point_pattern",P.Text_value "old_*"] in
  let session=Sop.Session.create ~max_entries:32 ~max_payload_bytes:16_000_000|>get_string_ok in
  Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
    let expected=cook session 1 97 oracle in
    List.iter(fun domains->List.iter(fun grain->Sop.Session.clear session;
      check(same expected(cook session domains grain actual))"Delete Attributes optional reference semantics differ") [1;97;4096])[1;4;8]);
  print_endline "metadata ports: Delete Attributes optional reference and inverse results match native"
let large_rules count=
  let input=Lisp_sop.snapshot(points 1) in
  List.iter(fun key->
    let row=if key="group_delete"then[" POINTS ";"missing"]
      else[" POINTS ";"missing";"replacement";if key="swap_attributes"then" COPY "else" SKIP "] in
    let raw=table(List.init count(fun _->row)) in
    let actual=node ~reference:false input key "" and oracle=native input key [] in
    let edited=fst(N.apply_parameters actual["rules",P.Text_value raw]|>get_string_ok)
    and expected=fst(N.apply_parameters oracle["rules",P.Text_value raw]|>get_string_ok) in
    check(N.parameter_fields edited=N.parameter_fields expected && N.parameter_key edited=N.parameter_key expected)
      (key^": large canonical schema/key differs");
    let session=Sop.Session.create ~max_entries:32 ~max_payload_bytes:16_000_000|>get_string_ok in
    Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
      check(same(cook session 1 97 edited)(cook session 1 97 expected))(key^": large native output differs"));
    Printf.printf "metadata ports: %s %d-row normalize/rebuild/cook matches native\n%!" key count)
    ["rename_attributes";"swap_attributes";"group_rename";"group_delete"]
let ()=if Array.exists((=)"--huge")Sys.argv then large_rules 100001
  else if Array.exists((=)"--large")Sys.argv then large_rules 5001
  else(declaration_metadata();verify();edits();invalid_parameters();reference_input())
