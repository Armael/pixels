use std::{
    io,
    net::{SocketAddr, SocketAddrV4, Ipv4Addr, UdpSocket},
};

/* TODO: à modifier par l'addresse IP donnée le jour du TP */
static IP : Ipv4Addr = Ipv4Addr::new(127, 0, 0, 1);

/* `draw_pixel(sock, x, y, r, g, b)` envoie une commande de dessin d'un pixel au serveur :
   - `sock` : le socket sur lequel envoyer le message (du même nom dans `main`)
   - `x`, `y` : les coordonnées du pixel à dessiner
   - `r`, `g`, `b` : la couleur du pixel, en composantes rouge/verte/bleue respectivement
     (entre 0 et 255)
*/
pub fn draw_pixel(sock: UdpSocket, x: u16, y: u16, r: u8, g: u8, b: u8) -> io::Result<()> {
    let mut buf = [0u8; 7];
    buf[..2].copy_from_slice(&x.to_be_bytes()[..]);
    buf[2..4].copy_from_slice(&y.to_be_bytes()[..]);
    buf[4] = r;
    buf[5] = g;
    buf[6] = b;
    sock.send(&buf[..])?;
    Ok(())
}

pub fn main() -> io::Result<()> {
    let addr = SocketAddr::V4(SocketAddrV4::new(IP, 4242));
    let sock = UdpSocket::bind("0.0.0.0:1234")?;
    sock.connect(addr)?;

    draw_pixel(sock, 10, 10, 255, 0, 0)?;
    Ok(())
}
