(* sop/group_range: one geometry input. Seam sources (connectivity attributes, collision groups of each owner,
   both together, keep boundary, tolerance) are listed under "Connected with seams". *)
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
let seams_cases =
  let connected = ["connectivity_mode", c "Connected with seams"] in
  List.concat_map (fun owner ->
    List.map (fun (label, changes) -> Printf.sprintf "%s seams %s" owner label, ("owner", c owner) :: connected @ changes) [
      "attribute float", ["connectivity_attributes", s "float"; "end_", i 3];
      "attribute many", ["connectivity_attributes", s "float vec3 text"; "end_", i 2; "use_region", b true; "region", i 1];
      "attribute integer", ["connectivity_attributes", s " integer "; "end_", i 1; "invert", b true];
      "attribute star", ["connectivity_attributes", s "*"; "end_", i 3];
      "attribute tolerance", ["connectivity_attributes", s "float vec2"; "connectivity_tolerance", Param.Float_value 1.0; "end_", i 2];
      "attribute nothing", ["connectivity_attributes", s "zzz"];
      "attribute bad pattern", ["connectivity_attributes", s "["];
      "attribute base", ["connectivity_attributes", s "float"; "base", s "a"; "end_", i 3];
      "attribute partition", ["connectivity_attributes", s "float"; "range_mode", c "Partition"; "partitions", i 2; "partition", i 1]]
    @ List.concat_map (fun collision ->
      List.map (fun (label, changes) -> Printf.sprintf "collision %s %s" collision label,
        ["use_collision", b true; "collision_owner", c collision] @ changes) [
        "a", ["collision_pattern", s "a"; "end_", i 3];
        "keep", ["collision_pattern", s "a"; "keep_boundary", b true; "end_", i 3];
        "multi", ["collision_pattern", s "dest_a old_x"; "end_", i 2];
        "star", ["collision_pattern", s "*"; "end_", i 3; "use_region", b true; "region", i 0];
        "none", ["collision_pattern", s "zzz"; "end_", i 3];
        "bad pattern", ["collision_pattern", s "["];
        "with attributes", ["collision_pattern", s "a"; "connectivity_attributes", s "float"; "end_", i 3];
        "remove", ["collision_pattern", s "dest_a"; "remove_other_regions", b true; "use_region", b true; "region", i 0]])
      owners) owners

let cases = cases @ seams_cases
let bench () =
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> Rdk_test_support.get_ok in
  [grid], ["owner", c "Primitives"; "end_", i 300000; "use_filter", b true; "filter_of", i 3]
let () = register { key = "group_range"; native = Sop.Nodes.Group_range.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
