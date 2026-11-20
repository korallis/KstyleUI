"""Synthetic client geometry only: no game installation or native build needed."""

import math
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "nav"))

import build_routes
from geometry import MID, UNIT, chunks, liquid_cells, lua_routes, m2_collision, place, simplify, terrain, transform, wmo_doodads, wmo_group


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
    def test_wmo_keeps_collision_hulls_and_drops_detail(self):
        group = bytes(68) + chunk("MOVT", struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0))
        group += chunk("MOVI", struct.pack("<12H", 0, 1, 2, 0, 2, 1, 1, 0, 2, 1, 2, 0))
        # Render+detail, collision-only hull (material 0xff), render, render without camera collision.
        group += chunk("MOPY", bytes([0x64, 0, 0x48, 0xff, 0x20, 0, 0x22, 0]))
        v, t = wmo_group(chunk("MOGP", group))
        self.assertEqual(len(v), 3)
        self.assertEqual(t, [(0, 2, 1), (1, 0, 2), (1, 2, 0)])

        modern = group.replace(chunk("MOPY", bytes([0x64, 0, 0x48, 0xff, 0x20, 0, 0x22, 0])), chunk("MPY2", struct.pack("<8H", 0x64, 300, 0x48, 0xffff, 0x20, 400, 0x22, 500)))
        self.assertEqual(wmo_group(chunk("MOGP", modern)), (v, t))

    def test_wmo_doodads_use_default_and_placed_sets(self):
        sets = b"".join(name.ljust(20, b"\0") + struct.pack("<3I", start, 1, 0) for name, start in ((b"Set_$DefaultGlobal", 0), (b"Night", 1), (b"Day", 2)))
        defs = b"".join(struct.pack("<I8fI", index, 10 * index, 0, 0, 0, 0, math.sin(math.pi / 4), math.cos(math.pi / 4), 2, 0) for index in range(3))
        blocks = {"MODS": sets, "MODD": defs, "MODI": struct.pack("<3I", 501, 502, 503)}
        found = list(wmo_doodads(blocks, 2))
        self.assertEqual([d[0] for d in found], ["501", "503"])
        source, position, rotation, scale = found[1]
        # A quarter turn about z, doubled and moved 20 yards along x.
        for actual, expected in zip(place([(1, 0, 0)], position, rotation, scale)[0], (20, 2, 0)):
            self.assertAlmostEqual(actual, expected, places=5)

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


class RouteTests(unittest.TestCase):
    def test_places_from_shared_csv_export(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            client = build_routes.Client(root / "game", root, root / "TACTTool.exe", {"Version": "test"})

            def export(*args, **kwargs):
                self.assertEqual(kwargs["tables"], ("TaxiNodes", "AreaPOI"))
                (root / "TaxiNodes.csv").write_text(
                    "ID,Name_lang,Pos[0],Pos[1],Pos[2]\n"
                    '25,"Crossroads, The Barrens",1.25,2.5,3.75\n'
                    '77,"Camp Taurajo, The Barrens",4,5,6\n'
                    '80," Ratchet,  The Barrens ",7,8,9\n', encoding="utf-8")
                (root / "AreaPOI.csv").write_text(
                    "ID,Name_lang,ContinentID,Pos[0],Pos[1],Pos[2]\n"
                    "31,Razor Hill,1,10.125,-20.25,30.5\n"
                    "1068,Wailing Caverns,1,40,50,60\n"
                    "99,Razor Hill,0,0,0,0\n", encoding="utf-8")

            with mock.patch.object(build_routes.casc_export, "export_tables", side_effect=export):
                points, zones, path, metadata = build_routes.places(client, {"Ragefire": (70, 80, 90), "SouthfuryCrossing": (100, 110, 120)})
            self.assertEqual(len(points), 21)
            self.assertEqual(points["RazorHill"], (10.125, -20.25, 30.5))
            self.assertEqual(points["Crossroads"], (1.25, 2.5, 3.75))
            self.assertEqual(points["Ratchet"], (7, 8, 9))
            self.assertEqual(points["WailingCaverns"], (40, 50, 60))
            self.assertEqual({name for name in points if zones[name] == "Barrens"}, {"Crossroads", "Ratchet", "CampTaurajo", "WailingCaverns", "SouthfuryCrossing"})
            self.assertEqual(metadata["Ragefire"]["radius"], 20)
            self.assertEqual(metadata["Crossroads"]["source"], "TaxiNodes 25: Crossroads, The Barrens")
            self.assertIn("Ragefire 70 80 90 20 0\n", path.read_text(encoding="utf-8"))

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
