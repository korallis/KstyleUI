"""Tests for Tools/media/make_media.py, which draws KstyleUI's procedural textures and logo."""

import contextlib
import importlib.util
import io
import re
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Tools" / "media" / "make_media.py"


def load_module():
    spec = importlib.util.spec_from_file_location("make_media", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def is_power_of_two(n):
    return n > 0 and n & (n - 1) == 0


class ManifestTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mm = load_module()

    def test_every_asset_is_a_power_of_two_png_or_tga_under_media(self):
        self.assertGreater(len(self.mm.ASSETS), 0)
        for asset in self.mm.ASSETS:
            self.assertTrue(asset.path.startswith("Media/"), asset.path)
            self.assertRegex(asset.path, r"\.(png|tga)$")
            self.assertTrue(is_power_of_two(asset.width), asset.path)
            self.assertTrue(is_power_of_two(asset.height), asset.path)

    def test_textures_cover_the_spec_list(self):
        names = {Path(a.path).stem for a in self.mm.ASSETS}
        for name in (
            "ChamferPanel", "ChamferTile", "ChamferWindow", "Line", "ChamferIconMask", "ChamferPortraitMask", "Shadow", "Glow", "Divider", "Noise", "Ring",
            "BarFlat", "BarSoft", "BarGlass", "MinimapMask", "Logo64", "Logo256",
            "Dot", "Pill", "GlyphChevron", "GlyphClose",
        ):
            self.assertIn(name, names)
        paths = {a.path for a in self.mm.ASSETS}
        # The core TOC's IconTexture names Media\Logo\Logo64 with no extension, which the game
        # resolves to a TGA or BLP file, not a PNG.
        self.assertIn("Media/Logo/Logo64.tga", paths)

    def test_chamfer_geometry_matches_the_shape_tokens(self):
        # Panels have 8-unit chamfers, tiles 3.5 and windows 12, drawn at TEXELS_PER_UNIT.
        density = self.mm.TEXELS_PER_UNIT
        self.assertEqual(self.mm.SLICE["ChamferPanel"], 8 * density)
        self.assertEqual(self.mm.SLICE["ChamferTile"], 3.5 * density)
        self.assertEqual(self.mm.SLICE["ChamferWindow"], 12 * density)
        self.assertEqual(self.mm.SLICE["Shadow"], 2 * 6 * self.mm.SHADOW_TEXELS_PER_UNIT, "the shadow reaches 6 units")
        self.assertFalse(any(name.startswith("Bevel") for name in self.mm.SLICE), "bevel lines are drawn in code, not baked")


class TokensTest(unittest.TestCase):
    """Core/Tokens.lua names the textures and their slice margins. They must match the script."""

    def test_tokens_texture_table_matches_the_assets(self):
        mm = load_module()
        text = (ROOT / "Core" / "Tokens.lua").read_text(encoding="ascii")
        entries = re.findall(r'file = "(Textures|Logo)\\\\(\w+)\.png"(?:, slice = (\d+), density = (\d+))?', text)
        self.assertGreater(len(entries), 0, "no texture entries found in Core/Tokens.lua")
        assets = {a.path: a for a in mm.ASSETS}
        for folder, stem, slice_, density in entries:
            path = f"Media/{folder}/{stem}.png"
            self.assertIn(path, assets, f"Tokens names {path}, which make_media.py does not draw")
            want = assets[path].slice
            self.assertEqual(int(slice_) if slice_ else None, want, f"{stem} slice margin")
            if want:
                per_unit = mm.SHADOW_TEXELS_PER_UNIT if stem == "Shadow" else mm.TEXELS_PER_UNIT
                self.assertEqual(int(density), per_unit, f"{stem} texels per unit")


class PngTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mm = load_module()

    def test_png_round_trip(self):
        pixels = bytes([10, 20, 30, 40, 50, 60, 70, 80] * 2)
        data = self.mm.encode_png(2, 2, pixels)
        self.assertEqual(self.mm.decode_png(data), (2, 2, pixels))

    def test_decode_handles_every_filter_type(self):
        width, height = 3, 5
        pixels = bytes((x * 37 + y * 11 + c * 5) % 256 for y in range(height) for x in range(width) for c in range(4))
        for kind in range(5):
            data = self.mm.encode_png(width, height, pixels, filter_type=kind)
            self.assertEqual(self.mm.decode_png(data), (width, height, pixels), f"filter {kind}")

    def test_tga_is_bottom_up_bgra(self):
        pixels = bytes([1, 2, 3, 4, 5, 6, 7, 8])  # 1x2: top pixel then bottom pixel
        data = self.mm.encode_tga(1, 2, pixels)
        self.assertEqual(len(data), 18 + 8)
        self.assertEqual(data[2], 2, "uncompressed true-colour")
        self.assertEqual(data[16], 32, "32 bits per pixel")
        self.assertEqual(data[17], 8, "8 alpha bits, bottom-left origin")
        self.assertEqual(data[18:], bytes([7, 6, 5, 8, 3, 2, 1, 4]))
        self.assertEqual(self.mm.decode_tga(data), (1, 2, pixels))


class DrawingTest(unittest.TestCase):
    """Each texture has the shape its use needs. Pixels are read from the rendered RGBA bytes."""

    @classmethod
    def setUpClass(cls):
        cls.mm = load_module()
        cls.rendered = {Path(a.path).name: (a.width, a.height, a.draw()) for a in cls.mm.ASSETS}

    def px(self, name, x, y):
        width, _, data = self.rendered[name]
        i = 4 * (y * width + x)
        return tuple(data[i : i + 4])

    def alpha(self, name, x, y):
        return self.px(name, x, y)[3]

    def test_chamfer_cuts_each_corner_at_45_degrees(self):
        for name, size, legs in (("ChamferPanel.png", 128, 32), ("ChamferTile.png", 32, 14), ("ChamferWindow.png", 128, 48)):
            last = size - 1
            for x, y in ((0, 0), (last, 0), (0, last), (last, last)):
                self.assertEqual(self.alpha(name, x, y), 0, f"{name} corner {x},{y}")
            self.assertEqual(self.alpha(name, size // 2, size // 2), 255, name)
            self.assertEqual(self.alpha(name, legs, 0), 255, f"{name} top edge after the cut")
            self.assertEqual(self.alpha(name, legs - 2, 0), 0, f"{name} top edge inside the cut")
            # On the diagonal the coverage is about half.
            self.assertTrue(96 <= self.alpha(name, legs // 2, legs // 2 - 1) <= 160, name)

    def test_line_strip_is_one_opaque_row_between_clear_rows(self):
        # The widget kit maps this strip onto each chamfer's diagonal with eight texture coordinates: the band is
        # row 1 of 4 (t from 0.25 to 0.5), and the rows either side are clear so CLAMP sampling outside is clear.
        width, height, _ = self.rendered["Line.png"]
        self.assertEqual((width, height), (4, 4))
        self.assertEqual(self.mm.LINE_BAND, (0.25, 0.5))
        for x in range(4):
            for y in range(4):
                r, g, b, a = self.px("Line.png", x, y)
                self.assertEqual((r, g, b), (255, 255, 255), "white, so SetVertexColor tints it")
                self.assertEqual(a, 255 if y == 1 else 0, f"row {y}")

    def test_sliced_textures_stretch_without_distortion(self):
        # A nine-slice stretches the strips between the margins. Every column and every row there
        # must be the same, or the stretch smears a corner's diagonal along the edge.
        for asset in self.mm.ASSETS:
            if not asset.slice:
                continue
            name, m = Path(asset.path).name, asset.slice
            self.assertLess(2 * m, asset.width, f"{name} keeps a stretchable centre")
            for x in range(m + 1, asset.width - m):
                for y in range(asset.height):
                    self.assertLessEqual(abs(self.alpha(name, x, y) - self.alpha(name, m, y)), 2, f"{name} column {x} row {y}")
            for y in range(m + 1, asset.height - m):
                for x in range(asset.width):
                    self.assertLessEqual(abs(self.alpha(name, x, y) - self.alpha(name, x, m)), 2, f"{name} row {y} column {x}")

    def test_portrait_mask_chamfer_is_15_percent_of_its_side(self):
        # The design file cuts the portrait's corners 10 units on a 68-unit square. The mask is stretched over the
        # portrait, so its cut is a share of its side, and the Chrome frame around it uses the same share.
        legs = 128 * 0.15
        self.assertEqual(self.alpha("ChamferPortraitMask.png", 0, 0), 0)
        self.assertEqual(self.alpha("ChamferPortraitMask.png", 64, 64), 255)
        self.assertEqual(self.alpha("ChamferPortraitMask.png", int(legs) + 2, 0), 255)
        self.assertEqual(self.alpha("ChamferPortraitMask.png", int(legs) - 3, 0), 0)
        self.assertEqual(self.alpha("ChamferPortraitMask.png", 127, 127 - int(legs) + 3), 0)

    def test_icon_mask_chamfer_is_3_units_of_34(self):
        legs = 128 * 3 / 34
        self.assertEqual(self.alpha("ChamferIconMask.png", 0, 0), 0)
        self.assertEqual(self.alpha("ChamferIconMask.png", 64, 64), 255)
        self.assertEqual(self.alpha("ChamferIconMask.png", int(legs) + 2, 0), 255)
        self.assertEqual(self.alpha("ChamferIconMask.png", int(legs) - 3, 0), 0)

    def test_shadow_falls_off_from_the_panel_edge(self):
        edge = self.mm.SLICE["Shadow"] // 2  # the panel corner sits in the middle of the corner piece
        self.assertEqual(self.alpha("Shadow.png", 64, 64), 255)
        self.assertLessEqual(self.alpha("Shadow.png", 0, 64), 4)
        self.assertTrue(110 <= self.alpha("Shadow.png", edge, 64) <= 145)
        self.assertLess(self.alpha("Shadow.png", 0, 0), self.alpha("Shadow.png", 0, 64))

    def test_glow_is_radial(self):
        self.assertEqual(self.alpha("Glow.png", 64, 64), 255)
        self.assertEqual(self.alpha("Glow.png", 0, 64), 0)
        self.assertEqual(self.alpha("Glow.png", 64, 20), self.alpha("Glow.png", 20, 64))

    def test_dot_is_a_filled_disc(self):
        self.assertEqual(self.alpha("Dot.png", 32, 32), 255)
        self.assertEqual(self.alpha("Dot.png", 32, 3), 255, "the disc reaches near the edge")
        self.assertEqual(self.alpha("Dot.png", 0, 0), 0, "the corners are empty")
        self.assertEqual(self.alpha("Dot.png", 0, 32), 0, "a texel of padding for filtering")
        self.assertEqual(self.alpha("Dot.png", 32, 10), self.alpha("Dot.png", 10, 32), "the disc is round")

    def test_pill_has_round_caps_and_a_flat_middle(self):
        cap = self.mm.PILL_CAP
        self.assertEqual(cap * 4, 64, "each cap is a quarter of the width, so a widget can three-slice it")
        self.assertEqual(self.alpha("Pill.png", 32, 16), 255)
        self.assertEqual(self.alpha("Pill.png", 0, 0), 0, "the caps are round")
        self.assertEqual(self.alpha("Pill.png", 63, 31), 0, "the caps are round")
        self.assertEqual(self.alpha("Pill.png", 0, 16), 0, "a texel of padding for filtering")
        self.assertEqual(self.alpha("Pill.png", 2, 16), 255, "the cap reaches the side")
        for x in range(cap, 64 - cap):
            for y in range(32):
                self.assertEqual(self.alpha("Pill.png", x, y), self.alpha("Pill.png", cap, y), f"column {x} row {y}")
        for y in range(32):
            self.assertEqual(self.alpha("Pill.png", 5, y), self.alpha("Pill.png", 58, y), "the caps mirror each other")

    def test_glyphs_are_thin_strokes_on_clear_ground(self):
        self.assertEqual(self.alpha("GlyphChevron.png", 16, 20), 255, "the chevron's point")
        self.assertEqual(self.alpha("GlyphChevron.png", 16, 12), 0, "the chevron is open above its point")
        self.assertEqual(self.alpha("GlyphChevron.png", 8, 12), 255, "the left arm")
        self.assertEqual(self.alpha("GlyphChevron.png", 24, 12), 255, "the right arm")
        self.assertEqual(self.alpha("GlyphClose.png", 16, 16), 255, "the cross's centre")
        self.assertEqual(self.alpha("GlyphClose.png", 16, 8), 0, "the cross is open between its arms")
        for x, y in ((10, 10), (22, 10), (10, 22), (22, 22)):
            self.assertEqual(self.alpha("GlyphClose.png", x, y), 255, f"arm at {x},{y}")
        for name in ("GlyphChevron.png", "GlyphClose.png"):
            for x, y in ((0, 0), (31, 0), (0, 31), (31, 31)):
                self.assertEqual(self.alpha(name, x, y), 0, f"{name} corner {x},{y}")

    def test_divider_fades_out_at_both_ends(self):
        self.assertEqual(self.alpha("Divider.png", 0, 1), 0)
        self.assertEqual(self.alpha("Divider.png", 255, 1), 0)
        self.assertEqual(self.alpha("Divider.png", 128, 1), 255)
        self.assertEqual(self.alpha("Divider.png", 40, 0), self.alpha("Divider.png", 40, 3))

    def test_noise_is_subtle_and_tiles(self):
        _, _, data = self.rendered["Noise.png"]
        alphas = data[3::4]
        self.assertGreater(len(set(alphas)), 16, "noise has texture")
        mean = sum(alphas) / len(alphas)
        self.assertTrue(100 <= mean <= 156, mean)
        # Opposite edges differ no more than neighbouring texels do inside the tile.
        def gap(a, b):
            return abs(self.alpha("Noise.png", *a) - self.alpha("Noise.png", *b))

        edge = sum(gap((127, y), (0, y)) for y in range(128)) / 128
        inside = sum(gap((63, y), (64, y)) for y in range(128)) / 128
        self.assertLess(edge, inside * 1.5 + 1)

    def test_ring_is_an_annulus(self):
        self.assertEqual(self.alpha("Ring.png", 64, 64), 0)
        self.assertEqual(self.alpha("Ring.png", 64, 3), 255)
        self.assertEqual(self.alpha("Ring.png", 0, 0), 0)

    def test_status_bars_are_opaque_and_shaded_top_to_bottom(self):
        for name in ("BarFlat.png", "BarSoft.png", "BarGlass.png"):
            self.assertEqual(self.alpha(name, 10, 16), 255, name)
            self.assertEqual(self.px(name, 10, 16), self.px(name, 200, 16), f"{name} is uniform along its length")
        self.assertEqual(self.px("BarFlat.png", 0, 0), (255, 255, 255, 255))
        self.assertGreater(self.px("BarSoft.png", 0, 0)[0], self.px("BarSoft.png", 0, 31)[0])
        self.assertGreater(self.px("BarGlass.png", 0, 2)[0], self.px("BarGlass.png", 0, 20)[0])
        # The design's health fill: the top is 12% brighter than the bottom, a near-flat gradient with no sheen band.
        top, bottom = self.px("BarGlass.png", 0, 0)[0], self.px("BarGlass.png", 0, 31)[0]
        self.assertEqual(top, 255, "the top is full brightness, so SetStatusBarColor gives the exact colour")
        self.assertAlmostEqual(top / bottom, 1.12, delta=0.015)
        levels = [self.px("BarGlass.png", 0, y)[0] for y in range(32)]
        self.assertEqual(levels, sorted(levels, reverse=True), "the gradient falls steadily, with no sheen")

    def test_minimap_mask_is_a_full_square(self):
        _, _, data = self.rendered["MinimapMask.png"]
        self.assertEqual(set(data), {255})

    def test_logo_is_a_chamfered_diamond(self):
        for name, size in (("Logo64.png", 64), ("Logo256.png", 256)):
            centre = self.px(name, size // 2, size // 2)
            self.assertEqual(centre[3], 255, name)
            self.assertGreater(centre[1], centre[0], f"{name} centre is the accent green")
            self.assertEqual(self.alpha(name, 0, 0), 0, f"{name} corner is transparent")
            self.assertEqual(self.alpha(name, size // 2, 0), 0, f"{name} top point is chamfered")
        self.assertEqual(self.rendered["Logo64.png"][2], self.rendered["Logo64.tga"][2])


class CommittedMediaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mm = load_module()

    def test_committed_files_match_the_script(self):
        problems = self.mm.check(ROOT)
        self.assertEqual(problems, [], "run Tools/media/make_media.py to redraw Media/")

    def test_check_reports_a_changed_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with contextlib.redirect_stdout(io.StringIO()):
                self.mm.main(["--root", str(root), "--only", "Glow"])
            path = root / "Media" / "Textures" / "Glow.png"
            width, height, pixels = self.mm.decode_png(path.read_bytes())
            changed = bytearray(pixels)
            changed[4 * (64 * width + 64) + 3] = 0
            path.write_bytes(self.mm.encode_png(width, height, bytes(changed)))
            problems = self.mm.check(root, only={"Glow"})
            self.assertEqual(len(problems), 1)
            self.assertIn("Glow.png", problems[0])

    def test_provenance_lists_every_media_file(self):
        text = (ROOT / "Media" / "PROVENANCE.md").read_text(encoding="utf-8")
        self.assertIn(self.mm.provenance_table(), text, "run Tools/media/make_media.py to refresh PROVENANCE.md")
        listed = set(re.findall(r"`(Media/[^`]+)`", text))
        on_disk = {
            p.relative_to(ROOT).as_posix()
            for p in (ROOT / "Media").rglob("*")
            if p.is_file() and p.name != "PROVENANCE.md"
        }
        self.assertEqual(on_disk - listed, set(), "every file in Media/ needs a PROVENANCE.md row")
        self.assertEqual(listed - on_disk, set(), "PROVENANCE.md lists files that do not exist")


class FontsTest(unittest.TestCase):
    def test_fonts_ship_with_their_licence(self):
        fonts = ROOT / "Media" / "Fonts"
        for name in ("SourceSans3-Regular.ttf", "SourceSans3-Semibold.ttf", "Inter-SemiBold.ttf"):
            data = (fonts / name).read_bytes()
            self.assertEqual(data[:4], b"\x00\x01\x00\x00", f"{name} is a TrueType font")
        licence = (fonts / "OFL.txt").read_text(encoding="utf-8")
        self.assertIn("SIL Open Font License, Version 1.1", licence)
        self.assertIn("Reserved Font Name 'Source'", licence)
        self.assertIn("The Inter Project Authors", licence)
        self.assertIn("Source Sans 3", (ROOT / "LICENSE.md").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
