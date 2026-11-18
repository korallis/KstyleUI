"""Subprocess CPU budgets must not count time lost to other workers."""
import ast
import contextlib
import io
import os
from pathlib import Path
import sys
import unittest
from unittest import mock

from Tools.tests import subprocess_budget


class BudgetPolicy(unittest.TestCase):
    def test_test_commands_do_not_use_wall_time_as_a_cpu_budget(self):
        offenders = []
        for path in Path(__file__).parent.glob("test_*.py"):
            for node in ast.walk(ast.parse(path.read_text(encoding="utf-8"))):
                if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                        and isinstance(node.func.value, ast.Name) and node.func.value.id == "subprocess"
                        and node.func.attr == "run" and any(arg.arg == "timeout" for arg in node.keywords)):
                    offenders.append(f"{path.name}:{node.lineno}")
        self.assertEqual(offenders, [], "Use Tools.tests.subprocess_budget.run with cpu_budget; "
                         "a fixed subprocess.run timeout confuses machine load with CPU cost: " + ", ".join(offenders))


class ChildBudgets(unittest.TestCase):
    def run_python(self, source, cpu_budget=1):
        return subprocess_budget.run([sys.executable, "-c", source], cpu_budget=cpu_budget)

    def test_hang_guard_keeps_the_floor_and_scales_with_the_cpu_budget(self):
        self.assertEqual(subprocess_budget.hang_limit(None), 120)
        self.assertEqual(subprocess_budget.hang_limit(10), 120)
        self.assertEqual(subprocess_budget.hang_limit(90), 450)

    def test_waiting_does_not_spend_the_cpu_budget(self):
        with mock.patch.dict(os.environ, CI="true"), mock.patch.object(sys, "platform", "darwin"):
            result = self.run_python("import time; time.sleep(0.5); print('finished')", cpu_budget=0.25)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "finished\n")
        self.assertGreater(result.wall_seconds, 0.5)
        self.assertLess(result.cpu_seconds, 0.25)

    def test_a_hung_child_is_killed_and_reports_cpu_and_wall_time(self):
        with mock.patch.object(subprocess_budget, "hang_limit", return_value=0.3):
            with self.assertRaisesRegex(AssertionError, r"hang guard:.*cpu=[\d.]+ s wall=[\d.]+ s"):
                self.run_python("import time; time.sleep(30)")

    def test_real_cpu_overrun_fails_on_mac_ci_and_warns_elsewhere(self):
        busy = "import time; start = time.process_time()\nwhile time.process_time() - start < 0.15: pass"
        for ci, platform, strict in (("true", "darwin", True), ("false", "darwin", False),
                                     ("true", "win32", False)):
            with self.subTest(ci=ci, platform=platform), mock.patch.dict(os.environ, CI=ci), \
                    mock.patch.object(sys, "platform", platform):
                if strict:
                    with self.assertRaisesRegex(AssertionError, r"CPU budget exceeded:.*cpu=.*wall=.*Make the test cheaper"):
                        self.run_python(busy, cpu_budget=0.05)
                else:
                    output = io.StringIO()
                    with contextlib.redirect_stderr(output):
                        result = self.run_python(busy, cpu_budget=0.05)
                    self.assertEqual(result.returncode, 0)
                    self.assertIn("WARN CPU budget exceeded:", output.getvalue())

    def test_failed_commands_include_output_and_usage(self):
        result = self.run_python("import sys; print('before failure'); sys.exit('bad fixture')")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("before failure", result.stdout)
        self.assertRegex(result.stderr, r"bad fixture\n\ncpu=[\d.]+ s wall=[\d.]+ s")

    def test_large_input_and_output_cannot_deadlock_the_accounting_wait(self):
        source = "import sys; data = sys.stdin.read(); print(data); sys.stderr.write(data)"
        data = "x" * 200_000
        result = subprocess_budget.run([sys.executable, "-c", source], cpu_budget=10, input=data)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, data + "\n")
        self.assertEqual(result.stderr, data)

    def test_missing_cpu_accounting_never_substitutes_wall_time(self):
        wait = subprocess_budget.runner_platform.wait

        def unmeasured(child):
            mb, _ = wait(child)
            return mb, None

        with mock.patch.object(subprocess_budget.runner_platform, "wait", side_effect=unmeasured):
            with mock.patch.dict(os.environ, CI="false"):
                result = self.run_python("pass")
                self.assertIsNone(result.cpu_seconds)
            with mock.patch.dict(os.environ, CI="true"), mock.patch.object(sys, "platform", "darwin"):
                with self.assertRaisesRegex(AssertionError, "Restore child CPU accounting"):
                    self.run_python("pass")

    def test_luajit_and_lua_overrides_keep_the_unbudgeted_hang_guard(self):
        for executable, env in (("luajit", {}), ("lua5.1", {"LUA": "lua5.1"})):
            with self.subTest(executable=executable), mock.patch.dict(os.environ, env, clear=True), \
                    mock.patch.object(subprocess_budget.subprocess, "Popen", side_effect=RuntimeError("probe")), \
                    mock.patch.object(subprocess_budget, "hang_limit", wraps=subprocess_budget.hang_limit) as limit:
                with self.assertRaisesRegex(RuntimeError, "probe"):
                    subprocess_budget.run([executable], cpu_budget=90)
                limit.assert_called_once_with(None)


if __name__ == "__main__":
    unittest.main()
