"""Release proof must refuse known-red checks and run missing gates."""

import contextlib
import io
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

try:
    from Tools.release import proof
except ImportError:
    from Tools.hooks import ci_scope as proof
from Tools.tests.test_workflows import WORKFLOWS, jobs_of


class ReleaseProofTest(unittest.TestCase):
    def run_proof(self, runs=None, error=None):
        run = {"id": 123, "path": ".github/workflows/checks.yml", "event": "push",
               "head_sha": "a" * 40, "head_branch": "staging", "created_at": "2026-11-20T05:58:53Z",
               "status": "completed", "conclusion": "success",
               "head_repository": {"full_name": "korallis/KstyleUI"}}
        elapsed = 0

        def sleep(seconds):
            nonlocal elapsed
            elapsed += seconds

        clock = mock.Mock()
        clock.monotonic.side_effect = lambda: elapsed
        clock.sleep.side_effect = sleep
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "out"
            log = io.StringIO()
            with mock.patch.dict(os.environ, GITHUB_REPOSITORY="korallis/KstyleUI", GITHUB_SHA="a" * 40,
                                 GITHUB_OUTPUT=str(output)), \
                    mock.patch.object(proof, "github_json", side_effect=error,
                                      return_value={"workflow_runs": runs(run) if runs else [run]}), \
                    mock.patch.object(proof, "time", clock), contextlib.redirect_stdout(log):
                result = proof.main(["proven-sha"]) if proof.__name__.endswith("ci_scope") else proof.main()
            return result, output.read_text() if output.exists() else "", log.getvalue()

    def test_latest_red_refuses_even_after_an_older_green(self):
        result, output, log = self.run_proof(lambda run: [run, dict(run, id=124, conclusion="failure")])
        self.assertEqual(result, 1)
        self.assertEqual(output, "")
        self.assertIn("124", log)
        self.assertIn("failure", log)

    def test_latest_green_allows_release_and_reuses_checks(self):
        result, output, _ = self.run_proof(lambda run: [dict(run, id=122, conclusion="failure"), run])
        self.assertEqual((result, output), (0, "run=false\n"))

    def test_missing_proof_runs_checks(self):
        self.assertEqual(self.run_proof(lambda run: [])[:2], (0, "run=true\n"))

    def test_hotfix_failure_also_refuses(self):
        self.assertEqual(self.run_proof(lambda run: [dict(run, head_branch="hotfix/repair", conclusion="failure")])[0], 1)

    def test_other_workflows_events_repositories_or_shas_cannot_prove_release(self):
        for changes in ({"path": ".github/workflows/release.yml"}, {"event": "pull_request"},
                        {"head_repository": {"full_name": "fork/KstyleUI"}}, {"head_sha": "b" * 40}):
            with self.subTest(changes=changes):
                self.assertEqual(self.run_proof(lambda run: [dict(run, **changes)])[:2], (0, "run=true\n"))

    def test_api_error_or_wait_timeout_runs_checks(self):
        self.assertEqual(self.run_proof(error=OSError("offline"))[:2], (0, "run=true\n"))
        self.assertEqual(self.run_proof(lambda run: [dict(run, status="in_progress", conclusion=None)])[:2],
                         (0, "run=true\n"))

    def test_rerun_failure_is_not_hidden_by_its_old_success(self):
        self.assertEqual(self.run_proof(lambda run: [dict(run, run_attempt=2, conclusion="failure")])[0], 1)

    def test_workflow_runs_missing_gates_and_requires_the_proof_before_upload(self):
        jobs = jobs_of((WORKFLOWS / "release.yml").read_text(encoding="utf-8"))
        check = jobs["check"]
        self.assertIn("python3 -m Tools.release.proof", check)
        self.assertIn("actions: read", check)
        for command in ("bash scripts/gate.sh lint", "bash scripts/gate.sh python"):
            step = next(step for step in check.split("\n      - ") if command in step)
            self.assertIn("if: steps.proof.outputs.run != 'false'", step)
            self.assertNotIn("continue-on-error", step)
        self.assertLess(check.index("python3 -m Tools.release.proof"), check.index("bash scripts/gate.sh lint"))
        self.assertIn("run: ${{ steps.proof.outputs.run }}", check)
        self.assertIn("needs: check", jobs["lua"])
        self.assertIn("if: needs.check.outputs.run != 'false'", jobs["lua"])
        self.assertIn("needs: [check, lua]", jobs["release"])


if __name__ == "__main__":
    unittest.main()
