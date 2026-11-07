"""Tests for Tools/hooks/check-pr.sh against a throwaway git repository."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "hooks" / "check-pr.sh"

CHANGELOG = "## Summary\nA change.\n\n## Changelog\nAdded: a thing players see.\n\n## In-game checks\n- none\n"

BASE_FILES = {
    "KstyleUI.toc": "## Interface: 16001\r\n## Notes: A UI.\r\n## Version: @project-version@\r\n\r\nCore\\Core.xml\r\n",
    "Core/Init.lua": "-- Init.lua: namespace.\r\nlocal _, ns = ...\r\nns.CODE_BUILD = 1\r\nif ns.CODE_BUILD == 1 then end\r\n",
    "Core/Core.xml": "<Ui>\r\n</Ui>\r\n",
    "Tools/regression/fixtures/toc/Fix.toc": "## Version: 1\n",
    "Tools/hooks/x.py": "print(1)\n",
    "docs/notes.md": "notes\n",
    ".github/workflows/x.yml": "on: push\n",
    "reports/r.md": "r\n",
    "research_notes/n.md": "n\n",
}


class CheckPrTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self._tmp.name)
        self.git("init", "-q", "-b", "base")
        self.write(BASE_FILES)
        self.commit("base")
        self.git("checkout", "-q", "-b", "pr")

    def tearDown(self):
        self._tmp.cleanup()

    def git(self, *args):
        return subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", *args],
            cwd=self.repo, check=True, capture_output=True, text=True,
        ).stdout

    def write(self, files):
        for rel, text in files.items():
            path = self.repo / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(text.encode())

    def commit(self, message="change"):
        self.git("add", "-A")
        self.git("commit", "-q", "--allow-empty", "-m", message)

    def change(self, files):
        self.write(files)
        self.commit()

    def run_check(self, body="", labels="", ref="base", args=None):
        env = dict(os.environ, PR_BODY=body, PR_LABELS=labels)
        argv = [os.environ.get("TEST_BASH", "bash"), str(SCRIPT)] + ([ref] if args is None else args)
        return subprocess.run(argv, cwd=self.repo, env=env, capture_output=True, text=True)

    def assertPasses(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assertFails(self, result, *needles):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        for needle in needles:
            self.assertIn(needle, result.stdout + result.stderr)

    # Changelog rule

    def test_requires_changelog_for_addon_change(self):
        self.change({"Core/Core.xml": "<Ui>\r\n<!-- x -->\r\n</Ui>\r\n"})
        self.assertFails(self.run_check(body="## Summary\nA change.\n"), "## Changelog", "Core/Core.xml")

    def test_changelog_line_passes(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        self.assertPasses(self.run_check(body=CHANGELOG))

    def test_each_changelog_prefix_passes(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        for prefix in ("Added:", "Changed:", "Fixed:", "- Fixed:", "* Changed:"):
            with self.subTest(prefix=prefix):
                self.assertPasses(self.run_check(body=f"## Changelog\n{prefix} the minimap ring.\n"))

    def test_crlf_body_passes(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        self.assertPasses(self.run_check(body=CHANGELOG.replace("\n", "\r\n")))

    def test_changelog_line_under_another_heading_fails(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        body = "## Summary\nAdded: a thing.\n\n## Changelog\n\n## In-game checks\n- none\n"
        self.assertFails(self.run_check(body=body), "## Changelog")

    def test_subheading_keeps_the_changelog_section(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        self.assertPasses(self.run_check(body="## Changelog\n### Player-facing\nChanged: bar colours.\n"))

    def test_empty_changelog_entry_fails(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        self.assertFails(self.run_check(body="## Changelog\nAdded:\n"), "## Changelog")

    def test_other_prefix_fails(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        self.assertFails(self.run_check(body="## Changelog\nRemoved: a thing.\n"), "## Changelog")

    def test_changelog_line_inside_html_comment_fails(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        body = "## Changelog\n<!--\nAdded: a placeholder.\n-->\n"
        self.assertFails(self.run_check(body=body), "## Changelog")

    def test_text_after_a_comment_on_the_same_line_counts(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        self.assertPasses(self.run_check(body="## Changelog\n<!-- one line -->Fixed: the bag sort.\n"))

    def test_docs_only_needs_no_changelog(self):
        self.change({"docs/notes.md": "more notes\n"})
        self.assertPasses(self.run_check())

    def test_tooling_folders_need_no_changelog(self):
        self.change({
            "Tools/hooks/x.py": "print(2)\n",
            ".github/workflows/x.yml": "on: pull_request\n",
            "reports/r.md": "r2\n",
            "research_notes/n.md": "n2\n",
        })
        self.assertPasses(self.run_check())

    def test_root_file_needs_changelog(self):
        self.change({"AGENTS.md": "rules\n"})
        self.assertFails(self.run_check(), "AGENTS.md")

    def test_moving_a_file_out_of_tools_counts_as_shipped(self):
        self.git("mv", "Tools/hooks/x.py", "x.py")
        self.commit()
        self.assertFails(self.run_check(), "x.py")

    def test_no_changelog_label_passes(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        self.assertPasses(self.run_check(labels="agent,no changelog"))

    def test_no_changelog_label_ignores_case_and_spaces(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        self.assertPasses(self.run_check(labels="agent, No Changelog \nrelease"))

    def test_label_must_match_whole_name(self):
        self.change({"Core/Core.xml": "<Ui/>\r\n"})
        self.assertFails(self.run_check(labels="no changelog needed"), "## Changelog")

    # Release rule

    def test_version_change_needs_release_label(self):
        toc = BASE_FILES["KstyleUI.toc"].replace("@project-version@", "1.0.0")
        self.change({"KstyleUI.toc": toc})
        self.assertFails(self.run_check(body=CHANGELOG), "KstyleUI.toc", "release")
        self.assertPasses(self.run_check(body=CHANGELOG, labels="release"))

    def test_code_build_change_needs_release_label(self):
        self.change({"Core/Init.lua": BASE_FILES["Core/Init.lua"].replace("CODE_BUILD = 1", "CODE_BUILD = 2")})
        self.assertFails(self.run_check(body=CHANGELOG), "Core/Init.lua", "CODE_BUILD")
        self.assertPasses(self.run_check(body=CHANGELOG, labels="release"))

    def test_removing_the_version_line_needs_release_label(self):
        self.change({"KstyleUI.toc": BASE_FILES["KstyleUI.toc"].replace("## Version: @project-version@\r\n", "")})
        self.assertFails(self.run_check(body=CHANGELOG), "KstyleUI.toc")

    def test_other_toc_and_lua_lines_need_no_release_label(self):
        self.change({
            "KstyleUI.toc": BASE_FILES["KstyleUI.toc"].replace("A UI.", "A complete UI."),
            "Core/Init.lua": BASE_FILES["Core/Init.lua"].replace("== 1", "== 2"),
        })
        self.assertPasses(self.run_check(body=CHANGELOG))

    def test_line_ending_change_on_the_version_line_needs_no_release_label(self):
        self.change({"KstyleUI.toc": BASE_FILES["KstyleUI.toc"].replace("\r\n", "\n")})
        self.assertPasses(self.run_check(body=CHANGELOG))

    def test_new_module_toc_needs_no_release_label(self):
        self.change({"KstyleUI_Foo/KstyleUI_Foo.toc": "## Interface: 16001\r\n## Version: @project-version@\r\n"})
        self.assertPasses(self.run_check(body=CHANGELOG))

    def test_version_change_in_tools_needs_no_release_label(self):
        self.change({"Tools/regression/fixtures/toc/Fix.toc": "## Version: 2\n"})
        self.assertPasses(self.run_check())

    def test_renaming_a_file_while_changing_code_build_needs_release_label(self):
        self.git("mv", "Core/Init.lua", "Core/Boot.lua")
        self.change({"Core/Boot.lua": BASE_FILES["Core/Init.lua"].replace("CODE_BUILD = 1", "CODE_BUILD = 2")})
        self.assertFails(self.run_check(body=CHANGELOG), "CODE_BUILD")

    def test_moving_code_build_into_a_rewritten_file_needs_release_label(self):
        self.git("rm", "-q", "Core/Init.lua")
        self.change({"Core/Namespace.lua": "-- Namespace.lua: other.\r\nlocal _, ns = ...\r\nns.Modules = {}\r\nns.CODE_BUILD = 2\r\n"})
        self.assertFails(self.run_check(body=CHANGELOG), "CODE_BUILD")

    def test_renaming_a_toc_while_changing_its_version_needs_release_label(self):
        self.git("mv", "KstyleUI.toc", "KstyleUI_Mainline.toc")
        self.change({"KstyleUI_Mainline.toc": BASE_FILES["KstyleUI.toc"].replace("@project-version@", "1.0.0")})
        self.assertFails(self.run_check(body=CHANGELOG), "## Version")

    def test_renaming_a_file_without_changing_code_build_passes(self):
        self.git("mv", "Core/Init.lua", "Core/Boot.lua")
        self.commit()
        self.assertPasses(self.run_check(body=CHANGELOG))

    def test_reports_both_rules_at_once(self):
        self.change({"Core/Init.lua": BASE_FILES["Core/Init.lua"].replace("CODE_BUILD = 1", "CODE_BUILD = 2")})
        self.assertFails(self.run_check(), "## Changelog", "CODE_BUILD")

    # Base ref

    def test_compares_with_the_merge_base(self):
        self.change({"docs/notes.md": "pr notes\n"})
        self.git("checkout", "-q", "base")
        self.change({"KstyleUI.toc": BASE_FILES["KstyleUI.toc"].replace("@project-version@", "1.0.0")})
        self.git("checkout", "-q", "pr")
        self.assertPasses(self.run_check())

    def test_unknown_ref_exits_2(self):
        result = self.run_check(ref="origin/nope")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("origin/nope", result.stderr)

    def test_missing_ref_exits_2(self):
        self.assertEqual(self.run_check(args=[]).returncode, 2)


if __name__ == "__main__":
    unittest.main()
