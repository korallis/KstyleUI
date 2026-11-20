"""Build sparse continent graphs from the owner's client; all outputs stay in cache."""

import argparse
from collections import Counter, defaultdict
from functools import lru_cache
import json
import hashlib
import inspect
import math
import os
from pathlib import Path
import random
import re
import statistics
import struct
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_routes as base
from geometry import MID, TILE, chunks, m2_collision, place, placements, simplify, terrain, transform, water_surface, wmo_doodads, wmo_group
from graph import distances, length, lua_graph, prune, shared_graph

TABLES = ('Map', 'AreaTable', 'UiMap', 'UiMapAssignment', 'TaxiNodes', 'AreaPOI', 'TaxiPath', 'TaxiPathNode', 'LiquidType')
CAP = 3500
K = 6
# Sampled places walking cannot reach, each with its reason; summary.json lists them.
ISLAND, SEA = 'island; boat or swim only', 'open sea area'
RIDGE = 'zone border without a walkable crossing (ridge, wall or sea); none of its six lowest border points joins the walking mesh'
HYJAL = 'Mount Hyjal: no walkable approach in client collision; its Darkwhisper Gorge edge is a 12-yard drop near (4480, -4509); flight points serve it'
EXCLUDED = {continent: {key: reason for reason, keys in groups for key in keys.split()} for continent, groups in {
    0: [(ISLAND, 'a172 a232 a297 a896 a162 a163 p1031 p1588'),
        (SEA, 'a2338 a2339 a2400'),
        (RIDGE, 'z4_41 z139_47 z12_46 z3_46 z11_3 z33_41 z130_17066 z1519_40'),
        ('Programmer Isle: developer island outside the continent map', 't3'),
        ('Caer Darrow: island in Darrowmere Lake; instanced dungeon', 'p710'),
        ('sunken temple in the Pool of Tears: swim only; instanced dungeon', 'a74 p1013'),
        ('Blackrock Mountain: underground instance hub inside the mountain', 'a254'),
        ('Gilneas: behind the closed Greymane Wall gate in client collision', 'a16757 a16758 z16756_17065 z17065_17066'),
        ('AreaPOI pin 30 yards under the bay water; Booty Bay flight master t18 stands for the town', 'p40')],
    1: [(ISLAND, 'a368 a1120 a1121 a2079 a2406 p796 p1067 p1169 p1187 t41 b303_1'),
        (SEA, 'a1227 a2318 a2322'),
        (HYJAL, 't559 t3242 a2256 a16848 a16866 a16867 a16868 a17050 a17144 a17145 z361_616 z616_618'),
        ('Thunder Bluff mesa: lift only; joined by lift edges', 't22 p29 a1640 l179656_0 l179660_0'),
        ('lift car floor, a moving transport; joined by a lift edge', 'l179656_1 l179660_1 l283429_1 l399190_1'),
        ('Ragefire Chasm: instanced dungeon inside the Cleft of Shadow', 'd389'),
        ('AreaPOI pin under water with no surface within its 30-yard radius', 'p1092 p1228')],
}.items()}


def exclusion(continent, key, point):
    """Why a sampled place is outside the mainland walking target, or None."""
    if key in EXCLUDED[continent]:
        return EXCLUDED[continent][key]
    if continent == 1 and point[0] > 8400 and point[1] > -1000:
        return 'Teldrassil: island; boat from Auberdine, portal to Darnassus'
    return None


def tables(client):
    missing = tuple(t for t in TABLES if not (client.cache / f'{t}.csv').exists())
    if missing:
        tools = base.casc_export.DEFAULT_TOOLS
        base.casc_export.export_tables(client.info['Version'], client.install, client.cache, 'wowf', client.tact,
                                      tools / 'dotnet/dotnet.exe', tools / 'casc/DBC2CSV/DBC2CSV.dll', tables=missing)
    return {t: base.load_csv(client.cache / f'{t}.csv') for t in TABLES}


def mesh_tiles(client, continent, directory, areas):
    """Only one ADT soup and a 32-entry collision LRU are resident in Python."""
    source = f'world/maps/{directory.lower()}/{directory.lower()}.wdt'
    client.fetch([source])
    maid = dict(chunks(client.path(source).read_bytes()))['MAID']
    tiles = [struct.unpack_from('<8I', maid, i * 32)[:2] for i in range(4096)]
    tiles = [(str(a), str(b)) for a, b in tiles if a]
    client.fetch(v for tile in tiles for v in tile if v != '0')
    placed = {obj: list(placements(client.path(obj).read_bytes())) for _, obj in tiles if obj != '0'}
    wmos = {(p[2], p[5]) for entries in placed.values() for p in entries if p[0] == 'MODF'}
    client.fetch(source for source, _ in wmos)
    groups, doodads = {}, {}
    for source, doodad_set in wmos:
        blocks = dict(chunks(client.path(source).read_bytes()))
        count = struct.unpack_from('<I', blocks['MOHD'], 4)[0]
        groups[source] = ([str(v[0]) for v in struct.iter_unpack('<I', blocks['GFID'])][:count]
                          if 'GFID' in blocks else [source[:-4] + f'_{i:03d}.wmo' for i in range(count)])
        doodads[source, doodad_set] = list(wmo_doodads(blocks, doodad_set))
    wanted = {p[2] for entries in placed.values() for p in entries if p[0] == 'MDDF'}
    wanted.update(d[0] for values in doodads.values() for d in values)
    names = {}
    with (client.cache / 'listfile.csv').open(encoding='utf-8') as handle:
        for line in handle:
            key, _, name = line.strip().partition(';')
            if key in wanted:
                names[key] = name.lower()
    foliage = ('bush', 'grass', 'tree', 'flower', 'fern', 'shrub', 'kelp', 'coral', 'vine', 'cactus', 'mushroom')

    def solid(source):
        return not any(w in names.get(source, source) for w in foliage)

    def entries(obj):
        return [p for p in placed.get(obj, []) if p[0] == 'MODF' or solid(p[2])]

    client.fetch(v for v in wanted if solid(v))
    client.fetch(v for files in groups.values() for v in files if v != '0')

    @lru_cache(maxsize=32)
    def model(source, doodad_set):
        if source not in groups:
            return m2_collision(client.path(source).read_bytes())
        v, t = [], []

        def add(gv, gt):
            t.extend(tuple(i + len(v) for i in tri) for tri in gt)
            v.extend(gv)

        for group in groups[source]:
            if group != '0':
                add(*wmo_group(client.path(group).read_bytes()))
        collision = {}
        for m2, position, rotation, scale in doodads[source, doodad_set]:
            if solid(m2):
                if m2 not in collision:
                    collision[m2] = m2_collision(client.path(m2).read_bytes())
                add(place(collision[m2][0], position, rotation, scale), collision[m2][1])
        return v, t

    out = client.cache / 'graph' / directory
    out.mkdir(parents=True, exist_ok=True)
    samples, totals, crossings = defaultdict(list), {}, {}
    paths, stats = [], Counter(tiles=len(tiles))

    def zone(area):
        seen = set()
        while area in areas and areas[area]['ParentAreaID'] != '0' and area not in seen:
            seen.add(area)
            area = areas[area]['ParentAreaID']
        return area

    for index, (root, obj) in enumerate(tiles):
        verts, tris, cells = [], [], {}

        def append(v, t):
            offset = len(verts)
            verts.extend(v)
            tris.extend(tuple(i + offset for i in tri) for tri in t)

        for area, v, t in terrain(client.path(root).read_bytes()):
            append(v, t)
            if t:
                key = str(area)
                point = v[40]
                old = totals.get(key, (0, 0, 0, 0))
                totals[key] = tuple(a + b for a, b in zip(old, (*point, 1)))
                if len(samples[key]) < 64:
                    samples[key].append(point)
                else:
                    slot = random.Random(f'{root}-{point[:2]}').randrange(totals[key][3])
                    if slot < 64:
                        samples[key][slot] = point
                cell = tuple(round((MID - value) / (TILE / 16)) for value in point[:2])
                cells[cell] = (zone(key), point)
        for cell, (a, p) in cells.items():
            for offset in ((0, 1), (1, 0)):
                other = cells.get((cell[0] + offset[0], cell[1] + offset[1]))
                if other and a != other[0] and a in areas and other[0] in areas:
                    pair = tuple(sorted((a, other[0])))
                    crossing = tuple((v + w) / 2 for v, w in zip(p, other[1]))
                    crossings.setdefault(pair, []).append(((abs(p[2] - other[1][2]) > 4, max(p[2], other[1][2])), crossing))
        seen = set()
        for kind, uid, source, pose, scale, doodad_set in entries(obj):
            if (kind, uid) in seen:
                continue
            seen.add((kind, uid))
            v, t = model(source, doodad_set)
            if t:
                append(transform(v, pose, scale), [(c, b, a) for a, b, c in t])
                stats[kind] += 1
        path = out / f'{root}.bin'
        with path.open('wb') as handle:
            handle.write(struct.pack('<I', len(verts)))
            handle.write(b''.join(struct.pack('<3f', *v) for v in verts))
            handle.write(struct.pack('<I', len(tris)))
            handle.write(b''.join(struct.pack('<3I', *tri) for tri in tris))
        paths.append(path)
        stats['triangles'] += len(tris)
        if index % 100 == 0:
            print(f'{directory}: {index + 1}/{len(tiles)} ADTs', flush=True)
    seeds = {area: min(values, key=lambda p: math.dist(p, [v / totals[area][3] for v in totals[area][:3]]))
             for area, values in samples.items()}
    manifest = out / 'continent.tiles'
    manifest.write_text(''.join(f'{p}\n' for p in paths), encoding='utf-8', newline='\n')
    fingerprint = hashlib.sha256(Path(__file__).with_name('geometry.py').read_bytes() + inspect.getsource(mesh_tiles).encode('utf-8')).hexdigest()
    metadata = dict(seeds=seeds, crossings=[(a, b, passes(v)) for (a, b), v in sorted(crossings.items())], stats=dict(stats), fingerprint=fingerprint)
    (out / 'terrain.json').write_text(json.dumps(metadata), encoding='utf-8', newline='\n')
    return manifest, metadata


def passes(cells, count=6, spacing=250):
    """Lowest level border cells first, at most `count`, each `spacing` yards from the others."""
    chosen = []
    for _, point in sorted(cells):
        if len(chosen) < count and all(math.dist(point[:2], other[:2]) >= spacing for other in chosen):
            chosen.append(point)
    return chosen


def discover(db, continent, metadata):
    nodes = []
    dungeon_names = {r['MapName_lang'] for r in db.get('Map', []) if r['InstanceType'] in ('1', '2')}
    for table, prefix, kind in (('TaxiNodes', 't', 'flight'), ('AreaPOI', 'p', 'hub')):
        for row in db[table]:
            name = ' '.join(row['Name_lang'].split())
            if int(row['ContinentID']) != continent or not name or name.startswith(('Transport,', 'Generic,', 'Quest Path', 'zzOLD')):
                continue
            if table == 'AreaPOI' and (int(row['WorldStateID']) or name in ('Under Attack', 'Sandworm!')):
                continue
            point = tuple(float(row[f'Pos_{i}']) for i in range(3))
            if point == (0, 0, 0):
                continue
            if any(n['name'] == name and math.dist(n['point'], point) < 80 for n in nodes):
                continue
            category = 'dungeon' if name in dungeon_names else kind
            if table == 'AreaPOI' and category == 'hub' and row.get('Importance') == '3':
                category = 'settlement'
            nodes.append(dict(id=prefix + row['ID'], name=name, point=point, kind=category, map=continent, radius=30))
    for row in db['AreaTable']:
        point = metadata['seeds'].get(row['ID'])
        name = row['AreaName_lang']
        if int(row['ContinentID']) != continent or point is None or not name or row['ParentAreaID'] == '0':
            continue
        if any(n['name'].split(',')[0].removeprefix('The ') == name.removeprefix('The ') for n in nodes):
            continue
        kind = 'dungeon' if name in dungeon_names else 'inn' if re.search(r'\binn\b', name, re.I) else 'area'
        nodes.append(dict(id='a' + row['ID'], name=name, point=point, kind=kind, map=continent, radius=120))
    names = {r['ID']: r['AreaName_lang'] for r in db['AreaTable']}
    for a, b, points in metadata['crossings']:
        nodes.append(dict(id=f'z{a}_{b}', name=f'{names[a]} / {names[b]}', point=points[0], candidates=points, kind='crossing', map=continent, radius=80))
    return nodes


def special_edges(db):
    taxis = {r['ID']: r for r in db['TaxiNodes']}
    hops = defaultdict(list)
    for row in db['TaxiPathNode']:
        hops[row['PathID']].append(row)
    nodes, edges = {}, []
    for route in db['TaxiPath']:
        a, b = route['FromTaxiNode'], route['ToTaxiNode']
        if a not in taxis or b not in taxis:
            continue
        rows = sorted(hops[route['ID']], key=lambda r: int(r['NodeIndex']))
        if len(rows) < 2:
            continue
        transport = any(taxis[key]['Name_lang'].startswith('Transport,') for key in (a, b))
        if transport:
            # Delayed spline nodes are actual stops; Transport taxi positions can be zero or offshore.
            stops = [i for i, row in enumerate(rows) if int(row['Delay']) > 0]
            for i, j in zip(stops, stops[1:]):
                endpoints = []
                for index in (i, j):
                    row = rows[index]
                    point = tuple(float(row[f'Loc_{v}']) for v in range(3))
                    key = f'b{route["ID"]}_{index}'
                    node = dict(id=key, name=f'{taxis[a]["Name_lang"]} stop {index}', point=point,
                                kind='dock', map=int(row['ContinentID']), radius=120)
                    # Repeated stops and overlapping transport splines share one dock.
                    existing = next((n for n in nodes.values() if n['map'] == node['map'] and math.dist(n['point'], point) < 60), None)
                    if existing:
                        key = existing['id']
                    else:
                        nodes[key] = node
                    endpoints.append(key)
                if endpoints[0] == endpoints[1]:
                    continue
                pts = [tuple(float(row[f'Loc_{v}']) for v in range(3)) for row in rows[i:j + 1]]
                same_map = rows[i]['ContinentID'] == rows[j]['ContinentID']
                distance = length(pts) if same_map else sum(math.dist(x, y) for x, y, r, s in zip(pts, pts[1:], rows[i:j], rows[i + 1:j + 1]) if r['ContinentID'] == s['ContinentID'])
                edges.append(dict(a=endpoints[0], b=endpoints[1], kind='boat', len=distance,
                                  pts=simplify(pts) if same_map else [pts[0], pts[-1]], seconds=60 + distance / 20))
            continue
        if taxis[a]['ContinentID'] != taxis[b]['ContinentID'] or taxis[a]['ContinentID'] not in ('0', '1'):
            continue
        pts = [tuple(float(row[f'Loc_{v}']) for v in range(3)) for row in rows]
        distance = length(pts)
        edges.append(dict(a='t' + a, b='t' + b, kind='flight', len=distance, pts=simplify(pts), directed=True, seconds=distance / 32))
    return list(nodes.values()), edges


def landmarks(client, directory, metadata, areas):
    if directory != 'Kalimdor':
        return [], []
    wanted = {}
    with (client.cache / 'listfile.csv').open(encoding='utf-8') as handle:
        for line in handle:
            key, _, name = line.strip().partition(';')
            if name.endswith('.wmo') and ('/thunderbluff/' in name or '/orgrimmar/' in name or name.endswith('/thousandneedleselevator.wmo')):
                wanted[key] = name
    maid = dict(chunks(client.path('world/maps/kalimdor/kalimdor.wdt').read_bytes()))['MAID']
    placed = {}
    for i in range(4096):
        root, obj = struct.unpack_from('<2I', maid, i * 32)
        if root and obj:
            for p in placements(client.path(str(obj)).read_bytes()):
                if p[0] == 'MODF' and p[2] in wanted:
                    placed[p[1]] = p
    nodes, pairs = [], []
    for _, uid, source, pose, scale, _ in placed.values():
        blocks = dict(chunks(client.path(source).read_bytes()))
        names = blocks.get('MOGN', b'')
        landings = {}
        count = struct.unpack_from('<I', blocks['MOHD'], 4)[0]
        for group, in list(struct.iter_unpack('<I', blocks['GFID']))[:count]:
            if not group:
                continue
            data = client.path(str(group)).read_bytes()
            header = dict(chunks(data))['MOGP']
            offset = struct.unpack_from('<I', header)[0]
            name = names[offset:].split(b'\0', 1)[0]
            if name == b'DungeonEntrance' and b'Cleft of Shadow' in names:
                lo, hi = struct.unpack_from('<3f', header, 12), struct.unpack_from('<3f', header, 24)
                center = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2])
                nodes.append(dict(id='d389', name='Ragefire Chasm', point=transform([center], pose, scale)[0], kind='dungeon', map=1, radius=20))
            if name not in (b'elevator', b'bottom'):
                continue
            vertices, triangles = wmo_group(data)
            floors = defaultdict(list)
            for triangle in triangles:
                a, b, c = [vertices[i] for i in triangle]
                area = ((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])) / 2
                if area > 0 and max(a[2], b[2], c[2]) - min(a[2], b[2], c[2]) < .15:
                    floors[round((a[2] + b[2] + c[2]) / 3 * 2) / 2].append((area, tuple((x + y + z) / 3 for x, y, z in zip(a, b, c))))
            if floors:
                floor = max(floors.values(), key=lambda values: sum(a for a, _ in values))
                total = sum(a for a, _ in floor)
                center = tuple(sum(a * p[i] for a, p in floor) / total for i in range(3))
                landings[name] = transform([center], pose, scale)[0]
        if len(landings) == 2:
            if '/thunderbluff/' in wanted[source]:
                label = 'Thunder Bluff lift'
            else:
                point = transform([(0, 0, 0)], pose, scale)[0]
                label = min((math.dist(point, seed), areas[key]['AreaName_lang'])
                            for key, seed in metadata['seeds'].items()
                            if key in areas and areas[key]['AreaName_lang'] in ('The Great Lift', 'Freewind Post'))[1]
            pair = []
            for i, point in enumerate(landings.values()):
                key = f'l{uid}_{i}'
                nodes.append(dict(id=key, name=f'{label} landing {i + 1}', point=point, kind='lift', map=1, radius=25))
                pair.append(key)
            pairs.append(tuple(sorted(pair)))
    return nodes, pairs


def query(client, exe, manifest, nodes, pairs, label):
    root = manifest.parent
    points, requested, output = (root / f'{label}.{ext}' for ext in ('points', 'pairs', 'paths'))
    points.write_text(''.join(f'{n["id"]} {" ".join(map(str, n["point"]))} {n["radius"]} {0 if n["kind"] == "lift" else -1}\n' for n in nodes), encoding='ascii', newline='\n')
    requested.write_text(''.join(f'{a} {b}\n' for a, b in sorted(pairs)), encoding='ascii', newline='\n')
    signature = hashlib.sha256(exe.read_bytes() + manifest.read_bytes())
    for line in manifest.read_text(encoding='utf-8').splitlines():
        stat = Path(line).stat()
        signature.update(f'{stat.st_size},{stat.st_mtime_ns}'.encode('ascii'))
    stamp = Path(str(manifest) + '.sha256')
    digest = signature.hexdigest()
    if not stamp.exists() or stamp.read_text(encoding='ascii') != digest:
        Path(str(manifest) + '.nav').unlink(missing_ok=True)
    request_digest = hashlib.sha256(digest.encode('ascii') + points.read_bytes() + requested.read_bytes()).hexdigest()
    request_stamp = root / f'{label}.sha256'
    if output.exists() and request_stamp.exists() and request_stamp.read_text(encoding='ascii') == request_digest:
        return base.paths(output)
    base.run([exe, manifest, points, output, requested], client.cache, root / f'{label}.log')
    stamp.write_text(digest, encoding='ascii', newline='\n')
    request_stamp.write_text(request_digest, encoding='ascii', newline='\n')
    return base.paths(output)


def swims(client, exe, db, manifest, nodes, snapped):
    cap = 600
    pairs = {tuple(sorted((a['id'], b['id']))) for i, a in enumerate(nodes) for b in nodes[i + 1:]
              if 0 < math.dist(a['point'], b['point']) <= cap
              and snapped[a['id']]['component'] >= 0 and snapped[b['id']]['component'] >= 0
              and snapped[a['id']]['component'] != snapped[b['id']]['component']}
    if not pairs:
        return [], dict(candidates=0, connected=0, cap=cap)
    directory = manifest.parent.name.lower()
    maid = dict(chunks(client.path(f'world/maps/{directory}/{directory}.wdt').read_bytes()))['MAID']
    by_id = {n['id']: n for n in nodes}
    tile_ids = set()
    for a, b in pairs:
        p, q = by_id[a]['point'], by_id[b]['point']
        bounds = [(math.floor((MID - max(p[i], q[i]) - 250) / TILE),
                   math.floor((MID - min(p[i], q[i]) + 250) / TILE)) for i in (0, 1)]
        for y in range(max(0, bounds[0][0]), min(63, bounds[0][1]) + 1):
            for x in range(max(0, bounds[1][0]), min(63, bounds[1][1]) + 1):
                root, = struct.unpack_from('<I', maid, (y * 64 + x) * 32)
                if root:
                    tile_ids.add(str(root))
    allowed = {int(r['ID']) for r in db['LiquidType'] if r['SoundBank'] in ('0', '1')}
    root = manifest.parent / 'swim'
    root.mkdir(exist_ok=True)
    stamp = root / 'surfaces.sha256'
    digest = hashlib.sha256(Path(__file__).with_name('geometry.py').read_bytes() + repr(sorted(allowed)).encode('ascii')).hexdigest()
    reuse_water = stamp.exists() and stamp.read_text(encoding='ascii') == digest
    sources, water_cells = [], 0
    for key in sorted(tile_ids):
        sources.append(manifest.parent / f'{key}.bin')
        path = root / f'{key}.bin'
        if not reuse_water or not path.exists():
            v, t = water_surface(client.path(key).read_bytes(), allowed)
            with path.open('wb') as handle:
                handle.write(struct.pack('<I', len(v)))
                handle.write(b''.join(struct.pack('<3f', *p) for p in v))
                handle.write(struct.pack('<I', len(t)))
                handle.write(b''.join(struct.pack('<3I', *tri) for tri in t))
        if path.stat().st_size > 8:
            sources.append(path)
            water_cells += (path.stat().st_size - 8) // 72
    stamp.write_text(digest, encoding='ascii', newline='\n')
    if not water_cells:
        return [], dict(candidates=len(pairs), connected=0, cap=cap)
    swimming = root / 'water.tiles'
    swimming.write_text(''.join(f'{p}\n' for p in sources), encoding='utf-8', newline='\n')
    used = {key for pair in pairs for key in pair}
    routes, _ = query(client, exe, swimming, [dict(n, radius=2) for n in nodes if n['id'] in used], pairs, 'swim')
    edges = []
    for a, b, status, pts in routes:
        if status == 'OK' and 0 < length(pts) <= cap:
            pts[0], pts[-1] = by_id[a]['point'], by_id[b]['point']
            if length(pts) <= cap:
                edges.append(dict(a=a, b=b, kind='swim', len=length(pts), pts=simplify(pts), seconds=length(pts) / 4.7))
    # Keep one short crossing per pair of walking components, avoiding parallel swims.
    kept = {}
    for e in sorted(edges, key=lambda e: (e['len'], e['a'], e['b'])):
        key = tuple(sorted(snapped[n]['component'] for n in (e['a'], e['b'])))
        kept.setdefault(key, e)
    return list(kept.values()), dict(candidates=len(pairs), connected=len(kept), cap=cap, water_cells=water_cells)


def picture(client, directory, continent, db, nodes, edges):
    from PIL import Image, ImageDraw, ImageFont
    art_name = 'easternkingdoms_c60' if continent == 0 else 'kalimdor_c60'
    sources = [f'interface/worldmap/{art_name}/{art_name}{i}.blp' for i in range(1, 13)]
    client.fetch(sources)
    art = Image.new('RGB', (1024, 768))
    for i, source in enumerate(sources):
        with Image.open(client.path(source)) as tile:
            art.paste(tile.convert('RGB'), ((i % 4) * 256, (i // 4) * 256))
    image = art.crop((0, 0, 1002, 668)).resize((1800, 1200))
    draw = ImageDraw.Draw(image)
    assignment = next(r for r in db['UiMapAssignment'] if r['UiMapID'] == str(1415 if continent == 0 else 1414))
    lo = [float(assignment[f'Region_{i}']) for i in range(3)]
    hi = [float(assignment[f'Region_{i}']) for i in range(3, 6)]

    def project(p):
        return ((hi[1] - p[1]) / (hi[1] - lo[1]) * 1800, (hi[0] - p[0]) / (hi[0] - lo[0]) * 1200)

    by_id = {n['id']: n for n in nodes}
    colors = dict(walk='#2af3ff', flight='#ffa348', boat='#d891ff', swim='#2277ff', lift='#ff4040')
    for e in sorted(edges, key=lambda e: e['kind'] == 'walk'):
        if by_id[e['a']]['map'] == by_id[e['b']]['map'] == continent:
            draw.line([project(p) for p in e['pts']], fill=colors[e['kind']], width=2)
    for n in nodes:
        if n['map'] == continent and n['kind'] != 'junction':
            x, y = project(n['point'])
            draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill='white')
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 22)
    draw.rectangle((0, 0, 1800, 65), fill='#16191d')
    draw.text((20, 8), f'{directory} | {len(nodes)} nodes | {len(edges)} edges | client map art', font=font, fill='white')
    draw.text((20, 34), 'Cyan walk | Orange flight | Purple transport | Blue swim | Red lift', font=font, fill='white')
    path = client.cache / 'graph' / f'{directory}.png'
    image.save(path)
    return str(path)


def build(client, exe, db, continent, directory, transport_nodes, transport_edges):
    started = time.monotonic()
    areas = {r['ID']: r for r in db['AreaTable'] if int(r['ContinentID']) == continent}
    manifest = client.cache / 'graph' / directory / 'continent.tiles'
    metadata_path = manifest.parent / 'terrain.json'
    metadata = json.loads(metadata_path.read_text(encoding='utf-8')) if metadata_path.exists() else {}
    fingerprint = hashlib.sha256(Path(__file__).with_name('geometry.py').read_bytes() + inspect.getsource(mesh_tiles).encode('utf-8')).hexdigest()
    if not manifest.exists() or metadata.get('fingerprint') != fingerprint:
        manifest, metadata = mesh_tiles(client, continent, directory, areas)
    lift_nodes, lift_pairs = landmarks(client, directory, metadata, areas)
    nodes = discover(db, continent, metadata) + [n for n in transport_nodes if n['map'] == continent] + lift_nodes
    # A border's low level cells are pass candidates; keep the first one on the main walking component.
    trial = [dict(n, id=f'{n["id"]}#{i}', point=p) for n in nodes for i, p in enumerate(n.get('candidates', ()))]
    _, probe = query(client, exe, manifest, nodes + trial, set(), 'crossings')
    main = Counter(v['component'] for v in probe.values() if v['component'] >= 0).most_common(1)[0][0]
    for n in nodes:
        options = n.pop('candidates', None)
        if options:
            n['point'] = next((p for i, p in enumerate(options) if probe[f'{n["id"]}#{i}']['component'] == main), options[0])
    seeds = {n['id']: tuple(n['point']) for n in nodes}
    candidates = set(lift_pairs)
    for n in nodes:
        nearby = sorted((math.dist(n['point'][:2], m['point'][:2]), m['id']) for m in nodes if m['id'] != n['id'])
        for distance, other in nearby:
            if distance <= CAP:
                candidates.add(tuple(sorted((n['id'], other))))
    ids = sorted(n['id'] for n in nodes)
    rng, sample = random.Random(70959 + continent), set()
    while len(sample) < min(500, len(ids) * (len(ids) - 1) // 2):
        sample.add(tuple(sorted(rng.sample(ids, 2))))
    routes, snapped = query(client, exe, manifest, nodes, candidates | sample, 'nearby')
    unresolved = [n['id'] for n in nodes if snapped[n['id']]['component'] < 0]
    for n in nodes:
        if n['id'] not in unresolved:
            n['point'] = snapped[n['id']]['point']
    complete = {(a, b): pts for a, b, status, pts in routes if status == 'OK'}
    swimming, swim_stats = swims(client, exe, db, manifest, nodes, snapped)
    selected = set()
    for n in nodes:
        reachable = [(length(pts), (a, b)) for (a, b), pts in complete.items() if n['id'] in (a, b) and (a, b) in candidates]
        selected.update(pair for _, pair in sorted(reachable)[:K])
    # Nearest-neighbour clusters can miss the sole exit from a dense town.
    parents = {n['id']: n['id'] for n in nodes}

    def component(key):
        while parents[key] != key:
            parents[key] = parents[parents[key]]
            key = parents[key]
        return key

    for a, b in sorted(selected):
        parents[component(a)] = component(b)
    for _, a, b in sorted((length(pts), a, b) for (a, b), pts in complete.items() if (a, b) in candidates):
        if component(a) != component(b):
            selected.add((a, b))
            parents[component(a)] = component(b)
    walks = [dict(a=a, b=b, kind='walk', len=length(complete[a, b]), pts=complete[a, b]) for a, b in sorted(selected)]
    special = list(swimming)
    by_id = {n['id']: n for n in nodes}
    for a, b in lift_pairs:
        if (a, b) not in complete and a not in unresolved and b not in unresolved:
            pts = [by_id[key]['point'] for key in (a, b)]
            special.append(dict(a=a, b=b, kind='lift', len=length(pts), pts=pts, seconds=30 + length(pts) / 8))
    nodes, edges = shared_graph(nodes, prune(walks))
    edges.extend(special)
    for n in nodes:
        n.setdefault('map', continent)
    by_id = {n['id']: n for n in nodes}
    for edge in transport_edges:
        a, b = edge['a'], edge['b']
        if edge['kind'] == 'flight':
            if a in by_id and b in by_id:
                pts = [by_id[a]['point'], *edge['pts'], by_id[b]['point']]
                edges.append(dict(edge, pts=simplify(pts), len=length(pts), seconds=length(pts) / 32))
        elif a in by_id or b in by_id:
            for key in (a, b):
                if key not in by_id:
                    node = next(n for n in transport_nodes if n['id'] == key)
                    by_id[key] = node
                    nodes.append(node)
            pts = [by_id[a]['point'], *edge['pts'], by_id[b]['point']]
            distance = edge['len'] + math.dist(pts[0], pts[1]) + math.dist(pts[-2], pts[-1])
            edges.append(dict(edge, pts=simplify(pts) if by_id[a]['map'] == by_id[b]['map'] else [pts[0], pts[-1]],
                              len=distance, seconds=60 + distance / 20))
    cached_distances = {}
    connected, detours, direct_count, walk_connected = 0, [], 0, 0
    excluded = {key: reason for n in nodes if (key := n['id']) in seeds and (reason := exclusion(continent, key, seeds[key]))}
    mainland = Counter()
    for a, b in sorted(sample):
        if a not in cached_distances:
            cached_distances[a] = distances(nodes, edges, a)
        connected += b in cached_distances[a]
        inland = a not in excluded and b not in excluded
        mainland['pairs'] += inland
        direct = complete.get((a, b))
        if direct and length(direct):
            direct_count += 1
            mainland['navmesh_direct'] += inland
            road = distances(nodes, edges, a, {'walk'}).get(b)
            if road is not None:
                walk_connected += 1
                mainland['walk_connected'] += inland
                detours.append(road / length(direct) - 1)
    text = lua_graph(nodes, edges)
    out = base.CACHE / 'out/graph'
    out.mkdir(parents=True, exist_ok=True)
    output = out / f'{"EasternKingdoms" if continent == 0 else directory}.lua'
    output.write_text(text, encoding='ascii', newline='\n')
    report = dict(continent=directory, nodes=len(nodes), edges=dict(Counter(e['kind'] for e in edges)), bytes=len(text),
                  sample_pairs=len(sample), connected=connected, navmesh_direct_pairs=direct_count, walk_connected=walk_connected,
                  mainland=dict(mainland), excluded={key: dict(name=by_id[key]['name'], reason=reason) for key, reason in sorted(excluded.items())},
                  median_detour=statistics.median(detours) if detours else None,
                  unresolved=unresolved, geometry=metadata['stats'], output=str(output),
                  swimming=swim_stats,
                  picture=picture(client, directory, continent, db, nodes, edges))
    report['seconds'] = round(time.monotonic() - started, 2)
    graph_ids = {n['id']: n['id'] if n['kind'] == 'dock' else i + 1 for i, n in enumerate(sorted(nodes, key=lambda n: n['id']))}
    report['endpoints'] = {n['id']: dict(name=n['name'], seed=seeds[n['id']], point=n['point'], radius=n['radius'],
                                      distance_moved=math.dist(seeds[n['id']], n['point']) if n['id'] not in unresolved else None,
                                      component=snapped[n['id']]['component'])
                           for n in nodes if n['id'] in snapped}
    for key, endpoint in report['endpoints'].items():
        endpoint['graph_id'] = graph_ids[key]
    (manifest.parent / 'summary.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'endpoints'}, indent=2), flush=True)
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', type=Path, default=Path(os.environ.get('KSTYLEUI_WOW', 'C:/Program Files (x86)/World of Warcraft')))
    args = parser.parse_args(argv)
    install = args.install.resolve()
    info = base.build_info(install)
    cache = base.outside(base.CACHE, install)
    base.outside(cache, Path(__file__).resolve().parents[2])
    cache.mkdir(parents=True, exist_ok=True)
    lock = cache / 'build.lock'
    with lock.open('x', encoding='ascii') as handle:
        handle.write(str(os.getpid()))
    try:
        work = cache / info['Version'] / info['Build Key']
        work.mkdir(parents=True, exist_ok=True)
        client = base.Client(install, work, base.casc_export.DEFAULT_TOOLS / 'casc/TACTTool/TACTTool.exe', info)
        exe, db = base.native(work), tables(client)
        transport_nodes, transport_edges = special_edges(db)
        reports = [build(client, exe, db, int(row['ID']), row['Directory'], transport_nodes, transport_edges)
                   for row in sorted(db['Map'], key=lambda r: r['ID']) if row['ID'] in ('0', '1')]
        (work / 'graph/summary.json').write_text(json.dumps(reports, indent=2) + '\n', encoding='utf-8', newline='\n')
        return 0
    finally:
        lock.unlink()


if __name__ == '__main__':
    sys.exit(main())
