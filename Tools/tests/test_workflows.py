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
        self.assertEqual([p.name for p in workflows()], ["checks.yml", "pr-rules.yml", "pr-title.yml", "release.yml"])

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

    def test_release_reads_secrets_only_in_the_upload_steps(self):
        text = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
        secret_lines = [line.strip() for line in text.splitlines() if "secrets." in line]
        self.assertEqual(
            sorted(secret_lines),
            sorted([
                "CF_API_KEY: ${{ secrets.CF_API_KEY }}",
                "WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}",
                "GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}",
                "GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}",
            ]),
        )
        jobs = re.findall(r"(?m)^  ([\w-]+):$", text.split("\njobs:\n", 1)[1])
        self.assertEqual(jobs, ["check", "release"])
        self.assertIn("needs: check", text)

    def test_release_builds_the_icon_pack_in_both_jobs_and_uploads_it_beside_the_addon_zip(self):
        text = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
        check, release = text.split("\n  release:\n", 1)
        # The check job builds and inspects the pack without uploading; the release job builds it again and
        # uploads KstyleUI-Icons-<version>.zip to the GitHub release the packager made.
        self.assertIn("Tools/icons/iconset.py pack", check)
        self.assertIn("python3-pil", check, "pack needs Pillow to read the PNGs")
        self.assertIn("Tools/icons/iconset.py verify", check)
        self.assertIn("Tools/icons/iconset.py pack", release)
        self.assertIn("python3-pil", release)
        self.assertRegex(release, r"KstyleUI-Icons-\$\{GITHUB_REF_NAME#v\}\.zip")
        self.assertIn("gh release upload", release)
        self.assertNotIn("gh release upload", check)
        self.assertRegex(release, r"zip -r .*Interface", "the zip holds the Interface/Icons tree")

    def test_checks_has_the_suite_jobs_and_one_verdict(self):
        text = (WORKFLOWS / "checks.yml").read_text(encoding="utf-8")
        jobs = re.findall(r"(?m)^  ([\w-]+):$", text.split("\njobs:\n", 1)[1])
        self.assertEqual(jobs, ["pre-commit", "lua", "python", "package", "verdict"])
        verdict = text.split("\n  verdict:\n", 1)[1]
        self.assertIn("needs: [pre-commit, lua, python, package]", verdict)
        self.assertIn("if: ${{ !cancelled() }}", verdict, "the verdict must report even when a job failed")

    def test_checks_runs_on_pull_request_opening_and_pushes_never_on_edits_or_labels(self):
        text = (WORKFLOWS / "checks.yml").read_text(encoding="utf-8")
        on = text.split("\non:\n", 1)[1].split("\npermissions:", 1)[0]
        self.assertRegex(on, r"pull_request:\s*\n\s+types: \[opened, synchronize, reopened\]")
        self.assertRegex(on, r"push:\s*\n\s+branches: \[staging\]")
        for event in ("edited", "labeled", "unlabeled"):
            self.assertNotIn(event, on)
        self.assertRegex(text, r"cancel-in-progress: \$\{\{ github.event_name == 'pull_request' \}\}")

    def test_pr_rules_runs_on_edits_and_labels_and_nothing_else_does(self):
        text = (WORKFLOWS / "pr-rules.yml").read_text(encoding="utf-8")
        self.assertRegex(text, r"types: \[opened, synchronize, reopened, edited, labeled, unlabeled\]")
        self.assertEqual(re.findall(r"(?m)^  ([\w-]+):$", text.split("\njobs:\n", 1)[1]), ["pr-rules"])
        self.assertIn("check-pr.sh", text)
        self.assertNotIn("check-pr.sh", (WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))

    def test_pr_title_and_pr_rules_check_on_every_run_so_none_hides_an_earlier_failure(self):
        for name in ("pr-title.yml", "pr-rules.yml"):
            text = (WORKFLOWS / name).read_text(encoding="utf-8")
            self.assertNotIn("steps.scope", text, name)
            self.assertNotRegex(text, r"(?m)^\s+if:", name)
        self.assertIn("types: [opened, edited, synchronize, reopened]", (WORKFLOWS / "pr-title.yml").read_text(encoding="utf-8"))

    def test_every_step_after_the_scope_decision_waits_for_it(self):
        text = (WORKFLOWS / "checks.yml").read_text(encoding="utf-8")
        for area in ("lua", "python", "package"):
            job = text.split("\n  {0}:\n".format(area), 1)[1].split("\n\n  ", 1)[0]
            self.assertIn("python3 Tools/hooks/ci_scope.py {0}".format(area), job)
            steps = re.split(r"(?m)^      - ", job)[1:]
            deciding = [i for i, step in enumerate(steps) if "ci_scope.py" in step]
            self.assertEqual(len(deciding), 1, area)
            for step in steps[deciding[0] + 1:]:
                self.assertIn("if: steps.scope.outputs.run == 'true'", step, area)

    def test_the_lua_matrix_matches_the_shard_count_the_runner_gets(self):
        text = (WORKFLOWS / "checks.yml").read_text(encoding="utf-8")
        job = text.split("\n  lua:\n", 1)[1].split("\n\n  ", 1)[0]
        shards = re.search(r"shard: \[([\d, ]+)\]", job).group(1).split(", ")
        self.assertEqual(shards, [str(i) for i in range(1, len(shards) + 1)])
        self.assertIn('--shard "$SHARD/{0}"'.format(len(shards)), job)
        self.assertIn("lua ${{ matrix.shard }}/" + str(len(shards)), job)

    def test_the_downloaded_luacheck_is_pinned_by_hash(self):
        text = (WORKFLOWS / "checks.yml").read_text(encoding="utf-8")
        self.assertRegex(text, r"luacheck/releases/download/v1\.2\.0/luacheck")
        self.assertRegex(text, r"[0-9a-f]{64}  luacheck\" \| sha256sum -c -")

    def test_no_workflow_fetches_packages_with_apt(self):
        for path in workflows():
            self.assertNotRegex(path.read_text(encoding="utf-8"), r"apt(-get)?\s+(update|install)", path.name)

    def test_every_lua_install_builds_the_pinned_source_and_is_cached(self):
        for path in workflows():
            text = path.read_text(encoding="utf-8")
            installs = text.count("bash Tools/dev/install-lua51.sh")
            self.assertEqual(text.count("- name: Cache Lua 5.1.5"), installs, path.name)
        script = (REPO / "Tools" / "dev" / "install-lua51.sh").read_text(encoding="utf-8")
        self.assertRegex(script, r"(?m)^sha256=[0-9a-f]{64}$")

    def test_pr_text_reaches_scripts_only_through_env(self):
        text_fields = re.compile(r"github\.(event\.pull_request\.(body|title|labels|head)|head_ref|base_ref)")
        for path in workflows():
            for line in path.read_text(encoding="utf-8").splitlines():
                if "${{" in line and text_fields.search(line):
                    self.assertRegex(line, r"^\s*([A-Z_]+|run-name): \"?\$\{\{", f"{path.name}: {line.strip()}")

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
            "run-all.sh --affected origin/staging", "cross-family review", "no changelog",
        ):
            self.assertIn(needle, text)


if __name__ == "__main__":
    unittest.main()
