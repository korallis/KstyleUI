"""Tests for Tools/hooks/toc_files.py and Tools/hooks/check_toc.py."""

import contextlib
import io
import re
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "Tools" / "hooks"))

import check_toc  # noqa: E402
from toc_files import toc_files  # noqa: E402

FIXTURE = REPO / "Tools" / "regression" / "fixtures" / "toc"


class TocFilesTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, rel, data):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def check(self, root):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = check_toc.main(["--root", str(root)])
        return code, out.getvalue()

    def test_lua_files_in_load_order(self):
        files = [f for f in toc_files(FIXTURE) if f.endswith(".lua")]
        self.assertEqual(
            files,
            [(FIXTURE / rel).as_posix() for rel in ("Core/A.lua", "Core/Sub/B.lua", "Fix_Mod/C.lua")],
        )

    def test_lists_xml_files_before_their_contents(self):
        rels = [Path(f).relative_to(FIXTURE).as_posix() for f in toc_files(FIXTURE)]
        self.assertEqual(
            rels,
            ["Core/Core.xml", "Core/A.lua", "Core/Sub/Sub.xml", "Core/Sub/B.lua", "Fix_Mod/Mod.xml", "Fix_Mod/C.lua"],
        )

    def test_explicit_module_glob(self):
        files = toc_files(FIXTURE, "Fix_*")
        self.assertTrue(files[-1].endswith("Fix_Mod/C.lua"))

    def test_reads_crlf_and_skips_comments(self):
        self.write("Add.toc", b"## Title: Add\r\n\r\nLoad.xml\r\n")
        self.write(
            "Load.xml",
            b'<Ui>\r\n<!-- <Script file="Old.lua"/> -->\r\n<Script file="New.lua"/>\r\n'
            b'<Texture file="Interface\\Buttons\\WHITE8X8"/>\r\n</Ui>\r\n',
        )
        self.assertEqual(toc_files(self.root), [(self.root / rel).as_posix() for rel in ("Load.xml", "New.lua")])

    def test_check_toc_passes_fixture(self):
        code, out = self.check(FIXTURE)
        self.assertEqual((code, out), (0, ""))

    def test_locale_conditions_preserve_paths_and_check_all_locales(self):
        self.write("Add.toc", b"Core\\deDE.lua [AllowLoadTextLocale deDE]\r\n[AllowLoadTextLocale: frFR] Core\\frFR.lua\r\n")
        self.write("Core/deDE.lua", b"return 1\r\n")
        self.assertEqual(toc_files(self.root), [(self.root / f"Core/{locale}.lua").as_posix() for locale in ("deDE", "frFR")])
        self.assertEqual(self.check(self.root), (1, "missing: Core/frFR.lua\n"))

    def test_client_locale_conditions_keep_the_spanish_alias(self):
        toc = (REPO / "KstyleUI.toc").read_text(encoding="ascii")
        entries = re.findall(r"^(Core\\Locales\\\w+\.lua) \[AllowLoadTextLocale (\w+)\]$", toc, re.M)
        expected = {"deDE": "deDE", "frFR": "frFR", "esES": "esES", "esMX": "esES", "zhCN": "zhCN"}
        self.assertEqual(dict((locale, Path(path.replace("\\", "/")).stem) for path, locale in entries), expected)
        self.assertLess(toc.index("Core\\Locale.lua"), toc.index("Core\\Locales\\"))
        self.assertNotIn("Locales\\Locales.xml", (REPO / "Core/Core.xml").read_text(encoding="ascii"))

    def test_check_toc_reports_missing(self):
        self.write("Add.toc", b"Core\\Gone.lua\r\n")
        code, out = self.check(self.root)
        self.assertEqual(code, 1)
        self.assertIn("missing: Core/Gone.lua", out)

    def test_check_toc_reports_case(self):
        self.write("Add.toc", b"core\\a.lua\r\n")
        self.write("Core/A.lua", b"return 1\r\n")
        code, out = self.check(self.root)
        self.assertEqual(code, 1)
        self.assertIn("case: core/a.lua != Core/A.lua", out)


if __name__ == "__main__":
    unittest.main()
