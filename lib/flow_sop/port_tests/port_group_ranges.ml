(* sop/group_ranges: one geometry input. Dropped: rows with garbage in connectivity columns the row does not use
   (native discards them, the Lisp normalizer refuses them so that every edit of the table changes its key); every range kind, owner, filter, merge, base and connectivity row,
   rule sequencing, skipped blank names and refused tables. *)
open Rdk
open Port_gate
module P = Param
let rules rows = "rules", P.Text_value (String.concat "\n" rows)
let one r = [rules [r]]
let cells = String.concat "\t"
let row ?(owner = "point") ?(name = "range") ?(base = "") ?(invert = "false") ?(merge = "replace")
    ?(spec = ["start_end"; "0"; "-1"]) ?(filter = ["none"; "0"; "1"; "0"])
    ?(conn = ["none"; ""; ""; "0"; "false"; "edge"; ""; "false"; "false"]) () =
  cells ([owner; name; base; invert; merge] @ spec @ filter @ conn)
let connected ?(region = "") ?(attrs = "") ?(tol = "0.00001") ?(collision = "false") ?(c_owner = "edge")
    ?(pattern = "") ?(keep = "false") ?(remove = "false") () =
  ["connected"; region; attrs; tol; collision; c_owner; pattern; keep; remove]
let disconnected region = ["disconnected"; region; ""; "0"; "false"; "edge"; ""; "false"; "false"]
let owners = ["point"; "vertex"; "primitive"; "edge"]
let specs = ["start_end", ["start_end"; "1"; "4"]; "negative", ["start_end"; "-3"; "2"];
  "from_ends", ["from_ends"; "1"; "1"]; "start_length", ["start_length"; "2"; "3"];
  "partition", ["partition"; "1"; "3"]; "partition outside", ["partition"; "5"; "3"]]
let cases =
  List.concat_map (fun owner -> List.map (fun (label, spec) ->
    Printf.sprintf "%s/%s" owner label, one (row ~owner ~spec ())) specs) owners
  @ List.concat_map (fun merge -> List.map (fun owner ->
      Printf.sprintf "merge %s/%s" merge owner,
      [rules [row ~owner ~name:"a" ~spec:["start_end"; "0"; "6"] (); row ~owner ~name:"a" ~merge ~spec:["start_end"; "3"; "9"] ()]])
      ["point"; "primitive"]) ["replace"; "union"; "intersection"; "subtract"; "xor"]
  @ [ "filter", one (row ~filter:["filter"; "2"; "3"; "1"] ~spec:["start_end"; "0"; "20"] ());
      "filter bad", one (row ~filter:["filter"; "4"; "3"; "0"] ());
      "invert", one (row ~invert:"true" ~spec:["start_end"; "1"; "3"] ());
      "base", one (row ~owner:"point" ~base:"a" ~spec:["start_end"; "0"; "30"] ());
      "base padded", one (row ~owner:"primitive" ~base:" dest_a " ~spec:["start_end"; "0"; "30"] ());
      "base bad", one (row ~base:"[" ());
      "blank name skipped", [rules [row ~name:" " (); row ~name:"kept" ~spec:["start_end"; "0"; "3"] ()]];
      "sequence", [rules [row ~name:"first" ~spec:["start_end"; "0"; "8"] ();
                          row ~name:"second" ~base:"first" ~spec:["start_end"; "2"; "5"] ();
                          row ~owner:"primitive" ~name:"third" ~spec:["partition"; "0"; "2"] ()]];
      "disconnected", one (row ~owner:"primitive" ~conn:(disconnected "") ~spec:["start_end"; "0"; "2"] ());
      "disconnected region", one (row ~owner:"point" ~conn:(disconnected "0") ~spec:["start_end"; "0"; "2"] ());
      "disconnected vertex error", one (row ~owner:"vertex" ~conn:(disconnected "") ());
      "connected plain", one (row ~owner:"primitive" ~conn:(connected ()) ~spec:["start_end"; "0"; "2"] ());
      "connected attrs", one (row ~owner:"primitive" ~conn:(connected ~attrs:"float" ~tol:"0.5" ()) ~spec:["start_end"; "0"; "2"] ());
      "connected collision", one (row ~owner:"point"
        ~conn:(connected ~collision:"true" ~c_owner:"primitive" ~pattern:"a" ()) ~spec:["start_end"; "0"; "2"] ());
      "connected collision edge", one (row ~owner:"point" ~conn:(connected ~collision:"true" ~c_owner:"edge" ~pattern:"a" ()) ~spec:["start_end"; "0"; "2"] ());
      "connected collision primitive keep", one (row ~owner:"point" ~conn:(connected ~collision:"true" ~c_owner:"primitive" ~pattern:"a" ~keep:"true" ()) ~spec:["start_end"; "0"; "2"] ());
      "connected collision keep", one (row ~owner:"point"
        ~conn:(connected ~collision:"true" ~c_owner:"edge" ~pattern:"a" ~keep:"true" ()) ~spec:["start_end"; "0"; "2"] ());
      "connected region remove", one (row ~owner:"primitive"
        ~conn:(connected ~region:"0" ~remove:"true" ~attrs:"float" ()) ~spec:["start_end"; "0"; "1"] ());
      "connected bad collision", one (row ~conn:(connected ~collision:"true" ~pattern:" " ()) ());
      "tokens", one (cells ["Points"; "t"; " a "; "YES"; "Union"; "START_END"; " 0 "; "3"; "NONE"; "0"; "1"; "0";
        "None"; ""; ""; "0"; "false"; "edge"; ""; "false"; "false"]);
      "bad owner", one (row ~owner:"nothing" ());
      "bad merge", one (row ~merge:"nothing" ());
      "bad int", one (row ~spec:["start_end"; "x"; "3"] ());
      "bad kind", one (row ~spec:["nothing"; "0"; "3"] ());
      "bad columns", one (cells ["point"; "range"; ""]);
      "empty table", [rules []] ]
let bench () =
  let grid = Plane_generators.grid ~connectivity:Grid_quads ~columns:300 ~rows:300 ~size:8. () |> Rdk_test_support.get_ok in
  [grid], one (row ~owner:"primitive" ~spec:["start_end"; "0"; "40000"] ~filter:["filter"; "1"; "3"; "0"] ())
let () = register { key = "group_ranges"; native = Sop.Nodes.Group_ranges.factory; inputs = standard_inputs;
  cases; ulps = 4; bench = Some bench }
