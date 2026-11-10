#!/usr/bin/env python3
"""make_bearings.py: write KstyleUI_Meters/Bearings.lua, the ink side bearings of every bundled face.

    python3 Tools/media/make_bearings.py [--fonts Media/Fonts] [--out KstyleUI_Meters/Bearings.lua] [--check]

The damage meter joins an amount and a share with a middle dot and keeps 5/21 em of ink each side of it
(KstyleUI_Meters/BarList.lua). The gap the game draws is between advances, so the meter needs each glyph's
left side bearing (ink start minus pen start) and right side bearing (advance minus ink end). This reads
them from each font file's head, hhea, hmtx, cmap, loca and glyf tables, in em rounded to three places,
for the characters a meter row joins. Run it again when a font in Media/Fonts changes and commit the
result; Tools/tests/test_make_bearings.py fails when the file is stale. Only the standard library is used.
"""

import argparse
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "Media" / "Fonts"
OUT = ROOT / "KstyleUI_Meters" / "Bearings.lua"
CHARACTERS = "0123456789%.:~,kmKM\u00b7"
PLACES = 3


def tables(data):
    count = struct.unpack_from(">H", data, 4)[0]
    out = {}
    for i in range(count):
        tag, _, offset, length = struct.unpack_from(">4sIII", data, 12 + 16 * i)
        out[tag.decode("latin-1")] = (offset, length)
    return out


def cmap_lookup(data, offset):
    best = None
    for i in range(struct.unpack_from(">H", data, offset + 2)[0]):
        platform, encoding, at = struct.unpack_from(">HHI", data, offset + 4 + 8 * i)
        fmt = struct.unpack_from(">H", data, offset + at)[0]
        if (platform == 3 and encoding in (1, 10)) or platform == 0:
            if fmt == 12 or (fmt == 4 and best is None):
                best = (fmt, offset + at)
    if best is None:
        raise ValueError("no Unicode cmap")
    fmt, sub = best

    def glyph(code):
        if fmt == 4:
            segs = struct.unpack_from(">H", data, sub + 6)[0] // 2
            ends = sub + 14
            starts = ends + 2 * segs + 2
            deltas = starts + 2 * segs
            ranges = deltas + 2 * segs
            for s in range(segs):
                end = struct.unpack_from(">H", data, ends + 2 * s)[0]
                if code > end:
                    continue
                start = struct.unpack_from(">H", data, starts + 2 * s)[0]
                if code < start:
                    return 0
                delta = struct.unpack_from(">h", data, deltas + 2 * s)[0]
                ro = struct.unpack_from(">H", data, ranges + 2 * s)[0]
                if ro == 0:
                    return (code + delta) & 0xFFFF
                g = struct.unpack_from(">H", data, ranges + 2 * s + ro + 2 * (code - start))[0]
                return (g + delta) & 0xFFFF if g else 0
            return 0
        groups = struct.unpack_from(">I", data, sub + 12)[0]
        for k in range(groups):
            start, end, first = struct.unpack_from(">III", data, sub + 16 + 12 * k)
            if start <= code <= end:
                return first + code - start
        return 0

    return glyph


def bearings(path):
    data = Path(path).read_bytes()
    t = tables(data)
    upem = struct.unpack_from(">H", data, t["head"][0] + 18)[0]
    long_loca = struct.unpack_from(">h", data, t["head"][0] + 50)[0] == 1
    metrics = struct.unpack_from(">H", data, t["hhea"][0] + 34)[0]
    hmtx, loca, glyf = t["hmtx"][0], t["loca"][0], t["glyf"][0]
    glyph = cmap_lookup(data, t["cmap"][0])
    lsb, rsb = {}, {}
    for char in CHARACTERS:
        gid = glyph(ord(char))
        if gid == 0:
            continue
        advance = struct.unpack_from(">H", data, hmtx + 4 * min(gid, metrics - 1))[0]
        if long_loca:
            start, end = struct.unpack_from(">II", data, loca + 4 * gid)
        else:
            start, end = (2 * v for v in struct.unpack_from(">HH", data, loca + 2 * gid))
        if start == end:
            continue
        x_min, _, x_max, _ = struct.unpack_from(">hhhh", data, glyf + start + 2)
        lsb[char] = round(x_min / upem, PLACES)
        rsb[char] = round((advance - x_max) / upem, PLACES)
    return lsb, rsb


def lua_key(char):
    if char.isalpha():
        return char
    return "[\"" + "".join(c if ord(c) < 128 else "\\" + str(b) for c in char for b in c.encode("utf-8")) + "\"]"


def lua_side(name, values):
    parts = ", ".join(lua_key(c) + " = " + format(values[c], "g") for c in CHARACTERS if c in values)
    return "\t\t" + name + " = { " + parts + " },"


def render(fonts_dir=FONTS):
    lines = [
        "-- Bearings.lua: written by Tools/media/make_bearings.py from Media/Fonts; each bundled face's left and right ink side bearings, in em, for the characters a meter row joins.",
        "local _, ns = ...",
        "",
        "ns.BEARINGS = {",
    ]
    for path in sorted(Path(fonts_dir).glob("*.ttf")):
        lsb, rsb = bearings(path)
        lines.append('\t["' + path.name.lower() + '"] = {')
        lines.append(lua_side("lsb", lsb))
        lines.append(lua_side("rsb", rsb))
        lines.append("\t},")
    lines.append("}")
    return "\r\n".join(lines) + "\r\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fonts", default=str(FONTS))
    parser.add_argument("--out", default=str(OUT))
    parser.add_argument("--check", action="store_true", help="change nothing; exit 1 when the file is stale")
    args = parser.parse_args(argv)
    text = render(args.fonts)
    out = Path(args.out)
    if args.check:
        if not out.exists() or out.read_bytes() != text.encode("ascii"):
            print(f"{out} is stale: run python3 Tools/media/make_bearings.py", file=sys.stderr)
            return 1
        return 0
    out.write_bytes(text.encode("ascii"))
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
