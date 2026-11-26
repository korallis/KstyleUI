"""Tests for Tools/tests/run_suite.py: which test files a change runs, and that one failing file fails the run.

Intent: the approved faster-gate plan. The Python suite runs one process per file, a tool's own tests run when
the tool changed, and the release gate runs every file.
"""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import run_suite

HERE = Path(__file__).resolve().parent

NAMES = ["test_check_pr.py", "test_crlf.py", "test_fonts.py", "test_gate.py"]


class SelectTest(unittest.TestCase):
    def test_a_tool_test_runs_only_when_its_tool_or_its_own_file_changed(self):
        self.assertEqual(run_suite.select(NAMES, {"Core/Init.lua": "M"}), (["test_fonts.py"], ["test_check_pr.py", "test_crlf.py", "test_gate.py"]))
        self.assertEqual(run_suite.select(NAMES, {"Tools/hooks/check-pr.sh": "M"})[0], ["test_check_pr.py", "test_fonts.py"])
        self.assertEqual(run_suite.select(NAMES, {"scripts/gate.sh": "M"})[0], ["test_fonts.py", "test_gate.py"])
        self.assertEqual(run_suite.select(NAMES, {"Tools/tests/test_crlf.py": "M"})[0], ["test_crlf.py", "test_fonts.py"])

    def test_every_file_runs_with_no_base_and_when_a_suite_helper_changed(self):
        self.assertEqual(run_suite.select(NAMES, None), (NAMES, []))
        self.assertEqual(run_suite.select(NAMES, {"Tools/tests/run_suite.py": "M"}), (NAMES, []))

    def test_every_tool_test_and_wide_file_names_a_file_in_the_suite(self):
        self.assertEqual([name for name in (*run_suite.TOOL_TESTS, *run_suite.WIDE) if not (HERE / name).is_file()], [])


class RunTest(unittest.TestCase):
    def run_suite(self, files, *args, **env):
        with tempfile.TemporaryDirectory() as tmp:
            for name, body in files.items():
                Path(tmp, name).write_text("import unittest\n\n\nclass T(unittest.TestCase):\n" + body, encoding="utf-8", newline="\n")
            git = ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"]
            for command in (["init", "-q"], ["add", "-A"], ["commit", "-q", "-m", "tests"]):
                subprocess.run(git + command, cwd=tmp, check=True, capture_output=True)
            return subprocess.run([sys.executable, str(HERE / "run_suite.py"), *args, "--dir", tmp], cwd=tmp,
                                  env=dict(os.environ, **env), capture_output=True, text=True)

    def test_a_failing_file_is_shown_and_fails_the_run_while_the_others_still_run(self):
        result = self.run_suite({
            "test_bad.py": "    def test_a(self):\n        self.assertEqual(1, 2, 'one is not two')\n",
            "test_good.py": "    def test_a(self):\n        pass\n\n    def test_b(self):\n        pass\n\n"
                            "    @unittest.skip('not here')\n    def test_c(self):\n        pass\n",
        })
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("FAIL test_bad.py", result.stdout)
        self.assertIn("one is not two", result.stdout)
        self.assertIn("ok   test_good.py (2 tests, 1 skipped", result.stdout)
        self.assertIn("ran 3 tests and skipped 1 in 2 files", result.stdout)
        self.assertIn("failed files: test_bad.py", result.stdout)

    def test_a_wide_file_never_runs_beside_another_file(self):
        body = ("    def test_a(self):\n        import os, time\n        from pathlib import Path\n"
                "        mine = Path(os.environ['SPANS'], Path(__file__).stem)\n"
                "        mine.write_text(str(time.time()) + ' ')\n        time.sleep(0.6)\n"
                "        mine.write_text(mine.read_text() + str(time.time()))\n")
        with tempfile.TemporaryDirectory() as spans:
            result = self.run_suite({name: body for name in ("test_run_all.py", "test_x1.py", "test_x2.py", "test_x3.py")}, SPANS=spans)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            times = {path.name: [float(part) for part in path.read_text().split()] for path in Path(spans).iterdir()}
        wide = times.pop("test_run_all")
        self.assertEqual([name for name, (start, end) in times.items() if start < wide[1] and wide[0] < end], [])
        self.assertLess(max(start for start, _ in times.values()), min(end for _, end in times.values()), "the other files run side by side")
        self.assertIn("at most 3 files at once", result.stdout)

    def test_the_release_gate_runs_a_tool_test_whose_tool_is_unchanged(self):
        files = {"test_crlf.py": "    def test_a(self):\n        pass\n", "test_other.py": "    def test_a(self):\n        pass\n"}
        usual = self.run_suite(files, "HEAD", KSTYLEUI_RELEASE="", KSTYLEUI_FULL="1")
        self.assertEqual(usual.returncode, 0, usual.stdout + usual.stderr)
        self.assertIn("1 of 2 test files", usual.stdout)
        self.assertIn("left out 1 tool tests whose tools did not change against HEAD: test_crlf.py", usual.stdout)
        release = self.run_suite(files, "HEAD", KSTYLEUI_RELEASE="1")
        self.assertEqual(release.returncode, 0, release.stdout + release.stderr)
        self.assertIn("2 of 2 test files", release.stdout)
        self.assertIn("ok   test_crlf.py", release.stdout)


if __name__ == "__main__":
    unittest.main()
