"""Exercise timing verdicts through the real Lua measurement and perf runner code."""

import os
from pathlib import Path
import shutil
import unittest

from Tools.tests.subprocess_budget import run

LUA = shutil.which("lua5.1") or str(Path.home() / ".local/bin/lua5.1")
ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(os.path.isfile(LUA), "PUC Lua 5.1 is needed")
class PerfPolicyTest(unittest.TestCase):
    def test_instruction_sampling_keeps_budgets_and_errors_fatal(self):
        source = '''
local budget = dofile("Tools/regression/instruction_budget.lua")
local work = assert(loadstring("return function() local n = 0; for i = 1, 10000 do n = n + i end end", "@Core/BudgetProbe.lua"))()
for _, step in ipairs({ 1, 100 }) do
    assert(budget(work, 100000, "fix probe", step) > 10000)
    local ok, err = pcall(budget, work, 1, "fix probe", step)
    assert(not ok and err:find("fix probe", 1, true))
    assert(debug.gethook() == nil, "a failed budget must leave no hook")
end
local ok, err = pcall(budget, function() error("probe error") end, 100000, "fix probe", 100)
assert(not ok and err:find("probe error", 1, true))
assert(debug.gethook() == nil, "a raised error must leave no hook")
'''
        result = run([LUA, "-e", source], cwd=ROOT, capture_output=True, text=True, cpu_budget=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def probe(self, ci, platform, environment, allocation=False):
        source = '''
package.config = os.getenv("RUNNER_OS") == "Windows" and string.char(92) or "/"
local Measure = dofile("Tools/regression/measure.lua")
Measure.Run = function()
    return { time = 0.01, addonKb = %s, kb = 0, sites = { { where = "Core/Fake.lua:1", bytes = 1 } } }
end
local files = { "Core.lua", "KstyleUI_ActionBars.lua", "KstyleUI_CombatText.lua", "KstyleUI_Cooldowns.lua",
    "KstyleUI_GroupFrames.lua", "KstyleUI_Meters.lua", "KstyleUI_Tooltips.lua", "KstyleUI_Nameplates.lua",
    "KstyleUI_UnitFrames.lua", "KstyleUI_Skins.lua", "KstyleUI_DataBars.lua", "KstyleUI_Minimap.lua" }
local real = dofile
dofile = function(path)
    if path == "Tools/regression/measure.lua" then return Measure end
    if path == "Tools/regression/fs.lua" then return { list = function() return files end } end
    return real(path)
end
loadfile = function(path)
    return function()
        return { { name = path, budget = 1, setup = function()
            return { SetCombat = function() end, RunTimers = function() end, SetQuiet = function() end,
                _errors = {} }, function() end
        end } }
    end
end
dofile("Tools/regression/perf_runner.lua")("hud")
''' % ("1" if allocation else "0")
        return run([LUA, "-e", source], cwd=ROOT, capture_output=True, text=True, cpu_budget=20,
                   env=dict(os.environ, CI=ci, RUNNER_OS=platform, RUNNER_ENVIRONMENT=environment))

    def test_only_mac_ci_fails_time_and_headroom(self):
        for ci, platform, environment, fatal in (
                ("true", "macOS", "self-hosted", True), ("false", "macOS", "", False),
                ("true", "Linux", "github-hosted", False), ("true", "Linux", "self-hosted", False),
                ("true", "Windows", "self-hosted", False)):
            with self.subTest(ci=ci, platform=platform, environment=environment):
                result = self.probe(ci, platform, environment)
                self.assertEqual(result.returncode, int(fatal), result.stdout + result.stderr)
                self.assertIn("over its budget", result.stdout)
                if environment == "github-hosted":
                    self.assertIn("HeadroomProblem skipped", result.stdout)
                    self.assertNotIn("set it to at least", result.stdout)

    def test_allocations_fail_on_every_platform(self):
        for platform, environment in (("macOS", "self-hosted"), ("Linux", "github-hosted"),
                                       ("Linux", "self-hosted"), ("Windows", "self-hosted")):
            with self.subTest(platform=platform):
                result = self.probe("true", platform, environment, allocation=True)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("allocates", result.stdout)
