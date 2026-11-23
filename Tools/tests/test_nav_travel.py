"""Overlay and transport rules use synthetic client rows, never the game install."""

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'nav'))

import build_travel


def overlay(key, art, width, height, x, y):
    return dict(ID=key, UiMapArtID=art, TextureWidth=str(width), TextureHeight=str(height), OffsetX=str(x), OffsetY=str(y))


def tile(overlay_id, row, column, file_id):
    return dict(WorldMapOverlayID=overlay_id, RowIndex=str(row), ColIndex=str(column), LayerIndex='0', FileDataID=str(file_id))


def db(overlays, tiles):
    return dict(UiMapXMapArt=[dict(UiMapArtID='7', UiMapID='1411')], UiMapArt=[dict(ID='7', UiMapArtStyleID='1')],
                UiMapArtStyleLayer=[dict(UiMapArtStyleID='1', LayerIndex='0', TileWidth='256')],
                WorldMapOverlay=overlays, WorldMapOverlayTile=tiles)


class OverlayTests(unittest.TestCase):
    def test_tiles_are_row_major_by_map(self):
        text, count, skipped = build_travel.overlays(db(
            [overlay('1', '7', 300, 300, 10, 20), overlay('2', '9', 100, 100, 0, 0)],
            [tile('1', 1, 1, 14), tile('1', 0, 1, 12), tile('1', 1, 0, 13), tile('1', 0, 0, 11), tile('2', 0, 0, 99)]))
        self.assertEqual((count, skipped), (1, []))
        self.assertIn('return {[1411]={{300,300,10,20,11,12,13,14}}}', text)
        self.assertTrue(text.startswith('-- Overlays.lua:') and text.count('--') == 1)

    def test_tile_count_mismatch_is_skipped(self):
        _, count, skipped = build_travel.overlays(db([overlay('1', '7', 300, 100, 0, 0)], [tile('1', 0, 0, 11)]))
        self.assertEqual((count, skipped), (0, ['1']))


class TransportTests(unittest.TestCase):
    def test_only_flying_transports_are_zeppelins(self):
        rows = dict(
            TaxiNodes=[dict(ID='1', Name_lang='Transport, Ship'), dict(ID='2', Name_lang='Transport, Zeppelin'), dict(ID='3', Name_lang='Orgrimmar')],
            TaxiPath=[dict(ID='10', FromTaxiNode='1'), dict(ID='20', FromTaxiNode='2'), dict(ID='30', FromTaxiNode='3')],
            TaxiPathNode=[dict(PathID='10', Loc_2='0.5'), dict(PathID='20', Loc_2='0'), dict(PathID='20', Loc_2='120'), dict(PathID='30', Loc_2='200')])
        self.assertEqual(build_travel.zeppelins(rows), [20])


class AreaTests(unittest.TestCase):
    def test_area_ids_answer_to_road_place_names(self):
        rows = dict(AreaTable=[dict(ID='362', AreaName_lang='Razor Hill', ContinentID='1'), dict(ID='159', AreaName_lang='Brill', ContinentID='0'),
                               dict(ID='1519', AreaName_lang='Stormwind City', ContinentID='0'), dict(ID='3487', AreaName_lang='Eversong', ContinentID='530')])
        graphs = ['{id=1,name="Razor Hill",x=1},{id=4,name="Stormwind",x=4}', '{id=2,name="Brill, Tirisfal Glades",x=2},{id=3,name="Eversong",x=3}']
        self.assertEqual(build_travel.areas(rows, graphs), {362: 'Razor Hill', 159: 'Brill', 1519: 'Stormwind'})


if __name__ == '__main__':
    unittest.main()
