#!/usr/bin/env python3
"""gen_glyphs.py: write Tools/render/glyphs.lua, the kit fonts' glyph advances, so the scene measures text as the page draws it.

    python3 Tools/render/gen_glyphs.py [--fonts Media/Fonts] [--out Tools/render/glyphs.lua]

scene.lua estimates the width of a text whose width nothing else gives (a chat row to wrap, a name a
frame is anchored to). Average widths per character class are off by a few percent for a given face,
enough to wrap a chat line a word early, so this writes the real advance of every printable ASCII glyph
of each font in Media/Fonts, in em, keyed by the font file's name. Run it again when a font changes and
commit the result. Pillow is needed; the script runs itself again with the wow-dev virtual environment's
Python when the system Python has none.
"""

import argparse
import glob
import json
import os
import struct
import sys
from pathlib import Path

VENV_PYTHON = os.path.expanduser("~/.local/share/wow-dev/venv/bin/python")
UNITS = 1000

try:
    from PIL import ImageFont
except ImportError:  # pragma: no cover - depends on the machine
    VENV_ROOT = os.path.dirname(os.path.dirname(VENV_PYTHON))
    if os.path.exists(VENV_PYTHON) and os.path.realpath(sys.prefix) != os.path.realpath(VENV_ROOT):
        os.execv(VENV_PYTHON, [VENV_PYTHON, "-I", *sys.argv])
    sys.exit("gen_glyphs.py needs Pillow: pip install Pillow, or create the wow-dev venv at " + VENV_PYTHON)


THIN_SPACE = 0x2009
MIDDLE_DOT = 0x00B7


def characters():
    codes = set(range(32, 127)) | {THIN_SPACE, MIDDLE_DOT}
    for locale in ("enUS", "deDE", "frFR", "esES"):
        data = json.loads((Path(__file__).resolve().parents[1] / "locale" / (locale + ".json")).read_text(encoding="utf-8"))
        for text in data if isinstance(data, list) else data.values():
            codes.update(ord(c) for c in text + text.upper() if c.isprintable())
    return codes


def mapped_codes(path):
    data = Path(path).read_bytes()
    count = struct.unpack_from(">H", data, 4)[0]
    for i in range(count):
        tag, _, offset, _ = struct.unpack_from(">4sIII", data, 12 + 16 * i)
        if tag == b"cmap":
            break
    else:
        raise ValueError("font has no cmap: " + str(path))
    cmap = data[offset:]
    codes = set()
    for i in range(struct.unpack_from(">H", cmap, 2)[0]):
        platform, encoding, at = struct.unpack_from(">HHI", cmap, 4 + 8 * i)
        if not (platform == 0 or (platform == 3 and encoding in (1, 10))):
            continue
        sub = cmap[at:]
        if struct.unpack_from(">H", sub)[0] != 4:
            continue
        n = struct.unpack_from(">H", sub, 6)[0] // 2
        ends = struct.unpack_from(">" + "H" * n, sub, 14)
        starts = struct.unpack_from(">" + "H" * n, sub, 16 + 2 * n)
        deltas = struct.unpack_from(">" + "h" * n, sub, 16 + 4 * n)
        ranges_at = 16 + 6 * n
        ranges = struct.unpack_from(">" + "H" * n, sub, ranges_at)
        for s in range(n):
            for code in range(starts[s], ends[s] + 1):
                if ranges[s]:
                    pos = ranges_at + 2 * s + ranges[s] + 2 * (code - starts[s])
                    glyph = struct.unpack_from(">H", sub, pos)[0]
                    glyph = (glyph + deltas[s]) & 0xFFFF if glyph else 0
                else:
                    glyph = (code + deltas[s]) & 0xFFFF
                if glyph:
                    codes.add(code)
    return codes


def advances(path):
    """Advances of the shipped Latin locales' actual mapped glyphs, in em."""
    font = ImageFont.truetype(path, UNITS)
    return {code: font.getlength(chr(code)) / UNITS for code in characters() & mapped_codes(path)}


def render(fonts):
    """The Lua module text for {name: {code: em}}."""
    lines = [
        "-- glyphs.lua: actual glyph advances in em for the shipped Latin locales and their capitals, by font file and Unicode code point; Tools/render/gen_glyphs.py writes it.",
        "return {",
    ]
    for name in sorted(fonts):
        lines.append("\t[%s] = {" % lua_string(name))
        row = []
        for code in sorted(fonts[name]):
            row.append("[%d] = %.4f" % (code, fonts[name][code]))
            if len(row) == 8:
                lines.append("\t\t" + ", ".join(row) + ",")
                row = []
        if row:
            lines.append("\t\t" + ", ".join(row) + ",")
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--fonts", default="Media/Fonts", help="the folder of .ttf files")
    parser.add_argument("--out", default="Tools/render/glyphs.lua", help="the Lua file to write")
    args = parser.parse_args(argv)
    paths = sorted(glob.glob(os.path.join(args.fonts, "*.ttf")))
    if not paths:
        sys.exit("no .ttf files in " + args.fonts)
    fonts = {os.path.splitext(os.path.basename(path))[0]: advances(path) for path in paths}
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(render(fonts))
    print("wrote %s: %d fonts" % (args.out, len(fonts)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
