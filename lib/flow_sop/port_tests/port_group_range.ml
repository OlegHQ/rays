(* sop/group_range: one geometry input.
   Cases that need a connectivity seam source (connectivity attributes or a collision group) are
   not listed: the draft refuses them with E_UNSUPPORTED because sop/components cannot take seams. *)
open Rdk
open Port_gate
module P = Param
let i n = P.Int_value n
let s v = P.Text_value v
let c v = P.Choice_value v
let b v = P.Bool_value v
let owners = ["Points"; "Vertices"; "Primitives"; "Edges"]
let merges = ["Replace"; "Union"; "Intersection"; "Subtract"; "Exclusive or"]
let cases =
  List.concat_map (fun owner ->
    List.map (fun (label, changes) -> Printf.sprintf "%s/%s" owner label, ("owner", c owner) :: changes) [
      "start_end", ["range_mode", c "Start and end"; "start", i 1; "end_", i 4];
      "start_end negative", ["start", i (-3); "end_", i 2];
      "from_ends", ["range_mode", c "From ends"; "start", i 1; "end_offset", i 1];
      "from_ends negative", ["range_mode", c "From ends"; "start", i (-1)];
      "start_length", ["range_mode", c "Start and length"; "start", i 2; "length", i 3];
      "start_length huge", ["range_mode", c "Start and length"; "start", i 1; "length", i 100000];
      "start_length negative", ["range_mode", c "Start and length"; "start", i (-2); "length", i 5];
      "start_length negative gone", ["range_mode", c "Start and length"; "start", i (-5); "length", i 2];
      "start_length zero", ["range_mode", c "Start and length"; "start", i 1; "length", i 0];
      "start_length beyond", ["range_mode", c "Start and length"; "start", i 100000; "length", i 2];
      "partition", ["range_mode", c "Partition"; "partition", i 1; "partitions", i 3];
      "partition outside", ["range_mode", c "Partition"; "partition", i 5; "partitions", i 3];
      "invert", ["start", i 1; "end_", i 3; "invert", b true];
      "filter", ["start", i 0; "end_", i 20; "use_filter", b true; "filter_select", i 2; "filter_of", i 3; "filter_offset", i 1];
      "filter negative offset", ["end_", i 30; "use_filter", b true; "filter_offset", i (-4); "filter_of", i 4];
      "filter invert", ["end_", i 30; "use_filter", b true; "filter_select", i 0; "filter_of", i 2; "invert", b true];
      "filter bad", ["use_filter", b true; "filter_select", i 3; "filter_of", i 2];
      "base", ["end_", i 30; "base", s "a"];
      "base glob", ["end_", i 30; "base", s "*_x old*"; "invert", b true];
      "base none", ["end_", i 30; "base", s "unmatched"];
      "base bad", ["base", s "["];
      "blank", ["name", s " "]]) owners
  @ List.concat_map (fun owner -> List.map (fun merge ->
      Printf.sprintf "%s merge %s" owner merge, ["owner", c owner; "name", s "a"; "end_", i 6; "merge", c merge])
      merges) owners
  @ List.concat_map (fun owner ->
    List.map (fun (label, changes) -> Printf.sprintf "%s connectivity %s" owner label, ("owner", c owner) :: changes) [
      "disconnected", ["connectivity_mode", c "Disconnected regions"; "end_", i 2];
      "disconnected region", ["connectivity_mode", c "Disconnected regions"; "use_region", b true; "region", i 0; "end_", i 2];
      "disconnected region far", ["connectivity_mode", c "Disconnected regions"; "use_region", b true; "region", i 9];
      "disconnected invert filter", ["connectivity_mode", c "Disconnected regions"; "invert", b true;
        "use_filter", b true; "filter_of", i 2; "end_", i 3];
      "disconnected partition", ["connectivity_mode", c "Disconnected regions"; "range_mode", c "Partition"; "partitions", i 2; "partition", i 1];
      "connected", ["connectivity_mode", c "Connected with seams"; "end_", i 2];
      "connected region keep", ["connectivity_mode", c "Connected with seams"; "use_region", b true; "region", i 0; "end_", i 1];
      "connected region remove", ["connectivity_mode", c "Connected with seams"; "use_region", b true; "region", i 0;
        "end_", i 1; "remove_other_regions", b true];
      "connected base", ["connectivity_mode", c "Connected with seams"; "base", s "a"; "end_", i 1];
      "connected bad collision", ["connectivity_mode", c "Connected with seams"; "use_collision", b true; "collision_pattern", s " "]])
    owners
let bench () =
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  [grid], ["owner", c "Primitives"; "end_", i 300000; "use_filter", b true; "filter_of", i 3]
let () = register { key = "group_range"; native = Sop.Nodes.Group_range.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
