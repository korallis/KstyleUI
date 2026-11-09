"""Tests for Tools/locale/strings.py: the English base, the UTF-8 sources and the escaped Lua tables."""

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "Tools" / "locale"))

import strings  # noqa: E402


class RepositoryTablesTest(unittest.TestCase):
    """The tables in the repository agree with the code and with each other."""

    def test_check_finds_nothing(self):
        self.assertEqual(strings.problems(REPO), [])

    def test_every_code_key_is_in_the_base(self):
        missing = sorted(set(strings.code_keys(REPO)) - set(strings.base(REPO)))
        self.assertEqual(missing, [], "run " + strings.SYNC)

    def test_k_dot_l_keys_are_collected(self):
        # Frames.lua reads K.L["Targeted"]; a lookbehind on "." once dropped every K.L key.
        self.assertIn("Targeted", strings.code_keys(REPO))

    def test_escaped_tables_decode_to_the_sources(self):
        for code in strings.LOCALES:
            text = (REPO / strings.OUT_DIR / (code + ".lua")).read_bytes()
            text.decode("ascii")
            self.assertEqual(strings.parse(text.decode("ascii")), strings.source(code, REPO), code)

    def test_each_locale_covers_the_base_exactly(self):
        base = set(strings.base(REPO))
        for code in strings.LOCALES:
            have = set(strings.source(code, REPO))
            self.assertEqual(sorted(base - have), [], code + " lacks keys")
            self.assertEqual(sorted(have - base), [], code + " has keys the base lacks")

    def test_the_core_toc_loads_every_locale_after_locale_lua(self):
        files = [Path(p).resolve().relative_to(REPO).as_posix() for p in strings.toc_files(REPO)]
        at = files.index("Core/Locale.lua")
        for code in strings.LOCALES:
            self.assertGreater(files.index("Core/Locales/%s.lua" % code), at, code)
            self.assertLess(files.index("Core/Locales/%s.lua" % code), files.index("Core/Tokens.lua"), code)


class EscapeTest(unittest.TestCase):
    def test_round_trip(self):
        for text in ("Größe", "É1", "小队 2", 'say "hi"\n', "back\\slash", "\x01" + "23", "100%"):
            body = strings.escape(text)
            self.assertTrue(all(" " <= c <= "~" for c in body), body)
            self.assertEqual(strings.unescape(body), text)

    def test_a_digit_after_an_escape_stays_a_digit(self):
        self.assertEqual(strings.escape("é1"), "\\195\\1691")


class ProblemsTest(unittest.TestCase):
    """Each problem the check reports, in a small tree of its own."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "Tools" / "locale").mkdir(parents=True)
        (self.root / "Media" / "Fonts").mkdir(parents=True)
        for face in strings.FACES:
            shutil.copy(REPO / "Media" / "Fonts" / face, self.root / "Media" / "Fonts" / face)
        (self.root / "KstyleUI.toc").write_text("## Interface: 16001\nMain.lua\n")
        self.lua('local L = {}\nprint(L["Hello"], L["Level %d"], L["On: "])\n')
        strings.sync(self.root)

    def tearDown(self):
        self._tmp.cleanup()

    def lua(self, text):
        (self.root / "Main.lua").write_text(text)

    def translate(self, code, table):
        strings.write_json(self.root / "Tools" / "locale" / (code + ".json"), table)
        strings.sync(self.root)

    def test_a_clean_tree_has_no_problems(self):
        self.assertEqual(strings.problems(self.root), [])

    def test_a_key_missing_from_the_base_fails(self):
        self.lua('local L = {}\nprint(L["Hello"], L["Level %d"], L["On: "], L["Goodbye"])\n')
        found = strings.problems(self.root)
        self.assertTrue(any('L["Goodbye"]' in p and "lacks" in p for p in found), found)

    def test_a_stale_base_key_fails(self):
        self.lua('local L = {}\nprint(L["Hello"], L["On: "])\n')
        self.assertTrue(any("no code uses" in p for p in strings.problems(self.root)))

    def test_a_table_missing_a_base_key_fails(self):
        self.translate("deDE", {"Hello": "Hallo", "Level %d": "Stufe %d"})
        found = strings.problems(self.root)
        self.assertTrue(any(p.startswith('deDE lacks "On: "') for p in found), found)
        self.translate("deDE", {"Hello": "Hallo", "Level %d": "Stufe %d", "On: ": "An: "})
        self.assertFalse(any("lacks" in p for p in strings.problems(self.root)))

    def test_a_changed_format_specifier_fails(self):
        self.translate("deDE", {"Level %d": "Stufe %s"})
        self.assertTrue(any("format specifiers" in p for p in strings.problems(self.root)))

    def test_a_dropped_edge_space_fails(self):
        strings.write_json(self.root / "Tools" / "locale" / "deDE.json", {"On: ": "An:"})
        strings.sync(self.root)
        self.assertTrue(any("space" in p for p in strings.problems(self.root)))

    def test_a_glyph_the_faces_lack_fails(self):
        self.translate("deDE", {"Hello": "Hallo 小"})
        found = strings.problems(self.root)
        self.assertTrue(any("小" in p and "Cinzel" in p for p in found), found)

    def test_chinese_glyphs_are_the_game_fonts_job(self):
        self.translate("zhCN", {"Hello": "你好", "Level %d": "等级 %d", "On: ": "开: "})
        self.assertEqual(strings.problems(self.root), [])

    def test_a_hand_edited_lua_table_is_stale(self):
        self.translate("frFR", {"Hello": "Bonjour"})
        path = self.root / strings.OUT_DIR / "frFR.lua"
        path.write_bytes(path.read_bytes().replace(b"Bonjour", b"Salut"))
        self.assertTrue(any("frFR.lua is stale" in p for p in strings.problems(self.root)))

    def test_sync_drops_a_translation_whose_key_is_gone(self):
        self.translate("esES", {"Hello": "Hola", "Gone": "Ido"})
        self.assertEqual(json.loads((self.root / "Tools" / "locale" / "esES.json").read_text()), {"Hello": "Hola"})


if __name__ == "__main__":
    unittest.main()
