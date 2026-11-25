"""Draw the warrior, paladin and rogue crest effects' art into Media/Textures/Medallions/Effects/.

Procedural, no model and no input image. Each piece is a forged object, drawn white so the game tints it (gilt,
steel, a school's colour), and stands upright filling the height, so a vertical status bar crops it from the top:

- Sword.png, Axe.png, Dagger.png, Hammer.png: a weapon standing on its pommel; it draws out of its hilt as it fills.
- Horn.png: a war horn, mouthpiece low right, bell high left (towards the band), with two bands.
- Shield.png, ShieldCracked.png: a heater shield with a boss and cross ribs; the cracked one shows under the lit face.
- Seal.png: a round wax-cut seal with a scalloped edge and a flared cross.
- Brand.png: a four-pointed radiant brand.
- Drop.png: a drop of blood, point up.
- Vial.png and VialGlass.png: a round flask's liquid and its glass (rim, neck and a highlight), drawn over it.
- <Name>Glow.png for each but the cracked shield and the glass: the object's silhouette blurred on a canvas half as
  wide again, white with the light as alpha, drawn ADD behind the lit object.
- <Name>Shade.png for the same: black with the art's darkness as alpha, drawn over the plain lit fill (which the
  object's own outline masks), so the fill is shaded like the metal and a partial fill never redraws the object.
- SwordHilt.png, AxeHilt.png, DaggerHilt.png, HammerHilt.png: the part below the blade or head, planted while the rest fills.

Metal is lit from the top left with a soft bevel, an engraved groove and a dark outline. Each is drawn at 8x and
reduced with a linear-light premultiplied Lanczos; BLEND art with straight alpha.

    python3 Tools/media/melee_effects.py [--out DIR]
"""
import argparse
import hashlib
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE, SCALE = 64, 8
N = SIZE * SCALE
OUT = Path(__file__).resolve().parents[2] / "Media/Textures/Medallions/Effects"
LIGHT = np.array([-0.55, -0.65, 0.55])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def canvas():
    image = Image.new("L", (N, N), 0)
    return image, ImageDraw.Draw(image)


def px(points):
    return [(x * N, y * N) for x, y in points]


def array(image):
    return np.asarray(image, np.float64) / 255


def blur(a, radius):
    image = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(image.filter(ImageFilter.GaussianBlur(radius * SCALE)), np.float64) / 255


def grow(a, radius):
    image = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(image.filter(ImageFilter.MaxFilter(2 * int(radius * SCALE) + 1)), np.float64) / 255


def lines(segments, width):
    image, draw = canvas()
    w = int(width * N)
    for points in segments:
        draw.line(px(points), fill=255, width=w, joint="curve")
    return array(image)


def metal(shape, grooves=None, bevel=1.6, base=0.42, outline=0.9):
    """Forged metal over a silhouette: a bevelled height, light from the top left, a groove and a dark outline."""
    height = blur(shape, bevel) * shape
    gy, gx = np.gradient(height * N / SCALE / 2.5)
    normal = np.dstack([-gx, -gy, np.ones_like(gx)])
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    diffuse = np.clip(normal @ LIGHT, 0, 1)
    spec = np.clip(2 * diffuse * normal[..., 2] - LIGHT[2], 0, 1) ** 24
    tone = base + 0.1 + 0.85 * diffuse ** 1.3 + 0.5 * spec
    if grooves is not None:
        cut = blur(grooves, 0.25) * shape
        tone = tone * (1 - 0.65 * cut) + 0.12 * np.clip(np.roll(cut, (-SCALE, -SCALE), (0, 1)) - cut, 0, 1)
    ring = np.clip(grow(shape, outline) - shape, 0, 1)
    tone = np.clip(tone, 0, 1) * shape + 0.06 * ring
    return np.dstack([tone, tone, tone]), np.clip(shape + ring, 0, 1)


def reduce(rgb, alpha, size=SIZE):
    channels = [rgb[..., c] ** 2.2 * alpha for c in range(3)] + [alpha]
    small = [np.asarray(Image.fromarray(c.astype(np.float32), "F").resize((size, size), Image.LANCZOS)) for c in channels]
    a = np.clip(small[3], 0, 1)
    colour = np.dstack([np.where(a > 0, np.clip(small[c], 0, None) / np.maximum(a, 1e-6), 0) ** (1 / 2.2) for c in range(3)])
    return np.dstack([np.clip(colour, 0, 1), a])


def polygon(points):
    image, draw = canvas()
    draw.polygon(px(points), fill=255)
    return array(image)


def union(*parts):
    return np.maximum.reduce(parts)


def ellipse(cx, cy, rx, ry):
    image, draw = canvas()
    draw.ellipse([(cx - rx) * N, (cy - ry) * N, (cx + rx) * N, (cy + ry) * N], fill=255)
    return array(image)


def rect(x0, y0, x1, y1):
    image, draw = canvas()
    draw.rounded_rectangle([x0 * N, y0 * N, x1 * N, y1 * N], radius=0.015 * N, fill=255)
    return array(image)


def hilt(guard, grip, pommel=0.94):
    return union(rect(0.5 - guard / 2, 0.63, 0.5 + guard / 2, 0.69), rect(0.5 - grip, 0.69, 0.5 + grip, pommel - 0.04),
                 ellipse(0.5, pommel - 0.02, 0.055, 0.04))


def sword():
    blade = polygon([(0.5, 0.03), (0.6, 0.16), (0.6, 0.63), (0.4, 0.63), (0.4, 0.16)])
    guard = union(hilt(0.56, 0.045), ellipse(0.22, 0.66, 0.05, 0.05), ellipse(0.78, 0.66, 0.05, 0.05))
    return metal(union(blade, guard), lines([[(0.5, 0.14), (0.5, 0.58)], [(0.47, 0.75), (0.53, 0.78)], [(0.47, 0.82), (0.53, 0.85)]], 0.016))


def dagger():
    blade = polygon([(0.5, 0.05), (0.63, 0.3), (0.61, 0.62), (0.39, 0.62), (0.37, 0.3)])
    guard = polygon([(0.2, 0.6), (0.5, 0.65), (0.8, 0.6), (0.78, 0.68), (0.5, 0.71), (0.22, 0.68)])
    return metal(union(blade, guard, hilt(0.0, 0.04)), lines([[(0.5, 0.2), (0.5, 0.58)]], 0.016))


def axe():
    haft = rect(0.465, 0.1, 0.535, 0.93)
    t = np.linspace(-1, 1, 40)
    edge = [(0.08 + 0.05 * (1 - s * s), 0.32 + 0.22 * s + 0.04 * s ** 3) for s in t]
    head = polygon([(0.48, 0.14), (0.3, 0.17)] + edge + [(0.3, 0.5), (0.48, 0.42)])
    spike = polygon([(0.53, 0.24), (0.76, 0.3), (0.53, 0.37)])
    tip = polygon([(0.5, 0.07), (0.545, 0.14), (0.455, 0.14)])
    grooves = [[(0.15 + 0.06 * (1 - s * s), 0.3 + 0.24 * s) for s in t[4:-4]], [(0.47, 0.62), (0.53, 0.65)], [(0.47, 0.7), (0.53, 0.73)]]
    return metal(union(haft, head, spike, tip), lines(grooves, 0.014))


def hammer():
    head = polygon([(0.2, 0.12), (0.26, 0.06), (0.74, 0.06), (0.8, 0.12), (0.8, 0.3), (0.74, 0.36), (0.26, 0.36), (0.2, 0.3)])
    haft = rect(0.465, 0.34, 0.535, 0.9)
    knob = ellipse(0.5, 0.92, 0.05, 0.04)
    grooves = [[(0.26, 0.21), (0.74, 0.21)], [(0.35, 0.09), (0.35, 0.33)], [(0.65, 0.09), (0.65, 0.33)], [(0.47, 0.72), (0.53, 0.75)]]
    return metal(union(head, haft, knob), lines(grooves, 0.016))


def horn():
    image, draw = canvas()
    def at(t):
        x = (1 - t) ** 2 * 0.8 + 2 * (1 - t) * t * 0.78 + t * t * 0.22
        y = (1 - t) ** 2 * 0.92 + 2 * (1 - t) * t * 0.3 + t * t * 0.24
        return x, y
    for i in range(121):
        t = i / 120
        x, y = at(t)
        r = 0.05 + 0.09 * t ** 2
        draw.ellipse([(x - r) * N, (y - r) * N, (x + r) * N, (y + r) * N], fill=255)
    bell = ellipse(0.2, 0.2, 0.13, 0.14)
    shape = union(array(image), bell)
    bands = []
    for t in (0.35, 0.68):
        x, y = at(t)
        x1, y1 = at(t + 0.01)
        nx, ny = -(y1 - y), x1 - x
        k = (0.05 + 0.09 * t ** 2 + 0.01) / math.hypot(nx, ny)
        bands.append([(x - nx * k, y - ny * k), (x + nx * k, y + ny * k)])
    rgb, alpha = metal(shape, lines(bands, 0.04))
    mouth = blur(ellipse(0.18, 0.19, 0.08, 0.1), 0.3)
    rgb = rgb * (1 - 0.9 * mouth[..., None])
    return rgb, alpha


def shield_shape():
    t = np.linspace(0, 1, 30)
    right = [(0.87 - 0.37 * s ** 1.6, 0.45 + 0.5 * s) for s in t]
    left = [(1 - x, y) for x, y in reversed(right)]
    return polygon([(0.13, 0.06), (0.5, 0.1), (0.87, 0.06)] + right + left)


def shield(cracked=False):
    shape = shield_shape()
    grooves = [[(0.5, 0.12), (0.5, 0.88)], [(0.17, 0.4), (0.83, 0.4)]]
    if cracked:
        grooves += [[(0.5, 0.4), (0.38, 0.28), (0.4, 0.18), (0.3, 0.1)], [(0.5, 0.4), (0.66, 0.52), (0.62, 0.64), (0.74, 0.72)],
                    [(0.5, 0.4), (0.36, 0.56), (0.4, 0.7)]]
    rgb, alpha = metal(shape, lines(grooves, 0.04 if cracked else 0.016))
    boss_rgb, boss_alpha = metal(ellipse(0.5, 0.4, 0.1, 0.1), bevel=2.2, base=0.5, outline=0.5)
    rgb = rgb * (1 - boss_alpha[..., None]) + boss_rgb * boss_alpha[..., None]
    rim = np.clip(shape - polygon([(x * 0.84 + 0.08, y * 0.86 + 0.07) for x, y in [(0.13, 0.08), (0.87, 0.08), (0.87, 0.5), (0.5, 0.95), (0.13, 0.5)]]), 0, 1)
    return rgb * (1 + 0.15 * rim[..., None]), alpha


def seal():
    y, x = np.mgrid[0:N, 0:N].astype(np.float64) / (N - 1)
    r, a = np.hypot(x - 0.5, y - 0.5), np.arctan2(y - 0.5, x - 0.5)
    shape = (r < 0.42 + 0.035 * np.cos(14 * a)).astype(np.float64)
    groove = np.clip(1 - np.abs(r - 0.31) / 0.012, 0, 1)
    cross = union(polygon([(0.44, 0.24), (0.56, 0.24), (0.53, 0.46), (0.53, 0.47), (0.56, 0.76), (0.44, 0.76), (0.47, 0.47)]),
                  polygon([(0.24, 0.44), (0.47, 0.47), (0.76, 0.44), (0.76, 0.56), (0.47, 0.53), (0.24, 0.56)]))
    rgb, alpha = metal(shape, groove + 0.8 * np.clip(grow(cross, 0.4) - cross, 0, 1), bevel=2.0)
    return rgb * (1 - 0.45 * cross[..., None]), alpha


def brand():
    points = []
    for k in range(8):
        angle = math.pi / 2 + k * math.pi / 4
        r = (0.47 if k % 4 == 0 else 0.36) if k % 2 == 0 else 0.1
        points.append((0.5 + r * math.cos(angle), 0.5 - r * math.sin(angle)))
    star = polygon(points)
    y, x = np.mgrid[0:N, 0:N].astype(np.float64) / (N - 1)
    ring = (np.abs(np.hypot(x - 0.5, y - 0.5) - 0.2) < 0.03).astype(np.float64)
    rgb, alpha = metal(union(star, ring), lines([[(0.5, 0.1), (0.5, 0.9)], [(0.18, 0.5), (0.82, 0.5)]], 0.012), bevel=1.2)
    tips = blur(union(*[ellipse(0.5 + dx, 0.5 + dy, 0.05, 0.05) for dx, dy in ((0, -0.4), (0, 0.4), (-0.3, 0), (0.3, 0))]), 0.8)
    return np.clip(rgb + 0.5 * tips[..., None] * alpha[..., None], 0, 1), alpha


def drop():
    t = np.linspace(-math.pi * 0.85, math.pi * 0.85, 60)
    body = [(0.5 + 0.29 * math.sin(s), 0.65 + 0.29 * math.cos(s)) for s in t]
    shape = polygon([(0.5, 0.05)] + body[::-1])
    rgb, alpha = metal(shape, bevel=3.0, base=0.5)
    shine = blur(ellipse(0.39, 0.6, 0.045, 0.1), 0.5)
    return np.clip(rgb + 0.5 * shine[..., None], 0, 1), alpha


FLASK = (0.5, 0.64, 0.3)


def vial():
    cx, cy, r = FLASK
    liquid = union(ellipse(cx, cy, r - 0.05, r - 0.05), rect(0.445, 0.28, 0.555, cy))
    rgb, alpha = metal(liquid, bevel=3.5, base=0.55, outline=0)
    shine = np.clip(blur(lines([[(0.35, 0.56), (0.33, 0.66), (0.37, 0.76)]], 0.03), 0.3) * 1.4, 0, 1) * alpha
    return np.clip(rgb + shine[..., None], 0, 1), alpha


def glass():
    cx, cy, r = FLASK
    outer = union(ellipse(cx, cy, r, r), rect(0.41, 0.12, 0.59, cy))
    inner = union(ellipse(cx, cy, r - 0.035, r - 0.035), rect(0.445, 0.15, 0.555, cy))
    lip = rect(0.37, 0.06, 0.63, 0.13)
    wall = np.clip(outer - inner, 0, 1)
    rgb, alpha = metal(union(wall, lip), bevel=0.6, base=0.55)
    return np.where(inner[..., None] > 0, 0.03, rgb), np.clip(alpha + 0.4 * inner, 0, 1)


def halo(alpha, size=SIZE):
    """The object's own glow: its silhouette blurred on a canvas half as wide again, white, drawn ADD."""
    n = alpha.shape[0]
    pad = n // 4
    big = np.zeros((n + 2 * pad, n + 2 * pad))
    big[pad:pad + n, pad:pad + n] = alpha
    image = Image.fromarray(np.clip(big * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.5 * SCALE * n / N))
    glow = np.clip(np.asarray(image.resize((size, size), Image.LANCZOS), np.float64) / 255 * 1.8, 0, 1)
    return np.dstack([np.ones_like(glow)] * 3 + [glow])


GROOVE, BAND = (59.5, 66.5), (56.5, 69.5)
# The crest pieces, in crest units round the hub's centre: art size in pixels, square side, centre x and y.
SEATS = {"GrooveLL": (128, 50, -47.0, -36.5), "GrooveLR": (128, 50, 47.0, -36.5), "GrooveBL": (64, 27, -21.3, -58.9),
         "GrooveBR": (64, 27, 21.3, -58.9), "Stain": (128, 92, 44.3, 0.0), "Flames": (128, 50, 47.0, -36.5), "Cracks": (256, 150, 0.0, 0.0),
         "Ward": (256, 120, 0.0, 0.0), "Oath": (256, 120, 0.0, 0.0), "OathInner": (256, 120, 0.0, 0.0), "Fuse": (256, 150, 0.0, 0.0),
         "Spark": (256, 150, 0.0, 0.0), "Wave": (256, 150, 0.0, 0.0), "BandFlash": (256, 150, 0.0, 0.0)}
FUSE = 71.5
ARCS = {"GrooveLL": (195, 240), "GrooveLR": (300, 345), "GrooveBL": (242, 257), "GrooveBR": (283, 298)}


def units(name):
    """Crest coordinates of a piece's 8x canvas: x and y in units, radius and angle."""
    px, side, cx, cy = SEATS[name]
    n = px * SCALE
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    ux, uy = cx + (x / (n - 1) - 0.5) * side, cy - (y / (n - 1) - 0.5) * side
    return ux, uy, np.hypot(ux, uy), np.degrees(np.arctan2(uy, ux)) % 360


def sector(name, a0, a1, r0, r1):
    ux, uy, r, a = units(name)
    mid, half = (r0 + r1) / 2, (r1 - r0) / 2
    inside = (((a - a0) % 360) <= (a1 - a0) % 360) & (np.abs(r - mid) <= half)
    for e in (a0, a1):
        inside |= np.hypot(ux - mid * math.cos(math.radians(e)), uy - mid * math.sin(math.radians(e))) <= half
    return inside.astype(np.float64), r, mid, half


def groove(name):
    """A groove cut into the rune band, lighter along its middle; the left foot's carries a notch cut through it, so the lit charge shows it too."""
    shape, r, mid, half = sector(name, *ARCS[name], *GROOVE)
    tone = 0.72 + 0.28 * np.clip(1 - np.abs(r - mid) / half, 0, 1)
    if name == "GrooveBL":
        ux, uy, _, _ = units(name)
        a = math.radians(250.5)
        x, y = 63 * math.cos(a), 63 * math.sin(a)
        notch = (np.abs(np.abs(ux - x) - (uy - y + 2.4) * 0.8) < 0.55) & (uy > y - 2.6) & (uy < y + 2.6)
        shape = np.where(notch, 0.0, shape)
    return np.dstack([tone] * 3), shape


def cracks():
    """Jagged cracks of fire across the rune band, none over the level badge, a white core in a soft glow; tinted by the swipe colour."""
    px, side, cx, cy = SEATS["Cracks"]
    n = px * SCALE
    image = Image.new("L", (n, n), 0)
    draw = ImageDraw.Draw(image)
    rng = np.random.default_rng(7)

    def to(x, y):
        return (x - cx) / side * (n - 1) + (n - 1) / 2, (cy - y) / side * (n - 1) + (n - 1) / 2

    for k in range(28):
        a, r = k * 360 / 28 + rng.uniform(-4, 4), BAND[0] + rng.uniform(0, 2)
        pts = []
        while r < BAND[1] and len(pts) < 6 and not 252 < a % 360 < 288:
            pts.append(to(r * math.cos(math.radians(a)), r * math.sin(math.radians(a))))
            r, a = r + rng.uniform(1.4, 3.0), a + rng.uniform(-5, 5)
        if len(pts) > 1:
            draw.line(pts, fill=255, width=int(1.1 / side * n), joint="curve")
    core = np.asarray(image, np.float64) / 255
    glow = np.asarray(image.filter(ImageFilter.GaussianBlur(2.2 / side * n)), np.float64) / 255
    return np.dstack([np.clip(0.75 + 0.25 * core, 0, 1)] * 3), np.clip(core + 1.6 * glow, 0, 1)


def ward():
    """A ward over the emblem: a bright rim on a faint dome."""
    ux, uy, _, _ = units("Ward")
    e = np.sqrt((ux / 50) ** 2 + (uy / 56) ** 2)
    light = np.clip(0.9 * np.exp(-((e - 1) / 0.035) ** 2) + 0.14 * np.sqrt(np.clip(1 - e * e, 0, 1)), 0, 1)
    return np.ones(light.shape + (3,)), light


def stain():
    """Blood flooding the ring's inner right side, darkest at its inner edge."""
    shape, r, mid, half = sector("Stain", 315, 45, 46, 56)
    tone = 0.55 + 0.45 * np.clip((r - 46) / 10, 0, 1)
    return np.dstack([tone] * 3), shape * np.clip((r - 45) / 3, 0, 1)


def flames():
    """Five Inner Fire flames standing along the lower right of the band, drawn ADD."""
    px, side, cx, cy = SEATS["Flames"]
    n = px * SCALE
    src = Image.open(Path(__file__).resolve().parents[2] / "Media/Textures/Medallions/Trackers/Flame.png").convert("RGBA")
    out = np.zeros((n, n, 4))
    w = int(12 / side * n)
    f = np.asarray(src.resize((w, w), Image.LANCZOS), np.float64) / 255
    for a in np.linspace(305, 338, 5):
        x, y = 63 * math.cos(math.radians(a)), 63 * math.sin(math.radians(a)) + 2
        x0, y0 = int((x - cx) / side * (n - 1) + (n - 1) / 2 - w / 2), int((cy - y) / side * (n - 1) + (n - 1) / 2 - w / 2)
        out[y0:y0 + w, x0:x0 + w] = np.maximum(out[y0:y0 + w, x0:x0 + w], f)
    return out[..., :3], out[..., 3]


def fuse():
    """Slice and Dice's fine fuse round the outer band, broken over the level badge (258 to 282 degrees); a white swipe tinted gold."""
    shape, _, _, _ = sector("Fuse", 282, 258, FUSE - 1.1, FUSE + 1.1)
    glow = np.asarray(Image.fromarray((shape * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5 / 150 * shape.shape[0])), np.float64) / 255
    return np.ones(shape.shape + (3,)), np.clip(shape + 0.6 * glow, 0, 1) * (((units("Fuse")[3] - 260) % 360) > 20)


def spark():
    """The fuse's travelling light: a bright bead at the top of the band with a tail fading back along it, turned clockwise round the crest."""
    ux, uy, r, a = units("Spark")
    head = np.exp(-(ux ** 2 + (uy - FUSE) ** 2) / 2.5 ** 2)
    behind = (a - 90) % 360
    tail = np.where(behind < 24, 1 - behind / 24, 0) * np.exp(-((r - FUSE) / 1.1) ** 2)
    alpha = np.clip(head + 0.8 * tail, 0, 1)
    return np.ones(alpha.shape + (3,)), alpha


def arc(name, a0, a1, r0, r1):
    """A soft arc, brightest along its middle."""
    shape, r, mid, half = sector(name, a0, a1, r0, r1)
    return np.ones(shape.shape + (3,)), shape * np.clip(1.2 - np.abs(r - mid) / half, 0, 1)


def shade(rgb, alpha):
    """Black with the art's darkness as alpha: drawn over a plain lit fill it multiplies the fill by the art's light."""
    return np.zeros_like(rgb), (1 - rgb[..., 0]) * alpha


ART = {"Sword.png": sword, "Axe.png": axe, "Dagger.png": dagger, "Hammer.png": hammer, "Horn.png": horn,
       "Shield.png": shield, "ShieldCracked.png": lambda: shield(True), "Seal.png": seal, "Brand.png": brand,
       "Drop.png": drop, "Vial.png": vial, "VialGlass.png": glass}
NO_GLOW = {"ShieldCracked.png", "VialGlass.png"}
HILT = {"Sword.png": 0.63, "Dagger.png": 0.6, "Axe.png": 0.5, "Hammer.png": 0.36}
BAND_ART = {"GrooveLL.png": lambda: groove("GrooveLL"), "GrooveLR.png": lambda: groove("GrooveLR"), "GrooveBL.png": lambda: groove("GrooveBL"),
            "GrooveBR.png": lambda: groove("GrooveBR"), "Cracks.png": cracks, "Ward.png": ward, "Stain.png": stain, "Flames.png": flames,
            "Oath.png": lambda: arc("Oath", 210, 330, 51, 53.5), "OathInner.png": lambda: arc("OathInner", 215, 325, 48.8, 50.8), "Fuse.png": fuse,
            "Spark.png": spark, "Wave.png": lambda: arc("Wave", 152, 174, 60, 68), "BandFlash.png": lambda: arc("BandFlash", 285, 75, 57, 73)}
BARE = {"Cracks.png", "Flames.png", "Fuse.png", "Spark.png", "Wave.png", "BandFlash.png"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    for name, draw in ART.items():
        rgb, alpha = draw()
        pictures = [(name, reduce(rgb, alpha))]
        if name not in NO_GLOW:
            pictures += [(name.replace(".png", "Glow.png"), halo(alpha)), (name.replace(".png", "Shade.png"), reduce(*shade(rgb, alpha)))]
        if name in HILT:
            below = (np.mgrid[0:N, 0:N][0] / (N - 1) > HILT[name]).astype(np.float64)
            pictures.append((name.replace(".png", "Hilt.png"), reduce(rgb, alpha * below)))
        save(args.out, pictures)
    for name, draw in BAND_ART.items():
        rgb, alpha = draw()
        size = SEATS[name[:-4]][0]
        pictures = [(name, reduce(rgb, alpha, size))]
        if name not in BARE:
            pictures.append((name.replace(".png", "Glow.png"), halo(alpha, size)))
        save(args.out, pictures)


def save(out, pictures):
    for file, art in pictures:
        path = out / file
        Image.fromarray(np.clip(art * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)
        print(path.relative_to(out.parents[3]) if out == OUT else path, hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
