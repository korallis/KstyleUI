"""Draw the Expiring ember swipes for the crest's timer rings (KstyleUI_ActionBars/SlabRings.lua).

Usage:
    python3 Tools/media/crest_rings.py [--out Media/Textures/Medallions/Trackers]

Writes, from the shipped ring art and with no model or source image:
    EmberOrbRing.png     512x512  OrbRing.png's alpha (the medal timer rings) kept only in the last fifth of a
                                  clockwise sweep: amber from 288 to 330 degrees, red from 330 to 360
    EmberRingLine16.png  128x128  the same sectors of RingLine16.png (the rim and cooldown rings)
    CastRing.png         128x128  RingLine16.png white, open 9 degrees either side of 6 o'clock, so the cast ring on the
                                  crest's 145 edge passes under the level plaque (20 units wide, at 72.5 units out)

A Cooldown swipe that drains from 12 o'clock always ends in that sector, so the texture drawn on a second swipe of the
same duration turns what is left hot by itself. Colour is stored flat (the swipe is tinted white): amber #f09a3c,
the research mockup's, and red #ff7060, the shared timerExpiring value. The sector edges are 8x8 supersampled.
Needs Pillow and numpy.
"""

import argparse
import hashlib
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Media" / "Textures"
OUT = SOURCE / "Medallions" / "Trackers"
AMBER, RED = (0xF0, 0x9A, 0x3C), (0xFF, 0x70, 0x60)
FIFTH, TWELFTH, SAMPLES, PLAQUE = 288.0, 330.0, 8, 9.0


def angles(size):
    """Each supersample's angle clockwise from 12 o'clock, and a reducer to per-pixel coverage."""
    n = size * SAMPLES
    y, x = np.mgrid[0:n, 0:n]
    def cover(inside):
        return inside.reshape(size, SAMPLES, size, SAMPLES).mean(axis=(1, 3))
    return np.degrees(np.arctan2(x + 0.5 - n / 2, n / 2 - (y + 0.5))) % 360, cover


def sectors(size):
    """Coverage of the amber and red sectors per pixel."""
    angle, cover = angles(size)
    return cover((angle >= FIFTH) & (angle < TWELFTH)), cover(angle >= TWELFTH)


def cast():
    base = np.asarray(Image.open(SOURCE / "RingLine16.png").convert("RGBA"), dtype=np.float64)
    angle, cover = angles(base.shape[0])
    alpha = base[..., 3] * cover(np.abs(angle - 180) >= PLAQUE)
    return Image.fromarray(np.uint8(np.round(np.dstack([np.full(alpha.shape + (3,), 255.0), alpha]))), "RGBA")


def ember(name):
    base = np.asarray(Image.open(SOURCE / name).convert("RGBA"), dtype=np.float64) / 255
    amber, red = sectors(base.shape[0])
    rgb = (amber[..., None] * np.array(AMBER) + red[..., None] * np.array(RED)) / np.maximum(amber + red, 1e-6)[..., None]
    alpha = base[..., 3] * (amber + red)
    out = np.dstack([np.where(alpha[..., None] > 0, rgb, 0), alpha * 255])
    return Image.fromarray(np.uint8(np.round(out)), "RGBA")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name, image in (("EmberOrbRing.png", ember("OrbRing.png")), ("EmberRingLine16.png", ember("RingLine16.png")), ("CastRing.png", cast())):
        path = args.out / name
        image.save(path, optimize=True)
        print(path.as_posix(), image.size, hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
