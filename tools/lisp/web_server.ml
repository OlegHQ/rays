let digest files =
  Editor_document.Contexts.sha256
    (String.concat "" (List.map (fun (name, text) -> Printf.sprintf "%s\000%d\000%s" name (String.length text) text) files))

let interval = 0.5   (* as lib/rays_editor/source_file.ml *)

let rec mkdir d = if not (Sys.file_exists d) then (mkdir (Filename.dirname d); Sys.mkdir d 0o755)

(* write beside, then rename, so a request never reads half a file *)
let write dir files =
  List.iter (fun (name, text) ->
    let path = Filename.concat dir name in
    mkdir (Filename.dirname path);
    Out_channel.with_open_bin (path ^ ".tmp") (fun oc -> output_string oc text);
    Sys.rename (path ^ ".tmp") path) files

let content_type name = match Filename.extension name with
  | ".html" -> "text/html; charset=utf-8"
  | ".js" | ".mjs" -> "text/javascript; charset=utf-8"
  | ".wgsl" -> "text/plain; charset=utf-8"
  | ".json" | ".map" -> "application/json"
  | _ -> "application/octet-stream"

(* the file for a request target under [dir], or None: no [..], nothing outside [dir] *)
let resolve dir target =
  let path = match String.index_opt target '?' with Some i -> String.sub target 0 i | None -> target in
  if path = "" || path.[0] <> '/' || String.contains path '\000' || String.contains path '\\' then None
  else
    let parts = List.filter (fun p -> p <> "" && p <> ".") (String.split_on_char '/' path) in
    if List.mem ".." parts then None
    else
      let file = Filename.concat dir (if parts = [] then "index.html" else String.concat "/" parts) in
      if Sys.file_exists file && not (Sys.is_directory file) then Some file else None

let response ?(content_type = "text/plain; charset=utf-8") status reason body =
  Printf.sprintf "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\n\
                  Cross-Origin-Opener-Policy: same-origin\r\nCross-Origin-Embedder-Policy: require-corp\r\n\
                  Connection: close\r\n\r\n%s" status reason content_type (String.length body) body

let handle dir version request =
  match String.split_on_char ' ' (List.hd (String.split_on_char '\r' request)) with
  | "GET" :: target :: _ ->
      if target = "/version" then response 200 "OK" version
      else (match resolve dir target with
        | Some file -> response ~content_type:(content_type file) 200 "OK" (In_channel.with_open_bin file In_channel.input_all)
        | None | exception Sys_error _ -> response 404 "Not Found" "not found")
  | _ :: _ :: _ -> response 405 "Method Not Allowed" "method not allowed"
  | _ -> response 400 "Bad Request" "bad request"

let send fd text =
  let rec go off = if off < String.length text then
    go (off + Unix.write_substring fd text off (String.length text - off)) in
  try go 0 with Unix.Unix_error _ -> ()

let contains text sub =
  let n = String.length sub in
  let rec at i = i + n <= String.length text && (String.sub text i n = sub || at (i + 1)) in
  at 0

let run ?(port = 8000) ?(dependencies = fun () -> []) ~dir ~file ~export () =
  Sys.set_signal Sys.sigpipe Sys.Signal_ignore;
  mkdir dir;
  let source = ref "" and version = ref "" in
  let fingerprint () = digest (List.map (fun path -> path,
    try In_channel.with_open_bin path In_channel.input_all with Sys_error message -> message)
    (List.sort_uniq String.compare (file :: dependencies ()))) in
  let refresh () =
        let sha = fingerprint () in
        if sha <> !source then begin
          source := sha;   (* a refused text is not retried until it changes *)
          let result = try export () with Sys_error message -> prerr_endline message; Error () in
          (* New dependencies trigger another poll; retain the pre-export digest so an edit
             made during export cannot be swallowed by the last-good write. *)
          match result with
          | Error () -> prerr_endline "web: refused; still serving the last good export"
          | Ok files -> write dir files; version := digest files; Printf.printf "web: exported, version %s\n%!" !version
        end in
  refresh ();
  if !version = "" then exit 1;
  let listener = Unix.socket PF_INET SOCK_STREAM 0 in
  Unix.setsockopt listener SO_REUSEADDR true;
  Unix.bind listener (ADDR_INET (Unix.inet_addr_loopback, port));
  Unix.listen listener 16;
  (match Unix.getsockname listener with
   | ADDR_INET (_, p) -> Printf.printf "serving http://127.0.0.1:%d/\n%!" p
   | _ -> ());
  let clients = ref [] and last = ref (Unix.gettimeofday ()) in
  let drop fd = clients := List.filter (fun (c, _) -> c <> fd) !clients; Unix.close fd in
  let chunk = Bytes.create 4096 in
  while true do
    let ready = try let r, _, _ = Unix.select (listener :: List.map fst !clients) [] [] interval in r
      with Unix.Unix_error (EINTR, _, _) -> [] in
    List.iter (fun fd ->
      if fd = listener then (let c, _ = Unix.accept listener in clients := (c, Buffer.create 256) :: !clients)
      else match List.assoc_opt fd !clients with
        | None -> ()
        | Some buffer ->
            (match Unix.read fd chunk 0 (Bytes.length chunk) with
             | 0 | exception Unix.Unix_error _ -> drop fd
             | n ->
                 Buffer.add_subbytes buffer chunk 0 n;
                 let request = Buffer.contents buffer in
                 if contains request "\r\n\r\n" then (send fd (handle dir !version request); drop fd)
                 else if Buffer.length buffer > 65536 then drop fd)) ready;
    if Unix.gettimeofday () -. !last >= interval then (last := Unix.gettimeofday (); refresh ())
  done
