"""Tests for Tools/render/standins.py and gen_glyphs.py: the mockup crops, the backdrop and the glyph table."""

import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path

RENDER = Path(__file__).resolve().parents[1] / "render"

try:
    from PIL import Image
except ImportError:  # pragma: no cover - depends on the machine
    Image = None


def load(name):
    spec = importlib.util.spec_from_file_location(name, RENDER / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@unittest.skipUnless(Image, "Pillow is not installed")
class StandinsTest(unittest.TestCase):
    def setUp(self):
        self.standins = load("standins")
        self.assertTrue(self.standins.pillow())
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def mockup(self):
        """A mockup-sized image: a blue field with a red square where the player portrait is."""
        image = Image.new("RGB", (2574, 1456), (20, 40, 200))
        left, top, right, bottom = self.standins.CROPS["portrait-player.png"]
        image.paste((200, 30, 30), (left, top, right, bottom))
        path = self.root / "mockup.png"
        image.save(path)
        return path

    def test_writes_every_stand_in_at_its_size(self):
        out = self.root / "standins"
        written = self.standins.write(str(self.mockup()), str(out), 2383, 1540)
        self.assertEqual(sorted(os.path.basename(p) for p in written), ["backdrop.png", "minimap.png", "portrait-player.png", "portrait-target.png"])
        self.assertEqual(Image.open(out / "portrait-player.png").size, (128, 128))
        self.assertEqual(Image.open(out / "portrait-target.png").size, (128, 128))
        self.assertEqual(Image.open(out / "minimap.png").size, (256, 256))
        self.assertEqual(Image.open(out / "backdrop.png").size, (2383, 1540))
        # The player crop is the red square; the target crop is the field.
        self.assertEqual(Image.open(out / "portrait-player.png").getpixel((64, 64)), (200, 30, 30))
        self.assertEqual(Image.open(out / "portrait-target.png").getpixel((64, 64)), (20, 40, 200))

    def test_backdrop_scales_to_the_height_and_crops_the_width_from_the_centre(self):
        image = Image.new("RGB", (400, 200), (10, 10, 10))
        image.paste((250, 250, 250), (0, 0, 100, 200))  # a white band at the left edge
        out = self.standins.backdrop(image, 300, 300, areas=[], radius=1, feather=1)
        self.assertEqual(out.size, (300, 300))
        # Scaled by 1.5 the image is 600 wide; the centre 300 start at x=150, past the band's end at 150.
        self.assertLess(out.getpixel((2, 150))[0], 30)
        self.assertLess(out.getpixel((297, 150))[0], 30)

    def test_backdrop_blurs_the_ui_areas_only(self):
        image = Image.new("RGB", (600, 300), (0, 0, 0))
        for x in range(0, 600, 2):
            image.paste((255, 255, 255), (x, 0, x + 1, 300))  # one-pixel stripes
        out = self.standins.backdrop(image, 600, 300, areas=[(0, 0, 200, 300)], radius=6, feather=1)
        blurred = [out.getpixel((x, 150))[0] for x in range(40, 60)]
        sharp = [out.getpixel((x, 150))[0] for x in range(500, 520)]
        self.assertLess(max(blurred) - min(blurred), 60, "the UI area is blurred flat")
        self.assertGreater(max(sharp) - min(sharp), 150, "the scenery keeps its stripes")

    def test_main_without_a_mockup_is_quiet_and_succeeds(self):
        code = self.standins.main(["--mockup", str(self.root / "missing.png"), "--out", str(self.root / "out"), "--quiet"])
        self.assertEqual(code, 0)
        self.assertFalse((self.root / "out").exists())

    def test_a_missing_mockup_needs_no_pillow(self):
        """shoot.sh runs standins.py on every machine; without a mockup it must not ask for Pillow."""
        fresh = load("standins")
        self.assertIsNone(fresh.Image, "Pillow is imported only when a mockup is cropped")
        self.assertEqual(fresh.main(["--mockup", str(self.root / "missing.png"), "--quiet"]), 0)
        self.assertIsNone(fresh.Image)


@unittest.skipUnless(Image, "Pillow is not installed")
class GlyphsTest(unittest.TestCase):
    def test_glyph_table_is_current(self):
        """glyphs.lua matches the fonts in Media/Fonts, so the scene measures text as the page draws it."""
        gen = load("gen_glyphs")
        fonts_dir = RENDER.parents[1] / "Media" / "Fonts"
        paths = sorted(fonts_dir.glob("*.ttf"))
        fonts = {path.stem: gen.advances(str(path)) for path in paths}
        expected = gen.render(fonts)
        actual = (RENDER / "glyphs.lua").read_text(encoding="utf-8")
        self.assertEqual(actual, expected, "run python3 Tools/render/gen_glyphs.py and commit glyphs.lua")

    def test_render_writes_a_lua_table_per_font(self):
        gen = load("gen_glyphs")
        text = gen.render({"Face": {65: 0.5, 32: 0.25}})
        self.assertIn('["Face"] = {', text)
        self.assertIn("[32] = 0.2500, [65] = 0.5000,", text)


if __name__ == "__main__":
    unittest.main()
