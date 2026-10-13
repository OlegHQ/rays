open Rdk
open Rdk_test_support
module N=Sop.Node
module P=Param
let checked=function Ok value->value|Error d->fail(Flow.Diagnostic.to_string d)
let sources=(Flow_sop.Catalog.sources() |>checked) @
  (In_channel.with_open_text "nodes/name_from_groups.pending" In_channel.input_all |>Flow.Syntax.parse |>checked)
let quoted value=Flow.Lisp.flat(Flow.Syntax.make(Str value))
let factories input=
  Sop.Edit_graph.factory ~key:"names_input" ~label:"Input" ~category:["Test"] ~arity:0(fun _->input)::
  List.filter(fun f->Sop.Edit_graph.factory_key f<>"name_from_groups")Sop_catalog.Editor.factories
let catalog factories=Flow_sop.Catalog.of_factories ~nodes:[] ~version:Flow_sop.Manifest.version factories |>checked
let workspace=function Some w,ds when not(List.exists(fun(d:Flow.Diagnostic.t)->d.severity=Error)ds)->w
  |_,ds->fail(String.concat "\n"(List.map Flow.Diagnostic.to_string ds))
let node ~reference input keywords=
  let factories=factories input in
  let forms=Flow.Syntax.parse("(workspace names (graph g :context sop (sop/name_from_groups (sop/names_input) "^keywords^")))") |>checked in
  let workspace=Flow_sop.Catalog.check_workspace ~sources ~ops:Flow_sop.Operators.all (catalog factories) forms |>workspace in
  let lowered=Flow_sop.Lower.of_checked ~reference ~factories workspace |>checked in
  if keywords="" then check(Flow_sop.Catalog.descriptor Sop.Nodes.Name_from_groups.factory=
    Flow_sop.Catalog.descriptor(List.find(fun f->Sop.Edit_graph.factory_key f="name_from_groups")lowered.factories))
    "Name from Groups full descriptor";
  let graph=List.hd lowered.graphs in
  Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root) |>get_string_ok
let native input changes=fst(N.apply_parameters
  (Sop.Edit_graph.instantiate Sop.Nodes.Name_from_groups.factory[input] |>get_string_ok) changes |>get_string_ok)
let session f=
  let session=Sop.Session.create ~max_entries:64 ~max_payload_bytes:512_000_000 |>get_string_ok in
  Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->f session)
let result session domains grain node=
  let context=Sop.Context.create ~domains ~grain() |>get_string_ok in
  Result.bind(Sop.Session.cook session ~context node)(fun output->Sop.Payload.geometry output.payload)
let cook session domains grain node=match result session domains grain node with
  |Ok geometry->geometry|Error d->fail(Sop.Diagnostic.error_to_string d)
let points count=Kernel.generate_point_ranges count(fun ~first ~last ~x ~y ~z->
  for i=first to last-1 do x.(i)<-float i*.0.125;y.(i)<- -0.;z.(i)<-0.25 done)
let mixed()=
  let topology=Topology.create_owned ~point_count:6 ~vertex_points:[|0;1;2;3;1;4;5|]
    ~primitive_offsets:[|0;4;7|] ~primitive_kinds:[|Topology.Polygon;Open_polyline|] |>get_string_ok in
  Geometry.create ~positions:(Geometry.positions(points 6)) ~topology() |>get_string_ok
let owner_count geometry=function Attribute.Point->Geometry.point_count geometry
  |Vertex->Geometry.vertex_count geometry|Primitive->Geometry.primitive_count geometry|Detail->1
let attribute geometry owner name storage=Geometry.with_attribute
  (Attribute.create_owned ~owner ~name storage |>get_string_ok)geometry |>get_string_ok
let grouped geometry=
  let geometry=List.fold_left(fun geometry owner->
    let count=match owner with Group.Point->Geometry.point_count geometry|Vertex->Geometry.vertex_count geometry
      |Primitive->Geometry.primitive_count geometry in
    List.fold_left(fun geometry(name,choose)->
      let indices=Array.init count Fun.id |>Array.to_list |>List.filter choose |>List.rev |>Array.of_list in
      Geometry.with_group(Group.ordered ~owner ~name ~length:count indices |>get_string_ok)geometry |>get_string_ok)
      geometry ["z_first",(fun i->i mod 3=0);"a_last",(fun i->i mod 2=0);
                "empty",(fun _->false);"é猫 *?[]^\\",(fun i->i mod 3=1);
                " spaced ",(fun i->i mod 3=2)])
    geometry [Group.Vertex;Point;Primitive] in
  let topology=Geometry.topology geometry in let index=Topology_index.create topology in
  Geometry.with_edge_group(Edge_group.init ~topology ~index ~name:"untouched"(fun i->i mod 2=0))geometry |>get_string_ok
let preserved geometry=
  List.fold_left(fun geometry owner->let count=owner_count geometry owner in
    let values=Array.init count(fun i->if i mod 2=0 then -0. else float i *.0.25)
    and integers=Array.init count(fun i->if i mod 2=0 then min_int else max_int) in
    List.fold_left(fun geometry(name,storage)->attribute geometry owner name storage)geometry
      ["old",Attribute.Text(Array.init count(fun i->"oldé"^string_of_int i));
       "keep_float",Float values;"keep_int",Int integers;
       "keep_vec2",Float2(Packed.Float2.of_owned ~x:(Array.copy values) ~y:(Array.copy values)|>get_string_ok);
       "keep_vec3",Float3(Packed.Float3.of_owned ~x:(Array.copy values) ~y:(Array.copy values) ~z:(Array.copy values)|>get_string_ok);
       "N",Float3(Packed.Float3.of_owned ~x:(Array.copy values) ~y:(Array.copy values) ~z:(Array.copy values)|>get_string_ok);
       "keep_vec4",Float4(Packed.Float4.of_owned ~x:(Array.copy values) ~y:(Array.copy values) ~z:(Array.copy values) ~w:(Array.copy values)|>get_string_ok);
       "keep_float_rows",Float_array(Packed.Float_array.create_owned ~offsets:(Array.init(count+1)Fun.id) ~values:(Array.copy values)|>get_string_ok);
       "keep_int_rows",Int_array(Packed.Int_array.create_owned ~offsets:(Array.init(count+1)Fun.id) ~values:(Array.copy integers)|>get_string_ok)])
    geometry [Attribute.Point;Vertex;Primitive;Detail]
let parameters owner attribute pattern default overlap delete_groups=
  ["owner",P.Choice_value owner;"attribute",P.Text_value attribute;"pattern",P.Text_value pattern;
   "default",P.Text_value default;"overlap",P.Choice_value overlap;"delete_groups",P.Bool_value delete_groups]
let keywords owner attribute pattern default overlap delete_groups=
  Printf.sprintf ":owner %s :attribute %s :pattern %s :default %s :overlap %s :delete_groups %b"
    (quoted owner)(quoted attribute)(quoted pattern)(quoted default)(quoted overlap)delete_groups
let compare geometry text changes domains_grains=
  let input=Lisp_sop.snapshot geometry and before=geometry_bytes geometry in
  let actual=node ~reference:false input text and reference=node ~reference:true input text and oracle=native input changes in
  check(N.parameter_fields actual=N.parameter_fields oracle && N.parameter_key actual=N.parameter_key oracle
    && N.operation actual=N.operation oracle && N.version actual=N.version oracle && N.label actual=N.label oracle)
    "Name from Groups runtime identity/schema";
  session(fun session->match result session 1 97 oracle,result session 1 97 actual with
    |Ok expected,Ok got->
        check(geometry_bytes expected=geometry_bytes got)("Name from Groups native exact "^text);
        check(geometry_bytes got=geometry_bytes(cook session 1 97 reference))"Name from Groups strict/reference bytes";
        List.iter(fun(domains,grain)->Sop.Session.clear session;
          check(geometry_bytes got=geometry_bytes(cook session domains grain actual))"Name from Groups domains/grain bytes")domains_grains
    |Error expected,Error got->
        let same got=check(expected.Sop.Diagnostic.code=got.Sop.Diagnostic.code && expected.message=got.message && expected.cause=got.cause)
          ("Name from Groups exact error "^text^" expected "^Sop.Diagnostic.error_to_string expected^" got "^Sop.Diagnostic.error_to_string got) in
        same got;
        List.iter(fun(domains,grain)->match result session domains grain actual with
          |Error got->same got|Ok _->fail "Name from Groups invalid parallel success")domains_grains;
        (match result session 1 97 reference with Error got->same got|Ok _->fail "Name from Groups invalid reference success")
    |Error expected,Ok _->fail("Name from Groups accepted "^Sop.Diagnostic.error_to_string expected)
    |Ok _,Error got->fail("Name from Groups refused "^text^": "^Sop.Diagnostic.error_to_string got));
  check(before=geometry_bytes geometry)"Name from Groups mutated source"
let verify()=
  let grid=Plane_generators.grid ~connectivity:Grid_quads ~columns:64 ~rows:64 ~size:8.() |>get_ok in
  check(Geometry.point_count grid=4225 && Geometry.primitive_count grid=4096)"Name from Groups real grid";
  List.iter(fun geometry->let geometry=preserved(grouped geometry) in
    ignore(node ~reference:false(Lisp_sop.snapshot geometry)"");
    List.iter(fun owner->List.iter(fun overlap->List.iter(fun delete->
      let text=keywords owner "name" "*" "fallbacké\000😀" overlap delete in
      compare geometry text(parameters owner "name" "*" "fallbacké\000😀" overlap delete)
        (List.concat_map(fun d->List.map(fun g->d,g)[1;97;4096])[1;4;8]))[false;true])
      ["First group";"Last group";"Error on overlap"])["Point";"Vertex";"Primitive"];
    List.iter(fun(attribute,pattern)->let text=keywords "Point" attribute pattern "default" "Last group" true in
      compare geometry text(parameters "Point" attribute pattern "default" "Last group" true)[1,97;4,4096])
      ["old","* ^a*";" name ","z*";"name","unmatched";"name","";"name"," \t\n";
       "name","é*";"name","z_first empty";"P","unmatched";"P","*"])
    [points 0;points 1;mixed();grid;points 5001];
  print_endline "Name from Groups: all owners/overlap/delete modes, inventory ordering, existing Text, native exact and strict/reference/domain/grain bytes"
let errors()=
  let geometry=preserved(grouped(mixed())) in
  List.iter(fun owner->List.iter(fun name->compare geometry(keywords owner name "*" "" "Error on overlap" false)
    (parameters owner name "*" "" "Error on overlap" false)[1,1;4,97;8,4096])
    ["keep_float";"keep_int";"keep_vec2";"keep_vec3";"keep_vec4";"keep_float_rows";"keep_int_rows"])
    ["Point";"Vertex";"Primitive"];
  List.iter(fun(attribute,pattern,overlap)->compare geometry(keywords "Point" attribute pattern "" overlap false)
    (parameters "Point" attribute pattern "" overlap false)[1,1;4,97;8,4096])
    [" \t\n","[","Error on overlap";"keep_int","[","First group";
     "name","\\","First group";"name","[","First group";"P","*","Error on overlap"];
  print_endline "Name from Groups native code/message/cause and blank/pattern/storage/overlap/P error precedence"
let edits()=
  let input=Lisp_sop.snapshot(preserved(grouped(mixed()))) in
  let initial=node ~reference:false input "" and oracle=native input[] in
  List.iter(fun(name,value)->let actual=fst(N.apply_parameters initial[name,value] |>get_string_ok)
    and expected=fst(N.apply_parameters oracle[name,value] |>get_string_ok) in
    check(N.parameter_key actual=N.parameter_key expected)("Name from Groups edited key "^name);
    session(fun s->ignore(cook s 1 97 initial);let before=Sop.Session.stats s in
      ignore(cook s 1 97 actual);let after=Sop.Session.stats s in
      check(after.misses=before.misses+1)("Name from Groups one public miss "^name);
      ignore(cook s 1 97 actual);check((Sop.Session.stats s).hits>after.hits)"Name from Groups warm hit";
      check(geometry_bytes(cook s 1 97 actual)=geometry_bytes(cook s 1 97 expected))"Name from Groups edited native"))
    ["owner",P.Choice_value "Point";"attribute",P.Text_value " old ";"pattern",P.Text_value "z*";
     "default",P.Text_value "differenté";"overlap",P.Choice_value "Last group";"delete_groups",P.Bool_value true];
  print_endline "Name from Groups every physical edit/cache key/one public miss/warm hit"
let projection()=
  let module S=Flow.Syntax in
  let module Projection=Flow_graph.Projection in
  let module Edit=Flow_graph.Flow_edit in
  let input=Lisp_sop.snapshot(preserved(grouped(mixed()))) in
  let factories=factories input in
  let base=catalog factories and native_catalog=catalog(Sop.Nodes.Name_from_groups.factory::factories) in
  let checker _ forms=Flow_sop.Catalog.check_workspace ~sources ~ops:Flow_sop.Operators.all base forms in
  let forms=S.parse{|(workspace names (graph g :context sop
    (let* [src (sop/names_input) card (sop/name_from_groups src :owner "Primitive" :attribute "name"
      :pattern "*" :default "" :overlap "First group" :delete_groups false)] card)))|} |>checked in
  let actual=checker base forms |>workspace
  and expected=Flow.Workspace.check ~ops:Flow_sop.Operators.all native_catalog forms |>workspace in
  let card catalog workspace=Option.get(Projection.find(Projection.of_graph catalog workspace "g")["g";"card"]) in
  let normalize(card:Projection.node)={card with rows=List.map(fun(row:Projection.row)->
    {row with expr=Option.map(fun expr->List.hd(S.parse(Flow.Lisp.flat expr)|>checked))row.expr})card.rows} in
  let actual_card=card base actual and expected_card=card native_catalog expected in
  check(normalize actual_card=normalize expected_card)"Name from Groups native graph card metadata";
  check(Projection.lines Full(normalize actual_card)=Projection.lines Full(normalize expected_card))
    "Name from Groups inspector metadata";
  List.iter(fun(name,value,parameter)->let _,changed=Edit.apply_checked ~checker base forms
    (Set_arg{node=actual_card.path;key=Kw name;sub=[];value=S.make value}) |>checked in
    let lowered=Flow_sop.Lower.of_checked ~factories changed |>checked in
    let graph=List.hd lowered.graphs in
    let actual=Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root) |>get_string_ok
    and expected=native input[name,parameter] in
    check(N.parameter_key actual=N.parameter_key expected)("Name from Groups gesture key "^name);
    session(fun s->check(geometry_bytes(cook s 1 97 actual)=geometry_bytes(cook s 1 97 expected))
      ("Name from Groups gesture native cook "^name)))
    ["owner",S.Str "Point",P.Choice_value "Point";"attribute",Str " old ",P.Text_value " old ";
     "pattern",Str "z*",P.Text_value "z*";"default",Str "é猫",P.Text_value "é猫";
     "overlap",Str "Last group",P.Choice_value "Last group";"delete_groups",Sym "true",P.Bool_value true];
  let _,bypassed=Edit.apply_checked ~checker base forms(Toggle_bypass{node=actual_card.path}) |>checked in
  check((card base bypassed).bypass)"Name from Groups bypass gesture";
  check(Result.is_error(Edit.apply_checked ~checker base forms
    (Set_arg{node=actual_card.path;key=Kw "owner";sub=[];value=S.make(Str "Detail")})))
    "Name from Groups invalid owner gesture";
  print_endline "Name from Groups native card/inspector parity and every field direct gesture"
let large_inventory()=
  let geometry=List.fold_left(fun geometry index->
    Geometry.with_group(Group.init ~owner:Group.Point ~name:("group_"^string_of_int index) 1
      (fun _->index=5000))geometry |>get_string_ok)(points 1)(List.init 5001 Fun.id) in
  List.iter(fun overlap->compare geometry(keywords "Point" "name" "*" "fallback" overlap false)
    (parameters "Point" "name" "*" "fallback" overlap false)[1,97;4,4096;8,1])
    ["First group";"Last group";"Error on overlap"];
  print_endline "Name from Groups genuinely cooked 5001-group inventory exceeds packed list limit"
let invalid_parameters()=
  let input=Lisp_sop.snapshot(mixed()) in
  let actual=node ~reference:false input "" and expected=native input [] in
  List.iter(fun change->match N.apply_parameters actual[change],N.apply_parameters expected[change] with
    |Error actual,Error expected->check(actual=expected)"Name from Groups parameter atomic refusal"
    |_->fail "Name from Groups invalid parameter accepted")
    ["owner",P.Choice_value "Detail";"overlap",P.Choice_value "unsupported";
     "default",P.Int_value 0;"delete_groups",P.Text_value "true"]
let opaque_preservation()=
  let positions=Packed.Float3.of_owned ~x:[|Int64.float_of_bits 0x7ff8000000000123L;infinity;neg_infinity|]
    ~y:[|-0.;0.;Float.max_float|] ~z:[|1.;2.;3.|] |>get_string_ok in
  let geometry=Geometry.with_positions positions(points 3) |>get_string_ok |>grouped |>preserved in
  let geometry=attribute geometry Attribute.Point "N"(Attribute.Float3 positions) in
  let geometry=attribute geometry Attribute.Point "old"(Attribute.Text[|"\255\000";"é猫";"\128"|]) in
  compare geometry(keywords "Point" "old" "z_first" "unused" "First group" false)
    (parameters "Point" "old" "z_first" "unused" "First group" false)[1,1;4,97;8,4096];
  print_endline "Name from Groups preserves opaque nonfinite P/N and unassigned native text bytes"
let benchmark first_only=
  let lines primitive_count=
    let topology=Topology.create_owned ~point_count:1_000_000
      ~vertex_points:(Array.init(primitive_count*2)(fun i->i mod 1_000_000))
      ~primitive_offsets:(Array.init(primitive_count+1)(fun i->i*2))
      ~primitive_kinds:(Array.make primitive_count Topology.Open_polyline) |>get_string_ok in
    Geometry.create ~positions:(Geometry.positions(points 1_000_000)) ~topology() |>get_string_ok in
  let median samples=List.sort(fun(a,_)(b,_)->Float.compare a b)samples |>fun samples->List.nth samples 1 in
  List.iter(fun(owner,attribute_owner,group_owner)->
    let geometry=match attribute_owner with Attribute.Point->points 1_000_000
      |Vertex->lines 500_000|Primitive->lines 1_000_000|Detail->assert false in
    let count=owner_count geometry attribute_owner in
    let geometry=List.fold_left(fun geometry(name,selected)->Geometry.with_group
      (Group.init ~owner:group_owner ~name count selected)geometry |>get_string_ok)geometry
      ["first",(fun i->i mod 3=0);"last",(fun i->i mod 3=1);"empty",(fun _->false)] in
    List.iter(fun existing->let geometry=if existing then
      attribute geometry attribute_owner "name"(Attribute.Text(Array.make count "previousé")) else geometry in
      let input=Lisp_sop.snapshot geometry in
      List.iter(fun overlap->List.iter(fun delete_groups->
        let actual=node ~reference:false input(keywords owner "name" "*" "default" overlap delete_groups)
        and oracle=native input(parameters owner "name" "*" "default" overlap delete_groups) in
        List.iter(fun domains->session(fun s->check(geometry_bytes(cook s domains 4096 actual)=
            geometry_bytes(cook s domains 4096 oracle))"Name from Groups benchmark native exact");
          let sample node=List.init 3(fun _->session(fun s->Gc.full_major();
            let bytes=Gc.allocated_bytes() and start=Unix.gettimeofday() in
            ignore(cook s domains 4096 node);Unix.gettimeofday()-.start,Gc.allocated_bytes()-.bytes)) |>median in
          let native_time,native_bytes=sample oracle and time,bytes=sample actual in
          Printf.printf "Name from Groups points=1000000 owner=%s elements=%d existing=%b overlap=%S delete=%b domains=%d grain=4096 native=%.6f lisp=%.6f ratio=%.3f native_bytes=%.0f lisp_bytes=%.0f\n%!"
            owner count existing overlap delete_groups domains native_time time(time/.native_time)native_bytes bytes) [1;4])
        (if first_only then[false]else[false;true]))
        (if first_only then["First group"]else["First group";"Last group";"Error on overlap"]))
      (if first_only then[false]else[false;true]))
    (if first_only then["Point",Attribute.Point,Group.Point]else
      ["Point",Attribute.Point,Group.Point;"Vertex",Attribute.Vertex,Group.Vertex;"Primitive",Attribute.Primitive,Group.Primitive])
let trace()=
  let old= !(Flow_ir.Packed.Private.trace) in
  let source=In_channel.with_open_text "nodes/name_from_groups.pending" In_channel.input_all in
  Fun.protect ~finally:(fun()->Flow_ir.Packed.Private.trace:=old)(fun()->
    Flow_ir.Packed.Private.trace:=(function Ok _->()|Error ds->List.iter(fun d->
      prerr_endline(Flow.Diagnostic.report ~file:"nodes/name_from_groups.pending" ~source d))ds);
    ignore(node ~reference:false(Lisp_sop.snapshot(grouped(mixed())))""))
let ()=if Array.exists((=)"--trace")Sys.argv then trace()
  else if Array.exists((=)"--bench")Sys.argv then benchmark false
  else if Array.exists((=)"--bench-first")Sys.argv then benchmark true
  else(verify();errors();edits();projection();large_inventory();invalid_parameters();opaque_preservation())
