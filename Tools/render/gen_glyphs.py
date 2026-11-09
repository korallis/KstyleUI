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
import os
import sys

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


def advances(path):
    """The advance of each printable ASCII glyph, and of the thin space the kit tracks capitals with, in em, as {code: em}."""
    font = ImageFont.truetype(path, UNITS)
    out = {code: font.getlength(chr(code)) / UNITS for code in range(32, 127)}
    # A font without the thin space draws its missing-glyph box; only a real glyph's advance is recorded.
    thin, missing = font.getlength(chr(THIN_SPACE)), font.getlength(chr(0xFFFE))
    if thin != missing:
        out[THIN_SPACE] = thin / UNITS
    return out


def render(fonts):
    """The Lua module text for {name: {code: em}}."""
    lines = [
        "-- glyphs.lua: the kit fonts' glyph advances in em, by font file name and code point (ASCII, and 8201 for the thin space); Tools/render/gen_glyphs.py writes it.",
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
