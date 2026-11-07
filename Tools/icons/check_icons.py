"""Reject generated icons that are blank, clipped, framed or carry text, by the rules of each icon set.

Usage:
    python Tools/icons/check_icons.py [--set A|B] [--no-text] [--cache-dir DIR] PNG...

Run it with a Python that has Pillow, such as ~/.local/share/wow-dev/venv/bin/python. It prints
"ok <path>" or "reject <path>: <reasons>" for each image and exits 1 when it rejects any.

Each image is reduced to a 256x256 raster of luma (brightness) and chroma (max minus min channel).
judge() checks set A, white light art on a black background, with one reason code per problem:

    blank             almost nothing is lit, or nothing is brighter than mid grey
    small             the lit area spans less than 40% of the side, so it will not read at 32 pixels
    background        the outer band is not black, or more than 60% of the image is lit
    clipped:<edge>    the subject runs into the top, bottom, left or right edge
    colour            the lit pixels carry a colour cast (set A must be monochrome)
    text:<string>     macOS Vision reads text in the full-size image

judge_colour() checks set B, full-colour paintings that fill the square edge to edge:

    blank             nothing is brighter than mid grey, or the image is almost one flat tone
    flat              too little contrast left at 32 pixels for the icon to read
    frame             a black margin runs round all four sides instead of paint
    grid:<rows|columns>  a black gutter crosses the middle, as in a sheet of several icons
    clipped:<edge>    the centre is much darker than the edges: the lit subject sits at that edge
    text:<string>     as for set A

judge_for("A") and judge_for("B") return the check for a set.

The text check compiles Tools/icons/ocr_text.swift with swiftc into the cache folder on first use.
--no-text skips it, for machines without swiftc.
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

ANALYSIS_SIZE = 256
LIT = 64  # luma that counts as part of the subject
BRIGHT = 96  # luma that counts as the subject when it reaches an edge
MIN_COVERAGE = 0.03
MIN_PEAK = 128
MIN_SPAN = 0.40
MAX_COVERAGE = 0.60
BAND = 8 / 256  # outer band, as a share of the side, that must stay black
MAX_BAND_MEAN = 24
EDGE = 3 / 256  # edge strip, as a share of the side, where a bright run counts as clipping
MAX_EDGE_SHARE = 0.02
CHROMA_LUMA = 40  # pixels at least this bright count for the colour check
MAX_MEAN_CHROMA = 16
BLANK_SD = 8  # set B: luma spread below this is one flat tone
FLAT_SIZE = 32  # set B: the size the icon must read at
MIN_FLAT_SD = 24  # set B: luma spread the icon keeps at FLAT_SIZE
DARK = 16  # set B: luma of a black margin or gutter
FRAME_BAND = 8 / 256  # set B: outer band, as a share of the side, that a frame fills
MIN_FRAME_DARK = 0.97  # set B: share of black pixels in every outer band that makes a frame
MIN_GUTTER_DARK = 0.95  # set B: share of black pixels in a row or column of a gutter
GUTTER_ZONE = (0.15, 0.85)  # set B: a gutter lies inside this share of the side
CENTRE = 0.25  # set B: the centre square starts this share of the side in from each edge
MIN_CENTRE_RATIO = 0.7  # set B: centre mean luma over the outer ring's
TEXT_CONFIDENCE = 0.5
TEXT_MIN_CHARS = 2

OCR_SOURCE = Path(__file__).with_name("ocr_text.swift")
DEFAULT_CACHE = Path.home() / ".local" / "share" / "wow-dev" / "icons" / "bin"


@dataclass(frozen=True)
class Raster:
    size: int
    luma: bytes
    chroma: bytes


class OcrError(RuntimeError):
    pass


def _edges(raster):
    size, luma = raster.size, raster.luma
    depth = max(1, round(size * EDGE))
    strips = {
        "top": lambda i, d: luma[d * size + i],
        "bottom": lambda i, d: luma[(size - 1 - d) * size + i],
        "left": lambda i, d: luma[i * size + d],
        "right": lambda i, d: luma[i * size + size - 1 - d],
    }
    clipped = []
    for edge, pixel in strips.items():
        hits = sum(1 for i in range(size) if max(pixel(i, d) for d in range(depth)) >= BRIGHT)
        if hits / size > MAX_EDGE_SHARE:
            clipped.append(f"clipped:{edge}")
    return clipped


def _band_mean(raster):
    size, luma = raster.size, raster.luma
    band = max(1, round(size * BAND))
    total = count = 0
    for y in range(size):
        row = y * size
        if y < band or y >= size - band:
            total += sum(luma[row:row + size])
            count += size
        else:
            total += sum(luma[row:row + band]) + sum(luma[row + size - band:row + size])
            count += 2 * band
    return total / count


def _readable(texts):
    found = []
    for text, confidence in texts:
        if confidence >= TEXT_CONFIDENCE and sum(ch.isalnum() for ch in text) >= TEXT_MIN_CHARS:
            found.append(f"text:{text}")
    return found


def judge(raster, texts=()):
    """Return the reasons to reject the raster; an empty list accepts it."""
    size, luma, chroma = raster.size, raster.luma, raster.chroma
    lit_count = 0
    left, top, right, bottom = size, size, -1, -1
    chroma_sum = chroma_count = 0
    for y in range(size):
        row = y * size
        for x in range(size):
            value = luma[row + x]
            if value >= CHROMA_LUMA:
                chroma_sum += chroma[row + x]
                chroma_count += 1
            if value >= LIT:
                lit_count += 1
                left, right = min(left, x), max(right, x)
                top, bottom = min(top, y), max(bottom, y)
    coverage = lit_count / (size * size)

    reasons = []
    if coverage < MIN_COVERAGE or max(luma) < MIN_PEAK:
        reasons.append("blank")
    elif max(right - left + 1, bottom - top + 1) < MIN_SPAN * size:
        reasons.append("small")
    if _band_mean(raster) > MAX_BAND_MEAN or coverage > MAX_COVERAGE:
        reasons.append("background")
    reasons.extend(_edges(raster))
    if chroma_count and chroma_sum / chroma_count > MAX_MEAN_CHROMA:
        reasons.append("colour")
    reasons.extend(_readable(texts))
    return reasons


def _spread(values):
    values = list(values)
    mean = sum(values) / len(values)
    return (sum((v - mean) ** 2 for v in values) / len(values)) ** 0.5


def _block_means(raster, blocks):
    size, luma = raster.size, raster.luma
    step = size // blocks
    means = []
    for by in range(blocks):
        for bx in range(blocks):
            total = sum(sum(luma[y * size + bx * step:y * size + (bx + 1) * step]) for y in range(by * step, (by + 1) * step))
            means.append(total / (step * step))
    return means


def _framed(raster):
    size, luma = raster.size, raster.luma
    band = max(1, round(size * FRAME_BAND))
    strips = (
        [luma[y * size + x] for y in range(band) for x in range(size)],
        [luma[y * size + x] for y in range(size - band, size) for x in range(size)],
        [luma[y * size + x] for y in range(size) for x in range(band)],
        [luma[y * size + x] for y in range(size) for x in range(size - band, size)],
    )
    return all(sum(1 for v in strip if v < DARK) / len(strip) >= MIN_FRAME_DARK for strip in strips)


def _has_gutter(dark_shares, size):
    """True when a run of black lines lies inside the gutter zone with paint on both sides."""
    low, high = GUTTER_ZONE[0] * size, GUTTER_ZONE[1] * size
    i = 0
    while i < size:
        if dark_shares[i] < MIN_GUTTER_DARK:
            i += 1
            continue
        start = i
        while i < size and dark_shares[i] >= MIN_GUTTER_DARK:
            i += 1
        if start > 0 and i < size and start >= low and i <= high:
            return True
    return False


def _gutters(raster):
    size, luma = raster.size, raster.luma
    rows = [sum(1 for x in range(size) if luma[y * size + x] < DARK) / size for y in range(size)]
    columns = [sum(1 for y in range(size) if luma[y * size + x] < DARK) / size for x in range(size)]
    found = []
    if _has_gutter(rows, size):
        found.append("grid:rows")
    if _has_gutter(columns, size):
        found.append("grid:columns")
    return found


def _off_centre(raster):
    size, luma = raster.size, raster.luma
    inner = round(size * CENTRE)
    centre_total = ring_total = 0
    sides = {"top": [0, 0], "bottom": [0, 0], "left": [0, 0], "right": [0, 0]}
    for y in range(size):
        for x in range(size):
            value = luma[y * size + x]
            if inner <= x < size - inner and inner <= y < size - inner:
                centre_total += value
                continue
            ring_total += value
            for side, inside in (("top", y < inner), ("bottom", y >= size - inner),
                                 ("left", x < inner), ("right", x >= size - inner)):
                if inside:
                    sides[side][0] += value
                    sides[side][1] += 1
    centre_count = (size - 2 * inner) ** 2
    centre_mean = centre_total / centre_count
    ring_mean = ring_total / (size * size - centre_count)
    if ring_mean <= 0 or centre_mean / ring_mean >= MIN_CENTRE_RATIO:
        return []
    brightest = max(sides, key=lambda side: sides[side][0] / sides[side][1])
    return [f"clipped:{brightest}"]


def judge_colour(raster, texts=()):
    """Set B: return the reasons to reject a full-colour painting; an empty list accepts it."""
    luma = raster.luma
    reasons = []
    if max(luma) < MIN_PEAK or _spread(luma) < BLANK_SD:
        reasons.append("blank")
    elif _spread(_block_means(raster, FLAT_SIZE)) < MIN_FLAT_SD:
        reasons.append("flat")
    if _framed(raster):
        reasons.append("frame")
    reasons.extend(_gutters(raster))
    reasons.extend(_off_centre(raster))
    reasons.extend(_readable(texts))
    return reasons


JUDGES = {"A": judge, "B": judge_colour}


def judge_for(set_name):
    """The check for an icon set: judge for A, judge_colour for B."""
    return JUDGES[set_name]


def load_raster(path, size=ANALYSIS_SIZE):
    try:
        from PIL import Image, ImageChops
    except ImportError as error:
        raise SystemExit("check_icons: Pillow is missing. Run with ~/.local/share/wow-dev/venv/bin/python.") from error
    with Image.open(path) as image:
        rgb = image.convert("RGB").resize((size, size), Image.BOX)
    red, green, blue = rgb.split()
    high = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    low = ImageChops.darker(ImageChops.darker(red, green), blue)
    return Raster(size, rgb.convert("L").tobytes(), ImageChops.subtract(high, low).tobytes())


def parse_ocr(output):
    """Map each path in the helper's JSON lines to its (text, confidence) readings."""
    readings = {}
    for line in output.splitlines():
        if not line.strip():
            continue
        entry = json.loads(line)
        if entry.get("error"):
            raise OcrError(f"{entry['path']}: {entry['error']}")
        readings[entry["path"]] = [(t["text"], float(t["confidence"])) for t in entry.get("texts", [])]
    return readings


def ocr_binary(cache_dir=DEFAULT_CACHE):
    """Compile the Vision helper once per source version and return its path."""
    digest = hashlib.sha256(OCR_SOURCE.read_bytes()).hexdigest()[:12]
    cache_dir = Path(cache_dir)
    binary = cache_dir / f"ocr_text-{digest}"
    if binary.exists():
        return binary
    swiftc = shutil.which("swiftc")
    if not swiftc:
        raise OcrError("swiftc not found: the text check needs macOS with the Xcode command line tools, or pass --no-text")
    cache_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=cache_dir) as tmp:
        built = Path(tmp) / "ocr_text"
        result = subprocess.run([swiftc, "-O", str(OCR_SOURCE), "-o", str(built)], capture_output=True, text=True)
        if result.returncode != 0:
            raise OcrError(f"swiftc failed: {result.stderr.strip()}")
        os.replace(built, binary)
    return binary


def read_text(paths, cache_dir=DEFAULT_CACHE):
    binary = ocr_binary(cache_dir)
    readings = {}
    paths = [str(p) for p in paths]
    for start in range(0, len(paths), 50):
        chunk = paths[start:start + 50]
        result = subprocess.run([str(binary), *chunk], capture_output=True, text=True)
        if result.returncode != 0:
            raise OcrError(f"the text helper failed: {result.stderr.strip()}")
        readings.update(parse_ocr(result.stdout))
    missing = [p for p in paths if p not in readings]
    if missing:
        raise OcrError(f"the text helper gave no result for {missing[0]}")
    return readings


def check_files(paths, text=True, cache_dir=DEFAULT_CACHE, set_name="A"):
    """Map each path to its reject reasons under the icon set's check."""
    check = judge_for(set_name)
    readings = read_text(paths, cache_dir) if text else {}
    return {str(p): check(load_raster(p), readings.get(str(p), ())) for p in paths}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("images", nargs="+", type=Path)
    parser.add_argument("--set", default="A", choices=sorted(JUDGES), help="the icon set whose rules apply")
    parser.add_argument("--no-text", action="store_true", help="skip the macOS Vision text check")
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE)
    args = parser.parse_args(argv)
    try:
        results = check_files(args.images, text=not args.no_text, cache_dir=args.cache_dir, set_name=args.set)
    except OcrError as error:
        print(f"check_icons: {error}", file=sys.stderr)
        return 2
    rejected = 0
    for path, reasons in results.items():
        if reasons:
            rejected += 1
            print(f"reject {path}: {', '.join(reasons)}")
        else:
            print(f"ok {path}")
    return 1 if rejected else 0


if __name__ == "__main__":
    sys.exit(main())
