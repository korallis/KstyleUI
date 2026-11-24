"""Draw the healer crest's figures into Media/Textures/Figures/.

A figure is the thing a crest piece tracks drawn as light rather than as a spell icon: a lance of holy light, a waning
moon, a claw's rake, an ankh. Each fills the height, so a vertical status bar drains it from the top over an aura's
time or fills it from the base over a cooldown, and is coloured by its school: a glow round a body lit from the top
with a white-hot core. Procedural, no model and no input image: the silhouette is drawn at 8x from polygons, strokes,
rings and dots in a unit box (y down, Tools/media/sigils.py's pen) and reduced with a linear-light Lanczos to 64x64.
Drawn ADD: colour unpremultiplied, alpha the brightest channel (as medallions_kit.py stores effects).

    python3 Tools/media/figures.py [--out DIR] [--sheet PNG]
"""
import argparse
import hashlib
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw

from healer_trackers import additive, blur, grid
from sigils import N, Pen, bezier

OUT = Path(__file__).resolve().parents[2] / "Media/Textures/Figures"
HOLY, SHADOW, BLOOD = (1.0, 0.8, 0.38), (0.62, 0.36, 1.0), (0.95, 0.16, 0.2)
NATURE, ARCANE, FIRE = (0.42, 0.95, 0.36), (0.62, 0.72, 1.0), (1.0, 0.5, 0.16)
FROST, STORM, AMBER = (0.36, 0.66, 1.0), (0.62, 0.84, 1.0), (1.0, 0.68, 0.26)
FIGURES = {}


def figure(colour, core=(1.0, 0.97, 0.9)):
    def wrap(fn):
        FIGURES[fn.__name__] = (fn, colour, core)
        return fn
    return wrap


def cut(pen, draw):
    hole = Pen()
    draw(hole)
    pen.image = ImageChops.subtract(pen.image, hole.image)
    pen.draw = ImageDraw.Draw(pen.image)


def polygon(cx, cy, r, sides, turn=-90, squash=1.0):
    return [(cx + r * math.cos(math.radians(turn + 360 * k / sides)), cy + squash * r * math.sin(math.radians(turn + 360 * k / sides)))
            for k in range(sides)]


def sparkle(p, cx, cy, r, waist=0.24):
    pts = []
    for k in range(8):
        a = math.radians(-90 + 45 * k)
        rr = r if k % 2 == 0 else r * waist
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    p.fill(*pts)


def tapered(p, f, w0, w1, steps=40):
    left, right = [], []
    for k in range(steps + 1):
        t = k / steps
        x, y = f(t)
        x2, y2 = f(min(1, t + 0.01)) if t < 1 else f(t)
        x1, y1 = f(max(0, t - 0.01))
        dx, dy = x2 - x1, y2 - y1
        length = math.hypot(dx, dy) or 1
        nx, ny = -dy / length, dx / length
        w = (w0 + (w1 - w0) * t) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    p.fill(*left, *reversed(right))


def dropshape(p, cx, top, bottom, r):
    cy = bottom - r
    p.dot(cx, cy, r)
    p.fill((cx - r * 0.86, cy - r * 0.5), (cx, top), (cx + r * 0.86, cy - r * 0.5))


# Priest
@figure(HOLY)
def Lance(p):
    p.fill((0.5, 0.05), (0.62, 0.3), (0.55, 0.36), (0.55, 0.95), (0.45, 0.95), (0.45, 0.36), (0.38, 0.3))
    tapered(p, lambda t: (0.5 - 0.3 * t, 0.42 + 0.12 * t), 0.06, 0.0)
    tapered(p, lambda t: (0.5 + 0.3 * t, 0.42 + 0.12 * t), 0.06, 0.0)


@figure(SHADOW)
def MindOrb(p):
    p.dot(0.5, 0.55, 0.34)
    cut(p, lambda h: h.curve(lambda t: (0.5 + 0.22 * t * math.cos(5 * t), 0.55 + 0.22 * t * math.sin(5 * t)), 0.1, 1, width=0.07))
    p.fill((0.5, 0.06), (0.56, 0.22), (0.44, 0.22))


@figure(SHADOW)
def Fiend(p):
    p.fill((0.3, 0.08), (0.4, 0.34), (0.6, 0.34), (0.7, 0.08), (0.76, 0.42), (0.72, 0.7), (0.5, 0.95), (0.28, 0.7), (0.24, 0.42))
    cut(p, lambda h: (h.fill((0.33, 0.48), (0.46, 0.54), (0.36, 0.58)), h.fill((0.67, 0.48), (0.54, 0.54), (0.64, 0.58))))


@figure(SHADOW)
def Shroud(p):
    p.fill(*[(0.5 + 0.3 * math.cos(math.radians(a)), 0.4 + 0.32 * math.sin(math.radians(a))) for a in range(180, 361, 10)],
           (0.84, 0.95), (0.16, 0.95))
    cut(p, lambda h: h.dot(0.5, 0.5, 0.15))


@figure(BLOOD)
def Fangs(p):
    for side in (-1, 1):
        tapered(p, lambda t, s=side: (0.5 + s * (0.2 - 0.08 * t * t), 0.06 + 0.66 * t), 0.26, 0.0)
    dropshape(p, 0.5, 0.7, 0.96, 0.07)


@figure(HOLY)
def Dome(p):
    p.arc(0.5, 0.82, 0.44, 180, 360, width=0.07)
    p.line((0.04, 0.82), (0.96, 0.82), width=0.05)
    p.arc(0.5, 0.82, 0.3, 200, 340, width=0.035)
    p.curve(lambda t: (0.5 + 0.18 * math.cos(t), 0.82 - 0.44 * math.sin(t)), 0, math.pi, width=0.035)
    p.dot(0.34, 0.5, 0.04)


@figure(NATURE)
def Renew(p):
    tapered(p, lambda t: (0.5 + 0.06 * math.sin(3 * t), 0.95 - 0.84 * t), 0.08, 0.02)
    for side, y in ((-1, 0.58), (1, 0.4), (-1, 0.24)):
        tapered(p, lambda t, s=side, y=y: (0.5 + s * 0.3 * t, y - 0.12 * math.sin(math.pi * t) - 0.06 * t), 0.02, 0.0)
        p.fill(*[(0.5 + side * (0.15 + 0.13 * math.cos(a)), y - 0.08 + 0.07 * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 24)])


@figure((0.86, 0.92, 1.0))
def Mending(p):
    p.ring(0.5, 0.52, 0.36, width=0.1)
    sparkle(p, 0.5, 0.52, 0.27)
    sparkle(p, 0.5, 0.08, 0.08)


@figure((0.62, 0.86, 0.3))
def Plague(p):
    for x, y, r in ((0.34, 0.74, 0.18), (0.62, 0.72, 0.2), (0.48, 0.52, 0.18), (0.6, 0.3, 0.1), (0.42, 0.14, 0.07)):
        p.dot(x, y, r)
    cut(p, lambda h: (h.dot(0.4, 0.7, 0.05), h.dot(0.58, 0.7, 0.05)))


@figure(SHADOW)
def Reaper(p):
    p.line((0.32, 0.95), (0.5, 0.1), width=0.07)
    tapered(p, lambda t: (0.5 + 0.38 * math.sin(math.pi * 0.5 * t), 0.12 + 0.36 * t * t), 0.16, 0.0)


# Druid
@figure(ARCANE)
def Moon(p):
    p.dot(0.46, 0.5, 0.42)
    cut(p, lambda h: h.dot(0.66, 0.42, 0.36))


@figure((0.78, 0.92, 0.26))
def Swarm(p):
    for k in range(9):
        t = k / 8
        a = 4.2 * t
        p.dot(0.5 + 0.32 * (1 - 0.6 * t) * math.cos(a), 0.12 + 0.8 * t, 0.07 - 0.03 * t * (k % 2))


@figure(NATURE)
def Bud(p):
    dropshape(p, 0.5, 0.06, 0.82, 0.24)
    tapered(p, lambda t: (0.5 - 0.26 * t, 0.84 + 0.1 * math.sin(math.pi * t)), 0.1, 0.0)
    tapered(p, lambda t: (0.5 + 0.26 * t, 0.84 + 0.1 * math.sin(math.pi * t)), 0.1, 0.0)


@figure(NATURE)
def Sprout(p):
    tapered(p, lambda t: (0.5 + 0.08 * math.sin(4 * t), 0.95 - 0.7 * t), 0.08, 0.04)
    for side, y in ((-1, 0.56), (1, 0.36)):
        p.fill(*[(0.5 + side * (0.2 + 0.18 * math.cos(a)), y + 0.1 * math.sin(a) - 0.06 * math.cos(a) * side) for a in np.linspace(0, 2 * math.pi, 28)])
    p.ring(0.6, 0.18, 0.08, width=0.06)


@figure((1.0, 0.36, 0.2))
def Rake(p):
    for dx in (-0.22, 0.0, 0.22):
        tapered(p, lambda t, dx=dx: (0.5 + dx - 0.08 + 0.18 * t, 0.06 + 0.88 * t), 0.02, 0.12)


@figure(BLOOD)
def Rip(p):
    p.fill((0.36, 0.05), (0.56, 0.24), (0.42, 0.36), (0.62, 0.52), (0.46, 0.62), (0.56, 0.7), (0.42, 0.62), (0.5, 0.52), (0.3, 0.36),
           (0.44, 0.24))
    dropshape(p, 0.36, 0.7, 0.88, 0.06)
    dropshape(p, 0.62, 0.76, 0.96, 0.06)


@figure(AMBER)
def Roar(p):
    for r in (0.18, 0.31, 0.44):
        p.arc(0.5, 0.95, r + 0.1, 220, 320, width=0.08)
    p.dot(0.5, 0.86, 0.08)


@figure((0.96, 0.5, 1.0))
def Faerie(p):
    sparkle(p, 0.5, 0.52, 0.42, 0.2)
    sparkle(p, 0.2, 0.18, 0.12)
    sparkle(p, 0.82, 0.82, 0.1)


@figure(NATURE)
def Growth(p):
    tapered(p, lambda t: (0.5, 0.95 - 0.55 * t), 0.12, 0.06)
    for x, y in ((0.18, 0.2), (0.36, 0.08), (0.64, 0.08), (0.82, 0.2)):
        tapered(p, lambda t, x=x, y=y: (0.5 + (x - 0.5) * t, 0.42 + (y - 0.42) * t ** 0.8), 0.06, 0.03)
        p.dot(x, y, 0.06)


@figure(AMBER)
def Growl(p):
    tapered(p, lambda t: (0.42 + 0.14 * t * t, 0.06 + 0.88 * t), 0.3, 0.0)
    tapered(p, lambda t: (0.74 + 0.04 * t, 0.2 + 0.4 * t), 0.12, 0.0)


@figure(AMBER)
def Charge(p):
    for y in (0.08, 0.38, 0.68):
        p.fill((0.5, y), (0.86, y + 0.26), (0.86, y + 0.34), (0.5, y + 0.12), (0.14, y + 0.34), (0.14, y + 0.26))


# Shaman
@figure(STORM)
def Strike(p):
    p.fill((0.6, 0.04), (0.28, 0.54), (0.48, 0.54), (0.36, 0.96), (0.74, 0.42), (0.54, 0.42))


@figure(FROST)
def Tide(p):
    tapered(p, lambda t: (0.14 + 0.72 * t, 0.9 - 0.42 * math.sin(math.pi * 0.85 * t)), 0.06, 0.16)
    p.curve(lambda t: (0.7 + 0.16 * math.cos(math.pi * (0.9 + 1.4 * t)), 0.34 + 0.16 * math.sin(math.pi * (0.9 + 1.4 * t)) * 1.1), 0, 1,
            width=0.1)
    for x, y in ((0.3, 0.18), (0.42, 0.08), (0.18, 0.32)):
        p.dot(x, y, 0.04)


@figure(HOLY)
def Ankh(p):
    p.ring(0.5, 0.24, 0.16, width=0.1)
    p.line((0.2, 0.48), (0.8, 0.48), width=0.11)
    tapered(p, lambda t: (0.5, 0.42 + 0.54 * t), 0.12, 0.2)


@figure((0.56, 0.82, 1.0))
def Wolf(p):
    p.fill((0.2, 0.06), (0.36, 0.32), (0.64, 0.32), (0.8, 0.06), (0.84, 0.44), (0.66, 0.66), (0.58, 0.92), (0.42, 0.92), (0.34, 0.66),
           (0.16, 0.44))
    cut(p, lambda h: (h.fill((0.3, 0.46), (0.44, 0.5), (0.36, 0.54)), h.fill((0.7, 0.46), (0.56, 0.5), (0.64, 0.54)), h.dot(0.5, 0.86, 0.04)))


@figure((0.74, 0.9, 0.42))
def Shock(p):
    p.fill((0.62, 0.04), (0.32, 0.46), (0.5, 0.46), (0.4, 0.8), (0.7, 0.36), (0.52, 0.36))
    p.fill((0.1, 0.86), (0.4, 0.82), (0.5, 0.9), (0.6, 0.82), (0.9, 0.86), (0.9, 0.94), (0.1, 0.94))


def render(draw, colour, core_colour):
    pen = Pen()
    draw(pen)
    mask = np.asarray(pen.image, np.float64) / 255
    x, y = grid()
    glow = np.clip(blur(mask, 4) * 1.4, 0, 1)
    core = 0.65 * np.clip((blur(mask, 2.2) - 0.72) / 0.26, 0, 1) * mask
    shade = 0.72 + 0.28 * (1 - y)
    colour, core_colour = np.array(colour), np.array(core_colour)
    rgb = (colour * 0.9)[None, None] * (0.75 * glow)[..., None] * (1 - mask)[..., None]
    rgb = rgb + (colour[None, None] * shade[..., None] * (1 - core)[..., None] + core_colour[None, None] * core[..., None]) * mask[..., None]
    light = np.clip(np.maximum(mask, 0.75 * glow), 0, 1)
    return additive(np.clip(rgb, 0, 1) * light[..., None])


def sheet(images, path, cell=96):
    names = list(images)
    columns = 9
    rows = (len(names) + columns - 1) // columns
    out = Image.new("RGB", (columns * (cell + 40), rows * (cell + 24)), (14, 14, 18))
    draw = ImageDraw.Draw(out)
    for k, name in enumerate(names):
        x, y = k % columns * (cell + 40), k // columns * (cell + 24)
        for size, dx, dy in ((cell, 0, 0), (18, cell + 6, 0)):
            a = np.asarray(Image.fromarray(np.clip(images[name] * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA")
                           .resize((size, size), Image.LANCZOS), np.float64) / 255
            add = (a[..., :3] * a[..., 3:4] * 255).astype(np.uint8)
            out.paste(Image.fromarray(add), (x + dx, y + dy))
        draw.text((x + 2, y + cell + 6), name, fill=(200, 200, 200))
    out.save(path)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--sheet", type=Path)
    args = parser.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    images = {}
    for name, (draw, colour, core) in FIGURES.items():
        images[name] = render(draw, colour, core)
        path = args.out / f"{name}.png"
        Image.fromarray(np.clip(images[name] * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)
        print(path.relative_to(args.out.parents[2]) if args.out == OUT else path, hashlib.sha256(path.read_bytes()).hexdigest())
    if args.sheet:
        sheet(images, args.sheet)


if __name__ == "__main__":
    main()
