module E = Flow.Eval
module G = Rdk.Geometry
module Group = Rdk.Group
module Edge = Rdk.Edge_group

type owner = Ordinary of Group.owner | Edge
let error code message = Error (Flow.Diagnostic.error ~code message)
let owner = function
  | "point" -> Ok (Ordinary Group.Point) | "vertex" -> Ok (Ordinary Group.Vertex)
  | "primitive" -> Ok (Ordinary Group.Primitive) | "edge" -> Ok Edge
  | _ -> error "E_GROUP_OWNER" "Group owner is point, vertex, primitive or edge."
let count geometry = function
  | Ordinary Point -> G.point_count geometry | Ordinary Vertex -> G.vertex_count geometry
  | Ordinary Primitive -> G.primitive_count geometry
  | Edge -> Rdk.Topology_index.edge_count (Rdk.Topology_index.create (G.topology geometry))
let name name = if String.trim name = "" then error "E_GROUP_NAME" "Group name must not be blank." else Ok ()
let missing name = error "E_GROUP_MISSING" ("Missing group " ^ name ^ ".")
let read ~owner ~name geometry =
  match owner with
  | Ordinary owner -> (match G.find_group ~owner name geometry with
      | None -> missing name | Some group -> Ok (E.Int_array (Array.init (Group.length group)
          (fun index -> if Group.mem index group then 1 else 0))))
  | Edge -> (match G.find_edge_group name geometry with
      | None -> missing name | Some group -> Ok (E.Int_array (Array.init (Edge.length group)
          (fun index -> if Edge.mem index group then 1 else 0))))
let order ~owner ~name geometry =
  match owner with
  | Edge -> (match G.find_edge_group name geometry with
      | None -> missing name
      | Some _ -> Ok (E.Record["ordered",E.Bool false;"indices",E.Int_array[||]]))
  | Ordinary owner -> (match G.find_group ~owner name geometry with
      | None -> missing name
      | Some group -> Ok (E.Record ["ordered", E.Bool (Group.is_ordered group);
          "indices", E.Int_array (Option.value ~default:[||] (Group.ordered_elements group))]))
let names ~owner ~pattern geometry =
  match Rdk.Attribute_pattern.compile pattern with
  | Error message -> error "E_GROUP_PATTERN" message
  | Ok pattern ->
      let names = match owner with
        | Ordinary owner -> G.groups geometry |> List.filter_map (fun group ->
            if Group.owner group = owner then Some (Group.name group) else None)
        | Edge -> List.map Edge.name (G.edge_groups geometry) in
      Ok (E.Text_array (Array.of_list (List.filter (Rdk.Attribute_pattern.matches pattern) names)))
let write ?order ~owner ~name:group_name mask geometry =
  Result.bind (name group_name) (fun () ->
  if Array.length mask <> count geometry owner then error "E_GROUP_COUNT" "Group mask must match its owner element count."
  else if Array.exists (fun value -> value <> 0 && value <> 1) mask then
    error "E_GROUP_MASK" "Group mask values must be 0 or 1."
  else
    let map_error result = Result.map_error (fun message -> Flow.Diagnostic.error ~code:"E_GROUP_ORDER" message) result in
    match owner, order with
    | Edge, Some _ -> error "E_GROUP_OWNER" "Edge groups do not have an explicit traversal order."
    | Edge, None ->
        let topology = G.topology geometry in
        let index = Rdk.Topology_index.create topology in
        map_error (G.with_edge_group (Edge.init ~topology ~index ~name:group_name (fun index -> mask.(index)=1)) geometry)
    | Ordinary owner, None ->
        map_error (G.with_group (Group.init ~owner ~name:group_name (Array.length mask) (fun index -> mask.(index)=1)) geometry)
    | Ordinary owner, Some order ->
        Result.bind (map_error (Group.ordered ~owner ~name:group_name ~length:(Array.length mask) order)) (fun group ->
          if Group.cardinality group <> Array.fold_left ( + ) 0 mask
              || not (Array.for_all (fun index -> mask.(index)=1) order) then
            error "E_GROUP_ORDER" "Explicit order must contain each selected mask index exactly once."
          else map_error (G.with_group group geometry)))

let resolve ~geometry = function
  | E.Source (("sop/group"|"sop/group_names"|"sop/group_order" as operation),_,args) ->
      let text key default = match List.assoc_opt key args with
        | None -> Ok default | Some(E.Text value) -> Ok value
        | _ -> error "E_GROUP_TYPE" ("Group " ^ key ^ " must be text.") in
      Result.bind(text "owner" "point")(fun owner_name->Result.bind(owner owner_name)(fun owner->
      match List.assoc_opt "geometry" args with
      | Some(E.Deferred(ty,id)) when Flow.Ty.is_geometry ty ->
          (match geometry id with
           | None -> error "E_DATA_SOURCE" "Group source has not been cooked."
           | Some geometry ->
               if operation="sop/group_names" then Result.bind(text "pattern" "")(fun pattern->names ~owner ~pattern geometry)
               else Result.bind(text "name" "")(fun group_name->Result.bind(name group_name)(fun()->
                 if operation="sop/group" then read ~owner ~name:group_name geometry
                 else Result.bind(order ~owner ~name:group_name geometry)(function
                   | E.Record fields -> (match List.assoc_opt "component" args with
                       | Some(E.Text component) -> (match List.assoc_opt component fields with
                           | Some value -> Ok value | None -> error "E_GROUP_TYPE" "Group order component is ordered or indices.")
                       | _ -> error "E_GROUP_TYPE" "Group order component is ordered or indices.")
                   | _ -> assert false))))
      | _ -> error "E_DATA_SOURCE" "Group source requires cooked geometry."))
  | _ -> error "E_DATA_SOURCE" "Unknown group data source."
