"""Tests for Tools/regression/affected.py and run-all.sh --affected: picking the Lua tests a change can reach."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REGRESSION = Path(__file__).resolve().parents[1] / "regression"
sys.path.insert(0, str(REGRESSION))
import affected  # noqa: E402

BASH = shutil.which("bash")
GIT_ENV = {
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.com",
    "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.com",
    "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_SYSTEM": os.devnull,
}


def record(files=(), names=(), content=(), wide=False, sha=""):
    return {"files": sorted(files), "names": sorted(names), "content": sorted(content), "wide": wide, "sha": sha}


def lua():
    for candidate in (shutil.which("lua5.1"), os.path.expanduser("~/.local/bin/lua5.1"), shutil.which("luajit")):
        if candidate and os.access(candidate, os.X_OK):
            return candidate
    return None


class CommandDepsTest(unittest.TestCase):
    def test_ls_reads_names(self):
        self.assertEqual(affected.command_deps("ls -1d '.'/'KstyleUI'_*/*.toc 2>/dev/null"), ("names", ["./KstyleUI_*/*.toc"]))
        self.assertEqual(affected.command_deps("ls -1A 'Tools/regression/perf' 2>/dev/null"), ("names", ["Tools/regression/perf"]))

    def test_git_ls_files_reads_names(self):
        self.assertEqual(affected.command_deps("git ls-files '*.lua'"), ("names", ["*.lua"]))
        self.assertEqual(affected.command_deps("git ls-files"), ("names", ["*"]))

    def test_grep_reads_content_of_its_paths_not_its_pattern(self):
        kind, patterns = affected.command_deps("grep -rhoE 'name=\"[A-Za-z]+\"' KstyleUI_ActionBars/ Core")
        self.assertEqual((kind, patterns), ("content", ["KstyleUI_ActionBars/", "Core"]))

    def test_housekeeping_commands_read_nothing(self):
        for command in ("mkdir -p /tmp/x", "rm -rf /tmp/x", "uptime 2>/dev/null"):
            self.assertEqual(affected.command_deps(command)[0], "ignore", command)

    def test_an_unknown_command_makes_the_test_depend_on_everything(self):
        self.assertEqual(affected.command_deps("python3 Tools/x.py")[0], "wide")
        self.assertEqual(affected.command_deps("echo 'unterminated")[0], "wide")


class RecordFromTraceTest(unittest.TestCase):
    def test_keeps_repository_files_and_drops_outside_ones(self):
        root = "/work/repo"
        text = "\n".join([
            "f Core/Init.lua", "f ./Core/./Init.lua", "f /work/repo/Core/Scale.lua", "f /tmp/other.lua", "f ../up.lua",
            "c ls -1d KstyleUI_*/", "c mkdir -p /tmp/x", "c grep -rl foo Core",
        ])
        result = affected.record_from_trace(text, root)
        self.assertEqual(result["files"], ["Core/Init.lua", "Core/Scale.lua"])
        self.assertEqual(result["names"], ["KstyleUI_*"])
        self.assertEqual(result["content"], ["Core"])
        self.assertFalse(result["wide"])

    def test_an_unknown_command_marks_the_record_wide(self):
        self.assertTrue(affected.record_from_trace("c tool --all", "/work/repo")["wide"])


class SelectTest(unittest.TestCase):
    tests = ["Tools/regression/test-" + name + ".lua" for name in ("a", "b", "c", "scan")]

    def cache(self, **changes):
        base = {
            self.tests[0]: record(["Core/Init.lua", "KstyleUI_A/A.lua", "KstyleUI_A/A.toc"]),
            self.tests[1]: record(["Core/Init.lua", "KstyleUI_B/B.lua", "Tools/regression/b_env.lua"]),
            self.tests[2]: record(["KstyleUI_C/C.lua"], names=["KstyleUI_*/"]),
            self.tests[3]: record(["KstyleUI_A/A.lua"], names=["*.lua"]),
        }
        base.update(changes)
        return base

    def choose(self, changes, cache=None, guards=("test-scan",)):
        return affected.select(self.tests, changes, cache if cache is not None else self.cache(), guards)

    def stems(self, chosen):
        return sorted(Path(test).stem for test in chosen)

    def test_a_changed_file_selects_the_tests_that_load_it_and_the_guards(self):
        chosen, _ = self.choose({"KstyleUI_B/B.lua": "M"})
        self.assertEqual(self.stems(chosen), ["test-b", "test-scan"])
        self.assertEqual(chosen[self.tests[1]], "KstyleUI_B/B.lua changed")
        self.assertEqual(chosen[self.tests[3]], "source guard, always runs")

    def test_the_guards_run_even_when_nothing_they_load_changed(self):
        chosen, _ = self.choose({"docs/note.md": "M"})
        self.assertEqual(self.stems(chosen), ["test-scan"])

    def test_the_test_file_itself_selects_it(self):
        chosen, _ = self.choose({"Tools/regression/test-c.lua": "M"})
        self.assertEqual(chosen[self.tests[2]], "Tools/regression/test-c.lua itself changed")

    def test_a_shared_file_runs_everything_and_says_why(self):
        for path in ("Tools/regression/stubs/wow.lua", "Tools/regression/widget_env.lua", "Tools/regression/run_all.py", ".luacheckrc"):
            with self.subTest(path=path):
                chosen, notes = self.choose({path: "M"})
                self.assertEqual(self.stems(chosen), ["test-a", "test-b", "test-c", "test-scan"])
                self.assertIn(path, notes[0])

    def test_a_file_that_half_the_tests_load_runs_everything(self):
        many = ["Tools/regression/test-{0}.lua".format(i) for i in range(20)]
        cache = {test: record(["Core/Init.lua"] if i < 10 else ["KstyleUI_X/X.lua"]) for i, test in enumerate(many)}
        chosen, notes = affected.select(many, {"Core/Init.lua": "M"}, cache, ())
        self.assertEqual(len(chosen), 20)
        self.assertIn("10 of 20", notes[0])
        few = {test: record(["KstyleUI_X/X.lua"] if i < 3 else []) for i, test in enumerate(many)}
        chosen, _ = affected.select(many, {"KstyleUI_X/X.lua": "M"}, few, ())
        self.assertEqual(len(chosen), 3, "a file few tests load selects only those tests")

    def test_a_few_readers_of_a_small_suite_do_not_count_as_shared(self):
        cache = self.cache()
        chosen, _ = self.choose({"Core/Init.lua": "M"}, cache)
        self.assertEqual(self.stems(chosen), ["test-a", "test-b", "test-scan"])

    def test_adding_or_deleting_a_file_selects_tests_that_list_names(self):
        self.assertIn(self.tests[2], self.choose({"KstyleUI_Z/Z.lua": "A"})[0])
        self.assertIn(self.tests[2], self.choose({"KstyleUI_C/old.lua": "D"})[0])
        self.assertNotIn(self.tests[2], self.choose({"KstyleUI_C/Other.lua": "M"})[0], "an edit does not change a listing")
        self.assertIn(self.tests[3], self.choose({"Core/New.lua": "A"})[0])

    def test_a_module_toc_selects_the_tests_that_load_that_module(self):
        chosen, _ = self.choose({"KstyleUI_A/A.toc": "M", "KstyleUI_A/A.xml": "M"})
        self.assertEqual(self.stems(chosen), ["test-a", "test-scan"])
        self.assertIn("lists the files KstyleUI_A loads", chosen[self.tests[0]])

    def test_a_record_made_from_another_version_of_the_test_file_does_not_count(self):
        cache = self.cache()
        cache[self.tests[1]] = record(["KstyleUI_B/B.lua"], sha="abc")
        chosen, _ = self.choose({"docs/note.md": "M"}, cache)
        self.assertEqual(chosen[self.tests[1]], "the record was made from another version of this test file")

    def test_a_test_with_no_record_runs(self):
        cache = self.cache()
        del cache[self.tests[1]]
        chosen, _ = self.choose({"docs/note.md": "M"}, cache)
        self.assertEqual(chosen[self.tests[1]], "no record of what it loads yet")

    def test_a_test_that_scans_the_whole_tree_always_runs(self):
        cache = self.cache()
        cache[self.tests[1]] = record(wide=True)
        chosen, _ = self.choose({"docs/note.md": "M"}, cache)
        self.assertIn(self.tests[1], chosen)

    def test_content_patterns_match_edits_under_the_folder(self):
        cache = self.cache()
        cache[self.tests[1]] = record(content=["KstyleUI_Q"])
        self.assertIn(self.tests[1], self.choose({"KstyleUI_Q/deep/File.lua": "M"}, cache)[0])
        self.assertNotIn(self.tests[1], self.choose({"KstyleUI_R/File.lua": "M"}, cache)[0])

    def test_a_file_no_test_loads_is_named(self):
        _, notes = self.choose({"docs/note.md": "M"})
        self.assertEqual(notes, ["no test file loads docs/note.md"])

    def test_an_empty_cache_runs_every_test(self):
        chosen, _ = self.choose({"docs/note.md": "M"}, {})
        self.assertEqual(len(chosen), 4)


class CacheTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.path = Path(self._tmp.name) / "deep" / "cache.json"

    def tearDown(self):
        self._tmp.cleanup()

    def test_records_merge_and_survive_a_round_trip(self):
        affected.save_cache(self.path, {"a": record(["x"])})
        affected.save_cache(self.path, {"b": record(["y"])})
        self.assertEqual(sorted(affected.load_cache(self.path)), ["a", "b"])
        affected.save_cache(self.path, {"a": record(["z"])})
        self.assertEqual(affected.load_cache(self.path)["a"]["files"], ["z"])

    def test_a_missing_corrupt_or_old_cache_is_empty(self):
        self.assertEqual(affected.load_cache(self.path), {})
        self.path.parent.mkdir(parents=True)
        self.path.write_text("{not json")
        self.assertEqual(affected.load_cache(self.path), {})
        self.path.write_text(json.dumps({"version": 0, "tests": {"a": {}}}))
        self.assertEqual(affected.load_cache(self.path), {})

    def test_a_fingerprint_follows_the_bytes(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text("one")
        first = affected.fingerprint(self.path)
        self.path.write_text("two")
        self.assertNotEqual(first, affected.fingerprint(self.path))
        self.assertEqual(affected.fingerprint(self.path.parent / "missing"), "")

    def test_the_path_follows_the_environment(self):
        old = os.environ.get("KSTYLEUI_DEPS_CACHE")
        os.environ["KSTYLEUI_DEPS_CACHE"] = "/tmp/elsewhere.json"
        try:
            self.assertEqual(affected.cache_path(), Path("/tmp/elsewhere.json"))
        finally:
            if old is None:
                del os.environ["KSTYLEUI_DEPS_CACHE"]
            else:
                os.environ["KSTYLEUI_DEPS_CACHE"] = old


class GitRepoCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self._tmp.name)
        self.git("init", "-q", "-b", "staging")

    def tearDown(self):
        self._tmp.cleanup()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, env=dict(os.environ, **GIT_ENV), check=True,
                              capture_output=True, text=True).stdout

    def write(self, files):
        for name, text in files.items():
            (self.repo / name).parent.mkdir(parents=True, exist_ok=True)
            (self.repo / name).write_text(text)

    def commit(self, files, message="c"):
        self.write(files)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)


class ChangedFilesTest(GitRepoCase):
    def test_reports_committed_staged_unstaged_untracked_and_deleted_files_against_the_merge_base(self):
        self.commit({"keep.lua": "1\n", "edit.lua": "1\n", "gone.lua": "1\n", "staged.lua": "1\n"})
        self.git("checkout", "-q", "-b", "work")
        self.commit({"committed.lua": "1\n"})
        self.git("checkout", "-q", "staging")
        self.commit({"moved-on.lua": "1\n"})
        self.git("checkout", "-q", "work")
        self.write({"edit.lua": "2\n", "staged.lua": "2\n", "fresh.lua": "1\n"})
        self.git("add", "staged.lua")
        (self.repo / "gone.lua").unlink()
        merge_base, changes = affected.changed_files("staging", cwd=self.repo)
        self.assertEqual(merge_base, self.git("rev-parse", "staging~1").strip())
        self.assertEqual(changes, {
            "committed.lua": "A", "edit.lua": "M", "staged.lua": "M", "fresh.lua": "A", "gone.lua": "D",
        })

    def test_a_rename_is_a_delete_and_an_add(self):
        self.commit({"old.lua": "same\n"})
        self.git("checkout", "-q", "-b", "work")
        self.git("mv", "old.lua", "new.lua")
        self.assertEqual(affected.changed_files("staging", cwd=self.repo)[1], {"old.lua": "D", "new.lua": "A"})

    def test_an_unknown_base_raises(self):
        self.commit({"a.lua": "1\n"})
        with self.assertRaises(RuntimeError):
            affected.changed_files("origin/nowhere", cwd=self.repo)


@unittest.skipUnless(lua() and BASH, "needs a Lua interpreter and bash")
class RunAllAffectedTest(GitRepoCase):
    def setUp(self):
        super().setUp()
        regression = self.repo / "Tools" / "regression"
        regression.mkdir(parents=True)
        for name in ("run-all.sh", "run_all.py", "affected.py", "trace.lua"):
            shutil.copy(REGRESSION / name, regression / name)
        self.commit({
            "Mod/a.lua": "return 1\n",
            "Mod/b.lua": "return 2\n",
            "Tools/regression/test-a.lua": 'assert(dofile("Mod/a.lua") == 1)\n',
            "Tools/regression/test-b.lua": 'local f = assert(io.open("Mod/b.lua", "rb")); f:close()\n',
            "Tools/regression/test-c.lua": "assert(1 + 1 == 2)\n",
            "Tools/regression/test-d.lua": 'assert(dofile("Mod/a.lua") == 1)\nlocal p = io.popen("ls -1 Mod 2>/dev/null"); p:read("*a"); p:close()\n',
        }, "base")
        self.cache = self.repo / "cache.json"

    def affected(self, base="HEAD", jobs="2"):
        full = dict(os.environ, LUA=lua(), JOBS=jobs, KSTYLEUI_DEPS_CACHE=str(self.cache))
        full.pop("CI", None)
        if not jobs:
            del full["JOBS"]
        return subprocess.run([BASH, "Tools/regression/run-all.sh", "--affected", base], cwd=self.repo, env=full,
                              capture_output=True, text=True)

    def ran(self, result):
        return sorted(line.split(":")[0].strip() for line in result.stdout.splitlines() if line.startswith("  test-"))

    def test_the_first_run_runs_everything_and_records_what_each_test_loads(self):
        result = self.affected()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.ran(result), ["test-a", "test-b", "test-c", "test-d"])
        self.assertIn("no record of what it loads yet", result.stdout)
        records = affected.load_cache(self.cache)
        self.assertEqual(records["Tools/regression/test-a.lua"]["files"], ["Mod/a.lua"])
        self.assertEqual(records["Tools/regression/test-b.lua"]["files"], ["Mod/b.lua"])
        self.assertEqual(records["Tools/regression/test-c.lua"]["files"], [])
        self.assertEqual(records["Tools/regression/test-d.lua"]["names"], ["Mod"])

    def test_a_test_edited_after_its_record_runs_again_even_when_the_base_is_unchanged(self):
        self.affected()
        self.commit({"Tools/regression/test-c.lua": "assert(2 + 2 == 4)\n"}, "edit c elsewhere")
        self.assertEqual(self.ran(self.affected(base="HEAD")), ["test-c"], "its record predates its last edit")
        self.assertEqual(self.ran(self.affected(base="HEAD")), [], "the run refreshed the record")

    def test_later_runs_pick_only_the_tests_that_load_a_changed_file(self):
        self.affected()
        self.write({"Mod/a.lua": "return 1 -- edited\n"})
        result = self.affected()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.ran(result), ["test-a", "test-d"])
        self.assertIn("affected: running 2 of 4 test files", result.stdout)
        self.assertIn("Mod/a.lua changed", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("(affected mode: 2 of 4 test files ran; the other 2 did not, and CI runs them all)"))

    def test_a_new_file_in_a_listed_folder_selects_the_test_that_lists_it(self):
        self.affected()
        self.write({"Mod/new.lua": "return 3\n"})
        self.assertEqual(self.ran(self.affected()), ["test-d"])

    def test_a_shared_file_runs_everything(self):
        self.affected()
        self.write({"Tools/regression/trace.lua": (REGRESSION / "trace.lua").read_text() + "\n"})
        result = self.affected()
        self.assertEqual(self.ran(result), ["test-a", "test-b", "test-c", "test-d"])
        self.assertIn("is shared by the whole suite", result.stdout)

    def test_a_failing_test_is_reported_and_not_recorded_as_known(self):
        self.write({"Tools/regression/test-e.lua": 'dofile("Mod/a.lua")\nerror("boom")\n'})
        self.git("add", "-A")
        result = self.affected()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL test-e", result.stdout)
        self.assertNotIn("Tools/regression/test-e.lua", affected.load_cache(self.cache))
        self.assertIn("passed 4, failed 1 (affected mode: 5 of 5", result.stdout)

    def test_an_unknown_base_runs_everything_and_says_so(self):
        result = self.affected(base="origin/nowhere")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("cannot compare with origin/nowhere", result.stdout)
        self.assertIn("passed 4, failed 0", result.stdout)

    def test_the_jobs_default_to_a_third_of_the_cpus_so_two_runs_fit_one_machine(self):
        result = self.affected(jobs="")
        expected = max(2, (os.cpu_count() or 2) // 3)
        self.assertRegex(result.stdout, r"in [\d.]+ s, {0} at a time".format(expected))


if __name__ == "__main__":
    unittest.main()
