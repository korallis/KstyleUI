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


class GitRepoCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        git(self.dir, "init", "-q", "-b", "base")
        (self.dir / "a.lua").write_text("".join("local a%d = %d\n" % (i, i) for i in range(10)), encoding="utf-8")
        git(self.dir, "add", "-A")
        git(self.dir, "commit", "-q", "-m", "base")
        git(self.dir, "checkout", "-q", "-b", "change")


class SuppressionsTest(GitRepoCase):
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

    def test_a_renamed_file_that_gains_a_suppression_fails(self):
        git(self.dir, "mv", "a.lua", "renamed.lua")
        with open(self.dir / "renamed.lua", "a", encoding="utf-8") as handle:
            handle.write("local unused = 2 -- " + IGNORE + "\n")
        git(self.dir, "add", "-A")
        git(self.dir, "commit", "-q", "-m", "rename")
        result = subprocess.run(["bash", str(SUPPRESSIONS), "base"], cwd=self.dir, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("renamed.lua", result.stdout)

    def test_markdown_is_skipped(self):
        self.assertEqual(self.check("notes.md", PROSE).returncode, 0)


class CountBaselinesTest(GitRepoCase):
    def count_change(self, rows, trailer=""):
        path = self.dir / "pixel.tsv"
        path.write_text("# scene\tscreen\tfile\tcount\na\t1080\tA.lua\t4\nb\t1440\tB.lua\t2\n",
                        encoding="utf-8", newline="\n")
        git(self.dir, "add", "pixel.tsv")
        git(self.dir, "commit", "-qm", "baseline")
        git(self.dir, "branch", "-f", "base", "HEAD")
        path.write_text("# scene\tscreen\tfile\tcount\n" + rows, encoding="utf-8", newline="\n")
        git(self.dir, "add", "pixel.tsv")
        git(self.dir, "commit", "-qm", "counts" + ("\n\n" + trailer if trailer else ""))
        return subprocess.run(["bash", str(SUPPRESSIONS), "base"], cwd=self.dir,
                              env=dict(os.environ, SUPPRESSION_BASELINES="pixel.tsv"), capture_output=True, text=True)

    def test_lower_counts_pass_without_a_trailer(self):
        result = self.count_change("a\t1080\tA.lua\t3\nb\t1440\tB.lua\t2\n")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_removed_rows_pass_without_a_trailer(self):
        result = self.count_change("b\t1440\tB.lua\t2\n")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_higher_counts_require_a_trailer(self):
        result = self.count_change("a\t1080\tA.lua\t5\nb\t1440\tB.lua\t1\n")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("Baseline-Growth:", result.stdout)

    def test_higher_counts_pass_with_a_ticket_trailer(self):
        result = self.count_change("a\t1080\tA.lua\t5\nb\t1440\tB.lua\t2\n", "Baseline-Growth: LEE-1234")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("allowed by Baseline-Growth: LEE-1234", result.stdout)

    def test_new_keys_require_a_trailer_even_when_another_count_falls(self):
        result = self.count_change("a\t1080\tA.lua\t3\nb\t1440\tB.lua\t2\na\t1440\tA.lua\t0\n")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("Baseline-Growth:", result.stdout)


class GateTest(unittest.TestCase):
    def test_gate_passes_the_pixel_baseline_to_the_suppression_check(self):
        text = GATE.read_text(encoding="utf-8")
        self.assertRegex(text, r'(?m)^\s*step "check-suppressions against \$base" env '
                              r'SUPPRESSION_BASELINES=Tools/regression/pixel_allow\.tsv '
                              r'bash scripts/check-suppressions\.sh "\$base"$')

    def test_gate_runs_every_check_the_repository_names(self):
        text = GATE.read_text(encoding="utf-8")
        for needle in (
            "Tools/dev/crlf.py --check",
            "pre-commit run --all-files",
            "Tools/locale/strings.py check",
            "scripts/check-suppressions.sh",
            "Tools/regression/run-all.sh",
            "unittest discover -s Tools/tests",
        ):
            self.assertIn(needle, text)
        self.assertIn("env -u SKIP pre-commit run --all-files", text)
        self.assertNotIn('step "luacheck"', text)
        self.assertNotIn('step "check_toc"', text)
        hooks = (REPO / ".pre-commit-config.yaml").read_text(encoding="utf-8")
        self.assertIn("entry: luacheck --no-color .", hooks)
        self.assertIn("entry: python Tools/hooks/check_toc.py", hooks)
        self.assertIn("source Tools/regression/run-all.sh", text)
        picker = (REPO / "Tools/regression/run-all.sh").read_text(encoding="utf-8")
        self.assertIn(".local/share/wow-dev/venv/bin/python", picker)

    def test_gate_rejects_an_unknown_group(self):
        result = subprocess.run(["bash", str(GATE), "nonsense"], cwd=REPO, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)

    def test_release_group_runs_lint_every_lua_file_and_the_python_suite(self):
        # The owner's ruling: a pull request runs the tests its change can reach; a release runs every test first.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for folder in ("scripts", "Tools/regression", "bin"):
                (root / folder).mkdir(parents=True)
            (root / "scripts/gate.sh").write_bytes(GATE.read_bytes())
            (root / "scripts/check-suppressions.sh").write_text("exit 0\n", encoding="utf-8", newline="\n")
            (root / "bin/pre-commit").write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8", newline="\n")
            os.chmod(root / "bin/pre-commit", 0o755)
            (root / "Tools/regression/run-all.sh").write_text(
                'pick_python() { py=(true); }\n'
                'if [ "${BASH_SOURCE[0]}" = "$0" ]; then echo "lua args=[$*] full=${KSTYLEUI_FULL:-unset}"; fi\n',
                encoding="utf-8", newline="\n")
            env = {key: value for key, value in os.environ.items() if key != "KSTYLEUI_FULL"}
            env["PATH"] = str(root / "bin") + os.pathsep + env["PATH"]
            result = subprocess.run(["bash", "scripts/gate.sh", "release"], cwd=root, env=env, capture_output=True, text=True)
        lines = result.stdout.splitlines()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("lua args=[] full=1", lines)
        for step in ("crlf --check", "pre-commit", "strings.py check", "python suite"):
            self.assertIn("== gate: " + step, lines)
        self.assertEqual(lines[-1], "gate passed (release)")

    def test_ci_calls_the_gate_in_each_job_that_has_a_group(self):
        text = CHECKS.read_text(encoding="utf-8")
        for group in ("lint", "lua", "python"):
            self.assertRegex(text, r"bash scripts/gate\.sh " + group)
        self.assertIn("GATE_BASE: ${{ github.event_name == 'push' && github.event.before || 'HEAD^1' }}", text)


if __name__ == "__main__":
    unittest.main()
