"""Tests for Tools/build/gen_spell_schools.py: the shipped table is current and holds the picture's spells."""

import json
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "Tools" / "build"))

import gen_spell_schools as gen  # noqa: E402


class SpellSchoolsTest(unittest.TestCase):
    def test_the_shipped_table_is_current(self):
        data = json.loads(gen.DATA.read_text(encoding="utf-8"))
        shipped = gen.DEFAULT_OUT.read_bytes().decode("ascii")
        self.assertEqual(shipped, gen.render(data), "run python3 Tools/build/gen_spell_schools.py")

    def test_the_picture_s_spells_have_their_schools(self):
        data = json.loads(gen.DATA.read_text(encoding="utf-8"))
        found = gen.schools(data)
        self.assertIn(403, found[8], "Lightning Bolt is nature")
        self.assertIn(8042, found[8], "Earth Shock is nature")
        self.assertIn(8050, found[4], "Flame Shock is fire")
        self.assertIn(3599, found[4], "Searing Totem is fire")

    def test_physical_spells_are_left_to_the_fallback(self):
        data = json.loads(gen.DATA.read_text(encoding="utf-8"))
        listed = {n for ids in gen.schools(data).values() for n in ids}
        self.assertNotIn(5215, listed, "Prowl is physical")

    def test_a_mixed_school_takes_the_first_in_the_combat_text_order(self):
        self.assertEqual(gen.primary(20), 4)
        self.assertEqual(gen.primary(1), 1)
        self.assertEqual(gen.primary(126), 2)


if __name__ == "__main__":
    unittest.main()
