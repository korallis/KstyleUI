"""Tests for scripts/check-suppressions.sh and scripts/gate.sh: what the suppression check flags, and what the gate runs and prints."""

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SUPPRESSIONS = REPO / "scripts" / "check-suppressions.sh"
GATE = REPO / "scripts" / "gate.sh"
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

    def run_gate(self, *args, failing="", versions=("Luacheck: 1.2.0", "pre-commit 4.7.0"), dirty=False, **pr):
        """Run gate.sh in a committed repository of stand-ins that log each command; return (exit code, stdout lines, logged commands)."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for folder in ("scripts", "Tools/regression", "Tools/hooks", "bin"):
                (root / folder).mkdir(parents=True)
            (root / "scripts/gate.sh").write_bytes(GATE.read_bytes())
            log = 'echo "$(basename "$0") $*" >> gate.log\n[ "${GATE_FAIL:-}" != "$(basename "$0")" ]\n'
            version = '[ "$1" = --version ] && { echo "%s"; exit 0; }\n'
            suite = 'case "$*" in *unittest*) echo "py-stub $* wording=${PR_TITLE-unset},${PR_BODY-unset},${PR_LABELS-unset}" >> gate.log; exit 0 ;; esac\n'
            stubs = {"bin/luacheck": version % versions[0], "bin/pre-commit": version % versions[1] + log, "bin/py-stub": suite + log,
                     "scripts/check-suppressions.sh": log, "Tools/hooks/check-pr.sh": 'echo "$(basename "$0") $* title=$PR_TITLE" >> gate.log\n'}
            for name, body in stubs.items():
                (root / name).write_text("#!/usr/bin/env bash\n" + body, encoding="utf-8", newline="\n")
                os.chmod(root / name, 0o755)
            (root / "Tools/regression/run-all.sh").write_text(
                'pick_python() { py=(py-stub); }\n'
                'if [ "${BASH_SOURCE[0]}" = "$0" ]; then\n'
                '\techo "run-all.sh [$*] KSTYLEUI_FULL=${KSTYLEUI_FULL:-unset} LUA=${LUA-unset}" >> gate.log\n'
                'fi\n', encoding="utf-8", newline="\n")
            (root / ".gitignore").write_text("gate.log\n", encoding="utf-8", newline="\n")
            git(root, "init", "-q")
            git(root, "add", "-A")
            git(root, "commit", "-q", "-m", "stand-ins")
            if dirty:
                (root / "scripts/check-suppressions.sh").write_text("#!/usr/bin/env bash\n" + log + "# edited\n", encoding="utf-8", newline="\n")
            commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, check=True, capture_output=True, text=True).stdout.strip()
            env = {key: value for key, value in os.environ.items()
                   if key not in ("KSTYLEUI_FULL", "GATE_BASE", "PR_TITLE", "PR_BODY", "PR_BODY_FILE", "PR_LABELS")}
            env.update(PATH=str(root / "bin") + os.pathsep + env["PATH"], LUA="luajit", GATE_FAIL=failing, **pr)
            result = subprocess.run(["bash", "scripts/gate.sh", *args], cwd=root, env=env, capture_output=True, text=True)
            logged = root / "gate.log"
            commands = logged.read_text(encoding="utf-8").splitlines() if logged.exists() else []
            return result.returncode, [line.replace(commit, "<commit>") for line in result.stdout.splitlines()], commands

    def run_release_gate(self, failing=""):
        return self.run_gate("release", "--shard", "1/8", failing=failing)

    def test_release_group_runs_lint_every_lua_file_and_the_python_suite(self):
        # The owner's ruling: a pull request runs the tests its change can reach; a release runs every test first.
        code, lines, commands = self.run_release_gate()
        self.assertEqual(commands, [
            "py-stub Tools/dev/crlf.py --check",
            "pre-commit run --all-files --show-diff-on-failure",
            "py-stub Tools/locale/strings.py check",
            "check-suppressions.sh origin/staging",
            "run-all.sh [] KSTYLEUI_FULL=1 LUA=unset",
            "py-stub -m unittest discover -s Tools/tests wording=unset,unset,unset",
        ])
        self.assertEqual((code, lines[-1]), (0, "gate passed (release) at <commit>"))

    def test_release_group_fails_when_one_check_fails(self):
        code, lines, commands = self.run_release_gate(failing="pre-commit")
        self.assertEqual(code, 1)
        self.assertFalse([line for line in lines if line.startswith("gate passed")])
        self.assertEqual(len(commands), 6, "the later checks still run")

    def test_a_pass_with_uncommitted_changes_names_no_commit(self):
        # The owner's ruling, checks run locally: the "local gate" mark quotes the last line, so only a run of the committed tree may name the commit.
        code, lines, _ = self.run_gate("lint", dirty=True)
        self.assertEqual(code, 0)
        self.assertTrue(lines[-1].startswith("gate passed (lint) with uncommitted changes"), lines[-1])
        self.assertNotIn("<commit>", lines[-1])

    def test_lint_fails_unless_luacheck_and_pre_commit_are_the_pinned_versions(self):
        # The owner's ruling, checks run locally: the gate checks the two lint tool versions, as no workflow does.
        for versions, step in ((("Luacheck: 1.1.2", "pre-commit 4.7.0"), "luacheck is 1.2.0"),
                               (("Luacheck: 1.2.0", "pre-commit 4.7.10"), "pre-commit is 4.7.0")):
            with self.subTest(step=step):
                code, lines, _ = self.run_gate("lint", versions=versions)
                self.assertEqual(code, 1)
                self.assertFalse([line for line in lines if line.startswith("gate passed")])
        self.assertEqual(self.run_gate("lint")[0], 0)

    def test_the_wording_check_runs_only_when_the_title_is_given(self):
        # The owner's ruling, checks run locally: the gate checks the pull request's wording when PR_TITLE is set.
        _, _, commands = self.run_gate("lint", PR_TITLE="fix(core): keep the bar")
        self.assertIn("check-pr.sh origin/staging title=fix(core): keep the bar", commands)
        _, _, commands = self.run_gate("lint")
        self.assertFalse([command for command in commands if command.startswith("check-pr.sh")])

    def test_the_python_suite_does_not_inherit_the_pull_request_wording(self):
        # The suite's own check-pr.sh tests set their own wording; the gate's must not leak into them.
        _, _, commands = self.run_gate("python", PR_TITLE="Not a title", PR_BODY="body", PR_LABELS="release")
        self.assertEqual(commands, ["py-stub -m unittest discover -s Tools/tests wording=unset,unset,unset"])


if __name__ == "__main__":
    unittest.main()
