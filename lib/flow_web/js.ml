module P = Flow_ir.Packed
module R = Flow_ir.Core.Region
let perlin = {|  const fade = (t) => t * t * t * (t * (t * 6 - 15) + 10);
  const lerp = (a, b, t) => a + t * (b - a);
  const grad = (hash, x, y, z) => {
    const h = hash & 15;
    const u = h < 8 ? x : y;
    const v = h < 4 ? y : ((h === 12 || h === 14) ? x : z);
    return ((h & 1) === 0 ? u : -u) + ((h & 2) === 0 ? v : -v);
  };
  const raw3 = (p, x, y, z) => {
    const fx = Math.floor(x), fy = Math.floor(y), fz = Math.floor(z);
    const xi = fx & 255, yi = fy & 255, zi = fz & 255;
    x = x - fx; y = y - fy; z = z - fz;
    const u = fade(x), v = fade(y), w = fade(z);
    const h000 = p[p[p[xi] + yi] + zi], h100 = p[p[p[xi + 1] + yi] + zi];
    const h010 = p[p[p[xi] + yi + 1] + zi], h110 = p[p[p[xi + 1] + yi + 1] + zi];
    const h001 = p[p[p[xi] + yi] + zi + 1], h101 = p[p[p[xi + 1] + yi] + zi + 1];
    const h011 = p[p[p[xi] + yi + 1] + zi + 1], h111 = p[p[p[xi + 1] + yi + 1] + zi + 1];
    const x00 = lerp(grad(h000, x, y, z), grad(h100, x - 1, y, z), u);
    const x10 = lerp(grad(h010, x, y - 1, z), grad(h110, x - 1, y - 1, z), u);
    const x01 = lerp(grad(h001, x, y, z - 1), grad(h101, x - 1, y, z - 1), u);
    const x11 = lerp(grad(h011, x, y - 1, z - 1), grad(h111, x - 1, y - 1, z - 1), u);
    return lerp(lerp(x00, x10, v), lerp(x01, x11, v), w);
  };
  const fbm = (p, x, y, z, octaves) => {
    let frequency = 1, amplitude = 1, sum = 0, weights = 0;
    for (let octave = 0; octave < octaves; octave++) {
      const sx = x * frequency, sy = y * frequency, sz = z * frequency;
      if (Number.isFinite(sx) && Number.isFinite(sy) && Number.isFinite(sz)
          && Number.isFinite(sum) && Number.isFinite(weights)) {
        const raw = (raw3(p, sx, sy, sz) + 1) * 0.5;
        sum = sum + (raw <= 0 ? 0 : raw >= 1 ? 1 : raw) * amplitude;
        weights = weights + amplitude;
        frequency = frequency * 2;
        amplitude = amplitude * 0.5;
      } else sum = NaN;
    }
    if (Number.isFinite(sum) && Number.isFinite(weights)) return weights === 0 ? 0 : sum / weights;
    return NaN;
  };
|}
let number x =
  if Float.is_nan x then "NaN" else if x = Float.infinity then "Infinity"
  else if x = Float.neg_infinity then "-Infinity" else Printf.sprintf "%.17g" x
let register index = "r" ^ string_of_int index
let checked = function
  | P.Binary ((Add | Sub | Mul | Div | Mod | Pow | Min | Max), _, _) | Unary ((Sin | Cos), _) -> true
  | _ -> false
let flag condition = "(" ^ condition ^ " ? 1 : 0)"
let binary operation a b = match operation with
  | P.Add -> a ^ " + " ^ b | Sub -> a ^ " - " ^ b | Mul -> a ^ " * " ^ b
  | Div -> b ^ " === 0 ? 0 : " ^ a ^ " / " ^ b
  | Mod -> b ^ " === 0 ? 0 : ((" ^ a ^ " % " ^ b ^ ") + " ^ b ^ ") % " ^ b
  | Pow -> "Math.pow(Math.abs(" ^ a ^ "), " ^ b ^ ")"
  | Min -> "Math.min(" ^ a ^ ", " ^ b ^ ")" | Max -> "Math.max(" ^ a ^ ", " ^ b ^ ")"
  | Lt -> flag (a ^ " < " ^ b) | Le -> flag (a ^ " <= " ^ b) | Gt -> flag (a ^ " > " ^ b)
  | Ge -> flag (a ^ " >= " ^ b) | Eq -> flag (a ^ " === " ^ b)
  | And -> flag (a ^ " !== 0 && " ^ b ^ " !== 0") | Or -> flag (a ^ " !== 0 || " ^ b ^ " !== 0")
let unary operation a = match operation with
  | P.Sin -> "Math.sin(" ^ a ^ ")" | Cos -> "Math.cos(" ^ a ^ ")"
  | Sqrt -> "Math.sqrt(Math.abs(" ^ a ^ "))" | Abs -> "Math.abs(" ^ a ^ ")" | Not -> flag (a ^ " === 0")
let region program =
  let view = P.Private.view program and region = P.to_region program in
  let line = Buffer.create 4096 in
  let add format = Printf.bprintf line format in
  let seeds = Array.to_list view.code |> List.filter_map (function P.Noise3 (_,_,_,seed,_) -> Some seed | _ -> None)
    |> List.sort_uniq Int.compare in
  let collecting = match region.result with R.Collect | R.Accumulate (_, true) -> true | _ -> false in
  let accumulating = region.result <> R.Collect in
  let outputs = Array.length view.outputs and width = Array.length view.outputs.(0) in
  let state = if collecting then outputs else 0 in
  let sources = Array.length view.widths in
  let product = region.iteration = R.Product && sources > 1 in
  let skip = Array.to_list region.skip |> List.filter (fun index -> index >= 0) in
  add "function region(inputs, uniforms, outputs, start, stop) {\n";
  if seeds <> [] then begin
    add "%s" perlin;
    List.iter (fun seed ->
      let table = Rays_math.Noise.Private.permutation (Rays_math.Noise.create seed) in
      add "  const table%d = Int32Array.from([%s]);\n" seed
        (String.concat "," (Array.to_list (Array.map string_of_int table)))) seeds
  end;
  Array.iteri (fun k _ -> add "  const in%d = inputs[%d];\n" k k) view.widths;
  if product then begin
    Array.iteri (fun k w -> add "  const n%d = in%d.length / %d;\n" k k w) view.widths;
    add "  const s%d = 1;\n" (sources - 1);
    for k = sources - 2 downto 0 do add "  const s%d = s%d * n%d;\n" k (k + 1) (k + 1) done
  end;
  for k = 0 to outputs - 1 do add "  const out%d = outputs[%d];\n" k k done;
  if accumulating then add "  const st = outputs[%d];\n" state;
  if skip <> [] then begin
    add "  const skip = [%s];\n  let s = 0;\n" (String.concat ", " (List.map string_of_int skip));
    add "  for (let hi = skip.length; s < hi;) {\n    const mid = (s + hi) >> 1;\n";
    add "    if (skip[mid] < start) s = mid + 1; else hi = mid;\n  }\n"
  end;
  add "  for (let i = start; i < stop; i++) {\n";
  if skip <> [] then add "    if (s < skip.length && skip[s] === i) { s++; continue; }\n    const o = i - s;\n"
  else add "    const o = i;\n";
  if product then Array.iteri (fun k _ -> add "    const j%d = Math.floor(i / s%d) %% n%d;\n" k k k) view.widths
  else Array.iteri (fun k _ -> add "    const j%d = i;\n" k) view.widths;
  Array.iteri (fun slot instruction ->
    let expression = match instruction with
      | P.Const value -> number value
      | Input (input, w, component) -> Printf.sprintf "in%d[j%d * %d + %d]" input input w component
      | Uniform (index, component) -> Printf.sprintf "uniforms[%d][%d]" index component
      | Frame _ -> Printf.sprintf "uniforms[%d][%d]" (Array.length view.uniform_widths) slot
      | Accumulator component -> Printf.sprintf "st[%d]" component
      | Binary (op, a, b) -> binary op (register a) (register b)
      | Unary (op, a) -> unary op (register a)
      | Select (c, yes, no) -> Printf.sprintf "%s !== 0 ? %s : %s" (register c) (register yes) (register no)
      | Noise3 (x, y, z, seed, octaves) -> Printf.sprintf "fbm(table%d, %s, %s, %s, %d)" seed
          (register x) (register y) (register z) octaves in
    add "    const r%d = %s;\n" slot expression;
    if checked instruction then add "    if (!Number.isFinite(r%d)) return 1;\n" slot) view.code;
  Array.iteri (fun k registers -> Array.iteri (fun component slot ->
    add "    if (!Number.isFinite(r%d)) return 1;\n" slot;
    (match region.result with
     | R.Collect | R.Accumulate _ -> ()
     | R.Sum _ -> add "    st[%d] = st[%d] !== 0 ? st[%d] + r%d : r%d;\n    if (!Number.isFinite(st[%d])) return 1;\n"
         component width component slot slot component);
    if collecting then add "    out%d[o * %d + %d] = r%d;\n" k (Array.length registers) component slot) registers)
    view.outputs;
  (match region.result with
   | R.Accumulate _ -> Array.iteri (fun component slot -> add "    st[%d] = r%d;\n" component slot) view.outputs.(0)
   | R.Sum _ -> add "    st[%d] = 1;\n" width
   | Collect -> ());
  add "  }\n  return 0;\n}\n";
  Buffer.contents line
