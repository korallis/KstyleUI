"""Tests for Tools/icons/abilities.py.

The fixtures in fixtures/db2 are real rows from the Forever 1.60.1.70840 client tables, with the
exact headers the DB2 exporter writes.
"""

import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "icons"))

import abilities  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "db2"


def fixture_tables():
    return {name: abilities.load_csv(FIXTURES / f"{name}.csv") for name in abilities.TABLES}


class BuildAbilitiesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.abilities = abilities.build_abilities(fixture_tables())
        cls.by_id = {spell["id"]: spell for spell in cls.abilities}
        cls.groups = abilities.group_by_icon(cls.abilities)
        cls.by_icon = {group["icon"]: group for group in cls.groups}

    def test_groups_ranks_under_one_icon(self):
        group = self.by_icon[135812]
        fireballs = [spell for spell in group["spells"] if spell["name"] == "Fireball"]
        self.assertEqual([spell["id"] for spell in fireballs], [133, 143])
        self.assertEqual([spell["subtext"] for spell in fireballs], ["Rank 1", "Rank 2"])
        self.assertEqual(group["name"], "Fireball")
        self.assertEqual(group["school"], 4)

    def test_classifies_class_racial_profession(self):
        expected = {
            133: ("class", "MAGE"),
            2842: ("class", "ROGUE"),  # Poisons: a secondary skill only rogues have
            3110: ("pet", "WARLOCK"),  # the Imp's Firebolt
            1853: ("pet", "HUNTER"),  # Beast Training teaches hunter pets
            20594: ("racial", "Dwarf"),
            1259705: ("racial", "Skyborne"),  # Forever's new race, race bit 32
            2580: ("profession", "Mining"),
            3273: ("profession", "First Aid"),
            5019: ("general", "MAGE,PRIEST,WARLOCK"),
            6603: ("general", "ALL"),
            674: ("general", "HUNTER,ROGUE,SHAMAN,WARRIOR"),  # Dual Wield: two rows, masks 13 and 64
        }
        got = {spell_id: (self.by_id[spell_id]["category"], self.by_id[spell_id]["owner"]) for spell_id in expected}
        self.assertEqual(got, expected)

    def test_skips_non_ability_lines(self):
        skipped = {
            459: "a mount",
            400080: "rune engraving, which Forever's UI does not load",
            1240365: "a [DNT] test profession",
            2575: "hidden from the spellbook",
            2657: "a recipe (Smelt Copper)",
            8681: "a rogue poison recipe",
            13240: "a recipe that creates an item but has no trivial rank",
            11367: "a talent rank the client does not ship",
        }
        self.assertEqual(sorted(set(skipped) & set(self.by_id)), [])

    def test_keeps_hidden_talents(self):
        accelerant = self.by_id[11069]
        self.assertEqual(accelerant["category"], "class")
        self.assertTrue(accelerant["talent"])
        self.assertTrue(accelerant["passive"])
        self.assertFalse(self.by_id[133]["talent"])

    def test_group_takes_highest_priority_category(self):
        group = self.by_icon[135809]  # Balefire Bolt (mage) shares the Imp's Firebolt icon
        self.assertEqual(group["category"], "class")
        self.assertEqual(group["name"], "Balefire Bolt")
        self.assertEqual({spell["category"] for spell in group["spells"]}, {"class", "pet"})

    def test_records_skill_line_and_school(self):
        firebolt = self.by_id[3110]
        self.assertEqual(firebolt["line"], "Pet - Imp")
        self.assertEqual(firebolt["school"], 4)

    def test_descriptions_are_prompt_text(self):
        self.assertEqual(
            self.by_id[133]["description"],
            "Hurls a fiery ball that causes X Fire damage and an additional X Fire damage over X.",
        )
        for spell in self.abilities:
            self.assertNotIn("$", spell["description"], spell["id"])

    def test_output_is_sorted(self):
        icons = [group["icon"] for group in self.groups]
        self.assertEqual(icons, sorted(icons))
        for group in self.groups:
            ids = [spell["id"] for spell in group["spells"]]
            self.assertEqual(ids, sorted(ids))
            self.assertNotIn("icon", group["spells"][0])


class CleanDescriptionTest(unittest.TestCase):
    def clean(self, text, descriptions=None, names=None):
        return abilities.clean_description(text, descriptions or {}, names or {})

    def test_replaces_values_with_x(self):
        self.assertEqual(self.clean("Deals $s1 damage over $d."), "Deals X damage over X.")
        self.assertEqual(self.clean("Lasts $24597d and adds $11354o1."), "Lasts X and adds X.")
        self.assertEqual(self.clean("Hits $n targets within $a1 yards, $u times."), "Hits X targets within X yards, X times.")

    def test_replaces_formulas_and_variables(self):
        self.assertEqual(self.clean("${$m1*2} to ${$M1+(1*$b1*$<mult>)} damage"), "X to X damage")
        self.assertEqual(self.clean("by $/1000;S1 sec, $<power> power"), "by X sec, X power")

    def test_picks_plural_and_first_gender_form(self):
        self.assertEqual(self.clean("Awards $s3 combo $lpoint:points;."), "Awards X combo points.")
        self.assertEqual(self.clean("$Lattack:attacks; for $ghis:her; allies"), "attacks for his allies")

    def test_conditional_takes_first_branch(self):
        self.assertEqual(self.clean("Absorbs $s1$?s11094[ and reflects][] damage."), "Absorbs X and reflects damage.")
        self.assertEqual(self.clean("A$?s1[b]?s2[c][d]e"), "Abe")
        self.assertEqual(self.clean("$?a14748[${$s1*(1+$14748s1/100)}][$s1] damage"), "X damage")

    def test_resolves_spell_references(self):
        descriptions = {407880: "Heals for $s1."}
        names = {824: "Horse Riding"}
        text = "Rune:\r\n\r\n$@spellicon407880\r\n$@spelldesc407880 Needs $@spellname824."
        self.assertEqual(self.clean(text, descriptions, names), "Rune: Heals for X. Needs Horse Riding.")

    def test_reference_cycle_stops(self):
        self.assertEqual(self.clean("A $@spelldesc1 B", {1: "loop $@spelldesc1"}), "A loop B")

    def test_drops_malformed_tokens(self):
        self.assertEqual(self.clean("a $@ b $?s1 c ${ d"), "a b c X")
        self.assertEqual(self.clean("cost 5$"), "cost 5")

    def test_strips_ui_escapes_and_collapses_whitespace(self):
        self.assertEqual(self.clean("|cFFFFFFFFBold|r  text|nnext\r\n\r\n  end "), "Bold text next end")
        self.assertEqual(self.clean("Rage.|CFFFFFFFFRequires Cat Form|R"), "Rage.Requires Cat Form")


class LoadCsvTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, name, text):
        path = self.root / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_normalises_array_headers(self):
        rows = abilities.load_csv(self.write("T.csv", "ID,RaceMasks[0],RaceMasks_1\n1,2,3\n"))
        self.assertEqual(rows, [{"ID": "1", "RaceMasks_0": "2", "RaceMasks_1": "3"}])

    def test_reads_quoted_multiline_fields(self):
        rows = abilities.load_csv(self.write("T.csv", 'ID,Description_lang\n1,"a,\r\nb"\n'))
        self.assertEqual(rows[0]["Description_lang"], "a,\r\nb")

    def test_rejects_html_response(self):
        path = self.write("T.csv", "<!doctype html>\n<html><body>Service unavailable</body></html>\n")
        with self.assertRaisesRegex(ValueError, "not CSV"):
            abilities.load_csv(path)

    def test_rejects_text_without_comma(self):
        with self.assertRaisesRegex(ValueError, "not CSV"):
            abilities.load_csv(self.write("T.csv", "Service Unavailable\n"))


class DownloadTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.cache = Path(self._tmp.name)
        self.requests = []

    def tearDown(self):
        self._tmp.cleanup()

    def fetch_with(self, status, content_type, body):
        def fetch(url, headers):
            self.requests.append((url, headers))
            return status, content_type, body

        return fetch

    def test_sends_user_agent_and_caches_tables(self):
        fetch = self.fetch_with(200, "text/csv", b"ID,Name_lang\n1,Fireball\n")
        folder = abilities.download_tables("1.60.1.70840", self.cache, fetch=fetch)
        self.assertEqual(folder, self.cache / "1.60.1.70840")
        self.assertEqual(len(self.requests), len(abilities.TABLES))
        url, headers = self.requests[0]
        self.assertEqual(url, f"https://wago.tools/db2/{abilities.TABLES[0]}/csv?build=1.60.1.70840")
        self.assertEqual(headers["User-Agent"], "KstyleUI-tools")
        self.assertEqual(sorted(p.name for p in folder.iterdir()), sorted(f"{t}.csv" for t in abilities.TABLES))

        abilities.download_tables("1.60.1.70840", self.cache, fetch=fetch)
        self.assertEqual(len(self.requests), len(abilities.TABLES))

    def test_rejects_html_response(self):
        fetch = self.fetch_with(200, "text/html; charset=utf-8", b"<!doctype html><p>maintenance</p>")
        with self.assertRaisesRegex(ValueError, "not CSV"):
            abilities.download_tables("1.60.1.70840", self.cache, fetch=fetch)
        self.assertEqual(list((self.cache / "1.60.1.70840").iterdir()), [])

    def test_reports_http_error_with_fallback(self):
        fetch = self.fetch_with(503, "text/html", b"<html>Service unavailable</html>")
        with self.assertRaisesRegex(abilities.DownloadError, "HTTP 503.*casc_export.py"):
            abilities.download_tables("1.60.1.70840", self.cache, fetch=fetch)


class MainTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.out = self.root / "data" / "abilities.json"

    def tearDown(self):
        self._tmp.cleanup()

    def run_main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = abilities.main(["--build", "1.60.1.70840", "--out", str(self.out), *args])
        return code, out.getvalue(), err.getvalue()

    def test_writes_icon_groups_from_dir(self):
        code, out, err = self.run_main("--from-dir", str(FIXTURES))
        self.assertEqual(code, 0, err)
        data = json.loads(self.out.read_text(encoding="utf-8"))
        self.assertEqual(data["build"], "1.60.1.70840")
        self.assertEqual(data["categories"], ["class", "pet", "racial", "profession", "general"])
        self.assertEqual(data["schools"]["4"], "Fire")
        self.assertEqual(sum(data["counts"].values()), len(data["icons"]))
        self.assertIn(f"{len(data['icons'])} icon groups", out)
        self.assertIn("no class abilities: DRUID", err)
        self.assertTrue(self.out.read_bytes().endswith(b"}\n"))

    def test_writes_atomically(self):
        partial = self.root / "partial"
        partial.mkdir()
        for name in abilities.TABLES[1:]:
            (partial / f"{name}.csv").write_bytes((FIXTURES / f"{name}.csv").read_bytes())
        code, _, err = self.run_main("--from-dir", str(partial))
        self.assertEqual(code, 1)
        self.assertIn(abilities.TABLES[0], err)
        self.assertFalse(self.out.exists())

    def test_reports_malformed_csv(self):
        broken = self.root / "broken"
        broken.mkdir()
        for name in abilities.TABLES:
            (broken / f"{name}.csv").write_bytes((FIXTURES / f"{name}.csv").read_bytes())
        (broken / "SpellName.csv").write_text('ID,Name_lang\n1,"' + "x" * 200000 + '"\n', encoding="utf-8")
        code, _, err = self.run_main("--from-dir", str(broken))
        self.assertEqual(code, 1)
        self.assertIn("field larger than field limit", err)
        self.assertFalse(self.out.exists())

    def test_written_file_follows_umask(self):
        previous = os.umask(0o022)
        try:
            abilities.write_json_atomic(self.out, {"ok": True})
        finally:
            os.umask(previous)
        self.assertEqual(self.out.stat().st_mode & 0o777, 0o644)

    def test_failed_write_keeps_old_file(self):
        self.out.parent.mkdir(parents=True)
        self.out.write_text("old\n", encoding="utf-8")
        with self.assertRaises(TypeError):
            abilities.write_json_atomic(self.out, {"bad": object()})
        self.assertEqual(self.out.read_text(encoding="utf-8"), "old\n")
        self.assertEqual([p.name for p in self.out.parent.iterdir()], ["abilities.json"])


if __name__ == "__main__":
    unittest.main()
