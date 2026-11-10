#!/usr/bin/env python3
"""Draw the Zalla mark into the Windows asset folder. No third-party packages."""

import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "src" / "Zalla.App" / "Assets"
RED = (227, 59, 79, 255)
WHITE = (255, 255, 255, 255)
NAVY = (7, 20, 34, 255)


def z_color(nx: float, ny: float, radius: float) -> tuple[int, int, int, int] | None:
    dx, dy = nx - 0.5, ny - 0.5
    if dx * dx + dy * dy > radius * radius:
        return None
    if 0.30 <= nx <= 0.70 and abs(ny - 0.33) <= 0.045:
        return WHITE
    if 0.30 <= nx <= 0.70 and abs(ny - 0.67) <= 0.045:
        return WHITE
    x1, y1, x2, y2 = 0.68, 0.36, 0.32, 0.64
    vx, vy = x2 - x1, y2 - y1
    length = vx * vx + vy * vy
    t = ((nx - x1) * vx + (ny - y1) * vy) / length
    t = max(0.0, min(1.0, t))
    px, py = x1 + t * vx, y1 + t * vy
    if (nx - px) ** 2 + (ny - py) ** 2 < 0.0016:
        return WHITE
    return RED


def png(width: int, height: int, pixel) -> bytes:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixel(x, y))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def circle_pixel(size: int, tile: tuple[int, int, int, int] | None):
    def pixel(x: int, y: int) -> tuple[int, int, int, int]:
        color = z_color((x + 0.5) / size, (y + 0.5) / size, 0.46)
        if color is None:
            return tile if tile is not None else (0, 0, 0, 0)
        return color

    return pixel


def wide_pixel(x: int, y: int) -> tuple[int, int, int, int]:
    # 310x150 tile, mark centered.
    side = 150
    left = (310 - side) // 2
    if left <= x < left + side:
        return circle_pixel(side, NAVY)(x - left, y)
    return NAVY


def dib(size: int) -> bytes:
    """Classic 32-bit BMP icon. The resource compiler rejects PNG-compressed icons."""
    pixel = circle_pixel(size, None)
    xor = bytearray()
    for y in range(size - 1, -1, -1):
        for x in range(size):
            red, green, blue, alpha = pixel(x, y)
            xor.extend((blue, green, red, alpha))

    row_bytes = ((size + 31) // 32) * 4
    mask = bytes(row_bytes * size)
    image = len(xor) + len(mask)
    header = struct.pack("<IiiHHIIiiII", 40, size, size * 2, 1, 32, 0, image, 0, 0, 0, 0)
    return header + bytes(xor) + mask


def ico(images: list[tuple[int, bytes]]) -> bytes:
    count = len(images)
    header = struct.pack("<HHH", 0, 1, count)
    entries = b""
    offset = 6 + 16 * count
    blobs = b""
    for size, blob in images:
        entries += struct.pack("<BBBBHHII", size if size < 256 else 0, size if size < 256 else 0, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
        blobs += blob
    return header + entries + blobs


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = {
        "Square44x44Logo.png": png(44, 44, circle_pixel(44, NAVY)),
        "StoreLogo.png": png(50, 50, circle_pixel(50, NAVY)),
        "Square150x150Logo.png": png(150, 150, circle_pixel(150, NAVY)),
        "Wide310x150Logo.png": png(310, 150, wide_pixel),
    }
    for name, blob in tiles.items():
        (OUT / name).write_bytes(blob)

    icon_sizes = [16, 32, 48, 256]
    images = [(size, dib(size)) for size in icon_sizes]
    (OUT / "zalla.ico").write_bytes(ico(images))
    print(f"Wrote icons in {OUT}")


if __name__ == "__main__":
    main()
