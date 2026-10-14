(* sop/attribute_randomize: one geometry input. The standard fixtures carry float/vec2/vec3/vec4 and
   integer attributes on every owner (existing targets, seed attribute). The last two fixtures also
   carry fraction attributes frac1..frac4 (strictly inside (0,1): the exact 0/1 quantile tails give
   native infinities, which a Lisp kernel cannot produce) and a detail float. *)
open Rdk
open Rdk_test_support
open Port_gate
module P = Param
let i n = P.Int_value n
let s v = P.Text_value v
let c v = P.Choice_value v
let b v = P.Bool_value v
let f v = P.Float_value v

let decorate geometry =
  let g = fixture_groups geometry in
  let g = List.fold_left (fun g owner ->
    let n = match owner with Attribute.Point -> Geometry.point_count g | Vertex -> Geometry.vertex_count g
      | Primitive -> Geometry.primitive_count g | Detail -> 1 in
    let unit_plane scale = Array.init n (fun k -> 0.05 +. float ((k * 7) mod 19) *. scale) in
    let add name storage g = Geometry.with_attribute (Attribute.create_owned ~owner ~name storage |> get_string_ok) g
      |> get_string_ok in
    g |> add "frac1" (Attribute.Float (unit_plane 0.05))
      |> add "frac2" (Attribute.Float2 (Packed.Float2.of_owned ~x:(unit_plane 0.05) ~y:(unit_plane 0.04) |> get_string_ok))
      |> add "frac3" (Attribute.Float3 (Packed.Float3.of_owned ~x:(unit_plane 0.05) ~y:(unit_plane 0.04) ~z:(unit_plane 0.03) |> get_string_ok))
      |> add "frac4" (Attribute.Float4 (Packed.Float4.of_owned ~x:(unit_plane 0.05) ~y:(unit_plane 0.04) ~z:(unit_plane 0.03)
           ~w:(unit_plane 0.02) |> get_string_ok))
      |> add "ids" (Attribute.Int (Array.init n (fun k -> (k * 5) mod 11))))
    g [Attribute.Point; Vertex; Primitive; Detail] in
  g
let grid_of connectivity columns rows = Plane_generators.grid ~connectivity ~columns ~rows ~size:6. () |> get_ok
let inputs = List.map (fun (l, gs) -> l, List.map fixture_groups gs) standard_inputs
  @ [ "frac-triangles", [decorate (grid_of Grid_triangles 5 4)];
      "frac-quads", [decorate (grid_of Grid_quads 6 5)] ]

let kinds = ["Scalar", "float", 1; "Vector 2", "vec2", 2; "Vector 3", "vec3", 3; "Vector 4", "vec4", 4]
let a4 = ["a_x", f (-1.); "a_y", f 0.5; "a_z", f (-0.25); "a_w", f 2.]
let b4 = ["b_x", f 2.; "b_y", f 1.5; "b_z", f 0.75; "b_w", f 3.]
let distributions =
  [ "Constant", a4;
    "Two values", a4 @ b4 @ ["probability_b", f 0.4];
    "Uniform", a4 @ b4;
    "Uniform discrete", a4 @ b4 @ ["step_x", f 0.5; "step_y", f 0.25; "step_z", f 0.2; "step_w", f 1.];
    "Normal", ["a_x", f 1.; "a_y", f (-1.); "a_z", f 0.5; "a_w", f 0.] @ ["b_x", f 0.5; "b_y", f 0.25; "b_z", f 2.; "b_w", f 0.];
    "Exponential", ["a_x", f 1.5; "a_y", f 0.5; "a_z", f 3.; "a_w", f 1.];
    "Log normal", ["a_x", f 1.5; "a_y", f 0.5; "a_z", f 3.; "a_w", f 1.] @ ["b_x", f 0.5; "b_y", f 0.; "b_z", f 1.; "b_w", f 0.25];
    "Cauchy", ["a_x", f 0.5; "a_y", f 1.; "a_z", f (-1.); "a_w", f 0.] @ ["b_x", f 0.3; "b_y", f 0.3; "b_z", f 0.3; "b_w", f 0.3];
    "Direction", ["a_x", f 0.; "a_y", f 1.; "a_z", f 0.; "a_w", f 0.] @ ["cone_angle", f 0.6];
    "Inside sphere cone", ["a_x", f 1.; "a_y", f 2.; "a_z", f (-0.5); "a_w", f 0.5] @ ["cone_angle", f 1.1];
    "Custom ramp", a4 @ b4 @ ["ramp", s "0:0,0.25:0.9,0.6:0.3,1:1"];
    "Custom discrete", [] ]
let entries_for dims = String.concat "\n" (List.map (fun (k, w) ->
  String.concat "\t" (List.init dims (fun d -> string_of_float (float (k + d) *. 0.5)) @ [string_of_float w]))
  [0, 1.; 1, 0.; 2, 2.5; 3, 1.])
let triage = Sys.getenv_opt "RANDOMIZE_TRIAGE" <> None
let cases_all =
  let base_dist name changes kind = ("distribution", c name) :: ("kind", c kind) :: changes in
  List.concat_map (fun (distribution, changes) ->
    List.concat_map (fun (kind, attribute, dims) ->
      let usable = not (List.mem distribution ["Direction"; "Inside sphere cone"]) || dims >= 2 in
      let changes = if distribution = "Custom discrete" then ["entries", s (entries_for dims)] else changes in
      if not usable then [] else
      let label what = Printf.sprintf "%s/%s/%s" distribution kind what in
      let dist = base_dist distribution changes kind in
      [ label "new", dist;
        label "seed", dist @ ["seed", i 7];
        label "named", dist @ ["name", s attribute; "operation", c "Set"];
        label "add", dist @ ["name", s attribute; "operation", c "Add"];
        label "minimum", dist @ ["name", s attribute; "operation", c "Minimum"];
        label "maximum", dist @ ["name", s attribute; "operation", c "Maximum"];
        label "multiply", dist @ ["name", s attribute; "operation", c "Multiply"; "scale", f (-1.5)];
        label "group", dist @ ["name", s attribute; "group", s "a"];
        label "typed group", dist @ ["name", s attribute; "selection_owner", c "Primitive"; "selection_group", s "dest_a"];
        label "limits", dist @ ["use_minimum", b true; "minimum", f (-0.2); "use_maximum", b true; "maximum", f 0.8];
        label "minimum only", dist @ ["use_minimum", b true; "minimum", f 0.1];
        label "maximum only", dist @ ["use_maximum", b true; "maximum", f 0.3];
        label "vector limits", dist @ ["use_minimum", b true; "use_maximum", b true; "use_vector_limits", b true;
          "minimum_vector_x", f (-0.5); "minimum_vector_y", f 0.1; "minimum_vector_z", f (-0.7); "minimum_w", f 0.2;
          "maximum_vector_x", f 0.6; "maximum_vector_y", f 0.9; "maximum_vector_z", f 0.4; "maximum_w", f 1.5];
        label "fraction", dist @ ["fraction_attribute", s (Printf.sprintf "frac%d" (match distribution with
          | "Two values" | "Custom discrete" -> 1
          | "Direction" -> dims - 1 | "Inside sphere cone" -> dims | _ -> dims))];
        label "seed attribute", dist @ ["seed_attribute", s "ids"];
        label "vertex", dist @ ["owner", c "Vertex"; "name", s attribute] ]) kinds)
    distributions
  @ List.concat_map (fun dimensions ->
      let kind = (match dimensions with 2 -> "Vector 2" | 3 -> "Vector 3" | _ -> "Vector 4") in
      let attribute = (match dimensions with 2 -> "vec2" | 3 -> "vec3" | _ -> "vec4") in
      let dist = ["distribution", c "Inside sphere"; "dimensions", i dimensions; "kind", c kind] in
      [ Printf.sprintf "sphere %d" dimensions, dist;
        Printf.sprintf "sphere %d named" dimensions, dist @ ["name", s attribute; "operation", c "Add"];
        Printf.sprintf "sphere %d fraction" dimensions, dist @ ["fraction_attribute", s (Printf.sprintf "frac%d" dimensions)];
        Printf.sprintf "sphere %d seed" dimensions, dist @ ["seed", i 3; "scale", f 2.] ]) [2; 3; 4]
  @ List.concat_map (fun (label, changes) -> [ "dir/" ^ label, changes ]) (
      let direction kind extra = ["distribution", c "Direction"; "kind", c kind] @ extra in
      [ "2d", direction "Vector 2" ["a_x", f 1.; "a_y", f 1.; "cone_angle", f 1.2];
        "2d bias", direction "Vector 2" ["a_x", f 1.; "a_y", f 1.; "cone_angle", f 1.2; "direction_bias", f 0.5];
        "2d negative bias", direction "Vector 2" ["a_x", f 1.; "a_y", f 1.; "cone_angle", f 1.2; "direction_bias", f (-0.4)];
        "2d zero cone", direction "Vector 2" ["a_x", f 1.; "a_y", f 1.; "cone_angle", f 0.];
        "2d full", direction "Vector 2" ["a_x", f 1.; "a_y", f 1.; "cone_angle", f 3.141592653589793];
        "3d", direction "Vector 3" ["a_x", f 0.2; "a_y", f 1.; "a_z", f (-0.3); "cone_angle", f 0.9];
        "3d bias", direction "Vector 3" ["a_x", f 0.2; "a_y", f 1.; "a_z", f (-0.3); "cone_angle", f 0.9; "direction_bias", f 2.];
        "3d zero", direction "Vector 3" ["a_x", f 0.2; "a_y", f 1.; "a_z", f (-0.3); "cone_angle", f 0.];
        "3d full", direction "Vector 3" ["a_x", f 0.2; "a_y", f 1.; "a_z", f (-0.3); "cone_angle", f 3.141592653589793];
        "3d fraction", direction "Vector 3" ["a_x", f 0.2; "a_y", f 1.; "a_z", f (-0.3); "fraction_attribute", s "frac2"];
        "4d", direction "Vector 4" ["a_x", f 0.2; "a_y", f 1.; "a_z", f (-0.3); "a_w", f 0.4; "cone_angle", f 1.5];
        "4d bias", direction "Vector 4" ["a_x", f 0.2; "a_y", f 1.; "a_z", f (-0.3); "a_w", f 0.4; "cone_angle", f 1.5; "direction_bias", f 0.7];
        "4d full", direction "Vector 4" ["a_x", f 0.2; "a_y", f 1.; "a_z", f (-0.3); "a_w", f 0.4; "cone_angle", f 3.141592653589793];
        "4d orientation", direction "Vector 4" ["a_x", f 0.2; "a_y", f 1.; "a_z", f (-0.3); "a_w", f 0.4; "cone_angle", f 5.];
        "4d zero", direction "Vector 4" ["a_x", f 0.2; "a_y", f 1.; "a_z", f (-0.3); "a_w", f 0.4; "cone_angle", f 0.];
        "bias on uniform", ["direction_bias", f 0.5];
        "bias too low", direction "Vector 3" ["a_y", f 1.; "direction_bias", f (-1.)];
        "scalar", direction "Scalar" [];
        "zero axis", direction "Vector 3" ["a_x", f 0.; "a_y", f 0.; "a_z", f 0.];
        "cone range", direction "Vector 3" ["a_y", f 1.; "cone_angle", f 3.2] ])
  @ [ (* ---- text, tables and cauchy ---- *)
      "text", ["distribution", c "Custom discrete text"];
      "text group", ["distribution", c "Custom discrete text"; "group", s "a"; "name", s "label"];
      "text fraction", ["distribution", c "Custom discrete text"; "fraction_attribute", s "frac1"];
      "text entries", ["distribution", c "Custom discrete text"; "text_entries", s "x\t0.5\ny\t1.5\nz\t0\nw\t2"; "seed", i 9];
      "text zero tail", ["distribution", c "Custom discrete text"; "text_entries", s "x\t1\ny\t0"; "seed", i 2];
      "text existing", ["distribution", c "Custom discrete text"; "name", s "text"; "seed", i 4];
      "text existing wrong", ["distribution", c "Custom discrete text"; "name", s "float"];
      "text add", ["distribution", c "Custom discrete text"; "operation", c "Add"];
      "text scale", ["distribution", c "Custom discrete text"; "scale", f 2.];
      "text limit", ["distribution", c "Custom discrete text"; "use_minimum", b true];
      "text P", ["distribution", c "Custom discrete text"; "name", s "P"];
      "text bad weights", ["distribution", c "Custom discrete text"; "text_entries", s "x\t0\ny\t0"];
      "text bad row", ["distribution", c "Custom discrete text"; "text_entries", s "x\ty\t1"];
      "discrete bad", ["distribution", c "Custom discrete"; "entries", s "1\t0"];
      "discrete width", ["distribution", c "Custom discrete"; "kind", c "Vector 2"];
      "ramp bad", ["distribution", c "Custom ramp"; "ramp", s "0:0,0.5:1"];
      "ramp short", ["distribution", c "Custom ramp"; "ramp", s "0:1"];
      "ramp order", ["distribution", c "Custom ramp"; "ramp", s "0:0,0.7:1,0.5:2,1:3"];
      "ramp blank", ["distribution", c "Custom ramp"; "ramp", s " "];
      "ramp padded", ["distribution", c "Custom ramp"; "ramp", s " 0 : 0 , 1 : 4 "];
      "cauchy 2d", ["distribution", c "Cauchy"; "kind", c "Vector 2"; "b_x", f 0.2; "b_y", f 0.2];
      "cauchy 3d", ["distribution", c "Cauchy"; "kind", c "Vector 3"; "b_x", f 0.2; "b_y", f 0.2; "b_z", f 0.2];
      "cauchy 4d", ["distribution", c "Cauchy"; "kind", c "Vector 4"; "b_x", f 0.2; "b_y", f 0.2; "b_z", f 0.2; "b_w", f 0.2];
      "cauchy 2d fraction", ["distribution", c "Cauchy"; "kind", c "Vector 2"; "b_x", f 0.2; "b_y", f 0.2; "fraction_attribute", s "frac2"];
      "cauchy 3d fraction", ["distribution", c "Cauchy"; "kind", c "Vector 3"; "b_x", f 0.2; "b_y", f 0.2; "b_z", f 0.2; "fraction_attribute", s "frac3"];
      "cauchy 4d fraction", ["distribution", c "Cauchy"; "kind", c "Vector 4"; "b_x", f 0.2; "b_y", f 0.2; "b_z", f 0.2; "b_w", f 0.2; "fraction_attribute", s "frac4"];
      "cauchy anisotropic", ["distribution", c "Cauchy"; "kind", c "Vector 2"; "b_x", f 0.2; "b_y", f 0.3];
      "cauchy negative scale", ["distribution", c "Cauchy"; "b_x", f (-0.1)] ]
  @ [ (* ---- targets, groups, seeds, errors ---- *)
      "P", ["distribution", c "Uniform"; "kind", c "Vector 3"; "name", s "P"];
      "P add", ["distribution", c "Normal"; "kind", c "Vector 3"; "name", s "P"; "operation", c "Add"; "scale", f 0.1];
      "P scalar", ["name", s "P"];
      "P group", ["kind", c "Vector 3"; "name", s "P"; "group", s "a"; "operation", c "Add"];
      "detail", ["owner", c "Detail"; "name", s "dfloat"];
      "detail new", ["owner", c "Detail"; "name", s "total"; "distribution", c "Normal"];
      "detail group", ["owner", c "Detail"; "group", s "a"];
      "detail selection", ["owner", c "Detail"; "selection_group", s "a"];
      "both groups", ["group", s "a"; "selection_group", s "a"];
      "primitive owner", ["owner", c "Primitive"; "name", s "float"; "operation", c "Add"];
      "vertex owner group", ["owner", c "Vertex"; "group", s "dest_a"];
      "point typed vertex", ["selection_owner", c "Vertex"; "selection_group", s "a"];
      "point typed edge", ["selection_owner", c "Edge"; "selection_group", s "dest_a"];
      "primitive typed point", ["owner", c "Primitive"; "selection_owner", c "Point"; "selection_group", s "old_x"];
      "missing group", ["group", s "nope"];
      "missing typed group", ["selection_group", s "nope"];
      "blank name", ["name", s "  "];
      "context seed", ["context_seed", b true];
      "context seed fraction", ["context_seed", b true; "fraction_attribute", s "frac1"];
      "seed big", ["seed", i 9999];
      "seed negative", ["seed", i (-3)];
      "seed attribute integer", ["seed_attribute", s "integer"];
      "seed attribute missing", ["seed_attribute", s "nope"];
      "seed attribute float", ["seed_attribute", s "float"];
      "seed attribute ignored", ["seed_attribute", s "float"; "fraction_attribute", s "frac1"];
      "fraction missing", ["fraction_attribute", s "nope"];
      "fraction wrong width", ["fraction_attribute", s "frac2"];
      "fraction int", ["fraction_attribute", s "ids"];
      "fraction out of range", ["fraction_attribute", s "float"];
      "fraction uniform", ["kind", c "Vector 4"; "fraction_attribute", s "frac4"; "name", s "vec4"; "operation", c "Add"];
      "fraction normal", ["distribution", c "Normal"; "fraction_attribute", s "frac1"; "a_x", f 1.; "b_x", f 2.];
      "fraction exponential", ["distribution", c "Exponential"; "fraction_attribute", s "frac1"; "a_x", f 2.];
      "fraction lognormal", ["distribution", c "Log normal"; "fraction_attribute", s "frac1"; "a_x", f 2.; "b_x", f 1.];
      "fraction discrete", ["distribution", c "Uniform discrete"; "fraction_attribute", s "frac1"; "b_x", f 4.; "step_x", f 0.5];
      "existing wrong storage", ["name", s "integer"];
      "existing wrong dimension", ["name", s "vec3"];
      "existing text", ["name", s "text"];
      "existing in group", ["name", s "float"; "operation", c "Maximum"; "group", s "old_x"];
      "order check", ["distribution", c "Uniform"; "a_x", f 1.; "b_x", f 0.];
      "discrete step", ["distribution", c "Uniform discrete"; "step_x", f 0.];
      "normal negative", ["distribution", c "Normal"; "b_x", f (-1.)];
      "exponential zero", ["distribution", c "Exponential"; "a_x", f 0.];
      "lognormal zero", ["distribution", c "Log normal"; "a_x", f 0.];
      "lognormal overflow", ["distribution", c "Log normal"; "a_x", f 1e-200; "b_x", f 1e200];
      "limit dimension", ["kind", c "Vector 2"; "use_minimum", b true; "distribution", c "Inside sphere"; "dimensions", i 3];
      "limits ordered", ["use_minimum", b true; "use_maximum", b true; "minimum", f 1.; "maximum", f 0.];
      "limits vector ordered", ["kind", c "Vector 2"; "use_minimum", b true; "use_maximum", b true; "use_vector_limits", b true;
        "minimum_vector_x", f 1.; "maximum_vector_x", f 0.];
      "overflow", ["distribution", c "Constant"; "a_x", f 1e200; "operation", c "Multiply"; "name", s "float"; "scale", f 10.] ]
(* RANDOMIZE_TRIAGE keeps a few variants per distribution so a failing mode is found quickly. *)
let skipped = ["Cauchy/Vector 3/fraction"; "Cauchy/Vector 4/fraction"]
let cases = if not triage then cases_all else List.filter (fun (label, _) -> not (List.mem label skipped) &&
  let ends suffix = String.length label >= String.length suffix && String.sub label (String.length label - String.length suffix) (String.length suffix) = suffix in
  List.length (String.split_on_char (Char.chr 47) label) < 3 || ends "/new" || ends "/fraction" || ends "/vector limits" || ends "/group") cases_all
let bench () =
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:700 ~rows:700 ~size:8. () |> get_ok in
  [grid], ["distribution", c "Normal"; "kind", c "Vector 3"; "seed", i 5]
let () = register { key = "attribute_randomize"; native = Sop.Nodes.Attribute_randomize.factory; inputs; cases;
  ulps = 4; bench = Some bench }
