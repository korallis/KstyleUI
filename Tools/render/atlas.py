"""Build the renderer's atlas cache from the installed game client, read-only.

Usage: python3 Tools/render/atlas.py build [NAME ...] [--scan] [--cache ~/.local/share/wow-dev/atlas]
       python3 Tools/render/atlas.py fetch NAME ... [--scan] [--cache ~/.local/share/wow-dev/atlas]

The game draws an atlas (`texture:SetAtlas(name)`) as a rectangle of a larger sheet. The UI source has no atlas
data; the client does, in three DB2 tables (UiTextureAtlas: the sheets, their file IDs and sizes; UiTextureAtlasMember:
each member's rectangle on a sheet; UiTextureAtlasElement: the names the game looks up). `build` exports those
tables with Tools/icons/casc_export.py (TACTTool and DBC2CSV, which read the game folder and never write to it),
writes `atlas.tsv`, one line per element, and fetches the sheets the named atlases need into `textures/<fileID>.png`.
`fetch` adds sheets to an existing cache. `--scan` adds every atlas name the scene JSON files in Tools/render/out
mention, so a run after a render fetches what that render lacked. The cache lives outside the repository;
`Tools/render/scene.lua` reads it when present and draws a grey box when not.

An element can have several members: a 1x and a 2x sheet, and Forever's own art with a `-c60` suffix. The map
keeps one: Forever's member over the shared one, the 2x sheet over the 1x, and the member's size in 1x units (what
`SetAtlas(name, true)` sizes a region to). The map is 2 MB of text, so it is a TSV and not a Lua table.
"""

import argparse
import csv
import glob
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ICONS = HERE.parent / "icons"
DEFAULT_CACHE = Path.home() / ".local" / "share" / "wow-dev" / "atlas"
DEFAULT_TOOLS = Path.home() / ".local" / "share" / "wow-dev"
DEFAULT_WOW_DIR = Path("/Applications/World of Warcraft")
PRODUCT, REGION = "wowf", "eu"
TABLES = ("UiTextureAtlas", "UiTextureAtlasMember", "UiTextureAtlasElement")
COLUMNS = ("name", "file", "atlasWidth", "atlasHeight", "left", "right", "top", "bottom", "width", "height", "tilesH", "tilesV")
FLAG_TILES_V, FLAG_TILES_H, FLAG_NO_TILE = 2, 4, 16
SCENE_JSON = str(HERE / "out" / "*.json")


def _rows(path):
    with open(path, newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def _int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _rank(member, canvas):
    """Higher is better: Forever's -c60 art, then the 2x sheet, then the newest member."""
    return ("-c60" in member["CommittedName"].lower(), canvas == 2, _int(member["ID"]))


def build_map(db2_dir):
    """Return {element name lowercased: entry} from the three exported tables in db2_dir."""
    db2_dir = Path(db2_dir)
    sheets = {row["ID"]: row for row in _rows(db2_dir / "UiTextureAtlas.csv")}
    elements = {row["ID"]: row["Name"] for row in _rows(db2_dir / "UiTextureAtlasElement.csv")}
    grouped = {}
    for member in _rows(db2_dir / "UiTextureAtlasMember.csv"):
        sheet = sheets.get(member["UiTextureAtlasID"])
        name = elements.get(member["UiTextureAtlasElementID"])
        if sheet is None or name is None:
            continue
        grouped.setdefault(name, []).append((member, sheet))
    out = {}
    for name, members in grouped.items():
        def canvas_of(pair):
            return _int(pair[1]["UiCanvasID"], 1)

        best, sheet = max(members, key=lambda pair: _rank(pair[0], canvas_of(pair)))
        # The size in 1x units comes from a 1x member when there is one, else from the 2x member halved.
        one_x = [pair for pair in members if canvas_of(pair) != 2]
        size_member, size_canvas = (max(one_x, key=lambda pair: _rank(pair[0], 1))[0], 1) if one_x else (best, 2)
        width = _int(size_member["OverrideWidth"]) or _int(size_member["Width"])
        height = _int(size_member["OverrideHeight"]) or _int(size_member["Height"])
        if size_canvas == 2:
            width, height = width // 2, height // 2
        flags = _int(best["CommittedFlags"])
        tiles = not flags & FLAG_NO_TILE
        out[name.lower()] = {
            "name": name,
            "file": _int(sheet["FileDataID"]),
            "atlasWidth": _int(sheet["AtlasWidth"]),
            "atlasHeight": _int(sheet["AtlasHeight"]),
            "left": _int(best["CommittedLeft"]),
            "right": _int(best["CommittedRight"]),
            "top": _int(best["CommittedTop"]),
            "bottom": _int(best["CommittedBottom"]),
            "width": width,
            "height": height,
            "tilesH": bool(tiles and flags & FLAG_TILES_H),
            "tilesV": bool(tiles and flags & FLAG_TILES_V),
        }
    return out


def write_tsv(atlas_map, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = ["\t".join(COLUMNS)]
    for key in sorted(atlas_map):
        entry = atlas_map[key]
        values = [key] + [str(int(entry[column])) for column in COLUMNS[1:]]
        lines.append("\t".join(values))
    partial = path.with_suffix(".tmp")
    partial.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.replace(partial, path)


def read_tsv(path):
    atlas_map = {}
    with open(path, encoding="utf-8") as handle:
        header = handle.readline().rstrip("\n").split("\t")
        for line in handle:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != len(header):
                continue
            entry = dict(zip(header, parts))
            for column in COLUMNS[1:]:
                entry[column] = int(entry[column])
            entry["tilesH"], entry["tilesV"] = bool(entry["tilesH"]), bool(entry["tilesV"])
            atlas_map[entry["name"]] = entry
    return atlas_map


def scan_names(json_paths):
    """Every atlas name (lowercased) the scene JSON files mention."""
    names = set()
    for path in json_paths:
        with open(path, encoding="utf-8") as handle:
            scene = json.load(handle)
        for item in scene.get("items") or []:
            atlas = item.get("atlas")
            if isinstance(atlas, str) and atlas:
                names.add(atlas.lower())
    return names


def tacttool(file_id, blp, cache_dir, tools=DEFAULT_TOOLS, wow_dir=DEFAULT_WOW_DIR):
    """Extract one file by ID with TACTTool, which reads the game folder only; its own cache goes under cache_dir."""
    tool = Path(tools) / "casc" / "TACTTool" / "TACTTool"
    if not tool.exists():
        raise RuntimeError(f"{tool} is missing; run Tools/icons/install-casc-tools.sh")
    work = Path(cache_dir) / "tact"
    work.mkdir(parents=True, exist_ok=True)
    command = [str(tool), "-p", PRODUCT, "-r", REGION, "-d", str(wow_dir), "-m", "id", "-i", str(file_id), "-o", str(Path(blp).resolve())]
    result = subprocess.run(command, cwd=work, capture_output=True, text=True, timeout=600)
    if result.returncode != 0:
        raise RuntimeError(f"TACTTool failed for {file_id}: {(result.stderr or result.stdout).strip()[-300:]}")


def decode_blp(blp, png):
    """Decode a sheet to an RGBA PNG at its own size: Pillow reads palette and DXT BLPs, iconset.py the raw ones."""
    sys.path.insert(0, str(ICONS))
    import iconset  # noqa: E402  (Tools/icons/iconset.py)

    Image, _ = iconset._pillow()
    try:
        with Image.open(blp) as image:
            rgba = image.convert("RGBA")
    except (OSError, ValueError, NotImplementedError) as error:
        rgba = iconset._open_raw_bgra(blp)
        if rgba is None:
            raise RuntimeError(f"{Path(blp).name}: {error}") from error
    partial = Path(png).with_suffix(".tmp.png")
    rgba.save(partial, optimize=True)
    os.replace(partial, png)


def fetch(atlas_map, names, textures_dir, tool, decode):
    """Fetch the sheet of every named atlas into textures_dir as <fileID>.png; return the names the map lacks."""
    textures_dir = Path(textures_dir)
    textures_dir.mkdir(parents=True, exist_ok=True)
    unknown, done = [], set()
    for name in names:
        entry = atlas_map.get(name.lower())
        if entry is None:
            unknown.append(name)
            continue
        file_id = entry["file"]
        png = textures_dir / f"{file_id}.png"
        if file_id in done or png.exists():
            done.add(file_id)
            continue
        blp = textures_dir / f"{file_id}.blp"
        tool(file_id, blp)
        if not blp.exists():
            raise RuntimeError(f"TACTTool wrote no file for {file_id}")
        decode(blp, png)
        blp.unlink()
        done.add(file_id)
    return unknown


def export_tables(out_dir, tools=DEFAULT_TOOLS, wow_dir=DEFAULT_WOW_DIR):
    """Export the three atlas tables with casc_export.py for the build the game folder holds."""
    sys.path.insert(0, str(ICONS))
    import casc_export  # noqa: E402  (Tools/icons/casc_export.py)

    build = casc_export.read_build_info(wow_dir, PRODUCT).get("Version")
    casc_export.export_tables(
        build, wow_dir, out_dir, PRODUCT,
        Path(tools) / "casc" / "TACTTool" / "TACTTool",
        Path(tools) / "dotnet" / "dotnet",
        Path(tools) / "casc" / "DBC2CSV" / "DBC2CSV.dll",
        tables=TABLES,
    )
    (Path(out_dir) / "BUILD").write_text(build + "\n", encoding="utf-8")


def main(argv=None, export=None, tool=None, decode=None):
    parser = argparse.ArgumentParser(description="Build or extend the renderer's atlas cache from the game client, read-only.")
    parser.add_argument("command", choices=("build", "fetch"), help="build: export the tables and write the map, then fetch; fetch: fetch sheets into an existing cache")
    parser.add_argument("names", nargs="*", help="atlas names whose sheets to fetch")
    parser.add_argument("--scan", action="store_true", help="also fetch every atlas the scene JSON files in Tools/render/out mention")
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE, help="the cache folder (default ~/.local/share/wow-dev/atlas)")
    parser.add_argument("--tools", type=Path, default=DEFAULT_TOOLS, help="folder install-casc-tools.sh filled")
    parser.add_argument("--wow-dir", type=Path, default=DEFAULT_WOW_DIR, help="game folder that holds .build.info")
    args = parser.parse_args(argv)

    cache = args.cache
    tsv = cache / "atlas.tsv"
    export = export or (lambda out_dir: export_tables(out_dir, args.tools, args.wow_dir))
    tool = tool or (lambda file_id, blp: tacttool(file_id, blp, cache, args.tools, args.wow_dir))
    decode = decode or decode_blp
    try:
        if args.command == "build":
            export(cache / "db2")
            atlas_map = build_map(cache / "db2")
            write_tsv(atlas_map, tsv)
            print(f"atlas: wrote {len(atlas_map)} atlases to {tsv}")
        elif not tsv.exists():
            print(f"atlas: {tsv} is missing; run python3 Tools/render/atlas.py build first", file=sys.stderr)
            return 1
        else:
            atlas_map = read_tsv(tsv)
        names = list(dict.fromkeys(args.names))
        if args.scan:
            names.extend(sorted(scan_names(glob.glob(SCENE_JSON)) - {name.lower() for name in names}))
        unknown = fetch(atlas_map, names, cache / "textures", tool, decode)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"atlas: {error}", file=sys.stderr)
        return 1
    fetched = len(names) - len(unknown)
    print(f"atlas: {fetched} atlas(es) have their sheet in {cache / 'textures'}")
    if unknown:
        print("atlas: not in the client's atlas tables: " + ", ".join(unknown), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
