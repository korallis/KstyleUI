"""Tests for Tools/regression/affected.py and run-all.sh --affected: picking the Lua tests a change can reach."""

import contextlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REGRESSION = Path(__file__).resolve().parents[1] / "regression"
sys.path.insert(0, str(REGRESSION))
import affected  # noqa: E402

BASH = shutil.which("bash")
GIT_ENV = {
    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.com",
    "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.com",
    "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_SYSTEM": os.devnull,
}


def record(files=(), listings=(), names=(), sha="", idle=(), seen=None):
    made = {"files": sorted(files), "idle": sorted(idle), "listings": sorted(listings), "names": sorted(names), "sha": sha}
    if seen is not None:
        made["seen"] = seen
    return made


def lua():
    for candidate in (shutil.which("lua5.1"), os.path.expanduser("~/.local/bin/lua5.1"), shutil.which("luajit")):
        if candidate and os.access(candidate, os.X_OK):
            return candidate
    return None


class RecordFromTraceTest(unittest.TestCase):
    def test_keeps_repository_files_and_drops_outside_ones(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "repo"
            text = "\n".join([
                "f Core/Init.lua", "f ./Core/./Init.lua", f"f {root / 'Core/Scale.lua'}", f"f {Path(tmp) / 'other.lua'}", "f ../up.lua",
            ])
            result = affected.record_from_trace(text, root)
        self.assertEqual(result["files"], ["Core/Init.lua", "Core/Scale.lua"])

    def test_a_language_file_run_with_no_game_language_is_idle_unless_the_test_also_reads_it(self):
        # Intent: the approved faster-gate plan, a language file change runs only the tests it can reach.
        text = "\n".join(["s Core/Locales/deDE.lua", "s Core/Locales/frFR.lua", "f Core/Locales/frFR.lua", "f Core/Init.lua"])
        result = affected.record_from_trace(text, "/work/repo")
        self.assertEqual(result["idle"], ["Core/Locales/deDE.lua"])
        self.assertEqual(result["files"], ["Core/Init.lua", "Core/Locales/frFR.lua"])

    def test_a_listing_records_its_folder_and_glob(self):
        text = "\n".join([
            "n ./KstyleUI_*", "n Tools/regression/perf", "n Tools/regression/fixtures/toc/Core/", "n .",
            "n Tools/render/scenes/gallery_*.lua", "n ../outside", "t *.lua",
        ])
        result = affected.record_from_trace(text, "/work/repo")
        self.assertEqual(result["listings"], [
            "*", "KstyleUI_*", "Tools/regression/fixtures/toc/Core/*", "Tools/regression/perf/*", "Tools/render/scenes/gallery_*.lua",
        ])
        self.assertEqual(result["names"], ["*.lua"])


class SelectTest(unittest.TestCase):
    tests = ["Tools/regression/test-" + name + ".lua" for name in ("a", "b", "c", "scan")]

    def cache(self, **changes):
        base = {
            self.tests[0]: record(["Core/Init.lua", "KstyleUI_A/A.lua", "KstyleUI_A/A.toc"]),
            self.tests[1]: record(["Core/Init.lua", "KstyleUI_B/B.lua", "Tools/regression/b_env.lua"]),
            self.tests[2]: record(["KstyleUI_C/C.lua"], listings=["KstyleUI_*", "KstyleUI_C/*.toc"]),
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
        for path in ("Tools/regression/stubs/wow.lua", "Tools/regression/run_all.py", ".luacheckrc"):
            with self.subTest(path=path):
                chosen, notes = self.choose({path: "M"})
                self.assertEqual(self.stems(chosen), ["test-a", "test-b", "test-c", "test-scan"])
                self.assertIn(path, notes[0])

    def test_an_env_change_selects_only_readers_and_all_mandatory_guards(self):
        guards = ["Tools/regression/" + name + ".lua" for name in affected.GUARDS]
        tests = self.tests + guards
        cache = self.cache()
        cache.update({test: record(sha=affected.fingerprint(test)) for test in guards})
        chosen, _ = affected.select(tests, {"Tools/regression/b_env.lua": "M"}, cache)
        self.assertEqual(set(chosen), {self.tests[1], *guards})
        self.assertNotIn(self.tests[2], chosen, "an unrelated module must stay excluded")

    def test_an_env_change_with_missing_or_stale_records_runs_everything(self):
        for stale in (None, record(sha="old")):
            cache = self.cache()
            if stale is None:
                del cache[self.tests[2]]
            else:
                cache[self.tests[2]] = stale
            chosen, notes = self.choose({"Tools/regression/b_env.lua": "M"}, cache)
            self.assertEqual(set(chosen), set(self.tests))
            self.assertIn("record", notes[0])

    def test_a_file_that_half_the_tests_load_runs_everything(self):
        many = ["Tools/regression/test-{0}.lua".format(i) for i in range(20)]
        cache = {test: record(["Core/Init.lua"] if i < 10 else ["KstyleUI_X/X.lua"]) for i, test in enumerate(many)}
        chosen, notes = affected.select(many, {"Core/Init.lua": "M"}, cache, ())
        self.assertEqual(len(chosen), 20)
        self.assertIn("10 of 20", notes[0])
        few = {test: record(["KstyleUI_X/X.lua"] if i < 3 else []) for i, test in enumerate(many)}
        chosen, _ = affected.select(many, {"KstyleUI_X/X.lua": "M"}, few, ())
        self.assertEqual(len(chosen), 3, "a file few tests load selects only those tests")

    def test_a_language_file_selects_its_readers_and_not_the_tests_where_it_stayed_idle(self):
        # Intent: the approved faster-gate plan; before it, a language file every test loads ran every test.
        many = ["Tools/regression/test-{0}.lua".format(i) for i in range(20)]
        cache = {test: record(["Core/Locales/deDE.lua"] if i < 2 else ["Core/Init.lua"], idle=[] if i < 2 else ["Core/Locales/deDE.lua"])
                 for i, test in enumerate(many)}
        chosen, notes = affected.select(many, {"Core/Locales/deDE.lua": "M"}, cache, ())
        self.assertEqual(sorted(chosen), many[:2])
        self.assertEqual(notes, [])
        chosen, _ = affected.select(many, {"Core/Locales/deDE.lua": "D"}, cache, ())
        self.assertEqual(len(chosen), 20, "load_files.lua fails on a language file that is gone, so its deletion reaches every loader")

    def test_a_few_readers_of_a_small_suite_do_not_count_as_shared(self):
        cache = self.cache()
        chosen, _ = self.choose({"Core/Init.lua": "M"}, cache)
        self.assertEqual(self.stems(chosen), ["test-a", "test-b", "test-scan"])

    def test_adding_or_deleting_a_file_selects_tests_that_list_names(self):
        self.assertIn(self.tests[2], self.choose({"KstyleUI_Z/Z.lua": "A"})[0])
        self.assertIn(self.tests[2], self.choose({"KstyleUI_C/old.lua": "D"})[0])
        self.assertNotIn(self.tests[2], self.choose({"KstyleUI_C/Other.lua": "M"})[0], "an edit does not change a listing")
        self.assertIn(self.tests[3], self.choose({"Core/New.lua": "A"})[0])

    def test_a_new_module_folder_selects_every_test_that_lists_the_module_glob(self):
        cache = self.cache()
        cache[self.tests[1]] = record(["KstyleUI_B/B.lua"], listings=["KstyleUI_*"])
        chosen, _ = self.choose({"KstyleUI_New/x.lua": "A"}, cache)
        self.assertEqual(self.stems(chosen), ["test-b", "test-c", "test-scan"])
        self.assertEqual(chosen[self.tests[1]], "KstyleUI_New/x.lua was added")

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
        self.assertNotIn(b"\r\n", self.path.read_bytes(), 'cache JSON must use LF: open writers with newline="\\n"')

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

    def test_each_working_copy_keeps_its_own_records_and_a_new_one_starts_from_the_shared_copy(self):
        # Intent: the approved faster-gate plan, another working copy's run must not replace this one's records.
        # resolve(): git names the macOS temp folder by its real /private/var path.
        root = Path(self._tmp.name).resolve()
        one, two = root / "one", root / "two"
        environment = {key: value for key, value in os.environ.items() if key != "KSTYLEUI_DEPS_CACHE"}
        environment.update(GIT_ENV, XDG_CACHE_HOME=str(root / "cache"))
        with mock.patch.dict(os.environ, environment, clear=True):
            affected.git("init", "-q", str(one))
            affected.git("commit", "-q", "--allow-empty", "-m", "base", cwd=one)
            affected.git("worktree", "add", "-q", str(two), cwd=one)
            self.assertEqual(affected.cache_path(one), one / ".git" / "kstyleui-regression-deps.json")
            self.assertEqual(affected.cache_path(two), one / ".git" / "worktrees" / "two" / "kstyleui-regression-deps.json")
            for folder in (one, two):
                (folder / "x").write_text("same in both")
                (folder / "y").write_text("made in " + folder.name)
                (folder / "z").write_text("z")
            (one / "kind").mkdir()
            (two / "more").write_text("only in two")
            affected.git("add", "more", cwd=two)

            def made(**parts):
                return record(seen=affected.seen(record(**parts), one), **parts)

            affected.save_records({"a": made(files=["x"]), "b": made(files=["y"]), "c": record(["x"]),
                                   "d": made(files=["x"], listings=["m*"]), "e": made(files=["x"], names=["m*"]),
                                   "f": made(files=["x"], listings=["z*"], names=["*.lua"]), "g": made(listings=["sub/*"]),
                                   "h": made(listings=["kind"])}, one)
            (two / "sub").mkdir()
            (two / "sub" / "missing").write_text("a file named like the word for no folder")
            (two / "kind").write_text("a file where the record saw a folder")
            self.assertEqual(sorted(affected.load_records(two)), ["a", "f"],
                             "a new working copy takes only the shared records whose files, listings and tracked names it holds")
            affected.save_records({"a": record(["z"], seen=affected.seen(record(["z"]), two)), "f": record(["z"])}, two)
            self.assertEqual(affected.load_records(one)["a"]["files"], ["x"], "the other working copy's run left these records alone")
            self.assertEqual({name: entry["files"] for name, entry in affected.load_records(two).items()}, {"a": ["z"], "f": ["z"]})

    def test_a_folder_that_cannot_be_read_is_not_a_missing_folder(self):
        # Intent: the approved faster-gate plan, a shared record is reused only where the working copy provably matches.
        listed = record(listings=["gone/*"])
        missing = affected.seen(listed, self._tmp.name)
        with mock.patch.object(affected.os, "scandir", side_effect=PermissionError("denied")):
            with self.assertRaises(PermissionError):
                affected.seen(listed, self._tmp.name)
            with mock.patch.dict(os.environ, {"XDG_CACHE_HOME": self._tmp.name, "KSTYLEUI_DEPS_CACHE": ""}), \
                    mock.patch.object(affected, "cache_path", return_value=self.path):
                affected.save_cache(affected.shared_path(), {"a": dict(listed, seen=missing)})
                self.assertEqual(affected.load_records(self._tmp.name), {}, "an unread folder matches no record")

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


class ChangedFoldersTest(GitRepoCase):
    def test_a_folder_changes_a_listing_only_when_it_appears_or_goes(self):
        self.commit({"KstyleUI_Old/a.lua": "1\n", "KstyleUI_Gone/a.lua": "1\n"})
        self.write({"KstyleUI_Old/b.lua": "1\n", "KstyleUI_New/deep/x.lua": "1\n"})
        shutil.rmtree(self.repo / "KstyleUI_Gone")
        changes = {"KstyleUI_Old/b.lua": "A", "KstyleUI_New/deep/x.lua": "A", "KstyleUI_Gone/a.lua": "D"}
        cwd = os.getcwd()
        os.chdir(self.repo)
        try:
            folders = affected.changed_folders(changes)
        finally:
            os.chdir(cwd)
        self.assertEqual(folders, {"KstyleUI_New", "KstyleUI_New/deep", "KstyleUI_Gone"})
        self.assertFalse(affected.listing_hit("KstyleUI_*", "KstyleUI_Old/b.lua", folders), "an existing folder keeps its name")
        self.assertTrue(affected.listing_hit("KstyleUI_Old/*", "KstyleUI_Old/b.lua", folders), "a new file is a new name in its own folder")
        self.assertTrue(affected.listing_hit("KstyleUI_*", "KstyleUI_New/deep/x.lua", folders))
        self.assertTrue(affected.listing_hit("KstyleUI_*", "KstyleUI_Gone/a.lua", folders))
        self.assertFalse(affected.listing_hit("*.toc", "KstyleUI_New/deep/x.lua", folders), "the glob must match the folder's name")


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
        for name in ("run-all.sh", "run_all.py", "runner_platform.py", "affected.py", "trace.lua", "fs.lua", "load_files.lua"):
            shutil.copy(REGRESSION / name, regression / name)
        self.commit({
            "Mod/a.lua": "return 1\n",
            "Mod/b.lua": "return 2\n",
            "Tools/regression/test-a.lua": 'assert(dofile("Mod/a.lua") == 1)\n',
            "Tools/regression/test-b.lua": 'local f = assert(io.open("Mod/b.lua", "rb")); f:close()\n',
            "Tools/regression/test-c.lua": "assert(1 + 1 == 2)\n",
            "Tools/regression/test-d.lua": 'assert(dofile("Mod/a.lua") == 1)\ndofile("Tools/regression/fs.lua").list("Mod")\n',
        }, "base")
        self.cache = self.repo / "cache.json"

    def affected(self, base="HEAD", jobs="2"):
        full = dict(os.environ, LUA=lua(), JOBS=jobs, KSTYLEUI_DEPS_CACHE=str(self.cache), KSTYLEUI_SLOTS="0")
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
        self.assertEqual(records["Tools/regression/test-d.lua"]["listings"], ["Mod/*"])

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
        self.assertTrue(result.stdout.rstrip().endswith("(affected mode: 2 of 4 test files ran; the other 2 did not; the nightly run runs them all)"))

    def test_a_language_file_change_runs_the_test_that_sets_a_language_and_not_the_one_that_does_not(self):
        # Intent: the approved faster-gate plan. A language file returns on its first line where GetLocale is unset.
        language = 'if not GetLocale or GetLocale() ~= "deDE" then\n\treturn\nend\nlocal _, ns = ...\nns.German = true\n'
        load = 'local Load = dofile("Tools/regression/load_files.lua")\nlocal env = Load({ "Core/Locales/deDE.lua" }, setmetatable({ %s }, { __index = _G }))\n'
        self.commit({
            "Core/Locales/deDE.lua": language,
            "Tools/regression/test-english.lua": load % "" + "assert(not env._addons.KstyleUI.German)\n",
            "Tools/regression/test-german.lua": load % 'GetLocale = function() return "deDE" end' + "assert(env._addons.KstyleUI.German)\n",
        }, "language file")
        first = self.affected()
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        self.write({"Core/Locales/deDE.lua": language + "ns.More = true\n"})
        self.assertEqual(self.ran(self.affected()), ["test-german"])

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

    def test_a_run_that_cannot_look_at_the_working_copy_afterwards_still_finishes_and_seeds_no_other_working_copy(self):
        # Intent: the approved faster-gate plan, records are a speed-up and never decide whether the gate passes.
        import run_all
        shared = tempfile.TemporaryDirectory()
        self.addCleanup(shared.cleanup)
        environment = {key: value for key, value in os.environ.items() if key not in ("CI", "KSTYLEUI_DEPS_CACHE")}
        environment.update(GIT_ENV, LUA=lua(), JOBS="2", KSTYLEUI_SLOTS="0", XDG_CACHE_HOME=shared.name)
        output, start = io.StringIO(), os.getcwd()
        with mock.patch.dict(os.environ, environment, clear=True):
            os.chdir(self.repo)
            try:
                with mock.patch.object(affected, "seen", side_effect=RuntimeError("git stopped")), \
                        contextlib.redirect_stdout(output):
                    status = run_all.main(["--affected", "HEAD"])
            finally:
                os.chdir(start)
            self.assertEqual(status, 0, output.getvalue())
            self.assertIn("passed 4, failed 0 (affected mode: 4 of 4", output.getvalue())
            saved = affected.load_cache(affected.shared_path())
            self.assertEqual(sorted(saved), ["Tools/regression/test-{0}.lua".format(letter) for letter in "abcd"])
            self.assertEqual([name for name, entry in saved.items() if "seen" in entry], [])
            other = Path(shared.name) / "other"
            self.git("worktree", "add", "-q", str(other))
            self.assertEqual(affected.load_records(other), {}, "a record with no look at its working copy seeds none")
            self.assertEqual(sorted(affected.load_records(self.repo)), sorted(saved), "the run's own working copy keeps them")

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

    def test_the_jobs_default_to_a_third_of_the_cpus_and_never_more_than_six(self):
        result = self.affected(jobs="")
        expected = max(2, min((os.cpu_count() or 2) // 3, 6))
        self.assertRegex(result.stdout, r"in [\d.]+ s, {0} at a time".format(expected))


    def fake_strings(self, exit_code):
        self.commit({"Tools/locale/strings.py": 'import sys\nprint("Mod/a.lua uses L[\\"New\\"], which the English base lacks; run python3 Tools/locale/strings.py sync")\nsys.exit(%d)\n' % exit_code}, "locale script")

    def test_an_addon_lua_change_runs_the_locale_check_and_names_the_sync_command_when_it_fails(self):
        self.fake_strings(1)
        self.write({"Mod/a.lua": "return 1 -- edited\n"})
        result = self.affected()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("FAIL locale: 1 problems in the string tables", result.stdout)
        self.assertIn("Mod/a.lua uses L[\"New\"], which the English base lacks", result.stdout)
        self.assertIn("Fix: python3 Tools/locale/strings.py sync", result.stdout)
        self.assertRegex(result.stdout, r"passed \d+, failed 1 \(affected mode")

    def test_the_locale_check_passes_quietly_when_the_tables_match(self):
        self.fake_strings(0)
        self.write({"Mod/a.lua": "return 1 -- edited\n"})
        result = self.affected()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("locale: the string tables match the code", result.stdout)

    def test_a_change_with_no_addon_lua_or_locale_file_skips_the_locale_check(self):
        self.fake_strings(1)
        self.write({"Tools/regression/test-c.lua": "assert(1 + 1 == 2) -- edited\n", "README.md": "docs\n"})
        result = self.affected()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("locale", result.stdout)

    def test_a_locale_table_change_runs_the_locale_check(self):
        self.fake_strings(1)
        self.write({"Tools/locale/deDE.json": "{}\n"})
        self.assertIn("FAIL locale", self.affected().stdout)


if __name__ == "__main__":
    unittest.main()
