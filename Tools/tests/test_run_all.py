"""Tests for Tools/regression/run-all.sh.

run-all.sh only runs "$LUA <file>", so sh stands in for Lua and the test files hold shell commands.
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "regression" / "run-all.sh"


class RunAllTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.regression = Path(self._tmp.name) / "Tools" / "regression"
        self.regression.mkdir(parents=True)
        shutil.copy(SCRIPT, self.regression / "run-all.sh")
        (self.regression / "helper.lua").write_text("exit 1\n")

    def tearDown(self):
        self._tmp.cleanup()

    def run_all(self, lua="sh"):
        env = dict(os.environ, LUA=lua)
        return subprocess.run(["bash", str(self.regression / "run-all.sh")], env=env, capture_output=True, text=True)

    def test_counts_passes_and_failures(self):
        (self.regression / "test-pass.lua").write_text("echo fine\n")
        lines = "".join(f"echo line{i}\n" for i in range(1, 8))
        (self.regression / "test-fail.lua").write_text(lines + "exit 1\n")
        result = self.run_all()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL test-fail", result.stdout)
        self.assertIn("line7", result.stdout)
        self.assertIn("line3", result.stdout)
        self.assertNotIn("line2", result.stdout)
        self.assertNotIn("FAIL test-pass", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 1, failed 1"))

    def test_exits_0_when_all_pass(self):
        (self.regression / "test-a.lua").write_text("true\n")
        (self.regression / "test-b.lua").write_text("true\n")
        result = self.run_all()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 2, failed 0"))

    def test_runs_from_the_repository_root(self):
        (self.regression / "test-cwd.lua").write_text("test -d Tools/regression\n")
        result = self.run_all()
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_fails_when_no_tests_exist(self):
        result = self.run_all()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no tests found", result.stdout)

    def test_stops_with_one_message_when_lua_is_missing(self):
        (self.regression / "test-a.lua").write_text("true\n")
        (self.regression / "test-b.lua").write_text("true\n")
        result = self.run_all(lua="no-such-lua-kstyleui")
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn("no-such-lua-kstyleui not found", result.stdout)
        self.assertNotIn("FAIL", result.stdout)


if __name__ == "__main__":
    unittest.main()
