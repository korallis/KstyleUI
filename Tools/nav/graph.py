"""Sparse shared walking graph and deterministic Lua serialization (no client needed)."""

from collections import defaultdict
import heapq
import math

from geometry import simplify


def length(points):
    return sum(math.dist(a, b) for a, b in zip(points, points[1:]))


def prune(edges, tolerance=.1):
    """Longest first: remove only while a current, same-kind two-hop path is <=110%."""
    special = [e for e in edges if e['kind'] != 'walk']
    kept = {(min(e['a'], e['b']), max(e['a'], e['b'])): e for e in edges if e['kind'] == 'walk'}
    adjacent = defaultdict(dict)
    for (a, b), edge in kept.items():
        adjacent[a][b] = adjacent[b][a] = edge
    for key, edge in sorted(kept.items(), key=lambda kv: (-kv[1]['len'], kv[0])):
        a, b = key
        if any(adjacent[a][c]['len'] + adjacent[b][c]['len'] <= edge['len'] * (1 + tolerance)
               for c in adjacent[a].keys() & adjacent[b].keys()):
            del kept[key], adjacent[a][b], adjacent[b][a]
    return list(kept.values()) + special


def shared_graph(places, edges):
    """Share identical half-yard xyz vertices; collapse degree-two non-place vertices."""
    nodes = {n['id']: dict(n) for n in places}
    positions, by_point = {}, {}
    for node in places:
        point = tuple(round(v * 2) / 2 for v in node['point'])
        positions[node['id']] = point
        by_point.setdefault(point, node['id'])
    adjacent = defaultdict(dict)

    def connect(a, b, pts):
        if a == b:
            return
        edge = dict(a=a, b=b, kind='walk', len=length(pts), pts=pts)
        if b not in adjacent[a] or edge['len'] < adjacent[a][b]['len']:
            adjacent[a][b] = adjacent[b][a] = edge

    for edge in edges:
        route = []
        for i, p in enumerate(edge['pts']):
            point = tuple(round(v * 2) / 2 for v in p)
            key = edge['a'] if i == 0 else edge['b'] if i == len(edge['pts']) - 1 else by_point.get(point)
            if key is None:
                key = f'j{places[0]["map"]}_{len(positions)}'
                by_point[point] = key
                positions[key] = point
            if not route or route[-1] != key:
                route.append(key)
        for a, b in zip(route, route[1:]):
            connect(a, b, [positions[a], positions[b]])
    anchors = set(nodes) | {key for key, neighbours in adjacent.items() if len(neighbours) != 2}
    visited, result = set(), []
    for start in sorted(anchors):
        for following in sorted(adjacent[start]):
            if tuple(sorted((start, following))) in visited:
                continue
            previous, current = start, following
            pts = [positions[start]]
            while True:
                visited.add(tuple(sorted((previous, current))))
                pts.append(positions[current])
                if current in anchors:
                    break
                previous, current = current, next(v for v in adjacent[current] if v != previous)
            if current != start:
                result.append(dict(a=start, b=current, kind='walk', len=length(pts), pts=simplify(pts)))
    for key in anchors - nodes.keys():
        nodes[key] = dict(id=key, name='', kind='junction', point=positions[key], map=places[0]['map'])
    result = {(e['a'], e['b'], tuple(p[:2] for p in e['pts'])): e
              for e in sorted(result, key=lambda e: -e['len'])}
    return list(nodes.values()), list(result.values())


def distances(edges, start, kinds=None):
    adjacent = defaultdict(list)
    for e in edges:
        if kinds is None or e['kind'] in kinds:
            adjacent[e['a']].append((e['b'], e['len']))
            if not e.get('directed'):
                adjacent[e['b']].append((e['a'], e['len']))
    best, todo = {start: 0}, [(0, start)]
    while todo:
        distance, a = heapq.heappop(todo)
        if distance != best[a]:
            continue
        for b, cost in adjacent[a]:
            candidate = distance + cost
            if candidate < best.get(b, math.inf):
                best[b] = candidate
                heapq.heappush(todo, (candidate, b))
    return best


def lua_graph(nodes, edges):
    def quote(value):
        return '"' + ''.join(chr(c) if 32 <= c < 127 and c not in (34, 92) else f'\\{c:03d}'
                             for c in value.encode('utf-8')) + '"'

    def number(value):
        if not math.isfinite(value):
            raise ValueError('graph contains a nonfinite number')
        return f'{round(value * 2) / 2:g}'

    ids = {n['id'] for n in nodes}
    if len(ids) != len(nodes):
        raise ValueError('duplicate node id')
    references = {n['id']: quote(n['id']) if n['kind'] == 'dock' else str(i + 1)
                  for i, n in enumerate(sorted(nodes, key=lambda n: n['id']))}
    kinds = {kind: f'k{i}' for i, kind in enumerate(sorted({r['kind'] for r in [*nodes, *edges]}))}
    prelude = 'local ' + ','.join(kinds.values()) + '=' + ','.join(quote(k) for k in kinds) + '\n' if kinds else ''
    continent = max(sorted({n['map'] for n in nodes}), key=lambda m: sum(n['map'] == m for n in nodes), default=0)
    lines = [f'return {{map={continent},nodes={{']
    for n in sorted(nodes, key=lambda n: n['id']):
        x, y, *_ = n['point']
        map_field = f',map={n["map"]}' if n['map'] != continent else ''
        lines.append(f'{{id={references[n["id"]]},name={quote(n["name"])},x={number(x)},y={number(y)},kind={kinds[n["kind"]]}{map_field}}},')
    lines.append('},edges={')
    for e in sorted(edges, key=lambda e: (e['a'], e['b'], e['kind'], e['len'], e['pts'])):
        if e['a'] not in ids or e['b'] not in ids or len(e['pts']) < 2 or e['len'] < 0:
            raise ValueError('edge needs valid endpoints, length and polyline')
        dim = 3 if e['kind'] == 'lift' else 2
        pts = ','.join(number(v) for p in e['pts'] for v in p[:dim])
        fields = f'a={references[e["a"]]},b={references[e["b"]]},kind={kinds[e["kind"]]},len={number(e["len"])},pts={{{pts}}}'
        if e.get('directed'):
            fields += ',directed=true'
        if 'seconds' in e:
            fields += f',seconds={number(e["seconds"])},about=true'
        lines.append('{' + fields + '},')
    return prelude + ''.join(lines + ['}}', '\n'])
