(* sop/carve: one geometry input of open and closed polyline curves with irregular lengths, two primitive
   float attributes (u0 < u1) for the attribute parameters, and a polygon-free default. Cases cover every
   mode of Curve_ops.carve_curves: inside, outside, both, divisions, breakpoints (open and all internal),
   extraction (interpolated and breakpoints), keep original, relative or index parameters, attribute modes. *)
open Rdk
open Port_gate
open Port_loft_support
module P = Param

let with_parameters geometry =
  let n = Geometry.primitive_count geometry in
  let add name f g = Geometry.with_attribute (Attribute.create_owned ~owner:Attribute.Primitive ~name
    (Attribute.Float (Array.init n f)) |> Rdk_test_support.get_string_ok) g |> Rdk_test_support.get_string_ok in
  geometry |> add "u0" (fun i -> 0.1 +. (0.05 *. float i)) |> add "u1" (fun i -> 0.6 +. (0.07 *. float i))

let curves = with_parameters (decorate (build
  [sec ~kind:open_k 5 0.; sec 6 1. ~radius:1.3; sec ~kind:open_k 4 2. ~radius:0.7; sec 7 3. ~phase:0.5;
   sec ~kind:open_k 9 4.]))
let single_open = with_parameters (build [sec ~kind:open_k 6 0.])
let single_closed = with_parameters (build [sec 5 0.])

let inputs =
  List.map (fun (label, g) -> label, [g]) [
    "empty", points 0; "curves", curves; "single open", single_open; "single closed", single_closed ]

let fields ?(group = "") ?(relative = true) ?(first = 0.) ?(last = 1.) ?(first_attribute = "")
    ?(last_attribute = "") ?(mode = "Replace") ?(breakpoints = false) ?(internal = false)
    ?(keep = "Inside") ?(extract = false) ?(divisions = 1) ?(original = false) () =
  ["group", P.Text_value group; "relative_arc_length", P.Bool_value relative; "first", P.Float_value first;
   "last", P.Float_value last; "first_attribute", P.Text_value first_attribute;
   "last_attribute", P.Text_value last_attribute; "attribute_mode", P.Choice_value mode;
   "only_at_breakpoints", P.Bool_value breakpoints; "cut_at_all_internal_breakpoints", P.Bool_value internal;
   "keep", P.Choice_value keep; "extract_points", P.Bool_value extract; "divisions", P.Int_value divisions;
   "keep_original", P.Bool_value original]

let cases = [
  "inside", fields ~first:0.2 ~last:0.7 ();
  "inside index", fields ~first:0.2 ~last:0.7 ~relative:false ();
  "outside", fields ~first:0.2 ~last:0.7 ~keep:"Outside" ();
  "both", fields ~first:0.2 ~last:0.7 ~keep:"Inside and outside" ();
  "both full", fields ~keep:"Inside and outside" ();
  "divisions", fields ~first:0.1 ~last:0.9 ~divisions:3 ();
  "divisions outside", fields ~first:0.3 ~last:0.6 ~divisions:2 ~keep:"Outside" ();
  "group", fields ~group:"a" ~first:0.25 ~last:0.5 ();
  "group missing", fields ~group:"nothing" ~first:0.25 ~last:0.5 ();
  "attributes replace", fields ~first_attribute:"u0" ~last_attribute:"u1" ();
  "attributes scale", fields ~first:0.5 ~last:0.9 ~first_attribute:"u0" ~last_attribute:"u1" ~mode:"Scale" ();
  "first attribute", fields ~first_attribute:"u0" ();
  "breakpoints", fields ~first:0.2 ~last:0.7 ~breakpoints:true ();
  "breakpoints internal", fields ~first:0.2 ~last:0.7 ~breakpoints:true ~internal:true ();
  "breakpoints outside", fields ~first:0.2 ~last:0.7 ~breakpoints:true ~keep:"Outside" ();
  "extract", fields ~first:0.25 ~last:0.75 ~extract:true ();
  "extract equal", fields ~first:0.5 ~last:0.5 ~extract:true ();
  "extract divisions", fields ~first:0.2 ~last:0.8 ~extract:true ~divisions:4 ();
  "extract original", fields ~first:0.2 ~last:0.8 ~extract:true ~original:true ();
  "extract breakpoints", fields ~first:0.2 ~last:0.8 ~extract:true ~breakpoints:true ();
  "extract internal", fields ~first:0.2 ~last:0.8 ~extract:true ~breakpoints:true ~internal:true ~original:true () ]

let bench () =
  let sections = List.init 20_000 (fun i -> sec ~kind:open_k 50 (float i *. 0.01) ~radius:(1. +. (0.001 *. float (i mod 7)))) in
  [with_parameters (build sections)], fields ~first:0.2 ~last:0.7 ()

let () = register { key = "carve"; native = Sop.Nodes.Carve.factory; inputs; cases; ulps = 4;
  bench = Some bench }
