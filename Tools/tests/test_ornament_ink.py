"""Tests for Tools/media/ornament_ink.py: the ink shapes the registry and the guard share come from the PNGs and stay current."""

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Tools" / "media" / "ornament_ink.py"


def load():
    spec = importlib.util.spec_from_file_location("ornament_ink", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class OrnamentInkTest(unittest.TestCase):
    def test_table_is_current(self):
        """Core/Widgets/OrnamentInk.lua matches the PNGs; a repainted pendant or ring fails here until the file is written again."""
        self.assertEqual(load().main(["--check"]), 0, "run python3 Tools/media/ornament_ink.py and commit Core/Widgets/OrnamentInk.lua")

    def test_spans_cover_every_ink_pixel_widened_by_one(self):
        gen = load()
        width, height, rows = gen.alpha(gen.FORGED / "BossPendantR70.png")
        runs = gen.spans(rows, 93, 152)
        covered = {}
        for top, bottom, left, right in runs:
            for y in range(top, bottom):
                covered[y] = (left, right)
        for y in range(152):
            ink = [x for x, value in enumerate(rows[y][:93]) if value]
            if ink:
                self.assertEqual(covered[y], (ink[0] - 1, ink[-1] + 2), "row %d" % y)
            else:
                self.assertNotIn(y, covered)

    def test_circles_cover_the_corners(self):
        gen = load()
        width, height, rows = gen.alpha(ROOT / "Media" / "Textures" / "Dot.png")
        self.assertAlmostEqual(gen.circle(rows, width, height), 1.0064, places=3)
        width, height, rows = gen.alpha(gen.FORGED / "Ring39.png")
        self.assertGreater(gen.circle(rows, 49, 49), 1.0, "the band's nubs reach past the inscribed circle")

    def test_check_fails_on_a_stale_file(self):
        gen = load()
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "OrnamentInk.lua"
            out.write_bytes(b"-- stale\r\n")
            self.assertEqual(gen.main(["--check", "--out", str(out)]), 1)
            self.assertEqual(gen.main(["--out", str(out)]), 0)
            self.assertEqual(gen.main(["--check", "--out", str(out)]), 0)
            text = out.read_bytes()
            self.assertTrue(text.isascii() and b"\r\n" in text and b"\n" not in text.replace(b"\r\n", b""), "an ASCII addon file with CRLF endings")
            self.assertEqual(text.count(b"--"), 1, "one comment, its first line")


if __name__ == "__main__":
    unittest.main()
