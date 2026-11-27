"""Tests for the hooks that pick checks by what changed: Tools/hooks/luacheck.sh and Tools/hooks/needs-lua.sh."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
HOOKS = REPO / "Tools" / "hooks"


def git(cwd, *args):
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false", *args],
                   cwd=cwd, check=True, capture_output=True)


class LuacheckHookTest(unittest.TestCase):
    def run_hook(self, *files):
        with tempfile.TemporaryDirectory() as tmp:
            stub = Path(tmp) / "luacheck"
            stub.write_text('#!/usr/bin/env bash\necho "luacheck $*"\n', encoding="utf-8", newline="\n")
            stub.chmod(0o755)
            env = dict(os.environ, PATH=tmp + os.pathsep + os.environ["PATH"])
            done = subprocess.run(["bash", str(HOOKS / "luacheck.sh"), *files], env=env, capture_output=True, text=True)
            return done.returncode, done.stdout.strip()

    def test_checks_only_the_files_it_is_given(self):
        # The captain's ruling: luacheck before a push is limited to the changed files.
        self.assertEqual(self.run_hook("Core/A.lua", "KstyleUI_Chat/B.lua"),
                         (0, "luacheck --no-color -- Core/A.lua KstyleUI_Chat/B.lua"))

    def test_a_change_to_the_config_or_the_globals_rechecks_the_tree(self):
        for changed in (".luacheckrc", "Tools/data/forever_globals.lua"):
            with self.subTest(changed=changed):
                self.assertEqual(self.run_hook("Core/A.lua", changed), (0, "luacheck --no-color ."))


class NeedsLuaTest(unittest.TestCase):
    def changed(self, path):
        """Return needs-lua.sh's exit code for a commit that changes path on top of a base commit."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "README.md").write_text("base\n", encoding="utf-8")
            git(root, "init", "-q")
            git(root, "add", "-A")
            git(root, "commit", "-q", "-m", "base")
            (root / path).parent.mkdir(parents=True, exist_ok=True)
            (root / path).write_text("change\n", encoding="utf-8")
            git(root, "add", "-A")
            git(root, "commit", "-q", "-m", "change")
            return subprocess.run(["bash", str(HOOKS / "needs-lua.sh"), "HEAD^1"], cwd=root, capture_output=True).returncode

    def test_files_no_lua_test_reads_need_no_lua_tests(self):
        # The captain's ruling (d:d-qp9lxr): a docs-only change runs no Lua tests.
        for path in ("docs/DEVELOPING.md", "AGENTS.md", "Tools/regression/README.md", "KstyleUI_Chat/docs/notes.md",
                     ".github/workflows/checks.yml", "Tools/tests/test_x.py", "scripts/gate.sh", "research_notes/api.md"):
            with self.subTest(path=path):
                self.assertEqual(self.changed(path), 1)

    def test_code_data_and_the_documents_the_lua_tests_read_need_them(self):
        # The captain's ruling: a code or data change runs the Lua tests it reaches. The documents here are ones
        # test-options-notes, test-scaffold, test-actionbars-keybind-review and test-setup-layouts read.
        for path in ("Core/Core.lua", "KstyleUI_Chat/KstyleUI_Chat.toc", "KstyleUI_Bags/Bags.xml", ".luacheckrc", ".pkgmeta",
                     "Tools/regression/stubs/frames.lua", "Tools/regression/run_all.py", "Tools/data/api.json",
                     "Tools/locale/enUS.json", "Tools/media/medallions_kit.py", "Tools/render/guard_allow.tsv",
                     "Media/Textures/Bar.tga", "CHANGELOG.md", "KstyleUI_Chat/README.md", "docs/feature-map.md",
                     "docs/superpowers/plans/element-keys.md"):
            with self.subTest(path=path):
                self.assertEqual(self.changed(path), 0)

    def test_an_unknown_base_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            git(tmp, "init", "-q")
            git(tmp, "commit", "-q", "--allow-empty", "-m", "base")
            done = subprocess.run(["bash", str(HOOKS / "needs-lua.sh"), "no-such-ref"], cwd=tmp, capture_output=True)
            self.assertEqual(done.returncode, 2)


if __name__ == "__main__":
    unittest.main()
