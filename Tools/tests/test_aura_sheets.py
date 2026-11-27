"""Tests for the crest's animated aura sheets in Media/Textures/Auras/, as shipped.

Tools/media/forge/auras.py starts each sheet after its smallest step (loop_start), so the game never shows the loop's
largest jump at the wrap from the last cell back to the first. A sheet baked before that rule, or edited by hand, can
still wrap on its biggest jump; this reads every shipped sheet and checks the wrap is no larger than the loop's largest
ordinary step. Every file in a folder under Media/Textures/Auras/ is a 4x4 sheet of 128 px cells (the socket, the one
still picture, sits at the top), so a sheet of the wrong size fails here rather than drop out of the check. The checks
need Pillow and skip without it.
"""

import unittest
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageStat
except ImportError:
    Image = None

ROOT = Path(__file__).resolve().parents[2]
AURAS = ROOT / "Media" / "Textures" / "Auras"
GRID, FRAMES, SIZE = 4, 16, 512


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
        sheets = sorted(p for p in AURAS.glob("*/**/*") if p.is_file())
        self.assertGreater(len(sheets), 0, "the aura sheets are where this test reads them")
        for path in sheets:
            with self.subTest(sheet=path.relative_to(ROOT).as_posix()):
                self.assertEqual(path.suffix, ".png", "an aura folder holds only sheets")
                with Image.open(path) as image:
                    self.assertEqual(image.size, (SIZE, SIZE), "a sheet is 4x4 cells of 128 px")
                s = steps(path)
                self.assertLessEqual(s[-1], max(s[:-1]), "the sheet wraps on its largest jump")


if __name__ == "__main__":
    unittest.main()
