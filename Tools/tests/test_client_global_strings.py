"""The client string supplement adds real FrameXML globals without opening GlueXML names."""
import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "build"))
import gen_globals


class ClientStringsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / gen_globals.DOCS).mkdir(parents=True)
        (self.root / "version.txt").write_text("1.60.1.70862\n")
        self.csv = self.root / "GlobalStrings.csv"
        self.csv.write_text('ID,BaseTag,TagText_lang,Flags\n1,LOOT_ITEM_SELF,"You receive %s",1\n2,YOU_LOOT_MONEY,Gold,3\n3,GLUE_ONLY,Login,2\n4,DISABLED,Hidden,0\n5,BAD-TAG,No,1\n')
        self.out = self.root / "globals.lua"

    def tearDown(self):
        self.temp.cleanup()

    def test_only_framexml_bit_and_identifiers_are_included(self):
        self.assertEqual(gen_globals.client_strings(self.csv), {"LOOT_ITEM_SELF", "YOU_LOOT_MONEY"})

    def test_malformed_csv_is_rejected(self):
        self.csv.write_text("Tag,Flags\nFOO,1\n")
        with self.assertRaisesRegex(ValueError, "BaseTag and Flags"):
            gen_globals.client_strings(self.csv)

    def generate(self, build):
        with patch.object(gen_globals, "describe", return_value="9dc84f0 1.60.1 (70862)"), patch.object(
            gen_globals, "collect", return_value=gen_globals.Globals(["CreateFrame"], [], [])
        ), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return gen_globals.main(["--source", str(self.root), "--global-strings", str(self.csv), "--client-build", build, "--out", str(self.out)])

    def test_output_records_both_sources_without_localized_values(self):
        self.assertEqual(self.generate("1.60.1.70862"), 0)
        text = self.out.read_text()
        for value in ("9dc84f0", "GlobalStrings 1.60.1.70862", "SHA256", "CreateFrame", "LOOT_ITEM_SELF", "YOU_LOOT_MONEY"):
            self.assertIn(value, text)
        for value in ("You receive", "GLUE_ONLY", "DISABLED", "BAD-TAG"):
            self.assertNotIn(value, text)

    def test_mismatching_client_and_ui_builds_never_write(self):
        self.assertEqual(self.generate("1.60.1.70840"), 1)
        self.assertFalse(self.out.exists())

    def test_loot_feed_names_are_in_generated_framexml_globals(self):
        text = (Path(__file__).resolve().parents[1] / "data" / "forever_globals.lua").read_text()
        read = text.split("deprecated = {", 1)[0]
        names = (
            "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
            "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_BONUS_ROLL_SELF",
            "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE", "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT", "GOLD_AMOUNT", "SILVER_AMOUNT", "COPPER_AMOUNT",
        )
        for name in names:
            self.assertIn('"' + name + '"', read)


if __name__ == "__main__":
    unittest.main()
