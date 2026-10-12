# Reversible Text transport

Text values are native byte strings. Valid UTF-8 remains ordinary JavaScript
Unicode. Each invalid UTF-8 byte uses an isolated low surrogate DC80–DCFF;
these code units cannot occur in valid UTF-8, so the representation is reversible.
The shared JSON/JavaScript literal printer uses the standard library UTF-8
decoder and emits an escape for each invalid byte. NUL and other controls retain
ordinary JSON escapes. No Unicode normalization or replacement is applied.

The runtime `textBytes` and `textOfBytes` helpers reverse this representation.
Valid UTF-8 uses the platform encoder/decoder directly. The byte-oriented repr,
glob and hashing boundaries use these helpers; literal BOM and replacement
characters stay distinct from invalid native bytes. Worker structured cloning
preserves the isolated code units as ordinary immutable strings.

The focused codec test covers all byte values, malformed and truncated UTF-8,
overlong sequences, encoded surrogates, NUL, valid Unicode, BOM, native repr and
one/eight-worker round trips. Request 9358 passed that test and the existing Web
goldens/runtime checks. Its overall result was one: 15 existing native rename
pattern fixtures reverse the bytes of `é`, but the old native JSON writer
silently replaced those invalid sequences. The new JavaScript transport
correctly retained them, exposing the oracle transport loss.

The fixture writer now reuses the shared literal printer, retaining all 15
semantic cases. The table-decode first-byte diagnostic also uses the reversible
codec. Follow-up request 56576 passed Web/tools/API/dependency, including all
17,552 native primitive cases and all 15 unchanged byte-rewrite cases; log:
`/tmp/rays-text-codec-final.log`. This document records the codec prerequisite only;
it does not qualify Text gather, a whole SOP recipe or C.2 completion.
