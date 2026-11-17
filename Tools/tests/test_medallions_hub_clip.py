"""Every shipped crest and bloom stays inside the circular hub opening, including pulses."""
import math
import re
import unittest
from functools import cache
from pathlib import Path

from Tools.media.make_media import decode_png

ROOT = Path(__file__).resolve().parents[2]


@cache
def alpha(path):
    width, height, pixels = decode_png(path.read_bytes())
    return width, height, pixels[3::4]


def sample(pixels, width, height, x, y):
    left, top = math.floor(x), math.floor(y)
    dx, dy = x - left, y - top
    return sum(pixels[py * width + px] * wx * wy
               for px, wx in ((left, 1 - dx), (left + 1, dx))
               for py, wy in ((top, 1 - dy), (top + 1, dy))
               if 0 <= px < width and 0 <= py < height)


class HubClipTest(unittest.TestCase):
    def test_all_52_crest_and_glow_alphas_stay_inside_the_opening(self):
        source = (ROOT / "KstyleUI_ActionBars/Slab.lua").read_text()
        ring, canvas, opening = map(int, re.search(
            r"local RING, CREST, OPENING = (\d+), (\d+), (\d+)", source).groups())
        self.assertEqual((ring, canvas, opening), (150, 150, 118))
        token = re.search(r'Tokens.Texture\("(\w+)"\)', source[source.index("local function OpeningMask"):]).group(1)
        tokens = (ROOT / "Core/Tokens.lua").read_text()
        path = re.search(r'\b' + token + r' = \{ file = "([^"]+)"', tokens).group(1)
        mw, mh, mask = alpha(ROOT / "Media" / path.replace("\\\\", "/"))
        support = [(x, y) for y in range(mh) for x in range(mw) if mask[y * mw + x]]
        outside = [(x, y) for x, y in support
                   if math.hypot((x + .5) / mw - .5, (y + .5) / mh - .5) * opening >= opening / 2]
        crests = sorted((ROOT / "Media/Textures/Medallions/Crests").glob("*.png"))
        crests = [p for p in crests if not p.stem.endswith(("_glow", "_metal"))]
        self.assertEqual(len(crests), 52)
        for crest in crests:
            for suffix, share in (("", 1), ("", 1.05), ("_glow", 1.08)):
                path = crest.with_stem(crest.stem + suffix)
                with self.subTest(crest=path.name, share=share):
                    width, height, pixels = alpha(path)
                    self.assertEqual((width, height), (512, 512), "rebake original crests at 512 before drawing the pulsed 4K hub")
                    scale = opening / (canvas * share) * width / mw
                    offset = (width - mw * scale) / 2

                    def visible(point):
                        x, y = point
                        return sample(pixels, width, height, (x + .5) * scale + offset - .5,
                                      (y + .5) * scale + offset - .5) > 0

                    self.assertTrue(any(map(visible, support)), path.name)
                    self.assertFalse(any(map(visible, outside)), f"{path.name}: use a circular mask contained in the opening")
                    self.assertLess(opening, ring, "the clipped opening must stay inside the ring")


if __name__ == "__main__":
    unittest.main()
