open Rdk
open Rdk_test_support
module N = Sop.Node
module P = Param
let checked = function Ok x->x|Error d->fail (Flow.Diagnostic.to_string d)
let sources = (Flow_sop.Catalog.sources () |> checked) @
  (In_channel.with_open_text "nodes/rest_position.pending" In_channel.input_all
   |> Flow.Syntax.parse |> checked)
let node ~reference input sample keywords =
  let input_factory=Sop.Edit_graph.factory ~key:"rest_input" ~label:"Input" ~category:["Test"] ~arity:0 (fun _->input) in
  let factories=input_factory::List.filter (fun f->Sop.Edit_graph.factory_key f<>"rest_position") Sop_catalog.Editor.factories in
  let factories,argument=match sample with None->factories,""|Some sample->
    Sop.Edit_graph.factory ~key:"rest_sample" ~label:"Reference" ~category:["Test"] ~arity:0 (fun _->sample)::factories,"(sop/rest_sample)" in
  let catalog=Flow_sop.Catalog.of_factories ~nodes:[] ~version:Flow_sop.Manifest.version factories |> checked in
  let forms=Flow.Syntax.parse (Printf.sprintf "(workspace rest (graph g :context sop (sop/rest_position (sop/rest_input) %s %s)))" argument keywords) |> checked in
  let workspace=match Flow_sop.Catalog.check_workspace ~sources ~ops:Flow_sop.Operators.all catalog forms with
    |Some w,ds when not(List.exists(fun(d:Flow.Diagnostic.t)->d.severity=Error)ds)->w
    |_,ds->fail(String.concat "\n"(List.map Flow.Diagnostic.to_string ds)) in
  let lowered=Flow_sop.Lower.of_checked ~reference ~factories workspace |> checked in
  let graph=List.hd lowered.graphs in
  Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root) |> get_string_ok
let native input sample changes =
  let node=Sop.Edit_graph.instantiate_optional Sop.Nodes.Rest_position.factory [Some input;sample] |> get_string_ok in
  fst(N.apply_parameters node changes |> get_string_ok)
let points count offset=Kernel.generate_point_ranges count(fun ~first ~last ~x ~y ~z->
  for i=first to last-1 do x.(i)<-float i+.offset;y.(i)<-0.25+.offset;z.(i)<- -0.5 done)
let add name owner values geometry=Geometry.with_attribute
  (Attribute.create_owned ~name ~owner values |> get_string_ok) geometry |> get_string_ok
let payload geometry =
  let count=Geometry.point_count geometry in
  geometry
  |> add "rest" Attribute.Point (Attribute.Float3(Geometry.positions(points count 7.)))
  |> add "N" Attribute.Point (Attribute.Float3(Geometry.positions(points count 2.)))
  |> add "restN" Attribute.Point (Attribute.Float3(Geometry.positions(points count 3.)))
  |> add "tag" Attribute.Detail (Attribute.Text[|"untouched ✓"|])
  |> Geometry.with_group (Group.init ~owner:Group.Point ~name:"selection" count(fun i->i mod 2=0)) |> get_string_ok
let mixed () =
  let topology=Topology.create_owned ~point_count:6 ~vertex_points:[|0;1;2;3;1;4;5|]
    ~primitive_offsets:[|0;4;7|] ~primitive_kinds:[|Topology.Polygon;Open_polyline|] |> get_string_ok in
  Geometry.create ~positions:(Geometry.positions(points 6 0.)) ~topology () |> get_string_ok
let context domains grain=Sop.Context.create ~domains ~grain () |> get_string_ok
let cook session domains grain node=match Sop.Session.cook session ~context:(context domains grain) node with
  |Ok result->(match Sop.Payload.geometry result.payload with Ok g->g|Error d->fail d.message)
  |Error e->fail(Sop.Diagnostic.error_to_string e)
let cases = ["",[]; ":rest_attribute \"\"",["rest_attribute",P.Text_value ""]]
  @ List.concat_map(fun mode->List.map(fun normals->
    Printf.sprintf ":mode %S :normals %S" mode normals,
    ["mode",P.Choice_value mode;"normals",P.Choice_value normals]) ["None";"If present";"Always"]) ["Store";"Extract";"Swap"]
  @ [":rest_attribute \"N\" :normals \"If present\" :normal_attribute \"restN\" :rest_normal_attribute \"rest\"",
     ["rest_attribute",P.Text_value "N";"normals",P.Choice_value "If present";
      "normal_attribute",P.Text_value "restN";"rest_normal_attribute",P.Text_value "rest"]]
  @ List.concat_map(fun mode->List.map(fun(rest,normal,stored)->
      Printf.sprintf ":mode %S :normals \"If present\" :rest_attribute %S :normal_attribute %S :rest_normal_attribute %S"
        mode rest normal stored,
      ["mode",P.Choice_value mode;"normals",P.Choice_value "If present";
       "rest_attribute",P.Text_value rest;"normal_attribute",P.Text_value normal;
       "rest_normal_attribute",P.Text_value stored])
    ["rest","rest","rest";"rest","N","rest";"N","N","restN";"rest","restN","restN"])
    ["Store";"Extract";"Swap"]
  @ [":mode \"Extract\" :rest_normal_attribute \"P\"",
      ["mode",P.Choice_value "Extract";"rest_normal_attribute",P.Text_value "P"]]
let verify () =
  let grid=Plane_generators.grid ~connectivity:Grid_quads ~columns:64 ~rows:64 ~size:8. () |> get_ok in
  check(Geometry.point_count grid=4225) "rest_position grid must have 4,225 points";
  List.iter(fun geometry->
    let input=Lisp_sop.snapshot geometry and before=geometry_bytes geometry in
    List.iter(fun sample->List.iter(fun(keywords,changes)->
      let actual=node ~reference:false input sample keywords and walked=node ~reference:true input sample keywords
      and oracle=native input sample changes in
      check(N.operation actual=N.operation oracle && N.version actual=N.version oracle)
        "rest_position runtime operation/version differs";
      check(N.label actual=N.label oracle) "rest_position default label differs";
      check(N.parameter_fields actual=N.parameter_fields oracle) "rest_position metadata differs";
      check(N.parameter_key actual=N.parameter_key oracle) "rest_position parameter key differs";
      let session=Sop.Session.create ~max_entries:64 ~max_payload_bytes:256_000_000 |> get_string_ok in
      Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
        let baseline=cook session 1 97 actual in
        check(close_geometry ~ulps:4 baseline(cook session 1 97 oracle)) ("rest_position native differs: "^keywords);
        check(geometry_bytes baseline=geometry_bytes(cook session 1 97 walked)) "rest_position reference bytes differ";
        List.iter(fun domains->List.iter(fun grain->Sop.Session.clear session;
          check(geometry_bytes baseline=geometry_bytes(cook session domains grain actual)) "rest_position domain/grain bytes differ") [1;97;4096]) [1;4;8])) cases)
      [None;Some(Lisp_sop.snapshot(payload(points (Geometry.point_count geometry) 9.)))];
    check(before=geometry_bytes geometry) "rest_position input mutated")
    [points 0 0.;points 1 0.;mixed ();payload(mixed ());grid;payload grid;payload(points 32769 0.)];
  print_endline "rest_position draft: all modes/normal policies, optional reference, missing rest fallback, alias ordering, metadata/cache key and strict/reference/domain bytes pass"

let with_session f =
  let session=Sop.Session.create ~max_entries:64 ~max_payload_bytes:256_000_000 |> get_string_ok in
  Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->f session)

let errors () =
  let base=points 3 0. in
  let wrong name=add name Attribute.Point (Attribute.Int[|1;2;3|]) base in
  let cases=[
    wrong "rest",None,"",[];
    wrong "restN",None,"",[];
    wrong "N",None,":normals \"If present\"",["normals",P.Choice_value "If present"];
    base,None,":normals \"Always\" :normal_attribute \"other\"",
      ["normals",P.Choice_value "Always";"normal_attribute",P.Text_value "other"];
    base,Some(points 2 0.),"",[];
    wrong "rest",Some(points 2 0.),"",[];
    base,Some(wrong "N"),":normals \"Always\"",["normals",P.Choice_value "Always"];
    payload base,None,":mode \"Extract\" :normal_attribute \"P\"",
      ["mode",P.Choice_value "Extract";"normal_attribute",P.Text_value "P"];
    payload base,None,":mode \"Swap\" :normal_attribute \" \"",
      ["mode",P.Choice_value "Swap";"normal_attribute",P.Text_value " "];
    wrong "quoted \"\\\n\195\169",None,":rest_attribute \"quoted \\\"\\\\\\n\195\169\"",
      ["rest_attribute",P.Text_value "quoted \"\\\n\195\169"]
  ] in
  List.iter(fun(geometry,sample,keywords,changes)->
    let input=Lisp_sop.snapshot geometry and before=geometry_bytes geometry in
    let sample=Option.map Lisp_sop.snapshot sample in
    let oracle=native input sample changes in
    with_session(fun session->
      let expected=match Sop.Session.cook session ~context:(context 1 97) oracle with
        |Error error->error|Ok _->fail "rest_position native error fixture succeeded" in
      List.iter(fun reference->
        let actual=node ~reference input sample keywords in
        List.iter(fun domains->
          match Sop.Session.cook session ~context:(context domains 97) actual with
          |Ok _->fail "rest_position Lisp error fixture succeeded"
          |Error error->
              check(error.code=expected.code) ("rest_position error code differs: "^error.code);
              check(error.message=expected.message)
                ("rest_position error message differs: "^error.message^" / "^expected.message);
              check(error.cause=expected.cause) "rest_position native error cause differs") [1;4;8]) [false;true]);
    check(before=geometry_bytes geometry) "rest_position error changed input") cases;
  (* Extract/Swap ignore reference cardinality when rest exists; blank-rest/None
     returns before inspecting even a malformed stored normal. *)
  List.iter(fun(geometry,keywords,changes)->
    let input=Lisp_sop.snapshot geometry and sample=Some(Lisp_sop.snapshot(points 2 0.)) in
    with_session(fun session->
      let oracle=native input sample changes in
      List.iter(fun reference->check(close_geometry ~ulps:4
        (cook session 1 97 (node ~reference input sample keywords))
        (cook session 1 97 oracle)) "rest_position ignored reference branch differs") [false;true]))
    [payload base,":mode \"Extract\"",["mode",P.Choice_value "Extract"];
     payload base,":mode \"Swap\"",["mode",P.Choice_value "Swap"];
     wrong "restN",":rest_attribute \" \"",["rest_attribute",P.Text_value " "]];
  print_endline "rest_position draft: exact native errors, precedence and unselected malformed/reference branches pass"

let parameter_edits () =
  let geometry=payload(mixed()) in
  let input=Lisp_sop.snapshot geometry in
  let initial=node ~reference:false input None "" and oracle=native input None [] in
  List.iter(fun(name,value)->
    let edited=fst(N.apply_parameters initial[name,value] |> get_string_ok)
    and expected=fst(N.apply_parameters oracle[name,value] |> get_string_ok) in
    check(N.id edited=N.id initial) "rest_position edit changed logical node id";
    check(N.parameter_key edited=N.parameter_key expected) ("rest_position edited key differs: "^name);
    with_session(fun session->
      ignore(cook session 1 97 initial); let before=Sop.Session.stats session in
      let actual=cook session 1 97 edited in let after=Sop.Session.stats session in
      check(after.misses=before.misses+1) ("rest_position edit must miss once: "^name);
      ignore(cook session 1 97 edited); let warm=Sop.Session.stats session in
      check(warm.misses=after.misses && warm.hits>after.hits) "rest_position warm edit missed";
      check(close_geometry ~ulps:4 actual(cook session 1 97 expected)) "rest_position edited oracle differs"))
    ["mode",P.Choice_value "Swap";"rest_attribute",P.Text_value "stored";
     "normals",P.Choice_value "If present";"normal_attribute",P.Text_value "rest";
     "rest_normal_attribute",P.Text_value "saved normal"];
  List.iter(fun changes->
    let expected=match N.apply_parameters oracle changes with Error message->message|Ok _->fail "native invalid rest edit succeeded" in
    (match N.apply_parameters initial changes with
     |Error message->check(message=expected)("rest_position rejected edit message differs: "^message)
     |Ok _->fail "Lisp invalid rest edit succeeded"))
    [["rest_attribute",P.Text_value "P"];
     ["normals",P.Choice_value "Always";"normal_attribute",P.Text_value " "];
     ["normals",P.Choice_value "If present";"rest_normal_attribute",P.Text_value "P"]];
  List.iter(fun changes->
    match N.apply_parameters initial changes,N.apply_parameters oracle changes with
    |Error actual,Error expected->check(actual=expected) "rest_position field refusal differs"
    |_->fail "rest_position invalid field was accepted")
    [["mode",P.Choice_value "bad"];["normals",P.Choice_value "bad"];
     ["rest_attribute",P.Int_value 1];["normal_attribute",P.Float_value nan]];
  print_endline "rest_position draft: every parameter edit preserves native keys, atomic validation and one public cache miss"

let typed_refusals () =
  let input=Lisp_sop.snapshot(points 1 0.) in
  let input_factory=Sop.Edit_graph.factory ~key:"rest_input" ~label:"Input" ~category:["Test"] ~arity:0 (fun _->input) in
  let native=input_factory::Sop_catalog.Editor.factories in
  let authored=List.filter(fun factory->Sop.Edit_graph.factory_key factory<>"rest_position")native in
  let errors factories sources text =
    let catalog=Flow_sop.Catalog.of_factories ~nodes:[] ~version:Flow_sop.Manifest.version factories |> checked in
    let forms=Flow.Syntax.parse("(workspace refusal (graph g :context sop "^text^"))") |> checked in
    let workspace,diagnostics=Flow_sop.Catalog.check_workspace ~sources ~ops:Flow_sop.Operators.all catalog forms in
    check(workspace=None) "rest_position accepted a wrongly typed input";
    List.filter_map(fun(d:Flow.Diagnostic.t)->if d.severity=Error then Some d.code else None)diagnostics
      |>List.sort_uniq String.compare in
  let native_sources=Flow_sop.Catalog.sources() |> checked in
  List.iter(fun expression->
    let actual=errors authored sources expression and expected=errors native native_sources expression in
    check(actual=expected && List.mem "E_TYPE" actual) "rest_position changed wrong input diagnostic")
    ["(sop/rest_position false)";"(sop/rest_position [1 2 3])";
     "(sop/rest_position (sop/rest_input) false)"];
  print_endline "rest_position draft: wrong positional and optional input types preserve native refusal codes"

let exceptional_storage () =
  let values=[|-0.;0.;Float.infinity;Float.neg_infinity;
    Int64.float_of_bits 0x7ff8000000000123L;max_float;-.max_float|] in
  let planes offset=Packed.Float3.Private.of_owned_exn
    ~x:(Array.init 7(fun i->values.((i+offset)mod 7)))
    ~y:(Array.init 7(fun i->values.((i+offset+2)mod 7)))
    ~z:(Array.init 7(fun i->values.((i+offset+4)mod 7))) in
  let geometry offset=payload(points 7 0.)
    |>Geometry.with_positions(planes offset)|>get_string_ok
    |>add "rest" Attribute.Point(Attribute.Float3(planes(offset+1)))
    |>add "N" Attribute.Point(Attribute.Float3(planes(offset+2)))
    |>add "restN" Attribute.Point(Attribute.Float3(planes(offset+3))) in
  let base=geometry 0 and sample=geometry 1 in
  let input=Lisp_sop.snapshot base and before=geometry_bytes base
  and sample_before=geometry_bytes sample in
  let attr name geometry=Geometry.find_attribute ~owner:Attribute.Point name geometry|>Option.get
    |>Attribute.Private.storage in
  let shares a b=match a,b with Attribute.Float3 a,Attribute.Float3 b->a==b|_->false in
  List.iter(fun mode->List.iter(fun normals->List.iter(fun sample_node->
    let keywords=Printf.sprintf ":mode %S :normals %S" mode normals in
    let expected_node=native input sample_node["mode",P.Choice_value mode;"normals",P.Choice_value normals] in
    with_session(fun session->
      let expected=cook session 1 97 expected_node in
      List.iter(fun reference->let actual_node=node ~reference input sample_node keywords in
        List.iter(fun domains->
          let actual=cook session domains 97 actual_node in
          check(geometry_bytes actual=geometry_bytes expected)
            "rest_position exceptional planes differ from native storage bytes";
          check(Geometry.positions actual==Geometry.positions expected)
            "rest_position copied unchanged position storage";
          List.iter(fun name->check(shares(attr name actual)(attr name expected))
            ("rest_position copied unchanged attribute storage: "^name))["rest";"N";"restN"])
          [1;8]) [false;true])) [None;Some(Lisp_sop.snapshot sample)])
    ["None";"If present";"Always"]) ["Store";"Extract";"Swap"];
  check(before=geometry_bytes base && sample_before=geometry_bytes sample)
    "rest_position exceptional storage transfer mutated an input";
  (* Borrowing only covers unchanged storage. Even an identity numeric map
     evaluates its input and keeps the ordinary nonfinite refusal. *)
  let mapped=Lisp_sop.workspace_node ~with_:["source",input]
    "(workspace checked_map (defnode sop/checked_map [(geo : geometry)] (sop/with_attr geo :mapped (exact (map (fn [p] p) (sop/attr geo :P))))) (graph g :context sop (sop/checked_map (sop/ext_source))))" in
  with_session(fun session->List.iter(fun domains->
    match Sop.Session.cook session ~context:(context domains 97) mapped with
    |Error error->check(error.code="E_NONFINITE") "Mapped exceptional source lost nonfinite refusal"
    |Ok _->fail "Computed numeric map accepted a nonfinite source") [1;8]);
  print_endline "rest_position: native exceptional-plane bytes and shared storage preserved; computed numeric inputs remain checked"

let benchmark () =
  let count=1_000_000 in
  let input=Lisp_sop.snapshot(payload(points count 0.)) in
  List.iter(fun mode->
    let actual=node ~reference:false input None (Printf.sprintf ":mode %S" mode)
    and oracle=native input None ["mode",P.Choice_value mode] in
    List.iter(fun domains->
      let measure node=List.init 3(fun _->with_session(fun session->
        Gc.full_major();let allocated=Gc.allocated_bytes() and started=Unix.gettimeofday() in
        ignore(cook session domains 4096 node);
        Unix.gettimeofday()-.started,Gc.allocated_bytes()-.allocated))
        |> List.sort(fun(a,_)(b,_)->Float.compare a b) |>fun samples->List.nth samples 1 in
      let native_seconds,native_bytes=measure oracle and lisp_seconds,lisp_bytes=measure actual in
      Printf.printf "rest_position mode=%s points=%d domains=%d grain=4096 native_seconds=%.6f lisp_seconds=%.6f ratio=%.3f native_allocated_bytes=%.0f lisp_allocated_bytes=%.0f\n%!"
        mode count domains native_seconds lisp_seconds (lisp_seconds/.native_seconds) native_bytes lisp_bytes)
      [1;4]) ["Store";"Extract";"Swap"]

let profile () =
  let input=Lisp_sop.snapshot(payload(points 1_000_000 0.)) in
  let actual=node ~reference:false input None ":mode \"Swap\"" in
  with_session(fun session->
    let until=Unix.gettimeofday()+.8. and count=ref 0 in
    while Unix.gettimeofday()<until do
      Sop.Session.clear session;
      ignore(cook session 1 4096 actual);
      incr count
    done;
    Printf.printf "Rest Swap wrapper profile: %d cleared-session cooks\n%!" !count)

let () = if Array.exists((=)"--profile")Sys.argv then profile()
  else if Array.exists((=)"--bench")Sys.argv then benchmark()
  else (verify(); errors(); parameter_edits(); typed_refusals(); exceptional_storage())
