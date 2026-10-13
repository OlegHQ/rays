(* sop/group_bounds: one geometry input (pending draft). *)
open Port_gate
module P = Param
let f name v = name, P.Float_value v
let t name v = name, P.Text_value v
let c name v = name, P.Choice_value v
let owners = ["Points"; "Vertices"; "Primitives"; "Edges"]
let boxes = ["small", [f "center_x" 0.5; f "center_y" 0.; f "center_z" 0.25; f "size_x" 1.; f "size_y" 1.; f "size_z" 1.];
             "line", [f "center_x" 1.; f "size_x" 0.3; f "size_y" 0.; f "size_z" 0.];
             "all", [f "size_x" 20.; f "size_y" 20.; f "size_z" 20.];
             "none", [f "center_x" 100.]]
let cases =
  List.concat_map (fun owner ->
    List.concat_map (fun (label, box) ->
      List.map (fun containment ->
        Printf.sprintf "box/%s/%s/%s" owner label containment,
        [c "owner" owner; c "containment" containment; t "name" "in"] @ box)
        ["Fully contained"; "Partially contained"]) boxes
    @ List.concat_map (fun containment ->
      List.map (fun (label, r, cx) ->
        Printf.sprintf "sphere/%s/%s/%s" owner label containment,
        [c "owner" owner; c "shape" "Sphere"; c "containment" containment; f "radius" r; f "center_x" cx])
        ["small", 0.5, 0.5; "zero", 0., 0.; "big", 10., 0.; "between", 0.2, 0.5]) ["Fully contained"; "Partially contained"]
    @ List.map (fun merge ->
      Printf.sprintf "merge/%s/%s" owner merge,
      [c "owner" owner; c "merge" merge; t "name" "a"; f "size_x" 3.]) ["Replace"; "Union"; "Intersection"; "Subtract"; "Exclusive or"]
    @ List.map (fun merge ->
      Printf.sprintf "merge_new/%s/%s" owner merge,
      [c "owner" owner; c "merge" merge; f "size_x" 3.]) ["Replace"; "Union"; "Intersection"; "Subtract"; "Exclusive or"]
    @ ["base/" ^ owner, [c "owner" owner; t "base" " a "; f "size_x" 3.];
       "base_missing/" ^ owner, [c "owner" owner; t "base" "zzz"];
       "default/" ^ owner, [c "owner" owner]]) owners
  @ ["blank_name", [t "name" " "]; "defaults", [];
     "base_blank", [t "base" "   "];
     "ordered_union", [c "merge" "Union"; t "name" "dest_a"; f "size_x" 3.]]
let bench () =
  let g = points 1_000_000 in
  [g], [f "size_x" 100000.; f "size_y" 20.; f "size_z" 20.]
let () = register { key = "group_bounds"; native = Sop.Nodes.Group_bounds.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
