(* sop/distance_along_geometry: one geometry input (pending draft nodes/distance_along_geometry.pending). *)
open Rdk
open Port_gate
module P = Param
let text name value = name, P.Text_value value
let choice name value = name, P.Choice_value value
let float name value = name, P.Float_value value
(* Standard fixtures plus a point group "start" (every third point) and "sparse" (the first point). *)
let with_start geometry =
  let n = Geometry.point_count geometry in
  let put name pick geometry = Geometry.with_group (Group.init ~owner:Group.Point ~name n pick) geometry
    |> Rdk_test_support.get_string_ok in
  put "sparse" (fun i -> i = 0) (put "start" (fun i -> i mod 3 = 0) geometry)
let inputs = List.map (fun (label, geometries) -> label, List.map with_start geometries) standard_inputs
let owners = ["Point"; "Vertex"; "Primitive"; "Edge"]
let cases =
  List.map (fun o -> "start " ^ o, [choice "start_owner" o; text "start_group" "a"]) owners
  @ List.map (fun o -> "affected " ^ o, [choice "affected_owner" o; text "affected_group" "a"]) owners
  @ [ "start sparse", [text "start_group" " sparse "];
      "start blank", [text "start_group" " "; choice "start_owner" "Edge"];
      "affected start", [text "affected_group" "start"];
      "missing start", [text "start_group" "nothing"];
      "missing affected", [text "affected_group" "nothing"];
      "start vertex missing", [choice "start_owner" "Vertex"; text "start_group" "start"] ]
  @ List.concat_map (fun f -> [
      f ^ "/maximum", [choice "falloff" f; text "mask_attribute" "mask"];
      f ^ "/fixed", [choice "falloff" f; choice "radius_mode" "Fixed"; float "radius" 0.75; text "mask_attribute" "mask"];
      f ^ "/fixed large", [choice "falloff" f; choice "radius_mode" "Fixed"; float "radius" 500.; text "mask_attribute" " mask "];
      f ^ "/fixed no distance", [choice "falloff" f; choice "radius_mode" "Fixed"; float "radius" 0.4;
        text "distance_attribute" " "; text "mask_attribute" "mask"];
      f ^ "/affected", [choice "falloff" f; text "mask_attribute" "mask"; text "affected_group" "sparse"];
      f ^ "/sparse", [choice "falloff" f; text "mask_attribute" "mask"; text "start_group" "sparse"]])
    ["Linear"; "Quadratic"; "Cubic"]
  @ [ "named distance", [text "distance_attribute" " dist "];
      "mask only", [text "distance_attribute" ""; text "mask_attribute" "mask"];
      "existing float", [text "distance_attribute" "float"; text "mask_attribute" "float2"];
      "existing float mask", [text "mask_attribute" "float"];
      "non-float distance", [text "distance_attribute" "vec3"];
      "non-float mask", [text "mask_attribute" "integer"];
      "affected existing", [text "distance_attribute" "float"; text "affected_group" "sparse"] ]
  (* Not cases: construction refusals (blank or equal or P names, non-positive fixed radius): the gate
     only sees checker refusals, and :validate runs at lowering. *)
let bench () =
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:1000 ~rows:1000 ~size:8. () |> Rdk_test_support.get_ok in
  [with_start g], [text "mask_attribute" "mask"]
let () = register { key = "distance_along_geometry"; native = Sop.Nodes.Distance_along_geometry.factory;
  inputs; cases; ulps = 4; bench = Some bench }
