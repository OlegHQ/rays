(* sop/promote_attributes: one geometry input. STUB registration for the blocked draft: the defaults on the
   standard fixtures; the full case list (12 methods x 4x4 owner pairs x float/int/text/array attributes,
   piece partition, rename and index patterns) is unwritten. *)
open Port_gate
let () = register { key = "promote_attributes"; native = Sop.Nodes.Promote_attributes.factory;
  inputs = standard_inputs; cases = []; ulps = 4; bench = None }
