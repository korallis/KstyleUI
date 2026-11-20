"""Build cached Durotar/Barrens walking routes from the owner's wowf client."""

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "icons"))
import casc_export
from abilities import load_csv
from geometry import chunks, lua_routes, m2_collision, placements, simplify, terrain, transform, wmo_group

CACHE = Path.home() / ".cache/kstyleui-navmesh"
RECAST_REV = "9f4ce64458dfae86e1239c525ddc219c4e9e06f1"
ZONES = {"Durotar": (-1716.6666, 1808.3333, -7250, -1962.5), "Barrens": (-5143.75, 1612.5, -7510.4165, 2622.9165)}
# The spike's sixteen sampling positions, retained so its connectivity is comparable.
PLACES = {
    "RazorHill": (324.359, -4774.359, 18.754), "OrgrimmarGate": (1470.606, -4353.030, 39.068),
    "Senjin": (-836.325, -4909.829, 19.909), "ValleyOfTrials": (-449.083, -4302.192, 72.206),
    "EchoShore": (-683.333, -5516.667, 2.957), "ThunderRidge": (866.333, -4108.667, 10.998),
    "BarrensCrossing": (-316.667, -4016.667, 89.468), "Ragefire": (1783.333, -4250.001, -25.076),
    "Tiragarde": (-188.889, -5021.181, 24.346), "Razormane": (210.501, -4339.788, 43.986),
    "SkullRock": (1448.148, -4824.074, 51.804), "Drygulch": (990.230, -4756.322, 40.568),
    "Darkspear": (-991.813, -4872.807, 5.928), "ScuttleCoast": (9.205, -5346.269, -13.809),
    "Razorwind": (762.903, -4552.688, 27.592), "Southfury": (441.270, -3886.508, 24.483),
}


def build_info(install):
    with (install / ".build.info").open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle, delimiter="|")
        header = [v.split("!", 1)[0] for v in next(reader)]
        rows = [dict(zip(header, row)) for row in reader]
    matches = [row for row in rows if row.get("Product") == "wowf" and row.get("Active") == "1"]
    if len(matches) != 1:
        raise ValueError(".build.info must contain exactly one active wowf install")
    return matches[0]


def outside(path, forbidden):
    path = Path(path).resolve()
    if path == forbidden or forbidden in path.parents:
        raise ValueError(f"refusing to write inside {forbidden}: {path}")
    return path


def run(command, cwd, log):
    with log.open("ab") as handle:
        result = subprocess.run([str(v) for v in command], cwd=cwd, stdout=handle, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f"{command[0]} exited {result.returncode}; see {log}")


class Client:
    def __init__(self, install, cache, tact, info):
        self.install, self.cache, self.tact, self.info = install, cache, tact, info
        self.extract = outside(cache / "extract", install)
        self.extract.mkdir(exist_ok=True)

    def path(self, source):
        # Never trust client filenames as filesystem paths.
        relative = str(source).replace("\\", "/").lower()
        if relative.startswith("/") or ":" in relative or ".." in relative.split("/"):
            raise ValueError(f"unsafe client path {source}")
        path = (self.extract / relative).resolve()
        if self.extract.resolve() not in path.parents:
            raise ValueError(f"extraction escaped cache: {source}")
        return path

    def fetch(self, sources):
        sources = sorted(set(str(v) for v in sources))
        missing = [v for v in sources if not self.path(v).is_file()]
        if missing:
            listing = self.cache / "extract-list.txt"
            listing.write_text(''.join(f"{v};{self.path(v)}\n" for v in missing), encoding="utf-8", newline="\n")
            print(f"Extracting {len(missing)} files", flush=True)
            run([self.tact, "-p", "wowf", "-r", self.info["Branch"], "-b", self.info["Build Key"],
                 "-c", self.info["CDN Key"], "-d", self.install, "-m", "list", "-i", listing, "-o", self.extract],
                self.cache, self.cache / "extract.log")
        for source in sources:
            path = self.path(source)
            if not path.is_file():
                raise ValueError(f"missing, empty or encrypted client file: {source}; see extract.log")
            with path.open("rb") as handle:
                if not any(handle.read(128)):
                    raise ValueError(f"missing, empty or encrypted client file: {source}; see extract.log")


def native(cache):
    source = Path(__file__).with_name("nav.cpp")
    recast = CACHE / "tools/recastnavigation"
    if not recast.exists():
        run(["git", "clone", "--filter=blob:none", "--no-checkout", "https://github.com/recastnavigation/recastnavigation.git", recast], cache, cache / "build.log")
        run(["git", "-C", recast, "checkout", "--detach", RECAST_REV], cache, cache / "build.log")
    revision = subprocess.check_output(["git", "-C", str(recast), "rev-parse", "HEAD"]).decode().strip()
    if revision != RECAST_REV or subprocess.check_output(["git", "-C", str(recast), "status", "--porcelain"]):
        raise ValueError(f"Recast must be clean at {RECAST_REV}; see Tools/nav/README.md")
    zig = CACHE / "tools/zig/zig-x86_64-windows-0.17.1/zig.exe"
    if not zig.is_file():
        raise FileNotFoundError(f"install Zig as described in Tools/nav/README.md: {zig}")
    exe = cache / "nav.exe"
    digest = hashlib.sha256(source.read_bytes() + revision.encode()).hexdigest()
    stamp = cache / "native.sha256"
    if not exe.exists() or not stamp.exists() or stamp.read_text() != digest:
        sources = [p for part in ("Recast", "Detour") for p in sorted((recast / part / "Source").glob("*.cpp"))]
        run([zig, "c++", "-O2", "-std=c++17", "-DDT_POLYREF64", "-I", recast / "Recast/Include", "-I", recast / "Detour/Include",
             source, *sources, "-o", exe], cache, cache / "build.log")
        stamp.write_text(digest, encoding="ascii", newline="\n")
    return exe


def geometry(client):
    client.fetch(["world/maps/kalimdor/kalimdor.wdt"])
    maid = dict(chunks(client.path("world/maps/kalimdor/kalimdor.wdt").read_bytes()))["MAID"]
    # One continuous rectangle includes both banks and a tile of context around the places.
    tiles = []
    for y in range(28, 39):
        for x in range(34, 44):
            root, obj, *_ = struct.unpack_from("<8I", maid, (y * 64 + x) * 32)
            if root:
                tiles.append((str(root), str(obj)))
    client.fetch(v for tile in tiles for v in tile if v != "0")
    placed = {}
    for _, obj in tiles:
        if obj != "0":
            for entry in placements(client.path(obj).read_bytes()):
                placed[entry[:2]] = entry
    wanted = {p[2] for p in placed.values()}
    names = {}
    with (client.cache / "listfile.csv").open(encoding="utf-8") as handle:
        for line in handle:
            key, _, name = line.strip().partition(";")
            if key in wanted:
                names[key] = name.lower()
    foliage = ("bush", "grass", "tree", "flower", "fern", "shrub", "kelp", "coral", "vine", "cactus", "mushroom")
    placed = [p for p in placed.values() if p[0] == "MODF" or not any(w in names.get(p[2], p[2]) for w in foliage)]
    client.fetch(p[2] for p in placed)
    groups = {}
    for kind, _, source, *_ in placed:
        if kind == "MODF" and source not in groups:
            blocks = dict(chunks(client.path(source).read_bytes()))
            count = struct.unpack_from("<I", blocks["MOHD"], 4)[0]
            if "GFID" in blocks:
                groups[source] = [str(v[0]) for v in struct.iter_unpack("<I", blocks["GFID"])][:count]
            else:
                groups[source] = [source[:-4] + f"_{i:03d}.wmo" for i in range(count)]
    client.fetch(v for files in groups.values() for v in files if v != "0")
    verts, tris = [], []

    def append(v, t):
        base = len(verts)
        verts.extend(v)
        tris.extend(tuple(i + base for i in tri) for tri in t)

    for root, _ in tiles:
        for _, v, t in terrain(client.path(root).read_bytes()):
            append(v, t)
    stats = {"tiles": len(tiles), "terrain_triangles": len(tris), "wmo_instances": 0, "m2_instances": 0}
    models, landmarks = {}, {}
    for kind, _, source, pose, scale, _ in placed:
        if source not in models:
            if kind == "MODF":
                v, t = [], []
                root_blocks = dict(chunks(client.path(source).read_bytes()))
                for group in groups[source]:
                    if group == "0":
                        continue
                    group_data = client.path(group).read_bytes()
                    gv, gt = wmo_group(group_data)
                    header = dict(chunks(group_data))["MOGP"]
                    name_offset = struct.unpack_from("<I", header)[0]
                    group_name = root_blocks.get("MOGN", b"")[name_offset:].split(b"\0", 1)[0]
                    if group_name == b"DungeonEntrance" and b"Cleft of Shadow" in root_blocks.get("MOGN", b""):
                        lo, hi = struct.unpack_from("<3f", header, 12), struct.unpack_from("<3f", header, 24)
                        local = tuple((a + b) / 2 for a, b in zip(lo[:2], hi[:2])) + (lo[2],)
                        landmarks["Ragefire"] = transform([local], pose, scale)[0]
                    t.extend(tuple(i + len(v) for i in tri) for tri in gt)
                    v.extend(gv)
                models[source] = v, t
            else:
                models[source] = m2_collision(client.path(source).read_bytes())
        v, t = models[source]
        if t:
            # Swapping WoW y/z for Recast reverses handedness. ADT fans already
            # have clockwise winding; model collision uses the opposite winding.
            append(transform(v, pose, scale), [(c, b, a) for a, b, c in t])
            stats["wmo_instances" if kind == "MODF" else "m2_instances"] += 1
        if names.get(source, source).endswith("/orcbridge/orcbridge.wmo"):
            landmarks["SouthfuryCrossing"] = transform([(0, 0, 0)], pose, scale)[0]
    mesh = client.cache / "mesh.bin"
    with mesh.open("wb") as handle:
        handle.write(struct.pack("<I", len(verts)))
        for v in verts:
            handle.write(struct.pack("<3f", *v))
        handle.write(struct.pack("<I", len(tris)))
        for tri in tris:
            handle.write(struct.pack("<3I", *tri))
    stats.update(vertices=len(verts), triangles=len(tris))
    print(stats, flush=True)
    return mesh, stats, landmarks


def places(client, landmarks):
    tools = casc_export.DEFAULT_TOOLS
    casc_export.export_tables(client.info["Version"], client.install, client.cache, "wowf", client.tact,
                              tools / "dotnet/dotnet.exe", tools / "casc/DBC2CSV/DBC2CSV.dll", tables=("TaxiNodes", "AreaPOI"))
    rows = load_csv(client.cache / "TaxiNodes.csv")
    result = dict(PLACES)
    sources = {name: "spike ADT area centroid; nearest main-component surface within 200 yards" for name in result}
    radii = {name: 200 for name in result}
    zones = {name: "Durotar" for name in result}
    zones.update(SouthfuryCrossing="Barrens", WailingCaverns="Barrens")
    pois = load_csv(client.cache / "AreaPOI.csv")
    wanted = {"Razor Hill": "RazorHill", "Orgrimmar": "OrgrimmarGate", "Sen'jin Village": "Senjin", "The Den": "ValleyOfTrials", "Razorwind Canyon": "Razorwind", "Wailing Caverns": "WailingCaverns"}
    for row in pois:
        key = wanted.get(row["Name_lang"])
        if key and row["ContinentID"] == "1":
            result[key] = tuple(float(row[f"Pos_{i}"]) for i in range(3))
            sources[key], radii[key] = f"AreaPOI {row['ID']}: {row['Name_lang']}", 20
    for key, point in landmarks.items():
        result[key] = point
        sources[key], radii[key] = ("client WMO DungeonEntrance group bounds", 20) if key == "Ragefire" else ("client orcbridge MODF pivot; nearest reachable surface", 80)
    for row in rows:
        name = ' '.join(row["Name_lang"].split())
        for prefix, key in (("Crossroads,", "Crossroads"), ("Ratchet,", "Ratchet"), ("Camp Taurajo,", "CampTaurajo")):
            if name.startswith(prefix):
                result[key] = tuple(float(row[f"Pos_{i}"]) for i in range(3))
                zones[key] = "Barrens"
                sources[key], radii[key] = f"TaxiNodes {row['ID']}: {name}", 8
    if not {"Crossroads", "Ratchet", "CampTaurajo", "WailingCaverns", "SouthfuryCrossing"} <= result.keys():
        raise ValueError("client data did not supply all five Barrens places")
    path = client.cache / "places.txt"
    radii["EchoShore"] = 8
    sources["EchoShore"] = "spike Echo Isles centroid; local island surface within 8 yards"
    if "Ragefire" not in landmarks:
        raise ValueError("Orgrimmar WMO did not supply its DungeonEntrance group")
    path.write_text(''.join(f"{name} {' '.join(str(v) for v in p)} {radii[name]} {int(name not in ('EchoShore', 'Ragefire'))}\n" for name, p in result.items()), encoding="utf-8", newline="\n")
    metadata = {name: dict(original=PLACES.get(name, point), seed=point, source=sources[name], radius=radii[name]) for name, point in result.items()}
    return result, zones, path, metadata


def paths(path):
    lines = iter(path.read_text(encoding="ascii").splitlines())
    result, snapped = [], {}
    for line in lines:
        if line.startswith("POINT "):
            _, name, x, y, z, component = line.split()
            snapped[name] = dict(point=(float(x), float(y), float(z)), component=int(component))
            continue
        _, a, b, status, count = line.split()
        pts = [tuple(map(float, next(lines).split())) for _ in range(int(count))]
        if next(lines) != "END":
            raise ValueError("invalid native path output")
        result.append((a, b, status, pts))
    return result, snapped


def picture(client, routes, points, zones, excluded):
    from PIL import Image, ImageDraw, ImageFont
    sources = [f"interface/worldmap/{zone.lower()}_c60/{zone.lower()}_c60{i}.blp" for zone in ZONES for i in range(1, 13)]
    client.fetch(sources)
    canvas = Image.new("RGB", (1920, 1080), "#171819")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
    for column, (zone, (xmin, xmax, ymin, ymax)) in enumerate(ZONES.items()):
        art = Image.new("RGB", (1024, 768))
        for i in range(12):
            tile = Image.open(client.path(f"interface/worldmap/{zone.lower()}_c60/{zone.lower()}_c60{i + 1}.blp"))
            art.paste(tile.convert("RGB"), ((i % 4) * 256, (i // 4) * 256))
        left, top, width, height = 20 + column * 950, 170, 930, 620
        # UiMapArtStyleLayer 1 is 1002x668; the remaining tile pixels are padding.
        canvas.paste(art.crop((0, 0, 1002, 668)).resize((width, height)), (left, top))
        draw.text((left, 100), zone, font=font, fill="white")

        def project(p):
            return (left + (ymax - p[1]) / (ymax - ymin) * width, top + (xmax - p[0]) / (xmax - xmin) * height)

        # Draw within each map's own rectangle so cross-zone lines cannot spill into its neighbour.
        overlay = Image.new("RGBA", (width, height))
        ink = ImageDraw.Draw(overlay)
        for a, b, status, pts in routes:
            if status == "OK" and len(pts) > 1:
                poly = [(x - left, y - top) for x, y in map(project, simplify(pts))]
                ink.line(poly, fill=(50, 230, 255, 90), width=2)
        canvas.paste(overlay, (left, top), overlay)
        for name, p in points.items():
            if zones[name] != zone:
                continue
            x, y = project(p)
            if left <= x < left + width and top <= y < top + height:
                color = "#ffcb66" if name in excluded else "white"
                draw.ellipse((x - 3, y - 3, x + 3, y + 3), fill=color)
                draw.text((x + 5, y), name, font=font, fill=color, stroke_width=2, stroke_fill="black")
    connected = sum(r[2] == "OK" for r in routes)
    eligible = [r for r in routes if r[0] not in excluded and r[1] not in excluded]
    draw.text((20, 35), f"Forever client map art | walking {sum(r[2] == 'OK' for r in eligible)}/{len(eligible)} eligible pairs | {connected}/{len(routes)} all pairs", font=font, fill="white")
    draw.text((20, 850), "Cyan: complete walking paths. Gold: Echo Isles, needs swimming or a boat. Deep water blocks walking; no swim routes emitted.", font=font, fill="white")
    draw.text((20, 885), "1-yard cells | 1.4-yard climb | 50-degree slope | 5-yard simplification | corrected endpoints and distances in summary.json", font=font, fill="white")
    path = client.cache / "durotar-barrens-routes-1920.png"
    canvas.save(path)
    return path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", type=Path, default=Path(os.environ.get("KSTYLEUI_WOW", "C:/Program Files (x86)/World of Warcraft")))
    args = parser.parse_args(argv)
    install = args.install.resolve()
    info = build_info(install)
    cache = outside(CACHE, install)
    outside(cache, Path(__file__).resolve().parents[2])
    cache.mkdir(parents=True, exist_ok=True)
    # Shared cache lock serializes extraction, Zig and Recast across invocations.
    lock = cache / "build.lock"
    with lock.open("x", encoding="ascii") as handle:
        handle.write(str(os.getpid()))
    started = time.monotonic()
    try:
        work = outside(cache / info["Version"] / info["Build Key"], install)
        work.mkdir(parents=True, exist_ok=True)
        tact = Path.home() / ".local/share/wow-dev/casc/TACTTool/TACTTool.exe"
        client = Client(install, work, tact, info)
        exe = native(work)
        mesh, stats, landmarks = geometry(client)
        points, zones, point_path, metadata = places(client, landmarks)
        path = work / "paths.txt"
        run([exe, mesh, point_path, path], work, work / "recast.log")
        routes, snapped = paths(path)
        for name, item in metadata.items():
            item.update(snapped[name])
            item["point"] = item["point"] if item["component"] >= 0 else None
            item["distance_moved"] = math.dist(item["original"], item["point"]) if item["point"] else None
        points = {name: item["point"] for name, item in metadata.items() if item["point"]}
        excluded = {"EchoShore": "Echo Isles: island; needs swim or boat"}
        if snapped["Ragefire"]["component"] != snapped["Crossroads"]["component"]:
            excluded["Ragefire"] = "Orgrimmar DungeonEntrance in the Cleft of Shadow: WMO interior remains disconnected; no traversable walking path proven"
        eligible = [r for r in routes if r[0] not in excluded and r[1] not in excluded]
        out = outside(cache / "out", install)
        out.mkdir(exist_ok=True)
        counts = {}
        for zone in ZONES:
            selected = [(a, b, simplify(pts)) for a, b, status, pts in routes if status == "OK" and zone in (zones[a], zones[b])]
            text = lua_routes(selected)
            (out / f"{zone}.lua").write_text(text, encoding="ascii", newline="\n")
            counts[zone] = {"routes": len(selected), "points": sum(len(p) for _, _, p in selected), "bytes": len(text)}
        image = picture(client, routes, points, zones, excluded)
        summary = dict(build=info["Version"], build_key=info["Build Key"], seconds=round(time.monotonic() - started, 2), geometry=stats,
                       connected=sum(r[2] == "OK" for r in eligible), pairs=len(eligible), all_connected=sum(r[2] == "OK" for r in routes), all_pairs=len(routes), zones=counts, picture=str(image), endpoints=metadata, excluded=excluded,
                       swimming=dict(pairs=0, explanation="Deep water is blocked; no swim edges are emitted or counted as walking"),
                       failures=[dict(a=a, b=b, status=status, reason=excluded.get(a) or excluded.get(b) or "No complete Detour walking path; unresolved failure") for a, b, status, _ in routes if status != "OK"])
        (work / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(f"Walking {summary['connected']}/{summary['pairs']} eligible pairs; {summary['all_connected']}/{summary['all_pairs']} including exclusions; {work / 'summary.json'}")
        valid_endpoints = all(item["component"] >= 0 for name, item in metadata.items() if name not in excluded)
        return 0 if valid_endpoints and summary["pairs"] and summary["connected"] / summary["pairs"] >= .9 else 3
    finally:
        lock.unlink()


if __name__ == "__main__":
    sys.exit(main())
