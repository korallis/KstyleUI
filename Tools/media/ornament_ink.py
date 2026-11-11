"""Writes Core/Widgets/OrnamentInk.lua: the ink shapes of round and tapered art, read from the PNG alpha.

The ornament registry and the centre-clearance guard measure the level badge, the portrait ring and band, and the
rank pendants by their drawn ink instead of their texture boxes. Any non-zero alpha counts as ink. A circle is the
smallest circle about the visible box's centre that covers every ink pixel, as a fraction of half the visible width;
a band's hole is the distance from that centre to its nearest ink pixel's centre, as the same fraction.
A pendant is a list of row runs, each widened by one texel on both sides. Each shipped font gives its ascender and
descender and, for every Latin character that reaches below the baseline, how far, in em, so a text's ink can be told
from its box.
"""

import argparse
import re
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "Core" / "Widgets" / "OrnamentData.lua"
OUT = ROOT / "Core" / "Widgets" / "OrnamentInk.lua"
FORGED = ROOT / "Media" / "Textures" / "ForgedOrnaments"
DISCS = ("Dot", "Ring", "RingBevel")


def alpha(path):
    """Returns (width, height, rows) for an 8-bit, non-interlaced RGBA PNG; rows are bytes of alpha values."""
    data = path.read_bytes()
    width, height, depth, colour, _, _, interlace = struct.unpack(">IIBBBBB", data[16:29])
    if (depth, colour, interlace) != (8, 6, 0):
        raise ValueError("%s: expected 8-bit RGBA without interlace" % path)
    chunks, at = [], 8
    while at < len(data):
        length, kind = struct.unpack(">I4s", data[at:at + 8])
        if kind == b"IDAT":
            chunks.append(data[at + 8:at + 8 + length])
        at += 12 + length
    raw, stride, previous, rows = zlib.decompress(b"".join(chunks)), width * 4, bytearray(width * 4), []
    for y in range(height):
        start = y * (stride + 1)
        kind, line = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        for x in range(stride):
            left = line[x - 4] if x >= 4 else 0
            up = previous[x]
            corner = previous[x - 4] if x >= 4 else 0
            if kind == 1:
                line[x] = (line[x] + left) & 255
            elif kind == 2:
                line[x] = (line[x] + up) & 255
            elif kind == 3:
                line[x] = (line[x] + (left + up) // 2) & 255
            elif kind == 4:
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                line[x] = (line[x] + (left if pa <= pb and pa <= pc else up if pb <= pc else corner)) & 255
        rows.append(bytes(line[3::4]))
        previous = line
    return width, height, rows


def circle(rows, width, height):
    """Fraction of half the width that covers every ink pixel's far corner, measured from the box centre."""
    cx, cy, far = width / 2, height / 2, 0.0
    for y in range(height):
        for x, value in enumerate(rows[y][:width]):
            if value:
                dx, dy = abs(x + 0.5 - cx) + 0.5, abs(y + 0.5 - cy) + 0.5
                far = max(far, dx * dx + dy * dy)
    return far ** 0.5 / (width / 2)


def hole(rows, width, height):
    """Fraction of half the width from the box centre to the nearest ink pixel's centre: the band's open middle."""
    cx, cy, near = width / 2, height / 2, None
    for y in range(height):
        for x, value in enumerate(rows[y][:width]):
            if value:
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                distance = dx * dx + dy * dy
                near = distance if near is None else min(near, distance)
    return near ** 0.5 / (width / 2)


def spans(rows, width, height, split=False):
    """Runs of rows as (top, bottom, left, right) texels, bottom and right exclusive, widened by one texel. With
    split, a row with ink in separate places (the plaque's two brackets) has a run for each place, and runs that
    touch once widened are one run; without it a row is one run from its first ink to its last."""
    runs, last = [], []
    for y in range(height):
        pieces = []
        for x, value in enumerate(rows[y][:width]):
            if value:
                if pieces and (not split or x - 1 <= pieces[-1][1]):
                    pieces[-1][1] = x + 2
                else:
                    pieces.append([x - 1, x + 2])
        current = []
        for left, right in pieces:
            match = next((run for run in last if run[1] == y and run[2:] == [left, right]), None)
            if match:
                match[1] = y + 1
            else:
                match = [y, y + 1, left, right]
                runs.append(match)
            current.append(match)
        last = current
    return runs


FONTS = ROOT / "Media" / "Fonts"
LATIN = range(0x20, 0x250)


def font_metrics(path):
    """Returns (ascent, descent, deep) for a TrueType font, in em: the hhea ascender and descender and, for each
    character from U+0020 to U+024F whose glyph reaches below the baseline, how far it reaches."""
    data = path.read_bytes()
    count = struct.unpack(">H", data[4:6])[0]
    tables = {}
    for i in range(count):
        tag, _, offset, length = struct.unpack(">4sIII", data[12 + 16 * i:28 + 16 * i])
        tables[tag.decode("latin-1")] = (offset, length)
    head = tables["head"][0]
    upm = struct.unpack(">H", data[head + 18:head + 20])[0]
    long_loca = struct.unpack(">h", data[head + 50:head + 52])[0] == 1
    hhea = tables["hhea"][0]
    ascent, descent = struct.unpack(">hh", data[hhea + 4:hhea + 8])
    glyphs = struct.unpack(">H", data[tables["maxp"][0] + 4:tables["maxp"][0] + 6])[0]
    loca, glyf = tables["loca"][0], tables["glyf"][0]
    if long_loca:
        starts = struct.unpack(">%dI" % (glyphs + 1), data[loca:loca + 4 * (glyphs + 1)])
    else:
        starts = [2 * v for v in struct.unpack(">%dH" % (glyphs + 1), data[loca:loca + 2 * (glyphs + 1)])]
    cmap = tables["cmap"][0]
    mapping = {}
    for i in range(struct.unpack(">H", data[cmap + 2:cmap + 4])[0]):
        platform, encoding, offset = struct.unpack(">HHI", data[cmap + 4 + 8 * i:cmap + 12 + 8 * i])
        at = cmap + offset
        kind = struct.unpack(">H", data[at:at + 2])[0]
        if platform == 3 and encoding in (1, 10) and kind == 4:
            segs = struct.unpack(">H", data[at + 6:at + 8])[0] // 2
            ends = struct.unpack(">%dH" % segs, data[at + 14:at + 14 + 2 * segs])
            begin = at + 16 + 2 * segs
            firsts = struct.unpack(">%dH" % segs, data[begin:begin + 2 * segs])
            deltas = struct.unpack(">%dh" % segs, data[begin + 2 * segs:begin + 4 * segs])
            ranges = begin + 4 * segs
            offsets = struct.unpack(">%dH" % segs, data[ranges:ranges + 2 * segs])
            for k in range(segs):
                for code in range(firsts[k], ends[k] + 1):
                    if code not in LATIN:
                        continue
                    if offsets[k] == 0:
                        glyph = (code + deltas[k]) & 0xFFFF
                    else:
                        where = ranges + 2 * k + offsets[k] + 2 * (code - firsts[k])
                        glyph = struct.unpack(">H", data[where:where + 2])[0]
                        glyph = (glyph + deltas[k]) & 0xFFFF if glyph else 0
                    if glyph:
                        mapping.setdefault(code, glyph)
        elif platform == 3 and encoding == 10 and kind == 12:
            for k in range(struct.unpack(">I", data[at + 12:at + 16])[0]):
                first, last, glyph = struct.unpack(">III", data[at + 16 + 12 * k:at + 28 + 12 * k])
                for code in range(first, last + 1):
                    if code in LATIN:
                        mapping.setdefault(code, glyph + code - first)
    deep = {}
    for code, glyph in mapping.items():
        if glyph < glyphs and starts[glyph + 1] > starts[glyph]:
            y_min = struct.unpack(">h", data[glyf + starts[glyph] + 4:glyf + starts[glyph] + 6])[0]
            if y_min < 0:
                deep[code] = -y_min / upm
    return ascent / upm, -descent / upm, deep


def render():
    sizes = {name: (int(w), int(h)) for name, w, h in re.findall(r"\t(\w+) = \{ (\d+), (\d+),", DATA.read_text())}
    circles, holes, tapers = {}, {}, {}
    for name in DISCS:
        width, height, rows = alpha(ROOT / "Media" / "Textures" / (name + ".png"))
        circles[name] = circle(rows, width, height)
    for name, (width, height) in sorted(sizes.items()):
        if re.fullmatch(r"Ring\d+", name):
            rows = alpha(FORGED / (name + ".png"))[2]
            circles[name], holes[name] = circle(rows, width, height), hole(rows, width, height)
        elif re.fullmatch(r"(Boss|Elite)PendantR\d+", name):
            tapers[name] = (width, height, spans(alpha(FORGED / (name + ".png"))[2], width, height))
        elif re.fullmatch(r"(Map|Point|Plaque)\d+", name):
            tapers[name] = (width, height, spans(alpha(FORGED / (name + ".png"))[2], width, height, True))
    lines = ["-- OrnamentInk.lua: ink shapes of round and tapered art, generated from the PNG alpha by Tools/media/ornament_ink.py.",
             "local _, ns = ...", "ns.Widgets.OrnamentInk = {", "\tcircles = {"]
    for name in sorted(circles):
        lines.append("\t\t%s = %.4f," % (name, (int(circles[name] * 10000 - 1e-9) + 1) / 10000))
    lines += ["\t},", "\tholes = {"]
    for name in sorted(holes):
        lines.append("\t\t%s = %.4f," % (name, int(holes[name] * 10000) / 10000))
    lines += ["\t},", "\tspans = {"]
    for name in sorted(tapers):
        width, height, runs = tapers[name]
        lines.append("\t\t%s = { %d, %d, %s }," % (name, width, height, ", ".join("%d, %d, %d, %d" % tuple(run) for run in runs)))
    lines += ["\t},", "\tfonts = {"]
    for path in sorted(FONTS.glob("*.ttf")):
        ascent, descent, deep = font_metrics(path)
        runs = ", ".join("[%d] = %.4f" % (code, (int(deep[code] * 10000 - 1e-9) + 1) / 10000) for code in sorted(deep))
        lines.append('\t\t["%s"] = { ascent = %.4f, descent = %.4f, deep = { %s } },' % (path.stem, ascent, int(descent * 10000) / 10000, runs))
    lines += ["\t},", "}"]
    return ("\r\n".join(lines) + "\r\n").encode("ascii")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail when the file differs from the PNGs")
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args(argv)
    text = render()
    if args.check:
        if not args.out.exists() or args.out.read_bytes() != text:
            print("%s is stale: run python3 Tools/media/ornament_ink.py" % args.out)
            return 1
        return 0
    args.out.write_bytes(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
