open Pixels_network

let udp_buffer = Bytes.create ((4096 / packet_size) * packet_size)

let rec loop sock =
  let len, _ = Unix.recvfrom sock udp_buffer 0 (Bytes.length udp_buffer) [] in
  output_bytes stdout (Bytes.sub udp_buffer 0 len);
  flush stdout;
  loop sock

let () =
  let port = ref 4242 in
  Arg.(parse [
    "--port", Set_int port, Printf.sprintf "network port (default: %d)" !port;
  ] (fun _ -> failwith "unexpected argument")
    (Printf.sprintf "usage: %s [..options]" Sys.argv.(0))
  );

  let sock = Unix.(socket PF_INET SOCK_DGRAM 0) in
  Unix.bind sock Unix.(ADDR_INET (Unix.inet_addr_of_string "0.0.0.0", !port));
  loop sock
