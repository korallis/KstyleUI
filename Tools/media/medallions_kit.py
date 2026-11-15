"""Bake the Medallions HUD style's generated textures into Media/Textures/Medallions/.

Usage:
    python3 Tools/media/medallions_kit.py bake --gen DIR [--root DIR]
    python3 Tools/media/medallions_kit.py sheets --out DIR [--root DIR]
    python3 Tools/media/medallions_kit.py provenance [--root DIR]

The sources are original Higgsfield generations (KSTY-90, plus six steel pieces from the KSTY-88 mock-ups). They are
not committed; Tools/media/medallions_sources.json records each one's job id, model, settings and full prompt, and
bake reads them from DIR under the names that file gives (on the owner's MacBook, ~/.capy/work/KSTY-90/gen/). This
script is the production pass. Effects are drawn for additive blending: their colour is stored unpremultiplied with
alpha set to the brightest channel, so ADD and BLEND both draw the light the source shows. Every flipbook is registered
on its core (each frame's light centroid moves to the centre of its cell), resampled in linear light and checked for a
clean loop; a loop whose seam step is more than LOOP_LIMIT times the median step between frames is cross-faded into a
seamless one. Steel pieces are trimmed to their silhouette, resampled with premultiplied alpha in linear light, lightly
sharpened, and get their 1 px outlines drawn procedurally at the shipped size. sheets writes contact sheets at the
shipped sizes and a loop strip for every flipbook. bake needs Pillow and NumPy; sheets and provenance need Pillow only.
The procedural Medallions pieces (rings, enamel, slabs, aura and group tiles, brackets) are drawn by make_media.py.
"""

import argparse
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Tuple

ROOT = Path(__file__).resolve().parents[2]
OUT = "Media/Textures/Medallions"
SOURCES = Path(__file__).resolve().parent / "medallions_sources.json"
CLASSES = ("Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior")
BAKED = "2026-11-15"
LOOP_LIMIT = 1.3
CELL = 128
EDGE_FADE = 3  # texels at each cell edge that fade to black, so bilinear sampling never bleeds into a neighbour
ALPHA_FLOOR = 4
TICK = "\x60"


@dataclass(frozen=True)
class Kit:
    name: str
    width: int
    height: int
    recipe: str
    source: str
    about: str
    blend: str = "ADD"
    flip: Optional[Tuple[int, int, int, Optional[float]]] = None  # rows, columns, frames, seconds per cycle

    @property
    def path(self):
        return f"{OUT}/{self.name}.png"

    @property
    def token(self):
        return "med" + self.name


MOTIF = {
    "Druid": "amber spirit leaves",
    "Hunter": "moss-green wind and feathers",
    "Mage": "icy arcane glyph sparks",
    "Paladin": "rose-gold holy rays",
    "Priest": "pearl holy motes and twinkles",
    "Rogue": "gold-edged smoke and glints",
    "Shaman": "blue storm lightning",
    "Warlock": "violet flame and fel embers",
    "Warrior": "forge fire and embers",
}

KIT = []
for _cls in CLASSES:
    _key = _cls.lower()
    KIT.append(Kit(f"Proc{_cls}", 512, 512, "loop", f"proc_{_key}",
                   f"Proc loop for an action slot, {MOTIF[_cls]}: an energy frame round the slot, 16 frames of 128 in a 4x4 grid. The slot's own square is the middle 56% of a cell.",
                   flip=(4, 4, 16, 0.96)))
    KIT.append(Kit(f"Ambient{_cls}", 512, 512, "loop", f"ambient_{_key}",
                   f"Ambient portrait loop, {MOTIF[_cls]} drifting round the rim of a round portrait (the middle 70% of a cell), drawn at low alpha: 16 frames of 128 in a 4x4 grid.",
                   flip=(4, 4, 16, 1.44)))
    KIT.append(Kit(f"Burst{_cls}", 512, 512, "radial", f"burst_{_key}",
                   f"Medallion burst, the 2D fallback for an engine model: {MOTIF[_cls]} blooming outward from a dark centre (the middle 40%) that sits behind the medallion."))
    KIT.append(Kit(f"Particle{_cls}", 128, 128, "sprites", f"particle_{_key}",
                   f"The crest's particles, {MOTIF[_cls]}: four sprite variants in a 2x2 grid of 64, centred in their cells. Pick one per particle; they are not frames.",
                   flip=(2, 2, 4, None)))
KIT += [
    Kit("LevelUp", 512, 512, "oneshot", "levelup",
        "Level-up burst flipbook: a golden starburst that swells from a spark and fades out, 16 frames of 128 in a 4x4 grid, played once.",
        flip=(4, 4, 16, 1.2)),
    Kit("ProcStart", 256, 256, "radial", "procstart",
        "The flash when a slot's proc starts: a white square ring with short rays round an empty slot (the middle 50%). White, tinted by the class."),
    Kit("ReadyFlash", 128, 128, "radial", "readyflash",
        "Cooldown-ready glint: a thin white square outline with a star glint at its top-left corner round an empty slot (the middle 70%)."),
    Kit("LowHealthRing", 256, 256, "radial", "lowhealth",
        "Low-health pulse: a ring of crimson energy round a round portrait (the middle 72%)."),
    Kit("Vignette", 512, 512, "vignette", "vignette",
        "Low-health screen-edge vignette: crimson glow on every edge and corner, black in the middle; made symmetric. Stretched over the screen."),
    Kit("PortraitSheen", 128, 128, "plain", "sheen",
        "Portrait and hub sheen: a soft white diagonal streak, translated across a masked portrait or the crest."),
    Kit("CombatSweep", 256, 32, "hstrip", "sweep",
        "The light that runs along the slab on entering combat: a thin white streak tapering to nothing at both ends."),
    Kit("BarSpark", 16, 64, "vstrip", "spark",
        "The status bar's leading-edge spark: a thin vertical white line with a soft glow."),
    Kit("HubWing", 512, 256, "wing", "src88_tex_hub",
        "One steel wing of the crest hub, pointing right. The texture's left edge, half way down, is the hub's centre; the wing's root is 33.6% of the width from it, at the rune ring's edge. Mirror it for the left wing.",
        blend="BLEND"),
    Kit("HubSocket", 128, 128, "disc", "socket",
        "The dark steel socket behind the crest, with a procedural 1 px outline.", blend="BLEND"),
    Kit("RuneRing", 256, 256, "disc", "src88_tex_rune",
        "The crest's rune band: dark steel between two silver lines with 24 invented glyphs, with procedural 1 px outlines. Rotated by the hub.",
        blend="BLEND"),
    Kit("RuneGlyphs", 256, 256, "glyphs", "src88_tex_rune",
        "The rune band's glyphs alone, as a white mask registered on RuneRing, so the class glow can be added on top (ADD, tinted)."),
    Kit("MinimapRing", 512, 512, "mapring", "src88_tex_mapring",
        "The round minimap's steel compass bezel with arrowhead studs; the haze outside the ring and everything inside the opening are cut to clear, and its edges get procedural 1 px outlines.",
        blend="BLEND"),
    Kit("CardCorner", 256, 256, "corner", "src88_tex_corner",
        "A card's top-left steel corner: a diamond stud with two filigree arms tapering right and down. The arms' centre lines run 12.3% in from the top and left edges; mirror it with texture coordinates for the other corners.",
        blend="BLEND"),
    Kit("SteelCard", 256, 256, "tile", "src88_tex_steel",
        "Seamless dark steel grain for cards and slabs: lighting removed, offset-blended so it tiles, then scaled to 256. Tiled at low alpha over a flat fill.",
        blend="BLEND"),
    Kit("BarFill", 64, 16, "bar", "barfill",
        "Status bar fill: flat light grey with one soft stripe a little above the middle, the same in every column so it tiles. Greyscale, so SetStatusBarColor tints it.",
        blend="BLEND"),
    Kit("BarTrack", 64, 16, "bar", "bartrack",
        "The empty track behind a bar: flat grey, very slightly darker along the top, the same in every column. Tinted dark in code.",
        blend="BLEND"),
    Kit("Slot", 64, 64, "slot", "slot",
        "Action slot frame, normal: a dark steel bevelled band about 9% of the side wide, centre clear, with procedural 1 px outer and inner lines.",
        blend="BLEND"),
    Kit("SlotPushed", 64, 64, "slot_pushed", "slot",
        "Action slot frame, pushed: the normal frame turned half a circle, so its light falls from the lower right, and darkened to 70%.",
        blend="BLEND"),
    Kit("SlotHighlight", 64, 64, "slot_highlight", "slot",
        "Action slot frame, highlight: the frame's band in white at half strength with a soft glow falling into the opening. White for ADD."),
    Kit("SlotChecked", 64, 64, "slot_checked", "slot",
        "Action slot frame, checked: a white line on the opening's edge with a soft inner glow. White for ADD, tinted by the accent."),
]
BY_NAME = {k.name: k for k in KIT}


def sources():
    return json.loads(SOURCES.read_text(encoding="utf-8"))


# Provenance --------------------------------------------------------------------------------------------------------

BEGIN, END = "<!-- BEGIN medallions_kit -->", "<!-- END medallions_kit -->"
SETTINGS = {
    "loop": "GIF frames on black, registered by cross-correlation (at most 4 px) and centred on the dark core of the mean frame, linear-light Lanczos to 128 cells, 3 px cell-edge fade, loop checked (cross-faded if the seam step exceeds 1.3x the median step), ADD alpha",
    "oneshot": "GIF frames on black, registered by cross-correlation and centred on the light's mean centroid, linear-light Lanczos to 128 cells, 3 px cell-edge fade, ends near black, ADD alpha",
    "radial": "on black, centred on its dark core, black point and gain normalised, linear-light Lanczos, radial edge fade, ADD alpha",
    "vignette": "on black, averaged with its mirror images, linear-light Lanczos, ADD alpha",
    "plain": "on black, linear-light Lanczos, edge fade, ADD alpha",
    "hstrip": "the brightest row band cropped, linear-light Lanczos, end and edge fades, ADD alpha",
    "vstrip": "the brightest column band cropped, linear-light Lanczos, end and edge fades, ADD alpha",
    "sprites": "each quarter on black, centred on its light, one shared scale, linear-light Lanczos to 64 cells, cell-edge fade, ADD alpha",
    "wing": "the right wing cut from the hub, ring cut away, premultiplied linear-light Lanczos, light unsharp mask",
    "disc": "trimmed to its silhouette, premultiplied linear-light Lanczos, light unsharp mask, procedural 1 px outlines",
    "glyphs": "glyph strokes inside the band (brighter than their blurred surroundings, thresholded per 7.5 degree sector), as a white mask, linear-light Lanczos",
    "mapring": "centred, haze outside the ring and the opening cut, premultiplied linear-light Lanczos, procedural 1 px outlines",
    "corner": "squared on the arms' meeting point, premultiplied linear-light Lanczos, light unsharp mask",
    "tile": "low-frequency light removed, offset-blended to tile, linear-light Lanczos on a 3x3 repeat",
    "bar": "the source's row profile, the same in every column, linear-light resample",
    "slot": "trimmed, premultiplied linear-light Lanczos, procedural 1 px outer and inner lines",
    "slot_pushed": "from the normal frame: turned 180 degrees, colour x0.7, procedural lines",
    "slot_highlight": "from the normal frame's alpha: band at 50% white plus a 4 texel inner glow",
    "slot_checked": "from the normal frame's opening: a 2 texel white line and a 3 texel inner glow",
}


def provenance_table(src=None):
    src = src or sources()
    lines = [
        "| File | Size | What it is | Made with | Settings | Date |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for kit in KIT:
        item = src[kit.source]
        made = (f"Higgsfield {TICK}{item['model']}{TICK} ({item['thread']}), job {TICK}{item['job_id']}{TICK}; "
                f"baked by {TICK}Tools/media/medallions_kit.py{TICK}")
        grid = f"; {kit.flip[0]}x{kit.flip[1]} cells" if kit.flip else ""
        lines.append(f"| {TICK}{kit.path}{TICK} | {kit.width}x{kit.height} | {kit.about} | {made} | {SETTINGS[kit.recipe]}{grid}; {kit.blend} | {BAKED} |")
    return "\n".join(lines)


def write_provenance(root):
    path = root / "Media" / "PROVENANCE.md"
    text = path.read_text(encoding="utf-8")
    start, stop = text.find(BEGIN), text.find(END)
    if start < 0 or stop < start:
        raise SystemExit(f"{path} has no {BEGIN} ... {END} block")
    path.write_text(text[: start + len(BEGIN)] + "\n" + provenance_table() + "\n" + text[stop:], encoding="utf-8")


# Measurements (Pillow only, so the tests can run them) --------------------------------------------------------------


def cells(image, rows, columns):
    w, h = image.size[0] // columns, image.size[1] // rows
    return [image.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)) for r in range(rows) for c in range(columns)]


def light(cell):
    """The cell's light as an L image: its brightest channel times its alpha."""
    from PIL import ImageChops

    r, g, b, a = cell.convert("RGBA").split()
    return ImageChops.multiply(ImageChops.lighter(ImageChops.lighter(r, g), b), a)


def mean_difference(a, b):
    from PIL import ImageChops, ImageStat

    return ImageStat.Stat(ImageChops.difference(a, b)).mean[0]


def centroid(image):
    w, h = image.size
    total = sx = sy = 0.0
    for i, v in enumerate(image.getdata()):
        if v:
            total += v
            sx += v * (i % w)
            sy += v * (i // w)
    if not total:
        return (w - 1) / 2, (h - 1) / 2
    return sx / total, sy / total


def core_centre(average):
    """Centre of the dark core of an averaged light image: the dark region connected to the middle, by flood fill."""
    from PIL import Image, ImageDraw

    w, h = average.size
    values = list(average.getdata())
    top = sorted(values)[int(0.995 * (len(values) - 1))]
    mask = Image.new("L", (w, h))
    mask.putdata([255 if v < 0.08 * top else 0 for v in values])
    ImageDraw.floodfill(mask, (w // 2, h // 2), 128)
    filled = [i for i, v in enumerate(mask.getdata()) if v == 128]
    return sum(i % w for i in filled) / len(filled), sum(i // w for i in filled) / len(filled)


def flipbook_metrics(path, rows, columns, frames, oneshot=False):
    """Steps between frames, the loop seam's step, and how far the core sits from the cell centre: the dark core of the
    averaged frames for a loop, the light's centroid for a one-shot burst."""
    from PIL import Image

    lights = [light(c) for c in cells(Image.open(path), rows, columns)[:frames]]
    steps = [mean_difference(lights[i], lights[i + 1]) for i in range(frames - 1)]
    w, h = lights[0].size
    total = [0] * (w * h)
    for lt in lights:
        total = [t + v for t, v in zip(total, lt.getdata())]
    average = Image.new("F", (w, h))
    average.putdata(total)
    cx, cy = centroid(average) if oneshot else core_centre(average)
    return {
        "steps": steps,
        "seam": mean_difference(lights[-1], lights[0]),
        "median_step": sorted(steps)[len(steps) // 2],
        "core_offset": math.hypot(cx - (w - 1) / 2, cy - (h - 1) / 2),
        "means": [sum(lt.getdata()) / (w * h) for lt in lights],
    }


# Bake (NumPy) -------------------------------------------------------------------------------------------------------


def bake(gen, root):
    import numpy as np
    from PIL import Image, ImageFilter, ImageSequence

    def linear(x):
        return np.power(np.clip(x, 0, 1), 2.2)

    def srgb(x):
        return np.power(np.clip(x, 0, 1), 1 / 2.2)

    def resize(arr, size):
        chans = [Image.fromarray(np.ascontiguousarray(arr[..., c], np.float32), "F").resize(size, Image.LANCZOS) for c in range(arr.shape[2])]
        return np.stack([np.asarray(c) for c in chans], -1)

    def shift(arr, dx, dy):
        chans = [Image.fromarray(np.ascontiguousarray(arr[..., c], np.float32), "F").transform(
            (arr.shape[1], arr.shape[0]), Image.AFFINE, (1, 0, -dx, 0, 1, -dy), resample=Image.BICUBIC) for c in range(arr.shape[2])]
        return np.clip(np.stack([np.asarray(c) for c in chans], -1), 0, None)

    def on_black(name):
        a = np.asarray(Image.open(gen / f"{name}.png").convert("RGBA")).astype(np.float32) / 255
        return a[..., :3] * a[..., 3:]

    def rgba(name):
        return np.asarray(Image.open(gen / f"{name}.png").convert("RGBA")).astype(np.float32) / 255

    def gif(name):
        out = []
        for frame in ImageSequence.Iterator(Image.open(gen / f"{name}.gif")):
            a = np.asarray(frame.convert("RGBA")).astype(np.float32) / 255
            out.append(a[..., :3] * a[..., 3:])
        return out

    def lum(rgb):
        return rgb.max(-1)

    def bright_centre(rgb):
        w = lum(rgb) ** 2
        ys, xs = np.mgrid[: w.shape[0], : w.shape[1]]
        return float((xs * w).sum() / w.sum()), float((ys * w).sum() / w.sum())

    def dark_centre(rgb):
        """Centre of the dark core: the dark region connected to the middle of the image, by flood fill."""
        from PIL import ImageDraw

        lv = lum(rgb)
        h, w = lv.shape
        mask = Image.fromarray(np.where(lv < 0.08 * float(np.percentile(lv, 99.5)), 255, 0).astype(np.uint8), "L").copy()
        ImageDraw.floodfill(mask, (w // 2, h // 2), 128)
        ys, xs = np.where(np.asarray(mask) == 128)
        return float(xs.mean()), float(ys.mean())

    def normalise(lin, floor_pct=25, peak_pct=99.7, target=0.97, max_gain=4.0):
        floor = min(0.02, float(np.percentile(lum(lin), floor_pct)))
        out = np.clip(lin - floor, 0, None) / (1 - floor)
        peak = float(np.percentile(lum(out), peak_pct))
        return np.clip(out * min(max_gain, target / max(peak, 1e-4)), 0, 1)

    def edge_window(h, w, fade):
        y = np.minimum(np.arange(h), np.arange(h)[::-1]).astype(np.float32)
        x = np.minimum(np.arange(w), np.arange(w)[::-1]).astype(np.float32)
        return (np.clip(y / fade, 0, 1)[:, None] * np.clip(x / fade, 0, 1)[None, :])[..., None]

    def radial_window(n, start=0.86):
        ys, xs = np.mgrid[:n, :n]
        r = np.hypot(xs - (n - 1) / 2, ys - (n - 1) / 2) / (n / 2)
        t = np.clip((1 - r) / (1 - start), 0, 1)
        return (t * t * (3 - 2 * t))[..., None]

    def add_encode(lin):
        s = srgb(lin)
        a = s.max(-1, keepdims=True)
        out = np.round(np.concatenate([np.where(a > 1e-4, s / np.maximum(a, 1e-4), 0), a], -1) * 255).astype(np.uint8)
        out[..., :3][out[..., 3] < 1] = 0
        return Image.fromarray(out, "RGBA")

    def blend_encode(pre):
        a = pre[..., 3:]
        col = np.where(a > 1e-4, pre[..., :3] / np.maximum(a, 1e-4), 0)
        out = np.round(np.concatenate([srgb(col), np.clip(a, 0, 1)], -1) * 255).astype(np.uint8)
        out[..., 3][out[..., 3] < ALPHA_FLOOR] = 0
        out[..., :3][out[..., 3] == 0] = 0
        return Image.fromarray(out, "RGBA")

    def premul_lin(src):
        return np.concatenate([linear(src[..., :3]) * src[..., 3:], src[..., 3:]], -1)

    def from_image(img):
        return premul_lin(np.asarray(img).astype(np.float32) / 255)

    def unsharp(img, amount=50):
        r, g, b = img.convert("RGB").filter(ImageFilter.UnsharpMask(radius=0.6, percent=amount, threshold=0)).split()
        return Image.merge("RGBA", (r, g, b, img.getchannel("A")))

    def ring_line(size, radius, width, level=0.03, alpha=1.0, ss=4):
        n = size * ss
        ys, xs = np.mgrid[:n, :n]
        r = np.hypot((xs + 0.5) / ss - size / 2, (ys + 0.5) / ss - size / 2)
        cov = (abs(r - radius) <= width / 2).astype(np.float32).reshape(size, ss, size, ss).mean((1, 3))[..., None] * alpha
        return np.concatenate([np.full((size, size, 3), float(linear(np.array(level))), np.float32) * cov, cov], -1)

    def over(top, bottom):
        return top + bottom * (1 - top[..., 3:])

    def offset_to(reference, frame):
        """The integer shift that best lays frame's light on reference's, by FFT cross-correlation."""
        a, b = lum(reference), lum(frame)
        if b.sum() < 1e-3 * a.sum():
            return 0, 0
        limit = 4
        corr = np.fft.irfft2(np.fft.rfft2(a - a.mean()) * np.conj(np.fft.rfft2(b - b.mean())), a.shape)
        dy, dx = np.unravel_index(int(np.argmax(corr)), corr.shape)
        h, w = a.shape
        dx, dy = (dx - w if dx > w // 2 else dx), (dy - h if dy > h // 2 else dy)
        return (dx, dy) if max(abs(dx), abs(dy)) <= limit else (0, 0)

    def flipbook(kit, oneshot):
        frames = [linear(f) for f in gif(kit.source)]
        n = frames[0].shape[0]
        mean = np.mean(frames, 0)
        moves = [offset_to(mean, f) for f in frames]
        frames = [np.roll(f, (dy, dx), (0, 1)) for f, (dx, dy) in zip(frames, moves)]
        cx, cy = bright_centre(np.mean(frames, 0)) if oneshot else dark_centre(np.mean(frames, 0))
        mid = (n - 1) / 2
        frames = [shift(f, mid - cx, mid - cy) for f in frames]
        frames = list(normalise(np.stack(frames)))
        steps = [float(np.abs(lum(frames[i + 1]) - lum(frames[i])).mean()) for i in range(len(frames) - 1)]
        seam = float(np.abs(lum(frames[0]) - lum(frames[-1])).mean())
        faded = False
        if not oneshot and seam > LOOP_LIMIT * float(np.median(steps)):
            half = len(frames) // 2
            weights = [math.sin(math.pi * (i + 0.5) / len(frames)) ** 2 for i in range(len(frames))]
            frames = [w * frames[i] + (1 - w) * frames[(i + half) % len(frames)] for i, w in enumerate(weights)]
            faded = True
        rows, cols = kit.flip[0], kit.flip[1]
        sheet = np.zeros((rows * CELL, cols * CELL, 3), np.float32)
        window = edge_window(CELL, CELL, EDGE_FADE)
        for i, f in enumerate(frames):
            r, c = divmod(i, cols)
            sheet[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = np.clip(resize(f, (CELL, CELL)), 0, 1) * window
        wander = max(math.hypot(dx, dy) for dx, dy in moves)
        return add_encode(sheet), {"faded": faded, "seam_ratio": round(seam / max(float(np.median(steps)), 1e-6), 2),
                                   "frame_moves_px": wander, "core_moved": [round(mid - cx, 2), round(mid - cy, 2)]}

    def radial(kit):
        lin = normalise(linear(on_black(kit.source)))
        h, w = lin.shape[:2]
        cx, cy = dark_centre(lin)
        half = min(cx, cy, w - 1 - cx, h - 1 - cy)
        crop = lin[int(round(cy - half)):int(round(cy + half)) + 1, int(round(cx - half)):int(round(cx + half)) + 1]
        small = np.clip(resize(crop, (kit.width, kit.height)), 0, 1) * radial_window(kit.width) * edge_window(kit.height, kit.width, 2)
        return add_encode(small), {"core_offset": [round(cx - (w - 1) / 2, 1), round(cy - (h - 1) / 2, 1)]}

    def vignette(kit):
        lin = normalise(linear(on_black(kit.source)), floor_pct=40)
        sym = (lin + lin[:, ::-1] + lin[::-1, :] + lin[::-1, ::-1]) / 4
        return add_encode(np.clip(resize(sym, (kit.width, kit.height)), 0, 1)), {}

    def plain(kit):
        lin = normalise(linear(on_black(kit.source)))
        return add_encode(np.clip(resize(lin, (kit.width, kit.height)), 0, 1) * edge_window(kit.height, kit.width, 4)), {}

    def strip(kit, horizontal):
        lin = normalise(linear(on_black(kit.source)))
        if not horizontal:
            lin = np.ascontiguousarray(lin.transpose(1, 0, 2))
        w = lin.shape[1]
        row = int(np.argmax(lum(lin).mean(1)))
        long_side, short_side = (kit.width, kit.height) if horizontal else (kit.height, kit.width)
        span = round(w * short_side / long_side / 2)
        crop = lin[max(0, row - span):row + span]
        small = np.clip(resize(crop, (long_side, short_side)), 0, 1) * edge_window(short_side, long_side, 3)
        if not horizontal:
            small = np.ascontiguousarray(small.transpose(1, 0, 2))
        return add_encode(small), {"line": row}

    def sprites(kit):
        lin = normalise(linear(on_black(kit.source)))
        h, w = lin.shape[:2]
        quarters = [lin[r * h // 2:(r + 1) * h // 2, c * w // 2:(c + 1) * w // 2] for r in range(2) for c in range(2)]
        reach, found = 0.0, []
        for q in quarters:
            cx, cy = bright_centre(q)
            lv = lum(q)
            ys, xs = np.mgrid[: lv.shape[0], : lv.shape[1]]
            d = np.hypot(xs - cx, ys - cy).ravel()
            order = np.argsort(d)
            energy = np.cumsum(lv.ravel()[order])
            reach = max(reach, float(d[order][np.searchsorted(energy, 0.97 * energy[-1])]))
            found.append((q, cx, cy))
        half = reach * 1.25
        out = np.zeros((128, 128, 3), np.float32)
        window = edge_window(64, 64, EDGE_FADE)
        pad = int(math.ceil(half)) + 2
        for i, (q, cx, cy) in enumerate(found):
            padded = np.pad(q, ((pad, pad), (pad, pad), (0, 0)))
            y0, x0 = int(round(cy - half)) + pad, int(round(cx - half)) + pad
            side = int(round(2 * half))
            r, c = divmod(i, 2)
            out[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64] = np.clip(resize(padded[y0:y0 + side, x0:x0 + side], (64, 64)), 0, 1) * window
        return add_encode(out), {"reach": round(reach, 1)}

    def steel_resize(src, size):
        return np.clip(resize(premul_lin(src), size), 0, None)

    def wing(kit):
        src = rgba(kit.source)
        cx, cy, ring, span = 668, 383, 219, 672
        crop = src[cy - span // 4: cy + span // 4, cx: cx + span].copy()
        ys, xs = np.mgrid[: crop.shape[0], : crop.shape[1]]
        cut = 1.03 * ring
        crop[..., 3] *= np.clip((np.hypot(xs, ys - span // 4) - cut) / 4, 0, 1)
        return unsharp(blend_encode(steel_resize(crop, (kit.width, kit.height)))), {"root_share": round(cut / span, 3)}

    def trimmed_square(src):
        ys, xs = np.where(src[..., 3] > 0.03)
        cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
        half = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2 + 2
        pad = int(half) + 4
        padded = np.pad(src, ((pad, pad), (pad, pad), (0, 0)))
        y0, x0, side = int(round(cy - half)) + pad, int(round(cx - half)) + pad, int(round(2 * half))
        return padded[y0:y0 + side, x0:x0 + side]

    def outline_radii(img, size):
        a = np.asarray(img.getchannel("A")).astype(np.float32) / 255
        c = (size - 1) / 2
        rr = np.arange(0, size / 2, 0.25)
        prof = []
        for ang in np.linspace(0, 2 * math.pi, 64, endpoint=False):
            xs = np.clip(np.round(c + rr * math.cos(ang)).astype(int), 0, size - 1)
            ys = np.clip(np.round(c + rr * math.sin(ang)).astype(int), 0, size - 1)
            prof.append(a[ys, xs])
        solid = np.where(np.median(np.stack(prof), 0) > 0.5)[0]
        return float(rr[solid.max()]) + 0.5, float(rr[solid.min()]) - 0.5

    def disc(kit):
        img = unsharp(blend_encode(steel_resize(trimmed_square(rgba(kit.source)), (kit.width, kit.height))))
        outer, inner = outline_radii(img, kit.width)
        lines = ring_line(kit.width, outer - 0.6, 1.2)
        if inner > 2:
            lines = over(ring_line(kit.width, inner + 0.6, 1.2), lines)
        return blend_encode(over(lines, from_image(img))), {"outer": round(outer, 2), "inner": round(inner, 2)}

    def glyphs(kit):
        sq = trimmed_square(rgba(kit.source))
        n = sq.shape[0]
        ys, xs = np.mgrid[:n, :n]
        r = np.hypot(xs - (n - 1) / 2, ys - (n - 1) / 2) / (n / 2)
        lv = sq[..., :3].mean(-1) * sq[..., 3]
        sat = sq[..., :3].max(-1) - sq[..., :3].min(-1)
        band = (r > 0.815) & (r < 0.93)
        smooth = np.asarray(Image.fromarray(np.round(lv * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(n / 128))).astype(np.float32) / 255
        detail = lv - smooth
        sector = np.floor((np.arctan2(ys - (n - 1) / 2, xs - (n - 1) / 2) + math.pi) / (2 * math.pi) * 48).astype(int) % 48
        mask = np.zeros_like(lv)
        for k in range(48):
            part = band & (sector == k)
            lo, hi = float(np.percentile(detail[part], 70)), float(np.percentile(detail[part], 95))
            mask[part] = np.clip((detail[part] - lo) / max(hi - lo, 1e-3), 0, 1)
        mask = np.clip((mask - 0.35) / 0.65, 0, 1) * (sat < 0.12)
        small = np.clip(resize(mask[..., None], (kit.width, kit.height)), 0, 1)[..., 0]
        out = np.zeros((kit.height, kit.width, 4), np.uint8)
        out[..., 3] = np.round(small * 255).astype(np.uint8)
        out[..., 3][out[..., 3] < ALPHA_FLOOR] = 0
        out[..., :3][out[..., 3] > 0] = 255
        return Image.fromarray(out, "RGBA"), {"band": [0.815, 0.93]}

    def mapring(kit):
        src = rgba(kit.source)
        cx = cy = 511.0
        ys, xs = np.mgrid[: src.shape[0], : src.shape[1]]
        r = np.hypot(xs - cx, ys - cy)
        src[..., 3][(r > 472) & (src[..., 3] < 0.5)] = 0
        src[..., 3] *= np.clip((r - 362) / 3, 0, 1)
        half = 511
        sq = src[int(cy - half):int(cy + half) + 1, int(cx - half):int(cx + half) + 1]
        img = unsharp(blend_encode(steel_resize(sq, (kit.width, kit.height))))
        scale = kit.width / (2 * half + 1)
        inner, outer = 363 * scale, 470 * scale
        lines = over(ring_line(kit.width, inner + 0.6, 1.2, alpha=0.9), ring_line(kit.width, outer - 0.6, 1.2, alpha=0.8))
        return blend_encode(over(lines, from_image(img))), {"opening_share": round(2 * inner / kit.width, 4), "ring_share": round(2 * outer / kit.width, 4)}

    def corner(kit):
        src = rgba(kit.source)
        meet_x, meet_y, reach, side, pad = 100, 161, 128, 1040, 64
        padded = np.pad(src, ((pad, pad + side), (pad, pad + side), (0, 0)))
        y0, x0 = meet_y - reach + pad, meet_x - reach + pad
        crop = padded[y0:y0 + side, x0:x0 + side]
        return unsharp(blend_encode(steel_resize(crop, (kit.width, kit.height)))), {"arm_share": round(reach / side, 4)}

    def tile(kit):
        src = linear(np.asarray(Image.open(gen / f"{kit.source}.png").convert("RGB")).astype(np.float32) / 255)
        n = src.shape[0]
        low = np.clip(resize(resize(src, (8, 8)), (n, n)), 1e-4, None)
        flat = src / low * low.mean((0, 1))
        rolled = np.roll(flat, (n // 2, n // 2), (0, 1))
        ramp = np.clip(np.minimum(np.arange(n), np.arange(n)[::-1]).astype(np.float32) / (n * 0.25), 0, 1)
        w = (ramp[:, None] * ramp[None, :])[..., None]
        seamless = w * flat + (1 - w) * rolled
        big = np.tile(seamless, (3, 3, 1))
        small = np.clip(resize(big, (3 * kit.width, 3 * kit.height)), 0, None)[kit.height:2 * kit.height, kit.width:2 * kit.width]
        out = np.concatenate([srgb(small), np.ones((kit.height, kit.width, 1), np.float32)], -1)
        return Image.fromarray(np.round(out * 255).astype(np.uint8), "RGBA"), {"mean": round(float(srgb(small).mean()), 4)}

    def bar(kit):
        src = linear(np.asarray(Image.open(gen / f"{kit.source}.png").convert("L")).astype(np.float32) / 255)
        w = src.shape[1]
        profile = np.ascontiguousarray(src[:, w // 5: 4 * w // 5].mean(1)[:, None], np.float32)
        small = np.asarray(Image.fromarray(profile, "F").resize((1, kit.height), Image.LANCZOS))[:, 0]
        if kit.name == "BarFill":
            lo, hi = float(small.min()), float(small.max())
            small = linear(0.84 + 0.16 * (srgb(small) - srgb(np.array(lo))) / max(float(srgb(np.array(hi)) - srgb(np.array(lo))), 1e-4))
        grey = np.repeat(np.round(srgb(small) * 255).astype(np.uint8)[:, None], kit.width, 1)
        return Image.fromarray(np.stack([grey, grey, grey, np.full_like(grey, 255)], -1), "RGBA"), {"profile": [int(v) for v in grey[:, 0]]}

    def slot_lines(n, inner):
        out = np.zeros((n, n, 4), np.float32)
        out[[0, -1], :] = (0, 0, 0, 1)
        out[:, [0, -1]] = (0, 0, 0, 1)
        lo, hi = inner, n - 1 - inner
        for k in (lo, hi):
            out[k, lo:hi + 1] = (0, 0, 0, 0.85)
            out[lo:hi + 1, k] = (0, 0, 0, 0.85)
        return out

    def slot(kit):
        body = steel_resize(trimmed_square(rgba("slot")), (kit.width, kit.height))
        solid = np.where(body[kit.height // 2, :, 3] > 0.5)[0]
        inner = int(solid[int(np.argmax(np.diff(solid)))]) + 1
        if kit.recipe == "slot_pushed":
            body = body[::-1, ::-1].copy()
            body[..., :3] *= float(linear(np.array(0.7)))
        if kit.recipe in ("slot", "slot_pushed"):
            img = unsharp(blend_encode(body))
            return blend_encode(over(slot_lines(kit.width, inner), from_image(img))), {"opening_from": inner}
        n = kit.width
        ys, xs = np.mgrid[:n, :n]
        d = np.minimum.reduce([xs - inner, n - 1 - inner - xs, ys - inner, n - 1 - inner - ys]).astype(np.float32)
        inside = d >= 0
        if kit.recipe == "slot_highlight":
            lit = np.maximum(np.clip(body[..., 3], 0, 1) * 0.5, np.where(inside, np.clip(1 - d / 4, 0, 1) * 0.6, 0))
        else:
            lit = np.maximum(np.where(inside & (d < 2), 1.0, 0), np.where(inside & (d >= 2), np.clip(1 - (d - 2) / 3, 0, 1) * 0.45, 0))
        return add_encode(np.repeat(linear(lit)[..., None], 3, -1)), {"opening_from": inner}

    recipes = {
        "loop": lambda k: flipbook(k, False), "oneshot": lambda k: flipbook(k, True), "radial": radial,
        "vignette": vignette, "plain": plain, "hstrip": lambda k: strip(k, True), "vstrip": lambda k: strip(k, False),
        "sprites": sprites, "wing": wing, "disc": disc, "glyphs": glyphs, "mapring": mapring, "corner": corner,
        "tile": tile, "bar": bar, "slot": slot, "slot_pushed": slot, "slot_highlight": slot, "slot_checked": slot,
    }
    report = {}
    for kit in KIT:
        img, info = recipes[kit.recipe](kit)
        if img.size != (kit.width, kit.height):
            raise SystemExit(f"{kit.name}: baked {img.size}, expected {(kit.width, kit.height)}")
        path = root / kit.path
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path, optimize=True)
        report[kit.name] = info
        print(f"wrote {kit.path} {json.dumps(info)}")
    write_provenance(root)
    return report


# Contact sheets ----------------------------------------------------------------------------------------------------


def lit(img):
    """An ADD texture as the light it adds over black."""
    from PIL import Image

    r, g, b, a = img.convert("RGBA").split()
    black = Image.new("L", img.size, 0)
    return Image.merge("RGB", tuple(Image.composite(c, black, a) for c in (r, g, b)))


def sheets(root, out):
    from PIL import Image, ImageChops, ImageDraw

    out.mkdir(parents=True, exist_ok=True)
    pad, label = 12, 14
    groups = {
        "effects": [k for k in KIT if k.blend == "ADD" and not k.flip],
        "steel": [k for k in KIT if k.blend == "BLEND"],
        "flipbooks": [k for k in KIT if k.flip and k.flip[2] == 16],
        "particles": [k for k in KIT if k.recipe == "sprites"],
    }
    for group, kits in groups.items():
        width, x, y, row_h, placed = 1600, pad, pad, 0, []
        for kit in kits:
            if x + kit.width + pad > width:
                x, y, row_h = pad, y + row_h + label + pad, 0
            placed.append((kit, x, y))
            x += kit.width + pad
            row_h = max(row_h, kit.height)
        sheet = Image.new("RGB", (width, y + row_h + label + pad), (16, 18, 22))
        draw = ImageDraw.Draw(sheet)
        for kit, x, y in placed:
            img = Image.open(root / kit.path).convert("RGBA")
            box = (x, y, x + kit.width, y + kit.height)
            if kit.blend == "ADD":
                sheet.paste(ImageChops.add(sheet.crop(box), lit(img)), box[:2])
            else:
                base = sheet.crop(box).convert("RGBA")
                base.alpha_composite(img)
                sheet.paste(base.convert("RGB"), box[:2])
            draw.text((x, y + kit.height + 1), f"{kit.name} {kit.width}x{kit.height}", fill=(200, 205, 215))
        sheet.save(out / f"contact-{group}-1x.png")
    for kit in groups["flipbooks"]:
        rows, cols, frames, _ = kit.flip
        frame_imgs = cells(Image.open(root / kit.path).convert("RGBA"), rows, cols)
        m = flipbook_metrics(root / kit.path, rows, cols, frames, kit.recipe == "oneshot")
        strip = Image.new("RGB", (CELL * 5 + pad * 6, CELL + 60), (16, 18, 22))
        draw = ImageDraw.Draw(strip)
        for i, idx in enumerate((frames - 2, frames - 1, 0, 1)):
            strip.paste(lit(frame_imgs[idx]), (pad + i * (CELL + pad), pad))
            draw.text((pad + i * (CELL + pad), CELL + pad + 2), f"frame {idx + 1}", fill=(200, 205, 215))
        seam = ImageChops.difference(light(frame_imgs[-1]), light(frame_imgs[0])).point(lambda v: min(255, v * 4))
        strip.paste(Image.merge("RGB", (seam, seam, seam)), (pad + 4 * (CELL + pad), pad))
        draw.text((pad + 4 * (CELL + pad), CELL + pad + 2), "|16 - 1| x4", fill=(200, 205, 215))
        draw.text((pad, CELL + pad + 22), f"{kit.name}: seam {m['seam']:.2f}, median step {m['median_step']:.2f}, "
                  f"ratio {m['seam'] / max(m['median_step'], 1e-6):.2f}, core offset {m['core_offset']:.2f} px", fill=(230, 235, 240))
        strip.save(out / f"loop-{kit.name}.png")


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    b = sub.add_parser("bake")
    b.add_argument("--gen", type=Path, required=True, help="folder holding the raw generations")
    b.add_argument("--root", type=Path, default=ROOT)
    s = sub.add_parser("sheets")
    s.add_argument("--out", type=Path, required=True)
    s.add_argument("--root", type=Path, default=ROOT)
    p = sub.add_parser("provenance")
    p.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args(argv)
    if args.command == "bake":
        bake(args.gen, args.root)
    elif args.command == "sheets":
        sheets(args.root, args.out)
    else:
        write_provenance(args.root)
    return 0


if __name__ == "__main__":    sys.exit(main(sys.argv[1:]))
