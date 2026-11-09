"""Tests for Media/Fonts: every bundled font is a static TrueType file the game can load, and Lumen's number faces keep their digits one width."""

import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "Media" / "Fonts"
TOKENS = ROOT / "Core" / "Tokens.lua"


def tables(data):
    """The sfnt table directory as {tag: (offset, length)}."""
    count = struct.unpack(">H", data[4:6])[0]
    out = {}
    for i in range(count):
        tag, _, offset, length = struct.unpack(">4sIII", data[12 + 16 * i : 28 + 16 * i])
        out[tag.decode("latin-1")] = (offset, length)
    return out


def table(data, tag):
    offset, length = tables(data)[tag]
    return data[offset : offset + length]


def glyph_index(data, code):
    """The glyph for a BMP character from the format 4 subtable of the Windows Unicode cmap."""
    cmap = table(data, "cmap")
    count = struct.unpack(">H", cmap[2:4])[0]
    for i in range(count):
        platform, encoding, offset = struct.unpack(">HHI", cmap[4 + 8 * i : 12 + 8 * i])
        if (platform, encoding) != (3, 1) or struct.unpack(">H", cmap[offset : offset + 2])[0] != 4:
            continue
        sub = cmap[offset:]
        segs = struct.unpack(">H", sub[6:8])[0] // 2
        ends = struct.unpack(f">{segs}H", sub[14 : 14 + 2 * segs])
        base = 16 + 2 * segs
        starts = struct.unpack(f">{segs}H", sub[base : base + 2 * segs])
        deltas = struct.unpack(f">{segs}h", sub[base + 2 * segs : base + 4 * segs])
        ranges_at = base + 4 * segs
        ranges = struct.unpack(f">{segs}H", sub[ranges_at : ranges_at + 2 * segs])
        for s in range(segs):
            if starts[s] <= code <= ends[s]:
                if ranges[s] == 0:
                    return (code + deltas[s]) & 0xFFFF
                at = ranges_at + 2 * s + ranges[s] + 2 * (code - starts[s])
                glyph = struct.unpack(">H", sub[at : at + 2])[0]
                return (glyph + deltas[s]) & 0xFFFF if glyph else 0
        return 0
    raise AssertionError("no Windows Unicode format 4 cmap")


def advance(data, glyph):
    metrics = struct.unpack(">H", table(data, "hhea")[34:36])[0]
    hmtx = table(data, "hmtx")
    return struct.unpack(">H", hmtx[4 * min(glyph, metrics - 1) : 4 * min(glyph, metrics - 1) + 2])[0]


class FontFilesTest(unittest.TestCase):
    def test_every_font_is_static_truetype(self):
        files = sorted(FONTS.glob("*.ttf"))
        self.assertGreaterEqual(len(files), 7)
        for path in files:
            data = path.read_bytes()
            self.assertEqual(data[:4], b"\x00\x01\x00\x00", f"{path.name} is TrueType")
            have = tables(data)
            self.assertIn("glyf", have, f"{path.name} has TrueType outlines")
            self.assertNotIn("fvar", have, f"{path.name} is static: the game cannot pick a variable font's instance")

    def test_cinzel_is_the_semibold_instance(self):
        data = (FONTS / "Cinzel-SemiBold.ttf").read_bytes()
        self.assertEqual(struct.unpack(">H", table(data, "OS/2")[4:6])[0], 600)

    def test_number_faces_have_tabular_lining_digits(self):
        # The game applies no OpenType features, so the files map the digits to their tabular lining figures.
        for name in ("AlegreyaSansTabular-Regular.ttf", "AlegreyaSansTabular-Medium.ttf", "AlegreyaSansTabular-Bold.ttf"):
            data = (FONTS / name).read_bytes()
            widths = {advance(data, glyph_index(data, ord(c))) for c in "0123456789"}
            self.assertEqual(len(widths), 1, f"{name} digits share one advance, got {sorted(widths)}")

    def test_tokens_name_files_that_exist(self):
        text = TOKENS.read_text(encoding="ascii")
        named = set()
        for line in text.splitlines():
            if 'FONTS_DIR .. "' in line:
                named.add(line.split('FONTS_DIR .. "')[1].split('"')[0])
        self.assertGreaterEqual(len(named), 7)
        for name in named:
            self.assertTrue((FONTS / name).exists(), f"Tokens names {name}")
        for name in ("Cinzel-SemiBold.ttf", "AlegreyaSansTabular-Regular.ttf", "AlegreyaSansTabular-Medium.ttf", "AlegreyaSansTabular-Bold.ttf"):
            self.assertIn(name, named, f"{name} is registered in Tokens")

    def test_licence_covers_every_family(self):
        text = (FONTS / "OFL.txt").read_text(encoding="ascii")
        for project in ("Adobe", "The Inter Project Authors", "The Cinzel Project Authors", "The Alegreya Sans Project Authors"):
            self.assertIn(project, text)


if __name__ == "__main__":
    unittest.main()
