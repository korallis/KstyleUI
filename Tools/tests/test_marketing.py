import importlib.util
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MARKETING = ROOT / "docs" / "media" / "marketing"
MASTER = ROOT / "docs" / "store" / "description.md"
RAW = "https://raw.githubusercontent.com/korallis/KstyleUI/main/"
SUMMARY = ("A complete, pixel-perfect interface for World of Warcraft: Forever "
           "\u2014 one dark forged style, three HUDs, set up in one window.")

try:
    from PIL import Image
except ImportError:  # pragma: no cover - depends on the machine
    Image = None


def load_marketing():
    spec = importlib.util.spec_from_file_location(
        "marketing", ROOT / "Tools" / "media" / "marketing.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


M = load_marketing()


def fenced_description(path):
    text = path.read_text(encoding="utf-8")
    start = text.index("```markdown\n") + len("```markdown\n")
    end = text.index("\n```", start)
    return text[start:end]


class MarketingImages(unittest.TestCase):
    def expected(self):
        return ({"banner.jpg"} | {name for name, _, _ in M.HEADERS}
                | {name for name, *_ in M.CARDS} | {name for name, _ in M.SHOWCASES})

    def test_folder_holds_exactly_the_script_outputs(self):
        self.assertEqual({p.name for p in MARKETING.glob("*") if p.is_file()}, self.expected())

    def test_images_are_web_light_and_wide_enough(self):
        for name in self.expected():
            path = MARKETING / name
            self.assertLessEqual(path.stat().st_size, 400 * 1024, name)
            if Image is not None:
                with Image.open(path) as image:
                    self.assertEqual(image.format, "JPEG", name)
                    self.assertTrue(1600 <= image.width <= 2560, f"{name} is {image.width}px wide")

    def test_every_referenced_image_exists(self):
        master = MASTER.read_text(encoding="utf-8")
        for rel in re.findall(r"!\[[^\]]*\]\(" + re.escape(RAW) + r"([^)]+)\)", master):
            self.assertTrue((ROOT / rel).is_file(), rel + " is referenced but missing")

    def test_every_marketing_image_is_referenced(self):
        master = MASTER.read_text(encoding="utf-8")
        for name in self.expected():
            rel = (MARKETING / name).relative_to(ROOT).as_posix()
            self.assertIn(rel, master, name)


class MasterDescription(unittest.TestCase):
    def test_curseforge_and_wago_blocks_equal_the_master(self):
        master = MASTER.read_text(encoding="utf-8").strip("\n")
        for rel in ("docs/store/curseforge.md", "docs/store/wago.md"):
            block = fenced_description(ROOT / rel)
            self.assertEqual(block, master, rel)
            self.assertNotIn("releases", block, rel)
            for url in re.findall(r"https?://[^\s)]+", block):
                self.assertNotIn("/releases", url, url)
                self.assertFalse(url.split("?")[0].lower().endswith(".zip"), url)

    def test_master_has_no_download_link_and_does_not_repeat_the_summary(self):
        master = MASTER.read_text(encoding="utf-8")
        self.assertNotIn("releases", master)
        for url in re.findall(r"https?://[^\s)]+", master):
            self.assertNotIn("/releases", url, url)
            self.assertFalse(url.split("?")[0].lower().endswith(".zip"), url)
        self.assertNotIn(SUMMARY, master)
        first_text = next(line for line in master.splitlines() if line and not line.startswith("!["))
        self.assertNotEqual(first_text.strip("* "), SUMMARY)

    def test_readme_is_the_master_plus_github_extras(self):
        master = MASTER.read_text(encoding="utf-8").strip("\n")
        expected = M.README_HEADER + master.replace(
            "\n## FAQ\n", M.ICON_NOTE + "\n## FAQ\n", 1) + "\n"
        self.assertEqual((ROOT / "README.md").read_text(encoding="utf-8"), expected)

    def test_links_and_credits_come_last(self):
        master = MASTER.read_text(encoding="utf-8")
        self.assertLess(master.index("## Install"), master.index("## FAQ"))
        self.assertLess(master.index("## FAQ"), master.index("## Links"))
        self.assertLess(master.index("## Links"), master.index("## Credits"))


if __name__ == "__main__":
    unittest.main()
