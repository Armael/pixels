open Pixels_network
open Pixels_graphics
open Tsdl
let (let$) = Result.bind

let read_pixels : Unix.file_descr -> pixel list =
  let buffer = Bytes.create ((4096 / packet_size) * packet_size) in
  fun sock ->
    let len = Unix.recv sock buffer 0 (Bytes.length buffer) [] in
    pixels_of_bytes buffer len

(* server state *)

type state =
  { w : int; h : int; scale : int;
    pixel_budget : int; max_age : float; decay : float;
    pixels : (Unix.inet_addr, (pixel * float (* age *)) list) Hashtbl.t;
    mutex : Mutex.t }

let make_state ~w ~h ~scale ~pixel_budget ~max_age ~decay =
  { w; h; scale; pixel_budget; max_age; decay;
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

let handle_client st addr sock =
  Unix.setsockopt sock Unix.TCP_NODELAY true;
  let continue = ref true in
  while !continue do
    match read_pixels sock with
    | [] -> continue := false
    | pxs ->
      let now = Unix.gettimeofday () in
      List.iter (register_user_pixel st addr now) pxs
  done

let tcp_loop (sock : Unix.file_descr) (st : state) =
  while true do
    let sock, addr = Unix.accept sock in
    ignore (Thread.create (handle_client st addr) sock : Thread.t)
  done


(* drawing a frame *)

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
    Some (take_pixels (now -. st.max_age -. st.decay) st.pixel_budget pixels)
  ) st.pixels;
  let pixels_to_draw =
    Hashtbl.to_seq_values st.pixels |> List.of_seq
    |> reduce (List.merge (fun (_, t1) (_, t2) -> Float.compare t2 t1)) []
  in
  Mutex.unlock st.mutex;
  render_pixels_with_age renderer pixels_to_draw
    ~scale:st.scale ~max_age:st.max_age ~decay:st.decay ~now;
  Ok ()

(* server *)

let () =
  let w = ref 160 in
  let h = ref 100 in
  let scale = ref 10 in
  let port = ref 4242 in
  let nb_clients = ref 15 in
  let max_age = ref 19. in
  let decay = ref 1. in
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
    "--decay", Set_float decay,
    Printf.sprintf "pixel decay time (in seconds) (default: %f)"
      !decay;
  ] (fun _ -> failwith "unexpected argument")
    (Printf.sprintf "usage: %s [..options]" Sys.argv.(0))
  );

  let pixel_budget = !w * !h / !nb_clients in
  let st =
    make_state ~w:!w ~h:!h ~scale:!scale ~pixel_budget
      ~max_age:!max_age ~decay:!decay
  in

  let sock = Unix.(socket PF_INET SOCK_STREAM 0) in
  Unix.setsockopt sock SO_REUSEADDR true;
  Unix.bind sock Unix.(ADDR_INET (Unix.inet_addr_any, !port));
  Unix.listen sock 16;
  Printf.printf "Listening on port %d...\n%!" !port;

  let _ : unit Domain.t = Domain.spawn (fun () -> tcp_loop sock st) in

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
