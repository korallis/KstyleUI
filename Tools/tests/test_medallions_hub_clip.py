"""Every shipped crest and bloom stays inside the circular hub opening, including pulses."""
import math
import re
import unittest
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]


class HubClipTest(unittest.TestCase):
    def test_all_52_crest_and_glow_alphas_stay_inside_the_opening(self):
        source = (ROOT / "KstyleUI_ActionBars/Slab.lua").read_text()
        ring, canvas, opening = map(int, re.search(
            r"local RING, CREST, OPENING = (\d+), (\d+), (\d+)", source).groups())
        self.assertEqual((ring, canvas, opening), (150, 150, 118))
        token = re.search(r'Tokens.Texture\("(\w+)"\)', source[source.index("local function OpeningMask"):]).group(1)
        tokens = (ROOT / "Core/Tokens.lua").read_text()
        path = re.search(r'\b' + token + r' = \{ file = "([^"]+)"', tokens).group(1)
        with Image.open(ROOT / "Media" / path.replace("\\\\", "/")) as image:
            mask = image.getchannel("A")
        crests = sorted((ROOT / "Media/Textures/Medallions/Crests").glob("*.png"))
        crests = [p for p in crests if not p.stem.endswith(("_glow", "_metal"))]
        self.assertEqual(len(crests), 52)
        for crest in crests:
            for suffix, share in (("", 1), ("", 1.05), ("_glow", 1.08)):
                path = crest.with_stem(crest.stem + suffix)
                with self.subTest(crest=path.name, share=share), Image.open(path) as image:
                    self.assertEqual(image.size, (512, 512), "rebake original crests at 512 before drawing the pulsed 4K hub")
                    alpha = image.getchannel("A")
                scale = opening / (canvas * share) * alpha.width / mask.width
                offset = (alpha.width - mask.width * scale) / 2
                fitted = alpha.transform(mask.size, Image.Transform.AFFINE,
                                         (scale, 0, offset, 0, scale, offset), Image.Resampling.BILINEAR)
                clipped = ImageChops.multiply(fitted, mask)
                self.assertIsNotNone(clipped.getbbox(), path.name)
                reach = max(math.hypot((x + .5) / mask.width - .5, (y + .5) / mask.height - .5) * opening
                            for y in range(mask.height) for x in range(mask.width) if clipped.getpixel((x, y)))
                self.assertLess(reach, opening / 2, f"{path.name}: use a circular mask contained in the opening")
                self.assertLess(reach, ring / 2, f"{path.name}: no crest or glow may reach the ring")


if __name__ == "__main__":
    unittest.main()
