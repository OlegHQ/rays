(* sop/attribute_interpolate: two geometry inputs (source, target). The source is a mixed mesh (triangle, quad,
   pentagon, open and closed polyline, a second triangle sharing points) with point/vertex/primitive/detail
   attributes of every storage and groups; the targets carry primitive/UVW and numbers/weights drivers on every
   owner plus existing attributes (to blend with), and variants with unmatched, out-of-range, mistyped or missing
   drivers. Cases cover all drivers x target owners x source owners, every parameter, patterns, groups and the
   construction refusals. Native arm64 fuses the sequential accumulation; the node models it with fma. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let ch name value = name, P.Choice_value value
let fl name value = name, P.Float_value value

let put owner name storage geometry = Geometry.with_attribute
  (Attribute.create_owned ~owner ~name storage |> get_string_ok) geometry |> get_string_ok
let count_of geometry = function
  | Attribute.Point -> Geometry.point_count geometry | Vertex -> Geometry.vertex_count geometry
  | Primitive -> Geometry.primitive_count geometry | Detail -> 1
let wave n k i = ((float ((i * 7 + k * 5) mod 13)) *. 0.37) -. 1.1 +. float n *. 0.01 +. float k *. 0.003
let f3 n k = Attribute.Float3 (Packed.Float3.of_owned ~x:(Array.init n (wave n k)) ~y:(Array.init n (wave n (k + 1)))
  ~z:(Array.init n (wave n (k + 2))) |> get_string_ok)
let f2 n k = Attribute.Float2 (Packed.Float2.of_owned ~x:(Array.init n (wave n k)) ~y:(Array.init n (wave n (k + 3)))
  |> get_string_ok)
let f4 n k = Attribute.Float4 (Packed.Float4.of_owned ~x:(Array.init n (wave n k)) ~y:(Array.init n (wave n (k + 1)))
  ~z:(Array.init n (wave n (k + 2))) ~w:(Array.init n (wave n (k + 4))) |> get_string_ok)
let rows_for n k =
  let lens = Array.init n (fun i -> (i + k) mod 4) in
  let offsets = Array.make (n + 1) 0 in
  Array.iteri (fun i l -> offsets.(i + 1) <- offsets.(i) + l) lens;
  offsets
let float_array n k = let offsets = rows_for n k in
  Attribute.Float_array (Packed.Float_array.create_owned ~offsets
    ~values:(Array.init offsets.(n) (fun j -> wave n k j)) |> get_string_ok)
let int_array n k = let offsets = rows_for n k in
  Attribute.Int_array (Packed.Int_array.create_owned ~offsets
    ~values:(Array.init offsets.(n) (fun j -> j * 3 + k)) |> get_string_ok)
let all_attributes geometry =
  List.fold_left (fun geometry owner ->
    let n = count_of geometry owner in
    List.fold_left (fun geometry (name, storage) -> put owner name storage geometry) geometry
      [ "Cd", f3 n 1; "N", f3 n 4; "f", Attribute.Float (Array.init n (wave n 2));
        "n", Attribute.Int (Array.init n (fun i -> i * 5 - 3)); "s", Attribute.Text (Array.init n (fun i -> "s" ^ string_of_int i));
        "v2", f2 n 3; "v4", f4 n 5; "fa", float_array n 1; "ia", int_array n 2 ])
    geometry [Attribute.Point; Vertex; Primitive; Detail]

let positions n = Packed.Float3.of_owned ~x:(Array.init n (fun i -> float i *. 0.5)) ~y:(Array.init n (fun i -> float (i mod 3) -. 1.))
  ~z:(Array.init n (fun i -> float (i * i mod 5) *. 0.25)) |> get_string_ok
let mesh ~points ~vertex_points ~primitive_offsets ~kinds =
  let topology = Topology.create_owned ~point_count:points ~vertex_points ~primitive_offsets ~primitive_kinds:kinds
    |> get_string_ok in
  Geometry.create ~positions:(positions points) ~topology () |> get_string_ok
let source () =
  mesh ~points:20 ~vertex_points:[|0;1;2; 3;4;5;6; 7;8;9;10;11; 12;13;14;15; 16;17;18;19; 0;3;7|]
    ~primitive_offsets:[|0;3;7;12;16;20;23|]
    ~kinds:[|Topology.Polygon; Polygon; Polygon; Open_polyline; Closed_polyline; Polygon|]
  |> all_attributes |> fixture_groups
let target_mesh () =
  mesh ~points:8 ~vertex_points:[|0;1;2;3; 4;5;6; 6;7|] ~primitive_offsets:[|0;4;7;9|]
    ~kinds:[|Topology.Polygon; Polygon; Open_polyline|]

let owners = [Attribute.Point; Vertex; Primitive; Detail]
let prim_numbers = [| 0; 1; 2; 3; 4; 5; -1; 99; 3; 2; 1; 0 |]
let uvw n i = let j = (i * 5 + n) mod 11 in
  match j with
  | 0 -> 0., 0., 0.
  | 1 -> 1., 1., 0.
  | 2 -> 1.4, 0.3, 0.
  | 3 -> -0.4, 0.8, 0.
  | _ -> float j *. 0.09 +. 0.03, float ((j * 3) mod 10) *. 0.1 +. 0.05, 0.
let drivers_prim geometry =
  List.fold_left (fun geometry owner ->
    let n = count_of geometry owner in
    let geometry = put owner "sourceprim" (Attribute.Int (Array.init n (fun i -> prim_numbers.((i + n) mod 12)))) geometry in
    put owner "sourceuvw" (Attribute.Float3 (Packed.Float3.of_owned
      ~x:(Array.init n (fun i -> let x, _, _ = uvw n i in x)) ~y:(Array.init n (fun i -> let _, y, _ = uvw n i in y))
      ~z:(Array.init n (fun i -> let _, _, z = uvw n i in z)) |> get_string_ok)) geometry)
    geometry owners
let weight_rows n ~limit ~bad =
  let lens = Array.init n (fun i -> [| 3; 0; 2; 1; 4; 2; 5; 1 |].(i mod 8)) in
  let offsets = Array.make (n + 1) 0 in
  Array.iteri (fun i l -> offsets.(i + 1) <- offsets.(i) + l) lens;
  let row_of j = let rec find i = if j < offsets.(i + 1) then i else find (i + 1) in find 0 in
  let numbers = Array.init offsets.(n) (fun j -> let i = row_of j in
    if bad && i = 4 then limit + 3 else (i * 3 + (j - offsets.(i)) * 2) mod limit) in
  let weights = Array.init offsets.(n) (fun j -> let i = row_of j in let k = j - offsets.(i) in
    match i mod 4 with
    | 0 -> 0.2 *. float (k + 1)
    | 1 -> 0.5
    | 2 -> 0.1 -. 0.3 *. float (k + 1)
    | _ -> if k mod 2 = 0 then 0.5 else -0.5) in
  offsets, numbers, weights
let drivers_weights ?(bad = false) ?(skew = false) geometry =
  List.fold_left (fun geometry owner ->
    let n = count_of geometry owner in
    let offsets, numbers, weights = weight_rows n ~limit:6 ~bad in
    let w_offsets = if skew then Array.map (fun o -> o + (if o > 0 then 1 else 0)) offsets else offsets in
    let geometry = put owner "sourcenums" (Attribute.Int_array
      (Packed.Int_array.create_owned ~offsets ~values:numbers |> get_string_ok)) geometry in
    put owner "sourceweights" (Attribute.Float_array
      (Packed.Float_array.create_owned ~offsets:w_offsets ~values:(if skew then Array.append weights [|0.|] else weights)
       |> get_string_ok)) geometry)
    geometry owners
let existing geometry = all_attributes geometry
let rich () = target_mesh () |> existing |> drivers_prim |> drivers_weights |> fixture_groups
let bare () = target_mesh () |> drivers_prim |> drivers_weights
let computed_pair geometry =
  List.fold_left (fun geometry owner ->
    let n = count_of geometry owner in
    let offsets = rows_for n 1 in
    let geometry = put owner "computednums" (Attribute.Int_array (Packed.Int_array.create_owned ~offsets
      ~values:(Array.init offsets.(n) (fun j -> j + 100)) |> get_string_ok)) geometry in
    put owner "computedweights" (Attribute.Float_array (Packed.Float_array.create_owned ~offsets
      ~values:(Array.init offsets.(n) (fun j -> float j *. 0.5)) |> get_string_ok)) geometry)
    geometry [Attribute.Point; Vertex; Primitive]
let mismatch () = target_mesh () |> drivers_prim |> drivers_weights
  |> put Attribute.Point "Cd" (Attribute.Float (Array.make 8 0.5))
let wrong_drivers () = target_mesh ()
  |> put Attribute.Point "sourceprim" (Attribute.Float (Array.make 8 1.))
  |> put Attribute.Point "sourceuvw" (Attribute.Float2 (Packed.Float2.of_owned ~x:(Array.make 8 0.5) ~y:(Array.make 8 0.5) |> get_string_ok))
  |> put Attribute.Point "sourcenums" (Attribute.Int (Array.make 8 0))
  |> put Attribute.Point "sourceweights" (Attribute.Float (Array.make 8 0.5))
let mixed () = fixture_attributes (fixture_groups (polygon_polyline ()))
let empty_source () = mesh ~points:0 ~vertex_points:[||] ~primitive_offsets:[|0|] ~kinds:[||] |> all_attributes
let empty_target () = mesh ~points:0 ~vertex_points:[||] ~primitive_offsets:[|0|] ~kinds:[||] |> drivers_prim |> drivers_weights
let inputs = [
  "rich", [source (); rich ()];
  "bare", [source (); bare ()];
  "oob", [source (); target_mesh () |> existing |> drivers_prim |> drivers_weights ~bad:true |> fixture_groups];
  "skew", [source (); target_mesh () |> drivers_prim |> drivers_weights ~skew:true];
  "computed", [source (); rich () |> computed_pair];
  "computed half", [source (); rich () |> put Attribute.Point "computednums" (Attribute.Int (Array.make 8 0))];
  "mismatch", [source (); mismatch ()];
  "wrong drivers", [source (); wrong_drivers ()];
  "no drivers", [source (); target_mesh () |> existing];
  "empty target", [source (); empty_target ()];
  "empty source", [empty_source (); rich ()];
  "mixed", [mixed (); mixed ()];
  "grid", [source (); fixture_groups (grid ())] ]

let names = ["Cd"; "f"; "n"; "s"; "v2"; "v4"; "fa"; "ia"; "N"]
let owner_name = function Attribute.Point -> "point" | Vertex -> "vertex" | Primitive -> "primitive" | Detail -> "detail"
let rule owner source target = owner ^ "\t" ^ source ^ "\t" ^ target
let rows owner = String.concat "\n" (List.map (fun n -> rule owner n n) names)
let drivers = ["Primitive UVW"; "Point weights"; "Vertex weights"; "Primitive weights"]
let target_owners = ["Point"; "Vertex"; "Primitive"; "Detail"]
let w = fl "threshold" 0.2
let matrix = List.concat_map (fun target_owner -> List.concat_map (fun driver ->
  List.map (fun owner ->
    Printf.sprintf "%s/%s/%s" target_owner driver (owner_name owner),
    [ch "target_owner" target_owner; ch "driver" driver; tx "attributes" (rows (owner_name owner)); w])
    owners) drivers) target_owners
let mixed_rows = String.concat "\n" [rule "point" "Cd" "Cd"; rule "vertex" "f" "f"; rule "primitive" "n" "n";
  rule "detail" "s" "s"; rule "point" "N" "N"; rule "vertex" "v2" "v2"; rule "primitive" "ia" "ia"; rule "point" "fa" "fa"]
let cases = matrix @ [
  "default mixed", [tx "attributes" mixed_rows];
  "uvw vertex mixed", [ch "target_owner" "Vertex"; tx "attributes" mixed_rows];
  "uvw primitive mixed", [ch "target_owner" "Primitive"; tx "attributes" mixed_rows];
  "uvw detail mixed", [ch "target_owner" "Detail"; tx "attributes" mixed_rows];
  "rename", [tx "attributes" (rule "point" "Cd" "Cd_out" ^ "\n" ^ rule "vertex" "n" "n_out" ^ "\n" ^ rule "primitive" "s" "s_out")];
  "kind mismatch float to vec3", [tx "attributes" (rule "point" "f" "Cd")];
  "kind mismatch vec3 to int", [tx "attributes" (rule "point" "Cd" "n")];
  "kind mismatch array to int", [tx "attributes" (rule "point" "fa" "ia")];
  "duplicate target", [tx "attributes" (rule "point" "Cd" "x" ^ "\n" ^ rule "vertex" "Cd" "x")];
  "missing source", [tx "attributes" (rule "point" "absent" "absent")];
  "empty rows", [tx "attributes" ""];
  "bad owner", [tx "attributes" (rule "corner" "Cd" "Cd")];
  "bad columns", [tx "attributes" "point\tCd"];
  "blank names", [tx "attributes" (rule "point" " " "Cd")];
  "blank target", [tx "attributes" (rule "point" "Cd" " ")];
  "owner case", [tx "attributes" (rule " Points " "Cd" "Cd" ^ "\n" ^ rule "VERTEX" "f" "f")];
  "position", [tx "attributes" (rule "point" "P" "P")];
  "position rename", [tx "attributes" (rule "point" "P" "pos")];
  "position vertex source", [tx "attributes" (rule "vertex" "P" "P")];
  "position vertex target", [ch "target_owner" "Vertex"; tx "attributes" (rule "point" "P" "P")];
  "position weighted", [ch "driver" "Point weights"; w; tx "attributes" (rule "point" "P" "P")];
  "position blend", [fl "blend" 0.5; tx "attributes" (rule "point" "P" "P")];
  "position into other", [tx "attributes" (rule "point" "Cd" "P")];
  "unmatched default", [ch "unmatched" "Default value"; tx "attributes" mixed_rows];
  "unmatched default weighted", [ch "unmatched" "Default value"; ch "driver" "Vertex weights"; w; tx "attributes" mixed_rows];
  "unmatched default all", [ch "unmatched" "Default value"; tx "attributes" (rows "point" ^ "\n" ^ rule "vertex" "Cd" "Cd2")];
  "unmatched keep all", [tx "attributes" (rows "point")];
  "blend 0", [fl "blend" 0.; tx "attributes" (rows "point")];
  "blend 0.3", [fl "blend" 0.3; tx "attributes" (rows "point")];
  "blend 0.5", [fl "blend" 0.5; tx "attributes" (rows "point")];
  "blend 0.7 weighted", [fl "blend" 0.7; ch "driver" "Point weights"; w; tx "attributes" (rows "point")];
  "blend 0.4 vertex", [fl "blend" 0.4; ch "target_owner" "Vertex"; tx "attributes" (rows "vertex")];
  "pre_scale 0.5", [fl "pre_scale" 0.5; tx "attributes" (rows "point")];
  "pre_scale 1.3 tri", [fl "pre_scale" 1.3; ch "target_owner" "Primitive"; tx "attributes" (rows "point")];
  "pre_scale negative", [fl "pre_scale" (-1.5); tx "attributes" (rows "point")];
  "pre_scale weighted", [fl "pre_scale" 2.5; ch "driver" "Point weights"; w; tx "attributes" (rows "point")];
  "pre_scale weighted unnormalized", [fl "pre_scale" 0.5; ch "driver" "Vertex weights"; w; bo "normalize_weights" false;
                                      tx "attributes" (rows "vertex")];
  "normalize off", [ch "driver" "Point weights"; w; bo "normalize_weights" false; tx "attributes" (rows "point")];
  "normalize off blend", [ch "driver" "Primitive weights"; w; bo "normalize_weights" false; fl "blend" 0.6;
                          tx "attributes" (rows "primitive")];
  "threshold 0.01", [ch "driver" "Point weights"; fl "threshold" 0.01; tx "attributes" (rows "point")];
  "threshold 1", [ch "driver" "Vertex weights"; fl "threshold" 1.; tx "attributes" (rows "vertex")];
  "threshold 0.9 blend", [ch "driver" "Vertex weights"; fl "threshold" 0.9; fl "blend" 0.8; ch "target_owner" "Vertex";
                          tx "attributes" (rows "vertex")];
  "threshold zero weighted", [ch "driver" "Point weights"; tx "attributes" (rows "point")];
  "threshold unused uvw", [fl "threshold" 0.5; tx "attributes" (rows "point")];
  "driver names", [tx "primitive_attribute" "sourceprim"; tx "uvw_attribute" "sourceuvw"; tx "attributes" (rows "point")];
  "driver names missing", [tx "primitive_attribute" "nope"; tx "attributes" (rows "point")];
  "driver uvw missing", [tx "uvw_attribute" "nope"];
  "driver prim blank", [tx "primitive_attribute" " "];
  "driver uvw blank", [tx "uvw_attribute" "  "];
  "driver names weighted", [ch "driver" "Point weights"; w; tx "numbers_attribute" "nope"];
  "driver weights missing", [ch "driver" "Point weights"; w; tx "weights_attribute" "nope"];
  "driver numbers blank", [ch "driver" "Point weights"; w; tx "numbers_attribute" " "];
  "driver weights blank", [ch "driver" "Point weights"; w; tx "weights_attribute" " "];
  "driver swap", [ch "driver" "Point weights"; w; tx "numbers_attribute" "sourceweights"; tx "weights_attribute" "sourcenums"];
  "driver prim as uvw", [tx "uvw_attribute" "sourceprim"];
  "driver Cd as prim", [tx "primitive_attribute" "n"];
  "driver weights unused", [tx "numbers_attribute" "nope"; tx "attributes" (rows "point")];
  "unsupported point weights", [ch "driver" "Point weights"; w; tx "attributes" (rule "vertex" "Cd" "Cd")];
  "unsupported primitive weights", [ch "driver" "Primitive weights"; w; tx "attributes" (rule "point" "Cd" "Cd")];
  "weighted compute refused", [ch "driver" "Point weights"; w; bo "compute_weights" true];
  "group a", [tx "group" "a"; tx "attributes" (rows "point")];
  "group a vertex", [tx "group" "a"; ch "target_owner" "Vertex"; tx "attributes" (rows "vertex")];
  "group a primitive", [tx "group" "dest_a"; ch "target_owner" "Primitive"; tx "attributes" (rows "primitive")];
  "group a default", [tx "group" "a"; ch "unmatched" "Default value"; tx "attributes" (rows "point")];
  "group a weighted", [tx "group" "dest_a"; ch "driver" "Point weights"; w; ch "unmatched" "Default value";
                       tx "attributes" (rows "point")];
  "group literal", [tx "group" "literal *?[]^\\"; tx "attributes" (rows "point")];
  "group unicode", [tx "group" "\195\169\231\140\171"; tx "attributes" (rows "point")];
  "group missing", [tx "group" "nothing"];
  "group missing before errors", [tx "group" "nothing"; tx "attributes" (rule "point" "absent" "absent")];
  "group detail refused", [ch "target_owner" "Detail"; tx "group" "a"];
  "group pattern", [tx "group_pattern" "*a"; tx "attributes" (rows "point")];
  "group pattern union", [tx "group_pattern" "[ad]*"; tx "attributes" (rows "point")];
  "group pattern vertex", [tx "group_pattern" "*"; ch "target_owner" "Vertex"; tx "attributes" (rows "vertex")];
  "group pattern none", [tx "group_pattern" "zzz*"; tx "attributes" (rows "point")];
  "group pattern wins", [tx "group" "nothing"; tx "group_pattern" "a"; tx "attributes" (rows "point")];
  "group pattern invalid", [tx "group_pattern" "[a"];
  "group pattern detail refused", [ch "target_owner" "Detail"; tx "group_pattern" "*"];
  "patterns point", [tx "attributes" ""; tx "point_pattern" "*"];
  "patterns point subset", [tx "attributes" ""; tx "point_pattern" "C* f n"];
  "patterns point P", [tx "attributes" ""; tx "point_pattern" "P"];
  "patterns point all P", [tx "attributes" ""; tx "point_pattern" "* P"];
  "patterns vertex", [tx "attributes" ""; tx "vertex_pattern" "[fnv]*"];
  "patterns primitive", [tx "attributes" ""; tx "primitive_pattern" "*"];
  "patterns detail", [tx "attributes" ""; tx "detail_pattern" "*"];
  "patterns all owners", [tx "attributes" ""; tx "point_pattern" "Cd"; tx "vertex_pattern" "f"; tx "primitive_pattern" "n";
                          tx "detail_pattern" "s"];
  "patterns duplicate", [tx "point_pattern" "Cd"];
  "patterns duplicate cross", [tx "attributes" ""; tx "point_pattern" "Cd"; tx "vertex_pattern" "Cd"];
  "patterns vertex target P", [ch "target_owner" "Vertex"; tx "attributes" ""; tx "point_pattern" "P"];
  "patterns weighted unsupported", [ch "driver" "Point weights"; w; tx "attributes" ""; tx "vertex_pattern" "f"];
  "patterns weighted", [ch "driver" "Vertex weights"; w; tx "attributes" ""; tx "point_pattern" "C* N"; tx "vertex_pattern" "f s";
                        tx "primitive_pattern" "n"; tx "detail_pattern" "v2"];
  "patterns invalid", [tx "point_pattern" "[a"];
  "patterns invalid vertex", [tx "vertex_pattern" "[a"];
  "patterns invalid primitive", [tx "primitive_pattern" "[a"];
  "patterns invalid detail", [tx "detail_pattern" "[a"];
  "match groups", [tx "attributes" ""; bo "match_groups" true; tx "point_pattern" "a"];
  "match groups all", [tx "attributes" ""; bo "match_groups" true; tx "point_pattern" "*"; tx "vertex_pattern" "x"];
  "match groups vertex", [tx "attributes" ""; bo "match_groups" true; tx "vertex_pattern" "d*"; ch "target_owner" "Vertex"];
  "match groups primitive", [tx "attributes" ""; bo "match_groups" true; tx "primitive_pattern" "[ad]*"];
  "match groups primitive target", [tx "attributes" ""; bo "match_groups" true; tx "primitive_pattern" "*";
                                    ch "target_owner" "Primitive"];
  "match groups blend", [tx "attributes" ""; bo "match_groups" true; tx "point_pattern" "*"; fl "blend" 0.4];
  "match groups default", [tx "attributes" ""; bo "match_groups" true; tx "point_pattern" "*"; ch "unmatched" "Default value"];
  "match groups duplicate", [tx "attributes" ""; bo "match_groups" true; tx "point_pattern" "a"; tx "vertex_pattern" "a"];
  "match groups detail target", [tx "attributes" ""; bo "match_groups" true; tx "point_pattern" "a"; ch "target_owner" "Detail"];
  "match groups weighted point", [tx "attributes" ""; bo "match_groups" true; tx "point_pattern" "*"; ch "driver" "Point weights"; w];
  "match groups weighted point vertex", [tx "attributes" ""; bo "match_groups" true; tx "vertex_pattern" "*";
                                         ch "driver" "Point weights"; w];
  "match groups weighted vertex", [tx "attributes" ""; bo "match_groups" true; tx "point_pattern" "a"; tx "primitive_pattern" "d*";
                                   ch "driver" "Vertex weights"; w];
  "match groups weighted vertex blend", [tx "attributes" ""; bo "match_groups" true; tx "vertex_pattern" "*";
                                         ch "driver" "Vertex weights"; w; fl "blend" 0.5; ch "unmatched" "Default value"];
  "match groups weighted primitive", [tx "attributes" ""; bo "match_groups" true; tx "primitive_pattern" "*";
                                      ch "driver" "Primitive weights"; w; ch "target_owner" "Primitive"];
  "match groups with attributes", [bo "match_groups" true; tx "point_pattern" "d*"; tx "attributes" (rows "point")];
  "match groups unused", [tx "attributes" (rows "point"); tx "point_pattern" ""; bo "match_groups" true];
  "match groups off", [tx "attributes" ""; tx "point_pattern" "a"];
  "match groups none", [tx "attributes" ""; bo "match_groups" true];
  "compute", [bo "compute_weights" true; tx "attributes" ""];
  "compute with attributes", [bo "compute_weights" true];
  "compute vertex", [bo "compute_weights" true; ch "computed_owner" "Vertex"];
  "compute vertex target", [bo "compute_weights" true; ch "target_owner" "Vertex"; ch "computed_owner" "Vertex"];
  "compute primitive target", [bo "compute_weights" true; ch "target_owner" "Primitive"];
  "compute detail target", [bo "compute_weights" true; ch "target_owner" "Detail"];
  "compute names", [bo "compute_weights" true; tx "computed_numbers_attribute" "cn"; tx "computed_weights_attribute" "cw"];
  "compute default", [bo "compute_weights" true; ch "unmatched" "Default value"; tx "computed_numbers_attribute" "cn"];
  "compute group", [bo "compute_weights" true; tx "group" "a"; tx "computed_numbers_attribute" "cn"];
  "compute group default", [bo "compute_weights" true; tx "group" "a"; ch "unmatched" "Default value"];
  "compute pre_scale", [bo "compute_weights" true; fl "pre_scale" 0.7; tx "attributes" ""];
  "compute same names", [bo "compute_weights" true; tx "computed_weights_attribute" "computednums"];
  "compute blank", [bo "compute_weights" true; tx "computed_numbers_attribute" " "];
  "compute P", [bo "compute_weights" true; tx "computed_numbers_attribute" "P"];
  "compute P vertex target", [bo "compute_weights" true; ch "target_owner" "Vertex"; tx "computed_numbers_attribute" "P"];
  "compute replaces driver", [bo "compute_weights" true; tx "computed_numbers_attribute" "sourceprim"];
  "compute replaces uvw", [bo "compute_weights" true; tx "computed_weights_attribute" "sourceuvw"];
  "compute replaces output", [bo "compute_weights" true; tx "computed_numbers_attribute" "Cd"];
  "compute with groups", [bo "compute_weights" true; bo "match_groups" true; tx "point_pattern" "a"; tx "attributes" ""];
  "compute off names", [tx "computed_numbers_attribute" "cn"];
  "all", [bo "compute_weights" true; bo "match_groups" true; tx "point_pattern" "d*"; tx "vertex_pattern" "f"; tx "group" "a";
          ch "unmatched" "Default value"; fl "blend" 0.6; fl "pre_scale" 0.8; ch "computed_owner" "Vertex"];
]

(* 1,000,000 target points interpolated over a 1,000 x 1,000 quad grid by primitive and UVW (Cd, vec3). *)
let bench () =
  let side = 1000 in
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:side ~rows:side ~size:8. () |> get_ok in
  let grid_points = Geometry.point_count grid in
  let source = put Attribute.Point "Cd" (f3 grid_points 1) grid in
  let n = 1_000_000 in
  let target = points n in
  let target = put Attribute.Point "sourceprim" (Attribute.Int (Array.init n (fun i -> (i * 7919) mod (side * side)))) target in
  let target = put Attribute.Point "sourceuvw" (Attribute.Float3 (Packed.Float3.of_owned
    ~x:(Array.init n (fun i -> float (i mod 97) /. 97.)) ~y:(Array.init n (fun i -> float (i mod 89) /. 89.))
    ~z:(Array.make n 0.) |> get_string_ok)) target in
  [source; target], []
let () = register { key = "attribute_interpolate"; native = Sop.Nodes.Attribute_interpolate.factory; inputs;
  cases; ulps = 4; bench = Some bench }
