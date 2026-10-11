(* core_fixtures.exe OUTDIR writes one JSON file per frame primitive of
   specification/core.md, named after its JavaScript export (tools/web/runtime/prims.js):
   "+" is add.json, "int/mul" is int_mul.json, "equal?" is equal.json.
   Each result is computed by the native body, run through Core_exec.

   File: {"primitive": NAME, "export": NAME, "cases": [CASE ...]}
   CASE: {"static": [JSON...], "args": [VALUE...], "result": VALUE | {"error": {"code","message"}}}
   "static" (only coerce, color/byte, fail) are the leading arguments fixed by
   lowering: call export(...static, ...args). A failure is the code and message
   native raised; compare the code exactly.

   VALUE encoding (lossless, tagged where JSON numbers would be ambiguous):
     Int         {"int": "-123"}        decimal text, always, never a JSON number
     Float       12.5                   JSON number; "-0" is negative zero
                 {"float": "NaN" | "Infinity" | "-Infinity"} when not finite
     Bool        true | false           Text   "string" (UTF-8)
     Vec2/3/4    {"vec": [FLOAT ...]}   List   [VALUE ...]
     Record      {"record": [["name", VALUE] ...]}  in field order
     Packed array {"array": WIDTH, "data": [FLOAT ...]}  interleaved components
     Empty geometry (sequence/build filler) null
   TYPE (coerce): "any" "int" "float" "bool" "text" "vec2" "vec3" "vec4" "other",
     {"list": TYPE}, {"record": [["name", TYPE] ...]}. *)
module C = Flow_ir.Core
module E = Flow.Eval
module P = Flow.Packed_ops
module T = Flow.Ty

let inventory = [
  C.Numeric P.Add; Numeric P.Sub; Numeric P.Mul; Numeric P.Div; Numeric P.Mod; Numeric P.Pow;
  Numeric P.Min; Numeric P.Max; Remainder; Math P.Sin; Math P.Cos; Math P.Sqrt; Exp; Math P.Abs;
  Floor; Ceil; Round; Int_convert; Float_convert;
  Numeric P.Lt; Numeric P.Le; Numeric P.Gt; Numeric P.Ge; Numeric P.Eq; Numeric P.And; Numeric P.Or; Math P.Not;
  Integer C.Mul; Integer C.Div; Integer C.Mod; Integer C.And; Integer C.Xor;
  Equal; Show; Text_concat; Sequence_length; Sequence_get; Sequence_build; Sequence_slice; Sequence_concat;
  Array_range; Array_float; Array_vec3; Array_nth; Array_count; Array_slice; Array_concat;
  Rand; Noise3; Color_parse; Color_byte Clamped; Coerce T.Any; Truthy; Fail ("", "") ]

let export name = match name with
  | "+" -> "add" | "-" -> "sub" | "*" -> "mul" | "/" -> "div" | "<" -> "lt" | "<=" -> "le"
  | ">" -> "gt" | ">=" -> "ge" | "=" -> "eq" | "equal?" -> "equal"
  | _ -> String.map (function '/' -> '_' | c -> c) name

(* ---- JSON ---- *)
let str s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter (function
    | '"' -> Buffer.add_string b "\\\"" | '\\' -> Buffer.add_string b "\\\\"
    | c when Char.code c < 32 -> Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
    | c -> Buffer.add_char b c) s;
  Buffer.add_char b '"'; Buffer.contents b
let seq f xs = "[" ^ String.concat "," (List.map f xs) ^ "]"
let flt x =
  if Float.is_nan x then {|{"float":"NaN"}|}
  else if x = infinity then {|{"float":"Infinity"}|}
  else if x = neg_infinity then {|{"float":"-Infinity"}|}
  else Printf.sprintf "%.17g" x
let rec json : E.value -> string = function
  | Int n -> Printf.sprintf {|{"int":"%d"}|} n
  | Float x -> flt x
  | Bool b -> string_of_bool b
  | Text s -> str s
  | Vec2 (x, y) -> {|{"vec":|} ^ seq flt [x; y] ^ "}"
  | Vec3 (x, y, z) -> {|{"vec":|} ^ seq flt [x; y; z] ^ "}"
  | Vec4 (x, y, z, w) -> {|{"vec":|} ^ seq flt [x; y; z; w] ^ "}"
  | List xs -> seq json (Array.to_list xs)
  | Record fs -> {|{"record":|} ^ seq (fun (n, v) -> "[" ^ str n ^ "," ^ json v ^ "]") fs ^ "}"
  | Float_array d -> packed 1 d | Vec2_array d -> packed 2 d
  | Vec3_array d -> packed 3 d | Vec4_array d -> packed 4 d
  | No_geo -> "null"
  | _ -> failwith "core_fixtures: unsupported value"
and packed w d = Printf.sprintf {|{"array":%d,"data":%s}|} w (seq flt (Array.to_list d))
let rec ty_json : T.t -> string = function
  | Any -> {|"any"|} | Int -> {|"int"|} | Float -> {|"float"|} | Bool -> {|"bool"|} | Text -> {|"text"|}
  | Vec2 -> {|"vec2"|} | Vec3 -> {|"vec3"|} | Vec4 -> {|"vec4"|}
  | List e -> {|{"list":|} ^ ty_json e ^ "}"
  | Record fs -> {|{"record":|} ^ seq (fun (n, t) -> "[" ^ str n ^ "," ^ ty_json t ^ "]") fs ^ "}"
  | _ -> {|"other"|}

(* ---- native evaluation: one assignment through Core_exec ---- *)
let arg_name prim i = match prim, i with
  | C.Integer _, _ | Equal, _ | Remainder, _ -> if i = 0 then "a" else "b"
  | Array_range, _ | Sequence_build, _ -> "count"
  | Array_float, _ | Array_vec3, _ -> if i = 0 then "count" else "value"
  | Array_count, _ -> "array"
  | Array_nth, _ -> if i = 0 then "array" else "index"
  | Exp, _ -> "x"
  | Array_slice, _ -> [|"array"; "first"; "count"|].(i)
  | Array_concat, _ -> if i = 0 then "first" else "second"
  | Sequence_slice, _ -> [|"list"; "first"; "count"|].(i)
  | Noise3, _ -> [|"position"; "seed"; "octaves"|].(i)
  | _ -> Printf.sprintf "x%d" i
let source : C.source = { site = []; owner = []; instance = 0; prefix = []; iter = []; span = None }
let run prim args =
  let n = List.length args in
  let st id node : C.statement = { id; source; node } in
  let program : C.program = {
    constants = Array.of_list (List.map (fun v -> Option.get (C.literal_of_value v)) args);
    locals = Array.make (n + 1) T.Any;
    body = List.mapi (fun i _ -> st i (C.Assign (i, C.Constant i))) args
      @ [st n (C.Assign (n, C.Prim (prim, List.mapi (fun i _ -> arg_name prim i, i) args)))];
    results = [| n |]; state_slots = [||]; regions = [||]; call_slots = 0 } in
  match Flow_ir.Core_exec.run program ~live:(Frame_input.at_time 0.) with
  | Ok v -> json v
  | Error (d : Flow.Diagnostic.t) -> Printf.sprintf {|{"error":{"code":%s,"message":%s}}|} (str d.code) (str d.message)

(* ---- cases ---- *)
let cases : (string, string list ref) Hashtbl.t = Hashtbl.create 64
let add ?(static = []) prim args =
  let name = C.primitive_name prim in
  let r = match Hashtbl.find_opt cases name with
    | Some r -> r | None -> let r = ref [] in Hashtbl.add cases name r; r in
  r := Printf.sprintf {|{"static":%s,"args":%s,"result":%s}|} (seq Fun.id static)
         (seq json args) (run prim args) :: !r

let int n = E.Int n and flt_ x = E.Float x and txt s = E.Text s
let v2 x y = E.Vec2 (x, y) and v3 x y z = E.Vec3 (x, y, z) and v4 x y z w = E.Vec4 (x, y, z, w)
let rec_ fs = E.Record fs
let ints = [0; 1; -1; 2; 3; -3; 7; -7; max_int; min_int; max_int - 1; min_int + 1;
  1 lsl 53; (1 lsl 53) + 1; 1 lsl 61; -(1 lsl 61); 1 lsl 31; 4_000_000_000_000_000_000;
  4_611_686_018_427_387_903 / 3]
let scalars = [int 0; int 7; int (-7); int 3; int max_int; int min_int; int ((1 lsl 53) + 1);
  flt_ 0.; flt_ (-0.); flt_ 2.5; flt_ (-2.5); flt_ 1e300; flt_ nan; flt_ infinity; E.Bool true; txt "x"]
let vectors = [v2 1. 2.; v3 1. 2. 3.; v4 1. 2. 3. 4.; v3 1e308 (-1e308) 0.5]
let unary_samples = [int 0; int 1; int (-1); int 7; int (-7); int max_int; int min_int; int ((1 lsl 53) + 1);
  flt_ 0.; flt_ (-0.); flt_ 0.5; flt_ (-0.5); flt_ 1.5; flt_ 2.5; flt_ (-2.5); flt_ (-2.7);
  flt_ 0.49999999999999994; flt_ 4e18; flt_ (-4e18); flt_ 3.9e18; flt_ 1e19; flt_ 1e300; flt_ nan;
  flt_ infinity; flt_ neg_infinity; flt_ 1e-300; flt_ 710.; flt_ 0.1; flt_ 123456.789;
  E.Bool true; E.Bool false; txt "x"; v3 1. 2. 3.; E.List [||]]
let pairs xs ys = List.concat_map (fun x -> List.map (fun y -> [x; y]) ys) xs
let binary prim =
  List.iter (add prim) (pairs scalars scalars);
  List.iter (add prim) (pairs vectors [int 2; flt_ 0.5; E.Bool true; txt "x"]);
  List.iter (add prim) (pairs [int 2; flt_ 0.5; E.Bool true; txt "x"] vectors);
  List.iter (add prim) (pairs vectors vectors)
let unary prim = List.iter (fun v -> add prim [v]) unary_samples
let arr1 xs = E.Float_array (Array.of_list xs)
let arr2 xs = E.Vec2_array (Array.of_list xs)
let arr3 xs = E.Vec3_array (Array.of_list xs)
let arr4 xs = E.Vec4_array (Array.of_list xs)
let digits xs = E.List (Array.of_list xs)
let counts = [int 0; int 1; int 5; flt_ 3.; flt_ 2.5; flt_ (-1.); int (-1); flt_ nan; E.Bool true;
  txt "x"; flt_ 1e300; flt_ 1e17; v3 1. 2. 3.]
let show_values = [flt_ 0.03125; flt_ (-0.03125); flt_ 17179869184.03125; flt_ 1e21; flt_ (-0.0);
  flt_ 0.00005; flt_ 0.; flt_ nan; flt_ infinity; flt_ neg_infinity; flt_ 1e-7; flt_ 0.99995;
  flt_ 123456.789; flt_ 1e300; flt_ 5e-324; flt_ (0.1 +. 0.2); flt_ 0.00015; flt_ 2.5; flt_ (-1e-5);
  flt_ 1.00005; flt_ 4503599627370497.5; flt_ 17179869184.0312501; flt_ 1.7976931348623157e308;
  int 0; int (-5); int max_int; int min_int; E.Bool true; E.Bool false; txt ""; txt "a b \"q\" é日";
  v2 1. 0.5; v3 0.03125 (-0.) nan; v4 1. 2. 3. 4.; E.List [||]; digits [int 1; flt_ 2.; txt "x"];
  digits [digits [int 1]; E.List [||]]; rec_ []; rec_ [("a", int 1); ("b", digits [E.Bool true])];
  arr1 [1.; 2.]; arr2 [1.; 2.; 3.; 4.]; arr3 [1.; 2.; 3.]; arr4 []; arr1 []; arr2 [1.; 2.; 3.];
  E.No_geo]

let () =
  let outdir = match Sys.argv with [| _; dir |] -> dir
    | _ -> prerr_endline "usage: core_fixtures OUTDIR"; exit 2 in
  List.iter binary [C.Numeric P.Add; Numeric P.Sub; Numeric P.Mul; Numeric P.Div; Numeric P.Mod;
    Numeric P.Pow; Numeric P.Min; Numeric P.Max; Numeric P.Lt; Numeric P.Le; Numeric P.Gt;
    Numeric P.Ge; Numeric P.Eq; Numeric P.And; Numeric P.Or];
  List.iter (fun p -> List.iter (add p) (pairs scalars scalars)) [C.Remainder];
  add C.Remainder [flt_ 7.5; flt_ 2.]; add C.Remainder [flt_ (-7.5); flt_ 2.];
  add C.Remainder [flt_ 7.5; flt_ (-2.)]; add C.Remainder [flt_ 1e300; flt_ 3.];
  List.iter unary [C.Math P.Sin; Math P.Cos; Math P.Sqrt; Exp; Math P.Abs; Floor; Ceil; Round;
    Int_convert; Float_convert; Math P.Not; Truthy];
  (* integer operations: grid of boundary values, then conversions of non-Int operands *)
  List.iter (fun op -> let p = C.Integer op in
    List.iter (add p) (pairs (List.map int ints) (List.map int ints));
    List.iter (add p) (pairs [flt_ 2.5; flt_ (-2.5); flt_ 1e19; flt_ nan; E.Bool true; txt "x"; flt_ 3.5]
      [int 3; int (-2)]);
    List.iter (add p) (pairs [int 7; int (-7)] [flt_ 2.5; flt_ (-0.4); E.Bool true; flt_ infinity; txt "x"]))
    [C.Mul; Div; Mod; And; Xor];
  (* equal?, show, text/concat *)
  let eqs = [int 1; int 1; int max_int; int (max_int - 1); flt_ 1.; flt_ 0.; flt_ (-0.); flt_ nan;
    E.Bool true; E.Bool false; txt "a"; txt ""; txt "A"; v2 1. 2.; v3 1. 2. 3.; v3 1. 2. 4.;
    v4 1. 2. 3. 4.; E.List [||]; digits [int 1]; digits [flt_ 1.]; digits [int 1; int 2];
    digits [flt_ nan]; rec_ [("a", int 1); ("b", int 2)]; rec_ [("b", int 2); ("a", int 1)];
    rec_ [("a", int 1)]; rec_ []; arr1 [1.; 2.]; arr2 [1.; 2.]; arr1 []; arr3 []; arr1 [nan];
    arr1 [0.]; arr1 [-0.]; E.No_geo] in
  List.iter (add C.Equal) (pairs eqs eqs);
  List.iter (fun v -> add C.Show [v]) show_values;
  List.iter (add C.Text_concat) [[]; [txt ""]; [txt "a"]; [txt "a"; txt ""; txt "bc"];
    [txt "é"; txt "日本"; txt "\n\"\\"]; [txt "a"; int 1]; [flt_ 1.]; [txt "a"; txt "b"; E.Bool true]];
  (* sequences *)
  let l3 = digits [int 1; int 2; int 3] in
  let mixed = digits [int 1; flt_ 2.; txt "z"] in
  List.iter (fun v -> add C.Sequence_length [v])
    [E.List [||]; l3; mixed; digits [E.List [||]]; int 3; txt "abc"; arr1 [1.]];
  List.iter (fun l -> List.iter (fun i -> add C.Sequence_get [l; i])
    [int (-1); int 0; int 1; int 2; int 3; flt_ 1.; flt_ 1.5; flt_ 0.5; flt_ 2.5; flt_ nan; flt_ infinity;
     flt_ 1e19; flt_ 1e-5; flt_ 123456789.5; E.Bool true; txt "x"; int max_int])
    [E.List [||]; l3; digits [txt "a"; v3 1. 2. 3.]; int 4];
  List.iter (fun c -> add C.Sequence_build [c])
    [int (-1); int 0; int 1; int 5; int 4096; int 4097; flt_ 2.5; flt_ 0.4; E.Bool true; txt "x"; flt_ 1e19];
  List.iter (fun l ->
    List.iter (fun (f, c) -> add C.Sequence_slice [l; int f; int c])
      [(0, 0); (0, 3); (1, 2); (3, 0); (4, 0); (2, 2); (-1, 1); (1, -1); (0, 4); (3, 1)])
    [l3; E.List [||]; mixed];
  add C.Sequence_slice [l3; flt_ 0.5; flt_ 1.4]; add C.Sequence_slice [int 3; int 0; int 0];
  add C.Sequence_slice [l3; txt "x"; int 0];
  let bools n = E.List (Array.make n (E.Bool true)) in
  List.iter (add C.Sequence_concat) [[]; [l3]; [l3; mixed]; [E.List [||]; E.List [||]];
    [digits [int 1]; digits [flt_ 2.]]; [digits [int 1]; digits [txt "a"]];
    [digits [flt_ 1.]; digits [int 2]; digits [E.Bool true]];
    [digits [v2 1. 2.]; digits [v2 3. 4.]];
    [digits [rec_ [("a", int 1)]]; digits [rec_ [("a", flt_ 2.)]]];
    [digits [digits [int 1]]; digits [digits [flt_ 2.]]];
    [digits [rec_ [("a", int 1); ("b", int 2)]]; digits [rec_ [("b", flt_ 1.); ("a", flt_ 2.)]]];
    [l3; int 4]; [bools 2048; bools 2048]; [bools 2048; bools 2049]; [bools 4096; E.List [||]]];
  (* packed arrays *)
  List.iter (fun c -> add C.Array_range [c]) counts;
  List.iter (fun (c, v) -> add C.Array_float [c; v]) [(int 3, flt_ 2.5); (int 2, int 7);
    (int 2, E.Bool true); (int 0, flt_ nan); (int 1, flt_ nan); (int 2, flt_ infinity);
    (int 2, v3 1. 2. 3.); (int 2, txt "x"); (flt_ 2.5, flt_ 1.); (int 3, flt_ (-0.))];
  add C.Array_float [int 3]; add C.Array_float [flt_ nan]; add C.Array_float [int 0];
  List.iter (fun (c, v) -> add C.Array_vec3 [c; v]) [(int 2, v3 1. 2. 3.); (int 2, flt_ 1.5);
    (int 2, int 3); (int 2, E.Bool true); (int 2, v2 1. 2.); (int 2, v4 1. 2. 3. 4.); (int 2, txt "x");
    (int 0, txt "x"); (int 1, v3 nan 0. 0.); (int 1, flt_ infinity); (int (-1), flt_ 1.);
    (flt_ 1.5, flt_ 1.); (int 3, flt_ (-0.))];
  add C.Array_vec3 [int 2]; add C.Array_vec3 [int 0];
  let arrays = [arr1 [1.; 2.; 3.]; arr2 [1.; 2.; 3.; 4.]; arr3 [1.; 2.; 3.; 4.; 5.; 6.];
    arr4 [1.; 2.; 3.; 4.]; arr1 []; arr2 []; arr3 []; arr4 []] in
  List.iter (fun v -> add C.Array_count [v])
    (arrays @ [arr2 [1.; 2.; 3.]; arr3 [1.; 2.; 3.; 4.]; arr4 [1.]; int 3; digits [int 1]; txt "x"]);
  List.iter (fun a -> List.iter (fun i -> add C.Array_nth [a; i])
    [int 0; int 1; int 2; int 3; int (-1); flt_ 1.; flt_ 1.5; flt_ nan; E.Bool true; txt "x"])
    (arrays @ [int 1; digits [int 1]; arr3 [1.; 2.]]);
  List.iter (fun a -> List.iter (fun (f, c) -> add C.Array_slice [a; int f; int c])
    [(0, 0); (0, 1); (1, 1); (1, 2); (2, 0); (3, 0); (4, 0); (0, 3); (1, 3); (-1, 1); (1, -1)])
    (arrays @ [int 1; digits [int 1]]);
  add C.Array_slice [arr1 [1.; 2.; 3.]; flt_ 0.5; int 1]; add C.Array_slice [arr1 [1.]; txt "x"; int 0];
  add C.Array_slice [int 1; flt_ 0.5; int 1];
  add C.Array_slice [arr1 [nan; 1.]; int 0; int 2];
  List.iter (fun (a, b) -> add C.Array_concat [a; b]) (pairs arrays arrays |> List.map (function [a; b] -> a, b | _ -> assert false));
  add C.Array_concat [arr1 [1.]; int 2]; add C.Array_concat [int 2; arr1 [1.]];
  add C.Array_concat [arr2 [1.; 2.; 3.]; arr2 [1.]];
  (* hash, noise, colors *)
  List.iter (add C.Rand) [[]; [flt_ 0.]; [flt_ 1.]; [flt_ 2.]; [flt_ (-1.)]; [flt_ 0.5]; [flt_ 1.; flt_ 2.];
    [flt_ 2.; flt_ 1.]; [flt_ 1.; flt_ 2.; flt_ 3.]; [int 5]; [int 5; int 7; int 9; int 11]; [E.Bool true];
    [flt_ 1e303]; [flt_ nan]; [flt_ infinity]; [flt_ 4294.967296]; [flt_ 4294967296.]; [flt_ (-4294967296.)];
    [flt_ 1e15]; [flt_ 1e9; flt_ (-1e9)]; [flt_ 0.123456789]; [flt_ 1e-7]; [flt_ 3.14159; flt_ 2.71828];
    [flt_ 12345.6789]; [txt "x"]; [flt_ 1.; txt "x"]; [v3 1. 2. 3.]];
  let positions = [(0., 0., 0.); (0.5, 0.5, 0.5); (1.5, 2.25, -3.75); (-0.1, -0.2, -0.3); (100.3, 200.7, 300.1);
    (255.5, 256.5, 257.5); (-255.5, -256.5, -257.5); (1e10, -1e10, 1e10); (0.123, 4.567, 8.9);
    (1e15 +. 0.5, 3., 7.); (1e19, -1e19, 5e18); (1e300, 0., 0.); (-1e300, 1., 2.); (1e308, 1e308, 1e308)] in
  List.iter (fun (x, y, z) -> let p = v3 x y z in
    add C.Noise3 [p]; add C.Noise3 [p; int 7]; add C.Noise3 [p; int (-1); int 3];
    add C.Noise3 [p; int 0; int 2]; add C.Noise3 [p; int max_int; int 32]) positions;
  List.iter (add C.Noise3) [[v3 0.3 0.6 0.9; int min_int; int 1]; [v3 0.3 0.6 0.9; int 42; int 4];
    [v3 0.3 0.6 0.9; flt_ 2.5; flt_ 2.4]; [v3 0.3 0.6 0.9; int 0; int 0]; [v3 0.3 0.6 0.9; int 0; int 33];
    [v3 0.3 0.6 0.9; int 0; int (-1)]; [v3 nan 0. 0.]; [v3 0. infinity 0.]; [v2 0. 0.]; [flt_ 1.];
    [v3 0.3 0.6 0.9; txt "x"]; [v3 0.3 0.6 0.9; int 0; E.Bool true]; [v3 0.3 0.6 0.9; E.Bool true]];
  List.iter (fun s -> add C.Color_parse [txt s])
    ["#fff"; "fff"; "#ffff"; "#ff0000"; "#FF000080"; "ff000080"; "#abcdef"; "#AbCdEf12"; "f_0000"; "#f_f_f_";
     "#_f0000"; "#+f0000"; "#-f0000"; "#ff"; ""; "#"; "#12345"; "#1234567"; "#ggg"; "#zzzzzz"; "#0x0000";
     " fff"; "#é1"; "日本"; "##fff"; "#ff 000"; "#00000_"; "#__0000"; "#ffffff__"; "#12_"; "#_12"];
  List.iter (fun v -> add C.Color_parse [v])
    [v3 1. 0. 0.5; v3 0. 0. 0.; v3 1e20 (-1e20) 0.5; v3 0.001 (-0.002) 0.4999; v3 1e300 1e300 1e300;
     v3 3e16 2e16 1e16; v3 (-3e16) (-2e16) (-1e16); v3 0.00196 0.00195 0.998; v3 nan 0. 0.; v3 0. infinity 0.;
     v3 0. 0. neg_infinity; v3 nan nan nan; v3 1.5 2. (-1.);
     E.List [| E.Float 1.; E.Float 0.; E.Float 0.5; E.Float 0.5 |];
     E.List [| E.Float 1e20; E.Float (-1e20); E.Float 0.5; E.Float 1. |];
     E.List [| E.Int 1; E.Bool true; E.Float 0.2; E.Int 0 |];
     E.List [| E.Float nan; E.Float 0.; E.Float 0.; E.Float 0. |];
     E.List [| E.Float 0.; E.Float 0.; E.Float 0.; E.Float infinity |];
     E.List [| E.Float nan; E.Float 0.; E.Float 0.; E.Text "x" |];
     E.List [| E.Float 0.; E.Float 0.; E.Float 0.; E.Text "x" |];
     E.List [| E.Float 0.; E.Float 0.; E.Float 0. |]; E.List [||]; E.List [| E.Float 0.; E.Float 0.; E.Float 0.; E.Float 0.; E.Float 0. |];
     v4 1. 0. 0. 1.; v2 1. 0.; flt_ 1.; int 1; E.Bool true; digits [txt "a"; txt "b"; txt "c"; txt "d"]];
  let channels = [0.; 1.; 0.5; 0.001960784; 0.00196; 0.002; 0.5 /. 255.; 1.5 /. 255.; 254.5 /. 255.; 0.999;
    1.001; -0.001; -0.002; -1.; 2.; 1e20; -1e20; 1e300; -1e300; 1e16; 2e16; 3e16; -2e16; -3e16;
    3.6e16; 9.1e18; 1.8e16; 2e19; nan; infinity; neg_infinity; -0.] in
  List.iter (fun (mode, name) ->
    List.iter (fun x -> add ~static:[str name] (C.Color_byte mode) [flt_ x]) channels;
    List.iter (fun v -> add ~static:[str name] (C.Color_byte mode) [v]) [int 0; int 1; int 2; E.Bool true; txt "x"; v3 1. 1. 1.])
    [(C.Clamped, "clamped"); (C.Unclamped, "unclamped")];
  (* coerce, fail *)
  let rt = T.Record [("a", T.Float); ("b", T.Int)] in
  let values = [int 0; int 3; int (-2); int max_int; flt_ 2.5; flt_ (-2.5); flt_ 0.49999999999999994;
    flt_ 0.5; flt_ 1e19; flt_ 4e18; flt_ nan; flt_ 0.; flt_ (-0.); flt_ infinity; E.Bool true; E.Bool false; txt "x";
    v2 1. 2.; v3 1. 2. 3.; E.List [||]; digits [flt_ 1.5; int 2; E.Bool true]; digits [txt "a"];
    rec_ [("a", int 1); ("b", flt_ 2.5)]; rec_ [("b", flt_ 1.5); ("c", int 4); ("a", E.Bool true)]; rec_ [];
    arr1 [1.]; E.No_geo] in
  List.iter (fun ty -> List.iter (fun v -> add ~static:[ty_json ty] (C.Coerce ty) [v]) values)
    [T.Any; Int; Float; Bool; Text; Vec2; Vec3; Vec4; T.List T.Int; T.List T.Float; T.List T.Bool;
     T.List (T.List T.Int); rt; T.Record []; T.Array T.Float; T.Color];
  List.iter (fun (c, m) -> add ~static:[str c; str m] (C.Fail (c, m)) [])
    [("E_X", "boom"); ("", ""); ("E_UNICODE", "é日\n\"q\"")];
  (* write *)
  assert (List.length inventory = 54);
  if not (Sys.file_exists outdir) then Sys.mkdir outdir 0o755;
  List.iter (fun prim ->
    let name = C.primitive_name prim in
    let body = String.concat ",\n" (List.rev !(Hashtbl.find cases name)) in
    Out_channel.with_open_bin (Filename.concat outdir (export name ^ ".json")) (fun oc ->
      Printf.fprintf oc "{\"primitive\":%s,\"export\":%s,\"cases\":[\n%s\n]}\n" (str name) (str (export name)) body))
    inventory
