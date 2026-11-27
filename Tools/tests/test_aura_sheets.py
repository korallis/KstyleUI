"""Tests for the crest's animated aura sheets in Media/Textures/Auras/, as shipped.

Tools/media/forge/auras.py starts each sheet after its smallest step (loop_start), so the game never shows the loop's
largest jump at the wrap from the last cell back to the first. A sheet baked before that rule, or edited by hand, can
still wrap on its biggest jump; this reads every shipped 4x4 sheet and checks the wrap is no larger than the loop's
largest ordinary step. The checks need Pillow and skip without it.
"""

import unittest
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageStat
except ImportError:
    Image = None

ROOT = Path(__file__).resolve().parents[2]
AURAS = ROOT / "Media" / "Textures" / "Auras"
GRID, FRAMES = 4, 16


def steps(path):
    """The mean absolute RGB change from each cell to the next, the last being the wrap back to the first."""
    with Image.open(path) as image:
        sheet = image.convert("RGB")
    cell = sheet.width // GRID
    cells = [sheet.crop((k * cell, r * cell, (k + 1) * cell, (r + 1) * cell)) for r in range(GRID) for k in range(GRID)]
    return [sum(ImageStat.Stat(ImageChops.difference(cells[(i + 1) % FRAMES], cells[i])).mean) / 3 for i in range(FRAMES)]


@unittest.skipIf(Image is None, "Pillow is not installed")
class AuraSheetLoops(unittest.TestCase):
    def test_the_wrap_is_no_larger_than_the_loops_largest_step(self):
        sheets = [p for p in sorted(AURAS.rglob("*.png")) if Image.open(p).size == (512, 512)]
        self.assertGreater(len(sheets), 0, "the aura sheets are where this test reads them")
        for path in sheets:
            with self.subTest(sheet=path.relative_to(ROOT).as_posix()):
                s = steps(path)
                self.assertLessEqual(s[-1], max(s[:-1]), "the sheet wraps on its largest jump")


if __name__ == "__main__":
    unittest.main()
