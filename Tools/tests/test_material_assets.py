"""Forged bracket art fits wholly inside the texels sampled by the widget."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("material_media", ROOT / "Tools/media/make_media.py")
media = importlib.util.module_from_spec(spec)
spec.loader.exec_module(media)


class BracketFootprintTest(unittest.TestCase):
    def test_prepared_and_shipped_art_fit_the_sampled_footprint(self):
        for scale in (1, 2, 3):
            for folder in ("Tools/media/materials", "Media/Textures"):
                with self.subTest(scale=scale, folder=folder):
                    width, height, pixels = media.decode_png((ROOT / folder / f"ForgedBracket{scale}.png").read_bytes())
                    drawn = [(x, y) for y in range(height) for x in range(width) if pixels[(y * width + x) * 4 + 3]]
                    self.assertTrue(drawn)
                    self.assertEqual(max(x for x, _ in drawn), scale * 8 - 1)
                    self.assertEqual(max(y for _, y in drawn), scale * 8 - 1)


if __name__ == "__main__":
    unittest.main()
