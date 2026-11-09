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
    backdrop.png          the scene behind the HUD at the render's size: the clean plate when there is one, else
                          the mockup's scenery with its UI areas blurred away
    portrait-player-<class>.png   one per class portrait in the portraits folder (`--portraits DIR`, or
                          KSTYLEUI_PORTRAITS, default ~/.local/share/kstyleui-handoff/scenery/portraits/<class>.png,
                          the class lower-cased): the painted head-and-shoulders portrait squared from its centre
                          and resampled to the portrait size, for the HUD scene of that class

The scenes use a crop when its file exists and fall back to a flat colour when it does not, so a render
on a machine without the mockup still works; a class with no portrait in the folder falls back to the orc.
The backdrop is scaled to the render's height and cropped to its width from the centre, because the mockup
is 1909 units wide and the owner's screen 1671.

The clean plate (`--plate PNG`, or KSTYLEUI_PLATE, default `~/.local/share/kstyleui-handoff/scenery/clean.png`)
is a UI-free render of the mockup's scene. When it exists it is the backdrop as it is, so no blurred square
sits next to a panel; when it is missing the mockup's scenery is blurred where its UI was, as before.

Pillow is needed. When the Python running this has none, the script runs itself again with the wow-dev
virtual environment's Python if that exists. shoot.sh calls this before every render and ignores a
missing mockup.
"""

import argparse
import os
import sys

MOCKUP = os.path.expanduser("~/.local/share/kstyleui-handoff/screens/mockup-leveling-warrior-2574.png")
PLATE = os.path.expanduser("~/.local/share/kstyleui-handoff/scenery/clean.png")
PLATE_ENV = "KSTYLEUI_PLATE"
PORTRAITS = os.path.expanduser("~/.local/share/kstyleui-handoff/scenery/portraits")
PORTRAITS_ENV = "KSTYLEUI_PORTRAITS"
CLASSES = ("warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid")
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
# The world map window draws the minimap's terrain at daylight: the mockup paints the map art dark for its lens,
# so worldmap.png is the same crop lifted to this mean luminance (0 to 255), its contrast kept.
MAP_DAYLIGHT = 112
# The mockup paints a white N at the top of its map art (left, top, right, bottom, relative to the minimap crop).
# KstyleUI draws its own north mark in the card's head, so the crop covers the mockup's with the terrain under it.
NORTH_MARK = (118, 0, 142, 16)

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


def cover_mark(crop, mark):
    """The crop with the mark's box covered by the strip of the same size just under it."""
    left, top, right, bottom = mark
    height = bottom - top
    patch = crop.crop((left, bottom, right, bottom + height)).transpose(Image.FLIP_TOP_BOTTOM)
    out = crop.copy()
    out.paste(patch, (left, top))
    return out


def daylight(crop, target=MAP_DAYLIGHT):
    """The crop lifted so its mean luminance is the target: a gamma lift, which keeps the terrain's contrast
    and never clips a highlight the way a plain multiply would."""
    grey = crop.convert("L")
    mean = sum(grey.getdata()) / (grey.width * grey.height)
    if mean <= 0 or mean >= 255:
        return crop.copy()
    import math
    gamma = math.log(target / 255) / math.log(mean / 255)
    table = [round(255 * ((i / 255) ** gamma)) for i in range(256)]
    return crop.point(table * 3)


def centre_square(image):
    """The largest square cut from the image's centre: a portrait wider or taller than square keeps its middle."""
    side = min(image.width, image.height)
    left = (image.width - side) // 2
    top = (image.height - side) // 2
    return (left, top, left + side, top + side)


def class_portraits(folder, classes=CLASSES):
    """The class portraits the folder holds, as (class, path) pairs for each <class>.png that exists."""
    out = []
    for name in classes:
        path = os.path.join(folder, name + ".png")
        if os.path.exists(path):
            out.append((name, path))
    return out


def portraits_path(flag, environ):
    """The portraits folder: the parsed --portraits value, then KSTYLEUI_PORTRAITS, then the handoff folder's."""
    return flag or environ.get(PORTRAITS_ENV) or PORTRAITS


def write_portraits(out_dir, portraits):
    """Write portrait-player-<class>.png for each class portrait the folder holds, squared from its centre at the
    portrait size, and remove the file of any class the folder no longer holds, so a missing portrait falls back
    to the orc; returns the paths written and sets write_portraits.used to the classes written."""
    os.makedirs(out_dir, exist_ok=True)
    found = dict(class_portraits(portraits)) if portraits else {}
    written = []
    for name in CLASSES:
        path = os.path.join(out_dir, "portrait-player-%s.png" % name)
        if name in found:
            portrait = Image.open(found[name]).convert("RGB")
            square(portrait, centre_square(portrait), PORTRAIT_SIZE).save(path)
            written.append(path)
        elif os.path.exists(path):
            os.remove(path)
    write_portraits.used = [name for name in CLASSES if name in found]
    return written


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


def backdrop_source(mockup_image, plate):
    """The image the backdrop is made from: the clean plate when its file exists, else the mockup itself.

    Returns (image, plate_path_or_None)."""
    if plate and os.path.exists(plate):
        return Image.open(plate).convert("RGB"), plate
    return mockup_image, None


def plate_path(argv, environ):
    """The plate to use: --plate on the command line, then KSTYLEUI_PLATE, then the handoff folder's clean plate."""
    if "--plate" in argv:
        return argv[argv.index("--plate") + 1]
    return environ.get(PLATE_ENV) or PLATE


def write(mockup, out_dir, width, height, plate=None, portraits=None):
    """Write every stand-in from the mockup into out_dir, and a portrait-player-<class>.png for each class
    portrait the portraits folder holds; returns the paths written."""
    if not pillow():
        sys.exit("standins.py needs Pillow: pip install Pillow, or create the wow-dev venv at " + VENV_PYTHON)
    image = Image.open(mockup).convert("RGB")
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for name, box in CROPS.items():
        size = MINIMAP_SIZE if name == "minimap.png" else PORTRAIT_SIZE
        path = os.path.join(out_dir, name)
        if name == "minimap.png":
            terrain = cover_mark(image.crop(box), NORTH_MARK).resize((size, size), Image.LANCZOS)
            terrain.save(path)
            day = os.path.join(out_dir, "worldmap.png")
            daylight(terrain).save(day)
            written.append(day)
        else:
            square(image, box, size).save(path)
        written.append(path)
    path = os.path.join(out_dir, "backdrop.png")
    source, used = backdrop_source(image, plate)
    backdrop(source, width, height, areas=[] if used else UI_AREAS).save(path)
    written.append(path)
    write.plate_used = used
    written.extend(write_portraits(out_dir, portraits))
    write.portraits_used = write_portraits.used
    return written


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--mockup", default=MOCKUP, help="the mockup PNG (default: the handoff folder's)")
    parser.add_argument("--out", default=OUT, help="the folder the stand-ins land in")
    parser.add_argument("--width", type=int, default=2383, help="the backdrop's width in pixels")
    parser.add_argument("--height", type=int, default=1540, help="the backdrop's height in pixels")
    parser.add_argument("--plate", default=None, help="the UI-free plate of the scene for the backdrop (default: KSTYLEUI_PLATE, then the handoff folder's clean.png)")
    parser.add_argument("--portraits", default=None, help="the folder of <class>.png portraits (default: KSTYLEUI_PORTRAITS, then the handoff folder's scenery/portraits)")
    parser.add_argument("--quiet", action="store_true", help="say nothing when the mockup is missing")
    args = parser.parse_args(argv)
    portraits = portraits_path(args.portraits, os.environ)
    if not os.path.exists(args.mockup):
        # The class portraits do not need the mockup; the other stand-ins fall back to flat colours.
        if pillow():
            write_portraits(args.out, portraits)
        if not args.quiet:
            print("no mockup at " + args.mockup + "; the scenes fall back to flat stand-ins", file=sys.stderr)
        return 0
    raw = argv if argv is not None else sys.argv[1:]
    plate = plate_path(raw, os.environ)
    for path in write(args.mockup, args.out, args.width, args.height, plate=plate, portraits=portraits):
        if not args.quiet:
            print("wrote " + path)
    if not args.quiet:
        if write.plate_used:
            print("backdrop: the clean plate " + write.plate_used)
        else:
            print("backdrop: the mockup with its UI blurred away (no plate at " + plate + ")")
        if write.portraits_used:
            print("class portraits: " + ", ".join(write.portraits_used) + " from " + portraits)
        else:
            print("class portraits: none in " + portraits + "; every class uses the mockup's orc")
    return 0


if __name__ == "__main__":
    sys.exit(main())
