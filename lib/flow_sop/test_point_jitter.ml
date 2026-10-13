open Rdk
open Rdk_test_support
module N = Sop.Node
module P = Param
let checked = function Ok value->value|Error d->fail(Flow.Diagnostic.to_string d)
let sources = (Flow_sop.Catalog.sources() |>checked) @
  (In_channel.with_open_bin "nodes/point_jitter.pending" In_channel.input_all |>Flow.Syntax.parse |>checked)
let node ~reference input keywords =
  let factory=Sop.Edit_graph.factory ~key:"jitter_input" ~label:"Jitter input" ~category:["Test"] ~arity:0(fun _->input) in
  let factories=factory::List.filter(fun f->Sop.Edit_graph.factory_key f<>"point_jitter")Sop_catalog.Editor.factories in
  let catalog=Flow_sop.Catalog.of_factories ~nodes:[] ~version:Flow_sop.Manifest.version factories |>checked in
  let forms=Flow.Syntax.parse("(workspace jitter (graph g :context sop (sop/point_jitter (sop/jitter_input) "^keywords^")))") |>checked in
  let workspace=match Flow_sop.Catalog.check_workspace ~sources ~ops:Flow_sop.Operators.all catalog forms with
    |Some ws,ds when not(List.exists(fun(d:Flow.Diagnostic.t)->d.severity=Error)ds)->ws
    |_,ds->fail(String.concat "\n"(List.map Flow.Diagnostic.to_string ds)) in
  let lowered=Flow_sop.Lower.of_checked ~reference ~factories workspace |>checked in
  if keywords="" then check(Flow_sop.Catalog.descriptor Sop.Nodes.Point_jitter.factory=
    Flow_sop.Catalog.descriptor(List.find(fun f->Sop.Edit_graph.factory_key f="point_jitter")lowered.factories))
    "Point Jitter full native descriptor";
  let graph=List.hd lowered.graphs in
  Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root) |>get_string_ok
let native input changes =
  let initial=Sop.Edit_graph.instantiate Sop.Nodes.Point_jitter.factory[input] |>get_string_ok in
  fst(N.apply_parameters initial changes |>get_string_ok)
let session f =
  let session=Sop.Session.create ~max_entries:64 ~max_payload_bytes:512_000_000 |>get_string_ok in
  Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->f session)
let result ?(seed=0L) session domains grain node =
  let context=Sop.Context.create ~seed ~domains ~grain () |>get_string_ok in
  Result.bind (Sop.Session.cook session ~context node) (fun cooked->Sop.Payload.geometry cooked.payload)
let cook ?seed session domains grain node = match result ?seed session domains grain node with
  |Ok geometry->geometry|Error error->fail(error.code^": "^error.message^" "^Option.value ~default:"" error.cause)
let points n=Kernel.generate_point_ranges n(fun ~first ~last ~x ~y ~z->
  for i=first to last-1 do x.(i)<-float i *.0.01;y.(i)<-0.3;z.(i)<- -0.7 done)
let attr geo name storage = Geometry.with_attribute
  (Attribute.create_owned ~owner:Attribute.Point ~name storage |>get_string_ok)geo |>get_string_ok
let storages count =
  let values=Array.init count(fun i->if i mod 2=0 then -0. else float i *.0.25)
  and integers=Array.init count(fun i->if i mod 2=0 then min_int else max_int) in
  ["float",Attribute.Float values;"int",Int integers;
   "vec2",Float2(Packed.Float2.of_owned ~x:(Array.copy values) ~y:(Array.copy values)|>get_string_ok);
   "vec3",Float3(Packed.Float3.of_owned ~x:(Array.copy values) ~y:(Array.copy values) ~z:(Array.copy values)|>get_string_ok);
   "vec4",Float4(Packed.Float4.of_owned ~x:(Array.copy values) ~y:(Array.copy values) ~z:(Array.copy values) ~w:(Array.copy values)|>get_string_ok);
   "float_rows",Float_array(Packed.Float_array.create_owned ~offsets:(Array.init(count+1)Fun.id) ~values:(Array.copy values)|>get_string_ok);
   "int_rows",Int_array(Packed.Int_array.create_owned ~offsets:(Array.init(count+1)Fun.id) ~values:(Array.copy integers)|>get_string_ok);
   "text",Text(Array.init count(fun i->if i mod 2=0 then "é猫\000\t\n" else string_of_int i))]
let fixture geo =
  let count=Geometry.point_count geo in
  let geo=attr geo "mask" (Attribute.Float(Array.init count(fun i->float(i mod 5-2) *.0.25))) in
  let geo=attr geo "pscale" (Attribute.Float(Array.init count(fun i->0.5+.float(i mod 3)))) in
  let geo=attr geo "stable_id" (Attribute.Int(Array.init count(fun i->
    match i mod 4 with 0->min_int|1->max_int|2->i|_-> -i))) in
  let geo=List.fold_left(fun geo(name,selected)->Geometry.with_group
    (Group.init ~owner:Group.Point ~name count selected)geo |>get_string_ok)geo
    ["selected",(fun i->i mod 2=0);"empty",(fun _->false);"full",(fun _->true)] in
  let geo=List.fold_left(fun geo owner->
    let count=match owner with Attribute.Point->count|Vertex->Geometry.vertex_count geo
      |Primitive->Geometry.primitive_count geo|Detail->1 in
    List.fold_left(fun geo(name,storage)->Geometry.with_attribute
      (Attribute.create_owned ~owner ~name:("keep_"^name) storage |>get_string_ok)geo |>get_string_ok)
      geo(storages count))geo [Attribute.Point;Vertex;Primitive;Detail] in
  let geo=List.fold_left(fun geo owner->
    let length=match owner with Group.Point->count|Vertex->Geometry.vertex_count geo
      |Primitive->Geometry.primitive_count geo in
    Geometry.with_group(Group.ordered ~owner ~name:"keep_order" ~length
      (Array.init length(fun i->length-1-i)) |>get_string_ok)geo |>get_string_ok)
    geo [Group.Point;Vertex;Primitive] in
  let topology=Geometry.topology geo in
  let geo=Geometry.with_edge_group(Edge_group.init ~topology ~index:(Topology_index.create topology)
    ~name:"keep_edges"(fun i->i mod 2=0))geo |>get_string_ok in
  List.fold_left(fun geo owner->
    let count=if owner=Attribute.Point then count else Geometry.vertex_count geo in
    let normal=Packed.Float3.of_owned ~x:(Array.make count (-0.)) ~y:(Array.make count 1.) ~z:(Array.make count 0.) |>get_string_ok in
    Geometry.with_attribute(Attribute.create_owned ~owner ~name:"N" (Attribute.Float3 normal) |>get_string_ok)geo |>get_string_ok)
    geo [Attribute.Point;Vertex]
let cases = ["",[];
  ":scale 0",["scale",P.Float_value 0.];
  ":axis [0 0 0]",["axis_x",P.Float_value 0.;"axis_y",P.Float_value 0.;"axis_z",P.Float_value 0.];
  ":group \"empty\"",["group",P.Text_value "empty"];
  ":group \" selected \" :mask_attribute \" mask \" :id_attribute \" stable_id \" :use_point_scale true :axis [0.25 1.5 0.75] :scale 2.75",
    ["group",P.Text_value " selected ";"mask_attribute",P.Text_value " mask ";"id_attribute",P.Text_value " stable_id ";"use_point_scale",P.Bool_value true;
     "axis_x",P.Float_value 0.25;"axis_y",P.Float_value 1.5;"axis_z",P.Float_value 0.75;"scale",P.Float_value 2.75];
  ":id_attribute \"missing\" :seed -4611686018427387904",["id_attribute",P.Text_value "missing";"seed",P.Int_value min_int];
  ":id_attribute \" P \"",["id_attribute",P.Text_value " P "];
  ":seed_mode \"Auto\" :seed 42",["seed_mode",P.Choice_value "Auto";"seed",P.Int_value 42];
  ":mask_attribute \" \t\n \" :id_attribute \" \t \"",["mask_attribute",P.Text_value " \t\n ";"id_attribute",P.Text_value " \t "]]
let verify () =
  let grid=session(fun s->cook s 1 97(Lisp_sop.node "(sop/grid :columns 64 :rows 64 :connectivity \"Quads\")")) in
  check(Geometry.point_count grid=4225 && Geometry.primitive_count grid=4096)"Point Jitter real grid";
  List.iter(fun geo->let geo=fixture geo in let input=Lisp_sop.snapshot geo and before=geometry_bytes geo in
    List.iter(fun(keywords,changes)->
      let actual=node ~reference:false input keywords and reference=node ~reference:true input keywords and expected=native input changes in
      check(N.parameter_fields actual=N.parameter_fields expected)"Point Jitter schema";
      check(N.parameter_key actual=N.parameter_key expected)"Point Jitter key";
      check(N.label actual=N.label expected && N.operation actual=N.operation expected && N.version actual=N.version expected)"Point Jitter identity";
      session(fun s->let baseline=cook ~seed:0x7000000000000000L s 1 97 actual in
        check(close_geometry ~ulps:4 baseline(cook ~seed:0x7000000000000000L s 1 97 expected))("Point Jitter native "^keywords);
        check(geometry_bytes baseline=geometry_bytes(cook ~seed:0x7000000000000000L s 1 97 reference))"Point Jitter strict/reference";
        List.iter(fun domains->List.iter(fun grain->Sop.Session.clear s;
          check(geometry_bytes baseline=geometry_bytes(cook ~seed:0x7000000000000000L s domains grain actual))"Point Jitter domains/grain") [1;97;4096])[1;4;8]);
      check(before=geometry_bytes geo)"Point Jitter mutated input")cases)
    [points 0;points 1;points 6;grid;points 32769];
  print_endline "Point Jitter full seed/group/ID/mask/pscale modes, native4ULP, unchanged normals and strict/reference/domain/grain bytes"
let errors () =
  let base=fixture(points 6) in
  List.iter(fun(geo,keywords,changes)->let input=Lisp_sop.snapshot geo in
    let expected=native input changes in
    session(fun s->let expected=match result s 1 97 expected with Error error->error
      |Ok _->fail("Point Jitter expected native error "^keywords) in
      List.iter(fun reference->let actual=node ~reference input keywords in
        List.iter(fun domains->List.iter(fun grain->Sop.Session.clear s;
          match result s domains grain actual with
          |Error actual->check(expected.code=actual.code && expected.message=actual.message && expected.cause=actual.cause)
              ("Point Jitter diagnostic "^keywords)
          |Ok _->fail("Point Jitter expected error "^keywords)) [1;97;4096]) [1;4;8]) [false;true]))
    ([base,":group \"absenté\" :mask_attribute \"absent\"",["group",P.Text_value "absenté";"mask_attribute",P.Text_value "absent"];
     base,":mask_attribute \"absent\"",["mask_attribute",P.Text_value "absent"];
     base,":mask_attribute \"P\"",["mask_attribute",P.Text_value "P"];
     attr base "mask"(Attribute.Int(Array.make 6 1)),":mask_attribute \"mask\" :use_point_scale true",["mask_attribute",P.Text_value "mask";"use_point_scale",P.Bool_value true];
     attr base "pscale"(Attribute.Int(Array.make 6 1)),":use_point_scale true :id_attribute \"mask\"",["use_point_scale",P.Bool_value true;"id_attribute",P.Text_value "mask"];
     base,":id_attribute \"mask\"",["id_attribute",P.Text_value "mask"]] @
      List.concat_map(fun count->let base=fixture(points count) in
        List.concat_map(fun(kind,storage)->
          (if kind="float" then [] else
            [attr base "mask" storage,":group \"empty\" :mask_attribute \"mask\"",
              ["group",P.Text_value "empty";"mask_attribute",P.Text_value "mask"];
             attr base "pscale" storage,":group \"empty\" :use_point_scale true",
              ["group",P.Text_value "empty";"use_point_scale",P.Bool_value true]]) @
          (if kind="int" then [] else
            [attr base "stable_id" storage,":group \"empty\" :id_attribute \"stable_id\"",
              ["group",P.Text_value "empty";"id_attribute",P.Text_value "stable_id"]])) (storages count)) [0;6]);
  print_endline "Point Jitter all optional incompatible storages, empty/ordinary owner counts, diagnostic precedence/code/message/cause, strict/reference/domains/grains"
let nonfinite_inputs () =
  List.iter(fun(name,keywords,changes)->List.iter(fun bad->
    let base=fixture(points 6) in
    let values=Array.make 6 1. in values.(1)<-bad;
    let geo=if name="P" then
      let old=Packed.Float3.Private.view(Geometry.positions base) in
      Geometry.with_positions(Packed.Float3.of_owned ~x:values ~y:(Array.copy old.y) ~z:(Array.copy old.z)
        |>get_string_ok)base |>get_string_ok
      else attr base name(Attribute.Float values) in let input=Lisp_sop.snapshot geo in
    List.iter(fun group->
      let keywords=keywords^" :group \""^group^"\"" and changes=("group",P.Text_value group)::changes in
      session(fun s->
        let native_result=result s 1 97(native input changes) in
        (match native_result with
         |Ok actual->check(group<>"full")"Native selected nonfinite accepted";
             if group="empty" then check(geometry_bytes actual=geometry_bytes geo)
               "Native empty selection must preserve positions/normals/attributes exactly"
         |Error error->check(group="full" && error.code="invalid_attribute"
             && error.message="point_jitter could not produce valid geometry"
             && error.cause=Some "point_jitter [invalid_attribute]: Rdk_gen.Point_jitter.point_jitter: selected point 1 has non-finite input or output")
               "Native first selected nonfinite index/cause contract");
        List.iter(fun reference->let actual=node ~reference input keywords in
          List.iter(fun domains->List.iter(fun grain->Sop.Session.clear s;
            match native_result,result s domains grain actual with
            |Ok expected,Ok got->check(geometry_bytes expected=geometry_bytes got)
                ("Point Jitter unselected nonfinite native bytes "^name^" "^group)
            |Error expected,Error got->check(expected.code=got.code && expected.message=got.message && expected.cause=got.cause)
                ("Point Jitter selected nonfinite native diagnostic "^name^" "^group)
            |_->fail("Point Jitter nonfinite result mismatch "^name^" "^group)) [1;97;4096]) [1;4;8]) [false;true]))
      ["empty";"selected";"full"]) [nan;infinity;neg_infinity])
    ["mask",":mask_attribute \"mask\"",["mask_attribute",P.Text_value "mask"];
     "pscale",":use_point_scale true",["use_point_scale",P.Bool_value true];
     "P","",[]];
  print_endline "Point Jitter checked raw P/mask/pscale: ignored unselected NaN/Inf bytes and exact selected first-index errors, strict/reference/domains/grains"
let edits () =
  let input=Lisp_sop.snapshot(fixture(points 6)) in
  let initial=node ~reference:false input "" and oracle=native input [] in
  List.iter(fun(field:P.field_view)->
    let value=match field.current with
      |P.Text_value _->P.Text_value(if field.name="group" then "selected" else if field.name="mask_attribute" then "mask" else "stable_id")
      |Choice_value _->P.Choice_value "Auto"|Int_value _->P.Int_value max_int
      |Float_value x->P.Float_value(x+.0.25)|Bool_value _->P.Bool_value true in
    let edited=fst(N.apply_parameters initial[field.name,value] |>get_string_ok)
    and expected=fst(N.apply_parameters oracle[field.name,value] |>get_string_ok) in
    check(N.parameter_key edited=N.parameter_key expected)("Point Jitter edited key "^field.name);
    session(fun s->ignore(cook s 1 97 initial);let before=Sop.Session.stats s in
      let actual=cook s 1 97 edited in let after=Sop.Session.stats s in
      check(after.misses=before.misses+1)("Point Jitter one public miss "^field.name);
      ignore(cook s 1 97 edited);let warm=Sop.Session.stats s in
      check(warm.misses=after.misses && warm.hits>after.hits)("Point Jitter warm hit "^field.name);
      check(close_geometry ~ulps:4 actual(cook s 1 97 expected))("Point Jitter edited native "^field.name)))
    (N.parameter_fields initial);
  List.iter(fun mode->let actual=node ~reference:false input(":seed_mode \""^mode^"\"") in
    session(fun s->let before_geometry=cook ~seed:0L s 1 97 actual in let before=Sop.Session.stats s in
      let after_geometry=cook ~seed:0x7000000000000000L s 1 97 actual in let after=Sop.Session.stats s in
      check(after.misses=before.misses+(if mode="Auto" then 1 else 0))"Point Jitter context Seed cache dependency";
      check((geometry_bytes before_geometry=geometry_bytes after_geometry)=(mode="Explicit"))"Point Jitter explicit/auto Seed behavior"))
    ["Explicit";"Auto"];
  List.iter(fun name->List.iter(fun value->let changes=[name,P.Float_value value] in
    match N.apply_parameters initial changes,N.apply_parameters oracle changes with
    |Error actual,Error expected->check(actual=expected)"Point Jitter nonfinite parameter diagnostic"
    |_->fail "Point Jitter nonfinite parameter accepted") [nan;infinity;neg_infinity])
    ["scale";"axis_x";"axis_y";"axis_z"];
  print_endline "Point Jitter every physical field/native cache key, one public miss/warm hit, Seed dependency and invalid parameter atomicity"
let projection () =
  let module Projection=Flow_graph.Projection in
  let module Edit=Flow_graph.Flow_edit in
  let input=Lisp_sop.snapshot(fixture(points 6)) in
  let factory=Sop.Edit_graph.factory ~key:"jitter_input" ~label:"Jitter input" ~category:["Test"] ~arity:0(fun _->input) in
  let factories=factory::List.filter(fun f->Sop.Edit_graph.factory_key f<>"point_jitter")Sop_catalog.Editor.factories in
  let catalog factories=Flow_sop.Catalog.of_factories ~nodes:[] ~version:Flow_sop.Manifest.version factories |>checked in
  let native_catalog=catalog(Sop.Nodes.Point_jitter.factory::factories) and catalog=catalog factories in
  let checker forms=Flow_sop.Catalog.check_workspace ~sources ~ops:Flow_sop.Operators.all catalog forms in
  let workspace=function Some w,ds when not(List.exists(fun(d:Flow.Diagnostic.t)->d.severity=Error)ds)->w
    |_,ds->fail(String.concat "\n"(List.map Flow.Diagnostic.to_string ds)) in
  let forms=Flow.Syntax.parse{|(workspace jitter (graph g :context sop
    (let* [src (sop/jitter_input) card (sop/point_jitter src :group "" :mask_attribute "" :id_attribute ""
      :seed_mode "Explicit" :seed 0 :scale 1.0 :use_point_scale false :axis [1.0 1.0 1.0])] card)))|} |>checked in
  let actual=workspace(checker forms) and expected=workspace(Flow.Workspace.check ~ops:Flow_sop.Operators.all native_catalog forms) in
  let card catalog workspace=Option.get(Projection.find(Projection.of_graph catalog workspace "g")["g";"card"]) in
  let normalize(card:Projection.node)={card with rows=List.map(fun(row:Projection.row)->
    {row with expr=Option.map(fun expr->List.hd(Flow.Syntax.parse(Flow.Lisp.flat expr)|>checked))row.expr})card.rows} in
  let actual_card=card catalog actual and expected_card=card native_catalog expected in
  check(normalize actual_card=normalize expected_card)"Point Jitter native graph card metadata";
  check(Projection.lines Full(normalize actual_card)=Projection.lines Full(normalize expected_card))"Point Jitter inspector rows";
  List.iter(fun(key,sub,value,field,parameter)->
    let _,changed=Edit.apply_checked ~checker:(fun _ forms->checker forms) catalog forms
      (Set_arg{node=actual_card.path;key=Kw key;sub;value=Flow.Syntax.make value}) |>checked in
    let lowered=Flow_sop.Lower.of_checked ~factories changed |>checked in let graph=List.hd lowered.graphs in
    let edited=Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root)|>get_string_ok in
    let expected=native input[field,parameter] in
    check(N.parameter_key edited=N.parameter_key expected)("Point Jitter graph gesture "^field);
    session(fun s->check(close_geometry ~ulps:4(cook s 1 97 edited)(cook s 1 97 expected))
      ("Point Jitter graph gesture cook "^field)))
    ["group",[],Flow.Syntax.Str "selected","group",P.Text_value "selected";
     "mask_attribute",[],Str "mask","mask_attribute",P.Text_value "mask";
     "id_attribute",[],Str "stable_id","id_attribute",P.Text_value "stable_id";
     "seed_mode",[],Str "Auto","seed_mode",P.Choice_value "Auto";
     "seed",[],Num "42","seed",P.Int_value 42;
     "scale",[],Num "0.25","scale",P.Float_value 0.25;
     "use_point_scale",[],Sym "true","use_point_scale",P.Bool_value true;
     "axis",[0],Num "0.25","axis_x",P.Float_value 0.25;
     "axis",[1],Num "0.25","axis_y",P.Float_value 0.25;
     "axis",[2],Num "0.25","axis_z",P.Float_value 0.25];
  let _,bypassed=Edit.apply_checked ~checker:(fun _ forms->checker forms) catalog forms
    (Toggle_bypass{node=actual_card.path}) |>checked in
  let lowered=Flow_sop.Lower.of_checked ~factories bypassed |>checked in
  let graph=List.hd lowered.graphs in
  let bypassed=Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root)|>get_string_ok in
  session(fun s->check(geometry_bytes(cook s 1 97 bypassed)=geometry_bytes(cook s 1 97 input))
    "Point Jitter graph bypass input bytes");
  (match Edit.apply_checked ~checker:(fun _ forms->checker forms) catalog forms
    (Set_arg{node=actual_card.path;key=Kw "seed_mode";sub=[];value=Flow.Syntax.make(Str "invalid")}) with
    |Error _->()|Ok _->fail "Point Jitter invalid seed-mode gesture accepted");
  print_endline "Point Jitter graph/inspector native structural parity and every physical direct gesture"
let checked_overflow () =
  let mask=Array.make 6 1. in mask.(1)<-Float.max_float;
  let geo=attr(fixture(points 6))"mask"(Attribute.Float mask) in
  let input=Lisp_sop.snapshot geo in
  List.iter(fun group->let keywords=":mask_attribute \"mask\" :scale 2.0 :group \""^group^"\""
    and changes=["mask_attribute",P.Text_value "mask";"scale",P.Float_value 2.;"group",P.Text_value group] in
    session(fun s->let expected=result s 1 97(native input changes) in
      List.iter(fun reference->let actual=result s 1 97(node ~reference input keywords) in
        match expected,actual with
        |Ok expected,Ok actual->check(close_geometry ~ulps:4 expected actual)"Point Jitter unselected finite overflow must be ignored"
        |Error expected,Error actual->check(expected.code=actual.code && expected.message=actual.message && expected.cause=actual.cause
            && expected.cause=Some "point_jitter [invalid_attribute]: Rdk_gen.Point_jitter.point_jitter: selected point 1 has non-finite input or output")
              "Point Jitter selected finite multiplication overflow exact native refusal"
        |_->fail "Point Jitter finite overflow selection behavior changed") [false;true])) ["selected";"full"]
let checked_edges () =
  let compare label geometry keywords changes success =
    let input=Lisp_sop.snapshot geometry and before=geometry_bytes geometry in
    session(fun s->let expected=result s 1 97(native input changes) in
      check(Result.is_ok expected=success)("Point Jitter native edge fixture "^label);
      let baseline=ref None in
      List.iter(fun reference->let actual=node ~reference input keywords in
        List.iter(fun domains->List.iter(fun grain->Sop.Session.clear s;
          match expected,result s domains grain actual with
          |Ok expected,Ok got->
              check(close_geometry ~ulps:4 expected got)("Point Jitter edge native "^label);
              let bytes=geometry_bytes got in
              (match !baseline with None->baseline:=Some bytes|Some old->
                check(old=bytes)("Point Jitter edge strict/reference/domain/grain "^label))
          |Error expected,Error got->check(expected.code=got.code && expected.message=got.message && expected.cause=got.cause)
              ("Point Jitter edge exact diagnostic "^label)
          |_->fail("Point Jitter edge result mismatch "^label)) [1;97;4096]) [1;4;8]) [false;true]);
    check(before=geometry_bytes geometry)("Point Jitter edge mutated input "^label) in
  let base=fixture(points 6) in
  let without_pscale=Geometry.without_attribute ~owner:Attribute.Point "pscale" base in
  compare "missing optional pscale" without_pscale ":use_point_scale true"
    ["use_point_scale",P.Bool_value true] true;
  let inactive=attr base "pscale"(Attribute.Float(Array.make 6 nan)) in
  (* Unrequested optional columns are never inspected, including raw invalid rows. *)
  let input=Lisp_sop.snapshot inactive in
  session(fun s->let expected=cook s 1 97(native input []) in
    List.iter(fun reference->check(geometry_bytes expected=geometry_bytes(cook s 1 97(node ~reference input "")))
      "Point Jitter disabled raw pscale byte preservation") [false;true]);
  let overflow=attr(attr base "mask"(Attribute.Float(Array.make 6 Float.max_float)))
    "pscale"(Attribute.Float(Array.make 6 0.)) in
  compare "overflow flag survives later zero" overflow
    ":mask_attribute \"mask\" :scale 2.0 :use_point_scale true"
    ["mask_attribute",P.Text_value "mask";"scale",P.Float_value 2.;"use_point_scale",P.Bool_value true] false;
  compare "zero scale ignores finite huge pscale" (attr base "pscale"(Attribute.Float(Array.make 6 Float.max_float)))
    ":scale 0.0 :use_point_scale true" ["scale",P.Float_value 0.;"use_point_scale",P.Bool_value true] true;
  let sample=Rays_math.Rand.float_at(Rays_math.Rand.seed 0)
    ~index:1276007651554290947 -.0.5 in
  let dx=Sys.opaque_identity(sample *.Float.max_float) in
  let axis=Float.max_float /.Float.abs dx *.1.25 in
  let position= -.Float.copy_sign Float.max_float dx in
  let p x=Geometry.with_positions(Packed.Float3.of_owned ~x:[|x|] ~y:[|0.|] ~z:[|-0.|]
    |>get_string_ok)(fixture(points 1)) |>get_string_ok in
  let keywords=Printf.sprintf ":scale %.17g :axis [%.17g 0.0 0.0]" Float.max_float axis in
  let parameters=["scale",P.Float_value Float.max_float;"axis_x",P.Float_value axis;
    "axis_y",P.Float_value 0.;"axis_z",P.Float_value 0.] in
  compare "fused finite cancellation of overflowing product" (p position) keywords parameters true;
  compare "selected final fma overflow" (p(-.position)) keywords parameters false;
  let count=32769 in
  let values=Array.make count 1. in values.(3)<-nan;values.(4097)<-infinity;values.(count-1)<-neg_infinity;
  let geometry=attr(fixture(points count))"mask"(Attribute.Float values) in
  compare "first invalid selected index across grain ranges" geometry ":mask_attribute \"mask\""
    ["mask_attribute",P.Text_value "mask"] false;
  print_endline "Point Jitter checked flag chains, fused overflow cancellation, output overflow, missing/disabled pscale and first invalid grain-independent index"
let benchmark_geometry () =
  let geometry=session(fun s->cook s 1 4096
    (Lisp_sop.node "(sop/grid :columns 999 :rows 999 :connectivity \"Quads\")")) in
  let count=Geometry.point_count geometry in
  check(count=1_000_000 && Geometry.primitive_count geometry=998_001)
    "Point Jitter benchmark real million-point grid";
  let geometry=attr geometry "mask"(Attribute.Float(Array.init count(fun i->float(i mod 5-2)*.0.25))) in
  let geometry=attr geometry "pscale"(Attribute.Float(Array.init count(fun i->0.5+.float(i mod 3)))) in
  let geometry=attr geometry "stable_id"(Attribute.Int(Array.init count(fun i->
    match i mod 4 with 0->min_int|1->max_int|2->i|_-> -i))) in
  let geometry=List.fold_left(fun geometry(name,selected)->Geometry.with_group
    (Group.init ~owner:Group.Point ~name count selected)geometry |>get_string_ok)geometry
    ["selected",(fun i->i mod 2=0);"empty",(fun _->false);"full",(fun _->true)] in
  List.fold_left(fun geometry owner->
    let count=if owner=Attribute.Point then count else Geometry.vertex_count geometry in
    Geometry.with_attribute(Attribute.create_owned ~owner ~name:"N"
      (Attribute.Float3(Packed.Float3.of_owned ~x:(Array.make count (-0.))
        ~y:(Array.make count 1.) ~z:(Array.make count 0.) |>get_string_ok)) |>get_string_ok)geometry |>get_string_ok)
    geometry [Attribute.Point;Vertex]
let benchmark first_only =
  let geometry=benchmark_geometry () in
  let count=Geometry.point_count geometry in
  let input=Lisp_sop.snapshot geometry in
  let selected=List.find(fun(keywords,_)->String.starts_with ~prefix:":group \" selected \"" keywords)cases in
  let rows=if first_only then ["defaults",("",[]);"selected_optional",selected] else
    List.mapi(fun i row->"mode_"^string_of_int i,row)cases in
  let median samples=List.sort(fun(a,_)(b,_)->Float.compare a b)samples |>fun samples->List.nth samples 1 in
  List.iter(fun(label,(keywords,changes))->
    let actual=node ~reference:false input keywords and oracle=native input changes
    and reference=node ~reference:true input keywords in
    let fingerprint=ref None in
    List.iter(fun domains->
      session(fun s->let got=cook ~seed:0x7000000000000000L s domains 4096 actual in
        check(close_geometry ~ulps:4 got(cook ~seed:0x7000000000000000L s domains 4096 oracle))
          ("Point Jitter benchmark native4ULP "^label);
        let bytes=geometry_bytes got in
        check(bytes=geometry_bytes(cook ~seed:0x7000000000000000L s domains 4096 reference))
          ("Point Jitter benchmark strict/reference bytes "^label);
        (match !fingerprint with None->fingerprint:=Some bytes|Some before->
          check(before=bytes)("Point Jitter benchmark domain bytes "^label)));
      let sample node=List.init 3(fun _->session(fun s->Gc.full_major();
        let allocated=Gc.allocated_bytes() and started=Unix.gettimeofday() in
        ignore(cook ~seed:0x7000000000000000L s domains 4096 node);
        Unix.gettimeofday()-.started,Gc.allocated_bytes()-.allocated)) |>median in
      let native_time,native_bytes=sample oracle and time,bytes=sample actual in
      Printf.printf "Point Jitter grid_points=%d quads=998001 mode=%s domains=%d grain=4096 native=%.6f lisp=%.6f ratio=%.3f native_bytes=%.0f lisp_bytes=%.0f\n%!"
        count label domains native_time time(time/.native_time)native_bytes bytes) [1;4])rows
let trace () =
  let module K=Flow_ir.Packed in
  let module C=Flow_ir.Core in
  let programs=ref [] and attempts=ref 0 and refusals=ref 0 in
  let old= !(K.Private.trace) in
  let phase=ref "construct" in
  let compiled=function
    |Error diagnostics->incr refusals;
        if !refusals<=20 then List.iter(fun d->Printf.printf "trace packed_refusal phase=%s %s\n%!"
          !phase(Flow.Diagnostic.to_string d))diagnostics
    |Ok program->incr attempts;
        if List.length !programs<80 then programs:=(!phase,program)::!programs in
  let geometry=benchmark_geometry () in
  let input=Lisp_sop.snapshot geometry in
  Fun.protect ~finally:(fun()->K.Private.trace:=old)(fun()->
    K.Private.trace:=compiled;
    Gc.full_major();
    let allocated=Gc.allocated_bytes() and started=Unix.gettimeofday() in
    let actual=node ~reference:false input "" in
    Printf.printf "trace construct points=1000000 seconds=%.6f bytes=%.0f\n%!"
      (Unix.gettimeofday()-.started)(Gc.allocated_bytes()-.allocated);
    phase:="cook";
    List.iter(fun domains->session(fun s->Gc.full_major();
      let allocated=Gc.allocated_bytes() and started=Unix.gettimeofday() in
      ignore(cook s domains 4096 actual);
      Printf.printf "trace whole_cook points=1000000 domains=%d seconds=%.6f bytes=%.0f\n%!"
        domains(Unix.gettimeofday()-.started)(Gc.allocated_bytes()-.allocated))) [1;4];
    K.Private.trace:=old;
    Printf.printf "trace public_compile_successes=%d refusals=%d retained=%d\n%!"
      !attempts !refusals(List.length !programs);
    List.iteri(fun index(phase,program)->
      let view=K.Private.view program and region=K.to_region program in
      let counts=Hashtbl.create 16 in
      let add name=Hashtbl.replace counts name(1+Option.value ~default:0(Hashtbl.find_opt counts name)) in
      let rec instruction=function
        |K.Guarded(_,body)->add "Guarded";instruction body
        |Checked_mul(Value,_,_)->add "Checked_mul.value"|Checked_mul(Valid,_,_)->add "Checked_mul.valid"
        |Checked_fma(Value,_,_,_)->add "Checked_fma.value"|Checked_fma(Valid,_,_,_)->add "Checked_fma.valid"
        |Rand_at _->add "Rand_at"|Fma _->add "Fma"|Int_input _->add "Int_input"|Input _->add "Input"
        |Int_binary _->add "Int_binary"|Int_compare _->add "Int_compare"|Binary _->add "Binary"
        |Select _|Int_select _->add "Select"|Const _|Int_const _->add "Const"
        |Uniform _|Int_uniform _->add "Uniform"|_->add "Other" in
      Array.iter instruction view.code;
      let counts=Hashtbl.to_seq counts |>List.of_seq |>List.sort(fun(a,_)(b,_)->String.compare a b)
        |>List.map(fun(name,count)->Printf.sprintf "%s:%d" name count) |>String.concat "," in
      Printf.printf "trace region=%d phase=%s source_offset=%d code=%d stages=%d sources=%d outputs=%d classes=%s\n%!"
        index phase region.term.form.span.start(Array.length view.code)(K.stage_count program)
        (Array.length region.sources)(Array.length view.outputs)counts;
      Array.iteri(fun index(_,term)->Printf.printf "trace source=%d type=%s form=%s\n%!"
        index(Flow.Ty.to_string term.Flow.Workspace.ty)(Flow.Lisp.flat term.form))region.sources;
      match Flow_ir.Core_lower.lower ~strict:true region.residual with
      |Error reason->Printf.printf "trace residual_core_refusal=%s\n%!" reason
      |Ok core->
          let counts=Hashtbl.create 16 in
          let add name=Hashtbl.replace counts name(1+Option.value ~default:0(Hashtbl.find_opt counts name)) in
          let rec statements body=List.iter(fun(statement:C.statement)->match statement.node with
            |Assign(_,Source _)->add "Source"|Assign(_,Host_source _)->add "Host_source"
            |Assign(_,Source_descriptor _)->add "Source_descriptor"
            |Assign(_,Prim(op,_))->add(C.primitive_name op)
            |Invoke _->add "Invoke"|If{yes;no;_}->statements yes;statements no
            |Iterate{body;_}->add "Iterate";statements body
            |Counted{init;body;_}->add "Counted";statements init;statements body
            |State_read{init;_}->statements init|_->())body in
          statements core.body;
          let counts=Hashtbl.to_seq counts |>List.of_seq |>List.sort(fun(a,_)(b,_)->String.compare a b)
            |>List.map(fun(name,count)->Printf.sprintf "%s:%d" name count) |>String.concat "," in
          Printf.printf "trace residual_core locals=%d regions=%d classes=%s\n%!"
            (Array.length core.locals)(Array.length core.regions)counts)
      (List.rev !programs))
let profile () =
  let input=Lisp_sop.snapshot(benchmark_geometry()) in
  let actual=node ~reference:false input "" in
  session(fun s->
    Printf.printf "Point Jitter profile ready pid=%d: default 1M points, domains=1 grain=4096\n%!"
      (Unix.getpid());
    let until=Unix.gettimeofday()+.8. and count=ref 0 in
    while Unix.gettimeofday()<until do
      Sop.Session.clear s;
      ignore(cook s 1 4096 actual);
      incr count
    done;
    Printf.printf "Point Jitter profile: %d cleared-session cooks\n%!" !count)
let () = if Array.exists((=)"--profile")Sys.argv then profile()
  else if Array.exists((=)"--bench-first")Sys.argv then benchmark true
  else if Array.exists((=)"--bench")Sys.argv then benchmark false
  else if Array.exists((=)"--trace")Sys.argv then trace()
  else(verify();errors();nonfinite_inputs();edits();projection();checked_overflow();checked_edges())
