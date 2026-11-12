"""Tests that .pkgmeta hands CHANGELOG.md to the packager, that the zip keeps it, and that CHANGELOG.md has a section for the version being released."""

import os
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHANGELOG = ROOT / "CHANGELOG.md"
PKGMETA = ROOT / ".pkgmeta"
HEADING = re.compile(r"^## v(\d+\.\d+\.\d+) \((\d{4}-\d{2}-\d{2})\)$", re.M)


def release_version(text):
    ref = os.environ.get("GITHUB_REF_NAME", "")
    if re.fullmatch(r"v\d+\.\d+\.\d+", ref):
        return ref[1:]
    return HEADING.search(text).group(1)


class ReleaseChangelogTests(unittest.TestCase):
    def test_pkgmeta_gives_the_changelog_to_the_packager(self):
        lines = PKGMETA.read_text(encoding="utf-8").splitlines()
        start = lines.index("manual-changelog:")
        self.assertEqual(lines[start + 1:start + 3], ["  filename: CHANGELOG.md", "  markup-type: markdown"])

    def test_pkgmeta_keeps_the_changelog_in_the_zip(self):
        ignored = [line.strip()[2:] for line in PKGMETA.read_text(encoding="utf-8").splitlines() if line.strip().startswith("- ")]
        self.assertNotIn("CHANGELOG.md", ignored)

    def test_changelog_has_a_section_for_the_release(self):
        text = CHANGELOG.read_text(encoding="utf-8")
        version = release_version(text)
        match = re.search(r"^## v%s \(\d{4}-\d{2}-\d{2}\)$" % re.escape(version), text, re.M)
        self.assertIsNotNone(match, "CHANGELOG.md has no section for v%s" % version)
        section = text[match.end():]
        end = re.search(r"^## ", section, re.M)
        section = section[:end.start()] if end else section
        for group in ("### Added", "### Changed", "### Fixed"):
            self.assertIn(group, section)

    def test_changelog_ends_with_how_to_install(self):
        text = CHANGELOG.read_text(encoding="utf-8")
        self.assertIn("\n## How to install\n", text)
        self.assertIn("https://github.com/korallis/KstyleUI/blob/main/docs/icons.md", text)


if __name__ == "__main__":
    unittest.main()
