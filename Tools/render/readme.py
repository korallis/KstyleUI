#!/usr/bin/env python3
"""readme.py: retake the README's test renders, preserving its in-game media.

    python3 Tools/render/readme.py [--work DIR] [--no-render] [--only NAME ...]

Run it from the repository root with luajit and Google Chrome installed. It renders the scenes into DIR (default
~/.capy/work/readme-renders), crops them and writes the finished JPEGs to docs/media/readme/, where README.md reads them.
In-game Medallions media uses the game_ prefix and is preserved.

The pictures:

  hud_1080         the whole HUD in combat on a 1920x1080 screen at the 15/16 size the game picks
  hud_finish       the middle of the same HUD at twice the size: the lit glass bars and the forged slab ends
  hud_frames_1080  the same in the Frames look
  frame_raid       the raid frames with their heading, from the group frames gallery scene at twice the density
  frames_medals    a warrior's Frames HUD with every crest piece lit as medals above the stance bar, at twice the size

--no-render reuses the renders a previous run left in DIR. --only redoes the named pictures. Pillow is needed; the script
runs itself again with the wow-dev virtual environment's Python when this one has none.
"""

import argparse
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
BUDGET_BYTES = 4 * 1024 * 1024
QUALITY = 86

COMBAT = {"RENDER_LAYOUT": "DPS", "RENDER_LOSS": "1", "RENDER_METER_SECRET": "1"}
HD = {"RENDER_SIZE": "0.9375", "RENDER_SCREEN": "1920x1080"}
HUD = dict(HD, **COMBAT)

RENDERS = {
    "hud_1080": ("hud_reference", 1.0, HUD, "--strict"),
    "hud_2x": ("hud_reference", 2.0, HUD, "--strict"),
    "frames_1080": ("hud_reference", 1.0, dict(HUD, RENDER_HUD_STYLE="Frames", RENDER_ORNAMENTS="Full"), "--strict"),
    "groupframes": ("gallery_groupframes", 2.0, {}, "--strict"),
    "frames_medals": ("hud_warrior_mac", 2.0, dict(HD, RENDER_LAYOUT="DPS", RENDER_HUD_STYLE="Frames", RENDER_ORNAMENTS="Full",
                                                   RENDER_TRACKERS="lit"), "--strict"),
}

# name, source, crop, width. A source is "render:<RENDERS key>"; a crop is "WxH+X+Y" in the source's pixels or None. A picture narrower than its width stays as it is.
IMAGES = [
    ("hud_1080", "render:hud_1080", None, 1920),
    ("hud_finish", "render:hud_2x", "1856x444+992+1700", 1856),
    ("hud_frames_1080", "render:frames_1080", None, 1200),
    ("frame_raid", "render:groupframes", "904x442+106+724", 720),
    ("frames_medals", "render:frames_medals", "1600x468+1240+1660", 1600),
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
    return PLATES / ("forest-" + shape + ".jpg")


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
                dict(env, KSTYLEUI_PLATE=str(scenery_plate(env))))


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
        image = Image.open(os.path.join(work, source.split(":")[1] + ".png"))
        if crop:
            image = image.crop(parse_crop(crop))
        save(scaled(image, width), name)


def total_bytes():
    paths = [os.path.join(OUT, name + ".jpg") for name in picture_names()]
    return sum(os.path.getsize(path) for path in paths if os.path.exists(path))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--work", default=DEFAULT_WORK, help="where the renders go")
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
    finish(args.work, wanted)
    for path in os.listdir(OUT):
        if not path.startswith("game_") and (os.path.splitext(path)[0] not in picture_names() or not path.endswith(".jpg")):
            os.remove(os.path.join(OUT, path))
    total = total_bytes()
    print("total %.2f MB of %.0f MB" % (total / 1048576, BUDGET_BYTES / 1048576))
    return 0 if total <= BUDGET_BYTES else 1


if __name__ == "__main__":
    sys.exit(main())
