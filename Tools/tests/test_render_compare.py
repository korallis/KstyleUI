"""Tests for Tools/render/compare.py: crop parsing and the side-by-side output."""

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "render" / "compare.py"

try:
    from PIL import Image
except ImportError:  # pragma: no cover - depends on the machine
    Image = None


def load():
    spec = importlib.util.spec_from_file_location("compare", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@unittest.skipUnless(Image, "Pillow is not installed")
class CompareTest(unittest.TestCase):
    def setUp(self):
        self.compare = load()
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def test_parse_crop_in_pixels_and_units(self):
        self.assertEqual(self.compare.parse_crop("10,20,30,40", 2.0), (10, 20, 30, 40))
        self.assertEqual(self.compare.parse_crop("10,20,30,40u", 2.0), (20, 40, 60, 80))
        self.assertEqual(self.compare.parse_crop("0,0,0,0", 1.0)[2:], (1, 1))

    def test_writes_side_by_side_at_the_render_density(self):
        render = self.root / "render.png"
        ref = self.root / "ref.png"
        out = self.root / "out.png"
        Image.new("RGB", (200, 100), (10, 20, 30)).save(render)
        Image.new("RGB", (400, 200), (40, 50, 60)).save(ref)
        code = self.compare.main([
            "--render", str(render), "--render-ppu", "1.0", "--crop", "0,0,100,50",
            "--ref", str(ref), "--ref-ppu", "2.0", "--ref-crop", "0,0,200,100",
            "--out", str(out), "--scale", "1",
        ])
        self.assertEqual(code, 0)
        image = Image.open(out)
        # Two 100 by 50 crops, an 8 pixel gap and an 18 pixel label strip.
        self.assertEqual(image.size, (208, 68))
        self.assertEqual(image.getpixel((50, 40)), (10, 20, 30))
        self.assertEqual(image.getpixel((158, 40)), (40, 50, 60))


if __name__ == "__main__":
    unittest.main()
