"""Prepare the Orbs HUD style's forged orb ring.

Usage:
    python3 Tools/media/orbs.py --ring RING.png [--out DIR]

The source is the original ring generated for the KSTY-44 mock-up (Higgsfield job 5a7af16a;
~/.capy/work/KSTY-44/mock/assets/ring.png on the owner's MacBook). It is not committed. This script is the production
pass: it centres the ring on its opening, resamples it with premultiplied alpha so no dark fringe shows, sharpens it
lightly after the downscale and trims stray alpha below 4. It writes the prepared source into Tools/media/materials/,
where Tools/media/make_media.py exports it into Media/Textures/. Needs Pillow.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]

# The ring's opening in its source, as measured on the generated image: left, top, right, bottom.
RING_HOLE = (290, 304, 1723, 1729)
RING_SIZE = 512
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



def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--ring", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=ROOT / "Tools" / "media" / "materials")
    args = parser.parse_args(argv)
    ring_source = Image.open(args.ring).convert("RGBA")
    args.out.mkdir(parents=True, exist_ok=True)
    outputs = {"OrbRing": ring(ring_source)}
    for name, image in outputs.items():
        path = args.out / f"{name}.png"
        image.save(path, optimize=True)
        print(f"wrote {path} {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
