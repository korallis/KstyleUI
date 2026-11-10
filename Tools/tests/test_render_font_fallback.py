"""The canvas fallback quotes its numbered family so the requested size parses."""

import json
import unittest
from pathlib import Path


class FontFallbackTest(unittest.TestCase):
    def test_numbered_family_is_quoted_in_the_canvas_font_shorthand(self):
        source = (Path(__file__).resolve().parents[1] / "render" / "render.js").read_text()
        family = json.dumps('"Source Sans 3", sans-serif')
        self.assertIn("family = " + family + ";", source)
        self.assertIn('ctx.font = sizePx.toFixed(2) + "px " + family;', source)


if __name__ == "__main__":
    unittest.main()
