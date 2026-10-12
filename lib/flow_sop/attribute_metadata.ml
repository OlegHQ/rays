let delete ~owner ~pattern input =
  let literal = pattern<>"" && not (String.exists (function
    | '*' | '?' | '[' | '\\' | '^' | ' ' | '\t' | '\n' | '\r' | '\012' -> true
    | _ -> false) pattern) in
  let delete geometry cancel =
    let pattern_for selected = if owner=selected then pattern else "" in
    Rdk.Attribute_ops.delete ~cancel
      ~point_pattern:(pattern_for "point") ~vertex_pattern:(pattern_for "vertex")
      ~primitive_pattern:(pattern_for "primitive") ~detail_pattern:(pattern_for "detail") geometry in
  Sop.Node.Private.make_geometry ~operation:"flow.delete_attr" ~version:1
    ~parameters:(Flow.Lisp.flat (Flow.Syntax.make (Vec [Flow.Syntax.make (Str owner);Flow.Syntax.make (Str pattern)])))
    ~cook_mode:(Sop.Node.Duplicate_input 0) ~dependencies:Sop.Context.Dependencies.static
    ~inputs:[|input|] (fun ~node_id:_ context inputs ->
      match delete inputs.(0) (Sop.Context.cancel_token context) with
      | Ok geometry -> Ok Sop.Node.Private.{geometry;diagnostics=[];instances=None}
      | Error error -> Error (Sop.Diagnostic.error ~code:"E_ATTR_DELETE" (Rdk.Error.to_string error)))
  |> Sop.Node.Private.with_facts Sop.Node.{cook_mode=Duplicate_input 0;elementwise=Points;
      reads=(if literal then [] else ["*"]);writes=(if literal then [pattern] else ["*"]);
      topology=Preserved;exact=true}
