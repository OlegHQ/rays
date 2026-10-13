(* sop/group_random: one geometry input (pending draft). *)
open Port_gate
module P = Param
let t name v = name, P.Text_value v
let c name v = name, P.Choice_value v
let owners = ["Points"; "Vertices"; "Primitives"; "Edges"]
let cases =
  List.concat_map (fun owner ->
    List.map (fun (label, changes) -> Printf.sprintf "%s/%s" label owner, c "owner" owner :: changes)
      ["default", [];
       "probability0", ["probability", P.Float_value 0.];
       "probability1", ["probability", P.Float_value 1.];
       "probability_small", ["probability", P.Float_value 0.3; "seed", P.Int_value 17];
       "seed", ["seed", P.Int_value 9999];
       "context_seed", ["context_seed", P.Bool_value true];
       "named", [t "name" "a"; c "merge" "Union"];
       "named_ordered", [t "name" "dest_a"; c "merge" "Exclusive or"];
       "base", [t "base" " a "; "probability", P.Float_value 0.8];
       "base_missing", [t "base" "zzz"];
       "seed_attribute_int", [t "seed_attribute" " integer "];
       "seed_attribute_float", [t "seed_attribute" "float"];
       "seed_attribute_missing", [t "seed_attribute" "nothing"];
       "blank_name", [t "name" " "]]
    @ List.map (fun merge ->
      Printf.sprintf "merge_%s/%s" merge owner, [c "owner" owner; c "merge" merge; t "name" "a"])
      ["Replace"; "Union"; "Intersection"; "Subtract"; "Exclusive or"]) owners
let bench () =
  [points 1_000_000], ["probability", P.Float_value 0.5; "seed", P.Int_value 3]
let () = register { key = "group_random"; native = Sop.Nodes.Group_random.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
