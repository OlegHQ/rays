(* sop/sweep: two inputs (backbone, cross_section) of polyline curves. Fixtures: open and closed backbones and
   profiles of irregular lengths with attributes and groups on every owner (the node carries them under
   a prefix), and backbones carrying the optional frame attributes (pscale, scale, N, up, orient). *)
open Rdk
open Port_gate
open Port_loft_support
module P = Param

let tx name v = name, P.Text_value v
let fl name v = name, P.Float_value v
let bo name v = name, P.Bool_value v
let ch name v = name, P.Choice_value v

let ok = Rdk_test_support.get_string_ok
let add owner name storage geometry =
  Geometry.with_attribute (Attribute.create_owned ~owner ~name storage |> ok) geometry |> ok

let backbone () = decorate (build [sec ~kind:open_k 5 0.; sec ~kind:closed_k 4 1. ~radius:1.5; sec ~kind:open_k 3 2.])
let profile () = decorate (build [sec ~kind:closed_k 4 0. ~radius:0.3; sec ~kind:open_k 3 0. ~radius:0.2])
let small_backbone () = build [sec ~kind:open_k 4 0.]
let small_profile () = build [sec ~kind:closed_k 5 0. ~radius:0.3]
(* An open profile along the three frame axes, scaled so that the sweep positions expose the frame vectors. *)
let axes_profile () =
  let positions = Packed.Float3.of_owned ~x:[|1e6; 0.; 0.|] ~y:[|0.; 1e6; 0.|] ~z:[|0.; 0.; 1e6|] |> ok in
  let topology = Topology.create_owned ~point_count:3 ~vertex_points:[|0;1;2|] ~primitive_offsets:[|0;3|]
    ~primitive_kinds:[|Topology.Open_polyline|] |> ok in
  Geometry.create ~positions ~topology () |> ok

let inputs = [
  "small", [small_backbone (); small_profile ()];

  "axes", [small_backbone (); axes_profile ()];
  "main", [backbone (); profile ()] ]

let cases = []

let () = register { key = "sweep"; native = Sop.Nodes.Sweep.factory; inputs; cases; ulps = 4; bench = None }
