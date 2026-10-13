(* sop/group_promotions: one geometry input (pending draft). Every owner pair x element mode, keep / attribute
   outputs, patterns and rewrites, rule sequencing, limits, the boundary mode and refusals. *)
open Rdk
open Port_gate
module P = Param
let owners = ["point"; "vertex"; "primitive"; "edge"]
let row ?(pattern = "*") ?(name = "") ?(keep = "false") ?(attr = "false") ?(op = "any") ?(tol = "0")
    ?(unshared = "false") ?(curve = "false") ?(prims = "false") ?(attrs = "") src dst =
  String.concat "\t" [src; dst; pattern; name; keep; attr; op; tol; unshared; curve; prims; attrs]
let rules rows = "rules", P.Text_value (String.concat "\n" rows)
let one r = [rules [r]]
let cases =
  List.concat_map (fun src -> List.concat_map (fun dst ->
    List.map (fun op -> Printf.sprintf "%s>%s/%s" src dst op, one (row ~op src dst))
      ["any"; "all"; "shared_edge"]) owners) owners
  @ List.concat_map (fun (src, dst) ->
      [Printf.sprintf "keep %s>%s" src dst, one (row ~keep:"true" ~name:"promoted_*" src dst);
       Printf.sprintf "attr %s>%s" src dst, one (row ~attr:"true" ~name:"mask_*" src dst);
       Printf.sprintf "attr_keep %s>%s" src dst, one (row ~attr:"true" ~keep:"true" src dst)])
    ["point", "primitive"; "primitive", "point"; "vertex", "point"; "edge", "vertex"; "point", "point"; "primitive", "vertex"; "edge", "edge"]
  @ [ "pattern_one", one (row ~pattern:"a" "point" "primitive");
      "pattern_multi", one (row ~pattern:"a dest_a" "point" "vertex");
      "pattern_exclude", one (row ~pattern:"* ^old*" "point" "primitive");
      "pattern_none", one (row ~pattern:"zzz" "point" "primitive");
      "pattern_blank_skipped", one (row ~pattern:" " "point" "primitive");
      "pattern_bad", one (row ~pattern:"[" "point" "primitive");
      "pattern_literal", one (row ~pattern:"literal\\ \\*\\?\\[\\]\\^\\\\" "point" "primitive");
      "pattern_unicode", one (row ~pattern:"\195\169*" ~name:"\231\140\171*" "primitive" "point");
      "rewrite", one (row ~pattern:"*" ~name:"p_*" "point" "primitive");
      "rewrite_trimmed", one (row ~pattern:"a" ~name:" renamed " "point" "primitive");
      "rewrite_constant", one (row ~pattern:"a dest_a" ~name:"same" "point" "primitive");
      "rewrite_empty_result", one (row ~pattern:"a" ~name:"\\" "point" "primitive");
      "rewrite_bad", one (row ~pattern:"a" ~name:"[" "point" "primitive");
      "same_owner_rename", one (row ~pattern:"a" ~name:"b_*" "primitive" "primitive");
      "same_owner_ordered", one (row ~pattern:"dest_a" ~name:"moved" ~keep:"true" "point" "point");
      "same_owner_replace", one (row ~pattern:"a" ~name:"dest_a" "vertex" "vertex");
      "same_name_reappend", one (row ~pattern:"a" "point" "point");
      "overwrite_other_owner", one (row ~pattern:"a" ~name:"dest_a" "point" "primitive");
      "sequence", [rules [row ~pattern:"a" ~name:"first" "point" "primitive"; row ~pattern:"first" ~name:"second" "primitive" "vertex";
                          row ~pattern:"second" ~keep:"true" "vertex" "point"]];
      "sequence_same_pattern", [rules [row ~pattern:"*" ~name:"z_*" "point" "primitive"; row ~pattern:"z_*" "primitive" "point"]];
      "sequence_touch", [rules [row ~pattern:"a dest_a" ~name:"dest_a" "primitive" "primitive"]];
      "sequence_error_late", [rules [row "point" "primitive"; row ~attr:"true" "point" "edge"]];
      "two_attrs", [rules [row ~attr:"true" ~name:"mask" ~pattern:"a" "point" "primitive"; row ~attr:"true" ~name:"mask" ~pattern:"dest_a" "point" "primitive"]];
      "no_rules", [rules [""]];
      "bad_columns", [rules ["point\tprimitive\t*"]];
      "bad_owner", one (row "points" "nowhere");
      "bad_op", one (row ~op:"sideways" "point" "primitive");
      "bad_bool", one (row ~keep:"maybe" "point" "primitive");
      "alt_tokens", one (row ~op:"Shared Edge" ~keep:"YES" ~attr:"0" "Points" "Primitives");
      "attr_to_edges", one (row ~attr:"true" "point" "edge");
      "shared_non_primitive", one (row ~op:"shared_edge" "point" "vertex");
      "all_to_points", one (row ~op:"all" "vertex" "point");
      "max_outputs_1", [rules [row ~pattern:"*" "point" "primitive"]; "max_outputs", P.Int_value 1];
      "max_outputs_2", [rules [row ~pattern:"a dest_a" "point" "primitive"]; "max_outputs", P.Int_value 2];
      "max_outputs_across", [rules [row ~pattern:"a" "point" "primitive"; row ~pattern:"dest_a" "point" "primitive"]; "max_outputs", P.Int_value 1];
      "max_payload", [rules [row ~pattern:"*" "point" "primitive"]; "max_payload_bytes", P.Int_value 1];
      "max_payload_attr", [rules [row ~pattern:"*" ~attr:"true" "point" "primitive"]; "max_payload_bytes", P.Int_value 5000];
      "max_payload_edge", [rules [row ~pattern:"*" "point" "edge"]; "max_payload_bytes", P.Int_value 2];
      (* boundary mode *)
      "boundary_default", one (row ~op:"boundary" ~tol:"0.5" "primitive" "edge");
      "boundary_points", one (row ~op:"boundary" ~tol:"0.5" "primitive" "point");
      "boundary_prims_from_points", one (row ~op:"boundary" ~tol:"0.5" ~unshared:"true" "point" "primitive");
      "boundary_attrs", one (row ~op:"boundary" ~tol:"0.25" ~attrs:"point\tfloat" "primitive" "point");
      "boundary_attrs_vertex", one (row ~op:"boundary" ~tol:"0.5" ~attrs:"Vertices\tvec*" "vertex" "primitive");
      "boundary_unshared", one (row ~op:"boundary" ~tol:"0.5" ~unshared:"true" "primitive" "edge");
      "boundary_curve", one (row ~op:"boundary" ~tol:"0.5" ~unshared:"true" ~curve:"true" "primitive" "edge");
      "boundary_curve_without_unshared", one (row ~op:"boundary" ~tol:"0.5" ~curve:"true" "primitive" "edge");
      "boundary_share_points", one (row ~op:"boundary" ~tol:"0.5" ~prims:"true" "point" "primitive");
      "boundary_share_points_bad", one (row ~op:"boundary" ~tol:"0.5" ~prims:"true" "point" "vertex");
      "boundary_attribute_output", one (row ~op:"boundary" ~tol:"0.5" ~attr:"true" ~name:"edge_*" "point" "primitive");
      "boundary_attribute_edges", one (row ~op:"boundary" ~tol:"0.5" ~attr:"true" "point" "edge");
      "boundary_negative", one (row ~op:"boundary" ~tol:"-1" "primitive" "edge");
      "boundary_bad_tolerance", one (row ~op:"boundary" ~tol:"x" "primitive" "edge");
      "boundary_detail_attribute", one (row ~op:"boundary" ~tol:"0.5" ~attrs:"detail\t*" "primitive" "edge");
      "boundary_keep_rename", one (row ~op:"boundary" ~tol:"0.5" ~keep:"true" ~name:"b_*" "primitive" "primitive");
      "boundary_edges_source", one (row ~op:"boundary" ~tol:"0.5" ~unshared:"true" "edge" "point") ]
let bench () =
  let g = Geometry.with_group (Group.init ~owner:Group.Point ~name:"selected" 1_000_000 (fun i -> i mod 3 = 0))
    (points 1_000_000) |> Rdk_test_support.get_string_ok in
  [g], one (row ~pattern:"selected" ~name:"out" "point" "vertex")
let () = register { key = "group_promotions"; native = Sop.Nodes.Group_promotions.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
