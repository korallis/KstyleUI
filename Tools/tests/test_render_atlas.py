"""Tests for Tools/render/atlas.py: the atlas map from the client's DB2 tables, and the texture fetch."""

import contextlib
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

RENDER = Path(__file__).resolve().parents[1] / "render"


def load(name):
    spec = importlib.util.spec_from_file_location(name, RENDER / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ATLASES = (
    "ID,FileDataID,UiTextureAtlasSetID,AtlasWidth,AtlasHeight,UiCanvasID\n"
    "1,1001,0,1024,512,1\n"  # the 1x sheet
    "2,1002,0,2048,1024,2\n"  # the 2x sheet
    "3,1003,0,512,512,1\n"  # Forever's own sheet
    "4,1004,0,64,32,1\n"
)

MEMBERS = (
    "CommittedName,ID,UiTextureAtlasID,Width,Height,CommittedLeft,CommittedRight,CommittedTop,CommittedBottom,"
    "UiTextureAtlasElementID,OverrideWidth,OverrideHeight,CommittedFlags,UiCanvasID\n"
    "ui-hud-unitframe-player-group-leadericon,10,1,16,16,213,229,490,506,100,0,0,0,0\n"
    "ui-hud-unitframe-player-group-leadericon-2x,11,2,32,32,426,458,980,1012,100,0,0,0,0\n"
    "ui-hud-actionbar-keyring-small-c60,12,3,27,40,1,28,1,41,101,0,0,0,0\n"
    "ui-hud-actionbar-keyring-small,13,1,27,40,600,627,100,140,101,0,0,0,0\n"
    "roleicon-tiny-tank,14,4,16,16,0,16,0,16,102,0,0,0,0\n"
    "_tiles-h,15,4,8,8,16,24,0,8,103,0,0,4,0\n"
    "_override,16,4,8,8,24,40,0,8,104,12,6,0,0\n"
)

ELEMENTS = (
    "Name,ID\n"
    "UI-HUD-UnitFrame-Player-Group-LeaderIcon,100\n"
    "UI-HUD-ActionBar-Keyring-Small,101\n"
    "roleicon-tiny-tank,102\n"
    "Tiles-H,103\n"
    "Override,104\n"
)


class AtlasMapTest(unittest.TestCase):
    def setUp(self):
        self.atlas = load("atlas")
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)
        for name, text in (("UiTextureAtlas", ATLASES), ("UiTextureAtlasMember", MEMBERS), ("UiTextureAtlasElement", ELEMENTS)):
            (self.dir / (name + ".csv")).write_text(text, encoding="utf-8")
        self.map = self.atlas.build_map(self.dir)

    def tearDown(self):
        self._tmp.cleanup()

    def test_keys_are_element_names_lowercased(self):
        self.assertEqual(
            sorted(self.map),
            ["override", "roleicon-tiny-tank", "tiles-h", "ui-hud-actionbar-keyring-small", "ui-hud-unitframe-player-group-leadericon"],
        )

    def test_prefers_the_2x_sheet_and_keeps_the_1x_size(self):
        entry = self.map["ui-hud-unitframe-player-group-leadericon"]
        self.assertEqual(entry["file"], 1002)
        self.assertEqual((entry["atlasWidth"], entry["atlasHeight"]), (2048, 1024))
        self.assertEqual((entry["left"], entry["right"], entry["top"], entry["bottom"]), (426, 458, 980, 1012))
        self.assertEqual((entry["width"], entry["height"]), (16, 16))

    def test_prefers_forevers_c60_member(self):
        entry = self.map["ui-hud-actionbar-keyring-small"]
        self.assertEqual(entry["file"], 1003)
        self.assertEqual((entry["left"], entry["top"]), (1, 1))

    def test_flags_and_overrides(self):
        self.assertEqual((self.map["tiles-h"]["tilesH"], self.map["tiles-h"]["tilesV"]), (True, False))
        self.assertEqual((self.map["override"]["width"], self.map["override"]["height"]), (12, 6))

    def test_tsv_round_trip(self):
        path = self.dir / "atlas.tsv"
        self.atlas.write_tsv(self.map, path)
        lines = path.read_text(encoding="utf-8").splitlines()
        self.assertEqual(lines[0], "name\tfile\tatlasWidth\tatlasHeight\tleft\tright\ttop\tbottom\twidth\theight\ttilesH\ttilesV")
        self.assertIn("roleicon-tiny-tank\t1004\t64\t32\t0\t16\t0\t16\t16\t16\t0\t0", lines)
        self.assertEqual(len(lines), 1 + len(self.map))

    def test_scan_finds_atlas_names_in_scene_json(self):
        scene = self.dir / "scene.json"
        scene.write_text(json.dumps({"items": [{"atlas": "UI-Test-A"}, {"atlas": "ui-test-a"}, {"file": "x.png"}, {"atlas": "Other"}]}), encoding="utf-8")
        self.assertEqual(self.atlas.scan_names([str(scene)]), {"ui-test-a", "other"})

    def test_fetch_extracts_each_sheet_once_and_names_unknown_atlases(self):
        calls = []

        def tool(file_id, blp):
            calls.append(file_id)
            Path(blp).write_bytes(b"BLP2")

        def decode(blp, png):
            Path(png).write_bytes(b"PNG")

        textures = self.dir / "textures"
        unknown = self.atlas.fetch(self.map, ["roleicon-tiny-tank", "Tiles-H", "no-such-atlas", "ROLEICON-TINY-TANK"], textures, tool=tool, decode=decode)
        self.assertEqual(unknown, ["no-such-atlas"])
        self.assertEqual(calls, [1004])
        self.assertTrue((textures / "1004.png").exists())
        self.assertFalse((textures / "1004.blp").exists(), "the BLP is removed once the PNG exists")
        # A second fetch finds the PNG and runs no tool.
        self.atlas.fetch(self.map, ["roleicon-tiny-tank"], textures, tool=tool, decode=decode)
        self.assertEqual(calls, [1004])

    def test_main_build_writes_the_cache_from_exported_tables(self):
        cache = self.dir / "cache"
        exported = []

        def export(out_dir):
            exported.append(out_dir)
            for name in ("UiTextureAtlas", "UiTextureAtlasMember", "UiTextureAtlasElement"):
                Path(out_dir).mkdir(parents=True, exist_ok=True)
                (Path(out_dir) / (name + ".csv")).write_text((self.dir / (name + ".csv")).read_text(encoding="utf-8"), encoding="utf-8")

        fetched = []

        def tool(file_id, blp):
            fetched.append(file_id)
            Path(blp).write_bytes(b"BLP2")

        def decode(blp, png):
            Path(png).write_bytes(b"PNG")

        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = self.atlas.main(["build", "roleicon-tiny-tank", "--cache", str(cache)], export=export, tool=tool, decode=decode)
        self.assertEqual(code, 0)
        self.assertIn("wrote 5 atlases", out.getvalue())
        self.assertEqual(exported, [cache / "db2"])
        self.assertTrue((cache / "atlas.tsv").exists())
        self.assertEqual(fetched, [1004])
        # fetch reuses the written map and reports what the client lacks.
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()) as err:
            code = self.atlas.main(["fetch", "Tiles-H", "nothing-here", "--cache", str(cache)], tool=tool, decode=decode)
        self.assertEqual(code, 1)
        self.assertIn("nothing-here", err.getvalue())
        self.assertEqual(fetched, [1004], "Tiles-H shares the sheet already fetched")


if __name__ == "__main__":
    unittest.main()
