module W = Flow.Workspace
module D = Flow.Diagnostic
module Doc = Editor_document.Workspace_doc
module C = Flow_ir.Core

type lowered = { program : C.program; span : D.span; root : Flow.Eval.residual option }

let ( let* ) = Result.bind

let children (t : W.term) =
  let fields l = List.map snd l in
  match t.node with
  | W.Lit _ | Text _ | Nil | Time | Ref_binding _ | Fn_ref _ -> []
  | Vec ts | List_lit ts | Str ts | List_op (_, ts) | Hof (_, ts) -> ts
  | Call {args; _} | Op {args; _} | Record args -> fields args
  | Call_fn {args; body; _} -> args @ Option.to_list body
  | Graph_ref {inputs; _} -> fields inputs
  | Let (bindings, body) -> fields bindings @ [body]
  | State {init; step; _} -> [init; step]
  | Loop {accs; clauses; body; _} -> fields accs @ fields clauses @ [body]
  | If (a, b, c) -> [a; b; c]
  | Cond (arms, d) -> List.concat_map (fun (a, b) -> [a; b]) arms @ [d]
  | Case (s, arms, d) -> s :: d :: fields arms
  | Fn {body; capture; _} -> body :: Option.to_list capture
  | Get (b, _) | Expanded {body = b; _} -> [b]
  | Assoc (r, args) -> r :: fields args
  | Bypass call -> call :: Option.to_list (W.bypass_input call)

(* The first reference from the draw graph to a sop or scene graph, or a catalog call of those contexts. *)
let foreign (doc : Doc.t) (draw : W.graph) =
  let graphs = doc.checked.graphs @ doc.checked.defs in
  let seen = Hashtbl.create 8 in
  let rec visit (t : W.term) =
    let here = match t.node with
      | W.Graph_ref {graph; _} ->
          (match List.find_opt (fun (g : W.graph) -> g.name = graph) graphs with
           | Some g when g.context = Flow.Context.sop || g.context = Flow.Context.scene -> Some (graph, g.context)
           | Some g when not (Hashtbl.mem seen g.name) -> Hashtbl.add seen g.name (); Option.map (fun x -> x) (visit_graph g)
           | _ -> None)
      | Call {kind; ctx; _} when ctx = Flow.Context.sop || ctx = Flow.Context.scene -> Some (kind, ctx)
      | _ -> None in
    match here with
    | Some (name, ctx) -> Some (t, name, ctx)
    | None -> List.find_map visit (children t)
  and visit_graph (g : W.graph) = Option.map (fun (_, n, c) -> n, c) (visit g.body) in
  visit draw.body

let first_draw (doc : Doc.t) =
  match List.find_opt (fun (g : W.graph) -> g.context = Flow.Context.draw) doc.checked.graphs with
  | Some g -> Ok g
  | None -> Error (D.error ~code:"E_WEB_GRAPH" "The workspace has no draw graph to export.")

let lower (doc : Doc.t) =
  let* draw = first_draw doc in
  let* () = match foreign doc draw with
    | Some ((t : W.term), name, ctx) ->
        Error (D.error ~span:t.form.span ~code:"E_WEB_GRAPH"
          (Printf.sprintf "The web export draws 2D canvas graphs only; this reaches the %s %s." (Flow.Context.name ctx) name))
    | None -> Ok () in
  let* lowered = Flow_sop.Lower.of_checked ~reference:true ~factories:Sop_catalog.Editor.factories
      ~inputs:doc.inputs doc.checked in
  let evaluated = lowered.evaluated in
  let value = List.assoc draw.name evaluated.results in
  match Flow_ir.Core_draw.lower evaluated.plan value with
  | Ok (program, root) -> Ok {program; span = draw.form.span; root}
  | Error message ->
      Error (D.error ~span:draw.form.span ~code:"E_WEB_LOWER" ("This draw graph does not lower to the core: " ^ message))

(* ---- the files ---- *)

let span_of_region (r : C.Region.t) = r.term.form.span

(* Every statement of the program, nested ones included. *)
let rec all_statements (body : C.statement list) =
  List.concat_map (fun (s : C.statement) -> s :: (match s.node with
    | If {yes; no; _} -> all_statements yes @ all_statements no
    | Iterate {body; _} -> all_statements body
    | Counted {init; body; _} -> all_statements init @ all_statements body
    | State_read {init; _} -> all_statements init
    | _ -> [])) body

(* The frame facts a region may read, named as the region's Frame instructions name them. *)
let frame_facts = ["t"; "frame/dt"; "frame/index"; "frame/width"; "frame/height"]

let number x = Printf.sprintf "%.17g" x
let list f xs = "[" ^ String.concat ", " (List.map f xs) ^ "]"

type files = (string * string) list

(* A region is exported as data when nothing it reads changes with the frame: two probes with different
   clocks, pointers, sizes and frame numbers must prepare the same inputs and captures. *)
let region_entry ~data k (r : C.Region.t) =
  let refuse code message = Error (D.error ~span:(span_of_region r) ~code message) in
  match Flow_ir.Packed.of_region r with
  | Error (d :: _) -> Error d
  | Error [] -> refuse "E_WEB_REGION" "This region does not compile."
  | Ok packed ->
      let view = Flow_ir.Packed.Private.view packed in
      if r.result <> C.Region.Collect || Array.length view.outputs <> 1 then
        refuse "E_WEB_REGION" "The web export runs collecting single-output regions only; this sum or fold needs a later release."
      else
        let probe t frame = { (Frame_input.at_time t) with dt = 0.25; frame; tick = frame; size = (640 + frame, 480);
          pointer = (100. +. t, 100.) } in
        let prepare live = try Flow_ir.Packed.Private.prepare packed ~live with Not_found | Invalid_argument _ | Failure _ ->
          Error (D.error ~span:(span_of_region r) ~code:"E_WEB_REGION" "This region could not be prepared.") in
        let* a = prepare (probe 0. 1) in
        let* b = prepare (probe 0.5 7) in
        if a.arrays <> b.arrays || a.uniforms <> b.uniforms || a.count <> b.count then
          refuse "E_WEB_CAPTURE" "This region reads a value that changes from frame to frame; the web export needs its inputs fixed."
        else if Array.exists (Array.exists (fun x -> not (Float.is_finite x))) a.uniforms then
          refuse "E_WEB_REGION" "This region captures a non-finite value."
        else begin
          let frame = Array.to_list view.code |> List.mapi (fun slot -> function
            | C.Region.Frame name -> [slot, name] | _ -> []) |> List.concat in
          match List.find_opt (fun (_, name) -> not (List.mem name frame_facts)) frame with
          | Some (_, name) -> refuse "E_WEB_REGION" ("This region reads the frame fact " ^ name ^ ", which the web runtime does not provide.")
          | None ->
              let skipped = Array.to_list r.skip |> List.filter (fun i -> i >= 0 && i < a.count) |> List.length in
              let placed = if Array.length a.arrays = 0 then "[]" else list (fun values ->
                let offset, length = data values in Printf.sprintf "[%d, %d]" offset length) (Array.to_list a.arrays) in
              let gpu = match a.count with
                | n when n >= 1024 && Flow_web.Target.region packed ~count:(Some n) = [] ->
                    (match Flow_web.Wgsl.kernel packed with Ok w -> Some w | Error _ -> None)
                | _ -> None in
              let text = Printf.sprintf
                "{\"source\": %s, \"count\": %d, \"kept\": %d, \"inputs\": %s, \"uniforms\": %s, \"frame\": %s, \"length\": %d, \"width\": %d, \"kernel\": %s}"
                (Flow_web.Kernel_table.json_string (Flow_web.Js.region packed)) a.count (a.count - skipped) placed
                (list (fun u -> list number (Array.to_list u)) (Array.to_list a.uniforms))
                (list (fun (slot, name) -> Printf.sprintf "[%d, %s]" slot (Flow_web.Kernel_table.json_string name)) frame)
                (Array.length view.code) (Array.length view.outputs.(0))
                (match gpu with Some _ -> Printf.sprintf "\"k%d\"" k | None -> "null") in
              Ok (text, Option.map (fun (w : Flow_web.Wgsl.wgsl) ->
                let id = Printf.sprintf "k%d" k in Flow_web.Kernel_table.entry ~id w, "// kernel " ^ id ^ "\n" ^ w.source) gpu)
        end

let index_html name = Printf.sprintf {|<!doctype html>
<meta charset="utf-8">
<title>%s</title>
<style>html, body { margin: 0; height: 100%%; background: #080a10; } canvas { display: block; width: 100%%; height: 100%%; }</style>
<!-- This page needs cross-origin isolation (Cross-Origin-Opener-Policy: same-origin and
     Cross-Origin-Embedder-Policy: require-corp) for its worker pool; serve it with those headers. -->
<canvas id="canvas"></canvas>
<script type="module">
import { start } from "./runtime/runtime.js";
import * as program from "./program.js";
const data = await (await fetch("data.bin")).arrayBuffer();
await start(document.getElementById("canvas"), program, { data });
</script>
|} name

let files (doc : Doc.t) (lowered : lowered) : (files, D.t) result =
  let program = lowered.program in
  let statements = all_statements program.body in
  let* () = match List.find_opt (fun (s : C.statement) -> match s.node with Draw (Image _) -> true | _ -> false) statements with
    | Some s ->
        Error (D.error ~span:(Option.value s.source.span ~default:lowered.span) ~code:"E_WEB_IMAGE"
          "The web export cannot draw an image yet: a draw image needs a host image resolver.")
    | None -> Ok () in
  let data = Buffer.create 4096 in
  let store values =
    let offset = Buffer.length data in
    Array.iter (fun x -> Buffer.add_int64_le data (Int64.bits_of_float x)) values;
    offset, Array.length values in
  let* entries = Array.to_list program.regions |> List.mapi (fun k r -> k, r)
    |> List.fold_left (fun acc (k, r) -> let* acc = acc in let* entry = region_entry ~data:store k r in Ok (entry :: acc)) (Ok [])
    |> Result.map List.rev in
  let* js = Flow_web.Js.frame ~store:(fun values ->
    let offset, length = store values in Printf.sprintf "new Float64Array(rt.data, %d, %d)" offset length) program in
  let regions = "export const regions = [" ^ String.concat ",\n  " (List.map fst entries) ^ "];\n" in
  let kernels = List.filter_map snd entries in
  let name = Doc.name doc in
  Ok ([ "program.js", js ^ "\n" ^ regions;
        "program.map", Flow_web.Js.frame_map program;
        "kernels.json", Flow_web.Kernel_table.table (List.map fst kernels);
        "kernels.wgsl", String.concat "\n" (List.map snd kernels);
        "data.bin", Buffer.contents data;
        "index.html", index_html name ]
      @ List.map (fun (file, text) -> "runtime/" ^ file, text) Web_runtime.files)

let load path =
  let read p = In_channel.with_open_bin p In_channel.input_all in
  let text = read path in
  let imports = match Doc.import_paths text with
    | Ok relative -> Ok (List.map (fun r -> r, read (Filename.concat (Filename.dirname path) r)) relative)
    | Error ds -> Error ds
    | exception Sys_error message -> Error [D.error ~code:"E_IMPORT" message] in
  text, (match imports with
    | Error ds -> Error ds
    | Ok imports ->
        match Editor_document.Contexts.catalog ~version:Flow_sop.Manifest.version Sop_catalog.Editor.factories with
        | Error d -> Error [d]
        | Ok catalog -> Result.map fst (Doc.check_text ~imports catalog text))
