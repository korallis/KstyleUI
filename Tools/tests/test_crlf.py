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
