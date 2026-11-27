"""Tests for .github: pinned actions, dropped credentials, minimal permissions, the checks workflow and the release."""

import os
import re
import subprocess
import textwrap
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


def jobs_of(text):
    """Return {job id: job text} for a workflow's jobs."""
    parts = re.split(r"(?m)^  ([\w-]+):$", text.split("\njobs:\n", 1)[1])
    return dict(zip(parts[1::2], parts[2::2]))


class WorkflowsTest(unittest.TestCase):
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
                "GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}",
                "DISCORD_RELEASE_WEBHOOK: ${{ secrets.DISCORD_RELEASE_WEBHOOK }}",
                "DISCORD_RELEASE_WEBHOOK: ${{ secrets.DISCORD_RELEASE_WEBHOOK }}",
            ]),
        )
        self.assertEqual(list(jobs_of(text)), ["check", "release", "discord-repost"])

    def test_release_runs_no_test_suite_and_uploads_only_after_check(self):
        # The owner's ruling: Actions makes the release; lint and the suites run locally on the commit before the tag.
        text = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
        for needle in ("gate.sh", "run-all", "unittest discover", "run_suite", "proof"):
            self.assertNotIn(needle, text)
        self.assertEqual(re.findall(r"(?m)^    needs: (.+)$", jobs_of(text)["release"]), ["check"])

    def test_release_upload_requires_successful_dependencies(self):
        jobs = jobs_of((WORKFLOWS / "release.yml").read_text(encoding="utf-8"))
        self.assertEqual(re.findall(r"(?m)^    if: (.+)$", jobs["release"]), ["github.event_name == 'push'"])

    def test_manual_release_dispatch_can_only_post_to_discord(self):
        text = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
        self.assertIn("workflow_dispatch:", text)
        for name, job in jobs_of(text).items():
            guard = re.search(r"(?m)^    if: (.+)$", job).group(1)
            expression = guard.replace("github.event_name", "'workflow_dispatch'")
            expression = expression.replace("github.event.pull_request.head.repo.full_name", "'fork'")
            expression = expression.replace("github.repository", "'repo'").replace("&&", "and").replace("||", "or")
            if not eval(expression, {"__builtins__": {}}):
                continue
            self.assertIn("github.event_name == 'workflow_dispatch'", job, name)
            self.assertIn("contents: read", job, name)
            self.assertNotIn("contents: write", job, name)
            self.assertNotIn("packager@", job, name)
            self.assertNotIn("release upload", job, name)
            self.assertNotIn("iconset.py", job, name)
            self.assertNotRegex(job, r"CF_API_KEY|WAGO_API_TOKEN|GITHUB_OAUTH", name)
        self.assertRegex(text, r"\n      roadmap:\n        description: .+\n        type: boolean\n")

    def test_manual_dispatch_runs_discord_post_in_the_chosen_mode(self):
        job = jobs_of((WORKFLOWS / "release.yml").read_text(encoding="utf-8"))["discord-repost"]
        script = textwrap.dedent(job.split("run: |\n", 1)[1])
        stubs = 'git() { echo "git $*"; [ "$TAG" = v1 ]; }\npython3() { echo "python3 $*"; }\n'
        post, tag = "python3 Tools/release/discord_post.py ", "git show-ref --verify refs/tags/"
        for roadmap, ref, ids, expected in (("true", "", "", post + "--roadmap"), ("true", "", "1", post + "--roadmap --edit 1"),
                                            ("false", "v1", "", tag + "v1\n" + post + "v1"),
                                            ("false", "v1", "1,2", tag + "v1\n" + post + "--edit v1 1,2"), ("false", "v2", "", tag + "v2")):
            env = dict(os.environ, ROADMAP=roadmap, TAG=ref, MESSAGE_IDS=ids)
            run = subprocess.run([os.environ.get("TEST_BASH", "bash"), "-e", "-c", stubs + script],
                                 env=env, capture_output=True, text=True)
            self.assertEqual((run.stdout.strip(), run.returncode == 0), (expected, ref != "v2"), (roadmap, ref, ids, run.stderr))

    def test_release_check_cannot_ignore_errors(self):
        text = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
        jobs = jobs_of(text)
        self.assertNotIn("continue-on-error:", jobs["check"])
        steps = jobs["release"].split("\n      - ")[1:]
        for step in steps[:-1]:
            self.assertNotIn("continue-on-error:", step)
        self.assertIn("name: Post the changelog to Discord", steps[-1])
        self.assertIn("continue-on-error: true", steps[-1])
        self.assertIn("DISCORD_RELEASE_WEBHOOK: ${{ secrets.DISCORD_RELEASE_WEBHOOK }}", steps[-1])
        self.assertIn('run: python3 Tools/release/discord_post.py "$GITHUB_REF_NAME"', steps[-1])

    def test_release_check_validates_the_tag_changelog(self):
        job = jobs_of((WORKFLOWS / "release.yml").read_text(encoding="utf-8"))["check"]
        step = next(step for step in job.split("\n      - ") if "Tools.tests.test_release_changelog" in step)
        self.assertEqual(re.findall(r"(?m)^        run: (.+)$", step),
                         ["python3 -m unittest Tools.tests.test_release_changelog"])
        self.assertNotIn("if:", step)
        self.assertNotIn("continue-on-error:", step)

    def test_release_builds_the_icon_pack_in_both_jobs_and_uploads_it_beside_the_addon_zip(self):
        text = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
        check, release = text.split("\n  release:\n", 1)
        # The check job builds and inspects the pack without uploading; the release job builds it again and
        # uploads KstyleUI-Icons-<version>.zip to the GitHub release the packager made.
        self.assertIn("Tools/icons/iconset.py pack", check)
        self.assertIn('"$KSTYLEUI_PILLOW_PYTHON" Tools/icons/iconset.py pack', check, "pack needs Pillow to read the PNGs")
        self.assertIn("Tools/icons/iconset.py verify", check)
        self.assertIn('python3 Tools/icons/iconset.py pack', release, "the upload job's only Python has Pillow")
        self.assertRegex(release, r"KstyleUI-Icons-\$\{GITHUB_REF_NAME#v\}\.zip")
        self.assertIn("gh release upload", release)
        self.assertNotIn("gh release upload", check)
        self.assertRegex(release, r"zip -r .*Interface", "the zip holds the Interface/Icons tree")
        packager = release.index("uses: BigWigsMods/packager@")
        for step in ("actions/setup-python@", "pip install Pillow", "Tools/icons/iconset.py pack"):
            self.assertLess(release.index(step), packager, f"{step} can fail: run it before the packager publishes")
        self.assertLess(packager, release.index("gh release upload"))

    def test_release_page_shows_only_its_version_after_the_upload(self):
        release = jobs_of((WORKFLOWS / "release.yml").read_text(encoding="utf-8"))["release"]
        notes = release.index('python3 Tools/release/discord_post.py --notes "$GITHUB_REF_NAME"')
        self.assertLess(release.index("uses: BigWigsMods/packager@"), notes)
        self.assertLess(notes, release.index('gh release edit "$GITHUB_REF_NAME" --notes-file'))

    def test_actions_runs_the_checks_the_nightly_suite_and_the_release(self):
        # The captain's ruling: on each pull request, the GitHub Actions workflow; nightly or before a release, the full suite.
        self.assertEqual([path.name for path in workflows()], ["checks.yml", "nightly.yml", "pr-rules.yml", "release.yml"])
        self.assertFalse((REPO / ".github" / "actionlint.yaml").exists(), "no workflow uses a self-hosted runner label")

    def test_every_job_runs_on_a_hosted_runner(self):
        for path in workflows():
            jobs = jobs_of(path.read_text(encoding="utf-8"))
            self.assertTrue(jobs, path.name)
            for job, body in jobs.items():
                self.assertEqual(re.search(r"(?m)^    runs-on: (.+)$", body).group(1), "ubuntu-latest", f"{path.name}: {job}")

    def test_release_jobs_run_for_a_tag_push_or_a_manual_repost(self):
        for job, body in jobs_of((WORKFLOWS / "release.yml").read_text(encoding="utf-8")).items():
            guard = re.search(r"(?m)^    if: (.*)$", body)
            self.assertIsNotNone(guard, f"release.yml: {job} has no event guard")
            expected = "github.event_name == 'workflow_dispatch'" if job == "discord-repost" else "github.event_name == 'push'"
            self.assertEqual(guard.group(1), expected, f"release.yml: {job}")

    def events(self, name):
        on = (WORKFLOWS / name).read_text(encoding="utf-8").split("\non:\n", 1)[1].split("\n\n", 1)[0]
        return on, re.findall(r"(?m)^  ([\w-]+):", on)

    def test_which_workflows_run_for_a_pull_request_and_on_a_schedule(self):
        self.assertTrue(set(self.events("release.yml")[1]) <= {"push", "workflow_dispatch"})
        self.assertEqual(self.events("pr-rules.yml")[1], ["pull_request"])
        self.assertEqual(self.events("nightly.yml")[1], ["schedule", "workflow_dispatch"])
        on, events = self.events("checks.yml")
        self.assertEqual(events, ["pull_request", "push", "workflow_dispatch"])
        self.assertIn("    branches: [staging, main]\n", on)
        self.assertNotIn("branches", on.split("\n  push:", 1)[0], "every pull request runs, whatever its base")

    def test_no_workflow_skips_fork_pull_requests_or_reads_a_secret_outside_the_release(self):
        for name in ("checks.yml", "nightly.yml", "pr-rules.yml"):
            text = (WORKFLOWS / name).read_text(encoding="utf-8")
            self.assertNotIn("head.repo", text, name)
            self.assertNotRegex(text, r"secrets\.|: write", name)

    def test_pull_request_checks_pick_by_what_changed_and_only_warn_on_perf(self):
        # The captain's ruling: checks picked by what changed (docs-only runs no Lua tests), perf a warning on each pull request.
        jobs = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))
        self.assertEqual(list(jobs), ["lua", "lint-python-package", "checks"])
        self.assertIn("      KSTYLEUI_PERF: warn\n", jobs["lua"])
        self.assertIn("if bash Tools/hooks/needs-lua.sh HEAD^1; then", jobs["lua"])
        self.assertIn('run: bash Tools/regression/run-all.sh --shard "$SHARD/$SHARD_TOTAL" --affected HEAD^1\n', jobs["lua"])
        self.assertEqual(jobs["lua"].count("if: steps.scope.outputs.run == 'true'"), 4, "every Lua step waits on the scope")
        self.assertIn("run: bash scripts/gate.sh fast\n", jobs["lint-python-package"])
        self.assertIn("""run: '"$KSTYLEUI_PYTHON" Tools/tests/run_suite.py HEAD^1 --skip test_render_deterministic.py'\n""",
                      jobs["lint-python-package"])
        self.assertIn("run: bash Tools/hooks/check-package.sh\n", jobs["lint-python-package"])

    def test_the_nightly_run_checks_everything_with_perf_enforced(self):
        text = (WORKFLOWS / "nightly.yml").read_text(encoding="utf-8")
        jobs = jobs_of(text)
        self.assertNotIn("KSTYLEUI_PERF", text)
        self.assertNotIn("--skip", text)
        self.assertIn("run: bash scripts/gate.sh lint\n", jobs["lint-python-package"])
        self.assertIn("""run: '"$KSTYLEUI_PYTHON" Tools/tests/run_suite.py'\n""", jobs["lint-python-package"])
        self.assertIn('--shard "$SHARD/$SHARD_TOTAL" --affected 4b825dc642cb6eb9a060e54bf8d69288fbee4904\n', jobs["lua"])
        self.assertIn("key: lua-deps-${{ github.run_id }}", jobs["lua-deps"])

    def test_the_checks_job_passes_only_when_every_job_passed(self):
        # The checks job is the one status a merge waits on, so a failed, cancelled or skipped job must turn it red.
        job = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))["checks"]
        self.assertIn("    if: ${{ always() }}\n    needs: [lua, lint-python-package]\n", job)
        script = textwrap.dedent(job.split("        run: |\n", 1)[1])
        for results, code in (("success success", 0), ("success failure", 1), ("cancelled success", 1),
                              ("success skipped", 1)):
            with self.subTest(results=results):
                done = subprocess.run(["bash", "-c", script], env=dict(os.environ, RESULTS=results), capture_output=True, text=True)
                self.assertEqual(done.returncode, code, done.stdout + done.stderr)

    def test_the_runner_tools_are_checked_by_version(self):
        release = jobs_of((WORKFLOWS / "release.yml").read_text(encoding="utf-8"))
        self.assertIn("lua5.1 -v 2>&1 | grep '^Lua 5\\.1\\.5 '", release["check"])
        for job in ("check", "release"):
            self.assertIn("| grep '^Pillow 13\\.0\\.0$'", release[job], job)

    def test_every_job_has_a_bounded_timeout(self):
        for path in workflows():
            for name, job in jobs_of(path.read_text(encoding="utf-8")).items():
                timeout = int(re.search(r"timeout-minutes: (\d+)", job).group(1))
                self.assertTrue(0 < timeout <= 60, f"{path.name}: {name}")

    def test_pr_text_reaches_scripts_only_through_env(self):
        text_fields = re.compile(r"github\.(event\.pull_request\.(body|title|labels|head)|head_ref|base_ref)")
        for path in workflows():
            for line in path.read_text(encoding="utf-8").splitlines():
                if "${{" in line and text_fields.search(line):
                    self.assertRegex(line, r"^\s*([A-Z_]+|run-name|if): \"?\$\{\{", f"{path.name}: {line.strip()}")


if __name__ == "__main__":
    unittest.main()
