open Rdk
open Rdk_test_support
module N = Sop.Node
module P = Param
let checked=function Ok x->x|Error d->fail(Flow.Diagnostic.to_string d)
let forms=In_channel.with_open_bin "nodes/set_color.pending" In_channel.input_all |>Flow.Syntax.parse |>checked
let sources=(Flow_sop.Catalog.sources() |>checked)@forms
let node ~reference input keywords=
  let factory=Sop.Edit_graph.factory ~key:"color_input" ~label:"Color input" ~category:["Test"] ~arity:0(fun _->input) in
  let factories=factory::List.filter(fun f->Sop.Edit_graph.factory_key f<>"set_color")Sop_catalog.Editor.factories in
  let catalog=Flow_sop.Catalog.of_factories ~nodes:[] ~version:Flow_sop.Manifest.version factories |>checked in
  let forms=Flow.Syntax.parse("(workspace color (graph g :context sop (sop/set_color (sop/color_input) "^keywords^")))") |>checked in
  let ws=match Flow_sop.Catalog.check_workspace ~sources ~ops:Flow_sop.Operators.all catalog forms with
    |Some ws,ds when not(List.exists(fun(d:Flow.Diagnostic.t)->d.severity=Error)ds)->ws
    |_,ds->fail(String.concat "\n"(List.map Flow.Diagnostic.to_string ds)) in
  let lowered=Flow_sop.Lower.of_checked ~reference ~factories ws |>checked in
  if keywords="" then begin
    let factory=List.find(fun factory->Sop.Edit_graph.factory_key factory="set_color")lowered.factories in
    check(Flow_sop.Catalog.descriptor factory=Flow_sop.Catalog.descriptor Sop.Nodes.Set_color.factory)
      "Set Color factory descriptor operation/schema differs"
  end;
  let graph=List.hd lowered.graphs in
  Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root) |>get_string_ok
let native input changes=
  let initial=Sop.Edit_graph.instantiate Sop.Nodes.Set_color.factory[input] |>get_string_ok in
  fst(N.apply_parameters initial changes |>get_string_ok)
let result session domains grain node=
  Sop.Session.cook session ~context:(Sop.Context.create ~domains ~grain() |>get_string_ok) node
let cook session domains grain node=match result session domains grain node with
  |Ok output->(match Sop.Payload.geometry output.payload with Ok geometry->geometry|Error e->fail e.message)
  |Error e->fail(Sop.Diagnostic.error_to_string e)
let with_session f=
  let session=Sop.Session.create ~max_entries:64 ~max_payload_bytes:512_000_000 |>get_string_ok in
  Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->f session)
let points count=Kernel.generate_point_ranges count(fun ~first ~last ~x ~y ~z->
  for i=first to last-1 do x.(i)<-float i;y.(i)<-0.25;z.(i)<- -0.5 done)
let owners=["Point",Attribute.Point,Group.Point;"Vertex",Attribute.Vertex,Group.Vertex;
  "Primitive",Attribute.Primitive,Group.Primitive]
let count geo=function Attribute.Point->Geometry.point_count geo|Vertex->Geometry.vertex_count geo
  |Primitive->Geometry.primitive_count geo|Detail->1
let fixture ()=
  let topology=Topology.create_owned ~point_count:6 ~vertex_points:[|0;1;2;3;1;4;5|]
    ~primitive_offsets:[|0;4;7|] ~primitive_kinds:[|Topology.Polygon;Open_polyline|] |>get_string_ok in
  let geo=Geometry.create ~positions:(Geometry.positions(points 6)) ~topology() |>get_string_ok in
  let geo=List.fold_left(fun geo(_,owner,group_owner)->
    let n=count geo owner in
    let geo=Geometry.with_group(Group.ordered ~owner:group_owner ~name:"ordered" ~length:n
      (Array.init((n+1)/2)(fun i->((n-1)/2-i)*2)) |>get_string_ok)geo |>get_string_ok in
    List.fold_left(fun geo(name,select)->Geometry.with_group
      (Group.init ~owner:group_owner ~name n select)geo |>get_string_ok) geo
      ["selected",(fun i->i mod 2=0);"empty",(fun _->false);"full",(fun _->true);"é猫\"",(fun i->i=0)]) geo owners in
  let geo=Geometry.with_group(Group.init ~owner:Group.Point ~name:"point_only" 6(fun _->true))geo |>get_string_ok in
  Geometry.with_attribute(Attribute.create_owned ~owner:Attribute.Detail ~name:"tag"
    (Attribute.Text[|"untouched ✓"|]) |>get_string_ok)geo |>get_string_ok
let with_cd geo storage=
  List.fold_left(fun geo owner->Geometry.with_attribute
    (Attribute.create_owned ~owner ~name:"Cd"(storage(count geo owner)) |>get_string_ok)geo |>get_string_ok)
    geo [Attribute.Point;Vertex;Primitive;Detail]
let existing n=Attribute.Float4(Packed.Float4.of_owned
  ~x:(Array.init n(fun i->float i *.0.125)) ~y:(Array.make n (-0.))
  ~z:(Array.make n 0.75) ~w:(Array.make n 0.5) |>get_string_ok)
let changes owner group=["owner",P.Choice_value owner;"group",P.Text_value group;
  "color_r",P.Float_value 0.2;"color_g",P.Float_value 0.4;"color_b",P.Float_value 0.6;"alpha",P.Float_value 0.8]
let quoted text=Flow.Lisp.flat(Flow.Syntax.make(Str text))
let keywords owner group=Printf.sprintf ":owner %s :group %s :color [0.2 0.4 0.6] :alpha 0.8" (quoted owner) (quoted group)
let verify ()=
  let base=fixture() in
  let grid=with_session(fun session->cook session 1 97(Lisp_sop.node "(sop/grid :columns 64 :rows 64)")) in
  check(Geometry.point_count grid=4225 && Geometry.primitive_count grid>0)"Set Color grid fixture topology";
  let fixtures=[base;points 0;points 1;grid;points 32769;with_cd base existing;
    with_cd base(fun n->Attribute.Float(Array.make n 0.1));
    with_cd base(fun n->Attribute.Int(Array.make n 17));
    with_cd base(fun n->Attribute.Text(Array.make n "wrong"));
    with_cd base(fun n->Attribute.Float2(Packed.Float2.of_owned
      ~x:(Array.make n 1.) ~y:(Array.make n 2.) |>get_string_ok));
    with_cd base(fun n->Attribute.Float_array(Packed.Float_array.create_owned
      ~offsets:(Array.init(n+1)Fun.id) ~values:(Array.make n 1.) |>get_string_ok));
    with_cd base(fun n->Attribute.Int_array(Packed.Int_array.create_owned
      ~offsets:(Array.init(n+1)Fun.id) ~values:(Array.make n 1) |>get_string_ok));
    with_cd base(fun n->Attribute.Float3(Packed.Float3.of_owned
      ~x:(Array.make n 1.) ~y:(Array.make n 2.) ~z:(Array.make n 3.) |>get_string_ok))] in
  List.iter(fun geo->let input=Lisp_sop.snapshot geo and before=geometry_bytes geo in
    let cases=List.concat_map(fun owner->List.map(fun group->owner,group)["";" \t\r\n "])["Point";"Vertex";"Primitive";"Detail"]
      @(if Geometry.point_count geo=6 then List.concat_map(fun(owner,_,_)->
        List.map(fun group->owner,group)["selected";"ordered";"empty";"full";" é猫\" "])owners else []) in
    List.iter(fun(owner,group)->
      let actual=node ~reference:false input(keywords owner group)
      and reference=node ~reference:true input(keywords owner group)
      and oracle=native input(changes owner group) in
      check(N.operation actual=N.operation oracle && N.version actual=N.version oracle)"Set Color runtime identity";
      check(N.parameter_fields actual=N.parameter_fields oracle)"Set Color parameter schema";
      check(N.parameter_key actual=N.parameter_key oracle)"Set Color parameter key";
      with_session(fun session->
        let baseline=cook session 1 97 actual in
        check(close_geometry ~ulps:4 baseline(cook session 1 97 oracle))"Set Color native geometry";
        check(geometry_bytes baseline=geometry_bytes(cook session 1 97 reference))"Set Color reference bytes";
        List.iter(fun domains->List.iter(fun grain->Sop.Session.clear session;
          check(geometry_bytes baseline=geometry_bytes(cook session domains grain actual))"Set Color domains/grain") [1;97;4096]) [1;4;8]);
      check(before=geometry_bytes geo)"Set Color mutated input")cases)fixtures;
  print_endline"Set Color draft: all owners/group modes/Cd storage, schema, native4ULP/reference/domain bytes"
let edits ()=
  let input=Lisp_sop.snapshot(fixture()) in
  let initial=node ~reference:false input "" and oracle=native input[] in
  List.iter(fun(field:P.field_view)->
    let value=match field.current with P.Choice_value _->P.Choice_value"Vertex"
      |Text_value _->P.Text_value"selected"|Float_value _->P.Float_value 0.25|_->assert false in
    let actual=fst(N.apply_parameters initial[field.name,value] |>get_string_ok)
    and expected=fst(N.apply_parameters oracle[field.name,value] |>get_string_ok) in
    check(N.parameter_key actual=N.parameter_key expected)("Set Color edited key "^field.name);
    with_session(fun session->ignore(cook session 1 97 initial);let before=Sop.Session.stats session in
      let geometry=cook session 1 97 actual in let after=Sop.Session.stats session in
      check(after.misses=before.misses+1)("Set Color public miss "^field.name);
      ignore(cook session 1 97 actual);let warm=Sop.Session.stats session in
      check(warm.misses=after.misses && warm.hits>after.hits)("Set Color warm "^field.name);
      check(close_geometry ~ulps:4 geometry(cook session 1 97 expected))("Set Color edited native "^field.name)))
    (N.parameter_fields initial);
  print_endline"Set Color draft: every physical field native key/edit + one public miss/warm hit"
let errors ()=
  let input=Lisp_sop.snapshot(fixture()) in
  List.iter(fun(owner,group)->
  let native_error=native input["owner",P.Choice_value owner;"group",P.Text_value group]
  and authored_error=node ~reference:false input (Printf.sprintf ":owner %s :group %s" (quoted owner) (quoted group)) in
  with_session(fun session->match result session 1 97 native_error,result session 1 97 authored_error with
    |Error expected,Error actual->
        check(expected.code=actual.code && expected.message=actual.message)"Set Color missing group code/message";
        check(expected.cause=Some(Printf.sprintf"could not find group %S"group))"Set Color native cause";
        check(actual.cause=expected.cause)"Set Color missing group cause"
    |_->fail"Set Color missing group accepted")) ["Point","missingé";"Vertex","point_only";"Primitive","missing"];
  let initial=node ~reference:false input "" and oracle=native input[] in
  let bad=["owner",P.Choice_value"Detail";"group",P.Text_value"selected"] in
  check(Result.is_error(N.apply_parameters initial bad) && Result.is_error(N.apply_parameters oracle bad))"Set Color detail group validation";
  check(Result.is_error(N.apply_parameters initial["owner",P.Choice_value"Edge"])
    && Result.is_error(N.apply_parameters oracle["owner",P.Choice_value"Edge"]))"Set Color owner validation";
  List.iter(fun(field:P.field_view)->if field.name<>"owner" && field.name<>"group" then
    List.iter(fun x->let changes=[field.name,P.Float_value x] in
      match N.apply_parameters initial changes,N.apply_parameters oracle changes with
      |Ok(actual,_),Ok(expected,_)->check(N.parameter_key actual=N.parameter_key expected)"Set Color hard clamp"
      |Error actual,Error expected->check(actual=expected)"Set Color channel validation diagnostic"
      |_->fail"Set Color channel validation mismatch")[-1.;2.;nan;infinity;neg_infinity]) (N.parameter_fields initial);
  List.iter(fun text->try ignore(node ~reference:false input text);fail"Set Color initial nonfinite accepted"
    with Failure message->check(not(String.starts_with ~prefix:"Set Color initial nonfinite accepted" message))
      "Set Color initial nonfinite accepted") [":color_r 1e309";":alpha -1e309"]
let projection ()=
  let module S=Flow.Syntax in
  let module Projection=Flow_graph.Projection in
  let module Edit=Flow_graph.Flow_edit in
  let input=Lisp_sop.snapshot(fixture()) in
  let factory=Sop.Edit_graph.factory ~key:"color_input" ~label:"Color input" ~category:["Test"] ~arity:0(fun _->input) in
  let factories=factory::List.filter(fun factory->Sop.Edit_graph.factory_key factory<>"set_color")Sop_catalog.Editor.factories in
  let native_factories=Sop.Nodes.Set_color.factory::factories in
  let catalog factories=Flow_sop.Catalog.of_factories ~nodes:[] ~version:Flow_sop.Manifest.version factories |>checked in
  let catalog=catalog factories and native_catalog=catalog native_factories in
  let checker catalog forms=Flow_sop.Catalog.check_workspace ~sources ~ops:Flow_sop.Operators.all catalog forms in
  let workspace=function Some workspace,diagnostics when not(List.exists(fun(d:Flow.Diagnostic.t)->d.severity=Error)diagnostics)->workspace
    |_,diagnostics->fail(String.concat"\n"(List.map Flow.Diagnostic.to_string diagnostics)) in
  let authored=Flow.Syntax.parse{|(workspace color (graph g :context sop
    (let* [src (sop/color_input)
           card (sop/set_color src :owner "Point" :group "" :color [0.2 0.4 0.6] :alpha 0.8)] card)))|} |>checked in
  let actual=workspace(checker catalog authored)
  and expected=workspace(Flow.Workspace.check ~ops:Flow_sop.Operators.all native_catalog authored) in
  let card catalog workspace=Option.get(Projection.find(Projection.of_graph catalog workspace "g")["g";"card"]) in
  let normalize(card:Projection.node)={card with rows=List.map(fun(row:Projection.row)->
    {row with expr=Option.map(fun expr->List.hd(Flow.Syntax.parse(Flow.Lisp.flat expr)|>checked))row.expr})card.rows} in
  let actual_card=card catalog actual and expected_card=card native_catalog expected in
  check(normalize actual_card=normalize expected_card)"Set Color native/Lisp graph card metadata";
  check(Projection.lines Full(normalize actual_card)=Projection.lines Full(normalize expected_card))"Set Color inspector rows";
  let root workspace=let lowered=Flow_sop.Lower.of_checked ~factories workspace |>checked in
    let graph=List.hd lowered.graphs in
    Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root)|>get_string_ok in
  List.iter(fun(key,sub,value,field,parameter)->
    let _,changed=Edit.apply_checked ~checker catalog authored
      (Set_arg{node=actual_card.path;key=Kw key;sub;value=S.make value}) |>checked in
    let row=List.find(fun(row:Projection.row)->row.key=Edit.Kw key)(card catalog changed).rows in
    check(Option.is_some row.expr)("Set Color edited row "^field);
    let actual=root changed in
    let changes=List.map(fun(name,old)->name,if name=field then parameter else old)(changes "Point" "") in
    let expected=native input changes in
    check(N.parameter_key actual=N.parameter_key expected)("Set Color gesture key "^field);
    with_session(fun session->check(close_geometry ~ulps:4(cook session 1 97 actual)(cook session 1 97 expected))
      ("Set Color gesture cook "^field)))
    ["group",[],S.Str "é猫\"","group",P.Text_value "é猫\"";
     "owner",[],S.Str "Vertex","owner",P.Choice_value "Vertex";
     "color",[0],S.Num "0.25","color_r",P.Float_value 0.25;
     "color",[1],S.Num "0.25","color_g",P.Float_value 0.25;
     "color",[2],S.Num "0.25","color_b",P.Float_value 0.25;
     "alpha",[],S.Num "0.25","alpha",P.Float_value 0.25];
  check(Result.is_error(Edit.apply_checked ~checker catalog authored
    (Set_arg{node=actual_card.path;key=Kw "alpha";sub=[];value=S.make(Num "1.5")})))"Set Color hard bound gesture";
  let _,bypassed=Edit.apply_checked ~checker catalog authored(Toggle_bypass{node=actual_card.path})|>checked in
  check((card catalog bypassed).bypass)"Set Color bypass gesture";
  print_endline"Set Color draft: native card/inspector parity and every field direct graph gesture"
let benchmark ()=
  let geo=points 1_000_000 in
  let geo=Geometry.with_group(Group.init ~owner:Group.Point ~name:"selected" 1_000_000(fun i->i mod 2=0))geo |>get_string_ok in
  let median xs=List.sort(fun(a,_)(b,_)->Float.compare a b)xs |>fun xs->List.nth xs 1 in
  List.iter(fun present->let geo=if present then with_cd geo existing else geo in
    let input=Lisp_sop.snapshot geo in
    List.iter(fun group->let actual=node ~reference:false input(keywords"Point"group)
      and native=native input(changes"Point"group) in
      List.iter(fun domains->let sample node=List.init 3(fun _->with_session(fun session->
        Gc.full_major();let bytes=Gc.allocated_bytes() and start=Unix.gettimeofday() in
        ignore(cook session domains 4096 node);Unix.gettimeofday()-.start,Gc.allocated_bytes()-.bytes)) |>median in
        let native_time,native_bytes=sample native and time,bytes=sample actual in
        Printf.printf"Set Color points=1000000 Cd=%b group=%S domains=%d grain=4096 native=%.6f lisp=%.6f ratio=%.3f native_bytes=%.0f lisp_bytes=%.0f\n%!"
          present group domains native_time time(time/.native_time)native_bytes bytes) [1;4]) ["";"selected"])
    [false;true]
let ()=if Array.exists((=)"--bench")Sys.argv then benchmark() else(verify();edits();errors();projection())
