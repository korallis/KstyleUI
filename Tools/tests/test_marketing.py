import importlib.util
import hashlib
import json
import os
import re
import unittest
from pathlib import Path
from subprocess import CompletedProcess
from tempfile import TemporaryDirectory
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
MARKETING = ROOT / "docs" / "media" / "marketing"
MASTER = ROOT / "docs" / "store" / "description.md"
RAW = "https://raw.githubusercontent.com/korallis/KstyleUI/main/"
DISCORD = "https://discord.gg/A5qqGZEXyN"
ICON_RELEASES = "https://github.com/korallis/KstyleUI/releases/latest"  # the one allowed releases link: the icon pack's page, never a file
GIF_CAP = 1_500_000  # the brief's ceiling; CurseForge refuses big images
SUMMARY = ("One dark forged UI for World of Warcraft: Forever. Pick Medallions or Frames for your HUD, get a class crest "
           "that lights up as you fight, and set it all up in one window.")

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
        return {"banner.jpg"} | {name for name, _ in M.SHOWCASES} | set(M.CLIPS)

    def test_folder_holds_exactly_the_script_outputs(self):
        self.assertEqual({p.name for p in MARKETING.glob("*") if p.is_file()}, self.expected())

    def test_clips_are_small_smooth_and_one_width(self):
        for name in M.CLIPS:
            path = MARKETING / name
            self.assertLessEqual(path.stat().st_size, GIF_CAP, name + ": fix: trim its shots in CLIPS or narrow its box")
            if Image is not None:
                with Image.open(path) as image:
                    self.assertEqual(image.width, M.CLIP_WIDTH + 32, name)
                    for frame in range(image.n_frames):
                        image.seek(frame)
                        self.assertGreaterEqual(image.info["duration"], M.FRAME_MS, name)

    def test_clip_frames_render_strict_over_a_real_plate(self):
        with TemporaryDirectory() as work, \
                patch.object(M.subprocess, "run", return_value=CompletedProcess([], 3, "", "")) as run:
            with self.assertRaises(SystemExit):
                M.clip_frame(Path(work), "hud_rogue_mac", {}, M.CREST, False)
        cmd, env = run.call_args.args[0], run.call_args.kwargs["env"]
        self.assertIn("--strict", cmd)
        backdrop = cmd[cmd.index("--backdrop") + 1]
        self.assertEqual(Path(backdrop), M.PLATES / "forest-1080.jpg",
                         "Fix: clips render over a real docs/media/plates crop, never the mockup plate")
        self.assertEqual(env["KSTYLEUI_PLATE"], backdrop)

    def test_images_are_web_light_and_wide_enough(self):
        for name in self.expected() - set(M.CLIPS):
            path = MARKETING / name
            self.assertLessEqual(path.stat().st_size, 512 * 1024, name)
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
        self.assertEqual(len(calls), len(readme.RENDERS))
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
        known = ({"readme/" + name + ".jpg" for name in readme.picture_names()}
                 | {"readme/" + p.name for p in M.README_MEDIA.glob("game_*")} | {"marketing/" + name for name in M.CLIPS})
        inputs = {"readme/" + source for _, source in M.SHOWCASES} | {source for _, source, _ in M.GALLERY}
        self.assertTrue(inputs <= known, inputs - known)

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
        self.assertEqual({p.name for p in (ROOT / "docs/store/gallery").glob("*.*")}, {name for name, _, _ in M.GALLERY})
        for name, source, width in M.GALLERY:
            path = ROOT / "docs/store/gallery" / name
            if width is None:
                self.assertEqual(path.read_bytes(), (M.README_MEDIA.parent / source).read_bytes(), name)
            if path.suffix == ".gif":
                self.assertLessEqual(path.stat().st_size, GIF_CAP, name)

    def test_picture_alt_text_names_the_source(self):
        master = MASTER.read_text(encoding="utf-8")
        for alt, rel in re.findall(r"!\[([^\]]+)\]\(" + re.escape(RAW) + r"([^)]+)\)", master):
            label = "in-game screenshot" if "/game_" in rel or rel.endswith("banner.jpg") else "test render over an in-game screenshot"
            self.assertIn(label, alt.lower(), rel)

    def test_pictured_icon_pack_is_disclosed(self):
        notice = "Icons in {} are the optional AI-made icon pack, not art shipped in the addon."
        master = MASTER.read_text(encoding="utf-8")
        pictures = master.split("![")
        self.assertIn(notice.format("this picture"), pictures[1], "Fix: caption the banner with the notice")
        self.assertIn(notice.format("these pictures"), pictures[1], "Fix: put the notice in the note above the first clip")
        for store in ("curseforge.md", "wago.md"):
            for line in (MASTER.parent / store).read_text(encoding="utf-8").splitlines():
                if line.startswith("| `gallery/"):
                    self.assertIn(notice.format("this picture"), line, store + ": " + line)


class MasterDescription(unittest.TestCase):
    def test_discord_invite_leads_the_page(self):
        top = MASTER.read_text(encoding="utf-8").split("\n## ", 1)[0]
        self.assertIn(DISCORD, top, "Fix: put the Discord invite " + DISCORD + " right under the banner in "
                      "docs/store/description.md, before the first ## heading, then run marketing.py --pages")

    def test_published_prose_has_no_windows_mojibake(self):
        for path in (MASTER, ROOT / "README.md", ROOT / "Tools/render/README.md",
                     ROOT / "docs/store/curseforge.md", ROOT / "docs/store/wago.md"):
            text = path.read_text(encoding="utf-8")
            for marker in ("\u00c3\u2014", "\u00e2\u20ac", "\u00c2\u00a0"):
                self.assertNotIn(marker, text, str(path) + ": read and write these docs with encoding='utf-8', not Windows cp1252")

    def test_icon_pack_line_sits_in_install(self):
        master = MASTER.read_text(encoding="utf-8")
        self.assertLess(master.index("## Install"), master.index(ICON_RELEASES))
        self.assertLess(master.index(ICON_RELEASES), master.index("## Links"))

    def test_page_stays_short_and_in_the_owners_voice(self):
        master = MASTER.read_text(encoding="utf-8")
        prose = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", master)
        self.assertLessEqual(len(prose.split()), 800, "Fix: the owner asked for a short page; link GitHub for detail")
        self.assertLessEqual(master.count("!["), 12, "Fix: one picture or clip per feature")
        for tell in ("\u2014", "Elevate", "Seamless", "Unleash", "Whether you"):
            self.assertNotIn(tell, master, "Fix: write it the way the owner talks, without " + repr(tell))

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
        expected = M.README_HEADER + master + "\n" + M.README_FOOTER
        self.assertEqual((ROOT / "README.md").read_text(encoding="utf-8"), expected)

    def test_links_and_credits_come_last(self):
        master = MASTER.read_text(encoding="utf-8")
        self.assertLess(master.index("## Install"), master.index("## Links"))
        self.assertLess(master.index("## Links"), master.index("## Credits"))


if __name__ == "__main__":
    unittest.main()
