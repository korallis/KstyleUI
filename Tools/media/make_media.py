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
# Lumen glass, from the mockup's .lg rule (~/.local/share/kstyleui-handoff/arena2/parent/index.html), drawn on a
# 1080-unit board, so one CSS pixel is one root unit. Cards, rails and windows round their corners 14 units; sockets
# and small tiles 8. The rim is the mockup's 1 px edge, 0.75 units here (3 texels), so it reads as one pixel on the
# owner's 1.426 px-per-unit screen; it is full strength along the top and at the rim-soft share (18 of 55) on the
# sides and bottom, easing between them around the top corners.
LUMEN_RADIUS, LUMEN_TILE_RADIUS = 14, 8
RIM_TEXELS = 3
RIM_SOFT = 0.18 / 0.55
# The frost: the mockup's gradient from glass-hi (22%) at the top through glass (13%) at 40% to 10% at the bottom,
# as a share of the top, in the three bands a nine-slice stretches: the top corner rows, the stretched middle and
# the bottom corner rows.
FROST_STOPS = (1.0, 0.75, 0.5, 0.45)
# The gilt filament: the mockup's 18-unit L of a 1.5-unit gold line rounded 14 units, set 1 unit outside the card's
# corner. The texture covers 20 units from that outside corner at 6.4 texels per unit; the legs fade over their
# last 3 units so the filament ends in a tip.
GILT_UNITS, GILT_SIZE, GILT_ARM, GILT_LINE, GILT_FADE = 20, 128, 18, 1.5, 3
# The gem: the mockup's 7-unit square turned 45 degrees, its four facets lit from the top left, in a 6-unit halo.
GEM_UNITS, GEM_SIZE, GEM_SIDE, GEM_HALO = 16, 64, 7, 6
GEM_FACETS = (1.0, 0.78, 0.62, 0.45)  # top-left, top-right, bottom-left, bottom-right facet levels
GEM_HALO_ALPHA = 0.5
# The icon in a socket: the mockup's 44-unit icon rounded 8 units, as a share of the side (masks stretch).
ICON_RADIUS_SHARE = 8 / 44
# The card's shadow: the mockup's soft drop shadow under a rounded card, reaching 14 units and dropping 3, from a
# shape rounded 6 units and blurred with a 3.5-unit Gaussian. The tighter shape and blur keep the corner's falloff
# inside the corner pieces, so the stretched edges stay even. As a CSS box shadow, it is never drawn under the card:
# the card's own 14-unit rounded shape is cut out, so translucent glass shows the world through it, not its shadow.
LUMEN_SHADOW_REACH, LUMEN_SHADOW_DROP, LUMEN_SHADOW_RADIUS, LUMEN_SHADOW_BLUR = 14, 3, 6, 3.5
SHEEN_REACH = 0.55  # the bar sheen fades from the top to nothing 55% of the way down, as the mockup's .bar i
# The minimap's mask. The map fills KstyleUI_Minimap's frame to just inside its bevel line: on the mockup's 221-unit
# frame with its 12-unit chamfer the map sits 2 units in (the dark line, the light line and the fade row), so the
# mask cuts 8 of the map's 217 units. The game stretches the mask over the map, so the cut is a share of the side;
# Format.lua in the module places the map from the same three numbers and lets the frame's chamfer grow with it, so
# the mask's cut meets the frame's cut at every size. 512 texels keep the diagonal crisp on a 300-pixel map.
MINIMAP_FRAME, MINIMAP_CHAMFER, MINIMAP_INSET = 221, 12, 2
MINIMAP_MASK_SHARE = (MINIMAP_CHAMFER - 2 * MINIMAP_INSET) / (MINIMAP_FRAME - 2 * MINIMAP_INSET)
# The bevelled ring: the mockup's portrait ring is a thin metal line, a dark bronze outer edge, a bright middle and
# the accent inside (3 px on a 118 px disc at 1.348 px per unit), with the dark disc showing 2 px outside it. On the
# 128-texel texture the line runs from radius 57 to 62; the shading sits in the colour channels so one tint, the
# accent lifted toward white, gives all three tones. A portrait inside starts at radius 56: 8/128 of the size.
RING_BEVEL_BAND = (57, 62)
RING_BEVEL_LEVELS = (0.75, 1.0, 0.45)  # inner edge, the lit middle, outer edge
RING_BEVEL_INSET = (64 - 56) / 128
GLYPH_STROKE = 5  # texels: the stroke of the 32-texel glyphs, about 1.25 units at 8 units across


# Slice margins in texels. A nine-slice corner piece is margin x margin texels from each corner and
# draws at the corner radius in units, snapped to whole pixels. Between the margins every column is the
# same, and so is every row except in LumenFrost, whose rows hold its vertical gradient, so stretching the
# edges and centre distorts nothing.
SLICE = {
    "LumenShape": LUMEN_RADIUS * TEXELS_PER_UNIT,
    "LumenFrost": LUMEN_RADIUS * TEXELS_PER_UNIT,
    "LumenRim": LUMEN_RADIUS * TEXELS_PER_UNIT,
    "LumenRimSmall": LUMEN_TILE_RADIUS * TEXELS_PER_UNIT,
    "LumenOutline": LUMEN_TILE_RADIUS * TEXELS_PER_UNIT,
    "Shadow": 2 * SHADOW_REACH * SHADOW_TEXELS_PER_UNIT,
    "LumenShadow": 2 * LUMEN_SHADOW_REACH * SHADOW_TEXELS_PER_UNIT,
}
VERTICAL_GRADIENT = {"LumenFrost"}

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


def chamfered_rect(width, height, legs):
    return convex([
        (legs, 0), (width - legs, 0), (width, legs), (width, height - legs),
        (width - legs, height), (legs, height), (0, height - legs), (0, legs),
    ])


def chamfered_diamond(cx, cy, reach, cut):
    """A square turned 45 degrees with its four points cut off flat, `cut` short of each point."""
    near, far = cut, reach - cut
    return convex([
        (cx - near, cy - far), (cx + near, cy - far), (cx + far, cy - near), (cx + far, cy + near),
        (cx + near, cy + far), (cx - near, cy + far), (cx - far, cy + near), (cx - far, cy - near),
    ])


# Drawings ----------------------------------------------------------------------------------------


def draw_chamfer(size, legs):
    return white(sample_spans(size, size, shape_spans(chamfered_rect(size, size, legs))))


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


def frost_level(y, size, margin):
    """The frost's alpha share on row y: falling through the top corner rows, the middle and the bottom rows."""
    top, upper, lower, bottom = FROST_STOPS
    if y <= margin:
        return top + (upper - top) * y / margin
    if y >= size - margin:
        return lower + (bottom - lower) * (y - (size - margin)) / margin
    return upper + (lower - upper) * (y - margin) / (size - 2 * margin)


def draw_frost(size, radius):
    """The rounded shape with the frost gradient in its alpha. Columns between the margins are the same."""
    coverage = sample_spans(size, size, rounded_spans(0, 0, size, size, radius))
    levels = sample_rows(size, size, lambda y: frost_level(y, size, radius))
    return white([c * v for c, v in zip(coverage, levels)])


def rim_level(y, radius, soft=RIM_SOFT):
    """Full strength on the top edge, easing to `soft` where the top corners meet the sides."""
    return soft + (1 - soft) * (1 - smoothstep(0, radius, y))


def draw_rim(size, radius, line=RIM_TEXELS, soft=RIM_SOFT):
    """A line `line` texels wide just inside the rounded shape's edge, brighter along the top unless `soft` is 1."""
    outer = rounded_spans(0, 0, size, size, radius)
    inner = rounded_spans(line, line, size - line, size - line, radius - line)
    coverage = sample_spans(size, size, ring_spans(outer, inner))
    levels = sample_rows(size, size, lambda y: rim_level(y, radius, soft))
    return white([c * v for c, v in zip(coverage, levels)])


def draw_gilt(size):
    """The gilt filament for the top left corner: a quarter circle and two legs that fade to a tip.

    The texture's top left is one unit outside the card's corner, as the mockup sets its filament.
    """
    per = size / GILT_UNITS
    radius, line, arm, fade = LUMEN_RADIUS * per, GILT_LINE * per, GILT_ARM * per, GILT_FADE * per

    def fn(x, y):
        if x < radius and y < radius:
            d = math.hypot(radius - x, radius - y)
            return 1.0 if radius - line <= d <= radius else 0.0
        if y < line and radius <= x <= arm:
            return 1.0 - smoothstep(arm - fade, arm, x)
        if x < line and radius <= y <= arm:
            return 1.0 - smoothstep(arm - fade, arm, y)
        return 0.0

    return white(sample(size, size, fn))


def draw_gem(size):
    """A square turned 45 degrees with four facets lit from the top left, in a soft halo."""
    per = size / GEM_UNITS
    c = size / 2
    reach = GEM_SIDE * per / math.sqrt(2)
    halo = GEM_HALO * per
    tl, tr, bl, br = GEM_FACETS

    def inside(x, y):
        return abs(x - c) + abs(y - c) <= reach

    def level(x, y):
        if not inside(x, y):
            return 1.0
        dx, dy = x - c, y - c
        if dx <= 0 and dy <= 0:
            return tl
        if dx > 0 and dy <= 0:
            return tr
        if dx <= 0:
            return bl
        return br

    def alpha(x, y):
        d = abs(x - c) + abs(y - c) - reach
        if d <= 0:
            return 1.0
        if d >= halo:
            return 0.0
        return GEM_HALO_ALPHA * (1 - d / halo) ** 2

    return shaded(sample(size, size, level), sample(size, size, alpha))


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

    @property
    def name(self):
        return Path(self.path).stem


def _texture(name, width, height, draw, about, settings="4x4 supersampled"):
    drawn = LUMEN_DRAWN if name in LUMEN_ASSETS else DRAWN
    return Asset(f"Media/Textures/{name}.png", width, height, draw, about, settings, SLICE.get(name), drawn)


LUMEN_ASSETS = {
    "LumenShape", "LumenFrost", "LumenRim", "LumenRimSmall", "LumenOutline", "LumenGilt", "LumenGem", "PillCapLeft",
    "PillCapRight", "BarSheen", "LensMask", "SocketMask", "RuleFade", "LumenShadow",
}


ASSETS = [
    _texture("LumenShape", 128, 128, lambda: draw_rounded(128, SLICE["LumenShape"]),
             "Lumen card shape: a square with 14-unit round corners at 4 texels per unit. Nine-slice fill for the deep tint, the socket body and the dispel tint, or a mask."),
    _texture("LumenFrost", 128, 128, lambda: draw_frost(128, SLICE["LumenFrost"]),
             "Lumen frost: the card shape with the mockup's vertical frost gradient baked into its alpha, falling from full at the top to 75% where the top corners end, 50% where the bottom corners start and 45% at the bottom. Nine-slice; tinted with the glass token.",
             "4x4 supersampled; columns between the margins match, rows hold the gradient"),
    _texture("LumenRim", 128, 128, lambda: draw_rim(128, SLICE["LumenRim"]),
             "Lumen rim for 14-unit corners: a 0.75-unit line just inside the card's edge, full strength along the top, 33% on the sides and bottom (the mockup's 18% rim-soft under its 55% top light), easing around the top corners. Nine-slice."),
    _texture("LumenRimSmall", 128, 128, lambda: draw_rim(128, SLICE["LumenRimSmall"]),
             "Lumen rim for 8-unit corners (sockets and small tiles): the same 0.75-unit line and top light on the smaller radius. Nine-slice."),
    _texture("LumenOutline", 128, 128, lambda: draw_rim(128, SLICE["LumenOutline"], soft=1.0),
             "Even outline for 8-unit corners: the rim's 0.75-unit line at one strength all round, for highlight rings such as the group frames' target ring. Nine-slice."),
    _texture("LumenGilt", GILT_SIZE, GILT_SIZE, lambda: draw_gilt(GILT_SIZE),
             "Gilt filament for a window or rail's top left corner, mirrored for the bottom right: a 1.5-unit line on the 14-unit radius with 18-unit legs that fade to a tip over their last 3 units. Covers 20 units from one unit outside the corner."),
    _texture("LumenGem", GEM_SIZE, GEM_SIZE, lambda: draw_gem(GEM_SIZE),
             "Gilt gem for section caps: a 7-unit square turned 45 degrees with four facets lit from the top left, in a 6-unit halo at half strength. Covers 16 units.",
             "4x4 supersampled, shading in the colour channels"),
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
             "Icon mask for sockets, portraits and every square icon: corners rounded 8 units on a 44-unit icon (18% of the side)."),
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
    _texture("MinimapMask", 512, 512, lambda: draw_chamfer(512, 512 * MINIMAP_MASK_SHARE),
             "Chamfered square mask for Minimap:SetMaskTexture and the minimap footer: the cut is 8 of 217 units, the frame's 12-unit chamfer at the map's 2-unit inset on the mockup's 221 frame."),
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


def provenance_table():
    lines = [
        "| File | Size | What it is | Made with | Settings | Date |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for asset in ASSETS:
        slice_note = f"; slice margins {asset.slice} texels" if asset.slice else ""
        lines.append(
            f"| `{asset.path}` | {asset.width}x{asset.height} | {asset.about} | "
            f"`Tools/media/make_media.py`, procedural, no model | {asset.settings}{slice_note} | {asset.drawn} |"
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
