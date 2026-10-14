(* sop/sort: one geometry input. The standard fixtures carry duplicated keys (ties), "-0" values and
   reversed ordered groups; the custom fixtures are bumped grids in 3-D (so the spatial key uses all
   three axes) with a permutation attribute "perm" and an "id" on points and primitives, and extra
   unused points (vertex order / primitive index give -1). Non-finite keys are not covered (finite
   inputs only). *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let i n = P.Int_value n
let s v = P.Text_value v
let c v = P.Choice_value v
let b v = P.Bool_value v
let f v = P.Float_value v

let bump geometry extra =
  let view = Packed.Float3.Private.view (Geometry.positions geometry) in
  let count = Array.length view.x in
  let total = count + extra in
  let x = Array.make total 0. and y = Array.make total 0. and z = Array.make total 0. in
  for k = 0 to total - 1 do
    let px = if k < count then view.x.(k) else float k *. 0.37 and py = if k < count then view.y.(k) else 1.5 -. float k *. 0.11 in
    x.(k) <- px; y.(k) <- py;
    z.(k) <- 0.9 *. sin (px *. 1.3) *. cos (py *. 0.9) +. (if k mod 7 = 0 then 1.25 else 0.) -. (if k mod 11 = 0 then 3. else 0.)
  done;
  let topology = Topology.Private.view (Geometry.topology geometry) in
  let topology = Topology.create_owned ~point_count:total ~vertex_points:(Array.copy topology.vertex_points)
    ~primitive_offsets:(Array.copy topology.primitive_offsets)
    ~primitive_kinds:(Array.init (Array.length topology.primitive_offsets - 1)
      (fun k -> if Bytes.get topology.primitive_kinds k = '\000' then Topology.Polygon else Topology.Open_polyline))
    |> get_string_ok in
  Geometry.create ~positions:(Packed.Float3.of_owned ~x ~y ~z |> get_string_ok) ~topology () |> get_string_ok

let decorate geometry =
  let g = fixture_groups geometry in
  List.fold_left (fun g owner ->
    let n = match owner with Attribute.Point -> Geometry.point_count g | _ -> Geometry.primitive_count g in
    let add name storage g = Geometry.with_attribute (Attribute.create_owned ~owner ~name storage |> get_string_ok) g
      |> get_string_ok in
    (* 7 is coprime with every count used here (n mod 7 <> 0 is not required: the check below re-derives) *)
    let rec gcd a bb = if bb = 0 then a else gcd bb (a mod bb) in
    let step = List.find (fun candidate -> gcd candidate (max n 1) = 1) [7; 11; 13; 17; 19; 23; 29; 31; 1] in
    g |> add "perm" (Attribute.Int (Array.init n (fun k -> (k * step + 3) mod (max n 1))))
      |> add "id" (Attribute.Int (Array.init n (fun k -> (k * 5) mod 4)))
      |> add "bucket" (Attribute.Float (Array.init n (fun k -> float (k mod 6) *. 0.5 -. 0.)))
      |> add "label" (Attribute.Text (Array.init n (fun k -> String.make 1 (Char.chr (97 + (k * 7) mod 5))))))
    g [Attribute.Point; Attribute.Primitive]

let grid_of connectivity columns rows = Plane_generators.grid ~connectivity ~columns ~rows ~size:6. () |> get_ok
let inputs = List.map (fun (l, gs) -> l, List.map decorate gs) standard_inputs @ List.map (fun (l, g) -> l, [g]) [
  "bump-triangles", decorate (bump (grid_of Grid_triangles 7 5) 5);
  "bump-quads", decorate (bump (grid_of Grid_quads 9 8) 6) ]

let keys = ["X"; "Y"; "Z"; "Distance to point"; "Along vector"; "Attribute component"; "Vertex order";
            "Primitive index"; "Spatial locality"; "Random"; "Index attribute"; "Reverse"; "Shift"]
let key_changes = function
  | "Distance to point" -> ["x", f 0.5; "y", f (-1.); "z", f 2.]
  | "Along vector" -> ["x", f 1.; "y", f 0.5; "z", f (-0.25)]
  | "Attribute component" -> ["attribute", s "bucket"]
  | "Index attribute" -> ["attribute", s "perm"]
  | "Random" -> ["seed", i 7]
  | "Shift" -> ["shift", i 3]
  | _ -> []
let cases =
  List.concat_map (fun owner ->
    let base = ["owner", c owner] in
    List.concat_map (fun key ->
      let k = key_changes key in
      [Printf.sprintf "%s/%s" owner key, base @ ["key", c key] @ k;
       Printf.sprintf "%s/%s desc" owner key, base @ ["key", c key; "descending", b true] @ k;
       Printf.sprintf "%s/%s group" owner key, base @ ["key", c key; "group", s "a"] @ k;
       Printf.sprintf "%s/%s group desc" owner key, base @ ["key", c key; "group", s " dest_a "; "descending", b true] @ k;
       Printf.sprintf "%s/%s output" owner key, base @ ["key", c key; "output_indices", s "rank"] @ k;
       Printf.sprintf "%s/%s output group" owner key, base @ ["key", c key; "output_indices", s "rank"; "group", s "old_x"] @ k]) keys
    @ List.map (fun (label, changes) -> owner ^ "/" ^ label, base @ changes) [
      "default", [];
      "seed 0", ["key", c "Random"; "seed", i 0];
      "seed 1", ["key", c "Random"; "seed", i 1];
      "seed big", ["key", c "Random"; "seed", i 9999];
      "seed negative", ["key", c "Random"; "seed", i (-5)];
      "random desc", ["key", c "Random"; "seed", i 3; "descending", b true];
      "random group", ["key", c "Random"; "group", s "a"];
      "shift 0", ["key", c "Shift"; "shift", i 0];
      "shift negative", ["key", c "Shift"; "shift", i (-4)];
      "shift big", ["key", c "Shift"; "shift", i 100];
      "shift group", ["key", c "Shift"; "shift", i 2; "group", s "a"];
      "shift desc", ["key", c "Shift"; "shift", i 2; "descending", b true];
      "reverse group", ["key", c "Reverse"; "group", s "dest_a"];
      "reverse desc", ["key", c "Reverse"; "descending", b true];
      "missing group", ["group", s "nope"];
      "literal group", ["group", s "literal *?[]^\\"];
      "unicode group", ["group", s "\195\169\231\140\171"; "key", c "Y"];
      "component 1", ["key", c "Attribute component"; "attribute", s "vec2"; "component", i 1];
      "component 2", ["key", c "Attribute component"; "attribute", s "vec3"; "component", i 2];
      "component 3", ["key", c "Attribute component"; "attribute", s "vec4"; "component", i 3; "descending", b true];
      "component 0 float", ["key", c "Attribute component"; "attribute", s "float"];
      "component integer", ["key", c "Attribute component"; "attribute", s "integer"; "descending", b true];
      "component text", ["key", c "Attribute component"; "attribute", s "label"];
      "component text desc", ["key", c "Attribute component"; "attribute", s "text"; "descending", b true];
      "component range", ["key", c "Attribute component"; "attribute", s "float"; "component", i 1];
      "component range vec4", ["key", c "Attribute component"; "attribute", s "vec4"; "component", i 4];
      "component rows", ["key", c "Attribute component"; "attribute", s "float_rows"];
      "component int rows", ["key", c "Attribute component"; "attribute", s "int_rows"];
      "component missing", ["key", c "Attribute component"; "attribute", s "nope"];
      "index bad", ["key", c "Index attribute"; "attribute", s "id"];
      "index missing", ["key", c "Index attribute"; "attribute", s "nope"];
      "index float", ["key", c "Index attribute"; "attribute", s "float"];
      "index group", ["key", c "Index attribute"; "attribute", s "perm"; "group", s "a"];
      "index desc", ["key", c "Index attribute"; "attribute", s "perm"; "descending", b true];
      "distance origin", ["key", c "Distance to point"; "x", f 0.; "y", f 0.; "z", f 0.];
      "vector zero", ["key", c "Along vector"; "x", f 0.; "y", f 0.; "z", f 0.];
      "vector tiny", ["key", c "Along vector"; "x", f 1e-16; "y", f 0.; "z", f 0.];
      "vector x", ["key", c "Along vector"; "x", f 3.; "y", f 0.; "z", f 0.];
      "output blank", ["output_indices", s "  "];
      "output P", ["output_indices", s "P"];
      "output existing", ["output_indices", s "perm"; "key", c "Y"];
      "output replaced name", ["output_indices", s " rank "; "key", c "Z"; "descending", b true];
      "combine", ["output_indices", s "perm"; "combine_indices", b true; "key", c "Attribute component"; "attribute", s "bucket"];
      "combine group", ["output_indices", s "perm"; "combine_indices", b true; "key", c "Attribute component";
                        "attribute", s "bucket"; "group", s "a"];
      "combine desc", ["output_indices", s "perm"; "combine_indices", b true; "key", c "X"; "descending", b true];
      "combine bad", ["output_indices", s "id"; "combine_indices", b true];
      "combine missing", ["output_indices", s "nope"; "combine_indices", b true];
      "combine wrong type", ["output_indices", s "float"; "combine_indices", b true];
      "combine no output", ["combine_indices", b true];
      "combine reverse", ["output_indices", s "perm"; "combine_indices", b true; "key", c "Reverse"];
      "combine random", ["output_indices", s "perm"; "combine_indices", b true; "key", c "Random"];
      "combine shift", ["output_indices", s "perm"; "combine_indices", b true; "key", c "Shift"];
      "combine index", ["output_indices", s "perm"; "combine_indices", b true; "key", c "Index attribute"; "attribute", s "perm"] ])
    ["Points"; "Primitives"]
let bench () =
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> get_ok in
  [bump grid 0], ["key", c "Random"; "seed", i 5]
let () = register { key = "sort"; native = Sop.Nodes.Sort.factory; inputs; cases; ulps = 4; bench = Some bench }
