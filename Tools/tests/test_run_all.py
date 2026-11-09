"""Tests for Tools/regression/run-all.sh and the runner it starts, run_all.py.

The runner only runs "<interpreter> <file>", so sh stands in for Lua and the test files hold shell commands.
"""

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
        for name in ("run-all.sh", "run_all.py"):
            shutil.copy(REGRESSION / name, self.regression / name)
        (self.regression / "helper.lua").write_text("exit 1\n")

    def tearDown(self):
        self._tmp.cleanup()

    def run_all(self, lua="sh", **changes):
        env = {key: value for key, value in os.environ.items() if key not in ("CI", "LUA", "TEST_TIME_BUDGET", "TEST_MEMORY_BUDGET")}
        if lua is not None:
            env["LUA"] = lua
        for key, value in changes.items():
            if value is None:
                env.pop(key, None)
            else:
                env[key] = value
        return subprocess.run([BASH, str(self.regression / "run-all.sh")], env=env, capture_output=True, text=True)

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
                runner = subprocess.Popen([BASH, str(self.regression / "run-all.sh")], env=dict(env, LUA="sh"),
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
