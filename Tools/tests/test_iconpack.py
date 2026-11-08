"""Tests for the loose-file icon pack in Tools/icons/iconset.py: the listfile names, the TGA format, pack and install.

The pack writes the way AcidWeb's Clean Icons ships (checked against its 12.1.5.70688-V5-1 archive on
2026-11-08): one flat Interface/Icons folder of 128 by 128 TGA files, 32 bits per pixel with an 8-bit alpha
channel, uncompressed, bottom-left origin, a TGA 2.0 footer, each named with Blizzard's mixed-case icon name.
No Pillow: the PNG decoder is injected.
"""

import hashlib
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "icons"))

import iconset  # noqa: E402

LISTFILE = (
    "1;interface/cinematics/logo_800.avi\n"
    "132089;Interface/ICONS/Ability_Ambush.blp\n"
    "135812;Interface/ICONS/Spell_Fire_FlameBolt.blp\n"
    "5834819;Interface/ICONS/INV_Store_Mount.blp\n"
    "99;Interface/Icons/Ability_Rogue_Sprint.BLP\n"
    "100;interface/addons/notanicon/icons/foo.blp\n"
)


def decode(width, height, colour):
    """A PNG decoder stand-in: every pixel is colour, whatever the file holds."""
    def read(path):
        return width, height, bytes(colour) * (width * height)
    return read


def write_pngs(folder, ids):
    folder.mkdir(parents=True, exist_ok=True)
    for icon in ids:
        (folder / f"{icon}.png").write_bytes(b"\x89PNG stand-in")


class IconNamesTest(unittest.TestCase):
    def test_reads_the_icon_name_of_each_file_id_and_skips_other_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "names.csv"
            path.write_text(LISTFILE)
            names, encrypted = iconset.load_icon_names(path)
        self.assertEqual(names, {132089: "Ability_Ambush", 135812: "Spell_Fire_FlameBolt", 5834819: "INV_Store_Mount", 99: "Ability_Rogue_Sprint"})
        self.assertEqual(encrypted, set())

    def test_a_third_field_marks_an_encrypted_icon(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "names.csv"
            path.write_text("5834819;Interface/ICONS/INV_Store_Mount.blp;encrypted\n132089;Interface/ICONS/Ability_Ambush.blp\n")
            names, encrypted = iconset.load_icon_names(path)
        self.assertEqual(names, {5834819: "INV_Store_Mount", 132089: "Ability_Ambush"})
        self.assertEqual(encrypted, {5834819})

    def test_write_keeps_the_listfile_rows_of_the_given_ids_and_marks_zero_filled_blps_encrypted(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / "listfile.csv").write_text(LISTFILE)
            blizzard = tmp / "blizzard"
            blizzard.mkdir()
            (blizzard / "5834819.blp").write_bytes(bytes(3916))
            (blizzard / "132089.blp").write_bytes(b"BLP2" + bytes(100))
            out = tmp / "icon_names.csv"
            summary = iconset.write_icon_names(tmp / "listfile.csv", [132089, 5834819, 424242], out, blizzard_dir=blizzard)
            text = out.read_text()
        self.assertEqual(text, "132089;Interface/ICONS/Ability_Ambush.blp\n5834819;Interface/ICONS/INV_Store_Mount.blp;encrypted\n")
        self.assertEqual(summary, {"named": 2, "encrypted": 1, "unnamed": [424242]})

    def test_the_committed_names_file_names_every_set_b_icon(self):
        names, _ = iconset.load_icon_names(iconset.ICON_NAMES)
        icons = sorted(int(p.stem) for p in (iconset.REPO / iconset.SETS["B"].folder / "Icons").glob("*.png"))
        self.assertTrue(icons, "set B has packaged icons")
        missing = [icon for icon in icons if icon not in names]
        self.assertEqual(missing, [], "every packaged icon has a listfile name")


class TgaTest(unittest.TestCase):
    def test_writes_a_32_bit_uncompressed_bottom_left_tga_with_a_footer_as_clean_icons_does(self):
        rgb = bytes([10, 20, 30, 40, 50, 60]) + bytes([70, 80, 90, 100, 110, 120])  # 2 by 2, two rows
        data = iconset.tga_bytes(2, 2, rgb)
        header = struct.unpack("<BBBHHBHHHHBB", data[:18])
        self.assertEqual(header, (0, 0, 2, 0, 0, 0, 0, 0, 2, 2, 32, 8))
        pixels = data[18:18 + 16]
        # Bottom-left origin: the last row of the image comes first, each pixel as BGRA with alpha 255.
        self.assertEqual(pixels[:8], bytes([90, 80, 70, 255, 120, 110, 100, 255]))
        self.assertEqual(pixels[8:], bytes([30, 20, 10, 255, 60, 50, 40, 255]))
        self.assertEqual(data[18 + 16:], bytes(8) + b"TRUEVISION-XFILE.\x00")
        self.assertEqual(len(data), 18 + 16 + 26)

    def test_the_header_reader_describes_the_file(self):
        data = iconset.tga_bytes(2, 2, bytes(12))
        self.assertEqual(iconset.tga_header(data), {"type": 2, "width": 2, "height": 2, "bpp": 32, "alpha": 8, "topLeft": False})
        self.assertIsNone(iconset.tga_header(b"\x89PNG"))

    def test_refuses_pixel_data_of_the_wrong_length(self):
        with self.assertRaises(ValueError):
            iconset.tga_bytes(2, 2, bytes(11))


class PackTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.icons = root / "setB" / "Icons"
        write_pngs(self.icons, [132089, 135812, 5834819, 424242])
        (self.icons / "notes.txt").write_text("not an icon")
        self.out = root / "pack"
        self.names = {132089: "Ability_Ambush", 135812: "Spell_Fire_FlameBolt", 5834819: "INV_Store_Mount"}
        self.encrypted = {5834819}

    def tearDown(self):
        self.tmp.cleanup()

    def pack(self, **kwargs):
        return iconset.pack(self.icons, self.out, self.names, self.encrypted, decode=decode(128, 128, (200, 100, 50)),
                            log=lambda message: None, **kwargs)

    def test_writes_one_tga_per_named_icon_under_interface_icons(self):
        summary = self.pack()
        folder = self.out / "Interface" / "Icons"
        self.assertEqual(sorted(p.name for p in folder.iterdir()), ["Ability_Ambush.tga", "Spell_Fire_FlameBolt.tga"])
        data = (folder / "Ability_Ambush.tga").read_bytes()
        self.assertEqual(iconset.tga_header(data), {"type": 2, "width": 128, "height": 128, "bpp": 32, "alpha": 8, "topLeft": False})
        self.assertEqual(data[18:22], bytes([50, 100, 200, 255]))
        self.assertEqual(len(data), 18 + 128 * 128 * 4 + 26)
        self.assertEqual(summary["written"], [132089, 135812])

    def test_skips_and_reports_an_icon_without_a_listfile_name_or_an_encrypted_one(self):
        summary = self.pack()
        self.assertEqual(summary["skipped"], {424242: "no listfile name", 5834819: "encrypted"})

    def test_a_png_that_is_not_128_by_128_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "132089.png is 64x64"):
            iconset.pack(self.icons, self.out, self.names, self.encrypted, decode=decode(64, 64, (0, 0, 0)), log=lambda m: None)

    def test_removes_a_stale_tga_the_pack_no_longer_makes_and_leaves_other_files(self):
        folder = self.out / "Interface" / "Icons"
        folder.mkdir(parents=True)
        (folder / "Old_Icon.tga").write_bytes(b"stale")
        (folder / "README.txt").write_text("keep")
        self.pack()
        self.assertFalse((folder / "Old_Icon.tga").exists())
        self.assertTrue((folder / "README.txt").exists())


class InstallTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.pack = root / "pack" / "Interface" / "Icons"
        self.pack.mkdir(parents=True)
        for name in ("Ability_Ambush", "Spell_Fire_FlameBolt"):
            (self.pack / f"{name}.tga").write_bytes(iconset.tga_bytes(1, 1, bytes([1, 2, 3])))
        self.wow = root / "_forever_"
        (self.wow / "Interface" / "AddOns").mkdir(parents=True)
        (self.wow / ".flavor.info").write_text("Product Flavor!STRING:0\nwowf\n")
        self.icons = self.wow / "Interface" / "Icons"
        self.lines = []

    def tearDown(self):
        self.tmp.cleanup()

    def install(self, **kwargs):
        return iconset.install(self.pack.parents[1], self.wow, log=self.lines.append, **kwargs)

    def test_refuses_a_folder_that_is_not_a_wow_flavour_folder(self):
        other = Path(self.tmp.name) / "Documents"
        other.mkdir()
        with self.assertRaisesRegex(SystemExit, "not a World of Warcraft flavour folder"):
            iconset.install(self.pack.parents[1], other, log=self.lines.append)
        self.assertFalse((other / "Interface").exists())

    def test_copies_the_pack_into_interface_icons_and_writes_a_manifest(self):
        summary = self.install()
        self.assertEqual(sorted(p.name for p in self.icons.iterdir()),
                         ["Ability_Ambush.tga", iconset.MANIFEST, "Spell_Fire_FlameBolt.tga"])
        self.assertEqual((self.icons / "Ability_Ambush.tga").read_bytes(), (self.pack / "Ability_Ambush.tga").read_bytes())
        manifest = json.loads((self.icons / iconset.MANIFEST).read_text())
        digest = hashlib.sha256((self.pack / "Ability_Ambush.tga").read_bytes()).hexdigest()
        self.assertEqual(manifest["files"]["Ability_Ambush.tga"], digest)
        self.assertEqual(set(manifest["files"]), {"Ability_Ambush.tga", "Spell_Fire_FlameBolt.tga"})
        self.assertEqual((summary["copied"], summary["unchanged"], summary["replaced"]), (2, 0, 0))
        self.assertEqual(sorted(p.name for p in (self.wow / "Interface").iterdir()), ["AddOns", "Icons"])

    def test_a_second_install_copies_nothing(self):
        self.install()
        summary = self.install()
        self.assertEqual((summary["copied"], summary["unchanged"], summary["replaced"]), (0, 2, 0))

    def test_a_file_of_another_pack_is_replaced_and_counted(self):
        self.icons.mkdir()
        (self.icons / "Ability_Ambush.tga").write_bytes(b"clean icons")
        summary = self.install()
        self.assertEqual((summary["copied"], summary["unchanged"], summary["replaced"]), (2, 0, 1))
        self.assertEqual((self.icons / "Ability_Ambush.tga").read_bytes(), (self.pack / "Ability_Ambush.tga").read_bytes())

    def test_a_dry_run_changes_nothing_and_says_what_it_would_do(self):
        summary = self.install(dry_run=True)
        self.assertFalse(self.icons.exists())
        self.assertEqual((summary["copied"], summary["unchanged"], summary["replaced"]), (2, 0, 0))
        self.assertTrue(any("dry run" in line for line in self.lines))

    def test_uninstall_removes_only_the_files_the_manifest_lists_and_keeps_a_changed_one(self):
        self.install()
        (self.icons / "Spell_Fire_FlameBolt.tga").write_bytes(b"edited by the player")
        (self.icons / "Other_Pack.tga").write_bytes(b"not ours")
        summary = self.install(uninstall=True)
        self.assertEqual(sorted(p.name for p in self.icons.iterdir()), ["Other_Pack.tga", "Spell_Fire_FlameBolt.tga"])
        self.assertEqual((summary["removed"], summary["kept"]), (1, 1))
        self.assertTrue((self.wow / "Interface" / "AddOns").exists())

    def test_uninstall_refuses_a_manifest_that_names_a_file_outside_the_icons_folder(self):
        self.install()
        outside = self.wow / "Interface" / "AddOns" / "Other.lua"
        outside.write_bytes(b"addon")
        manifest = self.icons / iconset.MANIFEST
        data = json.loads(manifest.read_text())
        for bad in ("../AddOns/Other.lua", str(outside), "sub/Ability_Ambush.tga", "Other.lua"):
            data["files"][bad] = hashlib.sha256(b"addon").hexdigest()
        manifest.write_text(json.dumps(data))
        with self.assertRaisesRegex(SystemExit, "manifest"):
            self.install(uninstall=True)
        self.assertTrue(outside.exists())
        self.assertTrue((self.icons / "Ability_Ambush.tga").exists(), "nothing is removed when the manifest is bad")

    def test_install_refuses_a_symlinked_icons_folder_or_file(self):
        elsewhere = Path(self.tmp.name) / "elsewhere"
        elsewhere.mkdir()
        (self.wow / "Interface" / "Icons").symlink_to(elsewhere)
        with self.assertRaisesRegex(SystemExit, "symbolic link"):
            self.install()
        self.assertEqual(list(elsewhere.iterdir()), [])
        (self.wow / "Interface" / "Icons").unlink()
        self.icons.mkdir()
        victim = Path(self.tmp.name) / "victim.tga"
        victim.write_bytes(b"keep me")
        (self.icons / "Ability_Ambush.tga").symlink_to(victim)
        with self.assertRaisesRegex(SystemExit, "symbolic link"):
            self.install()
        self.assertEqual(victim.read_bytes(), b"keep me")
        (self.icons / "Ability_Ambush.tga").unlink()
        (self.icons / iconset.MANIFEST).symlink_to(victim)
        with self.assertRaisesRegex(SystemExit, "symbolic link"):
            self.install()
        self.assertEqual(victim.read_bytes(), b"keep me")

    def test_a_newer_pack_removes_the_icons_it_no_longer_has_and_keeps_a_changed_one(self):
        self.install()
        (self.pack / "Spell_Fire_FlameBolt.tga").unlink()
        summary = self.install()
        self.assertEqual(sorted(p.name for p in self.icons.iterdir()), ["Ability_Ambush.tga", iconset.MANIFEST])
        self.assertEqual(summary["dropped"], 1)
        manifest = json.loads((self.icons / iconset.MANIFEST).read_text())
        self.assertEqual(set(manifest["files"]), {"Ability_Ambush.tga"})
        (self.pack / "Ability_Ambush.tga").unlink()
        (self.pack / "New_Icon.tga").write_bytes(iconset.tga_bytes(1, 1, bytes([4, 5, 6])))
        (self.icons / "Ability_Ambush.tga").write_bytes(b"edited by the player")
        summary = self.install()
        self.assertTrue((self.icons / "Ability_Ambush.tga").exists(), "a changed file is kept")
        self.assertEqual((summary["dropped"], summary["kept"]), (0, 1))
        self.assertEqual(set(json.loads((self.icons / iconset.MANIFEST).read_text())["files"]), {"New_Icon.tga"})

    def test_uninstall_without_a_manifest_removes_nothing(self):
        self.icons.mkdir()
        (self.icons / "Ability_Ambush.tga").write_bytes(b"someone else's")
        summary = self.install(uninstall=True)
        self.assertEqual((summary["removed"], summary["kept"]), (0, 0))
        self.assertTrue((self.icons / "Ability_Ambush.tga").exists())

    def test_the_command_line_runs_pack_and_install(self):
        root = Path(self.tmp.name)
        source = root / "setB" / "Icons"
        write_pngs(source, [132089])
        names = root / "names.csv"
        names.write_text("132089;Interface/ICONS/Ability_Ambush.blp\n")
        out = root / "cli-pack"
        decoder = decode(128, 128, (9, 9, 9))
        original = iconset.read_png_rgb
        iconset.read_png_rgb = decoder
        try:
            self.assertEqual(iconset.main(["pack", "--out", str(out), "--names", str(names), "--source", str(source)]), 0)
        finally:
            iconset.read_png_rgb = original
        self.assertTrue((out / "Interface" / "Icons" / "Ability_Ambush.tga").exists())
        self.assertEqual(iconset.main(["install", "--wow", str(self.wow), "--pack", str(out), "--dry-run"]), 0)
        self.assertFalse(self.icons.exists())
        self.assertEqual(iconset.main(["install", "--wow", str(self.wow), "--pack", str(out)]), 0)
        self.assertTrue((self.icons / "Ability_Ambush.tga").exists())
        self.assertEqual(iconset.main(["install", "--wow", str(self.wow), "--pack", str(out), "--uninstall"]), 0)
        self.assertFalse((self.icons / "Ability_Ambush.tga").exists())


if __name__ == "__main__":
    unittest.main()
