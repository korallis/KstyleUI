"""Tests for Tools/icons/iconset.py: prompts, the generate loop with rerolls and the credit floor, and packaging text.

The generate loop runs with a fake image service, so the tests spend no credits and need no Pillow.
"""

import json
import os
import re
import signal
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "icons"))

import iconset  # noqa: E402

SET_A = iconset.SETS["A"]


def spell(name, owner, line, school=1, description="", category="class", subtext=""):
    return {
        "id": abs(hash((name, owner, subtext))) % 100000,
        "name": name,
        "subtext": subtext,
        "category": category,
        "owner": owner,
        "line": line,
        "school": school,
        "passive": False,
        "talent": False,
        "description": description,
    }


def group(icon, name, category="class", school=1, spells=None, owner="MAGE", line="Fire", description=""):
    return {
        "icon": icon,
        "category": category,
        "name": name,
        "school": school,
        "spells": spells or [spell(name, owner, line, school, description, category)],
    }


class FakeService:
    """Stands in for Higgsfield: each prompt makes one image whose verdicts the test scripts."""

    def __init__(self, verdicts=None, balance=2000.0, cost=1.5, fail=(), busy=0):
        self.busy = busy
        self.names = {}
        self.verdicts = verdicts or {}
        self.balance_start = balance
        self.cost = cost
        self.fail = set(fail)
        self.prompts = []
        self.balance_calls = 0

    def icon_of(self, prompt):
        return self.names[re.search(r'"([^"]+)"', prompt).group(1)]

    def run(self, prompt):
        if self.busy:
            self.busy -= 1
            raise iconset.RateLimited("rate_limit_reached")
        self.prompts.append(prompt)
        n = len(self.prompts)
        icon = self.icon_of(prompt)
        if (icon, sum(1 for p in self.prompts if self.icon_of(p) == icon)) in self.fail:
            raise iconset.GenerationError("job ended nsfw")
        return {"id": f"job-{n}", "url": f"https://example.invalid/{n}.png"}

    def fetch(self, url, path):
        Path(path).write_bytes(url.encode())

    def judge(self, path):
        icon, n = Path(path).stem.split("-")
        queue = self.verdicts.get(int(icon), [])
        index = int(n) - 1
        return list(queue[index]) if index < len(queue) else []

    def account_balance(self):
        self.balance_calls += 1
        return self.balance_start - self.cost * len(self.prompts)


def run(groups, service, raw, **kwargs):
    options = {"jobs": 1, "floor": 1300, "cost": 1.5, "refresh_every": 100}
    options.update(kwargs)
    service.names.update({g["name"]: g["icon"] for g in groups})
    return iconset.generate(
        groups,
        SET_A,
        raw,
        runner=service.run,
        fetch=service.fetch,
        judge=service.judge,
        balance=service.account_balance,
        today="2026-11-07",
        log=lambda message: None,
        sleep=lambda seconds: None,
        **options,
    )


class OrderTest(unittest.TestCase):
    def test_orders_class_then_pet_then_racial_then_profession_then_general(self):
        data = {"icons": [
            group(5, "Fishing", "profession"), group(9, "Shoot", "general"), group(7, "Berserking", "racial"),
            group(3, "Bite", "pet"), group(8, "Fireball"), group(2, "Frostbolt"),
        ]}
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data)], [2, 8, 3, 7, 5, 9])

    def test_filters_by_category(self):
        data = {"icons": [group(5, "Fishing", "profession"), group(2, "Frostbolt")]}
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, ["profession"])], [5])


class DescriptionTest(unittest.TestCase):
    def test_drops_number_placeholders(self):
        cases = {
            "Increases your spellcasting and attack speed by X% for X.": "Increases your spellcasting and attack speed.",
            "Hurls a fiery ball that causes X Fire damage and an additional X Fire damage over X.":
                "Hurls a fiery ball that causes Fire damage and an additional Fire damage.",
            "Sends a wave of force, causing X damage and stunning all enemy targets within X yards in a frontal cone for X.":
                "Sends a wave of force, causing damage and stunning all enemy targets in a frontal cone.",
            "Allows the Druid to prowl around. Lasts until cancelled.": "Allows the Druid to prowl around. Lasts until cancelled.",
            "Shields you, absorbing X damage. Lasts X.": "Shields you, absorbing damage.",
            "Restores X% of your mana every X sec.": "Restores part of your mana.",
            "Incapacitates the target for up to X. Only works on Humanoids.": "Incapacitates the target. Only works on Humanoids.",
            "Each melee attack deals an additional X to X Holy damage.": "Each melee attack deals an additional Holy damage.",
            "Reduces the target's speed by an additional X%.": "Reduces the target's speed.",
        }
        for raw, cleaned in cases.items():
            self.assertEqual(iconset.clean_description(raw), cleaned)

    def test_keeps_words_that_contain_x(self):
        text = "Mixes an elixir that boxes the target. Max rank only."
        self.assertEqual(iconset.clean_description(text), text)

    def test_shortens_long_text_at_a_sentence(self):
        text = "First sentence is here. " + "Second sentence keeps going on and on. " * 20
        cleaned = iconset.clean_description(text)
        self.assertLessEqual(len(cleaned), iconset.MAX_DESCRIPTION)
        self.assertTrue(cleaned.endswith("."))


class PromptTest(unittest.TestCase):
    def test_lead_names_the_spell_owner_school_and_effect(self):
        g = group(135812, "Fireball", school=4, owner="MAGE", line="Fire",
                  description="Hurls a fiery ball that causes X Fire damage.")
        lead = iconset.lead_for(g)
        self.assertEqual(
            lead,
            'Fantasy game ability icon for "Fireball", a Mage ability (Fire school). '
            "What it does: Hurls a fiery ball that causes Fire damage.",
        )

    def test_owner_phrases(self):
        cases = [
            (group(1, "Sonic Blast", "pet", spells=[spell("Sonic Blast", "HUNTER", "Pet - Bat", category="pet")]),
             "a Hunter pet ability of the Bat"),
            (group(2, "Blood Pact", "pet", spells=[spell("Blood Pact", "WARLOCK", "Pet - Imp", category="pet")]),
             "a Warlock pet ability of the Imp"),
            (group(3, "Beast Training", "pet", spells=[spell("Beast Training", "HUNTER", "Beast Training", category="pet")]),
             "a Hunter pet ability"),
            (group(4, "Shadowmeld", "racial", spells=[spell("Shadowmeld", "NightElf", "Night Elf Racial", category="racial")]),
             "a Night Elf racial ability"),
            (group(5, "Will of the Forsaken", "racial",
                   spells=[spell("Will of the Forsaken", "Scourge", "Racial - Undead", category="racial")]),
             "an Undead racial ability"),
            (group(6, "Smelting", "profession", spells=[spell("Smelting", "Mining", "Mining", category="profession")]),
             "a Mining profession skill"),
            (group(7, "Shoot", "general", spells=[spell("Shoot", "MAGE,PRIEST,WARLOCK", "Wands", category="general")]),
             "a general skill"),
        ]
        for g, phrase in cases:
            self.assertIn(f", {phrase} (", iconset.lead_for(g))

    def test_names_every_school_of_a_mixed_mask(self):
        self.assertIn("(Fire, Nature and Frost school)", iconset.lead_for(group(1, "Chaos", school=28)))

    def test_uses_the_name_alone_when_no_spell_has_a_tooltip(self):
        lead = iconset.lead_for(group(1, "Demon Tongue", "general", description=""))
        self.assertTrue(lead.endswith("(Physical school)."), lead)

    def test_prompt_ends_with_the_set_style_and_adds_a_fix_after_a_rejection(self):
        g = group(1, "Frostbolt", school=16)
        lead, prompt = iconset.prompt_for(SET_A, g)
        self.assertEqual(prompt, f"{lead} {SET_A.style}")
        retry_lead, retry = iconset.prompt_for(SET_A, g, ["clipped:top", "text:FROST"])
        self.assertTrue(retry.endswith(SET_A.style))
        self.assertIn(iconset.HINTS["clipped"], retry_lead)
        self.assertIn(iconset.HINTS["text"], retry_lead)
        self.assertEqual(retry_lead.count(iconset.HINTS["clipped"]), 1)

    def test_set_a_style_asks_for_a_monochrome_single_icon_with_no_text(self):
        for phrase in ("pure black", "monochrome", "32 pixels", "No text", "no border", "no frame", "not a grid"):
            self.assertIn(phrase, SET_A.style)


class GenerateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.raw = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def record(self, icon):
        return json.loads((self.raw / f"{icon}.json").read_text())

    def test_accepts_the_first_clean_image_and_records_its_prompt(self):
        service = FakeService()
        summary = run([group(10, "Fireball", school=4)], service, self.raw)
        record = self.record(10)
        self.assertEqual(len(record["attempts"]), 1)
        attempt = record["attempts"][0]
        self.assertEqual(attempt["verdict"], "accepted")
        self.assertEqual(attempt["job"], "job-1")
        self.assertEqual(attempt["image"], "10-1.png")
        self.assertEqual(attempt["date"], "2026-11-07")
        self.assertEqual(attempt["model"], SET_A.model)
        self.assertIn('"Fireball"', attempt["prompt"])
        self.assertTrue((self.raw / "10-1.png").exists())
        self.assertEqual(summary["accepted"], 1)

    def test_a_rerun_skips_finished_icons(self):
        service = FakeService()
        run([group(10, "Fireball")], service, self.raw)
        again = FakeService()
        run([group(10, "Fireball")], again, self.raw)
        self.assertEqual(again.prompts, [])

    def test_rerolls_a_rejected_icon_at_most_twice(self):
        service = FakeService(verdicts={10: [["blank"], ["clipped:top"], ["text:AB"]], 11: [["blank"], []]})
        summary = run([group(10, "Fireball"), group(11, "Frostbolt")], service, self.raw)
        self.assertEqual([a["verdict"] for a in self.record(10)["attempts"]], ["rejected"] * 3)
        self.assertEqual([a["verdict"] for a in self.record(11)["attempts"]], ["rejected", "accepted"])
        self.assertIn(iconset.HINTS["clipped"], self.record(10)["attempts"][2]["prompt"])
        self.assertEqual(summary["generated"], 5)
        self.assertEqual(summary["rejected"], 4)
        self.assertEqual(summary["rerolled"], 3)
        self.assertEqual(summary["missing"], [10])
        again = FakeService()
        run([group(10, "Fireball")], again, self.raw)
        self.assertEqual(again.prompts, [])

    def test_a_failed_job_is_retried_but_not_counted_as_a_reroll(self):
        service = FakeService(fail={(10, 1)})
        summary = run([group(10, "Fireball")], service, self.raw)
        self.assertEqual([a["verdict"] for a in self.record(10)["attempts"]], ["failed", "accepted"])
        self.assertEqual(summary["rerolled"], 0)
        self.assertEqual(summary["failed"], 1)

    def test_waits_out_the_concurrency_limit_without_using_an_attempt(self):
        service = FakeService(busy=3)
        summary = run([group(10, "Fireball")], service, self.raw)
        self.assertEqual([a["verdict"] for a in self.record(10)["attempts"]], ["accepted"])
        self.assertEqual(summary["failed"], 0)

    def test_a_rate_limited_job_does_not_count_against_the_credit_floor(self):
        service = FakeService(balance=1303.0, busy=5)
        run([group(10, "Fireball"), group(11, "Frostbolt")], service, self.raw, refresh_every=1000)
        self.assertEqual(len(service.prompts), 2)  # 1303 - 2 * 1.5 = 1300

    def test_gives_up_after_two_failed_jobs(self):
        service = FakeService(fail={(10, 1), (10, 2)})
        summary = run([group(10, "Fireball")], service, self.raw)
        self.assertEqual(len(service.prompts), 2)
        self.assertEqual(summary["missing"], [10])

    def test_stops_at_the_credit_floor_and_leaves_the_rest_pending(self):
        groups = [group(i, f"Spell {i}") for i in range(1, 11)]
        service = FakeService(balance=1310.0)
        summary = run(groups, service, self.raw)
        self.assertEqual(len(service.prompts), 6)  # 1310 - 6 * 1.5 = 1301 >= 1300; a 7th would cross it
        self.assertGreaterEqual(service.account_balance(), 1300)
        self.assertEqual(summary["pending"], [7, 8, 9, 10])
        self.assertTrue(summary["stopped_at_floor"])

    def test_checks_the_balance_at_the_start_and_every_n_generations(self):
        groups = [group(i, f"Spell {i}") for i in range(1, 6)]
        service = FakeService()
        run(groups, service, self.raw, refresh_every=2)
        self.assertEqual(service.balance_calls, 3)  # start, after 2, after 4

    def test_generates_in_category_order(self):
        groups = [group(3, "Bite", "pet"), group(9, "Shoot", "general"), group(2, "Frostbolt")]
        service = FakeService()
        run(iconset.ordered_groups({"icons": groups}), service, self.raw)
        self.assertEqual([service.icon_of(p) for p in service.prompts], [2, 3, 9])

    def test_an_owner_reroll_makes_a_fresh_attempt_for_an_accepted_icon(self):
        run([group(10, "Fireball")], FakeService(), self.raw)
        service = FakeService()
        run([group(10, "Fireball")], service, self.raw, reroll={10})
        attempts = self.record(10)["attempts"]
        self.assertEqual(len(service.prompts), 1)
        self.assertEqual(len(attempts), 2)
        self.assertEqual(iconset.accepted_attempt(self.record(10))["n"], 2)

    def test_limits_the_number_of_new_icons(self):
        groups = [group(i, f"Spell {i}") for i in range(1, 6)]
        service = FakeService()
        summary = run(groups, service, self.raw, limit=2)
        self.assertEqual(len(service.prompts), 2)
        self.assertEqual(summary["pending"], [3, 4, 5])

    def test_ctrl_c_cancels_the_queued_icons_and_keeps_the_running_one(self):
        groups = [group(i, f"Spell {i}") for i in range(1, 6)]
        service = FakeService()
        real_run = service.run

        def interrupted(prompt):
            if not service.prompts:
                time.sleep(0.2)  # let the main thread finish queueing and wait on the first icon
                os.kill(os.getpid(), signal.SIGINT)  # Ctrl+C reaches the main thread, not this worker
                time.sleep(0.3)
            return real_run(prompt)

        service.run = interrupted
        with self.assertRaises(KeyboardInterrupt):
            run(groups, service, self.raw)
        self.assertEqual(len(service.prompts), 1)
        self.assertEqual([a["verdict"] for a in self.record(1)["attempts"]], ["accepted"])

    def test_runs_jobs_in_parallel_without_losing_records(self):
        groups = [group(i, f"Spell {i}") for i in range(1, 31)]
        service = FakeService(verdicts={i: [["blank"]] for i in range(1, 31, 3)})
        summary = run(groups, service, self.raw, jobs=12)
        self.assertEqual(summary["accepted"], 30)
        self.assertEqual(len(service.prompts), 40)


class PackageTextTest(unittest.TestCase):
    def entries(self):
        prowl = group(132089, "Prowl", spells=[
            spell("Prowl", "DRUID", "Feral Combat", subtext="Rank 1"),
            spell("Prowl", "DRUID", "Feral Combat", subtext="Rank 2"),
            spell("Shadowmeld", "NightElf", "Night Elf Racial", category="racial"),
        ])
        fire = group(135812, "Fireball", school=4)
        return [
            {"group": fire, "attempt": {"lead": 'Icon for "Fireball" | hot', "job": "job-2", "model": "gpt_image_2_5", "date": "2026-11-07"}},
            {"group": prowl, "attempt": {"lead": 'Icon for "Prowl"', "job": "job-1", "model": "gpt_image_2_5", "date": "2026-11-07"}},
        ]

    def test_data_lua_defines_the_documented_table(self):
        text = iconset.render_data_lua(SET_A, self.entries())
        lines = text.split("\r\n")
        self.assertNotIn("\n", text.replace("\r\n", ""))
        self.assertTrue(text.isascii())
        self.assertTrue(lines[0].startswith("-- Data.lua: "))
        self.assertEqual(sum(1 for line in lines if "--" in line), 1)
        self.assertIn("_G.KstyleUIIconData = {", lines)
        self.assertIn('\tset = "A",', lines)
        path_132089 = '\t\t[132089] = "Interface\\\\AddOns\\\\KstyleUI_Icons\\\\Icons\\\\132089.png",'
        path_135812 = '\t\t[135812] = "Interface\\\\AddOns\\\\KstyleUI_Icons\\\\Icons\\\\135812.png",'
        self.assertLess(lines.index(path_132089), lines.index(path_135812))
        self.assertIn("\t\t[135812] = 4,", lines)
        self.assertTrue(text.endswith("}\r\n"))

    def test_provenance_has_one_row_per_icon_with_names_model_prompt_and_date(self):
        text = iconset.render_provenance(SET_A, self.entries())
        rows = [line for line in text.splitlines() if line.startswith("| `")]
        self.assertEqual(len(rows), 2)
        self.assertTrue(rows[0].startswith("| `132089` | Prowl, Shadowmeld | gpt_image_2_5 | "))
        self.assertIn('Icon for "Fireball" \\| hot', rows[1])
        self.assertIn("job-2", rows[1])
        self.assertIn("2026-11-07", rows[1])
        self.assertIn(SET_A.style, text)
        self.assertIn(SET_A.reference, text)


def png(width=128, height=128, colour_type=0):
    """A minimal PNG: the signature and an IHDR chunk are all verify_package reads."""
    import struct
    import zlib
    body = struct.pack(">IIBBBBB", width, height, 8, colour_type, 0, 0, 0)
    ihdr = struct.pack(">I", len(body)) + b"IHDR" + body + struct.pack(">I", zlib.crc32(b"IHDR" + body))
    return b"\x89PNG\r\n\x1a\n" + ihdr


XML_WITHOUT_DATA = '<Ui xmlns="http://www.blizzard.com/wow/ui/">\r\n\t<Script file="Init.lua"/>\r\n</Ui>\r\n'


class IncludeDataTest(unittest.TestCase):
    def test_adds_data_lua_after_the_other_scripts(self):
        self.assertEqual(
            iconset.include_data(XML_WITHOUT_DATA),
            '<Ui xmlns="http://www.blizzard.com/wow/ui/">\r\n\t<Script file="Init.lua"/>\r\n'
            '\t<Script file="Data.lua"/>\r\n</Ui>\r\n',
        )

    def test_leaves_a_file_that_already_loads_it(self):
        once = iconset.include_data(XML_WITHOUT_DATA)
        self.assertEqual(iconset.include_data(once), once)


class VerifyPackageTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        self.icons = self.repo / SET_A.addon / "Icons"
        self.icons.mkdir(parents=True)
        self.groups = [group(135812, "Fireball", school=4), group(132089, "Prowl")]
        self.entries = [{"group": g, "attempt": {"lead": "x", "job": "j", "model": "m", "date": "d"}} for g in self.groups]

    def tearDown(self):
        self.tmp.cleanup()

    def write_set(self):
        (self.repo / SET_A.addon / SET_A.xml).write_bytes(iconset.include_data(XML_WITHOUT_DATA).encode())
        for g in self.groups:
            (self.icons / f"{g['icon']}.png").write_bytes(png())
        (self.repo / SET_A.addon / "PROVENANCE.md").write_text(iconset.render_provenance(SET_A, self.entries))
        (self.repo / SET_A.addon / "Data.lua").write_bytes(iconset.render_data_lua(SET_A, self.entries).encode())

    def problems(self):
        return iconset.verify_package(SET_A, self.groups, self.repo)

    def test_an_empty_set_passes(self):
        self.assertEqual(self.problems(), [])

    def test_a_packaged_set_passes(self):
        self.write_set()
        self.assertEqual(self.problems(), [])

    def test_rejects_a_colour_or_wrong_size_png(self):
        self.write_set()
        (self.icons / "135812.png").write_bytes(png(colour_type=2))
        (self.icons / "132089.png").write_bytes(png(width=64, height=64))
        problems = "\n".join(self.problems())
        self.assertIn("135812.png is not an 8-bit greyscale PNG", problems)
        self.assertIn("132089.png is 64x64, not 128x128", problems)

    def test_rejects_an_icon_with_no_ability_or_no_provenance_row(self):
        self.write_set()
        (self.icons / "999.png").write_bytes(png())
        (self.icons / "notes.txt").write_text("x")
        problems = "\n".join(self.problems())
        self.assertIn("999.png is not an icon file ID in Tools/data/abilities.json", problems)
        self.assertIn("999.png has no row in PROVENANCE.md", problems)
        self.assertIn("notes.txt is not <fileID>.png", problems)

    def test_rejects_data_the_addon_does_not_load(self):
        self.write_set()
        (self.repo / SET_A.addon / SET_A.xml).write_bytes(XML_WITHOUT_DATA.encode())
        self.assertIn(f"Data.lua exists but {SET_A.xml} does not load it", self.problems())

    def test_rejects_a_provenance_row_or_data_entry_without_a_png(self):
        self.write_set()
        (self.icons / "132089.png").unlink()
        problems = "\n".join(self.problems())
        self.assertIn("PROVENANCE.md has a row for 132089 but Icons/132089.png is missing", problems)
        self.assertIn("Data.lua does not match the icons in Icons/", problems)


class JudgeWrapperTest(unittest.TestCase):
    class Check:
        """Stands in for check_icons: load_raster raises what a broken download raises."""

        class OcrError(RuntimeError):
            pass

        def __init__(self, error):
            self.error = error

        def read_text(self, paths):
            raise self.error

        def load_raster(self, path):
            raise self.error

        def judge(self, raster, texts=()):
            return []

    def test_turns_a_failed_check_into_a_recorded_generation_error(self):
        for error in (OSError("cannot identify image file"), ValueError("bad JSON"), self.Check.OcrError("no text")):
            for text in (True, False):
                judge = iconset.make_judge(text=text, check=self.Check(error))
                with self.assertRaisesRegex(iconset.GenerationError, "image check failed"):
                    judge(Path("1-1.png"))

    def test_a_judge_error_records_a_failed_attempt_and_keeps_the_run_going(self):
        with tempfile.TemporaryDirectory() as tmp:
            service = FakeService()
            raw = Path(tmp)

            def broken(path):
                raise iconset.GenerationError("image check failed: cannot identify image file")

            service.judge = broken
            summary = run([group(10, "Fireball"), group(11, "Frostbolt")], service, raw)
            record = json.loads((raw / "10.json").read_text())
            self.assertEqual([a["verdict"] for a in record["attempts"]], ["failed", "failed"])
            self.assertEqual(record["attempts"][0]["image"], "10-1.png")
            self.assertEqual(summary["missing"], [10, 11])


class ShippedSetsTest(unittest.TestCase):
    def test_every_packaged_set_in_the_repository_is_consistent(self):
        groups = iconset.ordered_groups(json.loads(iconset.ABILITIES.read_text()))
        for icon_set in iconset.SETS.values():
            self.assertEqual(iconset.verify_package(icon_set, groups), [], icon_set.addon)


if __name__ == "__main__":
    unittest.main()
