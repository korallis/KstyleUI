"""Make the setup's big pictures: hud_reference renders of each HUD style and layout, and of each ultrawide arrangement.

    CHROME=... python3 Tools/render/setup_pictures.py --plate ~/.cache/kstyleui-backdrops/game_09.png --work TEMP_DIR

The 16:9 plate is the G4 layout pictures' UI-free crop of the owner's screenshot and the 32:9 plate its UI-free
treetops; both are darkened to 65% so the HUD reads. Each 1920x1080 capture is resampled to 1024x512 and each
5120x1440 capture to 1024x256 (the game stretches them back to 16:9 and 32:9), saved as an opaque PNG for the
render harness and a pixel-identical 24-bit TGA for the game in Media/Textures/Setup/. No generated scenery is used.
"""

import argparse
import os
import struct
import subprocess
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Media" / "Textures" / "Setup"
PLATES = {"1920x1080": ((0, 300, 1200, 975), (1920, 1080)), "5120x1440": ((0, 0, 2240, 630), (5120, 1440))}
SHOTS = [(style, layout, "centred", "1920x1080", layout, (1024, 512)) for style in ("Medallions", "Frames")
         for layout in ("DPS", "Tank", "Healer")]
SHOTS += [(style, "DPS", arrangement, "5120x1440", arrangement.capitalize(), (1024, 256)) for style in ("Medallions", "Frames")
          for arrangement in ("centred", "spread")]


def tga(image):
    width, height = image.size
    rows = image.transpose(Image.Transpose.FLIP_TOP_BOTTOM).tobytes("raw", "BGR")
    return struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 24, 0) + rows


def plate(source, screen, work):
    box, size = PLATES[screen]
    path = work / f"plate_{screen}.png"
    with Image.open(source) as image:
        ImageEnhance.Brightness(image.crop(box).convert("RGB").resize(size, Image.Resampling.LANCZOS)).enhance(0.65).save(path)
    return path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--plate", type=Path, required=True, help="the owner's 5120x1440 game screenshot")
    parser.add_argument("--work", type=Path, required=True, help="scratch folder for plates and captures")
    args = parser.parse_args(argv)
    args.work.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    plates = {screen: plate(args.plate, screen, args.work) for screen in PLATES}
    for style, layout, arrangement, screen, name, size in SHOTS:
        shot = args.work / f"{style}{name}.png"
        env = dict(os.environ, RENDER_SCREEN=screen, RENDER_SIZE="auto", RENDER_LAYOUT=layout, RENDER_HUD_STYLE=style,
                   RENDER_ORNAMENTS="Full", RENDER_ARRANGEMENT=arrangement, RENDER_BAR3="0",
                   RENDER_MEDALLIONS_STATE="calm" if style == "Medallions" else "")
        ppu = str(int(screen.split("x")[1]) / 1080)
        subprocess.run(["bash", "Tools/render/shoot.sh", "hud_reference", "--ppu", ppu, "--no-standins", "--strict",
                        "--backdrop", plates[screen].as_posix(), "--out", shot.as_posix()], cwd=ROOT, env=env, check=True)
        with Image.open(shot) as image:
            picture = image.convert("RGB").resize(size, Image.Resampling.LANCZOS)
        picture.save(OUT / f"{style}{name}.png", optimize=True)
        (OUT / f"{style}{name}.tga").write_bytes(tga(picture))
        print(f"wrote Media/Textures/Setup/{style}{name}.png and .tga")


if __name__ == "__main__":
    main()
