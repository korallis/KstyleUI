"""Make KstyleUI's branded marketing images, and splice the master store description.

    python3 Tools/media/marketing.py            # write docs/media/marketing/* and the store gallery
    python3 Tools/media/marketing.py --pages    # also regenerate README.md and the
                                                # CurseForge/Wago description blocks
                                                # from docs/store/description.md
    python3 Tools/media/marketing.py --clips [NAME ...]   # also render the highlight clips (LuaJIT, Chrome);
                                                          # map.gif needs RENDER_MAP_ART, the client's Kalimdor map art

Images only use the addon's own OFL fonts (Media/Fonts), its procedural logo
(Tools/media/make_media.py), the colours in Core/Tokens.lua, the in-game /
test-render pictures already in docs/media/readme and the clips' test renders
over the real plates in docs/media/plates. No AI and no game art is created
here; the in-game crop is the addon's own screenshot, darkened.
"""

import argparse
import importlib.util
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
README_MEDIA = ROOT / "docs" / "media" / "readme"
OUT = ROOT / "docs" / "media" / "marketing"
FONTS = ROOT / "Media" / "Fonts"
MASTER = ROOT / "docs" / "store" / "description.md"
PLATES = ROOT / "docs/media/plates"
# Store gallery uploads, in order: (file, source under docs/media, width or None to copy).
GALLERY = [
    ("01-medallions-hero.jpg", "readme/game_medallions_hero.jpg", 2560),
    ("02-classes.gif", "marketing/classes.gif", None),
    ("03-crowns.gif", "marketing/crowns.gif", None),
    ("04-crowns-more.gif", "marketing/crowns-more.gif", None),
    ("05-shaman.gif", "marketing/shaman.gif", None),
    ("06-hawks.gif", "marketing/hawks.gif", None),
    ("07-hud.jpg", "readme/hud_1080.jpg", None),
    ("08-frames.jpg", "readme/hud_frames_1080.jpg", None),
    ("09-rest.gif", "marketing/rest.gif", None),
    ("10-casts.gif", "marketing/casts.gif", None),
    ("11-map.gif", "marketing/map.gif", None),
    ("12-trackers.gif", "marketing/trackers.gif", None),
    ("13-frames-medals.jpg", "readme/frames_medals.jpg", None),
]

# Core/Tokens.lua colours.
FORGED = (16, 18, 17)        # materialForged 101211
SLAB_TOP = (21, 23, 28)      # slabTop 15171c
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

PITCH = "One dark forged look for the whole game."
PITCH2 = "Run the setup once and play."

# Narrow crops framed at banner width so every picture fills the page column.
SHOWCASES = [
    ("show_hud_1080.jpg", "hud_1080.jpg"),
    ("show_hud_finish.jpg", "hud_finish.jpg"),
    ("show_hud_frames_1080.jpg", "hud_frames_1080.jpg"),
    ("show_frame_raid.jpg", "frame_raid.jpg"),
    ("show_frames_medals.jpg", "frames_medals.jpg"),
]

# Highlight clips (--clips): 1920x1080 class HUD scenes rendered at CLIP_PPU over the real forest plate, cut to a box
# in screen units (x, y, width, height). A shot is (scene, env, clock variable, times in seconds, hold in ms): one
# frame per time, FRAME_MS apart, the last held hold ms longer.
CLIP_PPU, FRAME_MS, CLIP_WIDTH = 2, 70, 768
CLIP_ENV = {"RENDER_SCREEN": "1920x1080", "RENDER_SIZE": "auto", "RENDER_LAYOUT": "DPS"}
CREST, STRIP = (768, 845, 384, 222), (540, 800, 840, 266)


def times(start, stop, step=FRAME_MS / 1000):
    return [round(start + i * step, 3) for i in range(round((stop - start) / step) + 1)]


def climb(scene, top, env=None, gain=0.35, peak=0.56, spend=True):
    """Shots for combo points or stacks from 0 to top one at a time, the maximum, then (spend) back to 0."""
    env, clock = env or {}, "RENDER_PIPS_T"
    shots = [(scene, {**env, "RENDER_PIPS": "0,0"}, clock, [1], 400)]
    shots += [(scene, {**env, "RENDER_PIPS": f"{n - 1},{n}"}, clock, times(0, gain), 100) for n in range(1, top + 1)]
    shots.append((scene, {**env, "RENDER_PIPS": f"{top},{top}"}, clock, times(0, peak), 500))
    if spend:
        shots.append((scene, {**env, "RENDER_PIPS": f"{top},0"}, clock, times(0, 0.49), 600))
    return shots


def story(scene, env, clock, beats, fast):
    """Shots for a story played at full speed through each (start, stop, hold) beat, fast seconds a frame between."""
    shots, last = [], None
    for start, stop, hold in beats:
        if last is not None:
            shots.append((scene, env, clock, times(last + fast, start - fast, fast), 0))
        shots.append((scene, env, clock, times(start, stop), hold))
        last = stop
    return [shot for shot in shots if shot[3]]


CLIPS = {
    "classes.gif": (STRIP, [(scene, env, None, [0], 630) for scene, env in (
        ("hud_rogue_mac", {"RENDER_PIPS": "5,5", "RENDER_PIPS_T": "1"}),
        ("hud_shaman_mac", {"RENDER_TOTEMS": "story", "RENDER_TOTEMS_T": "8", "RENDER_FX": "storm", "RENDER_FX_T": "2.5"}),
        ("hud_warrior_mac", {"RENDER_PIPS": "5,5", "RENDER_PIPS_T": "1"}),
        ("hud_druid_mac", {"RENDER_PIPS": "5,5", "RENDER_PIPS_T": "1"}),
        ("hud_hunter_mac", {"RENDER_FX": "hawks", "RENDER_FX_T": "10"}),
        ("hud_paladin_mac", {"RENDER_FOREVER_POWERS": "1"}),
        ("hud_mage_mac", {"RENDER_PIPS": "4,4", "RENDER_PIPS_T": "1"}),
        ("hud_priest_mac", {"RENDER_PIPS": "5,5", "RENDER_PIPS_T": "1"}),
        ("hud_warlock_mac", {"RENDER_FOREVER_POWERS": "1"}),
    )]),
    "crowns.gif": (CREST, climb("hud_rogue_mac", 5) + climb("hud_druid_mac", 5)),
    "crowns-more.gif": (CREST, [shot for scene, top, env in (
        ("hud_warrior_mac", 5, {}), ("hud_priest_mac", 5, {}), ("hud_mage_mac", 4, {}),
        ("hud_hunter_mac", 3, {}), ("hud_druid_mac", 5, {"RENDER_FORM": "bear"}),
    ) for shot in climb(scene, top, env, gain=0.21, peak=0.28, spend=False)]),
    "shaman.gif": (CREST, story("hud_shaman_mac", {"RENDER_TOTEMS": "story"}, "RENDER_TOTEMS_T", [
        (0.3, 0.3, 400), (0.5, 0.71, 0), (1.0, 1.0, 500), (1.5, 1.71, 0), (2.0, 2.42, 400), (6.0, 6.56, 900),
    ], 1) + story("hud_shaman_mac", {"RENDER_FX": "storm"}, "RENDER_FX_T", [
        (0.9, 1.6, 0), (4.4, 5.0, 0), (11.4, 12.3, 700),
    ], 0.56)),
    "hawks.gif": (CREST, story("hud_hunter_mac", {"RENDER_FX": "hawks"}, "RENDER_FX_T", [
        (0.5, 0.5, 300), (0.9, 1.6, 0), (8.9, 9.6, 300), (18.9, 19.45, 0), (20.4, 21.1, 700),
    ], 0.7)),
    "trackers.gif": (CREST, [shot for scene, env, beats in (
        ("hud_warrior_mac", {}, [(0.1, 0.1, 300), (0.5, 0.64, 300), (3.0, 3.28, 300), (9.0, 9.21, 700)]),
        ("hud_druid_mac", {"RENDER_FORM": "bear"}, [(0.1, 0.1, 300), (0.5, 0.57, 250), (1.0, 1.07, 250), (1.5, 1.71, 250),
                                                     (2.0, 2.07, 250), (2.5, 2.57, 250), (3.0, 3.14, 900)]),
        ("hud_priest_mac", {}, [(0.1, 0.1, 300), (0.5, 0.71, 250), (1.5, 1.57, 250), (2.0, 2.14, 250), (2.5, 2.57, 300),
                                (4.6, 4.67, 300), (5.8, 5.87, 700)]),
        ("hud_warlock_mac", {}, [(0.1, 0.1, 300), (1.0, 1.07, 250), (2.0, 2.07, 250), (3.0, 3.07, 250), (3.5, 3.57, 250),
                                 (4.0, 4.07, 250), (5.0, 5.21, 300), (6.0, 6.14, 900)]),
    ) for shot in story(scene, {"RENDER_TRACKERS": "moment", **env}, "RENDER_TRACKERS_T", beats, 1)]),
    "rest.gif": ((468, 792, 984, 270), [
        ("hud_reference", {"RENDER_REST": "rest"}, "RENDER_REST_T", [0], 800),
        ("hud_reference", {"RENDER_REST": "rest"}, "RENDER_REST_T", times(0.07, 0.63), 1400),
        ("hud_reference", {"RENDER_REST": "target"}, "RENDER_REST_T", times(0.07, 0.21), 1600),
    ]),
    "casts.gif": ((1036, 886, 330, 92), [("hud_rogue_mac", {"RENDER_CAST_CUES": cue}, "RENDER_CAST_CUES_T", ts, hold)
                                         for cue, ts, hold in (("aimed", times(0, 0.28), 700), ("you", times(0, 0.28), 900),
                                                               ("locked", times(0, 0.28), 900), ("wait", times(0, 0.63), 1100))]),
    "map.gif": ((280, 275, 698, 531), [("worldmap_roads", {"RENDER_MAP_WIDE": "1", "RENDER_MAP_TRIP": "zeppelin", **env}, None, [0], 2400)
                                       for env in ({}, {"RENDER_MAP_SERVICES": "1"})]),
}

README_HEADER = """<p align="center">
<a href="https://github.com/korallis/KstyleUI/releases/latest"><img src="https://img.shields.io/github/v/release/korallis/KstyleUI?label=Download%20the%20latest%20release" alt="Download the latest KstyleUI release from GitHub"></a>
<a href="https://www.curseforge.com/wow/addons/kstyleui"><img src="https://img.shields.io/badge/CurseForge-KstyleUI-F16436?logo=curseforge&logoColor=white" alt="KstyleUI on CurseForge"></a>
<a href="https://addons.wago.io/addons/kstyleui"><img src="https://img.shields.io/badge/Wago-KstyleUI-C1272D" alt="KstyleUI on Wago Addons"></a>
</p>

"""

README_FOOTER = """
## For developers

The code, the tests and how to build and render everything are in [docs/DEVELOPING.md](https://github.com/korallis/KstyleUI/blob/main/docs/DEVELOPING.md).
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


def rounded_paste(img, thumb, xy, radius=14):
    from PIL import Image, ImageDraw
    mask = Image.new("L", thumb.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, thumb.width, thumb.height], radius=radius, fill=255)
    img.paste(thumb, xy, mask)
    ImageDraw.Draw(img).rounded_rectangle(
        [xy[0], xy[1], xy[0] + thumb.width, xy[1] + thumb.height], radius=radius, outline=EDGE, width=2)


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


def clip_frame(work, scene, env, box, standins):
    """One clip frame, rendered fresh and strict over the real forest plate, cut to box."""
    out, plate = Path(tempfile.mkdtemp(dir=work)), (PLATES / "forest-1080.jpg").as_posix()
    cmd = ["bash", "Tools/render/shoot.sh", scene, "--strict", "--ppu", str(CLIP_PPU), "--backdrop", plate,
           "--out", (out / "frame.png").as_posix()] + ([] if standins else ["--no-standins"])
    run = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                         env={**os.environ, **CLIP_ENV, **env, "RENDER_OUTDIR": out.as_posix(), "KSTYLEUI_PLATE": plate})
    if run.returncode:
        raise SystemExit(f"{scene} {env}: shoot.sh exited {run.returncode}\n{run.stdout[-3000:]}{run.stderr[-3000:]}")
    from PIL import Image
    x, y, w, h = (round(v * CLIP_PPU) for v in box)
    with Image.open(out / "frame.png") as image:
        return image.convert("RGB").crop((x, y, x + w, y + h))


def write_gif(path, frames, durations):
    """One palette for the whole clip, so colours hold still from frame to frame."""
    from PIL import Image
    sample = frames[::max(1, len(frames) // 24)]
    stack = Image.new("RGB", (frames[0].width, frames[0].height * len(sample)))
    for i, frame in enumerate(sample):
        stack.paste(frame, (0, i * frame.height))
    palette = stack.quantize(colors=255, method=Image.Quantize.FASTOCTREE)  # median cut turns a few frames' red bar brown
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    indexed[0].save(path, save_all=True, append_images=indexed[1:], duration=durations, loop=0, optimize=True, disposal=1)


def make_clip(name):
    """Render a clip's frames (two at a time) and write it as a GIF on the showcase's forged ground."""
    from concurrent.futures import ThreadPoolExecutor
    from PIL import Image, ImageDraw
    box, shots = CLIPS[name]
    if name == "map.gif" and not os.environ.get("RENDER_MAP_ART"):
        raise SystemExit("map.gif: set RENDER_MAP_ART to the client's Kalimdor map art")
    jobs = [(scene, {**env, **({clock: str(t)} if clock else {})}) for scene, env, clock, ts, _ in shots for t in ts]
    with tempfile.TemporaryDirectory() as work:
        crops = [clip_frame(work, *jobs[0], box, True)]
        with ThreadPoolExecutor(2) as pool:
            crops += pool.map(lambda job: clip_frame(work, *job, box, False), jobs[1:])
    durations = [FRAME_MS + (hold if i == len(ts) - 1 else 0) for _, _, _, ts, hold in shots for i in range(len(ts))]
    pad, label = 16, 34
    height = round(box[3] * CLIP_WIDTH / box[2])
    ground = gradient(CLIP_WIDTH + 2 * pad, height + pad + label, SLAB_TOP, FORGED)
    draw = ImageDraw.Draw(ground)
    gold_rule(draw, ground.width, 0, 2)
    gold_rule(draw, ground.width, ground.height - 4, 2)
    source_label(draw, (pad, height + pad + 5), name, size=18)
    frames = []
    for crop in crops:
        frame = ground.copy()
        rounded_paste(frame, crop.resize((CLIP_WIDTH, height), Image.LANCZOS), (pad, pad), radius=10)
        frames.append(frame)
    write_gif(OUT / name, frames, durations)
    print(f"{name} {ground.width}x{ground.height} {len(frames)} frames {sum(durations) / 1000:.1f} s "
          f"{(OUT / name).stat().st_size} bytes")


def make_gallery():
    from PIL import Image
    out = ROOT / "docs/store/gallery"
    for old in out.glob("*.*"):
        old.unlink()
    for name, source, width in GALLERY:
        if width:
            with Image.open(ROOT / "docs/media" / source) as image:
                image.resize((width, round(image.height * width / image.width)), Image.Resampling.LANCZOS).save(
                    out / name, quality=87, optimize=True, progressive=True)
        else:
            shutil.copyfile(ROOT / "docs/media" / source, out / name)
        print("gallery/" + name)
    for store in ("curseforge.md", "wago.md"):
        path = ROOT / "docs/store" / store
        text = path.read_text(encoding="utf-8")
        for name, _, _ in GALLERY:
            with Image.open(out / name) as image:
                size = f"{image.width}×{image.height}"
            text = re.sub(r"(\| `gallery/" + re.escape(name) + r"` \| )[^|]+", r"\g<1>" + size + " ", text)
        path.write_text(text, encoding="utf-8", newline="\n")


def build_pages():
    master = MASTER.read_text(encoding="utf-8").strip("\n")
    (ROOT / "README.md").write_text(README_HEADER + master + "\n" + README_FOOTER, encoding="utf-8", newline="\n")
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
    parser.add_argument("--clips", nargs="*", metavar="NAME", help="render these clips (all when none is named)")
    args = parser.parse_args(argv)
    if args.clips is not None:
        for name in args.clips or CLIPS:
            make_clip(name)
    make_banner()
    for name, picture in SHOWCASES:
        make_showcase(name, picture)
    make_gallery()
    if args.pages:
        build_pages()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
