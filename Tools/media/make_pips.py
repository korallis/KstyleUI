"""make_pips.py: draw the class-themed combo point pips into Media/Textures/Pips/.

Each class has three 64x64 textures that share one silhouette: the lit pip with its colours baked in, the
empty socket, and the white shape that masks the slide-in, slash and shine and that the game tints for the
flare. PipStreak.png is the soft diagonal stroke the slash and shine draw. The rogue's pip is a dagger
pointing up and right (a gilt pommel and guard, a wrapped grip, a crimson ember blade with polished steel
edges lit from the upper left, a glint on the lit edge); the druid's is three amber claw gouges with green
rims, raked down and left. Every pixel is the mean of 4x4 samples of premultiplied colour, as make_media.py
samples its shapes. Coordinates are texels, origin top left, y down. Standard library only.

    python3 Tools/media/make_pips.py          # write the textures
    python3 Tools/media/make_pips.py --check  # compare with the files on disk
"""

import argparse
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import make_media as mm  # noqa: E402

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
GILT_LIT, GILT, GILT_DIM = hexrgb("f3dca4"), hexrgb("d3b574"), hexrgb("8a6c34")
STEEL_LIT, STEEL, STEEL_DIM = hexrgb("e6ecf3"), hexrgb("b9c1cc"), hexrgb("6b7380")
SOCKET, GUN_LIT = hexrgb("23262c"), hexrgb("5a616b")
EMBER = [(0.0, hexrgb("ffd08a")), (0.3, hexrgb("ff7a3a")), (0.65, hexrgb("e8322a")), (1.0, hexrgb("9a141a"))]
AMBER = [(0.0, hexrgb("fff6d0")), (0.25, hexrgb("ffd25a")), (0.6, hexrgb("f39a1c")), (1.0, hexrgb("a8520c"))]
MOSS, MOSS_DIM = hexrgb("8fd651"), hexrgb("3f7a25")

# The dagger runs from the pommel's end P0 to the tip P1. s is the distance along it, w across it (w < 0 is
# the upper left, the lit side).
P0, P1 = (5.0, 59.0), (60.0, 4.0)
LENGTH = math.hypot(P1[0] - P0[0], P1[1] - P0[1])
U = ((P1[0] - P0[0]) / LENGTH, (P1[1] - P0[1]) / LENGTH)
V = (-U[1], U[0])
BLADE = 24.0
EDGE = 3.0  # texels of steel bevel on each blade edge


def blade_half(s):
    if s < 58:
        return 9.0 - (s - BLADE) * (1.6 / (58 - BLADE))
    return max(0.0, 7.4 * (LENGTH - s) / (LENGTH - 58))


def dagger(x, y):
    """(part, signed distance, s, w) of the dagger part nearest inside at (x, y)."""
    dx, dy = x - P0[0], y - P0[1]
    s, w = dx * U[0] + dy * U[1], dx * V[0] + dy * V[1]
    parts = [
        ("pommel", math.hypot(s - 5.6, w) - 5.8),
        ("grip", max(abs(w) - 4.0, abs(s - 13.0) - 6.5)),
        ("guard", max(abs(w) - (14.0 - 0.6 * abs(s - 21.0)), abs(s - 21.0) - 3.4)),
        ("blade", max(abs(w) - blade_half(s), BLADE - 0.5 - s, s - LENGTH)),
    ]
    part, d = min(parts, key=lambda p: p[1])
    return part, d, s, w


def gilt(t):
    return ramp([(0.0, GILT_LIT), (0.45, GILT), (1.0, GILT_DIM)], t)


def dagger_lit(x, y):
    part, d, s, w = dagger(x, y)
    if d > OUTLINE:
        return None
    if d > 0:
        return KEYLINE + (0.92,)
    if part == "pommel":
        lit = math.hypot(s - 3.4, w + 2.0) / 6.5
        return (mix(gilt(lit), (1, 1, 1), 0.6) if lit < 0.25 else gilt(lit)) + (1.0,)
    if part == "guard":
        return gilt(0.1 + 0.65 * (w + 14.0) / 28 + (0.25 if s > 22.5 else 0)) + (1.0,)
    if part == "grip":
        band = (s % 3.4) < 1.2
        return mix(hexrgb("4a3426"), hexrgb("22170f"), 0.75 if band else 0.15 + 0.3 * (w + 4.0) / 8.0) + (1.0,)
    half = blade_half(s)
    inner = half - abs(w)
    if inner < EDGE:
        edge = inner / EDGE
        if w < 0:
            steel = ramp([(0.0, STEEL_LIT), (0.5, STEEL), (1.0, STEEL_DIM)], edge)
            glint = math.hypot(s - 48.0, w + half - 1.2)
            if glint < 3.0:
                steel = mix(steel, (1, 1, 1), 1 - glint / 3.0)
            return steel + (1.0,)
        return ramp([(0.0, STEEL_DIM), (1.0, hexrgb("3a3f47"))], edge) + (1.0,)
    body = half - EDGE
    heat = ramp(EMBER, abs(w + 0.25 * body) / (1.25 * max(0.01, body)))
    return mix(heat, hexrgb("5a0c0e"), 0.35 * max(0.0, (BLADE + 6 - s) / 6)) + (1.0,)


def dagger_socket(x, y):
    part, d, s, w = dagger(x, y)
    if d > OUTLINE:
        return None
    if d > 0:
        return KEYLINE + (0.88,)
    if part in ("guard", "pommel"):
        return mix(GILT_DIM, SOCKET, 0.45 + 0.3 * (w + 14.0) / 28) + (0.95,)
    if part == "grip":
        return hexrgb("1a1512") + (0.95,)
    inner = blade_half(s) - abs(w)
    if inner < EDGE and w < 0:
        return mix(GUN_LIT, SOCKET, inner / EDGE) + (0.95,)
    return mix(SOCKET, hexrgb("0b0c0f"), max(0.0, w) / 9.0) + (0.95,)


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


def streak(x, y):
    """A soft stroke along the falling diagonal through the centre, fading towards its ends."""
    dx, dy = x - 32.0, y - 32.0
    across = (dx - dy) / math.sqrt(2)
    along = (dx + dy) / math.sqrt(2)
    a = math.exp(-((across / 2.8) ** 2)) * max(0.0, 1 - (along / 30.0) ** 2)
    return (1.0, 1.0, 1.0, a) if a > 0.004 else None


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
    "PipRogue": dagger_lit,
    "PipRogueSocket": dagger_socket,
    "PipRogueShape": white(dagger_lit),
    "PipDruid": claw_lit,
    "PipDruidSocket": claw_socket,
    "PipDruidShape": white(claw_lit),
    "PipStreak": streak,
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
