"""Draw KstyleUI's procedural textures and logo into Media/.

Usage:
    python3 Tools/media/make_media.py [--root DIR] [--only NAME ...]
    python3 Tools/media/make_media.py --check

Every texture is drawn at 4x and downsampled: each pixel is the mean of SUPERSAMPLE x SUPERSAMPLE
samples of a shape or a smooth function. Shapes are white with their coverage in alpha, so the game
tints them with SetVertexColor. Status bars hold their shading in the colour channels, so
SetStatusBarColor tints them. Coordinates are texture pixels, origin top left. Standard library only.

The default run writes every asset under DIR (the repository root by default) and rewrites the
generated table in Media/PROVENANCE.md. --only limits the run to the named assets (file stems).
--check draws in memory and compares with the files on disk, allowing one step per channel for libm
differences between platforms. It prints each mismatch and exits 1 if there is any.
"""

import argparse
import math
import random
import struct
import sys
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional

ROOT = Path(__file__).resolve().parents[2]
SUPERSAMPLE = 4
DRAWN = "2026-11-07"
LUMEN_DRAWN = "2026-11-09"

# Rounded corners are drawn at 4 texels per root unit, so the 14-unit radius is 56 texels. The shadow is
# soft, so 2 texels per unit is enough.
TEXELS_PER_UNIT = 4
SHADOW_TEXELS_PER_UNIT = 2
SHADOW_REACH = 6  # root units the shadow reaches past the panel edge
GLASS_DROP = 1 - 1 / 1.12  # the health fill's top is 12% brighter than its bottom
PILL_CAP = 16  # texels: each round cap of Pill.png is a quarter of its 64-texel width
# The rounded shape is drawn at 14 units, so its corner pieces stretch cleanly down to any smaller corner. The
# outline is a 0.75-unit line (3 texels) on an 8-unit corner, for bars and highlight rings.
LUMEN_RADIUS, LUMEN_TILE_RADIUS = 14, 8
RIM_TEXELS = 3
# The owner's picture (2026-11-09) draws every card and socket edge as lines one border thick on corners a whole
# number of border lines round: a card's dark edge line on a six-line corner with its rim one line inside it, a
# socket's dark edge on a three-line corner. RingLineN is a quarter ring one line thick on the outside of an N-line corner, so the kit
# draws its corner piece N border lines square and the arc lands on the same whole pixels as the straight runs.
RING_LINES = (2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32)
RING_TEXELS = 128
# The icon in a socket: the picture's icon is rounded to meet its socket's two-line inner corner, 3 units on a
# 44-unit icon, as a share of the side (masks stretch).
ICON_RADIUS_SHARE = 3 / 44
# The square portrait keeps its own mask, 8 units on 44, matching the rounder corner its frame pins.
PORTRAIT_RADIUS_SHARE = 8 / 44
# The card's shadow: the mockup's soft drop shadow under a rounded card, reaching 14 units and dropping 3, from a
# shape rounded 6 units and blurred with a 3.5-unit Gaussian. The tighter shape and blur keep the corner's falloff
# inside the corner pieces, so the stretched edges stay even. As a CSS box shadow, it is never drawn under the card:
# the card's own 14-unit rounded shape is cut out, so translucent glass shows the world through it, not its shadow.
LUMEN_SHADOW_REACH, LUMEN_SHADOW_DROP, LUMEN_SHADOW_RADIUS, LUMEN_SHADOW_BLUR = 14, 3, 6, 3.5
SHEEN_REACH = 0.55  # the bar sheen fades from the top to nothing 55% of the way down, as the mockup's .bar i
# The Orbs HUD style's orb (KSTY-46), drawn from the KSTY-44 mock-up's CSS: the empty orb's dark glass lit from 34% down,
# a rim that darkens from 52% of the radius out, the four glints of its glass, and liquid shaded as a cylinder whose
# edges keep 55% of the centre's light. The game tints the glass, the liquid and its surface with SetVertexColor and
# SetStatusBarColor, so the back keeps the mock-up's light ratios (#2b1414, #150909 at 52%, #050202) with its centre white.
ORB_BACK_STOPS = ((0.0, 1.0), (0.52, 0.49), (1.0, 0.12))
ORB_BACK_LIGHT = 0.34
# The liquid's surface (KSTY-63): the mock-up's lit ellipse, as wide as the orb and 11% as tall, lit from 35% down its
# height, its top edge a white line at 55% and a soft shadow 2 units under it at 35%. OrbSurface holds the ellipse's
# light for the liquid's colour; OrbSurfaceLight holds the white line, the white sheen at its lit point and the shadow.
ORB_SURFACE_SIZE = (256, 64)
ORB_SURFACE_RY = 14
ORB_SURFACE_STOPS = ((0.0, 1.0), (0.38, 0.92), (0.78, 0.72), (1.0, 0.58))
ORB_SURFACE_LIT = 0.35
ORB_SURFACE_SHEEN = ((0.0, 0.45), (0.55, 0.0))
ORB_SURFACE_RIM = (0.86, 0.55)
ORB_SURFACE_SHADOW = (3, 7, 0.35)
ORB_RIM_STOPS = ((0.0, 0.0), (0.52, 0.0), (0.78, 0.55), (1.0, 0.9))
ORB_GLINTS = (
    (0.37, 0.15, 0.30, 0.15, ((0.0, 0.5), (0.6, 0.14), (1.0, 0.0))),
    (0.29, 0.24, 0.20, 0.20, ((0.0, 0.62), (0.35, 0.18), (1.0, 0.0))),
    (0.56, 0.90, 0.46, 0.22, ((0.0, 0.13), (1.0, 0.0))),
    (0.68, 0.82, 0.22, 0.22, ((0.0, 0.14), (1.0, 0.0))),
)
ORB_LIQUID_EDGE = 0.55
# The HUD style pictures (KSTY-46): the KSTY-44 mock-ups' colours, drawn as flat shapes so they read at any size.
HUD_PICTURE = {
    "back": (14, 18, 23, 1), "slot": (88, 94, 102, 1), "portrait": (60, 66, 74, 1), "glass": (8, 9, 10, 1),
    "health": (44, 105, 204, 1), "mana": (61, 61, 236, 1), "hostile": (197, 68, 62, 1),
    "orbHealth": (192, 48, 43, 1), "orbMana": (42, 100, 200, 1), "gilt": (211, 181, 116, 1),
}
# The glass darkens the orb's lower half, liquid and empty glass alike, so the fill reads as a lit sphere.
ORB_FOOT_STOPS = ((0.0, 0.0), (0.5, 0.0), (1.0, 0.38))
# The bevelled ring: the mockup's portrait ring is a thin metal line, a dark bronze outer edge, a bright middle and
# the accent inside (3 px on a 118 px disc at 1.348 px per unit), with the dark disc showing 2 px outside it. On the
# 128-texel texture the line runs from radius 57 to 62; the shading sits in the colour channels so one tint, the
# accent lifted toward white, gives all three tones. A portrait inside starts at radius 56: 8/128 of the size.
RING_BEVEL_BAND = (57, 62)
RING_BEVEL_LEVELS = (0.75, 1.0, 0.45)  # inner edge, the lit middle, outer edge
RING_BEVEL_INSET = (64 - 56) / 128
GLYPH_STROKE = 5  # texels: the stroke of the 32-texel glyphs, about 1.25 units at 8 units across


# Slice margins in texels. A nine-slice corner piece is margin x margin texels from each corner and
# draws at the corner radius in units, snapped to whole pixels. Between the margins every column and every
# row is the same, so stretching the edges and centre distorts nothing. A ring's corner pieces meet in the
# middle: the kit draws its straight runs as solid lines.
SLICE = {
    "LumenShape": LUMEN_RADIUS * TEXELS_PER_UNIT,
    "CardShape": LUMEN_RADIUS * TEXELS_PER_UNIT,
    "LumenOutline": LUMEN_TILE_RADIUS * TEXELS_PER_UNIT,
    **{f"RingLine{n}": RING_TEXELS // 2 for n in RING_LINES},
    "Shadow": 2 * SHADOW_REACH * SHADOW_TEXELS_PER_UNIT,
    "LumenShadow": 2 * LUMEN_SHADOW_REACH * SHADOW_TEXELS_PER_UNIT,
}

# The logo's colours, in sRGB. They match the design tokens surface, textEmphasis and the kit's
# hunter accent in docs/design/mockups/05_kit_hunter.jpg. The logo is a fixed asset: the game
# cannot tint the addon list icon.
LOGO_GLASS = (16, 16, 16, 0.94)
LOGO_EDGE = (235, 235, 235, 1.0)
LOGO_HAIRLINE = (255, 255, 255, 0.35)
LOGO_ACCENT = (170, 211, 114, 1.0)

NOISE_SEED = 1107  # the noise tile is the same on every run


# Encoding ----------------------------------------------------------------------------------------


def _chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def encode_png(width, height, pixels, filter_type=0):
    """Encode 8-bit RGBA bytes (row-major, top row first) as a PNG. Every row uses filter_type."""
    stride = 4 * width
    raw = bytearray()
    prev = bytes(stride)
    for y in range(height):
        row = pixels[y * stride : (y + 1) * stride]
        out = bytearray(stride)
        for i in range(stride):
            a = row[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            predictor = (0, a, b, (a + b) // 2, _paeth(a, b, c))[filter_type]
            out[i] = (row[i] - predictor) & 0xFF
        raw.append(filter_type)
        raw += out
        prev = row
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", header) + _chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + _chunk(b"IEND", b"")


def decode_png(data):
    """Decode an 8-bit RGBA, non-interlaced PNG to (width, height, pixels)."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, header = 8, b"", None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos : pos + 8])
        body = data[pos + 8 : pos + 8 + length]
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    width, height, depth, colour, _, _, interlace = header
    if (depth, colour, interlace) != (8, 6, 0):
        raise ValueError("expected an 8-bit RGBA PNG without interlacing")
    raw = zlib.decompress(idat)
    stride = 4 * width
    pixels = bytearray()
    prev = bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind = raw[start]
        row = bytearray(raw[start + 1 : start + 1 + stride])
        for i in range(stride):
            a = row[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            predictor = (0, a, b, (a + b) // 2, _paeth(a, b, c))[kind]
            row[i] = (row[i] + predictor) & 0xFF
        pixels += row
        prev = row
    return width, height, bytes(pixels)


def encode_tga(width, height, pixels):
    """Encode RGBA bytes as an uncompressed 32-bit TGA, bottom row first, as the format expects."""
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    stride = 4 * width
    body = bytearray()
    for y in range(height - 1, -1, -1):
        row = pixels[y * stride : (y + 1) * stride]
        for i in range(0, stride, 4):
            r, g, b, a = row[i : i + 4]
            body += bytes((b, g, r, a))
    return header + bytes(body)


def decode_tga(data):
    """Decode a TGA written by encode_tga to (width, height, pixels)."""
    width, height, depth, descriptor = struct.unpack("<HHBB", data[12:18])
    if data[2] != 2 or depth != 32 or descriptor != 8:
        raise ValueError("expected an uncompressed bottom-up 32-bit TGA")
    stride = 4 * width
    body = data[18:]
    pixels = bytearray()
    for y in range(height - 1, -1, -1):
        row = body[y * stride : (y + 1) * stride]
        for i in range(0, stride, 4):
            b, g, r, a = row[i : i + 4]
            pixels += bytes((r, g, b, a))
    return width, height, bytes(pixels)


# Sampling ----------------------------------------------------------------------------------------

_OFFSETS = [(i + 0.5) / SUPERSAMPLE for i in range(SUPERSAMPLE)]
_SAMPLES = SUPERSAMPLE * SUPERSAMPLE


def sample(width, height, fn):
    """Coverage in 0..1 for each pixel: the mean of fn(x, y) over the pixel's sample points."""
    out = []
    for py in range(height):
        for px in range(width):
            total = 0.0
            for oy in _OFFSETS:
                for ox in _OFFSETS:
                    total += fn(px + ox, py + oy)
            out.append(total / _SAMPLES)
    return out


def sample_spans(width, height, spans):
    """Coverage for a shape given as spans(y) -> [(left, right), ...] on each horizontal line.

    A sample point is inside when left <= x <= right. Counting runs through a difference array, so
    the cost is per row, not per sample.
    """
    out = []
    for py in range(height):
        diff = [0] * (width + 1)
        for oy in _OFFSETS:
            for left, right in spans(py + oy):
                for ox in _OFFSETS:
                    lo = max(0, math.ceil(left - ox))
                    hi = min(width - 1, math.floor(right - ox))
                    if lo <= hi:
                        diff[lo] += 1
                        diff[hi + 1] -= 1
        run = 0
        for px in range(width):
            run += diff[px]
            out.append(run / _SAMPLES)
    return out


def sample_columns(width, height, fn):
    """Coverage for fn(x) that does not depend on y."""
    row = [sum(fn(px + ox) for ox in _OFFSETS) / SUPERSAMPLE for px in range(width)]
    return row * height


def sample_rows(width, height, fn):
    """Coverage for fn(y) that does not depend on x."""
    out = []
    for py in range(height):
        out += [sum(fn(py + oy) for oy in _OFFSETS) / SUPERSAMPLE] * width
    return out


def byte(v):
    return max(0, min(255, int(v * 255 + 0.5)))


def white(coverage):
    """White RGBA with coverage in alpha."""
    out = bytearray()
    for v in coverage:
        out += bytes((255, 255, 255, byte(v)))
    return bytes(out)


def grey(levels):
    """Opaque RGBA with each level in the colour channels."""
    out = bytearray()
    for v in levels:
        g = byte(v)
        out += bytes((g, g, g, 255))
    return bytes(out)


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


# Shapes ------------------------------------------------------------------------------------------


def convex(points):
    """A convex polygon as half-planes (a, b, c): a*x + b*y + c >= 0 inside, (a, b) a unit normal.

    Insetting by d moves every edge inward by d: a*x + b*y + c >= d.
    """
    pairs = list(zip(points, points[1:] + points[:1]))
    area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in pairs)
    sign = 1 if area > 0 else -1
    planes = []
    for (x0, y0), (x1, y1) in pairs:
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy)
        a, b = -dy * sign / length, dx * sign / length
        planes.append((a, b, -(a * x0 + b * y0)))
    return planes


def interval(planes, y, inset=0.0):
    """The span (left, right) of a convex shape, inset by `inset`, on the line y, or None."""
    left, right = -math.inf, math.inf
    for a, b, c in planes:
        rest = b * y + c - inset
        if abs(a) < 1e-12:
            if rest < 0:
                return None
        elif a > 0:
            left = max(left, -rest / a)
        else:
            right = min(right, -rest / a)
    return (left, right) if left <= right else None


def shape_spans(planes, inset=0.0):
    def spans(y):
        span = interval(planes, y, inset)
        return [span] if span else []

    return spans


def band_spans(planes, outer, inner):
    """Spans of the band between the shape inset by `outer` and the shape inset by `inner`."""
    eps = 1e-9

    def spans(y):
        a = interval(planes, y, outer)
        if not a:
            return []
        b = interval(planes, y, inner)
        if not b:
            return [a]
        out = []
        if b[0] > a[0]:
            out.append((a[0], b[0] - eps))
        if b[1] < a[1]:
            out.append((b[1] + eps, a[1]))
        return out

    return spans


def chamfered_diamond(cx, cy, reach, cut):
    """A square turned 45 degrees with its four points cut off flat, `cut` short of each point."""
    near, far = cut, reach - cut
    return convex([
        (cx - near, cy - far), (cx + near, cy - far), (cx + far, cy - near), (cx + far, cy + near),
        (cx + near, cy + far), (cx - near, cy + far), (cx - far, cy + near), (cx - far, cy - near),
    ])


# Drawings ----------------------------------------------------------------------------------------


def draw_square(size):
    """A plain square that fills the texture: every texel opaque white."""
    return white([1.0] * (size * size))


def rounded_spans(x0, y0, x1, y1, radius):
    """Spans of a rectangle with each corner rounded to `radius`."""
    def spans(y):
        if y < y0 or y > y1:
            return []
        dy = max(0.0, y0 + radius - y, y - (y1 - radius))
        if dy > radius:
            return []
        dx = radius - math.sqrt(max(0.0, radius * radius - dy * dy))
        return [(x0 + dx, x1 - dx)]

    return spans


def ring_spans(outer, inner):
    """Spans inside `outer` and outside `inner`, each a spans(y) function of a convex shape."""
    eps = 1e-9

    def spans(y):
        a = outer(y)
        if not a:
            return []
        b = inner(y)
        if not b:
            return a
        (al, ar), (bl, br) = a[0], b[0]
        out = []
        if bl > al:
            out.append((al, bl - eps))
        if br < ar:
            out.append((br + eps, ar))
        return out

    return spans


def draw_rounded(size, radius):
    return white(sample_spans(size, size, rounded_spans(0, 0, size, size, radius)))


def draw_rim(size, radius, line=RIM_TEXELS):
    """An even line `line` texels wide just inside the rounded shape's edge."""
    outer = rounded_spans(0, 0, size, size, radius)
    inner = rounded_spans(line, line, size - line, size - line, radius - line)
    return white(sample_spans(size, size, ring_spans(outer, inner)))


def draw_ring_line(size, lines):
    """Four quarter rings, one per corner piece, each one line thick on the outside of a `lines`-line corner."""
    half = size / 2
    line = half / lines
    outer = rounded_spans(0, 0, size, size, half)
    inner = rounded_spans(line, line, size - line, size - line, half - line)
    return white(sample_spans(size, size, ring_spans(outer, inner)))


def draw_diamond(size):
    """A flat square turned 45 degrees whose four points touch the middle of the texture's edges."""
    c = size / 2

    def spans(y):
        dx = c - abs(y - c)
        return [(c - dx, c + dx)] if dx > 0 else []

    return white(sample_spans(size, size, spans))


def draw_cap_mask(size, side):
    """A mask that rounds one end of a bar fill: a half disc on `side` and solid on the other half."""
    c = size / 2

    def fn(x, y):
        if (side == "left" and x >= c) or (side == "right" and x <= c):
            return 1.0
        return 1.0 if math.hypot(x - c, y - c) <= c else 0.0

    return white(sample(size, size, fn))


def draw_sheen(width, height):
    """White fading from the top row to nothing SHEEN_REACH of the way down."""
    return white(sample_rows(width, height, lambda y: 1 - smoothstep(0, SHEEN_REACH, y / height)))


def draw_disc(size):
    """A filled disc that touches the texture's edges, for a round mask."""
    c = size / 2

    def spans(y):
        dy = abs(y - c)
        if dy > c:
            return []
        dx = math.sqrt(c * c - dy * dy)
        return [(c - dx, c + dx)]

    return white(sample_spans(size, size, spans))


def draw_rule(width, height):
    """A line that fades out from its left end to its right."""
    return white(sample_columns(width, height, lambda x: 1 - smoothstep(0, 1, x / width)))


def draw_shadow(size):
    # A box blurred by a Gaussian is the product of two 1-D blurred steps. The panel's edge sits in
    # the middle of each corner piece, SHADOW_REACH units in from the texture's edge.
    edge = SLICE["Shadow"] / 2
    sigma = SHADOW_REACH * SHADOW_TEXELS_PER_UNIT / 2.4
    lo, hi = edge, size - edge

    def profile(x):
        s = sigma * math.sqrt(2)
        return 0.5 * (math.erf((x - lo) / s) - math.erf((x - hi) / s))

    axis = [sum(profile(px + ox) for ox in _OFFSETS) / SUPERSAMPLE for px in range(size)]
    peak = max(axis)
    axis = [v / peak for v in axis]
    return white([axis[px] * axis[py] for py in range(size) for px in range(size)])


def gaussian_blur(values, size, sigma):
    """A separable Gaussian blur of a size x size grid, clamping at the edges."""
    reach = int(3 * sigma) + 1
    kernel = [math.exp(-(i * i) / (2 * sigma * sigma)) for i in range(-reach, reach + 1)]
    total = sum(kernel)
    kernel = [k / total for k in kernel]
    rows = []
    for y in range(size):
        row = values[y * size : (y + 1) * size]
        rows.append([sum(kernel[j] * row[min(size - 1, max(0, x + j - reach))] for j in range(len(kernel))) for x in range(size)])
    out = [0.0] * (size * size)
    for x in range(size):
        column = [rows[y][x] for y in range(size)]
        for y in range(size):
            out[y * size + x] = sum(kernel[j] * column[min(size - 1, max(0, y + j - reach))] for j in range(len(kernel)))
    return out


def draw_lumen_shadow(size):
    """A blurred rounded shape dropped LUMEN_SHADOW_DROP units, with the card itself cut out.

    The card's edges sit in the middle of each corner piece, LUMEN_SHADOW_REACH units in from the texture's edge.
    """
    per = SHADOW_TEXELS_PER_UNIT
    edge = SLICE["LumenShadow"] / 2
    radius, drop = LUMEN_RADIUS * per, LUMEN_SHADOW_DROP * per
    blob = LUMEN_SHADOW_RADIUS * per
    sigma = LUMEN_SHADOW_BLUR * per
    lo, hi = edge, size - edge
    dropped = sample_spans(size, size, rounded_spans(lo, lo + drop, hi, hi + drop, blob))
    blurred = gaussian_blur(dropped, size, sigma)
    peak = blurred[(size // 2) * size + size // 2]
    card = sample_spans(size, size, rounded_spans(lo, lo, hi, hi, radius))
    return white([min(1.0, v / peak) * (1 - c) for v, c in zip(blurred, card)])


def draw_glow(size):
    k = 5.0
    floor = math.exp(-k)
    centre = size / 2

    def fn(x, y):
        r = math.hypot(x - centre, y - centre) / centre
        if r >= 1:
            return 0.0
        return (math.exp(-k * r * r) - floor) / (1 - floor)

    return white(sample(size, size, fn))


def draw_divider(width, height):
    fade = 0.4
    return white(sample_columns(width, height, lambda x: smoothstep(0, fade, x / width) * smoothstep(0, fade, 1 - x / width)))


def draw_noise(size):
    rng = random.Random(NOISE_SEED)
    big = size * SUPERSAMPLE
    grid = [rng.random() for _ in range(big * big)]
    cells = []
    for py in range(size):
        for px in range(size):
            total = 0.0
            for oy in range(SUPERSAMPLE):
                base = (py * SUPERSAMPLE + oy) * big + px * SUPERSAMPLE
                total += sum(grid[base : base + SUPERSAMPLE])
            cells.append(total / _SAMPLES)
    # A light 3x3 blur that wraps at the edges, so the tile repeats without a seam.
    weights = ((-1, 1), (0, 2), (1, 1))
    soft = []
    for py in range(size):
        for px in range(size):
            total = 0.0
            for dy, wy in weights:
                row = ((py + dy) % size) * size
                for dx, wx in weights:
                    total += wy * wx * cells[row + (px + dx) % size]
            soft.append(total / 16)
    mean = sum(soft) / len(soft)
    spread = math.sqrt(sum((v - mean) ** 2 for v in soft) / len(soft))
    return white([max(0.0, min(1.0, 0.5 + (v - mean) / (5 * spread))) for v in soft])


def draw_ring(size, thickness):
    centre = size / 2
    outer = centre - 2
    inner = outer - thickness

    def fn(x, y):
        r = math.hypot(x - centre, y - centre)
        return 1.0 if inner <= r <= outer else 0.0

    return white(sample(size, size, fn))


def shaded(levels, coverage):
    """Grey RGBA: each level in the colour channels, each coverage in alpha."""
    out = bytearray()
    for v, a in zip(levels, coverage):
        g = byte(v)
        out += bytes((g, g, g, byte(a)))
    return bytes(out)


def draw_ring_bevel(size):
    centre = size / 2
    scale = size / 128
    inner, outer = RING_BEVEL_BAND[0] * scale, RING_BEVEL_BAND[1] * scale
    lo, peak, hi = RING_BEVEL_LEVELS

    def level(x, y):
        r = max(inner, min(outer, math.hypot(x - centre, y - centre)))
        t = (r - inner) / (outer - inner)
        if t < 0.5:
            return lo + (peak - lo) * (t / 0.5)
        return peak + (hi - peak) * ((t - 0.5) / 0.5)

    def inside(x, y):
        return 1.0 if inner <= math.hypot(x - centre, y - centre) <= outer else 0.0

    return shaded(sample(size, size, level), sample(size, size, inside))


def draw_dot(size):
    centre = size / 2
    radius = centre - 1

    def fn(x, y):
        return 1.0 if math.hypot(x - centre, y - centre) <= radius else 0.0

    return white(sample(size, size, fn))


def draw_pill(width, height):
    """A capsule: two half discs joined by a band. Every column between the caps is the same."""
    radius = height / 2 - 1
    cy = height / 2
    left, right = PILL_CAP, width - PILL_CAP

    def fn(x, y):
        cx = min(max(x, left), right)
        return 1.0 if math.hypot(x - cx, y - cy) <= radius else 0.0

    return white(sample(width, height, fn))


def _segment_distance(x, y, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy)))
    return math.hypot(x - (x0 + t * dx), y - (y0 + t * dy))


def draw_strokes(size, segments, stroke):
    """Round-ended strokes along each segment ((x0, y0), (x1, y1)), in texels."""
    half = stroke / 2

    def fn(x, y):
        for (x0, y0), (x1, y1) in segments:
            if _segment_distance(x, y, x0, y0, x1, y1) <= half:
                return 1.0
        return 0.0

    return white(sample(size, size, fn))


def disc_spans(centre, radius):
    def spans(y):
        dy = y - centre
        if abs(dy) > radius:
            return []
        half = math.sqrt(radius * radius - dy * dy)
        return [(centre - half, centre + half)]

    return spans


def at_centres(width, height, fn):
    """fn(u, v) at each pixel's centre, u and v from 0 to 1: for gradients too smooth to need supersampling."""
    return [fn((px + 0.5) / width, (py + 0.5) / height) for py in range(height) for px in range(width)]


def ramp(stops, t):
    """Linear interpolation through (position, value) stops."""
    if t <= stops[0][0]:
        return stops[0][1]
    for (t0, v0), (t1, v1) in zip(stops, stops[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
    return stops[-1][1]


def draw_orb_mask(size):
    return white(sample_spans(size, size, disc_spans(size / 2, size / 2 - 1)))


def draw_orb_back(size):
    coverage = sample_spans(size, size, disc_spans(size / 2, size / 2 - 1))
    reach = math.hypot(0.5, 1 - ORB_BACK_LIGHT)

    def level(u, v):
        return ramp(ORB_BACK_STOPS, math.hypot(u - 0.5, v - ORB_BACK_LIGHT) / reach)

    return shaded(at_centres(size, size, level), coverage)


def draw_orb_glass(size):
    disc = sample_spans(size, size, disc_spans(size / 2, size / 2 - 1))

    def spot(cx, cy, rx, ry, stops):
        return [c * ramp(stops, math.hypot((u - cx) / rx, (v - cy) / ry)) for c, (u, v) in zip(disc, (
            ((px + 0.5) / size, (py + 0.5) / size) for py in range(size) for px in range(size)))]

    foot = [c * ramp(ORB_FOOT_STOPS, (py + 0.5) / size) for c, py in zip(disc, (py for py in range(size) for _ in range(size)))]
    layers = [((0, 0, 0, 1), foot), ((0, 0, 0, 1), spot(0.5, 0.5, 0.5, 0.5, ORB_RIM_STOPS))]
    for cx, cy, rx, ry, stops in ORB_GLINTS:
        layers.append(((255, 255, 255, 1), spot(cx, cy, rx, ry, stops)))
    return composite(size, size, layers)


def draw_orb_liquid(width, height):
    def level(x):
        t = (x / width - 0.5) * 2
        return ORB_LIQUID_EDGE + (1 - ORB_LIQUID_EDGE) * math.sqrt(max(0.0, 1 - t * t))

    return grey(sample_columns(width, height, level))


def ellipse_spans(cx, cy, rx, ry):
    def spans(y):
        t = (y - cy) / ry
        if abs(t) > 1:
            return []
        half = rx * math.sqrt(1 - t * t)
        return [(cx - half, cx + half)]

    return spans


def orb_surface_shape(width, height):
    """The surface ellipse's coverage and its normalised radius at each pixel centre, lit point and all."""
    cx, cy, rx, ry = width / 2, height / 2, width / 2 - 1, ORB_SURFACE_RY
    coverage = sample_spans(width, height, ellipse_spans(cx, cy, rx, ry))
    lit = cy - ry + 2 * ry * ORB_SURFACE_LIT
    radius, from_lit, shadow = [], [], []
    drop, blur, _ = ORB_SURFACE_SHADOW
    for py in range(height):
        for px in range(width):
            x, y = px + 0.5, py + 0.5
            radius.append(math.hypot((x - cx) / rx, (y - cy) / ry))
            from_lit.append(math.hypot((x - cx) / rx, (y - lit) / ry))
            below = math.hypot((x - cx) / rx, (y - cy - drop) / ry)
            shadow.append(1 - smoothstep(1 - blur / ry / 2, 1 + blur / ry, below))
    return coverage, radius, from_lit, shadow


def draw_orb_surface(width, height):
    coverage, _, from_lit, _ = orb_surface_shape(width, height)
    return shaded([ramp(ORB_SURFACE_STOPS, min(1.0, t)) for t in from_lit], coverage)


def draw_orb_surface_light(width, height):
    coverage, radius, from_lit, shadow = orb_surface_shape(width, height)
    cy, ry = height / 2, ORB_SURFACE_RY
    band, rim = ORB_SURFACE_RIM
    tops = [max(0.0, min(1.0, (cy - (py + 0.5)) / ry)) for py in range(height) for _ in range(width)]
    shade = [s * ORB_SURFACE_SHADOW[2] * (1 - c) for s, c in zip(shadow, coverage)]
    sheen = [c * ramp(ORB_SURFACE_SHEEN, t) for c, t in zip(coverage, from_lit)]
    line = [c * rim * smoothstep(band, 1.0, r) * math.sqrt(top) for c, r, top in zip(coverage, radius, tops)]
    return composite(width, height, [((0, 0, 0, 1), shade), ((255, 255, 255, 1), sheen), ((255, 255, 255, 1), line)])


def circle_spans(cx, cy, radius):
    def spans(y):
        dy = y - cy
        if abs(dy) > radius:
            return []
        half = math.sqrt(radius * radius - dy * dy)
        return [(cx - half, cx + half)]

    return spans


def rect_spans(x0, y0, x1, y1):
    def spans(y):
        return [(x0, x1)] if y0 <= y <= y1 else []

    return spans


def ring_band_spans(cx, cy, outer, inner):
    def spans(y):
        dy = y - cy
        if abs(dy) > outer:
            return []
        o = math.sqrt(outer * outer - dy * dy)
        if abs(dy) >= inner:
            return [(cx - o, cx + o)]
        i = math.sqrt(inner * inner - dy * dy)
        return [(cx - o, cx - i), (cx + i, cx + o)]

    return spans


def liquid_spans(cx, cy, radius, share):
    disc = circle_spans(cx, cy, radius)
    level = cy + radius - 2 * radius * share

    def spans(y):
        return disc(y) if y >= level else []

    return spans


def draw_hud_style(kind):
    """The settings window's and the setup's picture of a HUD style: the action bars, and the player as frames or orbs."""
    width, height = 256, 128
    cover = lambda spans: sample_spans(width, height, spans)
    layers = [(HUD_PICTURE["back"], sample_spans(width, height, rounded_spans(0, 0, width, height, 10)))]
    size, pitch = 9, 11
    left = (width - (12 * pitch - 2)) / 2
    for top in (92, 104):
        for i in range(12):
            x = left + i * pitch
            layers.append((HUD_PICTURE["slot"], cover(rect_spans(x, top, x + size, top + size))))
    if kind == "frames":
        layers += [
            (HUD_PICTURE["hostile"], cover(rect_spans(70, 42, 168, 48))),
            (HUD_PICTURE["portrait"], cover(circle_spans(181, 45, 9))),
            (HUD_PICTURE["portrait"], cover(circle_spans(75, 74, 9))),
            (HUD_PICTURE["health"], cover(rect_spans(88, 70, 186, 76))),
            (HUD_PICTURE["mana"], cover(rect_spans(88, 79, 186, 82))),
        ]
    else:
        layers.append((HUD_PICTURE["hostile"], cover(rect_spans(78, 12, 178, 18))))
        for cx, colour, share in ((38, "orbHealth", 0.62), (218, "orbMana", 0.55)):
            layers += [
                (HUD_PICTURE["glass"], cover(circle_spans(cx, 96, 21))),
                (HUD_PICTURE[colour], cover(liquid_spans(cx, 96, 21, share))),
                (HUD_PICTURE["gilt"], cover(ring_band_spans(cx, 96, 25, 21))),
            ]
    return composite(width, height, layers)


def draw_bar(width, height, kind):
    def flat(v):
        return 1.0

    def soft(v):
        return 1.0 - 0.3 * v

    def glass(v):
        return 1.0 - GLASS_DROP * v

    level = {"flat": flat, "soft": soft, "glass": glass}[kind]
    return grey(sample_rows(width, height, lambda y: level(y / height)))


def draw_full(width, height):
    return white([1.0] * (width * height))


def composite(width, height, layers):
    """Paint (colour, coverage) layers bottom to top with the over operator; return RGBA bytes."""
    out = bytearray()
    for i in range(width * height):
        r = g = b = a = 0.0  # premultiplied
        for (lr, lg, lb, la), coverage in layers:
            sa = la * coverage[i]
            r = lr / 255 * sa + r * (1 - sa)
            g = lg / 255 * sa + g * (1 - sa)
            b = lb / 255 * sa + b * (1 - sa)
            a = sa + a * (1 - sa)
        if a > 0:
            out += bytes((byte(r / a), byte(g / a), byte(b / a), byte(a)))
        else:
            out += bytes(4)
    return bytes(out)


def draw_logo(size):
    """The chamfered diamond: dark glass inside a bright edge and a faint inner hairline, with an
    accent diamond at the centre."""
    c = size / 2
    outer = chamfered_diamond(c, c, 0.47 * size, 0.06 * size)
    edge, gap, hair = 0.045 * size, 0.035 * size, 0.022 * size
    core = chamfered_diamond(c, c, 0.22 * size, 0.03 * size)
    return composite(size, size, [
        (LOGO_GLASS, sample_spans(size, size, shape_spans(outer))),
        (LOGO_EDGE, sample_spans(size, size, band_spans(outer, 0, edge))),
        (LOGO_HAIRLINE, sample_spans(size, size, band_spans(outer, edge + gap, edge + gap + hair))),
        (LOGO_ACCENT, sample_spans(size, size, shape_spans(core))),
    ])


# Assets ------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class Asset:
    path: str  # from the repository root
    width: int
    height: int
    draw: Callable[[], bytes]
    about: str
    settings: str = "4x4 supersampled"
    slice: Optional[int] = None
    drawn: str = DRAWN
    maker: str = "`Tools/media/make_media.py`, procedural, no model"

    @property
    def name(self):
        return Path(self.path).stem


def _texture(name, width, height, draw, about, settings="4x4 supersampled"):
    drawn = CAPTION_DRAWN if name in CAPTION_ASSETS else PICTURE_DRAWN if name in PICTURE_ASSETS else LUMEN_DRAWN if name in LUMEN_ASSETS else DRAWN
    return Asset(f"Media/Textures/{name}.png", width, height, draw, about, settings, SLICE.get(name), drawn)


LUMEN_ASSETS = {
    "LumenShape", "LumenOutline", "PillCapLeft", "PillCapRight", "BarSheen", "LensMask", "RuleFade",
    "LumenShadow", "PortraitMask", "MinimapMask",
}
PICTURE_ASSETS = {"CardShape", "SocketMask", *(f"RingLine{n}" for n in RING_LINES)}
PICTURE_DRAWN = "2026-11-09"
CAPTION_ASSETS = {"Diamond"}
CAPTION_DRAWN = "2026-11-10"


ASSETS = [
    _texture("LumenShape", 128, 128, lambda: draw_rounded(128, SLICE["LumenShape"]),
             "Lumen card shape: a square with 14-unit round corners at 4 texels per unit. Nine-slice fill for the deep tint, the socket body and the dispel tint, or a mask."),
    _texture("CardShape", 128, 128, lambda: draw_rounded(128, SLICE["CardShape"]),
             "The card's fill: the rounded shape, a file of its own so a render tells a card's fill from a socket's. The kit draws its corner pieces five border lines square, one line inside the card's six-line edge, the picture's corner. Nine-slice."),
    _texture("LumenOutline", 128, 128, lambda: draw_rim(128, SLICE["LumenOutline"]),
             "Even outline for 8-unit corners: a 0.75-unit line at one strength all round, for bar tracks and highlight rings such as the group frames' target ring. Nine-slice."),
    *(_texture(f"RingLine{n}", RING_TEXELS, RING_TEXELS, lambda n=n: draw_ring_line(RING_TEXELS, n),
               f"A quarter ring in each corner piece, one line thick on the outside of a corner {n} lines round: a card's dark edge (6), its rim and the arcs of its gilt L-ticks (5), a socket's dark edge (3) and its rim (2); the other counts serve short frames and pinned corners such as discs, so the kit draws the ring nearest the corner's line count. The kit draws each corner piece {n} border lines square, so the arc is one border line thick and meets the straight runs on whole pixels. Nine-slice; the runs are solid lines.")
      for n in RING_LINES),
    _texture("Diamond", 64, 64, lambda: draw_diamond(64),
             "The picture's caption bullet: a flat square turned 45 degrees, its points on the middle of the edges, with no facets and no halo. Tinted gilt at 8 units point to point (14 pixels on the owner's screen)."),
    _texture("PillCapLeft", 32, 32, lambda: draw_cap_mask(32, "left"),
             "Mask that rounds a bar fill's left end: a half disc on the left, solid on the right. Placed over the fill's first square with CLAMPTOWHITE, so the rest of the fill shows."),
    _texture("PillCapRight", 32, 32, lambda: draw_cap_mask(32, "right"),
             "Mask that rounds a bar fill's moving right end: PillCapLeft mirrored, anchored to the fill's edge."),
    _texture("BarSheen", 8, 32, lambda: draw_sheen(8, 32),
             "The bar fill's top sheen: white from the top row fading to nothing 55% of the way down, the mockup's .bar i highlight. Tinted white at 35% over the fill.",
             "4x supersampled gradient"),
    _texture("LensMask", 512, 512, lambda: draw_disc(512),
             "Round mask for the minimap lens: a disc touching the texture's edges."),
    _texture("SocketMask", 128, 128, lambda: draw_rounded(128, 128 * ICON_RADIUS_SHARE),
             "Icon mask for sockets and every square icon: corners rounded 3 units on a 44-unit icon (7% of the side), to meet the socket's inner corner."),
    _texture("PortraitMask", 128, 128, lambda: draw_rounded(128, 128 * PORTRAIT_RADIUS_SHARE),
             "Mask for the square portrait: corners rounded 8 units on a 44-unit image (18% of the side), inside the portrait frame's own rounder corner."),
    _texture("RuleFade", 256, 4, lambda: draw_rule(256, 4),
             "Section cap rule: a line that fades from full at its left end to nothing at its right.",
             "smoothstep fade, 4x supersampled"),
    _texture("Shadow", 128, 128, lambda: draw_shadow(128),
             "Nine-slice shadow falloff. Corner pieces are 12 units, centred on the panel's corners; the shadow reaches 6 units out.",
             "analytic Gaussian blur of a box, 4x supersampled"),
    _texture("LumenShadow", 128, 128, lambda: draw_lumen_shadow(128),
             "The Lumen card's drop shadow: a shape rounded 6 units, dropped 3 units and blurred to reach 14, with the card's own 14-unit rounded shape cut out, as a CSS box shadow, so it never darkens the glass above it. Corner pieces are 28 units, centred on the card's corners.",
             "separable Gaussian blur (sigma 3.5 units) of the 4x4 supersampled shape at 2 texels per unit"),
    _texture("Glow", 128, 128, lambda: draw_glow(128), "Soft radial glow for procs, hover and selection.",
             "Gaussian falloff to zero at the edge, 4x4 supersampled"),
    _texture("Divider", 256, 4, lambda: draw_divider(256, 4), "Divider line that fades out over 40% of its length at each end.",
             "smoothstep fades, 4x supersampled"),
    _texture("Noise", 128, 128, lambda: draw_noise(128), "Tileable grain for the smoked-glass surface, used at low alpha.",
             f"seeded random field (seed {NOISE_SEED}), 4x4 box-downsampled, 3x3 wrap blur"),
    _texture("Ring", 128, 128, lambda: draw_ring(128, 8), "Thin ring, 8 texels wide, for round indicators and pings."),
    _texture("RingBevel", 128, 128, lambda: draw_ring_bevel(128),
             "Bevelled ring for portraits and round badges: a 5-texel line from radius 57 to 62, shaded dark outside, lit in the middle and three quarters inside, so one tint reads as the mockup's thin metal ring. The disc under it shows for 2 texels outside; a portrait inside starts at radius 56.",
             "4x4 supersampled, shading in the colour channels"),
    _texture("BarFlat", 256, 32, lambda: draw_bar(256, 32, "flat"), "Flat status bar fill.", "solid"),
    _texture("BarSoft", 256, 32, lambda: draw_bar(256, 32, "soft"), "Status bar fill with a soft top-to-bottom gradient.",
             "4x supersampled gradient"),
    _texture("BarGlass", 256, 32, lambda: draw_bar(256, 32, "glass"),
             "Status bar fill whose top is 12% brighter than its bottom, the design's near-flat health fill.",
             "4x supersampled gradient"),
    _texture("MinimapMask", 64, 64, lambda: draw_square(64),
             "Plain square mask for Minimap:SetMaskTexture: opaque white to every edge, so the map keeps square corners, as the owner's picture draws it (LEE-20: the picture wins over #207's chamfer).",
             "solid"),
    _texture("Dot", 64, 64, lambda: draw_dot(64), "Filled disc for toggle and slider knobs."),
    _texture("Pill", 64, 32, lambda: draw_pill(64, 32),
             f"Capsule for toggle and slider tracks. Each round cap is {PILL_CAP} texels wide, so a widget three-slices it."),
    _texture("GlyphChevron", 32, 32, lambda: draw_strokes(32, (((8, 12), (16, 20)), ((16, 20), (24, 12))), GLYPH_STROKE),
             "Downward chevron for dropdowns and scroll steppers. Flip the texture coordinates to point it up."),
    _texture("GlyphClose", 32, 32, lambda: draw_strokes(32, (((9, 9), (23, 23)), ((23, 9), (9, 23))), GLYPH_STROKE),
             "Cross for close buttons."),
    Asset("Media/Logo/Logo64.png", 64, 64, lambda: draw_logo(64), "KstyleUI logo, the chamfered diamond, at 64 px."),
    Asset("Media/Logo/Logo64.tga", 64, 64, lambda: draw_logo(64),
          "Logo64 as a TGA for the TOC IconTexture line, which names the file without an extension."),
    Asset("Media/Logo/Logo256.png", 256, 256, lambda: draw_logo(256), "KstyleUI logo, the chamfered diamond, at 256 px."),
]


def material_pixels(name, width=256, height=256):
    actual_width, actual_height, pixels = decode_png((ROOT / "Tools" / "media" / "materials" / f"{name}.png").read_bytes())
    if (actual_width, actual_height) != (width, height):
        raise ValueError(f"{name}: expected a prepared {width}x{height} RGBA source")
    return pixels


for material_name in ("Slate", "Forged"):
    ASSETS.append(Asset(
        f"Media/Textures/Material{material_name}.png", 256, 256,
        lambda name=material_name: material_pixels(name),
        f"Prepared {material_name.lower()} grain for the optional card-material study.",
        "Prepared source in Tools/media/materials; lighting removed, 16px seam repair; prompt below",
        drawn="2026-11-10", maker="Higgsfield `gpt_image_2_6`; source-backed export by `Tools/media/make_media.py`",
    ))

for art_name, width, height, margin in (
    ("ForgedFrame1", 32, 32, 8), ("ForgedFrame2", 64, 64, 16),
	("ForgedFrame3", 128, 128, 24),
    ("ForgedBracket1", 8, 8, None), ("ForgedBracket2", 16, 16, None),
	("ForgedBracket3", 32, 32, None),
    ("ForgedDiamond", 64, 64, None), ("ForgedRule", 256, 4, None),
):
    ASSETS.append(Asset(
        f"Media/Textures/{art_name}.png", width, height,
        lambda name=art_name, w=width, h=height: material_pixels(name, w, h),
        "Original pixel-aligned forged-frame or header finish for the forged-material study.",
        "Prepared source in Tools/media/materials; source palette and pixel construction recorded below",
        slice=margin, drawn="2026-11-10", maker="Python/Pillow construction using original Higgsfield reference palettes",
    ))


ORB_DRAWN = "2026-11-12"
ORB_REDRAWN = {"OrbBack": "2026-11-13", "OrbSurface": "2026-11-13", "OrbSurfaceLight": "2026-11-13"}
for orb_name, width, height, draw, about in (
    ("OrbMask", 256, 256, lambda: draw_orb_mask(256), "Round mask for the Orbs HUD style's liquid: opaque white inside the orb's opening."),
    ("OrbBack", 128, 128, lambda: draw_orb_back(128), "The empty orb: glass lit from 34% down, white at its lit point, so SetVertexColor gives each orb its own dark tint under the liquid."),
    ("OrbGlass", 128, 128, lambda: draw_orb_glass(128), "The orb's glass over the liquid: a rim that darkens towards the ring and four glints."),
    ("OrbLiquid", 64, 64, lambda: draw_orb_liquid(64, 64), "Liquid fill for an orb's vertical status bar, shaded as a cylinder; SetStatusBarColor tints it."),
    ("OrbSurface", *ORB_SURFACE_SIZE, lambda: draw_orb_surface(*ORB_SURFACE_SIZE), "The liquid's curved surface: an ellipse as wide as the orb and 11% as tall, lit from 35% down, centred on the fill's top edge and tinted with the liquid's colour; also the pale cap of the loss band."),
    ("OrbSurfaceLight", *ORB_SURFACE_SIZE, lambda: draw_orb_surface_light(*ORB_SURFACE_SIZE), "The light over the surface ellipse: a white line along its top edge, a white sheen at its lit point and a soft shadow under it, drawn untinted."),
    ("HudStyleFrames", 256, 128, lambda: draw_hud_style("frames"), "The Frames HUD style's picture for the settings window and the setup: the bars and the player and target frames."),
    ("HudStyleOrbs", 256, 128, lambda: draw_hud_style("orbs"), "The Orbs HUD style's picture for the settings window and the setup: the bars between the two orbs and the target bar on top."),
):
    ASSETS.append(Asset(f"Media/Textures/{orb_name}.png", width, height, draw, about, "centre sampled, disc edges 4x4 supersampled", drawn=ORB_REDRAWN.get(orb_name, ORB_DRAWN)))

for orb_name, width, height, about in (
    ("OrbRing", 512, 512, "Forged ring around an orb, with its four spikes; its opening is 70.1% of the texture."),
):
    ASSETS.append(Asset(
        f"Media/Textures/{orb_name}.png", width, height,
        lambda name=orb_name, w=width, h=height: material_pixels(name, w, h),
        about,
        "Prepared source in Tools/media/materials by Tools/media/orbs.py (centred on its opening, premultiplied Lanczos resample, light unsharp mask); prompt below",
        drawn=ORB_DRAWN, maker="Higgsfield (KSTY-44 job 5a7af16a, the ring); production pass by `Tools/media/orbs.py`",
    ))

for orb_name, width, height, about in (
    ("OrbArm", 128, 256, "The Orbs tray's arm: the forged bracket that joins an orb's ring to the tray, the tray hole's left edge at 47.2% across."),
    ("OrbCrest", 256, 128, "The Orbs tray's centre crest over the top rail, between the two halves of action bar 2."),
    ("OrbRail", 1024, 64, "The Orbs tray's top rail, one strip with cross-faded seams, stretched between the arms."),
    ("OrbRailBottom", 1024, 64, "The Orbs tray's bottom rail, one strip with cross-faded seams, stretched between the arms."),
):
    ASSETS.append(Asset(
        f"Media/Textures/{orb_name}.png", width, height,
        lambda name=orb_name, w=width, h=height: material_pixels(name, w, h),
        about,
        "Prepared source in Tools/media/materials by Tools/media/orbs.py (cut from the base, rails joined from three segments, the last mirrored, with 40 px cross-fades, premultiplied Lanczos resample, light unsharp mask); prompt below",
        drawn="2026-11-13", maker="Higgsfield (KSTY-44 job 0b133988-204e-4852-89b6-a73ce6714226, the base); production pass by `Tools/media/orbs.py`",
    ))


def provenance_table():
    lines = [
        "| File | Size | What it is | Made with | Settings | Date |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for asset in ASSETS:
        slice_note = f"; slice margins {asset.slice} texels" if asset.slice else ""
        lines.append(
            f"| `{asset.path}` | {asset.width}x{asset.height} | {asset.about} | "
            f"{asset.maker} | {asset.settings}{slice_note} | {asset.drawn} |"
        )
    return "\n".join(lines)


BEGIN, END = "<!-- BEGIN make_media -->", "<!-- END make_media -->"


def write_provenance(root):
    path = root / "Media" / "PROVENANCE.md"
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    start, stop = text.find(BEGIN), text.find(END)
    if start < 0 or stop < start:
        raise SystemExit(f"{path} has no {BEGIN} ... {END} block")
    path.write_text(text[: start + len(BEGIN)] + "\n" + provenance_table() + "\n" + text[stop:], encoding="utf-8")


def encode(asset, pixels):
    if asset.path.endswith(".tga"):
        return encode_tga(asset.width, asset.height, pixels)
    return encode_png(asset.width, asset.height, pixels)


def decode(path):
    data = path.read_bytes()
    return decode_tga(data) if path.suffix == ".tga" else decode_png(data)


def selected(only):
    return [a for a in ASSETS if not only or a.name in only]


def check(root, only=None):
    """Return a message for each asset whose file is missing or differs from what the script draws."""
    problems = []
    for asset in selected(only):
        path = root / asset.path
        if not path.exists():
            problems.append(f"missing: {asset.path}")
            continue
        try:
            width, height, pixels = decode(path)
        except ValueError as err:
            problems.append(f"unreadable: {asset.path}: {err}")
            continue
        if (width, height) != (asset.width, asset.height):
            problems.append(f"size: {asset.path} is {width}x{height}, expected {asset.width}x{asset.height}")
            continue
        drawn = asset.draw()
        worst = max(abs(a - b) for a, b in zip(pixels, drawn))
        if worst > 1:
            problems.append(f"differs: {asset.path} (largest channel difference {worst})")
    return problems


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=ROOT, help="folder that holds Media/ (default: the repository root)")
    parser.add_argument("--only", nargs="+", metavar="NAME", help="draw only these assets, by file stem")
    parser.add_argument("--check", action="store_true", help="compare with the files on disk instead of writing")
    args = parser.parse_args(argv)
    only = set(args.only or [])
    unknown = only - {a.name for a in ASSETS}
    if unknown:
        parser.error("unknown asset: " + ", ".join(sorted(unknown)))
    if args.check:
        problems = check(args.root, only)
        for problem in problems:
            print(problem)
        return 1 if problems else 0
    for asset in selected(only):
        path = args.root / asset.path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(encode(asset, asset.draw()))
        print(f"wrote {asset.path}")
    if not only:
        write_provenance(args.root)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
