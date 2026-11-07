"""Tests for Tools/icons/check_icons.py, which rejects blank, clipped, coloured or text-bearing icons.

The tests build small synthetic rasters, so they need neither Pillow nor the OCR helper.
"""

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "icons"))

import check_icons  # noqa: E402

SIZE = 256


def raster(paint, size=SIZE, chroma=0):
    """A raster whose luma at (x, y) is paint(x, y), with a flat chroma wherever luma is lit."""
    luma = bytearray(size * size)
    tint = bytearray(size * size)
    for y in range(size):
        for x in range(size):
            value = paint(x, y)
            luma[y * size + x] = value
            tint[y * size + x] = chroma if value else 0
    return check_icons.Raster(size, bytes(luma), bytes(tint))


def disc(cx, cy, radius, value=230):
    return lambda x, y: value if (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius else 0


def codes(reasons):
    return {reason.split(":")[0] for reason in reasons}


class JudgeTest(unittest.TestCase):
    def test_accepts_a_bright_central_subject_on_black(self):
        self.assertEqual(check_icons.judge(raster(disc(128, 128, 80))), [])

    def test_rejects_a_black_image_as_blank(self):
        self.assertIn("blank", codes(check_icons.judge(raster(lambda x, y: 0))))

    def test_rejects_a_faint_image_as_blank(self):
        self.assertIn("blank", codes(check_icons.judge(raster(disc(128, 128, 80, value=50)))))

    def test_rejects_a_subject_too_small_to_read_at_32_pixels(self):
        square = lambda x, y: 230 if 98 <= x < 158 and 98 <= y < 158 else 0  # noqa: E731
        self.assertEqual(codes(check_icons.judge(raster(square))), {"small"})

    def test_names_each_edge_the_subject_crosses(self):
        reasons = check_icons.judge(raster(disc(250, 128, 70)))
        self.assertIn("clipped:right", reasons)
        self.assertNotIn("clipped:left", reasons)
        reasons = check_icons.judge(raster(disc(128, 4, 70)))
        self.assertIn("clipped:top", reasons)

    def test_ignores_a_faint_wisp_at_the_edge(self):
        wisp = lambda x, y: 230 if (x - 128) ** 2 + (y - 128) ** 2 <= 6400 else (40 if x > 240 else 0)  # noqa: E731
        self.assertEqual(check_icons.judge(raster(wisp)), [])

    def test_rejects_a_light_background(self):
        self.assertIn("background", codes(check_icons.judge(raster(lambda x, y: 200 if x % 7 else 90))))

    def test_rejects_a_coloured_cast(self):
        self.assertEqual(codes(check_icons.judge(raster(disc(128, 128, 80), chroma=60))), {"colour"})

    def test_accepts_slight_jpeg_like_chroma(self):
        self.assertEqual(check_icons.judge(raster(disc(128, 128, 80), chroma=4)), [])

    def test_scales_the_edge_band_with_the_raster(self):
        small = raster(disc(64, 64, 40), size=128)
        self.assertEqual(check_icons.judge(small), [])
        self.assertIn("clipped:bottom", check_icons.judge(raster(disc(64, 125, 40), size=128)))


def painting(x, y):
    """A full-bleed painting: a textured mid-dark background and a bright subject in the centre."""
    background = 40 + ((x * 7 + y * 13) % 50)
    return 235 if (x - 128) ** 2 + (y - 128) ** 2 <= 70 * 70 else background


def framed(paint, margin=12):
    """The painting shrunk inside a black margin, as the model draws it when it copies the reference sheet."""
    return lambda x, y: paint(x, y) if margin <= x < SIZE - margin and margin <= y < SIZE - margin else 0


class JudgeColourTest(unittest.TestCase):
    """Set B: full-colour paintings that fill the square edge to edge."""

    def judge(self, paint, **kwargs):
        return check_icons.judge_colour(raster(paint, chroma=90), **kwargs)

    def test_accepts_a_full_bleed_painting_with_a_bright_centre(self):
        self.assertEqual(self.judge(painting), [])

    def test_accepts_colour(self):
        self.assertNotIn("colour", codes(self.judge(painting)))

    def test_accepts_a_dark_painting_with_one_bright_subject(self):
        dark = lambda x, y: 230 if (x - 128) ** 2 + (y - 128) ** 2 <= 50 * 50 else 18 + (x + y) % 12  # noqa: E731
        self.assertEqual(self.judge(dark), [])

    def test_rejects_a_flat_or_unlit_image_as_blank(self):
        self.assertIn("blank", codes(self.judge(lambda x, y: 90)))
        self.assertIn("blank", codes(self.judge(lambda x, y: 20 + (x * 3 + y) % 60)))

    def test_rejects_detail_that_vanishes_at_32_pixels(self):
        checker = lambda x, y: 220 if (x // 2 + y // 2) % 2 else 30  # noqa: E731
        self.assertEqual(codes(self.judge(checker)), {"flat"})

    def test_rejects_a_black_margin_around_the_painting(self):
        self.assertIn("frame", codes(self.judge(framed(painting))))

    def test_accepts_dark_paint_at_some_edges(self):
        vignette = lambda x, y: 0 if x < 10 or y < 10 else painting(x, y)  # noqa: E731
        self.assertNotIn("frame", codes(self.judge(vignette)))

    def test_rejects_a_sheet_of_several_icons(self):
        rows = lambda x, y: 0 if 120 <= y < 132 else painting(x, y)  # noqa: E731
        columns = lambda x, y: 0 if 80 <= x < 90 or 160 <= x < 170 else painting(x, y)  # noqa: E731
        self.assertIn("grid:rows", self.judge(rows))
        self.assertIn("grid:columns", self.judge(columns))

    def test_a_dark_lower_half_is_not_a_grid(self):
        lower = lambda x, y: 0 if y >= 150 else painting(x, y)  # noqa: E731
        self.assertNotIn("grid", codes(self.judge(lower)))

    def test_rejects_a_subject_at_an_edge_with_a_dark_centre(self):
        corner = lambda x, y: 230 if x > 200 else 25 + (x + y) % 20  # noqa: E731
        self.assertEqual(self.judge(corner), ["clipped:right"])

    def test_accepts_a_subject_that_runs_off_one_edge_from_a_lit_centre(self):
        blade = lambda x, y: 230 if abs(x - y) < 30 else 40 + (x * 7 + y * 13) % 50  # noqa: E731
        self.assertEqual(self.judge(blade), [])

    def test_rejects_readable_text(self):
        self.assertEqual(self.judge(painting, texts=[("FROSTBOLT", 0.9)]), ["text:FROSTBOLT"])


class JudgeForTest(unittest.TestCase):
    def test_picks_the_check_for_each_set(self):
        self.assertIs(check_icons.judge_for("A"), check_icons.judge)
        self.assertIs(check_icons.judge_for("B"), check_icons.judge_colour)

    def test_rejects_an_unknown_set(self):
        with self.assertRaises(KeyError):
            check_icons.judge_for("C")


class TextTest(unittest.TestCase):
    def test_rejects_readable_text(self):
        reasons = check_icons.judge(raster(disc(128, 128, 80)), texts=[("SHIELD WALL", 1.0)])
        self.assertEqual(reasons, ["text:SHIELD WALL"])

    def test_ignores_low_confidence_and_single_glyph_readings(self):
        texts = [("Wall", 0.3), ("I", 0.95), ("-", 1.0), ("*.", 0.9)]
        self.assertEqual(check_icons.judge(raster(disc(128, 128, 80)), texts=texts), [])

    def test_parses_the_helper_output(self):
        lines = [
            json.dumps({"path": "a.png", "texts": [{"text": "Sonic", "confidence": 1}]}),
            json.dumps({"path": "b.png", "texts": []}),
        ]
        self.assertEqual(
            check_icons.parse_ocr("\n".join(lines)),
            {"a.png": [("Sonic", 1.0)], "b.png": []},
        )

    def test_a_helper_error_is_not_a_clean_reading(self):
        line = json.dumps({"path": "a.png", "texts": [], "error": "cannot read the image"})
        with self.assertRaisesRegex(check_icons.OcrError, "a.png: cannot read the image"):
            check_icons.parse_ocr(line)


if __name__ == "__main__":
    unittest.main()
