"""Tests for Tools/render/standins.py and gen_glyphs.py: the mockup crops, the backdrop and the glyph table."""

import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

RENDER = Path(__file__).resolve().parents[1] / "render"

try:
    from PIL import Image
except ImportError:  # pragma: no cover - depends on the machine
    Image = None


def setUpModule():
    if Image is None:
        print("glyph table capabilities: Pillow=unavailable; RAQM=unavailable")
    else:
        from PIL import features

        print(f"glyph table capabilities: Pillow=available; RAQM={features.check('raqm')}")


def load(name):
    spec = importlib.util.spec_from_file_location(name, RENDER / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@unittest.skipUnless(Image, "Pillow is not installed")
class StandinsTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.addCleanup(self._tmp.cleanup)
        env = {key: value for key, value in os.environ.items() if not key.startswith("KSTYLEUI_")}
        env["HOME"] = str(self.root)
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.standins = load("standins")
        self.assertTrue(self.standins.pillow())


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
        self.assertEqual(sorted(os.path.basename(p) for p in written), ["backdrop.png", "minimap.png", "portrait-player.png", "portrait-target.png", "worldmap.png"])
        self.assertEqual(Image.open(out / "portrait-player.png").size, (128, 128))
        self.assertEqual(Image.open(out / "portrait-target.png").size, (128, 128))
        self.assertEqual(Image.open(out / "minimap.png").size, (256, 256))
        self.assertEqual(Image.open(out / "worldmap.png").size, (256, 256))
        self.assertEqual(Image.open(out / "backdrop.png").size, (2383, 1540))
        # The player crop is the red square; the target crop is the field.
        self.assertEqual(Image.open(out / "portrait-player.png").getpixel((64, 64)), (200, 30, 30))
        self.assertEqual(Image.open(out / "portrait-target.png").getpixel((64, 64)), (20, 40, 200))

    def test_worldmap_crop_is_the_minimap_terrain_lifted_to_daylight(self):
        self.standins.pillow()
        out = self.root / "standins"
        self.standins.write(str(self.mockup()), str(out), 300, 200)
        expected = Image.open(self.standins.PLATES / "minimap.png").convert("RGB")
        with Image.open(out / "minimap.png") as terrain:
            self.assertEqual(terrain.tobytes(), expected.tobytes(), "map scenery must come from the real screenshot crop")
        self.assertTrue((out / "worldmap.png").is_file())

    def test_backdrop_scales_to_the_height_and_crops_the_width_from_the_centre(self):
        image = Image.new("RGB", (400, 200), (10, 10, 10))
        image.paste((250, 250, 250), (0, 0, 100, 200))  # a white band at the left edge
        out = self.standins.backdrop(image, 300, 300)
        self.assertEqual(out.size, (300, 300))
        # Scaled by 1.5 the image is 600 wide; the centre 300 start at x=150, past the band's end at 150.
        self.assertLess(out.getpixel((2, 150))[0], 30)
        self.assertLess(out.getpixel((297, 150))[0], 30)

    def test_wide_backdrop_crops_vertically_instead_of_stretching(self):
        image = Image.new("RGB", (100, 200), (10, 10, 10))
        image.paste((250, 250, 250), (0, 0, 100, 50))
        out = self.standins.backdrop(image, 300, 100)
        self.assertEqual(out.size, (300, 100))
        self.assertLess(out.getpixel((150, 2))[0], 30, "crop uniformly; never stretch scenery to fill the canvas")

    def test_backdrop_source_prefers_the_clean_plate(self):
        """With a UI-free plate of the scene, the backdrop is that plate scaled to the render, with nothing blurred."""
        plate = Image.new("RGB", (2688, 1520), (0, 0, 0))
        for x in range(0, 2688, 2):
            plate.paste((255, 255, 255), (x, 0, x + 1, 1520))  # one-pixel stripes everywhere, UI areas included
        plate_path = self.root / "clean.png"
        plate.save(plate_path)
        mockup = Image.new("RGB", (2574, 1456), (200, 30, 30))
        source, used = self.standins.backdrop_source(mockup, str(plate_path))
        self.assertEqual(used, str(plate_path))
        out = self.standins.backdrop(source, 2574, 1456)
        self.assertEqual(out.size, (2574, 1456))
        band = [out.getpixel((x, 1300))[0] for x in range(100, 140)]  # inside the chat's UI area on the mockup
        self.assertGreater(max(band) - min(band), 100, "the plate is not blurred where the mockup has UI")

    def test_missing_plate_never_falls_back_to_mockup_scenery(self):
        with self.assertRaises(FileNotFoundError):
            self.standins.backdrop_source(Image.new("RGB", (20, 20)), str(self.root / "missing.png"))

    def test_write_uses_the_plate_when_given(self):
        plate_path = self.root / "clean.png"
        Image.new("RGB", (2688, 1520), (10, 200, 10)).save(plate_path)
        out = self.root / "standins"
        self.standins.write(str(self.mockup()), str(out), 2383, 1540, plate=str(plate_path))
        self.assertEqual(Image.open(out / "backdrop.png").getpixel((1200, 700)), (10, 200, 10))
        with self.assertRaises(FileNotFoundError):
            self.standins.write(str(self.mockup()), str(out), 2383, 1540, plate=str(self.root / "missing.png"))

    def test_plate_option_and_environment(self):
        self.assertTrue(Path(self.standins.PLATE).as_posix().endswith("docs/media/plates/forest-mac.jpg"))
        self.assertEqual(self.standins.plate_path(["--plate", "/tmp/x.png"], {}), "/tmp/x.png")
        self.assertEqual(self.standins.plate_path([], {"KSTYLEUI_PLATE": "/tmp/env.png"}), "/tmp/env.png")
        self.assertEqual(self.standins.plate_path([], {}), self.standins.PLATE)

    def test_model_stand_in_keeps_its_alpha_and_aspect(self):
        """model-player-<class>.png is the class's full-body painting from the models folder, resampled to the model
        height with its transparency kept, so the paper doll draws the figure on the window's glass; a class the
        folder no longer holds loses its file, so the scene falls back to a flat tone."""
        models = self.root / "models"
        models.mkdir()
        figure = Image.new("RGBA", (100, 200), (0, 0, 0, 0))
        figure.paste((40, 120, 40, 255), (25, 50, 75, 150))
        figure.save(models / "warrior.png")
        out = self.root / "standins"
        written = self.standins.write_models(str(out), str(models))
        self.assertEqual([os.path.basename(p) for p in written], ["model-player-warrior.png"])
        model = Image.open(out / "model-player-warrior.png")
        self.assertEqual(model.mode, "RGBA")
        self.assertEqual(model.size, (self.standins.MODEL_HEIGHT // 2, self.standins.MODEL_HEIGHT))
        self.assertEqual(model.getpixel((model.width // 2, model.height // 2)), (40, 120, 40, 255))
        self.assertEqual(model.getpixel((2, 2))[3], 0, "the air around the figure stays transparent")
        self.assertEqual(self.standins.write_models.used, ["warrior"])
        os.remove(models / "warrior.png")
        self.assertEqual(self.standins.write_models(str(out), str(models)), [])
        self.assertFalse((out / "model-player-warrior.png").exists(), "a model the folder no longer holds is removed")
        self.assertEqual(self.standins.models_path("/tmp/m", {}), "/tmp/m")
        self.assertEqual(self.standins.models_path(None, {"KSTYLEUI_MODELS": "/tmp/env"}), "/tmp/env")
        self.assertTrue(self.standins.models_path(None, {}).endswith("scenery/models"))

    def test_real_backdrop_does_not_need_the_internal_mockup(self):
        out = self.root / "out"
        code = self.standins.main(["--mockup", str(self.root / "missing.png"), "--out", str(out),
                                   "--width", "320", "--height", "180", "--quiet"])
        self.assertEqual(code, 0)
        self.assertTrue((out / "backdrop.png").exists())
        self.assertFalse((out / "portrait-player.png").exists())


@unittest.skipUnless(Image, "Pillow is not installed")
class GlyphsTest(unittest.TestCase):
    def test_glyph_table_is_current(self):
        """glyphs.lua matches the fonts in Media/Fonts, so the scene measures text as the page draws it."""
        from PIL import features

        if not features.check("raqm"):
            reason = "committed glyph table is generated with RAQM layout; this Pillow lacks RAQM"
            print(f"skip: {self.id()}: {reason}")
            self.skipTest(reason)
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
