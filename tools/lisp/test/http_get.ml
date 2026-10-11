(* http_get PORT PATH [METHOD]: one HTTP/1.1 request to 127.0.0.1, the whole response on stdout (test helper). *)
let () =
  let port = int_of_string Sys.argv.(1) and path = Sys.argv.(2) in
  let meth = if Array.length Sys.argv > 3 then Sys.argv.(3) else "GET" in
  let fd = Unix.socket PF_INET SOCK_STREAM 0 in
  Unix.connect fd (ADDR_INET (Unix.inet_addr_loopback, port));
  let request = Printf.sprintf "%s %s HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" meth path in
  ignore (Unix.write_substring fd request 0 (String.length request));
  let chunk = Bytes.create 65536 in
  let rec read () = match Unix.read fd chunk 0 (Bytes.length chunk) with
    | 0 -> () | n -> print_string (Bytes.sub_string chunk 0 n); read () in
  read ()
