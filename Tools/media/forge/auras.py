"""Bake the crest's animated auras into Media/Textures/Auras/: one looping flip-book sheet per mark, and the empty socket they burn in.

An aura is a mark's own figure made of moving spell light. Its design (designs_<class>.py, Tools/media/sigils.py) gives
the silhouette and relief; this writes a signed distance field and a ridge map from them, has Blender render 16
frames at 512 px with EEVEE (aura.py), reduces each frame to a 128 px cell in linear light, fades the light before the
socket's gilt rim (a mark seated on a plate) or the cell's edge (a bare figure or a sigil), and packs a 4x4 sheet of
512x512, the shape of the class ambient sheets. The crest plays it with an engine FlipBook added over the socket
(Core/Tokens.lua aura<Kind><Name>, KstyleUI_ActionBars/SlabMedals.lua Medals.Mark).

The socket is a forged coin with its figure taken out, the dark plate and gilt rim only, forged by forge.py and
finished as marks.py finishes a coin. Each mark's colour is its spell's colour in Core/Tokens.lua; gilt keeps the amber
spell fire of the approved hunter mock.

    python3 Tools/media/forge/auras.py [--blender PATH] [--work DIR] [--only Name,Name,Socket] [--out DIR]

Needs Blender 5.x (BLENDER, --blender or blender on the PATH), numpy, Pillow and scipy.
"""
import argparse
import hashlib
import json
import os
import re
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

import melee_effects
import sigils
from finish import load, outline, resize, save, to_lin, to_srgb
from relief import N, Emblem, forge_lineart

FRAMES, MASTER, CELL, GRID = 16, 512, 128, 4
PAD = 410                 # field padding in map pixels, so warped flame lookups past the box still read distance
REACH = 170.0             # map pixels of distance from the outline to the field's 0 or 1
RIM_INNER = 0.49 - 0.045  # the socket plate's radius as a share of the box (relief.Emblem.seat)
SPAN = 1.25               # a bare figure's cell is this much wider than the figure, so its flames have room
EDGE = 3                  # cell pixels over which a bare figure's light fades before the cell's edge

# mark: (kind, Core/Tokens.lua colour, design). A "glyphs" mark's design is its factory in the class's designs module
# (designs_hunter.D["Hawk"]), whose emblem seats on the socket when it has a seated figure; a "sigils" mark draws
# Tools/media/sigils.py's figure of its name and takes None; an "effects" mark (named Effects/<Art>) is a crest object of
# Tools/media/melee_effects.py, its design the function drawing it, lit in place in its own box so the crest can lay its
# light over the object's fill. Each class adds its marks as it takes the kit. A mark in "white" bakes a neutral light the
# game tints: a racial, a potion or Sprint is on every class's rail in that class's colour, and an object takes its
# piece's colour, which a seal's school or a picked weapon changes.
MARKS = {}
NEUTRAL = "white"

# Warrior, paladin and rogue: each class's sigils in its rail's colour (SlabTrackers.lua crestCooldowns), the shared
# sigils and the crest objects in neutral light.
for colour, names in (("gilt", "Crossed Skull Wall Heart Sweep Thorns"), ("white", "Bubble Aegis Sun Hand Wing Bulwark Voice"),
                      ("pipPriestGlow", "Flurry Rush Evade Drop Smoke Ghost"),
                      (NEUTRAL, "Dash Axe Tusks Stone Eye Grave Shatter Star Gear Regen Potion")):
    for name in names.split():
        MARKS[name] = ("sigils", colour, None)
for name, (art, threshold) in {"Horn": ("Horn.png", 0.5), "Sword": ("Sword.png", 0.5), "Axe": ("Axe.png", 0.5),
                               "Dagger": ("Dagger.png", 0.5), "Hammer": ("Hammer.png", 0.5), "Shield": ("Shield.png", 0.5),
                               "Seal": ("Seal.png", 0.5), "Brand": ("Brand.png", 0.5), "Drop": ("Drop.png", 0.5),
                               "Vial": ("Vial.png", 0.5), "Ward": ("Ward.png", 0.5), "Oath": ("Oath.png", 0.3),
                               "Stain": ("Stain.png", 0.3)}.items():
    MARKS["Effects/" + name] = ("effects", NEUTRAL, (art, threshold))
# the amber spell fire of the approved hawk mock: dark ember to the crest's gilt to white heat
GILT = [[0.0, "000000"], [0.06, "2a0a02"], [0.18, "a8320a"], [0.34, "f26a12"], [0.52, "ffb22e"], [0.72, "ffe39a"], [1.0, "fffdf4"]]


def colours():
    text = (ROOT / "Core/Tokens.lua").read_text()
    return {m.group(1): m.group(2) for m in re.finditer(r'^\s*(\w+) = \{ "([0-9a-fA-F]{6})", [\d.]+ \}', text, re.M)}


def palette(hexv):
    """A ramp from black through the colour, deepened below it and paled above it, to near white."""
    if hexv.lower() == "d3b574":
        return GILT
    c = np.array([int(hexv[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    grey = c.mean()
    deep = np.clip(grey + (c - grey) * 1.4, 0, 1)
    stops = [(0.0, c * 0), (0.06, deep * 0.12), (0.18, deep * 0.42), (0.34, c * 0.78), (0.52, c), (0.72, c + (1 - c) * 0.5),
             (1.0, c + (1 - c) * 0.94)]
    return [[pos, "".join(f"{int(round(v * 255)):02x}" for v in np.clip(col, 0, 1))] for pos, col in stops]


def figure(name, kind, design, work):
    """The mark's figure mask and relief height in its own unit box, and whether it sits on a plate."""
    if kind == "sigils":
        pen = sigils.Pen()
        sigils.GLYPHS[name](pen)
        e = forge_lineart(name, pen.image, work / "maps")
        return e.M, e.H, False
    if kind == "effects":
        art, threshold = design
        rgb, alpha = (melee_effects.ART.get(art) or melee_effects.BAND_ART[art])()
        alpha = np.asarray(Image.fromarray(alpha.astype(np.float32)).resize((N, N), Image.BILINEAR))
        tone = np.asarray(Image.fromarray(rgb[..., 0].astype(np.float32)).resize((N, N), Image.BILINEAR))
        mask = alpha > threshold
        return mask, np.where(mask, 0.3 + tone, 0), False
    e = design()
    if e.figure is not None:
        return e.figure, np.where(e.figure, e.H, 0), True
    lit = e.M if e.dark is None else e.M & ~e.dark  # a shaded mouth stays dark metal, not light
    return lit, np.where(lit, e.H, 0), False


def fields(name, mask, height, folder):
    folder.mkdir(parents=True, exist_ok=True)
    inside = np.pad(mask, PAD)
    sd = ndi.distance_transform_edt(~inside) - ndi.distance_transform_edt(inside)
    sdf = np.clip(0.5 + sd / (2 * REACH), 0, 1)
    Image.fromarray((sdf * 65535).astype(np.uint16)).save(folder / f"{name}_sdf.png")
    h = height / max(float(height[mask].max()), 1e-6)
    hs = ndi.gaussian_filter(h, 2.0)
    g = np.hypot(ndi.sobel(hs, 0), ndi.sobel(hs, 1)) * mask
    g = np.clip(g / max(float(np.percentile(g[mask], 99.0)), 1e-6), 0, 1) ** 0.8
    ridge = np.clip(0.8 * g + 0.2 * hs, 0, 1) * mask
    Image.fromarray((ridge * 65535).astype(np.uint16)).save(folder / f"{name}_ridge.png")


def fade(seated):
    """The cell's light falls off before the socket's rim, or before the cell's edge for a bare figure."""
    yy, xx = np.mgrid[0:CELL, 0:CELL]
    c = (CELL - 1) / 2
    if seated:
        r = np.hypot(xx - c, yy - c)
        return np.clip((RIM_INNER * CELL - 2 - r) / 3.0, 0, 1)[..., None]
    edge = np.minimum(np.minimum(xx, CELL - 1 - xx), np.minimum(yy, CELL - 1 - yy))
    return np.clip(edge / EDGE, 0, 1)[..., None]


def loop_start(cells):
    """The cell the sheet starts on. The fields are periodic, so the seam is one more step of the cycle, but any one step
    can still be the cycle's largest; the game then shows its biggest jump at the wrap. Then the sheet starts after the
    smallest step instead, the same 16 cells in the same cyclic order."""
    steps = [float(np.abs(cells[(i + 1) % FRAMES] - cells[i]).mean()) for i in range(FRAMES)]
    if steps[-1] <= max(steps[:-1]):
        return 0
    return (steps.index(min(steps)) + 1) % FRAMES


def bake(frames, seated, path):
    """16 master frames to one 4x4 sheet of 128 px cells; returns the loop's seam step against its largest ordinary step."""
    k = fade(seated)
    cells = []
    for f in frames:
        lin = to_lin(np.asarray(Image.open(f).convert("RGB"), np.float32) / 255)
        small = np.stack([np.asarray(Image.fromarray(lin[..., i]).resize((CELL, CELL), Image.LANCZOS)) for i in range(3)], -1)
        cells.append(to_srgb(np.clip(small, 0, 1)) * k)
    start = loop_start(cells)
    cells = cells[start:] + cells[:start]
    sheet = np.zeros((CELL * GRID, CELL * GRID, 3), np.float32)
    for i, cell in enumerate(cells):
        y, x = divmod(i, GRID)
        sheet[y * CELL:(y + 1) * CELL, x * CELL:(x + 1) * CELL] = cell
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((np.clip(sheet, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(path, optimize=True)
    steps = [float(np.abs(cells[(i + 1) % FRAMES] - cells[i]).mean()) for i in range(FRAMES)]
    return steps[-1] / max(max(steps[:-1]), 1e-9)


def socket(work, blender, env, out):
    """The empty coin: relief.Emblem.seat's plate and rim with no figure, forged and finished as a coin is."""
    e = Emblem("Socket")
    yy, xx = np.mgrid[0:N, 0:N]
    far = np.hypot(xx - N / 2, yy - N / 2)
    disc = far <= 0.49 * N
    e.dark = disc & (far <= RIM_INNER * N)
    e.H = np.where(e.dark, 0.12, 0.0).astype(np.float32)
    e.M = disc
    e.add(disc & (far > RIM_INNER * N), h=0.5, r=0.045 / 2, base=0.2)
    e.save(work / "socket")
    renders = work / "socket-renders"
    subprocess.run([blender, "-b", "--factory-startup", "--python-exit-code", "1", "-P", str(HERE / "forge.py"), "--",
                    str(work / "socket"), str(renders), "--only", "Socket"], check=True, stdout=subprocess.DEVNULL, env=env)
    path = out / "Socket.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    save(resize(outline(load(renders / "Socket.png")), CELL), path)
    return path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--blender", default=os.environ.get("BLENDER") or shutil.which("blender"))
    parser.add_argument("--work", type=Path, help="keep the fields and the 512 px frames here")
    parser.add_argument("--only", default="", help="comma-separated mark names, or Socket")
    parser.add_argument("--out", type=Path, default=ROOT / "Media/Textures/Auras")
    args = parser.parse_args(argv)
    if not args.blender:
        parser.error("no Blender found; set BLENDER or pass --blender")
    only = set(filter(None, args.only.split(",")))
    unknown = only - set(MARKS) - {"Socket"}
    if unknown:
        parser.error("unknown mark: " + ", ".join(sorted(unknown)))
    work = args.work or Path(tempfile.mkdtemp(prefix="auras-"))
    env = dict(os.environ)
    env.setdefault("BLENDER_USER_RESOURCES", str(work / "blender-user"))
    hexes = colours()
    if not only or "Socket" in only:
        path = socket(work, args.blender, env, args.out)
        print(path.relative_to(args.out), hashlib.sha256(path.read_bytes()).hexdigest())
    for name, (kind, colour, design) in MARKS.items():
        if only and name not in only:
            continue
        mask, height, seated = figure(name.split("/")[-1], kind, design, work)
        stem = name.replace("/", "")
        fields(stem, mask, height, work / "fields")
        frames = work / "frames" / stem
        shutil.rmtree(frames, ignore_errors=True)
        subprocess.run([args.blender, "-b", "--factory-startup", "--python-exit-code", "1", "--python", str(HERE / "aura.py"), "--",
                        str(work / "fields"), stem, str(frames), "--frames", str(FRAMES), "--size", str(MASTER),
                        "--palette", json.dumps(palette(hexes[colour])), "--fit", str(1.0 if seated else 1 / SPAN),
                        "--plate", str(RIM_INNER if seated else 0.0), "--pad", str(PAD / (N + 2 * PAD))],
                       check=True, stdout=subprocess.DEVNULL, env=env)
        path = args.out / kind.capitalize() / f"{name.split('/')[-1]}.png"
        seam = bake([frames / f"{stem}_{i:02d}.png" for i in range(FRAMES)], seated, path)
        print(path.relative_to(args.out), hashlib.sha256(path.read_bytes()).hexdigest(), f"seam {seam:.2f}x largest ordinary step",
              "seated" if seated else "bare")
    if not args.work:
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
