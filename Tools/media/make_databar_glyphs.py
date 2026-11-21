"""make_databar_glyphs.py: draw the data bar's readout glyph sheet, KstyleUI_DataBars/Media/Glyphs.png.

Each glyph is a white line icon on a 32-texel cell, drawn with the minimap sheet's shapes and sampled 4x4
times per pixel with make_media.py's sampler, so the in-game tint colours it. The strokes are heavier than
the minimap's because the glyphs sit at caption size. The sheet is 128x128: four cells across, four down.
The Lua table in KstyleUI_DataBars/Strip.lua (GLYPH_CELLS) names each cell. Run it from the repository root:

    python3 Tools/media/make_databar_glyphs.py          # write the sheet
    python3 Tools/media/make_databar_glyphs.py --check  # compare with the file on disk
"""

import math
import sys

import make_minimap_glyphs as mg
from make_minimap_glyphs import CELL, arc, disc, ring, segment

PATH = "KstyleUI_DataBars/Media/Glyphs.png"
COLUMNS, ROWS = 4, 4
WIDTH, HEIGHT = CELL * COLUMNS, CELL * ROWS
STROKE = 3.4

# Cell order matches GLYPH_CELLS in Strip.lua; the last two cells stay empty.
NAMES = ["fps", "latency", "gold", "durability", "time", "spec", "hearth", "guild",
         "friends", "bags", "currencies", "xp", "location", "itemLevel"]


def poly(*points):
    return [segment(*points[i], *points[i + 1]) for i in range(len(points) - 1)]


def glyph_fps():
    return [arc(16, 20, 11, 180, 360), segment(16, 20, 22, 12), disc(16, 20, 1.5), segment(5, 20, 27, 20)]


def glyph_latency():
    return [segment(6 + i * 6.5, top, 6 + i * 6.5, 26) for i, top in enumerate((20, 15, 10, 5))]


def glyph_gold():
    return [ring(16, 16, 10), ring(16, 16, 5)]


def glyph_durability():
    return poly((16, 5), (26, 9), (25, 18), (16, 27), (7, 18), (6, 9), (16, 5)) + [segment(16, 10, 16, 21)]


def glyph_time():
    return [ring(16, 16, 10.5), segment(16, 16, 16, 9), segment(16, 16, 21, 19)]


def glyph_spec():
    points = []
    for i in range(11):
        angle = math.radians(-90 + i * 36)
        r = 11.5 if i % 2 == 0 else 5
        points.append((16 + r * math.cos(angle), 17 + r * math.sin(angle)))
    return poly(*points)


def glyph_hearth():
    return poly((5, 15), (16, 5), (27, 15)) + poly((8, 13), (8, 26), (24, 26), (24, 13)) + poly((14, 26), (14, 19), (18, 19), (18, 26))


def glyph_guild():
    return [segment(8, 5, 8, 27)] + poly((8, 6), (25, 6), (21, 11), (25, 16), (8, 16))


def glyph_friends():
    return [ring(11, 11, 4), arc(11, 26, 7.5, 180, 360), ring(22, 12, 3.5), arc(23, 26, 6, 200, 330)]


def glyph_bags():
    return poly((7, 12), (25, 12), (26, 26), (6, 26), (7, 12)) + [arc(16, 12, 5, 180, 360)]


def glyph_currencies():
    return [ring(12, 18, 7.5), arc(20, 14, 7.5, 250, 160)]


def glyph_xp():
    return poly((7, 16), (16, 7), (25, 16)) + poly((7, 25), (16, 16), (25, 25))


def glyph_location():
    return [arc(16, 13, 8, 150, 30), segment(9.1, 17, 16, 27), segment(22.9, 17, 16, 27), disc(16, 13, 2)]


def glyph_item_level():
    return [segment(9, 23, 24, 8), segment(24, 8, 26, 6), segment(6, 18, 14, 26), segment(10, 22, 6, 26)]


GLYPHS = [glyph_fps, glyph_latency, glyph_gold, glyph_durability, glyph_time, glyph_spec, glyph_hearth,
          glyph_guild, glyph_friends, glyph_bags, glyph_currencies, glyph_xp, glyph_location, glyph_item_level]


def main(argv):
    return mg.main(argv, PATH, lambda: mg.draw(GLYPHS, COLUMNS, ROWS, STROKE / 2), __doc__)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
