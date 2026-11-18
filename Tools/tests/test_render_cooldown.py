"""The canvas draws the serialized cooldown controls independently."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
NODE = shutil.which("node")


@unittest.skipUnless(NODE, "Node is required to exercise the canvas driver")
class CooldownCanvas(unittest.TestCase):
    def test_edge_without_swipe_and_edge_scale_and_alpha(self):
        result = subprocess.run([NODE, "-e", r'''
const assert = require("node:assert/strict");
global.window = {};
let calls = [];
function canvas() {
    const state = {};
    const ctx = new Proxy(state, {
        get: (_, name) => state[name] ?? ((...args) => calls.push([name, ...args])),
        set: (_, name, value) => { state[name] = value; calls.push([name, value]); return true; },
    });
    return {width: 0, height: 0, getContext: () => ctx};
}
global.document = {createElement: canvas};
require("./Tools/render/render.js");
(async () => {
    const item = {kind: "swipe", rect: [0,0,20,20], alpha: 1, fraction: 0.5,
                  drawSwipe: false, color: [0,0,0,0.8], edge: [0.9,0.8,0.7,0.6], edgeScale: 0.75};
    async function draw() {
        calls = [];
        await window.renderScene({screen: {width: 20, height: 20}, items: [item]},
                                 {canvas: canvas(), ppu: 2, base: ""});
    }
    await draw();
    assert.equal(calls.filter(c => c[0] === "fill").length, 0, "DrawSwipe(false) leaves the sector clear");
    assert.equal(calls.filter(c => c[0] === "stroke").length, 1, "the charge edge still draws");
    assert(calls.some(c => c[0] === "lineWidth" && c[1] === 2), "SetEdgeScale sizes the edge");
    assert(calls.some(c => c[0] === "shadowColor" && c[1] === "rgba(230,204,179,0.48)"), "edge alpha also tints its halo");
    delete item.edge;
    item.drawSwipe = true;
    await draw();
    assert.equal(calls.filter(c => c[0] === "fill").length, 1, "the enabled swipe draws");
    assert.equal(calls.filter(c => c[0] === "stroke").length, 0, "DrawEdge(false) leaves no lit hand");
})().catch(e => { console.error(e); process.exitCode = 1; });
'''], cwd=ROOT, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
