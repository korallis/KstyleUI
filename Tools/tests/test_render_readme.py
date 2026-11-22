import importlib.util
import re
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

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
    """The picture names README.md shows, in order, with the caption each one is read under.

    README.md is generated from docs/store/description.md, where each picture
    is a markdown image followed by an italic caption line.
    """
    text = README.read_text(encoding="utf-8")
    found = []
    for match in re.finditer(r"!\[[^\]]*\]\([^)]*(?:/readme/|/marketing/show_)([a-z0-9_]+)\.(?:jpg|gif)\)", text):
        after = text[match.end():]
        window = after[: after.find("![") if "![" in after else len(after)]
        caption = re.search(r"\*([^*]+)\*", window)
        found.append((match.group(1), caption.group(1) if caption else ""))
    return found


class Helpers(unittest.TestCase):
    def test_rerender_preserves_in_game_media(self):
        with TemporaryDirectory() as work:
            media = Path(work)
            for name in ("game_medallions_hero.jpg", "game_medallions_cast.gif"):
                (media / name).write_bytes(b"in-game")
            with patch.multiple(R, OUT=work), \
                    patch.object(R, "pillow", return_value=True), \
                    patch.object(R, "cut_all"), patch.object(R, "finish"), \
                    patch.object(R, "total_bytes", return_value=0):
                self.assertEqual(R.main(["--no-render"]), 0)
            self.assertEqual(sorted(p.name for p in media.iterdir()),
                             ["game_medallions_cast.gif", "game_medallions_hero.jpg"],
                             "readme.py must preserve game_ media when rerendering")

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
    def test_readme_shows_every_render_once(self):
        shown = [name for name, _ in readme_pictures()]
        self.assertEqual(sorted(name for name in shown if not name.startswith("game_")), sorted(R.picture_names()))
        self.assertEqual(len(shown), len(set(shown)), "a picture is shown twice")

    def test_every_picture_file_exists_and_nothing_else_is_in_the_folder(self):
        # The in-game hero is the banner's and the store gallery's source (Tools/media/marketing.py).
        on_disk = {p.stem for p in MEDIA.glob("*") if p.is_file()}
        self.assertEqual(on_disk, {name for name, _ in readme_pictures()} | {"game_medallions_hero"})
        self.assertTrue(all(p.suffix in (".jpg", ".gif") for p in MEDIA.glob("*")))

    def test_medallions_has_no_generated_sources(self):
        self.assertFalse(any("medallions" in name for name in R.picture_names()))
        self.assertFalse(any("medallions" in name for name in R.RENDERS))

    def test_pictures_fit_the_size_budget(self):
        self.assertLessEqual(R.total_bytes(), R.BUDGET_BYTES)
        for path in MEDIA.glob("game_*"):
            limit = 1150000 if path.suffix == ".gif" else 1500000 if path.stem.endswith("_hero") else 600000
            self.assertLessEqual(path.stat().st_size, limit, str(path))

    def test_in_game_hero_keeps_its_ultrawide_aspect(self):
        if Image is None:
            self.skipTest("Pillow is not installed")
        with Image.open(MEDIA / "game_medallions_hero.jpg") as image:
            self.assertAlmostEqual(image.width / image.height, 32 / 9, delta=0.002)

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
