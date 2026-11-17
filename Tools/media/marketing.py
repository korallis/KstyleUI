"""Make KstyleUI's branded marketing images, and splice the master store description.

    python3 Tools/media/marketing.py            # write docs/media/marketing/*
    python3 Tools/media/marketing.py --pages    # also regenerate README.md and the
                                                # CurseForge/Wago description blocks
                                                # from docs/store/description.md

Images only use the addon's own OFL fonts (Media/Fonts), its procedural logo
(Tools/media/make_media.py), the colours in Core/Tokens.lua and the in-game /
test-render pictures already in docs/media/readme. No AI and no game art is
created here; the in-game crop is the addon's own screenshot, darkened.
"""

import argparse
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
README_MEDIA = ROOT / "docs" / "media" / "readme"
OUT = ROOT / "docs" / "media" / "marketing"
FONTS = ROOT / "Media" / "Fonts"
MASTER = ROOT / "docs" / "store" / "description.md"

# Core/Tokens.lua colours.
FORGED = (16, 18, 17)        # materialForged 101211
SLAB_TOP = (21, 23, 28)      # slabTop 15171c
SLAB_BOTTOM = (10, 11, 14)   # slabBottom 0a0b0e
GILT = (211, 181, 116)       # gilt d3b574
GILT_LIT = (243, 220, 164)   # giltLit f3dca4
GILT_DIM = (138, 108, 52)    # giltDim 8a6c34
TEXT = (200, 209, 218)       # text c8d1da
EMPHASIS = (242, 245, 248)   # textEmphasis f2f5f8
MUTED = (169, 182, 194)      # muted a9b6c2
EDGE = (70, 78, 88)

CINZEL = "Cinzel-SemiBold.ttf"
CINZEL_CAPS = "CinzelCaps-Medium.ttf"
BODY = "AlegreyaSans-Regular.ttf"
BODY_BOLD = "AlegreyaSansTabular-Bold.ttf"

PITCH = "A complete, pixel-perfect interface for World of Warcraft: Forever"
PITCH2 = "One dark forged style. Three HUDs. Set up in one window."

HEADERS = [
    ("header-three-huds.jpg", "THREE HUDS", "Medallions, Frames or Orbs - pick yours, change it any time"),
    ("header-every-screen.jpg", "EVERY SCREEN", "Pixel-perfect from a laptop to a 32:9 ultrawide"),
    ("header-set-up.jpg", "SET UP IN ONE WINDOW", "One short setup, then you are playing"),
    ("header-whole-interface.jpg", "THE WHOLE INTERFACE", "Every window in the same dark forged style"),
]

CARDS = [
    ("game_medallions_closeup.jpg", "Three HUD styles",
     "Medallions, Frames or Orbs.", "Pick at setup, switch any time."),
    ("hud_frames_1080.jpg", "Pixel-perfect sizing",
     "Every edge lands on whole pixels.", "Text never drops below readable."),
    ("ultrawide_spread.jpg", "Ultrawide ready",
     "Centred or Spread on 21:9 and 32:9.", "Nothing stranded at the edges."),
    ("frame_setup.jpg", "Ready in minutes",
     "One setup: HUD, layout, modules.", "DPS, Tank and Healer layouts built in."),
    ("crop_meter.jpg", "The full kit",
     "Meter, nameplates, bags, tooltips.", "One style across the whole game."),
    ("frame_skins.jpg", "Nothing you don't want",
     "Every feature is its own module.", "Switch one off and it costs nothing."),
]

README_HEADER = """<p align="center">
<a href="https://github.com/korallis/KstyleUI/releases/latest"><img src="https://img.shields.io/github/v/release/korallis/KstyleUI?label=Download%20the%20latest%20release" alt="Download the latest KstyleUI release from GitHub"></a>
<a href="https://www.curseforge.com/wow/addons/kstyleui"><img src="https://img.shields.io/badge/CurseForge-KstyleUI-F16436?logo=curseforge&logoColor=white" alt="KstyleUI on CurseForge"></a>
<a href="https://addons.wago.io/addons/kstyleui"><img src="https://img.shields.io/badge/Wago-KstyleUI-C1272D" alt="KstyleUI on Wago Addons"></a>
</p>

"""

# GitHub is the icon pack's own host, so this note lives only in README.md.
# It is inserted before the FAQ, at the end of the Install section.
ICON_NOTE = """
**Optional, GitHub only: the repainted icons.** The `KstyleUI-Icons-<version>.zip` on the [GitHub release page](https://github.com/korallis/KstyleUI/releases/latest) repaints ability and item icons everywhere. It is not an addon and does not go in `AddOns`: quit the game, copy its `Interface` folder into `World of Warcraft/_forever_/`, then start the game again. The [icon pack guide](https://github.com/korallis/KstyleUI/blob/main/docs/icons.md) has the details.
"""


def _load_make_media():
    spec = importlib.util.spec_from_file_location(
        "make_media", ROOT / "Tools" / "media" / "make_media.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def logo_image(size):
    from PIL import Image
    make = _load_make_media()
    return Image.frombytes("RGBA", (size, size), make.draw_logo(size))


def font(name, size):
    from PIL import ImageFont
    return ImageFont.truetype(str(FONTS / name), size)


def tracked(draw, xy, text, face, fill, tracking=0):
    """Draw text with manual letter tracking; return its width."""
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=face, fill=fill)
        x += draw.textlength(ch, font=face) + tracking
    return x - tracking - xy[0]


def tracked_width(draw, text, face, tracking=0):
    return sum(draw.textlength(ch, font=face) + tracking for ch in text) - tracking


def fit_tracked(draw, text, name, size, tracking_ratio, max_width):
    while size > 12:
        face = font(name, size)
        tracking = size * tracking_ratio
        if tracked_width(draw, text, face, tracking) <= max_width:
            return face, tracking
        size -= 2
    return font(name, size), size * tracking_ratio


def gradient(width, height, top, bottom):
    from PIL import Image
    base = Image.new("RGB", (1, height))
    for y in range(height):
        t = y / max(height - 1, 1)
        base.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return base.resize((width, height))


def cover(img, width, height, focus_y=0.5):
    """Crop/resize img to exactly width x height, centre-x, focus_y vertically."""
    scale = max(width / img.width, height / img.height)
    nw, nh = round(img.width * scale), round(img.height * scale)
    img = img.resize((nw, nh))
    x = (nw - width) // 2
    y = int((nh - height) * focus_y)
    return img.crop((x, y, x + width, y + height))


def darken(img, factor):
    from PIL import ImageEnhance
    return ImageEnhance.Brightness(img).enhance(factor)


def gold_rule(draw, width, y, height=4):
    draw.rectangle([0, y, width, y + height], fill=GILT)
    draw.rectangle([0, y + height, width, y + height + 1], fill=GILT_DIM)


def save(img, name, quality=87):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    img.convert("RGB").save(path, "JPEG", quality=quality, optimize=True, progressive=True)
    print(f"{name} {img.width}x{img.height} {path.stat().st_size} bytes")
    return path


def make_banner():
    from PIL import Image, ImageDraw
    width, height = 2048, 640
    hero = Image.open(README_MEDIA / "game_medallions_hero.jpg").convert("RGB")
    img = cover(hero, width, height, focus_y=0.62)
    img = darken(img, 0.62)
    # Darken the left and top so the wordmark sits on quiet ground.
    shade = Image.new("L", (width, height), 0)
    px = shade.load()
    for yy in range(height):
        for xx in range(width):
            left = max(0.0, 1 - xx / (width * 0.72))
            top = max(0.0, 1 - yy / (height * 0.9))
            px[xx, yy] = int(215 * max(left, top * 0.8))
    img = Image.composite(Image.new("RGB", (width, height), (5, 6, 8)), img, shade)
    draw = ImageDraw.Draw(img)
    logo = logo_image(300)
    img.paste(logo, (84, 120), logo)
    draw = ImageDraw.Draw(img)
    x = 448
    eyebrow_f, eyebrow_t = fit_tracked(draw, "WORLD OF WARCRAFT: FOREVER", CINZEL_CAPS, 34, 0.32, 1400)
    tracked(draw, (x + 4, 128), "WORLD OF WARCRAFT: FOREVER", eyebrow_f, GILT, eyebrow_t)
    word_f, word_t = fit_tracked(draw, "KSTYLEUI", CINZEL, 168, 0.16, 1450)
    tracked(draw, (x, 168), "KSTYLEUI", word_f, EMPHASIS, word_t)
    draw.rectangle([x + 6, 378, x + 220, 381], fill=GILT)
    draw.text((x + 4, 404), PITCH, font=font(BODY_BOLD, 40), fill=GILT_LIT)
    draw.text((x + 4, 458), PITCH2, font=font(BODY, 38), fill=TEXT)
    gold_rule(draw, width, height - 6, 4)
    return save(img, "banner.jpg")


def make_header(name, title, subtitle):
    from PIL import ImageDraw
    width, height = 2048, 300
    img = gradient(width, height, SLAB_TOP, FORGED)
    draw = ImageDraw.Draw(img)
    gold_rule(draw, width, 0, 3)
    gold_rule(draw, width, height - 5, 3)
    logo = logo_image(168)
    img.paste(logo, (72, (height - 168) // 2), logo)
    draw = ImageDraw.Draw(img)
    x = 292
    eyebrow_f, eyebrow_t = fit_tracked(draw, "KSTYLEUI", CINZEL_CAPS, 26, 0.4, 600)
    tracked(draw, (x + 3, 58), "KSTYLEUI", eyebrow_f, GILT, eyebrow_t)
    title_f, title_t = fit_tracked(draw, title, CINZEL, 84, 0.12, width - x - 80)
    tracked(draw, (x, 92), title, title_f, EMPHASIS, title_t)
    draw.rectangle([x + 4, 196, x + 150, 199], fill=GILT)
    draw.text((x + 4, 214), subtitle, font=font(BODY, 36), fill=MUTED)
    return save(img, name)


def make_cards():
    from PIL import Image, ImageDraw
    width, height = 2048, 1220
    margin, gap = 48, 36
    cols, rows = 3, 2
    cw = (width - 2 * margin - (cols - 1) * gap) // cols
    ch = (height - 2 * margin - (rows - 1) * gap) // rows
    img = gradient(width, height, (13, 15, 18), FORGED)
    draw = ImageDraw.Draw(img)
    gold_rule(draw, width, 0, 3)
    gold_rule(draw, width, height - 5, 3)
    title_face = font(CINZEL, 40)
    body_face = font(BODY, 33)
    for i, (picture, title, line1, line2) in enumerate(CARDS):
        col, row = i % cols, i // cols
        x = margin + col * (cw + gap)
        y = margin + row * (ch + gap)
        draw.rounded_rectangle([x, y, x + cw, y + ch], radius=18, fill=SLAB_TOP,
                               outline=EDGE, width=2)
        thumb_h = 300
        src = Image.open(README_MEDIA / picture).convert("RGB")
        thumb = cover(src, cw - 24, thumb_h, focus_y=0.5)
        mask = Image.new("L", thumb.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, thumb.width, thumb.height], radius=12, fill=255)
        img.paste(thumb, (x + 12, y + 12), mask)
        draw = ImageDraw.Draw(img)
        draw.rectangle([x + 28, y + thumb_h + 28, x + 96, y + thumb_h + 31], fill=GILT)
        face, tracking = fit_tracked(draw, title, CINZEL, 40, 0.04, cw - 56)
        tracked(draw, (x + 28, y + thumb_h + 46), title, face, EMPHASIS, tracking)
        draw.text((x + 28, y + thumb_h + 118), line1, font=body_face, fill=TEXT)
        draw.text((x + 28, y + thumb_h + 164), line2, font=body_face, fill=MUTED)
    return save(img, "feature-cards.jpg", quality=80)


def build_pages():
    master = MASTER.read_text(encoding="utf-8").strip("\n")
    readme = README_HEADER + master.replace("\n## FAQ\n", ICON_NOTE + "\n## FAQ\n", 1) + "\n"
    (ROOT / "README.md").write_text(readme, encoding="utf-8", newline="\n")
    for rel in ("docs/store/curseforge.md", "docs/store/wago.md"):
        path = ROOT / rel
        text = path.read_text(encoding="utf-8")
        start = text.index("```markdown\n") + len("```markdown\n")
        end = text.index("\n```", start)
        path.write_text(text[:start] + master + text[end:], encoding="utf-8", newline="\n")
    print("pages regenerated from docs/store/description.md")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--pages", action="store_true", help="also regenerate the three pages")
    args = parser.parse_args(argv)
    make_banner()
    for name, title, subtitle in HEADERS:
        make_header(name, title, subtitle)
    make_cards()
    if args.pages:
        build_pages()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
