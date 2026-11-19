"""Tests for Tools/hooks/ci_scope.py: which CI jobs a pull request can skip."""

import contextlib
import http.client
import importlib.util
import io
import json
import os
import re
import subprocess
import tempfile
import unittest
import urllib.parse
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "hooks" / "ci_scope.py"
spec = importlib.util.spec_from_file_location("ci_scope", SCRIPT)
ci_scope = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci_scope)

GIT_ENV = {
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.com",
    "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.com",
    "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_SYSTEM": os.devnull,
}


class DecideTest(unittest.TestCase):
    def run_for(self, area, *paths, event="pull_request"):
        return ci_scope.decide(area, event, list(paths))[0]

    def test_docs_and_markdown_skip_every_area(self):
        for area in ci_scope.AREAS:
            with self.subTest(area=area):
                self.assertFalse(self.run_for(area, "docs/design/notes.md", "reports/r.md",
                                              "research_notes/x.md", "AGENTS.md", "Tools/regression/README.md"))

    def test_the_readme_and_its_pictures_run_the_python_job_only(self):
        for path in ("README.md", "docs/media/readme/a.png"):
            with self.subTest(path=path):
                self.assertTrue(self.run_for("python", path))
                self.assertFalse(self.run_for("lua", path))
                self.assertFalse(self.run_for("package", path))

    def test_addon_code_runs_lua_python_and_package(self):
        for area in ci_scope.AREAS:
            with self.subTest(area=area):
                self.assertTrue(self.run_for(area, "KstyleUI_Chat/Panel.lua"))

    def test_a_doc_that_a_test_reads_is_not_inert(self):
        for path in ("docs/superpowers/plans/element-keys.md", "Media/PROVENANCE.md", "Tools/icons/setB/PROVENANCE.md",
                     "LICENSE.md", ".github/PULL_REQUEST_TEMPLATE.md", "KstyleUI_Chat/README.md", "Core/README.md"):
            with self.subTest(path=path):
                self.assertTrue(self.run_for("lua", path) and self.run_for("python", path))

    def test_markdown_inside_an_addon_folder_ships_so_it_is_not_inert(self):
        self.assertTrue(self.run_for("package", "KstyleUI_Chat/NOTES.md", "Core/NOTES.md", "Media/NOTES.md"))

    def test_the_package_ignores_what_pkgmeta_ignores_and_the_dev_tools(self):
        self.assertFalse(self.run_for("package", "Tools/render/shoot.sh", ".github/dependabot.yml", ".luacheckrc",
                                      ".pre-commit-config.yaml", "KstyleUI_Chat/README.md"))

    def test_the_package_reads_its_own_check_and_the_toc_walker(self):
        for path in ("Tools/hooks/check-package.sh", "Tools/regression/toc_files.lua", ".pkgmeta", "KstyleUI.toc", "LICENSE.md"):
            with self.subTest(path=path):
                self.assertTrue(self.run_for("package", path))

    def test_the_lua_tests_ignore_workflows_and_python_tests(self):
        self.assertFalse(self.run_for("lua", ".github/workflows/pr-rules.yml", "Tools/tests/test_ci_scope.py"))
        self.assertTrue(self.run_for("python", ".github/workflows/pr-rules.yml"))
        self.assertTrue(self.run_for("lua", "Tools/locale/enUS.json", ".luacheckrc", ".pkgmeta"))

    def test_the_pipeline_files_run_every_area(self):
        for area in ci_scope.AREAS:
            for path in ci_scope.PIPELINE:
                with self.subTest(area=area, path=path):
                    self.assertTrue(self.run_for(area, path))

    def test_one_runnable_file_among_docs_runs(self):
        decision, reason = ci_scope.decide("lua", "pull_request", ["docs/a.md", "Core/Scale.lua", "docs/b.md"])
        self.assertTrue(decision)
        self.assertIn("Core/Scale.lua", reason)

    def test_anything_but_a_pull_request_runs_everything(self):
        for event in ("push", "workflow_dispatch", ""):
            for area in ci_scope.AREAS:
                with self.subTest(event=event, area=area):
                    self.assertTrue(self.run_for(area, "docs/a.md", event=event))

    def test_unreadable_or_empty_changes_run(self):
        self.assertTrue(ci_scope.decide("lua", "pull_request", None)[0])
        self.assertTrue(ci_scope.decide("lua", "pull_request", [])[0])

    def test_a_skip_names_the_files_and_says_it_succeeds(self):
        decision, reason = ci_scope.decide("lua", "pull_request", ["docs/a.md"])
        self.assertFalse(decision)
        self.assertIn("docs/a.md", reason)
        self.assertIn("success", reason)


class ReadByTestsTest(unittest.TestCase):
    def test_no_existing_doc_path_that_a_test_names_is_inert(self):
        repo = SCRIPT.parents[2]
        pattern = re.compile(r"(?:docs|research_notes|reports)/[\w./-]*[\w]")
        sources = list((repo / "Tools" / "tests").glob("*.py")) + list((repo / "Tools" / "regression").glob("*.lua"))
        for source in sources:
            for path in pattern.findall(source.read_text(encoding="utf-8", errors="replace")):
                if not (repo / path).exists():
                    continue
                for area in ("lua", "python"):
                    with self.subTest(source=source.name, path=path, area=area):
                        self.assertFalse(ci_scope.is_inert(area, path), f"{source.name} names {path}: list it in READ_BY_TESTS")


class PushProofTest(unittest.TestCase):
    def scope(self, *, artifacts=None, run=None, area="python", event="push", error=None, env=None, total_count=None):
        tree = "a" * 40
        marker = {"id": 2, "name": f"green-{tree}-python", "created_at": "2026-11-16T12:00:00Z",
                  "expired": False, "workflow_run": {"id": 123}}
        proof = {"id": 123, "path": ".github/workflows/checks.yml", "event": "pull_request",
                 "status": "completed", "conclusion": "success",
                 "head_repository": {"full_name": "korallis/KstyleUI"}}
        calls = []

        def api(path):
            calls.append(path)
            if error:
                raise error
            if "/artifacts?" in path:
                items = artifacts if artifacts is not None else [marker]
                name = urllib.parse.parse_qs(urllib.parse.urlparse(path).query)["name"][0]
                items = [item for item in items if item.get("name") == name]
                return {"artifacts": items, "total_count": len(items) if total_count is None else total_count}
            return run if run is not None else proof

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "out"
            settings = dict(GITHUB_EVENT_NAME=event, GITHUB_REF="refs/heads/staging",
                            GITHUB_REPOSITORY="korallis/KstyleUI", GITHUB_TOKEN="test",
                            SHARD="1", SHARD_TOTAL="2", GITHUB_OUTPUT=str(output))
            settings.update(env or {})
            stdout = io.StringIO()
            with mock.patch.dict(os.environ, settings), \
                    mock.patch.object(ci_scope, "current_tree", return_value=tree), \
                    mock.patch.object(ci_scope, "github_json", side_effect=api), \
                    mock.patch.object(ci_scope, "changed_paths", return_value=["docs/a.md"]), \
                    contextlib.redirect_stdout(stdout):
                self.assertEqual(ci_scope.main([area]), 0)
            return output.read_text(), stdout.getvalue(), calls

    def test_successful_pr_proof_skips_the_exact_tree_and_area(self):
        output, log, calls = self.scope()
        self.assertEqual(output, "run=false\n")
        self.assertIn("tree " + "a" * 40 + ", area python passed in run 123: skipping", log)
        self.assertIn("name=green-" + "a" * 40 + "-python", calls[0])

    def test_failed_cancelled_or_incomplete_latest_attempt_runs(self):
        for conclusion, status in (("failure", "completed"), ("cancelled", "completed"), (None, "in_progress")):
            with self.subTest(conclusion=conclusion):
                self.assertEqual(self.scope(run={"path": ".github/workflows/checks.yml", "event": "pull_request",
                                                "status": status, "conclusion": conclusion})[0], "run=true\n")

    def test_lua_never_reuses_hosted_proof_on_staging(self):
        for total in (2, 6, 8):
            marker = {"name": "green-" + "a" * 40 + f"-lua-1-of-{total}"}
            output, log, calls = self.scope(area="lua", artifacts=[marker])
            self.assertEqual(output, "run=true\n")
            self.assertIn("Mac CPU and cumulative instruction budgets", log)
            self.assertEqual(calls, [])

    def test_a_partial_artifact_page_cannot_prove_which_marker_is_newest(self):
        self.assertEqual(self.scope(total_count=101)[0], "run=true\n")

    def test_a_different_tree_expired_marker_or_missing_proof_runs(self):
        for markers in ([], [{"name": "green-" + "b" * 40 + "-python"}],
                        [{"id": 2, "name": "green-" + "a" * 40 + "-python", "expired": True,
                          "created_at": "2026-11-16T12:00:00Z", "workflow_run": {"id": 123}}]):
            with self.subTest(markers=markers):
                output, log, _ = self.scope(artifacts=markers)
                self.assertEqual(output, "run=true\n")
                self.assertIn("staging moved or no proof: running", log)

    def test_a_fork_pr_cannot_prove_a_tree(self):
        run = {"id": 123, "path": ".github/workflows/checks.yml", "event": "pull_request",
               "status": "completed", "conclusion": "success", "head_repository": {"full_name": "attacker/KstyleUI"}}
        self.assertEqual(self.scope(run=run)[0], "run=true\n")

    def test_a_newer_red_marker_beats_an_older_green(self):
        markers = [{"id": i, "name": colour + "-" + "a" * 40 + "-python", "expired": False,
                    "created_at": f"2026-11-16T12:00:0{i}Z", "workflow_run": {"id": i}}
                   for i, colour in ((1, "green"), (2, "red"))]
        output, _, _ = self.scope(artifacts=markers)
        self.assertEqual(output, "run=true\n")

    def test_a_start_without_an_end_blocks_an_older_green(self):
        markers = [{"id": i, "name": kind + "-" + "a" * 40 + "-python", "expired": False,
                    "created_at": f"2026-11-16T12:00:0{i}Z", "workflow_run": {"id": i}}
                   for i, kind in ((1, "green"), (2, "start"))]
        self.assertEqual(self.scope(artifacts=markers)[0], "run=true\n")

    def test_a_newer_green_after_its_start_can_skip(self):
        markers = [{"id": i, "name": kind + "-" + "a" * 40 + "-python", "expired": False,
                    "created_at": f"2026-11-16T12:00:0{i}Z", "workflow_run": {"id": 123}}
                   for i, kind in ((1, "start"), (2, "green"))]
        output, _, calls = self.scope(artifacts=markers)
        self.assertEqual(output, "run=false\n")
        self.assertTrue(any("name=start-" in call for call in calls))

    def test_a_newer_green_marker_after_an_older_red_can_skip(self):
        markers = [{"id": i, "name": colour + "-" + "a" * 40 + "-python", "expired": False,
                    "created_at": f"2026-11-16T12:00:0{i}Z", "workflow_run": {"id": 123}}
                   for i, colour in ((1, "red"), (2, "green"))]
        output, _, calls = self.scope(artifacts=markers)
        self.assertEqual(output, "run=false\n")
        self.assertTrue(any("name=red-" in call for call in calls))

    def test_markers_with_the_same_timestamp_cannot_prove_which_is_newest(self):
        for colours in (("green", "red"), ("green", "green"), ("green", "start")):
            markers = [{"id": i, "name": colour + "-" + "a" * 40 + "-python", "expired": False,
                        "created_at": "2026-11-16T12:00:00Z", "workflow_run": {"id": 123}}
                       for i, colour in enumerate(colours, 1)]
            with self.subTest(colours=colours):
                self.assertEqual(self.scope(artifacts=markers)[0], "run=true\n")

    def test_newest_marker_must_pass_even_if_an_older_marker_did(self):
        markers = [{"id": i, "name": "green-" + "a" * 40 + "-python", "expired": False,
                    "created_at": f"2026-11-16T12:00:0{i}Z", "workflow_run": {"id": i}} for i in (1, 2)]
        output, _, calls = self.scope(artifacts=markers, run={"conclusion": "failure"})
        self.assertEqual(output, "run=true\n")
        self.assertTrue(calls[-1].endswith("/runs/2"))

    def test_wrong_workflow_or_event_cannot_prove_a_tree(self):
        for path, event in ((".github/workflows/release.yml", "pull_request"), (".github/workflows/checks.yml", "push")):
            self.assertEqual(self.scope(run={"path": path, "event": event, "status": "completed", "conclusion": "success"})[0], "run=true\n")

    def test_api_or_malformed_response_errors_run(self):
        for error in (OSError("offline"), http.client.IncompleteRead(b""), json.JSONDecodeError("bad", "", 0)):
            output, log, _ = self.scope(error=error)
            self.assertEqual(output, "run=true\n")
            self.assertIn("staging moved or no proof: running", log)
        self.assertEqual(self.scope(artifacts=[{}])[0], "run=true\n")

    def test_pr_scope_and_manual_runs_do_not_query_proof(self):
        for event, expected in (("pull_request", "false"), ("workflow_dispatch", "true")):
            output, _, calls = self.scope(event=event)
            self.assertEqual(output, f"run={expected}\n")
            self.assertEqual(calls, [])

    def test_combined_job_checks_lint_python_and_package_independently(self):
        marker = {"id": 2, "name": "green-" + "a" * 40 + "-python", "created_at": "2026-11-16T12:00:00Z",
                  "expired": False, "workflow_run": {"id": 123}}
        output, _, _ = self.scope(area="all", artifacts=[marker])
        self.assertEqual(output, "lint=true\nlua=true\npython=false\npackage=true\n")

    def test_each_non_sharded_area_can_reuse_proof(self):
        for area in ("lint", "python", "package"):
            marker = {"id": 2, "name": "green-" + "a" * 40 + "-" + area,
                      "created_at": "2026-11-16T12:00:00Z", "expired": False, "workflow_run": {"id": 123}}
            with self.subTest(area=area):
                self.assertEqual(self.scope(area=area, artifacts=[marker])[0], "run=false\n")


class ShaProofTest(unittest.TestCase):
    def scope(self, runs=None, error=None):
        proof = {"id": 123, "path": ".github/workflows/checks.yml", "event": "push",
                 "head_sha": "a" * 40, "created_at": "2026-11-16T12:00:00Z",
                 "status": "completed", "conclusion": "success",
                 "head_repository": {"full_name": "korallis/KstyleUI"}}
        elapsed = 0
        self.waits = []

        def sleep(seconds):
            nonlocal elapsed
            self.assertGreater(seconds, 0)
            self.assertLessEqual(seconds, 15)
            self.waits.append(seconds)
            elapsed += seconds

        clock = mock.Mock()
        clock.monotonic.side_effect = lambda: elapsed
        clock.sleep.side_effect = sleep

        def api(path):
            if error:
                raise error
            return {"workflow_runs": runs(proof) if runs else [proof]}

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "out"
            stdout = io.StringIO()
            with mock.patch.dict(os.environ, GITHUB_REPOSITORY="korallis/KstyleUI", GITHUB_SHA="a" * 40,
                                 GITHUB_OUTPUT=str(output)), \
                    mock.patch.object(ci_scope, "github_json", side_effect=api) as request, \
                    mock.patch.object(ci_scope, "time", clock, create=True), contextlib.redirect_stdout(stdout):
                self.assertEqual(ci_scope.main(["proven-sha"]), 0)
            self.requests = request.call_count
            return output.read_text(), stdout.getvalue(), request.call_args.args[0]

    def test_waits_for_a_queued_or_running_push_to_succeed(self):
        for status in ("queued", "in_progress"):
            with self.subTest(status=status):
                statuses = iter((status, "completed"))
                output, log, _ = self.scope(lambda run: [dict(run, status=next(statuses))])
                self.assertEqual(output, "run=false\n")
                self.assertEqual(self.waits, [15])
                self.assertIn(f"waiting for checks.yml push run 123 ({status})", log)

    def test_waits_for_a_running_push_to_fail_before_running_the_shards(self):
        statuses = iter(("in_progress", "completed"))
        output, log, _ = self.scope(lambda run: [dict(run, status=next(statuses), conclusion="failure")])
        self.assertEqual(output, "run=true\n")
        self.assertEqual(self.waits, [15])
        self.assertIn("completed/failure", log)

    def test_waiting_times_out_after_fifteen_minutes_and_runs_the_shards(self):
        for final_status in ("in_progress", "completed"):
            with self.subTest(final_status=final_status):
                requests = 0

                def runs(run):
                    nonlocal requests
                    requests += 1
                    return [dict(run, status=final_status if requests == 61 else "in_progress")]

                output, log, _ = self.scope(runs)
                self.assertEqual(output, "run=true\n")
                self.assertEqual(self.waits, [15] * 60)
                self.assertEqual(self.requests, 61)
                self.assertIn("timed out waiting for checks.yml push run 123 after 900s", log)

    def test_api_error_while_waiting_runs_the_shards(self):
        def runs(run):
            if self.waits:
                raise OSError("offline")
            return [dict(run, status="in_progress", conclusion=None)]

        output, log, _ = self.scope(runs)
        self.assertEqual(output, "run=true\n")
        self.assertEqual(self.waits, [15])
        self.assertIn("API error", log)

    def test_only_a_success_conclusion_proves_a_sha(self):
        for conclusion in ("failure", "cancelled", "timed_out", "skipped", "neutral", "action_required",
                           "stale", "startup_failure", None):
            with self.subTest(conclusion=conclusion):
                self.assertEqual(self.scope(lambda run: [dict(run, conclusion=conclusion)])[0], "run=true\n")

    def test_successful_push_proves_the_exact_sha(self):
        output, log, path = self.scope()
        self.assertEqual(output, "run=false\n")
        self.assertIn("123", log)
        query = urllib.parse.parse_qs(urllib.parse.urlparse(path).query)
        self.assertEqual(query["head_sha"], ["a" * 40])
        self.assertEqual(query["event"], ["push"])
        self.assertTrue(path.startswith("/repos/korallis/KstyleUI/actions/runs?"))

    def test_failed_cancelled_in_progress_or_missing_push_runs(self):
        for status, conclusion in (("completed", "failure"), ("completed", "cancelled"), ("in_progress", None)):
            with self.subTest(status=status, conclusion=conclusion):
                output, log, _ = self.scope(lambda run: [dict(run, status=status, conclusion=conclusion)])
                self.assertEqual(output, "run=true\n")
                self.assertIn(str(conclusion or status), log)
        self.assertEqual(self.scope(lambda run: [])[0], "run=true\n")

    def test_an_older_success_cannot_hide_the_newest_failed_or_running_push(self):
        for status, conclusion in (("completed", "failure"), ("completed", "cancelled"), ("in_progress", None)):
            with self.subTest(status=status, conclusion=conclusion):
                runs = lambda run: [run, dict(run, id=124, created_at="2026-11-16T13:00:00Z",
                                              status=status, conclusion=conclusion)]
                self.assertEqual(self.scope(runs)[0], "run=true\n")

    def test_other_workflows_forks_events_or_shas_cannot_prove_the_sha(self):
        for changes in ({"path": ".github/workflows/release.yml"},
                        {"head_repository": {"full_name": "attacker/KstyleUI"}},
                        {"event": "pull_request"}, {"head_sha": "b" * 40}):
            with self.subTest(changes=changes):
                self.assertEqual(self.scope(lambda run: [dict(run, **changes)])[0], "run=true\n")

    def test_unrelated_newer_runs_do_not_hide_a_successful_checks_push(self):
        output, _, _ = self.scope(lambda run: [dict(run, id=124, path=".github/workflows/release.yml",
                                                   created_at="2026-11-16T13:00:00Z"), run])
        self.assertEqual(output, "run=false\n")

    def test_api_errors_or_malformed_results_run_the_shards(self):
        for error in (OSError("offline"), http.client.IncompleteRead(b""), json.JSONDecodeError("bad", "", 0)):
            with self.subTest(error=error):
                output, log, _ = self.scope(error=error)
                self.assertEqual(output, "run=true\n")
                self.assertIn("API", log)
        self.assertEqual(self.scope(lambda run: [{}])[0], "run=true\n")


class MainTest(unittest.TestCase):
    """Run the script in a repository that holds a pull request's merge commit."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self._tmp.name)
        self.git("init", "-q", "-b", "staging")
        self.commit("base", {"Core/Init.lua": "a\n", "docs/a.md": "a\n"})

    def tearDown(self):
        self._tmp.cleanup()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, env=dict(os.environ, **GIT_ENV), check=True,
                              capture_output=True, text=True).stdout

    def commit(self, message, files):
        for name, text in files.items():
            (self.repo / name).parent.mkdir(parents=True, exist_ok=True)
            (self.repo / name).write_text(text)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)

    def merge_of(self, files):
        self.git("checkout", "-q", "-b", "pr")
        self.commit("pr", files)
        self.git("checkout", "-q", "staging")
        self.commit("other", {"unrelated.txt": "x\n"})
        self.git("merge", "-q", "--no-ff", "-m", "merge", "pr")

    def scope(self, area, event="pull_request"):
        output = self.repo / "out"
        env = dict(os.environ, GITHUB_EVENT_NAME=event, GITHUB_OUTPUT=str(output))
        result = subprocess.run(["python3", str(SCRIPT), area], cwd=self.repo, env=env, capture_output=True, text=True)
        return result, output.read_text() if output.exists() else ""

    def test_a_docs_only_pull_request_skips_with_a_success(self):
        self.merge_of({"docs/a.md": "b\n"})
        result, output = self.scope("lua")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "run=false\n")
        self.assertIn("skip", result.stdout)
        self.assertNotIn("unrelated.txt", result.stdout)

    def test_a_code_pull_request_runs(self):
        self.merge_of({"Core/Init.lua": "b\n"})
        result, output = self.scope("lua")
        self.assertEqual(output, "run=true\n")
        self.assertIn("Core/Init.lua", result.stdout)

    def test_a_push_runs_whatever_changed(self):
        self.merge_of({"docs/a.md": "b\n"})
        self.assertEqual(self.scope("lua", event="push")[1], "run=true\n")

    def test_a_commit_without_a_second_parent_runs(self):
        self.commit("plain", {"docs/a.md": "b\n"})
        self.assertEqual(self.scope("lua")[1], "run=true\n")

    def test_a_rename_into_an_inert_folder_counts_its_source(self):
        self.git("checkout", "-q", "-b", "pr")
        self.git("mv", "Core/Init.lua", "docs/Init.md")
        self.git("commit", "-q", "-m", "move")
        self.git("checkout", "-q", "staging")
        self.commit("other", {"unrelated.txt": "x\n"})
        self.git("merge", "-q", "--no-ff", "-m", "merge", "pr")
        result, output = self.scope("lua")
        self.assertEqual(output, "run=true\n")
        self.assertIn("Core/Init.lua", result.stdout)

    def test_all_writes_one_output_per_area(self):
        self.merge_of({"docs/a.md": "b\n", "README.md": "c\n"})
        result, output = self.scope("all")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "lint=true\nlua=false\npython=true\npackage=false\n")

    def test_all_runs_every_area_for_code(self):
        self.merge_of({"Core/Init.lua": "b\n"})
        self.assertEqual(self.scope("all")[1], "lint=true\nlua=true\npython=true\npackage=true\n")

    def test_all_runs_every_area_for_a_push(self):
        self.merge_of({"docs/a.md": "b\n"})
        self.assertEqual(self.scope("all", event="push")[1], "lint=true\nlua=true\npython=true\npackage=true\n")

    def test_a_mixed_pull_request_runs_what_any_of_its_files_reach(self):
        self.merge_of({"docs/a.md": "b\n", "Media/Textures/Dot.png": "x\n"})
        self.assertEqual(self.scope("all")[1], "lint=true\nlua=true\npython=true\npackage=true\n")

    def test_a_bad_area_is_a_usage_error(self):
        result, _ = self.scope("bogus")
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
