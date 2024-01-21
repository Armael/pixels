open Pixels_network

let buffer = Bytes.create ((4096 / packet_size) * packet_size)
let outlock = Mutex.create ()

let handle_client sock =
  Unix.setsockopt sock Unix.TCP_NODELAY true;
  let continue = ref true in
  while !continue do
    let len = Unix.recv sock buffer 0 (Bytes.length buffer) [] in
    if len = 0 then continue := false else (
      Mutex.lock outlock;
      output stdout buffer 0 len;
      flush stdout;
      Mutex.unlock outlock
    )
  done

let loop sock =
  while true do
    let sock, _addr = Unix.accept sock in
    ignore (Thread.create handle_client sock : Thread.t)
  done

let () =
  let port = ref 4242 in
  Arg.(parse [
    "--port", Set_int port, Printf.sprintf "network port (default: %d)" !port;
  ] (fun _ -> failwith "unexpected argument")
    (Printf.sprintf "usage: %s [..options]" Sys.argv.(0))
  );

  let sock = Unix.(socket PF_INET SOCK_STREAM 0) in
  Unix.setsockopt sock SO_REUSEADDR true;
  Unix.bind sock Unix.(ADDR_INET (Unix.inet_addr_any, !port));
  Unix.listen sock 16;
  Printf.eprintf "Listening on port %d...\n%!" !port;
  loop sock
