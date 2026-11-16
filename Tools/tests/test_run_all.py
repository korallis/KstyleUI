"""Tests for Tools/regression/run-all.sh and the runner it starts, run_all.py.

The runner only runs "<interpreter> <file>"; Python fixtures exercise the same contract on every OS.
"""

import json
import ctypes
import errno
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest import mock
from pathlib import Path

REGRESSION = Path(__file__).resolve().parents[1] / "regression"
BASH = shutil.which("bash")
sys.path.insert(0, str(REGRESSION))


class PortableRunnerTest(unittest.TestCase):
    def setUp(self):
        import run_all
        self.runner = run_all
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.folder = Path(self.tmp.name)

    def run_python(self, source, limit=10):
        script = self.folder / "test.py"
        script.write_text(source, encoding="utf-8")
        return self.runner.run_one([sys.executable], str(script), self.folder / "log", limit)

    def test_timeout_kills_the_native_child(self):
        start = time.monotonic()
        result = self.run_python("import time; time.sleep(30)", limit=0.3)
        self.assertTrue(result["stopped"])
        self.assertFalse(result["ok"])
        self.assertLess(time.monotonic() - start, 5)

    def test_peak_memory_still_fails_the_budget_after_memory_is_freed(self):
        result = self.run_python("x = bytearray(100 << 20); del x")
        self.assertTrue(result["ok"])
        self.assertGreater(result["mb"], 90)
        self.assertIn("peaked at", self.runner.problems("test", result, 10, 50)[0])

    def test_shard_selection_is_unchanged(self):
        tests = ["a", "b", "c", "d"]
        weights = {"a": 9, "b": 8, "c": 2, "d": 1}
        self.assertEqual(self.runner.shard(tests, 1, 2, weights), ["a", "d"])
        self.assertEqual(self.runner.shard(tests, 2, 2, weights), ["b", "c"])

    def test_explicit_interpreter_passes_the_resolved_executable(self):
        with mock.patch.dict(os.environ, LUA='"C:\\Program Files\\Lua\\lua5.1.exe" -e hello'), \
                mock.patch.object(self.runner, "os", SimpleNamespace(name="nt", environ=os.environ)), \
                mock.patch.object(self.runner.shutil, "which", return_value="resolved.exe") as which:
            command, _ = self.runner.interpreter()
        which.assert_called_once_with("C:\\Program Files\\Lua\\lua5.1.exe")
        self.assertEqual(command, ["resolved.exe", "-e", "hello"])

    def test_default_interpreter_preferences_and_exe_fallback(self):
        for lua, jit, expected in (("lua51", "jit", ["lua51"]), (None, "jit", ["jit", "-joff"]), (None, None, None)):
            with self.subTest(lua=lua, jit=jit), mock.patch.dict(os.environ, {"HOME": str(self.folder)}, clear=True), \
                    mock.patch.object(self.runner.shutil, "which", side_effect=lambda name: {"lua5.1": lua, "luajit": jit}[name]):
                self.assertEqual(self.runner.interpreter()[0], expected)
        local = self.folder / ".local" / "bin" / ("lua5.1.exe" if os.name == "nt" else "lua5.1")
        local.parent.mkdir(parents=True)
        local.touch()
        local.chmod(0o755)
        with mock.patch.dict(os.environ, {"HOME": str(self.folder)}, clear=True), \
                mock.patch.object(self.runner.shutil, "which", return_value=None):
            self.assertEqual(self.runner.interpreter()[0], [str(local)])

    def test_luajit_fast_mode_and_explicit_joff(self):
        for choice, fast in (("luajit", True), ("luajit -joff", False)):
            with mock.patch.dict(os.environ, LUA=choice), mock.patch.object(self.runner.shutil, "which", return_value="luajit"):
                command, label = self.runner.interpreter()
            self.assertEqual("fast mode" in label, fast)
            self.assertEqual(command, choice.split())

    def test_platform_locks_use_nonblocking_os_calls_and_only_ignore_contention(self):
        import runner_platform as platform
        with open(self.folder / "slot", "a+b") as guard:
            for windows, flags in ((True, 2), (False, 6)):
                locker = mock.Mock()
                self.assertTrue(platform.try_lock(guard, windows=windows, locker=locker))
                locker.assert_called_once_with(guard.fileno(), flags, *([1] if windows else []))
                locker.side_effect = OSError(errno.EACCES, "locked")
                self.assertFalse(platform.try_lock(guard, windows=windows, locker=locker))
                locker.side_effect = OSError(errno.EBADF, "bad descriptor")
                with self.assertRaises(OSError):
                    platform.try_lock(guard, windows=windows, locker=locker)

    def test_windows_accounting_on_every_os(self):
        import runner_platform as platform

        def memory(handle, counters, size):
            self.assertEqual(handle.value, 123)
            self.assertEqual(size, ctypes.sizeof(platform.MemoryCounters))
            counters._obj.PeakPagefileUsage = 123 << 20
            return 1

        def times(handle, created, exited, kernel, user):
            kernel._obj.value, user._obj.value = 10_000_000, 20_000_000
            return 1

        self.assertEqual(platform.windows_usage(123, memory, times), (123, 3))
        self.assertEqual(platform.windows_usage(123, lambda *args: 0, times), (None, 3))
        self.assertEqual(platform.windows_usage(123, memory, lambda *args: 0), (123, None))
        self.assertEqual(platform.windows_usage(123, mock.Mock(side_effect=OSError), times), (None, None))

    def test_windows_kill_and_wait_on_every_os(self):
        import runner_platform as platform
        child = mock.Mock()
        platform.kill(child, windows=True)
        child.kill.assert_called_once_with()
        with mock.patch.object(platform, "windows_usage", return_value=(12, 3)) as usage:
            self.assertEqual(platform.wait(child, windows=True), (12, 3))
        child.wait.assert_called_once_with()
        usage.assert_called_once_with(child._handle)

    def test_posix_kill_and_wait_on_every_os(self):
        import runner_platform as platform
        child = mock.Mock(pid=123)
        with mock.patch.object(platform.os, "killpg", create=True) as killpg, \
                mock.patch.object(platform, "signal", SimpleNamespace(SIGKILL=9)):
            platform.kill(child, windows=False)
        killpg.assert_called_once_with(123, 9)
        usage = SimpleNamespace(ru_maxrss=2 << 20, ru_utime=1, ru_stime=2)
        for system, mb in (("darwin", 2), ("linux", 2048)):
            with mock.patch.object(platform.os, "wait4", create=True, return_value=(123, 0, usage)), \
                    mock.patch.object(platform.os, "waitstatus_to_exitcode", create=True, return_value=0), \
                    mock.patch.object(platform.sys, "platform", system):
                self.assertEqual(platform.wait(child, windows=False), (mb, 3))
        self.assertEqual(child.returncode, 0)

    def test_missing_memory_and_load_print_na_without_failing_or_crashing(self):
        result = {"mb": None, "seconds": 1, "load": None, "stopped": False}
        self.assertEqual(self.runner.problems("test", result, 2, 50), [])
        self.assertEqual(self.runner.memory_text(None), "n/a")
        with mock.patch.object(self.runner.os, "getloadavg", create=True, side_effect=AttributeError):
            self.assertIsNone(self.runner.load_now())


class RunAllTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.regression = self.tmp / "Tools" / "regression"
        self.regression.mkdir(parents=True)
        for name in ("run-all.sh", "run_all.py", "runner_platform.py", "affected.py", "trace.lua"):
            shutil.copy(REGRESSION / name, self.regression / name)
        (self.regression / "helper.lua").write_text("raise SystemExit(1)\n")

    def tearDown(self):
        self._tmp.cleanup()

    def run_all(self, *args, lua=sys.executable, **changes):
        env = {key: value for key, value in os.environ.items() if key not in ("CI", "RUNNER_ENVIRONMENT", "LUA", "TEST_TIME_BUDGET", "TEST_MEMORY_BUDGET")}
        env.update(KSTYLEUI_SLOT_DIR=str(self.tmp / "slots"), KSTYLEUI_SLOTS="64")
        if lua is not None:
            env["LUA"] = f'"{lua}"' if " " in lua and Path(lua).exists() else lua
        for key, value in changes.items():
            if value is None:
                env.pop(key, None)
            else:
                env[key] = value
        return subprocess.run([BASH, str(self.regression / "run-all.sh"), *args], env=env, capture_output=True, text=True)

    def start_all(self, **changes):
        env = dict(os.environ, LUA=f'"{sys.executable}"', KSTYLEUI_SLOT_DIR=str(self.tmp / "slots"), KSTYLEUI_SLOTS="64", JOBS="4")
        env.pop("CI", None)
        env.pop("RUNNER_ENVIRONMENT", None)
        env.update(changes)
        return subprocess.Popen([BASH, str(self.regression / "run-all.sh")], env=env, stdout=subprocess.PIPE, text=True)

    def test_counts_passes_and_failures(self):
        (self.regression / "test-pass.lua").write_text("print('fine')\n")
        lines = "".join(f"print('line{i}')\n" for i in range(1, 8))
        (self.regression / "test-fail.lua").write_text(lines + "raise SystemExit(1)\n")
        result = self.run_all()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL test-fail", result.stdout)
        self.assertIn("line7", result.stdout)
        self.assertIn("line3", result.stdout)
        self.assertNotIn("line2", result.stdout)
        self.assertNotIn("FAIL test-pass", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 1, failed 1"))

    def test_exits_0_when_all_pass(self):
        (self.regression / "test-a.lua").write_text("pass\n")
        (self.regression / "test-b.lua").write_text("pass\n")
        result = self.run_all()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 2, failed 0"))

    def test_runs_from_the_repository_root(self):
        (self.regression / "test-cwd.lua").write_text("from pathlib import Path; assert Path('Tools/regression').is_dir()\n")
        result = self.run_all()
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_runs_tests_in_parallel(self):
        for own, other in (("x", "y"), ("y", "x")):
            (self.regression / f"test-{own}.lua").write_text(
                "import time\nfrom pathlib import Path\n"
                f"Path({str(self.tmp / own)!r}).touch()\n"
                "deadline = time.monotonic() + 5\n"
                f"while not Path({str(self.tmp / other)!r}).exists():\n"
                "    assert time.monotonic() < deadline\n    time.sleep(0.05)\n")
        result = self.run_all(JOBS="2")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 2, failed 0"))

    def test_reports_failures_in_file_order(self):
        for name in ("test-c.lua", "test-a.lua", "test-b.lua"):
            (self.regression / name).write_text("raise SystemExit(1)\n")
        result = self.run_all()
        self.assertNotEqual(result.returncode, 0)
        order = [line for line in result.stdout.splitlines() if line.startswith("FAIL ")]
        self.assertEqual(order, ["FAIL test-a", "FAIL test-b", "FAIL test-c"])

    def test_fails_when_no_tests_exist(self):
        result = self.run_all()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no tests found", result.stdout)

    def test_stops_with_one_message_when_lua_is_missing(self):
        (self.regression / "test-a.lua").write_text("pass\n")
        (self.regression / "test-b.lua").write_text("pass\n")
        result = self.run_all(lua="no-such-lua-kstyleui")
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn("no-such-lua-kstyleui not found", result.stdout)
        self.assertNotIn("FAIL", result.stdout)

    # Slices of the files, for CI.

    def marking_tests(self, names):
        for name in names:
            (self.regression / f"test-{name}.lua").write_text(f"with open({str(self.tmp / 'marks')!r}, 'a') as out: out.write('{name}\\n')\n")

    def marks(self):
        path = self.tmp / "marks"
        return path.read_text().split() if path.exists() else []

    def test_shards_cover_every_file_exactly_once(self):
        names = list("abcdefg")
        self.marking_tests(names)
        seen = []
        for index in (1, 2, 3):
            result = self.run_all("--shard", f"{index}/3")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn(f"shard {index}/3: ", result.stdout)
            seen += self.marks()
            (self.tmp / "marks").unlink()
        self.assertEqual(sorted(seen), names)

    def test_a_shard_reports_only_its_own_files_and_ends_with_the_plain_summary(self):
        self.marking_tests("abcd")
        result = self.run_all("--shard", "1/2")
        self.assertIn("shard 1/2: 2 of 4 test files", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 2, failed 0"))

    def test_shards_balance_by_the_recorded_weights(self):
        self.marking_tests("abcdef")
        (self.regression / "weights.json").write_text(json.dumps({"test-a.lua": 30, "test-b.lua": 30, "test-c.lua": 1}))
        self.run_all("--shard", "1/2")
        first = self.marks()
        self.assertIn(("a" in first) + ("b" in first), (1,), "the two heavy files land in different shards")

    def test_the_heaviest_files_start_first(self):
        self.marking_tests("abc")
        (self.regression / "weights.json").write_text(json.dumps({"test-a.lua": 1, "test-b.lua": 5, "test-c.lua": 9}))
        self.run_all(JOBS="1")
        self.assertEqual(self.marks(), ["c", "b", "a"])

    def test_a_malformed_shard_is_a_usage_error(self):
        self.marking_tests("a")
        for bad in ("0/2", "3/2", "x", "1/0", "1"):
            with self.subTest(shard=bad):
                result = self.run_all("--shard", bad)
                self.assertEqual(result.returncode, 2)
                self.assertIn("--shard takes I/N", result.stderr)

    def test_write_weights_records_the_times_and_needs_every_file(self):
        self.marking_tests("ab")
        self.assertEqual(self.run_all("--write-weights", "--shard", "1/2").returncode, 2)
        result = self.run_all("--write-weights")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(sorted(json.loads((self.regression / "weights.json").read_text())), ["test-a.lua", "test-b.lua"])

    # The time budget.

    def test_fails_a_test_over_the_time_budget_and_names_the_fix(self):
        (self.regression / "test-fast.lua").write_text("pass\n")
        (self.regression / "test-slow.lua").write_text("import time; time.sleep(1.5)\n")
        result = self.run_all(TEST_TIME_BUDGET="1")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        line = next((line for line in result.stdout.splitlines() if line.startswith("FAIL test-slow")), "")
        self.assertRegex(line, r"^FAIL test-slow: took 1\.\d s, over the 1 s budget\. Make the test cheaper; CI runs Lua 5\.1")
        self.assertNotIn("FAIL test-fast", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 1, failed 1"))

    def test_passes_tests_within_the_time_budget(self):
        (self.regression / "test-fast.lua").write_text("import time; time.sleep(0.1)\n")
        result = self.run_all(TEST_TIME_BUDGET="1")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 1, failed 0"))

    def test_stops_a_test_at_three_times_the_budget(self):
        (self.regression / "test-hang.lua").write_text("import time; time.sleep(30)\n")
        start = time.monotonic()
        result = self.run_all(TEST_TIME_BUDGET="0.5")
        self.assertLess(time.monotonic() - start, 10, result.stdout)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL test-hang: stopped after 1.5 s, 3 times the 0.5 s budget", result.stdout)

    def test_stopping_the_runner_stops_its_tests(self):
        import run_all
        children = run_all.Children()
        with open(os.devnull, "wb") as out:
            child = children.start([sys.executable, "-c", "import time; time.sleep(30)"], out)
        children.stop_all()
        child.wait(timeout=5)
        self.assertNotEqual(child.returncode, 0)
        with self.assertRaises(KeyboardInterrupt):
            children.start([], None)

    def test_the_default_budget_is_20_s_and_four_times_that_on_ci(self):
        (self.regression / "test-a.lua").write_text("pass\n")
        self.assertIn("budget 20 s", self.run_all().stdout)
        self.assertIn("budget 80 s", self.run_all(CI="true").stdout)

    # The memory budget.

    def test_fails_a_test_over_the_memory_budget(self):
        (self.regression / "test-small.lua").write_text("pass\n")
        (self.regression / "test-big.lua").write_text("x = bytearray(300 << 20)\n")
        result = self.run_all(TEST_MEMORY_BUDGET="200")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        line = next((line for line in result.stdout.splitlines() if line.startswith("FAIL test-big")), "")
        self.assertRegex(line, r"^FAIL test-big: peaked at \d+ MB, over the 200 MB budget\. Make the test use less memory")
        self.assertNotIn("FAIL test-small", result.stdout)

    # The summary.

    def test_prints_the_slowest_five_and_the_total(self):
        for i, seconds in enumerate(("0", "0.2", "0.4", "0.6", "0.8", "1.0")):
            (self.regression / f"test-{i}.lua").write_text(f"import time; time.sleep({seconds})\n")
        result = self.run_all(JOBS="6")
        self.assertEqual(result.returncode, 0, result.stdout)
        lines = result.stdout.splitlines()
        start = lines.index("slowest:")
        slowest = [re.sub(r"^\s+[\d.]+ s\s+\d+ MB\s+", "", line) for line in lines[start + 1:start + 6]]
        self.assertEqual(slowest, ["test-5", "test-4", "test-3", "test-2", "test-1"])
        self.assertRegex(result.stdout, r"\ntotal [\d.]+ s of test time in [\d.]+ s, 6 at a time\n")

    # The machine-wide worker limit.

    def overlaps(self):
        """Count overlapping intervals, with a separate timestamp file per process."""
        running = most = 0
        events = [(int(path.read_text()), 1 if path.suffix == ".start" else -1)
                  for path in (self.tmp / "log").iterdir()]
        for _, change in sorted(events):
            running += change
            most = max(most, running)
        self.assertEqual(running, 0, "every started fixture must finish")
        return most

    def timed_tests(self, count):
        for i in range(count):
            (self.regression / f"test-{i}.lua").write_text(
                "import os, time\nfrom pathlib import Path\n"
                f"folder = Path({str(self.tmp / 'log')!r})\n"
                "folder.mkdir(exist_ok=True)\nstem = folder / str(os.getpid())\n"
                "stem.with_suffix('.start').write_text(str(time.monotonic_ns()))\n"
                "time.sleep(0.3)\n"
                "stem.with_suffix('.end').write_text(str(time.monotonic_ns()))\n")

    def test_the_slot_limit_caps_the_files_running_at_once(self):
        self.timed_tests(6)
        result = self.run_all(JOBS="6", KSTYLEUI_SLOTS="2")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.overlaps(), 2)
        self.assertIn("worker slots: 2 for every run on this machine", result.stdout)
        self.assertRegex(result.stdout, r"\ntotal [\d.]+ s of test time in [\d.]+ s, 2 at a time\n")

    def test_two_runs_share_the_slots(self):
        self.timed_tests(4)
        first, second = self.start_all(KSTYLEUI_SLOTS="1"), self.start_all(KSTYLEUI_SLOTS="1")
        outputs = [first.communicate()[0], second.communicate()[0]]
        self.assertEqual([first.returncode, second.returncode], [0, 0], outputs)
        self.assertEqual(self.overlaps(), 1)
        self.assertTrue(any("other runs held up to 1 of 1" in out for out in outputs), outputs)

    def test_a_live_holder_keeps_its_slot_until_it_lets_go(self):
        (self.tmp / "slots").mkdir()
        ready = self.tmp / "ready"
        source = ("import sys, time; from pathlib import Path; "
                  f"sys.path.insert(0, {str(REGRESSION)!r}); import runner_platform; "
                  f"guard = open({str(self.tmp / 'slots' / 'worker-slot-0.lock')!r}, 'a+b'); "
                  "assert runner_platform.try_lock(guard); "
                  f"Path({str(ready)!r}).touch(); time.sleep(30)")
        holder = subprocess.Popen([sys.executable, "-c", source])
        self.addCleanup(lambda: holder.poll() is None and holder.kill())
        deadline = time.monotonic() + 10
        while not ready.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertTrue(ready.exists(), "the native slot holder never started")
        self.timed_tests(1)
        waiting = self.start_all(KSTYLEUI_SLOTS="1")
        time.sleep(1.5)
        self.assertIsNone(waiting.poll(), "the run took a slot that a live holder has")
        self.assertFalse((self.tmp / "log").exists())
        holder.kill()
        holder.wait()
        output = waiting.communicate(timeout=20)[0]
        self.assertEqual(waiting.returncode, 0, output)
        self.assertIn("1 held by other runs", output)

    def test_prints_the_load_the_run_saw(self):
        self.timed_tests(1)
        result = self.run_all()
        self.assertRegex(result.stdout, r"machine load (?:[\d.]+|n/a) on \d+ CPUs; worker slots: 64")
        self.assertRegex(result.stdout, r"machine load (?:[\d.]+|n/a) at the start, (?:[\d.]+|n/a) at the end, (?:[\d.]+|n/a) at most when a test started; waited [\d.]+ s for worker slots")

    def test_a_time_failure_names_the_load(self):
        (self.regression / "test-slow.lua").write_text("import time; time.sleep(1.2)\n")
        result = self.run_all(TEST_TIME_BUDGET="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stdout, r"FAIL test-slow: took [\d.]+ s, over the 1 s budget")
        if hasattr(os, "getloadavg"):
            self.assertRegex(result.stdout, r"Machine load was [\d.]+ when it started")

    def test_the_limit_is_off_in_ci_and_with_zero_slots(self):
        self.timed_tests(1)
        self.assertIn("worker slots: off in CI", self.run_all(CI="true").stdout)
        self.assertIn("worker slots: off (KSTYLEUI_SLOTS=0)", self.run_all(KSTYLEUI_SLOTS="0").stdout)
        self.assertFalse((self.tmp / "slots" / "worker-slots.json").exists())

    def test_the_limit_stays_on_for_ci_on_a_self_hosted_runner(self):
        self.timed_tests(1)
        result = self.run_all(CI="true", RUNNER_ENVIRONMENT="self-hosted", KSTYLEUI_SLOTS="3")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("worker slots: 3 for every run on this machine", result.stdout)
        self.assertIn("worker slots: off in CI", self.run_all(CI="true", RUNNER_ENVIRONMENT="github-hosted").stdout)

    def test_runs_unlimited_when_the_slot_folder_cannot_be_made(self):
        self.timed_tests(1)
        blocker = self.tmp / "blocker"
        blocker.write_text("a file, not a folder\n")
        result = self.run_all(KSTYLEUI_SLOT_DIR=str(blocker / "slots"))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("worker slots: off, cannot use", result.stdout)

    # Margins.

    def test_margins_lists_the_files_within_20_percent_of_the_budget(self):
        (self.regression / "test-near.lua").write_text("import time; time.sleep(0.9)\n")
        (self.regression / "test-far.lua").write_text("import time; time.sleep(0.2)\n")
        result = self.run_all("--margins", TEST_TIME_BUDGET="1", JOBS="8")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("within 20% of the budget, run alone:", result.stdout)
        self.assertRegex(result.stdout, r"\n\s+0\.[89] s \(\s*[89]\d%\).*test-near")
        self.assertNotRegex(result.stdout, r"\(\s*\d+%\)[^\n]*test-far")
        self.assertRegex(result.stdout, r", 1 at a time\n")

    def test_margins_says_none_when_every_file_has_room(self):
        (self.regression / "test-far.lua").write_text("pass\n")
        result = self.run_all("--margins")
        self.assertIn("within 20% of the budget, run alone: none", result.stdout)

    def test_margins_cannot_write_weights(self):
        (self.regression / "test-a.lua").write_text("pass\n")
        self.assertEqual(self.run_all("--margins", "--write-weights").returncode, 2)

if __name__ == "__main__":
    unittest.main()
