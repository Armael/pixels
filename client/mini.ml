let ip = "127.0.0.1"
let port = 4242

let send_px sock addr x y r g b =
  let buf = Bytes.create 7 in
  Bytes.set_uint16_be buf 0 x;
  Bytes.set_uint16_be buf 2 y;
  Bytes.set_uint8 buf 4 r;
  Bytes.set_uint8 buf 5 g;
  Bytes.set_uint8 buf 6 b;
  ignore @@ Unix.sendto sock buf 0 (Bytes.length buf) [] addr

let () =
  let sock = Unix.(socket PF_INET SOCK_DGRAM 0) in
  let addr = Unix.(ADDR_INET (inet_addr_of_string ip, port)) in

  send_px sock addr 10 10 255 0 0
