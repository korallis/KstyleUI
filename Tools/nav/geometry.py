"""Client geometry readers. Coordinates leaving this module are WoW xyz, z up."""

import math
import struct

TILE = 1600 / 3
UNIT = TILE / 128
MID = TILE * 32


def chunks(data, start=0, end=None):
    end = len(data) if end is None else end
    while start < end:
        if start + 8 > end:
            raise ValueError("truncated chunk header")
        size = struct.unpack_from("<I", data, start + 4)[0]
        stop = start + 8 + size
        if stop > end:
            raise ValueError("chunk extends beyond its container")
        yield data[start:start + 4][::-1].decode("ascii"), data[start + 8:stop]
        start = stop


def liquid_cells(data):
    """MH2O's offsets and existence mask are relative to the whole MH2O body."""
    result = {}
    if not data:
        return result
    boundaries = {len(data)}
    for i in range(256):
        off, layers, attributes = struct.unpack_from("<III", data, i * 12)
        boundaries.update(v for v in (off, attributes) if v)
        for j in range(layers):
            boundaries.update(v for v in struct.unpack_from("<II", data, off + j * 24 + 16) if v)
    for index in range(256):
        cells = {}
        offset, count, _ = struct.unpack_from("<III", data, index * 12)
        for layer in range(count):
            kind, fmt, low, high, x, y, w, h, mask, vertices = struct.unpack_from("<HHff4BII", data, offset + layer * 24)
            if vertices and fmt > 3:
                size = min(v for v in boundaries if v > vertices) - vertices
                stride = size / ((w + 1) * (h + 1))
                if stride not in (1, 5, 8, 9):
                    raise ValueError(f"unsupported MH2O vertex stride {stride} for liquid object {fmt}")
                fmt = {1: 2, 5: 0, 8: 1, 9: 3}[stride]
            bits = int.from_bytes(data[mask:mask + (w * h + 7) // 8], "little") if mask else (1 << (w * h)) - 1
            for row in range(h):
                for col in range(w):
                    if bits & (1 << (row * w + col)):
                        heights = [low] * 4
                        if vertices and fmt != 2:
                            heights = [struct.unpack_from("<f", data, vertices + 4 * k)[0] for k in (
                                row * (w + 1) + col, row * (w + 1) + col + 1,
                                (row + 1) * (w + 1) + col + 1, (row + 1) * (w + 1) + col)]
                        cells[y + row, x + col] = (kind, heights)
        if cells:
            result[index] = cells
    return result


def terrain(data):
    """Yield (area, vertices, triangles) per MCNK, retaining shallow water ground."""
    top = list(chunks(data))
    if dict(top).get("MVER") != struct.pack("<I", 18):
        raise ValueError("expected ADT version 18")
    liquid = liquid_cells(dict(top).get("MH2O"))
    for name, body in top:
        if name != "MCNK":
            continue
        flags, ix, iy = struct.unpack_from("<III", body)
        area = struct.unpack_from("<I", body, 0x34)[0]
        holes = struct.unpack_from("<H", body, 0x3c)[0]
        high_holes = int.from_bytes(body[0x14:0x1c], "little")
        x, y, z = struct.unpack_from("<3f", body, 0x68)
        heights = struct.unpack("<145f", dict(chunks(body, 128))["MCVT"])
        # MCVT alternates nine outer and eight inner vertices on each row.
        verts = [(x - r * UNIT, y - c * UNIT, z + heights[r * 17 + c]) for r in range(9) for c in range(9)]
        verts += [(x - (r + .5) * UNIT, y - (c + .5) * UNIT, z + heights[r * 17 + 9 + c]) for r in range(8) for c in range(8)]
        water = liquid.get(iy * 16 + ix, {})
        tris = []
        for r in range(8):
            for c in range(8):
                hole = high_holes & (1 << (r * 8 + c)) if flags & 0x10000 else holes & (1 << ((r // 2) * 4 + c // 2))
                if hole:
                    continue
                corners = [r * 9 + c, r * 9 + c + 1, (r + 1) * 9 + c + 1, (r + 1) * 9 + c]
                centre = 81 + r * 8 + c
                wet = water.get((r, c))
                if wet and max([h - verts[k][2] for h, k in zip(wet[1], corners)] + [sum(wet[1]) / 4 - verts[centre][2]]) > 1.5:
                    continue
                tris.extend((corners[a], corners[(a + 1) % 4], centre) for a in range(4))
        yield area, verts, tris


def placements(data):
    blocks = dict(chunks(data))
    for kind, stride, flag_offset, direct_flag, names, offsets in (
        ("MODF", 64, 56, 8, "MWMO", "MWID"), ("MDDF", 36, 34, 64, "MMDX", "MMID")
    ):
        body = blocks.get(kind, b"")
        if len(body) % stride:
            raise ValueError(f"truncated {kind} placement")
        for off in range(0, len(body), stride):
            entry, uid, *pose = struct.unpack_from("<II6f", body, off)
            flags = struct.unpack_from("<H", body, off + flag_offset)[0]
            if flags & direct_flag:
                source = str(entry)
            else:
                start = struct.unpack_from("<I", blocks[offsets], entry * 4)[0]
                source = blocks[names][start:].split(b"\0", 1)[0].decode("ascii").replace("\\", "/").lower()
            scale = struct.unpack_from("<H", body, off + (62 if kind == "MODF" else 32))[0] / 1024
            yield kind, uid, source, pose, scale or 1


def transform(verts, pose, scale):
    px, py, pz, rx, ry, rz = pose
    angles = [(math.cos(math.radians(a)), math.sin(math.radians(a))) for a in (ry - 90, -rx, rz)]
    result = []
    for vx, vy, vz in verts:
        x, y, z = vx * scale, vz * scale, -vy * scale
        c, s = angles[0]
        x, z = c * x + s * z, -s * x + c * z
        c, s = angles[1]
        x, y = c * x - s * y, s * x + c * y
        c, s = angles[2]
        y, z = c * y - s * z, s * y + c * z
        result.append((MID - pz - z, MID - px - x, py + y))
    return result


def wmo_group(data):
    body = dict(chunks(data))["MOGP"]
    blocks = dict(chunks(body, 68))
    verts = list(struct.iter_unpack("<3f", blocks["MOVT"]))
    indices = list(struct.iter_unpack("<3H", blocks["MOVI"]))
    materials = blocks.get("MOPY", blocks.get("MPY2"))
    stride = 2 if "MOPY" in blocks else 4
    if materials is None or len(materials) != len(indices) * stride:
        raise ValueError("WMO collision flags do not match triangles")
    tris = [tri for i, tri in enumerate(indices) if materials[i * stride] & 4 or (materials[i * stride] & 0x20 and not materials[i * stride] & 2)]
    return verts, tris


def m2_collision(data):
    if data[:4] == b"MD21":
        size = struct.unpack_from("<I", data, 4)[0]
        data = data[8:8 + size]
    if data[:4] != b"MD20":
        raise ValueError("expected MD20/MD21 model")
    ni, oi, nv, ov = struct.unpack_from("<4I", data, 216)
    verts = list(struct.iter_unpack("<3f", data[ov:ov + nv * 12]))
    tris = list(struct.iter_unpack("<3H", data[oi:oi + ni * 2]))
    if len(verts) != nv or len(tris) * 3 != ni or any(max(t) >= nv for t in tris):
        raise ValueError("invalid M2 collision arrays")
    return verts, tris


def simplify(points, epsilon=5):
    """Douglas-Peucker in xyz; iterative to allow continent-sized inputs."""
    if epsilon < 0:
        raise ValueError("epsilon must be nonnegative")
    if len(points) < 3:
        return list(points)
    keep = {0, len(points) - 1}
    pending = [(0, len(points) - 1)]
    while pending:
        lo, hi = pending.pop()
        a, b = points[lo], points[hi]
        delta = [q - p for p, q in zip(a, b)]
        length = sum(v * v for v in delta)
        worst, index = epsilon * epsilon, None
        for i in range(lo + 1, hi):
            t = max(0, min(1, sum((p - q) * v for p, q, v in zip(points[i], a, delta)) / length)) if length else 0
            distance = sum((p - q - t * v) ** 2 for p, q, v in zip(points[i], a, delta))
            if distance > worst:
                worst, index = distance, i
        if index is not None:
            keep.add(index)
            pending.extend(((lo, index), (index, hi)))
    return [points[i] for i in sorted(keep)]


def lua_routes(routes):
    """Return deterministic ASCII Lua; names use decimal escapes when needed."""
    def quote(value):
        return '"' + ''.join(chr(c) if 32 <= c < 127 and c not in (34, 92) else f"\\{c:03d}" for c in value.encode("utf-8")) + '"'
    lines = ["return {"]
    for a, b, points in sorted(routes):
        if any(not math.isfinite(v) for p in points for v in p):
            raise ValueError("route contains a nonfinite coordinate")
        coords = ','.join('{' + ','.join(f"{v:.2f}" for v in p) + '}' for p in points)
        lines.append(f"  {{{quote(a)},{quote(b)},{{{coords}}},mode=\"walk\"}},")
    return '\n'.join(lines + ["}", ""])
