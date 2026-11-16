"""Tests for Tools/dev/crlf.py."""

import contextlib
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "dev"))

import crlf  # noqa: E402


class CrlfTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, rel, data):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def run_main(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = crlf.main(["--root", str(self.root), *args])
        return code, out.getvalue()

    def test_converts_lf_to_crlf(self):
        path = self.write("Core/A.lua", b"a\nb\n")
        code, _ = self.run_main(str(path))
        self.assertEqual(code, 0)
        self.assertEqual(path.read_bytes(), b"a\r\nb\r\n")

    def test_leaves_crlf_unchanged(self):
        path = self.write("KstyleUI.toc", b"## Title: x\r\nCore\\Core.xml\r\n")
        before = path.stat().st_mtime_ns
        self.run_main(str(path))
        self.assertEqual(path.read_bytes(), b"## Title: x\r\nCore\\Core.xml\r\n")
        self.assertEqual(path.stat().st_mtime_ns, before)

    def test_does_not_double_convert(self):
        path = self.write("Core/Core.xml", b"a\r\nb\nc\r\n")
        self.run_main(str(path))
        self.assertEqual(path.read_bytes(), b"a\r\nb\r\nc\r\n")

    def test_skips_tools_and_docs(self):
        tools = self.write("Tools/x.lua", b"a\n")
        docs = self.write("docs/x.xml", b"a\n")
        self.run_main(str(tools), str(docs))
        self.assertEqual(tools.read_bytes(), b"a\n")
        self.assertEqual(docs.read_bytes(), b"a\n")

    def test_skips_other_extensions(self):
        readme = self.write("README.md", b"a\n")
        self.run_main(str(readme))
        self.assertEqual(readme.read_bytes(), b"a\n")

    def test_check_mode_exits_1_and_lists_files(self):
        bad = self.write("Core/Bad.lua", b"a\n")
        good = self.write("Core/Good.lua", b"a\r\n")
        code, out = self.run_main("--check", str(bad), str(good))
        self.assertEqual(code, 1)
        self.assertIn("Core/Bad.lua", out)
        self.assertNotIn("Core/Good.lua", out)
        self.assertEqual(bad.read_bytes(), b"a\n")

    def test_check_mode_exits_0_when_clean(self):
        good = self.write("Core/Good.lua", b"a\r\n")
        code, out = self.run_main("--check", str(good))
        self.assertEqual(code, 0)
        self.assertEqual(out, "")

    def test_check_rejects_crlf_tools_and_docs_text_and_names_the_writer_fix(self):
        for rel in ("Tools/new.py", "docs/new.md", "Tools/new.json", "Tools/new.lua",
                    "Tools/icons/new.py", "Tools/render/new.py", "Tools/icons/setB/PROVENANCE.md", "Media/PROVENANCE.md"):
            with self.subTest(rel=rel):
                path = self.write(rel, b"text\r\n")
                code, out = self.run_main("--check", str(path))
                self.assertEqual(code, 1)
                self.assertIn(rel, out)
                self.assertIn('newline="\\n"', out)
                self.assertEqual(path.read_bytes(), b"text\r\n")

    def test_check_accepts_lf_text_and_ignores_binary_assets(self):
        paths = [self.write("Tools/new.py", b"text\n"), self.write("docs/new.md", b"text\n"),
                 self.write("Tools/image.png", b"\x89PNG\r\n\x1a\n"), self.write("Tools/image.dat", b"\0\r\n")]
        self.assertEqual(self.run_main("--check", *(str(path) for path in paths)), (0, ""))

    def test_check_rejects_non_utf8_tools_and_docs_and_names_the_fix(self):
        for rel in ("Tools/regression/README.md", "docs/bad.md", "Tools/bad.py"):
            with self.subTest(rel=rel):
                path = self.write(rel, b"calibration \x97 multiplication \xd7\n")
                code, out = self.run_main("--check", str(path))
                self.assertEqual(code, 1, "Reject non-UTF-8 text; save Tools/docs with encoding='utf-8'")
                self.assertIn(rel, out)
                self.assertIn('encoding="utf-8"', out)
                self.assertEqual(path.read_bytes(), b"calibration \x97 multiplication \xd7\n")

    def test_check_accepts_utf8_text(self):
        path = self.write("docs/good.md", "calibration \u2014 multiplication \u00d7\n".encode("utf-8"))
        self.assertEqual(self.run_main("--check", str(path)), (0, ""))

    def test_no_paths_checks_untracked_tools_text(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.write("Tools/New.py", b"text\r\n")
        code, out = self.run_main("--check")
        self.assertEqual(code, 1)
        self.assertIn("Tools/New.py", out)

    def test_check_includes_committed_tools_text(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        for rel in ("Tools/Old.py", "Media/PROVENANCE.md"):
            self.write(rel, b"text\r\n")
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.root), "-c", "user.name=t", "-c", "user.email=t@example.com",
                        "commit", "-qm", "fixture"], check=True)
        code, out = self.run_main("--check")
        self.assertEqual(code, 1)
        self.assertIn("Tools/Old.py", out)
        self.assertIn("Media/PROVENANCE.md", out)

    def test_csv_allows_embedded_crlf_but_requires_lf_record_endings(self):
        path = self.write("Tools/data.csv", b'ID,Text\n1,"a,\r\nb"\n')
        self.assertEqual(self.run_main("--check", str(path)), (0, ""))
        path.write_bytes(b'ID,Text\r\n1,"a,\r\nb"\r\n')
        code, out = self.run_main("--check", str(path))
        self.assertEqual(code, 1)
        self.assertIn("Tools/data.csv", out)

    def test_no_paths_uses_git_status(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        changed = self.write("Core/New.lua", b"a\n")
        tools = self.write("Tools/New.lua", b"a\n")
        code, _ = self.run_main()
        self.assertEqual(code, 0)
        self.assertEqual(changed.read_bytes(), b"a\r\n")
        self.assertEqual(tools.read_bytes(), b"a\n")


if __name__ == "__main__":
    unittest.main()
