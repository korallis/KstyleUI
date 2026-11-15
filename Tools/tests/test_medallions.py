"""Tests for Tools/medallions: the prompts table, the generate loop with rerolls and the credit cap, the image steps,
and verify on the repository's shipped Medallions files. The generate loop runs with a fake image service, so the
tests spend no credits.
"""

import copy
import importlib
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Tools" / "medallions"))
medallions = importlib.import_module("medallions")
tables = importlib.import_module("tables")

try:
    from PIL import Image, ImageDraw

    imaging = importlib.import_module("imaging")
except ImportError:  # the image tests need Pillow, as the venv interpreter has
    Image = None

ANCHORS = json.loads((ROOT / "Tools" / "medallions" / "anchors.json").read_text(encoding="utf-8"))


class TablesTest(unittest.TestCase):
    def test_fifty_two_combinations_and_one_hundred_and_four_portraits(self):
        self.assertEqual(len(tables.combos()), 52)
        self.assertEqual(len(tables.portrait_keys()), 104)
        self.assertEqual({r: len(c) for r, c in tables.VALID.items()},
                         {"human": 7, "dwarf": 6, "nightelf": 5, "gnome": 5, "orc": 6, "scourge": 6, "tauren": 4,
                          "troll": 7, "skyborne": 6})

    def test_every_race_and_class_has_its_lines(self):
        for race in tables.RACES:
            for table in (tables.PEOPLE, tables.HERALDRY, tables.FRAME_KEEP, tables.MASTER_CLASS, tables.RACE_FILES):
                self.assertIn(race, table)
            self.assertIn(tables.MASTER_CLASS[race], tables.VALID[race])
        for cls in tables.CLASSES:
            for table in (tables.CALLINGS, tables.EMBLEMS, tables.NOT_EMBLEM, tables.GLOW_HUES):
                self.assertIn(cls, table)

    def test_the_race_masters_are_a_latin_square(self):
        self.assertEqual(sorted(tables.MASTER_CLASS.values()), sorted(tables.CLASSES))

    def test_no_prompt_names_the_setting(self):
        for race, cls in tables.combos():
            texts = [tables.crest_prompt(race, cls), tables.master_prompt(race, cls), tables.BADGE_PROMPT]
            texts += [tables.bust_prompt(race, cls, sex) for sex in tables.SEXES]
            for text in texts:
                for word in tables.BANNED_WORDS:
                    self.assertNotIn(word, text.lower(), f"{race} {cls}: {word}")

    def test_every_anchor_prompt_is_clean_apart_from_its_historical_words(self):
        anchors = [ANCHORS["portrait"], ANCHORS["badge"], ANCHORS["crestStyle"], *ANCHORS["crests"].values()]
        for anchor in anchors:
            extra = set(medallions.banned_in(anchor["prompt"])) - set(anchor.get("historicalWords", ()))
            self.assertEqual(extra, set(), anchor["key"])

    def test_keys_are_checked_against_the_matrix(self):
        self.assertEqual(tables.split_key("nightelf_priest_female"), ("nightelf", "priest", "female"))
        self.assertEqual(tables.split_key("troll_shaman"), ("troll", "shaman", None))
        for bad in ("tauren_mage", "gnome_druid_male", "orc_warrior_m", "human"):
            with self.assertRaises(ValueError):
                tables.split_key(bad)

    def test_a_master_prompt_keeps_ksty88_s_blocks_and_an_edit_keeps_the_frame(self):
        master = tables.crest_prompt("troll", "priest")
        for block in (tables.CREST_STYLE_REFERENCE, tables.CREST_HEADER, tables.CREST_FINISH, tables.CREST_EXCLUSIONS):
            self.assertIn(block, master)
        edit = tables.crest_prompt("troll", "rogue")
        self.assertTrue(edit.startswith("Edit the reference crest. Keep its whole outer frame exactly as it is: "))
        self.assertIn(tables.FRAME_KEEP["troll"][0], edit)
        self.assertIn(tables.EMBLEMS["rogue"][1], edit)
        self.assertIn(tables.NOT_EMBLEM["priest"], edit)

    def test_a_bust_prompt_is_the_anchor_style_and_one_character(self):
        prompt = tables.bust_prompt("gnome", "rogue", "male")
        self.assertTrue(prompt.startswith(tables.BUST_STYLE + " " + tables.BUST_REFERENCE + " Character: "))
        self.assertIn(tables.PEOPLE["gnome"]["male"], prompt)
        self.assertIn(tables.CALLINGS["rogue"], prompt)

    def test_the_anchor_prompts_are_the_locked_style_blocks(self):
        self.assertTrue(ANCHORS["portrait"]["prompt"].startswith(tables.BUST_STYLE))
        for race, anchor in ANCHORS["crests"].items():
            self.assertEqual(anchor["key"], tables.master_key(race))
            if race != "dwarf":
                self.assertEqual(anchor["prompt"].split("\n\n")[0], tables.CREST_STYLE_REFERENCE)


class FakeService:
    """Stands in for Higgsfield: each job makes one image whose verdict the test scripts by job number."""

    def __init__(self, rejected=(), failed=(), busy=0, broken=()):
        self.rejected, self.failed, self.busy, self.broken = set(rejected), set(failed), busy, set(broken)
        self.calls = []

    def run(self, kind, prompt, references):
        if self.busy:
            self.busy -= 1
            raise medallions.RateLimited("rate_limit_reached")
        self.calls.append((kind, prompt, list(references)))
        n = len(self.calls)
        if n in self.failed:
            raise medallions.GenerationError("job ended nsfw")
        return {"id": f"job-{n}", "url": f"https://example.invalid/{n}.png"}

    def fetch(self, url, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_bytes(url.encode())

    def judge_for(self, key):
        def judge(path):
            n = int(Path(path).read_text().rsplit("/", 1)[1].split(".")[0])
            if n in self.broken:
                raise ValueError("cannot read the image")
            return {"n": n}, (["off-centre"] if n in self.rejected else [])
        return judge


class GenerateTest(unittest.TestCase):
    def setUp(self):
        self.raw = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.raw)
        self.log = []

    def run_generate(self, service, kind, keys, cap=100.0):
        budget = medallions.Budget(cap, log=self.log.append)
        steps = medallions.generate(kind, keys, self.raw, ANCHORS, runner=service.run, fetch=service.fetch,
                                    judge_for=service.judge_for, budget=budget, jobs=1, log=self.log.append,
                                    sleep=lambda s: None)
        return steps, budget

    def test_accepts_the_first_clean_image_and_records_its_prompt_and_references(self):
        service = FakeService()
        steps, budget = self.run_generate(service, "bust", ["gnome_rogue_male"])
        self.assertEqual(steps, {"gnome_rogue_male": "done"})
        record = medallions.load_record(self.raw, "bust", "gnome_rogue_male")
        attempt = medallions.accepted(record)
        self.assertEqual(attempt["prompt"], tables.bust_prompt("gnome", "rogue", "male"))
        self.assertEqual(attempt["references"], [ANCHORS["portrait"]["job"]])
        self.assertEqual(attempt["settings"], medallions.SETTINGS["bust"])
        self.assertEqual(budget.spent, 1.5)

    def test_rerolls_a_rejected_image_with_the_same_prompt_at_most_three_images(self):
        service = FakeService(rejected={1, 2, 3})
        steps, _ = self.run_generate(service, "bust", ["gnome_rogue_male"])
        self.assertEqual(steps["gnome_rogue_male"], "exhausted")
        self.assertEqual(len(service.calls), 3)
        self.assertEqual(len({prompt for _, prompt, _ in service.calls}), 1)

    def test_a_rerun_skips_finished_assets(self):
        service = FakeService()
        self.run_generate(service, "bust", ["gnome_rogue_male"])
        self.run_generate(service, "bust", ["gnome_rogue_male"])
        self.assertEqual(len(service.calls), 1)

    def test_stops_at_the_run_s_credit_cap(self):
        service = FakeService()
        keys = ["human_mage_female", "orc_warrior_male", "nightelf_priest_female"]
        steps, budget = self.run_generate(service, "bust", keys, cap=3.0)
        self.assertEqual(len(service.calls), 2)
        self.assertEqual(budget.spent, 3.0)
        self.assertEqual(sorted(steps.values()), ["done", "done", "generate"])

    def test_a_rate_limit_is_waited_out_without_spending(self):
        service = FakeService(busy=2)
        steps, budget = self.run_generate(service, "bust", ["gnome_rogue_male"])
        self.assertEqual(steps["gnome_rogue_male"], "done")
        self.assertEqual(budget.spent, 1.5)

    def test_a_sustained_rate_limit_records_nothing_and_leaves_the_asset_for_the_next_run(self):
        service = FakeService(busy=10 ** 6)
        steps, budget = self.run_generate(service, "bust", ["gnome_rogue_male"])
        self.assertEqual(steps["gnome_rogue_male"], "generate")
        self.assertEqual(budget.spent, 0)
        self.assertEqual(medallions.load_record(self.raw, "bust", "gnome_rogue_male")["attempts"], [])

    def test_a_judge_error_keeps_the_paid_image_and_stops_rerolling_it(self):
        service = FakeService(broken={1})
        steps, _ = self.run_generate(service, "bust", ["gnome_rogue_male"])
        self.assertEqual(len(service.calls), 1)
        self.assertEqual(steps["gnome_rogue_male"], "generate")
        attempt = medallions.load_record(self.raw, "bust", "gnome_rogue_male")["attempts"][0]
        self.assertEqual((attempt["verdict"], attempt["image"]), ("failed", "gnome_rogue_male-1.png"))
        chosen = medallions.accept_by_eye(self.raw, "bust", "gnome_rogue_male", "looked at it")
        self.assertEqual(chosen["n"], 1)

    def test_a_missing_anchor_stops_the_run_before_anything_is_spent(self):
        service = FakeService()

        def judge_for(key):
            raise FileNotFoundError("anchors/crest_troll_priest.png")

        budget = medallions.Budget(100, log=self.log.append)
        with self.assertRaises(FileNotFoundError):
            medallions.generate("crest", ["troll_rogue"], self.raw, ANCHORS, runner=service.run, fetch=service.fetch,
                                judge_for=judge_for, budget=budget, jobs=1, log=self.log.append, sleep=lambda s: None)
        self.assertEqual((service.calls, budget.spent), ([], 0))

    def test_a_reservation_handed_back_at_the_cap_can_start_another_job(self):
        budget = medallions.Budget(3.0, log=self.log.append)
        self.assertTrue(budget.reserve(1.5))
        self.assertTrue(budget.reserve(1.5))
        self.assertFalse(budget.reserve(1.5))
        budget.release(1.5)
        self.assertTrue(budget.reserve(1.5))

    def test_two_failed_jobs_exhaust_an_asset(self):
        service = FakeService(failed={1, 2})
        steps, budget = self.run_generate(service, "bust", ["gnome_rogue_male"])
        self.assertEqual(steps["gnome_rogue_male"], "exhausted")
        self.assertEqual(budget.spent, 3.0)

    def test_a_badge_waits_for_its_bust_then_references_it_and_the_badge_style(self):
        service = FakeService()
        steps, _ = self.run_generate(service, "badge", ["gnome_rogue_male"])
        self.assertEqual(service.calls, [])
        self.assertEqual(steps["gnome_rogue_male"], "generate")
        self.run_generate(service, "bust", ["gnome_rogue_male"])
        self.run_generate(service, "badge", ["gnome_rogue_male"])
        self.assertEqual(service.calls[-1][2], ["job-1", ANCHORS["badge"]["job"]])
        self.assertEqual(service.calls[-1][1], tables.BADGE_PROMPT)

    def test_a_crest_edit_references_its_race_master_and_a_locked_master_is_never_generated(self):
        service = FakeService()
        steps, _ = self.run_generate(service, "crest", ["troll_priest", "troll_rogue"])
        self.assertEqual(len(service.calls), 1)
        self.assertEqual(service.calls[0][2], [ANCHORS["crests"]["troll"]["job"]])
        self.assertEqual(service.calls[0][1], tables.edit_prompt("troll", "rogue"))
        self.assertEqual(steps["troll_rogue"], "done")

    def test_a_rejection_by_eye_rerolls_and_an_acceptance_by_eye_overrules_the_judge(self):
        service = FakeService(rejected={2})
        self.run_generate(service, "bust", ["gnome_rogue_male"])
        medallions.reject_by_eye(self.raw, "bust", "gnome_rogue_male", "hood hides the face")
        self.run_generate(service, "bust", ["gnome_rogue_male"])
        record = medallions.load_record(self.raw, "bust", "gnome_rogue_male")
        self.assertEqual([a["verdict"] for a in record["attempts"]], ["rejected", "rejected", "accepted"])
        chosen = medallions.accept_by_eye(self.raw, "bust", "gnome_rogue_male", "clearer face", attempt=2)
        self.assertEqual(chosen["overruled"], ["off-centre"])
        self.assertEqual(medallions.accepted(medallions.load_record(self.raw, "bust", "gnome_rogue_male"))["n"], 2)


class LuaTableTest(unittest.TestCase):
    ENTRIES = [
        {"file": "Media/Textures/Medallions/Busts/nightelf_priest_female.png", "kind": "bust", "key": "nightelf_priest_female"},
        {"file": "Media/Textures/Medallions/Badges/nightelf_priest_female.png", "kind": "badge", "key": "nightelf_priest_female"},
        {"file": "Media/Textures/Medallions/Crests/troll_rogue.png", "kind": "crest", "key": "troll_rogue"},
        {"file": "Media/Textures/Medallions/Crests/troll_rogue_glow.png", "kind": "crest_glow", "key": "troll_rogue"},
        {"file": "Media/Textures/Medallions/Crests/troll_rogue_metal.png", "kind": "crest_metal", "key": "troll_rogue"},
    ]

    def test_keys_on_the_game_s_race_file_class_file_and_unit_sex(self):
        lua = medallions.render_lua(self.ENTRIES)
        self.assertIn("\t\tNightElf = {\r\n\t\t\tPRIEST = {\r\n\t\t\t\t[3] = { badge = DIR .. \"Badges\\\\nightelf_priest_female.png\", "
                      "bust = DIR .. \"Busts\\\\nightelf_priest_female.png\" },", lua)
        self.assertIn("\t\tTroll = {\r\n\t\t\tROGUE = { crest = DIR .. \"Crests\\\\troll_rogue.png\", "
                      "glow = DIR .. \"Crests\\\\troll_rogue_glow.png\", metal = DIR .. \"Crests\\\\troll_rogue_metal.png\" },", lua)

    def test_is_an_addon_file_with_one_comment(self):
        lua = medallions.render_lua(self.ENTRIES)
        lua.encode("ascii")
        self.assertNotIn("\n", lua.replace("\r\n", ""))
        lines = lua.split("\r\n")
        self.assertTrue(lines[0].startswith("-- MedallionAssets.lua: "))
        self.assertEqual([line for line in lines[1:] if "--" in line], [])


@unittest.skipIf(Image is None, "needs Pillow")
class ImagingTest(unittest.TestCase):
    def test_resizes_in_linear_light(self):
        checker = Image.new("RGBA", (64, 64))
        checker.putdata([(255, 255, 255, 255) if (x + y) % 2 else (0, 0, 0, 255) for y in range(64) for x in range(64)])
        grey = imaging.resize_linear(checker, (8, 8), sharpen=False).getpixel((4, 4))
        self.assertTrue(180 <= grey[0] <= 195, grey)

    def test_a_baked_portrait_is_a_disc_with_a_dark_rim(self):
        face = Image.new("RGB", (512, 512), (200, 160, 120))
        out = imaging.bake_portrait(face, 64)
        self.assertEqual(out.size, (64, 64))
        self.assertEqual(out.getpixel((0, 0))[3], 0)
        self.assertEqual(out.getpixel((32, 32))[3], 255)
        self.assertLess(out.getpixel((32, 0))[0], 120)
        self.assertGreater(out.getpixel((32, 2))[0], 180)

    def test_a_baked_crest_is_refitted_with_a_one_pixel_outline_outside_it(self):
        raw = Image.new("RGBA", (1024, 1024))
        ImageDraw.Draw(raw).rectangle((300, 200, 700, 800), (220, 220, 230, 255))
        out = imaging.bake_crest(raw, 256)
        self.assertEqual(out.getpixel((0, 0))[3], 0)
        box = out.getchannel("A").getbbox()
        self.assertAlmostEqual(box[3] - box[1], round(256 * imaging.CREST_FILL) + 2, delta=2)
        top = out.getpixel((128, box[1]))
        self.assertLess(top[0], 40)
        self.assertGreater(top[3], 150)
        glow, metal = imaging.crest_masks(out)
        self.assertGreater(metal.getpixel((128, 128))[3], 200)
        self.assertEqual(glow.getpixel((128, 128))[3], 0)

    def test_an_edit_that_changed_nothing_is_rejected(self):
        master = Image.open(ROOT / "Tools" / "medallions" / ANCHORS["crests"]["troll"]["copy"])
        _, reasons = imaging.judge_crest(master, tables.GLOW_HUES["rogue"], master)
        self.assertEqual(reasons, ["emblem unchanged (0% of the field)"])

    def test_a_change_in_blue_alone_counts_as_a_new_emblem(self):
        master = Image.open(ROOT / "Tools" / "medallions" / ANCHORS["crests"]["troll"]["copy"]).convert("RGBA")
        r, g, b, a = master.split()
        bluer = Image.merge("RGBA", (r, g, b.point(lambda v: min(255, v + 80)), a))
        metrics = imaging.crest_metrics(bluer, master)
        self.assertGreater(metrics["emblem_changed"], 0.5)

    def test_a_portrait_with_no_subject_is_not_centred(self):
        flat = Image.new("RGB", (512, 512), (30, 30, 30))
        _, reasons = imaging.judge_portrait(flat, {"luma": 30, "sat": 0.0, "cy": 0.5})
        self.assertIn("no subject stands out from the background", reasons)

    def test_an_edit_of_another_race_s_master_drifts(self):
        here = ROOT / "Tools" / "medallions"
        troll = Image.open(here / ANCHORS["crests"]["troll"]["copy"])
        human = Image.open(here / ANCHORS["crests"]["human"]["copy"])
        _, reasons = imaging.judge_crest(troll, tables.GLOW_HUES["priest"], human)
        self.assertTrue(any(r.startswith("silhouette drift") for r in reasons), reasons)
        self.assertTrue(any(r.startswith("frame drift") for r in reasons), reasons)

    def test_the_badge_anchor_reads_at_24_pixels_and_the_portrait_anchor_does_not(self):
        here = ROOT / "Tools" / "medallions"
        badge = imaging.badge_readability(Image.open(here / ANCHORS["badge"]["copy"]))
        bust = imaging.badge_readability(Image.open(here / ANCHORS["portrait"]["copy"]))
        self.assertGreaterEqual(badge["separation"], imaging.BADGE_SEPARATION_MIN)
        self.assertLess(bust["separation"], imaging.BADGE_SEPARATION_MIN)

    def test_the_portrait_anchor_passes_its_own_judge(self):
        anchor = Image.open(ROOT / "Tools" / "medallions" / ANCHORS["portrait"]["copy"])
        _, reasons = imaging.judge_portrait(anchor, imaging.portrait_metrics(anchor))
        self.assertEqual(reasons, [])


class VerifyTest(unittest.TestCase):
    def test_the_repository_s_medallions_files_are_consistent(self):
        self.assertEqual(medallions.verify(ROOT), [])

    def copy_repo(self):
        repo = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, repo)
        for rel in ("Tools/medallions", "Media/Textures/Medallions"):
            if (ROOT / rel).exists():
                shutil.copytree(ROOT / rel, repo / rel)
        (repo / "Media").mkdir(exist_ok=True)
        shutil.copy(ROOT / medallions.PROVENANCE, repo / medallions.PROVENANCE)
        (repo / "Core").mkdir()
        if (ROOT / medallions.LUA).exists():
            shutil.copy(ROOT / medallions.LUA, repo / medallions.LUA)
        return repo

    def test_finds_an_unlisted_file_a_changed_file_and_a_stale_table(self):
        repo = self.copy_repo()
        entries = json.loads((repo / "Tools/medallions/manifest.json").read_text())
        stray = repo / "Media/Textures/Medallions/Busts/human_warrior_male.png"
        stray.parent.mkdir(parents=True, exist_ok=True)
        stray.write_bytes(b"x")
        problems = medallions.verify(repo)
        self.assertIn(f"{medallions.MEDIA}/Busts/human_warrior_male.png has no manifest entry", problems)
        stray.unlink()
        first = repo / entries[0]["file"]
        first.write_bytes(first.read_bytes() + b"\0")
        self.assertIn(f"{entries[0]['file']}: SHA-256 differs from the manifest (run medallions.py bake)",
                      medallions.verify(repo))
        changed = copy.deepcopy(entries)
        changed.pop()
        (repo / "Tools/medallions/manifest.json").write_text(json.dumps(changed))
        problems = medallions.verify(repo)
        self.assertIn(f"{medallions.LUA} is stale (run medallions.py bake)", problems)
        self.assertIn(f"{medallions.PROVENANCE}: the Medallions section is stale (run medallions.py bake)", problems)

    @unittest.skipIf(Image is None, "needs Pillow")
    def test_finds_a_changed_mask_and_a_changed_anchor_copy(self):
        repo = self.copy_repo()
        entries = json.loads((repo / "Tools/medallions/manifest.json").read_text())
        glow = next(e for e in entries if e["kind"] == "crest_glow")
        path = repo / glow["file"]
        image = Image.open(path).convert("RGBA")
        image.putpixel((128, 128), (255, 255, 255, 7))
        image.save(path)
        glow["sha256"] = medallions.sha256(path)
        (repo / "Tools/medallions/manifest.json").write_text(json.dumps(entries))
        anchor = repo / "Tools/medallions" / ANCHORS["portrait"]["copy"]
        anchor.write_bytes(anchor.read_bytes() + b"\0")
        problems = medallions.verify(repo)
        self.assertTrue(any(p.startswith(f"{glow['file']}: does not match the glow mask") for p in problems), problems)
        self.assertIn(f"anchor portrait: {ANCHORS['portrait']['copy']} differs from its copySha256", problems)

    def test_complete_names_every_missing_combination(self):
        problems = medallions.verify(ROOT, complete=True)
        have = len(json.loads((ROOT / "Tools/medallions/manifest.json").read_text()))
        self.assertEqual(len(problems), 104 * 2 + 52 * 3 - have)


if __name__ == "__main__":
    unittest.main()
