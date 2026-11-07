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

# Chamfers and bevels are drawn at 4 texels per root unit, so a 6-unit chamfer is 24 texels. The
# shadow is soft, so 2 texels per unit is enough.
TEXELS_PER_UNIT = 4
SHADOW_TEXELS_PER_UNIT = 2
PANEL_CHAMFER, TILE_CHAMFER = 6, 3  # root units, from the spec's Shape section
BEVEL_LINE = 1  # art units: the widget kit draws one art unit as one whole-pixel border
HAIRLINE_AT = 3  # art units in from the edge: the faint hairline, one unit of glass inside the inner line
SHADOW_REACH = 12  # root units the shadow reaches past the panel edge
ICON_SIZE = 34  # root units: an action button at the 1080 reference
PILL_CAP = 16  # texels: each round cap of Pill.png is a quarter of its 64-texel width
GLYPH_STROKE = 5  # texels: the stroke of the 32-texel glyphs, about 1.25 units at 8 units across

# Slice margins in texels. A nine-slice corner piece is margin x margin texels from each corner and
# draws at margin / TEXELS_PER_UNIT root units, so pieces of different textures line up. Between the
# margins every row and column is the same, so stretching the edges and centre distorts nothing.
# The bevel bands are mitred: the inner edge of a band of width w meets the straight edge
# w * (sqrt(2) - 1) past the chamfer, so the bevel margins reach past both lines' mitres.
_MITRE = math.ceil(2 * BEVEL_LINE * TEXELS_PER_UNIT * (math.sqrt(2) - 1))
_HAIRLINE_MITRE = TEXELS_PER_UNIT * math.ceil((HAIRLINE_AT + BEVEL_LINE) * (math.sqrt(2) - 1))
SLICE = {
    "ChamferPanel": PANEL_CHAMFER * TEXELS_PER_UNIT,
    "ChamferTile": TILE_CHAMFER * TEXELS_PER_UNIT,
    "BevelPanelOuter": PANEL_CHAMFER * TEXELS_PER_UNIT + _MITRE,
    "BevelPanelInner": PANEL_CHAMFER * TEXELS_PER_UNIT + _MITRE,
    "BevelTileOuter": TILE_CHAMFER * TEXELS_PER_UNIT + _MITRE,
    "BevelTileInner": TILE_CHAMFER * TEXELS_PER_UNIT + _MITRE,
    "BevelPanelHairline": PANEL_CHAMFER * TEXELS_PER_UNIT + _HAIRLINE_MITRE,
    "BevelTileHairline": TILE_CHAMFER * TEXELS_PER_UNIT + _HAIRLINE_MITRE,
    "Shadow": 2 * SHADOW_REACH * SHADOW_TEXELS_PER_UNIT,
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


def draw_bevel(size, legs, line, which):
    start = {"outer": 0, "inner": line, "hairline": HAIRLINE_AT * line}[which]
    planes = chamfered_rect(size, size, legs)  # legs is the chamfer, not the slice margin
    return white(sample_spans(size, size, band_spans(planes, start, start + line)))


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
        sheen = 0.22 * math.exp(-(((v - 0.12) / 0.09) ** 2))
        return max(0.0, min(1.0, 0.68 + 0.22 * (1 - v) + sheen - 0.12 * smoothstep(0.82, 1.0, v)))

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

    @property
    def name(self):
        return Path(self.path).stem


def _texture(name, width, height, draw, about, settings="4x4 supersampled"):
    return Asset(f"Media/Textures/{name}.png", width, height, draw, about, settings, SLICE.get(name))


ASSETS = [
    _texture("ChamferPanel", 64, 64, lambda: draw_chamfer(64, SLICE["ChamferPanel"]),
             "Panel shape with 6-unit chamfers at 4 texels per unit. Nine-slice fill or mask."),
    _texture("ChamferTile", 32, 32, lambda: draw_chamfer(32, SLICE["ChamferTile"]),
             "Tile and button shape with 3-unit chamfers at 4 texels per unit. Nine-slice fill or mask."),
    _texture("BevelPanelOuter", 64, 64, lambda: draw_bevel(64, PANEL_CHAMFER * TEXELS_PER_UNIT, BEVEL_LINE * TEXELS_PER_UNIT, "outer"),
             "Outer bevel line of a panel: a 1-unit band on the chamfered edge, tinted edgeOuter."),
    _texture("BevelPanelInner", 64, 64, lambda: draw_bevel(64, PANEL_CHAMFER * TEXELS_PER_UNIT, BEVEL_LINE * TEXELS_PER_UNIT, "inner"),
             "Inner bevel hairline of a panel: the 1-unit band inside the outer line, tinted edgeInner."),
    _texture("BevelTileOuter", 64, 64, lambda: draw_bevel(64, TILE_CHAMFER * TEXELS_PER_UNIT, BEVEL_LINE * TEXELS_PER_UNIT, "outer"),
             "Outer bevel line of a tile, as BevelPanelOuter with 3-unit chamfers."),
    _texture("BevelTileInner", 64, 64, lambda: draw_bevel(64, TILE_CHAMFER * TEXELS_PER_UNIT, BEVEL_LINE * TEXELS_PER_UNIT, "inner"),
             "Inner bevel hairline of a tile, as BevelPanelInner with 3-unit chamfers."),
    _texture("BevelPanelHairline", 128, 128, lambda: draw_bevel(128, PANEL_CHAMFER * TEXELS_PER_UNIT, BEVEL_LINE * TEXELS_PER_UNIT, "hairline"),
             "Faint third line of a panel's bevel: a 1-unit band 3 units inside the edge, tinted edgeFaint."),
    _texture("BevelTileHairline", 64, 64, lambda: draw_bevel(64, TILE_CHAMFER * TEXELS_PER_UNIT, BEVEL_LINE * TEXELS_PER_UNIT, "hairline"),
             "Faint third line of a tile's bevel, as BevelPanelHairline with 3-unit chamfers."),
    _texture("ChamferIconMask", 128, 128, lambda: draw_chamfer(128, 128 * TILE_CHAMFER / ICON_SIZE),
             "Square mask for icons and portraits: a 3-unit chamfer on a 34-unit square."),
    _texture("Shadow", 128, 128, lambda: draw_shadow(128),
             "Nine-slice shadow falloff. Corner pieces are 24 units, centred on the panel's corners; the shadow reaches 12 units out.",
             "analytic Gaussian blur of a box, 4x supersampled"),
    _texture("Glow", 128, 128, lambda: draw_glow(128), "Soft radial glow for procs, hover and selection.",
             "Gaussian falloff to zero at the edge, 4x4 supersampled"),
    _texture("Divider", 256, 4, lambda: draw_divider(256, 4), "Divider line that fades out over 40% of its length at each end.",
             "smoothstep fades, 4x supersampled"),
    _texture("Noise", 128, 128, lambda: draw_noise(128), "Tileable grain for the smoked-glass surface, used at low alpha.",
             f"seeded random field (seed {NOISE_SEED}), 4x4 box-downsampled, 3x3 wrap blur"),
    _texture("Ring", 128, 128, lambda: draw_ring(128, 8), "Thin ring, 8 texels wide, for round indicators and pings."),
    _texture("BarFlat", 256, 32, lambda: draw_bar(256, 32, "flat"), "Flat status bar fill.", "solid"),
    _texture("BarSoft", 256, 32, lambda: draw_bar(256, 32, "soft"), "Status bar fill with a soft top-to-bottom gradient.",
             "4x supersampled gradient"),
    _texture("BarGlass", 256, 32, lambda: draw_bar(256, 32, "glass"), "Status bar fill with a glass sheen near the top.",
             "4x supersampled gradient"),
    _texture("MinimapMask", 128, 128, lambda: draw_full(128, 128), "Square minimap mask for Minimap:SetMaskTexture.", "solid"),
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
            f"`Tools/media/make_media.py`, procedural, no model | {asset.settings}{slice_note} | {DRAWN} |"
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
