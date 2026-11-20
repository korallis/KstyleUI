"""Synthetic client geometry only: no game installation or native build needed."""

import math
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "nav"))

import build_routes
import db2
from geometry import MID, UNIT, chunks, liquid_cells, lua_routes, m2_collision, simplify, terrain, transform, wmo_group


def chunk(name, body):
    return name.encode("ascii")[::-1] + struct.pack("<I", len(body)) + body


def adt(x=100, y=200, z=10, flags=0, holes=0, high_holes=0, liquid=b""):
    header = bytearray(128)
    struct.pack_into("<III", header, 0, flags, 0, 0)
    struct.pack_into("<Q", header, 0x14, high_holes)
    struct.pack_into("<I", header, 0x34, 14)
    struct.pack_into("<H", header, 0x3c, holes)
    struct.pack_into("<3f", header, 0x68, x, y, z)
    # A plane z = 10 + row + column, including half-grid centre samples.
    heights = []
    for r in range(9):
        heights.extend(r + c for c in range(9))
        if r < 8:
            heights.extend(r + c + 1 for c in range(8))
    return chunk("MVER", struct.pack("<I", 18)) + (chunk("MH2O", liquid) if liquid else b"") + chunk("MCNK", header + chunk("MCVT", struct.pack("<145f", *heights)))


class TerrainTests(unittest.TestCase):
    def test_alternating_height_rows_and_chunk_seam(self):
        _, a, triangles = next(terrain(adt()))
        self.assertEqual(len(a), 145)
        self.assertEqual(len(triangles), 256)
        self.assertEqual(a[9], (100 - UNIT, 200, 11))
        self.assertEqual(a[81], (100 - UNIT / 2, 200 - UNIT / 2, 11))
        _, b, _ = next(terrain(adt(x=100 - 8 * UNIT, z=18)))
        for c in range(9):
            self.assertAlmostEqual(a[72 + c][0], b[c][0], places=5)
            self.assertEqual(a[72 + c][1], b[c][1])
            self.assertEqual(a[72 + c][2], b[c][2])

    def test_low_resolution_hole_removes_four_quads(self):
        self.assertEqual(len(next(terrain(adt(holes=1)))[2]), 240)

    def test_high_resolution_hole_removes_one_quad(self):
        self.assertEqual(len(next(terrain(adt(flags=0x10000, high_holes=1)))[2]), 252)

    def test_truncated_chunks_fail(self):
        for data in (b"M", b"REVM" + struct.pack("<I", 100) + b"x"):
            with self.assertRaisesRegex(ValueError, "truncated|beyond"):
                list(chunks(data))

    def test_liquid_existence_mask_and_shallow_depth(self):
        water = bytearray(3072)
        struct.pack_into("<III", water, 0, 3072, 1, 0)
        water += struct.pack("<HHff4BII", 2, 2, 11.5, 11.5, 0, 0, 2, 1, 3096, 0) + b"\x01"
        self.assertEqual(set(liquid_cells(water)[0]), {(0, 0)})
        self.assertEqual(len(next(terrain(adt(liquid=water)))[2]), 256)
        deep_centre = bytearray(adt(liquid=water))
        struct.pack_into("<f", deep_centre, deep_centre.index(b"TVCM") + 8 + 9 * 4, -4)
        self.assertEqual(len(next(terrain(deep_centre))[2]), 252, "include the ADT centre vertex when rejecting deep water")
        struct.pack_into("<ff", water, 3076, 12, 12)
        self.assertEqual(len(next(terrain(adt(liquid=water)))[2]), 252)

    def test_modern_liquid_object_infers_vertex_layout(self):
        water = bytearray(3072)
        struct.pack_into("<III", water, 0, 3072, 1, 0)
        water += struct.pack("<HHff4BII", 1240, 6083, 11, 11, 0, 0, 1, 1, 0, 3096)
        water += struct.pack("<4f", 11, 12, 13, 14) + bytes(4)
        self.assertEqual(liquid_cells(water)[0][0, 0], (1240, [11, 12, 14, 13]))


    def test_liquid_boundaries_include_other_chunk_layers(self):
        water = bytearray(3072)
        struct.pack_into("<III", water, 0, 3072, 1, 0)
        struct.pack_into("<III", water, 12, 3116, 1, 0)
        water += struct.pack("<HHff4BII", 1240, 6083, 11, 11, 0, 0, 1, 1, 0, 3096)
        water += struct.pack("<4f", 11, 12, 13, 14) + bytes(4)
        water += struct.pack("<HHff4BII", 2, 2, 20, 20, 1, 2, 1, 1, 0, 0)
        self.assertEqual(liquid_cells(water), {
            0: {(0, 0): (1240, [11, 12, 14, 13])},
            1: {(2, 1): (2, [20, 20, 20, 20])},
        })


class CollisionTests(unittest.TestCase):
    def test_wmo_filters_render_only_detail(self):
        group = bytes(68) + chunk("MOVT", struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0))
        group += chunk("MOVI", struct.pack("<9H", *([0, 1, 2] * 3)))
        group += chunk("MOPY", bytes([4, 0, 0x22, 0, 0x20, 0]))
        v, t = wmo_group(chunk("MOGP", group))
        self.assertEqual(len(v), 3)
        self.assertEqual(len(t), 2)

        modern = group.replace(chunk("MOPY", bytes([4, 0, 0x22, 0, 0x20, 0])), chunk("MPY2", struct.pack("<6H", 4, 300, 0x22, 400, 0x20, 500)))
        self.assertEqual(wmo_group(chunk("MOGP", modern)), (v, t))

    def test_m2_collision_offsets_are_relative_to_md20(self):
        data = bytearray(250)
        data[:4] = b"MD20"
        struct.pack_into("<4I", data, 216, 3, 244, 3, 250)
        struct.pack_into("<3H", data, 244, 0, 1, 2)
        data += struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0)
        self.assertEqual(m2_collision(b"MD21" + struct.pack("<I", len(data)) + data)[1], [(0, 1, 2)])

    def test_upright_object_coordinate_conversion(self):
        point = transform([(1, 2, 3)], [MID + 10, 20, MID + 30, 0, 0, 0], 2)[0]
        for actual, expected in zip(point, (-32, -14, 26)):
            self.assertAlmostEqual(actual, expected)


class DatabaseTests(unittest.TestCase):
    def test_wdc5_client_position_and_encryption_refusal(self):
        header = b"WDC5" + struct.pack("<I", 5) + bytes(128)
        header += struct.pack("<9iHH7i", 1, 3, 20, 5, 0, 0, 7, 7, 0, 0, 1, 3, 0, 0, 72, 0, 0, 1)
        section = struct.pack("<Q8i", 0, 328, 1, 5, 348, 0, 0, 0, 0)
        meta = b"".join(struct.pack("<hh", 0, off) for off in (0, 4, 8))
        columns = b"".join(struct.pack("<HHIIIII", off, size, 0, 0, 0, 0, 0) for off, size in ((0, 32), (32, 32), (64, 96)))
        data = header + section + meta + columns + struct.pack("<II3f", 20, 7, 1.5, -2.5, 3.5) + b"Test\0"
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "synthetic.db2"
            path.write_bytes(data)
            rows = db2.load(path, ["Name", "ID", ("Pos", 3)], strings=("Name",), floats=("Pos",))
            self.assertEqual(rows, [dict(Name="Test", ID=7, Pos_0=1.5, Pos_1=-2.5, Pos_2=3.5)])
            encrypted = bytearray(data)
            struct.pack_into("<Q", encrypted, 204, 42)
            path.write_bytes(encrypted)
            with self.assertRaisesRegex(ValueError, "encrypted"):
                db2.load(path, ["Name", "ID", ("Pos", 3)])

    def test_pallet_array_consumes_one_index_for_whole_vector(self):
        header = b"WDC5" + struct.pack("<I", 5) + bytes(128)
        header += struct.pack("<9iHH7i", 1, 1, 1, 0, 0, 0, 7, 7, 0, 0, 0, 1, 0, 0, 24, 0, 24, 1)
        section = struct.pack("<Q8i", 0, 296, 1, 0, 297, 4, 0, 0, 0)
        meta = struct.pack("<hhHHIIIII", 0, 0, 0, 2, 24, 4, 0, 2, 3)
        data = header + section + meta + struct.pack("<6f", 1, 2, 3, 4, 5, 6) + b"\x01" + struct.pack("<I", 7)
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "synthetic.db2"
            path.write_bytes(data)
            self.assertEqual(db2.load(path, ["ID", ("Pos", 3)], floats=("Pos",)), [dict(ID=7, Pos_0=4, Pos_1=5, Pos_2=6)])


class RouteTests(unittest.TestCase):
    def test_simplifies_collinear_keeps_endpoints(self):
        points = [(i, 0, 0) for i in range(100)]
        self.assertEqual(simplify(points), [points[0], points[-1]])

    def test_retains_bend_and_vertical_detour(self):
        for points in ([(0, 0, 0), (5, 10, 0), (10, 0, 0)], [(0, 0, 0), (5, 0, 10), (10, 0, 0)]):
            self.assertEqual(simplify(points), points)

    def test_degenerate_and_empty(self):
        self.assertEqual(simplify([]), [])
        self.assertEqual(simplify([(0, 0), (8, 0), (0, 0)]), [(0, 0), (8, 0), (0, 0)])
        with self.assertRaises(ValueError):
            simplify([], -1)

    def test_lua_ascii_determinism_precision_and_escaping(self):
        routes = [('b"\\\n', 'café', [(1.123, -2, 3)])]
        text = lua_routes(routes)
        self.assertEqual(text, 'return {\n  {"b\\034\\092\\010","caf\\195\\169",{{1.12,-2.00,3.00}},mode="walk"},\n}\n')
        self.assertTrue(text.isascii())
        self.assertEqual(lua_routes(routes + [("a", "z", [])]), lua_routes([( "a", "z", [])] + routes))
        with self.assertRaises(ValueError):
            lua_routes([("a", "b", [(math.nan, 1, 2)])])

    def test_output_must_resolve_outside_game(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            with self.assertRaises(ValueError):
                build_routes.outside(root / "data", root)
            self.assertEqual(build_routes.outside(root.parent / "other", root), root.parent / "other")

    def test_extraction_names_cannot_escape_cache(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            client = build_routes.Client(root / "game", root, root / "unused.exe", {})
            for name in ("../game", "c:/game", "/game", "world/../../game"):
                with self.assertRaises(ValueError):
                    client.path(name)

    def test_active_wowf_build_required(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / ".build.info").write_text("Product!STRING:0|Active!DEC:1|Version!STRING:0\nwow|1|bad\nwowf|0|old\nwowf|1|1.60.1.70959\n", encoding="utf-8")
            self.assertEqual(build_routes.build_info(root)["Version"], "1.60.1.70959")


if __name__ == "__main__":
    unittest.main()
