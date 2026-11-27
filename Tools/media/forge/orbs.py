"""Bake the mage's power orb into Media/Textures/Medallions/Orbs/: a vessel per race, the light per school, the glass and the proc effects.

The orb replaces the crest's painted emblem in the hub's opening (KstyleUI_ActionBars/SlabOrb.lua). orb.py, the Blender rig,
renders each layer framed on its glass alone; this packs the frames for the game:

- Vessel<Race>: the race's vessel and the empty dark glass on clear film, 256 px, drawn solid.
- Light<School>: the light that fills the glass, a 16-frame loop in 256 px cells of a 4x4 sheet, additive.
- Core<School>: the star's bright heart and the rays it sheds while the cooldown is ready, 128 px cells, additive.
- Meniscus<School>: the bright band at the light's surface while it rises, a 256x32 strip, additive.
- Glass: the glass's rim and highlight over everything, 256 px, additive.
- Clear, Barrage, Heat, Rime1, Rime2: the procs (Clearcasting's glitter, Missile Barrage's three missiles, Heating Up's
  fire, Fingers of Frost's rime for one charge and the second), 128 px cells, additive; each rime is the difference its
  charge makes to the glass, so the two stack.

Layers framed on the glass are rendered with the glass at radius 1 and sized in game by the race's glass radius, so one
light serves every vessel. A loop renders twice its frames and cross-fades the second half into the first in linear
light, so it closes without a seam; the missiles circle exactly one turn instead.

    python3 Tools/media/forge/orbs.py [--blender PATH] [--work DIR] [--only Vessel,Light,...] [--out DIR]

Needs Blender 5.x (BLENDER, --blender or blender on the PATH), numpy and Pillow.
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

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path[:0] = [str(HERE)]

from finish import to_lin, to_srgb  # noqa: E402

RACES = ("human", "gnome", "orc", "scourge", "troll", "skyborne")
SCHOOLS = ("arcane", "fire", "frost")
CELLS, SECONDS, MASTER, SAMPLES = 16, 1.6, 512, 24
RIME = 1.8  # frost on glass is faint beside the light it covers
# name: (layer, school, cell px, light gain, or a gain per channel); a proc is lit in its own school, and Clearcasting's
# pale mist is tinted arcane and kept faint so the light under it still reads; Heating Up's flames
# burn only in a band round the glass's edge (RIM), where the light is dim, so each stack's third of the rim reads even over a
# full fire orb
SHEETS = {
    **{f"Light{s.capitalize()}": ("light", s, 256, 1.0) for s in SCHOOLS},
    **{f"Core{s.capitalize()}": ("core", s, 128, 1.0) for s in SCHOOLS},
    "Clear": ("clear", "arcane", 128, (0.07, 0.03, 0.1)),
    "Barrage": ("barrage", "arcane", 128, 1.0),
    "Heat": ("heat", "fire", 128, (1.6, 0.7, 0.25)),
}


def render(blender, env, work, race, layer, school="", re=0.0):
    out = work / f"{race}-{layer}-{school or 'none'}"
    shutil.rmtree(out, ignore_errors=True)
    cmd = [blender, "-b", "--factory-startup", "--python-exit-code", "1", "--python", str(HERE / "orb.py"), "--", race, str(out),
           "--repo", str(ROOT), "--layer", layer, "--size", str(MASTER), "--samples", str(SAMPLES), "--cells", str(CELLS),
           "--seconds", str(SECONDS)]
    if school:
        cmd += ["--school", school]
    if re:
        cmd += ["--re", str(re)]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, env=env)
    return sorted(out.glob(f"{layer}_*.png"))


def linear(path):
    return to_lin(np.asarray(Image.open(path).convert("RGB"), np.float32) / 255)


def loop(frames):
    """Cross-fade frames N..2N-1 into 0..N-1: frame i is (1 - i/N) of frame N+i and i/N of frame i, so the last runs on into the first."""
    n = len(frames) // 2
    if n * 2 != len(frames):
        return frames
    return [(1 - i / n) * frames[n + i] + (i / n) * frames[i] for i in range(n)]


def shrink(lin, size):
    chans = [Image.fromarray(lin[..., k].astype(np.float32)).resize((size, size), Image.LANCZOS) for k in range(3)]
    return np.clip(np.stack([np.asarray(c) for c in chans], -1), 0, None)


def write_rgb(lin, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((to_srgb(lin) * 255 + 0.5).astype(np.uint8), "RGB").save(path, optimize=True)
    return path


def fade(lin, inner, outer=1.0):
    """Fade the light to black between two radii, as shares of the half cell, so no bloom reaches the cell's square edge."""
    n = lin.shape[0]
    y, x = np.mgrid[0:n, 0:n]
    r = np.hypot(x - (n - 1) / 2, y - (n - 1) / 2) / (n / 2)
    k = np.clip((outer - r) / (outer - inner), 0, 1)
    return lin * (k * k * (3 - 2 * k))[..., None]


RIM = (0.74, 0.9, 0.975)  # inner, full and outer radius of Heating Up's band, as shares of the half cell


def rim(lin):
    n = lin.shape[0]
    y, x = np.mgrid[0:n, 0:n]
    r = np.hypot(x - (n - 1) / 2, y - (n - 1) / 2) / (n / 2)
    k = np.clip(np.minimum((r - RIM[0]) / (RIM[1] - RIM[0]), (RIM[2] - r) / (RIM[2] - RIM[1])), 0, 1)
    return lin * (k * k * (3 - 2 * k))[..., None]


def sheet(frames, cell, gain):
    grid = int(round(len(frames) ** 0.5))
    out = np.zeros((cell * grid, cell * grid, 3), np.float32)
    for i, f in enumerate(frames):
        y, x = divmod(i, grid)
        out[y * cell:(y + 1) * cell, x * cell:(x + 1) * cell] = shrink(f, cell) * np.asarray(gain, np.float32)
    return out


def vessel(blender, env, work, race, path):
    f = render(blender, env, work, race, "vessel")[0]
    img = np.asarray(Image.open(f).convert("RGBA"), np.float32) / 255
    lin = to_lin(img[..., :3]) * img[..., 3:4]
    rgb = shrink(lin, 256)
    a = np.clip(np.asarray(Image.fromarray(img[..., 3]).resize((256, 256), Image.LANCZOS)), 0, 1)
    rgb = to_srgb(rgb / np.maximum(a[..., None], 1e-6))
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((np.concatenate([rgb, a[..., None]], -1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)
    return path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--blender", default=os.environ.get("BLENDER") or shutil.which("blender"))
    parser.add_argument("--work", type=Path, help="keep the rendered frames here")
    parser.add_argument("--only", default="", help="comma-separated texture names (VesselHuman, LightArcane, Glass, Meniscus, Rime...)")
    parser.add_argument("--out", type=Path, default=ROOT / "Media/Textures/Medallions/Orbs")
    args = parser.parse_args(argv)
    if not args.blender:
        parser.error("no Blender found; set BLENDER or pass --blender")
    only = set(filter(None, args.only.split(",")))
    work = args.work or Path(tempfile.mkdtemp(prefix="orbs-"))
    env = dict(os.environ)
    env.setdefault("BLENDER_USER_RESOURCES", str(work / "blender-user"))

    def wanted(name):
        return not only or name in only or any(name.startswith(o) for o in only)

    made = []
    for race in RACES:
        name = "Vessel" + race.capitalize()
        if wanted(name):
            made.append(vessel(args.blender, env, work, race, args.out / f"{name}.png"))
    for name, (layer, school, cell, gain) in SHEETS.items():
        if wanted(name):
            # the glass's edge sits at 1/1.025 of the half cell (orb.py frames 2.05 glass radii); the core's rays fade out
            inner = 0.55 if layer == "core" else 0.95
            frames = [fade(linear(f), inner) for f in render(args.blender, env, work, "human", layer, school, 1.0)]
            # the barrage renders one exact turn of its bolts (orb.py); every other layer crossfades its two halves
            frames = frames if layer == "barrage" else loop(frames)
            frames = [rim(f) for f in frames] if layer == "heat" else frames
            made.append(write_rgb(sheet(frames, cell, gain), args.out / f"{name}.png"))
    if wanted("Glass"):
        glass = linear(render(args.blender, env, work, "human", "glass", "", 1.0)[0])
        made.append(write_rgb(shrink(glass, 256), args.out / "Glass.png"))
    for school in SCHOOLS:
        name = "Meniscus" + school.capitalize()
        if wanted(name):
            band = linear(render(args.blender, env, work, "human", "meniscus", school, 1.0)[0])
            mid = band.shape[0] // 2
            strip = band[mid - MASTER // 16:mid + MASTER // 16]
            chans = [Image.fromarray(strip[..., k].astype(np.float32)).resize((256, 32), Image.LANCZOS) for k in range(3)]
            made.append(write_rgb(np.clip(np.stack([np.asarray(c) for c in chans], -1), 0, None), args.out / f"{name}.png"))
    if wanted("Rime"):
        glass = linear(render(args.blender, env, work, "human", "glass", "frost", 1.0)[0])
        one = [linear(f) for f in render(args.blender, env, work, "human", "rime1", "frost", 1.0)]
        two = [linear(f) for f in render(args.blender, env, work, "human", "rime2", "frost", 1.0)]
        first = loop([np.clip(f - glass, 0, None) for f in one])
        second = loop([np.clip(b - a, 0, None) for a, b in zip(one, two)])
        made.append(write_rgb(sheet(first, 128, RIME), args.out / "Rime1.png"))
        made.append(write_rgb(sheet(second, 128, RIME), args.out / "Rime2.png"))
    for path in made:
        print(path.relative_to(args.out), hashlib.sha256(path.read_bytes()).hexdigest())
    if not args.work:
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
