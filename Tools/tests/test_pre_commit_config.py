"""Tests for .pre-commit-config.yaml: pinned hooks and the addon pattern hooks."""

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CONFIG = REPO / ".pre-commit-config.yaml"

REPO_LINE = re.compile(r"^  - repo: (\S+)$")
REV_LINE = re.compile(r"^    rev: (\S+)(.*)$")
ID_LINE = re.compile(r"^      - id: (\S+)$")
KEY_LINE = re.compile(r"^        (\w+): (.*)$")


def unquote(value):
    """Return a YAML scalar as text. Single-quoted scalars keep backslashes literally."""
    value = value.strip()
    if value.startswith("'") and value.endswith("'"):
        return value[1:-1].replace("''", "'")
    return value


def read_config():
    """Return (repos, hooks): [(url, rev, comment)] and {hook id: {key: value}}."""
    repos, hooks = [], {}
    current = None
    for line in CONFIG.read_text(encoding="utf-8").splitlines():
        if match := REPO_LINE.match(line):
            repos.append([match.group(1), None, ""])
        elif match := REV_LINE.match(line):
            repos[-1][1:] = [match.group(1), match.group(2).strip()]
        elif match := ID_LINE.match(line):
            current = hooks.setdefault(match.group(1), {})
        elif (match := KEY_LINE.match(line)) and current is not None:
            current[match.group(1)] = unquote(match.group(2))
    return repos, hooks


def pygrep(hook, data):
    """Return True when pre-commit's pygrep would report a match for this hook in data."""
    flags = re.MULTILINE if "--multiline" in hook.get("args", "") else 0
    return re.search(hook["entry"].encode(), data, flags) is not None


class PreCommitConfigTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repos, cls.hooks = read_config()

    def test_every_remote_hook_is_pinned_by_full_sha_with_its_version(self):
        remote = [repo for repo in self.repos if repo[0] != "local"]
        self.assertGreaterEqual(len(remote), 4)
        for url, rev, comment in remote:
            self.assertRegex(rev or "", r"^[0-9a-f]{40}$", url)
            self.assertRegex(comment, r"^# frozen: v\d", url)

    def test_has_every_planned_hook(self):
        planned = {
            "check-merge-conflict", "check-yaml", "check-xml", "check-case-conflict", "detect-private-key",
            "trailing-whitespace", "check-added-large-files", "mixed-line-ending", "actionlint", "zizmor",
            "conventional-pre-commit", "luacheck", "addon-crlf", "addon-ascii", "no-goto", "toc-files",
        }
        self.assertLessEqual(planned, set(self.hooks))

    def test_addon_crlf_finds_a_bare_line_feed(self):
        hook = self.hooks["addon-crlf"]
        self.assertTrue(pygrep(hook, b"local a = 1\nlocal b = 2\r\n"))
        self.assertFalse(pygrep(hook, b"local a = 1\r\nlocal b = 2\r\n"))

    def test_addon_ascii_finds_a_non_ascii_byte(self):
        hook = self.hooks["addon-ascii"]
        self.assertTrue(pygrep(hook, 'local s = "café"\r\n'.encode("utf-8")))
        self.assertFalse(pygrep(hook, b'local s = "cafe"\r\n'))

    def test_no_goto_finds_goto_and_labels_only(self):
        hook = self.hooks["no-goto"]
        self.assertTrue(pygrep(hook, b"goto continue\r\n"))
        self.assertTrue(pygrep(hook, b"::continue::\r\n"))
        self.assertFalse(pygrep(hook, b"local gotoTarget = Frame:GetName()\r\n"))
        self.assertFalse(pygrep(hook, b'local s = "a:b:c"\r\n'))

    def test_addon_hooks_skip_tools_and_docs(self):
        for hook_id in ("addon-crlf", "addon-ascii"):
            hook = self.hooks[hook_id]
            self.assertRegex("Core/Init.lua", hook["files"])
            self.assertRegex("KstyleUI.toc", hook["files"])
            self.assertRegex("Tools/regression/test-stubs.lua", hook["exclude"])
            self.assertRegex("docs/design/x.xml", hook["exclude"])
            self.assertNotRegex("Core/Init.lua", hook["exclude"])

    def test_commit_messages_use_the_planned_types(self):
        hook = self.hooks["conventional-pre-commit"]
        self.assertEqual(hook.get("stages"), "[commit-msg]")
        self.assertEqual(
            hook.get("args"), "[feat, fix, perf, refactor, docs, test, ci, build, chore, revert]"
        )


if __name__ == "__main__":
    unittest.main()
