(* TODO: à modifier par l'addresse IP donnée le jour du TP *)
let ip = "127.0.0.1"

(* [draw_pixel sock x y r g b] envoie une commande de dessin d'un pixel au serveur :
   - [sock] : le socket sur lequel envoyer le message (du même nom plus bas)
   - [x], [y] : les coordonnées du pixel à dessiner
   - [r], [g], [b] : la couleur du pixel, en composantes rouge/verte/bleue respectivement
     (entre 0 et 255)
*)
let draw_pixel sock x y r g b =
  let buf = Bytes.create 7 in
  Bytes.set_uint16_be buf 0 x;
  Bytes.set_uint16_be buf 2 y;
  Bytes.set_uint8 buf 4 r;
  Bytes.set_uint8 buf 5 g;
  Bytes.set_uint8 buf 6 b;
  ignore @@ Unix.send sock buf 0 (Bytes.length buf) []

let () =
  let sock = Unix.(socket PF_INET SOCK_STREAM 0) in
  let addr = Unix.(ADDR_INET (inet_addr_of_string ip, 4242)) in

  Unix.connect sock addr;
  draw_pixel sock 10 10 255 0 0;
  Unix.close sock
