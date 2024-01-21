# a shared pixel display controllable via TCP

Dependencies: ocaml 5.0, `tsdl`

``` sh
$ dune exec -- server/server.exe
# in another terminal, try one of the basic clients:
$ dune exec -- client/client.exe
# or go write your own!
```

Pass `--help` to the server binary for additional settings.

## protocol

The server expects TCP packets. An TCP packet should contain one or several
concatenated *pixel commands*. A pixel command consists of 7 bytes, and tells
the server to draw one colored pixel:

```
 XX YY R G B 
```
- `XX`: a 16 bits big-endian integer for the `x` coordinate of the pixel
- `YY`: a 16 bits big-endian integer for the `y` coordinate of the pixel
- `R`, `G`, `B`: the color of the pixel (the red, green, blue component 
  respectively)

## anti-spam measures (only for `server/localnet`)

The server implements some basic rate-limiting / anti-spam measures based on the
client IP address, tweakable using the `--nb-clients` and `--max-age` options of
the server.

- there is a limit on the number of visible pixels sent by the same client;
  after this limit, oldest pixels get removed first. If `--nb-clients` (an
  estimation of the number of simultaneous clients) is `N` and the total number
  of pixels of the screen is `S`, then the per-client limit is `S / N`.

- pixels decay and disappear after some time (set by `--max-age`).

## separate receiver/display (`server/{receiver,display}`)

Allows putting the server receiving pixels on a different computer than the
pixels display. The output of the receiver should be piped into the input of the
display.

Example usage:
```
scp _build/default/server/receiver/receiver.exe you@yourserver
ssh -t -t you@yourserver ./receiver.exe | dune exec -- server/display/display.exe
```

(`-t -t` seems to be the adequate hack so that cancelling the whole thing with
^C also kills the receiver process on the server side:
https://unix.stackexchange.com/a/210356)
