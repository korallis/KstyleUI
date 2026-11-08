"""Tests for Tools/icons/iconset.py: prompts, the generate loop with rerolls and the credit floor, and packaging text.
The loose-file pack (names, pack, install) is tested in test_iconpack.py.

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


def run(groups, service, raw, icon_set=SET_B, **kwargs):
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

    def test_a_class_sees_general_spells_for_all_every_profession_and_with_a_race_its_racials(self):
        throw = group(1, "Throw", "general", spells=[spell("Throw", "HUNTER,ROGUE,WARRIOR", "General", category="general")])
        riding = group(2, "Horse Riding", "general", spells=[spell("Horse Riding", "ALL", "Riding", category="general")])
        shoot = group(3, "Shoot", "general", spells=[spell("Shoot", "MAGE,PRIEST,WARLOCK", "Wands", category="general")])
        smelting = group(4, "Smelting", "profession", spells=[spell("Smelting", "Mining", "Mining", category="profession")])
        fury = group(5, "Blood Fury", "racial", spells=[spell("Blood Fury", "Orc", "Orc Racial", category="racial")])
        stomp = group(6, "War Stomp", "racial", spells=[spell("War Stomp", "Tauren", "Tauren Racial", category="racial")])
        bite = group(7, "Bite", "pet", spells=[spell("Bite", "HUNTER", "Pet - Wolf", category="pet")])
        charge = group(8, "Charge", owner="WARRIOR", line="Arms")
        data = {"icons": [throw, riding, shoot, smelting, fury, stomp, bite, charge]}
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, owner="WARRIOR")], [8, 4, 1, 2])
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, owner="WARRIOR", race="Orc")], [8, 5, 4, 1, 2])
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, ["racial"], owner="WARRIOR", race="Orc")], [5])
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, race="Orc")], [5, 4, 2])

    def test_a_profession_skill_that_shares_another_class_s_icon_counts_for_every_class(self):
        first_aid = group(1, "Blessing of Sacrifice", spells=[spell("Blessing of Sacrifice", "PALADIN", "Holy"),
                                                               spell("First Aid", "First Aid", "First Aid", category="profession")])
        data = {"icons": [first_aid, group(2, "Fireball")]}
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, owner="WARRIOR")], [1])


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
        lead, prompt = iconset.prompt_for(SET_B, g)
        self.assertEqual(prompt, f"{lead} {SET_B.style}")
        retry_lead, retry = iconset.prompt_for(SET_B, g, ["clipped:top", "text:FROST"])
        self.assertTrue(retry.endswith(SET_B.style))
        self.assertIn(iconset.HINTS_B["clipped"], retry_lead)
        self.assertIn(iconset.HINTS_B["text"], retry_lead)
        self.assertEqual(retry_lead.count(iconset.HINTS_B["clipped"]), 1)


class SetBPromptTest(unittest.TestCase):
    def test_set_b_is_the_full_colour_set_kept_in_tools(self):
        self.assertEqual(SET_B.folder, "Tools/icons/setB")
        self.assertEqual(SET_B.reference, "docs/design/mockups/icons_B_fullcolour.jpg")
        self.assertEqual(SET_B.model, "gpt_image_2_5")
        self.assertTrue((iconset.REPO / SET_B.reference).exists())
        self.assertTrue((iconset.REPO / SET_B.folder / "Icons").is_dir())

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

    def test_set_b_rerolls_add_the_set_b_fixes(self):
        lead, _ = iconset.prompt_for(SET_B, group(1, "Frostbolt", school=16), ["frame", "grid:rows", "clipped:left", "flat"])
        for code in ("frame", "grid", "clipped", "flat"):
            self.assertIn(iconset.HINTS_B[code], lead)

    def test_every_set_b_reason_has_a_fix(self):
        for code in ("blank", "flat", "frame", "grid", "clipped", "text"):
            self.assertIn(code, iconset.HINTS_B)


class FaithfulSetTest(unittest.TestCase):
    """Set B repainted from Blizzard's own icon (image 1) in the look of the action-button strip (image 2)."""

    def test_packages_into_the_same_folder_with_its_own_check_and_references(self):
        self.assertEqual((FAITHFUL.name, FAITHFUL.folder), (SET_B.name, SET_B.folder))
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


def has_pillow():
    try:
        import PIL  # noqa: F401
    except ImportError:
        return False
    return True


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
        self.assertEqual(attempt["model"], SET_B.model)
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
        self.assertIn(iconset.HINTS_B["clipped"], self.record(10)["attempts"][2]["prompt"])
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

    def test_provenance_has_one_row_per_icon_with_names_model_prompt_and_date(self):
        text = iconset.render_provenance(SET_B, self.entries())
        rows = [line for line in text.splitlines() if line.startswith("| `")]
        self.assertEqual(len(rows), 2)
        self.assertIn("| File ID | Spells or items | Model | Method | Prompt | Blizzard BLP sha256 | Job | Date |", text)
        self.assertTrue(rows[0].startswith("| `132089` | Prowl, Shadowmeld | gpt_image_2_5 | style | Icon for \"Prowl\" |  | job-1 |"))
        self.assertIn('Icon for "Fireball" \\| hot', rows[1])
        self.assertIn("job-2", rows[1])
        self.assertIn("2026-11-07", rows[1])
        self.assertIn(SET_B.style, text)
        self.assertIn(SET_B.reference, text)


def png(width=128, height=128, colour_type=2, pixel=(128, 128, 128, 255)):
    """A small PNG whose every pixel is pixel: the signature, IHDR, one IDAT and IEND."""
    import struct
    import zlib

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    row = b"\x00" + bytes(pixel[:{0: 1, 2: 3, 6: 4}[colour_type]]) * width
    header = struct.pack(">IIBBBBB", width, height, 8, colour_type, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(row * height))


class SetBPackageTextTest(unittest.TestCase):
    def entries(self):
        fire = group(135812, "Fireball", school=4)
        return [{"group": fire, "attempt": {"lead": 'Icon for "Fireball"', "job": "job-2", "model": "gpt_image_2_5",
                                            "date": "2026-11-07"}}]

    def test_provenance_describes_set_b_reference_colour_and_checks(self):
        text = iconset.render_provenance(SET_B, self.entries())
        self.assertIn("# Icon set B provenance", text)
        self.assertIn("iconset.py pack", text)
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


class VerifyPackageTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        self.icons = self.repo / SET_B.folder / "Icons"
        self.icons.mkdir(parents=True)
        self.groups = [group(135812, "Fireball", school=4), group(132089, "Prowl")]
        self.entries = [{"group": g, "attempt": {"lead": "x", "job": "j", "model": "m", "date": "d"}} for g in self.groups]

    def tearDown(self):
        self.tmp.cleanup()

    def write_set(self):
        for g in self.groups:
            (self.icons / f"{g['icon']}.png").write_bytes(png())
        (self.repo / SET_B.folder / "PROVENANCE.md").write_text(iconset.render_provenance(SET_B, self.entries))

    def problems(self, **kwargs):
        return iconset.verify_package(SET_B, self.groups, self.repo, **kwargs)

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

    def test_an_icon_without_a_listfile_name_is_reported_when_names_are_given(self):
        self.write_set()
        self.assertEqual(self.problems(names={135812: "Spell_Fire_FlameBolt", 132089: "Ability_Ambush"}), [])
        self.assertEqual(self.problems(names={135812: "Spell_Fire_FlameBolt"}),
                         ["Icons/132089.png has no listfile name in Tools/data/icon_names.csv: run iconset.py names"])

    def test_rejects_an_icon_with_no_ability_or_no_provenance_row(self):
        self.write_set()
        (self.icons / "999.png").write_bytes(png())
        (self.icons / "notes.txt").write_text("x")
        problems = "\n".join(self.problems())
        self.assertIn("999.png is not an icon file ID in Tools/data/abilities.json", problems)
        self.assertIn("999.png has no row in PROVENANCE.md", problems)
        self.assertIn("notes.txt is not <fileID>.png", problems)

    def test_rejects_a_provenance_row_without_a_png(self):
        self.write_set()
        (self.icons / "132089.png").unlink()
        self.assertIn("PROVENANCE.md has a row for 132089 but Icons/132089.png is missing", self.problems())


class SetBVerifyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        self.icons = self.repo / SET_B.folder / "Icons"
        self.icons.mkdir(parents=True)
        self.groups = [group(135812, "Fireball", school=4)]
        entries = [{"group": g, "attempt": {"lead": "x", "job": "j", "model": "m", "date": "d"}} for g in self.groups]
        (self.repo / SET_B.folder / "PROVENANCE.md").write_text(iconset.render_provenance(SET_B, entries))

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


class DryRunTest(unittest.TestCase):
    def test_a_dry_run_lists_every_group_it_would_paint_and_the_cost(self):
        import contextlib
        import io

        with tempfile.TemporaryDirectory() as tmp:
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = iconset.main(["generate", "--mode", "subject_reference", "--owner", "WARRIOR", "--race", "Orc",
                                     "--categories", "racial", "--dry-run", "--work-dir", tmp])
            self.assertEqual(code, 0)
            text = out.getvalue()
            self.assertIn("2 icons to generate, about 3.0 credits", text)
            self.assertIn("133125 Hardiness (racial)", text)
            self.assertIn("135726 Blood Fury (racial)", text)
            self.assertNotIn("War Stomp", text)


class FloorTest(unittest.TestCase):
    def test_the_set_has_its_credit_floor(self):
        self.assertEqual(SET_B.floor, 60)

    def test_a_dry_run_names_the_set_floor_unless_overridden(self):
        import contextlib
        import io

        with tempfile.TemporaryDirectory() as tmp:
            for argv, floor in (([], "60"), (["--floor", "500"], "500")):
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
                return {"faithful": lambda raster, texts=(), reference=None: ["drift"], "B": lambda raster, texts=(): ["frame"]}[name]

            def load_raster(self, path):
                return None

        self.assertEqual(iconset.make_judge(text=False, check=Check(None), icon_set=SET_B)(Path("1-1.png")), ["frame"])
        self.assertEqual(iconset.make_judge(text=False, check=Check(None))(Path("1-1.png")), ["frame"], "set B is the default")
        faithful = iconset.make_judge(text=False, check=Check(None), icon_set=FAITHFUL, sources={1: {"png": "blizzard.png"}})
        self.assertEqual(faithful(Path("1-1.png")), ["drift"], "the faithful set gets its own check")

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
        groups = iconset.ordered_groups({"icons": iconset.load_groups()})
        names, _ = iconset.load_icon_names(iconset.ICON_NAMES)
        for icon_set in iconset.SETS.values():
            self.assertEqual(iconset.verify_package(icon_set, groups, names=names), [], icon_set.folder)


if __name__ == "__main__":
    unittest.main()


def item_group(icon=134829, name="Minor Healing Potion", kind="Consumable (Potions)", rank=1, items=None):
    items = items or [{"id": 118, "name": name, "classID": 0, "subclassID": 1, "quality": 1, "level": 1}]
    return {"icon": icon, "category": "item", "name": name, "kind": kind, "rank": rank, "count": len(items), "items": items}


class ItemGroupTest(unittest.TestCase):
    def test_item_follows_the_ability_categories_and_the_client_s_other_icons_follow_it(self):
        self.assertEqual(iconset.CATEGORIES[:6], ("class", "pet", "racial", "profession", "general", "item"))
        self.assertEqual(iconset.CATEGORIES[6:], ("spell", "currency", "mount", "companion", "achievement", "unlisted", "misc"))

    def test_item_groups_come_after_the_spell_groups_in_rank_then_count_order(self):
        data = {"icons": [item_group(5, rank=2), item_group(4, rank=1), group(9, "Shoot", "general"), group(2, "Frostbolt"),
                          item_group(3, rank=1, items=[{"id": 1, "name": "a"}, {"id": 2, "name": "b"}])]}
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data)], [2, 9, 3, 4, 5])
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, ["item"])], [3, 4, 5])

    def test_every_class_sees_the_item_groups(self):
        data = {"icons": [item_group(4), group(2, "Frostbolt")]}
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, owner="WARRIOR", race="Orc")], [4])

    def test_load_groups_merges_the_two_data_files_and_an_ability_keeps_a_shared_icon(self):
        with tempfile.TemporaryDirectory() as tmp:
            abilities_path, items_path = Path(tmp) / "abilities.json", Path(tmp) / "items.json"
            abilities_path.write_text(json.dumps({"icons": [group(135812, "Fireball"), group(134829, "Healing Touch")]}))
            items_path.write_text(json.dumps({"icons": [item_group(134829), item_group(134830, "Lesser Healing Potion")]}))
            groups = iconset.load_groups(abilities_path, items_path, Path(tmp) / "missing.json")
            self.assertEqual([(g["icon"], g["category"]) for g in groups],
                             [(135812, "class"), (134829, "class"), (134830, "item")])
            self.assertEqual([g["icon"] for g in iconset.load_groups(abilities_path, Path(tmp) / "missing.json", Path(tmp) / "missing.json")],
                             [135812, 134829])

    def test_an_item_faithful_lead_says_item_icon_and_names_the_kind(self):
        lead, prompt = iconset.prompt_for(FAITHFUL, item_group())
        self.assertTrue(lead.startswith(
            'Image 1 is a World of Warcraft item icon, "Minor Healing Potion", a Consumable (Potions). Image 2 shows'), lead)
        self.assertIn("so a player recognises the item instantly. Keep", lead)
        self.assertNotIn("ability", lead)
        self.assertEqual(prompt, f"{lead} {FAITHFUL.style}")

    def test_a_spell_faithful_lead_is_unchanged(self):
        lead, _ = iconset.prompt_for(FAITHFUL, group(132337, "Charge"))
        self.assertTrue(lead.startswith('Image 1 is a World of Warcraft ability icon, "Charge". Image 2 shows'), lead)
        self.assertIn("so a player recognises it instantly. Keep", lead)

    def test_an_item_subject_sentence_follows_the_kind(self):
        lead, _ = iconset.prompt_for(FAITHFUL, item_group(), subjects={134829: "a red potion flask"})
        self.assertIn("recognises the item instantly: a red potion flask. Keep", lead)

    def test_an_item_style_lead_names_the_item_and_its_kind(self):
        self.assertEqual(iconset.lead_for(item_group(kind="Weapon (One-Handed Swords)", name="Worn Shortsword")),
                         'Fantasy game item icon for "Worn Shortsword", a Weapon (One-Handed Swords).')
        self.assertEqual(iconset.lead_for(item_group(kind="Armor (Shield)")), 'Fantasy game item icon for "Minor Healing Potion", an Armor (Shield).')

    def test_a_provenance_row_lists_the_items_and_how_many_more_share_the_icon(self):
        many = [{"id": i, "name": f"Recipe {i}"} for i in range(1, 4)]
        g = item_group(134939, "Recipe 1", items=many)
        g["count"] = 10
        text = iconset.render_provenance(SET_B, [{"group": g, "attempt": {
            "lead": 'Image 1 is "Recipe 1"', "job": "job-9", "model": "gpt_image_2_5", "date": "2026-11-08",
            "mode": "subject_reference", "source": {"fileID": 134939, "blp_sha256": "ab" * 32}}}])
        self.assertIn("| File ID | Spells or items | Model |", text)
        rows = [line for line in text.splitlines() if line.startswith("| `")]
        self.assertTrue(rows[0].startswith("| `134939` | Recipe 1, Recipe 2, Recipe 3 and 7 more items | gpt_image_2_5 | subject_reference |"), rows[0])

    def test_verify_knows_an_item_file_id(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            icons = repo / SET_B.folder / "Icons"
            icons.mkdir(parents=True)
            (icons / "134829.png").write_bytes(png())
            entries = [{"group": item_group(), "attempt": {"lead": "x", "job": "j", "model": "m", "date": "d"}}]
            (repo / SET_B.folder / "PROVENANCE.md").write_text(iconset.render_provenance(SET_B, entries))
            self.assertEqual(iconset.verify_package(SET_B, [item_group()], repo), [])
            self.assertIn("Icons/134829.png is not an icon file ID in Tools/data/abilities.json or items.json",
                          iconset.verify_package(SET_B, [], repo))


def blp2_bgra(width, height, pixels):
    """A BLP2 file in encoding 3, raw BGRA after the 148-byte header and the 1024-byte palette, as some of
    Forever's item icons are stored; Pillow reads only encodings 1 and 2."""
    import struct

    header = b"BLP2" + struct.pack("<IBBBBII", 1, 3, 8, 0, 0, width, height)
    header += struct.pack("<16I", 148 + 1024, *([0] * 15)) + struct.pack("<16I", width * height * 4, *([0] * 15))
    return header + bytes(1024) + b"".join(bytes(pixel) for pixel in pixels)


@unittest.skipUnless(has_pillow(), "needs Pillow")
class BlpDecodeTest(unittest.TestCase):
    def test_decodes_a_raw_bgra_blp_pillow_cannot_read_and_composites_it_over_black(self):
        from PIL import Image

        with tempfile.TemporaryDirectory() as tmp:
            blp, png = Path(tmp) / "x.blp", Path(tmp) / "x.png"
            blp.write_bytes(blp2_bgra(2, 2, [(255, 0, 0, 255), (0, 0, 255, 128), (0, 0, 0, 255), (0, 255, 0, 0)]))
            iconset.decode_blp(blp, png, size=2)
            with Image.open(png) as image:
                self.assertEqual((image.mode, image.size), ("RGB", (2, 2)))
                self.assertEqual(image.getpixel((0, 0)), (0, 0, 255), "BGRA becomes RGB")
                red = image.getpixel((1, 0))
                self.assertEqual((red[1], red[2]), (0, 0))
                self.assertTrue(126 <= red[0] <= 130, "half alpha over black halves the colour")
                self.assertEqual(image.getpixel((1, 1)), (0, 0, 0), "a transparent pixel is black")

    def test_a_blp_nobody_can_read_is_an_extract_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            blp = Path(tmp) / "x.blp"
            blp.write_bytes(b"BLP2" + bytes(200))
            with self.assertRaises(iconset.ExtractError):
                iconset.decode_blp(blp, Path(tmp) / "x.png")


class ExtractAllTest(unittest.TestCase):
    def test_reports_an_icon_it_cannot_extract_or_decode_and_goes_on(self):
        logged = []

        def extract(icon, cache_dir):
            if icon == 2:
                raise iconset.ExtractError("TACTTool failed for 2")
            if icon == 3:
                raise iconset.ExtractError("x.blp: unknown BLP encoding 9")
            return {"png": f"{cache_dir}/{icon}.png", "blp_sha256": "ab"}

        with tempfile.TemporaryDirectory() as tmp:
            sources = iconset.extract_all([group(1, "a"), group(2, "b"), group(3, "c")], tmp, log=logged.append, extract=extract)
        self.assertEqual(sorted(sources), [1])
        self.assertEqual(logged[-1], f"blizzard icons: 1 in {tmp}, 2 missing")
        self.assertTrue(any("3 c: x.blp: unknown BLP encoding 9" in line for line in logged), logged)


class AcceptByEyeTest(unittest.TestCase):
    """A reviewer who compared a rejected repaint with Blizzard's icon can accept it; the record keeps the check's reasons."""

    def record(self, raw):
        g = group(132208, "Rapid Fire")
        service = FakeService(verdicts={132208: [["drift"], ["drift"], ["drift"]]})
        summary = run([g], service, raw, icon_set=FAITHFUL, sources={132208: {"png": "/cache/132208.png", "blp_sha256": "ab"}})
        self.assertEqual(summary["missing"], [132208])
        return g

    def test_accepts_the_latest_image_of_the_mode_and_keeps_the_reasons_it_overrules(self):
        with tempfile.TemporaryDirectory() as tmp:
            g = self.record(Path(tmp))
            attempt = iconset.accept_by_eye(g, FAITHFUL, Path(tmp), today="2026-11-08", note="faithful: the darker backdrop failed the drift check")
            self.assertEqual((attempt["n"], attempt["verdict"], attempt["image"]), (3, "accepted", "132208-3.png"))
            self.assertEqual(attempt["overruled"], ["drift"])
            self.assertEqual(attempt["reviewed"], "2026-11-08")
            self.assertEqual(attempt["note"], "faithful: the darker backdrop failed the drift check")
            record = iconset.load_record(Path(tmp), g)
            self.assertEqual(record["attempts"][2]["verdict"], "accepted")
            self.assertEqual(iconset.next_step(record, "subject_reference"), "done")
            self.assertEqual(iconset.accepted_attempt(record)["n"], 3)
            self.assertEqual(iconset.summarise([g], Path(tmp), mode="subject_reference")["accepted"], 1)
            changed = iconset.rejudge([g], FAITHFUL, Path(tmp), judge=lambda path: ["drift"], today="2026-11-09", log=lambda m: None)
            self.assertEqual(changed, [], "a rejudge leaves a reviewed attempt alone")

    def test_accepts_a_chosen_attempt_and_refuses_one_without_an_image_of_the_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            g = self.record(Path(tmp))
            self.assertEqual(iconset.accept_by_eye(g, FAITHFUL, Path(tmp), today="d", attempt=2)["n"], 2)
            with self.assertRaisesRegex(ValueError, "no subject_reference image"):
                iconset.accept_by_eye(group(5, "Shoot"), FAITHFUL, Path(tmp), today="d")
            with self.assertRaisesRegex(ValueError, "attempt 7"):
                iconset.accept_by_eye(g, FAITHFUL, Path(tmp), today="d", attempt=7)

    def test_an_explicit_choice_supersedes_a_later_accepted_attempt(self):
        with tempfile.TemporaryDirectory() as tmp:
            g = self.record(Path(tmp))
            iconset.accept_by_eye(g, FAITHFUL, Path(tmp), today="d1")
            chosen = iconset.accept_by_eye(g, FAITHFUL, Path(tmp), today="d2", attempt=2)
            record = iconset.load_record(Path(tmp), g)
            self.assertEqual(iconset.accepted_attempt(record)["n"], 2, "the package takes the reviewer's choice")
            self.assertEqual(chosen["verdict"], "accepted")
            later = record["attempts"][2]
            self.assertEqual(later["verdict"], "rejected")
            self.assertEqual(later["reasons"], ["superseded by attempt 2"])
            self.assertEqual(later["overruled"], ["drift"], "the check's reasons it once overruled are kept")
            self.assertEqual(iconset.next_step(record, "subject_reference"), "done")

    def test_accepting_the_same_image_again_keeps_the_reasons_it_overruled(self):
        with tempfile.TemporaryDirectory() as tmp:
            g = self.record(Path(tmp))
            iconset.accept_by_eye(g, FAITHFUL, Path(tmp), today="d1")
            again = iconset.accept_by_eye(g, FAITHFUL, Path(tmp), today="d2")
            self.assertEqual(again["overruled"], ["drift"])
            self.assertEqual(again["reviewed"], "d2")

    def test_a_reviewed_row_says_so_in_the_method_column(self):
        entries = [{"group": group(132208, "Rapid Fire"), "attempt": {
            "lead": "x", "job": "job-3", "model": "gpt_image_2_5", "date": "2026-11-08", "mode": "subject_reference",
            "reviewed": "2026-11-08", "overruled": ["drift"], "source": {"fileID": 132208, "blp_sha256": "ab" * 32}}}]
        text = iconset.render_provenance(SET_B, entries)
        rows = [line for line in text.splitlines() if line.startswith("| `")]
        self.assertIn("| gpt_image_2_5 | subject_reference, accepted by eye over drift |", rows[0])
        self.assertIn("accepted by eye", text.split("| File ID |")[0], "the header explains the mark")

    def test_the_accept_command_records_the_review(self):
        import contextlib
        import io

        with tempfile.TemporaryDirectory() as tmp:
            raw = Path(tmp) / "raw"
            raw.mkdir()
            self.record(raw)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = iconset.main(["accept", "--mode", "subject_reference", "--work-dir", tmp, "--note", "faithful by eye", "132208"])
            self.assertEqual(code, 0)
            self.assertIn("132208 Rapid Fire: attempt 3 accepted by eye over drift", out.getvalue())
            record = json.loads((raw / "132208.json").read_text())
            self.assertEqual(record["attempts"][2]["note"], "faithful by eye")


@unittest.skipUnless(has_pillow(), "needs Pillow")
class ContactSheetTest(unittest.TestCase):
    """A contact sheet puts Blizzard's icon beside each repaint, so a reviewer compares them at a glance."""

    def test_a_sheet_shows_blizzard_s_icon_then_the_repaint_then_the_small_version(self):
        from PIL import Image

        with tempfile.TemporaryDirectory() as tmp:
            raw, out, blizzard = Path(tmp) / "raw", Path(tmp) / "sheets", Path(tmp) / "blizzard"
            raw.mkdir()
            blizzard.mkdir()
            g = group(10, "Charge")
            Image.new("RGB", (1024, 1024), (200, 40, 40)).save(raw / "10-1.png")
            Image.new("RGB", (512, 512), (40, 40, 200)).save(blizzard / "10.png")
            iconset.save_record(raw, {"icon": 10, "name": "Charge", "category": "class", "rerollFrom": 0, "attempts": [
                {"n": 1, "verdict": "accepted", "image": "10-1.png", "mode": "subject_reference", "model": "m", "lead": "x",
                 "prompt": "x", "job": "j", "date": "d"}]})
            iconset.contact_sheets(SET_B, [g], raw, out, sources={10: {"png": str(blizzard / "10.png")}}, log=lambda m: None)
            with Image.open(out / "sheet-01.png") as sheet:
                self.assertEqual(sheet.size, (iconset.SHEET_COLUMNS * iconset.SHEET_TILE_W, iconset.ICON_SIZE + 16))
                self.assertEqual(sheet.getpixel((64, 64)), (40, 40, 200), "Blizzard's icon first")
                self.assertEqual(sheet.getpixel((iconset.ICON_SIZE + 4 + 64, 64)), (200, 40, 40), "then the repaint")
                self.assertEqual(sheet.getpixel((2 * iconset.ICON_SIZE + 8 + 16, 16)), (200, 40, 40), "then the 32-pixel version")

    def test_a_sheet_without_a_source_leaves_blizzard_s_tile_dark(self):
        from PIL import Image

        with tempfile.TemporaryDirectory() as tmp:
            raw, out = Path(tmp) / "raw", Path(tmp) / "sheets"
            raw.mkdir()
            Image.new("RGB", (64, 64), (200, 40, 40)).save(raw / "10-1.png")
            iconset.save_record(raw, {"icon": 10, "name": "Charge", "category": "class", "rerollFrom": 0, "attempts": [
                {"n": 1, "verdict": "accepted", "image": "10-1.png", "model": "m", "lead": "x", "prompt": "x", "job": "j", "date": "d"}]})
            iconset.contact_sheets(SET_B, [group(10, "Charge")], raw, out, log=lambda m: None)
            with Image.open(out / "sheet-01.png") as sheet:
                self.assertEqual(sheet.getpixel((64, 64)), (24, 24, 24))
                self.assertEqual(sheet.getpixel((iconset.ICON_SIZE + 4 + 64, 64)), (200, 40, 40))


class ItemStylePromptTest(unittest.TestCase):
    def test_set_b_style_mode_gives_an_item_no_spell_school_palette(self):
        lead, prompt = iconset.prompt_for(SET_B, item_group())
        self.assertEqual(lead, 'Fantasy game item icon for "Minor Healing Potion", a Consumable (Potions). ' + iconset.ITEM_PALETTE)
        self.assertEqual(prompt, f"{lead} {SET_B.style}")
        for palette in iconset.PALETTES.values():
            self.assertNotIn(palette, lead)

    def test_a_dry_run_in_style_mode_lists_item_groups(self):
        import contextlib
        import io

        with tempfile.TemporaryDirectory() as tmp:
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = iconset.main(["generate", "--categories", "item", "--dry-run", "--limit", "2", "--work-dir", tmp])
            self.assertEqual(code, 0)
            self.assertIn("2 icons to generate", out.getvalue())


class MoreIconsGroupsTest(unittest.TestCase):
    """The third data file, Tools/data/icons_more.json: the client's other icons, generated after the spells and items."""

    def test_load_groups_merges_the_third_file_and_the_first_two_keep_their_icons(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / "abilities.json").write_text(json.dumps({"icons": [group(1, "Fireball")]}))
            (tmp / "items.json").write_text(json.dumps({"icons": [item_group(icon=2), item_group(icon=1, name="Shares Fireball")]}))
            (tmp / "more.json").write_text(json.dumps({"icons": [
                {"icon": 3, "category": "currency", "name": "Honor Points", "rank": 1, "count": 1, "file": "PVPCurrency-Honor-Alliance"},
                {"icon": 2, "category": "misc", "name": "Potion", "rank": 1, "count": 0, "file": "INV_Potion_01"},
            ]}))
            groups = iconset.load_groups(tmp / "abilities.json", tmp / "items.json", tmp / "more.json")
        self.assertEqual([(g["icon"], g["category"]) for g in groups], [(1, "class"), (2, "item"), (3, "currency")])

    def test_the_new_categories_come_after_the_items_in_generation_order(self):
        more = [
            {"icon": 10, "category": "misc", "name": "Bag", "rank": 1, "count": 0},
            {"icon": 11, "category": "spell", "name": "Growl", "rank": 2, "count": 1, "spells": [{"id": 5, "name": "Growl"}]},
            {"icon": 12, "category": "spell", "name": "Bite", "rank": 1, "count": 3, "spells": [{"id": 6, "name": "Bite"}]},
            {"icon": 13, "category": "currency", "name": "Honor", "rank": 1, "count": 1},
            {"icon": 14, "category": "unlisted", "name": "Shield", "kind": "item", "rank": 1, "count": 1},
            {"icon": 15, "category": "achievement", "name": "Victory", "rank": 1, "count": 1},
            {"icon": 16, "category": "companion", "name": "Piglet", "rank": 1, "count": 1},
        ]
        data = {"icons": more + [item_group(icon=2), group(1, "Fireball")]}
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data)], [1, 2, 12, 11, 13, 16, 15, 14, 10])
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, owner="WARRIOR")], [2, 12, 11, 13, 16, 15, 14, 10],
                         "an owner filter keeps every group that is not a class spell")
        self.assertEqual([g["icon"] for g in iconset.ordered_groups(data, categories=["spell"])], [12, 11])

    def test_the_faithful_lead_names_the_kind_of_icon(self):
        lead = iconset.faithful_lead({"icon": 13, "category": "currency", "name": "Honor Points"})
        self.assertTrue(lead.startswith('Image 1 is a World of Warcraft currency icon, "Honor Points". Image 2'), lead)
        self.assertIn("so a player recognises it instantly", lead)
        for category, what in (("spell", "spell"), ("mount", "mount"), ("companion", "companion pet"), ("achievement", "achievement"), ("unlisted", "item")):
            self.assertIn(f"World of Warcraft {what} icon, ", iconset.faithful_lead({"icon": 1, "category": category, "name": "X"}), category)
        misc = iconset.faithful_lead({"icon": 1, "category": "misc", "name": "Misc Bag 07"})
        self.assertTrue(misc.startswith('Image 1 is a World of Warcraft icon, "Misc Bag 07". Image 2'), misc)
        self.assertEqual(iconset.faithful_lead(item_group()).split(". Image 2")[0],
                         'Image 1 is a World of Warcraft item icon, "Minor Healing Potion", a Consumable (Potions)')

    def test_the_style_lead_of_a_new_category_names_the_icon_without_a_school(self):
        lead = iconset.lead_for({"icon": 13, "category": "currency", "name": "Honor Points"})
        self.assertEqual(lead, 'Fantasy game currency icon for "Honor Points".')
        self.assertEqual(iconset.lead_for({"icon": 1, "category": "misc", "name": "Misc Bag 07"}), 'Fantasy game icon for "Misc Bag 07".')

    def test_a_provenance_row_lists_a_spell_group_s_spells_and_a_plain_name_otherwise(self):
        spell = {"icon": 12, "category": "spell", "name": "Bite", "rank": 1, "count": 2, "spells": [{"id": 6, "name": "Bite"}, {"id": 7, "name": "Maul"}]}
        self.assertEqual(iconset.spell_names(spell), "Bite, Maul")
        self.assertEqual(iconset.spell_names({"icon": 13, "category": "currency", "name": "Honor", "count": 1}), "Honor")
