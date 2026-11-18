import os
import shutil
import tempfile
import unittest
from pathlib import Path

from Tools.tests.subprocess_budget import run as budgeted_run

ROOT = Path(__file__).resolve().parents[2]
LUA = shutil.which("lua5.1") or shutil.which("luajit")


@unittest.skipUnless(LUA, "Lua 5.1 or LuaJIT is required")
class GalleryScenes(unittest.TestCase):
    def test_galleries_under_medallions(self):
        for scene in ("gallery_options", "gallery_unitframes", "gallery_auras_counts"):
            with self.subTest(scene=scene):
                result = budgeted_run(
                    [LUA, "-"], cwd=ROOT,
                    env={**os.environ, "RENDER_HUD_STYLE": "Medallions", "RENDER_SCREEN": "5120x1440", "RENDER_SIZE": "auto"},
                    input=f'''
RENDER_SCENE_LIB = true
local scene = dofile("Tools/render/scenes/{scene}.lua")()
local Guard = dofile("Tools/render/guard.lua")
for _, line in ipairs(scene.log) do
    assert(not line:find("error:", 1, true), line)
    assert(not line:find("anchor target unresolved", 1, true), line)
end
local findings = Guard.Check(scene)
for _, f in ipairs(findings) do print(f.kind, f.subject, f.detail) end
assert(#findings == 0, "gallery has " .. #findings .. " render guard findings")
print("{scene}: no errors, unresolved anchors or guard findings")
''', text=True, capture_output=True, cpu_budget=60,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


@unittest.skipUnless(shutil.which("node"), "Node is required")
class TexturePaths(unittest.TestCase):
    def test_cached_windows_textures_are_loaded_as_file_urls(self):
        result = budgeted_run(
            ["node", "-"], cwd=ROOT, input=r'''
const assert = require("node:assert/strict");
const requested = [];
global.window = {};
global.Image = class {
    constructor() { this.width = this.height = 16; }
    set src(value) { requested.push(value); this.onload(); }
};
const context = new Proxy({}, { get: () => () => {} });
const canvas = () => ({ getContext: () => context });
global.document = { createElement: canvas };
require("./Tools/render/render.js");
const files = ["C:\\Users\\owner\\cache\\raid.png", "D:/cache/raid.png", "/tmp/raid.png", "Media/raid.png"];
window.renderScene({ screen: { width: 100, height: 100 }, items: files.map(file => ({
    kind: "texture", file, rect: [0, 0, 16, 16], alpha: 1,
})) }, { base: "file:///repo/", canvas: canvas() }).then(() => {
    assert.deepEqual(requested, ["file:///C:/Users/owner/cache/raid.png", "file:///D:/cache/raid.png",
        "file:///tmp/raid.png", "file:///repo/Media/raid.png"]);
}).catch(error => { console.error(error); process.exitCode = 1; });
''', text=True, capture_output=True, cpu_budget=10,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


@unittest.skipUnless(LUA and shutil.which("bash"), "Lua and Bash are required")
class StrictAssets(unittest.TestCase):
    def test_strict_rejects_a_grey_texture_box(self):
        scenes = ROOT / "Tools" / "render" / "scenes"
        with tempfile.NamedTemporaryFile(mode="w", suffix=".lua", prefix="test_missing_", dir=scenes, delete=False) as script:
            script.write('''local Common = dofile("Tools/render/scenes/_common.lua")
return Common.Run(function()
    return { screen = { width = 100, height = 100 }, items = {},
        log = { "texture Interface/absent is drawn as a grey box" } }
end)
''')
        path = Path(script.name)
        try:
            result = budgeted_run(
                ["bash", "Tools/render/shoot.sh", path.stem, "--json-only", "--no-standins", "--strict"],
                cwd=ROOT, env={**os.environ, "LUA": LUA}, text=True, capture_output=True, cpu_budget=15,
            )
            self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
            self.assertIn("guard: texture Interface/absent is drawn as a grey box", result.stderr)
        finally:
            path.unlink()
            for output in (ROOT / "Tools" / "render" / "out").glob(path.stem + ".*"):
                output.unlink()


if __name__ == "__main__":
    unittest.main()
