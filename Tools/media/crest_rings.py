"""Draw the crest's ring-edge timer art (KstyleUI_ActionBars/SlabRings.lua).

Usage:
    python3 Tools/media/crest_rings.py [--out Media/Textures/Medallions/Trackers]

Writes, procedurally and with no model or source image:
    EmberBand.png        128x128  Expiring ember for medals and sigils: a bright band at 85.3% of the radius (just outside
                                  a medal's rim when drawn at (medal + 3) / 0.853 across) with a soft spill, kept only in the
                                  last fifth of a clockwise sweep: amber from 288 to 330 degrees, red from 330 to 360, each
                                  with a near-white core
    EmberRingLine16.png  128x128  the same sectors of the shipped RingLine16.png, for the rim and cooldown rings
    EmberBandAmber.png, EmberRingLine16Amber.png
                         128x128  the red sector of each (330 to 360 degrees) in amber: drawn still over the swipe, it keeps
                                  the whole last fifth amber until the last twelfth, when the addon fades it out
    CastRing.png         256x256  the cast ring: a near-white core stroke at 95.5% of the radius in a soft gilt bloom, open
                                  9 degrees either side of 6 o'clock so it passes under the level plaque
    SwingRing.png        256x256  the swing ring: one fine pale steel line (#e6ecf3, steelLit) at 97.5% of the radius in a
                                  soft dark channel, so the line reads over the emblem's bright edge
    SwingHalo.png        256x256  a soft white halo ring at 80% of the radius, the hit's flash (drawn ADD at the line's
                                  diameter times 0.975 / 0.8, so it lands on the line with room to spill)
    RingBead.png         64x64    a ring timer's head: a white-hot round bead with a short tapered trail along its x axis
                                  (the ring's tangent), drawn as the Cooldown's edge

A Cooldown swipe that drains from 12 o'clock always ends in the ember sector, so the texture drawn on a second swipe of
the same duration turns what is left hot by itself. Colour is stored in the art where the swipe is tinted white: amber
#f09a3c (the research mockup's) and red #ff7060 (the shared timerExpiring value), with brighter cores #ffc86e and #ffa090.
Everything is 8x8 supersampled. Needs Pillow and numpy.
"""

import argparse
import hashlib
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Media" / "Textures"
OUT = SOURCE / "Medallions" / "Trackers"
AMBER, RED, AMBER_CORE, RED_CORE = (0xF0, 0x9A, 0x3C), (0xFF, 0x70, 0x60), (0xFF, 0xC8, 0x6E), (0xFF, 0xA0, 0x90)
WHITE, GILT, CORE, STEEL, BLACK = (255, 255, 255), (0xD3, 0xB5, 0x74), (0xFF, 0xFA, 0xF0), (0xE6, 0xEC, 0xF3), (0, 0, 0)
FIFTH, TWELFTH, SAMPLES, PLAQUE = 288.0, 330.0, 8, 9.0


def field(size):
    """Per supersample: radius as a share of the half size, angle clockwise from 12 o'clock, x and y in [-1, 1];
    and a reducer to per-pixel coverage."""
    n = size * SAMPLES
    y, x = np.mgrid[0:n, 0:n]
    x, y = (x + 0.5) / (n / 2) - 1, 1 - (y + 0.5) / (n / 2)
    def cover(v):
        return v.reshape(size, SAMPLES, size, SAMPLES).mean(axis=(1, 3))
    return np.hypot(x, y), np.degrees(np.arctan2(x, y)) % 360, x, y, cover


def band(r, at, half):
    return ((r >= at - half) & (r <= at + half)).astype(np.float64)


def glow(r, at, sigma):
    return np.exp(-((r - at) / sigma) ** 2)


def image(rgb, alpha):
    out = np.dstack([np.where(alpha[..., None] > 0, rgb, 0), np.clip(alpha, 0, 1) * 255])
    return Image.fromarray(np.uint8(np.round(out)), "RGBA")


def paint(core, spill, edge_colour, core_colour, cover):
    """A core over a spill: the core in core_colour, the spill fading to edge_colour."""
    a, s = cover(core), cover(spill)
    alpha = np.maximum(a, s)
    mix = a / np.maximum(alpha, 1e-6)
    return mix[..., None] * np.array(core_colour) + (1 - mix[..., None]) * np.array(edge_colour), alpha


def sectors(angle, cover):
    return cover((angle >= FIFTH) & (angle < TWELFTH)), cover(angle >= TWELFTH)


def ember_band(size=128, patch=False):
    r, angle, _, _, cover = field(size)
    core, spill = band(r, 0.853, 0.045), glow(r, 0.853, 0.075) * 0.75
    amber, red = sectors(angle, cover)
    a_rgb, alpha = paint(core, spill, AMBER, AMBER_CORE, cover)
    if patch:
        return image(a_rgb, alpha * red)
    r_rgb, _ = paint(core, spill, RED, RED_CORE, cover)
    hot = amber + red
    rgb = (amber[..., None] * a_rgb + red[..., None] * r_rgb) / np.maximum(hot, 1e-6)[..., None]
    return image(rgb, alpha * hot)


def ember_line(name="RingLine16.png", patch=False):
    base = np.asarray(Image.open(SOURCE / name).convert("RGBA"), dtype=np.float64) / 255
    _, angle, _, _, cover = field(base.shape[0])
    amber, red = sectors(angle, cover)
    if patch:
        return image(np.broadcast_to(np.array(AMBER, dtype=np.float64), base.shape[:2] + (3,)), base[..., 3] * red)
    rgb = (amber[..., None] * np.array(AMBER) + red[..., None] * np.array(RED)) / np.maximum(amber + red, 1e-6)[..., None]
    return image(rgb, base[..., 3] * (amber + red))


def cast(size=256):
    r, angle, _, _, cover = field(size)
    rgb, alpha = paint(band(r, 0.955, 0.013), glow(r, 0.955, 0.04) * 0.8, GILT, CORE, cover)
    return image(rgb, alpha * cover(np.abs(angle - 180) >= PLAQUE))


def swing(size=256):
    r, _, _, _, cover = field(size)
    rgb, alpha = paint(band(r, 0.975, 0.013), glow(r, 0.972, 0.035) * 0.6, BLACK, STEEL, cover)
    return image(rgb, alpha)


def halo(size=256):
    r, _, _, _, cover = field(size)
    return image(np.full((size, size, 3), 255.0), cover(glow(r, 0.8, 0.07) * 0.9))


def bead(size=64):
    r, _, x, y, cover = field(size)
    trail = np.clip(1 - np.abs(x) / 0.75, 0, 1) * np.exp(-(y / 0.09) ** 2)
    return image(np.full((size, size, 3), 255.0), cover(np.maximum(np.maximum(r <= 0.12, glow(r, 0, 0.16)), trail)))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name, made in (("EmberBand.png", ember_band()), ("EmberRingLine16.png", ember_line()),
                       ("EmberBandAmber.png", ember_band(patch=True)), ("EmberRingLine16Amber.png", ember_line(patch=True)),
                       ("CastRing.png", cast()),
                       ("SwingRing.png", swing()), ("SwingHalo.png", halo()), ("RingBead.png", bead())):
        path = args.out / name
        made.save(path, optimize=True)
        print(path.as_posix(), made.size, hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
