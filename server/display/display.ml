open Pixels_network
open Pixels_graphics
open Tsdl
let (let$) = Result.bind

type state =
  { w : int; h : int; scale : int;
    max_age : float; decay : float;
    mutable pixels : (pixel * float (* age *)) list;
    mutex : Mutex.t }

let make_state ~w ~h ~scale ~max_age ~decay =
  { w; h; scale; max_age; decay;
    pixels = [];
    mutex = Mutex.create () }

let register_pixel st time px =
  if 0 <= px.x && px.x < st.w && 0 <= px.y && px.y < st.h then begin
    Mutex.lock st.mutex;
    st.pixels <- (px, time) :: st.pixels;
    Mutex.unlock st.mutex
  end

(* loop reading incoming pixels from stdin *)

let px_buf = Bytes.create packet_size

let stdin_loop (st : state) =
  while true do
    really_input stdin px_buf 0 packet_size;
    Option.iter (register_pixel st (Unix.gettimeofday ()))
      (pixel_of_bytes px_buf 0 packet_size)
  done

(* drawing a frame *)

let rec take_pixels after = function
  | (px, time) :: pxs when time >= after ->
    (px, time) :: take_pixels after pxs
  | _ -> []

let draw_frame renderer st =
  let$ () = Sdl.set_render_draw_color renderer 0 0 0 255 in
  let$ () = Sdl.render_clear renderer in
  let now = Unix.gettimeofday () in
  Mutex.lock st.mutex;
  let pixels_to_draw = st.pixels in
  st.pixels <- take_pixels (now -. st.max_age -. st.decay) st.pixels;
  Mutex.unlock st.mutex;
  render_pixels_with_age renderer pixels_to_draw
    ~scale:st.scale ~max_age:st.max_age ~decay:st.decay ~now;
  Ok ()

let () =
  let w = ref 160 in
  let h = ref 100 in
  let scale = ref 10 in
  let max_age = ref 19. in
  let decay = ref 1. in
  Arg.(parse [
    "-w", Set_int w, Printf.sprintf "canvas width (default: %d)" !w;
    "-h", Set_int h, Printf.sprintf "canvas height (default: %d)" !h;
    "--scale", Set_int scale, Printf.sprintf "pixel scale (default: %d)" !scale;
    "--max-age", Set_float max_age,
    Printf.sprintf "maximum age for a pixel (in seconds) (default: %f)"
      !max_age;
    "--decay", Set_float decay,
    Printf.sprintf "pixel decay time (in seconds) (default: %f)"
      !decay;
  ] (fun _ -> failwith "unexpected argument")
    (Printf.sprintf "usage: %s [..options]" Sys.argv.(0))
  );

  let st =
    make_state ~w:!w ~h:!h ~scale:!scale
      ~max_age:!max_age ~decay:!decay
  in

  let _ : unit Domain.t = Domain.spawn (fun () -> stdin_loop st) in

  let main () =
    let$ () = Sdl.init Sdl.Init.video in
    let$ window =
      Sdl.create_window
        ~w:(st.w * st.scale)
        ~h:(st.h * st.scale) "pixels"
        Sdl.Window.opengl in
    let$ () = sdl_main_loop window (fun renderer -> draw_frame renderer st) in
    Sdl.destroy_window window;
    Sdl.quit ();
    Ok ()
  in
  match main () with
  | Ok () -> exit 0
  | Error (`Msg e) -> Sdl.log "error: %s" e
