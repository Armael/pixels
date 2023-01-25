use std::{
    io,
    net::{SocketAddr, UdpSocket},
};

/// A RGB color.
#[derive(Debug, Copy, Clone, Default)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Color {
    pub const RED: Color = Color { r: 255, g: 0, b: 0 };
    pub const GREEN: Color = Color { r: 0, g: 255, b: 0 };
    pub const BLUE: Color = Color { r: 0, g: 0, b: 255 };
    pub const BLACK: Color = Color { r: 0, g: 0, b: 0 };
    pub const WHITE: Color = Color {
        r: 255,
        g: 255,
        b: 255,
    };

    #[inline]
    fn to_buf(&self, into: &mut [u8; 3]) {
        into[0] = self.r;
        into[1] = self.g;
        into[2] = self.b;
    }
}

#[derive(Debug, Copy, Clone, Default)]
pub struct Point {
    pub x: u16,
    pub y: u16,
}

impl Point {
    #[inline]
    fn to_buf(&self, into: &mut [u8; 4]) {
        let x = self.x.to_be_bytes();
        into[..2].copy_from_slice(&x[..]);
        let y = self.y.to_be_bytes();
        into[2..].copy_from_slice(&y[..]);
    }
}

/// A pixel on the screen.
#[derive(Debug, Copy, Clone, Default)]
pub struct Pixel {
    pub point: Point,
    pub color: Color,
}

const PIXEL_SIZE: usize = 4 + 3;

impl Pixel {
    pub fn new(point: Point, color: Color) -> Self {
        Self { point, color }
    }

    fn to_buf(&self, into: &mut [u8; PIXEL_SIZE]) {
        self.point.to_buf((&mut into[0..4]).try_into().unwrap());
        self.color.to_buf((&mut into[4..7]).try_into().unwrap());
    }
}

/// Client
pub struct Client {
    sock: UdpSocket,
}

impl Client {
    pub fn new(addr: SocketAddr) -> io::Result<Client> {
        let sock = UdpSocket::bind("0.0.0.0:1234")?;
        sock.connect(addr)?;
        let client = Client { sock };
        Ok(client)
    }

    /// Send a command to the server, asking it to draw the given pixel.
    pub fn draw(&mut self, pixel: Pixel) -> io::Result<()> {
        let mut buf = [0u8; PIXEL_SIZE];
        pixel.to_buf(&mut buf);
        self.sock.send(&buf[..])?;
        Ok(())
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn pix_to_buf() {
        let mut buf = [0u8; PIXEL_SIZE];
        let pix = Pixel::new(Point { x: 0, y: 1 }, Color::BLUE);
        pix.to_buf(&mut buf);
        assert_eq!([0, 0, 0, 1, 0, 0, 255], buf);
    }
}
