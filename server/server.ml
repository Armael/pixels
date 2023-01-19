open Tsdl
let (let$) = Result.bind

(* incoming UDP pixel drawing commands *)

type pixel = { x : int; y : int; color : Sdl.color }

(* packet size in bytes *)
let packet_size = 2 (* x *) + 2 (* y *) + 3 (* color *)

let pixel_of_bytes (buf : Bytes.t) (off : int) (len : int) : pixel option =
  if off + packet_size > len then None else begin
    let x = Bytes.get_uint16_be buf off in
    let y = Bytes.get_uint16_be buf (off + 2) in
    let r = Bytes.get_uint8 buf (off + 4) in
    let g = Bytes.get_uint8 buf (off + 5) in
    let b = Bytes.get_uint8 buf (off + 6) in
    Some { x; y; color = Sdl.Color.create ~r ~g ~b ~a:255 }
  end

let pixels_of_bytes (buf : Bytes.t) (len : int) : pixel list =
  let rec read off len =
    match pixel_of_bytes buf off len with
    | None -> []
    | Some pkt -> pkt :: read (off + packet_size) (len - packet_size)
  in
  read 0 len

let read_pixels : Unix.file_descr -> pixel list * Unix.sockaddr =
  let udp_buffer = Bytes.create ((4096 / packet_size) * packet_size) in
  fun sock ->
    let (len, sender) = Unix.recvfrom sock udp_buffer 0 (Bytes.length udp_buffer) [] in
    pixels_of_bytes udp_buffer len, sender

(* server state *)

type state =
  { w : int; h : int; scale : int;
    pixel_budget : int; max_age : float;
    pixels : (Unix.inet_addr, (pixel * float (* age *)) list) Hashtbl.t;
    mutex : Mutex.t }

let make_state ~w ~h ~scale ~pixel_budget ~max_age =
  { w; h; scale; pixel_budget; max_age;
    pixels = Hashtbl.create 37;
    mutex = Mutex.create () }

let register_user_pixel st sender time px =
  match sender with
  | Unix.ADDR_UNIX _ -> ()
  | Unix.ADDR_INET (sender_ip, _) ->
    if 0 <= px.x && px.x < st.w && 0 <= px.y && px.y < st.h then begin
      Mutex.lock st.mutex;
      let user_pixels =
        try Hashtbl.find st.pixels sender_ip with Not_found -> [] in
      Hashtbl.replace st.pixels sender_ip ((px, time) :: user_pixels);
      Mutex.unlock st.mutex
    end

(* network loop, reading incoming pixels *)

let rec udp_loop (sock : Unix.file_descr) (st : state) =
  let pxs, sender = read_pixels sock in
  let now = Unix.gettimeofday () in
  List.iter (register_user_pixel st sender now) pxs;
  udp_loop sock st

(* drawing a frame *)

let render_pixel renderer st px =
  let$ () =
    Sdl.set_render_draw_color renderer
      (Sdl.Color.r px.color) (Sdl.Color.g px.color) (Sdl.Color.b px.color)
      255
  in
  Sdl.render_fill_rect renderer
    (Some (Sdl.Rect.create ~x:(px.x * st.scale) ~y:(px.y * st.scale)
            ~w:st.scale ~h:st.scale))

let rec take_pixels after n = function
  | (px, time) :: pxs when n > 0 && time >= after ->
    (px, time) :: take_pixels after (n - 1) pxs
  | _ -> []

let rec reduce (f : 'a -> 'a -> 'a) (default : 'a) (l : 'a list) =
  let rec reduce_step = function
    | ([] | [_]) as l -> l
    | x :: y :: xs -> f x y :: reduce_step xs
  in
  match l with
  | [] -> default
  | [x] -> x
  | _ -> reduce f default (reduce_step l)

let draw_frame renderer st =
  let$ () = Sdl.set_render_draw_color renderer 0 0 0 255 in
  let$ () = Sdl.render_clear renderer in
  let now = Unix.gettimeofday () in
  Mutex.lock st.mutex;
  Hashtbl.filter_map_inplace (fun _ pixels ->
    Some (take_pixels (now -. st.max_age) st.pixel_budget pixels)
  ) st.pixels;
  let pixels_to_draw =
    Hashtbl.to_seq_values st.pixels |> List.of_seq
    |> reduce (List.merge (fun (_, t1) (_, t2) -> Float.compare t2 t1)) []
  in
  Mutex.unlock st.mutex;
  List.iter (fun (px, _) ->
    Result.value ~default:()
      (render_pixel renderer st px)
  ) (List.rev pixels_to_draw);
  Ok ()

(* sdl main loop *)

let rec consume_events ev =
  if Sdl.poll_event (Some ev) then (
    match Sdl.Event.(enum (get ev typ)) with
    | `Quit -> `Quit
    | _ -> consume_events ev
  ) else
    `Continue

let rec sdl_loop window renderer ev st =
  match consume_events ev with
  | `Quit -> Ok ()
  | `Continue ->
    let$ () = draw_frame renderer st in
    Sdl.render_present renderer;
    sdl_loop window renderer ev st

(* server *)

let () =
  let w = ref 160 in
  let h = ref 100 in
  let scale = ref 10 in
  let port = ref 4242 in
  let nb_clients = ref 15 in
  let max_age = ref 20. in
  Arg.(parse [
    "-w", Set_int w, Printf.sprintf "canvas width (default: %d)" !w;
    "-h", Set_int h, Printf.sprintf "canvas height (default: %d)" !h;
    "--scale", Set_int scale, Printf.sprintf "pixel scale (default: %d)" !scale;
    "--port", Set_int port, Printf.sprintf "network port (default: %d)" !port;
    "--nb-clients", Set_int nb_clients,
    Printf.sprintf "estimated nb of clients (used to compute the antispam pixel budget) (default: %d)"
      !nb_clients;
    "--max-age", Set_float max_age,
    Printf.sprintf "maximum age for a pixel (in seconds) (default: %f)"
      !max_age;
  ] (fun _ -> failwith "unexpected argument")
    (Printf.sprintf "usage: %s [..options]" Sys.argv.(0))
  );

  let pixel_budget = !w * !h / !nb_clients in
  let st = make_state ~w:!w ~h:!h ~scale:!scale ~pixel_budget ~max_age:!max_age in

  let sock = Unix.(socket PF_INET SOCK_DGRAM 0) in
  Unix.bind sock Unix.(ADDR_INET (Unix.inet_addr_of_string "0.0.0.0", !port));
  Printf.printf "Listening on port %d...\n%!" !port;

  let _ : unit Domain.t = Domain.spawn (fun () -> udp_loop sock st) in

  let main () =
    let$ () = Sdl.init Sdl.Init.video in
    let$ window =
      Sdl.create_window
        ~w:(st.w * st.scale)
        ~h:(st.h * st.scale) "pixels"
        Sdl.Window.opengl in
    let$ renderer =
      Sdl.create_renderer ~flags:Sdl.Renderer.(accelerated + presentvsync)
        window
    in
    let ev = Sdl.Event.create () in
    let$ () = sdl_loop window renderer ev st in
    Sdl.destroy_window window;
    Sdl.quit ();
    Ok ()
  in
  match main () with
  | Ok () -> exit 0
  | Error (`Msg e) -> Sdl.log "error: %s" e
