"""Tests for the crest's animated aura sheets in Media/Textures/Auras/, as shipped.

Tools/media/forge/auras.py starts each sheet after its smallest step (loop_start), so the game never shows the loop's
largest jump at the wrap from the last cell back to the first. A sheet baked before that rule, or edited by hand, can
still wrap on its biggest jump; this reads every shipped sheet and checks the wrap is no larger than the loop's largest
ordinary step. Media/PROVENANCE.md lists every sheet with its size, 512x512; the sheets are read
from that list, so a listed sheet that is missing, moved or of the wrong size fails here rather than drop out of the
check, and so does a file in a sheet folder that the list does not name. Quick Shots' gust, a strip of 2 columns by 8
rows, shipped before the rule and keeps its seam, since rebaking it would change the hunter's resting art; it is still
checked for its place and size. The checks need Pillow and skip without it.
"""

import re
import unittest
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageStat
except ImportError:
    Image = None

ROOT = Path(__file__).resolve().parents[2]
AURAS = ROOT / "Media" / "Textures" / "Auras"
GRID, FRAMES, SIZE = 4, 16, 512
SHIPPED_SEAM = {"Media/Textures/Auras/Trackers/Gust.png"}
LISTED = re.compile(r"^\| `(Media/Textures/Auras/[^/`]+/[^`]+)` \| (\d+)x(\d+) \|", re.M)


def listed():
    """Each sheet Media/PROVENANCE.md records under a folder of Media/Textures/Auras/, with its recorded size."""
    text = (ROOT / "Media" / "PROVENANCE.md").read_text(encoding="utf-8")
    return {path: (int(w), int(h)) for path, w, h in LISTED.findall(text)}


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
        sheets = listed()
        self.assertGreater(len(sheets), 0, "Media/PROVENANCE.md lists the aura sheets")
        on_disk = {p.relative_to(ROOT).as_posix() for p in AURAS.glob("*/**/*") if p.is_file()}
        self.assertEqual(sorted(on_disk - set(sheets)), [], "every file in an aura folder is a listed sheet")
        for name, size in sorted(sheets.items()):
            with self.subTest(sheet=name):
                path = ROOT / name
                self.assertTrue(path.is_file(), "the listed sheet is where the game loads it")
                self.assertEqual(size, (SIZE, SIZE), "the list records a 512x512 sheet")
                with Image.open(path) as image:
                    self.assertEqual(image.size, (SIZE, SIZE), "a sheet is 512x512")
                if name in SHIPPED_SEAM:
                    continue
                s = steps(path)
                self.assertLessEqual(s[-1], max(s[:-1]), "the sheet wraps on its largest jump")


if __name__ == "__main__":
    unittest.main()
