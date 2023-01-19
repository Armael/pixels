let send_px buf sock addr x y r g b =
  Bytes.set_uint16_be buf 0 x;
  Bytes.set_uint16_be buf 2 y;
  Bytes.set_uint8 buf 4 r;
  Bytes.set_uint8 buf 5 g;
  Bytes.set_uint8 buf 6 b;
  ignore @@ Unix.sendto sock buf 0 (Bytes.length buf) [] addr

let () =
  let x = ref 0 in
  let y = ref 0 in

  let sock = Unix.(socket PF_INET SOCK_DGRAM 0) in
  let addr = Unix.(ADDR_INET (inet_addr_of_string "127.0.0.1", 4242)) in
  let buf = Bytes.create 7 in
  while true do
    send_px buf sock addr !x !y 255 255 255;
    if !x = 0 then y := (!y + 1) mod 100;
    x := (!x + 1) mod 160;
    Unix.sleepf 0.001;
  done
