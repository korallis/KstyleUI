"""Subprocess CPU budgets must not count time lost to other workers."""
import ast
from pathlib import Path
import unittest


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


if __name__ == "__main__":
    unittest.main()
