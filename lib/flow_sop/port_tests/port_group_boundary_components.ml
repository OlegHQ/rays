(* sop/group_boundary_components: one geometry input. *)
open Rdk
open Port_gate
module P = Param
let fields prefix conflict max_groups max_payload_bytes =
  ["prefix", P.Text_value prefix; "conflict", P.Choice_value conflict; "max_groups", P.Int_value max_groups;
   "max_payload_bytes", P.Int_value max_payload_bytes]
let cases =
  List.concat_map (fun conflict -> [
    conflict ^ "/default", fields "boundary" conflict 4096 268435456;
    conflict ^ "/prefix", fields "ring" conflict 4096 268435456;
    conflict ^ "/few groups", fields "boundary" conflict 1 268435456;
    conflict ^ "/small payload", fields "boundary" conflict 4096 1]) ["Replace"; "Union"]
  @ ["blank", fields "  " "Replace" 4096 268435456; "exact limit", fields "boundary" "Replace" 3 268435456]
(* Three disjoint polygon pieces (one with an interior shared edge), a polyline whose ends are not
   surface boundary, and existing groups sharing the generated names. *)
let pieces () =
  let topology = Topology.create_owned ~point_count:16
    ~vertex_points:[|0;1;2;3; 4;5;6; 7;8;9;10; 8;11;9; 12;13;14;15|]
    ~primitive_offsets:[|0;4;7;11;14;18|]
    ~primitive_kinds:[|Topology.Polygon; Polygon; Polygon; Polygon; Open_polyline|] |> Rdk_test_support.get_string_ok in
  let geometry = Geometry.create ~positions:(Geometry.positions (points 16)) ~topology () |> Rdk_test_support.get_string_ok in
  let put name members g = Geometry.with_group
    (Group.init ~owner:Group.Point ~name 16 (fun i -> List.mem i members)) g |> Rdk_test_support.get_string_ok in
  let ordered = Group.ordered ~owner:Group.Point ~name:"boundary__1" ~length:16 [|9; 2; 5|] |> Rdk_test_support.get_string_ok in
  geometry |> put "boundary__0" [0; 4] |> Geometry.with_group ordered |> Rdk_test_support.get_string_ok
let inputs = standard_inputs @ ["pieces", [pieces ()]]
let bench () =
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:100 ~rows:100 ~size:8. () |> Rdk_test_support.get_ok in
  [grid], fields "boundary" "Replace" 4096 268435456
let () = register { key = "group_boundary_components"; native = Sop.Nodes.Group_boundary_components.factory;
  inputs; cases; ulps = 4; bench = Some bench }
