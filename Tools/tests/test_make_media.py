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
            "LumenShape", "CardShape", "RingLine2", "RingLine3", "RingLine4", "RingLine5", "RingLine6", "LumenOutline", "LumenGem",
            "PillCapLeft", "PillCapRight", "BarSheen", "LensMask", "SocketMask", "PortraitMask", "RuleFade", "Shadow", "Glow", "Divider", "Noise", "Ring", "RingBevel",
            "BarFlat", "BarSoft", "BarGlass", "MinimapMask", "Logo64", "Logo256",
            "Dot", "Pill", "GlyphChevron", "GlyphClose",
        ):
            self.assertIn(name, names)
        self.assertFalse(any(name.startswith("Chamfer") or name == "Line" for name in names), "the chamfer material is retired")
        for name in ("LumenFrost", "LumenRim", "LumenRimSmall", "LumenGilt"):
            self.assertNotIn(name, names, "the frost glass is retired: the owner's picture of 2026-11-09 has none")
        paths = {a.path for a in self.mm.ASSETS}
        # The core TOC's IconTexture names Media\Logo\Logo64 with no extension, which the game
        # resolves to a TGA or BLP file, not a PNG.
        self.assertIn("Media/Logo/Logo64.tga", paths)

    def test_lumen_geometry_matches_the_radius_tokens(self):
        # The fills are drawn on a 14-unit corner and the outline on 8, at TEXELS_PER_UNIT; the kit stretches them to
        # the corner it draws. A ring line's corner piece is half the texture: its four quarter rings meet in the middle.
        density = self.mm.TEXELS_PER_UNIT
        for name in ("LumenShape", "CardShape"):
            self.assertEqual(self.mm.SLICE[name], 14 * density, name)
        self.assertEqual(self.mm.SLICE["LumenOutline"], 8 * density)
        for n in self.mm.RING_LINES:
            self.assertEqual(self.mm.SLICE[f"RingLine{n}"], self.mm.RING_TEXELS // 2, n)
        self.assertEqual(self.mm.SLICE["Shadow"], 2 * 6 * self.mm.SHADOW_TEXELS_PER_UNIT, "the shadow reaches 6 units")
        self.assertFalse(any(name.startswith(("Bevel", "Chamfer")) for name in self.mm.SLICE), "no chamfer or bevel slices")


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
                per_unit = mm.SHADOW_TEXELS_PER_UNIT if stem in ("Shadow", "LumenShadow") else mm.TEXELS_PER_UNIT
                self.assertEqual(int(density), per_unit, f"{stem} texels per unit")


    def test_tokens_match_the_baked_shadow_and_radii(self):
        # The shadow's reach and drop, and the corner radii, are baked into the textures; the tokens must say the same.
        mm = load_module()
        text = (ROOT / "Core" / "Tokens.lua").read_text(encoding="ascii")

        def size(name):
            found = re.search(r"\n\t" + name + r" = ([0-9.]+),", text)
            self.assertIsNotNone(found, name)
            return float(found.group(1))

        self.assertEqual(size("shadow"), mm.LUMEN_SHADOW_REACH)
        self.assertEqual(size("shadowOffset"), mm.LUMEN_SHADOW_DROP)
        self.assertEqual(size("radius"), mm.LUMEN_RADIUS)
        self.assertEqual(size("radiusTile"), mm.LUMEN_TILE_RADIUS)
        self.assertEqual(size("gem"), mm.GEM_UNITS)


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

    def test_lumen_shape_rounds_each_corner(self):
        # A 56-texel radius: the corner texel is clear, the arc's midpoint is half covered, the edges are solid.
        size, r = 128, 56
        last = size - 1
        for name in ("LumenShape.png", "CardShape.png"):
            for x, y in ((0, 0), (last, 0), (0, last), (last, last)):
                self.assertEqual(self.alpha(name, x, y), 0, f"{name} corner {x},{y}")
            self.assertEqual(self.alpha(name, size // 2, size // 2), 255)
            self.assertEqual(self.alpha(name, r, 0), 255, "the top edge starts where the arc ends")
            self.assertEqual(self.alpha(name, 0, r), 255, "and the left edge")
            d = round(r - r / 2 ** 0.5)
            self.assertTrue(64 <= self.alpha(name, d, d) <= 192, f"the arc crosses the diagonal {d} texels in")
            self.assertEqual(self.alpha(name, d + 3, d + 3), 255, "inside the arc is solid")
            self.assertEqual(self.alpha(name, d - 3, d - 3), 0, "outside it is clear")

    def test_ring_line_is_one_line_on_an_n_line_corner(self):
        # RingLineN: a ring one line thick, a line being 1/N of the 64-texel corner piece, clear inside and outside.
        for n in self.mm.RING_LINES:
            name, line = f"RingLine{n}.png", 64 / n
            self.assertGreaterEqual(self.alpha(name, 64, int(line / 2)), 250, f"{name}: the line at the top")
            self.assertGreaterEqual(self.alpha(name, int(line / 2), 64), 250, f"{name}: and the side")
            self.assertEqual(self.alpha(name, 64, int(line) + 2), 0, f"{name}: one line thick")
            self.assertEqual(self.alpha(name, 0, 0), 0, f"{name}: rounded")
            self.assertEqual(self.alpha(name, 64, 64), 0, f"{name}: the middle is clear")
            r = 64 - line / 2
            d = round(64 - r / 2 ** 0.5)
            self.assertGreater(self.alpha(name, d, d), 128, f"{name}: the arc crosses the diagonal")

    def test_outline_is_even(self):
        top, side, bottom = self.alpha("LumenOutline.png", 64, 1), self.alpha("LumenOutline.png", 1, 64), self.alpha("LumenOutline.png", 64, 126)
        self.assertEqual(top, side)
        self.assertEqual(side, bottom)
        self.assertGreaterEqual(top, 250)

    def test_gem_is_the_pictures_flat_diamond(self):
        tl, br = self.px("LumenGem.png", 28, 28), self.px("LumenGem.png", 36, 36)
        self.assertEqual((tl[3], br[3]), (255, 255))
        self.assertEqual(tl[:3], br[:3], "one flat level, not four lit facets")
        self.assertEqual(self.alpha("LumenGem.png", 32, 32 - 15), 255, "solid to its top point")
        self.assertEqual(self.alpha("LumenGem.png", 32, 32 - 18), 0, "and no halo past it")
        self.assertEqual(self.alpha("LumenGem.png", 0, 0), 0)

    def test_cap_masks_round_one_end_each(self):
        self.assertEqual(self.alpha("PillCapLeft.png", 0, 0), 0, "the left mask rounds its left corners")
        self.assertEqual(self.alpha("PillCapLeft.png", 31, 0), 255, "and keeps its right half solid")
        self.assertEqual(self.alpha("PillCapRight.png", 31, 0), 0, "the right mask rounds its right corners")
        self.assertEqual(self.alpha("PillCapRight.png", 0, 0), 255, "and keeps its left half solid")
        self.assertEqual(self.alpha("PillCapLeft.png", 1, 16), 255, "the cap reaches the end at mid-height")

    def test_sheen_fades_from_the_top(self):
        self.assertGreaterEqual(self.alpha("BarSheen.png", 4, 0), 250, "full at the top row")
        self.assertEqual(self.alpha("BarSheen.png", 4, 20), 0, "gone 55% of the way down")
        self.assertGreater(self.alpha("BarSheen.png", 4, 4), self.alpha("BarSheen.png", 4, 12))

    def test_lens_mask_is_a_disc(self):
        self.assertEqual(self.alpha("LensMask.png", 256, 256), 255)
        self.assertEqual(self.alpha("LensMask.png", 0, 0), 0)
        self.assertEqual(self.alpha("LensMask.png", 256, 1), 255, "it reaches the edge")
        self.assertEqual(self.alpha("LensMask.png", 256, 60), self.alpha("LensMask.png", 60, 256), "round")

    def test_lumen_shadow_is_never_under_the_card(self):
        # As a CSS box shadow: clear inside the card, soft outside it, heavier below than above (the 4-unit drop).
        edge = self.mm.SLICE["LumenShadow"] // 2
        self.assertEqual(self.alpha("LumenShadow.png", 64, 64), 0, "clear under the card")
        self.assertEqual(self.alpha("LumenShadow.png", 64, edge + 2), 0, "clear just inside its top edge")
        below, above = self.alpha("LumenShadow.png", 64, 128 - edge + 2), self.alpha("LumenShadow.png", 64, edge - 3)
        self.assertGreater(below, above, "heavier below the card than above it")
        self.assertGreater(below, 150)
        self.assertLessEqual(self.alpha("LumenShadow.png", 64, 0), 2, "faded out at the reach")

    def test_rule_fades_to_the_right(self):
        self.assertEqual(self.alpha("RuleFade.png", 0, 1), 255)
        self.assertEqual(self.alpha("RuleFade.png", 255, 1), 0)
        self.assertGreater(self.alpha("RuleFade.png", 64, 1), self.alpha("RuleFade.png", 192, 1))

    def test_sliced_textures_stretch_without_distortion(self):
        # A nine-slice stretches the strips between the margins. Every column and every row there
        # must be the same, or the stretch smears a corner's diagonal along the edge.
        # A ring line has no centre: its corner pieces meet in the middle and the kit draws its runs as solid lines.
        for asset in self.mm.ASSETS:
            if not asset.slice or asset.name.startswith("RingLine"):
                continue
            name, m = Path(asset.path).name, asset.slice
            self.assertLess(2 * m, asset.width, f"{name} keeps a stretchable centre")
            for x in range(m + 1, asset.width - m):
                for y in range(asset.height):
                    self.assertLessEqual(abs(self.alpha(name, x, y) - self.alpha(name, m, y)), 2, f"{name} column {x} row {y}")
            for y in range(m + 1, asset.height - m):
                for x in range(asset.width):
                    self.assertLessEqual(abs(self.alpha(name, x, y) - self.alpha(name, x, m)), 2, f"{name} row {y} column {x}")

    def test_socket_mask_rounds_3_units_of_44(self):
        # Every square icon and the square portrait are masked to meet the socket's inner corner: 3 of 44 units, the
        # owner's picture of 2026-11-09.
        r = 128 * 3 / 44
        self.assertEqual(self.alpha("SocketMask.png", 0, 0), 0)
        self.assertEqual(self.alpha("SocketMask.png", 64, 64), 255)
        self.assertEqual(self.alpha("SocketMask.png", int(r) + 1, 0), 255, "the top edge after the arc")
        d = round(r - r / 2 ** 0.5)
        self.assertEqual(self.alpha("SocketMask.png", d - 3, d - 3), 0, "outside the arc")

    def test_portrait_mask_rounds_8_units_of_44(self):
        # The square portrait keeps the rounder mask its frame's pinned corner needs.
        r = 128 * 8 / 44
        self.assertEqual(self.alpha("PortraitMask.png", int(r) + 1, 0), 255, "the top edge after the arc")
        d = round(r - r / 2 ** 0.5)
        self.assertEqual(self.alpha("PortraitMask.png", d - 3, d - 3), 0, "outside the arc")

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

    def test_ring_bevel_is_a_thin_ring_lit_between_a_dark_outer_and_a_mid_inner_edge(self):
        # The mockup's portrait ring (measured at 1.348 px per unit): a dark bronze outer edge, a bright line, then the
        # accent, 3 px on a 118 px disc, with the dark disc showing 2 px outside it. The texture bakes the shading into
        # its colour channels so one tint (the accent lifted toward white) gives all three tones.
        width, height, _ = self.rendered["RingBevel.png"]
        self.assertEqual((width, height), (128, 128))
        self.assertEqual(self.alpha("RingBevel.png", 64, 64), 0, "clear inside")
        self.assertEqual(self.alpha("RingBevel.png", 0, 0), 0, "clear at the corners")
        self.assertEqual(self.alpha("RingBevel.png", 64, 0), 0, "the disc under it shows outside the line")
        outer, peak, inner = self.px("RingBevel.png", 64, 2), self.px("RingBevel.png", 64, 4), self.px("RingBevel.png", 64, 6)
        self.assertEqual((outer[3], peak[3], inner[3]), (255, 255, 255), "the band is opaque from radius 57 to 62")
        self.assertEqual(self.alpha("RingBevel.png", 64, 8), 0, "and clear inside radius 56, where the portrait starts")
        self.assertLess(outer[0], inner[0], "the outer edge is darker than the inner")
        self.assertLess(inner[0], peak[0], "and the middle is the brightest: the lit bevel")
        self.assertGreaterEqual(peak[0], 235, "the lit middle is near white before the tint")
        self.assertEqual(peak[0], peak[1], "grey, so SetVertexColor tints it")
        self.assertAlmostEqual(self.mm.RING_BEVEL_INSET, 8 / 128)

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

    def test_minimap_mask_is_a_plain_square(self):
        # The owner's picture draws the map as a plain square with square corners (LEE-20: the picture wins over the
        # chamfered mask of #207), so the mask is opaque white to every edge and corner of its 64 texels.
        width, height, _ = self.rendered["MinimapMask.png"]
        self.assertEqual((width, height), (64, 64))
        for x, y in ((0, 0), (63, 0), (0, 63), (63, 63), (32, 32), (32, 0), (0, 32)):
            self.assertEqual(self.alpha("MinimapMask.png", x, y), 255, f"texel {x},{y} is opaque: no corner is cut")
        px = self.px("MinimapMask.png", 32, 32)
        self.assertEqual(px[:3], (255, 255, 255), "white, so the alpha alone masks")

    def test_minimap_module_wears_the_square_mask(self):
        face = (ROOT / "KstyleUI_Minimap" / "Face.lua").read_text(encoding="ascii")
        game = (ROOT / "KstyleUI_Minimap" / "Map.lua").read_text(encoding="ascii")
        self.assertIn('Tokens.Texture("minimapMask")', face, "the face's own mask is the square mask")
        self.assertIn('Tokens.Texture("minimapMask")', game, "the Minimap frame and the hybrid map wear the square mask")
        self.assertNotIn("lensMask", face + game, "nothing in the module asks for the round lens mask")
        fmt = (ROOT / "KstyleUI_Minimap" / "Format.lua").read_text(encoding="ascii")
        self.assertNotIn("MASK_", fmt, "no chamfer numbers: the mask has no cut to meet")
        self.assertIsNone(re.search(r"local (RIM|FOOT|COMPASS_PLATE)\s*=", fmt), "the lens card's bands are gone")
        self.assertIsNone(re.search(r"local HEAD\s*=", fmt), "the card has no head band: the north mark rides the lens")

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
