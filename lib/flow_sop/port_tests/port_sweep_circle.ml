(* sop/sweep_circle: the same node as sop/polywire (both run Rdk.Sweep_circle.run), so it shares the fixtures
   and cases of port_polywire.ml. *)
let node = Port_polywire.make "sweep_circle" Sop.Nodes.Sweep_circle.factory
let () = Port_gate.register node
let () = Port_polywire.run_extra_for "sweep_circle" node
