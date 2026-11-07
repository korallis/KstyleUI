"""Tests for Tools/spikes/KstyleUI_Spike/make_media.py, which draws the textures spike's PNGs."""

import contextlib
import importlib.util
import io
import struct
import tempfile
import unittest
import zlib
from pathlib import Path

SPIKE = Path(__file__).resolve().parents[1] / "spikes" / "KstyleUI_Spike"


def load_module():
    spec = importlib.util.spec_from_file_location("make_media", SPIKE / "make_media.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_png(path, raw_out=None):
    """Return (width, height, pixel) for an 8-bit RGBA PNG whose rows use filter type 0.

    Pass a list as raw_out to receive the decoded scanlines.
    """
    data = Path(path).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos, idat, header = 8, b"", None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos : pos + 8])
        body = data[pos + 8 : pos + 8 + length]
        crc = struct.unpack(">I", data[pos + 8 + length : pos + 12 + length])[0]
        assert zlib.crc32(kind + body) == crc, f"bad CRC in {kind!r}"
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    width, height, depth, colour, _, _, interlace = header
    assert (depth, colour, interlace) == (8, 6, 0), "expected 8-bit RGBA, not interlaced"
    raw = zlib.decompress(idat)
    stride = 1 + 4 * width
    assert len(raw) == stride * height
    if raw_out is not None:
        raw_out.append(raw)

    def pixel(x, y):
        row = y * stride
        assert raw[row] == 0, "expected filter type 0"
        start = row + 1 + 4 * x
        return tuple(raw[start : start + 4])

    return width, height, pixel


class SpikeMediaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module()
        cls._tmp = tempfile.TemporaryDirectory()
        cls.out = Path(cls._tmp.name)
        with contextlib.redirect_stdout(io.StringIO()):
            cls.module.main([str(cls.out)])

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def test_writes_power_of_two_rgba_pngs(self):
        for name, size in (("mask_2048.png", 2048), ("alpha_test.png", 256)):
            width, height, _ = read_png(self.out / name)
            self.assertEqual((width, height), (size, size), name)

    def test_mask_is_a_chamfered_square_with_a_diamond_cut_out(self):
        _, _, pixel = read_png(self.out / "mask_2048.png")
        self.assertEqual(pixel(0, 0)[3], 0, "corner is chamfered away")
        self.assertEqual(pixel(2047, 2047)[3], 0, "corner is chamfered away")
        self.assertEqual(pixel(1024, 1024)[3], 0, "centre diamond is cut out")
        self.assertEqual(pixel(1024, 200)[3], 255, "body is opaque")
        self.assertEqual(pixel(200, 1024)[3], 255, "body is opaque")
        self.assertEqual(pixel(1024, 200)[:3], (255, 255, 255), "colour is white")

    def test_alpha_test_separates_alpha_from_colour(self):
        # Alpha ramps left to right and grey ramps top to bottom, so a mask that reads alpha shows a
        # horizontal gradient and a mask that reads colour shows a vertical one.
        _, _, pixel = read_png(self.out / "alpha_test.png")
        self.assertEqual(pixel(0, 128)[3], 0)
        self.assertEqual(pixel(255, 128)[3], 255)
        self.assertEqual(pixel(128, 0)[:3], (0, 0, 0))
        self.assertEqual(pixel(128, 255)[:3], (255, 255, 255))
        self.assertEqual(pixel(10, 200)[3], pixel(10, 20)[3], "alpha does not change down a column")
        self.assertEqual(pixel(20, 10)[:3], pixel(200, 10)[:3], "grey does not change along a row")

    def test_committed_media_matches_the_script(self):
        for name in ("mask_2048.png", "alpha_test.png"):
            committed = SPIKE / "Media" / name
            self.assertTrue(committed.is_file(), f"run make_media.py: {committed} is missing")
            got, want = [], []
            read_png(committed, got)
            read_png(self.out / name, want)
            self.assertTrue(got[0] == want[0], f"{name} differs from make_media.py output: rerun the script")


if __name__ == "__main__":
    unittest.main()
