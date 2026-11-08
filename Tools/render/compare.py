#!/usr/bin/env python3
"""compare.py: crop a render and a reference image at the same pixels per unit and write them side by side.

    python3 Tools/render/compare.py \
        --render Tools/render/out/hud_dps_mac.png --render-ppu 1.426 --crop 480,1250,520,160 \
        --ref ~/.local/share/kstyleui-handoff/screens/mockup-leveling-warrior-2574.png --ref-ppu 1.348 --ref-crop 455,1180,490,150 \
        --out Tools/render/out/cmp_player.png

Crops are x,y,width,height in that image's pixels; add a "u" suffix (480,1250,520,160u) to give them in
screen units instead. The reference crop is rescaled to the render's pixels per unit, so one unit is the
same number of pixels in both halves. --scale magnifies both halves for viewing. The reference densities:
the design file reads 2.0 px per unit, the mockup 1.348, the owner's Mac screenshots 1.426 (2383 by 1540)
or 1.5417 (2576 by 1665, the same screen scaled up).

Pillow is needed. When the Python running this has none, the script runs itself again with the wow-dev
virtual environment's Python if that exists.
"""

import argparse
import os
import subprocess
import sys

VENV_PYTHON = os.path.expanduser("~/.local/share/wow-dev/venv/bin/python")

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover - depends on the machine
    VENV_ROOT = os.path.dirname(os.path.dirname(VENV_PYTHON))
    if os.path.exists(VENV_PYTHON) and os.path.realpath(sys.prefix) != os.path.realpath(VENV_ROOT):
        os.execv(VENV_PYTHON, [VENV_PYTHON, "-I", *sys.argv])
    sys.exit("compare.py needs Pillow: pip install Pillow, or create the wow-dev venv at " + VENV_PYTHON)


def parse_crop(text, ppu):
    """Return an integer x, y, w, h box in pixels from "x,y,w,h" or "x,y,w,hu" (units)."""
    units = text.endswith("u")
    parts = [float(v) for v in text.rstrip("u").split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("a crop is x,y,width,height")
    if units:
        parts = [v * ppu for v in parts]
    x, y, w, h = parts
    return int(round(x)), int(round(y)), max(1, int(round(w))), max(1, int(round(h)))


def crop(image, box):
    x, y, w, h = box
    return image.crop((x, y, x + w, y + h))


def labelled(panel, label, scale):
    """Magnify a crop and add a label strip above it."""
    if scale != 1:
        panel = panel.resize((max(1, int(panel.width * scale)), max(1, int(panel.height * scale))), Image.LANCZOS)
    strip = 18
    out = Image.new("RGB", (panel.width, panel.height + strip), (24, 24, 24))
    out.paste(panel.convert("RGB"), (0, strip))
    ImageDraw.Draw(out).text((4, 3), label, fill=(220, 220, 220))
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--render", required=True, help="the render PNG")
    parser.add_argument("--render-ppu", type=float, default=1.426, help="the render's pixels per unit")
    parser.add_argument("--crop", required=True, help="x,y,w,h of the render crop, in pixels or with a u suffix in units")
    parser.add_argument("--ref", required=True, help="the reference PNG: design, mockup or screenshot")
    parser.add_argument("--ref-ppu", type=float, required=True, help="the reference's pixels per unit")
    parser.add_argument("--ref-crop", required=True, help="x,y,w,h of the reference crop, in pixels or with a u suffix in units")
    parser.add_argument("--out", required=True, help="the side-by-side PNG to write")
    parser.add_argument("--scale", type=float, default=2.0, help="magnification of both halves (default 2)")
    parser.add_argument("--label-a", default="render")
    parser.add_argument("--label-b", default="reference")
    args = parser.parse_args(argv)

    render = Image.open(args.render)
    ref = Image.open(args.ref)
    a = crop(render, parse_crop(args.crop, args.render_ppu))
    b = crop(ref, parse_crop(args.ref_crop, args.ref_ppu))
    factor = args.render_ppu / args.ref_ppu
    if abs(factor - 1) > 1e-6:
        b = b.resize((max(1, int(round(b.width * factor))), max(1, int(round(b.height * factor)))), Image.LANCZOS)
    left = labelled(a, f"{args.label_a} {a.width}x{a.height}px @ {args.render_ppu:g} px/u", args.scale)
    right = labelled(b, f"{args.label_b} {b.width}x{b.height}px rescaled to {args.render_ppu:g} px/u", args.scale)
    gap = 8
    out = Image.new("RGB", (left.width + gap + right.width, max(left.height, right.height)), (60, 60, 60))
    out.paste(left, (0, 0))
    out.paste(right, (left.width + gap, 0))
    out.save(args.out)
    print(f"wrote {args.out}: render crop {a.width}x{a.height}, reference crop {b.width}x{b.height} at {args.render_ppu:g} px/u")
    return 0


if __name__ == "__main__":
    sys.exit(main())
