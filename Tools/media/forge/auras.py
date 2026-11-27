"""Bake the crest's animated auras into Media/Textures/Auras/: one looping flip-book sheet per mark, and the empty socket they burn in.

An aura is a mark's own figure made of moving spell light. Its design (designs_<class>.py, Tools/media/sigils.py, or
a shipped picture's alpha and shading for a figure that has no design, such as the hawk perches' bird) gives the
silhouette and relief; this writes a signed distance field and a ridge map from them, has Blender render 16
frames at 512 px with EEVEE (aura.py), reduces each frame to a 128 px cell in linear light, fades the light before the
socket's gilt rim (a mark seated on a plate) or the cell's edge (a bare figure or a sigil), and packs a 4x4 sheet of
512x512, the shape of the class ambient sheets; a mark in BANDS is a strip, its frames cut to their middle band and
packed in cells as wide as the band is long (Quick Shots' gust: 2 columns by 8 rows of 256x64). The crest plays it with an engine FlipBook added over the socket
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

import designs_casters as casters
import melee_effects
import designs_hunter
import sigils
from finish import load, outline, resize, save, to_lin, to_srgb
from relief import N, Emblem, forge_lineart

FRAMES, MASTER, CELL, GRID = 16, 512, 128, 4
PAD = 410                 # field padding in map pixels, so warped flame lookups past the box still read distance
REACH = 170.0             # map pixels of distance from the outline to the field's 0 or 1
RIM_INNER = 0.49 - 0.045  # the socket plate's radius as a share of the box (relief.Emblem.seat)
SPAN = 1.25               # a bare figure's cell is this much wider than the figure, so its flames have room
EDGE = 3                  # cell pixels over which a bare figure's light fades before the cell's edge

# mark: (kind, Core/Tokens.lua colour, design). A "figures" mark is the silhouette of a shipped picture where it stands
# in its box (picture()). A "glyphs" or "trackers" mark's design is its factory in the class's
# designs module (designs_hunter.D["Hawk"]), whose emblem seats on the socket when it has a seated figure; a "sigils"
# mark draws Tools/media/sigils.py's figure of its name and takes None, or another figure's name to light it in a second colour; an "effects" mark (named Effects/<Art>) is a crest
# object of Tools/media/melee_effects.py, its design the function drawing it, lit in place in its own box so the crest can
# lay its light over the object's fill. The name is the texture token's (glyph<Name>, sigil<Name>, tracker<Name> in
# Core/Tokens.lua), which may keep an older subject's name: the mage's ChillShard is the designs' ice Shard; a "#" suffix
# tells two kinds' marks of one name apart (Eye#glyph, Hourglass#sigil), and the sheet keeps the name before it. Each class
# adds its marks as it takes the kit. A mark in "white" bakes a neutral light the game tints: a racial, a potion or Sprint is
# on every class's rail in that class's colour, and an object takes its piece's colour, which a seal's school or a picked
# weapon changes. Every other mark's colour is the one its seat draws it in.
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
# the mage's and warlock's marks (KstyleUI_ActionBars/SlabRanged.lua); Facet and Healthstone are one gem in two lights,
# and each demon burns twice: in the live pet's green on its sigil (HornsPet for a pet out whose spellbook names none of the four demons) and in fel violet as the
# sacrificed demon (ImpFel and the rest), while Horns stays the armor perch's violet
MARKS.update({
    "Intellect": ("glyphs", "schoolArcane", casters.D["Intellect"]),
    "Facet": ("glyphs", "magic", casters.D["Gem"]),
    "Healthstone": ("glyphs", "friendly", casters.D["Gem"]),
    "FireTongue": ("glyphs", "schoolFire", casters.D["Flame"]),
    "ChillShard": ("glyphs", "schoolFrost", casters.D["Shard"]),
    "PolyCurl": ("glyphs", "schoolArcane", casters.D["Sheep"]),
    "Imp": ("glyphs", "schoolNature", casters.D["Imp"]),
    "Voidwalker": ("glyphs", "schoolNature", casters.D["Voidwalker"]),
    "Succubus": ("glyphs", "schoolNature", casters.D["Succubus"]),
    "Fangs": ("glyphs", "schoolNature", casters.D["Felhunter"]),
    "Horns": ("glyphs", "jewelShard", casters.D["Demon"]),
    "HornsPet": ("glyphs", "schoolNature", casters.D["Demon"]),
    "ImpFel": ("glyphs", "jewelShard", casters.D["Imp"]),
    "VoidwalkerFel": ("glyphs", "jewelShard", casters.D["Voidwalker"]),
    "SuccubusFel": ("glyphs", "jewelShard", casters.D["Succubus"]),
    "FangsFel": ("glyphs", "jewelShard", casters.D["Felhunter"]),
    "Weakness": ("glyphs", "jewelShard", casters.D["BrokenBlade"]),
    "Tongue": ("glyphs", "schoolArcane", casters.D["Tongues"]),
    "Burst": ("glyphs", "hostile", casters.LINEART["Burst"]),
    "Elements": ("glyphs", "schoolFire", casters.LINEART["Elements"]),
    "Hourglass": ("glyphs", "schoolFrost", casters.LINEART["Hourglass"]),
    "Swirl": ("glyphs", "totemEarth", casters.LINEART["Swirl"]),
    "Eye#glyph": ("glyphs", "jewelShard", casters.LINEART["Eye"]),
    "Siphon": ("glyphs", "healthHostile", casters.LINEART["Siphon"]),
    "Arcane": ("sigils", "pipMageGlow", None),
    "Hourglass#sigil": ("sigils", "pipMageGlow", None),
    "Flame": ("sigils", "pipMageGlow", None),
    "Vortex": ("sigils", "pipMageGlow", None),
    "Crystal": ("sigils", "pipMageGlow", None),
    "Curse": ("sigils", "jewelShard", None),
    "Horns#sigil": ("sigils", "jewelShard", None),
    "Shade": ("sigils", "jewelShard", None),
    "Void": ("sigils", "jewelShard", None),
    "SoulWisp": ("trackers", "jewelShard", casters.D["SoulWisp"]),
    "Gust": ("trackers", "jewelHawk", casters.D["Gust"]),
})
BANDS = {"Gust": 4}  # mark: its strip's length over its height


def picture(path, mirror=False):
    """A shipped picture's silhouette (alpha) raised by its own shading (luminance), left where it stands in its box;
    mirror turns it left for right, since a flip-book cannot mirror its cells by texture coordinates."""
    def design():
        im = Image.open(ROOT / path).convert("RGBA").resize((N, N), Image.LANCZOS)
        if mirror:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        px = np.asarray(im, np.float32) / 255
        e = Emblem(Path(path).stem)
        e.M = ndi.binary_opening(px[..., 3] > 0.35, iterations=2)
        luma = px[..., :3] @ np.array([0.2126, 0.7152, 0.0722], np.float32)
        e.H = np.where(e.M, 0.35 + 0.65 * ndi.gaussian_filter(luma, 2.0), 0).astype(np.float32)
        return e
    return design


# the hunter: seven Aspects, six Stings, the two openings, Raptor Strike, the pet's haunch and lost hound, Trueshot Aura and
# Improved Tracking's compass; the three cooldown sigils
# and the rail's six more; the hawk perches' bird and the ready shots' arrows at their three angles
MARKS.update({name: ("glyphs", colour, designs_hunter.D[name]) for name, colour in {
    "Hawk": "gilt", "Monkey": "neutral", "Cheetah": "steelLit", "Pack": "steelLit", "Wild": "schoolNature", "Beast": "hostile",
    "Viper": "magic", "Serpent": "schoolNature", "ViperSting": "magic", "Scorpid": "neutral", "Wyvern": "schoolFire",
    "Lacerate": "hostile", "BlackArrow": "schoolShadow", "Counter": "hostile", "Mongoose": "hostile", "Raptor": "gilt",
    "Haunch": "neutral", "Hound": "hostile", "Trueshot": "gilt", "Compass": "gilt",
}.items()})
MARKS.update({name: ("sigils", "jewelHawk", None) for name in (
    "Volley", "Deflect", "Paw", "Intimidate", "FireTrap", "Sniper", "Aimed", "Strider", "Charm")})
# Immolation Trap's burn on the Sting fuse: the rail's trap sigil in the fuse's fire, so the rail keeps its own green
MARKS["FireTrapFuse"] = ("sigils", "schoolFire", "FireTrap")
MARKS["HawkPerch"] = ("figures", "gilt", picture("Media/Textures/Medallions/Hawks/HawkSigil.png"))
MARKS["HawkPerchMirror"] = ("figures", "gilt", picture("Media/Textures/Medallions/Hawks/HawkSigil.png", True))
MARKS.update({f"Arrow{angle}": ("figures", "giltLit", picture(f"Media/Textures/Pips/PipArrow{angle}.png")) for angle in (105, 90, 75)})
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
        sigils.GLYPHS[design or name](pen)
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


def fade(seated, w=CELL, h=CELL):
    """The cell's light falls off before the socket's rim, or before the cell's edge for a bare figure."""
    yy, xx = np.mgrid[0:h, 0:w]
    if seated:
        r = np.hypot(xx - (w - 1) / 2, yy - (h - 1) / 2)
        return np.clip((RIM_INNER * w - 2 - r) / 3.0, 0, 1)[..., None]
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    return np.clip(edge / EDGE, 0, 1)[..., None]


def loop_start(cells):
    """The cell the sheet starts on. The fields are periodic, so the seam is one more step of the cycle, but any one step
    can still be the cycle's largest; the game then shows its biggest jump at the wrap. Then the sheet starts after the
    smallest step instead, the same 16 cells in the same cyclic order."""
    steps = [float(np.abs(cells[(i + 1) % FRAMES] - cells[i]).mean()) for i in range(FRAMES)]
    if steps[-1] <= max(steps[:-1]):
        return 0
    return (steps.index(min(steps)) + 1) % FRAMES


def shape(band):
    """A sheet's cell width, cell height and columns: 4x4 square cells, or a band's strips two wide down the sheet."""
    if not band:
        return CELL, CELL, GRID
    w = CELL * GRID // 2
    return w, w // band, 2


def bake(frames, seated, path, band=0):
    """16 master frames to one 512x512 sheet; returns the loop's seam step against its largest ordinary step."""
    w, h, columns = shape(band)
    k = fade(seated, w, h)
    cells = []
    for f in frames:
        lin = to_lin(np.asarray(Image.open(f).convert("RGB"), np.float32) / 255)
        if band:
            lin = np.rot90(lin, 1)
            top = (lin.shape[0] - lin.shape[1] // band) // 2
            lin = lin[top:top + lin.shape[1] // band]
        small = np.stack([np.asarray(Image.fromarray(lin[..., i]).resize((w, h), Image.LANCZOS)) for i in range(3)], -1)
        cells.append(to_srgb(np.clip(small, 0, 1)) * k)
    start = loop_start(cells)
    cells = cells[start:] + cells[:start]
    sheet = np.zeros((CELL * GRID, CELL * GRID, 3), np.float32)
    for i, cell in enumerate(cells):
        y, x = divmod(i, columns)
        sheet[y * h:(y + 1) * h, x * w:(x + 1) * w] = cell
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
    for key, (kind, colour, design) in MARKS.items():
        if only and key not in only:
            continue
        name, tag = key.split("#")[0].split("/")[-1], key.replace("#", "-").replace("/", "")
        mask, height, seated = figure(name, kind, design, work)
        band = BANDS.get(key, 0)
        if band:
            # the rig's light rises up the frame; a strip lies on its side so its light streams back along it, and its
            # frames turn upright again in bake()
            mask, height = np.rot90(mask, -1), np.rot90(height, -1)
        fields(tag, mask, height, work / "fields")
        frames = work / "frames" / tag
        shutil.rmtree(frames, ignore_errors=True)
        # a band fills the frame's width, its flames cropped above and below rather than shrunk inside a span
        fit = 1.0 if seated or band else 1 / SPAN
        subprocess.run([args.blender, "-b", "--factory-startup", "--python-exit-code", "1", "--python", str(HERE / "aura.py"), "--",
                        str(work / "fields"), tag, str(frames), "--frames", str(FRAMES), "--size", str(MASTER),
                        "--palette", json.dumps(palette(hexes[colour])), "--fit", str(fit),
                        "--plate", str(RIM_INNER if seated else 0.0), "--pad", str(PAD / (N + 2 * PAD))],
                       check=True, stdout=subprocess.DEVNULL, env=env)
        path = args.out / kind.capitalize() / f"{name}.png"
        seam = bake([frames / f"{tag}_{i:02d}.png" for i in range(FRAMES)], seated, path, band)
        print(path.relative_to(args.out), hashlib.sha256(path.read_bytes()).hexdigest(), f"seam {seam:.2f}x largest ordinary step",
              "seated" if seated else "bare")
    if not args.work:
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
