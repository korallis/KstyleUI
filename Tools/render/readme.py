#!/usr/bin/env python3
"""readme.py: retake the README's test renders, preserving its in-game media.

    python3 Tools/render/readme.py [--work DIR] [--no-render] [--only NAME ...]

Run it from the repository root with luajit and Google Chrome installed. It renders the scenes into DIR (default
~/.capy/work/readme-renders), cuts them and writes the finished JPEGs to docs/media/readme/, where README.md reads them.
Every render draws at the shipped ornament level, Full. In-game Medallions media uses the game_ prefix and is preserved.

The pictures:

  hud_<style>_5120, hud_<style>_1080   the whole HUD in Frames and Orbs, in combat, on a 5120x1440 screen
                                       in the Spread arrangement at Interface size Auto and on a 1920x1080 screen at the
                                       15/16 size the game picks there
  ultrawide_centred, ultrawide_spread  the Healer layout on 5120x1440 in each ultrawide arrangement
  crop_*                               close crops of the 1080 HUD drawn at twice the density: the orbs and tray, the
                                       unit frames, the right rail, the group meter,
                                       and the nameplate scene
  frame_*                              frames cut directly from the gallery scenes

--no-render reuses the renders a previous run left in DIR. --only redoes the named pictures. Pillow is needed; the script
runs itself again with the wow-dev virtual environment's Python when this one has none.
"""

import argparse
import json
from pathlib import Path
import os
import subprocess
import sys

VENV_PYTHON = os.path.expanduser("~/.local/share/wow-dev/venv/bin/python")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "docs", "media", "readme")
DEFAULT_WORK = os.environ.get("KSTYLEUI_MEDIA_WORK", os.path.expanduser("~/.capy/work/readme-renders"))

PLATES = Path(ROOT) / "docs/media/plates"
GALLERY_PPU = 2.0
STYLES = ("Frames", "Orbs")
BUDGET_BYTES = 4 * 1024 * 1024
QUALITY = 86

FULL = {"RENDER_ORNAMENTS": "Full"}
COMBAT = {"RENDER_LAYOUT": "DPS", "RENDER_LOSS": "1", "RENDER_METER_SECRET": "1"}
ULTRAWIDE = {"RENDER_SIZE": "auto", "RENDER_SCREEN": "5120x1440"}
HD = {"RENDER_SIZE": "0.9375", "RENDER_SCREEN": "1920x1080"}


def style_env(style):
    env = dict(COMBAT, RENDER_HUD_STYLE=style)
    if style == "Orbs":
        env["RENDER_ORBS_HIT"] = "1"
    return env



RENDERS = {}
for _style in STYLES:
    _key = _style.lower()
    RENDERS[_key + "_5120"] = ("hud_reference", 1440 / 1080, dict(ULTRAWIDE, **style_env(_style), RENDER_ARRANGEMENT="spread"), "--strict")
    RENDERS[_key + "_1080"] = ("hud_reference", 1.0, dict(HD, **style_env(_style)), "--strict")
    RENDERS[_key + "_1080_2x"] = ("hud_reference", 2.0, dict(HD, **style_env(_style)), "--strict")
for _arrangement in ("centred", "spread"):
    RENDERS["healer_" + _arrangement] = ("hud_reference", 1440 / 1080, dict(
        ULTRAWIDE, **dict(style_env("Frames"), RENDER_LAYOUT="Healer", RENDER_ARRANGEMENT=_arrangement)), "--strict")
RENDERS["meter_party"] = ("hud_reference", 2.0, dict(HD, **dict(style_env("Frames"), RENDER_METER_GROUP="party")), "--strict")
RENDERS["meter_both_2x"] = ("hud_reference", 2.0, dict(HD, **dict(style_env("Frames"), RENDER_METER_GROUP="party", RENDER_METER_CHOICE="both")), "--strict")
RENDERS["plates"] = ("nameplate_bible", 2.0, {"RENDER_COMBAT": "1"}, "--strict")

GALLERIES = ("gallery_setup", "gallery_groupframes", "gallery_skins_character")

# name, source, crop, width. A source is "render:<RENDERS key>" or "frame:<gallery frame name>"; a crop is
# "WxH+X+Y" in the source's pixels or None. A picture narrower than its width stays as it is.
IMAGES = [
    ("hud_frames_5120", "render:frames_5120", None, 1600),
    ("hud_orbs_5120", "render:orbs_5120", None, 1600),
    ("hud_frames_1080", "render:frames_1080", None, 1200),
    ("hud_orbs_1080", "render:orbs_1080", None, 1200),
    ("crop_orbs", "render:orbs_1080_2x", "2120x525+860+1615", 1000),
    ("crop_unitframes", "render:frames_1080_2x", "1480x560+1260+1290", 900),
    ("crop_nameplates", "render:plates", "1340x780+400+300", 800),
    ("crop_meter", "render:meter_party", "490x350+3340+1810", 540),
    ("crop_meters_both", "render:meter_both_2x", "1020x350+2810+1810", 1120),
    ("crop_rail", "render:frames_1080_2x", "1100x1040+2720+20", 660),
    ("ultrawide_centred", "render:healer_centred", None, 1600),
    ("ultrawide_spread", "render:healer_spread", None, 1600),
    ("frame_setup", "frame:setup_layouts", None, 720),
    ("frame_raid", "frame:groupframes_raid", None, 720),
    ("frame_skins", "frame:skins_character", None, 560),
]

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


def picture_names():
    return [name for name, _, _, _ in IMAGES]


def parse_crop(spec):
    """'WxH+X+Y' as (left, top, right, bottom)."""
    size, left, top = spec.split("+")
    width, height = size.split("x")
    return int(left), int(top), int(left) + int(width), int(top) + int(height)


def fit_width(width, height, limit):
    """The size at a width limit; a picture already narrower keeps its size."""
    if width <= limit:
        return width, height
    return limit, max(1, round(height * limit / width))


def run(cmd, env=None):
    """Run one command from the repository root with the render environment; raises on failure."""
    full = dict(os.environ)
    full.update(env or {})
    subprocess.run(cmd, check=True, cwd=ROOT, env=full)


def scenery_plate(env):
    """Published renders always use a committed real plate, ignoring local mockup overrides."""
    shape = "ultrawide" if env.get("RENDER_SCREEN") == "5120x1440" else "1080" if env.get("RENDER_SCREEN") == "1920x1080" else "mac"
    ground = "town" if env.get("RENDER_HUD_STYLE") == "Orbs" else "forest"
    return PLATES / (ground + "-" + shape + ".jpg")


def bash_path(path):
    """Use Git Bash drive paths; shoot.sh converts them to escaped native file URLs."""
    path = Path(path).resolve().as_posix()
    return "/" + path[0].lower() + path[2:] if len(path) > 1 and path[1] == ":" else path


def render_all(work, wanted):
    """Render every scene the wanted pictures need, one process at a time."""
    os.makedirs(work, exist_ok=True)
    sources = {source for name, source, _, _ in IMAGES if name in wanted}
    for key, (scene, ppu, env, guard) in RENDERS.items():
        if "render:" + key in sources:
            run(["bash", "Tools/render/shoot.sh", scene, guard, "--backdrop", bash_path(scenery_plate(env)), "--ppu", repr(ppu), "--out", os.path.join(work, key + ".png")],
                dict(FULL, **env, KSTYLEUI_PLATE=str(scenery_plate(env))))
    if any(source.startswith("frame:") for source in sources):
        for scene in GALLERIES:
            run(["bash", "Tools/render/shoot.sh", scene, "--backdrop", bash_path(scenery_plate({})), "--ppu", str(GALLERY_PPU),
                 "--out", os.path.join(work, scene + ".png")],
                dict(FULL, KSTYLEUI_PLATE=str(scenery_plate({}))))


def cut_all(work, wanted):
    """Cut published gallery frames directly; design-mockup references are internal only."""
    frames = Path(work) / "frames"
    frames.mkdir(parents=True, exist_ok=True)
    needed = {source[6:] for name, source, _, _ in IMAGES if name in wanted and source.startswith("frame:")}
    for scene in GALLERIES if needed else ():
        path = Path(ROOT) / "Tools/render/out" / scene
        data = json.loads(path.with_suffix(".json").read_text(encoding="utf-8"))
        with Image.open(Path(work) / (scene + ".png")) as image:
            for frame in data["frames"]:
                if frame["name"] not in needed:
                    continue
                x, y, width, height = frame["rect"]
                pad = frame.get("pad", 14)
                box = (max(0, round((x-pad)*GALLERY_PPU)), max(0, round((y-pad)*GALLERY_PPU)),
                       min(image.width, round((x+width+pad)*GALLERY_PPU)), min(image.height, round((y+height+pad)*GALLERY_PPU)))
                image.crop(box).save(frames / ("kstyle_" + frame["name"] + ".png"))


def source_path(work, source):
    kind, _, name = source.partition(":")
    if kind == "frame":
        return os.path.join(work, "frames", "kstyle_%s.png" % name)
    return os.path.join(work, name + ".png")


def save(image, name):
    path = os.path.join(OUT, name + ".jpg")
    image.convert("RGB").save(path, quality=QUALITY, optimize=True, progressive=True)
    print("%s %dx%d %d KB" % (name, image.width, image.height, os.path.getsize(path) // 1024))


def scaled(image, limit):
    size = fit_width(image.width, image.height, limit)
    return image if size == image.size else image.resize(size, Image.LANCZOS)


def finish(work, wanted):
    os.makedirs(OUT, exist_ok=True)
    for name, source, crop, width in IMAGES:
        if name not in wanted:
            continue
        image = Image.open(source_path(work, source))
        if crop:
            image = image.crop(parse_crop(crop))
        save(scaled(image, width), name)


def total_bytes():
    paths = [os.path.join(OUT, name + ".jpg") for name in picture_names()]
    return sum(os.path.getsize(path) for path in paths if os.path.exists(path))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--work", default=DEFAULT_WORK, help="where the renders and cut frames go")
    parser.add_argument("--no-render", action="store_true", help="reuse the renders a previous run left")
    parser.add_argument("--only", nargs="*", default=[], help="redo only these pictures")
    args = parser.parse_args(argv)
    unknown = [name for name in args.only if name not in picture_names()]
    if unknown:
        sys.exit("unknown picture(s): " + ", ".join(unknown))
    if not pillow():
        sys.exit("readme.py needs Pillow: pip install Pillow, or create the wow-dev venv at " + VENV_PYTHON)
    wanted = set(args.only or picture_names())
    if not args.no_render:
        render_all(args.work, wanted)
    cut_all(args.work, wanted)
    finish(args.work, wanted)
    for path in os.listdir(OUT):
        if not path.startswith("game_") and (os.path.splitext(path)[0] not in picture_names() or not path.endswith(".jpg")):
            os.remove(os.path.join(OUT, path))
    total = total_bytes()
    print("total %.2f MB of %.0f MB" % (total / 1048576, BUDGET_BYTES / 1048576))
    return 0 if total <= BUDGET_BYTES else 1


if __name__ == "__main__":
    sys.exit(main())
