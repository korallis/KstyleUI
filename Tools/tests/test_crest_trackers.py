"""Tests for Tools/media/crest_trackers.py: it writes both crest tracker textures into any --out folder, inside the
repository or not, byte-identical to the shipped files. Skips without NumPy or Pillow."""

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

try:
    import numpy  # noqa: F401
    from PIL import Image  # noqa: F401
except ImportError:
    numpy = None


@unittest.skipIf(numpy is None, "needs NumPy and Pillow")
class CrestTrackers(unittest.TestCase):
    def test_writes_both_textures_outside_the_repository(self):
        spec = importlib.util.spec_from_file_location("crest_trackers", ROOT / "Tools/media/crest_trackers.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as out, mock.patch.object(sys, "argv", ["crest_trackers.py", "--out", out]):
            with redirect_stdout(io.StringIO()):
                module.main()
            for name in ("SoulWisp.png", "Gust.png"):
                self.assertEqual((Path(out) / name).read_bytes(), (SHIPPED / name).read_bytes(), name)


if __name__ == "__main__":
    unittest.main()
