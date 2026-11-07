"""Tests for .github: pinned actions, dropped credentials, minimal permissions and the PR title rule."""

import os
import re
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
WORKFLOWS = REPO / ".github" / "workflows"

USES = re.compile(r"^\s*(?:- )?uses: (\S+)(.*)$", re.M)
STEP_OR_JOB = re.compile(r"^(\s+- |  \S)")


def workflows():
    return sorted(WORKFLOWS.glob("*.yml"))


def steps_after(text, start):
    """Return the step text from offset start up to the next step or job."""
    lines = text[start:].splitlines()
    block = [lines[0]]
    for line in lines[1:]:
        if STEP_OR_JOB.match(line):
            break
        block.append(line)
    return "\n".join(block)


def title_pattern():
    match = re.search(r"^\s*pattern='([^']+)'$", (WORKFLOWS / "pr-title.yml").read_text(encoding="utf-8"), re.M)
    assert match, "pr-title.yml has no pattern='...' line"
    return match.group(1)


def title_passes(title):
    """Run the title pattern the way the workflow does: bash [[ =~ ]]."""
    env = dict(os.environ, TITLE=title, PATTERN=title_pattern())
    bash = os.environ.get("TEST_BASH", "bash")
    return subprocess.run([bash, "-c", '[[ $TITLE =~ $PATTERN ]]'], env=env).returncode == 0


class WorkflowsTest(unittest.TestCase):
    def test_has_the_planned_workflows(self):
        self.assertEqual([p.name for p in workflows()], ["checks.yml", "pr-title.yml", "release.yml"])

    def test_every_action_is_pinned_by_full_sha_with_its_version(self):
        uses = [(path.name, m) for path in workflows() for m in USES.finditer(path.read_text(encoding="utf-8"))]
        self.assertGreaterEqual(len(uses), 5)
        for name, match in uses:
            self.assertRegex(match.group(1), r"^[\w.-]+/[\w./-]+@[0-9a-f]{40}$", name)
            self.assertRegex(match.group(2), r"^ # v\d", name)

    def test_every_checkout_drops_credentials(self):
        for path in workflows():
            text = path.read_text(encoding="utf-8")
            for match in USES.finditer(text):
                if match.group(1).startswith("actions/checkout@"):
                    self.assertIn("persist-credentials: false", steps_after(text, match.start()), path.name)

    def test_every_workflow_sets_minimal_permissions(self):
        for path in workflows():
            text = path.read_text(encoding="utf-8")
            self.assertRegex(text, r"(?m)^permissions:", path.name)
            self.assertNotRegex(text, r"(?m)^permissions:\s*\n\s+[\w-]+: write$", path.name)
            writes = re.findall(r"(?m)^\s+([\w-]+): write$", text)
            if path.name == "release.yml":
                # Only the upload job may write, and only the repository contents, for the GitHub release.
                self.assertEqual(writes, ["contents"], path.name)
            else:
                self.assertEqual(writes, [], path.name)

    def test_release_runs_only_for_version_tags_on_main(self):
        text = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
        on = text.split("\non:\n", 1)[1].split("\npermissions:", 1)[0]
        self.assertNotIn("pull_request", on)
        self.assertRegex(on, r"tags:\s*\n\s+- \"v\*\"")
        self.assertIn("merge-base --is-ancestor", text)
        self.assertIn("bash Tools/hooks/check-package.sh", text)

    def test_release_reads_secrets_only_in_the_upload_step(self):
        text = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
        secret_lines = [line.strip() for line in text.splitlines() if "secrets." in line]
        self.assertEqual(
            sorted(secret_lines),
            sorted([
                "CF_API_KEY: ${{ secrets.CF_API_KEY }}",
                "WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}",
                "GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}",
            ]),
        )
        jobs = re.findall(r"(?m)^  ([\w-]+):$", text.split("\njobs:\n", 1)[1])
        self.assertEqual(jobs, ["check", "release"])
        self.assertIn("needs: check", text)

    def test_checks_has_the_four_jobs(self):
        text = (WORKFLOWS / "checks.yml").read_text(encoding="utf-8")
        jobs = re.findall(r"(?m)^  ([\w-]+):$", text.split("\njobs:\n", 1)[1])
        self.assertEqual(jobs, ["pre-commit", "tests", "package", "pr-rules"])

    def test_pr_text_reaches_scripts_only_through_env(self):
        text_fields = re.compile(r"github\.(event\.pull_request\.(body|title|labels|head)|head_ref|base_ref)")
        for path in workflows():
            for line in path.read_text(encoding="utf-8").splitlines():
                if "${{" in line and text_fields.search(line):
                    self.assertRegex(line, r"^\s+[A-Z_]+: \$\{\{", f"{path.name}: {line.strip()}")

    def test_title_pattern_accepts_type_scope_summary(self):
        for title in ("ci(repo): add CI workflows", "feat: add the minimap", "fix(unit-frames): keep the bar", "revert(core): undo"):
            with self.subTest(title=title):
                self.assertTrue(title_passes(title))

    def test_title_pattern_rejects_other_titles(self):
        for title in ("Add CI", "Feat: add", "feat(Core): add", "feat(core):add", "feat(core): ", "style: tidy", "feat!: break", "feat(): x"):
            with self.subTest(title=title):
                self.assertFalse(title_passes(title))

    def test_dependabot_updates_actions_weekly(self):
        text = (REPO / ".github" / "dependabot.yml").read_text(encoding="utf-8")
        self.assertIn('package-ecosystem: "github-actions"', text)
        self.assertIn('interval: "weekly"', text)

    def test_pr_template_has_the_sections_the_rules_read(self):
        text = (REPO / ".github" / "PULL_REQUEST_TEMPLATE.md").read_text(encoding="utf-8")
        for needle in (
            "## Summary", "## Changelog", "## In-game checks", "addonCombatRestrictionsForced",
            "addonEncounterRestrictionsForced", "addonMapRestrictionsForced", "addonChatRestrictionsForced",
            "taintLog", "python3 Tools/dev/crlf.py", "pre-commit run --all-files", "bash Tools/regression/run-all.sh",
            "python3 -m unittest discover -s Tools/tests", "/codex:review", "no changelog",
        ):
            self.assertIn(needle, text)
        self.assertNotIn("cr review", text, "KstyleUI does not use CodeRabbit")


if __name__ == "__main__":
    unittest.main()
