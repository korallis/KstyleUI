"""Build native-texel ornaments from the Captain's original painted source sheets."""

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

from painted_ornaments import build_masters, pixel_data, premultiplied_resize


RAIL_ROWS = (
    (11,),
    (11, 12),
    (6, 11, 16),
    (6, 8, 11, 16),
    (6, 8, 11, 12, 16),
    (3, 6, 8, 11, 12, 16),
    (3, 6, 8, 10, 11, 12, 16),
    (1, 3, 6, 8, 10, 11, 12, 16),
    (1, 3, 6, 8, 10, 11, 12, 14, 16),
    (1, 3, 5, 6, 8, 10, 11, 12, 14, 16),
    (1, 3, 5, 6, 8, 10, 11, 12, 14, 16, 18),
    (1, 3, 5, 6, 7, 8, 10, 11, 12, 14, 16, 18),
)

def build(source, work, output, lua, reach=None):
    keep = set(json.loads(reach.read_text())) if reach else None
    masters = build_masters(source, work)
    output.mkdir(parents=True, exist_ok=True)
    assets = {}

    def painted(name, width=None, height=None):
        entry = masters["components"][name]
        image = Image.open(work / entry["file"]).convert("RGBA")
        if width is None:
            width = max(1, round(image.width * height / image.height))
        if height is None:
            height = max(1, round(image.height * width / image.width))
        return premultiplied_resize(image, (width, height))

    def save(name, image, sources):
        if keep is not None and name not in keep:
            return
        image.putdata([pixel if pixel[3] else (0, 0, 0, 0) for pixel in pixel_data(image)])
        width, height = image.size
        sw = 1 << (width - 1).bit_length()
        sh = 1 << (height - 1).bit_length()
        sheet = Image.new("RGBA", (sw, sh))
        sheet.paste(image, (0, 0))
        if name.startswith("Ring"):
            quantized = sheet.quantize(32, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGBA")
            quantized.paste((0, 0, 0, 0), mask=sheet.getchannel("A").point(lambda alpha: 255 if alpha == 0 else 0))
            sheet = quantized
        sheet.putdata([pixel if pixel[3] else (0, 0, 0, 0) for pixel in pixel_data(sheet)])
        path = output / (name + ".png")
        sheet.save(path, optimize=True)
        assets[name] = dict(width=width, height=height, sheet_width=sw, sheet_height=sh,
                            bytes=path.stat().st_size, sources=sources)

    for height in (6, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40, 48, 64):
        for family, piece in (("Arrow", "cap-arrow-left"), ("Wing", "cap-wing-left"),
                              ("SlimPlain", "slender-plain-left"), ("SlimElite", "slender-elite-left")):
            if height <= 32 or family.startswith("Slim"):
                save(family + str(height), painted(piece, height=height), [piece])
    for size in (12, 16, 20, 24, 32, 40):
        for family, piece in (("Map", "minimap-claw-top-left"),):
            image = painted(piece, width=size, height=size)
            if family == "Map":
                alpha = image.getchannel("A")
                outset = int(size * 0.4)
                ImageDraw.Draw(alpha).rectangle((outset, outset, size, size), fill=0)
                image.putalpha(alpha)
            save(family + str(size), image, [piece])
    for family, piece, heights in (
        ("Tray", "tray-finial-left", (20, 32, 40, 64, 80, 96)),
        ("Keystone", "tray-keystone", (6, 8, 12)),
        ("Crest", "window-crest-open", (6, 8, 12, 16, 20, 32, 48, 64)),
        ("Selected", "selected-crest", (8, 12, 16, 24)),
        ("Plaque", "minimap-plaque", (8, 12, 16, 20, 24, 28, 32)),
        ("Point", "minimap-point", (6, 12)),
        ("Corner", "corner-plain", (12, 16, 20, 24, 32, 40)),
    ):
        for height in heights:
            if height <= masters["components"][piece]["native_size"][1]:
                image = painted(piece, height=height)
                if family == "Plaque":
                    alpha = image.getchannel("A")
                    cx, cy = image.width / 2, image.height / 2
                    radius = height / 2 + 1
                    ImageDraw.Draw(alpha).ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=0)
                    image.putalpha(alpha)
                save(family + str(height), image, [piece])
    for family, piece, top, bottom in (
        ("Pointed", "frame-pointed", 44, 117),
        ("Clawed", "frame-clawed", 198, 270),
        ("Winged", "frame-winged", 367, 439),
        ("Crested", "frame-crested", 550, 626),
    ):
        entry = masters["components"][piece]
        width, height = entry["native_size"]
        for frame in list(range(8, 49)) + [52, 56, 60, 64]:
            scale = frame / (bottom - top)
            name = "End" + family + str(frame)
            save(name, painted(piece, max(1, round(width * scale)), max(1, round(height * scale))), [piece])
            if name in assets:
                assets[name]["anchor"] = [round((top - entry["source_bbox"][1]) * scale, 2), round(16.5 * scale, 2)]
    rail = Image.open(work / masters["components"]["rail-gold"]["file"]).convert("RGBA")
    for thickness, rows in enumerate(RAIL_ROWS, 1):
        strip = Image.new("RGBA", (16, thickness))
        for y, row in enumerate(rows):
            strip.paste(rail.crop((15, row, 31, row + 1)), (0, y))
        save("Rail" + str(thickness), strip, ["rail-gold"])
    riveted = Image.open(work / masters["components"]["rail-riveted"]["file"]).convert("RGBA")
    for thickness in range(2, 9):
        body = {2: 0, 3: 1, 4: 2, 5: 2}.get(thickness, thickness - 4)
        bands = {2: [(0, 7), (31, 36)], 3: [(0, 7), None, (31, 36)], 4: [(0, 7), None, None, (36, 43)],
                 5: [(0, 7), None, None, (31, 36), (36, 43)]}.get(thickness, [(0, 7), (7, 11)] + [None] * body + [(31, 36)])
        rivet_width = max(2 if thickness >= 3 else 1, round(body * 0.75))
        period = max(6, 3 * thickness)
        pad = max(1, round(30 * thickness / 43))
        chamfer = max(1, round(15 * thickness / 43))
        strip = Image.new("RGBA", (1024 // period * period, thickness))
        tip = Image.new("RGBA", (chamfer + period, thickness))
        row = 0
        for y, band in enumerate(bands):
            rivet = None
            if band is None:
                band = (11 + round(20 * row / body), 11 + round(20 * (row + 1) / body))
                rivet = (103, 14 + round(10 * row / body), 113, 14 + round(10 * (row + 1) / body)) if body > 1 else (103, 14, 113, 21)
                row += 1
            plain = premultiplied_resize(riveted, (pad, 1), box=(125, band[0], 155, band[1]))
            cell = Image.new("RGBA", (period, 1))
            for x in range(0, period, pad):
                cell.paste(plain, (x, 0))
            if rivet:
                cell.paste(premultiplied_resize(riveted, (rivet_width, 1), box=rivet), ((period - rivet_width) // 2, 0))
            for x in range(0, strip.width, period):
                strip.paste(cell, (x, y))
            tip.paste(premultiplied_resize(riveted, (chamfer, 1), box=(0, band[0], 15, band[1])), (0, y))
            tip.paste(cell, (chamfer, y))
        save("Forge" + str(thickness), strip, ["rail-riveted"])
        if "Forge" + str(thickness) in assets:
            assets["Forge" + str(thickness)]["period"] = period
        save("Tip" + str(thickness), tip, ["rail-riveted"])
    for family, piece, origin, centre, radius in (
        ("ElitePendantR", "portrait-elite-pendant", (413, 438), (455.5529, 315.7641), 114.9923),
        ("BossPendantR", "portrait-boss-pendant", (739, 429), (815.147, 311.353), 117.652),
    ):
        native = masters["components"][piece]["native_size"]
        for hole in (14, 17, 20, 24, 28, 32, 38, 44, 52, 60, 70, 80):
            scale = hole / radius
            image = painted(piece, max(1, round(native[0] * scale)), max(1, round(native[1] * scale)))
            ax = (centre[0] - origin[0]) * image.width / native[0]
            ay = (centre[1] - origin[1]) * image.height / native[1]
            alpha = image.getchannel("A")
            ImageDraw.Draw(alpha).ellipse((ax - hole - 1, ay - hole - 1, ax + hole + 1, ay + hole + 1), fill=0)
            image.putalpha(alpha)
            save(family + str(hole), image, [piece])
            if family + str(hole) in assets:
                assets[family + str(hole)]["anchor"] = [round(ax, 2), round(ay, 2)]
    for side in sorted(set(range(24, 161, 2)) | {39, 59, 79}):
        ideal = math.ceil((2.555 * (side / 2 + 1) - side) / 2)
        padding = min(ideal, max(4, int(side * 0.14)))
        diameter = side + 2 * padding
        full = painted("portrait-plain", side + 2 * ideal, side + 2 * ideal)
        image = full.crop((ideal - padding, ideal - padding, ideal + side + padding, ideal + side + padding))
        rim = image.getchannel("A")
        edge = Image.new("L", (diameter * 4, diameter * 4), 0)
        ImageDraw.Draw(edge).ellipse((0, 0, diameter * 4 - 1, diameter * 4 - 1), fill=255)
        edge = edge.resize((diameter, diameter), Image.Resampling.LANCZOS)
        image.putalpha(ImageChops.multiply(rim, edge))
        alpha = image.getchannel("A")
        draw = ImageDraw.Draw(alpha)
        draw.ellipse((padding - 2, padding - 2, padding + side + 2, padding + side + 2), fill=0)
        centre = padding + side * 0.88
        radius = side * 0.20 + 2
        draw.ellipse((centre - radius, centre - radius, centre + radius, centre + radius), fill=0)
        image.putalpha(alpha)
        save("Ring" + str(side), image, ["portrait-plain"])
    manifest = {"assets": assets, "source_manifest": masters["sources"],
                "total_bytes": sum(asset["bytes"] for asset in assets.values())}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for path in output.glob("*.png"):
        if path.stem not in assets:
            path.unlink()
    lines = ["-- OrnamentData.lua: native dimensions and source crops generated by Tools/media/ornaments.py.",
             "local _, ns = ...", "ns.Widgets.OrnamentAssets = {"]
    for name, entry in sorted(assets.items()):
        anchor = "".join(", %.2f" % value for value in entry.get("anchor", ()))
        lines.append("\t%s = { %d, %d, %d, %d%s }," %
                     (name, entry["width"], entry["height"], entry["sheet_width"], entry["sheet_height"], anchor))
    lines.append("}")
    lua.write_bytes(("\r\n".join(lines) + "\r\n").encode("ascii"))
    provenance = Path("Media/PROVENANCE.md")
    text = provenance.read_text()
    start = text.index("## Forged ornament study")
    end = text.index("## Ability icons", start)
    rows = ["## Forged ornament study", "",
            "Original painted sources generated by the project Captain with Higgsfield gpt_image_2_6 on 2026-11-10. "
            "No artwork was extracted or traced from a game. The source sheets and prompts are retained in the Captain's "
            "handoffs/ornament-study folder. Tools/media/painted_ornaments.py keys and despills their magenta backgrounds; "
            "Tools/media/ornaments.py crops, premultiplies, downsamples and masks the original painted pieces to preserve "
            "existing content. Runtime placement is one physical pixel per authored texel, without stretching. "
            "Every PNG uses RGBA encoding. Ring colours are reduced to 32 entries without dithering before RGBA export; "
            "fully transparent source pixels remain exactly transparent. Other pieces retain their downsampled RGBA samples. "
            "Native loading still needs the client's in-game pass.", "",
            "The source SHA-256 hashes, crop sizes and PNG byte counts are recorded in "
            "`Media/Textures/ForgedOrnaments/manifest.json`. This remains a local, opt-in study.", "",
            "| File | Native texels | Painted source cut | PNG bytes |", "| --- | --- | --- | ---: |"]
    for name, entry in sorted(assets.items()):
        rows.append("| `Media/Textures/ForgedOrnaments/%s.png` | %dx%d | %s | %d |" %
                    (name, entry["width"], entry["height"], ", ".join(entry["sources"]), entry["bytes"]))
    provenance.write_text(text[:start] + "\n".join(rows) + "\n\n" + text[end:])
    print(len(assets), "native assets:", manifest["total_bytes"], "bytes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("Media/Textures/ForgedOrnaments"))
    parser.add_argument("--lua", type=Path, default=Path("Core/Widgets/OrnamentData.lua"))
    parser.add_argument("--reach", type=Path, default=Path("Tools/media/ornament_reach.json"),
                        help="ship only the pieces this reach table names")
    args = parser.parse_args()
    build(args.source, args.work, args.output, args.lua, args.reach)


if __name__ == "__main__":
    main()
