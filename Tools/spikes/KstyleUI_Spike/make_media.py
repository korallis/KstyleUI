"""Draw the textures spike's PNGs: mask_2048.png and alpha_test.png.

Usage: python3 Tools/spikes/KstyleUI_Spike/make_media.py [OUT_DIR]
OUT_DIR defaults to the Media folder next to this script. Standard library only.
"""

import struct
import sys
import zlib
from pathlib import Path

MASK_SIZE = 2048
MASK_CHAMFER = 384  # corner cut, in pixels along each edge
MASK_DIAMOND = 320  # half-diagonal of the transparent centre diamond
ALPHA_SIZE = 256


def png(width, height, rows):
    """Encode 8-bit RGBA rows (each 4 * width bytes) as a PNG with filter type 0."""

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    raw = b"".join(b"\x00" + bytes(row) for row in rows)
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def mask_rows(size=MASK_SIZE, chamfer=MASK_CHAMFER, diamond=MASK_DIAMOND):
    """White everywhere. Alpha is 255 inside a chamfered square and 0 in its corners and centre diamond."""
    centre = (size - 1) / 2
    for y in range(size):
        row = bytearray(b"\xff\xff\xff\x00" * size)
        edge = min(y, size - 1 - y)  # distance to the nearer horizontal edge
        lo = max(0, chamfer - edge)
        hi = size - 1 - lo
        if lo <= hi:
            row[4 * lo + 3 : 4 * hi + 4 : 4] = b"\xff" * (hi - lo + 1)
        reach = diamond - abs(y - centre)
        if reach > 0:
            cut_lo = int(centre - reach) + 1
            cut_hi = size - 1 - cut_lo
            if cut_lo <= cut_hi:
                row[4 * cut_lo + 3 : 4 * cut_hi + 4 : 4] = b"\x00" * (cut_hi - cut_lo + 1)
        yield row


def alpha_rows(size=ALPHA_SIZE):
    """Alpha ramps from 0 to 255 left to right. Grey ramps from 0 to 255 top to bottom."""
    scale = 255 / (size - 1)
    alphas = [round(x * scale) for x in range(size)]
    for y in range(size):
        grey = round(y * scale)
        row = bytearray()
        for alpha in alphas:
            row += bytes((grey, grey, grey, alpha))
        yield row


def main(argv):
    out = Path(argv[0]) if argv else Path(__file__).resolve().parent / "Media"
    out.mkdir(parents=True, exist_ok=True)
    (out / "mask_2048.png").write_bytes(png(MASK_SIZE, MASK_SIZE, mask_rows()))
    (out / "alpha_test.png").write_bytes(png(ALPHA_SIZE, ALPHA_SIZE, alpha_rows()))
    for name in ("mask_2048.png", "alpha_test.png"):
        print(f"wrote {out / name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
