open Pixels_network
open Tsdl
let (let$) = Result.bind

let render_pixel renderer (px : pixel) scale alpha =
  let$ () = Sdl.set_render_draw_color renderer px.r px.g px.b alpha in
  Sdl.render_fill_rect renderer
    (Some (Sdl.Rect.create ~x:(px.x * scale) ~y:(px.y * scale)
            ~w:scale ~h:scale))

let render_pixels_with_age renderer pixels ~scale ~max_age ~decay ~now =
  List.iter (fun (px, time) ->
    let decayed = Float.min (time -. (now -. max_age -. decay)) decay in
    let alpha = int_of_float (decayed *. 255. /. decay) in
    Result.value ~default:() (render_pixel renderer px scale alpha)
  ) (List.rev pixels) (* XXX behavior with alpha blending in case of overlapping pixels? *)

let rec consume_events ev =
  if Sdl.poll_event (Some ev) then (
    match Sdl.Event.(enum (get ev typ)) with
    | `Quit -> `Quit
    | _ -> consume_events ev
  ) else
    `Continue

let rec sdl_loop window renderer ev draw_frame =
  match consume_events ev with
  | `Quit -> Ok ()
  | `Continue ->
    let$ () = draw_frame renderer in
    Sdl.render_present renderer;
    sdl_loop window renderer ev draw_frame

let sdl_main_loop window draw_frame =
  let$ renderer =
    Sdl.create_renderer ~flags:Sdl.Renderer.(accelerated + presentvsync)
      window
  in
  let$ () = Sdl.set_render_draw_blend_mode renderer Sdl.Blend.mode_blend in
  let ev = Sdl.Event.create () in
  sdl_loop window renderer ev draw_frame
