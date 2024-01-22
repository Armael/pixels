use std::{
    io, io::Write,
    net::{SocketAddr, SocketAddrV4, Ipv4Addr, TcpStream},
};

/* TODO: à modifier par l'addresse IP donnée le jour du TP */
static IP : Ipv4Addr = Ipv4Addr::new(127, 0, 0, 1);

/* `draw_pixel(stream, x, y, r, g, b)` envoie une commande de dessin d'un pixel au serveur :
   - `stream` : le stream sur lequel envoyer le message (du même nom dans `main`)
   - `x`, `y` : les coordonnées du pixel à dessiner
   - `r`, `g`, `b` : la couleur du pixel, en composantes rouge/verte/bleue respectivement
     (entre 0 et 255)
*/
pub fn draw_pixel(stream: &mut TcpStream, x: u16, y: u16, r: u8, g: u8, b: u8) -> io::Result<()> {
    let mut buf = [0u8; 7];
    buf[..2].copy_from_slice(&x.to_be_bytes()[..]);
    buf[2..4].copy_from_slice(&y.to_be_bytes()[..]);
    buf[4] = r;
    buf[5] = g;
    buf[6] = b;
    stream.write(&buf[..])?;
    Ok(())
}

pub fn main() -> io::Result<()> {
    let addr = SocketAddr::V4(SocketAddrV4::new(IP, 4242));
    let mut stream = TcpStream::connect(addr)?;

    draw_pixel(&mut stream, 10, 10, 255, 0, 0)?;
    Ok(())
}
