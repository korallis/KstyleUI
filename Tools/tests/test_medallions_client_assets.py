"""Client encoding and exact-case paths for every shipped Medallions texture."""

import re
import struct
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


class MedallionsClientAssets(unittest.TestCase):
    def test_pngs_are_power_of_two_eight_bit_rgba(self):
        paths = list((ROOT / "Media/Textures/Medallions").rglob("*.png"))
        self.assertGreater(len(paths), 100)
        for path in paths:
            with self.subTest(path=path.relative_to(ROOT)):
                data = path.read_bytes()
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                width, height, depth, color, compression, filtering, interlace = struct.unpack(
                    ">IIBBBBB", data[16:29]
                )
                self.assertEqual((depth, color, compression, filtering, interlace), (8, 6, 0, 0, 0))
                self.assertTrue(width > 0 and width & (width - 1) == 0)
                self.assertTrue(height > 0 and height & (height - 1) == 0)
                with Image.open(path) as image:
                    image.verify()

    def test_token_paths_match_disk_case(self):
        source = (ROOT / "Core/Tokens.lua").read_text()
        paths = re.findall(r'file = "(Textures\\\\Medallions\\\\[^"]+)"', source)
        self.assertGreater(len(paths), 50)
        for value in paths:
            path = ROOT / "Media"
            for part in value.split("\\\\"):
                self.assertIn(part, [entry.name for entry in path.iterdir()], value)
                path /= part
            self.assertTrue(path.is_file(), value)

    def test_hub_visible_layers_do_not_use_clipping_masks(self):
        source = (ROOT / "KstyleUI_ActionBars/Slab.lua").read_text()
        for line in source.splitlines():
            if "Region(" in line:
                self.assertNotIn('"portraitMask"', line)
                self.assertNotIn('"medMinimapMask"', line)


if __name__ == "__main__":
    unittest.main()
