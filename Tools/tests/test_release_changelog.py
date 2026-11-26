"""Tests that .pkgmeta hands the packager one version's notes that never ship, that both packaging jobs write them, that the zip keeps CHANGELOG.md, and that CHANGELOG.md has a section for the version being released, with at least one of Added, Changed or Fixed and an entry under each heading it has."""

import contextlib
import io
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from Tools.release.discord_post import github_notes, main

ROOT = Path(__file__).resolve().parents[2]
CHANGELOG = ROOT / "CHANGELOG.md"
PKGMETA = ROOT / ".pkgmeta"
WORKFLOW = ROOT / ".github/workflows/release.yml"
HEADING = re.compile(r"^## v(\d+\.\d+\.\d+(?:\.\d+)?) \((\d{4}-\d{2}-\d{2})\)$", re.M)
# Two neighbouring releases: each tag, how its section starts and how the other one starts.
NEIGHBOURS = (("v0.2.8.1", "A small fix release.", "The map and bars release"),
              ("v0.2.8", "The map and bars release", "A small fix release."))
# GitHub answers 422 "body is too long (maximum is 125000 characters)" to longer release text.
GITHUB_RELEASE_TEXT_LIMIT = 125000


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
    def test_pkgmeta_gives_the_packager_markdown_notes_that_never_ship(self):
        # The v0.3.5.1 release: the packager sent the whole CHANGELOG.md as the release text and GitHub refused its length.
        lines = PKGMETA.read_text(encoding="utf-8").splitlines()
        start = lines.index("manual-changelog:")
        filename = lines[start + 1].removeprefix("  filename: ")
        self.assertEqual(lines[start + 2], "  markup-type: markdown")
        self.assertNotEqual(filename, "CHANGELOG.md", "give the packager one version's notes, not the whole changelog")
        ignored = [line.strip()[2:] for line in lines if line.strip().startswith("- ")]
        self.assertIn(filename.split("/")[0], ignored, "the packager copies a generated changelog into the zip unless its folder is ignored")

    def test_both_packaging_jobs_write_the_notes_pkgmeta_names(self):
        # The v0.3.5.1 release: without this file the packager uploads the git log as the release text instead.
        target = re.search(r"(?m)^manual-changelog:\n  filename: (\S+)$", PKGMETA.read_text(encoding="utf-8")).group(1)
        *before, _ = WORKFLOW.read_text(encoding="utf-8").split("uses: BigWigsMods/packager@")
        self.assertEqual(len(before), 2, "the check job and the upload job each package once")
        for job, steps in zip(("check", "release"), before):
            with self.subTest(job=job), tempfile.TemporaryDirectory() as folder:
                command = re.search(r"(?m)^        run: (python3 Tools/release/discord_post\.py --section .+)$", steps)
                self.assertIsNotNone(command, "this job packages without this version's notes")
                (Path(folder) / target).parent.mkdir(parents=True, exist_ok=True)
                subprocess.run([os.environ.get("TEST_BASH", "bash"), "-e", "-c", 'python3() { echo "python3 $*"; }\n' + command.group(1)],
                               cwd=folder, env=dict(os.environ, GITHUB_REF_NAME="v1"), check=True)
                written = {path.relative_to(folder).as_posix(): path.read_text(encoding="utf-8") for path in Path(folder).rglob("*") if path.is_file()}
                self.assertEqual(written, {target: "python3 Tools/release/discord_post.py --section v1\n"}, "write the file .pkgmeta names")

    def test_pkgmeta_keeps_the_changelog_in_the_zip(self):
        # Tools/hooks/check-package.sh refuses a zip without the changelog, a rule since the v0.0.5 release.
        ignored = [line.strip()[2:] for line in PKGMETA.read_text(encoding="utf-8").splitlines() if line.strip().startswith("- ")]
        self.assertNotIn("CHANGELOG.md", ignored)

    def test_changelog_has_a_section_for_the_release(self):
        # The release workflow runs this file for the tag before any upload, so a tag without notes never reaches the stores.
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
        # The Discord announcement is one embed built from the summary and the highlights.
        text = CHANGELOG.read_text(encoding="utf-8")
        for match in HEADING.finditer(text):
            section = re.split(r"^## ", text[match.end():], maxsplit=1, flags=re.M)[0].strip()
            with self.subTest(version=match.group(1)):
                check_readable_section(section)

    def test_readability_guard_rejects_the_old_wall_of_text(self):
        # The v0.2.8 world map bullet, which no announcement could carry whole.
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
        # The data bar highlight and its upgrade note, which the announcement cut off at 120 characters.
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
        # The announcement carries 120 characters whole, so the guard allows exactly that many.
        line = "x" * 120
        check_readable_section("Summary.\n\nHighlights:\n\n- " + line + "\n\n### Upgrading\n\n- " + line)

    def test_changelog_ends_with_how_to_install(self):
        # The zip's changelog is where a player who downloads it by hand reads how to install it and the icon pack.
        text = CHANGELOG.read_text(encoding="utf-8")
        self.assertIn("\n## How to install\n", text)
        self.assertIn("https://github.com/korallis/KstyleUI/blob/main/docs/icons.md", text)

    def test_packager_text_is_one_version_without_the_store_links(self):
        # The v0.3.5.1 release: the text goes to CurseForge, Wago and GitHub, so it is one version and names no store.
        for tag, start, other in NEIGHBOURS:
            with self.subTest(tag=tag):
                with patch("sys.argv", ["discord_post.py", "--section", tag]), contextlib.redirect_stdout(io.StringIO()) as output:
                    main()
                section = output.getvalue()
                self.assertTrue(section.startswith(start), section[:80])
                self.assertNotIn(other, section)
                self.assertNotRegex(section, r"(?m)^#{1,2} ")
                self.assertNotIn("curseforge", section.lower())
                self.assertRegex(section, r"\S\n\Z")

    def test_every_release_text_fits_a_github_release(self):
        # The v0.3.5.1 release: GitHub refused the release, so the zip and release.json never reached it.
        text = CHANGELOG.read_text(encoding="utf-8")
        versions = [match.group(1) for match in HEADING.finditer(text)]
        self.assertIn(release_version(text), versions)
        for version in versions:
            with self.subTest(version=version):
                self.assertLessEqual(len(github_notes(text, "v" + version)), GITHUB_RELEASE_TEXT_LIMIT,
                                     "split this release's notes: GitHub refuses the release")

    def test_github_release_body_is_one_version_and_the_store_links(self):
        # The release page shows one version and where to download it, not every release so far.
        text = CHANGELOG.read_text(encoding="utf-8")
        links = ("**Download:** [CurseForge](https://www.curseforge.com/wow/addons/kstyleui)"
                 " · [Wago](https://addons.wago.io/addons/kstyleui)\n")
        for tag, start, other in NEIGHBOURS:
            with self.subTest(tag=tag):
                notes = github_notes(text, tag)
                self.assertTrue(notes.startswith(start), notes[:80])
                self.assertTrue(notes.endswith("\n\n" + links), notes[-200:])
                self.assertNotIn(other, notes)
                self.assertNotRegex(notes, r"(?m)^#{1,2} ")


if __name__ == "__main__":
    unittest.main()
