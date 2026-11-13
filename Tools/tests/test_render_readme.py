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
    for match in re.finditer(r'<img src="[^"]*/readme/([a-z0-9_]+)\.jpg"[^>]*>', text):
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
    def test_parse_crop_reads_width_height_and_offset(self):
        self.assertEqual(R.parse_crop("620x1160+2800+20"), (2800, 20, 3420, 1180))

    def test_fit_width_never_enlarges(self):
        self.assertEqual(R.fit_width(3456, 2234, 1920), (1920, 1241))
        self.assertEqual(R.fit_width(400, 300, 800), (400, 300))

    def test_every_table_entry_is_well_formed(self):
        names = R.picture_names()
        self.assertEqual(len(names), len(set(names)))
        for name, source, crop, width in R.IMAGES:
            self.assertRegex(source, r"^(render:[a-z0-9_]+|frame:[a-z_]+)$", name)
            if source.startswith("render:"):
                self.assertIn(source.split(":")[1], R.RENDERS, name)
            self.assertTrue(crop is None or R.parse_crop(crop), name)
            self.assertGreater(width, 0)

    def test_hud_renders_are_in_combat_at_the_shipped_sizes(self):
        for key, (scene, ppu, env, guard) in R.RENDERS.items():
            if scene != "hud_reference":
                continue
            self.assertEqual(guard, "--strict", key)
            self.assertEqual(env["RENDER_METER_SECRET"], "1", key)
            width, height = (int(n) for n in env["RENDER_SCREEN"].split("x"))
            self.assertAlmostEqual(ppu, height / 1080 * (2 if key.endswith("_2x") or key == "meter_party" else 1), msg=key)
            self.assertEqual(env["RENDER_SIZE"], "0.9375" if height == 1080 else "auto", key)



class ReadmePictures(unittest.TestCase):
    def test_readme_shows_exactly_the_pictures_the_script_writes(self):
        shown = [name for name, _ in readme_pictures()]
        self.assertEqual(sorted(shown), sorted(R.picture_names()))
        self.assertEqual(len(shown), len(set(shown)), "a picture is shown twice")

    def test_every_picture_file_exists_and_nothing_else_is_in_the_folder(self):
        on_disk = {p.stem for p in MEDIA.glob("*") if p.is_file()}
        self.assertEqual(on_disk, set(R.picture_names()))
        self.assertTrue(all(p.suffix == ".jpg" for p in MEDIA.glob("*")))

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
        total = sum(p.stat().st_size for p in MEDIA.glob("*.jpg"))
        self.assertLessEqual(total, R.BUDGET_BYTES)

    def test_whole_screen_pictures_keep_their_screen_aspect(self):
        if Image is None:
            self.skipTest("Pillow is not installed")
        for name, source, crop, width in R.IMAGES:
            if crop is not None or not source.startswith("render:"):
                continue
            screen = R.RENDERS[source.split(":")[1]][2]["RENDER_SCREEN"]
            screen_w, screen_h = (int(n) for n in screen.split("x"))
            with Image.open(MEDIA / (name + ".jpg")) as image:
                self.assertEqual(image.width, width, name)
                self.assertAlmostEqual(image.height / image.width, screen_h / screen_w, delta=0.002)

    def test_the_package_does_not_ship_the_pictures(self):
        ignored = [line.strip()[2:] for line in PKGMETA.read_text(encoding="utf-8").splitlines() if line.strip().startswith("- ")]
        self.assertIn("docs", ignored)
        self.assertIn("README.md", ignored)


if __name__ == "__main__":
    unittest.main()
