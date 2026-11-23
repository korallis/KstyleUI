"""Draw the crest trackers' art into Media/Textures/Medallions/Trackers/.

Procedural, no model and no input image, each drawn at 8x and reduced with a linear-light Lanczos:

- Flame.png: the priest's Inner Fire flame, a white-hot core in a gold body with an orange glow, its tip licking to
  one side; it fills the height so a vertical StatusBar burns it down from the tip.
- Leaf.png: the druid's Clearcasting leaf, pointing up, a green blade with a gold midrib and veins in a soft glow.
- Rune.png: the shaman's imbue rune, a forked stave with a short cross stroke, white in a soft glow, tinted by the
  imbue's element; it fills the height so a vertical StatusBar drains it from the top.
- Stone.png: the rune stone the rune is set into, a rounded slate pebble lit from the top left with the rune's
  grooves cut dark into it and a 1-unit dark outline.

Flame, Leaf and Rune are drawn ADD: colour unpremultiplied, alpha the brightest channel (as medallions_kit.py stores
effects). Stone is BLEND art with straight alpha.

    python3 Tools/media/healer_trackers.py [--out DIR]
"""
import argparse
import hashlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE, SCALE = 64, 8
N = SIZE * SCALE
OUT = Path(__file__).resolve().parents[2] / "Media/Textures/Medallions/Trackers"
RUNE = [((0.5, 0.86), (0.5, 0.14)), ((0.5, 0.5), (0.27, 0.24)), ((0.5, 0.5), (0.73, 0.24)), ((0.36, 0.7), (0.64, 0.7))]


def grid():
    y, x = np.mgrid[0:N, 0:N].astype(np.float64) / (N - 1)
    return x, y


def blur(a, radius):
    image = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(image.filter(ImageFilter.GaussianBlur(radius * SCALE)), np.float64) / 255


def reduce(channels):
    out = [np.asarray(Image.fromarray(c.astype(np.float32), "F").resize((SIZE, SIZE), Image.LANCZOS)) for c in channels]
    return [np.clip(c, 0, 1) for c in out]


def additive(rgb):
    r, g, b = reduce([rgb[..., c] ** 2.2 for c in range(3)])
    small = np.dstack([r, g, b]) ** (1 / 2.2)
    alpha = small.max(axis=2)
    colour = np.where(alpha[..., None] > 0, small / np.maximum(alpha[..., None], 1e-6), 0)
    return np.dstack([colour, alpha])


def blended(rgb, alpha):
    channels = reduce([rgb[..., c] ** 2.2 * alpha for c in range(3)] + [alpha])
    a = channels[3]
    colour = np.dstack([np.where(a > 0, channels[c] / np.maximum(a, 1e-6), 0) ** (1 / 2.2) for c in range(3)])
    return np.dstack([np.clip(colour, 0, 1), a])


def mix(layers):
    rgb = np.zeros((N, N, 3))
    for colour, weight in layers:
        rgb = rgb * (1 - weight[..., None]) + np.array(colour) * weight[..., None]
    return rgb


def strokes(width, segments=RUNE):
    image = Image.new("L", (N, N), 0)
    draw = ImageDraw.Draw(image)
    w = int(width * N)
    for (x0, y0), (x1, y1) in segments:
        draw.line([(x0 * N, y0 * N), (x1 * N, y1 * N)], fill=255, width=w)
        for x, y in ((x0, y0), (x1, y1)):
            draw.ellipse([x * N - w / 2, y * N - w / 2, x * N + w / 2, y * N + w / 2], fill=255)
    return np.asarray(image, np.float64) / 255


def flame():
    x, y = grid()
    t = (0.96 - y) / 0.92
    bulb = np.sqrt(np.clip(1 - ((0.3 - t) / 0.3) ** 2, 0, 1))
    half = 0.21 * np.where(t < 0.3, bulb, ((1 - np.clip(t, 0, 1)) / 0.7) ** 1.25) + 1e-4
    axis = 0.5 + 0.06 * np.sin(2.2 * np.pi * t) * np.clip(t, 0, 1) ** 1.6
    d = np.abs(x - axis) / half
    inside = (t > 0) & (t < 1)
    body = np.clip(1 - d, 0, 1) ** 0.6 * inside
    core = np.clip(1 - d / 0.38, 0, 1) ** 0.9 * np.clip(1 - t / 0.7, 0, 1) ** 0.5 * inside
    glow = np.clip(blur(body, 6) * 1.5, 0, 1)
    rgb = mix([((1.0, 0.5, 0.12), 0.8 * glow), ((1.0, 0.74, 0.27), body), ((1.0, 0.97, 0.86), core)])
    return additive(rgb * np.clip(np.maximum(0.7 * glow, body), 0, 1)[..., None])


def leaf():
    x, y = grid()
    t = (0.92 - y) / 0.82
    half = 0.2 * np.sin(np.pi * np.clip(t, 0, 1) ** 0.8) ** 0.85 + 1e-4
    axis = 0.5 + 0.03 * np.sin(np.pi * np.clip(t, 0, 1))
    d = np.abs(x - axis) / half
    inside = (t > 0) & (t < 1)
    blade = np.clip((1 - d) * 3, 0, 1) * inside
    rib = np.clip(1 - np.abs(x - axis) / 0.012, 0, 1) * (t > -0.12) * (t < 0.9)
    veins = np.zeros_like(x)
    for k in range(1, 5):
        start = 0.16 * k
        along = (t - start) * 0.82
        side = np.abs(x - axis)
        veins += np.clip(1 - np.abs(along - side * 0.9) / 0.012, 0, 1) * (side < half * 0.85) * (t > start)
    veins = np.clip(veins, 0, 1) * blade
    glow = blur(blade, 3)
    shade = 0.55 + 0.45 * np.clip(1 - d, 0, 1) ** 0.5
    rgb = mix([((0.35, 0.75, 0.2), 0.5 * glow), ((0.42, 0.82, 0.26), blade * shade), ((1.0, 0.86, 0.42), 0.8 * veins), ((1.0, 0.95, 0.7), rib)])
    return additive(rgb * np.clip(np.maximum(0.5 * glow, np.maximum(blade * shade, rib)), 0, 1)[..., None])


def rune():
    lines = strokes(0.075)
    glow = np.clip(blur(lines, 3) * 1.6, 0, 1)
    light = np.clip(np.maximum(lines, 0.6 * glow), 0, 1)
    rgb = mix([((0.85, 0.9, 1.0), glow), ((1.0, 1.0, 1.0), lines)])
    return additive(rgb * light[..., None])


def stone():
    x, y = grid()
    cx, cy, rx, ry = 0.5, 0.52, 0.42, 0.46
    r = np.sqrt(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)
    outline = (r < 1).astype(np.float64)
    body = (r < 1 - 1 / 32).astype(np.float64)
    nz = np.sqrt(np.clip(1 - np.minimum(r, 1) ** 2, 0, 1))
    nx, ny = (x - cx) / rx * 0.7, (y - cy) / ry * 0.7
    light = np.clip(-0.5 * nx - 0.6 * ny + 0.62 * nz, 0, 1)
    base = 0.12 + 0.36 * light + 0.2 * np.clip(-nx - ny, 0, 1) ** 4
    grooves = blur(strokes(0.1), 0.6)
    lip = blur(strokes(0.1, [((a[0] + 0.01, a[1] + 0.012), (b[0] + 0.01, b[1] + 0.012)) for a, b in RUNE]), 0.6)
    tone = np.clip(base * (1 - 0.75 * grooves) + 0.18 * np.clip(lip - grooves, 0, 1), 0, 1)
    slate = np.dstack([tone * 0.92, tone * 0.95, tone * 1.05])
    rgb = slate * body[..., None] + np.array([0.04, 0.04, 0.05]) * (outline - body)[..., None]
    return blended(np.clip(rgb, 0, 1), outline)


ART = {"Flame.png": flame, "Leaf.png": leaf, "Rune.png": rune, "Stone.png": stone}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    for name, draw in ART.items():
        path = args.out / name
        Image.fromarray(np.clip(draw() * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)
        print(path.relative_to(args.out.parents[3]) if args.out == OUT else path, hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
