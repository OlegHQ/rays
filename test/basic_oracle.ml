(* Test-only oracle: examples/basic/main.ml as it stood at 3baf0095, up to its
   application entry point. The program was deleted when the example became a Lisp
   workspace; test_2d_ports compares the port's scene with this one. Do not edit it
   to follow the port. *)
open Rays

type model = {
  phase : float;
}

let init _frame =
  {
    phase = 0.;
  }

let update model (frame : Frame.t) =
  { phase = model.phase +. frame.dt }

let view model (frame : Frame.t) =
  let radius = 42 + int_of_float (10. *. sin (model.phase *. 2.)) in
  Scene.[
    clear (Color.rgb 20 22 28);
    circle ~at:(frame.width / 2, frame.height / 2) ~radius
      ~fill:(Color.rgb 90 170 240) ();
    text ~at:(12, 12)
      (Printf.sprintf "%d × %d  frame %d"
        frame.width frame.height frame.count);
  ]
