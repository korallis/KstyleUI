"""Prepare the HUD style pictures: crops of the Frames and Orbs HUD as the hud_reference render draws them.

Usage:
    python3 Tools/media/hud_pictures.py --frames FRAMES.png --orbs ORBS.png

The sources are two renders of the shipped code with no game art in them: no backdrop, no stand-ins cut from the
handoff mock-up, and a HOME without the Blizzard icon and atlas caches, so every icon is the KstyleUI icon pack's
own repaint (Tools/icons/setB) and every portrait the renderer's flat stand-in. From the repository root:

    mv Tools/render/out/standins Tools/render/out/standins.off
    for style in Frames Orbs; do
        HOME=$(mktemp -d) RENDER_HUD_STYLE=$style RENDER_SIZE=auto RENDER_SCREEN=1920x1080 \\
            bash Tools/render/shoot.sh hud_reference --ppu 2 --no-standins --out /tmp/hud-$style.png
    done
    mv Tools/render/out/standins.off Tools/render/out/standins

This script crops each render to the style's centre (a 2:1 box in the render's 1080-unit screen, CROPS), resamples
it to PICTURE with Lanczos and writes it opaque into Tools/media/materials/, where Tools/media/make_media.py exports
it into Media/Textures/. Needs Pillow.
"""

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SCREEN_HEIGHT = 1080
PICTURE = (512, 256)
# Left, top, right, bottom in screen units of a 1920 by 1080 render: the cast bar, the cooldown row, the target and
# player frames and the two-row tray for Frames; the two orbs, the forged tray and the cast bar for Orbs.
CROPS = {
    "HudStyleFrames": (540, 640, 1360, 1050),
    "HudStyleOrbs": (501, 621, 1419, 1080),
}


def prepare(source, box):
    image = Image.open(source).convert("RGB")
    scale = image.height / SCREEN_HEIGHT
    left, top, right, bottom = (round(v * scale) for v in box)
    picture = image.crop((left, top, right, bottom)).resize(PICTURE, Image.LANCZOS)
    return picture.convert("RGBA")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--frames", required=True, type=Path, help="the hud_reference render with RENDER_HUD_STYLE=Frames")
    parser.add_argument("--orbs", required=True, type=Path, help="the hud_reference render with RENDER_HUD_STYLE=Orbs")
    parser.add_argument("--out", type=Path, default=ROOT / "Tools" / "media" / "materials")
    args = parser.parse_args(argv)
    for name, source in (("HudStyleFrames", args.frames), ("HudStyleOrbs", args.orbs)):
        path = args.out / f"{name}.png"
        prepare(source, CROPS[name]).save(path, optimize=True)
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
