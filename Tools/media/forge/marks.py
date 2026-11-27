"""Forge the crest marks that are Blender renders into Media/Textures/Glyphs/ and Media/Textures/Sigils/.

A forged mark is a small cast-metal object, not a flat sign: a hawk's head for Aspect of the Hawk. Each is a relief
(relief.py) raised from layered shapes, lit and rendered by Blender in bright neutral metal (forge.py), given a dark outline
(thin on a plate, heavy on a figure with none) and reduced to 128 px (finish.py). The crest tints the neutral metal (KstyleUI_ActionBars/SlabMedals.lua,
Medals.Mark): gold with a halo in the spell's colour at 24 units and over; below that the spell's colour, or white for a
cooldown sigil; steel for an unlit perch. A texture drawn this way is flagged forged in Core/Tokens.lua. A hunter's lit
mark draws its animated aura (auras.py) instead, over the empty socket or over this figure drawn black.

The hunter's 17 glyphs, the pet's Haunch among them, are drawn in designs_hunter.py. The hunter's cooldown sigils (Volley, Deflect, Paw and the rail's Intimidate, FireTrap, Sniper, Aimed, Strider, Charm) keep
the drawing Tools/media/sigils.py gives them, with its shapes raised as ridges and the gaps between them left open.

    python3 Tools/media/forge/marks.py [--blender PATH] [--work DIR] [--only Hawk,Volley] [--glyphs DIR] [--sigils DIR]

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

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path[:0] = [str(HERE), str(HERE.parent)]

import designs_hunter
import sigils
from finish import load, outline, resize, save
from relief import forge_lineart

SIZE = 128
FREE_EDGE = 0.036
SIGILS = tuple(sorted(sigils.FORGED))
GLYPHS = tuple(designs_hunter.D)


def maps(work, only):
    """Write each mark's maps; returns {kind: [names]} and, under "free", the outline width of each glyph that stands on no plate."""
    done = {"glyphs": [], "sigils": [], "free": {}}
    for name in GLYPHS:
        if not only or name in only:
            emblem = designs_hunter.D[name]().save(work / "maps" / "glyphs")
            done["glyphs"].append(name)
            if emblem.edge or emblem.dark is None:
                done["free"][name] = emblem.edge or FREE_EDGE
    for name in SIGILS:
        if not only or name in only:
            pen = sigils.Pen()
            sigils.GLYPHS[name](pen)
            forge_lineart(name, pen.image, work / "maps" / "sigils")
            done["sigils"].append(name)
    return done


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--blender", default=os.environ.get("BLENDER") or shutil.which("blender"))
    parser.add_argument("--work", type=Path, help="keep the maps and the 512 px renders here")
    parser.add_argument("--only", default="", help="comma-separated mark names")
    parser.add_argument("--glyphs", type=Path, default=ROOT / "Media/Textures/Glyphs")
    parser.add_argument("--sigils", type=Path, default=ROOT / "Media/Textures/Sigils")
    args = parser.parse_args(argv)
    if not args.blender:
        parser.error("no Blender found; set BLENDER or pass --blender")
    only = set(filter(None, args.only.split(",")))
    unknown = only - set(GLYPHS) - set(SIGILS)
    if unknown:
        parser.error("unknown mark: " + ", ".join(sorted(unknown)))
    work = args.work or Path(tempfile.mkdtemp(prefix="forge-"))
    done = maps(work, only)
    free = done.pop("free")
    for kind, names in done.items():
        if not names:
            continue
        renders = work / "renders" / kind
        for name in names:
            (renders / f"{name}.png").unlink(missing_ok=True)
        subprocess.run([args.blender, "-b", "--factory-startup", "--python-exit-code", "1", "-P", str(HERE / "forge.py"), "--",
                        str(work / "maps" / kind), str(renders), "--only", ",".join(names)], check=True, stdout=subprocess.DEVNULL)
        out = getattr(args, kind)
        out.mkdir(parents=True, exist_ok=True)
        for name in names:
            path = out / f"{name}.png"
            # a figure with no plate stands over the painted emblem, so its dark edge is heavy enough to part it from the paint
            save(resize(outline(load(renders / f"{name}.png"), **({"width": free[name]} if name in free else {})), SIZE), path)
            print(f"{kind}/{path.name}", hashlib.sha256(path.read_bytes()).hexdigest())
    if not args.work:
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
