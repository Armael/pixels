let send_px buf sock x y r g b =
  Bytes.set_uint16_be buf 0 x;
  Bytes.set_uint16_be buf 2 y;
  Bytes.set_uint8 buf 4 r;
  Bytes.set_uint8 buf 5 g;
  Bytes.set_uint8 buf 6 b;
  ignore @@ Unix.send sock buf 0 (Bytes.length buf) []

let () =
  let ip = ref "127.0.0.1" in
  let port = ref 4242 in
  Arg.(parse [
    "--ip", Set_string ip, Printf.sprintf "IP address (default: %s)" !ip;
    "--port", Set_int port, Printf.sprintf "network port (default: %d)" !port;
  ] (fun _ -> failwith "unexpected argument")
    (Printf.sprintf "usage: %s [..options]" Sys.argv.(0))
  );

  let x = ref 0 in
  let y = ref 0 in

  let sock = Unix.(socket PF_INET SOCK_STREAM 0) in
  let addr = Unix.(ADDR_INET (inet_addr_of_string !ip, !port)) in
  Unix.connect sock addr;
  let buf = Bytes.create 7 in
  while true do
    send_px buf sock !x !y 255 255 255;
    if !x = 0 then y := (!y + 1) mod 100;
    x := (!x + 1) mod 160;
    Unix.sleepf 0.001;
  done
