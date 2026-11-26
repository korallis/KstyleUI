"""Draw the crest effects' flat glyph, the bail a bag gem hangs from, into Media/Textures/Glyphs/, and six marks for the forge.

Procedural, no model and no input image. A glyph is a bold white silhouette or line figure drawn at 8x. Bail is given a
soft glow and reduced with a linear-light Lanczos, so the crest tints it and draws it ADD (colour unpremultiplied, alpha
the brightest channel, as medallions_kit.py stores effects). The six in FORGED (the Curses Burst, Elements and Hourglass
and the torment spires' feet Swirl, Eye and Siphon; KstyleUI_ActionBars/SlabRanged.lua) are only drawn here:
Tools/media/forge/marks.py raises each drawing as ridges on a plate and writes it as Blender-forged metal, as it writes
the hunter's, mage's and warlock's other marks from its own designs.

    python3 Tools/media/crest_glyphs.py [--out DIR]
"""
import argparse
import hashlib
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE, SCALE = 64, 8
N = SIZE * SCALE
OUT = Path(__file__).resolve().parents[2] / "Media/Textures/Glyphs"
W = 0.085


class Pen:
    def __init__(self):
        self.image = Image.new("L", (N, N), 0)
        self.draw = ImageDraw.Draw(self.image)

    def line(self, points, w=W, erase=False):
        px = [(x * N, y * N) for x, y in points]
        r, fill = w * N / 2, 0 if erase else 255
        self.draw.line(px, fill=fill, width=int(w * N), joint="curve")
        for x, y in (px[0], px[-1]):
            self.draw.ellipse([x - r, y - r, x + r, y + r], fill=fill)

    def arc(self, cx, cy, r, a0, a1, w=W, steps=48):
        self.line([(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / steps)),
                    cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)], w)

    def poly(self, points, erase=False):
        self.draw.polygon([(x * N, y * N) for x, y in points], fill=0 if erase else 255)

    def dot(self, cx, cy, rx, ry=None, erase=False):
        ry = rx if ry is None else ry
        self.draw.ellipse([(cx - rx) * N, (cy - ry) * N, (cx + rx) * N, (cy + ry) * N], fill=0 if erase else 255)

    def wave(self, x0, x1, y0, y1, amp, turns, w=W, phase=0.0):
        self.line([(x0 + (x1 - x0) * t / 40 + amp * math.sin(phase + 2 * math.pi * turns * t / 40), y0 + (y1 - y0) * t / 40) for t in range(41)], w)

    def spiral(self, cx, cy, r0, r1, turns, w=W, a0=0.0):
        steps = int(60 * turns)
        self.line([(cx + (r0 + (r1 - r0) * i / steps) * math.cos(a0 + 2 * math.pi * turns * i / steps),
                    cy + (r0 + (r1 - r0) * i / steps) * math.sin(a0 + 2 * math.pi * turns * i / steps)) for i in range(steps + 1)], w)

    def star(self, cx, cy, r0, r1, points, a0=-90.0):
        self.poly([(cx + (r1 if i % 2 == 0 else r0) * math.cos(math.radians(a0 + 180 * i / points)),
                    cy + (r1 if i % 2 == 0 else r0) * math.sin(math.radians(a0 + 180 * i / points))) for i in range(2 * points)])

    def shield(self):
        self.line([(0.2, 0.14), (0.8, 0.14), (0.8, 0.46), (0.68, 0.72), (0.5, 0.88), (0.32, 0.72), (0.2, 0.46), (0.2, 0.14)], 0.075)

    def snow(self, cx, cy, r, w=0.06):
        for a in (90, 30, 150):
            dx, dy = r * math.cos(math.radians(a)), r * math.sin(math.radians(a))
            self.line([(cx - dx, cy - dy), (cx + dx, cy + dy)], w)


def glyphs():
    g = {}

    def make(name):
        def wrap(fn):
            p = Pen()
            fn(p)
            g[name] = p
            return fn
        return wrap

    @make("Burst")
    def _(p):
        p.star(0.5, 0.5, 0.17, 0.46, 8)

    @make("Elements")
    def _(p):
        p.line([(0.5, 0.04), (0.96, 0.5), (0.5, 0.96), (0.04, 0.5), (0.5, 0.04)], 0.08)
        p.line([(0.5, 0.26), (0.5, 0.74)], 0.07)
        p.line([(0.26, 0.5), (0.74, 0.5)], 0.07)

    @make("Hourglass")
    def _(p):
        p.poly([(0.2, 0.06), (0.8, 0.06), (0.5, 0.48)])
        p.line([(0.5, 0.5), (0.2, 0.94), (0.8, 0.94), (0.5, 0.5)], 0.08)
        p.poly([(0.32, 0.9), (0.68, 0.9), (0.5, 0.72)])

    @make("Swirl")
    def _(p):
        p.spiral(0.5, 0.5, 0.04, 0.42, 2.2, 0.08)

    @make("Eye")
    def _(p):
        p.arc(0.5, 0.92, 0.6, -128, -52, 0.08)
        p.arc(0.5, 0.08, 0.6, 52, 128, 0.08)
        p.dot(0.5, 0.5, 0.13)

    @make("Siphon")
    def _(p):
        p.poly([(0.36, 0.1)] + [(0.36 + 0.2 * math.cos(math.radians(a)), 0.52 + 0.2 * math.sin(math.radians(a))) for a in range(-30, 211, 10)])
        p.arc(0.52, 0.6, 0.32, -80, 80, 0.07)
        p.poly([(0.6, 0.86), (0.48, 0.96), (0.5, 0.8)])

    @make("Bail")
    def _(p):
        p.arc(0.5, 0.82, 0.12, 0, 360, 0.07)
        for y in (0.16, 0.38, 0.6):
            p.arc(0.5, y, 0.07, 0, 360, 0.05)

    return g


# Drawn here, written as Blender-forged metal by Tools/media/forge/marks.py.
FORGED = {"Burst", "Elements", "Hourglass", "Swirl", "Eye", "Siphon"}


def light(pen):
    shape = np.asarray(pen.image, np.float64) / 255
    glow = np.clip(np.asarray(pen.image.filter(ImageFilter.GaussianBlur(3 * SCALE)), np.float64) / 255 * 1.7, 0, 1)
    value = np.clip(np.maximum(shape, 0.55 * glow), 0, 1)
    small = np.asarray(Image.fromarray((value ** 2.2 * 255).astype(np.float32), "F").resize((SIZE, SIZE), Image.LANCZOS))
    alpha = np.clip(small / 255, 0, 1) ** (1 / 2.2)
    return np.dstack([np.ones((SIZE, SIZE, 3)), alpha])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    for name, pen in glyphs().items():
        if name in FORGED:
            continue
        path = args.out / f"{name}.png"
        Image.fromarray(np.clip(light(pen) * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)
        print(path.name, hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
