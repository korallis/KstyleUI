#!/usr/bin/env python3
"""readme.py: retake every picture the README shows from the render scenes, in one command.

    python3 Tools/render/readme.py [--work DIR] [--no-render] [--only NAME ...]

Run it from the repository root with luajit and Google Chrome installed. It renders the scenes into
Tools/render/out (as shoot.sh always does), cuts them into DIR (default ~/.capy/work/readme-renders), and writes the
finished PNGs to docs/media/readme/, where README.md reads them. Every render draws at the game's defaults:
RENDER_ORNAMENTS=Full, because Full is the shipped default while a scene draws Off unless told. None of the pictures
is a game screenshot; each README caption says it is a test render.

The pictures:

  hud_dps, hud_tank, hud_healer   the whole HUD of each layout preset, hud_reference at 3456x2234, scaled to HUD_WIDTH
  ornaments_strip                 the same HUD region at Off, Subtle and Full, side by side
  card_materials                  one card at each of the five card materials
  settings_*, setup_ornaments     the settings window's General page and the setup's ornament step
  merit_*, tile_*, class_*        every other picture the README shows, cut from the gallery and class scenes

The gallery, class and Lumen scenes draw over a flat colour, not over the mockup's scenery, so the PNGs stay small and
none reads as a game frame. The gallery and class cuts still read the handoff mockup for their reference crops (see
gallery.py). --no-render reuses the renders a previous run left in Tools/render/out and DIR. --only redoes the named
pictures. Pillow is needed; the script runs itself again with the wow-dev virtual environment's Python when this one
has none.
"""

import argparse
import os
import subprocess
import sys

VENV_PYTHON = os.path.expanduser("~/.local/share/wow-dev/venv/bin/python")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "docs", "media", "readme")
DEFAULT_WORK = os.path.expanduser("~/.capy/work/readme-renders")

SCREEN = (3456, 2234)
HUD_PPU = SCREEN[1] / 1080
GALLERY_PPU = 2.0
LAYOUTS = ("DPS", "Tank", "Healer")
LEVELS = ("Off", "Subtle", "Full")
MATERIALS = ("ForgedBrackets", "ForgedTicks", "Slate", "Flat", "Glass")
CLASSES = ("druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior")

HUD_WIDTH = 1800
BUDGET_BYTES = 6 * 1024 * 1024

# The HUD region the strip crops, in physical pixels of the 3456x2234 render (x, y, width, height): the cast bar, the
# cooldown row, both unit frames, the action bars and the experience bar of the centre column.
STRIP_BOX = (1200, 1480, 1100, 750)
# The chat card in the left rail, the card the materials sheet shows.
CARD_BOX = (20, 1870, 710, 345)

GALLERIES = (
    "gallery_skins_character", "gallery_skins_spellbook", "gallery_groupframes", "gallery_setup",
    "gallery_nameplates_pull", "gallery_unitframes", "gallery_cooldowns", "gallery_auras", "gallery_minimap",
    "gallery_chat", "gallery_bags", "gallery_meters", "gallery_layout", "gallery_options",
)

# name, source, crop, width. A source is "hud:<layout>", "frame:<frame name>", "lumen_combat" or "class:<class>"; a
# crop is "WxH+X+Y" in the source's pixels, "cover" (a centred 16:10 window hung from the top edge, the shape every
# tile in the README's grid shares) or None. A picture narrower than its width stays as it is.
IMAGES = [
    ("merit_skins", "frame:skins_character", None, 560),
    ("merit_combat", "lumen_combat", "1860x740+620+1420", 720),
    ("merit_raid", "frame:groupframes_raid", None, 720),
    ("merit_setup", "frame:setup_layouts", None, 720),
    ("merit_plates", "frame:nameplates_pull", None, 720),
    ("merit_rail", "hud:DPS", "916x990+2540+20", 560),
    ("settings_type", "frame:options_appearance", None, 720),
    ("settings_ornaments", "frame:options_ornaments", None, 720),
    ("setup_ornaments", "frame:setup_ornaments", None, 720),
    ("tile_unitframes", "frame:unitframes_preview", "cover", 440),
    ("tile_groupframes", "frame:groupframes_party", "cover", 440),
    ("tile_actionbars", "lumen_combat", "1066x477+1164+1683", 440),
    ("tile_cooldowns", "frame:cooldowns_preview", "cover", 440),
    ("tile_auras", "frame:auras_preview", "cover", 440),
    ("tile_nameplates", "frame:nameplates_pull", "850x531+0+0", 440),
    ("tile_minimap", "frame:minimap_preview", "cover", 440),
    ("tile_chat", "frame:chat_preview", "cover", 440),
    ("tile_bags", "frame:bags_window", "cover", 440),
    ("tile_meters", "frame:meters_damage", "cover", 440),
    ("tile_skins", "frame:skins_spellbook", "cover", 440),
    ("tile_layout", "frame:layout_plates", "cover", 440),
] + [("class_" + name, "class:" + name, "2060x701+40+154", 440) for name in CLASSES]

COMPOSED = ("hud_dps", "hud_tank", "hud_healer", "ornaments_strip", "card_materials")

Image = None


def pillow():
    """Import Pillow, or run again under the wow-dev venv when this Python has none."""
    global Image
    if Image is not None:
        return True
    try:
        from PIL import Image as image
    except ImportError:  # pragma: no cover - depends on the machine
        venv_root = os.path.dirname(os.path.dirname(VENV_PYTHON))
        if os.path.exists(VENV_PYTHON) and os.path.realpath(sys.prefix) != os.path.realpath(venv_root):
            os.execv(VENV_PYTHON, [VENV_PYTHON, "-I", *sys.argv])
        return False
    Image = image
    return True


def picture_names():
    return list(COMPOSED) + [name for name, _, _, _ in IMAGES]


def cover_box(width, height):
    """A centred 16:10 window hung from the top edge, never larger than the frame: (left, top, right, bottom)."""
    crop_w, crop_h = width, width * 10 // 16
    if crop_h > height:
        crop_h, crop_w = height, height * 16 // 10
    left = (width - crop_w) // 2
    return left, 0, left + crop_w, crop_h


def parse_crop(spec):
    """'WxH+X+Y' as (left, top, right, bottom)."""
    size, left, top = spec.split("+")
    width, height = size.split("x")
    return int(left), int(top), int(left) + int(width), int(top) + int(height)


def fit_width(width, height, limit):
    """The size at a width limit; a picture already narrower keeps its size."""
    if width <= limit:
        return width, height
    return limit, max(1, round(height * limit / width))


def run(cmd, env=None):
    """Run one command from the repository root with the render environment; raises on failure."""
    full = dict(os.environ)
    full.update(env or {})
    subprocess.run(cmd, check=True, cwd=ROOT, env=full)


def shoot(scene, env, out=None, *args):
    cmd = ["bash", "Tools/render/shoot.sh", scene, *args]
    if "--ppu" not in args:
        cmd += ["--ppu", str(GALLERY_PPU)]
    if out:
        cmd += ["--out", out]
    run(cmd, env)


def render_all(work, wanted):
    """Render every scene the wanted pictures need, one process at a time."""
    os.makedirs(work, exist_ok=True)
    full = {"RENDER_ORNAMENTS": "Full"}
    hud = dict(full, RENDER_SCREEN="%dx%d" % SCREEN)
    ppu = ("--strict", "--ppu", repr(HUD_PPU))
    sources = {source.split(":")[0] if source.startswith(("frame:", "class:")) else source
               for name, source, _, _ in IMAGES if name in wanted}
    layouts = set()
    if "hud_dps" in wanted or "ornaments_strip" in wanted or "merit_rail" in wanted:
        layouts.add("DPS")
    if "hud_tank" in wanted:
        layouts.add("Tank")
    if "hud_healer" in wanted:
        layouts.add("Healer")
    for layout in sorted(layouts):
        shoot("hud_reference", dict(hud, RENDER_LAYOUT=layout), os.path.join(work, "hud_%s.png" % layout), *ppu)
    if "ornaments_strip" in wanted:
        for level in ("Off", "Subtle"):
            shoot("hud_reference", dict(hud, RENDER_LAYOUT="DPS", RENDER_ORNAMENTS=level),
                  os.path.join(work, "level_%s.png" % level), *ppu)
    if "card_materials" in wanted:
        for material in MATERIALS:
            shoot("hud_reference", dict(hud, RENDER_LAYOUT="DPS", RENDER_CARD_MATERIAL=material),
                  os.path.join(work, "material_%s.png" % material), *ppu)
    if "lumen_combat" in sources:
        shoot("hud_lumen_combat", full, os.path.join(work, "lumen_combat.png"))
    if any(source.startswith("frame:") and not source.endswith("_ornaments") for name, source, _, _ in IMAGES if name in wanted):
        for scene in GALLERIES:
            shoot(scene, full)
    for subject in ("setup", "options"):
        frame = "frame:setup_ornaments" if subject == "setup" else "frame:options_ornaments"
        if any(source == frame for name, source, _, _ in IMAGES if name in wanted):
            shoot("setup_ornaments", dict(full, RENDER_SUBJECT=subject))
            run([sys.executable, "Tools/render/gallery.py", "--no-render", "--out", os.path.join(work, "frames"),
                 "--refs", os.path.join(work, "refs"), "--ppu", str(GALLERY_PPU), "setup_ornaments"])
    if "class" in sources:
        for name in CLASSES:
            shoot("hud_%s_mac" % name, full)


def cut_all(work, wanted):
    """Cut the gallery frames and the class close-ups out of the renders with gallery.py and classes.py."""
    if any(source.startswith("frame:") and not source.endswith("_ornaments") for name, source, _, _ in IMAGES if name in wanted):
        run([sys.executable, "Tools/render/gallery.py", "--no-render", "--out", os.path.join(work, "frames"),
             "--refs", os.path.join(work, "refs"), "--ppu", str(GALLERY_PPU), *GALLERIES])
    if any(source.startswith("class:") for name, source, _, _ in IMAGES if name in wanted):
        run([sys.executable, "Tools/render/classes.py", "--no-render", "--out", os.path.join(work, "classes"),
             "--ppu", str(GALLERY_PPU), *CLASSES])


def source_path(work, source):
    kind, _, name = source.partition(":")
    if kind == "hud":
        return os.path.join(work, "hud_%s.png" % name)
    if kind == "frame":
        return os.path.join(work, "frames", "kstyle_%s.png" % name)
    if kind == "class":
        return os.path.join(work, "classes", "%s_frames.png" % name)
    return os.path.join(work, source + ".png")


def save(image, name):
    path = os.path.join(OUT, name + ".png")
    image.convert("RGB").save(path, optimize=True)
    print("%s %dx%d %d KB" % (name, image.width, image.height, os.path.getsize(path) // 1024))


def scaled(image, limit):
    size = fit_width(image.width, image.height, limit)
    return image if size == image.size else image.resize(size, Image.LANCZOS)


def compose_row(images, gap, background):
    """The images side by side, top aligned, on the background colour."""
    sheet = Image.new("RGB", (sum(i.width for i in images) + gap * (len(images) - 1), max(i.height for i in images)), background)
    left = 0
    for i in images:
        sheet.paste(i, (left, 0))
        left += i.width + gap
    return sheet


def compose_grid(images, columns, gap, background):
    """The images in rows of columns, each cell the size of the first image."""
    cell_w, cell_h = images[0].size
    rows = (len(images) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * cell_w + gap * (columns - 1), rows * cell_h + gap * (rows - 1)), background)
    for index, i in enumerate(images):
        sheet.paste(i, ((index % columns) * (cell_w + gap), (index // columns) * (cell_h + gap)))
    return sheet


def box(x, y, w, h):
    return x, y, x + w, y + h


def finish(work, wanted):
    os.makedirs(OUT, exist_ok=True)
    hud = {layout: Image.open(source_path(work, "hud:" + layout)) for layout in LAYOUTS
           if os.path.exists(source_path(work, "hud:" + layout))}
    for layout in LAYOUTS:
        if "hud_" + layout.lower() in wanted:
            save(scaled(hud[layout], HUD_WIDTH), "hud_" + layout.lower())
    if "ornaments_strip" in wanted:
        levels = {"Off": Image.open(os.path.join(work, "level_Off.png")),
                  "Subtle": Image.open(os.path.join(work, "level_Subtle.png")), "Full": hud["DPS"]}
        crops = [levels[level].crop(box(*STRIP_BOX)) for level in LEVELS]
        save(scaled(compose_row(crops, 24, crops[0].getpixel((0, 0))), HUD_WIDTH), "ornaments_strip")
    if "card_materials" in wanted:
        cards = [Image.open(os.path.join(work, "material_%s.png" % m)).crop(box(*CARD_BOX)) for m in MATERIALS]
        background = cards[0].getpixel((0, 0))
        cards.append(Image.new("RGB", cards[0].size, background))
        save(scaled(compose_grid(cards, 3, 24, background), 1400), "card_materials")
    for name, source, crop, width in IMAGES:
        if name not in wanted:
            continue
        image = Image.open(source_path(work, source))
        if crop == "cover":
            image = image.crop(cover_box(image.width, image.height))
        elif crop:
            image = image.crop(parse_crop(crop))
        save(scaled(image, width), name)


def total_bytes():
    paths = [os.path.join(OUT, name + ".png") for name in picture_names()]
    return sum(os.path.getsize(path) for path in paths if os.path.exists(path))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--work", default=DEFAULT_WORK, help="where the renders and cut frames go")
    parser.add_argument("--no-render", action="store_true", help="reuse the renders a previous run left")
    parser.add_argument("--only", nargs="*", default=[], help="redo only these pictures")
    args = parser.parse_args(argv)
    unknown = [name for name in args.only if name not in picture_names()]
    if unknown:
        sys.exit("unknown picture(s): " + ", ".join(unknown))
    if not pillow():
        sys.exit("readme.py needs Pillow: pip install Pillow, or create the wow-dev venv at " + VENV_PYTHON)
    wanted = set(args.only or picture_names())
    if not args.no_render:
        render_all(args.work, wanted)
    cut_all(args.work, wanted)
    finish(args.work, wanted)
    total = total_bytes()
    print("total %.2f MB of %.0f MB" % (total / 1048576, BUDGET_BYTES / 1048576))
    return 0 if total <= BUDGET_BYTES else 1


if __name__ == "__main__":
    sys.exit(main())
