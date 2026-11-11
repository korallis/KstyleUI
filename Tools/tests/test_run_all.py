"""Tests for Tools/regression/run-all.sh and the runner it starts, run_all.py.

The runner only runs "<interpreter> <file>", so sh stands in for Lua and the test files hold shell commands.
"""

import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

REGRESSION = Path(__file__).resolve().parents[1] / "regression"
BASH = shutil.which("bash")


class RunAllTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.regression = self.tmp / "Tools" / "regression"
        self.regression.mkdir(parents=True)
        for name in ("run-all.sh", "run_all.py", "affected.py", "trace.lua"):
            shutil.copy(REGRESSION / name, self.regression / name)
        (self.regression / "helper.lua").write_text("exit 1\n")

    def tearDown(self):
        self._tmp.cleanup()

    def run_all(self, *args, lua="sh", **changes):
        env = {key: value for key, value in os.environ.items() if key not in ("CI", "RUNNER_ENVIRONMENT", "LUA", "TEST_TIME_BUDGET", "TEST_MEMORY_BUDGET")}
        env.update(KSTYLEUI_SLOT_DIR=str(self.tmp / "slots"), KSTYLEUI_SLOTS="64")
        if lua is not None:
            env["LUA"] = lua
        for key, value in changes.items():
            if value is None:
                env.pop(key, None)
            else:
                env[key] = value
        return subprocess.run([BASH, str(self.regression / "run-all.sh"), *args], env=env, capture_output=True, text=True)

    def start_all(self, **changes):
        env = dict(os.environ, LUA="sh", KSTYLEUI_SLOT_DIR=str(self.tmp / "slots"), KSTYLEUI_SLOTS="64", JOBS="4")
        env.pop("CI", None)
        env.pop("RUNNER_ENVIRONMENT", None)
        env.update(changes)
        return subprocess.Popen([BASH, str(self.regression / "run-all.sh")], env=env, stdout=subprocess.PIPE, text=True)

    def write_slots(self, *holders):
        (self.tmp / "slots").mkdir(exist_ok=True)
        (self.tmp / "slots" / "worker-slots.json").write_text(json.dumps(
            [{"pid": pid, "token": f"t{i}", "until": time.time() + until} for i, (pid, until) in enumerate(holders)]))

    def fake_bin(self, *names):
        """A PATH with python3 and a fake interpreter per name that records its name and arguments."""
        folder = self.tmp / "bin"
        folder.mkdir(exist_ok=True)
        os.symlink(sys.executable, folder / "python3")
        for name in names:
            self.fake_lua(folder / name)
        return str(folder)

    def fake_lua(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f'#!/bin/sh\necho "{path.name} $*" >> "{self.tmp}/ran"\n')
        path.chmod(0o755)

    def ran(self):
        return (self.tmp / "ran").read_text()

    def test_counts_passes_and_failures(self):
        (self.regression / "test-pass.lua").write_text("echo fine\n")
        lines = "".join(f"echo line{i}\n" for i in range(1, 8))
        (self.regression / "test-fail.lua").write_text(lines + "exit 1\n")
        result = self.run_all()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL test-fail", result.stdout)
        self.assertIn("line7", result.stdout)
        self.assertIn("line3", result.stdout)
        self.assertNotIn("line2", result.stdout)
        self.assertNotIn("FAIL test-pass", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 1, failed 1"))

    def test_exits_0_when_all_pass(self):
        (self.regression / "test-a.lua").write_text("true\n")
        (self.regression / "test-b.lua").write_text("true\n")
        result = self.run_all()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 2, failed 0"))

    def test_runs_from_the_repository_root(self):
        (self.regression / "test-cwd.lua").write_text("test -d Tools/regression\n")
        result = self.run_all()
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_runs_tests_in_parallel(self):
        # Two tests that each wait for the other's marker finish only when they run at the same time.
        (self.regression / "test-x.lua").write_text(
            f"touch {self.tmp}/x; for i in $(seq 50); do [ -e {self.tmp}/y ] && exit 0; sleep 0.1; done; exit 1\n")
        (self.regression / "test-y.lua").write_text(
            f"touch {self.tmp}/y; for i in $(seq 50); do [ -e {self.tmp}/x ] && exit 0; sleep 0.1; done; exit 1\n")
        result = self.run_all(JOBS="2")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 2, failed 0"))

    def test_reports_failures_in_file_order(self):
        for name in ("test-c.lua", "test-a.lua", "test-b.lua"):
            (self.regression / name).write_text("exit 1\n")
        result = self.run_all()
        self.assertNotEqual(result.returncode, 0)
        order = [line for line in result.stdout.splitlines() if line.startswith("FAIL ")]
        self.assertEqual(order, ["FAIL test-a", "FAIL test-b", "FAIL test-c"])

    def test_fails_when_no_tests_exist(self):
        result = self.run_all()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no tests found", result.stdout)

    def test_stops_with_one_message_when_lua_is_missing(self):
        (self.regression / "test-a.lua").write_text("true\n")
        (self.regression / "test-b.lua").write_text("true\n")
        result = self.run_all(lua="no-such-lua-kstyleui")
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn("no-such-lua-kstyleui not found", result.stdout)
        self.assertNotIn("FAIL", result.stdout)

    # Slices of the files, for CI.

    def marking_tests(self, names):
        for name in names:
            (self.regression / f"test-{name}.lua").write_text(f"echo {name} >> {self.tmp}/marks\n")

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
        (self.regression / "test-fast.lua").write_text("true\n")
        (self.regression / "test-slow.lua").write_text("sleep 1.5\n")
        result = self.run_all(TEST_TIME_BUDGET="1")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        line = next((line for line in result.stdout.splitlines() if line.startswith("FAIL test-slow")), "")
        self.assertRegex(line, r"^FAIL test-slow: took 1\.\d s, over the 1 s budget\. Make the test cheaper; CI runs Lua 5\.1")
        self.assertNotIn("FAIL test-fast", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 1, failed 1"))

    def test_passes_tests_within_the_time_budget(self):
        (self.regression / "test-fast.lua").write_text("sleep 0.1\n")
        result = self.run_all(TEST_TIME_BUDGET="1")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("passed 1, failed 0"))

    def test_stops_a_test_at_three_times_the_budget(self):
        (self.regression / "test-hang.lua").write_text("exec sleep 30\n")
        start = time.monotonic()
        result = self.run_all(TEST_TIME_BUDGET="0.5")
        self.assertLess(time.monotonic() - start, 10, result.stdout)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL test-hang: stopped after 1.5 s, 3 times the 0.5 s budget", result.stdout)

    def test_stopping_the_runner_stops_its_tests(self):
        for sig in (signal.SIGINT, signal.SIGTERM):
            with self.subTest(signal=sig.name):
                pidfile = self.tmp / f"pid-{sig.name}"
                (self.regression / "test-hang.lua").write_text(f"echo $$ > {pidfile}.tmp; mv {pidfile}.tmp {pidfile}; exec sleep 30\n")
                env = {key: value for key, value in os.environ.items() if key != "CI"}
                runner = subprocess.Popen([BASH, str(self.regression / "run-all.sh")], env=dict(env, LUA="sh", KSTYLEUI_SLOT_DIR=str(self.tmp / "slots"), KSTYLEUI_SLOTS="64"),
                                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                deadline = time.monotonic() + 10
                while not pidfile.exists() and time.monotonic() < deadline:
                    time.sleep(0.05)
                test_pid = int(pidfile.read_text())
                runner.send_signal(sig)
                runner.wait(timeout=5)
                time.sleep(0.2)
                with self.assertRaises(ProcessLookupError, msg="the test outlived the runner"):
                    os.kill(test_pid, 0)

    def test_the_default_budget_is_20_s_and_four_times_that_on_ci(self):
        (self.regression / "test-a.lua").write_text("true\n")
        self.assertIn("budget 20 s", self.run_all().stdout)
        self.assertIn("budget 80 s", self.run_all(CI="true").stdout)

    # The memory budget.

    def test_fails_a_test_over_the_memory_budget(self):
        (self.regression / "test-small.lua").write_text("true\n")
        (self.regression / "test-big.lua").write_text(f"exec '{sys.executable}' -c 'x = b\"1\" * (300 << 20)'\n")
        result = self.run_all(TEST_MEMORY_BUDGET="200")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        line = next((line for line in result.stdout.splitlines() if line.startswith("FAIL test-big")), "")
        self.assertRegex(line, r"^FAIL test-big: peaked at \d+ MB, over the 200 MB budget\. Make the test use less memory")
        self.assertNotIn("FAIL test-small", result.stdout)

    # The summary.

    def test_prints_the_slowest_five_and_the_total(self):
        for i, seconds in enumerate(("0", "0.2", "0.4", "0.6", "0.8", "1.0")):
            (self.regression / f"test-{i}.lua").write_text(f"sleep {seconds}\n")
        result = self.run_all(JOBS="6")
        self.assertEqual(result.returncode, 0, result.stdout)
        lines = result.stdout.splitlines()
        start = lines.index("slowest:")
        slowest = [re.sub(r"^\s+[\d.]+ s\s+\d+ MB\s+", "", line) for line in lines[start + 1:start + 6]]
        self.assertEqual(slowest, ["test-5", "test-4", "test-3", "test-2", "test-1"])
        self.assertRegex(result.stdout, r"\ntotal [\d.]+ s of test time in [\d.]+ s, 6 at a time\n")

    # The machine-wide worker limit.

    def overlaps(self):
        """The most test files that were running at once, from the start and end lines the tests append to a log."""
        running = most = 0
        for line in (self.tmp / "log").read_text().split():
            running += 1 if line == "start" else -1
            most = max(most, running)
        return most

    def timed_tests(self, count):
        for i in range(count):
            (self.regression / f"test-{i}.lua").write_text(f"echo start >> {self.tmp}/log; sleep 0.3; echo end >> {self.tmp}/log\n")

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

    def test_a_holder_whose_process_is_gone_or_whose_lease_ran_out_is_dropped(self):
        dead = subprocess.Popen(["true"])
        dead.wait()
        self.write_slots((dead.pid, 600), (os.getpid(), -5))
        self.timed_tests(1)
        result = self.run_all(KSTYLEUI_SLOTS="2")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("0 held by other runs", result.stdout)
        self.assertEqual(json.loads((self.tmp / "slots" / "worker-slots.json").read_text()), [])

    def test_a_live_holder_keeps_its_slot_until_it_lets_go(self):
        holder = subprocess.Popen(["sleep", "30"])
        self.addCleanup(holder.kill)
        self.write_slots((holder.pid, 600))
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
        self.assertRegex(result.stdout, r"machine load [\d.]+ on \d+ CPUs; worker slots: 64")
        self.assertRegex(result.stdout, r"machine load [\d.]+ at the start, [\d.]+ at the end, [\d.]+ at most when a test started; waited [\d.]+ s for worker slots")

    def test_a_time_failure_names_the_load(self):
        (self.regression / "test-slow.lua").write_text("sleep 1.2\n")
        result = self.run_all(TEST_TIME_BUDGET="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stdout, r"FAIL test-slow: took [\d.]+ s, over the 1 s budget\..* Machine load was [\d.]+ when it started")

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
        (self.regression / "test-near.lua").write_text("sleep 0.9\n")
        (self.regression / "test-far.lua").write_text("sleep 0.2\n")
        result = self.run_all("--margins", TEST_TIME_BUDGET="1", JOBS="8")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("within 20% of the budget, run alone:", result.stdout)
        self.assertRegex(result.stdout, r"\n\s+0\.[89] s \(\s*[89]\d%\).*test-near")
        self.assertNotRegex(result.stdout, r"\(\s*\d+%\)[^\n]*test-far")
        self.assertRegex(result.stdout, r", 1 at a time\n")

    def test_margins_says_none_when_every_file_has_room(self):
        (self.regression / "test-far.lua").write_text("true\n")
        result = self.run_all("--margins")
        self.assertIn("within 20% of the budget, run alone: none", result.stdout)

    def test_margins_cannot_write_weights(self):
        (self.regression / "test-a.lua").write_text("true\n")
        self.assertEqual(self.run_all("--margins", "--write-weights").returncode, 2)

    # The interpreter.

    def test_prefers_lua51_on_the_path(self):
        (self.regression / "test-a.lua").write_text("true\n")
        result = self.run_all(lua=None, PATH=self.fake_bin("lua5.1", "luajit"), HOME=str(self.tmp))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.ran(), "lua5.1 Tools/regression/test-a.lua\n")
        self.assertIn("Lua 5.1, as CI runs", result.stdout)

    def test_finds_lua51_in_the_home_local_bin(self):
        (self.regression / "test-a.lua").write_text("true\n")
        self.fake_lua(self.tmp / ".local" / "bin" / "lua5.1")
        result = self.run_all(lua=None, PATH=self.fake_bin("luajit"), HOME=str(self.tmp))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.ran(), "lua5.1 Tools/regression/test-a.lua\n")

    def test_falls_back_to_luajit_without_the_jit(self):
        (self.regression / "test-a.lua").write_text("true\n")
        result = self.run_all(lua=None, PATH=self.fake_bin("luajit"), HOME=str(self.tmp))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.ran(), "luajit -joff Tools/regression/test-a.lua\n")
        self.assertIn("install-lua51.sh", result.stdout)

    def test_stops_when_no_lua_is_installed(self):
        (self.regression / "test-a.lua").write_text("true\n")
        result = self.run_all(lua=None, PATH=self.fake_bin(), HOME=str(self.tmp))
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn("install-lua51.sh", result.stdout)

    def test_labels_luajit_with_the_jit_as_fast_mode(self):
        (self.regression / "test-a.lua").write_text("true\n")
        path = self.fake_bin("luajit")
        fast = self.run_all(lua="luajit", PATH=path, HOME=str(self.tmp))
        self.assertEqual(fast.returncode, 0, fast.stdout)
        self.assertIn("fast mode, not CI-equivalent", fast.stdout)
        interpreted = self.run_all(lua="luajit -joff", PATH=path, HOME=str(self.tmp))
        self.assertNotIn("fast mode", interpreted.stdout)
        self.assertEqual(self.ran().splitlines()[-1], "luajit -joff Tools/regression/test-a.lua")


if __name__ == "__main__":
    unittest.main()
