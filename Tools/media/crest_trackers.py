"""Draw the art the ranged crest trackers add (KstyleUI_ActionBars/SlabRanged.lua).

Usage:
    python3 Tools/media/crest_trackers.py [--out Media/Textures/Medallions/Trackers]

Writes, procedurally and with no model or source image:
    SoulWisp.png  64x64   a warlock's Soul Shard as a violet soul wisp: a white-hot core in a violet glow with a
                          flame tail curling up and to the left, drawn ADD
    Gust.png      256x64  a hunter's Quick Shots gust: three feather-thin wind streaks, tapered at both ends, and a
                          small feather riding the front of the middle one, white (tinted in the game), drawn ADD

The crest burns both as animated auras instead (Tools/media/forge/auras.py: Media/Textures/Auras/Trackers/); these flat
files stay for the Frames row's flat textures and as the wisp's black figure.

Each is drawn at 8x in linear light, blurred for its glow, reduced with Lanczos and stored as Tools/media/medallions_kit.py
stores effects: colour unpremultiplied, alpha the brightest channel, so ADD draws the light the picture shows.
Needs Pillow and numpy.
"""

import argparse
import hashlib
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Media" / "Textures" / "Medallions" / "Trackers"
SCALE = 8
VIOLET = (0.62, 0.32, 1.0)
CORE = (0.97, 0.92, 1.0)


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def mask(size, draw):
    """An L mask at size, drawn by draw(ImageDraw)."""
    m = Image.new("L", size, 0)
    draw(ImageDraw.Draw(m))
    return np.asarray(m, dtype=np.float64) / 255


def blur(a, radius):
    img = Image.fromarray(np.uint8(np.clip(a, 0, 1) * 255))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float64) / 255


def bake(light, size, fade):
    """light: HxWx3 linear light at 8x -> an RGBA image at size with ADD alpha and an edge fade."""
    img = Image.fromarray(np.uint8(np.clip(light, 0, 1) * 65535 // 257), "RGB")
    small = np.asarray(img.resize(size, Image.LANCZOS), dtype=np.float64) / 255
    small = small * fade(size)[..., None]
    rgb = to_srgb(small)
    alpha = rgb.max(axis=2)
    colour = np.where(alpha[..., None] > 0, rgb / np.maximum(alpha[..., None], 1e-6), 0)
    out = np.dstack([colour, alpha])
    return Image.fromarray(np.uint8(np.round(np.clip(out, 0, 1) * 255)), "RGBA")


def radial_fade(size):
    w, h = size
    y, x = np.mgrid[0:h, 0:w]
    r = np.hypot((x + 0.5 - w / 2) / (w / 2), (y + 0.5 - h / 2) / (h / 2))
    return np.clip((0.98 - r) / (0.98 - 0.82), 0, 1)


def end_fade(size):
    w, h = size
    y, x = np.mgrid[0:h, 0:w]
    fx = np.clip(np.minimum(x + 0.5, w - x - 0.5) / (w * 0.06), 0, 1)
    fy = np.clip(np.minimum(y + 0.5, h - y - 0.5) / (h * 0.12), 0, 1)
    return fx * fy


def wisp():
    n = 64 * SCALE
    cx, cy = n * 0.5, n * 0.6
    tail = []
    for i in range(41):
        t = i / 40
        x = cx - n * 0.12 * math.sin(t * math.pi * 0.9) - n * 0.04 * t
        y = cy - n * 0.42 * t
        half = n * 0.13 * (1 - t) ** 1.3
        tail.append((x, y, half))
    left = [(x - h, y) for x, y, h in tail]
    right = [(x + h, y) for x, y, h in reversed(tail)]
    flame = mask((n, n), lambda d: d.polygon(left + right, fill=255))
    inner = mask((n, n), lambda d: d.polygon([(x - h * 0.45, y) for x, y, h in tail] + [(x + h * 0.45, y) for x, y, h in reversed(tail)], fill=255))
    y = np.arange(n, dtype=np.float64)[:, None]
    rise = np.clip((y - (cy - n * 0.42)) / (n * 0.42), 0, 1) ** 1.5
    body = mask((n, n), lambda d: d.ellipse((cx - n * 0.13, cy - n * 0.13, cx + n * 0.13, cy + n * 0.13), fill=255))
    core = mask((n, n), lambda d: d.ellipse((cx - n * 0.055, cy - n * 0.055, cx + n * 0.055, cy + n * 0.055), fill=255))
    shape = np.maximum(flame * (0.35 + 0.65 * rise), body)
    glow = blur(shape, n * 0.015) * 0.95 + blur(shape, n * 0.05) * 0.3
    hot = blur(np.maximum(core, inner * rise * 0.55), n * 0.02)
    violet, white = to_linear(np.array(VIOLET)), to_linear(np.array(CORE))
    light = glow[..., None] * violet + hot[..., None] * white * 1.3
    return bake(light, (64, 64), radial_fade)


def gust():
    w, h = 256 * SCALE, 64 * SCALE
    streaks = mask((w, h), lambda d: None)
    for x0, x1, y, thick, bow in ((0.06, 0.78, 0.28, 0.022, 0.05), (0.14, 0.94, 0.5, 0.03, -0.04), (0.04, 0.7, 0.74, 0.018, 0.04)):
        points = []
        for i in range(61):
            t = i / 60
            x = w * (x0 + (x1 - x0) * t)
            y_ = h * (y + bow * math.sin(t * math.pi))
            half = h * thick * math.sin(t * math.pi) ** 0.8 * (0.35 + 0.65 * t)
            points.append((x, y_, half))
        top = [(x, y_ - k) for x, y_, k in points]
        bottom = [(x, y_ + k) for x, y_, k in reversed(points)]
        streaks = np.maximum(streaks, mask((w, h), lambda d, p=top + bottom: d.polygon(p, fill=255)))
    fx, fy, length = w * 0.9, h * 0.47, w * 0.15
    vane = [(fx - length * t, fy - h * 0.11 * math.sin(t * math.pi) ** 0.6) for t in (i / 30 for i in range(31))]
    vane += [(fx - length * t, fy + h * 0.06 * math.sin(t * math.pi) ** 0.6) for t in (1 - i / 30 for i in range(31))]
    feather = mask((w, h), lambda d: d.polygon(vane, fill=255))
    barbs = mask((w, h), lambda d: [d.line((fx - length * t, fy - h * 0.12, fx - length * (t - 0.06), fy), fill=255, width=max(2, int(h * 0.012))) for t in (0.3, 0.5, 0.7)])
    feather = np.clip(feather - barbs, 0, 1)
    quill = mask((w, h), lambda d: d.line((fx + w * 0.012, fy, fx - length * 1.12, fy + h * 0.015), fill=255, width=max(2, int(h * 0.016))))
    shape = np.maximum(streaks, np.maximum(feather * 0.7, quill))
    light = (blur(shape, h * 0.01) + blur(shape, h * 0.05) * 0.25)[..., None] * np.ones(3)
    return bake(light, (256, 64), end_fade)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name, image in (("SoulWisp.png", wisp()), ("Gust.png", gust())):
        path = args.out / name
        image.save(path, optimize=True)
        print(path.as_posix(), image.size, hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
