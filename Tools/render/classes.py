#!/usr/bin/env python3
"""classes.py: render the HUD for every class over the clean plate, crop each class's frames close-up, write the manifest.

    python3 Tools/render/classes.py [warrior mage ...] [--out DIR] [--ppu 1.426] [--no-render] [--notes JSON]

One HUD scene per class (Tools/render/scenes/hud_<class>_mac.lua, the nine classes of scenes/_classes.lua) runs
through shoot.sh with --backdrop; the full render is copied to --out (default
~/.local/share/kstyleui-handoff/final/classes) as <class>.png, and the frames close-up (FRAMES_BOX: the player
frame, the cast bar, the centre cluster and the bars, the same box as the handoff's frames_now.png, in screen
units at the render's density) as <class>_frames.png. manifest.json lists one entry per class: class, title, the
character's name, the class colour as hex, the power token, the cast (or "none"), the files and a note. --notes
names a JSON file of { "CLASS": "note" } to fill the notes; without it each note is empty. --no-render reuses
the PNG and JSON a previous shoot.sh left in Tools/render/out. Without class names every class runs; a run with
names replaces those classes' entries in an existing manifest and keeps the rest.

Pillow is needed. When the Python running this has none, the script runs itself again with the wow-dev virtual
environment's Python if that exists.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys

VENV_PYTHON = os.path.expanduser("~/.local/share/wow-dev/venv/bin/python")
HANDOFF = os.path.expanduser("~/.local/share/kstyleui-handoff")
OUT = os.path.join(HANDOFF, "final", "classes")
RENDER_PPU = 1.426
RENDERS = "Tools/render/out"
CLASSES = ("warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid")

# The frames close-up in screen units (x, y, width, height): the player frame, the cast bar, the centre cluster,
# the buff bars and the action bars, as the handoff's frames_now.png crops them.
FRAMES_BOX = (290, 640, 1100, 440)

Image = None


def pillow():
    """Import Pillow, or run again under the wow-dev venv when this Python has none."""
    global Image
    if Image is not None:
        return True
    try:
        from PIL import Image as image
    except ImportError:  # pragma: no cover - depends on the machine
        venv_root = os.path.dirname(os.path.dirname(VENV_PYTHON))
        if os.path.exists(VENV_PYTHON) and os.path.realpath(sys.prefix) != os.path.realpath(venv_root):
            os.execv(VENV_PYTHON, [VENV_PYTHON, "-I", *sys.argv])
        return False
    Image = image
    return True


def pixel_box(units, ppu, width, height):
    """The pixel box (left, top, right, bottom) of a box in screen units at a density, inside the canvas."""
    x, y, w, h = units
    left, top = max(0, int(round(x * ppu))), max(0, int(round(y * ppu)))
    right = min(width, max(left + 1, int(round((x + w) * ppu))))
    bottom = min(height, max(top + 1, int(round((y + h) * ppu))))
    return left, top, right, bottom


def density_matches(png_size, screen, ppu):
    """Whether a render's pixel size is the scene's screen at the density (shoot.sh rounds each side up)."""
    width, height = png_size
    return abs(width - screen["width"] * ppu) <= 1.5 and abs(height - screen["height"] * ppu) <= 1.5


def hex_of(colour):
    """A colour's six-digit hex, as RAID_CLASS_COLORS.<class>.colorStr spells it without the alpha."""
    return "".join("%02X" % int(round(float(v) * 255)) for v in colour[:3])


def scene_name(class_name):
    return "hud_%s_mac" % class_name


def render(class_name, ppu):
    """Run shoot.sh for the class's scene over the clean plate; raises on failure."""
    subprocess.run(["bash", "Tools/render/shoot.sh", scene_name(class_name), "--backdrop", "--ppu", str(ppu)], check=True)


def cut(png, class_name, out_dir, box, ppu):
    """Copy the full render to out_dir as <class>.png and crop the frames box as <class>_frames.png.

    Returns the two paths."""
    pillow()
    os.makedirs(out_dir, exist_ok=True)
    full = os.path.join(out_dir, class_name + ".png")
    shutil.copyfile(png, full)
    image = Image.open(png).convert("RGB")
    frames = os.path.join(out_dir, class_name + "_frames.png")
    image.crop(pixel_box(box, ppu, image.width, image.height)).save(frames)
    return full, frames


def manifest_entry(scene, full_name, frames_name, note):
    """One manifest entry from the scene JSON's class summary (Hud.Build writes scene.class)."""
    info = scene.get("class") or {}
    return {
        "class": info.get("class"),
        "title": info.get("title"),
        "name": info.get("name"),
        "colour": hex_of(info.get("colour") or [1, 1, 1]),
        "power": info.get("power"),
        "cast": info.get("cast") or "none",
        "file": full_name,
        "frames": frames_name,
        "notes": note or "",
    }


def merged(path, entries, classes):
    """The existing manifest with the rendered classes' entries replaced, in the game's class order."""
    with open(path, "r", encoding="utf-8") as handle:
        kept = [entry for entry in json.load(handle) if (entry.get("class") or "").lower() not in classes]
    out = kept + entries
    out.sort(key=lambda entry: CLASSES.index((entry.get("class") or "").lower()) if (entry.get("class") or "").lower() in CLASSES else len(CLASSES))
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("classes", nargs="*", help="class names (default: all nine)")
    parser.add_argument("--out", default=OUT, help="where the PNGs and manifest.json land")
    parser.add_argument("--ppu", type=float, default=RENDER_PPU, help="the render's pixels per unit")
    parser.add_argument("--no-render", action="store_true", help="reuse the PNG and JSON shoot.sh left")
    parser.add_argument("--notes", default=None, help="a JSON file of { CLASS: note } for the manifest's notes")
    args = parser.parse_args(argv)
    if not pillow():
        sys.exit("classes.py needs Pillow: pip install Pillow, or create the wow-dev venv at " + VENV_PYTHON)
    names = [name.lower() for name in args.classes] or list(CLASSES)
    unknown = [name for name in names if name not in CLASSES]
    if unknown:
        sys.exit("not a class: " + ", ".join(unknown) + "; the classes are " + ", ".join(CLASSES))
    notes = {}
    if args.notes:
        with open(args.notes, "r", encoding="utf-8") as handle:
            notes = {key.upper(): value for key, value in json.load(handle).items()}
    os.makedirs(args.out, exist_ok=True)
    entries = []
    for name in names:
        if not args.no_render:
            render(name, args.ppu)
        png = os.path.join(RENDERS, scene_name(name) + ".png")
        with open(os.path.join(RENDERS, scene_name(name) + ".json"), "r", encoding="utf-8") as handle:
            scene = json.load(handle)
        pillow()
        size = Image.open(png).size
        if not density_matches(size, scene["screen"], args.ppu):
            sys.exit("%s is %dx%d px, not the %.3f px per unit the crop expects; render it again or pass --ppu" % (png, size[0], size[1], args.ppu))
        full, frames = cut(png, name, args.out, FRAMES_BOX, args.ppu)
        entries.append(manifest_entry(scene, os.path.basename(full), os.path.basename(frames), notes.get(name.upper())))
        print("%s: %s, %s" % (name, full, frames))
    path = os.path.join(args.out, "manifest.json")
    if args.classes and os.path.exists(path):
        entries = merged(path, entries, set(names))
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(entries, handle, indent=2)
        handle.write("\n")
    print("wrote %d entries to %s" % (len(entries), path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
