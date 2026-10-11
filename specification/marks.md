# Marks: the run-time drawing contract

Status: specification for `Scene_command.Marks` (web-export plan P3.2). Nothing
here is implemented yet. Defaults and error codes were taken from
`lib/rays_editor/drawing.ml`, `lib/rays/scene.ml` and `lib/scene_command` at the
time of writing; this file, not `drawing.ml`, is the contract once P3.9 lands.

A draw graph, run once per frame by the core executor
([core.md](core.md), "Drawing statements and intrinsics"), produces one **mark
table**: an ordered array of entries. Every default is resolved and every
check is made before the table exists. A consumer applies no default, never
reorders, and never reads a Lisp value. The native consumer is the adapter
`Marks_scene` (P3.8), which builds the same `Render_ir` commands `drawing.ml`
builds today; the web consumer is the fixed runtime.

## Units and encodings

- Coordinates, sizes, radii and widths are **logical points**. The origin is
  the canvas top-left, x grows right, y grows down. Conversion to drawable
  pixels happens once, in the presenter (`AGENTS.md`, "Coordinates").
- Table floats are binary64. They are narrowed to binary32 once, when an
  instance or a vertex is written for the GPU. Sums such as `x + width` are
  computed in binary64 and then narrowed.
- A **colour** is packed `0xRRGGBBAA` in an `int32` (red in the top byte),
  straight alpha, 8 bits per channel, the value `Rays_math.Color` gives and
  `Scene.rgba` packs. Constants are decoded by the compiler before the table
  (`Flow_ir.Operators.drawing_color`): hex text `#rgb`, `#rgba`, `#rrggbb`,
  `#rrggbbaa` (`#` optional; `E_DRAW_COLOR` otherwise), a vec3 of 0..1 floats
  (alpha 255), or `(list r g b a)` of 0..1 floats. A float channel `c` becomes
  `clamp(trunc(c * 255 + 0.5), 0, 255)`; a nonfinite channel is `E_NONFINITE`.
- A **colour buffer** holds three binary floats per element (red, green, blue,
  0..1); each element decodes as the vec3 constant does, alpha 255.
- The colour value `0` (`#00000000`) means "none" for a stroke: no outline.
  A fill of `0` is simply fully transparent.

## The table

```
Marks.t = entry array, painter order, first entry drawn first

entry =
  | Mark_set of { kind; count; attributes }
  | Geometry of { vertices : float array; indices : int array; color : int32 }
  | Image of { resource : int; x : int; y : int; scale : float; angle : float }
  | Text of { x : int; y : int; size : int; color : int32; text : string }
  | Push_transform of { xx; xy; yx; yy; tx; ty : float }  | Pop_transform
  | Push_clip of { x; y; width; height : float }          | Pop_clip

attribute = Constant of floats-or-colour | Buffer of { id : int; count : int; width : int }
```

A **buffer reference** is an abstract positive integer `id`, an element `count`
and a `width` in floats per element. The id names a per-frame table the caller
owns (a CPU array, or later a GPU region output); the contract never holds the
data. `count` is an element count, not a float count.

### Mark sets

A mark set is `count` instances of one kind, drawn in index order 0 to
`count - 1`; instance `i` is drawn completely (fill, then stroke) before
instance `i + 1`. Each attribute is a constant (one value for every instance)
or a buffer. Attribute lists are fixed per kind:

| Kind | Attribute | Constant | Buffer width | Default (applied by the compiler) |
| --- | --- | --- | --- | --- |
| rect | `position` (top-left) | x, y | 2 or 3 | none, required |
| | `size` | width, height, each >= 0 | 2 or 3 | none, required |
| | `fill`, `stroke` | colour | 3 | see "Style resolution" |
| | `stroke_width` | float >= 0 | 1 | 1 |
| circle | `position` (centre) | x, y | 2 or 3 | none, required |
| | `radius` | float >= 0 | 1 | 1 |
| | `fill`, `stroke`, `stroke_width` | as rect | | as rect |
| line | `position` (from) | x, y | 2 or 3 | none, required |
| | `end` (to) | x, y | 2 or 3 | none, required |
| | `stroke` (the line's colour) | colour | 3 | white `0xffffffff` |
| | `stroke_width` | float >= 0 | 1 | 1 |
| point | `position` | x, y | 2 or 3 | none, required |
| | `fill` (the ink) | colour | 3 constant only | white `0xffffffff` |

A width-3 buffer is the packed vec3 layout of `Vec3_array`: the third float of
each element (z) is ignored. A constant has width 2 for a position; there is no
constant z. `draw/points` ignores a per-instance `color` (today it falls back to
white), so a point's `fill` is constant only.

**Style resolution** (`Shape_batch.Builder`; the compiler does this, the table
holds the result):

- Neither `fill` nor `stroke` given: fill is white `0xffffffff`, stroke is `0`.
- Only `fill` given: stroke is `0`.
- Only `stroke` given: fill is `0` (transparent, not white).
- The effective stroke width of a rect or circle is `0` when the resolved
  stroke is `0`, otherwise the `stroke_width` attribute. A line's width is its
  `stroke_width` and is not affected by its colour.
- Operators today set `stroke_width` only for lines (`draw/line` `:width`,
  `draw/lines` `:width`, scalar); rects and circles always carry the constant 1.

**Validity** of a mark set:

- `count` is in `0 .. 1,000,000`.
- Every buffer reference has `count` equal to the mark set's count and a width
  from the table; every id is positive.
- Every constant is finite with `abs v <= 3.4028234663852886e38` (largest
  binary32), and a size, radius or width constant is `>= 0`. This is
  `Shape_batch.Builder`'s check; buffer values are checked when read.
- A point set has no stroke and no stroke width.

Kind meanings on the native adapter (the oracle for pixel parity):

| Kind | `Shape_batch` instance (64 bytes, little-endian) |
| --- | --- |
| rect | kind word 10 = 0; words 0..3 = `x, y, x + w, y + h` |
| circle | kind 4; words 0..3 = `x - r, y - r, x + r, y + r` |
| line | kind 5; words 0..3 = `x0, y0, x1, y1`; the colour is in the fill word, the stroke word is 0 |
| all | fill word 8, stroke word 9, stroke width word 12, anti-alias flag word 13 = `1.0`; every other word 0 |

A mark set becomes one `Shapes` command (a count-0 set becomes an empty
`Shapes`, as `drawing.ml` emits today). A **point set** is not `Shapes`: each
position is truncated toward zero to an integer (`E_DRAW_RANGE` if it is
nonfinite or does not fit an OCaml int), and the point is the unit square
`(x, y), (x+1, y), (x+1, y+1), (x, y+1)` in `Ink.rect` form: 8 vertex floats and
indices `b, b+1, b+2, b, b+2, b+3` with `b` the first vertex index. Points of one
colour accumulate in one `Geometry`; a colour change starts a new one (a
constant ink gives exactly one). A count-0 point set emits nothing. The cap in
this section is the one binding `Shape_batch` limit (`1_000_000`), applied to
point sets too.

### Geometry entries

Rounded rectangles, polygons, polylines, the single `draw/point` and
`draw/background` are **indexed path geometry**, not marks. The compiler calls the
existing pure `Scene_command.Shape2` helper and stores its output unchanged:
`vertices` is x, y pairs, `indices` is triangle triples into them, `color` is the
packed colour. A helper that returns a fill and a stroke geometry gives two
entries in that order, **fill then stroke**. No target tessellates, approximates a
path with marks, or merges, splits or reorders these entries (translucent pixels
would change). An empty geometry (no vertices) is a valid entry and is kept.

| Statement | Helper and arguments | Entries |
| --- | --- | --- |
| `draw/polygon` | `Shape2.polygon points ~fill ~stroke`; points truncate to integers | fill, stroke (either may be absent; neither gives a white fill) |
| `draw/polyline` | `Shape2.polyline points ~color:ink`; width 1 | one |
| `draw/rounded_rect` | `Shape2.rounded_rect ~width ~height ~radius ~fill ~stroke`, local coordinates | `Push_transform` translate by the integer `at`, fill, stroke, `Pop_transform` |
| `draw/point` | `Shape2.polygon` of the unit square at the integer `at`, fill ink | one |
| `draw/background` | `Shape2.polygon` of `(0,0) (w,0) (w,h) (0,h)`, `w`, `h` the integer canvas size, fill the colour | one |

`rounded_rect`: `at` and `size` truncate to integers; `radius` is `floor(r + 0.5)`
(default 0) and the helper clamps it to `[0, min(abs w, abs h) / 2]`. Fill and
stroke are colours; neither given means a white fill. Stroke width is 1.

Validity: `vertices` length even, `indices` length a multiple of 3, every vertex
finite, every index in `0 .. vertices/2 - 1` (the `Render_ir` rules).

### Images and text

- `Image`: `resource` is an abstract positive integer naming an entry of the
  host resource table; an absent resolver is `E_IMAGE`, never a dropped entry.
  `x`, `y` are `at` truncated to integers (default `(0, 0)`). `scale` is finite
  and `> 0` (default 1) and `angle` is finite radians (default 0); otherwise
  `E_DRAW_RANGE`. Native lowering: destination `(x, y, w * scale, h * scale)`,
  source `(0, 0, w, h)`; if `angle <> 0`, the image is wrapped in a transform
  rotating about the destination centre `(px, py)` with `xx = cos`, `xy = -sin`,
  `yx = sin`, `yy = cos`, `tx = px - xx*px - xy*py`, `ty = py - yx*px - yy*py`.
- `Text`: a whole string, drawn left-aligned, unwrapped, with the automatic
  font, as one image at `(x, y)` (`Scene.text_image`). `x`, `y` are `at`
  truncated to integers; `size` is `floor(s + 0.5)`, default 16; `color` is the
  ink, default white. The empty string emits no entry. Rasterisation is the
  target's; the table carries the string.

### View transforms and clips

`Push_transform` carries the six affine coefficients `Render_ir.transform` uses;
entries until the matching `Pop_transform` are in the pushed local coordinates.
A transform is **never baked into per-instance attributes**. A statement writes:

| Statement | Coefficients |
| --- | --- |
| `draw/translate` | `xx=1 xy=0 yx=0 yy=1`, `tx`, `ty` the offset truncated to integers (`E_DRAW_RANGE` if nonfinite or out of int range) |
| `draw/rotate` | `a` radians, finite: `xx=cos a  xy=sin a  yx=-sin a  yy=cos a`, `tx=ty=0` |
| `draw/scale` | `xx=sx`, `yy=sy`, others 0; a scalar factor means `sx = sy`, a vec3 uses its first two components; finite |

`Push_clip` carries a rect (`x`, `y`, `width`, `height` finite, extents `>= 0`),
a scissor rectangle in the coordinates in force at the push. No draw operator
emits one yet; the entry exists so a later one needs no format change.

Transform and clip nesting are two independent depth counters, as in
`Render_ir`: every pop has an open push of its own family before it, and both
counters end at 0. Every coefficient is finite.

### Painter order

Entries are drawn in table order, later over earlier, at every level; the
table is flat, nesting is expressed only by push and pop. `draw/merge` appends
its inputs in order and flattens drawing lists; one referenced node used twice
appears twice, in place. The contract does not merge or coalesce marks; batch
merging is an optimisation that preserves this order. The table cap is
`1,048,576` entries (the `Render_ir` command limit).

## Errors

These are raised while building the table; the first one stops the frame.

| Code | When |
| --- | --- |
| `E_DRAW_INPUT` | A required input is missing: `%s needs %s.` (kind, input name) |
| `E_DRAW_LENGTH` | A per-instance buffer's element count differs from the count. `Colors and positions have different lengths.` (fill, stroke or colour), `Radii and positions have different lengths.`, `Sizes and positions have different lengths.`, `Line endpoints have different lengths.` The count is that of `positions` (`from` for lines). Checked before any instance is built |
| `E_DRAW_RANGE` | A coordinate that must be an integer is nonfinite or does not fit an int (`A drawing coordinate must fit an integer.`); and any rejection by a builder or helper: a nonfinite or over-large float, a negative radius, extent or width, a count above 1,000,000, an image scale `<= 0`, a nonfinite angle |
| `E_DRAW_KIND` | A deferred drawing node of any other kind: `No native drawing implementation for %s.` |
| `E_DRAW_COLOR` | Colour decoding failed (`Color.hex`, empty gradient stops) |
| `E_TYPE` | Radius is not a number or float array; sizes are not vec3 or vec3 array; text is not text; a colour has the wrong type |
| `E_NONFINITE` | A rotate angle, scale factor, rounded-rect radius, text size or colour channel is nonfinite |
| `E_IMAGE` | No image resolver |

## Serialization

`Marks.serialize` is stable, versioned and explicitly little-endian, in the
style of `Render_ir.serialize`. It is the P3.1 snapshot oracle for a frame's
marks. All integers are signed 64-bit, floats are the binary64 bit pattern,
colours are `int32`; a string is an integer byte length then the UTF-8 bytes.

```
int32  0x524d4b31 ("RMK1")        magic and version
int    entry count
per entry: byte tag, then
  0 mark set:   byte kind (rect 0, circle 1, line 2, point 3); int count;
                attributes in the table's order (rect: position size fill
                stroke stroke_width; circle: position radius fill stroke
                stroke_width; line: position end stroke stroke_width;
                point: position fill); each is
                  byte 0, then the constant (2 floats for position, size and
                  end; 1 float for radius and stroke_width; 1 int32 for fill and
                  stroke)
                | byte 1, then int id, int count, int width
  1 geometry:   int32 color; int vertex float count; the floats;
                int index count; the indices as ints
  2 image:      int resource, int x, int y, float scale, float angle
  3 text:       int x, int y, int size, int32 color, string
  4 push transform: float xx xy yx yy tx ty      5 pop transform
  6 push clip:  float x y width height           7 pop clip
```

A table is accepted by the validity check only when every mark set, geometry,
image, text, transform and clip meets the rules above. Image `resource` must be
`> 0`, text `size` is an unvalidated integer (see below), and buffer ids are not
checked against any table: that is the caller's.

## Ambiguities in today's `drawing.ml` that this file fixes

An implementer must keep these exactly or parity with the P3.1 snapshots breaks:

- Positions of `draw/point`, `draw/points`, `draw/text`, `draw/image`,
  `draw/translate`, polygon and polyline points, and rounded-rect `at` and `size`
  **truncate** toward zero; rounded-rect `radius` and text `size` **round**
  (`floor(x + 0.5)`). Positions of rects, circles and lines are floats.
- `draw/rect`, `draw/circle` and `draw/line` take the `Shapes` route (not path
  geometry), while `draw/point` and `draw/background` take the path-geometry
  route even though they look like a 1x1 rect and a full-canvas rect.
- Rotate stores `xy = sin, yx = -sin`; an image with an angle stores
  `xy = -sin, yx = sin`. The two signs differ and are both kept.
- A stroke-only mark has a transparent fill (`0`), not white; a stroke colour of
  `0` is "no stroke" even for a hex colour `#00000000`.
- `core.md` says invalid transforms are `E_DRAW_RANGE`; `drawing.ml` raises
  `E_NONFINITE` for a nonfinite rotate angle or scale factor. This file keeps
  `E_NONFINITE`; a later task may change both together.
- Text `size <= 0` is not validated in `drawing.ml`; the font layer decides.
- `draw/points` has no count cap in `drawing.ml`; the 1,000,000 cap on point
  sets is new here.
