let of_sop (error:Sop.Diagnostic.error) =
  let trace=List.map(fun(frame:Sop.Diagnostic.trace)->Flow.Diagnostic.{
    node_id=frame.node_id;label=frame.label;operation=frame.operation})error.trace in
  Flow.Diagnostic.error ?cause:error.cause ~hints:error.hints ~trace ~code:error.code error.message
let to_sop (error:Flow.Diagnostic.t) =
  let trace=List.map(fun(frame:Flow.Diagnostic.trace)->Sop.Diagnostic.{
    node_id=frame.node_id;label=frame.label;operation=frame.operation})error.trace in
  { (Sop.Diagnostic.error ?cause:error.cause ~hints:error.hints ~code:error.code error.message) with trace }
