"""Writes Core/Widgets/OrnamentInk.lua: the ink shapes of round and tapered art, read from the PNG alpha.

The ornament registry and the centre-clearance guard measure the level badge, the portrait ring and band, and the
rank pendants by their drawn ink instead of their texture boxes. Any non-zero alpha counts as ink. A circle is the
smallest circle about the visible box's centre that covers every ink pixel, as a fraction of half the visible width.
A pendant is a list of row runs, each widened by one texel on both sides.
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


def spans(rows, width, height):
    """Runs of rows as (top, bottom, left, right) texels, bottom and right exclusive, widened by one texel."""
    runs = []
    for y in range(height):
        ink = [x for x, value in enumerate(rows[y][:width]) if value]
        if not ink:
            continue
        left, right = ink[0] - 1, ink[-1] + 2
        if runs and runs[-1][1] == y and runs[-1][2:] == [left, right]:
            runs[-1][1] = y + 1
        else:
            runs.append([y, y + 1, left, right])
    return runs


def render():
    sizes = {name: (int(w), int(h)) for name, w, h in re.findall(r"\t(\w+) = \{ (\d+), (\d+),", DATA.read_text())}
    circles, tapers = {}, {}
    for name in DISCS:
        width, height, rows = alpha(ROOT / "Media" / "Textures" / (name + ".png"))
        circles[name] = circle(rows, width, height)
    for name, (width, height) in sorted(sizes.items()):
        if re.fullmatch(r"Ring\d+", name):
            circles[name] = circle(alpha(FORGED / (name + ".png"))[2], width, height)
        elif re.fullmatch(r"(Boss|Elite)PendantR\d+", name):
            tapers[name] = (width, height, spans(alpha(FORGED / (name + ".png"))[2], width, height))
    lines = ["-- OrnamentInk.lua: ink shapes of round and tapered art, generated from the PNG alpha by Tools/media/ornament_ink.py.",
             "local _, ns = ...", "ns.Widgets.OrnamentInk = {", "\tcircles = {"]
    for name in sorted(circles):
        lines.append("\t\t%s = %.4f," % (name, (int(circles[name] * 10000 - 1e-9) + 1) / 10000))
    lines += ["\t},", "\tspans = {"]
    for name in sorted(tapers):
        width, height, runs = tapers[name]
        lines.append("\t\t%s = { %d, %d, %s }," % (name, width, height, ", ".join("%d, %d, %d, %d" % tuple(run) for run in runs)))
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
