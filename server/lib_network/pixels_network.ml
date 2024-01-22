(* incoming UDP pixel drawing commands *)

type pixel = { x : int; y : int; r : int; g : int; b : int }

(* packet size in bytes *)
let packet_size = 2 (* x *) + 2 (* y *) + 3 (* color *)

let pixel_of_bytes (buf : Bytes.t) (off : int) (len : int) : pixel option =
  if len < packet_size then None else begin
    let x = Bytes.get_uint16_be buf off in
    let y = Bytes.get_uint16_be buf (off + 2) in
    let r = Bytes.get_uint8 buf (off + 4) in
    let g = Bytes.get_uint8 buf (off + 5) in
    let b = Bytes.get_uint8 buf (off + 6) in
    Some { x; y; r; g; b }
  end

let pixels_of_bytes (buf : Bytes.t) (len : int) : pixel list =
  let rec read off len =
    match pixel_of_bytes buf off len with
    | None -> []
    | Some pkt -> pkt :: read (off + packet_size) (len - packet_size)
  in
  read 0 len
