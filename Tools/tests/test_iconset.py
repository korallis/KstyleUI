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
SET_B = iconset.SETS["B"]
FAITHFUL = iconset.faithful(SET_B)


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
        self.references = []
        self.balance_calls = 0

    def icon_of(self, prompt):
        return self.names[re.search(r'"([^"]+)"', prompt).group(1)]

    def run(self, prompt, references=()):
        if self.busy:
            self.busy -= 1
            raise iconset.RateLimited("rate_limit_reached")
        self.prompts.append(prompt)
        self.references.append(list(references))
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


def run(groups, service, raw, icon_set=SET_A, **kwargs):
    options = {"jobs": 1, "floor": 1300, "cost": 1.5, "refresh_every": 100}
    options.update(kwargs)
    service.names.update({g["name"]: g["icon"] for g in groups})
    return iconset.generate(
        groups,
        icon_set,
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

    def test_filters_by_the_class_that_uses_a_spell(self):
        throw = group(1, "Throw", "general", spells=[spell("Throw", "HUNTER,ROGUE,WARRIOR", "General", category="general")])
        shared = group(2, "Backstab", spells=[spell("Backstab", "ROGUE", "Combat"), spell("Deep Wounds", "WARRIOR", "Arms")])
        data = {"icons": [group(3, "Fireball"), throw, shared]}
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, owner="WARRIOR")], [2, 1])
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, ["class"], owner="WARRIOR")], [2])


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


class SetBPromptTest(unittest.TestCase):
    def test_set_b_is_the_full_colour_addon(self):
        self.assertEqual(SET_B.addon, "KstyleUI_IconsColour")
        self.assertEqual(SET_B.xml, "IconsColour.xml")
        self.assertEqual(SET_B.reference, "docs/design/mockups/icons_B_fullcolour.jpg")
        self.assertEqual(SET_B.model, "gpt_image_2_5")
        self.assertFalse(SET_B.greyscale)
        self.assertTrue((iconset.REPO / SET_B.reference).exists())

    def test_set_b_style_asks_for_one_full_bleed_colour_painting_with_no_text(self):
        for phrase in ("edge to edge", "full-colour", "32 pixels", "No text", "no border", "no frame",
                       "no black margin", "not a grid"):
            self.assertIn(phrase, SET_B.style)

    def test_set_b_lead_names_the_palette_of_the_school(self):
        lead, prompt = iconset.prompt_for(SET_B, group(1, "Fireball", school=4))
        self.assertTrue(lead.startswith(iconset.lead_for(group(1, "Fireball", school=4))))
        self.assertIn(iconset.PALETTES[4], lead)
        self.assertEqual(prompt, f"{lead} {SET_B.style}")

    def test_a_mixed_school_takes_its_first_magic_school_and_physical_counts_only_alone(self):
        self.assertIn(iconset.PALETTES[16], iconset.prompt_for(SET_B, group(1, "Frostfire", school=1 | 16 | 32))[0])
        self.assertIn(iconset.PALETTES[2], iconset.prompt_for(SET_B, group(1, "Holy Fire", school=2 | 4))[0])
        self.assertIn(iconset.PALETTES[1], iconset.prompt_for(SET_B, group(1, "Strike", school=1))[0])

    def test_set_a_prompts_name_no_palette(self):
        lead, _ = iconset.prompt_for(SET_A, group(1, "Fireball", school=4))
        self.assertEqual(lead, iconset.lead_for(group(1, "Fireball", school=4)))

    def test_set_b_rerolls_add_the_set_b_fixes(self):
        lead, _ = iconset.prompt_for(SET_B, group(1, "Frostbolt", school=16), ["frame", "grid:rows", "clipped:left", "flat"])
        for code in ("frame", "grid", "clipped", "flat"):
            self.assertIn(iconset.HINTS_B[code], lead)
        self.assertNotIn(iconset.HINTS["clipped"], lead)

    def test_every_set_b_reason_has_a_fix(self):
        for code in ("blank", "flat", "frame", "grid", "clipped", "text"):
            self.assertIn(code, iconset.HINTS_B)


class FaithfulSetTest(unittest.TestCase):
    """Set B repainted from Blizzard's own icon (image 1) in the look of the action-button strip (image 2)."""

    def test_packages_into_the_same_addon_with_its_own_check_and_references(self):
        self.assertEqual((FAITHFUL.name, FAITHFUL.addon, FAITHFUL.xml), (SET_B.name, SET_B.addon, SET_B.xml))
        self.assertEqual(FAITHFUL.mode, "subject_reference")
        self.assertEqual(FAITHFUL.judge, "faithful")
        self.assertEqual(FAITHFUL.reference, "docs/design/mockups/icons_B_buttons.png")
        self.assertEqual(SET_B.mode, "style")
        self.assertEqual(SET_B.judge, "B")

    def test_the_prompt_repaints_image_1_in_the_finish_of_image_2(self):
        lead, prompt = iconset.prompt_for(FAITHFUL, group(132337, "Charge", owner="WARRIOR", line="Arms"))
        self.assertTrue(lead.startswith('Image 1 is a World of Warcraft ability icon, "Charge". Image 2 shows the target UI style'))
        self.assertIn("do not copy any subject from image 2", lead)
        self.assertIn("same subject, silhouette, composition, viewing angle, scale and dominant colours", lead)
        self.assertIn("Remove image 1's dark bevelled frame and extend the art to every edge", lead)
        self.assertIn("add nothing that is not in image 1", lead)
        self.assertNotIn("Colours:", lead)
        self.assertNotIn("What it does", lead)
        self.assertEqual(prompt, f"{lead} {FAITHFUL.style}")
        self.assertIn("edge to edge", FAITHFUL.style)
        self.assertIn("No text", FAITHFUL.style)

    def test_adds_a_hand_checked_subject_sentence_when_one_exists(self):
        subjects = {132337: "a steel sword over a bold red arrow"}
        lead, _ = iconset.prompt_for(FAITHFUL, group(132337, "Charge"), subjects=subjects)
        self.assertIn("instantly: a steel sword over a bold red arrow. Keep the subject", lead)
        without, _ = iconset.prompt_for(FAITHFUL, group(132337, "Charge"), subjects={})
        self.assertIn("recognises it instantly. Keep the subject", without)

    def test_a_drift_reroll_asks_to_stay_closer_to_image_1(self):
        lead, _ = iconset.prompt_for(FAITHFUL, group(132337, "Charge"), reasons=["drift"])
        self.assertIn(iconset.HINTS_FAITHFUL["drift"], lead)
        self.assertIn("image 1", iconset.HINTS_FAITHFUL["drift"])

    def test_every_faithful_reason_has_a_fix(self):
        for reason in ("blank", "flat", "frame", "grid", "drift", "text"):
            self.assertIn(reason, iconset.HINTS_FAITHFUL)

    def test_subjects_file_maps_file_ids_to_sentences(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "icon_subjects.json"
            self.assertEqual(iconset.load_subjects(path), {})
            path.write_text(json.dumps({"132337": "a sword over an arrow"}))
            self.assertEqual(iconset.load_subjects(path), {132337: "a sword over an arrow"})


class ExtractTest(unittest.TestCase):
    """extract reads Blizzard's icon from the installed client by file ID, once, into a cache outside the repo."""

    def test_runs_the_tool_once_per_file_id_and_caches_the_decoded_icon(self):
        import hashlib

        calls = []

        def tool(icon, blp):
            calls.append(icon)
            Path(blp).write_bytes(b"BLP2" + str(icon).encode())

        def decode(blp, png):
            Path(png).write_bytes(b"PNG" + Path(blp).read_bytes())

        with tempfile.TemporaryDirectory() as tmp:
            first = iconset.extract_icon(132337, tmp, tool=tool, decode=decode)
            again = iconset.extract_icon(132337, tmp, tool=tool, decode=decode)
            self.assertEqual(calls, [132337])
            self.assertEqual(first, again)
            self.assertEqual(first["png"], str(Path(tmp) / "132337.png"))
            self.assertEqual(first["blp_sha256"], hashlib.sha256(b"BLP2132337").hexdigest())
            self.assertEqual(Path(first["png"]).read_bytes(), b"PNGBLP2132337")

    def test_a_tool_that_writes_nothing_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(iconset.ExtractError, "132337"):
                iconset.extract_icon(132337, tmp, tool=lambda icon, blp: None, decode=lambda blp, png: None)

    def test_the_tool_reads_the_game_folder_by_file_id(self):
        command = iconset.tacttool_command(132337, Path("/cache/132337.blp"))
        self.assertEqual(command[1:], ["-p", "wowf", "-r", "eu", "-d", "/Applications/World of Warcraft",
                                       "-m", "id", "-i", "132337", "-o", "/cache/132337.blp"])


class FaithfulGenerateTest(unittest.TestCase):
    def test_passes_the_blizzard_icon_as_the_first_reference_and_records_the_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            service = FakeService()
            sources = {10: {"png": "/cache/10.png", "blp_sha256": "abc123"}}
            summary = run([group(10, "Charge")], service, Path(tmp), icon_set=FAITHFUL, sources=sources)
            self.assertEqual(summary["accepted"], 1)
            self.assertEqual(service.references, [["/cache/10.png"]])
            attempt = json.loads((Path(tmp) / "10.json").read_text())["attempts"][0]
            self.assertEqual(attempt["mode"], "subject_reference")
            self.assertEqual(attempt["source"], {"fileID": 10, "blp_sha256": "abc123"})
            self.assertTrue(attempt["prompt"].startswith("Image 1 is"))

    def test_style_mode_passes_no_subject_reference_and_records_its_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            service = FakeService()
            run([group(10, "Charge")], service, Path(tmp), icon_set=SET_B)
            self.assertEqual(service.references, [[]])
            attempt = json.loads((Path(tmp) / "10.json").read_text())["attempts"][0]
            self.assertEqual(attempt["mode"], "style")
            self.assertNotIn("source", attempt)

    def test_repaints_an_icon_accepted_in_style_mode_once_and_keeps_a_faithful_one(self):
        with tempfile.TemporaryDirectory() as tmp:
            raw = Path(tmp)
            service = FakeService()
            groups = [group(10, "Charge"), group(11, "Rend")]
            sources = {10: {"png": "/cache/10.png", "blp_sha256": "a"}, 11: {"png": "/cache/11.png", "blp_sha256": "b"}}
            run(groups, service, raw, icon_set=SET_B)
            self.assertEqual(len(service.prompts), 2)
            summary = run(groups, service, raw, icon_set=FAITHFUL, sources=sources)
            self.assertEqual(len(service.prompts), 4)
            self.assertEqual(summary["accepted"], 2)
            run(groups, service, raw, icon_set=FAITHFUL, sources=sources)
            self.assertEqual(len(service.prompts), 4)
            record = json.loads((raw / "10.json").read_text())
            self.assertEqual(record["rerollFrom"], 0, "the style image stays as a fallback; no owner reroll")
            self.assertEqual(iconset.accepted_attempt(record)["mode"], "subject_reference")
            run(groups, service, raw, icon_set=SET_B)
            self.assertEqual(len(service.prompts), 4, "a faithful icon counts as done for a plain set B run")

    def test_a_missing_source_leaves_the_icon_pending_for_a_run_after_extract(self):
        with tempfile.TemporaryDirectory() as tmp:
            service = FakeService()
            groups = [group(10, "Charge")]
            summary = run(groups, service, Path(tmp), icon_set=FAITHFUL, sources={})
            self.assertEqual(service.prompts, [])
            self.assertEqual(summary["pending"], [10])
            self.assertEqual(iconset.load_record(Path(tmp), groups[0])["attempts"], [])
            summary = run(groups, service, Path(tmp), icon_set=FAITHFUL, sources={10: {"png": "/c/10.png", "blp_sha256": "a"}})
            self.assertEqual(summary["accepted"], 1)

    def test_a_plain_style_run_keeps_an_accepted_repaint(self):
        with tempfile.TemporaryDirectory() as tmp:
            raw = Path(tmp)
            service = FakeService()
            groups = [group(10, "Charge"), group(11, "Rend")]
            sources = {i: {"png": f"/c/{i}.png", "blp_sha256": "a"} for i in (10, 11)}
            run([groups[0]], service, raw, icon_set=FAITHFUL, sources=sources)  # first made in faithful mode
            run([groups[1]], service, raw, icon_set=SET_B)
            run([groups[1]], service, raw, icon_set=FAITHFUL, sources=sources, reroll={11})  # owner reroll hides the style attempt
            self.assertEqual(len(service.prompts), 3)
            summary = run(groups, service, raw, icon_set=SET_B)
            self.assertEqual(len(service.prompts), 3)
            self.assertEqual(summary["accepted"], 2)
            for g in groups:
                self.assertEqual(iconset.accepted_attempt(iconset.load_record(raw, g))["mode"], "subject_reference")
            run([groups[1]], service, raw, icon_set=SET_B, reroll={11})
            self.assertEqual(len(service.prompts), 4, "an explicit reroll still makes a style image")


class RejudgeTest(unittest.TestCase):
    """rejudge re-runs the set's check on the images a mode already has, after the check changes."""

    def test_flips_the_verdict_of_an_image_the_check_now_accepts_and_leaves_failed_jobs_alone(self):
        with tempfile.TemporaryDirectory() as tmp:
            raw = Path(tmp)
            service = FakeService(verdicts={10: [["frame"], ["frame"], ["frame"]], 11: [[]]}, fail={(12, 1), (12, 2)})
            groups = [group(10, "Charge"), group(11, "Rend"), group(12, "Slam")]
            sources = {i: {"png": f"/cache/{i}.png", "blp_sha256": "a"} for i in (10, 11, 12)}
            run(groups, service, raw, icon_set=FAITHFUL, sources=sources)
            self.assertEqual(iconset.next_step(iconset.load_record(raw, groups[0]), "subject_reference"), "exhausted")

            changed = iconset.rejudge(groups, FAITHFUL, raw, judge=lambda path: [], today="2026-11-08", log=lambda m: None)
            self.assertEqual([(icon, image) for icon, image, _, _ in changed], [(10, "10-1.png"), (10, "10-2.png"), (10, "10-3.png")])
            record = iconset.load_record(raw, groups[0])
            self.assertEqual([a["verdict"] for a in record["attempts"]], ["accepted"] * 3)
            self.assertEqual(record["attempts"][2]["rejudged"], "2026-11-08")
            self.assertEqual(iconset.accepted_attempt(record)["image"], "10-3.png")
            self.assertNotIn("rejudged", iconset.load_record(raw, groups[1])["attempts"][0])
            self.assertEqual([a["verdict"] for a in iconset.load_record(raw, groups[2])["attempts"]], ["failed", "failed"])

    def test_names_only_the_groups_with_an_image_of_the_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            raw = Path(tmp)
            groups = [group(10, "Charge"), group(11, "Rend"), group(12, "Slam")]
            run([groups[0]], FakeService(), raw, icon_set=FAITHFUL, sources={10: {"png": "/c/10.png", "blp_sha256": "a"}})
            run([groups[1]], FakeService(), raw, icon_set=SET_B)
            self.assertEqual([g["icon"] for g in iconset.rejudge_groups(groups, FAITHFUL, raw)], [10])
            self.assertEqual([g["icon"] for g in iconset.rejudge_groups(groups, SET_B, raw)], [11])

    def test_only_the_mode_s_attempts_are_rejudged(self):
        with tempfile.TemporaryDirectory() as tmp:
            raw = Path(tmp)
            service = FakeService(verdicts={10: [["frame"], []]})
            groups = [group(10, "Charge")]
            run(groups, service, raw, icon_set=SET_B)
            changed = iconset.rejudge(groups, FAITHFUL, raw, judge=lambda path: [], today="d", log=lambda m: None)
            self.assertEqual(changed, [])
            self.assertEqual([a["verdict"] for a in iconset.load_record(raw, groups[0])["attempts"]], ["rejected", "accepted"])

    def test_a_stricter_check_can_reject_an_accepted_image(self):
        with tempfile.TemporaryDirectory() as tmp:
            raw = Path(tmp)
            groups = [group(10, "Charge")]
            run(groups, FakeService(), raw, icon_set=FAITHFUL, sources={10: {"png": "/c/10.png", "blp_sha256": "a"}})
            changed = iconset.rejudge(groups, FAITHFUL, raw, judge=lambda path: ["drift"], today="d", log=lambda m: None)
            self.assertEqual(changed, [(10, "10-1.png", [], ["drift"])])
            self.assertIsNone(iconset.accepted_attempt(iconset.load_record(raw, groups[0])))


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

        def interrupted(prompt, references=()):
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
        self.assertIn("| File ID | Spells | Model | Method | Prompt | Blizzard BLP sha256 | Job | Date |", text)
        self.assertTrue(rows[0].startswith("| `132089` | Prowl, Shadowmeld | gpt_image_2_5 | style | Icon for \"Prowl\" |  | job-1 |"))
        self.assertIn('Icon for "Fireball" \\| hot', rows[1])
        self.assertIn("job-2", rows[1])
        self.assertIn("2026-11-07", rows[1])
        self.assertIn(SET_A.style, text)
        self.assertIn(SET_A.reference, text)


def png(width=128, height=128, colour_type=2, pixel=(128, 128, 128, 255)):
    """A small PNG whose every pixel is pixel: the signature, IHDR, one IDAT and IEND."""
    import struct
    import zlib

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    row = b"\x00" + bytes(pixel[:{0: 1, 2: 3, 6: 4}[colour_type]]) * width
    header = struct.pack(">IIBBBBB", width, height, 8, colour_type, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(row * height))


XML_WITHOUT_DATA = '<Ui xmlns="http://www.blizzard.com/wow/ui/">\r\n\t<Script file="Init.lua"/>\r\n</Ui>\r\n'


class SetBPackageTextTest(unittest.TestCase):
    def entries(self):
        fire = group(135812, "Fireball", school=4)
        return [{"group": fire, "attempt": {"lead": 'Icon for "Fireball"', "job": "job-2", "model": "gpt_image_2_5",
                                            "date": "2026-11-07"}}]

    def test_data_lua_names_set_b_and_its_addon(self):
        lines = iconset.render_data_lua(SET_B, self.entries()).split("\r\n")
        self.assertIn('\tset = "B",', lines)
        self.assertIn('\t\t[135812] = "Interface\\\\AddOns\\\\KstyleUI_IconsColour\\\\Icons\\\\135812.png",', lines)

    def test_provenance_describes_set_b_reference_colour_and_checks(self):
        text = iconset.render_provenance(SET_B, self.entries())
        self.assertIn("# KstyleUI_IconsColour provenance", text)
        self.assertIn(SET_B.reference, text)
        self.assertIn(SET_B.style, text)
        self.assertIn("full colour (RGB PNG)", text)
        self.assertIn(SET_B.checks, text)
        self.assertNotIn("off-black", text)
        self.assertEqual(len([line for line in text.splitlines() if line.startswith("| `")]), 1)
        self.assertNotIn("TACTTool", text, "a set with no faithful icon does not describe the Blizzard source")

    def test_a_faithful_row_names_the_method_and_the_blizzard_blp_hash(self):
        digest = "69f12f1fe357130b" * 4
        entries = self.entries() + [{"group": group(132337, "Charge"), "attempt": {
            "lead": 'Image 1 is "Charge"', "job": "job-3", "model": "gpt_image_2_5", "date": "2026-11-07",
            "mode": "subject_reference", "source": {"fileID": 132337, "blp_sha256": digest}}}]
        text = iconset.render_provenance(SET_B, entries)
        rows = [line for line in text.splitlines() if line.startswith("| `")]
        self.assertEqual(rows[0], f"| `132337` | Charge | gpt_image_2_5 | subject_reference | Image 1 is \"Charge\" | {digest} | job-3 | 2026-11-07 |")
        self.assertIn("TACTTool", text)
        self.assertIn("/Applications/World of Warcraft", text)
        self.assertIn(FAITHFUL.reference, text)
        self.assertIn(FAITHFUL.style, text)
        self.assertIn(SET_B.style, text)
        self.assertIn(FAITHFUL.checks, text)


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

    def test_rejects_a_greyscale_or_wrong_size_png(self):
        self.write_set()
        (self.icons / "135812.png").write_bytes(png(colour_type=0))
        (self.icons / "132089.png").write_bytes(png(width=64, height=64))
        problems = "\n".join(self.problems())
        self.assertIn("135812.png is not an 8-bit RGB PNG", problems)
        self.assertIn("132089.png is 64x64, not 128x128", problems)

    def test_rejects_a_set_a_png_with_colour(self):
        self.write_set()
        (self.icons / "135812.png").write_bytes(png(pixel=(200, 60, 60)))
        self.assertIn("Icons/135812.png is not luminance only", self.problems())

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


class SetBVerifyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        self.icons = self.repo / SET_B.addon / "Icons"
        self.icons.mkdir(parents=True)
        self.groups = [group(135812, "Fireball", school=4)]
        entries = [{"group": g, "attempt": {"lead": "x", "job": "j", "model": "m", "date": "d"}} for g in self.groups]
        (self.repo / SET_B.addon / "PROVENANCE.md").write_text(iconset.render_provenance(SET_B, entries))

    def tearDown(self):
        self.tmp.cleanup()

    def test_accepts_an_rgb_png_in_colour(self):
        (self.icons / "135812.png").write_bytes(png(pixel=(200, 60, 60)))
        self.assertEqual(iconset.verify_package(SET_B, self.groups, self.repo), [])

    def test_rejects_a_greyscale_or_alpha_png(self):
        for colour_type in (0, 6):
            (self.icons / "135812.png").write_bytes(png(colour_type=colour_type))
            self.assertIn("Icons/135812.png is not an 8-bit RGB PNG", iconset.verify_package(SET_B, self.groups, self.repo))


class PackageFiltersTest(unittest.TestCase):
    def test_package_and_verify_take_no_filter_that_would_drop_the_other_icons(self):
        import contextlib
        import io

        for argv in (["package", "--owner", "WARRIOR"], ["package", "--categories", "class"], ["verify", "--owner", "WARRIOR"]):
            err = io.StringIO()
            with contextlib.redirect_stderr(err), self.assertRaises(SystemExit) as stop:
                iconset.main(argv)
            self.assertEqual(stop.exception.code, 2, argv)
            self.assertIn("unrecognized arguments", err.getvalue())


class FloorTest(unittest.TestCase):
    def test_each_set_has_its_own_credit_floor(self):
        self.assertEqual(SET_A.floor, 1300)
        self.assertEqual(SET_B.floor, 60)

    def test_a_dry_run_names_the_set_floor_unless_overridden(self):
        import contextlib
        import io

        with tempfile.TemporaryDirectory() as tmp:
            for argv, floor in ((["--set", "B"], "60"), (["--set", "B", "--floor", "500"], "500")):
                out = io.StringIO()
                with contextlib.redirect_stdout(out):
                    iconset.main(["generate", *argv, "--dry-run", "--limit", "1", "--work-dir", tmp])
                self.assertIn(f"stops before the balance falls below {floor}", out.getvalue())
                self.assertIn(SET_B.style, out.getvalue())


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

    def test_uses_the_check_of_the_icon_set(self):
        class Check(self.Check):
            def judge_for(self, name):
                return {"A": lambda raster, texts=(): ["colour"], "B": lambda raster, texts=(): ["frame"]}[name]

            def load_raster(self, path):
                return None

        self.assertEqual(iconset.make_judge(text=False, check=Check(None), icon_set=SET_B)(Path("1-1.png")), ["frame"])
        self.assertEqual(iconset.make_judge(text=False, check=Check(None))(Path("1-1.png")), ["colour"])

    def test_the_faithful_check_gets_the_blizzard_raster_of_the_icon(self):
        seen = {}

        class Check(self.Check):
            def judge_for(self, name):
                def faithful(raster, texts=(), reference=None):
                    seen["raster"], seen["reference"] = raster, reference
                    return []
                return {"faithful": faithful}[name]

            def load_raster(self, path):
                return f"raster:{path}"

        judge = iconset.make_judge(text=False, check=Check(None), icon_set=FAITHFUL,
                                   sources={10: {"png": "/cache/10.png", "blp_sha256": "a"}})
        self.assertEqual(judge(Path("/raw/10-2.png")), [])
        self.assertEqual(seen, {"raster": "raster:/raw/10-2.png", "reference": "raster:/cache/10.png"})

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
