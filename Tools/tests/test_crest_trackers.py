"""Tests for Tools/media/crest_trackers.py: it writes both crest tracker textures into any --out folder, inside the
repository or not, as PNGs of the shipped size. Skips without NumPy or Pillow."""

import importlib.util
import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SHIPPED = ROOT / "Media/Textures/Medallions/Trackers"

HAVE = importlib.util.find_spec("numpy") and importlib.util.find_spec("PIL")


@unittest.skipUnless(HAVE, "needs NumPy and Pillow")
class CrestTrackers(unittest.TestCase):
    def test_writes_both_textures_outside_the_repository(self):
        from PIL import Image

        spec = importlib.util.spec_from_file_location("crest_trackers", ROOT / "Tools/media/crest_trackers.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as out, mock.patch.object(sys, "argv", ["crest_trackers.py", "--out", out]):
            with redirect_stdout(io.StringIO()):
                module.main()
            # The captain's ruling: no test compares exact PNG bytes, which differ between NumPy and Pillow builds.
            for name in ("SoulWisp.png", "Gust.png"):
                with Image.open(Path(out) / name) as written, Image.open(SHIPPED / name) as shipped:
                    written.load()
                    self.assertEqual((written.format, written.size, written.mode), ("PNG", shipped.size, shipped.mode), name)


if __name__ == "__main__":
    unittest.main()
