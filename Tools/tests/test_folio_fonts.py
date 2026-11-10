"""Folio's static files, source-copy contracts, metrics and shipped Latin locale coverage."""

import hashlib
import importlib.util
import json
import struct
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from Tools.tests.test_fonts import FONTS, ROOT, advance, glyph_box, glyph_index, table, tables

FOLIO = {
    "FolioDisplay-Regular.ttf": (400, "cde1b1e206b36ef2f74ea4b2bf19786d99e93e1c65775b926701e1141726de81"),
    "FolioCaps-SemiBold.ttf": (600, "013dfe836c3a9ffd9d746de47be5a9931115961a9e2ca545b0cfddd58e1dac95"),
    "CinzelNames-SemiBold.ttf": (600, "093759097bef8aecd9156e3f7f87dc4e0cd4023e39c67d5d17ea42eaf8e457c9"),
    "CinzelUnit-SemiBold.ttf": (600, "4bd8f69f468998747f024a26692fa3c06e865ae680c9d6ff15d48660b1f1e806"),
    "PTSerif-Regular.ttf": (400, "a4951fade06ff8f09b7673aa81ffb65a8cd409e24d3289a6dc670bc4dda2557a"),
    "PTSerif-Bold.ttf": (700, "038ba7336bd7ea14f12ad155bed51a4345cac5153275d521dec3ba04021c526e"),
}


def locale_characters(locale):
    entries = json.loads((ROOT / "Tools" / "locale" / f"{locale}.json").read_text(encoding="utf-8"))
    strings = list(entries) + list(entries.values()) if isinstance(entries, dict) else entries
    return {char for text in strings for char in text + text.upper() if char.isprintable()}


def builder():
    spec = importlib.util.spec_from_file_location("make_fonts", ROOT / "Tools" / "media" / "make_fonts.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FolioFontsTest(unittest.TestCase):
    def test_files_are_pinned_static_truetype_and_documented(self):
        provenance = (ROOT / "Media" / "PROVENANCE.md").read_text(encoding="utf-8")
        for name, (weight, digest) in FOLIO.items():
            with self.subTest(font=name):
                data = (FONTS / name).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), digest)
                self.assertIn(digest, provenance)
                self.assertIn(name, provenance)
                self.assertEqual(data[:4], b"\x00\x01\x00\x00")
                self.assertIn("glyf", tables(data))
                self.assertNotIn("fvar", tables(data))
                self.assertEqual(struct.unpack(">H", table(data, "OS/2")[4:6])[0], weight)

    def test_every_printable_locale_character_and_uppercase_accent_has_a_glyph(self):
        for locale in ("enUS", "deDE", "frFR", "esES"):
            characters = locale_characters(locale)
            self.assertTrue(characters)
            for name in FOLIO:
                data = (FONTS / name).read_bytes()
                missing = [f"U+{ord(c):04X} {c}" for c in sorted(characters) if not glyph_index(data, ord(c))]
                self.assertEqual(missing, [], f"{name}: {locale}, including uppercased text")

    def test_modified_faces_map_lowercase_and_accents_to_capitals(self):
        characters = set().union(*(locale_characters(locale) for locale in ("enUS", "deDE", "frFR", "esES")))
        for name in ("FolioCaps-SemiBold.ttf", "CinzelNames-SemiBold.ttf", "CinzelUnit-SemiBold.ttf"):
            data = (FONTS / name).read_bytes()
            for char in characters:
                upper = char.upper()
                if char.islower() and len(upper) == 1:
                    self.assertEqual(glyph_index(data, ord(char)), glyph_index(data, ord(upper)), f"{name}: {char}")

    def test_tracking_and_word_spacing_are_baked_into_advances(self):
        for name, base_a, track, base_space, word in (
            ("FolioCaps-SemiBold.ttf", 711, 45, 225, 80),
            ("CinzelNames-SemiBold.ttf", 715, 0, 250, 160),
            ("CinzelUnit-SemiBold.ttf", 715, -64, 250, 250),
        ):
            data = (FONTS / name).read_bytes()
            self.assertEqual(struct.unpack(">H", table(data, "head")[18:20])[0], 1000)
            self.assertEqual(advance(data, glyph_index(data, ord("A"))), base_a + track)
            self.assertEqual(advance(data, glyph_index(data, ord(" "))), base_space + track + word)

    def test_pt_serif_default_digits_are_tabular_lining_without_feature_selection(self):
        for name, width in (("PTSerif-Regular.ttf", 533), ("PTSerif-Bold.ttf", 565)):
            data = (FONTS / name).read_bytes()
            digits = [glyph_index(data, ord(c)) for c in "0123456789"]
            self.assertEqual({advance(data, glyph) for glyph in digits}, {width})
            for glyph in digits:
                bottom, top = glyph_box(data, glyph)
                self.assertGreater(bottom, -30, name)
                self.assertGreater(top, 650, name)

    def test_unmodified_copies_retain_their_reserved_names(self):
        for name, family in (("FolioDisplay-Regular.ttf", "IM FELL Double Pica SC"), ("PTSerif-Regular.ttf", "PT Serif"), ("PTSerif-Bold.ttf", "PT Serif")):
            self.assertIn(family.encode("utf-16-be"), table((FONTS / name).read_bytes(), "name"))
        provenance = (ROOT / "Media" / "PROVENANCE.md").read_text(encoding="utf-8")
        for filename, author in (("OFL-EBGaramond.txt", "The EB Garamond Project Authors"), ("OFL-IMFell.txt", "Igino Marini"), ("OFL-PTSerif.txt", "ParaType")):
            text = (FONTS / filename).read_text(encoding="utf-8")
            self.assertIn(author, text)
            self.assertIn("SIL OPEN FONT LICENSE Version 1.1", text)
            self.assertIn(hashlib.sha256((FONTS / filename).read_bytes()).hexdigest(), provenance)

    def test_only_folio_never_runs_lumen_builders_and_default_stays_lumen(self):
        module = builder()
        with tempfile.TemporaryDirectory() as directory, mock.patch("builtins.print"), mock.patch.object(importlib.util, "find_spec", return_value=None), mock.patch.object(module, "make_folio") as folio, mock.patch.object(module, "make_cinzel") as cinzel, mock.patch.object(module, "make_tracked") as tracked, mock.patch.object(module, "make_alegreya") as alegreya:
            args = ["--src", directory, "--out", directory]
            self.assertEqual(module.main(args + ["--only", "folio"]), 0)
            folio.assert_called_once()
            cinzel.assert_not_called()
            tracked.assert_not_called()
            alegreya.assert_not_called()
            folio.reset_mock()
            self.assertEqual(module.main(args), 0)
            folio.assert_not_called()
            cinzel.assert_called_once()
            self.assertEqual(tracked.call_count, 3)
            self.assertEqual(alegreya.call_count, 4)

    def test_folio_rejects_an_unpinned_source_before_writing_outputs(self):
        module = builder()
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for name in module.FOLIO_SOURCES:
                (folder / name).write_bytes(b"not the pinned font")
            output = folder / "output"
            output.mkdir()
            with self.assertRaisesRegex(SystemExit, "pinned google/fonts source"):
                module.make_folio(folder, output)
            self.assertEqual(list(output.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
