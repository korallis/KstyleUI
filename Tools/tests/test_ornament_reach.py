"""The shipped forged ornaments are exactly the reachable ones: the files, the addon's table, the manifest and the reach table agree."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "Media" / "Textures" / "ForgedOrnaments"
CAP_BYTES = 1_700_000


class OrnamentReachTest(unittest.TestCase):
    def test_every_request_the_matrix_makes_resolves_to_a_shipped_file(self):
        """Tools/media/ornament_reach.json lists every piece drawn across the nine screens, the whole Interface size
        slider at its step, Subtle and Full, every HUD preset and target class, the galleries and the nameplate scales.
        The addon resolves a piece only through OrnamentAssets, so each listed piece must be in that table and on disk,
        and nothing unreachable may ship."""
        reach = json.loads((ROOT / "Tools" / "media" / "ornament_reach.json").read_text())
        table = set(re.findall(r"^\t(\w+) = \{", (ROOT / "Core" / "Widgets" / "OrnamentData.lua").read_text(), re.M))
        files = {path.stem for path in FOLDER.glob("*.png")}
        manifest = set(json.loads((FOLDER / "manifest.json").read_text())["assets"])
        self.assertEqual(set(reach) - files, set(), "a reachable piece has no file")
        self.assertEqual(table, files, "OrnamentAssets and the files on disk differ")
        self.assertEqual(manifest, files, "the manifest and the files on disk differ")
        self.assertEqual(files - set(reach), set(), "an unreachable piece ships")
        for name, case in reach.items():
            self.assertTrue(case, name + " names the first matrix case that draws it")

    def test_the_ornament_media_stays_under_the_cap(self):
        """The Captain capped the ornament media at 1.7 MB on 2026-11-11 (docs/ORNAMENT-SPEC.md): the pieces ship as
        lossless RGBA at their native sizes, so growth past the cap needs a new ruling, not a quieter encoding."""
        total = sum(path.stat().st_size for path in FOLDER.iterdir() if path.is_file())
        self.assertLessEqual(total, CAP_BYTES, "the ornament media is %d B, over the %d B cap" % (total, CAP_BYTES))


if __name__ == "__main__":
    unittest.main()
