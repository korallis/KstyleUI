"""Sparse graph rules use synthetic geometry, never the game install."""

import math
from pathlib import Path
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'nav'))

import build_graph
from geometry import water_surface
from graph import distances, lua_graph, prune, shared_graph


def node(key, x, y=0, z=0):
    return dict(id=key, name=key, point=(x, y, z), kind='hub', map=1)


def edge(a, b, distance, kind='walk', pts=None):
    return dict(a=a, b=b, len=distance, kind=kind, pts=pts or [(0, 0, 0), (distance, 0, 0)])


class PruningTests(unittest.TestCase):
    def test_two_hop_within_ten_percent_prunes_long_edge(self):
        edges = [edge('a', 'b', 10), edge('a', 'c', 5), edge('c', 'b', 6)]
        kept = prune(edges)
        self.assertEqual(len(kept), 2)
        self.assertEqual(distances(kept, 'a')['b'], 11)

    def test_too_long_alternative_keeps_edge(self):
        self.assertEqual(len(prune([edge('a', 'b', 10), edge('a', 'c', 6), edge('c', 'b', 6)])), 3)

    def test_bridge_and_disconnected_components_survive(self):
        edges = [edge('a', 'b', 1), edge('b', 'c', 1), edge('x', 'y', 1)]
        self.assertEqual(prune(edges), edges)

    def test_equal_length_triangle_is_not_deleted_simultaneously(self):
        kept = prune([edge('a', 'b', 0), edge('a', 'c', 0), edge('b', 'c', 0)])
        self.assertEqual(len(kept), 2)
        self.assertEqual(set(distances(kept, 'a')), {'a', 'b', 'c'})

    def test_flight_is_never_a_walking_prune_alternative(self):
        edges = [edge('a', 'b', 10), edge('a', 'c', 1, 'flight'), edge('c', 'b', 1)]
        self.assertEqual(len(prune(edges)), 3)

    def test_directed_flight_dijkstra(self):
        hop = dict(edge('a', 'b', 1, 'flight'), directed=True)
        self.assertIn('b', distances([hop], 'a'))
        self.assertNotIn('a', distances([hop], 'b'))

    def test_parallel_special_edge_is_preserved(self):
        special = edge('a', 'b', 2, 'flight')
        result = prune([edge('a', 'b', 10), edge('a', 'c', 5), edge('c', 'b', 5), special])
        self.assertIn(special, result)
        self.assertEqual(sum(e['kind'] == 'walk' for e in result), 2)


class SharingTests(unittest.TestCase):
    def test_identical_simplified_walks_keep_only_the_shortest(self):
        nodes = [node('a', 0), node('b', 20)]
        roads = [edge('a', 'b', 21, pts=[(0, 0, 0), (10, 2, 0), (20, 0, 0)]),
                 edge('a', 'b', 21, pts=[(0, 0, 0), (10, -1, 0), (20, 0, 0)])]
        for routes in (roads, roads[::-1]):
            with self.subTest(routes=routes):
                _, edges = shared_graph(nodes, routes)
                self.assertEqual(len(edges), 1, 'deduplicate simplified walking polylines, keeping the shortest')
                self.assertEqual(edges[0]['pts'], [(0, 0, 0), (20, 0, 0)])
                self.assertAlmostEqual(edges[0]['len'], 2 * math.sqrt(101))

    def test_shared_trunk_is_one_edge_and_has_a_junction(self):
        nodes = [node('a', 0), node('b', 20, 10), node('c', 20, -10)]
        roads = [edge('a', 'b', 25, pts=[(0, 0, 0), (10, 0, 0), (20, 10, 0)]),
                 edge('a', 'c', 25, pts=[(0, 0, 0), (10, 0, 0), (20, -10, 0)])]
        result, edges = shared_graph(nodes, roads)
        self.assertEqual(len(result), 4)
        self.assertTrue(all(n['map'] == 1 for n in result))
        self.assertEqual(len(edges), 3)
        self.assertEqual(sum(e['len'] == 10 for e in edges), 1)

    def test_overpass_does_not_join(self):
        nodes = [node('a', 0), node('b', 20), node('c', 10, -10, 20), node('d', 10, 10, 20)]
        roads = [edge('a', 'b', 20, pts=[(0, 0, 0), (10, 0, 0), (20, 0, 0)]),
                 edge('c', 'd', 20, pts=[(10, -10, 20), (10, 0, 20), (10, 10, 20)])]
        _, edges = shared_graph(nodes, roads)
        self.assertNotIn('c', distances(edges, 'a'))

    def test_degree_two_bends_simplify_and_keep_length(self):
        nodes = [node('a', 0), node('b', 20)]
        _, edges = shared_graph(nodes, [edge('a', 'b', 20, pts=[(0, 0, 0), (10, 0, 0), (20, 0, 0)])])
        self.assertEqual(len(edges), 1)
        self.assertEqual(edges[0]['pts'], [(0, 0, 0), (20, 0, 0)])
        self.assertEqual(edges[0]['len'], 20)


class LuaTests(unittest.TestCase):
    def test_deterministic_ascii_half_yard_and_flat_xy(self):
        nodes = [dict(node('b', -0.1, 1.26, 10), name='café"\\\n'), node('a', 0)]
        edges = [edge('a', 'b', 1.26, pts=[(0, 0, 0), (-0.1, 1.26, 10)])]
        text = lua_graph(nodes, edges)
        self.assertEqual(text, lua_graph(nodes[::-1], edges))
        self.assertTrue(text.isascii())
        self.assertIn('caf\\195\\169\\034\\092\\010', text)
        self.assertIn('x=0,y=1.5', text)
        self.assertIn('len=1.5,pts={0,0,0,1.5}', text)
        self.assertNotIn('1.26', text)

    def test_lift_keeps_z_and_estimates_are_labelled(self):
        e = edge('a', 'b', 30, 'lift', [(0, 0, 1), (0, 0, 31)])
        e['seconds'] = 15
        text = lua_graph([node('a', 0), node('b', 0, z=30)], [e])
        self.assertIn('pts={0,0,1,0,0,31}', text)
        self.assertIn('seconds=15,about=true', text)

    def test_remote_dock_has_continent_assignment(self):
        nodes = [node('a', 0), node('c', 20), dict(node('b', 100), map=0)]
        edges = [edge('a', 'b', 100, 'boat')]
        text = lua_graph(nodes, edges)
        self.assertEqual(text, lua_graph(nodes[::-1], edges))
        self.assertIn('return {map=1,nodes={', text)
        self.assertIn('map=0}', text)

    def test_invalid_numbers_ids_and_polylines_rejected(self):
        nodes = [node('a', 0), node('b', 1)]
        cases = [([node('a', math.nan)], []), (nodes + [node('a', 2)], []),
                 (nodes, [edge('a', 'missing', 1)]), (nodes, [edge('a', 'b', math.inf)]),
                 (nodes, [edge('a', 'b', -1)]), (nodes, [edge('a', 'b', 1, pts=[(0, 0, 0)])])]
        for ns, es in cases:
            with self.subTest(nodes=ns, edges=es), self.assertRaises(ValueError):
                lua_graph(ns, es)


class DiscoveryTests(unittest.TestCase):
    def test_continent_assignment_and_named_inn(self):
        db = dict(TaxiNodes=[], AreaPOI=[], AreaTable=[
            dict(ID='1', ContinentID='1', ParentAreaID='0', AreaName_lang='Zone'),
            dict(ID='2', ContinentID='1', ParentAreaID='1', AreaName_lang='Shady Rest Inn'),
            dict(ID='3', ContinentID='0', ParentAreaID='4', AreaName_lang='Other')])
        nodes = build_graph.discover(db, 1, dict(seeds={'2': (1, 2, 3), '3': (4, 5, 6)}, crossings=[]))
        self.assertEqual([(n['id'], n['kind']) for n in nodes], [('a2', 'inn')])

    def test_crossing_candidates_are_low_level_and_spaced(self):
        cells = [((False, 50), (0, 0, 50)), ((False, 60), (100, 0, 60)), ((True, 10), (900, 0, 10)), ((False, 70), (400, 0, 70))]
        self.assertEqual(build_graph.passes(cells), [(0, 0, 50), (400, 0, 70), (900, 0, 10)])

    def test_exclusions_carry_reasons(self):
        self.assertIn('Teldrassil', build_graph.exclusion(1, 'p38', (9952, 2254, 1336)))
        self.assertIn('island', build_graph.exclusion(1, 'a368', (-1117, -5383, 9)))
        self.assertEqual(build_graph.exclusion(1, 'a2322', (9717, -104, 0)), build_graph.SEA)
        self.assertIsNone(build_graph.exclusion(1, 'p33', (1382, -4371, 26)))
        self.assertIsNone(build_graph.exclusion(1, 'z148_493', (8247, -1935, 505)))

    def test_transport_stops_use_spline_map_not_zero_taxi_position(self):
        db = dict(TaxiNodes=[dict(ID='1', Name_lang='Transport, Test', ContinentID='0'),
                             dict(ID='2', Name_lang='End', ContinentID='1')],
                  TaxiPath=[dict(ID='3', FromTaxiNode='1', ToTaxiNode='2', Cost='999')],
                  TaxiPathNode=[dict(PathID='3', NodeIndex=str(i), Delay='60', ContinentID=str(i),
                                    Loc_0=str(i * 100), Loc_1='1', Loc_2='0') for i in range(2)])
        nodes, edges = build_graph.special_edges(db)
        self.assertEqual([n['map'] for n in nodes], [0, 1])
        self.assertEqual(edges[0]['kind'], 'boat')
        self.assertEqual(edges[0]['seconds'], 60)


class WaterTests(unittest.TestCase):
    def test_swim_surface_respects_mask_and_rejects_hazardous_liquid(self):
        from test_nav_routes import adt
        water = bytearray(3072)
        struct.pack_into('<III', water, 0, 3072, 1, 0)
        water += struct.pack('<HHff4BII', 2, 2, 20, 20, 0, 0, 2, 1, 3096, 0) + b'\x01'
        vertices, triangles = water_surface(adt(liquid=water), {1, 2})
        self.assertEqual(len(vertices), 4)
        self.assertEqual(len(triangles), 2)
        self.assertEqual({p[2] for p in vertices}, {20})
        self.assertEqual(water_surface(adt(liquid=water), {3, 4}), ([], []))


if __name__ == '__main__':
    unittest.main()
