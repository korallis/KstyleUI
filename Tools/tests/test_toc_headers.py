"""Tests that every shipped TOC carries the headers addon sites and the packager read, and that the soft dependencies are declared, not embedded."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOCS = [ROOT / "KstyleUI.toc"] + sorted(ROOT.glob("KstyleUI_*/KstyleUI_*.toc"))
OPTIONAL = {
    "KstyleUI.toc": "LibSharedMedia-3.0",
    "KstyleUI_Minimap.toc": "LibDBIcon-1.0",
    "KstyleUI_Skins.toc": "RXPGuides",
}


def headers(path):
    found = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"## ([A-Za-z-]+): ?(.*)$", line)
        if match:
            found[match.group(1)] = match.group(2).strip()
    return found


class TocHeaderTests(unittest.TestCase):
    def test_every_toc_has_the_conventional_headers(self):
        self.assertGreater(len(TOCS), 10)
        for toc in TOCS:
            with self.subTest(toc=toc.name):
                found = headers(toc)
                for key in ("Interface", "Title", "Notes", "Author", "Category", "X-Website", "X-License"):
                    self.assertTrue(found.get(key), key)
                self.assertEqual(found["Version"], "@project-version@")
                self.assertEqual(found["X-Website"], "https://github.com/korallis/KstyleUI")

    def test_no_store_ids_until_the_projects_exist(self):
        for toc in TOCS:
            with self.subTest(toc=toc.name):
                self.assertFalse({"X-Curse-Project-ID", "X-Wago-ID"} & set(headers(toc)))

    def test_soft_dependencies_are_declared_not_embedded(self):
        for toc in TOCS:
            with self.subTest(toc=toc.name):
                self.assertEqual(headers(toc).get("OptionalDeps"), OPTIONAL.get(toc.name))
        self.assertFalse((ROOT / "Libs").exists())
        self.assertNotIn("externals", (ROOT / ".pkgmeta").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
