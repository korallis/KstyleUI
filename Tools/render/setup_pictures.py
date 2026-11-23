"""Make the setup's big pictures: hud_reference renders of each HUD style and layout, and of each ultrawide arrangement.

    CHROME=... python3 Tools/render/setup_pictures.py --plate ~/.cache/kstyleui-backdrops/game_09.png --work TEMP_DIR

The 16:9 plate is the G4 layout pictures' UI-free crop of the owner's screenshot and the 32:9 plate its UI-free
treetops; both are darkened to 65% so the HUD reads. Each 1920x1080 capture is resampled to 1024x512 and each
5120x1440 capture to 1024x256 (the game stretches them back to 16:9 and 32:9) and saved in Media/Textures/Setup/ as an
opaque DXT1 BLP2 without mipmaps, the client's own compressed format (256 KB or 128 KB each); standins.py decodes
them for the render harness. No generated scenery is used.
"""

import argparse
import os
import struct
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Media" / "Textures" / "Setup"
PLATES = {"1920x1080": ((0, 300, 1200, 975), (1920, 1080)), "5120x1440": ((0, 0, 2240, 630), (5120, 1440))}
SHOTS = [(style, layout, "centred", "1920x1080", layout, (1024, 512)) for style in ("Medallions", "Frames")
         for layout in ("DPS", "Tank", "Healer")]
SHOTS += [(style, "DPS", arrangement, "5120x1440", arrangement.capitalize(), (1024, 256)) for style in ("Medallions", "Frames")
          for arrangement in ("centred", "spread")]
WEIGHTS = np.array([[1, 0], [0, 1], [2 / 3, 1 / 3], [1 / 3, 2 / 3]])  # each DXT1 index's share of the two colours


def blp(image):
    """The image as an opaque DXT1 BLP2 without mipmaps. Each 4x4 block's two colours start at the ends of its
    principal axis and are refitted by least squares to the pixels that pick them; Pillow's DXT1 encoder shifts
    icon colours visibly (30.8 dB against 35.1 dB at worst on these pictures)."""
    width, height = image.size
    px = np.asarray(image, float).reshape(height // 4, 4, width // 4, 4, 3).transpose(0, 2, 1, 3, 4).reshape(-1, 16, 3)
    centred = px - px.mean(1, keepdims=True)
    cov = np.einsum("nki,nkj->nij", centred, centred)
    axis = np.ones((len(px), 3))
    for _ in range(8):
        axis = np.einsum("nij,nj->ni", cov, axis)
        axis /= np.linalg.norm(axis, axis=1, keepdims=True) + 1e-9
    t = np.einsum("nki,ni->nk", centred, axis)
    ends = px.mean(1, keepdims=True) + np.stack([t.max(1), t.min(1)], 1)[..., None] * axis[:, None]
    for step in range(4):
        q = np.rint(np.clip(ends, 0, 255) * [31 / 255, 63 / 255, 31 / 255]).astype(int)
        ends = (q * [8, 4, 8] | q >> [2, 4, 2]).astype(float)
        index = ((px[:, :, None] - np.einsum("pk,nki->npi", WEIGHTS, ends)[:, None]) ** 2).sum(3).argmin(2)
        if step < 3:
            a = WEIGHTS[index]
            m = np.einsum("nka,nkb->nab", a, a)
            ok = np.abs(np.linalg.det(m)) > 1e-6
            m[~ok] = np.eye(2)
            ends = np.where(ok[:, None, None], np.linalg.solve(m, np.einsum("nka,nki->nai", a, px)), ends)
    colours = q[..., 0] << 11 | q[..., 1] << 5 | q[..., 2]
    swap = colours[:, 0] < colours[:, 1]
    colours[swap] = colours[swap][:, ::-1]
    index = np.where(swap[:, None], np.array([1, 0, 3, 2])[index], index)
    index[colours[:, 0] == colours[:, 1]] = 0
    blocks = np.stack([colours[:, 0] | colours[:, 1] << 16, (index << 2 * np.arange(16)).sum(1)], 1).astype("<u4").tobytes()
    return (b"BLP2" + struct.pack("<I4B2I", 1, 2, 0, 0, 0, width, height) + struct.pack("<16I", 1172, *[0] * 15)
            + struct.pack("<16I", len(blocks), *[0] * 15) + bytes(1024) + blocks)


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
        (OUT / f"{style}{name}.blp").write_bytes(blp(picture))
        print(f"wrote Media/Textures/Setup/{style}{name}.blp")


if __name__ == "__main__":
    main()
