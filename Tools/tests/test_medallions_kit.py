"""Tests for the Medallions style kit: Tools/media/medallions_kit.py's baked textures, their sources, provenance and tokens.

The bake itself needs NumPy and the raw generations, so these tests check what it shipped: sizes, the effects' clean
edges, every flipbook's registration and loop, the steel pieces' geometry, and that Core/Tokens.lua, Media/PROVENANCE.md
and Tools/media/medallions_sources.json agree with the files. Pillow only.
"""

import importlib.util
import json
import re
import unittest
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


kit = load("medallions_kit", "Tools/media/medallions_kit.py")
media = load("medallions_make_media", "Tools/media/make_media.py")
PROCEDURAL = [a for a in media.ASSETS if a.path.startswith(kit.OUT + "/")]
TOKEN_NAMES = {"Ring128": "medRing", "Ring256": "medRingLarge", "Enamel128": "medEnamel", "Enamel256": "medEnamelLarge", "MapMask": "medMinimapMask"}


def open_rgba(path):
    return Image.open(ROOT / path).convert("RGBA")


def tokens():
    text = (ROOT / "Core" / "Tokens.lua").read_text(encoding="ascii")
    found = {}
    for name, body in re.findall(r"\n\t(med\w+) = \{ (file = [^}]*)\}", text):
        fields = dict(re.findall(r"(\w+) = (\"[^\"]*\"|[0-9.]+)", body))
        found[name] = {k: (v.strip('"') if v.startswith('"') else float(v)) for k, v in fields.items()}
    return found


class FilesTest(unittest.TestCase):
    def test_every_kit_file_is_a_power_of_two_rgba_png_at_its_size(self):
        for item in kit.KIT:
            with self.subTest(item.name):
                image = Image.open(ROOT / item.path)
                self.assertEqual(image.format, "PNG")
                self.assertEqual(image.mode, "RGBA")
                self.assertEqual(image.size, (item.width, item.height))
                for side in image.size:
                    self.assertEqual(side & (side - 1), 0, f"{item.name} is not a power of two")

    def test_the_folder_holds_only_kit_and_procedural_files(self):
        on_disk = {p.name for p in (ROOT / kit.OUT).iterdir()}
        listed = {Path(i.path).name for i in kit.KIT} | {Path(a.path).name for a in PROCEDURAL}
        self.assertEqual(on_disk, listed)
        self.assertEqual(len(listed), len(kit.KIT) + len(PROCEDURAL), "two pieces share a file name")

    def test_one_proc_ambient_burst_and_particle_set_per_class(self):
        names = {i.name for i in kit.KIT}
        for cls in kit.CLASSES:
            for kind in ("Proc", "Ambient", "Burst", "Particle"):
                self.assertIn(kind + cls, names)


class SourcesTest(unittest.TestCase):
    def test_every_source_has_a_job_a_model_and_an_original_prompt(self):
        sources = kit.sources()
        used = {i.source for i in kit.KIT}
        self.assertEqual(used - set(sources), set(), "a kit piece names a source with no record")
        self.assertEqual(set(sources) - used, set(), "a recorded source is not used")
        for key, item in sources.items():
            with self.subTest(key):
                self.assertRegex(item["job_id"], r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
                self.assertIn(item["thread"], ("KSTY-88", "KSTY-90"))
                self.assertTrue(item["model"])
                self.assertGreater(len(item["prompt"]), 80)
                for banned in ("caith", "meow", "blizzard", "warcraft", "azeroth"):
                    self.assertNotIn(banned, item["prompt"].lower(), "prompts are original and name no other work")

    def test_provenance_holds_the_kit_table(self):
        text = (ROOT / "Media" / "PROVENANCE.md").read_text(encoding="utf-8")
        self.assertIn(kit.provenance_table(), text, "run Tools/media/medallions_kit.py provenance")


class TokensTest(unittest.TestCase):
    def test_every_file_has_a_token_and_every_token_a_file(self):
        found = tokens()
        expected = {i.token: i for i in kit.KIT}
        expected.update({TOKEN_NAMES.get(a.name, "med" + a.name): a for a in PROCEDURAL})
        self.assertEqual(set(found), set(expected))
        for name, spec in found.items():
            with self.subTest(name):
                item = expected[name]
                self.assertEqual(spec["file"], "Textures\\\\Medallions\\\\" + Path(item.path).name)
                self.assertTrue((ROOT / item.path).exists())

    def test_flipbook_and_slice_fields_match_the_files(self):
        found = tokens()
        for item in kit.KIT:
            spec = found[item.token]
            if item.flip:
                rows, columns, frames, seconds = item.flip
                self.assertEqual((spec["rows"], spec["columns"], spec["frames"]), (rows, columns, frames), item.name)
                self.assertEqual(spec.get("seconds"), seconds, item.name)
            else:
                self.assertNotIn("frames", spec, item.name)
        for asset in PROCEDURAL:
            spec = found[TOKEN_NAMES.get(asset.name, "med" + asset.name)]
            self.assertEqual(spec.get("slice"), asset.slice, asset.name)
            if asset.slice:
                self.assertEqual(spec["density"], media.TEXELS_PER_UNIT, asset.name)


class EffectsTest(unittest.TestCase):
    def border_alpha(self, image):
        w, h = image.size
        a = image.getchannel("A")
        edge = [a.getpixel((x, y)) for x in range(w) for y in (0, h - 1)] + [a.getpixel((x, y)) for y in range(h) for x in (0, w - 1)]
        return max(edge)

    def test_effects_fade_to_nothing_at_every_edge_and_cell_edge(self):
        for item in kit.KIT:
            if item.blend != "ADD" or item.recipe in ("vignette", "slot_highlight", "slot_checked", "glyphs"):
                continue
            image = open_rgba(item.path)
            pieces = kit.cells(image, item.flip[0], item.flip[1]) if item.flip else [image]
            for i, piece in enumerate(pieces):
                with self.subTest(item=item.name, cell=i):
                    self.assertLessEqual(self.border_alpha(piece), 2)

    def test_loops_are_registered_and_seamless(self):
        for item in kit.KIT:
            if item.recipe != "loop":
                continue
            rows, columns, frames, _ = item.flip
            m = kit.flipbook_metrics(ROOT / item.path, rows, columns, frames)
            with self.subTest(item.name):
                self.assertLessEqual(m["core_offset"], 3.0, "the effect's core sits on the cell centre")
                self.assertLessEqual(m["seam"], kit.LOOP_LIMIT * m["median_step"], "the last frame flows into the first")
                self.assertGreater(min(m["means"]), 1.0, "no frame of a loop is empty")

    def test_every_loop_frame_is_distinct(self):
        for item in kit.KIT:
            if item.recipe != "loop":
                continue
            rows, columns, frames, _ = item.flip
            lights = [kit.light(c) for c in kit.cells(open_rgba(item.path), rows, columns)[:frames]]
            median = kit.flipbook_metrics(ROOT / item.path, rows, columns, frames)["median_step"]
            for i in range(frames):
                for j in range(i + 1, frames):
                    with self.subTest(item=item.name, pair=(i + 1, j + 1)):
                        self.assertGreater(kit.mean_difference(lights[i], lights[j]), 0.2 * median, "two frames are the same picture")

    def test_level_up_swells_from_a_spark_and_fades_out(self):
        item = kit.BY_NAME["LevelUp"]
        m = kit.flipbook_metrics(ROOT / item.path, 4, 4, 16, oneshot=True)
        peak = max(m["means"])
        self.assertLess(m["means"][0], 0.1 * peak)
        self.assertLess(m["means"][-1], 0.03 * peak)
        self.assertLessEqual(m["core_offset"], 3.0)

    def test_procs_leave_the_slot_icon_clear(self):
        for cls in kit.CLASSES:
            image = open_rgba(f"{kit.OUT}/Proc{cls}.png")
            for i, cell in enumerate(kit.cells(image, 4, 4)):
                middle = kit.light(cell).crop((40, 40, 88, 88))
                with self.subTest(cls=cls, frame=i):
                    self.assertLess(ImageStat.Stat(middle).mean[0], 8, "the middle of the slot stays dark")

    def test_particle_variants_are_centred_in_their_cells(self):
        for cls in kit.CLASSES:
            for i, cell in enumerate(kit.cells(open_rgba(f"{kit.OUT}/Particle{cls}.png"), 2, 2)):
                x, y = kit.centroid(kit.light(cell))
                with self.subTest(cls=cls, cell=i):
                    self.assertLess(abs(x - 31.5) + abs(y - 31.5), 8)


class SteelTest(unittest.TestCase):
    def test_steel_card_tiles_without_a_seam(self):
        image = open_rgba(f"{kit.OUT}/SteelCard.png").convert("L")
        w, h = image.size
        def column(x):
            return image.crop((x, 0, x + 1, h))
        def row(y):
            return image.crop((0, y, w, y + 1))
        inner = (kit.mean_difference(column(w // 2), column(w // 2 + 1)) + kit.mean_difference(row(h // 2), row(h // 2 + 1))) / 2
        wrap = (kit.mean_difference(column(w - 1), column(0)) + kit.mean_difference(row(h - 1), row(0))) / 2
        self.assertLessEqual(wrap, 1.5 * inner + 0.5)

    def test_bars_are_the_same_in_every_column(self):
        for name in ("BarFill", "BarTrack"):
            image = open_rgba(f"{kit.OUT}/{name}.png")
            first = image.crop((0, 0, 1, image.height))
            for x in range(1, image.width):
                self.assertEqual(ImageChops.difference(first, image.crop((x, 0, x + 1, image.height))).getbbox(), None, f"{name} column {x}")
            self.assertEqual(image.getchannel("A").getextrema(), (255, 255))

    def test_slots_have_a_clear_opening_and_black_outer_line(self):
        for name in ("Slot", "SlotPushed"):
            image = open_rgba(f"{kit.OUT}/{name}.png")
            self.assertEqual(image.crop((10, 10, 54, 54)).getchannel("A").getextrema(), (0, 0), name)
            for x in range(64):
                for y in (0, 63):
                    r, g, b, a = image.getpixel((x, y))
                    self.assertEqual(a, 255, name)
                    self.assertLess(max(r, g, b), 24, name)

    def test_rings_have_a_clear_middle_and_corners(self):
        for name in ("HubSocket", "RuneRing", "MinimapRing"):
            image = open_rgba(f"{kit.OUT}/{name}.png")
            n = image.width
            self.assertEqual(image.getpixel((0, 0))[3], 0, name)
            if name != "HubSocket":
                self.assertEqual(image.getpixel((n // 2, n // 2))[3], 0, name)

    def test_rune_glyphs_sit_on_the_rune_band(self):
        glyphs = open_rgba(f"{kit.OUT}/RuneGlyphs.png").getchannel("A")
        band = open_rgba(f"{kit.OUT}/RuneRing.png").getchannel("A")
        stray = ImageChops.subtract(glyphs, band.point(lambda v: 255 if v > 64 else 0))
        self.assertLess(ImageStat.Stat(stray).sum[0], 255 * 4, "a glyph lies off the band")
        self.assertGreater(ImageStat.Stat(glyphs).mean[0], 2, "the glyph mask is not empty")

    def test_hub_wing_points_right_from_the_hub_centre(self):
        alpha = open_rgba(f"{kit.OUT}/HubWing.png").getchannel("A")
        left, top, right, bottom = alpha.getbbox()
        self.assertGreater(left, 0.3 * alpha.width, "the ring is cut away: the wing starts at the rune ring's edge")
        self.assertGreater(right, 0.95 * alpha.width, "the tip reaches the right edge")
        self.assertLess(abs((top + bottom) / 2 - alpha.height / 2), 6, "the wing is centred on the hub's middle")


if __name__ == "__main__":
    unittest.main()
