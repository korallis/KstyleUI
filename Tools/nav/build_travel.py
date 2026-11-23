"""Write the map overlay and travel-stop data files from the owner's client; outputs stay in cache."""

import argparse
from collections import defaultdict
import math
import os
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_routes as base
from geometry import chunks, placements, transform

TABLES = ('WorldMapOverlay', 'WorldMapOverlayTile', 'UiMapXMapArt', 'UiMapArt', 'UiMapArtStyleLayer',
          'TaxiNodes', 'TaxiPath', 'TaxiPathNode', 'TransportAnimation', 'Map', 'SpellName')
# Each capital's straight gnome tunnel ends at the Deeprun Tram; Stormwind's lies 55 yards from Map 369's corpse point.
TRAM_TUNNELS = ('stormwindcity/21138.wmo', 'Straight06'), ('ironforge/20884.wmo', 'straight01')


def number(value):
    return f'{round(value * 2) / 2:g}'


def overlays(db):
    maps = {r['UiMapArtID']: r['UiMapID'] for r in db['UiMapXMapArt']}
    styles = {r['UiMapArtStyleID']: r for r in db['UiMapArtStyleLayer'] if r['LayerIndex'] == '0'}
    tile = {r['ID']: int(styles[r['UiMapArtStyleID']]['TileWidth']) for r in db['UiMapArt'] if r['UiMapArtStyleID'] in styles}
    tiles = defaultdict(list)
    for r in db['WorldMapOverlayTile']:
        if r['LayerIndex'] == '0':
            tiles[r['WorldMapOverlayID']].append((int(r['RowIndex']), int(r['ColIndex']), int(r['FileDataID'])))
    by_map, skipped = defaultdict(list), []
    for r in sorted(db['WorldMapOverlay'], key=lambda r: int(r['ID'])):
        art = r['UiMapArtID']
        if art not in maps:
            continue
        w, h = int(r['TextureWidth']), int(r['TextureHeight'])
        size = tile.get(art, 256)
        files = [f for *_, f in sorted(tiles[r['ID']])]
        if len(files) != math.ceil(w / size) * math.ceil(h / size):
            skipped.append(r['ID'])
            continue
        by_map[int(maps[art])].append([w, h, int(r['OffsetX']), int(r['OffsetY']), *files])
    body = ','.join(f'[{m}]={{' + ','.join('{' + ','.join(map(str, o)) + '}' for o in rows) + '}' for m, rows in sorted(by_map.items()))
    return (f'-- Overlays.lua: deferred map overlay tiles from the owner\'s Forever client, by UI map.\n'
            f'KstyleUI_RouteData = KstyleUI_RouteData or {{}}\n'
            f'KstyleUI_RouteData.overlays = function()\nreturn {{{body}}}\nend\n'), sum(map(len, by_map.values())), skipped


def zeppelins(db):
    """TaxiPath ids of transports that fly; boats stay at sea level between their delayed stops."""
    taxis = {r['ID']: r for r in db['TaxiNodes']}
    hops = defaultdict(list)
    for r in db['TaxiPathNode']:
        hops[r['PathID']].append(r)
    flying = []
    for path in db['TaxiPath']:
        node = taxis.get(path['FromTaxiNode'])
        if node and node['Name_lang'].startswith('Transport,') and max(float(r['Loc_2']) for r in hops[path['ID']]) > 30:
            flying.append(int(path['ID']))
    return sorted(flying)


def tram(client, db):
    frames = defaultdict(list)
    for r in db['TransportAnimation']:
        frames[r['TransportID']].append((int(r['TimeIndex']), tuple(float(r[f'Pos_{i}']) for i in range(3))))
    longest = max(frames.values(), key=lambda f: max(math.dist(p, f[0][1]) for _, p in f))
    longest.sort()
    moving = sum(b[0] - a[0] for a, b in zip(longest, longest[1:]) if a[1] != b[1])
    maid = dict(chunks(client.path('world/maps/azeroth/azeroth.wdt').read_bytes()))['MAID']
    objs = [str(obj) for i in range(4096) for root, obj in [struct.unpack_from('<2I', maid, i * 32)] if root and obj]
    client.fetch(objs)
    names = {}
    with (client.cache / 'listfile.csv').open(encoding='utf-8') as handle:
        for line in handle:
            key, _, name = line.strip().partition(';')
            if name.endswith(tuple(wmo for wmo, _ in TRAM_TUNNELS)):
                names[key] = name
    placed = {p[2]: p for obj in objs for p in placements(client.path(obj).read_bytes()) if p[0] == 'MODF' and p[2] in names}
    client.fetch(placed)
    ends = []
    for wmo, group in TRAM_TUNNELS:
        _, _, source, pose, scale, _ = next(p for key, p in placed.items() if names[key].endswith(wmo))
        blocks = dict(chunks(client.path(source).read_bytes()))
        count = struct.unpack_from('<I', blocks['MOHD'], 4)[0]
        files = [str(g) for g, in list(struct.iter_unpack('<I', blocks['GFID']))[:count] if g]
        client.fetch(files)
        for file in files:
            header = dict(chunks(client.path(file).read_bytes()))['MOGP']
            if blocks['MOGN'][struct.unpack_from('<I', header)[0]:].split(b'\0', 1)[0] == group.encode():
                lo, hi = struct.unpack_from('<3f', header, 12), struct.unpack_from('<3f', header, 24)
                ends.append(transform([tuple((a + b) / 2 for a, b in zip(lo, hi))], pose, scale)[0])
    if len(ends) != 2:
        raise ValueError('tram tunnels not found in the city WMOs')
    corpse = next(r for r in db['Map'] if r['Directory'] == 'DeeprunTram')
    check = math.dist(ends[0][:2], (float(corpse['Corpse_0']), float(corpse['Corpse_1'])))
    if check > 80:
        raise ValueError(f'the Stormwind tunnel is {check:.0f} yards from the Deeprun Tram corpse point')
    return ends, moving / 2000


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', type=Path, default=Path(os.environ.get('KSTYLEUI_WOW', 'C:/Program Files (x86)/World of Warcraft')))
    args = parser.parse_args(argv)
    install = args.install.resolve()
    info = base.build_info(install)
    cache = base.outside(base.CACHE, install)
    base.outside(cache, Path(__file__).resolve().parents[2])
    work = cache / info['Version'] / info['Build Key']
    work.mkdir(parents=True, exist_ok=True)
    lock = cache / 'build.lock'
    with lock.open('x', encoding='ascii') as handle:
        handle.write(str(os.getpid()))
    try:
        client = base.Client(install, work, base.casc_export.DEFAULT_TOOLS / 'casc/TACTTool/TACTTool.exe', info)
        missing = tuple(t for t in TABLES if not (work / f'{t}.csv').exists())
        if missing:
            tools = base.casc_export.DEFAULT_TOOLS
            base.casc_export.export_tables(info['Version'], install, work, 'wowf', client.tact,
                                          tools / 'dotnet/dotnet.exe', tools / 'casc/DBC2CSV/DBC2CSV.dll', tables=missing)
        db = {t: base.load_csv(work / f'{t}.csv') for t in TABLES}
        client.fetch(['world/maps/azeroth/azeroth.wdt'])
        text, count, skipped = overlays(db)
        ends, ride = tram(client, db)
        flying = zeppelins(db)
        points = ','.join(number(v) for p in ends for v in p[:2])
        travel = ('-- Travel.lua: zeppelin routes and the Deeprun Tram from the owner\'s Forever client.\n'
                  'KstyleUI_RouteData = KstyleUI_RouteData or {}\n'
                  f'KstyleUI_RouteData.travel = {{zeppelins={{{",".join(f"[{p}]=true" for p in flying)}}},'
                  f'tram={{map=0,pts={{{points}}},seconds={number(60 + ride)}}}}}\n')
        out = cache / 'out/travel'
        out.mkdir(parents=True, exist_ok=True)
        (out / 'Overlays.lua').write_text(text, encoding='ascii', newline='\n')
        (out / 'Travel.lua').write_text(travel, encoding='ascii', newline='\n')
        print(f'{info["Version"]}: {count} overlays ({len(text)} bytes), skipped {skipped}; zeppelin paths {flying}; '
              f'tram {[tuple(round(v) for v in p) for p in ends]}, ride {ride:.1f} s; written to {out}')
        return 0
    finally:
        lock.unlink()


if __name__ == '__main__':
    sys.exit(main())
