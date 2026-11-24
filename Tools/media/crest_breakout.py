"""Draw the ranged crest's break-out art into Media/Textures/Glyphs/ (KstyleUI_ActionBars/SlabRanged.lua).

Procedural, no model and no input image. Each file is a square window onto the crest in hub units (the ring is 150
across), centred where SlabRanged.lua seats it, so a status bar over it fills along the band: white strokes with a soft
glow, colour unpremultiplied and alpha the brightness, drawn ADD and tinted by the crest like the glyphs.

    ArcRight     the right band, 67 out, -24 to 24 degrees, 4 wide: your damage over time burning down (window 58 at 64, 0)
    ArcLeft      its mirror, 156 to 204 degrees: the demon's health, Arcane Wrath or Frost Nova charging (58 at -64, 0)
    ArcPet       the lower right band, 290 to 335 degrees: the pet's health (42 at 42, -46)
    RimLeft      a fine line 75 out on the left, 156 to 204 degrees: Demonic Sacrifice draining (62 at -72, 0)
    ArmorFrost   five ice crystals on the upper left band, 69 out at 100 to 152 degrees, and a fine line 75 out from 96 to
                 154 degrees: Frost or Ice Armor (64 at -37, 51)
    ArmorArcane  the same with five arcane runes: Mage Armor
    Frost        frost over the inner ring's lower half, 55 out from 205 to 335 degrees, four ice spikes pointing in: your
                 Frost Nova on the target (108 at 0, -39)
    MarkReticle  a ring 42 out with four prongs on the diagonals from 30 to 51: Hunter's Mark over the emblem (108 at 0, 0)

    python3 Tools/media/crest_breakout.py [--out DIR]
"""
import argparse
import hashlib
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 8
OUT = Path(__file__).resolve().parents[2] / "Media/Textures/Glyphs"


class Window:
    def __init__(self, px, cx, cy, side):
        self.px, self.cx, self.cy, self.side = px, cx, cy, side
        self.n = px * SS
        self.image = Image.new("L", (self.n, self.n), 0)
        self.draw = ImageDraw.Draw(self.image)

    def at(self, x, y):
        k = self.n / self.side
        return (x - self.cx + self.side / 2) * k, (self.cy - y + self.side / 2) * k

    def line(self, points, w):
        pts = [self.at(x, y) for x, y in points]
        r = w * self.n / self.side / 2
        self.draw.line(pts, fill=255, width=max(1, int(2 * r)), joint="curve")
        for x, y in (pts[0], pts[-1]):
            self.draw.ellipse([x - r, y - r, x + r, y + r], fill=255)

    def arc(self, r, a0, a1, w):
        steps = max(8, int(abs(a1 - a0)))
        self.line([(r * math.cos(math.radians(a0 + (a1 - a0) * i / steps)), r * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)], w)

    def poly(self, points):
        self.draw.polygon([self.at(x, y) for x, y in points], fill=255)

    def shape(self, x, y, angle, outline, size):
        c, s = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        self.poly([(x + size * (u * c - v * s), y + size * (u * s + v * c)) for u, v in outline])

    def light(self, glow=2.5):
        shape = np.asarray(self.image, np.float64) / 255
        blur = np.asarray(self.image.filter(ImageFilter.GaussianBlur(glow * self.n / self.side)), np.float64) / 255
        value = np.clip(np.maximum(shape, 0.6 * np.clip(blur * 1.8, 0, 1)), 0, 1)
        small = np.asarray(Image.fromarray((value ** 2.2 * 255).astype(np.float32), "F").resize((self.px, self.px), Image.LANCZOS))
        alpha = np.clip(small / 255, 0, 1) ** (1 / 2.2)
        return np.dstack([np.ones((self.px, self.px, 3)), alpha])


CRYSTAL = [(0.5, 0), (0.12, 0.2), (-0.5, 0), (0.12, -0.2)]
RUNE = [(0.5, 0), (0, 0.32), (-0.5, 0), (0, -0.32)]
SPIKE = [(0.5, 0), (-0.3, 0.22), (-0.5, 0), (-0.3, -0.22)]


def arts():
    out = {}

    right = Window(128, 64, 0, 58)
    right.arc(67, -24, 24, 4)
    out["ArcRight"] = right.light()
    out["ArcLeft"] = right.light()[:, ::-1]

    pet = Window(128, 42, -46, 42)
    pet.arc(67, 290, 335, 4)
    out["ArcPet"] = pet.light()

    rim = Window(128, -72, 0, 62)
    rim.arc(75, 156, 204, 1.4)
    out["RimLeft"] = rim.light(1.5)

    for name, outline in (("ArmorFrost", CRYSTAL), ("ArmorArcane", RUNE)):
        w = Window(128, -37, 51, 64)
        w.arc(75, 96, 154, 1.4)
        for i, a in enumerate((100, 113, 126, 139, 152)):
            x, y = 69 * math.cos(math.radians(a)), 69 * math.sin(math.radians(a))
            w.shape(x, y, a, outline, 12 + 3 * (i % 2))
            if outline is RUNE:
                w.draw.ellipse([*w.at(x - 1.2, y + 1.2), *w.at(x + 1.2, y - 1.2)], fill=0)
        out[name] = w.light(2)

    frost = Window(256, 0, -39, 108)
    frost.arc(55, 205, 335, 5.5)
    for a in (222, 246, 294, 318):
        frost.shape(51 * math.cos(math.radians(a)), 51 * math.sin(math.radians(a)), a + 180, SPIKE, 13)
    out["Frost"] = frost.light()

    mark = Window(256, 0, 0, 108)
    mark.arc(42, 0, 360, 1.6)
    for a in (45, 135, 225, 315):
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        mark.line([(51 * c, 51 * s), (30 * c, 30 * s)], 2.6)
    out["MarkReticle"] = mark.light(2)
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    for name, rgba in arts().items():
        path = args.out / f"{name}.png"
        Image.fromarray(np.clip(rgba * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)
        print(path.name, hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
