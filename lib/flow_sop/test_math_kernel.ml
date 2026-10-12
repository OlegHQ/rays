module E = Flow.Eval
module P = Flow_ir.Packed
let ok = function Ok x -> x | Error d -> failwith (Flow.Diagnostic.to_string d)
let function_value input_ty body =
  let source = Flow.Syntax.parse ("(workspace math (graph result :context value (let* [tested (fn [(x : "
    ^ Flow.Ty.to_string input_ty ^ ")] " ^ body ^ ")] 0.0)))" ) |> ok in
  let workspace = match Flow.Workspace.check Flow.Check.{version=1;kinds=[]} source with
    | Some w,[] -> w | _,ds -> failwith (String.concat "\n" (List.map Flow.Diagnostic.to_string ds)) in
  let evaluation = ok (E.static ~record:true workspace) in
  match snd (List.hd (List.assoc ["result";"tested"] evaluation.records)) with
  | E.Fn f -> f | _ -> assert false
let compile input_ty output_ty input body =
  let fn = function_value input_ty body in
  let value = ok (E.Private.map_function ~signature:Flow.Ty.{params=[input_ty];result=output_ty} fn [input]) in
  match value with
  | E.Residual residual ->
      let term = (E.Private.residual_view residual).term in
      let program = match P.compile_result residual term with Ok p -> p
        | Error ds -> failwith (body ^ "\n" ^ String.concat "\n" (List.map Flow.Diagnostic.to_string ds)) in
      value,program
  | _ -> failwith (body ^ ": live packed value expected")
let bytes = fun value -> Marshal.to_string value [Marshal.No_sharing]
let () =
  let count = 32769 in
  let scalar = E.Float_array (Array.init count (fun i -> if i=0 then -0.
    else sin (float i *. 0.31) *. 0.8)) in
  let vectors = E.Vec3_array (Array.init (count*3) (fun i ->
    if i<3 then -0. else sin (float i *. 0.73) *. Float.ldexp 1. (i mod 40-20))) in
  let cases = List.map (fun body -> Flow.Ty.Float,Flow.Ty.Float,scalar,body)
      ["(tan (+ x t))";"(atan2 x t)";"(asin (* (+ x t) 0.25))";
       "(acos (* (+ x t) 0.25))";"(exp (+ x t))";"(log (+ (+ x t) 4.0))";
       "(sign (+ x t))";"(hypot x t)"]
    @ [Flow.Ty.Vec3,Float,vectors,"(dot x [t 0.3 -0.2])";
       Flow.Ty.Vec3,Vec3,vectors,"(cross x [t 0.3 -0.2])";
       Flow.Ty.Vec3,Vec3,vectors,"(normalize (+ x [t 0.0 0.0]))";
       Flow.Ty.Vec3,Vec3,vectors,"(normalize (+ x [(float (frame/index)) t 0.0]))"] in
  List.iter (fun (input_ty,output_ty,input,body) ->
    let value,program = compile input_ty output_ty input body in
    List.iter (fun time ->
      let live = Frame_input.at_time time in
      let expected = ok (E.Private.force_reference value ~live) |> bytes in
      List.iter (fun domains -> Rays_math.Parallel.run ~domains (fun () ->
        let actual = ok (P.force ~strict:true program ~live) |> bytes in
        if actual<>expected then failwith (Printf.sprintf "%s differs at %g on %d domains" body time domains))) [1;8])
      [-0.;0.;0.37;1.]) cases;
  List.iter (fun (input,body) ->
    let value,program = compile Flow.Ty.Float Flow.Ty.Float input body in
    let live = Frame_input.at_time 0. in
    let expected = ok (E.Private.force_reference value ~live) |> bytes in
    List.iter (fun domains -> Rays_math.Parallel.run ~domains (fun () ->
      assert (bytes (ok (P.force ~strict:true program ~live))=expected))) [1;8])
    [E.Float_array [|1e308;1e-300;Int64.float_of_bits 1L;-0.|],"(hypot x (+ x t))"];
  List.iter (fun body ->
    let value,program = compile Flow.Ty.Float Flow.Ty.Float (E.Float_array [|2.;-2.|]) body in
    let live = Frame_input.at_time 0. in
    let nonfinite = function Error d ->
        if d.Flow.Diagnostic.code<>"E_NONFINITE" then
          failwith (body ^ ": " ^ Flow.Diagnostic.to_string d)
      | Ok _ -> failwith (body ^ ": expected nonfinite error") in
    nonfinite (E.Private.force_reference value ~live);
    nonfinite (P.force ~strict:true program ~live))
    ["(asin (+ x t))";"(acos (+ x t))";"(log (+ x t))";"(exp (+ (* x 1000.0) t))"];
  print_endline "Packed math matches native reference bytes on one/eight domains; invalid domains refuse"
