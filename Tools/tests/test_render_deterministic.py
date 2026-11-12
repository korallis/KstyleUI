"""Two renders of one tree must be byte-identical. LuaJIT seeds its string hash per process, so a pairs() loop over
string keys that creates frames or regions draws them in a different order each run and moves overlapping pixels. Each
render runs in its own process (one process always repeats its own order), through the scene step and, where Chrome is
installed, through the screenshot."""

import hashlib
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHOOT = ROOT / "Tools" / "render" / "shoot.sh"
SCENE = ROOT / "Tools" / "render" / "scenes" / "hud_reference.lua"
RUNS = 4
CONFIGS = [("1280x720", "DPS"), ("1366x768", "Healer"), ("3840x2160", "Tank")]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class RenderDeterminism(unittest.TestCase):
    def setUp(self):
        self.lua = os.environ.get("LUA") or shutil.which("luajit") or shutil.which("lua5.1")
        if not self.lua:
            self.skipTest("no Lua interpreter")

    def scene(self, out, screen, layout):
        env = dict(os.environ, RENDER_SCREEN=screen, RENDER_LAYOUT=layout, RENDER_PPU="1")
        subprocess.run([self.lua, str(SCENE), str(out)], cwd=ROOT, env=env, check=True, capture_output=True)
        return digest(out)

    def test_scene_json_is_identical_across_processes(self):
        with tempfile.TemporaryDirectory() as tmp:
            for screen, layout in CONFIGS:
                with self.subTest(screen=screen, layout=layout):
                    digests = {self.scene(Path(tmp) / "scene.json", screen, layout) for _ in range(RUNS)}
                    self.assertEqual(len(digests), 1, "the scene JSON differs between runs of one tree")

    def test_screenshot_is_identical_across_runs(self):
        chrome = os.environ.get("CHROME") or "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        if not os.access(chrome, os.X_OK):
            chrome = shutil.which("google-chrome") or shutil.which("chromium")
        if not chrome:
            self.skipTest("no Chrome")
        env = dict(os.environ, CHROME=chrome, RENDER_SCREEN="1280x720", RENDER_LAYOUT="DPS")
        with tempfile.TemporaryDirectory() as tmp:
            digests = set()
            for i in range(3):
                png = Path(tmp) / f"{i}.png"
                subprocess.run(
                    ["bash", str(SHOOT), "hud_reference", "--ppu", "0.6666666667", "--report", "--no-standins", "--out", str(png)],
                    cwd=ROOT, env=env, check=True, capture_output=True,
                )
                digests.add(digest(png))
            self.assertEqual(len(digests), 1, "the screenshot differs between runs of one tree")


if __name__ == "__main__":
    unittest.main()
