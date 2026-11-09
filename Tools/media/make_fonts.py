"""Make the Lumen fonts in Media/Fonts from the google/fonts sources.

Usage (fontTools is needed, so run it from a throwaway virtual environment, never the repository):
    python3 -m venv /tmp/fonts-venv && /tmp/fonts-venv/bin/pip install fonttools
    /tmp/fonts-venv/bin/python Tools/media/make_fonts.py --src DIR [--out Media/Fonts]

DIR holds the files from google/fonts at the commit Media/PROVENANCE.md names:
    Cinzel[wght].ttf (ofl/cinzel), AlegreyaSans-Regular.ttf, AlegreyaSans-Medium.ttf, AlegreyaSans-Bold.ttf
    (ofl/alegreyasans).

Cinzel ships only as a variable font, and the game loads static TrueType files, so this pins the weight axis
at 600 with fontTools.varLib.instancer and names the result Cinzel SemiBold.

The game's text renderer applies no OpenType features, so Alegreya Sans would always draw its default
figures, which are oldstyle and proportional. Each Alegreya Sans file is copied with its character map
pointing the digits 0 to 9 at the font's own tabular lining figures (zero.tf to nine.tf), the figures the
mockup selects with font-variant-numeric: tabular-nums lining-nums. Nothing else changes. The family is
renamed Alegreya Sans Tabular so the modified files are not mistaken for the originals; neither font has a
Reserved Font Name.
"""

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CINZEL_WEIGHT = 600
DIGITS = ("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine")
TABULAR_SUFFIX = ".tf"
ALEGREYA = (("Regular", 400), ("Medium", 500), ("Bold", 700))
TABULAR_FAMILY = "Alegreya Sans Tabular"


def set_names(font, family, style, full, postscript, typographic=None):
    name = font["name"]
    for rec in list(name.names):
        if rec.nameID in (1, 2, 3, 4, 6, 16, 17, 25):
            name.removeNames(nameID=rec.nameID)
    rows = [(1, family), (2, "Regular" if typographic else style), (3, postscript + ";KstyleUI"), (4, full), (6, postscript)]
    if typographic:
        rows += [(16, typographic[0]), (17, typographic[1])]
    for nid, text in rows:
        name.setName(text, nid, 3, 1, 0x409)
        name.setName(text, nid, 1, 0, 0)


def make_cinzel(src, out):
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer

    static = instancer.instantiateVariableFont(TTFont(src / "Cinzel[wght].ttf", recalcTimestamp=False), {"wght": CINZEL_WEIGHT}, static=True)
    set_names(static, "Cinzel SemiBold", "Regular", "Cinzel SemiBold", "Cinzel-SemiBold", ("Cinzel", "SemiBold"))
    static["OS/2"].usWeightClass = CINZEL_WEIGHT
    path = out / "Cinzel-SemiBold.ttf"
    static.save(path)
    return path


def make_alegreya(src, out, style, weight):
    from fontTools.ttLib import TTFont

    font = TTFont(src / f"AlegreyaSans-{style}.ttf", recalcTimestamp=False)
    order = set(font.getGlyphOrder())
    for table in font["cmap"].tables:
        if not table.isUnicode():
            continue
        for i, glyph in enumerate(DIGITS):
            tabular = glyph + TABULAR_SUFFIX
            if tabular not in order:
                raise SystemExit(f"AlegreyaSans-{style}.ttf has no {tabular}")
            if ord("0") + i in table.cmap:
                table.cmap[ord("0") + i] = tabular
    full = f"{TABULAR_FAMILY} {style}"
    if style in ("Regular", "Bold"):
        set_names(font, TABULAR_FAMILY, style, full, f"AlegreyaSansTabular-{style}")
    else:
        set_names(font, full, "Regular", full, f"AlegreyaSansTabular-{style}", (TABULAR_FAMILY, style))
    font["OS/2"].usWeightClass = weight
    path = out / f"AlegreyaSansTabular-{style}.ttf"
    font.save(path)
    return path


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--src", type=Path, required=True, help="folder with the google/fonts source files")
    parser.add_argument("--out", type=Path, default=ROOT / "Media" / "Fonts", help="where to write (default: Media/Fonts)")
    args = parser.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    print("wrote", make_cinzel(args.src, args.out))
    for style, weight in ALEGREYA:
        print("wrote", make_alegreya(args.src, args.out, style, weight))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
