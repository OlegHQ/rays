module E = Flow.Eval
module G = Rdk.Geometry

let error code message = Error (Flow.Diagnostic.error ~code message)
let count geometry = function
  | "points" -> Ok (G.point_count geometry)
  | "vertices" -> Ok (G.vertex_count geometry)
  | "primitives" -> Ok (G.primitive_count geometry)
  | "edges" -> Ok (Rdk.Topology_index.edge_count (Rdk.Topology_index.create (G.topology geometry)))
  | _ -> error "E_TOPOLOGY_COUNT" "Count element is points, vertices, primitives or edges."

let resolve ~geometry = function
  | E.Source (("sop/count" | "sop/edges" as name), _, args) ->
      (match List.assoc_opt "geometry" args with
       | Some (E.Deferred (ty, id)) when Flow.Ty.is_geometry ty ->
           (match geometry id with
            | None -> error "E_DATA_SOURCE" "Topology source has not been cooked."
            | Some geometry ->
                if name="sop/count" then
                  (match List.assoc_opt "element" args with
                   | Some (E.Text element) -> Result.map (fun n -> E.Int n) (count geometry element)
                   | _ -> error "E_TOPOLOGY_COUNT" "Count element is points, vertices, primitives or edges.")
                else
                  let index = Rdk.Topology_index.Private.view
                    (Rdk.Topology_index.create (G.topology geometry)) in
                  (match List.assoc_opt "component" args with
                   | Some (E.Text "a") -> Ok (E.Int_array (Array.copy index.edge_a))
                   | Some (E.Text "b") -> Ok (E.Int_array (Array.copy index.edge_b))
                   | _ -> error "E_DATA_SOURCE" "Edge source requires endpoint component a or b."))
       | _ -> error "E_DATA_SOURCE" "Topology source requires cooked geometry.")
  | _ -> error "E_DATA_SOURCE" "Unknown topology data source."
