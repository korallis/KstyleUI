"""Tests for Tools/media/make_pips.py: the class-themed pips match the script, and each class's textures share one silhouette."""

import contextlib
import importlib.util
import io
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MEDIA = ROOT / "Tools" / "media"


def load():
    sys.path.insert(0, str(MEDIA))
    spec = importlib.util.spec_from_file_location("make_pips", MEDIA / "make_pips.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MakePipsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mp = load()

    def test_shipped_textures_match_the_script(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(self.mp.main(["--check"]), 0, "run python3 Tools/media/make_pips.py")

    def test_each_class_shares_one_silhouette(self):
        # The lit pip must cover its socket and its mask exactly, or a socket edge shows round a lit pip.
        for name in ("PipRogue", "PipDruid"):
            alphas = [self.mp.paint(self.mp.TEXTURES[name + part])[3::4] for part in ("", "Socket", "Shape")]
            covered = [[a > 0 for a in alpha] for alpha in alphas]
            self.assertEqual(covered[0], covered[1], f"{name} and its socket cover different texels")
            self.assertEqual(covered[0], covered[2], f"{name} and its shape cover different texels")


if __name__ == "__main__":
    unittest.main()
