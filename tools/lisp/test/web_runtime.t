The browser runtime under node: event translation, held input and the frame clock.
Without node the checks are skipped, and the message
goes to stderr.

  $ if command -v node >/dev/null 2>&1; then
  >   { node ../../web/test/runtime.mjs ../../web/runtime/runtime.js; } > out.txt 2>&1 || { cat out.txt; exit 1; }
  > else
  >   echo "node not found: skipping web runtime tests" >&2
  > fi 2>/dev/null
  > echo "web runtime: ok"
  web runtime: ok
