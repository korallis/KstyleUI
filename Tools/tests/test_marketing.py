import importlib.util
import hashlib
import json
import os
import re
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
MARKETING = ROOT / "docs" / "media" / "marketing"
MASTER = ROOT / "docs" / "store" / "description.md"
RAW = "https://raw.githubusercontent.com/korallis/KstyleUI/main/"
ICON_RELEASES = "https://github.com/korallis/KstyleUI/releases/latest"  # the one allowed releases link: the icon pack's page, never a file
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
        return ({"banner.jpg"} | {name for name, _, _ in M.HEADERS} | set(M.COMPARE)
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

    def test_published_render_inputs_never_use_the_mockup_plate(self):
        spec = importlib.util.spec_from_file_location("readme_media", ROOT / "Tools/render/readme.py")
        readme = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(readme)
        manifest = json.loads((M.PLATES / "manifest.json").read_text(encoding="utf-8"))
        calls = []
        with patch.object(readme, "run", side_effect=lambda cmd, env=None: calls.append((cmd, env))), \
                patch.dict(os.environ, {"KSTYLEUI_PLATE": "/internal/mockup/clean.png"}):
            readme.render_all(str(M.PLATES), set(readme.picture_names()))
        self.assertEqual(len(calls), len(readme.RENDERS) + len(readme.GALLERIES))
        for cmd, env in calls:
            self.assertIn("--out", cmd, "Fix: every published render needs an explicit PNG output path, including galleries")
            self.assertIn("--backdrop", cmd, "Published pictures must use real scenery, not flat or mockup backdrops")
            backdrop = cmd[cmd.index("--backdrop") + 1]
            self.assertIn(backdrop, [readme.bash_path(M.PLATES / name) for name in manifest],
                          "Fix: pass an explicit real docs/media/plates crop for every published picture")
            self.assertEqual(readme.bash_path(env["KSTYLEUI_PLATE"]), backdrop,
                             "Fix: standins.py must receive the same real plate as the published render")
        for name, entry in manifest.items():
            self.assertEqual(hashlib.sha256((M.PLATES / name).read_bytes()).hexdigest(), entry["sha256"], name)
            self.assertIn(entry["source"], ("game_03.png", "game_09.png"))
        # Every derivative must resolve to either one of those renders or a preserved game capture.
        known = {name + ".jpg" for name in readme.picture_names()} | {p.name for p in M.README_MEDIA.glob("game_*")}
        inputs = [source for _, source, *_ in M.CARDS + M.SHOWCASES + M.GALLERY]
        self.assertTrue(set(inputs) <= known, set(inputs) - known)

    def test_scenery_plate_crops_avoid_recorded_source_ui(self):
        spec = importlib.util.spec_from_file_location("plates", ROOT / "Tools/media/plates.py")
        plates = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(plates)
        manifest = json.loads((M.PLATES / "manifest.json").read_text(encoding="utf-8"))
        for name, entry in manifest.items():
            self.assertEqual(tuple(entry["crop"]), plates.SPECS[name][1],
                             "Fix: regenerate the plate manifest with python Tools/media/plates.py")
            if name == "minimap.png":  # This map stand-in intentionally captures UI, not scenery.
                continue
            left, top, right, bottom = entry["crop"]
            self.assertTrue(0 <= left < right <= 5120 and 0 <= top < bottom <= 1440, name)
            for label, (x1, y1, x2, y2) in plates.UI_REGIONS[entry["source"]].items():
                overlaps = max(left, x1) < min(right, x2) and max(top, y1) < min(bottom, y2)
                self.assertFalse(overlaps,
                                 f"{name} includes {entry['source']} {label}; fix: recrop outside the recorded UI regions and run python Tools/media/plates.py")

    def test_gallery_matches_current_readme_media(self):
        for name, source, width in M.GALLERY:
            path = ROOT / "docs/store/gallery" / name
            if width is None:
                self.assertEqual(path.read_bytes(), (M.README_MEDIA / source).read_bytes(), name)
            if path.suffix == ".gif":
                self.assertLessEqual(path.stat().st_size, 1_000_000, name)

    def test_picture_alt_text_names_the_source(self):
        master = MASTER.read_text(encoding="utf-8")
        for alt, rel in re.findall(r"!\[([^\]]+)\]\(" + re.escape(RAW) + r"([^)]+)\)", master):
            if "/header-" in rel:
                continue
            label = "in-game screenshot" if "/game_" in rel or rel.endswith(("banner.jpg", "card-three-huds.jpg")) else "test render over an in-game screenshot"
            self.assertIn(label, alt.lower(), rel)

    def test_pictured_icon_pack_is_disclosed(self):
        notice = "Icons in this picture are the optional AI-made icon pack, not art shipped in the addon."
        master = MASTER.read_text(encoding="utf-8")
        for match in re.finditer(r"!\[[^\]]+\]\(([^)]+)\)", master):
            name = match[1].rsplit("/", 1)[-1]
            if name.startswith("header-") or name in ("show_frame_setup.jpg", "card-ready-in-minutes.jpg"):
                continue
            window = master[match.end():].split("![", 1)[0]
            caption = re.search(r"\*([^*]+)\*", window)
            self.assertIsNotNone(caption, name)
            self.assertIn(notice, caption[1], name)
        for store in ("curseforge.md", "wago.md"):
            for line in (MASTER.parent / store).read_text(encoding="utf-8").splitlines():
                if line.startswith("| `gallery/") and "06-setup.jpg" not in line:
                    self.assertIn(notice, line, store + ": " + line)


class MasterDescription(unittest.TestCase):
    def test_published_prose_has_no_windows_mojibake(self):
        for path in (MASTER, ROOT / "README.md", ROOT / "Tools/render/README.md",
                     ROOT / "docs/store/curseforge.md", ROOT / "docs/store/wago.md"):
            text = path.read_text(encoding="utf-8")
            for marker in ("\u00c3\u2014", "\u00e2\u20ac", "\u00c2\u00a0"):
                self.assertNotIn(marker, text, str(path) + ": read and write these docs with encoding='utf-8', not Windows cp1252")

    def test_optional_icon_pack_note_follows_install_without_a_download_url(self):
        paragraph = ("An optional icon pack repaints ability and item icons everywhere, including buffs. "
                     "The icons were made with AI image tools. The pack is not an addon and is not part of "
                     "this download: it is available from this project's GitHub page. Quit the game, copy "
                     "the Icons folder from inside its Interface folder into your game's _forever_/Interface "
                     "folder, then start the game again. The KstyleUI Icons section above has the Windows "
                     "and Mac steps.")
        master = MASTER.read_text(encoding="utf-8")
        self.assertIn(paragraph, master)
        self.assertLess(master.index("4. Type `/kstyle`"), master.index(paragraph))
        self.assertLess(master.index(paragraph), master.index("## FAQ"))
        self.assertNotRegex(paragraph, r"https?://")

    def test_curseforge_and_wago_blocks_equal_the_master(self):
        master = MASTER.read_text(encoding="utf-8").strip("\n")
        for rel in ("docs/store/curseforge.md", "docs/store/wago.md"):
            block = fenced_description(ROOT / rel)
            self.assertEqual(block, master, rel)
            for url in re.findall(r"https?://[^\s)]+", block):
                self.assertTrue("/releases" not in url or url == ICON_RELEASES, url)
                self.assertFalse(url.split("?")[0].lower().endswith(".zip"), url)

    def test_master_has_no_download_link_and_does_not_repeat_the_summary(self):
        master = MASTER.read_text(encoding="utf-8")
        for url in re.findall(r"https?://[^\s)]+", master):
            self.assertTrue("/releases" not in url or url == ICON_RELEASES, url)
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
