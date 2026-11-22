"""Prepare the HUD style pictures: crops of the Frames, Orbs and Medallions HUD as the hud_reference render draws them.

Re-shoot from the current code, with a real screenshot's UI-free forest crop:
    python3 Tools/media/hud_pictures.py --plate ~/.cache/kstyleui-backdrops/game_09.png --work TEMP_DIR
    python3 Tools/media/make_media.py --only HudStyleFrames HudStyleOrbs HudStyleMedallions

CHROME and the native Lua/Bash toolchain must be on the environment's paths as for shoot.sh.
The plate crop is explicit and contains no screenshot UI; no generated scenery is used. The live presets
keep two stacked bars for Frames/Orbs and one twelve-button row on each side of the Medallions crest.
Alternatively pass --frames, --orbs and --medallions to crop existing 1920x1080 hud_reference renders.
The 2:1 crops are resampled to opaque 1024x512 prepared PNGs; make_media.py exports matching PNG/TGA pairs.
"""

import argparse
import os
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SCREEN_HEIGHT = 1080
PICTURE = (1024, 512)
# Left, top, right, bottom in screen units of a 1920 by 1080 render: the cast bar, the cooldown row, the target and
# player frames and the two-row tray for Frames; the two orbs, the forged tray and the cast bar for Orbs; the unit
# frames over the crest and its single row of buttons on each side for Medallions.
CROPS = {
    "HudStyleFrames": (540, 640, 1360, 1050),
    "HudStyleOrbs": (416, 536, 1504, 1080),
    "HudStyleMedallions": (440, 560, 1480, 1080),
}


def prepare(source, box):
    image = Image.open(source).convert("RGB")
    scale = image.height / SCREEN_HEIGHT
    left, top, right, bottom = (round(v * scale) for v in box)
    picture = image.crop((left, top, right, bottom)).resize(PICTURE, Image.LANCZOS)
    return picture.convert("RGBA")


def capture(plate, box, work):
    work.mkdir(parents=True, exist_ok=True)
    with Image.open(plate) as source:
        if not (0 <= box[0] < box[2] <= source.width and 0 <= box[1] < box[3] <= source.height):
            raise ValueError("plate crop must stay inside the screenshot")
        source.crop(box).convert("RGB").resize((1920, 1080), Image.Resampling.LANCZOS).save(work / "plate.png")
    shots = []
    for style in ("Frames", "Orbs", "Medallions"):
        shot = work / f"hud_{style}.png"
        env = dict(os.environ, RENDER_SCREEN="1920x1080", RENDER_SIZE="auto", RENDER_LAYOUT="DPS",
                   RENDER_HUD_STYLE=style, RENDER_ORNAMENTS="Full", RENDER_BAR3="0",
                   RENDER_ARRANGEMENT="centred", RENDER_MEDALLIONS_STATE="calm" if style == "Medallions" else "")
        subprocess.run(["bash", "Tools/render/shoot.sh", "hud_reference", "--ppu", "1", "--no-standins",
                        "--backdrop", str(work / "plate.png"), "--strict", "--out", str(shot)],
                       cwd=ROOT, env=env, check=True)
        shots.append(shot)
    return shots


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--frames", type=Path, help="the hud_reference render with RENDER_HUD_STYLE=Frames")
    parser.add_argument("--orbs", type=Path, help="the hud_reference render with RENDER_HUD_STYLE=Orbs")
    parser.add_argument("--medallions", type=Path, help="the hud_reference render with RENDER_HUD_STYLE=Medallions")
    parser.add_argument("--plate", type=Path, help="real game screenshot to crop into a UI-free backdrop")
    parser.add_argument("--plate-box", type=int, nargs=4, default=(0, 300, 1200, 975), metavar=("L", "T", "R", "B"))
    parser.add_argument("--work", type=Path, help="scratch folder for the plate and full-screen captures")
    parser.add_argument("--out", type=Path, default=ROOT / "Tools" / "media" / "materials")
    args = parser.parse_args(argv)
    if args.plate:
        if not args.work:
            parser.error("--plate requires --work for the temporary captures")
        args.frames, args.orbs, args.medallions = capture(args.plate, args.plate_box, args.work)
    elif not all((args.frames, args.orbs, args.medallions)):
        parser.error("supply --plate/--work, or all three rendered HUD images")
    args.out.mkdir(parents=True, exist_ok=True)
    for name, source in (("HudStyleFrames", args.frames), ("HudStyleOrbs", args.orbs), ("HudStyleMedallions", args.medallions)):
        path = args.out / f"{name}.png"
        prepare(source, CROPS[name]).save(path, optimize=True)
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
