"""Extract original painted ornaments; all coordinates are top-left, half-open texels."""

import argparse
from collections import Counter, deque
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps


SHEETS = {
    "portrait-rings": (1024, 688),
    "bar-end-caps": (1024, 688),
    "bar-frames": (1024, 688),
    "action-bar-tray": (1344, 752),
    "minimap-frame": (1024, 1024),
    "slot-frames": (1024, 1024),
    "crests-keystones": (1024, 688),
    "bar-end-caps-slender-a": (1024, 688),
    "bar-end-caps-slender-b": (1024, 688),
    "frame-parts": (1024, 688),
    "unit-frame-plates-a": (1024, 688),
    "unit-frame-plates-b": (1024, 688),
}


def pixel_data(image):
    if hasattr(image, "get_flattened_data"):
        return image.get_flattened_data()
    return image.getdata()


def selections():
    result = []

    def add(name, sheet, box, transforms=("identity",), hole=None):
        for transform in transforms:
            suffix = "" if len(transforms) == 1 else "-" + transform
            result.append((name + suffix, sheet, box, transform, hole))

    for name, box, seed in [
        ("plain", (1, 150, 302, 480), (149, 316)),
        ("elite", (303, 60, 608, 604), (455, 316)),
        ("boss", (608, 0, 1024, 688), (817, 312)),
    ]:
        add("portrait-" + name, "portrait-rings", box, hole=seed)
    for name, box in [
        ("elite-crown", (363, 68, 547, 198)),
        ("elite-pendant", (413, 438, 500, 596)),
        ("boss-crown", (678, 0, 959, 204)),
        ("boss-pendant", (739, 429, 895, 688)),
    ]:
        add("portrait-" + name, "portrait-rings", box)
    add("portrait-boss-wing", "portrait-rings", (608, 295, 705, 381), ("left", "right"))
    for name, box in [
        ("arrow", (15, 30, 230, 205)),
        ("diamond", (540, 15, 740, 215)),
        ("claw", (25, 228, 230, 445)),
        ("fang", (540, 228, 740, 447)),
        ("wing", (15, 470, 230, 655)),
        ("blunt", (550, 480, 740, 655)),
    ]:
        add("cap-" + name, "bar-end-caps", box, ("left", "right"))
    for name, sheet, box in [
        ("plain", "bar-end-caps-slender-b", (50, 10, 112, 290)),
        ("claw", "bar-end-caps-slender-a", (739, 10, 833, 294)),
        ("elite", "bar-end-caps-slender-b", (386, 310, 479, 664)),
    ]:
        add("slender-" + name, sheet, box, ("left", "right"))
    add("tray-finial", "action-bar-tray", (8, 150, 240, 553), ("left", "right"))
    add("tray-keystone", "action-bar-tray", (532, 418, 815, 598))
    add("selected-crest", "bar-frames", (397, 468, 626, 568))
    for name, box in [
        ("pointed", (31, 44, 121, 117)),
        ("clawed", (40, 177, 136, 303)),
        ("winged", (11, 331, 152, 450)),
        ("crested", (12, 517, 134, 661)),
    ]:
        add("frame-" + name, "bar-frames", box)
    add("rail-gold", "unit-frame-plates-b", (300, 15, 340, 38))
    add("rail-riveted", "frame-parts", (545, 8, 970, 60))
    add("corner-plain", "frame-parts", (50, 5, 235, 165))
    add("minimap-claw", "minimap-frame", (16, 16, 184, 187),
        ("top-left", "top-right", "bottom-right", "bottom-left"))
    add("minimap-plaque", "minimap-frame", (388, 0, 638, 145))
    add("minimap-point", "minimap-frame", (407, 861, 618, 1024))
    add("slot-claw", "slot-frames", (697, 134, 761, 199),
        ("top-left", "top-right", "bottom-right", "bottom-left"))
    add("slot-heavy-claw", "slot-frames", (10, 537, 102, 633),
        ("top-left", "top-right", "bottom-right", "bottom-left"))
    for name, box in [
        ("window-crest", (16, 4, 340, 255)),
        ("window-crest-crowned", (696, 4, 1015, 252)),
        ("window-crest-open", (347, 4, 679, 275)),
        ("window-keystone", (38, 267, 249, 501)),
        ("window-stud", (291, 285, 486, 483)),
        ("window-pendant", (562, 256, 701, 515)),
        ("window-pendant-wide", (776, 256, 963, 502)),
        ("divider", (8, 529, 508, 665)),
        ("divider-tall", (515, 501, 1016, 684)),
    ]:
        add(name, "crests-keystones", box)
    return result


def despill(rgb):
    r, g, b = rgb
    excess = max(0, min(r, b) - g)
    return r - excess, g, b - excess


def key_magenta(image):
    image = image.convert("RGBA")
    pixels = list(pixel_data(image))
    candidates = ((r, g, b) for r, g, b, a in pixels
                  if a and r > 220 and b > 220 and g < 32)
    counts = Counter(candidates)
    if not counts:
        raise ValueError("Source has no magenta key background")
    key = counts.most_common(1)[0][0]
    difference = min(key[0], key[2]) - key[1]
    output = []
    for r, g, b, original_alpha in pixels:
        coverage = max(0.0, min(1.0, (difference - (min(r, b) - g) - 8)
                                / (difference - 8)))
        alpha = round(coverage * original_alpha)
        if alpha <= 3:
            output.append((0, 0, 0, 0))
            continue
        rgb = [max(0, min(255, round((c - (1 - coverage) * k) / coverage)))
               for c, k in zip((r, g, b), key)]
        output.append((*despill(rgb), alpha))
    result = Image.new("RGBA", image.size)
    result.putdata(output)
    return result, key


def load_sheet(image):
    image = image.convert("RGBA") if image.mode in ("RGBA", "LA", "P") else image
    if image.mode == "RGBA" and image.getchannel("A").getextrema()[0] == 0:
        image = image.copy()
        image.putdata([(*despill(pixel[:3]), pixel[3]) if pixel[3] > 3 else (0, 0, 0, 0)
                       for pixel in pixel_data(image)])
        return image, None
    return key_magenta(image)


def connected_region(mask, seed=None):
    width, height = mask.size
    pixels = bytearray(mask.tobytes())
    regions = []
    indices = [seed[1] * width + seed[0]] if seed else range(len(pixels))
    for start in indices:
        if not pixels[start]:
            continue
        pixels[start] = 0
        queue = deque([start])
        region = []
        while queue:
            i = queue.popleft()
            region.append(i)
            x, y = i % width, i // width
            neighbors = []
            if x:
                neighbors.append(i - 1)
            if x + 1 < width:
                neighbors.append(i + 1)
            if y:
                neighbors.append(i - width)
            if y + 1 < height:
                neighbors.append(i + width)
            for j in neighbors:
                if pixels[j]:
                    pixels[j] = 0
                    queue.append(j)
        regions.append(region)
    if not regions:
        raise ValueError("No connected painted component")
    selected = max(regions, key=len)
    data = bytearray(width * height)
    for i in selected:
        data[i] = 255
    return Image.frombytes("L", mask.size, bytes(data))


def isolate(image, box):
    crop = image.crop(box)
    alpha = crop.getchannel("A")
    core = connected_region(alpha.point(lambda a: 255 if a >= 64 else 0))
    halo = core.filter(ImageFilter.MaxFilter(5))
    alpha.putdata([a if keep else 0 for a, keep in zip(pixel_data(alpha), pixel_data(halo))])
    crop.putalpha(alpha)
    bounds = alpha.getbbox()
    if not bounds:
        raise ValueError("Empty painted component")
    tight = crop.crop(bounds)
    tight.putdata([pixel if pixel[3] else (0, 0, 0, 0) for pixel in pixel_data(tight)])
    source_box = [bounds[0] + box[0], bounds[1] + box[1],
                  bounds[2] + box[0], bounds[3] + box[1]]
    return tight, source_box


def solve_linear(matrix, values):
    count = len(values)
    rows = [list(row) + [value] for row, value in zip(matrix, values)]
    for col in range(count):
        pivot = max(range(col, count), key=lambda i: abs(rows[i][col]))
        rows[col], rows[pivot] = rows[pivot], rows[col]
        factor = rows[col][col]
        if abs(factor) < 1e-10:
            raise ValueError("Degenerate portrait hole")
        rows[col] = [x / factor for x in rows[col]]
        for row in range(count):
            if row != col:
                factor = rows[row][col]
                rows[row] = [x - factor * y for x, y in zip(rows[row], rows[col])]
    return [row[count] for row in rows]


def boundary_points(mask):
    inside = mask.filter(ImageFilter.MinFilter(3))
    return [(i % mask.width + 0.5, i // mask.width + 0.5)
            for i, (a, b) in enumerate(zip(pixel_data(mask), pixel_data(inside))) if a and not b]


def fit_ellipse(mask, source_box):
    points = boundary_points(mask)
    mx, my = mask.width / 2, mask.height / 2
    scale = max(mask.size)
    rows = [(((x-mx)/scale)**2, ((y-my)/scale)**2, (x-mx)/scale, (y-my)/scale)
            for x, y in points]
    matrix = [[sum(row[i] * row[j] for row in rows) for j in range(4)] for i in range(4)]
    rhs = [sum(row[i] for row in rows) for i in range(4)]
    a, b, c, d = solve_linear(matrix, rhs)
    cx, cy = -c / (2*a), -d / (2*b)
    level = 1 + a*cx*cx + b*cy*cy
    rx, ry = math.sqrt(level/a)*scale, math.sqrt(level/b)*scale
    cx, cy = cx*scale + mx, cy*scale + my
    errors = [abs(math.hypot((x-cx)/rx, (y-cy)/ry)-1) * min(rx, ry) for x, y in points]
    box = mask.getbbox()
    return {"center_local": [round(cx, 4), round(cy, 4)],
            "center_source": [round(cx + source_box[0], 4), round(cy + source_box[1], 4)],
            "radii_xy": [round(rx, 4), round(ry, 4)],
            "bbox_local": list(box),
            "bbox_source": [box[i] + source_box[i % 2] for i in range(4)],
            "rms_error_texels": round(math.sqrt(sum(e*e for e in errors)/len(errors)), 4)}


def inner_circle(image, source_box, seed, measure_outer=False):
    local_seed = (seed[0] - source_box[0], seed[1] - source_box[1])
    mask = image.getchannel("A").point(lambda a: 255 if a < 128 else 0)
    hole = connected_region(mask, local_seed)
    box = hole.getbbox()
    if box[0] == 0 or box[1] == 0 or box[2] == image.width or box[3] == image.height:
        raise ValueError("Portrait centre is not hollow and enclosed")
    points = boundary_points(hole)
    rows = [(x, y, 1) for x, y in points]
    values = [-(x*x + y*y) for x, y in points]
    matrix = [[sum(row[i] * row[j] for row in rows) for j in range(3)] for i in range(3)]
    rhs = [sum(row[i] * value for row, value in zip(rows, values)) for i in range(3)]
    a, b, c = solve_linear(matrix, rhs)
    cx, cy = -a / 2, -b / 2
    radius = math.sqrt(cx*cx + cy*cy - c)
    distances = [math.hypot(x-cx, y-cy) for x, y in points]
    result = {
        "alpha_threshold": 128,
        "hole_bbox_local": list(box),
        "hole_bbox_source": [box[i] + source_box[i % 2] for i in range(4)],
        "center_local": [round(cx, 4), round(cy, 4)],
        "center_source": [round(cx + source_box[0], 4), round(cy + source_box[1], 4)],
        "radius_fit": round(radius, 4),
        "radius_safe": round(min(distances), 4),
        "radius_max": round(max(distances), 4),
        "rms_error": round(math.sqrt(sum((r-radius)**2 for r in distances) / len(distances)), 4),
    }
    result["ellipse"] = fit_ellipse(hole, source_box)
    if measure_outer:
        solid = image.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
        padded = ImageOps.expand(solid, 1)
        outside = connected_region(ImageOps.invert(padded), (0, 0))
        outer = ImageOps.invert(outside).crop((1, 1, image.width + 1, image.height + 1))
        result["outer_ellipse"] = fit_ellipse(outer, source_box)
    return result


def transform_piece(image, transform):
    if transform in ("right", "top-right"):
        return ImageOps.mirror(image)
    if transform == "bottom-right":
        return image.transpose(Image.Transpose.ROTATE_180)
    if transform == "bottom-left":
        return ImageOps.flip(image)
    return image


def validate_alpha(image):
    pixels = list(pixel_data(image))
    dirty_zero = sum(1 for r, g, b, a in pixels if not a and (r or g or b))
    magenta = sum(1 for r, g, b, a in pixels if a and min(r, b) > g)
    partial = sum(1 for r, g, b, a in pixels if 0 < a < 255)
    if dirty_zero or magenta:
        raise ValueError(f"Unclean alpha: {dirty_zero} dirty transparent, {magenta} magenta pixels")
    return {"partial_alpha_pixels": partial, "magenta_pixels": magenta,
            "dirty_transparent_pixels": dirty_zero}


def contact_sheet(images, output):
    cell_width, cell_height, columns = 390, 380, 4
    rows = math.ceil(len(images) / columns)
    sheet = Image.new("RGB", (cell_width * columns, cell_height * rows), (27, 29, 31))
    draw = ImageDraw.Draw(sheet)
    for index, (name, image) in enumerate(images.items()):
        x = index % columns * cell_width
        y = index // columns * cell_height
        draw.text((x + 10, y + 8), name, fill=(239, 219, 171))
        draw.text((x + 10, y + 23), f"native {image.width} x {image.height}", fill=(185, 185, 185))
        preview = image.copy()
        preview.thumbnail((cell_width - 20, cell_height - 50), Image.Resampling.LANCZOS)
        left = x + (cell_width - preview.width) // 2
        top = y + 43 + (cell_height - 50 - preview.height) // 2
        draw.rectangle((x + cell_width // 2, y + 40, x + cell_width - 1, y + cell_height - 1),
                       fill=(178, 178, 170))
        sheet.paste(preview, (left, top), preview)
    sheet.save(output)
    page_height = cell_height * 4
    page_prefix = output.stem.removesuffix("-sheet")
    for page, top in enumerate(range(0, sheet.height, page_height), 1):
        sheet.crop((0, top, sheet.width, min(top + page_height, sheet.height))).save(
            output.with_name(f"{page_prefix}-page-{page}.png"))


def build_masters(source_directory, output_directory):
    source_directory, output_directory = Path(source_directory), Path(output_directory)
    masters = output_directory / "masters"
    masters.mkdir(parents=True, exist_ok=True)
    manifest = {
        "version": 1,
        "coordinates": "top-left half-open integer texels; source_bbox before transform",
        "transforms": {"identity": "identity", "left": "identity", "right": "mirror-x",
                       "top-left": "identity", "top-right": "mirror-x",
                       "bottom-right": "rotate-180", "bottom-left": "mirror-y"},
        "keying": {"method": "colour-difference unmix, neutral despill",
                   "key_noise_allowance": 8, "alpha_floor": 3,
                   "component_core_alpha": 64, "antialias_halo_texels": 2},
        "sources": {}, "components": {},
    }
    sheets, images = {}, {}
    for name, size in SHEETS.items():
        path = source_directory / (name + ".png")
        with Image.open(path) as original:
            if original.size != size:
                raise ValueError(f"{path.name}: expected native size {size}, got {original.size}")
            sheets[name], key = load_sheet(original)
        manifest["sources"][name] = {"file": path.name, "size": list(size), "key_rgb": list(key) if key else None,
                                     "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    for name, sheet, box, transform, seed in selections():
        image, source_box = isolate(sheets[sheet], box)
        circle = inner_circle(image, source_box, seed, name == "portrait-plain") if seed else None
        image = transform_piece(image, transform)
        images[name] = image
        path = masters / (name + ".png")
        image.save(path, optimize=True)
        entry = {"file": "masters/" + path.name, "source": sheet, "selection_bbox": list(box),
                 "source_bbox": source_box, "transform": transform, "native_size": list(image.size),
                 "bytes": path.stat().st_size, "validation": validate_alpha(image)}
        if circle:
            entry["inner_circle"] = circle
        manifest["components"][name] = entry
    (output_directory / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    contact_sheet(images, output_directory / "contact-sheet.png")
    return manifest


def premultiplied_resize(image, size, box=None):
    if any(not isinstance(value, int) or value <= 0 for value in size) or len(size) != 2:
        raise ValueError("Requested size must be two positive integer texel counts")
    image = image.convert("RGBA")
    available = (box[2] - box[0], box[3] - box[1]) if box else image.size
    if size[0] > available[0] or size[1] > available[1]:
        raise ValueError("Painted exports may downsample, not invent higher-resolution detail")
    pixels = list(pixel_data(image))
    channels = []
    for channel in range(4):
        plane = Image.new("F", image.size)
        plane.putdata([pixel[channel] * pixel[3] / 255 if channel < 3 else pixel[3]
                       for pixel in pixels])
        channels.append(list(pixel_data(plane.resize(tuple(size), Image.Resampling.LANCZOS, box=box))))
    output = []
    for r, g, b, a in zip(*channels):
        alpha = max(0, min(255, round(a)))
        if not alpha:
            output.append((0, 0, 0, 0))
        else:
            rgb = [max(0, min(255, round(value * 255 / max(a, 1e-6)))) for value in (r, g, b)]
            output.append((*despill(rgb), alpha))
    result = Image.new("RGBA", tuple(size))
    result.putdata(output)
    return result


def portrait_band(image, outer_ellipse, hole_diameter, band_width):
    if any(type(value) is not int or value <= 0 for value in (hole_diameter, band_width)):
        raise ValueError("Hole diameter and outward band width must be positive integer texels")
    diameter = hole_diameter + 2 * band_width
    cx, cy = outer_ellipse["center_local"]
    rx, ry = outer_ellipse["radii_xy"]
    box = (cx-rx, cy-ry, cx+rx, cy+ry)
    band = premultiplied_resize(image, (diameter, diameter), box)
    pixels = []
    center = diameter / 2
    for i, (r, g, b, a) in enumerate(pixel_data(band)):
        distance = math.hypot(i % diameter + 0.5 - center, i // diameter + 0.5 - center)
        alpha = round(a * max(0, min(1, distance - hole_diameter / 2)))
        pixels.append((r, g, b, alpha) if alpha else (0, 0, 0, 0))
    band.putdata(pixels)
    return band


def write_padded(image, output_directory, name, padding, image_format):
    width, height = image.size
    sheet_size = [1 << (value + 2 * padding - 1).bit_length() for value in (width, height)]
    padded = Image.new("RGBA", tuple(sheet_size))
    padded.paste(image, (padding, padding))
    path = Path(output_directory) / (name + "." + image_format)
    padded.save(path, optimize=True)
    return {"file": path.name, "content_size": [width, height], "texture_size": sheet_size,
            "content_bbox": [padding, padding, padding + width, padding + height],
            "uv": [padding / sheet_size[0], (padding + width) / sheet_size[0],
                   padding / sheet_size[1], (padding + height) / sheet_size[1]],
            "bytes": path.stat().st_size, "validation": validate_alpha(padded)}


def export_sizes(master_directory, output_directory, requests, padding=2, image_format="png"):
    if not isinstance(padding, int) or padding < 0:
        raise ValueError("Padding must be a nonnegative integer")
    if image_format not in ("png", "tga"):
        raise ValueError("Export format must be png or tga")
    master_directory, output_directory = Path(master_directory), Path(output_directory)
    manifest = json.loads((master_directory / "manifest.json").read_text())
    output_directory.mkdir(parents=True, exist_ok=True)
    exported = {"version": 1, "sampling": "1:1; no runtime resizing",
                "uv_order": "left, right, top, bottom; half-open content edges", "components": {}}
    for name, size in requests.items():
        source = manifest["components"][name]
        with Image.open(master_directory / source["file"]) as original:
            image = premultiplied_resize(original, size)
        width, height = image.size
        entry = write_padded(image, output_directory, f"{name}-{width}x{height}", padding, image_format)
        entry["scale_xy"] = [width / source["native_size"][0], height / source["native_size"][1]]
        if "inner_circle" in source:
            circle = source["inner_circle"]
            ellipse = circle["ellipse"]
            sx, sy = entry["scale_xy"]
            entry["inner_ellipse"] = {
                "center_content": [ellipse["center_local"][0] * sx, ellipse["center_local"][1] * sy],
                "radii_fit": [ellipse["radii_xy"][0] * sx, ellipse["radii_xy"][1] * sy],
                "safe_circle_radii": [max(0, circle["radius_safe"] * sx - 1),
                                      max(0, circle["radius_safe"] * sy - 1)],
            }
        exported["components"][name] = entry
    exported["total_bytes"] = sum(entry["bytes"] for entry in exported["components"].values())
    (output_directory / "manifest.json").write_text(json.dumps(exported, indent=2) + "\n")
    return exported


def export_band(master_directory, output_directory, hole_diameter, band_width, padding=2):
    if type(padding) is not int or padding < 0:
        raise ValueError("Padding must be a nonnegative integer")
    master_directory, output_directory = Path(master_directory), Path(output_directory)
    source = json.loads((master_directory / "manifest.json").read_text())["components"]["portrait-plain"]
    with Image.open(master_directory / source["file"]) as original:
        band = portrait_band(original, source["inner_circle"]["outer_ellipse"], hole_diameter, band_width)
    output_directory.mkdir(parents=True, exist_ok=True)
    name = f"portrait-band-hole{hole_diameter}-width{band_width}"
    entry = write_padded(band, output_directory, name, padding, "png")
    entry["source_component"] = "portrait-plain"
    entry["hole_diameter"] = hole_diameter
    entry["outward_band_width"] = band_width
    entry["center_content"] = [band.width / 2, band.height / 2]
    entry["hole_policy"] = "alpha zero at every texel centre inside hole radius; 1 texel outward AA"
    (output_directory / (name + ".json")).write_text(json.dumps(entry, indent=2) + "\n")
    return entry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    masters = commands.add_parser("masters", help="key source sheets and isolate native painted masters")
    masters.add_argument("source_directory", type=Path)
    masters.add_argument("output_directory", type=Path)
    export = commands.add_parser("export", help="downsample only the requested components and POT-pad")
    export.add_argument("master_directory", type=Path)
    export.add_argument("output_directory", type=Path)
    export.add_argument("--size", action="append", required=True, metavar="NAME=WIDTHxHEIGHT")
    export.add_argument("--padding", type=int, default=2)
    export.add_argument("--format", choices=("png", "tga"), default="png")
    band = commands.add_parser("band", help="fit painted plain band and clear an exact hole offline")
    band.add_argument("master_directory", type=Path)
    band.add_argument("output_directory", type=Path)
    band.add_argument("--hole-diameter", type=int, required=True,
                      help="fully clear diameter in texels, including desired portrait clearance")
    band.add_argument("--band-width", type=int, required=True, help="outward band width in texels")
    band.add_argument("--padding", type=int, default=2)
    args = parser.parse_args()
    if args.command == "masters":
        manifest = build_masters(args.source_directory, args.output_directory)
        print(f"Wrote {len(manifest['components'])} native masters, manifest and contact sheet")
    elif args.command == "band":
        entry = export_band(args.master_directory, args.output_directory, args.hole_diameter,
                            args.band_width, args.padding)
        print(f"Wrote {entry['file']}; {entry['bytes']} texture bytes")
    else:
        requests = {}
        for request in args.size:
            name, dimensions = request.split("=", 1)
            requests[name] = tuple(int(value) for value in dimensions.lower().split("x"))
        manifest = export_sizes(args.master_directory, args.output_directory, requests,
                                args.padding, args.format)
        print(f"Wrote {len(requests)} exports; {manifest['total_bytes']} texture bytes")


if __name__ == "__main__":
    main()
