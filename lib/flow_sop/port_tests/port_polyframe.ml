(* sop/polyframe: one geometry input. Fixtures: the standard four plus randomised small grids and a
   polygon+polyline with uv attributes (vertex float2, point float3), existing N / tangent / bitangent
   at point and vertex owners, and wrongly typed attributes, so every style, selection owner, output
   name combination and error branch is reached. The last fixture receives every case in the quick
   gate. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let fl name x = name, P.Float_value x
let tx name value = name, P.Text_value value
let bo name b = name, P.Bool_value b
let ch name value = name, P.Choice_value value

let hash i salt = float ((i * 7919 + salt * 104729 + 13) mod 1000) /. 500. -. 1.
let add owner name storage g = Geometry.with_attribute
  (Attribute.create_owned ~owner ~name storage |> get_string_ok) g |> get_string_ok
let spread geometry =
  let n = Geometry.point_count geometry in
  let plane salt scale count = Array.init count (fun i -> scale *. hash i salt) in
  Geometry.with_positions (Packed.Float3.of_owned ~x:(plane 1 2.5 n) ~y:(plane 2 2.5 n) ~z:(plane 3 2.5 n)
    |> get_string_ok) geometry |> get_string_ok
let float3 salt count = Attribute.Float3 (Packed.Float3.of_owned ~x:(Array.init count (fun i -> hash i salt))
  ~y:(Array.init count (fun i -> hash i (salt + 1))) ~z:(Array.init count (fun i -> hash i (salt + 2)))
  |> get_string_ok)
let float2 salt count = Attribute.Float2 (Packed.Float2.of_owned ~x:(Array.init count (fun i -> hash i salt))
  ~y:(Array.init count (fun i -> hash i (salt + 1))) |> get_string_ok)
let with_vertex_uv g = add Attribute.Vertex "uv" (float2 21 (Geometry.vertex_count g)) g
let with_point_uv name g = add Attribute.Point name (float3 25 (Geometry.point_count g)) g
let with_frames g =
  g |> (fun g -> add Attribute.Point "N" (float3 4 (Geometry.point_count g)) g)
    |> (fun g -> add Attribute.Vertex "N" (float3 8 (Geometry.vertex_count g)) g)
    |> (fun g -> add Attribute.Point "tangentu" (float3 12 (Geometry.point_count g)) g)
    |> (fun g -> add Attribute.Vertex "tangentu" (float3 16 (Geometry.vertex_count g)) g)
    |> (fun g -> add Attribute.Point "tangentv" (float3 30 (Geometry.point_count g)) g)
    |> (fun g -> add Attribute.Vertex "tangentv" (float3 34 (Geometry.vertex_count g)) g)
let with_wrong g =
  g |> (fun g -> add Attribute.Vertex "fl" (Attribute.Float (Array.init (Geometry.vertex_count g) (fun i -> hash i 3))) g)
    |> (fun g -> add Attribute.Point "fl" (Attribute.Float (Array.init (Geometry.point_count g) (fun i -> hash i 3))) g)
let small_grid () = Plane_generators.grid ~connectivity:Grid_quads ~columns:6 ~rows:6 ~size:4. () |> get_ok
let base () = fixture_attributes (fixture_groups (polygon_polyline ()))
let inputs = standard_inputs @ List.map (fun (label, g) -> label, [g]) [
  "spread mixed uv", with_vertex_uv (with_frames (spread (base ())));
  "spread mixed point uv", with_point_uv "uv" (spread (base ()));
  "flat grid uv", with_vertex_uv (fixture_groups (small_grid ()));
  "spread grid point uv", with_point_uv "uv" (with_wrong (spread (fixture_groups (small_grid ()))));
  "spread grid", with_point_uv "puv" (with_wrong (with_frames (with_vertex_uv (spread (fixture_groups (small_grid ()))))))]

let styles = ["First edge"; "Two edges"; "Primitive centroid"; "Texture UV"; "Texture UV gradient"; "Attribute gradient"]
let cases =
  List.concat_map (fun style -> List.concat_map (fun orthogonal -> List.map (fun left ->
    Printf.sprintf "%s/ortho %b/left %b" style orthogonal left,
    [ch "style" style; bo "orthogonal" orthogonal; bo "left_handed" left; tx "style_attribute" "uv"])
    [false; true]) [false; true]) styles
  @ List.concat_map (fun style -> List.concat_map (fun group_owner -> List.map (fun group ->
    Printf.sprintf "%s/%s %S" style group_owner group,
    [ch "style" style; ch "group_owner" group_owner; tx "group" group; tx "style_attribute" "uv"; bo "orthogonal" true])
    ["a"; " old_x "]) ["Point"; "Vertex"; "Primitive"; "Edge"]) styles
  @ [ "missing group", [tx "group" "nothing"];
      "missing edge group", [ch "group_owner" "Edge"; tx "group" "nothing"];
      "no tangent", [tx "tangent_attribute" ""];
      "no bitangent", [tx "bitangent_attribute" "  "];
      "no tangent ortho", [tx "tangent_attribute" ""; bo "orthogonal" true];
      "neither", [tx "tangent_attribute" ""; tx "bitangent_attribute" ""];
      "neither texture", [ch "style" "Texture UV"; tx "tangent_attribute" ""; tx "bitangent_attribute" ""];
      "no bitangent texture", [ch "style" "Texture UV"; tx "bitangent_attribute" ""; tx "style_attribute" "uv"];
      "no tangent gradient", [ch "style" "Texture UV gradient"; tx "tangent_attribute" ""; tx "style_attribute" "uv"];
      "normal name", [tx "normal_attribute" "nn"; tx "tangent_attribute" " tu "; tx "bitangent_attribute" "tv"];
      "normal blank", [tx "normal_attribute" " "];
      "normal P", [tx "normal_attribute" "P"];
      "tangent P", [tx "tangent_attribute" "P"];
      "bitangent P", [tx "bitangent_attribute" " P "];
      "duplicate names", [tx "tangent_attribute" "N"];
      "duplicate tangents", [tx "tangent_attribute" "x"; tx "bitangent_attribute" "x"];
      "existing wrong type", [tx "normal_attribute" "fl"];
      "existing wrong tangent", [tx "tangent_attribute" "fl"];
      "existing wrong bitangent", [tx "bitangent_attribute" "fl"];
      "uv blank", [ch "style" "Texture UV"; tx "style_attribute" "  "];
      "uv point", [ch "style" "Texture UV"; tx "style_attribute" "puv"; bo "orthogonal" true];
      "uv point gradient", [ch "style" "Texture UV gradient"; tx "style_attribute" "puv"];
      "uv vec3", [ch "style" "Attribute gradient"; tx "style_attribute" "vec3"];
      "uv vec2", [ch "style" "Attribute gradient"; tx "style_attribute" "vec2"];
      "uv float", [ch "style" "Attribute gradient"; tx "style_attribute" "fl"];
      "uv vec4", [ch "style" "Texture UV"; tx "style_attribute" "vec4"];
      "uv missing", [ch "style" "Texture UV"; tx "style_attribute" "absent"];
      "uv blank gradient", [ch "style" "Attribute gradient"; tx "style_attribute" " "];
      "first edge ortho left", [bo "orthogonal" true; bo "left_handed" true; tx "tangent_attribute" "tu"] ]

let bench () =
  let n = 1000 in
  let g = Plane_generators.grid ~connectivity:Grid_quads ~columns:n ~rows:n ~size:8. () |> get_ok in
  [g], []
let () = register { key = "polyframe"; native = Sop.Nodes.Polyframe.factory; inputs; cases; ulps = 4; bench = Some bench }
