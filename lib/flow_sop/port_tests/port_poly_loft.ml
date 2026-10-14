(* sop/poly_loft: input geometry plus an optional rest guide with the same point count. Fixtures: rings
   and arcs of different counts, wrapped lofts, a single section, normals on either owner. *)
open Rdk
open Port_gate
open Port_loft_support
module P = Param

let mixed_counts = build [sec 5 0.; sec 7 1. ~radius:1.2; sec 4 2. ~radius:0.8; sec 6 3.]
let same_counts = build [sec 6 0.; sec 6 1. ~radius:1.3 ~phase:0.4; sec 6 2.]
let arcs = build [sec ~kind:open_k 4 0.; sec ~kind:open_k 5 1.; sec ~kind:open_k 3 2. ~radius:1.5]
let mixed_kinds = build [sec 5 0.; sec ~kind:open_k 4 1.; sec ~kind:poly_k 6 2. ~radius:0.7; sec 3 3.]
let single = build [sec 5 0.]

let inputs =
  List.map (fun (label, g, rest) ->
    label, decorate g :: Option.to_list (Option.map decorate rest))
  [ "empty", points 0, None; "single point", points 1, None;
    "mixed counts", mixed_counts, None; "same counts", same_counts, None; "arcs", arcs, None;
    "mixed kinds", mixed_kinds, None; "one section", single, None;
    "rest", mixed_counts, Some (shifted mixed_counts);
    "rest same", same_counts, Some (shifted same_counts) ]
  @ [ "point normals", [with_normals Attribute.Point (decorate mixed_counts)];
      "vertex normals", [with_normals Attribute.Vertex (decorate same_counts)];
  ]

let fields ?(group = "") ?(connect = true) ?(minimize = "Two point distance") ?(u = false) ?(v = false)
    ?(keep = false) ?(output = "loft") ?(tolerance = 0.) ?(normals = true) () =
  ["group", P.Text_value group; "connect_closest_ends", P.Bool_value connect;
   "minimize", P.Choice_value minimize; "u_wrap", P.Bool_value u; "v_wrap", P.Bool_value v;
   "keep_primitives", P.Bool_value keep; "output_group", P.Text_value output;
   "collinearity_tolerance", P.Float_value tolerance; "recompute_normals", P.Bool_value normals]

let cases = [
  "no connect", fields ~connect:false ();
  "three point", fields ~minimize:"Three point distance" ();
  "three point open", fields ~minimize:"Three point distance" ~connect:false ();
  "u wrap", fields ~u:true ();
  "v wrap", fields ~v:true ();
  "wrap both", fields ~u:true ~v:true ();
  "keep", fields ~keep:true ();
  "keep no group", fields ~keep:true ~output:"" ();
  "no group name", fields ~output:" " ();
  "named group", fields ~group:"a" ();
  "named group keep", fields ~group:"dest_a" ~keep:true ();
  "missing group", fields ~group:"nothing" ();
  "padded group", fields ~group:" old_x " ~u:true ();
  "unicode group", fields ~group:"\195\169\231\140\171" ();
  "tolerance", fields ~tolerance:0.5 ();
  "tolerance max", fields ~tolerance:1. ();
  "no normals", fields ~normals:false () ]

let bench () =
  let sections = List.init 12_500 (fun i -> sec ~kind:open_k 40 (float i *. 0.01)
    ~radius:(1. +. (0.001 *. float (i mod 7)))) in
  [build sections], fields ()

let () = register { key = "poly_loft"; native = Sop.Nodes.Poly_loft.factory; inputs; cases; ulps = 4;
  bench = Some bench }
