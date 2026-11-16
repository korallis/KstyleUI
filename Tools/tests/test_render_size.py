import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LUA = shutil.which("lua5.1") or shutil.which("luajit")


@unittest.skipUnless(LUA, "Lua 5.1 or LuaJIT is required")
class AutoSize(unittest.TestCase):
    def test_standalone_gallery_keeps_its_enabled_module_fit(self):
        result = subprocess.run(
            [LUA, "-"], cwd=ROOT,
            env={**os.environ, "RENDER_SIZE": "auto", "RENDER_HUD_STYLE": "Medallions", "RENDER_SCREEN": "3456x2234"},
            input='''
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local Core = dofile("Tools/regression/core_env.lua")
local _, game = Core.New({ size = "auto", fit = true })
local env, K = U.New(Common.ScreenOpts({ saved = Gallery.Saved({ "UnitFrames" }), setup = Gallery.Setup }))
local enabled = game.Setup.Layouts.Enabled("DPS", K.Store.Profile())
local maximum, fits = game.Setup.Layouts.ScaleLimit(3456, 2234, "DPS", enabled, "medallions")
local expected = game.Scale.Auto(2234, maximum, fits)
assert(math.abs(K.Scale.AppliedUserScale() - expected) < 1e-8,
    "standalone galleries must retain the game's fit for their enabled modules")
''', text=True, capture_output=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_auto_uses_the_complete_presets_game_fit(self):
        result = subprocess.run(
            [LUA, "-"], cwd=ROOT, env={**os.environ, "RENDER_SIZE": "auto", "RENDER_HUD_STYLE": "Medallions"},
            input='''
local Common = dofile("Tools/render/scenes/_common.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")
local Core = dofile("Tools/regression/core_env.lua")
local _, game = Core.New({ size = "auto", fit = true })
for _, screen in ipairs({ {3456, 2234}, {5120, 1440}, {1920, 1080} }) do
    RENDER_SCREEN = { width = screen[1], height = screen[2], size = "auto" }
    local width = game.Scale.CanvasWidth(screen[1], screen[2])
    local maximum, fits = game.Setup.Layouts.ScaleLimit(width, screen[2], "DPS", nil, "medallions")
    local expected = game.Scale.Auto(screen[2], maximum, fits)
    if screen[1] == 3456 then
        assert(math.abs(expected - 0.8158) < 0.00005, "the game's 3456x2234 fit changed")
    end
    for _, module in ipairs({ "unitframes", "actionbars", "minimap" }) do
        local scene = Hud.Module(module, { layout = "DPS", applyPreset = true })
        local actual = Hud.envs[scene].KstyleUI.Scale.AppliedUserScale()
        print(string.format("%dx%d %s auto=%.8f game=%.8f", screen[1], screen[2], module, actual, expected))
        assert(math.abs(actual - expected) < 1e-8, "RENDER_SIZE=auto must use the complete preset's game fit")
    end
end
''', text=True, capture_output=True, timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
