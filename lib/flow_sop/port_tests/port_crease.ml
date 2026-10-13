(* sop/crease: one geometry input. Custom fixtures carry creaseweight / Cd attributes. *)
open Rdk
open Port_gate
module P = Param
let put owner name storage g =
  Geometry.with_attribute (Attribute.create_owned ~owner ~name storage |> Rdk_test_support.get_string_ok) g
  |> Rdk_test_support.get_string_ok
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:3 ~rows:3 ~size:2. () |> Rdk_test_support.get_ok
let float4 f n = let p g = Array.init n g in
  Attribute.Float4 (Packed.Float4.of_owned ~x:(p (fun i -> f i 0)) ~y:(p (fun i -> f i 1))
    ~z:(p (fun i -> f i 2)) ~w:(p (fun i -> f i 3)) |> Rdk_test_support.get_string_ok)
let weighted g value =
  put Attribute.Vertex "creaseweight" (Attribute.Float (Array.init (Geometry.vertex_count g) value)) g
let shapes = [ "mixed", (fun () -> fixture_groups (polygon_polyline ())); "grid", (fun () -> fixture_groups (small_grid ())) ]
let inputs =
  List.concat_map (fun (name, make) ->
    let n g = Geometry.vertex_count g and pn g = Geometry.point_count g in
    [ name ^ "/plain", make ();
      name ^ "/weighted", weighted (make ()) (fun i -> if i mod 3 = 0 then 0. else float (i mod 4) *. 0.5);
      name ^ "/zeroes", weighted (make ()) (fun _ -> 0.);
      name ^ "/huge", weighted (make ()) (fun _ -> 1e308);
      name ^ "/cd vertex", (let g = make () in
        weighted (put Attribute.Vertex "Cd" (float4 (fun i c -> float (i + c) *. 0.125) (n g)) g) (fun i -> float (i mod 2)));
      name ^ "/cd vertex red", (let g = make () in
        weighted (put Attribute.Vertex "Cd" (float4 (fun _ c -> if c = 0 || c = 3 then 1. else 0.) (n g)) g) (fun _ -> 1.));
      name ^ "/cd point", (let g = make () in
        weighted (put Attribute.Point "Cd" (float4 (fun i c -> float (i * 3 + c) *. 0.0625) (pn g)) g) (fun i -> float (i mod 2)));
      name ^ "/cd int", (let g = make () in
        weighted (put Attribute.Vertex "Cd" (Attribute.Int (Array.make (n g) 3)) g) (fun _ -> 1.)) ]
    |> List.map (fun (label, g) -> label, [g])) shapes
  @ standard_inputs
let cases =
  List.concat_map (fun op ->
    List.concat_map (fun (glabel, group) ->
      List.map (fun (wlabel, w, color) ->
        Printf.sprintf "%s/%s/%s%s" op glabel wlabel (if color then "/color" else ""),
        ["operation", P.Choice_value op; "group", P.Text_value group; "weight", P.Float_value w;
         "add_vertex_color", P.Bool_value color])
        ["one", 1., false; "zero", 0., false; "big", 2.5, true; "huge", 1e308, false; "zero color", 0., true])
      ["all", ""; "group", "a"; "padded", " dest_a "; "missing", "nothing"; "empty", "old_x"])
    ["Add"; "Set"; "Delete"]
let bench () =
  let n = 500 in
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:n ~rows:n ~size:8. () |> Rdk_test_support.get_ok in
  [g], ["operation", P.Choice_value "Set"; "add_vertex_color", P.Bool_value true]
let () = register { key = "crease"; native = Sop.Nodes.Crease.factory; inputs; cases; ulps = 4; bench = Some bench }
