"""Tests for .github: pinned actions, dropped credentials, minimal permissions and the PR title rule."""

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
FORK_GUARD = "github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository"


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


def title_pattern():
    match = re.search(r"^\s*pattern='([^']+)'$", (WORKFLOWS / "pr-rules.yml").read_text(encoding="utf-8"), re.M)
    assert match, "pr-rules.yml has no pattern='...' line"
    return match.group(1)


def title_passes(title):
    """Run the title pattern the way the workflow does: bash [[ =~ ]]."""
    env = dict(os.environ, TITLE=title, PATTERN=title_pattern())
    bash = os.environ.get("TEST_BASH", "bash")
    return subprocess.run([bash, "-c", '[[ $TITLE =~ $PATTERN ]]'], env=env).returncode == 0


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
        jobs = re.findall(r"(?m)^  ([\w-]+):$", text.split("\njobs:\n", 1)[1])
        self.assertIn("release", jobs)
        self.assertIn("needs: [check, lua]", text)

    def test_release_requires_successful_shards_or_a_successful_sha_proof(self):
        text = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
        jobs = jobs_of(text)
        shards = re.search(r"shard: \[([\d, ]+)\]", jobs["lua"]).group(1).split(", ")
        self.assertEqual(shards, [str(i) for i in range(1, len(shards) + 1)])
        self.assertIn('bash scripts/gate.sh lua --shard "$SHARD/{0}"'.format(len(shards)), jobs["lua"])
        self.assertIn("needs: [check, lua]", jobs["release"])
        self.assertEqual(re.findall(r"(?m)^    if: (.+)$", jobs["lua"]), ["github.event_name == 'push'"])
        self.assertNotIn("continue-on-error:", jobs["lua"])
        self.assertIn("needs: check", jobs["lua"])
        step = next(step for step in jobs["lua"].split("\n      - ") if "bash scripts/gate.sh lua" in step)
        self.assertIn("if: needs.check.outputs.run != 'false'", step)

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

    def test_release_check_and_lua_cannot_ignore_errors(self):
        text = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
        jobs = jobs_of(text)
        for job in (jobs["check"], jobs["lua"]):
            self.assertNotIn("continue-on-error:", job)
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
        self.assertIn("Tools/icons/iconset.py pack", release)
        self.assertIn('"$KSTYLEUI_PILLOW_PYTHON" Tools/icons/iconset.py pack', release)
        self.assertRegex(release, r"KstyleUI-Icons-\$\{GITHUB_REF_NAME#v\}\.zip")
        self.assertIn("gh release upload", release)
        self.assertNotIn("gh release upload", check)
        self.assertRegex(release, r"zip -r .*Interface", "the zip holds the Interface/Icons tree")

    def test_release_page_shows_only_its_version_after_the_upload(self):
        release = jobs_of((WORKFLOWS / "release.yml").read_text(encoding="utf-8"))["release"]
        notes = release.index('python3 Tools/release/discord_post.py --notes "$GITHUB_REF_NAME"')
        self.assertLess(release.index("uses: BigWigsMods/packager@"), notes)
        self.assertLess(notes, release.index('gh release edit "$GITHUB_REF_NAME" --notes-file'))

    def test_checks_runs_the_suite_jobs_without_dependencies_or_a_verdict(self):
        text = (WORKFLOWS / "checks.yml").read_text(encoding="utf-8")
        jobs = jobs_of(text)
        for job, body in jobs.items():
            self.assertNotRegex(body, r"(?m)^    needs:", job)

    def test_check_package_removes_tags_even_when_a_self_hosted_checkout_keeps_them(self):
        job = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))["python-package"]
        cleanup_name = "Remove tags from the check build"
        self.assertIn("- name: " + cleanup_name, job,
                      "remove checkout tags before packaging: the packager skips branch pushes whose HEAD has a tag")
        cleanup = steps_after(job, job.index("      - name: " + cleanup_name))
        self.assertEqual(re.search(r"(?m)^        run: (.*)$", cleanup).group(1),
                         "git for-each-ref --format='delete %(refname)' refs/tags | git update-ref --stdin")
        package = steps_after(job, job.index("      - name: Package without uploading or localisation"))
        self.assertEqual(re.search(r"(?m)^        if: (.*)$", cleanup).group(1),
                         re.search(r"(?m)^        if: (.*)$", package).group(1))
        self.assertLess(job.index(cleanup), job.index(package))
        self.assertIn("args: -d -l", package)
        self.assertIn("pandoc: false", package)

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
        self.assertIn("check-pr.sh", text)
        self.assertNotIn("check-pr.sh", (WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))

    def test_pr_rules_checks_the_title_and_the_body_on_every_run_so_none_hides_an_earlier_failure(self):
        text = (WORKFLOWS / "pr-rules.yml").read_text(encoding="utf-8")
        self.assertNotIn("steps.scope", text)
        self.assertNotRegex(text.replace("    if: " + FORK_GUARD + "\n", ""), r"(?m)^\s+if:")
        self.assertIn("TITLE: ${{ github.event.pull_request.title }}", text)

    def test_each_suite_decides_its_own_scope(self):
        jobs = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))
        for job, mode in (("lua", "lua"), ("python-package", "all")):
            self.assertIn("id: scope", jobs[job], job)
            self.assertIn("python3 Tools/hooks/ci_scope.py " + mode, jobs[job], job)
        self.assertNotIn("actions/upload-artifact@", jobs["lua"], "staging Lua budgets must run without marker reuse")
        self.assertIn("fetch-depth: 2", jobs["lua"])
        for step in ("Check the runner's Lua is 5.1.5", "Lua regression tests, one slice of the files"):
            block = jobs["lua"].split("- name: " + step, 1)[1].split("\n      - ", 1)[0]
            self.assertIn("if: steps.scope.outputs.run != 'false'", block, step)

    def test_python_and_package_run_after_a_lint_failure_unless_cancelled_or_out_of_scope(self):
        job = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))["python-package"]
        lint = job.index("run: bash scripts/gate.sh lint")
        self.assertLess(job.index("python3 Tools/hooks/ci_scope.py all"), lint)
        steps = job[lint:].split("\n      - ")[1:]
        suite_steps = [step for step in steps[:-1] if "actions/upload-artifact@" not in step]
        for step in suite_steps:
            self.assertRegex(step, r"if: \$\{\{ !cancelled\(\) && .*steps\.scope\.outputs\.", step)
        for step, output in (("Check the runner's Python is 3.12", "python"), ("Python tool tests", "python"), ("Package without uploading or localisation", "package"), ("Check the zip", "package")):
            block = job.split("- name: " + step, 1)[1].split("\n      - ", 1)[0]
            self.assertIn("if: ${{{{ !cancelled() && steps.scope.outputs.{0} != 'false' && (github.event_name != 'pull_request' || steps.start_{0}.outcome == 'success') }}}}".format(output), block, step)
        for command in ("bash scripts/gate.sh python", "BigWigsMods/packager@", "bash Tools/hooks/check-package.sh"):
            self.assertGreater(job.index(command), lint)

    def test_each_checks_job_annotates_a_failed_or_cancelled_staging_push_as_its_last_step(self):
        jobs = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))
        for job, body in jobs.items():
            with self.subTest(job=job):
                last_step = body.rsplit("\n      - ", 1)[1]
                self.assertIn("if: (failure() || cancelled()) && github.event_name == 'push'", last_step, job)
                self.assertIn("::error title=staging is red::The merged result of staging fails", last_step, job)

    def test_checks_jobs_never_allow_errors_to_leave_a_job_green(self):
        jobs = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))
        for job, body in jobs.items():
            with self.subTest(job=job):
                self.assertNotRegex(body, r"(?m)^\s+(?:- )?continue-on-error:",
                                    job + ": remove continue-on-error so every failing step fails its job")

    def test_markers_record_each_pr_area_even_after_failure_or_cancellation(self):
        body = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))["python-package"]
        self.assertIn("git rev-parse 'HEAD^{tree}'", body)
        areas = ("lint", "python", "package")
        uploads = [step for step in body.split("\n      - ") if "actions/upload-artifact@" in step and "name: start-" not in step]
        self.assertEqual(len(uploads), len(areas))
        for area, upload in zip(areas, uploads):
            self.assertIn("name: ${{ job.status == 'success' && 'green' || 'red' }}-${{ steps.tree.outputs.tree }}-" + area, upload)
            self.assertIn("if: ${{ always() && github.event_name == 'pull_request' && steps.scope.outputs." + area, upload)
            self.assertIn("!= 'false' }}", upload)
            self.assertIn("retention-days: 7", upload)
            self.assertIn("if-no-files-found: error", upload)
            self.assertIn("overwrite: true", upload)
        self.assertIn("contents: read", body)
        self.assertIn("actions: read", body)

    def test_marker_uploads_follow_their_area_suite_and_precede_the_next_area(self):
        body = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))["python-package"]
        suites = (("bash scripts/gate.sh lint",), ("bash scripts/gate.sh python",),
                  ("BigWigsMods/packager@", "bash Tools/hooks/check-package.sh"))
        uploads = [match.start() for match in re.finditer("uses: actions/upload-artifact@", body)
                   if "name: start-" not in steps_after(body, match.start())]
        self.assertEqual(len(uploads), len(suites))
        for i, commands in enumerate(suites):
            for command in commands:
                self.assertLess(body.index(command), uploads[i], command + ": marker must follow its suite")
                if i:
                    self.assertLess(uploads[i - 1], body.index(command), command + ": previous area's marker comes first")

    def test_cancelled_pr_steps_write_red_markers(self):
        text = (WORKFLOWS / "checks.yml").read_text(encoding="utf-8")
        uploads = [step for step in text.split("\n      - ") if "uses: actions/upload-artifact@" in step and "name: start-" not in step]
        self.assertEqual(len(uploads), 3)
        for upload in uploads:
            self.assertIn("if: ${{ always() &&", upload)
            self.assertIn("job.status == 'success' && 'green' || 'red'", upload)
            self.assertNotIn("!cancelled()", upload)

    def test_tree_steps_run_even_after_scope_failure_or_cancellation(self):
        body = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))["python-package"]
        tree = body.split("id: tree", 1)[1].split("\n      - ", 1)[0]
        self.assertIn("if: ${{ always() && github.event_name == 'pull_request' }}", tree)

    def test_each_area_records_its_start_before_any_suite_work(self):
        body = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))["python-package"]
        for area, first_step in (("lint", "Check the runner's luacheck"),
                                 ("python", "Check the runner's Lua"), ("package", "Check the runner's Lua")):
            self.assertIn("id: start_" + area, body, "record the area's start before its suite")
            start = body.split("id: start_" + area, 1)[1].split("\n      - ", 1)[0]
            self.assertIn("name: start-${{ steps.tree.outputs.tree }}-" + area, start)
            self.assertIn("always() && github.event_name == 'pull_request'", start)
            self.assertIn("steps.scope.outputs." + area + " != 'false'", start)
            self.assertLess(body.index("id: tree"), body.index("id: start_" + area))
            self.assertLess(body.index("id: start_" + area), body.index("- name: " + first_step))

    def test_a_pr_suite_cannot_run_without_a_successful_start_upload(self):
        body = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))["python-package"]
        commands = (("lint", "Check the runner's luacheck"), ("lint", "Run the lint gate"),
                    ("python", "Check the runner's Python"), ("python", "Python tool tests"),
                    ("package", "Package without"), ("package", "Check the zip"))
        for area, name in commands:
            step = body.split("- name: " + name, 1)[1].split("\n      - ", 1)[0]
            self.assertIn("github.event_name != 'pull_request' || steps.start_" + area + ".outcome == 'success'", step)

    def test_push_reuse_is_a_step_decision_and_covers_lint_too(self):
        jobs = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))
        for body in jobs.values():
            self.assertIn("    if: " + FORK_GUARD + "\n", body)
        job = jobs["python-package"]
        scope = job.split("id: scope", 1)[1].split("\n      - ", 1)[0]
        self.assertIn("GITHUB_TOKEN: ${{ github.token }}", scope)
        for name in ("Check the runner's luacheck and pre-commit", "Run the lint gate"):
            step = job.split("- name: " + name, 1)[1].split("\n      - ", 1)[0]
            self.assertIn("if: steps.scope.outputs.lint != 'false'", step)

    def test_jobs_guard_fork_code_and_macs_never_run_package_managers(self):
        for path in workflows():
            text = path.read_text(encoding="utf-8")
            jobs = jobs_of(text)
            self.assertTrue(jobs, path.name)
            for job, body in jobs.items():
                if "self-hosted" in body:
                    self.assertNotRegex(body, r"\bsudo\b|apt(-get)?\s+(update|install)", f"{path.name}: {job} runs on the owner's Mac: no sudo or apt there")
                guard = re.search(r"(?m)^    if: (.*)$", body)
                self.assertIsNotNone(guard, f"{path.name}: {job} has no fork guard")
                expected = "github.event_name == 'workflow_dispatch'" if job == "discord-repost" else "github.event_name == 'push'"
                self.assertEqual(guard.group(1), expected if path.name == "release.yml" else FORK_GUARD,
                                 f"{path.name}: {job}")

    def test_only_the_mac_budget_monitor_runs_on_the_macs(self):
        for path in workflows():
            for job, body in jobs_of(path.read_text(encoding="utf-8")).items():
                runner = re.search(r"(?m)^    runs-on: (.+)$", body).group(1)
                expected = "[self-hosted, mac-ci, KstyleUI]" if path.name == "mac-budgets.yml" else "ubuntu-latest"
                self.assertEqual(runner, expected, f"{path.name}: {job}: gates run on GitHub-hosted runners; "
                                 "only mac-budgets.yml uses the Macs, and nothing requires or awaits it")

    def test_no_workflow_runs_on_an_event_that_carries_fork_code_past_the_guard(self):
        for path in workflows():
            on = path.read_text(encoding="utf-8").split("\non:\n", 1)[1].split("\n\n", 1)[0]
            events = re.findall(r"(?m)^  ([\w-]+):", on)
            self.assertTrue(events, path.name)
            self.assertTrue(set(events) <= {"pull_request", "push", "workflow_dispatch"}, f"{path.name}: {events}")

    def test_the_runner_tools_are_checked_by_version(self):
        checks = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))
        self.assertIn("luacheck --version | grep '^Luacheck: 1\\.2\\.0$'", checks["python-package"])
        self.assertIn("pre-commit --version | grep '^pre-commit 4\\.7\\.0$'", checks["python-package"])
        for job in ("lua", "python-package"):
            self.assertIn("lua5.1 -v 2>&1 | grep '^Lua 5\\.1\\.5 '", checks[job], job)
        self.assertIn("python3 --version | grep '^Python 3\\.12\\.'", checks["python-package"])
        release = jobs_of((WORKFLOWS / "release.yml").read_text(encoding="utf-8"))
        self.assertIn("lua5.1 -v 2>&1 | grep '^Lua 5\\.1\\.5 '", release["check"])
        for job in ("check", "release"):
            self.assertIn("| grep '^Pillow 13\\.0\\.0$'", release[job], job)

    def test_hosted_tools_cache_is_keyed_by_pins_and_never_restores_other_keys(self):
        job = jobs_of((WORKFLOWS / "checks.yml").read_text(encoding="utf-8"))["python-package"]
        cache = next(step for step in job.split("\n      - ") if "uses: actions/cache@" in step)
        self.assertIn("hashFiles('.pre-commit-config.yaml')", cache)
        self.assertNotIn("restore-keys:", cache)

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

    def test_title_pattern_accepts_type_scope_summary(self):
        for title in ("ci(repo): add CI workflows", "feat: add the minimap", "fix(unit-frames): keep the bar", "revert(core): undo"):
            with self.subTest(title=title):
                self.assertTrue(title_passes(title))

    def test_title_pattern_rejects_other_titles(self):
        for title in ("Add CI", "Feat: add", "feat(Core): add", "feat(core):add", "feat(core): ", "style: tidy", "feat!: break", "feat(): x"):
            with self.subTest(title=title):
                self.assertFalse(title_passes(title))

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
