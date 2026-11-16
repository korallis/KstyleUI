"""Tests for the Medallions style kit: Tools/media/medallions_kit.py's baked textures, their sources, provenance and tokens.

The bake itself needs NumPy and the raw generations, so these tests check what it shipped: sizes, the effects' clean
edges, every flipbook's registration and loop, the steel pieces' geometry, and that Core/Tokens.lua, Media/PROVENANCE.md
and Tools/media/medallions_sources.json agree with the files. The procedural chrome kit (KSTY-110) is checked for its
value ceiling and geometry, and redrawn and compared when NumPy is there. The image checks need Pillow and skip without it.
"""

import importlib.util
import json
import re
import unittest
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageStat
except ImportError:
    Image = None

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


kit = load("medallions_kit", "Tools/media/medallions_kit.py")
media = load("medallions_make_media", "Tools/media/make_media.py")
PROCEDURAL = [a for a in media.ASSETS if a.path.startswith(kit.OUT + "/")]
TOKEN_NAMES = {"MapMask": "medMinimapMask"}


def open_rgba(path):
    return Image.open(ROOT / path).convert("RGBA")


def tokens():
    text = (ROOT / "Core" / "Tokens.lua").read_text(encoding="ascii")
    found = {}
    for name, body in re.findall(r"\n\t(med\w+) = \{ (file = [^}]*)\}", text):
        fields = dict(re.findall(r"(\w+) = (\"[^\"]*\"|[0-9.]+)", body))
        found[name] = {k: (v.strip('"') if v.startswith('"') else float(v)) for k, v in fields.items()}
    return found


@unittest.skipIf(Image is None, "needs Pillow")
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
        on_disk = {p.name for p in (ROOT / kit.OUT).iterdir() if p.is_file()}
        pieces = [i.path for i in kit.KIT] + [a.path for a in PROCEDURAL] + [c.path for c in kit.CHROME]
        listed = {Path(path).name for path in pieces}
        self.assertEqual(on_disk, listed)
        self.assertEqual(len(listed), len(pieces), "two pieces share a file name")

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
        expected.update({c.token: c for c in kit.CHROME})
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
        for piece in kit.CHROME:
            spec = found[piece.token]
            self.assertEqual(spec.get("slice"), piece.slice, piece.name)
            self.assertEqual(spec.get("density"), piece.density, piece.name)
        for asset in PROCEDURAL:
            spec = found[TOKEN_NAMES.get(asset.name, "med" + asset.name)]
            self.assertEqual(spec.get("slice"), asset.slice, asset.name)
            if asset.slice:
                self.assertEqual(spec["density"], media.TEXELS_PER_UNIT, asset.name)


@unittest.skipIf(Image is None, "needs Pillow")
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


@unittest.skipIf(Image is None, "needs Pillow")
class SteelTest(unittest.TestCase):
    def test_bars_are_the_same_in_every_column(self):
        for name in ("BarFill", "BarTrack"):
            image = open_rgba(f"{kit.OUT}/{name}.png")
            first = image.crop((0, 0, 1, image.height))
            for x in range(1, image.width):
                self.assertEqual(ImageChops.difference(first, image.crop((x, 0, x + 1, image.height))).getbbox(), None, f"{name} column {x}")
            self.assertEqual(image.getchannel("A").getextrema(), (255, 255))

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


def alpha_at(image, x, y):
    return image.getpixel((x, y))[3]


@unittest.skipIf(Image is None, "needs Pillow")
class ChromeTest(unittest.TestCase):
    """KSTY-110's dark chrome kit: procedural, never brighter than the chrome ceiling, rounded, and the geometry the
    consumers size from."""

    def test_the_kit_is_the_spec_list(self):
        spec = {"UnitSlab", "ActionSlab", "Slot", "SlotHighlight", "SlotPushed", "SlotChecked", "Ring128", "Ring256",
                "HubSocket", "CardEdge", "MinimapRing", "LevelPlaque", "AuraBorder", "GroupTile",
                "GroupTargetRing", "TargetBrackets", "Enamel128", "Enamel256", "SlotMask", "SlotSocket"}
        self.assertEqual({c.name for c in kit.CHROME}, spec)

    def test_geometry_is_the_spec(self):
        self.assertEqual((kit.RING_UNITS, kit.RING_BAND, kit.ACCENT), (86, 8, 1.5), "KSTY-110 4.3: medallion 86, band 8")
        self.assertEqual((kit.HUB_UNITS, kit.HUB_BAND), (150, 16), "KSTY-110 4.3: hub ring 150, band 16")
        self.assertEqual((kit.SOCKET_UNITS, kit.SOCKET_INSET, kit.ICON_RADIUS), (42, 3, 2.5), "socket 42, icon inset 3, radius 2.5")
        self.assertEqual(kit.MAP_BAND, 14)
        face = (ROOT / "KstyleUI_Minimap" / "Face.lua").read_text(encoding="ascii")
        outer = float(re.search(r"^local RING_OUTER = ([0-9.]+)", face, re.M).group(1))
        self.assertEqual(kit.MAP_OPENING, outer, "the bezel opens where Face.lua sizes the map")

    def test_ring_openings_measured_from_the_files(self):
        for name, share in (("Ring128", 0.814), ("Ring256", 0.787)):
            image = open_rgba(f"{kit.OUT}/{name}.png")
            n = image.width
            row = [image.getpixel((x, n // 2))[3] for x in range(n // 2, n)]
            inner = next(i for i, a in enumerate(row) if a >= 128)
            with self.subTest(name):
                self.assertAlmostEqual(2 * inner / n, share, delta=1.5 / n * 2, msg="the portrait's share of the ring")

    def test_the_ceiling_is_the_lua_checks(self):
        lua = (ROOT / "Tools" / "regression" / "test-medallions-chrome-value.lua").read_text(encoding="utf-8")
        self.assertIn('local CEILING = "%02x%02x%02x"' % kit.CHROME_CEILING, lua)

    def test_dark_pieces_stay_under_the_chrome_ceiling(self):
        for piece in kit.CHROME:
            if not piece.dark:
                continue
            with self.subTest(piece.name):
                image = open_rgba(piece.path)
                worst = [0, 0, 0]
                for r, g, b, a in image.getdata():
                    if a:
                        worst = [max(worst[0], r), max(worst[1], g), max(worst[2], b)]
                for channel, ceiling in zip(worst, kit.CHROME_CEILING):
                    self.assertLessEqual(channel, ceiling, f"{piece.name} has a texel at {worst}")

    def test_light_pieces_are_white(self):
        for piece in kit.CHROME:
            if piece.dark:
                continue
            with self.subTest(piece.name):
                for r, g, b, a in open_rgba(piece.path).getdata():
                    if a:
                        self.assertEqual((r, g, b), (255, 255, 255))

    def test_sliced_pieces_have_round_corners_and_stretch_cleanly(self):
        for piece in kit.CHROME:
            if not piece.slice:
                continue
            with self.subTest(piece.name):
                image = open_rgba(piece.path)
                w, h = image.size
                self.assertEqual(alpha_at(image, 0, 0), 0, "the corner is rounded off")
                self.assertEqual(alpha_at(image, w // 2, 0), 255, "the edge runs straight between the corners")
                middle = image.crop((w // 2, 0, w // 2 + 1, h))
                for x in range(piece.slice, w - piece.slice):
                    self.assertIsNone(ImageChops.difference(middle, image.crop((x, 0, x + 1, h))).getbbox(), f"column {x}")

    def test_slabs_and_cards_have_a_black_outline_and_a_lit_top(self):
        for name in ("ActionSlab", "UnitSlab", "CardEdge", "GroupTile", "LevelPlaque"):
            image = open_rgba(f"{kit.OUT}/{name}.png")
            w, h = image.size
            with self.subTest(name):
                self.assertEqual(image.getpixel((w // 2, 0))[:3], (0, 0, 0))
                self.assertEqual(image.getpixel((w // 2, h - 1))[:3], (0, 0, 0))
                top, bottom = image.getpixel((w // 2, 5)), image.getpixel((w // 2, h - 6))
                self.assertGreater(sum(top[:3]), sum(bottom[:3]), "the rim is lit at the top")

    def test_card_fill_is_translucent(self):
        image = open_rgba(f"{kit.OUT}/CardEdge.png")
        self.assertEqual(image.getpixel((64, 64))[3], round(0.94 * 255))

    def test_rings_leave_the_portrait_share_clear(self):
        for name, units, band in (("Ring128", kit.RING_UNITS, kit.RING_BAND), ("Ring256", kit.HUB_UNITS, kit.HUB_BAND)):
            image = open_rgba(f"{kit.OUT}/{name}.png")
            n = image.width
            per_unit = n / units
            with self.subTest(name):
                for e, want in ((0.4, 255), (band - 0.8, 255), (band + 0.8, 0)):
                    y = int((e * per_unit))
                    self.assertEqual(alpha_at(image, n // 2, y), want, f"{e} units in from the top")
                self.assertGreater(sum(image.getpixel((n // 2, int(3 * per_unit)))[:3]),
                                   sum(image.getpixel((n // 2, n - 1 - int(3 * per_unit)))[:3]), "lit from 12 o'clock")

    def test_accent_lines_sit_just_inside_their_rings(self):
        for name, units, band in (("Enamel128", kit.RING_UNITS, kit.RING_BAND), ("Enamel256", kit.HUB_UNITS, kit.HUB_BAND)):
            image = open_rgba(f"{kit.OUT}/{name}.png")
            n = image.width
            per_unit = n / units
            with self.subTest(name):
                self.assertEqual(alpha_at(image, n // 2, int((band + kit.ACCENT / 2) * per_unit)), 255)
                self.assertEqual(alpha_at(image, n // 2, int((band - 0.5) * per_unit)), 0)
                self.assertEqual(alpha_at(image, n // 2, int((band + kit.ACCENT + 0.5) * per_unit) + 1), 0)

    def test_slot_socket_is_opaque_and_its_overlays_leave_the_icon_clear(self):
        socket = open_rgba(f"{kit.OUT}/SlotSocket.png")
        self.assertEqual(alpha_at(socket, 0, 0), 0)
        self.assertEqual(alpha_at(socket, 32, 32), 255, "the socket is drawn behind the icon, well included")
        self.assertLess(sum(socket.getpixel((32, 8))[:3]), sum(socket.getpixel((32, 55))[:3]), "the well is dark at the top")
        frame = open_rgba(f"{kit.OUT}/Slot.png")
        self.assertEqual(frame.crop((7, 7, 57, 57)).getchannel("A").getextrema(), (0, 0), "the frame leaves the icon clear")
        self.assertEqual((alpha_at(frame, 0, 0), alpha_at(frame, 32, 0), alpha_at(frame, 4, 4)), (0, 255, 255), "the rim rounds the icon's corners")
        self.assertEqual(frame.getpixel((32, 0))[:3], (0, 0, 0))
        for name in ("SlotPushed", "SlotHighlight", "SlotChecked"):
            self.assertEqual(alpha_at(open_rgba(f"{kit.OUT}/{name}.png"), 32, 32), 0, name)
        mask = open_rgba(f"{kit.OUT}/SlotMask.png")
        self.assertEqual((alpha_at(mask, 0, 0), alpha_at(mask, 32, 32), alpha_at(mask, 32, 0)), (0, 255, 255))

    def test_minimap_ring_opens_on_the_map_with_an_inner_shadow(self):
        image = open_rgba(f"{kit.OUT}/MinimapRing.png")
        n = image.width
        edge = int(n / 2 * (1 - kit.MAP_OPENING))
        self.assertEqual(alpha_at(image, n // 2, n // 2), 0)
        self.assertEqual(alpha_at(image, n // 2, edge // 2), 255, "the band")
        inside = alpha_at(image, n // 2, edge + 2)
        self.assertGreater(inside, 120, "the shadow is deepest at the map's edge")
        self.assertLessEqual(inside, round(kit.MAP_SHADOW_PEAK * 255))

    def test_committed_files_match_the_script(self):
        if importlib.util.find_spec("numpy") is None:
            self.skipTest("needs NumPy")
        self.assertEqual(kit.check_chrome(ROOT), [], "run Tools/media/medallions_kit.py chrome")


if __name__ == "__main__":
    unittest.main()
