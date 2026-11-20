"""Tests that .pkgmeta hands CHANGELOG.md to the packager, that the zip keeps it, and that CHANGELOG.md has a section for the version being released, with at least one of Added, Changed or Fixed and an entry under each heading it has."""

import os
import re
import unittest
from pathlib import Path

from Tools.release.discord_post import github_notes

ROOT = Path(__file__).resolve().parents[2]
CHANGELOG = ROOT / "CHANGELOG.md"
PKGMETA = ROOT / ".pkgmeta"
HEADING = re.compile(r"^## v(\d+\.\d+\.\d+(?:\.\d+)?) \((\d{4}-\d{2}-\d{2})\)$", re.M)


def release_version(text):
    ref = os.environ.get("GITHUB_REF_NAME", "")
    if re.fullmatch(r"v\d+\.\d+\.\d+(?:\.\d+)?", ref):
        return ref[1:]
    return HEADING.search(text).group(1)


def check_readable_section(section):
    fix = "Add one summary paragraph, then Highlights: with 1-6 short bullets; shorten the bullet or move detail to docs/RELEASE_NOTES.md"
    intro = section.split("### ", 1)[0].strip()
    summary, separator, highlights = intro.partition("\n\nHighlights:")
    assert separator and summary and "\n\n" not in summary and not summary.startswith(("- ", "#")), fix
    bullets = re.findall(r"^- (.+)$", highlights, re.M)
    assert 1 <= len(bullets) <= 6, fix
    for body in [highlights] + re.findall(r"^### Upgrading\n([\s\S]*?)(?=^### |\Z)", section, re.M):
        for line in re.findall(r"^- (.+)$", body, re.M):
            assert len(line) <= 120 and "…" not in line, (
                "shorten this highlight to 120 characters or fewer; move the detail to Added/Changed/Fixed: " + line)
    for name, body in re.findall(r"^### (Added|Changed|Fixed)\n([\s\S]*?)(?=^### |\Z)", section, re.M):
        bullets = re.findall(r"^\s*- (.+)$", body, re.M)
        assert bullets and all(len(line) <= 220 for line in bullets), name + ": " + fix


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
        groups = re.split(r"^### (\w+)$", section, flags=re.M)
        found = dict(zip(groups[1::2], groups[2::2]))
        self.assertTrue(set(found) & {"Added", "Changed", "Fixed"}, "the v%s section has none of ### Added, ### Changed or ### Fixed" % version)
        for group, body in found.items():
            self.assertTrue(re.search(r"^- \S", body, re.M), "### %s in v%s has no entry" % (group, version))

    def test_every_release_is_readable(self):
        text = CHANGELOG.read_text(encoding="utf-8")
        for match in HEADING.finditer(text):
            section = re.split(r"^## ", text[match.end():], maxsplit=1, flags=re.M)[0].strip()
            with self.subTest(version=match.group(1)):
                check_readable_section(section)

    def test_readability_guard_rejects_the_old_wall_of_text(self):
        old_bullet = ("The world map zooms smoothly with the mouse wheel and remembers your zoom and pan for each map, even after a reload. "
                      "Wheel out again at the smallest zoom to open the parent map, or in again over a zone to open it; in combat the wheel only zooms the current map. "
                      "Smooth zoom, Remember zoom and Wheel between maps are each on by default under Window Skins > World map.")
        with self.assertRaisesRegex(AssertionError, "shorten the bullet or move detail to docs/RELEASE_NOTES.md"):
            check_readable_section("Summary.\n\nHighlights:\n\n- Short highlight.\n\n### Added\n\n- " + old_bullet)
        for section in ("### Fixed\n\n- Fix.", "Summary.\n\nAnother paragraph.\n\nHighlights:\n\n- Fix.",
                        "Summary.\n\nHighlights:\n\n" + "- Fix.\n" * 7):
            with self.assertRaises(AssertionError):
                check_readable_section(section)

    def test_announcement_guard_rejects_the_old_cut_off_highlight_and_upgrade(self):
        highlight = ("A data bar across the top in Frames and Orbs, and a dock under the slab in Medallions, "
                     "with your choice of readouts and a toggleable micro menu.")
        upgrade = ("In Medallions your readouts move into the dock under the slab; "
                   "a saved readout position is not used while the dock is on.")
        for line in (highlight, upgrade, "A cut-off announcement…"):
            for heading in ("Highlights:", "### Upgrading"):
                section = "Summary.\n\nHighlights:\n\n- Short highlight.\n\n### Fixed\n\n- Fix."
                section = (section.replace("Short highlight.", line) if heading == "Highlights:" else
                           section + "\n\n" + heading + "\n\n- " + line)
                with self.subTest(heading=heading, line=line):
                    with self.assertRaisesRegex(AssertionError, "shorten this highlight to 120 characters or fewer"):
                        check_readable_section(section)

    def test_announcement_guard_accepts_120_characters(self):
        line = "x" * 120
        check_readable_section("Summary.\n\nHighlights:\n\n- " + line + "\n\n### Upgrading\n\n- " + line)

    def test_changelog_ends_with_how_to_install(self):
        text = CHANGELOG.read_text(encoding="utf-8")
        self.assertIn("\n## How to install\n", text)
        self.assertIn("https://github.com/korallis/KstyleUI/blob/main/docs/icons.md", text)

    def test_github_release_body_is_one_version_and_the_store_links(self):
        text = CHANGELOG.read_text(encoding="utf-8")
        links = ("**Download:** [CurseForge](https://www.curseforge.com/wow/addons/kstyleui)"
                 " · [Wago](https://addons.wago.io/addons/kstyleui)\n")
        for tag, start, other in (("v0.2.8.1", "A small fix release.", "The map and bars release"),
                                  ("v0.2.8", "The map and bars release", "A small fix release.")):
            with self.subTest(tag=tag):
                notes = github_notes(text, tag)
                self.assertTrue(notes.startswith(start), notes[:80])
                self.assertTrue(notes.endswith("\n\n" + links), notes[-200:])
                self.assertNotIn(other, notes)
                self.assertNotRegex(notes, r"(?m)^#{1,2} ")


if __name__ == "__main__":
    unittest.main()
