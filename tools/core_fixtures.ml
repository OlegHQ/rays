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
  Numeric P.Atan2; Numeric P.Hypot; Math P.Tan; Math P.Asin; Math P.Acos; Math P.Log; Math P.Sign;
  Floor; Ceil; Round; Int_convert; Float_convert;
  Numeric P.Lt; Numeric P.Le; Numeric P.Gt; Numeric P.Ge; Numeric P.Eq; Numeric P.And; Numeric P.Or; Math P.Not;
  Integer P.Iadd; Integer P.Isub; Integer P.Imul; Integer P.Idiv; Integer P.Imod;
  Integer P.Iand; Integer P.Ior; Integer P.Ixor; Integer P.Ishl; Integer P.Ishr;
  Integer_compare P.Ilt; Integer_compare P.Ile; Integer_compare P.Igt;
  Integer_compare P.Ige; Integer_compare P.Ieq;
  Equal; Show; Text_concat; Text_blank; Text_trim; Text_lower; Text_repr; Text_table_decode; Text_table_encode;
  Sequence_length; Sequence_get; Sequence_build; Sequence_slice; Sequence_concat;
  Array_reduce Minimum; Array_reduce Maximum; Array_segment Sum; Array_segment Minimum; Array_segment Maximum;
  Array_range; Array_int; Array_text; Array_float; Array_vec3; Array_vec4; Array_nth; Array_count; Array_slice; Array_concat;
  Rand; Rand_at; Fma; Noise3; Color_parse; Color_byte Clamped; Coerce T.Any; Truthy; Error; Fail ("", "") ]

let export name = match name with
  | "+" -> "add" | "-" -> "sub" | "*" -> "mul" | "/" -> "div" | "<" -> "lt" | "<=" -> "le"
  | ">" -> "gt" | ">=" -> "ge" | "=" -> "eq" | "equal?" -> "equal"
  | "text/blank?" -> "text_blank"
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
  | Int_array d -> {|{"array":"int","data":|} ^ seq (fun n->str(string_of_int n)) (Array.to_list d) ^ "}"
  | Text_array d -> {|{"array":"text","data":|} ^ seq str (Array.to_list d) ^ "}"
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
  | C.Numeric _, _ | Integer _, _ | Integer_compare _, _ | Equal, _ | Remainder, _ -> if i = 0 then "a" else "b"
  | Math P.Not, _ -> "a"
  | Math _, _ | Floor, _ | Ceil, _ | Round, _ | Int_convert, _ | Float_convert, _ -> "x"
  | Array_range, _ -> if i = 0 then "count" else "type"
  | Sequence_build, _ -> [|"count";"width";"type"|].(i)
  | Array_int, _ | Array_text, _ | Array_float, _ | Array_vec3, _ | Array_vec4, _ -> if i = 0 then "count" else "value"
  | Array_count, _ -> "array"
  | Text_blank, _ | Text_trim, _ | Text_lower, _ | Text_repr, _ -> "text"
  | Text_table_decode, _ -> "text" | Text_table_encode, _ -> "rows"
  | Array_reduce _, _ -> "array"
  | Rand_at, 0 -> "seed" | Rand_at, _ -> "index"
  | Fma, _ -> [|"a";"b";"c"|].(i)
  | Error, 0 -> "code" | Error, 1 -> "message" | Error, _ -> "cause"
  | Array_segment _, _ -> if i=0 then "values" else "offsets"
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
  | Error (d : Flow.Diagnostic.t) -> Printf.sprintf {|{"error":{"code":%s,"message":%s%s}}|} (str d.code) (str d.message)
      (Option.fold ~none:"" ~some:(fun cause->",\"cause\":"^str cause)d.cause)

(* ---- cases ---- *)
let cases : (string, string list ref) Hashtbl.t = Hashtbl.create 64
let add ?(static = []) prim args =
  let name = C.primitive_name prim in
  let r = match Hashtbl.find_opt cases name with
    | Some r -> r | None -> let r = ref [] in Hashtbl.add cases name r; r in
  r := Printf.sprintf {|{"static":%s,"args":%s,"result":%s}|} (seq Fun.id static)
         (seq json args) (run prim args) :: !r

let add_host name args result =
  let r=match Hashtbl.find_opt cases name with Some r->r | None->let r=ref [] in Hashtbl.add cases name r;r in
  r:=Printf.sprintf {|{"static":[],"args":%s,"result":%s}|} (seq json args) result :: !r

(* array/sum lowers to a typed loop, rather than a standalone Core primitive. *)
let integer_sum values =
  let st id node : C.statement = {id;source;node} in
  let program : C.program = {
    constants=[|Option.get(C.literal_of_value(E.Int_array values));C.Int 0|];
    locals=[|T.Array T.Int;T.Int;T.Int;T.Int|];
    body=[st 0 (Assign(0,Constant 0));st 1 (Assign(1,Constant 1));
      st 2 (Iterate{sequence=0;index=2;item=3;limit=max_int;
        body=[st 3 (Assign(1,Prim(Integer P.Iadd,["a",1;"b",3])))]})];
    results=[|1|];state_slots=[||];regions=[||];call_slots=0} in
  match Flow_ir.Core_exec.run program ~live:(Frame_input.at_time 0.) with
  | Ok value -> json value
  | Error d -> failwith (Flow.Diagnostic.to_string d)

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
    Math P.Tan; Math P.Asin; Math P.Acos; Math P.Log; Math P.Sign;
    Int_convert; Float_convert; Math P.Not; Truthy];
  List.iter (fun p -> List.iter (add p) (pairs scalars scalars)) [C.Numeric P.Atan2; Numeric P.Hypot];
  List.iter (fun (a,b) ->
    add (C.Numeric P.Hypot) [flt_ a;flt_ b];
    add (C.Numeric P.Atan2) [flt_ a;flt_ b])
    [0.,0.;-0.,0.;0.,-0.;-0.,-0.;1e308,1e308;1e-300,1e-300;
     Int64.float_of_bits 1L,Int64.float_of_bits 1L];
  (* integer operations: grid of boundary values, then conversions of non-Int operands *)
  List.iter (fun op -> let p = C.Integer op in
    List.iter (add p) (pairs (List.map int ints) (List.map int ints));
    List.iter (add p) (pairs [flt_ 2.5; flt_ (-2.5); flt_ 1e19; flt_ nan; E.Bool true; txt "x"; flt_ 3.5]
      [int 3; int (-2)]);
    List.iter (add p) (pairs [int 7; int (-7)] [flt_ 2.5; flt_ (-0.4); E.Bool true; flt_ infinity; txt "x"]))
    [P.Iadd; Isub; Imul; Idiv; Imod; Iand; Ior; Ixor; Ishl; Ishr];
  List.iter (fun comparison -> List.iter (add(C.Integer_compare comparison))
    (pairs (List.map int ints) (List.map int ints))) [P.Ilt;Ile;Igt;Ige;Ieq];
  List.iter (fun shift -> List.iter(fun value ->
    List.iter(fun amount -> add(C.Integer shift)[int value;int amount])
      [-65;-64;-63;-1;0;1;62;63;64;65]) ints) [P.Ishl;Ishr];
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
  List.iter (fun s -> add C.Text_blank [txt s])
    ["";" ";"\t";"\n";"\r";"\012";" \t\n\r\012";"\011";"\000";" ";"　";"é日本🐈";" a ";"a\n"];
  List.iter (fun value -> add C.Text_blank [value]) [int 0;E.Bool false;E.No_geo];
  List.iter(fun primitive->List.iter(fun text->add primitive[txt text])
    ["";" \t\r\n\012";" \tA B\r\n";"\011A\011";"\000A\000";"  A 　";"éÉΣİ日本😀ABCZaz";"A\nB";"\rA\012"];
    List.iter(fun value->add primitive[value])[int 0;E.Bool false;E.No_geo;digits[txt "A"]])
    [C.Text_trim;C.Text_lower;C.Text_repr];
  List.iter(fun text->add C.Text_table_decode[txt text])
    ["";"a\tb\nc\td";"é日本😀\tline\\n\\t\\\\";"\t";"\n";"\\q";"\\é";"\\😀";"abc\\";"\\\\\\n\\t"];
  List.iter(fun rows->add C.Text_table_encode[rows])
    [digits[];digits[digits[]];digits[digits[txt ""]];digits[digits[txt "a";txt "b"]];
     digits[digits[txt "é日本😀";txt "\t\n\\"];digits[txt ""]];digits[digits[];digits[]];
     int 0;digits[int 0];digits[digits[int 0]]];
  add C.Text_table_decode[int 0];
  let arrays=[arr1[];arr1[0.;-0.;0.];arr1[1e16;1.;-1e16];
    E.Int_array[|min_int;max_int;9007199254740993;-9007199254740993|];
    arr2[3.;-0.;1.;0.];arr3[3.;2.;-0.;1.;4.;0.];arr4[3.;2.;1.;-0.;1.;4.;5.;0.];
    arr1[nan];arr1[infinity];E.Text_array[|"x"|]] in
  List.iter(fun operation->List.iter(fun array->add(C.Array_reduce operation)[array])arrays)
    [Flow.Op.Private.Minimum;Maximum];
  List.iter(fun operation->List.iter(fun array->
    let count=Flow.Value.array_length array in
    List.iter(fun offsets->add(C.Array_segment operation)[array;E.Int_array offsets])
      [[|0;count|];[|0;0;count|];[|0|];[||];[|0;count+1;count|];[|0;-1;count|];[|0;max_int;count|]];
    add(C.Array_segment operation)[array;arr1[0.;float count]]) arrays)
    [Flow.Op.Private.Sum;Minimum;Maximum];
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
  (* a width allocates packed storage, with no list cap *)
  List.iter (fun w -> List.iter (fun c -> add C.Sequence_build [c; int w])
    [int (-1); int 0; int 1; int 5; int 4097; int 100_000; flt_ 2.5; flt_ 1e19]) [1; 2; 3; 4];
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
  List.iter (fun c -> add C.Array_text [c]) counts;
  List.iter (fun value -> add C.Array_text [int 3; value])
    [txt ""; txt "snow"; txt "\226\152\131"; int 1; E.Bool true];
  let text_arrays = List.map (fun xs -> E.Text_array (Array.of_list xs))
    [[]; [""]; ["a"; "\226\152\131"; "b"]] in
  List.iter (fun array ->
    add C.Array_count [array];
    List.iter (fun index -> add C.Array_nth [array; int index]) [-1;0;1;3];
    List.iter (fun (first,count) -> add C.Array_slice [array; int first; int count])
      [0,0;0,1;1,2;0,19;-1,1;1,-1]) text_arrays;
  List.iter (fun pair -> match pair with [a;b] -> add C.Array_concat [a;b] | _ -> assert false)
    (pairs text_arrays (text_arrays @ [arr1 [1.]]));
  List.iter (fun c -> add C.Array_range [c]) counts;
  List.iter (fun c -> add C.Array_range [c;txt "int"];
    add C.Array_int [c]) (int 4097::counts);
  List.iter(fun kind -> add C.Array_range[int 3;kind]) [txt "float";txt "invalid";int 1];
  List.iter(fun value -> add C.Array_int[int 3;int value]) ints;
  List.iter(fun value -> add C.Array_int[int 2;value])
    [flt_ 2.5;flt_ (-2.5);flt_ nan;flt_ infinity;txt "x";E.Bool true];
  List.iter(fun c -> add C.Sequence_build[c;int 1;txt "int"])
    [int(-1);int 0;int 3;int 4097];
  List.iter(fun width -> add C.Sequence_build[int 3;int width;txt "int"]) [0;2;3;4];
  let integer_arrays=List.map(fun xs -> E.Int_array(Array.of_list xs))
    [[];[0];[min_int;max_int;((1 lsl 53)+1)];ints] in
  List.iter(fun array -> add C.Array_count[array];
    List.iter(fun index -> add C.Array_nth[array;int index]) [-1;0;1;3;19];
    List.iter(fun(first,count) -> add C.Array_slice[array;int first;int count])
      [0,0;0,1;1,2;0,19;-1,1;1,-1];
    match array with E.Int_array values -> add_host "array/sum" [array] (integer_sum values)
      | _ -> assert false) integer_arrays;
  List.iter(fun(a,b) -> add C.Array_concat[a;b])
    (pairs integer_arrays (integer_arrays@[arr1[1.]])
      |>List.map(function[a;b]->a,b|_->assert false));
  List.iter(fun values -> add_host "array/sum" [E.Int_array values] (integer_sum values))
    [Array.make 4097 max_int;[|max_int;1;min_int;-1|];[|(1 lsl 53)+1;1;-(1 lsl 53)|]];
  List.iter (fun (c, v) -> add C.Array_float [c; v]) [(int 3, flt_ 2.5); (int 2, int 7);
    (int 2, E.Bool true); (int 0, flt_ nan); (int 1, flt_ nan); (int 2, flt_ infinity);
    (int 2, v3 1. 2. 3.); (int 2, txt "x"); (flt_ 2.5, flt_ 1.); (int 3, flt_ (-0.))];
  add C.Array_float [int 3]; add C.Array_float [flt_ nan]; add C.Array_float [int 0];
  List.iter (fun (c, v) -> add C.Array_vec3 [c; v]) [(int 2, v3 1. 2. 3.); (int 2, flt_ 1.5);
    (int 2, int 3); (int 2, E.Bool true); (int 2, v2 1. 2.); (int 2, v4 1. 2. 3. 4.); (int 2, txt "x");
    (int 0, txt "x"); (int 1, v3 nan 0. 0.); (int 1, flt_ infinity); (int (-1), flt_ 1.);
    (flt_ 1.5, flt_ 1.); (int 3, flt_ (-0.))];
  add C.Array_vec3 [int 2]; add C.Array_vec3 [int 0];
  List.iter (add C.Array_vec4) [[int 2;v4 1. 2. 3. 4.]; [int 3;flt_ (-0.)];
    [int 2;int 7];[int 2;E.Bool true];[int 2;v3 1. 2. 3.];
    [int 0;txt "ignored"];[int 1;v4 nan 0. 0. 0.];[int (-1);flt_ 1.];
    [flt_ 1.5;flt_ 1.];[int 2];[int 0]];
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
  List.iter(add C.Error)[[txt "E_RULES";txt "exact é日本😀\t\n"];
    [txt "E_CAUSE";txt "message";txt "reason é日本😀\t\n"];[txt "E_CAUSE";txt "message";txt ""];
    [txt "E_CAUSE";txt "message";int 0];
    [txt "";txt ""];[txt "CODE";txt "message"];
    [int 0;txt "message"];[txt "CODE";int 0];[E.Bool false;txt "message"]];
  List.iter (add C.Fma) (List.map (List.map flt_) [
    [1.0000000000000002;0.9999999999999998;-1.];[-0.;1.;-0.];[0.;-1.;0.];
    [Float.max_float;2.;-.Float.max_float];[Float.max_float;2.;0.];
    [Float.min_float;0.5;0.];[Int64.float_of_bits 1L;0.5;0.];
    [infinity;0.;1.];[1.;nan;0.];[1.;1.;neg_infinity]]);
  add C.Fma [txt "bad";flt_ 1.;flt_ 0.];
  List.iter(fun seed->List.iter(fun index->add C.Rand_at[int seed;int index])
    [min_int;min_int+1;-(1 lsl 53)-1;0;1;(1 lsl 53)+1;max_int])
    [min_int;min_int+1;0;1;42;max_int];
  List.iter(add C.Rand_at)[[flt_ 1.;int 0];[int 0;flt_ 1.];[E.Bool false;int 0];[int 0;txt "0"]];
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
  (* Geometry host operations have a separate immutable record protocol; they
     are not frame-core primitives and do not enlarge the intrinsic inventory. *)
  List.iter (fun seed -> List.iter (fun label ->
    let context=E.Record ["seed",E.Text (Int64.to_string seed);"label",E.Text label] in
    let result=Flow_sop.Operators.seed_for ~seed ~namespace:"noise_displace" ~label in
    add_host "sop/context_seed" [E.Text "noise_displace";context] (json (E.Int result)))
    ["Noise Displace";"result";"é日";""]) [0L;1L;(-1L);42L;Int64.max_int;Int64.min_int];
  let geometry =
    let positions=Rdk.Packed.Float3.Private.of_owned_exn ~x:[|0.;1.;0.|] ~y:[|0.;0.;1.|] ~z:[|0.;0.;0.|] in
    let topology=Rdk.Topology.polygons_owned ~point_count:3 ~vertex_points:[|0;1;2|] ~primitive_offsets:[|0;3|] |> Result.get_ok in
    let attributes=List.concat_map (fun (owner,count) -> List.map (fun name ->
      Rdk.Attribute.create_owned ~name ~owner (Rdk.Attribute.Float (Array.init count float)) |> Result.get_ok)
      ["N";"Cd";"mask_1";"mask_2";"mask_A";"é";"a b";"a*";"z"])
      [Rdk.Attribute.Point,3;Vertex,3;Primitive,1;Detail,1] in
    Rdk.Geometry.create ~positions ~topology ~attributes () |> Result.get_ok in
  let owner_name=function Rdk.Attribute.Point->"point"|Vertex->"vertex"|Primitive->"primitive"|Detail->"detail" in
  let geometry_value geometry =
    let topology=Rdk.Topology.Private.view (Rdk.Geometry.topology geometry) in
    let positions=Rdk.Packed.Float3.Private.view (Rdk.Geometry.positions geometry) in
    let positions=Array.init (Array.length positions.x*3) (fun i -> match i mod 3 with
      |0->positions.x.(i/3)|1->positions.y.(i/3)|_->positions.z.(i/3)) in
    let tuple width planes =
      let data=Array.init(Array.length planes.(0)*width)(fun i->planes.(i mod width).(i/width)) in
      match width with 2->E.Vec2_array data|3->E.Vec3_array data|_->E.Vec4_array data in
    let storage = function
      | Rdk.Attribute.Float values -> "float",E.Float_array values
      | Int values -> "int",E.Int_array values
      | Text values -> "text",E.Text_array values
      | Float2 values -> let v=Rdk.Packed.Float2.Private.view values in "vec2",tuple 2 [|v.x;v.y|]
      | Float3 values -> let v=Rdk.Packed.Float3.Private.view values in "vec3",tuple 3 [|v.x;v.y;v.z|]
      | Float4 values -> let v=Rdk.Packed.Float4.Private.view values in "vec4",tuple 4 [|v.x;v.y;v.z;v.w|]
      | Float_array values -> let v=Rdk.Packed.Float_array.Private.view values in
          "float_array",E.Record["offsets",E.Int_array v.offsets;"values",E.Float_array v.values]
      | Int_array values -> let v=Rdk.Packed.Int_array.Private.view values in
          "int_array",E.Record["offsets",E.Int_array v.offsets;"values",E.Int_array v.values] in
    E.Record ["positions",E.Vec3_array positions;
      "vertex_points",E.List (Array.map (fun n->E.Int n) topology.vertex_points);
      "primitive_offsets",E.List (Array.map (fun n->E.Int n) topology.primitive_offsets);
      "primitive_kinds",E.Text (Bytes.to_string topology.primitive_kinds);
      "attributes",E.List (Array.of_list (List.map (fun attribute->
        let kind,values=storage(Rdk.Attribute.Private.storage attribute) in
        E.Record ["owner",E.Text (owner_name (Rdk.Attribute.owner attribute));"name",E.Text (Rdk.Attribute.name attribute);
          "type",E.Text kind;"values",values]) (Rdk.Geometry.attributes geometry)));
      "groups",E.List(Array.of_list(List.map(fun group->
        let owner=match Rdk.Group.owner group with Point->"point"|Vertex->"vertex"|Primitive->"primitive" in
        E.Record["owner",E.Text owner;"name",E.Text(Rdk.Group.name group);
          "mask",E.Int_array(Array.init(Rdk.Group.length group)(fun i->if Rdk.Group.mem i group then 1 else 0));
          "ordered",E.Bool(Rdk.Group.is_ordered group);
          "indices",E.Int_array(Option.value ~default:[||](Rdk.Group.ordered_elements group))])
        (Rdk.Geometry.groups geometry)));
      "edge_groups",E.List(Array.of_list(List.map(fun group->
        E.Record["name",E.Text(Rdk.Edge_group.name group);
          "mask",E.Int_array(Array.init(Rdk.Edge_group.length group)(fun i->if Rdk.Edge_group.mem i group then 1 else 0))])
        (Rdk.Geometry.edge_groups geometry)))] in
  let delete=List.find (fun (op:Flow.Op.t)->op.name="sop/delete_attr") Flow_sop.Operators.all in
  List.iter (fun owner->List.iter (fun pattern->
    let args=["geometry",E.No_geo;"attribute",E.Text pattern;"owner",E.Text owner] in
    let result=try
      delete.check args;
      let for_owner key=if key=owner then pattern else "" in
      match Rdk.Attribute_ops.delete ~point_pattern:(for_owner "point") ~vertex_pattern:(for_owner "vertex")
        ~primitive_pattern:(for_owner "primitive") ~detail_pattern:(for_owner "detail") geometry with
      |Ok g->json (geometry_value g)
      |Error e->Printf.sprintf {|{"error":{"code":"E_ATTR_DELETE","message":%s}}|} (str (Rdk.Error.to_string e))
      with Flow.Value.Fail (code,message,_) -> Printf.sprintf {|{"error":{"code":%s,"message":%s}}|} (str code) (str message) in
    add_host "sop/delete_attr" [geometry_value geometry;E.Text pattern;E.Text owner] result)
    ["N";"*";"mask_?";"mask_[1-2]";"mask_[!1]";"^N";"* ^mask_* mask_1";"a\\ b";"a\\*";
     "?";"??";"[a-z]*";"Cd N";"[";"\\";""]) ["point";"vertex";"primitive";"detail";"invalid"];
  let diagnostic(d:Flow.Diagnostic.t)=Printf.sprintf {|{"error":{"code":%s,"message":%s}}|}(str d.code)(str d.message) in
  let host_result f=try match f() with Ok value->json value|Error d->diagnostic d
    with Flow.Value.Fail(code,message,_)->diagnostic(Flow.Diagnostic.error ~code message)
      |Flow.Value.Diagnostic_fail diagnostic_->diagnostic diagnostic_ in
  let op name=List.find(fun(op:Flow.Op.t)->op.name=name)Flow_sop.Operators.all in
  let validation name args =
    let keys=if name="text/glob_error" then ["pattern"] else ["pattern";"replacement"] in
    add_host name args (host_result(fun()->Ok((op name).body
      ~live:(Frame_input.at_time 0.) ~node:(fun _ _->assert false) (List.combine keys args)))) in
  List.iter(fun pattern->validation "text/glob_error"[E.Text pattern])
    ["";"*";"^N Cd*";"é日本😀";"x\\*";"[a-z]";"[!a-z]";"[";"[]";"[!]";"[z-a]";"^";"x\\";"N ["];
  List.iter(validation "text/glob_error") [[E.Int 0];[E.Bool false]];
  List.iter(fun(pattern,replacement)->validation "text/glob_rewrite_error"[E.Text pattern;E.Text replacement])
    ["*","x*";"é*","猫*";"a?","b?";"[ab]","[cd]";"[!ab]","[cd]";
     "*","?";"??","?";"*?","*";"","";"a b","x";
     "^a","x";"a","^x";"*","x";"a","*";"[","x";"a","[";"a\\","x";"a","x\\"];
  List.iter(validation "text/glob_rewrite_error") [[E.Int 0;E.Text "x"];[E.Text "x";E.Int 0]];
  let text_operation name keys args =
    add_host name args (host_result(fun()->Ok((op name).body
      ~live:(Frame_input.at_time 0.) ~node:(fun _ _->assert false) (List.combine keys args)))) in
  List.iter(fun text->text_operation "text/glob_literal" ["text"] [E.Text text])
    (["";"ordinary";"-";"[a-z]";"\\";"\\\\";"^*?[]";"é猫😀";"\011"]
     @List.init 128(fun byte->"p"^String.make 1(Char.chr byte)^"q"));
  List.iter(text_operation "text/glob_literal" ["text"]) [[E.Int 0];[E.Bool false]];
  List.iter(fun(pattern,replacement,text)->text_operation "text/glob_rewrite"
    ["pattern";"replacement";"text"] [E.Text pattern;E.Text replacement;E.Text text])
    ["*_???","old_???_*","tag_abc";"[a-c]*","*[a-c]","aé猫";
     "a\\*","b","a*";"*","x*","";"a*","x*","unmatched";
     "é*","猫*","é😀";"*","x","name";"[","x","name";"a b","x","a";
     "^a","x","a";"a","x\\","a"];
  List.iter(text_operation "text/glob_rewrite" ["pattern";"replacement";"text"])
    [[E.Int 0;E.Text "x";E.Text "a"];[E.Text "a";E.Int 0;E.Text "a"];[E.Text "a";E.Text "x";E.Int 0]];
  let read geometry name owner kind query =
    let args=["geometry",E.Deferred(T.geometry,0);"attribute",E.Text name;"owner",E.Text owner]
      @(if kind="" then [] else ["type",E.Text kind]) in
    (op(if query then "sop/has_attr" else "sop/attr")).check args;
    let resolve=Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some geometry) in
    if query then resolve(E.Source("sop/has_attr",T.Bool,args)) else
    if kind="float_array"||kind="int_array" then
      Result.bind(resolve(E.Struct("sop/attr",T.Array T.Int,args@["component",E.Text"offsets"]))) (fun offsets->
      Result.map(fun values->E.Record["offsets",offsets;"values",values])
        (resolve(E.Struct("sop/attr",T.Any,args@["component",E.Text"values"]))))
    else resolve(E.Struct("sop/attr",T.Any,args)) in
  let write geometry name owner kind values =
    (op "sop/with_attr").check ["geometry",E.No_geo;"attribute",E.Text name;
      "owner",E.Text owner;"type",E.Text kind;"values",values];
    Result.bind(Flow_sop.Attribute_kernel.owner owner)(fun owner->
      let input=Sop.Node.Private.make_geometry ~operation:"core_fixture.attribute" ~version:1
        ~parameters:"" ~cook_mode:Sop.Node.Generator ~dependencies:Sop.Context.Dependencies.static ~inputs:[||]
        (fun ~node_id:_ _ _->Ok Sop.Node.Private.{geometry;diagnostics=[];instances=None}) in
      let node=Flow_sop.Attribute_kernel.node ~owner ~kind ~reference:true ~source:"host_fixture"
        ~name ~values ~sources:[0] [input] in
      let session=Sop.Session.create ~max_entries:8 ~max_payload_bytes:1_000_000|>Result.get_ok in
      Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
        let context=Sop.Context.create()|>Result.get_ok in
        match Sop.Session.cook session ~context node with
        |Error d->Error(Flow.Diagnostic.error ~code:d.code d.message)
        |Ok output->Ok(geometry_value(Result.get_ok(Sop.Payload.geometry output.payload))))) in
  List.iter(fun(owner,count)->List.iter(fun kind->
    let floats width=Array.init(count*width)(fun i->if i mod 2=0 then -0. else float i+.0.25) in
    let values=match kind with
      |"float"->E.Float_array(floats 1)|"vec2"->E.Vec2_array(floats 2)
      |"vec3"->E.Vec3_array(floats 3)|"vec4"->E.Vec4_array(floats 4)
      |"int"->E.Int_array(Array.init count(fun i->if i mod 2=0 then max_int else min_int))
      |"text"->E.Text_array(Array.init count(fun i->[|"";"é日本🐈";"line\n\"quote\""|].(i mod 3)))
      |"float_array"|"int_array"->E.Record["offsets",E.Int_array(Array.init(count+1)(fun i->i*16));
          "values",(if kind="float_array" then E.Float_array(floats 16)
            else E.Int_array(Array.init(count*16)(fun i->max_int-i)))]
      |_->assert false in
    add_host "sop/with_attr" [geometry_value geometry;E.Text"typed";E.Text owner;E.Text kind;values]
      (host_result(fun()->write geometry "typed" owner kind values));
    let bad=match values with
      |E.Record fields->E.Record(("offsets",E.Int_array[|0|])::List.remove_assoc "offsets" fields)
      |E.Int_array _->E.Int_array[||]|Float_array _->E.Float_array[||]
      |Text_array _->E.Text_array[||]
      |Vec2_array _->E.Vec2_array[||]|Vec3_array _->E.Vec3_array[||]|Vec4_array _->E.Vec4_array[||]
      |_->assert false in
    let writes=("typed",bad)::(if kind="vec3" then ["P",values] else []) in
    List.iter(fun(name,values)->add_host "sop/with_attr"
      [geometry_value geometry;E.Text name;E.Text owner;E.Text kind;values]
      (host_result(fun()->write geometry name owner kind values)))writes;
    let fresh=match kind with
      |"float"->Rdk.Attribute.Float(floats 1)|"int"->Int(Array.init count(fun i->max_int-i))
      |"vec2"->Float2(Result.get_ok(Rdk.Packed.Float2.of_owned ~x:(floats 1) ~y:(floats 1)))
      |"vec3"->Float3(Rdk.Packed.Float3.Private.of_owned_exn ~x:(floats 1) ~y:(floats 1) ~z:(floats 1))
      |"vec4"->Float4(Result.get_ok(Rdk.Packed.Float4.of_owned ~x:(floats 1) ~y:(floats 1) ~z:(floats 1) ~w:(floats 1)))
      |"float_array"->Float_array(Result.get_ok(Rdk.Packed.Float_array.create_owned
          ~offsets:(Array.init(count+1)(fun i->if i=0 then 0 else 2)) ~values:[|(-0.);0.25|]))
      |"int_array"->Int_array(Result.get_ok(Rdk.Packed.Int_array.create_owned
          ~offsets:(Array.init(count+1)(fun i->if i=0 then 0 else 2)) ~values:[|max_int;min_int|]))
      |"text"->Text(Array.init count(fun i->[|"";"é日本🐈";"line\n\"quote\""|].(i mod 3)))
      |_->assert false in
    let owner_enum=Flow_sop.Attribute_kernel.owner owner|>Result.get_ok in
    let typed=Rdk.Geometry.with_attribute
      (Rdk.Attribute.create_owned ~owner:owner_enum ~name:"typed" fresh|>Result.get_ok)geometry|>Result.get_ok in
    let wrong=if kind="text" then "float" else "text" in
    List.iter(fun name->List.iter(fun requested->
      add_host "sop/attr" [geometry_value typed;E.Text name;E.Text owner;E.Text requested]
        (host_result(fun()->read typed name owner requested false))) [kind;wrong]) ["typed";"missing"];
    List.iter(fun name->List.iter(fun requested->
      add_host "sop/has_attr" ([geometry_value typed;E.Text name;E.Text owner]
        @(if requested="" then [] else [E.Text requested]))
        (host_result(fun()->read typed name owner requested true))) [kind;wrong;""]) ["typed";"missing";"P"])
    ["float";"int";"vec2";"vec3";"vec4";"text";"float_array";"int_array"])
    ["point",3;"vertex",3;"primitive",1;"detail",1];
  (* Cooked topology sources use the same immutable geometry protocol. *)
  let topology_fixture points vertices offsets kinds =
    let topology=Rdk.Topology.create_owned ~point_count:points ~vertex_points:vertices
      ~primitive_offsets:offsets ~primitive_kinds:kinds |>Result.get_ok in
    let positions=Rdk.Packed.Float3.Private.of_owned_exn
      ~x:(Array.init points float) ~y:(Array.make points 0.) ~z:(Array.make points 0.) in
    Rdk.Geometry.create ~positions ~topology () |>Result.get_ok in
  let topology_fixtures = [
    topology_fixture 0 [||] [|0|] [||];
    topology_fixture 5 [|0;1;2;2;1;3|] [|0;3;6|] [|Rdk.Topology.Polygon;Polygon|];
    topology_fixture 3 [|0;1;1;2;1|] [|0;5|] [|Rdk.Topology.Open_polyline|];
    topology_fixture 4 [|3;2;1;0|] [|0;4|] [|Rdk.Topology.Closed_polyline|];
    topology_fixture 6 [|0;1;2;0;1;3;1;0;4;0;1;5|] [|0;3;6;9;12|]
      [|Rdk.Topology.Polygon;Open_polyline;Closed_polyline;Polygon|]] in
  List.iter(fun geometry->
    let resolve=Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some geometry) in
    let handle=E.Deferred(T.geometry,0) in
    List.iter(fun element->add_host "sop/count" [geometry_value geometry;E.Text element]
      (host_result(fun()->
        let args=["geometry",handle;"element",E.Text element] in
        (op "sop/count").check args;
        resolve(E.Source("sop/count",T.Int,args))))) ["points";"vertices";"primitives";"edges";"detail"];
    let edge component=resolve(E.Source("sop/edges",T.Array T.Int,
      ["geometry",handle;"component",E.Text component])) in
    add_host "sop/edges" [geometry_value geometry]
      (host_result(fun()->Result.bind(edge "a")(fun a->Result.map(fun b->E.Record["a",a;"b",b])(edge "b")))))
    topology_fixtures;
  List.iter(fun name->let args=["geometry",E.No_geo] @
      (if name="sop/count" then ["element",E.Text"points"] else ["component",E.Text"a"]) in
    add_host name (E.No_geo::(if name="sop/count" then [E.Text"points"] else []))
      (host_result(fun()->Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->None)
        (E.Source(name,(if name="sop/count" then T.Int else T.Array T.Int),args))))) ["sop/count";"sop/edges"];
  (* Group host fixtures execute the production lowering for mask writes. *)
  let group_write geometry owner name mask order =
    let base=op "sop/with_group" in
    let rec payload : type f r. E.value -> (f,r) Flow.Value.t = function
      | E.Int_array values -> Flow.Value.Int_array values
      | E.Bool value -> Flow.Value.Bool value
      | E.Record fields -> Flow.Value.Record(List.map(fun(name,value)->name,payload value)fields)
      | _ -> assert false in
    let constant name ty value={base with Flow.Op.name=name;ctx=Flow.Context.value;
      signature={pos=[];opt=[];rest=None;kw=[]};out=(fun _->ty);out_args=None;
      choices=[];check=(fun _->());body=(fun ~live:_ ~node:_ _->payload value)} in
    let input=Sop.Node.Private.make_geometry ~operation:"core_fixture.groups" ~version:1
      ~parameters:"" ~cook_mode:Sop.Node.Generator ~dependencies:Sop.Context.Dependencies.static ~inputs:[||]
      (fun ~node_id:_ _ _->Ok Sop.Node.Private.{geometry;diagnostics=[];instances=None}) in
    let factory=Sop.Edit_graph.factory ~key:"fixture" ~label:"Fixture" ~category:["Test"] ~arity:0 (fun _->input) in
    let geometry_op={base with Flow.Op.name="sop/fixture";
      signature={pos=[];opt=[];rest=None;kw=[]};out_args=None;choices=[];check=(fun _->());
      body=(fun ~live:_ ~node _->node "sop/fixture" [])} in
    let order_ops=Option.to_list(Option.map(fun order->constant "fixture/order"(Flow.Value.ty_of order)order)order) in
    let forms=Flow.Syntax.parse("(workspace groups (graph g :context sop (sop/with_group (sop/fixture) "^
      "(fixture/mask) :name "^Flow.Lisp.flat(Flow.Syntax.make(Str name))^" :owner "^owner^
      (if order=None then "" else " :order (fixture/order)")^")))") in
    Result.bind forms(fun forms->
      match Flow.Workspace.check ~ops:(geometry_op::constant "fixture/mask"(Flow.Value.ty_of mask)mask::order_ops @Flow_sop.Operators.all)
        {Flow.Check.version=1;kinds=[]} forms with
      | None,diagnostics->Error(List.find(fun(d:Flow.Diagnostic.t)->d.severity=Error)diagnostics)
      | Some checked,_->Result.bind(Flow_sop.Lower.of_checked ~factories:[factory] checked)(fun lowered->
          let graph=List.hd lowered.graphs in
          match Sop.Edit_graph.compile_node graph.network.geometry ~node_id:(Option.get graph.root) with
          | Error message->Error(Flow.Diagnostic.error ~code:"E_DATA_SOURCE" message)
          | Ok node->
              let session=Sop.Session.create ~max_entries:8 ~max_payload_bytes:1_000_000 |>Result.get_ok in
              Fun.protect ~finally:(fun()->Sop.Session.close session)(fun()->
                match Sop.Session.cook session ~context:(Sop.Context.create() |>Result.get_ok)node with
                | Error d->Error(Flow.Diagnostic.error ~code:d.code d.message)
                | Ok output->Ok(geometry_value(Result.get_ok(Sop.Payload.geometry output.payload)))))) in
  List.iter(fun geometry->List.iter(fun(owner,count,native_owner)->
    let mask=Array.init count(fun i->if i mod 2=0 then 1 else 0) in
    let names=["wall_a";"wall_b";"wall_1";"floor";"literal*";"žarek"] in
    let grouped=List.fold_left(fun geometry name->match native_owner with
      | Some owner->Rdk.Geometry.with_group(Rdk.Group.init ~owner ~name count(fun i->mask.(i)=1))geometry |>Result.get_ok
      | None->let topology=Rdk.Geometry.topology geometry in
          Rdk.Geometry.with_edge_group(Rdk.Edge_group.init ~topology ~index:(Rdk.Topology_index.create topology)
            ~name(fun i->mask.(i)=1))geometry |>Result.get_ok)geometry names in
    let resolve=Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some grouped) in
    let args name=["geometry",E.Deferred(T.geometry,0);"owner",E.Text owner;"name",E.Text name] in
    List.iter(fun name->
      add_host "sop/group" [geometry_value grouped;E.Text name;E.Text owner]
        (host_result(fun()->resolve(E.Source("sop/group",T.Array T.Int,args name))));
      add_host "sop/group_order" [geometry_value grouped;E.Text name;E.Text owner]
        (host_result(fun()->Result.bind(resolve(E.Source("sop/group_order",T.Bool,args name@["component",E.Text"ordered"])))
          (fun ordered->Result.map(fun indices->E.Record["ordered",ordered;"indices",indices])
            (resolve(E.Source("sop/group_order",T.Array T.Int,args name@["component",E.Text"indices"]))))))) ["wall_a";"missing"];
    List.iter(fun pattern->add_host "sop/group_names" [geometry_value grouped;E.Text pattern;E.Text owner]
      (host_result(fun()->resolve(E.Source("sop/group_names",T.Array T.Text,
        ["geometry",E.Deferred(T.geometry,0);"owner",E.Text owner;"pattern",E.Text pattern])))))
      ["";"*";"wall*";"wall_[a-b]";"wall_[!0-9]";"* ^wall*";"^wall* wall_b";"literal\\*";"ž*";"[";"\\";"[z-a]"];
    let selected=Array.to_list(Array.mapi(fun i value->i,value)mask) |>List.filter_map(fun(i,value)->if value=1 then Some i else None)
      |>List.rev |>Array.of_list in
    List.iter(fun(mask,order)->add_host "sop/with_group"
      ([geometry_value grouped;mask;E.Text "wall_a";E.Text owner]@Option.to_list order)
      (host_result(fun()->group_write grouped owner "wall_a" mask order)))
      [E.Int_array mask,None;E.Int_array(Array.make count 0),Some(E.Record["ordered",E.Bool false;"indices",E.Int_array[||]]);
       E.Int_array mask,Some(E.Int_array selected);
       E.Int_array mask,Some(E.Record["ordered",E.Bool true;"indices",E.Int_array selected]);
       E.Int_array(Array.make count 0),Some(E.Int_array[||]);
       E.Int_array(Array.make(count+1)0),None;E.Int_array(Array.make count 2),None;
       E.Int_array mask,Some(E.Int_array[|count|]);E.Int_array mask,Some(E.Int_array[|0;0|])];
    Option.iter(fun native_owner->List.iter(fun indices->
      let geometry=Rdk.Geometry.with_group(Rdk.Group.ordered ~owner:native_owner ~name:"wall_a" ~length:count indices
        |>Result.get_ok)grouped |>Result.get_ok in
      add_host "sop/group_order" [geometry_value geometry;E.Text "wall_a";E.Text owner]
        (json(E.Record["ordered",E.Bool true;"indices",E.Int_array indices]))) [selected;[||]])native_owner)
    ["point",Rdk.Geometry.point_count geometry,Some Rdk.Group.Point;
     "vertex",Rdk.Geometry.vertex_count geometry,Some Vertex;
     "primitive",Rdk.Geometry.primitive_count geometry,Some Primitive;
     "edge",Rdk.Topology_index.edge_count(Rdk.Topology_index.create(Rdk.Geometry.topology geometry)),None])
    topology_fixtures;
  List.iter(fun name->let selector=if name="sop/group_names" then "pattern" else "name" in
    let args=["geometry",E.No_geo;selector,E.Text"selected";"component",E.Text"ordered"] in
    add_host name [E.No_geo;E.Text"selected"]
      (host_result(fun()->Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->None)
        (E.Source(name,T.Any,args))))) ["sop/group";"sop/group_names";"sop/group_order"];
  (* Metadata mutations preserve immutable payloads, owner identity and store order. *)
  let metadata_geometry=
    let ordinary owner name indices=Rdk.Group.ordered ~owner ~name ~length:(match owner with
      Rdk.Group.Point->3|Vertex->3|Primitive->1) indices |>Result.get_ok in
    let geometry=List.fold_left(fun geometry group->Rdk.Geometry.with_group group geometry |>Result.get_ok) geometry
      [ordinary Point "wall_a" [|2;0|];ordinary Point "wall_b" [|1;0|];
       ordinary Vertex "wall_a" [|1|];ordinary Primitive "wall_a" [|0|];ordinary Point "empty" [||]] in
    let topology=Rdk.Geometry.topology geometry in
    List.fold_left(fun geometry name->Rdk.Geometry.with_edge_group
      (Rdk.Edge_group.init ~topology ~index:(Rdk.Topology_index.create topology) ~name (fun i->i=0)) geometry |>Result.get_ok)
      geometry ["wall_a";"wall_b";"literal*"] in
  let entries geometry pattern owner =
    let resolve=Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some geometry) in
    let column component=resolve(E.Source("sop/group_entries",T.Array T.Text,
      ["geometry",E.Deferred(T.geometry,0);"pattern",pattern;"owner",owner;"component",E.Text component])) in
    Result.bind(column "owners")(fun owners->Result.map(fun names->E.Record["owners",owners;"names",names])(column "names")) in
  List.iter(fun owner->List.iter(fun pattern->add_host "sop/group_entries"
    [geometry_value metadata_geometry;E.Text pattern;E.Text owner]
    (host_result(fun()->entries metadata_geometry(E.Text pattern)(E.Text owner))))
    ["";"*";"wall*";"* ^wall_a";"literal\\*";"missing";"[";"\\";"[z-a]"])
    ["any";"point";"vertex";"primitive";"edge";" Points ";"invalid"];
  List.iter(fun(pattern,owner)->add_host "sop/group_entries"
    [geometry_value metadata_geometry;pattern;owner]
    (host_result(fun()->entries metadata_geometry pattern owner)))
    [E.Int 0,E.Text "any";E.Text "*",E.Int 0];
  add_host "sop/group_entries" [E.No_geo;E.Text "*"]
    (host_result(fun()->Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->None)
      (E.Source("sop/group_entries",T.Array T.Text,["geometry",E.No_geo;"pattern",E.Text"*";"component",E.Text"names"]))));
  let large_inventory=Rdk.Geometry.create ~positions:(Rdk.Geometry.positions geometry)
    ~topology:(Rdk.Geometry.topology geometry)
    ~groups:(List.init 5001(fun i->Rdk.Group.init ~owner:Rdk.Group.Point ~name:("entry_"^string_of_int i) 3(fun _->false)))()
    |>Result.get_ok in
  add_host "sop/group_entries" [geometry_value large_inventory;E.Text "*";E.Text "any"]
    (host_result(fun()->entries large_inventory(E.Text "*")(E.Text "any")));
  let metadata_result name args native = host_result(fun()->
    (op name).check (("geometry",E.No_geo)::args);
    Result.map geometry_value (Result.map_error(fun error->Flow.Diagnostic.error ~code:(Rdk.Error.code error)
      (Rdk.Error.operation error^" could not produce valid geometry")) (native()))) in
  let owners=["point",Some Rdk.Attribute.Point;"vertex",Some Vertex;"primitive",Some Primitive;
    "detail",Some Detail;"any",None] in
  List.iter(fun name->
    let args=["pattern",E.Text "missing";"replacement",E.Text "renamed";
      "owner",E.Text "any";"conflict",E.Text "sKip"] in
    add_host name [geometry_value metadata_geometry;E.Text "missing";E.Text "renamed";E.Text "any";E.Text "sKip"]
      (host_result(fun()->(op name).check (("geometry",E.No_geo)::args);Ok E.No_geo)))
    ["sop/rename_attr";"sop/rename_group"];
  List.iter(fun(owner,selected)->
    List.iter(fun name->add_host "sop/attr_type" [geometry_value metadata_geometry;E.Text name;E.Text owner]
      (host_result(fun()->let args=["geometry",E.Deferred(T.geometry,0);"attribute",E.Text name;"owner",E.Text owner] in
        (op "sop/attr_type").check args;
        Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some metadata_geometry)(E.Source("sop/attr_type",T.Text,args)))))
      ["P";"N";"missing";"missing é"];
    List.iter(fun pattern->add_host "sop/attr_names" [geometry_value metadata_geometry;E.Text pattern;E.Text owner]
      (host_result(fun()->let args=["geometry",E.Deferred(T.geometry,0);"pattern",E.Text pattern;"owner",E.Text owner] in
        (op "sop/attr_names").check args;
        Flow_sop.Attribute_kernel.resolve ~geometry:(fun _->Some metadata_geometry)(E.Source("sop/attr_names",T.Array T.Text,args)))))
      ["";"*";"mask_* ^mask_A";"??";"[";"\\"];
    List.iter(fun(pattern,replacement)->List.iter(fun(conflict,policy)->
      add_host "sop/rename_attr" [geometry_value metadata_geometry;E.Text pattern;E.Text replacement;E.Text owner;E.Text conflict]
        (metadata_result "sop/rename_attr" ["pattern",E.Text pattern;"replacement",E.Text replacement;"owner",E.Text owner;"conflict",E.Text conflict]
          (fun()->Rdk.Attribute_ops.rename ~rules:[{rename_attribute_owner=selected;rename_attribute_pattern=pattern;
            rename_attribute_replacement=replacement;rename_attribute_conflict=policy}] metadata_geometry)))
      ["skip",Rdk.Attribute_ops.Attribute_rename_skip;"error",Attribute_rename_error;"overwrite",Attribute_rename_overwrite])
      ["N","Cd";"mask_*","new_*";"mask_?","new_?";"mask_[1-2]","new_[1-2]";
       "missing","new";"N","P";"a\\*","literal";"*?","?*";"N Cd","x";"*","x";"[","x"];
    Option.iter(fun selected->List.iter(fun(source,destination)->List.iter(fun(method_,method_enum)->
      add_host "sop/swap_attr" [geometry_value metadata_geometry;E.Text source;E.Text destination;E.Text owner;E.Text method_]
        (metadata_result "sop/swap_attr" ["source",E.Text source;"destination",E.Text destination;"owner",E.Text owner;"method",E.Text method_]
          (fun()->Rdk.Attribute_ops.swap ~rules:[{swap_attribute_owner=selected;swap_attribute_source=source;
            swap_attribute_destination=destination;swap_attribute_method=method_enum}] metadata_geometry)))
      ["swap",Rdk.Attribute_ops.Attribute_swap;"move",Attribute_move;"copy",Attribute_copy])
      ["N","Cd";"N","new";"missing","Cd";"missing","absent";"P","new";"N","P";
       "mask_*","copy_*";"N","N";"[","x"]) selected) owners;
  List.iter(fun reference->List.iter(fun inverse->List.iter(fun point->
    let reference_value=match reference with None->E.No_geo|Some geometry->geometry_value geometry in
    add_host "sop/delete_attrs" [geometry_value metadata_geometry;reference_value;E.Bool inverse;E.Text point;E.Text"";E.Text"N";E.Text"*"]
      (metadata_result "sop/delete_attrs" ["inverse",E.Bool inverse;"point",E.Text point;"vertex",E.Text"";
        "primitive",E.Text"N";"detail",E.Text"*"]
        (fun()->Rdk.Attribute_ops.delete ?reference ~delete_non_selected:inverse
          ~point_pattern:point ~vertex_pattern:"" ~primitive_pattern:"N" ~detail_pattern:"*" metadata_geometry)))
    ["";"*";"^N";"mask_* ^mask_1";"["]) [false;true]) [None;Some metadata_geometry];
  List.iter(fun(owner,selected)->
    List.iter(fun(pattern,replacement)->List.iter(fun(conflict,policy)->
      add_host "sop/rename_group" [geometry_value metadata_geometry;E.Text pattern;E.Text replacement;E.Text owner;E.Text conflict]
        (metadata_result "sop/rename_group" ["pattern",E.Text pattern;"replacement",E.Text replacement;"owner",E.Text owner;"conflict",E.Text conflict]
          (fun()->Rdk.Group_ops.rename ~rules:[{rename_owner=selected;rename_pattern=pattern;
            rename_replacement=replacement;rename_conflict=policy}] metadata_geometry)))
      ["skip",Rdk.Group_ops.Rename_skip;"error",Rename_error;"overwrite",Rename_overwrite;"union",Rename_union])
      ["wall_a","wall_b";"wall_*","new_*";"wall_?","new_?";"missing","absent";"literal\\*","literal";"*","x"];
    List.iter(fun pattern->List.iter(fun unused->add_host "sop/delete_group"
      [geometry_value metadata_geometry;E.Text pattern;E.Text owner;E.Bool unused]
      (metadata_result "sop/delete_group" ["pattern",E.Text pattern;"owner",E.Text owner;"unused",E.Bool unused]
        (fun()->Rdk.Group_ops.delete ~rules:[{delete_owner=selected;delete_pattern=pattern}]
          ~delete_unused:unused metadata_geometry))) [false;true]) ["";"wall*";"^wall_a";"*"])
    ["point",Some Rdk.Group_ops.Group_points;"vertex",Some Group_vertices;
      "primitive",Some Group_primitives;"edge",Some Group_edges;"any",None];
  List.iter(fun(from,into)->add_host "sop/rename_edge" [geometry_value metadata_geometry;E.Text from;E.Text into]
    (host_result(fun()->try Result.map geometry_value(Result.map_error(fun _->Flow.Diagnostic.error
      ~code:"rename_edge_group_failed" "rename_edge_group could not produce valid geometry")
      (Rdk.Geometry.rename_edge_group ~from ~into metadata_geometry))
      with Invalid_argument _->Error(Flow.Diagnostic.error ~code:"uncaught_node_exception"
        "a procedural node raised an exception while cooking"))))
    ["wall_a","new";"wall_a","wall_b";"wall_a","wall_a";"missing","missing";"literal*","new*";"wall_a"," "];
  List.iter(fun name->add_host "sop/delete_edge" [geometry_value metadata_geometry;E.Text name]
    (json(geometry_value(Rdk.Geometry.without_edge_group name metadata_geometry)))) ["wall_a";"missing";"*";""];
  (* write *)
  assert (List.length inventory = 88);
  if not (Sys.file_exists outdir) then Sys.mkdir outdir 0o755;
  List.iter (fun name ->
    let body = String.concat ",\n" (List.rev !(Hashtbl.find cases name)) in
    Out_channel.with_open_bin (Filename.concat outdir (export name ^ ".json")) (fun oc ->
      Printf.fprintf oc "{\"primitive\":%s,\"export\":%s,\"cases\":[\n%s\n]}\n" (str name) (str (export name)) body))
    (List.map C.primitive_name inventory @ ["array/sum";"sop/context_seed";"sop/delete_attr";"sop/attr";"sop/with_attr";"sop/has_attr";"sop/count";"sop/edges";
      "sop/group";"sop/group_names";"sop/group_order";"sop/with_group";
      "sop/attr_type";"sop/attr_names";"sop/rename_attr";"sop/swap_attr";"sop/delete_attrs";
      "sop/rename_group";"sop/delete_group";"sop/rename_edge";"sop/delete_edge";"text/glob_error";"text/glob_rewrite_error";
      "text/glob_literal";"text/glob_rewrite";"sop/group_entries"])
