"""Tests for Tools/hooks/ci_scope.py: which CI jobs a pull request can skip."""

import importlib.util
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

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

    def test_a_bad_area_is_a_usage_error(self):
        result, _ = self.scope("bogus")
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
