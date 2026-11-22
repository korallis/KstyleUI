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
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
README_MEDIA = ROOT / "docs" / "media" / "readme"
OUT = ROOT / "docs" / "media" / "marketing"
FONTS = ROOT / "Media" / "Fonts"
MASTER = ROOT / "docs" / "store" / "description.md"
PLATES = ROOT / "docs/media/plates"
GALLERY = [
    ("01-medallions-hero.jpg", "game_medallions_hero.jpg", 2560),
    ("02-medallions-combat.jpg", "game_medallions_16x9.jpg", None),
    ("03-ultrawide-spread.jpg", "ultrawide_spread.jpg", None),
    ("04-setup.jpg", "frame_setup.jpg", None),
    ("05-nameplates.jpg", "crop_nameplates.jpg", None),
    ("06-meter.jpg", "crop_meter.jpg", None),
    ("07-quests.jpg", "crop_rail.jpg", None),
    ("08-medallion-closeup.gif", "game_medallions_target.gif", None),
    ("09-frames-combat.jpg", "hud_frames_1080.jpg", None),
]

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

PITCH = "Dark forged chrome for the whole game."
PITCH2 = "One HUD. One setup. Every screen."

HEADERS = [
    ("header-discord.jpg", "JOIN THE DISCORD", "Help, bug reports, release news and UI sharing - discord.gg/A5qqGZEXyN"),
    ("header-medallions.jpg", "MEDALLIONS", "Painted portraits, your class crest and one forged slab"),
    ("header-every-screen.jpg", "EVERY SCREEN", "Pixel-perfect from a laptop to a 32:9 ultrawide"),
    ("header-set-up.jpg", "SET UP IN ONE WINDOW", "One short setup, then you are playing"),
    ("header-rest-of-your-ui.jpg", "THE REST OF YOUR UI", "Nameplates, meter, map, bags, tooltips and window skins"),
    ("header-make-it-yours.jpg", "MAKE IT YOURS", "Deep settings for every part, each with a live preview"),
]

# One image per card, stacked in the markdown, so each stays readable on a phone.
CARDS = [
    ("card-medallions.jpg", "game_medallions_closeup.jpg", "Medallions",
     "Painted portraits and your class crest.", "One forged slab for your bars."),
    ("card-pixel-perfect.jpg", "hud_1080.jpg", "Pixel-perfect sizing",
     "Every edge lands on whole pixels.", "A readable text floor from 1080 lines up."),
    ("card-ultrawide.jpg", "ultrawide_spread.jpg", "Ultrawide ready",
     "Centred or Spread on 21:9 and 32:9.", "Nothing stranded at the edges."),
    ("card-ready-in-minutes.jpg", "frame_setup.jpg", "Ready in minutes",
     "One setup: layout and modules.", "DPS, Tank and Healer layouts built in."),
    ("card-full-kit.jpg", "crop_meter.jpg", "The full kit",
     "Meter, nameplates, bags, tooltips.", "One style across the whole game."),
    ("card-nothing-extra.jpg", "frame_skins.jpg", "Nothing you don't want",
     "Every feature is its own module.", "Switch one off and it costs nothing."),
]

# Narrow crops framed at banner width so every picture fills the page column.
SHOWCASES = [
    ("show_crop_unitframes.jpg", "crop_unitframes.jpg"),
    ("show_frame_setup.jpg", "frame_setup.jpg"),
    ("show_frame_raid.jpg", "frame_raid.jpg"),
    ("show_crop_nameplates.jpg", "crop_nameplates.jpg"),
    ("show_crop_meter.jpg", "crop_meter.jpg"),
    ("show_crop_meters_both.jpg", "crop_meters_both.jpg"),
    ("show_crop_rail.jpg", "crop_rail.jpg"),
    ("show_crop_crest.jpg", "crop_crest.jpg"),
    ("show_crop_dock.jpg", "crop_dock.jpg"),
    ("show_crop_route.jpg", "crop_route.jpg"),
    ("show_frame_skins.jpg", "frame_skins.jpg"),
]

# The icon pack before-and-after: one action bar row from the hud_reference render, Blizzard's icons
# then the pack's. Its crops live in Tools/render/out (icons_before.png, icons_after.png), cut from
# that render and the same scene with the icon sources swapped to the Blizzard extract cache; a
# machine without them keeps the committed image.
COMPARE = ["icons-before-after.jpg"]

# (file, frame step, width, colours, posterize step) for clips over the size cap.
GIF_SPECS = [
    ("game_medallions_target.gif", 1, 800, 48, 8),
    ("game_medallions_cast.gif", 2, 880, 80, 4),
]
GIF_CAP = 1_000_000

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


def source_label(draw, xy, picture, size=30):
    label = "In-game screenshot" if picture.startswith("game_") else "KstyleUI test render over an in-game screenshot"
    draw.text(xy, label, font=font(BODY, size), fill=MUTED)


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
    draw.text((x + 4, 398), PITCH, font=font(BODY_BOLD, 54), fill=GILT_LIT)
    draw.text((x + 4, 468), PITCH2, font=font(BODY, 48), fill=TEXT)
    source_label(draw, (x + 4, 556), "game_medallions_hero.jpg")
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


def rounded_paste(img, thumb, xy, radius=14):
    from PIL import Image, ImageDraw
    mask = Image.new("L", thumb.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, thumb.width, thumb.height], radius=radius, fill=255)
    img.paste(thumb, xy, mask)
    ImageDraw.Draw(img).rounded_rectangle(
        [xy[0], xy[1], xy[0] + thumb.width, xy[1] + thumb.height], radius=radius, outline=EDGE, width=2)


def make_card(name, picture, title, line1, line2):
    from PIL import Image, ImageDraw
    width, height = 1600, 1010
    img = gradient(width, height, (13, 15, 18), FORGED)
    draw = ImageDraw.Draw(img)
    gold_rule(draw, width, 0, 3)
    gold_rule(draw, width, height - 5, 3)
    draw.rounded_rectangle([40, 40, width - 40, height - 40], radius=22, fill=SLAB_TOP,
                           outline=EDGE, width=2)
    src = Image.open(README_MEDIA / picture).convert("RGB")
    thumb = cover(src, width - 128, 520, focus_y=0.5)
    rounded_paste(img, thumb, (64, 64))
    draw = ImageDraw.Draw(img)
    x, y = 88, 64 + 520
    draw.rectangle([x, y + 36, x + 110, y + 40], fill=GILT)
    face, tracking = fit_tracked(draw, title, CINZEL, 68, 0.04, width - 2 * x)
    tracked(draw, (x, y + 58), title, face, EMPHASIS, tracking)
    draw.text((x, y + 162), line1, font=font(BODY, 54), fill=TEXT)
    draw.text((x, y + 232), line2, font=font(BODY, 54), fill=MUTED)
    source_label(draw, (x, y + 322), picture)
    return save(img, name, quality=84)


def make_showcase(name, picture):
    from PIL import Image, ImageDraw, ImageFilter
    src = Image.open(README_MEDIA / picture).convert("RGB")
    width, pad, max_scale = 2048, 96, 2.6
    scale = min((width - 2 * pad) / src.width, 1150 / src.height, max_scale)
    thumb = src.resize((round(src.width * scale), round(src.height * scale)), Image.LANCZOS)
    thumb = thumb.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    height = thumb.height + 2 * pad
    img = gradient(width, height, SLAB_TOP, FORGED)
    draw = ImageDraw.Draw(img)
    gold_rule(draw, width, 0, 3)
    gold_rule(draw, width, height - 5, 3)
    rounded_paste(img, thumb, ((width - thumb.width) // 2, pad), radius=16)
    source_label(ImageDraw.Draw(img), (pad, height - 60), picture)
    return save(img, name, quality=82)


def make_icons_compare():
    from PIL import Image, ImageDraw
    crops = [ROOT / "Tools/render/out" / name for name in ("icons_before.png", "icons_after.png")]
    if not all(path.is_file() for path in crops):
        print("icons-before-after.jpg kept (no crops in Tools/render/out)")
        return
    width = 1600
    rows = []
    for path in crops:
        row = Image.open(path).convert("RGB")
        rows.append(row.resize((width - 128, round(row.height * (width - 128) / row.width)), Image.LANCZOS))
    height = 64 + 120 + sum(56 + row.height for row in rows) + 128
    img = darken(cover(Image.open(PLATES / "forest-1080.jpg").convert("RGB"), width, height), 0.35)
    draw = ImageDraw.Draw(img)
    gold_rule(draw, width, 0, 3)
    gold_rule(draw, width, height - 5, 3)
    draw.rounded_rectangle([40, 40, width - 40, height - 40], radius=22, fill=SLAB_TOP,
                           outline=EDGE, width=2)
    x, y = 88, 64
    draw.rectangle([x, y + 8, x + 110, y + 12], fill=GILT)
    face, tracking = fit_tracked(draw, "KstyleUI Icons", CINZEL, 68, 0.04, width - 2 * x)
    tracked(draw, (x, y + 30), "KstyleUI Icons", face, EMPHASIS, tracking)
    y += 120
    for label, row in zip(("Blizzard's icons", "With the pack"), rows):
        draw.text((x, y), label, font=font(BODY_BOLD, 40), fill=GILT_LIT)
        y += 56
        rounded_paste(img, row, (64, y))
        y += row.height
    source_label(draw, (x, y + 28), "hud_1080.jpg")
    return save(img, COMPARE[0], quality=84)


def make_gallery():
    from PIL import Image
    out = ROOT / "docs/store/gallery"
    out.mkdir(parents=True, exist_ok=True)
    for name, source, width in GALLERY:
        if width:
            with Image.open(README_MEDIA / source) as image:
                image.resize((width, round(image.height * width / image.width)), Image.Resampling.LANCZOS).save(
                    out / name, quality=87, optimize=True, progressive=True)
        else:
            shutil.copyfile(README_MEDIA / source, out / name)
        print("gallery/" + name)
    for store in ("curseforge.md", "wago.md"):
        path = ROOT / "docs/store" / store
        text = path.read_text(encoding="utf-8")
        for name, _, _ in GALLERY:
            with Image.open(out / name) as image:
                size = f"{image.width}×{image.height}"
            text = re.sub(r"(\| `gallery/" + re.escape(name) + r"` \| )[^|]+", r"\g<1>" + size + " ", text)
        path.write_text(text, encoding="utf-8", newline="\n")


def recompress_gif(name, step, width, colours, poster):
    """Shrink an oversized clip: fewer frames (same duration), narrower, one shared
    palette, unchanged pixels stored as transparent."""
    from PIL import Image, ImageChops
    path = README_MEDIA / name
    if path.stat().st_size <= GIF_CAP:
        return
    src = Image.open(path)
    frames, durations = [], []
    for i in range(src.n_frames):
        src.seek(i)
        durations.append(src.info.get("duration", 60))
        frames.append(src.convert("RGB"))
    frames = frames[::step]
    durations = [sum(durations[i:i + step]) for i in range(0, len(frames) * step, step)][:len(frames)]
    height = round(frames[0].height * width / frames[0].width)
    frames = [f.resize((width, height), Image.LANCZOS) for f in frames]
    if poster > 1:
        frames = [f.point(lambda v: v // poster * poster) for f in frames]
    tile = Image.new("RGB", (width * 2, height * 2))
    for j, fi in enumerate((0, len(frames) // 3, 2 * len(frames) // 3, len(frames) - 1)):
        tile.paste(frames[fi], ((j % 2) * width, (j // 2) * height))
    palette = tile.quantize(colors=colours - 1, method=Image.MEDIANCUT)
    indexed = [f.quantize(colors=colours - 1, palette=palette, dither=Image.Dither.NONE)
               for f in frames]
    out, prev = [indexed[0]], indexed[0]
    blank = Image.new("P", indexed[0].size, colours - 1)
    blank.putpalette(indexed[0].getpalette())
    for frame in indexed[1:]:
        a = Image.frombytes("L", frame.size, prev.tobytes())
        b = Image.frombytes("L", frame.size, frame.tobytes())
        mask = ImageChops.difference(a, b).point(lambda v: 0 if v else 255)
        delta = Image.composite(blank, frame, mask)
        delta.putpalette(frame.getpalette())
        out.append(delta)
        prev = frame
    out[0].save(path, save_all=True, append_images=out[1:], duration=durations, loop=0,
                optimize=True, transparency=colours - 1, disposal=[0] + [1] * (len(out) - 1))
    print(f"{name} recompressed to {path.stat().st_size} bytes")


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
    for card in CARDS:
        make_card(*card)
    for name, picture in SHOWCASES:
        make_showcase(name, picture)
    make_icons_compare()
    for spec in GIF_SPECS:
        recompress_gif(*spec)
    make_gallery()
    if args.pages:
        build_pages()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
