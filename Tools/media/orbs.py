"""Prepare the Orbs HUD style's forged art: the orb ring and the tray's arm, rails and crest.

Usage:
    python3 Tools/media/orbs.py --ring RING.png --base BASE.png [--out DIR]

The sources are the two original images generated for the KSTY-44 mock-up (Higgsfield jobs 5a7af16a, the ring, and
0b133988, the base; ~/.capy/work/KSTY-44/mock/assets/ on the owner's MacBook). They are not committed. This script is
the production pass: it centres the ring on its opening, cuts the base into the pieces the game stretches (an arm
that three-slices vertically, a top and a bottom rail, the centre crest), joins rail segments into one long strip
with cross-faded seams, resamples everything with premultiplied alpha so no dark fringe shows, sharpens lightly
after the downscale and trims stray alpha below 4. It writes the prepared sources into Tools/media/materials/,
where Tools/media/make_media.py exports them into Media/Textures/. Needs Pillow.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]

# The ring's opening in its source, as measured on the generated image: left, top, right, bottom.
RING_HOLE = (290, 304, 1723, 1729)
RING_SIZE = 512
# The base's pieces, in its source pixels: (left, top, right, bottom) and the output size.
ARM = ((556, 185, 736, 545), (128, 256))
CREST = ((1152, 146, 1512, 326), (256, 128))
RAIL_TOP_ROWS = (262, 326)
RAIL_BOTTOM_ROWS = (452, 516)
# Each segment: left, right, and whether it is mirrored. The strip runs from the left arm's inner edge (736) and ends
# on the same joint mirrored, because the game draws the right arm as the left one flipped.
RAIL_SEGMENTS = ((736, 1140, False), (1530, 1927, False), (736, 1140, True))
RAIL_FADE = 40
RAIL_SIZE = (1024, 64)
ALPHA_FLOOR = 4


def flat(image):
    read = getattr(image, "get_flattened_data", None) or image.getdata
    return list(read())


def premultiplied_resize(image, size):
    rgba = image.convert("RGBA")
    pre = Image.new("RGBA", rgba.size)
    pixels = [(r * a // 255, g * a // 255, b * a // 255, a) for r, g, b, a in flat(rgba)]
    pre.putdata(pixels)
    small = pre.resize(size, Image.LANCZOS)
    out = []
    for r, g, b, a in flat(small):
        if a < ALPHA_FLOOR:
            out.append((0, 0, 0, 0))
        else:
            out.append((min(255, r * 255 // a), min(255, g * 255 // a), min(255, b * 255 // a), a))
    result = Image.new("RGBA", size)
    result.putdata(out)
    return result


def sharpen(image):
    alpha = image.getchannel("A")
    rgb = image.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    rgb.putalpha(alpha)
    return rgb


def ring(source):
    left, top, right, bottom = RING_HOLE
    cx, cy = (left + right) / 2, (top + bottom) / 2
    half = max(cx, source.width - cx, cy, source.height - cy)
    box = (round(cx - half), round(cy - half), round(cx + half), round(cy + half))
    square = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]))
    square.paste(source, (-box[0], -box[1]))
    return sharpen(premultiplied_resize(square, (RING_SIZE, RING_SIZE)))


def piece(source, spec):
    box, size = spec
    return sharpen(premultiplied_resize(source.crop(box), size))


def rail(source, rows):
    top, bottom = rows
    strips = []
    for a, b, mirrored in RAIL_SEGMENTS:
        strip = source.crop((a, top, b, bottom))
        strips.append(strip.transpose(Image.FLIP_LEFT_RIGHT) if mirrored else strip)
    width = sum(s.width for s in strips) - RAIL_FADE * (len(strips) - 1)
    joined = Image.new("RGBA", (width, bottom - top))
    x = 0
    for i, strip in enumerate(strips):
        if i == 0:
            joined.paste(strip, (0, 0))
        else:
            for dx in range(strip.width):
                t = min(1.0, dx / RAIL_FADE)
                column = strip.crop((dx, 0, dx + 1, strip.height))
                under = joined.crop((x + dx, 0, x + dx + 1, strip.height))
                joined.paste(Image.blend(under, column, t), (x + dx, 0))
        x += strip.width - RAIL_FADE
    return sharpen(premultiplied_resize(joined, RAIL_SIZE))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--ring", type=Path, required=True)
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=ROOT / "Tools" / "media" / "materials")
    args = parser.parse_args(argv)
    ring_source = Image.open(args.ring).convert("RGBA")
    base_source = Image.open(args.base).convert("RGBA")
    args.out.mkdir(parents=True, exist_ok=True)
    outputs = {
        "OrbRing": ring(ring_source),
        "OrbArm": piece(base_source, ARM),
        "OrbCrest": piece(base_source, CREST),
        "OrbRail": rail(base_source, RAIL_TOP_ROWS),
        "OrbRailBottom": rail(base_source, RAIL_BOTTOM_ROWS),
    }
    for name, image in outputs.items():
        path = args.out / f"{name}.png"
        image.save(path, optimize=True)
        print(f"wrote {path} {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
