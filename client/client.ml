let rgb_of_hue h =
  let x = 1. -. Float.abs (fst (Float.modf (float h /. 120.)) *. 2. -. 1.) in
  let r', g', b' =
    if h < 60 then (1., x, 0.)
    else if h < 120 then (x, 1., 0.)
    else if h < 180 then (0., 1., x)
    else if h < 240 then (0., x, 1.)
    else if h < 300 then (x, 0., 1.)
    else (1., 0., x)
  in
  int_of_float (r' *. 255.),
  int_of_float (g' *. 255.),
  int_of_float (b' *. 255.)

let send_px buf sock x y r g b =
  Bytes.set_uint16_be buf 0 x;
  Bytes.set_uint16_be buf 2 y;
  Bytes.set_uint8 buf 4 r;
  Bytes.set_uint8 buf 5 g;
  Bytes.set_uint8 buf 6 b;
  ignore @@ Unix.send sock buf 0 (Bytes.length buf) []

let () =
  let x = ref 0 in
  let y = ref 0 in
  let h = ref 0 in
  let sock = Unix.(socket PF_INET SOCK_STREAM 0) in
  let addr = Unix.(ADDR_INET (inet_addr_of_string "127.0.0.1", 4242)) in
  Unix.connect sock addr;
  let buf = Bytes.create 7 in
  while true do
    let r, g, b = rgb_of_hue !h in
    send_px buf sock !x !y r g b;
    x := (!x + 1) mod 160;
    y := (!y + 1) mod 99;
    h := (!h + 1) mod 360;
    Unix.sleepf 0.005;
  done
