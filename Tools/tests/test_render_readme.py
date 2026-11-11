"""Tests for Tools/render/readme.py and the README's pictures: the crop and size helpers, that README.md shows exactly the
pictures the script writes, that each one is captioned as a test render, that they fit the size budget and that the
packaged addon does not ship them."""

import importlib.util
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
README = ROOT / "README.md"
MEDIA = ROOT.joinpath("docs", "media", "readme")
PKGMETA = ROOT / ".pkgmeta"

try:
    from PIL import Image
except ImportError:  # pragma: no cover - depends on the machine
    Image = None


def load():
    spec = importlib.util.spec_from_file_location("readme_script", ROOT / "Tools" / "render" / "readme.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


R = load()


def readme_pictures():
    """The picture names README.md shows, in order, with the caption each one is read under."""
    text = README.read_text(encoding="utf-8")
    tables = [(m.start(), m.end()) for m in re.finditer(r"<table>.*?</table>", text, re.S)]
    found = []
    for match in re.finditer(r'<img src="[^"]*/readme/([a-z_]+)\.png"[^>]*>', text):
        table = next((t for t in tables if t[0] < match.start() < t[1]), None)
        if table:
            after = text[table[1]:]
            caption = re.match(r"\s*<p[^>]*><sub>(.*?)</sub>", after, re.S)
        else:
            after = text[match.end():]
            caption = re.search(r"<sub>(.*?)</sub>", after[: after.find("<img") if "<img" in after else len(after)], re.S)
        found.append((match.group(1), caption.group(1) if caption else ""))
    return found


class Helpers(unittest.TestCase):
    def test_cover_box_hangs_a_16_by_10_window_from_the_top_edge(self):
        self.assertEqual(R.cover_box(1600, 1000), (0, 0, 1600, 1000))
        self.assertEqual(R.cover_box(1000, 1000), (0, 0, 1000, 625))
        self.assertEqual(R.cover_box(1000, 300), (260, 0, 740, 300))

    def test_parse_crop_reads_width_height_and_offset(self):
        self.assertEqual(R.parse_crop("620x1160+2800+20"), (2800, 20, 3420, 1180))

    def test_fit_width_never_enlarges(self):
        self.assertEqual(R.fit_width(3456, 2234, 1920), (1920, 1241))
        self.assertEqual(R.fit_width(400, 300, 800), (400, 300))

    def test_hud_density_gives_the_reference_screen(self):
        self.assertEqual(round(1671 * R.HUD_PPU), R.SCREEN[0])
        self.assertEqual(round(1080 * R.HUD_PPU), R.SCREEN[1])

    def test_every_table_entry_is_well_formed(self):
        names = R.picture_names()
        self.assertEqual(len(names), len(set(names)))
        for name, source, crop, width in R.IMAGES:
            self.assertRegex(source, r"^(hud:(DPS|Tank|Healer)|frame:[a-z_]+|class:[a-z]+|lumen_combat)$", name)
            self.assertTrue(crop in (None, "cover") or R.parse_crop(crop), name)
            self.assertGreater(width, 0)
        self.assertEqual({s.split(":")[1] for _, s, _, _ in R.IMAGES if s.startswith("class:")}, set(R.CLASSES))

    @unittest.skipIf(Image is None, "Pillow is not installed")
    def test_compose_row_and_grid_place_every_image(self):
        R.Image = Image
        red, blue = Image.new("RGB", (10, 6), (200, 0, 0)), Image.new("RGB", (10, 6), (0, 0, 200))
        row = R.compose_row([red, blue], 4, (0, 0, 0))
        self.assertEqual(row.size, (24, 6))
        self.assertEqual((row.getpixel((0, 0)), row.getpixel((14, 0)), row.getpixel((11, 0))), ((200, 0, 0), (0, 0, 200), (0, 0, 0)))
        grid = R.compose_grid([red, blue, red], 2, 2, (0, 0, 0))
        self.assertEqual(grid.size, (22, 14))
        self.assertEqual(grid.getpixel((0, 8)), (200, 0, 0))


class ReadmePictures(unittest.TestCase):
    def test_readme_shows_exactly_the_pictures_the_script_writes(self):
        shown = [name for name, _ in readme_pictures()]
        self.assertEqual(sorted(shown), sorted(R.picture_names()))
        self.assertEqual(len(shown), len(set(shown)), "a picture is shown twice")

    def test_every_picture_file_exists_and_nothing_else_is_in_the_folder(self):
        on_disk = {p.stem for p in MEDIA.glob("*") if p.is_file()}
        self.assertEqual(on_disk, set(R.picture_names()))
        self.assertTrue(all(p.suffix == ".png" for p in MEDIA.glob("*")))

    def test_every_picture_is_captioned_as_a_test_render(self):
        text = README.read_text(encoding="utf-8")
        self.assertIn("test render", text.lower())
        for name, caption in readme_pictures():
            self.assertRegex(caption, r"(?i)test render", name + " is not captioned as a test render")

    def test_readme_never_claims_a_picture_is_the_game(self):
        text = README.read_text(encoding="utf-8").lower()
        for phrase in ("screenshot of the game", "in-game screenshot", "seen in game", "proved in game"):
            self.assertNotIn(phrase, text)

    def test_pictures_fit_the_size_budget(self):
        total = sum(p.stat().st_size for p in MEDIA.glob("*.png"))
        self.assertLessEqual(total, R.BUDGET_BYTES)

    def test_hud_pictures_keep_the_reference_aspect(self):
        if Image is None:
            self.skipTest("Pillow is not installed")
        for name in ("hud_dps", "hud_tank", "hud_healer"):
            with Image.open(MEDIA / (name + ".png")) as image:
                self.assertEqual(image.width, R.HUD_WIDTH, name)
                self.assertAlmostEqual(image.height / image.width, R.SCREEN[1] / R.SCREEN[0], delta=0.001)

    def test_the_package_does_not_ship_the_pictures(self):
        ignored = [line.strip()[2:] for line in PKGMETA.read_text(encoding="utf-8").splitlines() if line.strip().startswith("- ")]
        self.assertIn("docs", ignored)
        self.assertIn("README.md", ignored)


if __name__ == "__main__":
    unittest.main()
