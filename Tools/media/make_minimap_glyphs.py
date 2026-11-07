"""make_minimap_glyphs.py: draw the minimap button glyph sheet, KstyleUI_Minimap/Media/Glyphs.png.

Each glyph is a white line icon on a 32-texel cell, sampled 4x4 times per pixel with make_media.py's
sampler, so the in-game tint colours it. The sheet is 128x64: four cells across, two down. The Lua
table in KstyleUI_Minimap/Column.lua names each cell. Run it from the repository root:

    python3 Tools/media/make_minimap_glyphs.py          # write the sheet
    python3 Tools/media/make_minimap_glyphs.py --check  # compare with the file on disk
"""

import argparse
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import make_media as mm  # noqa: E402

ROOT = HERE.parent.parent
PATH = "KstyleUI_Minimap/Media/Glyphs.png"
CELL = 32
COLUMNS, ROWS = 4, 2
WIDTH, HEIGHT = CELL * COLUMNS, CELL * ROWS
STROKE = 2.6  # texels: about 1.6 units on a 20-unit glyph
HALF = STROKE / 2

# Cell order: tracking, mail, calendar, group finder, drawer, then three empty cells.
NAMES = ["tracking", "mail", "calendar", "queue", "drawer"]


def segment(x0, y0, x1, y1):
    def dist(x, y):
        return mm._segment_distance(x, y, x0, y0, x1, y1)

    return dist


def ring(cx, cy, r):
    def dist(x, y):
        return abs(math.hypot(x - cx, y - cy) - r)

    return dist


def arc(cx, cy, r, start, stop):
    """Ring between two angles in degrees, measured from +x, y down."""

    def dist(x, y):
        angle = math.degrees(math.atan2(y - cy, x - cx)) % 360
        lo, hi = start % 360, stop % 360
        inside = lo <= angle <= hi if lo <= hi else (angle >= lo or angle <= hi)
        if inside:
            return abs(math.hypot(x - cx, y - cy) - r)
        ends = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in (start, stop)]
        return min(math.hypot(x - ex, y - ey) for ex, ey in ends)

    return dist


def disc(cx, cy, r):
    def dist(x, y):
        return max(0.0, math.hypot(x - cx, y - cy) - r)

    return dist


def box(x0, y0, x1, y1):
    return [segment(x0, y0, x1, y0), segment(x1, y0, x1, y1), segment(x1, y1, x0, y1), segment(x0, y1, x0, y0)]


def glyph_tracking():
    return [ring(14, 14, 7.5), segment(19.5, 19.5, 25.5, 25.5)]


def glyph_mail():
    return box(6, 9, 26, 23) + [segment(6, 9, 16, 17), segment(16, 17, 26, 9)]


def glyph_calendar():
    parts = box(6, 8, 26, 25) + [segment(6, 13, 26, 13), segment(11, 5, 11, 10), segment(21, 5, 21, 10)]
    for gx in (11, 16, 21):
        for gy in (17.5, 21.5):
            parts.append(disc(gx, gy, 0.3))
    return parts


def glyph_queue():
    return [arc(16, 25, 15, 216.87, 323.13), arc(16, 7, 15, 36.87, 143.13), disc(16, 16, 2.2)]


def glyph_drawer():
    parts = []
    for x0, y0 in ((7, 7), (17.5, 7), (7, 17.5), (17.5, 17.5)):
        parts += box(x0, y0, x0 + 7.5, y0 + 7.5)
    return parts


GLYPHS = [glyph_tracking, glyph_mail, glyph_calendar, glyph_queue, glyph_drawer]


def draw():
    cells = [g() for g in GLYPHS]

    def fn(x, y):
        col, row = int(x // CELL), int(y // CELL)
        index = row * COLUMNS + col
        if index >= len(cells):
            return 0.0
        lx, ly = x - col * CELL, y - row * CELL
        for dist in cells[index]:
            if dist(lx, ly) <= HALF:
                return 1.0
        return 0.0

    return mm.white(mm.sample(WIDTH, HEIGHT, fn))


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=ROOT, help="the repository root")
    parser.add_argument("--check", action="store_true", help="compare with the file on disk instead of writing")
    args = parser.parse_args(argv)
    path = args.root / PATH
    data = mm.encode_png(WIDTH, HEIGHT, bytes(draw()))
    if args.check:
        if not path.exists() or path.read_bytes() != data:
            print(f"differs: {PATH}; run python3 Tools/media/make_minimap_glyphs.py")
            return 1
        return 0
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    print(f"wrote {PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
