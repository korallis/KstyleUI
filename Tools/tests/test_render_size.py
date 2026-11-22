import os
import shutil
import unittest
from pathlib import Path

from Tools.tests.subprocess_budget import run as budgeted_run

ROOT = Path(__file__).resolve().parents[2]
LUA = shutil.which("lua5.1") or shutil.which("luajit")


@unittest.skipUnless(LUA, "Lua 5.1 or LuaJIT is required")
class AutoSize(unittest.TestCase):
    def test_auto_counts_the_enabled_third_bar_in_every_hud_environment(self):
        result = budgeted_run(
            [LUA, "-"], cwd=ROOT, env={**os.environ, "RENDER_SIZE": "auto", "RENDER_BAR3": "1"},
            input='''
local Hud = dofile("Tools/render/scenes/hud.lua")
local Core = dofile("Tools/regression/core_env.lua")
local _, medallions = Core.New({ size = "auto", fit = true })
local framesEnv, frames = Core.New({ size = "auto", fit = true })
Core.LoadSaved(framesEnv)
frames.Options.Write("HudStyle", "style", "frames")
for _, case in ipairs({ {1920, 1080}, {3456, 2234}, {5120, 1440}, {3456, 2234, "Frames"} }) do
    local game = case[3] and frames or medallions
    RENDER_HUD_STYLE = case[3]
    RENDER_SCREEN = { width = case[1], height = case[2], size = "auto" }
    local enabled = game.Setup.Layouts.Enabled("DPS")
    enabled["actionbars.bar3"] = true
    local width = game.Scale.CanvasWidth(case[1], case[2])
    local maximum, fits = game.Setup.Layouts.ScaleLimit(width, case[2], "DPS", enabled)
    local expected = game.Scale.Auto(case[2], maximum, fits)
    for _, module in ipairs({ "actionbars", "unitframes", "minimap" }) do
        local scene = Hud.Module(module, { layout = "DPS", applyPreset = true })
        local K = Hud.envs[scene].KstyleUI
        if module == "actionbars" then
            assert(K.Store.Module("ActionBars").bar3.enabled, "the scene enables bar 3")
        end
        local actual = K.Scale.AppliedUserScale()
        print(string.format("%s %dx%d %s bar3 auto=%.8f game=%.8f", case[3] or "Medallions", case[1], case[2], module, actual, expected))
        assert(math.abs(actual - expected) < 1e-8, "RENDER_BAR3=1 must be included in the addon's fit in every HUD environment")
    end
end
''', text=True, capture_output=True, cpu_budget=90,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_standalone_gallery_keeps_its_enabled_module_fit(self):
        result = budgeted_run(
            [LUA, "-"], cwd=ROOT,
            env={**os.environ, "RENDER_SIZE": "auto", "RENDER_SCREEN": "3456x2234"},
            input='''
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local Core = dofile("Tools/regression/core_env.lua")
local _, game = Core.New({ size = "auto", fit = true })
local env, K = U.New(Common.ScreenOpts({ saved = Gallery.Saved({ "UnitFrames" }), setup = Gallery.Setup }))
local enabled = game.Setup.Layouts.Enabled("DPS", K.Store.Profile())
local maximum, fits = game.Setup.Layouts.ScaleLimit(3456, 2234, "DPS", enabled)
local expected = game.Scale.Auto(2234, maximum, fits)
assert(math.abs(K.Scale.AppliedUserScale() - expected) < 1e-8,
    "standalone galleries must retain the game's fit for their enabled modules")
''', text=True, capture_output=True, cpu_budget=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_auto_uses_the_complete_presets_game_fit(self):
        result = budgeted_run(
            [LUA, "-"], cwd=ROOT, env={**os.environ, "RENDER_SIZE": "auto"},
            input='''
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Core = dofile("Tools/regression/core_env.lua")
local gameEnv, game = Core.New({ size = "auto", fit = true })
local legacyMaximum, legacyFits = game.Setup.Layouts.ScaleLimit(3456, 2234, "DPS", nil)
assert(math.abs(game.Scale.Auto(2234, legacyMaximum, legacyFits) - 0.8158) < 0.00005,
    "an absent placement retains the legacy rail fit")
Core.Boot(gameEnv)
game.Store.Module("DataBars").strip = { placement = "top" }
for _, screen in ipairs({ {3456, 2234}, {5120, 1440}, {1920, 1080} }) do
    RENDER_SCREEN = { width = screen[1], height = screen[2], size = "auto" }
    local width = game.Scale.CanvasWidth(screen[1], screen[2])
    local maximum, fits = game.Setup.Layouts.ScaleLimit(width, screen[2], "DPS", nil)
    local expected = game.Scale.Auto(screen[2], maximum, fits)
    if screen[1] == 3456 then
        assert(math.abs(expected - 0.81580125335721) < 1e-8, "the dock leaves the current Medallions Auto fit unchanged")
    end
    for _, module in ipairs({ "unitframes", "actionbars", "minimap" }) do
        local scene = Hud.Module(module, { layout = "DPS", applyPreset = true })
        local actual = Hud.envs[scene].KstyleUI.Scale.AppliedUserScale()
        print(string.format("%dx%d %s auto=%.8f game=%.8f", screen[1], screen[2], module, actual, expected))
        assert(math.abs(actual - expected) < 1e-8, "RENDER_SIZE=auto must use the complete preset's game fit")
    end
end
''', text=True, capture_output=True, cpu_budget=60,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
