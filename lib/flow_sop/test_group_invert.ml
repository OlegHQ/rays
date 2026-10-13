open Rdk
open Rdk_test_support
module N=Sop.Node
module P=Param
let checked=function Ok value->value|Error d->fail(Flow.Diagnostic.to_string d)
let sources=(Flow_sop.Catalog.sources() |>checked) @
  (In_channel.with_open_text "nodes/group_invert.pending" In_channel.input_all |>Flow.Syntax.parse |>checked)
let quoted value=Flow.Lisp.flat(Flow.Syntax.make(Str value))
let node ~reference input keywords=
  let factory=Sop.Edit_graph.factory ~key:"invert_input" ~label:"Input" ~category:["Test"] ~arity:0(fun _->input) in
  let factories=factory::List.filter(fun f->Sop.Edit_graph.factory_key f<>"group_invert")Sop_catalog.Editor.factories in
  let catalog=Flow_sop.Catalog.of_factories ~nodes:[] ~version:Flow_sop.Manifest.version factories |>checked in
  let forms=Flow.Syntax.parse("(workspace invert (graph g :context sop (sop/group_invert (sop/invert_input) "^keywords^")))") |>checked in
  let workspace=match Flow_sop.Catalog.check_workspace ~sources ~ops:Flow_sop.Operators.all catalog forms with
    |Some w,ds when not(List.exists(fun(d:Flow.Diagnostic.t)->d.severity=Error)ds)->w
    |_,ds->fail(String.concat "\n"(List.map Flow.Diagnostic.to_string ds)) in
  let lowered=match Flow_sop.Lower.of_checked ~reference ~factories workspace with
    |Ok lowered->lowered
    |Error d->fail("Group Invert lowering "^keywords^": "^Flow.Diagnostic.to_string d^
      Option.fold ~none:"" ~some:(fun cause->" ("^cause^")")d.cause) in
  let graph=List.hd lowered.graphs in
  Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root) |>get_string_ok
let native input changes=
  fst(N.apply_parameters(Sop.Edit_graph.instantiate Sop.Nodes.Group_invert.factory[input] |>get_string_ok)changes |>get_string_ok)
let with_session f=
  let session=Sop.Session.create ~max_entries:64 ~max_payload_bytes:256_000_000 |>get_string_ok in
  Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->f session)
let result session domains grain node=
  let context=Sop.Context.create ~domains ~grain() |>get_string_ok in
  Result.map(fun output->Sop.Payload.geometry output.Sop.Session.payload |>Result.get_ok)(Sop.Session.cook session ~context node)
let cook session domains grain node=match result session domains grain node with
  |Ok geometry->geometry|Error d->fail(Sop.Diagnostic.error_to_string d)
let points count=Kernel.generate_point_ranges count(fun ~first ~last ~x ~y ~z->
  for i=first to last-1 do x.(i)<-float i*.0.125;y.(i)<- -0.;z.(i)<-0.25 done)
let mixed()=
  let topology=Topology.create_owned ~point_count:6 ~vertex_points:[|0;1;2;3;1;4;5|]
    ~primitive_offsets:[|0;4;7|] ~primitive_kinds:[|Topology.Polygon;Open_polyline|] |>get_string_ok in
  Geometry.create ~positions:(Geometry.positions(points 6)) ~topology() |>get_string_ok
let grouped geometry=
  let put owner name phase geometry=
    let count=match owner with Group.Point->Geometry.point_count geometry|Vertex->Geometry.vertex_count geometry|Primitive->Geometry.primitive_count geometry in
    let indices=Array.init count Fun.id |>Array.to_list |>List.filter(fun i->i mod 3=phase) |>List.rev |>Array.of_list in
    Geometry.with_group(Group.ordered ~owner ~name ~length:count indices |>get_string_ok)geometry |>get_string_ok in
  let geometry=List.fold_left(fun g(name,phase)->g |>put Group.Vertex name phase |>put Group.Point name phase |>put Group.Primitive name phase)
    geometry["a",0;"dest_a",1;"old_x",2;"literal *?[]^\\",0;"é猫",1] in
  let topology=Geometry.topology geometry in
  let index=Topology_index.create topology in
  let geometry=List.fold_left(fun g(name,phase)->Geometry.with_edge_group
    (Edge_group.init ~topology ~index ~name(fun i->i mod 3=phase))g |>get_string_ok)
    geometry["a",0;"dest_a",1;"old_x",2;"literal *?[]^\\",0;"é猫",1] in
  Geometry.with_attribute(Attribute.create_owned ~owner:Attribute.Detail ~name:"untouched"(Attribute.Text[|"UTF8 ✓"|]) |>get_string_ok)geometry |>get_string_ok
let preserved_attributes geometry=
  List.fold_left(fun geometry owner->
    let n=match owner with Attribute.Point->Geometry.point_count geometry|Vertex->Geometry.vertex_count geometry
      |Primitive->Geometry.primitive_count geometry|Detail->1 in
    let values=Array.init n(fun i->if i mod 2=0 then -0. else float i*.0.125)
    and integers=Array.init n(fun i->if i mod 2=0 then max_int else min_int) in
    List.fold_left(fun geometry(name,storage)->Geometry.with_attribute
      (Attribute.create_owned ~owner ~name storage |>get_string_ok)geometry |>get_string_ok)geometry
      ["float",Attribute.Float values;"integer",Int integers;"text",Text(Array.make n "é猫\000😀");
       "vec2",Float2(Packed.Float2.of_owned ~x:(Array.copy values) ~y:(Array.copy values)|>get_string_ok);
       "vec3",Float3(Packed.Float3.of_owned ~x:(Array.copy values) ~y:(Array.copy values) ~z:(Array.copy values)|>get_string_ok);
       "vec4",Float4(Packed.Float4.of_owned ~x:(Array.copy values) ~y:(Array.copy values) ~z:(Array.copy values) ~w:(Array.copy values)|>get_string_ok);
       "float_rows",Float_array(Packed.Float_array.create_owned ~offsets:(Array.init(n+1)Fun.id) ~values:(Array.copy values)|>get_string_ok);
       "int_rows",Int_array(Packed.Int_array.create_owned ~offsets:(Array.init(n+1)Fun.id) ~values:(Array.copy integers)|>get_string_ok)])
    geometry [Attribute.Point;Vertex;Primitive;Detail]
let fields owner pattern new_name conflict=
  ["owner",P.Choice_value owner;"pattern",P.Text_value pattern;"new_name",P.Text_value new_name;"conflict",P.Choice_value conflict]
let keywords owner pattern new_name conflict=Printf.sprintf ":owner %s :pattern %s :new_name %s :conflict %s"
  (quoted owner)(quoted pattern)(quoted new_name)(quoted conflict)
let cases=
  List.concat_map(fun owner->List.map(fun conflict->owner,"*","dest_*",conflict)
    ["Skip";"Error";"Overwrite";"Union"])["Any";"Points";"Vertices";"Primitives";"Edges"]
  @List.map(fun(pattern,new_name)->"Any",pattern,new_name,"Overwrite")
    ["*","";"unmatched","";"a dest_a","";"* ^old*","";"^old* a","";
     "literal\\ \\*\\?\\[\\]\\^\\\\","";"é*","猫*";"old_?","new_?";
     "[ad]*","*[ad]";"a","a";"a"," renamed ";"a","\\ ";"a","";
     "a dest_a","x";"* ^old*","*";"[","";"\\","";"","";" \t\n","";
     "unmatched","[";"unmatched","*";"old_?","new_*"]
let verify()=
  let grid=Plane_generators.grid ~connectivity:Grid_quads ~columns:64 ~rows:64 ~size:8.() |>get_ok in
  check(Geometry.point_count grid=4225)"Group Invert needs the real 4225-point grid";
  List.iter(fun geometry->let before=geometry_bytes geometry and input=Lisp_sop.snapshot geometry in
    List.iter(fun(owner,pattern,new_name,conflict)->
      let text=keywords owner pattern new_name conflict in
      let actual=node ~reference:false input text and walked=node ~reference:true input text
      and oracle=native input(fields owner pattern new_name conflict) in
      check(N.operation actual=N.operation oracle && N.version actual=N.version oracle)"Group Invert operation/version";
      check(N.label actual=N.label oracle && N.parameter_fields actual=N.parameter_fields oracle)"Group Invert label/fields";
      check(N.parameter_key actual=N.parameter_key oracle)"Group Invert parameter key";
      with_session(fun session->match result session 1 97 oracle,result session 1 97 actual with
        |Error expected,Error got->
            check(expected.code=got.code && expected.message=got.message && expected.cause=got.cause)("Group Invert error "^text);
            List.iter(fun domains->List.iter(fun grain->match result session domains grain actual with
              |Error got->check(got.code=expected.code && got.message=expected.message && got.cause=expected.cause)"Group Invert parallel error"
              |Ok _->fail"Group Invert invalid parallel success") [1;97;4096]) [1;4;8]
        |Ok expected,Ok got->
            check(close_geometry ~ulps:4 expected got)("Group Invert native "^text);
            check(geometry_bytes got=geometry_bytes(cook session 1 97 walked))"Group Invert reference bytes";
            List.iter(fun domains->List.iter(fun grain->Sop.Session.clear session;
              check(geometry_bytes got=geometry_bytes(cook session domains grain actual))"Group Invert domain/grain bytes") [1;97;4096]) [1;4;8]
        |Error d,Ok _->fail("Group Invert accepted native error "^Sop.Diagnostic.error_to_string d)
        |Ok _,Error d->fail("Group Invert refused native success "^Sop.Diagnostic.error_to_string d))) cases;
    check(before=geometry_bytes geometry)"Group Invert mutated input")
    [grouped(points 0);grouped(points 1);preserved_attributes(grouped(mixed()));grouped grid;grouped(points 32769);mixed()];
  print_endline"Group Invert draft: all owners/conflicts, snapshot ordering, exact causes, native/reference, real grid and domain/grain bytes"
let edits()=
  let geometry=grouped(mixed()) and input=Lisp_sop.snapshot(grouped(mixed())) in
  let initial=node ~reference:false input "" and oracle=native input[] in
  List.iter(fun(name,value)->let actual=fst(N.apply_parameters initial[name,value] |>get_string_ok)
    and expected=fst(N.apply_parameters oracle[name,value] |>get_string_ok) in
    check(N.id actual=N.id initial && N.parameter_key actual=N.parameter_key expected)("Group Invert edit key "^name);
    with_session(fun session->ignore(cook session 1 97 initial);let before=Sop.Session.stats session in
      let output=cook session 1 97 actual in let after=Sop.Session.stats session in
      check(after.misses=before.misses+1)("Group Invert public miss "^name);
      ignore(cook session 1 97 actual);let warm=Sop.Session.stats session in
      check(warm.misses=after.misses && warm.hits>after.hits)"Group Invert warm hit";
      check(close_geometry ~ulps:4 output(cook session 1 97 expected))"Group Invert edited native"))
    ["owner",P.Choice_value"Edges";"pattern",P.Text_value"a";"new_name",P.Text_value"new_*";"conflict",P.Choice_value"Union"];
  List.iter(fun changes->check(N.apply_parameters initial changes=N.apply_parameters oracle changes)"Group Invert invalid choice diagnostic")
    [["owner",P.Choice_value"Detail"];["conflict",P.Choice_value"Other"];
     ["pattern",P.Float_value nan];["new_name",P.Bool_value true]];
  with_session(fun session->let node=node ~reference:false(Lisp_sop.snapshot geometry)(keywords"Any""missing""""Overwrite") in
    check(cook session 1 97 node==geometry)"Group Invert no-match physical identity")
let projection()=
  let module S=Flow.Syntax in
  let module Projection=Flow_graph.Projection in
  let module Edit=Flow_graph.Flow_edit in
  let input=Lisp_sop.snapshot(grouped(mixed())) in
  let factory=Sop.Edit_graph.factory ~key:"invert_input" ~label:"Input" ~category:["Test"] ~arity:0(fun _->input) in
  let factories=factory::List.filter(fun factory->Sop.Edit_graph.factory_key factory<>"group_invert")Sop_catalog.Editor.factories in
  let catalog factories=Flow_sop.Catalog.of_factories ~nodes:[] ~version:Flow_sop.Manifest.version factories |>checked in
  let base=catalog factories and native_catalog=catalog(Sop.Nodes.Group_invert.factory::factories) in
  let checker=Flow_sop.Catalog.check_workspace ~sources ~ops:Flow_sop.Operators.all in
  let workspace=function Some w,ds when not(List.exists(fun(d:Flow.Diagnostic.t)->d.severity=Error)ds)->w
    |_,ds->fail(String.concat "\n"(List.map Flow.Diagnostic.to_string ds)) in
  let forms=S.parse {|(workspace invert (graph g :context sop
    (let* [src (sop/invert_input) card (sop/group_invert src :owner "Any" :pattern "*" :new_name "" :conflict "Overwrite")] card)))|} |>checked in
  let actual=workspace(checker base forms) and expected=workspace(Flow.Workspace.check ~ops:Flow_sop.Operators.all native_catalog forms) in
  List.iter(fun value->
    let forms=S.parse("(workspace wrong_input (graph g :context sop (sop/group_invert "^value^")))") |>checked in
    let codes(_,ds)=List.filter_map(fun(d:Flow.Diagnostic.t)->if d.severity=Error then Some d.code else None)ds in
    let actual=codes(checker base forms) and expected=codes(Flow.Workspace.check ~ops:Flow_sop.Operators.all native_catalog forms) in
    check(actual<>[] && actual=expected)"Group Invert wrong input code") ["1";"true";"\"geometry\""];
  let card catalog workspace=Option.get(Projection.find(Projection.of_graph catalog workspace "g")["g";"card"]) in
  let normalize(card:Projection.node)={card with rows=List.map(fun(row:Projection.row)->
    {row with expr=Option.map(fun expr->List.hd(S.parse(Flow.Lisp.flat expr)|>checked))row.expr})card.rows} in
  let actual_card=card base actual and expected_card=card native_catalog expected in
  check(normalize actual_card=normalize expected_card)"Group Invert native card metadata";
  check(Projection.lines Full(normalize actual_card)=Projection.lines Full(normalize expected_card))"Group Invert inspector metadata";
  let root workspace=let lowered=Flow_sop.Lower.of_checked ~factories workspace |>checked in
    let graph=List.hd lowered.graphs in
    Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root) |>get_string_ok in
  List.iter(fun(name,value,parameter)->let _,changed=Edit.apply_checked ~checker base forms
    (Set_arg{node=actual_card.path;key=Kw name;sub=[];value=S.make(Str value)}) |>checked in
    let actual=root changed and expected=native input[name,parameter] in
    check(N.parameter_key actual=N.parameter_key expected)("Group Invert gesture key "^name);
    with_session(fun session->check(close_geometry ~ulps:4(cook session 1 97 actual)(cook session 1 97 expected))
      ("Group Invert gesture cook "^name)))
    ["owner","Edges",P.Choice_value"Edges";"pattern","a",P.Text_value"a";
     "new_name","new_*",P.Text_value"new_*";"conflict","Union",P.Choice_value"Union"];
  let _,bypassed=Edit.apply_checked ~checker base forms(Toggle_bypass{node=actual_card.path}) |>checked in
  check((card base bypassed).bypass)"Group Invert bypass gesture"
let benchmark()=
  let geometry=Geometry.with_group(Group.init ~owner:Group.Point ~name:"selected" 1_000_000(fun i->i mod 2=0))(points 1_000_000) |>get_string_ok in
  let input=Lisp_sop.snapshot geometry in
  let actual=node ~reference:false input(keywords"Points""*""""Overwrite") and oracle=native input(fields"Points""*""""Overwrite") in
  let median samples=List.sort(fun(a,_)(b,_)->Float.compare a b)samples |>fun xs->List.nth xs 1 in
  List.iter(fun domains->
    with_session(fun session->check(geometry_bytes(cook session domains 4096 actual)=
      geometry_bytes(cook session domains 4096 oracle))"Group Invert benchmark oracle bytes");
    let sample node=List.init 3(fun _->with_session(fun session->
    Gc.full_major();let allocated=Gc.allocated_bytes() and start=Unix.gettimeofday() in
    ignore(cook session domains 4096 node);Unix.gettimeofday()-.start,Gc.allocated_bytes()-.allocated)) |>median in
    let native_time,native_bytes=sample oracle and time,bytes=sample actual in
    Printf.printf"Group Invert points=1000000 domains=%d grain=4096 native=%.6f lisp=%.6f ratio=%.3f native_bytes=%.0f lisp_bytes=%.0f\n%!"
      domains native_time time(time/.native_time)native_bytes bytes)[1;4]
(* Test-only ordinary-record transport, not a new group API. Word blocks end
   on byte boundaries, so pooled writers never share a destination byte. *)
module Word_prototype = struct
  module E=Flow.Eval
  module Packed=Flow_ir.Packed
  let mask width=if width=63 then -1 else (1 lsl width)-1
  let pack width length bits=
    let count=(length+width-1)/width in
    let words=Rays_math.Parallel.init_array ~grain:4096 count(fun index->
      let first=index*width in
      let byte=first lsr 3 and shift=first land 7 in
      let chunk=
        if byte+8<=Bytes.length bits then Bytes.get_int64_le bits byte
        else begin
          let value=ref 0L in
          for j=0 to min 7 (Bytes.length bits-byte-1) do
            value:=Int64.logor !value(Int64.shift_left(Int64.of_int(Char.code(Bytes.get bits(byte+j))))(8*j))
          done;!value
        end in
      let word=Int64.to_int(Int64.shift_right_logical chunk shift) in
      let word=if shift+width>64 && byte+8<Bytes.length bits then
        word lor (Char.code(Bytes.get bits(byte+8)) lsl (64-shift)) else word in
      word land mask(min width(length-first))) in
    E.Record["length",E.Int length;"words",E.Int_array words]
  let components=function
    |E.Record fields->(match List.assoc "length" fields,List.assoc "words" fields with
      |E.Int length,E.Int_array words when length>=0->length,words
      |_->fail"membership record types")
    |_->fail"membership record required"
  let unpack width record=
    let length,words=components record in
    check(Array.length words=(length+width-1)/width)"membership word cardinality";
    (* Every signed63 Int is a valid full word; only its final partial tile
       can contain padding. Positive tiles also validate full-word high bits. *)
    if width<>63 then Array.iter(fun word->check(word land lnot(mask width)=0)
      "membership word padding")words;
    if Array.length words>0 then begin
      let last=Array.length words-1 in
      check(words.(last) land lnot(mask(length-last*width))=0)"membership tail padding"
    end;
    let bits=Bytes.make((length+7)/8)'\000' in
    let count=Array.length words and block_words=4096 in
    Rays_math.Parallel.for_ ~chunk_size:1 ~start:0 ~finish:((count-1)/block_words)
      (fun block->
        let first=block*block_words and last=min count((block+1)*block_words) in
        let block_end=min(Bytes.length bits)((last*width+7)/8) in
        for index=first to last-1 do
          let offset=index*width in
          let byte=offset lsr 3 and shift=offset land 7 in
          let word=Int64.logand(Int64.of_int words.(index))0x7fffffffffffffffL in
          let chunk=Int64.logor(Int64.shift_left word shift)
            (Int64.of_int(Char.code(Bytes.get bits byte))) in
          if byte+8<=block_end then Bytes.set_int64_le bits byte chunk
          else for j=0 to min 7(block_end-byte-1) do
            Bytes.set bits(byte+j)(Char.chr(Int64.to_int(Int64.shift_right_logical chunk(8*j))land 255))
          done;
          if shift+width>64 && byte+8<block_end then
            Bytes.set bits(byte+8)(Char.chr(Int64.to_int(Int64.shift_right_logical word(64-shift))))
        done);
    bits
  let function_value width last tail=
    let forms=Flow.Syntax.parse(Printf.sprintf
      "(workspace words (graph g :context host (let* [f (fn [(word : int) (index : int)] (int/and (int/xor word %d) (if (int/eq index %d) %d %d)))] 0.0)))"
      (mask width)last tail(mask width))|>checked in
    let workspace=match Flow.Workspace.check Flow.Check.{version=1;kinds=[]} forms with
      |Some w,[]->w|_,ds->fail(String.concat"\n"(List.map Flow.Diagnostic.to_string ds)) in
    match snd(List.hd(List.assoc["g";"f"](E.static ~record:true workspace|>checked).records)) with
      |E.Fn fn->fn|_->assert false
  let compiler width length=
    let count=(length+width-1)/width in
    let tail=if count=0 then 0 else mask(length-(count-1)*width) in
    let fn=function_value width(count-1)tail in
    let source=E.Int_array(Array.make count 0) in
    let indices=E.Int_array(Array.init count Fun.id) in
    let mapped=E.Private.map_function ~signature:Flow.Ty.{params=[Int;Int];result=Int}
      fn[source;indices]|>checked in
    let residual=match mapped with E.Residual residual->residual|_->assert false in
    let term=(E.Private.residual_view residual).term in
    let program=match Packed.compile_template residual term with
      |Some program->program|None->fail"word kernel template qualification" in
    fun record->
      let length,words=components record in
      let residual=E.Private.with_bindings residual ~term
        ["$kernel-input:0",E.Int_array words;
         "$kernel-input:1",E.Int_array(Array.init(Array.length words)Fun.id)] in
      let program=match Packed.rebind program residual with Some program->program|None->fail"word kernel rebind" in
      let value=Packed.force ~strict:true program ~live:(Frame_input.at_time 0.)|>checked in
      E.Record["length",E.Int length;"words",value]
  let check_case width length=
    let members=Array.init length Fun.id |>Array.to_list |>List.filter(fun i->i mod 3=1) |>List.rev |>Array.of_list in
    let group=Group.ordered ~owner:Group.Point ~name:"words" ~length members |>get_string_ok in
    let bits=Group.Private.bits_view group and invert=compiler width length in
    let packed=pack width length bits in
    check(unpack width packed=bits)"word roundtrip bytes";
    let expected=Group.complement group in
    let run domains=Rays_math.Parallel.run ~domains(fun()->unpack width(invert packed)) in
    check(run 1=Group.Private.bits_view expected)"word Lisp/native complement bytes";
    check(run 4=run 1)"word complement domain bytes";
    let rebuilt=Group.Private.of_owned_bits ~owner:Group.Point ~name:"words" ~length(run 1) in
    check(not(Group.is_ordered rebuilt))"complement drops explicit order";
    if length>0 then begin
      let bad=E.Record["length",E.Int length;"words",E.Int_array[||]] in
      check((try ignore(unpack width bad);false with _->true))"word count refusal";
      if length mod width<>0 then begin
        let _,words=components packed in
        let words=Array.copy words in
        words.(Array.length words-1)<-words.(Array.length words-1) lor (1 lsl (length mod width));
        check((try ignore(unpack width(E.Record["length",E.Int length;"words",E.Int_array words]));false with _->true))"word padding refusal"
      end
    end
  let check_edge width=
    let geometry=mixed() in
    let topology=Geometry.topology geometry in
    let index=Topology_index.create topology in
    let edge=Edge_group.init ~topology ~index ~name:"edges"(fun i->i mod 2=0) in
    let length=Edge_group.length edge in
    (* Edge currently exposes membership queries rather than a borrowed bit
       view. A production word reader needs that narrow read-only view; the
       small topology proof uses the existing query without a new API. *)
    let group=Group.init ~owner:Group.Point ~name:"edge_bits" length(fun i->Edge_group.mem i edge) in
    let record=compiler width length(pack width length(Group.Private.bits_view group)) in
    let result=Edge_group.Private.of_owned_bits ~topology ~edge_count:length ~name:"edges"(unpack width record) in
    let expected=Edge_group.complement edge in
    check(Edge_group.topology_data_id result=Edge_group.topology_data_id expected)"word edge topology affinity";
    for i=0 to length-1 do check(Edge_group.mem i result=Edge_group.mem i expected)"word edge complement" done
  let benchmark()=
    List.iter(fun width->List.iter(check_case width)[0;1;7;8;55;56;61;62;63;64;65;127;4095;4096;4097;32769];check_edge width) [56;62;63];
    let length=1_000_000 in
    let group=Group.init ~owner:Group.Point ~name:"words" length(fun i->i mod 2=0) in
    let bits=Group.Private.bits_view group in
    let geometry=Geometry.with_group group(points length)|>get_string_ok in
    let measure label run=
      let samples=Array.init 7(fun _->Gc.full_major();
        let allocated=Gc.allocated_bytes() and started=Unix.gettimeofday() in
        ignore(Sys.opaque_identity(run()));Unix.gettimeofday()-.started,Gc.allocated_bytes()-.allocated) in
      Array.iteri(fun i(seconds,allocated)->Printf.printf"word_sample %s sample=%d seconds=%.9f allocated=%.0f\n%!"label i seconds allocated)samples;
      Array.sort(fun(a,_)(b,_)->Float.compare a b)samples;samples.(3) in
    List.iter(fun domains->Rays_math.Parallel.run ~domains(fun()->
      let native_seconds,_=measure(Printf.sprintf"native d%d"domains)(fun()->Group.complement group) in
      let native_whole()=Group_ops.invert ~owner:Group_ops.Group_points ~pattern:"*" geometry|>get_ok in
      let whole_seconds,_=measure(Printf.sprintf"native whole d%d"domains)native_whole in
      List.iter(fun width->
        let invert=compiler width length and packed=pack width length bits in
        let inverted=invert packed in
        let prefix=Printf.sprintf"width%d d%d"width domains in
        let pack_seconds,pack_bytes=measure(prefix^" pack")(fun()->pack width length bits)
        and map_seconds,map_bytes=measure(prefix^" map")(fun()->invert packed)
        and unpack_seconds,unpack_bytes=measure(prefix^" unpack")(fun()->unpack width inverted) in
        let run()=let record=invert(pack width length bits) in
          Group.Private.of_owned_bits ~owner:Group.Point ~name:"words" ~length(unpack width record) in
        check(Group.Private.bits_view(run())=Group.Private.bits_view(Group.complement group))"million word/native bytes";
        let seconds,allocated=measure(prefix^" total")run in
        let whole()=Geometry.with_group(run())geometry|>get_string_ok in
        check(geometry_bytes(whole())=geometry_bytes(native_whole()))"million word whole geometry bytes";
        let word_whole,whole_bytes=measure(prefix^" whole")whole in
        Printf.printf"word_median length=%d domains=%d width=%d words=%d native=%.9f pack=%.9f map=%.9f unpack=%.9f total=%.9f ratio=%.3f pack_bytes=%.0f map_bytes=%.0f unpack_bytes=%.0f total_bytes=%.0f native_whole=%.9f word_whole=%.9f whole_ratio=%.3f whole_bytes=%.0f\n%!"
          length domains width ((length+width-1)/width)native_seconds pack_seconds map_seconds unpack_seconds seconds(seconds/.native_seconds)
          pack_bytes map_bytes unpack_bytes allocated whole_seconds word_whole(word_whole/.whole_seconds)whole_bytes)[56;62;63]))[1;4]
end
let ()=if Array.exists((=)"--bench-words")Sys.argv then Word_prototype.benchmark()
  else if Array.exists((=)"--bench")Sys.argv then benchmark()
  else if Array.exists((=)"--integration")Sys.argv then(edits();projection())
  else(verify();edits();projection())
