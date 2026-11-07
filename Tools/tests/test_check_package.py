"""Tests for Tools/hooks/check-package.sh against a fake addon tree and hand-made zips."""

import os
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "hooks" / "check-package.sh"

SOURCE = {
    "KstyleUI.toc": "## Interface: 16001\r\n\r\nLibs\\Lib.lua\r\nCore\\Core.xml\r\n",
    "Core/Core.xml": '<Ui>\r\n<Script file="Init.lua"/>\r\n</Ui>\r\n',
    "Core/Init.lua": "-- Init.lua: x.\r\n",
    "Libs/Lib.lua": "-- Lib.lua: x.\r\n",
    "KstyleUI_Foo/KstyleUI_Foo.toc": "## Interface: 16001\r\n\r\nFoo.xml\r\n",
    "KstyleUI_Foo/Foo.xml": '<Ui>\r\n<Script file="Foo.lua"/>\r\n</Ui>\r\n',
    "KstyleUI_Foo/Foo.lua": "-- Foo.lua: x.\r\n",
    "Tools/x.py": "print(1)\n",
}

GOOD = [
    "KstyleUI/",
    "KstyleUI/KstyleUI.toc",
    "KstyleUI/CHANGELOG.md",
    "KstyleUI/Core/",
    "KstyleUI/Core/Core.xml",
    "KstyleUI/Core/Init.lua",
    "KstyleUI/Libs/Lib.lua",
    "KstyleUI_Foo/",
    "KstyleUI_Foo/KstyleUI_Foo.toc",
    "KstyleUI_Foo/Foo.xml",
    "KstyleUI_Foo/Foo.lua",
]


class CheckPackageTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        for rel, text in SOURCE.items():
            path = self.root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(text.encode())

    def tearDown(self):
        self._tmp.cleanup()

    def make_zip(self, entries, name="KstyleUI-v1.zip", folder=".release"):
        directory = self.root / folder
        directory.mkdir(exist_ok=True)
        with zipfile.ZipFile(directory / name, "w") as archive:
            for entry in entries:
                archive.writestr(entry, "" if entry.endswith("/") else "x")

    def run_check(self, *args):
        bash = os.environ.get("TEST_BASH", "bash")
        return subprocess.run([bash, str(SCRIPT), *args], cwd=self.root, capture_output=True, text=True)

    def assertPasses(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assertFails(self, result, *needles):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        for needle in needles:
            self.assertIn(needle, result.stdout + result.stderr)

    def test_good_package_passes(self):
        self.make_zip(GOOD)
        self.assertPasses(self.run_check())

    def test_release_dir_argument(self):
        self.make_zip(GOOD, folder="out")
        self.assertPasses(self.run_check("out"))

    def test_no_zip_fails(self):
        (self.root / ".release").mkdir()
        self.assertFails(self.run_check(), "found 0")

    def test_two_zips_fail(self):
        self.make_zip(GOOD)
        self.make_zip(GOOD, name="KstyleUI-v1-nolib.zip")
        self.assertFails(self.run_check(), "found 2")

    def test_missing_release_dir_exits_2(self):
        self.assertEqual(self.run_check().returncode, 2)

    def test_missing_loaded_file_fails(self):
        self.make_zip([e for e in GOOD if e != "KstyleUI/Core/Init.lua"])
        self.assertFails(self.run_check(), "KstyleUI/Core/Init.lua")

    def test_missing_library_fails(self):
        self.make_zip([e for e in GOOD if e != "KstyleUI/Libs/Lib.lua"])
        self.assertFails(self.run_check(), "KstyleUI/Libs/Lib.lua")

    def test_missing_core_toc_fails(self):
        self.make_zip([e for e in GOOD if e != "KstyleUI/KstyleUI.toc"])
        self.assertFails(self.run_check(), "KstyleUI/KstyleUI.toc")

    def test_missing_module_toc_fails(self):
        self.make_zip([e for e in GOOD if e != "KstyleUI_Foo/KstyleUI_Foo.toc"])
        self.assertFails(self.run_check(), "KstyleUI_Foo/KstyleUI_Foo.toc")

    def test_module_left_inside_the_core_folder_fails(self):
        entries = [e.replace("KstyleUI_Foo/", "KstyleUI/KstyleUI_Foo/") for e in GOOD]
        self.make_zip(entries)
        self.assertFails(self.run_check(), "KstyleUI_Foo/Foo.lua")

    def test_case_mismatch_fails(self):
        self.make_zip([e.replace("Core/Init.lua", "Core/init.lua") for e in GOOD])
        self.assertFails(self.run_check(), "KstyleUI/Core/Init.lua")

    def test_top_level_file_fails(self):
        self.make_zip(GOOD + ["README.md"])
        self.assertFails(self.run_check(), "README.md")

    def test_foreign_top_level_folder_fails(self):
        self.make_zip(GOOD + ["Other/x.lua"])
        self.assertFails(self.run_check(), "Other/")

    def test_dev_folders_fail(self):
        for folder in ("Tools", "docs", "research_notes", "reports", ".github"):
            with self.subTest(folder=folder):
                self.make_zip(GOOD + [f"KstyleUI/{folder}/x.txt"])
                self.assertFails(self.run_check(), f"KstyleUI/{folder}/x.txt")

    def test_dev_files_fail(self):
        for name in (".luacheckrc", ".pre-commit-config.yaml", ".pkgmeta", "AGENTS.md"):
            with self.subTest(name=name):
                self.make_zip(GOOD + [f"KstyleUI/{name}"])
                self.assertFails(self.run_check(), f"KstyleUI/{name}")

    def test_dev_folder_inside_a_module_fails(self):
        self.make_zip(GOOD + ["KstyleUI_Foo/Tools/x.lua"])
        self.assertFails(self.run_check(), "KstyleUI_Foo/Tools/x.lua")

    def test_reports_every_problem(self):
        self.make_zip([e for e in GOOD if e != "KstyleUI/Core/Init.lua"] + ["KstyleUI/docs/a.md"])
        self.assertFails(self.run_check(), "KstyleUI/Core/Init.lua", "KstyleUI/docs/a.md")


if __name__ == "__main__":
    unittest.main()
