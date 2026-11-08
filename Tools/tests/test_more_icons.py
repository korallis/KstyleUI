"""Tests for Tools/icons/more_icons.py: the client's icons that abilities.json and items.json do not cover, grouped
and ranked by what a player sees."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "icons"))

import more_icons  # noqa: E402

CHARGE, FROSTBOLT, GRYPHON, WOLF, TICKET, VICTORY, PIGLET, SHIELD, BAG = 132337, 135846, 132261, 132266, 134481, 136243, 132761, 134951, 133633


def tables():
    return {
        # SpellMisc.ID is the record's own ID; SpellID names the spell, as the client's table does.
        "SpellMisc": [
            {"ID": "5100", "SpellID": "100", "SpellIconFileDataID": str(CHARGE), "SchoolMask": "1"},
            {"ID": "5116", "SpellID": "116", "SpellIconFileDataID": str(FROSTBOLT), "SchoolMask": "16"},
            {"ID": "5117", "SpellID": "117", "SpellIconFileDataID": str(FROSTBOLT), "SchoolMask": "16"},
            {"ID": "5200", "SpellID": "200", "SpellIconFileDataID": str(GRYPHON), "SchoolMask": "1"},
            {"ID": "5458", "SpellID": "458", "SpellIconFileDataID": str(WOLF), "SchoolMask": "1"},
            {"ID": "5900", "SpellID": "900", "SpellIconFileDataID": "0", "SchoolMask": "1"},
            {"ID": "5901", "SpellID": "901", "SpellIconFileDataID": "777001", "SchoolMask": "32"},
        ],
        "SpellName": [
            {"ID": "100", "Name_lang": "Charge"},
            {"ID": "116", "Name_lang": "Frostbolt"},
            {"ID": "117", "Name_lang": "Frostbolt"},
            {"ID": "200", "Name_lang": "[DND] Gryphon Test"},
            {"ID": "458", "Name_lang": "Gray Wolf"},
        ],
        "Talent": [{"ID": "1", "SpellID": "100"}],
        "CurrencyTypes": [{"ID": "515", "Name_lang": "Darkmoon Prize Ticket", "InventoryIconFileID": str(TICKET)}],
        "Achievement": [{"ID": "49", "Title_lang": "Alterac Valley victories", "IconFileID": str(VICTORY)}],
        "Mount": [{"ID": "7", "Name_lang": "Gray Wolf", "SourceSpellID": "458"}],
        "BattlePetSpecies": [{"ID": "39", "IconFileDataID": str(PIGLET), "CreatureID": "2671"}],
        "Item": [
            {"ID": "1", "IconFileDataID": str(SHIELD), "ClassID": "4", "SubclassID": "6"},
            {"ID": "2", "IconFileDataID": str(BAG), "ClassID": "1", "SubclassID": "0"},
        ],
        "ItemSparse": [{"ID": "1", "Display_lang": "Monster - Shield, Round"}],
    }


CLIENT = {
    CHARGE: "Ability_Warrior_Charge", FROSTBOLT: "Spell_Frost_FrostBolt02", GRYPHON: "Ability_Mount_Gryphon_01",
    WOLF: "Ability_Mount_WhiteDireWolf", TICKET: "INV_Misc_Ticket_Darkmoon_01", VICTORY: "Achievement_BG_winAV",
    PIGLET: "INV_Pet_Piglet", SHIELD: "INV_Shield_09", BAG: "INV_Misc_Bag_07", 999001: "INV_Misc_QuestionMark",
    777001: "Spell_Shadow_Hidden_01",
}


class BuildGroupsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.groups = more_icons.build_groups(tables(), CLIENT, known={CHARGE})
        cls.by_icon = {group["icon"]: group for group in cls.groups}

    def test_an_icon_the_data_files_already_cover_is_left_out(self):
        self.assertNotIn(CHARGE, self.by_icon)

    def test_a_spell_icon_is_named_by_its_spells_and_lists_them(self):
        group = self.by_icon[FROSTBOLT]
        self.assertEqual((group["category"], group["name"], group["count"], group["school"]), ("spell", "Frostbolt", 2, 16))
        self.assertEqual(group["spells"], [{"id": 116, "name": "Frostbolt"}, {"id": 117, "name": "Frostbolt"}])
        self.assertEqual(group["rank"], 1)

    def test_a_spell_icon_only_placeholder_spells_use_ranks_after_the_clean_ones(self):
        self.assertEqual((self.by_icon[GRYPHON]["rank"], self.by_icon[GRYPHON]["name"]), (2, "[DND] Gryphon Test"))

    def test_a_spell_icon_of_nameless_spells_is_named_after_its_file_at_rank_2(self):
        self.assertEqual((self.by_icon[777001]["category"], self.by_icon[777001]["name"], self.by_icon[777001]["rank"]), ("spell", "Shadow Hidden 01", 2))

    def test_a_mount_s_summon_spell_icon_is_a_mount_named_by_the_mount(self):
        self.assertEqual((self.by_icon[WOLF]["category"], self.by_icon[WOLF]["name"], self.by_icon[WOLF]["rank"]), ("mount", "Gray Wolf", 1))

    def test_currency_achievement_and_companion_icons_take_their_own_categories_and_names(self):
        self.assertEqual((self.by_icon[TICKET]["category"], self.by_icon[TICKET]["name"]), ("currency", "Darkmoon Prize Ticket"))
        self.assertEqual((self.by_icon[VICTORY]["category"], self.by_icon[VICTORY]["name"]), ("achievement", "Alterac Valley victories"))
        self.assertEqual((self.by_icon[PIGLET]["category"], self.by_icon[PIGLET]["name"]), ("companion", "Piglet"))

    def test_an_item_the_item_list_dropped_is_unlisted_and_named_by_the_item_or_the_file(self):
        self.assertEqual((self.by_icon[SHIELD]["category"], self.by_icon[SHIELD]["name"], self.by_icon[SHIELD]["kind"]),
                         ("unlisted", "Monster - Shield, Round", "item"))
        self.assertEqual((self.by_icon[BAG]["category"], self.by_icon[BAG]["name"]), ("unlisted", "Misc Bag 07"))

    def test_an_icon_nothing_references_is_misc_and_named_by_its_file(self):
        self.assertEqual((self.by_icon[999001]["category"], self.by_icon[999001]["name"]), ("misc", "Misc QuestionMark"))

    def test_groups_come_in_generation_order(self):
        order = [group["category"] for group in self.groups]
        self.assertEqual(order, ["spell", "spell", "spell", "currency", "mount", "companion", "achievement", "unlisted", "unlisted", "misc"])
        self.assertEqual([g["icon"] for g in self.groups if g["category"] == "spell"], [FROSTBOLT, GRYPHON, 777001])

    def test_every_group_names_the_blizzard_file(self):
        for group in self.groups:
            self.assertEqual(group["file"], CLIENT[group["icon"]])


class FileNameTest(unittest.TestCase):
    def test_a_file_name_reads_as_words_without_its_prefix(self):
        self.assertEqual(more_icons.file_words("INV_Misc_Bag_07"), "Misc Bag 07")
        self.assertEqual(more_icons.file_words("Spell_Frost_FrostBolt02"), "Frost FrostBolt02")
        self.assertEqual(more_icons.file_words("Achievement_BG_winAV"), "BG winAV")
        self.assertEqual(more_icons.file_words("Trade_Engineering"), "Engineering")
        self.assertEqual(more_icons.file_words("Temp"), "Temp")
        self.assertEqual(more_icons.file_words("Ability_Druid_Mangle.tga"), "Druid Mangle")

    def test_placeholder_spell_names(self):
        for name in ("[DND] Thing", "Test Spell", "zzOLDHeal", "Spell (PH)", "QA Test", "[DEPRECATED] Fire"):
            self.assertFalse(more_icons.clean_name(name), name)
        for name in ("Frostbolt", "Charge", "Gray Wolf"):
            self.assertTrue(more_icons.clean_name(name), name)


class MainTest(unittest.TestCase):
    def test_writes_the_data_file_from_the_tables_and_the_client_listing(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            folder = tmp / "db2"
            folder.mkdir()
            for name, rows in tables().items():
                keys = list(rows[0])
                lines = [",".join(keys)] + [",".join('"%s"' % row[k] if "," in row[k] else row[k] for k in keys) for row in rows]
                (folder / f"{name}.csv").write_text("\n".join(lines) + "\n")
            listing = tmp / "client.csv"
            listing.write_text("".join(f"{icon};Interface/ICONS/{name}.blp\n" for icon, name in CLIENT.items()))
            known = tmp / "known.json"
            known.write_text(json.dumps({"icons": [{"icon": CHARGE}]}))
            out = tmp / "icons_more.json"
            code = more_icons.main(["--build", "1.60.1.70862", "--from-dir", str(folder), "--client", str(listing),
                                    "--known", str(known), "--out", str(out)])
            self.assertEqual(code, 0)
            data = json.loads(out.read_text())
        self.assertEqual(data["build"], "1.60.1.70862")
        self.assertEqual(len(data["icons"]), 10)
        self.assertEqual(data["counts"]["spell"], 3)
        self.assertEqual(data["counts"]["mount"], 1)
        self.assertEqual(data["categories"], list(more_icons.CATEGORIES))


if __name__ == "__main__":
    unittest.main()
