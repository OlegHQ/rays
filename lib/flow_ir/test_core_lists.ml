module E = Flow.Eval
module I = Flow_ir
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let rec same (a : E.value) (b : E.value) = match a,b with
  | Float a,Float b -> Int64.bits_of_float a=Int64.bits_of_float b
  | List a,List b -> Array.length a=Array.length b && Array.for_all2 same a b
  | Record a,Record b -> List.length a=List.length b && List.for_all2 (fun (n,a) (m,b) -> n=m && same a b) a b
  | a,b -> a=b
let cases = Core_fixtures.lists
let check (name,body) =
  let tested=if String.starts_with ~prefix:"captured-" name then body
    else "(if (> t -1000.) " ^ body ^ " " ^ body ^ ")" in
  let source="(workspace w (graph g :context value (let* [tested " ^ tested ^ "] 0.)))" in
  let ws=match Flow.Workspace.check {Flow.Check.version=1;kinds=[]} (ok (Flow.Syntax.parse source)) with
    | Some ws,[] -> ws | _,ds -> failwith (name ^ ": " ^ String.concat "; " (List.map Flow.Diagnostic.to_string ds)) in
  let r=match snd (List.hd (List.assoc ["g";"tested"] (ok (E.static ~record:true ws)).records)) with
    | E.Residual r -> r | _ -> failwith (name ^ ": expected residual") in
  let core=match I.Core_lower.lower r with Ok p -> p | Error n -> failwith (name ^ ": refused " ^ n) in
  assert (Format.asprintf "%a" I.Core.pp core = Format.asprintf "%a" I.Core.pp (Result.get_ok (I.Core_lower.lower r)));
  let program=ok (I.Executor.compile (E.Residual r)) in
  List.iter (fun time ->
    let live=Frame_input.at_time time in
    let expected=E.Private.force_reference (E.Residual r) ~live in
    let verify actual = match actual,expected with
      | Ok actual,Ok expected when same actual expected -> ()
      | Error a,Error b when a.Flow.Diagnostic.code=b.Flow.Diagnostic.code -> ()
      | _ -> let show=function Ok v -> E.show v | Error d -> Flow.Diagnostic.to_string d in
          failwith (Printf.sprintf "%s at %g: %s <> %s" name time (show actual) (show expected)) in
    verify (E.force (E.Residual r) ~live);
    verify (I.Core_exec.run core ~live);
    verify (I.Executor.force program ~live))
    [-3.;-2.5;-0.;0.;0.37;1.;1.9;3.;8.;4096.;4097.]
let () = List.iter check cases;print_endline "Core lists: direct/reference/executor parity passed"

let () =
  let module C=I.Core in
  let source : C.source = {site=["builder"];owner=[];instance=0;prefix=[];iter=[];span=None} in
  let statement id node : C.statement = {id;source;node} in
  let program body : C.program =
    {constants=[|Int 2;Int 0;Int 7;List [|Int 0;Int 0|]|];
     locals=[|Flow.Ty.Int;List Int;Int;Int;List Int;Record ["xs",List Int]|];
     body;results=[|1|];state_slots=[||];regions=[||];call_slots=0} in
  let init=[statement 0 (Assign (0,Constant 0));statement 1 (Assign (1,Prim (Sequence_build,["count",0])));
    statement 2 (Assign (2,Constant 1));statement 3 (Assign (3,Constant 2))] in
  let store=statement 4 (Store {sequence=1;index=2;value=3}) in
  let live=Frame_input.at_time 0. in
  assert (I.Core_exec.run (program (init @ [store])) ~live = Ok (E.List [|Int 7;No_geo|]));
  List.iter (fun body -> match I.Core_exec.run (program body) ~live with
    | Error d -> assert (d.code="E_CORE_OWNERSHIP")
    | Ok _ -> failwith "A published or constant sequence accepted a store")
    [init @ [statement 5 (Assign (4,Local 1));statement 6 (Assign (5,Fields ["xs",4]));store];
     [statement 0 (Assign (1,Constant 3));statement 1 (Assign (2,Constant 1));
      statement 2 (Assign (3,Constant 2));store]];
  print_endline "Core list stores: local builder ownership and alias publication passed"
