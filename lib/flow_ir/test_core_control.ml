module E = Flow.Eval
module I = Flow_ir
module C = I.Core
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let offset = Core_fixtures.offset
let checked source = match Flow.Workspace.check ~ops:[offset] {Flow.Check.version=1;kinds=[]} (ok (Flow.Syntax.parse source)) with
  | Some ws,[] -> ws | _,ds -> failwith (String.concat "; " (List.map Flow.Diagnostic.to_string ds))
let workspace = Core_fixtures.workspace
let residual source = match snd (List.hd (List.assoc ["g";"tested"] (ok (E.static ~record:true (checked source))).records)) with
  | E.Residual r -> r | _ -> failwith ("Expected a residual: " ^ source)
let lower r = match I.Core_lower.lower r with Ok p -> p | Error name -> failwith ("Core refused " ^ name)
let bits x y = Int64.bits_of_float x=Int64.bits_of_float y
let rec same (a : E.value) (b : E.value) = match a,b with
  | Float x,Float y -> bits x y
  | Vec2 (a,b),Vec2 (x,y) -> bits a x && bits b y
  | Vec3 (a,b,c),Vec3 (x,y,z) -> bits a x && bits b y && bits c z
  | Vec4 (a,b,c,d),Vec4 (x,y,z,w) -> bits a x && bits b y && bits c z && bits d w
  | List a,List b -> Array.length a=Array.length b && Array.for_all2 same a b
  | Record a,Record b -> List.length a=List.length b && List.for_all2 (fun (n,a) (m,b) -> n=m && same a b) a b
  | a,b -> a=b
let cases = Core_fixtures.control
let dump () =
  String.concat "" (List.map (fun (name,source) ->
    let r=residual source in let core=lower r in
    let printed=Format.asprintf "%a" C.pp core in
    assert (printed=Format.asprintf "%a" C.pp (lower r));
    List.iter (fun time ->
      let live=Frame_input.at_time time in
      let expected=E.Private.force_reference (E.Residual r) ~live in
      match I.Core_exec.run core ~live,expected with
      | Ok actual,Ok expected ->
          if name="bypass" || name="bypass-keyword" then assert (same actual (E.Float time));
          if not (same actual expected) then failwith (name ^ ": value mismatch")
      | Error actual,Error expected -> assert (actual.code=expected.code)
      | _ -> failwith (name ^ ": result mismatch")) [-3.;-2.5;0.;0.37;1.;1.9;100.25];
    name ^ "\n" ^ printed) cases)
let () =
  let actual=dump () in
  if Array.length Sys.argv=2 && Sys.argv.(1)="--print" then print_string actual
  else begin
    let expected=In_channel.with_open_bin "core_control.expected" In_channel.input_all in
    if expected<>actual then failwith ("Core control print changed:\n" ^ actual)
  end;
  let r=residual (workspace "(if (> t -100.) (let* [f (fn [x] (+ x 1.)) n (if (> t 0.) (f t) 0.)] (+ n (f t))) t)") in
  let core=lower r in
  let rec last_call last statements = List.fold_left (fun last (s : C.statement) -> match s.node with
    | Assign (n,Call_index _) -> Some n
    | If {yes;no;_} -> last_call (last_call last yes) no
    | _ -> last) last statements in
  let index=Option.get (last_call None core.body) in
  let counts={core with C.results=[|index|]} in
  List.iter (fun (time,count) ->
    let live=Frame_input.at_time time in
    assert (ok (I.Core_exec.run counts ~live) = E.Int count);
    assert (ok (I.Core_exec.run counts ~live) = E.Int count)) [1.,1; -1.,0];
  if Array.length Sys.argv=1 then
    print_endline "Core control: direct vector/branch/pattern/call/macro/bypass parity and dynamic call identity passed"

let () =
  List.iter (fun body ->
    let r=residual (workspace body) in
    let core=lower r in
    let program=ok (I.Executor.compile (E.Residual r)) in
    List.iter (fun time ->
      let live=Frame_input.at_time time in
      assert (ok (I.Executor.force program ~live) = E.Float time);
      assert (ok (I.Core_exec.run core ~live) = E.Float time)) [0.;0.37;2.])
    ["^:bypass (+ t 5.)";"^:bypass (+ t (exp 10000.))";
     "^:bypass (test/offset :offset (exp 10000.) t)"]
