The development server of `rays-lisp web --watch`: it exports, serves 127.0.0.1 with the cross-origin isolation
headers, and re-exports when the file changes. A refusal keeps the last good export.

  $ cp ../../../sketches/flow_vectors/sketch.rays live.rays && chmod u+w live.rays
  $ rays-lisp web --watch live.rays -o out --port 0 > log 2> err &
  $ until grep -q '^serving' log 2>/dev/null; do sleep 0.1; done
  $ port=$(sed -n 's|^serving http://127.0.0.1:\([0-9]*\)/$|\1|p' log)
  $ get() { ./http_get.exe "$port" "$@"; }

A file, with the headers and its type.

  $ get /program.js | head -1
  HTTP/1.1 200 OK
  $ get /program.js | grep -i '^content-type'
  Content-Type: text/javascript; charset=utf-8
  $ for f in program.js index.html kernels.json kernels.wgsl data.bin program.map runtime/runtime.js /nothing /version; do get /${f#/} | grep -c '^Cross-Origin-\(Opener\|Embedder\)-Policy: \(same-origin\|require-corp\)'; done | sort -u
  2
  $ get /index.html | grep -i '^content-type'
  Content-Type: text/html; charset=utf-8
  $ get / | grep -c '<canvas'
  1
  $ get /data.bin | grep -i '^content-type'
  Content-Type: application/octet-stream
  $ get /program.map | grep -i '^content-type'
  Content-Type: application/json
  $ get /kernels.wgsl | grep -i '^content-type'
  Content-Type: text/plain; charset=utf-8

The body is the file.

  $ get /program.js | sed '1,/^\r$/d' | cmp - out/program.js && echo same
  same

/version is the export digest.

  $ get /version | sed '1,/^\r$/d' | grep -Ec '^[0-9a-f]{64}$'
  1
  $ get /version | sed '1,/^\r$/d' > v1

Requests outside the directory, other methods, and unknown files.

  $ get /../live.rays | head -1
  HTTP/1.1 404 Not Found
  $ get /runtime/../../live.rays | head -1
  HTTP/1.1 404 Not Found
  $ get //etc/passwd | head -1
  HTTP/1.1 404 Not Found
  $ get /%2e%2e/live.rays | head -1
  HTTP/1.1 404 Not Found
  $ get /runtime | head -1
  HTTP/1.1 404 Not Found
  $ get /program.js POST | head -1
  HTTP/1.1 405 Method Not Allowed
  $ get /program.js POST | grep -c '^Cross-Origin-Opener-Policy'
  1

An edit is exported and the version changes.

  $ sed 's/(draw\/circle at 24/(draw\/circle at 30/' live.rays > edited.rays && cp edited.rays live.rays
  $ for i in $(seq 100); do get /version | sed '1,/^\r$/d' > v2; cmp -s v1 v2 || break; sleep 0.1; done; if cmp -s v1 v2; then echo unchanged; fi

A refused edit prints its diagnostic and the last good export keeps being served.

  $ echo '(workspace' > live.rays
  $ for i in $(seq 100); do grep -q refused err && break; sleep 0.1; done; grep -c 'still serving the last good export' err
  1
  $ get /version | sed '1,/^\r$/d' | cmp - v2 && echo kept
  kept
  $ kill %1
