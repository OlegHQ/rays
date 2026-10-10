(* The lowering's provenance tag and an authored [:source_attribute] share one
   geometry merge. Existing attributes keep their values; a missing authored
   attribute needs only one integer per output primitive. *)

let node ~tag ~attribute ~base ~source_base inputs =
  Sop.Node.Private.make_geometry ~label:"Merge" ~operation:"merge" ~version:1
    ~parameters:(Printf.sprintf "tag=%S;base=%d;source=%S;source_base=%d" tag base attribute
      source_base)
    ~cook_mode:Sop.Node.Generic ~dependencies:Sop.Context.Dependencies.static
    ~inputs:(Array.of_list inputs)
    (fun ~node_id:_ context geometries ->
      let failed error = Error (Sop.Diagnostic.error ~code:(Rdk.Error.code error)
        ~cause:(Rdk.Error.to_string error) ~hints:(Rdk.Error.hints error)
        (Rdk.Error.operation error ^ " could not produce valid geometry")) in
      let cancel = Sop.Context.cancel_token context in
      let geometry = Result.bind
        (Rdk.Mesh_merge.run ~cancel ~grain:(Sop.Context.grain context)
          ~source_attribute:tag ~source_base:base (Array.to_list geometries))
        (fun tagged -> Rdk.Error.guard ~operation:"merge" ~code:"schema_mismatch" (fun () ->
          Rdk.Cancel.check cancel;
          let owner = Rdk.Attribute.Primitive in
          (* The old authored-attribute merge did not fill missing provenance
             tags. Keep its exact-schema refusal when those tags are mixed. *)
          let has_tag geometry = Rdk.Geometry.find_attribute ~owner tag geometry <> None in
          if attribute <> tag && Array.exists has_tag geometries
              && Array.exists (fun geometry -> not (has_tag geometry)) geometries then
            Error "Rdk.Mesh_merge.merge: attribute schemas must match exactly"
          else if Array.length geometries = 0 || Rdk.Geometry.find_attribute ~owner attribute tagged <> None
          then Ok tagged
          else
            let values = Array.make (Rdk.Geometry.primitive_count tagged) source_base in
            let offset = ref 0 in
            Array.iteri (fun index geometry ->
              Rdk.Cancel.check cancel;
              let count = Rdk.Geometry.primitive_count geometry in
              if index > 0 then Array.fill values !offset count (source_base + index);
              offset := !offset + count) geometries;
            Result.bind (Rdk.Attribute.create_owned ~name:attribute ~owner (Rdk.Attribute.Int values))
              (fun values -> Rdk.Geometry.with_attribute values tagged))) in
      match geometry with
      | Error error -> failed error
      | Ok geometry -> Ok Sop.Node.Private.{ geometry; diagnostics = []; instances = None })
