"""Render the hunter rail's animated sigil auras into Media/Textures/Medallions/Rail/.

Each rail seat's sigil (Tools/media/sigils.py) is raised as a relief (relief.py), rendered by Blender as a looping spell-effect
aura, 16 frames (aura_render.py: white-gold energy flowing through the strokes, green flames rising off the edges, five
circling motes), bloomed and reduced to 128 px cells in linear light, and packed 4x4 into one 512 px sheet per sigil. Each
sheet is light on black with alpha set to its brightest channel, for ADD; the crest plays it as a FlipBook
(KstyleUI_ActionBars/SlabRail.lua) and loads a sheet only for a seat the hunter has.

    python3 Tools/media/forge/rail_auras.py [--blender PATH] [--work DIR] [--only Volley,Paw] [--out DIR]

Needs Blender 5.x (BLENDER, --blender or blender on the PATH), numpy, Pillow and scipy.
"""
import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path[:0] = [str(HERE), str(HERE.parent)]

import sigils
from finish import resize, to_lin, to_srgb
from relief import forge_lineart

NAMES = ("Volley", "Paw", "Deflect", "Intimidate", "FireTrap", "Sniper", "Aimed", "Strider", "Charm")
FRAMES, GRID, CELL, RES = 16, 4, 128, 256
SIGIL = 0.62
EDGE = 3


def glow_map(mask_path, out_path, n=512):
    """The silhouette placed at SIGIL of a cell and blurred, normalised so the strokes' edge is near 1."""
    m = np.asarray(Image.open(mask_path).convert("L").resize((int(n * SIGIL),) * 2, Image.LANCZOS), np.float32) / 255
    cell = np.zeros((n, n), np.float32)
    o = (n - m.shape[0]) // 2
    cell[o:o + m.shape[0], o:o + m.shape[1]] = m
    g = ndi.gaussian_filter(cell, n * 0.045) + 0.6 * ndi.gaussian_filter(cell, n * 0.1)
    g = np.clip(g / max(float(g.max()), 1e-6) * 1.6, 0, 1)
    Image.fromarray((g * 65535).astype(np.uint16)).save(out_path)


def frame(path):
    rgb = np.asarray(Image.open(path).convert("RGB"), np.float32) / 255
    lin = to_lin(rgb)
    lin = lin + 0.45 * np.stack([ndi.gaussian_filter(lin[..., k], RES * 0.03) for k in range(3)], -1)
    return lin


def cell(lin):
    """Linear light on black to a CELL px RGBA cell: alpha the brightest channel, colour the light over it."""
    a = np.clip(lin.max(-1), 0, 1)
    rgb = np.clip(lin / np.maximum(a[..., None], 1e-6), 0, 1)
    small = resize(np.concatenate([to_srgb(rgb), a[..., None]], -1), CELL)
    ramp = np.minimum(np.arange(CELL) + 0.5, CELL - np.arange(CELL) - 0.5) / EDGE
    small[..., 3] *= np.clip(np.minimum.outer(ramp, ramp), 0, 1)
    return small


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--blender", default=os.environ.get("BLENDER") or shutil.which("blender"))
    parser.add_argument("--work", type=Path, help="keep the maps and the frames here")
    parser.add_argument("--only", default="", help="comma-separated sigil names")
    parser.add_argument("--out", type=Path, default=ROOT / "Media/Textures/Medallions/Rail")
    args = parser.parse_args(argv)
    if not args.blender:
        parser.error("no Blender found; set BLENDER or pass --blender")
    names = [n for n in NAMES if not args.only or n in args.only.split(",")]
    work = args.work or Path(tempfile.mkdtemp(prefix="auras-"))
    maps = work / "maps"
    for name in names:
        pen = sigils.Pen()
        sigils.GLYPHS[name](pen)
        forge_lineart(name, pen.image, maps)
        glow_map(maps / f"{name}_m.png", maps / f"{name}_g.png")
    subprocess.run([args.blender, "-b", "--factory-startup", "--python-exit-code", "1", "-P", str(HERE / "aura_render.py"), "--",
                    str(maps), str(work / "frames"), ",".join(names), "--frames", str(FRAMES), "--res", str(RES)], check=True, stdout=subprocess.DEVNULL)
    args.out.mkdir(parents=True, exist_ok=True)
    for name in names:
        sheet = np.zeros((GRID * CELL, GRID * CELL, 4), np.float32)
        for f in range(FRAMES):
            y, x = divmod(f, GRID)
            sheet[y * CELL:(y + 1) * CELL, x * CELL:(x + 1) * CELL] = cell(frame(work / "frames" / name / f"{f:02d}.png"))
        path = args.out / f"Aura{name}.png"
        Image.fromarray((np.clip(sheet, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)
        print(path.name, hashlib.sha256(path.read_bytes()).hexdigest())
    if not args.work:
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
