"""Tests for Tools/icons/items.py.

The fixtures in fixtures/db2 are real rows from the Forever 1.60.1.70840 client tables, with the
exact headers the DB2 exporter writes.
"""

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "icons"))

import abilities  # noqa: E402
import items  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "db2"

POTION, SCROLL, SWORD, HEARTHSTONE, CLOTH, THUNDERFURY, HEAD = 134829, 134939, 135274, 134414, 132905, 135349, 134166
MONSTER_SHIELD, OLD_BELT, NO_SPARSE = 134951, 132494, 132759


def fixture_tables():
    return {name: abilities.load_csv(FIXTURES / f"{name}.csv") for name in items.TABLES}


class BuildItemsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.groups = items.build_items(fixture_tables())
        cls.by_icon = {group["icon"]: group for group in cls.groups}

    def test_groups_items_under_one_icon_and_names_the_most_common_item(self):
        group = self.by_icon[POTION]
        self.assertEqual(group["category"], "item")
        self.assertEqual(group["name"], "Minor Healing Potion")
        self.assertEqual(group["kind"], "Consumable (Potions)")
        self.assertEqual(group["count"], 3)
        self.assertEqual([item["id"] for item in group["items"]], [118, 268881, 287966])
        self.assertEqual(group["items"][1]["name"], "Perishable Minor Healing Potion")
        self.assertEqual(group["items"][0]["quality"], 1)
        self.assertEqual(group["items"][0]["classID"], 0)
        self.assertEqual(group["items"][0]["subclassID"], 1)
        self.assertEqual(group["items"][0]["level"], 1)
        self.assertNotIn("school", group)

    def test_a_group_lists_at_most_a_few_items_but_counts_them_all(self):
        many = [dict(items.SAMPLE_ITEM, id=i, name=f"Item {i}") for i in range(1, 20)]
        group = items.group_items(many)[0]
        self.assertEqual(group["count"], 19)
        self.assertEqual(len(group["items"]), items.MAX_ITEMS)
        self.assertEqual(group["items"][0]["id"], 1)

    def test_skips_monster_items_deprecated_items_and_items_the_client_has_no_data_for(self):
        for icon in (MONSTER_SHIELD, OLD_BELT, NO_SPARSE):
            self.assertNotIn(icon, self.by_icon)

    def test_ranks_consumables_then_trade_goods_then_gear_then_quest_then_the_rest(self):
        self.assertEqual(self.by_icon[POTION]["rank"], 1)
        self.assertEqual(self.by_icon[CLOTH]["rank"], 2)
        self.assertEqual(self.by_icon[SWORD]["rank"], 3)
        self.assertEqual(self.by_icon[THUNDERFURY]["rank"], 3)
        self.assertEqual(self.by_icon[HEAD]["rank"], 5)
        self.assertEqual(self.by_icon[HEARTHSTONE]["rank"], 6)

    def test_a_shared_icon_takes_the_best_rank_and_the_lowest_item_id_names_a_tie(self):
        group = self.by_icon[SCROLL]
        self.assertEqual(group["rank"], 2, "a recipe and a quest document share the scroll: the recipe's rank wins")
        self.assertEqual(group["name"], "Recipe: Westfall Stew")
        self.assertEqual(group["kind"], "Recipe (Cooking)")

    def test_the_kind_is_the_class_alone_when_the_subclass_repeats_it(self):
        self.assertEqual(self.by_icon[HEARTHSTONE]["kind"], "Miscellaneous (Junk)")
        self.assertEqual(self.by_icon[CLOTH]["kind"], "Trade Goods (Cloth)")
        self.assertEqual(self.by_icon[HEAD]["kind"], "Quest")

    def test_groups_come_in_rank_order_then_by_how_many_items_share_the_icon(self):
        keys = [(g["rank"], -g["count"], g["icon"]) for g in self.groups]
        self.assertEqual(keys, sorted(keys))
        self.assertEqual(self.groups[0]["icon"], POTION)


class MainTest(unittest.TestCase):
    def test_writes_the_json_with_the_build_and_the_counts_per_rank(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "items.json"
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                code = items.main(["--build", "1.60.1.70840", "--from-dir", str(FIXTURES), "--out", str(out)])
            self.assertEqual(code, 0)
            data = json.loads(out.read_text())
            self.assertEqual(data["build"], "1.60.1.70840")
            self.assertEqual(data["categories"], ["item"])
            self.assertEqual(data["ranks"]["1"], "consumables")
            self.assertEqual(data["counts"]["1"], 2)
            self.assertEqual(len(data["icons"]), 8)
            self.assertIn("Wrote 8 icon groups", stdout.getvalue())

    def test_downloads_the_item_tables_through_the_abilities_downloader(self):
        asked = []

        def fetch(url, headers):
            asked.append(url)
            table = url.split("/db2/")[1].split("/")[0]
            return 200, "text/csv", (FIXTURES / f"{table}.csv").read_bytes()

        with tempfile.TemporaryDirectory() as tmp:
            folder = abilities.download_tables("1.60.1.70840", tmp, fetch=fetch, tables=items.TABLES)
            self.assertEqual(sorted(p.name for p in Path(folder).iterdir()),
                             ["Item.csv", "ItemClass.csv", "ItemSparse.csv", "ItemSubClass.csv"])
        self.assertEqual(len(asked), 4)


if __name__ == "__main__":
    unittest.main()
