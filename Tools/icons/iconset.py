"""Generate, check and package a custom icon set from Tools/data/abilities.json.

Usage (run with a Python that has Pillow, such as ~/.local/share/wow-dev/venv/bin/python):
    iconset.py extract  [--owner WARRIOR] [--categories class,pet]
    iconset.py generate [--set A|B] [--mode style|subject_reference] [--owner WARRIOR] [--jobs 8] [--floor N]
                        [--limit N] [--categories class,pet] [--reroll FILEID ...] [--dry-run]
    iconset.py rejudge  [--set A|B] [--mode ...] [--owner ...]
    iconset.py status   [--set A|B] [--mode ...]
    iconset.py package  [--set A|B] [--no-data]
    iconset.py sheets   [--set A|B]
    iconset.py verify   [--set A|B]

Set A is white light art on black, tinted in game (KstyleUI_Icons). Set B is full-colour painted art
that fills the square (KstyleUI_IconsColour); its prompts also name a palette for the spell school.

--mode subject_reference repaints Blizzard's own icon instead of painting from a text description, so
a player recognises the ability. extract reads each icon from the installed WoW Forever client by file
ID with TACTTool (read-only) into ~/.local/share/wow-dev/icons/blizzard/<fileID>.png, 512 px. The
prompt then gets two image references: the Blizzard icon (image 1, the subject) and the action-button
strip docs/design/mockups/icons_B_buttons.png (image 2, finish only). Tools/data/icon_subjects.json
may add a hand-checked subject sentence for an icon the reference alone does not carry.
--owner WARRIOR keeps the icon groups with a spell that class uses. rejudge re-runs the mode's check on
the images it already has, after the check changes, and stamps each changed verdict.

generate makes one 1:1 image per icon group with Higgsfield, in category order (class, pet, racial,
profession, general), up to --jobs at a time (at most 12; the plus plan runs 8 and the run waits out
its rate limit). Each image goes through the set's check in check_icons (judge for A, judge_colour
for B, judge_faithful for subject_reference, which also rejects a repaint that drifts from Blizzard's
icon); a rejected icon is rerolled at most twice, with a fix for the reasons added to its prompt. Raw
images and one JSON record per icon live outside the repository in ~/.local/share/wow-dev/icons/<set>/raw,
so a rerun skips finished icons. Each attempt records its mode; a subject_reference run repaints an
icon whose accepted image came from a style run, and the style image stays in the package until a
repaint is accepted. The run reads the credit balance at the start and every 100 images, and
stops before a job would take the balance below --floor (set A 1300, set B 60 by default). --reroll makes a fresh attempt for icons the
owner marked on a contact sheet, even when they were accepted.

package writes each accepted icon as a 128x128 PNG to <addon>/Icons/<fileID>.png (luminance only for
set A), removes PNGs it no longer selects, writes <addon>/PROVENANCE.md and <addon>/Data.lua, the
KstyleUIIconData table that Core/Icons.lua reads, and adds Data.lua to the addon's XML load file.
sheets writes contact sheets of 64 icons for review.
verify checks the packaged files: Tools/tests/test_iconset.py runs it on every set.
"""

import argparse
import concurrent.futures
import dataclasses
import datetime
import hashlib
import json
import os
import re
import struct
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
import zlib
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ABILITIES = REPO / "Tools" / "data" / "abilities.json"
SUBJECTS = REPO / "Tools" / "data" / "icon_subjects.json"
WORK = Path.home() / ".local" / "share" / "wow-dev" / "icons"
BLIZZARD = WORK / "blizzard"  # Blizzard's icons, read from the installed client; never in the repository
TACTTOOL = Path.home() / ".local" / "share" / "wow-dev" / "casc" / "TACTTool" / "TACTTool"
WOW_DIR = Path("/Applications/World of Warcraft")
TACT_PRODUCT, TACT_REGION = "wowf", "eu"
REFERENCE_SIZE = 512  # the 64 px Blizzard icon is upscaled to this for the model
MODES = ("style", "subject_reference")
CATEGORIES = ("class", "pet", "racial", "profession", "general")
SCHOOLS = {1: "Physical", 2: "Holy", 4: "Fire", 8: "Nature", 16: "Frost", 32: "Shadow", 64: "Arcane"}
MAX_IMAGES = 3  # the first image and at most two rerolls
MAX_FAILURES = 2  # jobs that end without an image
MAX_JOBS = 12  # the task's ceiling
DEFAULT_JOBS = 8  # the Higgsfield plus plan runs at most 8 jobs at once
RATE_LIMIT_WAIT = 15  # seconds before a rate-limited job tries again
RATE_LIMIT_TRIES = 40
MAX_DESCRIPTION = 300
ICON_SIZE = 128
SHEET_COLUMNS = 8
SHEET_ICONS = 64

STYLE_A = (
    "Draw one simple, iconic subject that captures this ability: a single object, creature head, hand or "
    "symbol seen up close, centred and filling about two thirds of the square, with a wide margin of pure "
    "black on every side. Use bold, thick, solid shapes with a bright glowing core and a clean outline, and "
    "only a little smoke and a few sparks around it, so the silhouette reads clearly when the icon is shrunk "
    "to 32 pixels. No scene, no landscape, no full-body characters, no busy background. Style: match the "
    "reference image exactly: a sculpture of glowing white light and luminous white smoke on a pure black "
    "background, strictly monochrome greyscale, no colour at all. One icon only, not a grid or a sheet. "
    "No text, no letters, no numbers, no runes, no writing, no border, no frame, no rounded square, nothing "
    "touching the edges."
)

HINTS = {
    "blank": "Make the subject large, bright and clearly lit.",
    "small": "Make the subject larger, filling about two thirds of the square.",
    "background": "Keep the background pure black and the subject compact.",
    "clipped": "Keep the whole subject well inside the square with a wide black margin; nothing may touch or cross the edges.",
    "colour": "Use only white and grey light, with no colour tint at all.",
    "text": "Draw no text, letters, numbers or writing of any kind.",
}

STYLE_B = (
    "Paint one bold, iconic subject that captures this ability: the ability's own object, weapon, creature or "
    "magical effect, large and centred, filling most of the square, with a strong clear silhouette and one "
    "bright focal point, so it still reads when the icon is shrunk to 32 pixels. Show the effect itself rather "
    "than a casting hand or a whole character; draw a hand or a figure only when the ability is about one. The "
    "painting fills the whole square edge to edge, with a dark, softly blurred background in matching colours "
    "and no empty margin; no scene and no landscape. Style: match the reference image: a rich, full-colour "
    "fantasy painting like a high-quality MMORPG spell icon, saturated colours, dramatic glowing light, "
    "painterly brushwork and fine detail. Keep the subject whole inside the square. One icon only: a single "
    "square painting, not a grid, a sheet or a set. No text, no letters, no numbers, no runes, no writing, no "
    "border, no frame, no black margin, no rounded corners."
)

# Set B names one palette per spell school. A mixed mask takes its first magic school in the order holy,
# fire, nature, frost, shadow, arcane, as Core/Icons.lua's SchoolColor does; physical counts only alone.
PALETTES = {
    1: "Colours: the subject's own natural colours, such as steel, leather, wood, stone, fur or bone, lit by a "
       "cool white rim light with one accent colour that suits the ability, against a dark smoky background; "
       "no golden glow.",
    2: "Colours: radiant gold, warm white and pale amber holy light.",
    4: "Colours: blazing orange, red and yellow fire against deep ember darkness.",
    8: "Colours: vivid emerald green, teal and bright yellow-green light, or crackling storm blue and white for "
       "lightning and storms.",
    16: "Colours: icy blue, pale cyan and white against deep midnight blue.",
    32: "Colours: deep violet, purple and black, with pale sickly highlights.",
    64: "Colours: brilliant magenta, violet and pale blue arcane light.",
}
PALETTE_ORDER = (2, 4, 8, 16, 32, 64)

HINTS_B = {
    "blank": "Make the subject large, bright and clearly lit against a darker background.",
    "flat": "Use strong contrast: one bright, simple subject against a darker, calmer background.",
    "frame": "Paint all the way to every edge of the square: no border, frame or black margin.",
    "grid": "Paint one single icon that fills the whole square, not a grid or a sheet of several icons.",
    "clipped": "Centre the subject and light it brightly; keep the edges of the square darker than the centre.",
    "text": HINTS["text"],
}

CHECKS_A = "no blank, small, clipped, off-black, coloured or text-bearing image is accepted"
CHECKS_B = ("no blank, flat (unreadable at 32 pixels), framed, grid, off-centre or text-bearing image is "
            "accepted")

# subject_reference: Blizzard's icon is image 1, the action-button strip is image 2. The pilot's v2 prompt.
FAITHFUL_LEAD = (
    'Image 1 is a World of Warcraft ability icon, "{name}". Image 2 shows the target UI style, dark glass action '
    "buttons holding crisp glowing art, and is for finish and mood only: do not copy any subject from image 2. "
    "Repaint image 1 at high resolution keeping the same subject, silhouette, composition, viewing angle, scale and "
    "dominant colours so a player recognises it instantly{subject}. Keep the subject in the same place in the "
    "square. Remove image 1's dark bevelled frame and extend the art to every edge; draw no button, frame or glass "
    "around it. Turn the blurry pixel art into a crisp modern painting; add nothing that is not in image 1."
)
STYLE_FAITHFUL = (
    "Style: a crisp, clean, high-resolution fantasy ability icon for a modern, minimal, dark game UI. Painterly but "
    "clean: smooth confident brushwork, sharp readable edges, strong value contrast, one bright focal point, a dark "
    "near-black backdrop with a soft vignette so the subject pops at small sizes. The art fills the whole square edge "
    "to edge: no frame, no border, no bevel, no rounded corners, no margin. No text, letters, numbers or runes. One "
    "icon only."
)
HINTS_FAITHFUL = {
    "blank": "Keep image 1's subject large and clearly lit against the darker backdrop.",
    "flat": "Keep strong contrast between image 1's subject and the backdrop so it reads at 32 pixels.",
    "frame": "Image 1's bevelled frame must go completely: paint the art to every edge of the square, with no border.",
    "grid": "Paint one single icon that fills the whole square, not a grid or a sheet of several icons.",
    "drift": ("Stay much closer to image 1: copy its silhouette, composition, placement and colours exactly, and "
              "change only the rendering quality."),
    "text": HINTS["text"],
}
CHECKS_FAITHFUL = ("no blank, flat (unreadable at 32 pixels), grid or text-bearing image is accepted, no black "
                   "margin with a hard edge round the painting (a vignette is not a frame), and no repaint whose 8x8 "
                   "light-and-dark layout correlates below 0.6 with Blizzard's icon (drift)")
BUTTONS_REFERENCE = "docs/design/mockups/icons_B_buttons.png"

CLASS_NAMES = {"DEATHKNIGHT": "Death Knight", "DEMONHUNTER": "Demon Hunter"}
RACE_NAMES = {"Scourge": "Undead"}


@dataclass(frozen=True)
class IconSet:
    name: str  # the set: A or B
    addon: str
    xml: str  # the addon's XML load file, which must load Data.lua
    model: str
    reference: str  # repository path of the style reference passed as the last image reference
    style: str
    greyscale: bool
    hints: dict  # reason code -> the fix a reroll adds to the prompt
    floor: float  # credits the generate command leaves unspent by default
    checks: str  # what check_icons rejects, for PROVENANCE.md
    judge: str  # the name of the set's check in check_icons.judge_for
    palette: bool = False  # add the spell school's palette to each prompt
    mode: str = "style"  # style: paint from a text description; subject_reference: repaint Blizzard's icon


SETS = {
    "A": IconSet("A", "KstyleUI_Icons", "Icons.xml", "gpt_image_2_5", "docs/design/mockups/icons_A_luminous.jpg", STYLE_A, True,
                 hints=HINTS, floor=1300.0, checks=CHECKS_A, judge="A"),
    "B": IconSet("B", "KstyleUI_IconsColour", "IconsColour.xml", "gpt_image_2_5", "docs/design/mockups/icons_B_fullcolour.jpg",
                 STYLE_B, False, hints=HINTS_B, floor=60.0, checks=CHECKS_B, judge="B", palette=True),
}


def faithful(icon_set):
    """The set in subject_reference mode: the same addon, repainted from Blizzard's icon in the button strip's finish."""
    return dataclasses.replace(icon_set, mode="subject_reference", judge="faithful", reference=BUTTONS_REFERENCE,
                               style=STYLE_FAITHFUL, hints=HINTS_FAITHFUL, checks=CHECKS_FAITHFUL, palette=False)


def with_mode(icon_set, mode):
    return faithful(icon_set) if mode == "subject_reference" else icon_set

GENERATION_ARGS = ["--aspect_ratio", "1:1", "--resolution", "1k", "--quality", "high"]


class GenerationError(RuntimeError):
    pass


class RateLimited(GenerationError):
    """The account is running its maximum number of jobs; the job did not start and cost nothing."""


# Prompts ---------------------------------------------------------------------------------------

def uses(group, owner):
    """True when a spell of the group belongs to owner, alone or in a comma-separated list of classes."""
    return any(owner in spell["owner"].split(",") for spell in group["spells"])


def ordered_groups(data, categories=None, owner=None):
    wanted = set(categories or CATEGORIES)
    groups = [g for g in data["icons"] if g["category"] in wanted and (owner is None or uses(g, owner))]
    return sorted(groups, key=lambda g: (CATEGORIES.index(g["category"]), g["icon"]))


def primary_spell(group):
    named = [s for s in group["spells"] if s["name"] == group["name"]]
    for spell in named + group["spells"]:
        if spell["description"]:
            return spell, spell["description"]
    return (named or group["spells"])[0], ""


_PREPOSITION = r"(?:by|for|over|within|every|to|up to|after|plus|of|with|at)"
_UNIT = r"(?: (?:yards?|yds|sec|secs|seconds?|min|mins|minutes?|hours?|times|charges?))?"
_STOP = r"(?=[.,;:)]|$| (?:and|or|but|to|that|while|when|if|in|on|at|after|before|per|plus|with|each)\b)"


def clean_description(text):
    """Turn a tooltip with X number placeholders into a short plain description."""
    text = re.sub(r"\s*\bLasts X\b[^.]*\.", "", text)
    text = re.sub(r"\bX% of\b", "part of", text)
    text = re.sub(r"\ba X% chance\b", "a chance", text)
    text = re.sub(r"\bX%? to X%?(?!\w)", "X", text)
    previous = None
    while previous != text:
        previous = text
        text = re.sub(r"\s*\b(?:" + _PREPOSITION + r" )+(?:an additional )?X%?" + _UNIT + _STOP, "", text)
    text = re.sub(r"\bX%?" + _UNIT + r"\s+", "", text)
    text = re.sub(r"\s*\bX%?" + _UNIT + r"(?!\w)", "", text)
    text = re.sub(r"\(\s*\)", "", text)
    text = re.sub(r"\s+([.,;:])", r"\1", text)
    text = re.sub(r"([.,;:])(?=[.,;:])", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > MAX_DESCRIPTION:
        cut = text[:MAX_DESCRIPTION]
        end = cut.rfind(". ")
        text = cut[:end + 1] if end > 0 else cut[:cut.rfind(" ")].rstrip(",;:") + "."
    return text


def school_phrase(mask):
    names = [name for bit, name in sorted(SCHOOLS.items()) if mask & bit] or ["Physical"]
    if len(names) > 1:
        return ", ".join(names[:-1]) + " and " + names[-1]
    return names[0]


def _article(word):
    return "an" if word[:1].upper() in "AEIOU" else "a"


def _split_camel(name):
    return re.sub(r"(?<=[a-z])(?=[A-Z])", " ", name)


def owner_phrase(group, spell):
    category, owner, line = group["category"], spell["owner"], spell["line"]
    if category == "class":
        name = CLASS_NAMES.get(owner, owner.title())
        return f"{_article(name)} {name} ability"
    if category == "pet":
        name = CLASS_NAMES.get(owner, owner.title()) if owner != "PET" else "pet"
        lead = f"{_article(name)} {name} pet ability" if owner != "PET" else "a pet ability"
        family = line[len("Pet - "):] if line.startswith("Pet - ") else ""
        return f"{lead} of the {family}" if family and not family.startswith("Event") else lead
    if category == "racial":
        name = RACE_NAMES.get(owner, _split_camel(owner))
        return f"{_article(name)} {name} racial ability"
    if category == "profession":
        return f"{_article(owner)} {owner} profession skill"
    return "a general skill"


def lead_for(group):
    spell, description = primary_spell(group)
    lead = (
        f'Fantasy game ability icon for "{group["name"]}", {owner_phrase(group, spell)} '
        f"({school_phrase(group['school'])} school)."
    )
    description = clean_description(description)
    return f"{lead} What it does: {description}" if description else lead


def palette_for(mask):
    for bit in PALETTE_ORDER:
        if mask & bit:
            return PALETTES[bit]
    return PALETTES[1]


def load_subjects(path=SUBJECTS):
    """Hand-checked subject sentences by file ID, for icons the Blizzard reference alone does not carry."""
    path = Path(path)
    if not path.exists():
        return {}
    return {int(icon): sentence for icon, sentence in json.loads(path.read_text()).items()}


def faithful_lead(group, subjects=None):
    sentence = (subjects or {}).get(group["icon"], "")
    return FAITHFUL_LEAD.format(name=group["name"], subject=f": {sentence}" if sentence else "")


def prompt_for(icon_set, group, reasons=(), subjects=None):
    """Return (lead, prompt): the icon's own part, with its palette and any reroll fixes, and the full prompt."""
    if icon_set.mode == "subject_reference":
        lead = faithful_lead(group, subjects)
    else:
        lead = lead_for(group)
    if icon_set.palette:
        lead = f"{lead} {palette_for(group['school'])}"
    fixes = []
    for reason in reasons:
        hint = icon_set.hints.get(reason.split(":")[0])
        if hint and hint not in fixes:
            fixes.append(hint)
    if fixes:
        lead = f"{lead} {' '.join(fixes)}"
    return lead, f"{lead} {icon_set.style}"


# Records ---------------------------------------------------------------------------------------

def load_record(raw_dir, group):
    path = Path(raw_dir) / f"{group['icon']}.json"
    if path.exists():
        return json.loads(path.read_text())
    return {"icon": group["icon"], "name": group["name"], "category": group["category"], "attempts": [], "rerollFrom": 0}


def save_record(raw_dir, record):
    path = Path(raw_dir) / f"{record['icon']}.json"
    fd, tmp = tempfile.mkstemp(dir=raw_dir, suffix=".tmp")
    with os.fdopen(fd, "w") as handle:
        json.dump(record, handle, indent=1)
    os.replace(tmp, path)


def mode_of(attempt):
    return attempt.get("mode", "style")


def _window(record, mode=None):
    """The attempts that count: those after an owner's reroll, and with mode only that mode's attempts. A
    style run also counts an accepted repaint, so it never paints over one; a subject_reference run does
    not count a style image, so it repaints it."""
    attempts = record["attempts"][record.get("rerollFrom", 0):]
    if mode is None:
        return attempts
    return [a for a in attempts if mode_of(a) == mode or (mode == "style" and a["verdict"] == "accepted")]


def accepted_attempt(record):
    """The latest accepted attempt of any mode: a repaint replaces the style image once it is accepted."""
    for attempt in reversed(_window(record)):
        if attempt["verdict"] == "accepted":
            return attempt
    return None


def next_step(record, mode=None):
    window = _window(record, mode)
    if any(a["verdict"] == "accepted" for a in window):
        return "done"
    images = sum(1 for a in window if a["verdict"] != "failed")
    failures = sum(1 for a in window if a["verdict"] == "failed")
    if images >= MAX_IMAGES or failures >= MAX_FAILURES:
        return "exhausted"
    return "generate"


def _last_reasons(record, mode=None):
    for attempt in reversed(_window(record, mode)):
        if attempt["verdict"] == "rejected":
            return attempt["reasons"]
    return ()


# Credits ---------------------------------------------------------------------------------------

class Budget:
    """Lets a job start only while the estimated balance stays at or above the floor after it."""

    def __init__(self, balance, floor, cost, refresh_every, log):
        self._balance_fn, self.floor, self.cost, self.refresh_every, self.log = balance, floor, cost, refresh_every, log
        self._lock = threading.Lock()
        self.started = 0
        self.stopped = False
        self._refresh()

    def _refresh(self):
        self.balance = float(self._balance_fn())
        self._spent = 0
        self._in_flight_at_refresh = getattr(self, "in_flight", 0)
        self.in_flight = self._in_flight_at_refresh
        self._refreshed_at = self.started
        self.log(f"credits: {self.balance:.2f} (floor {self.floor})")

    def _available(self):
        return self.balance - (self._spent + self.in_flight) * self.cost

    def reserve(self):
        with self._lock:
            if self.stopped:
                return False
            if self.started and self.started % self.refresh_every == 0 and self._refreshed_at != self.started:
                self._refresh()
            if self._available() - self.cost < self.floor:
                self._refresh()
                if self._available() - self.cost < self.floor:
                    self.stopped = True
                    self.log(f"credits: stopping at the floor of {self.floor}")
                    return False
            self.in_flight += 1
            self.started += 1
            return True

    def settle(self):
        with self._lock:
            self.in_flight -= 1
            self._spent += 1

    def stop(self):
        with self._lock:
            self.stopped = True

    def release(self):
        """Return a reservation whose job never started."""
        with self._lock:
            self.in_flight -= 1
            self.started -= 1


# Generation ------------------------------------------------------------------------------------

def _start_job(runner, prompt, references, budget, sleep):
    """Run one job, waiting out the account's concurrency limit; None when the floor stops it."""
    for tries in range(RATE_LIMIT_TRIES):
        if not budget.reserve():
            return None
        try:
            return runner(prompt, references)
        except RateLimited:
            budget.release()
            sleep(RATE_LIMIT_WAIT * (1 + tries % 4))
        except BaseException:
            budget.settle()
            raise
    raise GenerationError(f"still rate limited after {RATE_LIMIT_TRIES} tries")


def _attempt_icon(group, icon_set, raw_dir, runner, fetch, judge, budget, today, reroll, log, sleep, sources=None,
                  subjects=None):
    record = load_record(raw_dir, group)
    if reroll:
        record["rerollFrom"] = len(record["attempts"])
        save_record(raw_dir, record)
    mode = icon_set.mode
    while next_step(record, mode) == "generate":
        n = len(record["attempts"]) + 1
        lead, prompt = prompt_for(icon_set, group, _last_reasons(record, mode), subjects)
        attempt = {"n": n, "model": icon_set.model, "mode": mode, "lead": lead, "prompt": prompt, "date": today}
        references = []
        if mode == "subject_reference":
            source = (sources or {}).get(group["icon"])
            if source is None:
                log(f"{group['icon']} {group['name']}: skipped, no Blizzard icon in the cache (run iconset.py extract)")
                return record
            attempt["source"] = {"fileID": group["icon"], "blp_sha256": source["blp_sha256"]}
            references = [source["png"]]
        try:
            job = _start_job(runner, prompt, references, budget, sleep)
        except GenerationError as error:
            job = None
            attempt.update(verdict="failed", error=str(error))
        if job is None and "error" not in attempt:
            return record
        if job is not None:
            try:
                image = f"{group['icon']}-{n}.png"
                fetch(job["url"], Path(raw_dir) / image)
                reasons = list(judge(Path(raw_dir) / image))
                attempt.update(job=job["id"], url=job["url"], image=image, reasons=reasons,
                               verdict="rejected" if reasons else "accepted")
            except GenerationError as error:
                attempt.update(job=job["id"], url=job["url"], image=image, verdict="failed", error=str(error))
            finally:
                budget.settle()
        record["attempts"].append(attempt)
        save_record(raw_dir, record)
        detail = attempt.get("error") or ", ".join(attempt.get("reasons", [])) or "ok"
        log(f"{group['icon']} {group['name']}: attempt {n} {attempt['verdict']} ({detail})")
    return record


def rejudge_groups(groups, icon_set, raw_dir):
    """The groups that have an image of the set's mode to re-check."""
    return [g for g in groups if any(mode_of(a) == icon_set.mode and a["verdict"] != "failed" and "image" in a
                                     for a in load_record(raw_dir, g)["attempts"])]


def rejudge(groups, icon_set, raw_dir, *, judge, today, log=print):
    """Re-run the set's check on every image of the set's mode, after the check changed. Returns the
    (icon, image, old reasons, new reasons) of each attempt whose verdict changed; each is stamped rejudged."""
    changed = []
    for group in groups:
        record = load_record(raw_dir, group)
        for attempt in record["attempts"]:
            if mode_of(attempt) != icon_set.mode or attempt["verdict"] == "failed" or "image" not in attempt:
                continue
            reasons = list(judge(Path(raw_dir) / attempt["image"]))
            verdict = "rejected" if reasons else "accepted"
            if verdict == attempt["verdict"] and reasons == attempt.get("reasons", []):
                continue
            changed.append((group["icon"], attempt["image"], attempt.get("reasons", []), reasons))
            attempt.update(reasons=reasons, verdict=verdict, rejudged=today)
            log(f"{group['icon']} {group['name']}: {attempt['image']} {attempt['verdict']} ({', '.join(reasons) or 'ok'})")
        if any(a.get("rejudged") == today for a in record["attempts"]):
            save_record(raw_dir, record)
    return changed


def summarise(groups, raw_dir, stopped_at_floor=False, mode=None):
    summary = {"accepted": 0, "generated": 0, "rejected": 0, "rerolled": 0, "failed": 0,
               "missing": [], "pending": [], "stopped_at_floor": stopped_at_floor}
    for group in groups:
        record = load_record(raw_dir, group)
        attempts = record["attempts"] if mode is None else [a for a in record["attempts"] if mode_of(a) == mode]
        images = [a for a in attempts if a["verdict"] != "failed"]
        summary["generated"] += len(images)
        summary["rejected"] += sum(1 for a in images if a["verdict"] == "rejected")
        summary["failed"] += sum(1 for a in attempts if a["verdict"] == "failed")
        summary["rerolled"] += sum(1 for i, a in enumerate(images) if i > 0 and images[i - 1]["verdict"] == "rejected")
        step = next_step(record, mode)
        if step == "done":
            summary["accepted"] += 1
        elif step == "exhausted":
            summary["missing"].append(group["icon"])
        else:
            summary["pending"].append(group["icon"])
    return summary


def generate(groups, icon_set, raw_dir, *, runner, fetch, judge, balance, today, jobs=DEFAULT_JOBS, floor=1300.0,
             cost=1.5, refresh_every=100, limit=None, reroll=frozenset(), log=print, sleep=time.sleep, sources=None,
             subjects=None):
    """Generate every group that is not finished in the set's mode; return summarise() for the groups.

    sources maps a file ID to its extracted Blizzard icon ({"png", "blp_sha256"}) for subject_reference mode."""
    raw_dir = Path(raw_dir)
    raw_dir.mkdir(parents=True, exist_ok=True)
    jobs = max(1, min(MAX_JOBS, jobs))
    todo = [g for g in groups if g["icon"] in reroll or next_step(load_record(raw_dir, g), icon_set.mode) == "generate"]
    if limit is not None:
        todo = todo[:limit]
    budget = Budget(balance, floor, cost, refresh_every, log)
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        futures = []
        try:
            for g in todo:
                futures.append(pool.submit(_attempt_icon, g, icon_set, raw_dir, runner, fetch, judge, budget, today,
                                           g["icon"] in reroll, log, sleep, sources, subjects))
            for future in futures:
                future.result()
        except BaseException:
            budget.stop()
            for future in futures:
                future.cancel()
            raise
    return summarise(groups, raw_dir, budget.stopped, icon_set.mode)


# Higgsfield ------------------------------------------------------------------------------------

def _higgsfield(*args, timeout=900):
    result = subprocess.run(["higgsfield", *args], capture_output=True, text=True, timeout=timeout)
    if result.returncode != 0:
        if "rate_limit_reached" in result.stderr:
            raise RateLimited("rate_limit_reached")
        raise GenerationError(f"higgsfield {args[0]} {args[1]} failed: {result.stderr.strip()[-300:]}")
    return json.loads(result.stdout)


def account_balance():
    return float(_higgsfield("account", "status", "--json", timeout=60)["credits"])


def reference_id(icon_set, work_dir):
    """Upload the style reference once and reuse its upload ID while the file is unchanged."""
    path = REPO / icon_set.reference
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    cache = Path(work_dir) / "reference.json"
    known = json.loads(cache.read_text()) if cache.exists() else {}
    if digest not in known:
        known[digest] = _higgsfield("upload", "create", str(path), "--json", timeout=300)["id"]
        cache.write_text(json.dumps(known, indent=1))
    return known[digest]


def higgsfield_runner(icon_set, reference):
    """Run one job. The style reference is always the last image reference; subject_reference mode passes
    the Blizzard icon before it, so the prompt's image 1 is the subject and image 2 the finish."""
    def run(prompt, references=()):
        command = ["generate", "create", icon_set.model, "--prompt", prompt, *GENERATION_ARGS]
        for image in [*references, reference]:
            command += ["--image-references", str(image)]
        try:
            jobs = _higgsfield(*command, "--wait", "--json")
        except subprocess.TimeoutExpired as error:
            raise GenerationError("timed out waiting for the job") from error
        job = jobs[0] if isinstance(jobs, list) and jobs else {}
        if job.get("status") != "completed" or not job.get("result_url"):
            raise GenerationError(f"job {job.get('id')} ended {job.get('status')}")
        return {"id": job["id"], "url": job["result_url"]}
    return run


def make_judge(text=True, check=None, icon_set=None, sources=None):
    """Wrap the set's check_icons check so a broken download or helper error becomes a recorded GenerationError.
    The faithful check also gets the raster of the icon's Blizzard original from sources."""
    if check is None:
        import check_icons as check
    icon_set = icon_set or SETS["A"]
    name = icon_set.judge

    def judge(path):
        try:
            texts = check.read_text([path]).get(str(path), ()) if text else ()
            raster = check.load_raster(path)
            if name == "faithful":
                icon = int(Path(path).stem.split("-")[0])
                reference = check.load_raster((sources or {})[icon]["png"])
                return check.judge_for(name)(raster, texts, reference=reference)
            return check.judge_for(name)(raster, texts)
        except (check.OcrError, OSError, ValueError) as error:
            raise GenerationError(f"image check failed: {error}") from error

    return judge


def download(url, path):
    if not url.startswith("https://"):
        raise GenerationError(f"refusing a non-https result URL: {url}")
    path = Path(path)
    tmp = path.with_suffix(".part")
    try:
        with urllib.request.urlopen(url, timeout=120) as response, open(tmp, "wb") as handle:
            handle.write(response.read())
    except OSError as error:
        raise GenerationError(f"download failed: {error}") from error
    os.replace(tmp, path)


# Blizzard's icons ------------------------------------------------------------------------------

class ExtractError(RuntimeError):
    pass


def tacttool_command(icon, blp, tacttool=TACTTOOL, wow_dir=WOW_DIR):
    return [str(tacttool), "-p", TACT_PRODUCT, "-r", TACT_REGION, "-d", str(wow_dir), "-m", "id", "-i", str(icon),
            "-o", str(blp)]


def run_tacttool(icon, blp):
    """Extract one file by ID. TACTTool only reads the game folder; its own cache goes beside the BLP."""
    blp = Path(blp)
    cache = blp.parent / "tact"
    cache.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(tacttool_command(icon, blp.resolve()), cwd=cache, capture_output=True, text=True, timeout=300)
    if result.returncode != 0:
        raise ExtractError(f"TACTTool failed for {icon}: {(result.stderr or result.stdout).strip()[-300:]}")


def decode_blp(blp, png, size=REFERENCE_SIZE):
    """Decode a BLP with Pillow, composite it over black and upscale it to size for the model."""
    Image, _ = _pillow()
    with Image.open(blp) as image:
        rgba = image.convert("RGBA")
        black = Image.new("RGBA", rgba.size, (0, 0, 0, 255))
        flat = Image.alpha_composite(black, rgba).convert("RGB")
        flat.resize((size, size), Image.LANCZOS).save(png, optimize=True)


def extract_icon(icon, cache_dir, tool=run_tacttool, decode=decode_blp):
    """Return {"png", "blp_sha256"} for a file ID, extracting and decoding it once into cache_dir."""
    cache_dir = Path(cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)
    blp, png = cache_dir / f"{icon}.blp", cache_dir / f"{icon}.png"
    if not blp.exists():
        tool(icon, blp)
        if not blp.exists():
            raise ExtractError(f"TACTTool wrote no file for {icon}")
    if not png.exists():
        decode(blp, png)
    return {"png": str(png), "blp_sha256": hashlib.sha256(blp.read_bytes()).hexdigest()}


def extract_all(groups, cache_dir=BLIZZARD, log=print):
    """Extract the Blizzard icon of every group; return the sources map for generate. A missing icon is logged."""
    sources, missing = {}, []
    for group in groups:
        try:
            sources[group["icon"]] = extract_icon(group["icon"], cache_dir)
        except (ExtractError, OSError, subprocess.TimeoutExpired) as error:
            missing.append(group["icon"])
            log(f"{group['icon']} {group['name']}: {error}")
    log(f"blizzard icons: {len(sources)} in {cache_dir}" + (f", {len(missing)} missing" if missing else ""))
    return sources


# Packaging -------------------------------------------------------------------------------------

def accepted_entries(groups, raw_dir):
    entries = []
    for group in groups:
        attempt = accepted_attempt(load_record(raw_dir, group))
        if attempt:
            entries.append({"group": group, "attempt": attempt})
    return sorted(entries, key=lambda e: e["group"]["icon"])


def texture_path(icon_set, icon):
    return f"Interface\\AddOns\\{icon_set.addon}\\Icons\\{icon}.png"


def render_data_lua(icon_set, entries):
    entries = sorted(entries, key=lambda e: e["group"]["icon"])
    lines = [
        f"-- Data.lua: icon set {icon_set.name}, the table from icon file ID to texture path that KstyleUI.Icons reads; "
        "Tools/icons/iconset.py writes it.",
        "_G.KstyleUIIconData = {",
        f'\tset = "{icon_set.name}",',
        "\ticons = {",
    ]
    for entry in entries:
        icon = entry["group"]["icon"]
        lua_path = texture_path(icon_set, icon).replace("\\", "\\\\")
        lines.append(f'\t\t[{icon}] = "{lua_path}",')
    lines += ["\t},", "\tschools = {"]
    for entry in entries:
        lines.append(f"\t\t[{entry['group']['icon']}] = {entry['group']['school']},")
    lines += ["\t},", "}", ""]
    return "\r\n".join(lines)


DATA_SCRIPT = '<Script file="Data.lua"/>'


def include_data(xml_text):
    """Add Data.lua as the last script of an addon's CRLF XML load file, once."""
    if DATA_SCRIPT in xml_text:
        return xml_text
    end = xml_text.rindex("</Ui>")
    return f"{xml_text[:end]}\t{DATA_SCRIPT}\r\n{xml_text[end:]}"


def spell_names(group):
    names = []
    for spell in [{"name": group["name"]}] + group["spells"]:
        if spell["name"] not in names:
            names.append(spell["name"])
    return ", ".join(names)


def _cell(text):
    return str(text).replace("|", "\\|").replace("\n", " ")


def render_provenance(icon_set, entries):
    entries = sorted(entries, key=lambda e: e["group"]["icon"])
    tone = "luminance only (RGB PNG with R = G = B)" if icon_set.greyscale else "full colour (RGB PNG)"
    repaint = faithful(icon_set)
    repainted = any(mode_of(e["attempt"]) == "subject_reference" for e in entries)
    lines = [
        f"# {icon_set.addon} provenance",
        "",
        f"Icon set {icon_set.name}. Every icon in `Icons/` has a row below. `Tools/icons/iconset.py package` writes this "
        "file and the icons from the generation records; do not edit it by hand.",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| Model | Higgsfield `{icon_set.model}` |",
        f"| Settings | `{' '.join(GENERATION_ARGS)}` |",
        f"| Style reference | `{icon_set.reference}`, passed as `image_references` |",
        "| Seed | The model exposes none; the Higgsfield job ID identifies each image |",
        f"| Post-processing | Pillow: Lanczos downscale from 1024 to {ICON_SIZE} pixels, {tone} |",
        f"| Checks | `Tools/icons/check_icons.py --set {icon_set.name}`: {icon_set.checks} |",
        "",
        "Each `style` prompt is the row's prompt text followed by this style block:",
        "",
        "```text",
        icon_set.style,
        "```",
    ]
    if repainted:
        lines += [
            "",
            "## Repainted from Blizzard's icon (`subject_reference`)",
            "",
            "| Field | Value |",
            "| --- | --- |",
            f"| Blizzard source | The icon's BLP2 texture, read by file ID from the installed WoW Forever client "
            f"(`{WOW_DIR}`, product `{TACT_PRODUCT}`) with TACTTool (`iconset.py extract`, read-only), decoded with "
            f"Pillow, composited over black and upscaled to {REFERENCE_SIZE} pixels. The row's sha256 is the BLP's. "
            "No Blizzard file is in this repository. |",
            f"| Image references | 1: the Blizzard icon (the subject); 2: `{repaint.reference}`, the action-button strip "
            "(finish only) |",
            f"| Checks | `Tools/icons/check_icons.py --set faithful`: {repaint.checks} |",
            "",
            "Each `subject_reference` prompt is the row's prompt text followed by this style block:",
            "",
            "```text",
            repaint.style,
            "```",
        ]
    lines += [
        "",
        "| File ID | Spells | Model | Method | Prompt | Blizzard BLP sha256 | Job | Date |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for entry in entries:
        group, attempt = entry["group"], entry["attempt"]
        digest = attempt.get("source", {}).get("blp_sha256", "")
        lines.append(
            f"| `{group['icon']}` | {_cell(spell_names(group))} | {attempt['model']} | {mode_of(attempt)} "
            f"| {_cell(attempt['lead'])} | {digest} | {attempt['job']} | {attempt['date']} |"
        )
    return "\n".join(lines) + "\n"


def _pillow():
    try:
        from PIL import Image, ImageDraw
    except ImportError as error:
        raise SystemExit("iconset: Pillow is missing. Run with ~/.local/share/wow-dev/venv/bin/python.") from error
    return Image, ImageDraw


def downscale(source, target, greyscale):
    Image, _ = _pillow()
    with Image.open(source) as image:
        image = image.convert("L" if greyscale else "RGB")
        image = image.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
        image.convert("RGB").save(target, optimize=True)


def package(icon_set, groups, raw_dir, repo=REPO, data=True, log=print):
    addon = Path(repo) / icon_set.addon
    icons = addon / "Icons"
    icons.mkdir(parents=True, exist_ok=True)
    entries = accepted_entries(groups, raw_dir)
    keep = set()
    for entry in entries:
        icon = entry["group"]["icon"]
        keep.add(f"{icon}.png")
        downscale(Path(raw_dir) / entry["attempt"]["image"], icons / f"{icon}.png", icon_set.greyscale)
    for stale in icons.glob("*.png"):
        if stale.name not in keep:
            stale.unlink()
    (addon / "PROVENANCE.md").write_text(render_provenance(icon_set, entries))
    if data:
        with open(addon / "Data.lua", "w", newline="") as handle:
            handle.write(render_data_lua(icon_set, entries))
        xml = addon / icon_set.xml
        xml.write_bytes(include_data(xml.read_bytes().decode("ascii")).encode("ascii"))
    log(f"packaged {len(entries)} icons into {addon}")
    return entries


def _png_header(path):
    head = Path(path).read_bytes()[:33]
    if len(head) < 33 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    width, height, depth, colour = struct.unpack(">IIBB", head[16:26])
    return width, height, depth, colour


def _luminance_only(path):
    """True when every pixel of a 128x128 8-bit RGB PNG has R = G = B. PNG filters work on each channel
    alone, so the filtered bytes of a pixel match exactly when its channels do: no unfiltering needed."""
    data, rows, at = Path(path).read_bytes(), b"", 8
    while at + 8 <= len(data):
        length, kind = struct.unpack(">I4s", data[at:at + 8])
        if kind == b"IDAT":
            rows += data[at + 8:at + 8 + length]
        at += length + 12
    try:
        raw = zlib.decompress(rows)
    except zlib.error:
        return False
    stride = ICON_SIZE * 3 + 1
    for start in range(0, len(raw), stride):
        row = raw[start + 1:start + stride]
        if row[0::3] != row[1::3] or row[0::3] != row[2::3]:
            return False
    return len(raw) == stride * ICON_SIZE


def verify_package(icon_set, groups, repo=REPO):
    """List what is wrong with the packaged set: PNG format, file IDs, provenance rows and Data.lua."""
    addon = Path(repo) / icon_set.addon
    icons_dir = addon / "Icons"
    known = {g["icon"]: g for g in groups}
    problems, present = [], {}
    for path in sorted(icons_dir.iterdir()) if icons_dir.is_dir() else []:
        match = re.fullmatch(r"(\d+)\.png", path.name)
        if not match:
            problems.append(f"Icons/{path.name} is not <fileID>.png")
            continue
        icon = int(match.group(1))
        present[icon] = path
        header = _png_header(path)
        if header is None:
            problems.append(f"Icons/{path.name} is not a PNG")
            continue
        width, height, depth, colour = header
        if (width, height) != (ICON_SIZE, ICON_SIZE):
            problems.append(f"Icons/{path.name} is {width}x{height}, not {ICON_SIZE}x{ICON_SIZE}")
        if (depth, colour) != (8, 2):
            problems.append(f"Icons/{path.name} is not an 8-bit RGB PNG")
        elif icon_set.greyscale and (width, height) == (ICON_SIZE, ICON_SIZE) and not _luminance_only(path):
            problems.append(f"Icons/{path.name} is not luminance only")
        if icon not in known:
            problems.append(f"Icons/{path.name} is not an icon file ID in Tools/data/abilities.json")

    provenance = addon / "PROVENANCE.md"
    rows = set()
    if provenance.exists():
        rows = {int(m) for m in re.findall(r"^\| `(\d+)` \|", provenance.read_text(), re.MULTILINE)}
    elif present:
        problems.append("PROVENANCE.md is missing")
    for icon in sorted(present):
        if icon not in rows:
            problems.append(f"Icons/{icon}.png has no row in PROVENANCE.md")
    for icon in sorted(rows - set(present)):
        problems.append(f"PROVENANCE.md has a row for {icon} but Icons/{icon}.png is missing")

    data = addon / "Data.lua"
    if data.exists():
        expected = render_data_lua(icon_set, [{"group": known[i]} for i in present if i in known])
        if data.read_bytes() != expected.encode("ascii"):
            problems.append("Data.lua does not match the icons in Icons/: run iconset.py package")
        xml = addon / icon_set.xml
        if not xml.exists() or DATA_SCRIPT not in xml.read_text():
            problems.append(f"Data.lua exists but {icon_set.xml} does not load it")
    return problems


def contact_sheets(icon_set, groups, raw_dir, out_dir, log=print):
    """Write sheets of 64 accepted icons at full and 32-pixel size, captioned with the file ID."""
    Image, ImageDraw = _pillow()
    entries = [e for g in groups for e in accepted_entries([g], raw_dir)]
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    tile_w, tile_h = ICON_SIZE + 40, ICON_SIZE + 16
    for start in range(0, len(entries), SHEET_ICONS):
        chunk = entries[start:start + SHEET_ICONS]
        rows = (len(chunk) + SHEET_COLUMNS - 1) // SHEET_COLUMNS
        sheet = Image.new("RGB", (SHEET_COLUMNS * tile_w, rows * tile_h), (24, 24, 24))
        draw = ImageDraw.Draw(sheet)
        for i, entry in enumerate(chunk):
            x, y = (i % SHEET_COLUMNS) * tile_w, (i // SHEET_COLUMNS) * tile_h
            with Image.open(Path(raw_dir) / entry["attempt"]["image"]) as image:
                mode = "L" if icon_set.greyscale else "RGB"
                big = image.convert(mode).resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
                small = image.convert(mode).resize((32, 32), Image.LANCZOS)
            sheet.paste(big.convert("RGB"), (x, y))
            sheet.paste(small.convert("RGB"), (x + ICON_SIZE + 4, y))
            draw.text((x + 2, y + ICON_SIZE + 2), f"{entry['group']['icon']} {entry['group']['name']}"[:24], fill=(200, 200, 200))
        path = out_dir / f"sheet-{start // SHEET_ICONS + 1:02d}.png"
        sheet.save(path)
        log(f"wrote {path}")


# Command line ----------------------------------------------------------------------------------

def _load_groups(args):
    data = json.loads(ABILITIES.read_text())
    categories = args.categories.split(",") if getattr(args, "categories", None) else None
    unknown = set(categories or ()) - set(CATEGORIES)
    if unknown:
        raise SystemExit(f"iconset: unknown categories: {', '.join(sorted(unknown))}")
    return ordered_groups(data, categories, getattr(args, "owner", None))


def _print_summary(summary):
    print(
        f"accepted {summary['accepted']}, generated {summary['generated']}, rejected {summary['rejected']}, "
        f"rerolled {summary['rerolled']}, failed jobs {summary['failed']}, missing {len(summary['missing'])}, "
        f"pending {len(summary['pending'])}"
    )
    if summary["missing"]:
        print("missing: " + " ".join(str(i) for i in summary["missing"]))
    if summary["stopped_at_floor"]:
        print("stopped at the credit floor")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("extract", "generate", "rejudge", "status", "package", "sheets", "verify"):
        command = sub.add_parser(name)
        command.add_argument("--set", default="A", choices=sorted(SETS))
        if name not in ("package", "verify"):  # package writes the whole set: a filtered package would drop the rest
            command.add_argument("--categories", help="comma-separated subset of " + ",".join(CATEGORIES))
            command.add_argument("--owner", help="keep the icon groups with a spell this class uses, such as WARRIOR")
        command.add_argument("--work-dir", type=Path, default=None, help="default ~/.local/share/wow-dev/icons/<set>")
        if name in ("extract", "generate", "rejudge"):
            command.add_argument("--blizzard-dir", type=Path, default=BLIZZARD, help="cache of extracted Blizzard icons")
        if name in ("generate", "rejudge", "status"):
            command.add_argument("--mode", default="style", choices=MODES,
                                 help="style paints from the tooltip; subject_reference repaints Blizzard's icon")
        if name in ("generate", "rejudge"):
            command.add_argument("--no-text", action="store_true", help="skip the macOS Vision text check")
        if name == "generate":
            command.add_argument("--jobs", type=int, default=DEFAULT_JOBS, choices=range(1, MAX_JOBS + 1), metavar="1-12")
            command.add_argument("--floor", type=float, default=None, help="credits to leave unspent (default: the set's floor)")
            command.add_argument("--cost", type=float, default=1.5, help="credits per image")
            command.add_argument("--limit", type=int, help="generate at most this many icons")
            command.add_argument("--reroll", type=int, nargs="*", default=[], help="file IDs to generate afresh")
            command.add_argument("--dry-run", action="store_true", help="print the work and its cost, spend nothing")
        if name == "package":
            command.add_argument("--no-data", action="store_true", help="write the icons and PROVENANCE.md only")
    args = parser.parse_args(argv)

    icon_set = with_mode(SETS[args.set], getattr(args, "mode", "style"))
    if getattr(args, "floor", None) is None:
        args.floor = icon_set.floor
    work = args.work_dir or WORK / icon_set.name
    raw = work / "raw"
    groups = _load_groups(args)

    if args.command == "extract":
        sources = extract_all(groups, args.blizzard_dir)
        return 0 if len(sources) == len(groups) else 1
    if args.command == "status":
        _print_summary(summarise(groups, raw, mode=icon_set.mode))
    elif args.command == "rejudge":
        import check_icons

        if not args.no_text:
            check_icons.ocr_binary()
        groups = rejudge_groups(groups, icon_set, raw)
        sources = extract_all(groups, args.blizzard_dir) if icon_set.mode == "subject_reference" else None
        changed = rejudge(groups, icon_set, raw, judge=make_judge(text=not args.no_text, icon_set=icon_set, sources=sources),
                          today=datetime.date.today().isoformat())
        print(f"rejudged: {len(changed)} verdicts changed")
        _print_summary(summarise(groups, raw, mode=icon_set.mode))
    elif args.command == "package":
        package(icon_set, groups, raw, data=not args.no_data)
    elif args.command == "sheets":
        contact_sheets(icon_set, groups, raw, work / "sheets")
    elif args.command == "verify":
        problems = verify_package(icon_set, groups)
        for problem in problems:
            print(f"{icon_set.addon}: {problem}")
        return 1 if problems else 0
    else:
        import check_icons

        subjects = load_subjects()
        todo = [g for g in groups if g["icon"] in args.reroll or next_step(load_record(raw, g), icon_set.mode) == "generate"]
        todo = todo[:args.limit] if args.limit is not None else todo
        if args.dry_run:
            print(f"{len(todo)} icons to generate, about {len(todo) * args.cost:.1f} credits before rerolls; "
                  f"the run stops before the balance falls below {args.floor:g}")
            for group in todo[:5]:
                print(prompt_for(icon_set, group, subjects=subjects)[1])
            return 0
        raw.mkdir(parents=True, exist_ok=True)
        if not args.no_text:
            check_icons.ocr_binary()
        sources = extract_all(todo, args.blizzard_dir) if icon_set.mode == "subject_reference" else None

        summary = generate(
            groups, icon_set, raw,
            runner=higgsfield_runner(icon_set, reference_id(icon_set, work)),
            fetch=download, judge=make_judge(text=not args.no_text, icon_set=icon_set, sources=sources),
            balance=account_balance, today=datetime.date.today().isoformat(), jobs=args.jobs, floor=args.floor,
            cost=args.cost, limit=args.limit, reroll=set(args.reroll), sources=sources, subjects=subjects,
        )
        _print_summary(summary)
        print(f"credits now: {account_balance():.2f}")
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    sys.exit(main())
