#!/usr/bin/env python3
"""standins.py: cut the renderer's stand-ins out of the owner's mockup, so a render reads like the game.

    python3 Tools/render/standins.py [--mockup PNG] [--out DIR] [--width 2383 --height 1540] [--quiet]

The stub draws no world, so the renderer stands in for what the game draws: the two unit portraits that
SetPortraitTexture would paint, the minimap's terrain, and the scenery behind the HUD. This script crops
them out of the handoff mockup (`screens/mockup-leveling-warrior-2574.png`, 1.348 px per unit) into
Tools/render/out/standins/, which git ignores:

    portrait-player.png   the orc's face inside the mockup's round player portrait
    portrait-target.png   the crocolisk's face inside the mockup's round target portrait
    minimap.png           the map art inside the mockup's minimap square
    backdrop.png          the mockup's scenery at the render's size, its UI areas blurred away

The scenes use a crop when its file exists and fall back to a flat colour when it does not, so a render
on a machine without the mockup still works. The backdrop is scaled to the render's height and cropped
to its width from the centre, because the mockup is 1909 units wide and the owner's screen 1671.

Pillow is needed. When the Python running this has none, the script runs itself again with the wow-dev
virtual environment's Python if that exists. shoot.sh calls this before every render and ignores a
missing mockup.
"""

import argparse
import os
import sys

MOCKUP = os.path.expanduser("~/.local/share/kstyleui-handoff/screens/mockup-leveling-warrior-2574.png")
OUT = "Tools/render/out/standins"
VENV_PYTHON = os.path.expanduser("~/.local/share/wow-dev/venv/bin/python")

# Crops in the mockup's pixels: left, top, right, bottom. The portraits are the squares inside the gold
# rings, read off the mockup; the minimap is the map art inside the square's dark border.
CROPS = {
    "portrait-player.png": (632, 1008, 736, 1112),
    "portrait-target.png": (1840, 1006, 1944, 1110),
    "minimap.png": (2272, 50, 2526, 278),
}
PORTRAIT_SIZE = 128
MINIMAP_SIZE = 256

# The mockup's UI areas, in its pixels, blurred away in the backdrop so only the scenery stays.
UI_AREAS = [
    (0, 1100, 660, 1456),       # chat panel
    (560, 930, 2020, 1456),     # HUD band: unit frames, cast bar, cooldowns, bars, experience
    (2190, 0, 2574, 650),       # minimap, buff icons, quest tracker
    (1300, 480, 1720, 690),     # nameplate and the combat numbers
    (1800, 1300, 2574, 1456),   # data strip
    (900, 740, 1200, 920),      # the heal number over the player
]
BLUR_RADIUS = 18
FEATHER = 24

Image = ImageDraw = ImageFilter = None


def pillow():
    """Import Pillow once a mockup is there to crop; a machine without one never needs it."""
    global Image, ImageDraw, ImageFilter
    if Image is not None:
        return True
    try:
        from PIL import Image as image, ImageDraw as draw, ImageFilter as filter_
    except ImportError:  # pragma: no cover - depends on the machine
        VENV_ROOT = os.path.dirname(os.path.dirname(VENV_PYTHON))
        if os.path.exists(VENV_PYTHON) and os.path.realpath(sys.prefix) != os.path.realpath(VENV_ROOT):
            os.execv(VENV_PYTHON, [VENV_PYTHON, "-I", *sys.argv])
        return False
    Image, ImageDraw, ImageFilter = image, draw, filter_
    return True


def square(image, box, size):
    """The box of the image, resampled to a size by size square."""
    return image.crop(box).resize((size, size), Image.LANCZOS)


def backdrop(image, width, height, areas=UI_AREAS, radius=BLUR_RADIUS, feather=FEATHER):
    """The mockup scaled to the render's height, cropped to its width from the centre, UI areas blurred."""
    blurred = image.filter(ImageFilter.GaussianBlur(radius))
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)
    for left, top, right, bottom in areas:
        draw.rectangle((left, top, right, bottom), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(feather))
    scenery = Image.composite(blurred, image, mask)
    scale = height / scenery.height
    scaled = scenery.resize((max(1, round(scenery.width * scale)), height), Image.LANCZOS)
    left = max(0, (scaled.width - width) // 2)
    out = Image.new("RGB", (width, height), (0, 0, 0))
    out.paste(scaled.crop((left, 0, left + min(width, scaled.width), height)), (0, 0))
    return out


def write(mockup, out_dir, width, height):
    """Write every stand-in from the mockup into out_dir; returns the paths written."""
    if not pillow():
        sys.exit("standins.py needs Pillow: pip install Pillow, or create the wow-dev venv at " + VENV_PYTHON)
    image = Image.open(mockup).convert("RGB")
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for name, box in CROPS.items():
        size = MINIMAP_SIZE if name == "minimap.png" else PORTRAIT_SIZE
        path = os.path.join(out_dir, name)
        square(image, box, size).save(path)
        written.append(path)
    path = os.path.join(out_dir, "backdrop.png")
    backdrop(image, width, height).save(path)
    written.append(path)
    return written


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--mockup", default=MOCKUP, help="the mockup PNG (default: the handoff folder's)")
    parser.add_argument("--out", default=OUT, help="the folder the stand-ins land in")
    parser.add_argument("--width", type=int, default=2383, help="the backdrop's width in pixels")
    parser.add_argument("--height", type=int, default=1540, help="the backdrop's height in pixels")
    parser.add_argument("--quiet", action="store_true", help="say nothing when the mockup is missing")
    args = parser.parse_args(argv)
    if not os.path.exists(args.mockup):
        if not args.quiet:
            print("no mockup at " + args.mockup + "; the scenes fall back to flat stand-ins", file=sys.stderr)
        return 0
    for path in write(args.mockup, args.out, args.width, args.height):
        if not args.quiet:
            print("wrote " + path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
