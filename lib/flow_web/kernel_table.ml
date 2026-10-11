let json_string s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter (function
    | '"' -> Buffer.add_string b "\\\"" | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n"
    | c when Char.code c < 32 || Char.code c = 127 -> Printf.bprintf b "\\u%04x" (Char.code c)
    | c -> Buffer.add_char b c) s;
  Buffer.add_char b '"'; Buffer.contents b
let json_list f items = "[" ^ String.concat "," (List.map f items) ^ "]"
let json_ints a = json_list string_of_int (Array.to_list a)
let kind_name = function
  | Wgsl.Uniform_buffer -> "uniform" | Storage_read -> "read" | Storage_read_write -> "read_write"

let entry ?cpu ~id (w : Wgsl.wgsl) =
  let tables = json_list (fun seed -> json_ints (Rays_math.Noise.Private.permutation (Rays_math.Noise.create seed)))
    (Array.to_list w.table_seeds) in
  Printf.sprintf
    "{\"id\":%s,%s\"entry\":%s,\"source\":%s,\"interface\":%s,\"uniform_layout\":%s,\"uniform_bytes\":%d,\"table_seeds\":%s,\"tables\":%s,\"input_widths\":%s,\"output_widths\":%s}"
    (json_string id) (match cpu with Some c -> "\"cpu\":" ^ json_string c ^ "," | None -> "")
    (json_string w.entry) (json_string w.source)
    (json_list (fun (b : Wgsl.binding) -> Printf.sprintf "{\"group\":%d,\"binding\":%d,\"kind\":%s}" b.group b.binding (json_string (kind_name b.kind))) w.interface)
    (json_list (fun (n, o, width) -> Printf.sprintf "[%s,%d,%d]" (json_string n) o width) w.uniform_layout)
    w.uniform_bytes (json_ints w.table_seeds) tables (json_ints w.input_widths) (json_ints w.output_widths)

let table entries = "{\"kernels\":[" ^ String.concat ",\n" entries ^ "]}\n"
