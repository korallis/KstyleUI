"""Tests for the class renders: the class table in Tools/render/scenes/_classes.lua against Tools/data/abilities.json
and the stubs' class colours, the class portraits standins.py cuts, and Tools/render/classes.py's crops and manifest."""

import importlib.util
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLASSES_LUA = ROOT / "Tools" / "render" / "scenes" / "_classes.lua"
ABILITIES = ROOT / "Tools" / "data" / "abilities.json"
GROUP_ENV = ROOT / "Tools" / "regression" / "group_env.lua"
CLASSES_PY = ROOT / "Tools" / "render" / "classes.py"
STANDINS_PY = ROOT / "Tools" / "render" / "standins.py"

ORDER = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"]

try:
    from PIL import Image
except ImportError:  # pragma: no cover - depends on the machine
    Image = None


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def class_blocks():
    """The Lua source of each class's entry, by class token."""
    text = CLASSES_LUA.read_text(encoding="utf-8")
    starts = [(m.group(1), m.start()) for m in re.finditer(r"^Classes\.([A-Z]+) = \{(?=\n\ttitle = )", text, re.M)]
    blocks = {}
    for i, (name, start) in enumerate(starts):
        end = starts[i + 1][1] if i + 1 < len(starts) else text.index("\n-- Get(class)", start)
        blocks[name] = text[start:end]
    return blocks


def spells_of(block):
    """Every { "Name", icon } pair in a class block, as (name, icon) tuples, with the pet's actions apart."""
    pairs = re.findall(r'\{ "([^"]+)", (\d+)', block)
    pet = block.find("pet = {")
    pet_pairs = re.findall(r'\{ "([^"]+)", (\d+)', block[pet:]) if pet >= 0 else []
    main = pairs[: len(pairs) - len(pet_pairs)] if pet_pairs else pairs
    return [(n, int(i)) for n, i in main], [(n, int(i)) for n, i in pet_pairs]


class ClassTableTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.blocks = class_blocks()
        data = json.loads(ABILITIES.read_text(encoding="utf-8"))
        cls.known = {}
        cls.racial = {}
        for entry in data["icons"]:
            for spell in entry["spells"]:
                cls.known.setdefault((spell["owner"], spell["name"], spell["category"]), set()).add(entry["icon"])
                if spell["category"] == "racial":
                    cls.racial.setdefault(spell["name"], set()).add(entry["icon"])

    def test_nine_classes_in_the_games_order(self):
        self.assertEqual(list(self.blocks), ORDER)
        text = CLASSES_LUA.read_text(encoding="utf-8")
        self.assertIn('Classes.ORDER = { "' + '", "'.join(ORDER) + '" }', text)

    def test_every_spell_is_that_class_spell_with_its_icon_from_abilities_json(self):
        for name, block in self.blocks.items():
            main, pet = spells_of(block)
            self.assertGreaterEqual(len(main), 40, name + " lists its bars, cluster, buffs and buff row")
            for spell, icon in main:
                # A racial (the orc's Blood Fury) sits on a bar as a class spell would, and a pet's buff on its
                # master (the imp's Fire Shield and Blood Pact) sits in the buff row.
                icons = self.known.get((name, spell, "class"), set()) or self.known.get((name, spell, "pet"), set()) or self.racial.get(spell, set())
                self.assertTrue(icons, "%s: %s is not a %s class or pet spell, or a racial, in abilities.json" % (name, spell, name.lower()))
                self.assertIn(icon, icons, "%s: %s has icon %s in abilities.json, not %d" % (name, spell, sorted(icons), icon))
            for spell, icon in pet:
                icons = self.known.get((name, spell, "pet"), set())
                self.assertTrue(icons, "%s: %s is not a %s pet action in abilities.json" % (name, spell, name.lower()))
                self.assertIn(icon, icons, "%s: pet action %s has icon %s, not %d" % (name, spell, sorted(icons), icon))

    def test_pets_and_forms_follow_the_class(self):
        for name, block in self.blocks.items():
            self.assertEqual("pet = {" in block, name in ("HUNTER", "WARLOCK"), name + ": a pet for the hunter and the warlock only")
            self.assertEqual("forms = {" in block, name in ("WARRIOR", "DRUID", "ROGUE"), name + ": forms for the warrior, the druid and the rogue")
            self.assertEqual("cast = {" in block, name != "ROGUE", name + ": every class but the rogue casts")
            self.assertEqual("combo = " in block, name == "ROGUE", name + ": combo points for the rogue")

    def test_class_colours_match_the_stubs_raid_class_colors(self):
        stub = GROUP_ENV.read_text(encoding="utf-8")
        start = stub.index("local CLASS_COLORS = {")
        wanted = dict(re.findall(r"([A-Z]+) = \{ ([^}]+) \}", stub[start:stub.index("}\n", start) + 2]))
        for name, block in self.blocks.items():
            colour = re.search(r"colour = \{ ([^}]+) \}", block).group(1)
            ours = [float(v) for v in colour.split(",")]
            theirs = [float(v) for v in wanted[name].split(",")]
            self.assertEqual(ours, theirs, name + " wears the stubs' RAID_CLASS_COLORS value")

    def test_power_tokens(self):
        powers = {"WARRIOR": "RAGE", "ROGUE": "ENERGY"}
        for name, block in self.blocks.items():
            token = powers.get(name, "MANA")
            self.assertRegex(block, r"power = " + token + r"\b", name + " draws " + token.lower())


class ClassesScriptTest(unittest.TestCase):
    def setUp(self):
        self.classes = load(CLASSES_PY, "classes")

    def test_the_frames_crop_is_the_close_up_box_at_the_renders_density(self):
        self.assertEqual(self.classes.FRAMES_BOX, (290, 640, 1100, 440))
        self.assertEqual(self.classes.pixel_box((290, 640, 1100, 440), 1.426, 2383, 1540), (414, 913, 1982, 1540))
        self.assertEqual(self.classes.pixel_box((0, 0, 10, 10), 2.0, 15, 15), (0, 0, 15, 15))

    def test_hex_spells_the_colour_as_the_game_does(self):
        self.assertEqual(self.classes.hex_of([0.78, 0.61, 0.43]), "C79C6E")
        self.assertEqual(self.classes.hex_of([1, 1, 1]), "FFFFFF")
        self.assertEqual(self.classes.hex_of([0, 0.44, 0.87]), "0070DE")

    def test_the_manifest_entry_reads_the_scene_json(self):
        scene = {"class": {"class": "MAGE", "title": "Mage", "name": "Tinkwee", "colour": [0.25, 0.78, 0.92], "power": "MANA", "cast": "Fireball"}}
        entry = self.classes.manifest_entry(scene, "mage.png", "mage_frames.png", "the accent reads well")
        self.assertEqual(entry["class"], "MAGE")
        self.assertEqual(entry["title"], "Mage")
        self.assertEqual(entry["name"], "Tinkwee")
        self.assertEqual(entry["colour"], "40C7EB")
        self.assertEqual(entry["power"], "MANA")
        self.assertEqual(entry["cast"], "Fireball")
        self.assertEqual(entry["file"], "mage.png")
        self.assertEqual(entry["frames"], "mage_frames.png")
        self.assertEqual(entry["notes"], "the accent reads well")
        rogue = self.classes.manifest_entry({"class": {"class": "ROGUE", "title": "Rogue", "name": "Rokhan", "colour": [1, 0.96, 0.41], "power": "ENERGY", "cast": None}}, "r.png", "rf.png", "")
        self.assertEqual(rogue["cast"], "none")

    def test_nine_scenes_one_per_class(self):
        self.assertEqual([c.lower() for c in ORDER], list(self.classes.CLASSES))
        for name in self.classes.CLASSES:
            self.assertTrue((ROOT / "Tools" / "render" / "scenes" / ("hud_%s_mac.lua" % name)).exists(), name + " has a scene script")

    @unittest.skipIf(Image is None, "Pillow is not installed")
    def test_cut_writes_the_full_render_and_the_frames_crop(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            render = Image.new("RGB", (100, 80), (10, 20, 30))
            render.putpixel((50, 50), (255, 0, 0))
            render.save(tmp / "hud_mage_mac.png")
            full, frames = self.classes.cut(tmp / "hud_mage_mac.png", "mage", tmp, (20, 40, 50, 20), 1.0)
            self.assertEqual(Path(full).name, "mage.png")
            self.assertEqual(Path(frames).name, "mage_frames.png")
            self.assertEqual(Image.open(full).size, (100, 80))
            crop = Image.open(frames)
            self.assertEqual(crop.size, (50, 20))
            self.assertEqual(crop.getpixel((30, 10)), (255, 0, 0), "the crop starts at the box's corner")
            self.assertEqual(crop.getpixel((0, 0)), (10, 20, 30))

    def test_a_reused_render_must_match_the_density(self):
        screen = {"width": 1080 * 2383 / 1540, "height": 1080}
        self.assertTrue(self.classes.density_matches((2384, 1541), screen, 1.426))
        self.assertFalse(self.classes.density_matches((3343, 2160), screen, 1.426))
        self.assertTrue(self.classes.density_matches((3343, 2160), screen, 2.0))


class ClassPortraitsTest(unittest.TestCase):
    def setUp(self):
        self.standins = load(STANDINS_PY, "standins")

    def test_class_portraits_lists_the_classes_the_folder_holds(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "mage.png").write_bytes(b"")
            (Path(tmp) / "druid.png").write_bytes(b"")
            (Path(tmp) / "monk.png").write_bytes(b"")
            found = self.standins.class_portraits(tmp)
            self.assertEqual([name for name, _ in found], ["mage", "druid"])

    def test_portraits_folder_comes_from_the_flag_then_the_environment_then_the_default(self):
        self.assertEqual(self.standins.portraits_path("/p", {"KSTYLEUI_PORTRAITS": "/e"}), "/p")
        self.assertEqual(self.standins.portraits_path(None, {"KSTYLEUI_PORTRAITS": "/e"}), "/e")
        self.assertEqual(self.standins.portraits_path(None, {}), self.standins.PORTRAITS)

    @unittest.skipIf(Image is None, "Pillow is not installed")
    def test_a_class_whose_portrait_went_away_loses_its_file(self):
        self.standins.pillow()
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            portraits = tmp / "portraits"
            portraits.mkdir()
            Image.new("RGB", (64, 64), (1, 2, 3)).save(portraits / "mage.png")
            out = tmp / "out"
            self.standins.write_portraits(str(out), str(portraits))
            self.assertTrue((out / "portrait-player-mage.png").exists())
            (portraits / "mage.png").unlink()
            Image.new("RGB", (64, 64), (1, 2, 3)).save(portraits / "druid.png")
            written = self.standins.write_portraits(str(out), str(portraits))
            self.assertEqual([Path(p).name for p in written], ["portrait-player-druid.png"])
            self.assertFalse((out / "portrait-player-mage.png").exists(), "the stale portrait is removed so the orc stands in")
            self.assertEqual(self.standins.write_portraits.used, ["druid"])

    @unittest.skipIf(Image is None, "Pillow is not installed")
    def test_a_class_portrait_is_squared_from_its_centre_at_the_portrait_size(self):
        self.standins.pillow()
        wide = Image.new("RGB", (300, 100), (0, 0, 0))
        self.assertEqual(self.standins.centre_square(wide), (100, 0, 200, 100))
        tall = Image.new("RGB", (100, 300), (0, 0, 0))
        self.assertEqual(self.standins.centre_square(tall), (0, 100, 100, 200))
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            mockup = Image.new("RGB", (2574, 1456), (40, 40, 40))
            mockup.save(tmp / "mockup.png")
            portraits = tmp / "portraits"
            portraits.mkdir()
            Image.new("RGB", (1024, 1024), (200, 100, 50)).save(portraits / "priest.png")
            out = tmp / "out"
            written = self.standins.write(str(tmp / "mockup.png"), str(out), 200, 120, plate=None, portraits=str(portraits))
            self.assertIn(str(out / "portrait-player-priest.png"), written)
            self.assertEqual(self.standins.write.portraits_used, ["priest"])
            portrait = Image.open(out / "portrait-player-priest.png")
            self.assertEqual(portrait.size, (self.standins.PORTRAIT_SIZE, self.standins.PORTRAIT_SIZE))
            self.assertEqual(portrait.getpixel((64, 64)), (200, 100, 50))
            self.assertFalse((out / "portrait-player-mage.png").exists(), "a class with no portrait gets no file")


if __name__ == "__main__":
    unittest.main()
