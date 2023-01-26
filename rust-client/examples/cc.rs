use pixel::*;
use std::{
    io,
    net::{SocketAddr, SocketAddrV4},
};

pub fn main() -> io::Result<()> {
    let addr = SocketAddr::V4(SocketAddrV4::new([127, 0, 0, 1].into(), 4242));
    let mut client = Client::new(addr)?;

    println!("connected!");

    for x in 10..30 {
        for y in 20..25 {
            let pixel = Pixel::new(Point { x, y }, Color::BLUE);
            client.draw(pixel)?;
        }
    }

    Ok(())
}
