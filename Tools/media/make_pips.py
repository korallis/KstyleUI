"""make_pips.py: draw the druid's class-themed combo point pips into Media/Textures/Pips/.

Three 64x64 textures share one silhouette: the lit pip with its colours baked in, the empty socket, and the
white shape that masks the slide-in and slash and that the game tints for the flare. The pip is three amber
claw gouges with green rims, raked down and left. Every pixel is the mean of 4x4 samples of premultiplied
colour, as make_media.py samples its shapes. Coordinates are texels, origin top left, y down. Standard
library only.

    python3 Tools/media/make_pips.py          # write the textures
    python3 Tools/media/make_pips.py --check  # compare with the files on disk
"""

import argparse
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import make_media as mm

ROOT = HERE.parent.parent
FOLDER = "Media/Textures/Pips"
SIZE = 64
OUTLINE = 2.4  # texels of dark keyline round each pip, so it reads on bright and dark ground


def hexrgb(text):
    return tuple(int(text[i : i + 2], 16) / 255 for i in (0, 2, 4))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def ramp(stops, t):
    """Colour at t along stops [(t, rgb), ...], sorted by t."""
    if t <= stops[0][0]:
        return stops[0][1]
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            return mix(c0, c1, (t - t0) / (t1 - t0))
    return stops[-1][1]


KEYLINE = hexrgb("08090b")
AMBER = [(0.0, hexrgb("fff6d0")), (0.25, hexrgb("ffd25a")), (0.6, hexrgb("f39a1c")), (1.0, hexrgb("a8520c"))]
MOSS, MOSS_DIM = hexrgb("8fd651"), hexrgb("3f7a25")

# Three claw gouges raked down and to the left: each a curved stroke, blunt where the claw went in at the upper
# right and drawn out to a point at the lower left.
CLAWS = [(-16.0, 24.0, 6.4), (0.0, 29.0, 7.4), (16.0, 22.0, 6.4)]  # offset across, half length, half width
RAKE = (-0.62, 0.785)  # along a gouge, down and left
ACROSS = (RAKE[1], -RAKE[0])  # to the right and down
BOW, ENTRY = 4.0, 0.14


def claw(x, y):
    """(signed distance, share along from the entry, across share, gouge) of the gouge nearest inside at (x, y)."""
    best = None
    for k, (offset, half_length, half_width) in enumerate(CLAWS):
        dx, dy = x - 32.0, y - 32.0
        a = dx * RAKE[0] + dy * RAKE[1]
        u = (a / half_length + 1) / 2
        b = dx * ACROSS[0] + dy * ACROSS[1] - offset - BOW * math.sin(math.pi * min(1.0, max(0.0, u)))
        if 0 <= u <= 1:
            half = half_width * (math.sqrt(u / ENTRY) if u < ENTRY else ((1 - u) / (1 - ENTRY)) ** 0.85)
            d = abs(b) - half
        else:
            half, d = 0.0, math.hypot(abs(a) - half_length, b)
        if best is None or d < best[0]:
            best = (d, u, b / max(0.01, half), k)
    return best


def claw_lit(x, y):
    d, t, across, _ = claw(x, y)
    if d > OUTLINE:
        return None
    if d > 0:
        return KEYLINE + (0.92,)
    if d > -1.6:
        return mix(MOSS, MOSS_DIM, (across + 1) / 2) + (1.0,)
    return ramp(AMBER, 0.1 + 0.9 * abs(across) + 0.3 * t) + (1.0,)


def claw_socket(x, y):
    d, _, across, _ = claw(x, y)
    if d > OUTLINE:
        return None
    if d > 0:
        return KEYLINE + (0.88,)
    if d > -1.1:
        return (hexrgb("0c0d10") if across < 0 else hexrgb("3b3324")) + (0.95,)
    return hexrgb("17140f") + (0.92,)


def white(fn):
    def shape(x, y):
        return (1.0, 1.0, 1.0, 1.0) if fn(x, y) is not None else None

    return shape


def paint(fn, size=SIZE):
    """RGBA bytes: each pixel the mean of the samples' premultiplied colour."""
    out = bytearray()
    for py in range(size):
        for px in range(size):
            r = g = b = a = 0.0
            for oy in mm._OFFSETS:
                for ox in mm._OFFSETS:
                    c = fn(px + ox, py + oy)
                    if c:
                        r, g, b, a = r + c[0] * c[3], g + c[1] * c[3], b + c[2] * c[3], a + c[3]
            if a <= 0:
                out += bytes(4)
            else:
                out += bytes((mm.byte(r / a), mm.byte(g / a), mm.byte(b / a), mm.byte(a / mm._SAMPLES)))
    return bytes(out)


TEXTURES = {
    "PipDruid": claw_lit,
    "PipDruidSocket": claw_socket,
    "PipDruidShape": white(claw_lit),
}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="compare with the files on disk")
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args(argv)
    bad = 0
    for name, fn in TEXTURES.items():
        path = args.root / FOLDER / f"{name}.png"
        data = mm.encode_png(SIZE, SIZE, paint(fn))
        if args.check:
            if not path.exists() or mm.decode_png(path.read_bytes())[2] != mm.decode_png(data)[2]:
                print(f"{path.relative_to(args.root)} differs; run python3 Tools/media/make_pips.py")
                bad += 1
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            print(f"wrote {path.relative_to(args.root)}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
