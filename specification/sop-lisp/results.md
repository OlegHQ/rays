# SOP Lisp implementation evidence

Started 2026-10-12 against checkout `79b52a0516acdce15ce2227926e9e5db22510d95`.
The approved [plan](plan.md) remains the scope: 128 target nodes, 31 retained
OCaml nodes and 3 wiring nodes. No port, performance result or phase review is
claimed by this initial census.

The intended public API snapshot was accepted separately in commit `9cea2e6b`
(`Accept Lisp SOP declaration and packed column APIs`), after promotion session
78317 and the API/catalog/dependency gate exited 0. That commit changes only
`tools/api_manifest/api_stable.json`; the implementation and pilot remain
separate changes, as required by the plan.

## Task evidence

| Task | Current evidence | Remaining gate |
| --- | --- | --- |
| A.0 | The plan records all six decision baselines, using the explicitly decided answers and the other approved recommendations. | Complete: answers recorded. |
| A.1 | `opam exec -- _build/default/tools/check.exe @lib/rdk/test_support/runtest @test/lisp_sop/runtest` exited 0 (helper agent session 95253). `test_geometry_comparison.ml` checks equality at 0 ULP, one ULP at tolerance 1, rejection at 0, two ULP rejection at 1, and changed integer storage rejection at 4. | Complete: helper gates passed. |
| A.2 | The census checks all 128 target keys. `test_defnode.ml` covers typed/image/function/optional/rest slots, every supported metadata key, vector grouping, refusal shapes, recursion and an OCaml kind-name clash. `_build/default/tools/check.exe @lib/flow/runtest @lib/sop_catalog/runtest @test/dependency_gate` exited 0 after the final checker changes (session 29492); prior checker sessions 87642 and 6143 also passed. | Complete: reader/checker gates passed. |
| A.3 | Lowering keeps one public cache identity with zero retained internal entries; derives specialized facts; tests all Param edits with exactly one miss, nested/optional/rest nodes, physical Image/Fn slots and cooked captures, strict unsupported refusal without interpreter fallback, and reference/domain/grain exactness. `@lib/flow_sop/runtest @lib/flow_ir/runtest` passed (helper sessions 9823, 3589 and 55571). The last run covers strict typed-Fn lowering and geometry-zone element uniforms after forwarding `elems` to the packed executor. Attribute packing ownership/nonfinite/domain regressions passed (root session 92124). Injected-body cache identity passed (session 91419). Borrowed-plane host tests passed in `@lib/flow_sop/runtest` (root session 37000): 0/1/32769 elements, signed zero, one/eight domains, physically shared exact P planes, independently owned Cd planes, short-zip `E_ATTR_COUNT`, and immutable original bytes. Accepted optional/rest Fn slots and scoped helper context dependencies were repaired; refreshed `@lib/flow_sop/runtest @lib/flow/runtest @lib/flow_ir/runtest` exited 0 (session 93829), followed by root integration gate 80542. | Complete: focused lowering, cache, typed-slot and exactness gates passed. |
| A.4 | Shared `tools/lisp/embed.exe` embeds the source directory; the catalog injects definitions with disjoint IDs and the manifest records Lisp bodies and checked calls. Focused lowering/dependency tests passed (session 61578); focused dummy-driver editor tests passed (session 97387). Reviewed promoted metadata-only manifest diff: descriptions and non-Cook impact, digest `e3e6c69a267f17ee74791ce4f4adc112`. `@lib/sop_catalog/runtest @test/dependency_gate` exited 0 (sessions 95723, 14766); combined checker/catalog/dependency gate passed (session 29492). Source/edit/body-cache and keyword manifest regressions passed (session 91419). | Focused integration gates passed; actual embedded-pilot save/editor refresh remains pending before A.R. |
| A.5 | `test_lisp_projection.ml` compares the Lisp and independent OCaml cards structurally, full inspector metadata, scalar/vector scrubs, parameter drives, bypass, nested cards and schema-change invalidation. Combined lowering/graph/editor gate exited 0 (session 89094); actual editor fallback-inspector editing and menu search/add passed (session 92998). Dummy-driver `@test/test_workspace_vocabulary @test/test_workspace_shell @test/test_sop_catalog @test/dependency_gate` exited 0 (session 16558), proving helper navigation filtering, completion refresh after declaration addition/removal, schema changes, reload and reducer undo/redo, actual menu interaction, and the combined factory registry. | Focused card/menu/vocabulary/navigation gates passed; actual embedded-pilot save/editor refresh remains pending before A.R. |
| A.6 | The complete pilot implements both noise modes and explicit/context seed selection. Its context-seed and attribute-delete prerequisites have moved forward from later work. Whole-mode geometry/domain/grain/cache/schema checks passed (checker agent session 60089). The quiet one-million-point timing gate passed (session 59246, measurements below). | Production `.rays` registration switch, source-save/editor rerun, shipping/native checks and any justified golden refresh remain pending. |
| A.R | `specification/sop.md` and `lib/sop_catalog/AGENTS.md` now describe the Lisp declaration alternative and runtime ownership. `specification/flow.md` describes `defnode`. | `check.exe --ship` and `@runtest-native` after the pilot remain pending. |
| B–E | No port evidence recorded here yet. | All language, port and phase review gates. |
| G.1–G.2 | Optional tasks; no placement evidence recorded here yet. | Measured placement and CPU/GPU tolerance checks. |

## A.2 parameter census

The target keys were read from the plan's B–E inventory, including its A.6
pilot, rather than assuming every `sop/` manifest kind is a target. There are
128 distinct keys, and every key has a current manifest entry and source
declaration. The manifest snapshot is version `202609`, digest
`0535593a6c5ed90781b183492dcd22d7`.

A.4 now extends the manifest writer and reader to retain descriptions and
non-default parameter impact. The omission counts below describe the original
snapshot audited above; they are not a claim that the extended writer still
loses that metadata. The final promoted digest is recorded with A.4's gate.

The census used the existing `Flow.Syntax.parse` reader from the built Flow
library and OCaml `Str` for the plan/source annotations. The exact field names,
defaults, ranges, choice order, folder paths and vector-component indices remain
in [`flow_manifest.sexp`](../../lib/sop_catalog/flow_manifest.sexp). The source
records in [`shapes.ml`](../../lib/sop/shapes.ml),
[`attributes.ml`](../../lib/sop/attributes.ml),
[`groups.ml`](../../lib/sop/groups.ml) and
[`sop_topology.ml`](../../lib/sop/sop_topology.ml) provide validation and metadata
that the snapshot omits. `sweep_circle` deliberately shares the Polywire record
and schema (`Polywire.sweep_factory`); its manifest entry was counted separately.

| Requirement | Observed across the 128 target declarations |
| --- | ---: |
| Total scalar fields | 1,434 |
| Bool / int / float / text / choice fields | 191 / 95 / 532 / 384 / 232 |
| Numeric fields with at least one hard bound | 200 |
| Fields with a nonempty folder path | 834 |
| Primary fields | 37 |
| Fields with units | 3 |
| Vec3 presentation groups | 95 |
| Required / optional / rest / optional-rest slots | 124 / 19 / 1 / 2 |
| Source fields with descriptions omitted by the manifest | 8 |
| Encoded parameter fields exposed as text by the manifest | 12 |
| Nodes with a record-level `sop.validate` clause | 81 |

### Contract gaps the form must cover

1. The five manifest scalar kinds are sufficient for the present target field
   values, but the header must preserve soft and hard bounds separately, choice
   labels and order, description, folder, primary, unit and vec3 group/component
   metadata. `Param.field` also carries impact. All target fields have the
   default `Cook` impact; the explicit `View` fields belong to excluded
   `exploded_view`. Preserve the model's impact capability when defining the form.
2. The original snapshot omitted descriptions and impact. A.4 now preserves
   those through [`Manifest.field`](../../lib/flow_sop/manifest.ml) and
   [`Check.catalog_of_manifest`](../../lib/flow/check.ml). The promoted digest is
   recorded above; the eight target descriptions now survive the round trip.
3. `Param.Encoded` appears as plain `text` in `Param.view` and the manifest. Its
   deterministic encoder, decoder and validation remain source behavior.
   Twelve target fields depend on these: rename/swap attribute rules; group
   delete/rename/copy/promotions/ranges rules; group-combine steps; ordered-group
   indices; and three boundary-attribute rule fields. Their malformed-input
   refusals require Lisp validation/decoding, not merely a text parameter.
4. Ramp parameters are text recipes today, not a missing `Param.Ramp` kind:
   `attribute_remap.ramp`, `spiral.height_ramp` and `spiral.radius_ramp` have
   documented knot encodings and source validators. Preserving the header is
   separate from implementing knot evaluation in each Lisp body.
5. The 81 record-level validators cover coupled values, encoded recipes and
   special names; scalar bounds cannot replace them. The form needs checked
   validation clauses with the same construction-time refusal behavior.
6. Slot declarations need required, optional, rest and optional-rest forms,
   preserving slot positions and names. Most slots are geometry; `attr_from_image`
   also accepts an image and `iso_surface` accepts keyword `field` typed
   `fn(vec3)->float`. The Phase A form now accepts `:keyword true` on required
   non-rest function/image slots. It retains physical slot order separately
   from visible positional rows, and the manifest round trip covers both
   keyword types. The refreshed combined lowering/graph gate passed in session
   91419; later ports must retain each native call shape.
7. `set_transform` writes 16-float array-valued attributes, and
   `attribute_interpolate` handles array-valued attributes. B.1's proposed scalar
   attribute list does not express this storage. The capability must be extended
   or those nodes explicitly moved; silently dropping these modes is forbidden.
8. The inventory already calls out `Float.next_after` for `separate_pieces` and
   explicit `Float.fma` for `iso_surface`; neither is in B.8's proposed math
   list. Resolve these prerequisites before those ports and retain their oracles.

The per-node table uses `b/i/f/t/c` for bool/int/float/text/choice field counts.
Vec3 groups count presentation groups, not additional fields. Slot types default
to geometry when omitted. A record validation entry does not include errors
inside the kernel or an encoded decoder; those remain part of each port audit.

The manifest part of the census can be rerun from the repository root with the
following OCaml script after building `lib/flow/flow.cma`. It fails if a target
key disappears or the inventory no longer contains exactly 128 unique targets.

```sh
ocaml -I +str \
  -I _build/default/lib/param/.param.objs/byte \
  -I _build/default/lib/frame_input/.frame_input.objs/byte \
  -I _build/default/lib/flow/.flow.objs/byte \
  str.cma _build/default/lib/param/param.cma \
  _build/default/lib/frame_input/frame_input.cma \
  _build/default/lib/flow/flow.cma -stdin <<'OCAML'
open Flow;;
let read path = let ch = open_in path in
  let s = really_input_string ch (in_channel_length ch) in close_in ch; s;;
let prop name xs = List.find (fun x -> Syntax.head x = Some name) xs
  |> Syntax.children |> List.tl;;
let atom x = match x.Syntax.node with Syntax.Str s -> s | _ -> assert false;;
let plan = read "specification/sop-lisp/plan.md";;
let first = Str.search_forward (Str.regexp_string "| `noise_displace` |") plan 0;;
let last = Str.search_forward (Str.regexp_string "### Stays OCaml") plan first;;
let inventory = String.sub plan first (last - first);;
let quoted s = let re = Str.regexp {|`\([^`]+\)`|} in
  let rec loop at acc = try ignore (Str.search_forward re s at);
    let key = Str.matched_group 1 s in loop (Str.match_end ()) (key :: acc)
    with Not_found -> List.rev acc in loop 0 [];;
let targets = String.split_on_char '\n' inventory
  |> List.filter (String.starts_with ~prefix:"| `")
  |> List.concat_map (fun row -> quoted (List.nth (String.split_on_char '|' row) 1));;
let () = assert (List.length targets = 128);
  assert (List.length (List.sort_uniq String.compare targets) = 128);;
let manifest = match Syntax.parse (read "lib/sop_catalog/flow_manifest.sexp") with
  Ok [x] -> x | _ -> failwith "manifest parse";;
let kinds = prop "kinds" (Syntax.children manifest);;
let fields = List.concat_map (fun key ->
  let kind = List.find (fun x -> atom (List.hd (prop "key" (Syntax.children x))) = key) kinds in
  prop "fields" (Syntax.children kind)) targets;;
let () = List.iter (fun name ->
  let count = List.filter (fun field ->
    Syntax.head (List.nth (Syntax.children field) 4) = Some name) fields |> List.length in
  Printf.printf "%s %d\n" name count) ["bool"; "int"; "float"; "text"; "choice"];;
OCAML
```

### All target declarations

| Node | Fields b/i/f/t/c | Vec3 groups | Slots | Description fields | Encoded kinds | Record validation |
| --- | --- | ---: | --- | ---: | --- | --- |
| `noise_displace` | 1/1/2/0/1 | 0 | in0:required | 0 | — | — |
| `match_axis` | 0/0/6/0/0 | 2 | in0:required | 0 | — | — |
| `transform` | 3/0/35/1/4 | 5 | in0:required | 0 | — | yes |
| `match_size` | 6/0/16/3/5 | 5 | input:required, target:optional | 0 | — | yes |
| `peak` | 2/0/1/3/1 | 0 | in0:required | 0 | — | yes |
| `mountain` | 2/2/9/4/1 | 2 | in0:required | 0 | — | yes |
| `bend` | 4/0/12/3/1 | 3 | in0:required | 0 | — | yes |
| `snap_to_grid` | 2/0/7/5/3 | 2 | in0:required | 2 | — | yes |
| `point_jitter` | 1/1/4/3/1 | 1 | in0:required | 0 | — | yes |
| `rest_position` | 0/0/0/3/2 | 0 | input:required, reference:optional | 0 | — | yes |
| `distance_from_target` | 0/0/7/3/5 | 2 | in0:required | 0 | — | yes |
| `uv_project` | 2/0/20/2/1 | 5 | in0:required | 0 | — | yes |
| `uv_transform` | 0/0/7/2/1 | 0 | in0:required | 0 | — | yes |
| `attr_from_image` | 0/0/0/2/1 | 0 | geometry:required, image:required:image | 0 | — | yes |
| `attribute_noise` | 1/2/17/3/5 | 4 | in0:required | 0 | — | yes |
| `attribute_noise_quaternion` | 0/2/3/4/1 | 1 | in0:required | 0 | — | yes |
| `attribute_remap` | 0/0/16/4/4 | 4 | in0:required | 1 | — | yes |
| `attribute_randomize` | 4/2/26/8/5 | 5 | in0:required | 0 | — | yes |
| `attribute_composite` | 1/0/5/6/1 | 0 | input:required, layer1:optional, layer2:optional, layer3:optional, layer4:optional, layers:optional-rest | 0 | — | yes |
| `attribute_fade` | 1/0/6/6/0 | 0 | input:required, start_source:optional, hold_source:optional | 2 | — | yes |
| `color_by_height` | 0/8/0/0/0 | 0 | in0:required | 0 | — | yes |
| `measure` | 0/0/0/3/2 | 0 | in0:required | 0 | — | — |
| `set_float` | 0/0/1/1/1 | 0 | in0:required | 0 | — | yes |
| `set_int` | 0/1/0/1/1 | 0 | in0:required | 0 | — | yes |
| `set_vector` | 0/0/3/1/1 | 1 | in0:required | 0 | — | yes |
| `set_orient` | 0/0/4/0/0 | 0 | in0:required | 0 | — | yes |
| `set_color` | 0/0/4/1/1 | 1 | in0:required | 0 | — | yes |
| `set_transform` | 0/0/16/0/0 | 0 | in0:required | 0 | — | yes |
| `swap_attributes` | 0/0/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `delete_attributes` | 1/0/0/4/0 | 0 | input:required, reference:optional | 0 | — | yes |
| `rename_attributes` | 0/0/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `delete_edge_group` | 0/0/0/1/0 | 0 | in0:required | 0 | — | — |
| `rename_edge_group` | 0/0/0/2/0 | 0 | in0:required | 0 | — | — |
| `group_delete` | 1/0/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `group_rename` | 0/0/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `group_combine` | 1/0/0/3/1 | 0 | in0:required | 0 | steps_parameter | — |
| `group_invert` | 0/0/0/2/2 | 0 | in0:required | 0 | — | — |
| `group_random` | 1/1/1/3/2 | 0 | in0:required | 0 | — | — |
| `group_bounds` | 0/0/7/2/4 | 2 | in0:required | 0 | — | — |
| `group_non_planar` | 0/0/1/2/1 | 0 | in0:required | 0 | — | — |
| `group_backface` | 0/0/3/2/1 | 1 | in0:required | 0 | — | — |
| `ordered_group` | 0/0/0/2/1 | 0 | in0:required | 0 | elements_parameter | yes |
| `groups_from_name` | 0/2/0/2/3 | 0 | in0:required | 0 | — | — |
| `name_from_groups` | 1/0/0/3/2 | 0 | in0:required | 0 | — | — |
| `material` | 0/0/7/2/0 | 2 | in0:required | 0 | — | — |
| `line` | 0/1/7/0/1 | 2 | — | 0 | — | — |
| `points` | 0/1/0/3/0 | 0 | — | 0 | — | yes |
| `circle` | 1/1/16/0/4 | 3 | — | 0 | — | yes |
| `grid` | 0/2/13/1/5 | 3 | — | 0 | — | yes |
| `box` | 1/3/10/2/3 | 3 | — | 0 | — | — |
| `uv_sphere` | 2/2/14/1/8 | 4 | — | 0 | — | yes |
| `torus` | 4/2/16/1/5 | 3 | — | 0 | — | yes |
| `tube` | 2/2/13/2/5 | 3 | — | 0 | — | yes |
| `platonic` | 0/0/10/1/4 | 3 | — | 0 | — | yes |
| `spiral` | 1/2/19/8/6 | 3 | — | 2 | — | yes |
| `bound` | 0/5/7/4/2 | 2 | in0:required | 0 | — | yes |
| `merge` | 0/1/0/1/0 | 0 | input:rest | 0 | — | — |
| `mirror` | 1/0/6/0/0 | 2 | in0:required | 0 | — | — |
| `duplicate` | 2/1/16/2/0 | 0 | in0:required | 0 | — | yes |
| `copy_to_points` | 1/0/0/4/0 | 0 | source:required, targets:required | 1 | — | yes |
| `reverse` | 0/1/0/1/1 | 0 | in0:required | 0 | — | — |
| `sort` | 2/3/3/3/2 | 0 | in0:required | 0 | — | — |
| `blast` | 2/0/0/1/2 | 0 | in0:required | 0 | — | — |
| `blast_by_attribute` | 2/0/5/3/3 | 0 | in0:required | 0 | — | yes |
| `compact_points` | 0/0/0/0/0 | 0 | in0:required | 0 | — | — |
| `rewire_vertices` | 3/0/0/3/2 | 0 | in0:required | 0 | — | yes |
| `ends` | 0/0/0/1/1 | 0 | in0:required | 0 | — | — |
| `resample` | 3/1/1/7/0 | 0 | in0:required | 0 | — | yes |
| `revolve` | 2/1/8/3/2 | 2 | in0:required | 0 | — | yes |
| `sweep` | 4/0/3/5/2 | 0 | backbone:required, cross_section:required | 0 | — | yes |
| `sweep_circle` | 9/4/8/13/0 | 0 | in0:required | 0 | — | yes |
| `polywire` | 9/4/8/13/0 | 0 | in0:required | 0 | — | yes |
| `point_generate` | 2/2/1/8/1 | 0 | in0:required | 0 | — | yes |
| `point_replicate` | 6/3/25/8/2 | 6 | input:required, custom_shape:optional | 0 | — | yes |
| `scatter` | 3/2/0/9/1 | 0 | in0:required | 0 | — | yes |
| `extract_point_from_curve` | 1/0/1/8/1 | 0 | in0:required | 0 | — | yes |
| `extract_centroid` | 0/0/0/3/2 | 0 | in0:required | 0 | — | yes |
| `separate_pieces` | 0/0/4/2/2 | 1 | in0:required | 0 | — | — |
| `enumerate` | 0/2/0/4/3 | 0 | in0:required | 0 | — | yes |
| `group_copy` | 2/0/0/1/1 | 0 | source:required, target:required | 0 | rules_parameter | — |
| `blend_shapes` | 0/0/4/6/3 | 0 | input:required, shape1:optional, shape2:optional, shape3:optional, shape4:optional, shapes:optional-rest | 0 | — | yes |
| `point_velocity` | 1/0/8/5/3 | 2 | input:required, previous:optional, next:optional | 0 | — | yes |
| `attribute_interpolate` | 3/0/3/13/4 | 0 | source:required, target:required | 0 | — | yes |
| `edge_transport_curves` | 2/0/0/2/5 | 0 | in0:required | 0 | — | yes |
| `iso_surface` | 1/0/10/0/0 | 3 | field:required:fn(vec3)->float | 0 | — | yes |
| `connectivity` | 0/0/0/6/2 | 0 | in0:required | 0 | — | yes |
| `normals` | 2/0/1/2/3 | 0 | in0:required | 0 | — | yes |
| `attribute_blur` | 1/1/5/4/2 | 0 | in0:required | 0 | — | yes |
| `smooth` | 1/1/5/5/3 | 0 | in0:required | 0 | — | yes |
| `attribute_laplacian` | 1/0/0/3/1 | 0 | in0:required | 0 | — | yes |
| `measure_curvature` | 0/1/1/7/1 | 0 | in0:required | 0 | — | yes |
| `polyframe` | 2/0/0/5/2 | 0 | in0:required | 0 | — | yes |
| `edge_relax` | 1/1/2/2/2 | 0 | source:required, reference:required | 0 | — | yes |
| `edge_equalize` | 0/1/1/2/1 | 0 | in0:required | 0 | — | yes |
| `edge_straighten` | 0/0/0/2/0 | 0 | in0:required | 0 | — | — |
| `circle_from_edges` | 1/0/4/2/0 | 1 | in0:required | 0 | — | yes |
| `crease` | 1/0/1/1/1 | 0 | in0:required | 0 | — | — |
| `edge_divide` | 1/1/0/1/0 | 0 | in0:required | 0 | — | — |
| `edge_cusp` | 1/0/0/1/0 | 0 | in0:required | 0 | — | — |
| `point_split` | 1/0/1/2/1 | 0 | in0:required | 0 | — | yes |
| `convert_line` | 4/0/1/2/0 | 0 | in0:required | 0 | — | — |
| `uv_auto_seam` | 2/0/2/5/0 | 0 | in0:required | 0 | — | yes |
| `uv_unitize` | 1/0/1/3/1 | 0 | in0:required | 0 | — | — |
| `promote_attributes` | 1/0/0/4/3 | 0 | in0:required | 0 | — | yes |
| `attribute_copy` | 1/0/0/8/2 | 0 | source:required, target:required | 0 | — | yes |
| `group_edges` | 4/0/4/2/2 | 0 | in0:required | 0 | — | — |
| `group_unshared` | 0/0/0/1/2 | 0 | in0:required | 0 | — | — |
| `group_edge_depth` | 0/1/0/2/1 | 0 | in0:required | 0 | — | — |
| `group_expand` | 5/1/2/6/4 | 0 | in0:required | 0 | boundary_attributes_parameter | yes |
| `group_boundary_components` | 0/2/0/1/1 | 0 | in0:required | 0 | — | — |
| `group_from_attribute_boundary` | 3/0/1/2/1 | 0 | in0:required | 0 | boundary_attributes_parameter | — |
| `group_promote_boundary` | 4/0/1/4/2 | 0 | in0:required | 0 | boundary_attributes_parameter | — |
| `group_promotions` | 0/2/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `group_normal` | 2/0/4/3/2 | 1 | in0:required | 0 | — | yes |
| `group_range` | 6/10/1/4/5 | 0 | in0:required | 0 | — | — |
| `group_ranges` | 0/0/0/1/0 | 0 | in0:required | 0 | rules_parameter | — |
| `distance_along_geometry` | 0/0/1/4/4 | 0 | in0:required | 0 | — | yes |
| `edge_transport` | 2/0/0/3/7 | 0 | in0:required | 0 | — | yes |
| `edge_transport_parent` | 2/0/0/3/6 | 0 | in0:required | 0 | — | yes |
| `group_find_path` | 2/0/0/3/3 | 0 | in0:required | 0 | — | — |
| `graph_color` | 2/0/0/4/2 | 0 | in0:required | 0 | — | yes |
| `poly_path` | 3/0/1/0/0 | 0 | in0:required | 0 | — | — |
| `carve` | 5/1/2/3/2 | 0 | in0:required | 0 | — | yes |
| `poly_bridge` | 5/2/1/3/2 | 0 | in0:required | 0 | — | yes |
| `poly_loft` | 5/0/1/2/1 | 0 | input:required, rest:optional | 0 | — | yes |
| `skin` | 5/0/1/2/1 | 0 | input:required, rest:optional | 0 | — | yes |
| `edge_flip` | 2/1/0/1/0 | 0 | in0:required | 0 | — | — |
| `subdivide` | 5/1/2/4/7 | 0 | input:required, creases:optional | 0 | — | yes |

## Port and measurement ledger

No nodes have completed their full Verification gate in this ledger yet.
Do not fill timings, run counts, render parity or domain equality from estimates.
Each accepted row must cite the command and fixture, machine/domain setup,
OCaml/Lisp times and validation result before its plan checkbox is marked.

| Node | CPU oracle gate | 1/8 domains | Cache/refusals/UI | Native goldens | OCaml/Lisp time at 1,000,000 | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `noise_displace` pilot | Pending new port gate | Pending | Pending | Pending | Unmeasured | Not ported |

## Moves and blocked modes

| Found during | Prerequisite / move | Gate status |
| --- | --- | --- |
| A.6 pilot audit | `sop/context_seed` exposes the cook's keyed seed inside a Lisp body, preserving its Seed context dependency. Parameter validators reject context seed directly or through a helper. | Direct/helper context and checker/IR regressions passed in session 93829; full production pilot gate pending. |
| A.6 pilot audit | Owner/pattern `sop/delete_attr` advances the subset of B.6 required to invalidate point and vertex N after displacement. | Both pilot modes passed session 60089; production switch pending and B.6 remains incomplete. |

## A.6 pilot performance evidence

Quiet benchmark session 59246 exited 0 on Apple M1, OCaml 5.3.0, one million
points and grain 4096. From `lib/sop`, the command was
`opam exec -- ../../_build/default/lib/sop/test_lisp_ports.exe --bench`.
Each reported time is the median of three cold cooks using fresh sessions.
Four-domain allocation counts cover only the main domain.

| Mode and controls | Domains | OCaml seconds | Lisp seconds | Lisp / OCaml | OCaml allocated bytes | Lisp allocated bytes |
| --- | --- | --- | --- | --- | --- | --- |
| Normal 3D, amplitude 0.8, frequency 0.16 | 1 | 0.028841 | 0.032618 | 1.131 | 24,107,808 | 25,705,352 |
| Normal 3D, amplitude 0.8, frequency 0.16 | 4 | 0.008391 | 0.009430 | 1.124 | 24,131,664 | 24,476,824 |
| Default height 2D, amplitude 0.1, frequency 1 | 1 | 0.014198 | 0.020069 | 1.414 | 8,078,088 | 9,686,600 |
| Default height 2D, amplitude 0.1, frequency 1 | 4 | 0.004773 | 0.006412 | 1.343 | 8,132,456 | 8,554,072 |

Both complete modes are below the plan's 2× cook-time threshold. This is pilot
evidence before the production registration switch; it does not complete A.6
or A.R's shipping checks.

## Phase A integration audit

The audit found that library injection crossed the authored-source boundary on
literal edits and that structural edits used the generic checker. The fixes
below are implemented. Focused source, editor and catalog checks passed; the
production-pilot save gate and shipping checks remain pending.

| Path / invariant | Current finding | Required evidence |
| --- | --- | --- |
| Embedded definitions stay out of saved user files | `Catalog.check_workspace` restores authored `checked.source` after checking the injected library. | `test_workspace_source.run_embedded_nodes` checks literal scrubbing, structural notes, atomic save and reopen without embedded definitions. Run after the production pilot source lands. |
| Gestures keep the library available | `Flow_edit.apply_checked` accepts a checker callback for branch defaults and every candidate; `Workspace_doc` supplies `Catalog.check_workspace`. | `test_node_sources` checks a library-backed structural edit and printed-source reopen. `@lib/flow_sop/runtest @lib/flow_graph/runtest` exited 0 (session 91419). |
| Body identity survives authored-source restoration | `Lower` hashes authored forms plus checked definition, macro and node-body forms. | `test_node_sources` keeps authored text and public node ID unchanged while changing the injected body or an embedded macro helper, and requires changed output with exactly one public cache miss. Lowering/graph gate exited 0 (sessions 91419 and 73414). |
| Helper context dependencies use lexical scope | `Context_kernel.depends` binds helper formal names to actual scalar arguments, tracks sequential aliases, and removes function/loop/state binders from inherited known values. Unknown branches are scanned conservatively. | `test_node_sources` covers nested helper calls with an outer boolean of the same name, active/inactive helper branches and function-local names. An active seed helper changes output and causes exactly one public miss across context seeds; an inactive helper retains its hit. Checker/lowering/IR gate exited 0 (session 93829). |
| Embedded helpers stay out of editable navigation | Navigator filters checked defns/macros by authored top-level form IDs, including the search view, while lowering retains them. | `test_workspace_source.run_library_navigation` checks normal/search rows hide injected helpers while retaining authored definitions. Refreshed dummy-driver editor gate passed (session 16558). |
| Local declaration completions follow the document | Shared vocabulary refresh compares operator and declaration schema identities on install, history/preset reduction and carry document adoption. Scalar scrubs reuse the same lazy vocabulary. | Actual editor reload/add/remove/schema changes and reducer undo/redo pass in `@test/test_workspace_vocabulary` (sessions 97286 and 16558). |
| Catalog/menu inventory survives registration removal | Catalog tests assemble the native and lowered Lisp factory lists, keeping the existing total-key, metadata, disconnected-instance and cache perturbation assertions. | Combined registry test passed before the production switch (sessions 97286 and 16558); repeat after the switch. |
| Typed function libraries remain inspectable before connection | Default factories without a checked callable retain operation/schema identity and report `disconnected_input` on cook. Instantiated calls derive their facts and packed bodies from the actual function. | `test_node_sources` checks native keyword-Fn delegation, typed vec3-map calls, default factory catalog introspection, disconnected identity/schema and typed unbound cook refusal. Refreshed lowering/graph gate exited 0 after these checks. |

The A.4 and A.5 passing sessions above predate these source-boundary fixes;
their integration gates must run again before A.R is complete. Combined
`@lib/flow_sop/runtest @lib/flow_graph/runtest` sessions 77216 and 79773 exited 1
on the ongoing A.3 function-capture regression; they are not passing evidence
for the phase review.
The later session 91419 passed both focused aliases, including the new body
cache, source/edit and keyword function/image manifest regressions. The actual
embedded-pilot save gate and the catalog/editor checks after registration
removal remain pending. The refreshed editor/navigation/vocabulary and
dependency gate passed before that switch in session 16558.

No node classification move has been accepted yet. The known array-valued
attribute, `next_after`, `fma`, encoded-decoder and partial-subdivide requirements
above must be resolved by implementation or an explicit recorded move. They are
scope requirements, not evidence that a node has been completed.
