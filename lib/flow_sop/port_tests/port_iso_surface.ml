(* sop/iso_surface: its only input is the function slot "field" (fn [vec3] float). The gate wires geometry
   fixtures into slots (its head is "(sop/port_in0)"), so a function-typed slot cannot be fed: with no
   fixture both sides refuse the default cook, and the cache check (which needs a successful default cook)
   fails. The draft is instead compared with native by the PORT_ISO harness in port_iso_check.ml (several
   fields, resolutions, bounds, iso values, smooth on/off). *)
open Port_gate
module P = Param
let f v = P.Float_value v
let cases = [
  "resolution", ["resolution_x", f 5.; "resolution_y", f 4.; "resolution_z", f 3.];
  "bounds", ["min_x", f (-1.); "max_x", f 3.];
  "iso", ["iso", f 0.3];
  "flat", ["smooth", P.Bool_value false] ]
let () = register { key = "iso_surface"; native = Sop.Nodes.Iso_surface.factory; inputs = no_input; cases;
  ulps = 4; bench = None }
