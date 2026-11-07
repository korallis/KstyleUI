"""Tests for Tools/media/make_minimap_glyphs.py, which draws the minimap button glyph sheet."""

import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Tools" / "media" / "make_minimap_glyphs.py"


def load_module():
    sys.path.insert(0, str(SCRIPT.parent))
    spec = importlib.util.spec_from_file_location("make_minimap_glyphs", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class GlyphSheetTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mg = load_module()

    def test_sheet_is_power_of_two(self):
        for n in (self.mg.WIDTH, self.mg.HEIGHT):
            self.assertEqual(n & (n - 1), 0, f"{n} is not a power of two")

    def test_shipped_sheet_matches_the_script(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(self.mg.main(["--check"]), 0, "run python3 Tools/media/make_minimap_glyphs.py")

    def test_check_fails_on_a_changed_sheet(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / self.mg.PATH
            path.parent.mkdir(parents=True)
            path.write_bytes(b"not a png")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(self.mg.main(["--root", tmp, "--check"]), 1)

    def test_each_named_cell_has_a_glyph_and_the_rest_are_empty(self):
        mm = self.mg.mm
        width, height, pixels = mm.decode_png((ROOT / self.mg.PATH).read_bytes())
        cell = self.mg.CELL

        def coverage(index):
            col, row = index % self.mg.COLUMNS, index // self.mg.COLUMNS
            total = 0
            for y in range(row * cell, (row + 1) * cell):
                for x in range(col * cell, (col + 1) * cell):
                    total += pixels[4 * (y * width + x) + 3]
            return total

        for index, name in enumerate(self.mg.NAMES):
            self.assertGreater(coverage(index), 255 * 20, f"the {name} cell is empty")
        for index in range(len(self.mg.NAMES), self.mg.COLUMNS * self.mg.ROWS):
            self.assertEqual(coverage(index), 0, f"cell {index} should be empty")

    def test_provenance_lists_the_sheet(self):
        text = (ROOT / "Media" / "PROVENANCE.md").read_text(encoding="utf-8")
        self.assertIn(f"`{self.mg.PATH}`", text, "add a Media/PROVENANCE.md row for the glyph sheet")


if __name__ == "__main__":
    unittest.main()
