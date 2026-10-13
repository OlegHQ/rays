(* sop/color_by_height: one geometry input (pending draft). The standard fixtures cover an empty
   input, one point (zero extent) and a grid in the y=0 plane (zero extent); the "tall" fixtures
   below add a real height range, a tiny one and mixed signs. *)
open Rdk
open Port_gate
module P = Param
let num name value = name, P.Int_value value
let tall values =
  let count = Array.length values in
  let geometry = points count in
  let positions = Packed.Float3.of_owned ~x:(Array.init count (fun i -> float i *. 0.5))
    ~y:values ~z:(Array.make count 0.25) |> Rdk_test_support.get_string_ok in
  Geometry.create ~positions ~topology:(Geometry.topology geometry) () |> Rdk_test_support.get_string_ok
let inputs = standard_inputs @ List.map (fun (label, values) -> label, [tall values]) [
  "heights", Array.init 4225 (fun i -> sin (float i *. 0.01) *. 3. -. 0.5);
  "tiny_extent", Array.init 33 (fun i -> 1. +. float (i mod 3) *. 1e-16);
  "just_over_extent", [|0.; 2e-15|];
  "negative", [|-5.; -2.; -9.; -0.|]]
let channels = ["low_red"; "low_green"; "low_blue"; "low_alpha"; "high_red"; "high_green"; "high_blue"; "high_alpha"]
let cases =
  List.mapi (fun i name -> name, [num name (i * 31 mod 256)]) channels
  @ [ "all_zero", List.map (fun name -> num name 0) channels;
      "all_max", List.map (fun name -> num name 255) channels;
      "swapped", [num "low_red" 255; num "low_blue" 0; num "high_red" 0; num "high_blue" 255];
      "alpha_ramp", [num "low_alpha" 0; num "high_alpha" 128] ]
let bench () =
  let count = 1_000_000 in
  [tall (Array.init count (fun i -> float (i mod 4001) *. 0.001))], []
let () = register { key = "color_by_height"; native = Sop.Nodes.Color_by_height.factory;
  inputs; cases; ulps = 4; bench = Some bench }
