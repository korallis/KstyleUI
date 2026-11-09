#!/usr/bin/env python3
"""gallery.py: render the gallery scenes, cut each frame they list out of the render, and write the manifest.

    python3 Tools/render/gallery.py [gallery_widgets gallery_options ...] [--out DIR] [--refs DIR] [--ppu 1.426]
                                    [--no-render] [--mockup PNG]

A gallery scene (Tools/render/scenes/gallery_<area>.lua, built on scenes/_gallery.lua) lists the frames it wants
shown in scene.frames: name, title, caption, grade, reference, match, pad and rect (screen units). This script
runs shoot.sh for each scene over the clean plate, crops every listed frame plus its padding out of the PNG at the
render's density, and writes kstyle_<name>.png into --out (default ~/.local/share/kstyleui-handoff/final/frames)
with kstyle_manifest.json, a list of { file, title, caption, grade, reference, match, scene }.

The references are crops of the owner's mockup (1.348 px per unit) rescaled to the render's density, one per
grade crop the scenes may name (REFERENCE_BOXES, mockup pixels), written as ref_<key>.png into --refs (default
the handoff folder's theme-crops, beside the measured m_*.png crops) and referred to from the manifest relative
to the frames folder. Without scene names every gallery_*.lua scene runs. --no-render reuses the PNG and JSON a
previous shoot.sh left in Tools/render/out. A run with scene names replaces those scenes' entries in an existing
manifest and keeps the rest, so one scene can be redone without rendering them all.

Pillow is needed. When the Python running this has none, the script runs itself again with the wow-dev virtual
environment's Python if that exists.
"""

import argparse
import glob
import json
import os
import subprocess
import sys

VENV_PYTHON = os.path.expanduser("~/.local/share/wow-dev/venv/bin/python")
HANDOFF = os.path.expanduser("~/.local/share/kstyleui-handoff")
MOCKUP = os.path.join(HANDOFF, "screens", "mockup-leveling-warrior-2574.png")
OUT = os.path.join(HANDOFF, "final", "frames")
REFS = os.path.join(HANDOFF, "theme-crops")
MOCKUP_PPU = 1.348
RENDER_PPU = 1.426
SCENES = "Tools/render/scenes"
RENDERS = "Tools/render/out"

# Mockup crops, in the mockup's pixels (left, top, right, bottom), one per reference a gallery frame may name.
# Each shows one grade the theme spec measured: the chat and tracker glass (window), the unit frames, the
# minimap and the nameplate (panel), the action buttons, centre cluster, buff icons and data strip (button),
# the buff bars, cast bar and experience bar (bar).
REFERENCE_BOXES = {
    "chat": (0, 1130, 620, 1400),
    "tracker": (2220, 425, 2574, 650),
    "player": (600, 1000, 1010, 1150),
    "target": (1570, 1000, 1980, 1150),
    "cast": (1040, 945, 1540, 1012),
    "buffbars": (700, 1140, 1010, 1240),
    "actionbars": (930, 1245, 1650, 1380),
    "cluster": (1020, 1020, 1560, 1210),
    "datastrip": (1880, 1340, 2574, 1410),
    "minimap": (2190, 15, 2574, 335),
    "nameplate": (1350, 490, 1680, 580),
    "bufficons": (2240, 335, 2574, 435),
    "xp": (940, 1218, 1650, 1255),
}

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


def crop_box(rect, pad, ppu, width, height):
    """The pixel box (left, top, right, bottom) of a frame rect in screen units plus pad units, inside the canvas."""
    x, y, w, h = rect
    left = int(round((x - pad) * ppu))
    top = int(round((y - pad) * ppu))
    right = int(round((x + w + pad) * ppu))
    bottom = int(round((y + h + pad) * ppu))
    left, top = max(0, left), max(0, top)
    right, bottom = min(width, max(left + 1, right)), min(height, max(top + 1, bottom))
    return left, top, right, bottom


def scene_names(requested):
    if requested:
        return requested
    return sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(SCENES, "gallery_*.lua")))


def render(scene, ppu):
    """Run shoot.sh for a scene over the clean plate; raises on failure."""
    subprocess.run(["bash", "Tools/render/shoot.sh", scene, "--backdrop", "--ppu", str(ppu)], check=True)


def globs(scenes):
    """After a full run, judge the allowlist's glob lines by every scene's guard sidecar; raises in strict mode on a stale one."""
    raws = [os.path.join(RENDERS, scene + ".guard.tsv") for scene in scenes]
    raws = [raw for raw in raws if os.path.exists(raw)]
    mode = os.environ.get("RENDER_GUARD", "default")
    lua = os.environ.get("LUA", "luajit")
    subprocess.run([lua, "Tools/render/guard.lua", "--globs", mode, *raws], check=True)


def references(mockup, refs_dir, ppu, keys):
    """Write ref_<key>.png for each key from the mockup at the render's density; returns key -> path."""
    pillow()
    os.makedirs(refs_dir, exist_ok=True)
    image = Image.open(mockup).convert("RGB")
    factor = ppu / MOCKUP_PPU
    out = {}
    for key in sorted(keys):
        box = REFERENCE_BOXES[key]
        crop = image.crop(box)
        crop = crop.resize((max(1, int(round(crop.width * factor))), max(1, int(round(crop.height * factor)))), Image.LANCZOS)
        path = os.path.join(refs_dir, "ref_%s.png" % key)
        crop.save(path)
        out[key] = path
    return out


def frames_of(scene_json):
    with open(scene_json, "r", encoding="utf-8") as handle:
        scene = json.load(handle)
    frames = scene.get("frames") or []
    if not frames:
        raise SystemExit("%s lists no frames; a gallery scene must Add at least one" % scene_json)
    return frames


def cut(scene, frames, ppu, out_dir, refs, ref_relative):
    """Crop each listed frame out of the scene's render; returns the manifest entries."""
    pillow()
    png = os.path.join(RENDERS, scene + ".png")
    image = Image.open(png).convert("RGB")
    entries = []
    for frame in frames:
        box = crop_box(frame["rect"], frame.get("pad", 14), ppu, image.width, image.height)
        name = "kstyle_%s.png" % frame["name"]
        image.crop(box).save(os.path.join(out_dir, name))
        entries.append({
            "file": name,
            "title": frame["title"],
            "caption": frame["caption"],
            "grade": frame["grade"],
            "reference": os.path.relpath(refs[frame["reference"]], out_dir) if ref_relative else refs[frame["reference"]],
            "match": frame["match"],
            "scene": scene,
        })
    return entries


def merged(path, entries, scenes):
    """The existing manifest with the rendered scenes' entries replaced by `entries`, in scene order."""
    with open(path, "r", encoding="utf-8") as handle:
        kept = [entry for entry in json.load(handle) if entry.get("scene") not in scenes]
    out = kept + entries
    out.sort(key=lambda entry: entry.get("scene", ""))
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("scenes", nargs="*", help="gallery scene names (default: every gallery_*.lua)")
    parser.add_argument("--out", default=OUT, help="where the frame PNGs and the manifest land")
    parser.add_argument("--refs", default=REFS, help="where the mockup reference crops land")
    parser.add_argument("--mockup", default=MOCKUP, help="the mockup PNG")
    parser.add_argument("--ppu", type=float, default=RENDER_PPU, help="the render's pixels per unit")
    parser.add_argument("--no-render", action="store_true", help="reuse the PNG and JSON shoot.sh left")
    args = parser.parse_args(argv)
    if not pillow():
        sys.exit("gallery.py needs Pillow: pip install Pillow, or create the wow-dev venv at " + VENV_PYTHON)
    names = scene_names(args.scenes)
    if not names:
        sys.exit("no gallery_*.lua scene in " + SCENES)
    os.makedirs(args.out, exist_ok=True)
    per_scene = {}
    keys = set()
    for scene in names:
        if not args.no_render:
            render(scene, args.ppu)
        frames = frames_of(os.path.join(RENDERS, scene + ".json"))
        per_scene[scene] = frames
        keys.update(frame["reference"] for frame in frames)
    if not args.scenes:
        globs(names)
    missing = [key for key in keys if key not in REFERENCE_BOXES]
    if missing:
        sys.exit("no mockup box for the reference(s) " + ", ".join(sorted(missing)))
    refs = references(args.mockup, args.refs, args.ppu, keys)
    manifest = []
    for scene in names:
        manifest.extend(cut(scene, per_scene[scene], args.ppu, args.out, refs, True))
    path = os.path.join(args.out, "kstyle_manifest.json")
    if args.scenes and os.path.exists(path):
        manifest = merged(path, manifest, set(names))
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    print("wrote %d frames from %d scene(s) to %s" % (len(manifest), len(names), args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
