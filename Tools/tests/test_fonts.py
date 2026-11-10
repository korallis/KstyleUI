"""Tests for Media/Fonts: every bundled font is a static TrueType file the game can load, and Lumen's number faces keep their digits one width."""

import hashlib
import importlib.util
import struct
import unittest
from pathlib import Path
from unittest import mock

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


def glyph_box(data, glyph):
    """The glyph's (yMin, yMax) in font units from its glyf header, or None for an empty glyph."""
    long_loca = struct.unpack(">h", table(data, "head")[50:52])[0]
    loca, glyf = table(data, "loca"), table(data, "glyf")
    if long_loca:
        start, end = struct.unpack(">II", loca[4 * glyph : 4 * glyph + 8])
    else:
        start, end = (2 * v for v in struct.unpack(">HH", loca[2 * glyph : 2 * glyph + 4]))
    if start == end:
        return None
    _, _, y_min, _, y_max = struct.unpack(">hhhhh", glyf[start : start + 10])
    return y_min, y_max


class FontFilesTest(unittest.TestCase):
    def test_every_font_is_static_truetype(self):
        files = sorted(FONTS.glob("*.ttf"))
        self.assertGreaterEqual(len(files), 8)
        for path in files:
            data = path.read_bytes()
            self.assertEqual(data[:4], b"\x00\x01\x00\x00", f"{path.name} is TrueType")
            have = tables(data)
            self.assertIn("glyf", have, f"{path.name} has TrueType outlines")
            self.assertNotIn("fvar", have, f"{path.name} is static: the game cannot pick a variable font's instance")

    def test_cinzel_is_the_semibold_instance(self):
        data = (FONTS / "Cinzel-SemiBold.ttf").read_bytes()
        self.assertEqual(struct.unpack(">H", table(data, "OS/2")[4:6])[0], 600)

    def test_tracked_cinzel_is_medium_with_wider_advances(self):
        # Cinzel's own advances (Cinzel[wght].ttf at weight 500, in 1000 units) and the tracking the script adds.
        medium = {"S": 509, "K": 690, "Y": 675, "B": 615, "O": 852, "R": 700, "N": 849, "E": 595}
        space = 250
        for name, track, word in (("CinzelCaps-Medium.ttf", 65, 180), ("CinzelNames-Medium.ttf", 0, 160), ("CinzelUnit-Medium.ttf", -65, 250)):
            data = (FONTS / name).read_bytes()
            self.assertEqual(struct.unpack(">H", table(data, "OS/2")[4:6])[0], 500, name)
            self.assertEqual(struct.unpack(">H", table(data, "head")[18:20])[0], 1000, name)
            for letter, base in medium.items():
                self.assertEqual(advance(data, glyph_index(data, ord(letter))), base + track, f"{name}: {letter} is Cinzel Medium's advance plus {track}")
            self.assertEqual(advance(data, glyph_index(data, ord(" "))), space + track + word, f"{name}: the space is Cinzel's {space} plus the tracking plus {word} of its own, the picture's word gap")
            self.assertEqual(glyph_index(data, ord("a")), glyph_index(data, ord("A")), f"{name}: lowercase is drawn as the capital, so a name Lua cannot uppercase still reads in capitals")
            self.assertEqual(glyph_index(data, 0xE9), glyph_index(data, 0xC9), f"{name}: accented lowercase too")

    def test_tracked_cinzel_has_no_thin_space_to_misuse(self):
        for name in ("CinzelCaps-Medium.ttf", "CinzelNames-Medium.ttf", "CinzelUnit-Medium.ttf", "Cinzel-SemiBold.ttf"):
            data = (FONTS / name).read_bytes()
            self.assertEqual(glyph_index(data, 0x2009), 0, f"{name} has no thin space: the tracking is in the advances")

    def test_tracked_cinzel_is_renamed(self):
        for name, family in (("CinzelCaps-Medium.ttf", "Cinzel Caps"), ("CinzelNames-Medium.ttf", "Cinzel Names"), ("CinzelUnit-Medium.ttf", "Cinzel Unit")):
            data = (FONTS / name).read_bytes()
            self.assertIn(family.encode("utf-16-be"), table(data, "name"), f"{name}: the modified family carries its own name")

    def test_provenance_hashes_match_the_cinzel_files(self):
        # make_fonts.py output depends on the build environment (uharfbuzz changes the bytes), so the files and the recorded hashes must agree.
        text = (ROOT / "Media" / "PROVENANCE.md").read_text(encoding="utf-8")
        for name in ("CinzelCaps-Medium.ttf", "CinzelNames-Medium.ttf", "CinzelUnit-Medium.ttf"):
            digest = hashlib.sha256((FONTS / name).read_bytes()).hexdigest()
            self.assertIn(digest, text, f"{name} changed: record its SHA-256 in Media/PROVENANCE.md")

    def test_the_build_refuses_to_run_with_uharfbuzz(self):
        spec = importlib.util.spec_from_file_location("make_fonts", ROOT / "Tools" / "media" / "make_fonts.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with mock.patch.object(importlib.util, "find_spec", return_value=object()):
            with self.assertRaises(SystemExit) as raised:
                module.main(["--src", "/nonexistent", "--out", "/nonexistent"])
        self.assertIn("uharfbuzz", str(raised.exception))

    def test_number_faces_have_tabular_oldstyle_digits(self):
        # The game applies no OpenType features, so the files map the digits to their tabular oldstyle figures: the
        # owner's picture draws Alegreya's default figures (3, 4, 5, 7 and 9 hang below the baseline, 0, 1 and 2 stand
        # at x-height, 6 and 8 reach up), and a number that ticks keeps its width.
        for name in ("AlegreyaSansTabular-Regular.ttf", "AlegreyaSansTabular-Medium.ttf", "AlegreyaSansTabular-Bold.ttf", "AlegreyaSansTabular-ExtraBold.ttf"):
            data = (FONTS / name).read_bytes()
            widths = {advance(data, glyph_index(data, ord(c))) for c in "0123456789"}
            self.assertEqual(widths, {475}, f"{name} digits share one advance of 475 units, got {sorted(widths)}")
            box = {c: glyph_box(data, glyph_index(data, ord(c))) for c in "0123456789"}
            for digit in "34579":
                self.assertLess(box[digit][0], -50, f"{name}: {digit} hangs below the baseline, an oldstyle figure")
            for digit in "012":
                self.assertGreater(box[digit][0], -30, f"{name}: {digit} stands on the baseline")
                self.assertLess(box[digit][1], 540, f"{name}: {digit} stands at x-height, an oldstyle figure")
            for digit in "68":
                self.assertGreater(box[digit][1], 560, f"{name}: {digit} reaches the ascender, an oldstyle figure")

    def test_the_number_face_is_extra_bold(self):
        # The picture's bold figures are heavier than Bold (LEE-85, Media/PROVENANCE.md): the number role's file is weight 800.
        data = (FONTS / "AlegreyaSansTabular-ExtraBold.ttf").read_bytes()
        self.assertEqual(struct.unpack(">H", table(data, "OS/2")[4:6])[0], 800)
        self.assertIn("Extra".encode("utf-16-be"), table(data, "name"))
        bold = (FONTS / "AlegreyaSansTabular-Bold.ttf").read_bytes()
        self.assertNotEqual(table(data, "glyf"), table(bold, "glyf"), "Extra Bold draws its own outlines, not Bold's")
        self.assertEqual(advance(data, glyph_index(data, ord("1"))), advance(bold, glyph_index(bold, ord("1"))), "the figures keep their 475-unit width")

    def test_the_lining_build_is_one_switch_away(self):
        spec = importlib.util.spec_from_file_location("make_fonts", ROOT / "Tools" / "media" / "make_fonts.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertEqual(module.FIGURES, "oldstyle")
        self.assertEqual(module.TABULAR_SUFFIX, {"oldstyle": ".tosf", "lining": ".tf"})

    def test_tokens_name_files_that_exist(self):
        text = TOKENS.read_text(encoding="ascii")
        named = set()
        for line in text.splitlines():
            if 'FONTS_DIR .. "' in line:
                named.add(line.split('FONTS_DIR .. "')[1].split('"')[0])
        self.assertGreaterEqual(len(named), 8)
        for name in named:
            self.assertTrue((FONTS / name).exists(), f"Tokens names {name}")
        for name in ("Cinzel-SemiBold.ttf", "CinzelCaps-Medium.ttf", "CinzelNames-Medium.ttf", "CinzelUnit-Medium.ttf", "AlegreyaSansTabular-Regular.ttf", "AlegreyaSansTabular-Medium.ttf", "AlegreyaSansTabular-Bold.ttf", "AlegreyaSansTabular-ExtraBold.ttf"):
            self.assertIn(name, named, f"{name} is registered in Tokens")

    def test_licence_covers_every_family(self):
        text = (FONTS / "OFL.txt").read_text(encoding="ascii")
        for project in ("Adobe", "The Inter Project Authors", "The Cinzel Project Authors", "The Alegreya Sans Project Authors"):
            self.assertIn(project, text)


if __name__ == "__main__":
    unittest.main()
