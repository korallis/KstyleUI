"""Tests for scripts/check-suppressions.sh and scripts/gate.sh: what the suppression check flags, and that CI calls the gate."""

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SUPPRESSIONS = REPO / "scripts" / "check-suppressions.sh"
GATE = REPO / "scripts" / "gate.sh"
CHECKS = REPO / ".github" / "workflows" / "checks.yml"
IGNORE = "luacheck" + ": ignore 211"
NOQA = "# no" + "qa: F401"
PROSE = "a work" + "around that is described here\n"


def git(cwd, *args):
    subprocess.run(
        ["git", "-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false", *args],
        cwd=cwd, check=True, capture_output=True,
    )


class SuppressionsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        git(self.dir, "init", "-q", "-b", "base")
        (self.dir / "a.lua").write_text("local a = 1\n", encoding="utf-8")
        git(self.dir, "add", "-A")
        git(self.dir, "commit", "-q", "-m", "base")
        git(self.dir, "checkout", "-q", "-b", "change")

    def check(self, name, text):
        (self.dir / name).write_text(text, encoding="utf-8")
        git(self.dir, "add", "-A")
        git(self.dir, "commit", "-q", "-m", "change")
        return subprocess.run(["bash", str(SUPPRESSIONS), "base"], cwd=self.dir, capture_output=True, text=True)

    def test_a_clean_change_passes(self):
        self.assertEqual(self.check("a.lua", "local a = 1\nlocal b = 2\n").returncode, 0)

    def test_a_luacheck_ignore_without_a_ticket_fails(self):
        result = self.check("a.lua", "local a = 1\nlocal unused = 2 -- " + IGNORE + "\n")
        self.assertEqual(result.returncode, 1)
        self.assertIn("a.lua:2", result.stdout)

    def test_a_luacheck_ignore_with_a_ticket_passes(self):
        self.assertEqual(self.check("a.lua", "local a = 1\nlocal unused = 2 -- " + IGNORE + " LEE-1234\n").returncode, 0)

    def test_a_python_suppression_without_a_ticket_fails(self):
        self.assertEqual(self.check("b.py", "import os  " + NOQA + "\n").returncode, 1)

    def test_markdown_is_skipped(self):
        self.assertEqual(self.check("notes.md", PROSE).returncode, 0)


class GateTest(unittest.TestCase):
    def test_gate_runs_every_check_the_repository_names(self):
        text = GATE.read_text(encoding="utf-8")
        for needle in (
            "Tools/dev/crlf.py --check",
            "pre-commit run --all-files",
            "luacheck",
            "Tools/hooks/check_toc.py",
            "Tools/locale/strings.py check",
            "scripts/check-suppressions.sh",
            "Tools/regression/run-all.sh",
            "unittest discover -s Tools/tests",
            ".local/share/wow-dev/venv/bin/python",
        ):
            self.assertIn(needle, text)

    def test_gate_rejects_an_unknown_group(self):
        result = subprocess.run(["bash", str(GATE), "nonsense"], cwd=REPO, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)

    def test_ci_calls_the_gate_in_each_job_that_has_a_group(self):
        text = CHECKS.read_text(encoding="utf-8")
        for group in ("lint", "lua", "python"):
            self.assertRegex(text, r"bash scripts/gate\.sh " + group)
        self.assertIsNotNone(re.search(r"GATE_BASE: HEAD\^1", text))


if __name__ == "__main__":
    unittest.main()
