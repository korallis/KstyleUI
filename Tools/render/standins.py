#!/usr/bin/env python3
"""Render stand-ins: real screenshot scenery by default; painted portraits remain addon art.

The backdrop and map terrain come from docs/media/plates (PROVENANCE.md records crops).
--internal-mockup-plate is an explicit escape hatch for internal tests, never publishing.
The optional handoff mockup supplies portrait art only; it never supplies scenery.
"""

import argparse
import os
import sys
from pathlib import Path

MOCKUP = os.path.expanduser("~/.local/share/kstyleui-handoff/screens/mockup-leveling-warrior-2574.png")
PLATES = Path(__file__).resolve().parents[2] / "docs/media/plates"
PLATE = str(PLATES / "forest-mac.jpg")
PLATE_ENV = "KSTYLEUI_PLATE"
PORTRAITS = os.path.expanduser("~/.local/share/kstyleui-handoff/scenery/portraits")
PORTRAITS_ENV = "KSTYLEUI_PORTRAITS"
MODELS = os.path.expanduser("~/.local/share/kstyleui-handoff/scenery/models")
MODELS_ENV = "KSTYLEUI_MODELS"
# The full-body model stand-in is resampled to this height in pixels, with its aspect kept.
MODEL_HEIGHT = 640
CLASSES = ("warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid")
OUT = "Tools/render/out/standins"
VENV_PYTHON = os.path.expanduser("~/.local/share/wow-dev/venv/bin/python")

# Crops in the mockup's pixels: left, top, right, bottom. The portraits are the squares inside the gold
# rings, read off the mockup. The map entry is replaced by a real screenshot crop.
CROPS = {
    "portrait-player.png": (632, 1008, 736, 1112),
    "portrait-target.png": (1840, 1006, 1944, 1110),
    "minimap.png": (2272, 50, 2526, 278),
}
PORTRAIT_SIZE = 128
MINIMAP_SIZE = 256
MAP_DAYLIGHT = 112
Image = None


def pillow():
    """Import Pillow, or use the wow-dev environment when available."""
    global Image
    if Image is not None:
        return True
    try:
        from PIL import Image as image
    except ImportError:  # pragma: no cover - depends on the machine
        VENV_ROOT = os.path.dirname(os.path.dirname(VENV_PYTHON))
        if os.path.exists(VENV_PYTHON) and os.path.realpath(sys.prefix) != os.path.realpath(VENV_ROOT):
            os.execv(VENV_PYTHON, [VENV_PYTHON, "-I", *sys.argv])
        return False
    Image = image
    return True


def square(image, box, size):
    """The box of the image, resampled to a size by size square."""
    return image.crop(box).resize((size, size), Image.LANCZOS)


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


def models_path(flag, environ):
    """The models folder: the parsed --models value, then KSTYLEUI_MODELS, then the handoff folder's."""
    return flag or environ.get(MODELS_ENV) or MODELS


def write_models(out_dir, models):
    """Write model-player-<class>.png for each full-body class painting the folder holds, resampled to the model
    height with its aspect and transparency kept, and remove the file of any class the folder no longer holds, so
    the paper doll falls back to a flat tone; returns the paths written and sets write_models.used."""
    os.makedirs(out_dir, exist_ok=True)
    found = dict(class_portraits(models)) if models else {}
    written = []
    for name in CLASSES:
        path = os.path.join(out_dir, "model-player-%s.png" % name)
        if name in found:
            figure = Image.open(found[name]).convert("RGBA")
            width = max(1, round(figure.width * MODEL_HEIGHT / figure.height))
            figure.resize((width, MODEL_HEIGHT), Image.LANCZOS).save(path)
            written.append(path)
        elif os.path.exists(path):
            os.remove(path)
    write_models.used = [name for name in CLASSES if name in found]
    return written


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


def backdrop(image, width, height):
    """Resize uniformly and crop the centre, without painting or extending the scenery."""
    scale = max(width / image.width, height / image.height)
    scaled = image.resize((max(width, round(image.width * scale)), max(height, round(image.height * scale))), Image.LANCZOS)
    left, top = (scaled.width - width) // 2, (scaled.height - height) // 2
    return scaled.crop((left, top, left + width, top + height))


def backdrop_source(mockup_image, plate):
    """Open the requested real scenery plate; never fall back to mockup scenery.

    Returns (image, plate_path_or_None)."""
    if plate and os.path.exists(plate):
        return Image.open(plate).convert("RGB"), plate
    raise FileNotFoundError("Missing scenery plate; regenerate with python Tools/media/plates.py: " + str(plate))


def plate_path(argv, environ):
    """The real plate to use: --plate, then KSTYLEUI_PLATE, then the committed forest crop."""
    if "--plate" in argv:
        return argv[argv.index("--plate") + 1]
    return environ.get(PLATE_ENV) or PLATE


def write(mockup, out_dir, width, height, plate=None, portraits=None, models=None):
    """Write real scenery and map crops, plus optional painted portrait/model stand-ins."""
    if not pillow():
        sys.exit("standins.py needs Pillow: pip install Pillow, or create the wow-dev venv at " + VENV_PYTHON)
    image = Image.open(mockup).convert("RGB") if os.path.exists(mockup) else None
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for name, box in CROPS.items():
        size = MINIMAP_SIZE if name == "minimap.png" else PORTRAIT_SIZE
        path = os.path.join(out_dir, name)
        if image is None and name != "minimap.png":
            if os.path.exists(path):
                os.remove(path)
            continue
        if name == "minimap.png":
            terrain = Image.open(PLATES / "minimap.png").convert("RGB").resize((size, size), Image.LANCZOS)
            terrain.save(path)
            day = os.path.join(out_dir, "worldmap.png")
            daylight(terrain).save(day)
            written.append(day)
        else:
            square(image, box, size).save(path)
        written.append(path)
    path = os.path.join(out_dir, "backdrop.png")
    source, used = backdrop_source(image, plate or PLATE)
    backdrop(source, width, height).save(path)
    written.append(path)
    write.plate_used = used
    written.extend(write_portraits(out_dir, portraits))
    write.portraits_used = write_portraits.used
    written.extend(write_models(out_dir, models))
    write.models_used = write_models.used
    return written


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--mockup", default=MOCKUP, help="the mockup PNG (default: the handoff folder's)")
    parser.add_argument("--out", default=OUT, help="the folder the stand-ins land in")
    parser.add_argument("--width", type=int, default=2383, help="the backdrop's width in pixels")
    parser.add_argument("--height", type=int, default=1540, help="the backdrop's height in pixels")
    parser.add_argument("--plate", default=None, help="real scenery plate (default: KSTYLEUI_PLATE, then docs/media/plates/forest-mac.jpg)")
    parser.add_argument("--internal-mockup-plate", help="INTERNAL TESTS ONLY: use an unpublished synthetic scenery plate")
    parser.add_argument("--portraits", default=None, help="the folder of <class>.png portraits (default: KSTYLEUI_PORTRAITS, then the handoff folder's scenery/portraits)")
    parser.add_argument("--models", default=None, help="the folder of <class>.png full-body paintings with transparency for the paper doll (default: KSTYLEUI_MODELS, then the handoff folder's scenery/models)")
    parser.add_argument("--quiet", action="store_true", help="do not print written paths")
    args = parser.parse_args(argv)
    portraits = portraits_path(args.portraits, os.environ)
    models = models_path(args.models, os.environ)
    raw = argv if argv is not None else sys.argv[1:]
    plate = args.internal_mockup_plate or plate_path(raw, os.environ)
    for path in write(args.mockup, args.out, args.width, args.height, plate=plate, portraits=portraits, models=models):
        if not args.quiet:
            print("wrote " + path)
    root = Path(__file__).resolve().parents[2]
    for blp in sorted((root / "Media").rglob("*.blp")):  # Chrome cannot read the game's BLPs
        png = Path(args.out, blp.relative_to(root).with_suffix(".png"))
        if not png.exists() or png.stat().st_mtime < blp.stat().st_mtime:
            png.parent.mkdir(parents=True, exist_ok=True)
            Image.open(blp).convert("RGB").save(png)
    if not args.quiet:
        if write.plate_used:
            print("backdrop: " + write.plate_used)
        else:
            raise AssertionError("A real scenery plate is required")
        if write.portraits_used:
            print("class portraits: " + ", ".join(write.portraits_used) + " from " + portraits)
        else:
            print("class portraits: none in " + portraits + "; every class uses the mockup's orc")
        if write.models_used:
            print("class models: " + ", ".join(write.models_used) + " from " + models)
        else:
            print("class models: none in " + models + "; the paper doll draws a flat tone where the game draws the model")
    return 0


if __name__ == "__main__":
    sys.exit(main())
