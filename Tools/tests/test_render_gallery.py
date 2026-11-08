"""Tests for Tools/render/gallery.py: the crop boxes, the mockup reference crops and the manifest."""

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "render" / "gallery.py"

try:
    from PIL import Image
except ImportError:  # pragma: no cover - depends on the machine
    Image = None


def load():
    spec = importlib.util.spec_from_file_location("gallery", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class CropBoxTest(unittest.TestCase):
    def setUp(self):
        self.gallery = load()

    def test_crop_box_pads_the_rect_and_scales_by_the_density(self):
        box = self.gallery.crop_box([100, 50, 200, 40], 10, 2.0, 1000, 1000)
        self.assertEqual(box, (180, 80, 620, 200))

    def test_crop_box_stays_inside_the_canvas(self):
        box = self.gallery.crop_box([0, 0, 100, 100], 20, 1.0, 90, 60)
        self.assertEqual(box, (0, 0, 90, 60))

    def test_every_reference_the_scenes_may_name_has_a_mockup_box(self):
        lua = (SCRIPT.parent / "scenes" / "_gallery.lua").read_text(encoding="utf-8")
        start = lua.index("Gallery.REFERENCES = {")
        end = lua.index("}", start)
        keys = set()
        for line in lua[start:end].splitlines()[1:]:
            for part in line.split(","):
                part = part.strip()
                if "=" in part:
                    keys.add(part.split("=")[0].strip())
        self.assertTrue(keys)
        self.assertEqual(keys, set(self.gallery.REFERENCE_BOXES))
        for key, (left, top, right, bottom) in self.gallery.REFERENCE_BOXES.items():
            self.assertLess(left, right, key)
            self.assertLess(top, bottom, key)
            self.assertLessEqual(right, 2574, key)
            self.assertLessEqual(bottom, 1456, key)


@unittest.skipUnless(Image, "Pillow is not installed")
class GalleryTest(unittest.TestCase):
    def setUp(self):
        self.gallery = load()
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.renders = self.root / "renders"
        self.renders.mkdir()
        self.gallery.RENDERS = str(self.renders)
        self.gallery.SCENES = str(self.root / "scenes")
        (self.root / "scenes").mkdir()
        self.mockup = self.root / "mockup.png"
        Image.new("RGB", (2574, 1456), (10, 20, 30)).save(self.mockup)

    def tearDown(self):
        self._tmp.cleanup()

    def scene(self, name, frames, ppu=2.0):
        canvas = Image.new("RGB", (int(1671 * ppu), int(1080 * ppu)), (0, 0, 0))
        canvas.paste((200, 100, 50), (200, 100, 400, 180))
        canvas.save(self.renders / (name + ".png"))
        (self.renders / (name + ".json")).write_text(json.dumps({"frames": frames, "items": [], "log": []}), encoding="utf-8")
        (self.root / "scenes" / (name + ".lua")).write_text("return nil\n", encoding="utf-8")

    def frame(self, name, reference="chat", **extra):
        spec = {"name": name, "title": name.title(), "caption": "what it is", "grade": "window", "reference": reference,
                "match": "fill and edge as the mockup", "pad": 10, "rect": [100, 50, 100, 40]}
        spec.update(extra)
        return spec

    def test_references_are_cut_from_the_mockup_at_the_render_density(self):
        refs = self.gallery.references(str(self.mockup), str(self.root / "refs"), 1.426, {"chat", "xp"})
        self.assertEqual(sorted(refs), ["chat", "xp"])
        left, top, right, bottom = self.gallery.REFERENCE_BOXES["chat"]
        image = Image.open(refs["chat"])
        self.assertEqual(image.width, round((right - left) * 1.426 / 1.348))
        self.assertEqual(image.height, round((bottom - top) * 1.426 / 1.348))

    def test_main_crops_each_frame_and_writes_the_manifest(self):
        self.scene("gallery_a", [self.frame("a_one"), self.frame("a_two", reference="player", rect=[0, 0, 50, 50], pad=0)])
        out = self.root / "frames"
        code = self.gallery.main(["--no-render", "--out", str(out), "--refs", str(self.root / "refs"), "--mockup", str(self.mockup), "--ppu", "2.0"])
        self.assertEqual(code, 0)
        manifest = json.loads((out / "kstyle_manifest.json").read_text(encoding="utf-8"))
        self.assertEqual([entry["file"] for entry in manifest], ["kstyle_a_one.png", "kstyle_a_two.png"])
        one = manifest[0]
        self.assertEqual((one["title"], one["grade"], one["reference"], one["scene"]), ("A_One", "window", "../refs/ref_chat.png", "gallery_a"))
        self.assertEqual(one["match"], "fill and edge as the mockup")
        self.assertTrue((out / one["reference"]).resolve().exists())
        crop = Image.open(out / "kstyle_a_one.png")
        self.assertEqual(crop.size, (240, 120))
        self.assertEqual(crop.getpixel((20, 20)), (200, 100, 50))
        self.assertEqual(Image.open(out / "kstyle_a_two.png").size, (100, 100))

    def test_main_runs_every_gallery_scene_by_default(self):
        self.scene("gallery_b", [self.frame("b_one")])
        self.scene("gallery_a", [self.frame("a_one")])
        out = self.root / "frames"
        self.gallery.main(["--no-render", "--out", str(out), "--refs", str(self.root / "refs"), "--mockup", str(self.mockup)])
        manifest = json.loads((out / "kstyle_manifest.json").read_text(encoding="utf-8"))
        self.assertEqual([entry["scene"] for entry in manifest], ["gallery_a", "gallery_b"])

    def test_named_scenes_replace_their_entries_in_an_existing_manifest(self):
        self.scene("gallery_a", [self.frame("a_one")])
        self.scene("gallery_b", [self.frame("b_one")])
        out = self.root / "frames"
        common = ["--no-render", "--out", str(out), "--refs", str(self.root / "refs"), "--mockup", str(self.mockup)]
        self.gallery.main(common)
        self.scene("gallery_b", [self.frame("b_two")])
        self.gallery.main(["gallery_b", *common])
        manifest = json.loads((out / "kstyle_manifest.json").read_text(encoding="utf-8"))
        self.assertEqual([entry["file"] for entry in manifest], ["kstyle_a_one.png", "kstyle_b_two.png"])

    def test_a_scene_without_frames_fails(self):
        self.scene("gallery_empty", [])
        with self.assertRaises(SystemExit):
            self.gallery.main(["--no-render", "gallery_empty", "--out", str(self.root / "frames"), "--refs", str(self.root / "refs"), "--mockup", str(self.mockup)])


if __name__ == "__main__":
    unittest.main()
