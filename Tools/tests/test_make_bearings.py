"""Tests for Tools/media/make_bearings.py: the meter's side bearings come from the font files and stay current."""

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Tools" / "media" / "make_bearings.py"


def load():
    spec = importlib.util.spec_from_file_location("make_bearings", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BearingsTest(unittest.TestCase):
    def test_table_is_current(self):
        """KstyleUI_Meters/Bearings.lua matches Media/Fonts; a rebuilt font fails here until the table is written again."""
        gen = load()
        self.assertEqual(gen.main(["--check"]), 0, "run python3 Tools/media/make_bearings.py and commit KstyleUI_Meters/Bearings.lua")

    def test_reads_the_glyph_boxes(self):
        """Alegreya Sans ExtraBold's figures give the values the meter kept by hand before the table was generated."""
        gen = load()
        lsb, rsb = gen.bearings(ROOT / "Media" / "Fonts" / "AlegreyaSansTabular-ExtraBold.ttf")
        self.assertEqual((rsb["1"], rsb["2"], lsb["4"], rsb["%"]), (0.141, 0.022, 0.01, 0.027))
        self.assertEqual((lsb["\u00b7"], rsb["\u00b7"]), (0.033, 0.033))
        lsb, rsb = gen.bearings(ROOT / "Media" / "Fonts" / "PTSerif-Bold.ttf")
        self.assertNotEqual(rsb["1"], 0.141, "PT Serif Bold has its own bearings")

    def test_check_fails_on_a_stale_file(self):
        gen = load()
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "Bearings.lua"
            out.write_bytes(b"-- stale\r\n")
            self.assertEqual(gen.main(["--check", "--out", str(out)]), 1)
            self.assertEqual(gen.main(["--out", str(out)]), 0)
            self.assertEqual(gen.main(["--check", "--out", str(out)]), 0)
            text = out.read_bytes()
            self.assertTrue(text.isascii() and b"\r\n" in text and b"\n" not in text.replace(b"\r\n", b""), "an ASCII addon file with CRLF endings")
            self.assertEqual(text.count(b"--"), 1, "one comment, its first line")


if __name__ == "__main__":
    unittest.main()
