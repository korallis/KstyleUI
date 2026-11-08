"""Generate, check and package a custom icon set from Tools/data/abilities.json and Tools/data/items.json.

Usage (run with a Python that has Pillow, such as ~/.local/share/wow-dev/venv/bin/python):
    iconset.py extract  [--owner WARRIOR] [--race Orc] [--categories class,pet]
    iconset.py generate [--set A|B] [--mode style|subject_reference] [--owner WARRIOR] [--race Orc] [--jobs 8]
                        [--floor N] [--limit N] [--categories class,pet] [--reroll FILEID ...] [--dry-run]
    iconset.py rejudge  [--set A|B] [--mode ...] [--owner ...]
    iconset.py status   [--set A|B] [--mode ...]
    iconset.py package  [--set A|B] [--no-data]
    iconset.py sheets   [--set A|B]
    iconset.py verify   [--set A|B]
    iconset.py derive   [--owner WARRIOR] [--race Orc] [--categories class,pet] [--force]
    iconset.py accept   [--set A|B] [--mode ...] [--attempt N] [--note TEXT] FILEID ...

Set A is white light art on black, tinted in game (KstyleUI_Icons). Set B is full-colour painted art
that fills the square (KstyleUI_IconsColour); its prompts also name a palette for the spell school.

--mode subject_reference repaints Blizzard's own icon instead of painting from a text description, so
a player recognises the ability. extract reads each icon from the installed WoW Forever client by file
ID with TACTTool (read-only) into ~/.local/share/wow-dev/icons/blizzard/<fileID>.png, 512 px. The
prompt then gets two image references: the Blizzard icon (image 1, the subject) and the action-button
strip docs/design/mockups/icons_B_buttons.png (image 2, finish only). Tools/data/icon_subjects.json
may add a hand-checked subject sentence for an icon the reference alone does not carry.
--owner WARRIOR keeps the icon groups a character of that class sees: the class's spells, general spells
for ALL, every profession skill, every item and, with --race Orc, that race's racials. Tools/icons/items.py
builds items.json: one group per item icon file ID with the category item and a rank, the order the
generator draws them in; an icon a spell uses keeps the spell's group. rejudge re-runs the mode's
check on the images it already has, after the check changes, and stamps each changed verdict; for set A
in style mode that includes the art derived from set B.

generate makes one 1:1 image per icon group with Higgsfield, in category order (class, pet, racial,
profession, general, item; items by rank, then by how many items share the icon), up to --jobs at a time (at most 12; the plus plan runs 8 and the run waits out
its rate limit). Each image goes through the set's check in check_icons (judge for A, judge_colour
for B, judge_faithful for subject_reference, which also rejects a repaint that drifts from Blizzard's
icon); a rejected icon is rerolled at most twice, with a fix for the reasons added to its prompt. Raw
images and one JSON record per icon live outside the repository in ~/.local/share/wow-dev/icons/<set>/raw,
so a rerun skips finished icons. Each attempt records its mode; a subject_reference run repaints an
icon whose accepted image came from a style run, and the style image stays in the package until a
repaint is accepted. The run reads the credit balance at the start and every 100 images, and
stops before a job would take the balance below --floor (set A 1300, set B 60 by default). --reroll makes a fresh attempt for icons the
owner marked on a contact sheet, even when they were accepted. accept records a reviewer's decision on a
rejected image after comparing it with Blizzard's icon by eye: the latest image of the mode (or --attempt N)
becomes accepted, the check's reasons move to overruled, and the provenance row says accepted by eye.

derive makes set A's light art from set B's accepted subject_reference repaints without the model: the
brightest channel of each pixel, levels to black and white, an unsharp mask, the art shrunk onto black
and faded out at the edge (see derive_light), checked with set A's judge (no text check: the repaint
passed it). The attempt is recorded in set A's raw folder with mode derived, the repaint's job, prompt
and Blizzard source, and derivedFrom naming the set B image, so a plain generate run treats the group
as done and the provenance row traces back to the set B record. A group already derived from the same
repaint is skipped unless --force; a group without a repaint keeps its style art.

package writes each accepted icon as a 128x128 PNG to <addon>/Icons/<fileID>.png (luminance only for
set A), removes PNGs it no longer selects, writes <addon>/PROVENANCE.md and <addon>/Data.lua, the
KstyleUIIconData table that Core/Icons.lua reads, and adds Data.lua to the addon's XML load file.
sheets writes contact sheets of 64 icons for review: Blizzard's icon from the extract cache, the icon and its
32-pixel version.
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
ITEMS = REPO / "Tools" / "data" / "items.json"  # item icon groups, built by Tools/icons/items.py; optional
SUBJECTS = REPO / "Tools" / "data" / "icon_subjects.json"
WORK = Path.home() / ".local" / "share" / "wow-dev" / "icons"
BLIZZARD = WORK / "blizzard"  # Blizzard's icons, read from the installed client; never in the repository
TACTTOOL = Path.home() / ".local" / "share" / "wow-dev" / "casc" / "TACTTool" / "TACTTool"
WOW_DIR = Path("/Applications/World of Warcraft")
TACT_PRODUCT, TACT_REGION = "wowf", "eu"
REFERENCE_SIZE = 512  # the 64 px Blizzard icon is upscaled to this for the model
MODES = ("style", "subject_reference")
CATEGORIES = ("class", "pet", "racial", "profession", "general", "item")
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
SHEET_TILE_W = 2 * ICON_SIZE + 48  # Blizzard's icon, the repaint and its 32-pixel version

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
ITEM_PALETTE = ("Colours: the item's own natural colours, lit by a cool white rim light with one accent colour that suits "
                "it, against a dark smoky background.")

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
    'Image 1 is a World of Warcraft {what} icon, "{name}"{kind}. Image 2 shows the target UI style, dark glass action '
    "buttons holding crisp glowing art, and is for finish and mood only: do not copy any subject from image 2. "
    "Repaint image 1 at high resolution keeping the same subject, silhouette, composition, viewing angle, scale and "
    "dominant colours so a player recognises {it} instantly{subject}. Keep the subject in the same place in the "
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

# derive: set A's light art from a set B repaint. The levels put the backdrop (the median pixel, capped) at
# black and the brightest half-percent at white; the art is shrunk onto black and faded out at the edge.
DERIVE_BLACK = 0.5  # percentile of the brightest-channel values that becomes black
DERIVE_BLACK_CAP = 56  # but never a level above this, so a bright painting keeps its mid tones
DERIVE_WHITE = 0.995  # percentile that becomes white
DERIVE_MIN_RANGE = 64  # the white level sits at least this far above the black level
DERIVE_GAMMA = 0.9  # lifts the mid tones a little, as the in-game tint only darkens
DERIVE_SHARPEN = (3, 80, 2)  # unsharp mask radius, percent and threshold, for crisp edges at 32 pixels
DERIVE_SCALE = 0.84  # the art's share of the side: the rest is set A's black margin
DERIVE_FADE = (0.80, 0.97)  # the edge fade starts and ends at these shares of the half side

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

def uses(group, owner, race=None):
    """True when a character of that class, and of that race when one is given, sees a spell of the group:
    the class or the race is in a spell's comma-separated owner list, the list is ALL, or a spell of the group
    is a profession skill, which every class can learn (First Aid shares a paladin icon, so the group's own
    category is not enough)."""
    if group["category"] == "item":
        return True
    wanted = {owner, race, "ALL"} - {None}
    return any(spell["category"] == "profession" or wanted & set(spell["owner"].split(",")) for spell in group["spells"])


def ordered_groups(data, categories=None, owner=None, race=None):
    wanted = set(categories or CATEGORIES)
    filtered = owner is not None or race is not None
    groups = [g for g in data["icons"] if g["category"] in wanted and (not filtered or uses(g, owner, race))]
    return sorted(groups, key=lambda g: (CATEGORIES.index(g["category"]), g.get("rank", 0), -g.get("count", 0), g["icon"]))


def load_groups(abilities_path=ABILITIES, items_path=ITEMS):
    """The icon groups of both data files as one list for ordered_groups: the spell groups of abilities.json
    and the item groups of items.json, when it exists. An icon a spell uses keeps the spell's group, so the
    item group for that file ID is dropped: the spell's repaint serves the items too."""
    icons = list(json.loads(Path(abilities_path).read_text())["icons"])
    items_path = Path(items_path)
    if items_path.exists():
        known = {g["icon"] for g in icons}
        icons += [g for g in json.loads(items_path.read_text())["icons"] if g["icon"] not in known]
    return icons


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


def item_phrase(group):
    kind = group.get("kind") or "item"
    return f"{_article(kind)} {kind}"


def lead_for(group):
    if group["category"] == "item":
        return f'Fantasy game item icon for "{group["name"]}", {item_phrase(group)}.'
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
    item = group["category"] == "item"
    return FAITHFUL_LEAD.format(what="item" if item else "ability", name=group["name"],
                                kind=f", {item_phrase(group)}" if item else "", it="the item" if item else "it",
                                subject=f": {sentence}" if sentence else "")


def prompt_for(icon_set, group, reasons=(), subjects=None):
    """Return (lead, prompt): the icon's own part, with its palette and any reroll fixes, and the full prompt."""
    if icon_set.mode == "subject_reference":
        lead = faithful_lead(group, subjects)
    else:
        lead = lead_for(group)
    if icon_set.palette:
        lead = f"{lead} {palette_for(group['school']) if 'school' in group else ITEM_PALETTE}"
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


def accept_by_eye(group, icon_set, raw_dir, *, today, attempt=None, note=""):
    """A reviewer who compared a rejected image with Blizzard's icon accepts it: the latest image of the set's
    mode, or attempt n. The check's reasons move to overruled, reviewed carries the date and note the reason,
    so the provenance row says the icon was accepted by eye; rejudge leaves a reviewed attempt alone. Any
    other accepted attempt of the mode is superseded, so the package takes the reviewer's choice. Saves the
    record and returns the attempt."""
    record = load_record(raw_dir, group)
    images = [a for a in _window(record, icon_set.mode)
              if mode_of(a) == icon_set.mode and "image" in a and a["verdict"] != "failed"]
    if attempt is not None:
        images = [a for a in images if a["n"] == attempt]
        if not images:
            raise ValueError(f"{group['icon']} {group['name']}: attempt {attempt} has no {icon_set.mode} image")
    if not images:
        raise ValueError(f"{group['icon']} {group['name']}: no {icon_set.mode} image to accept")
    chosen = images[-1]
    chosen.update(overruled=list(chosen.get("overruled") or chosen.get("reasons", [])), reasons=[], verdict="accepted",
                  reviewed=today)
    if note:
        chosen["note"] = note
    for other in _window(record, icon_set.mode):
        if other is not chosen and mode_of(other) == icon_set.mode and other["verdict"] == "accepted":
            other.update(overruled=list(other.get("overruled") or other.get("reasons", [])),
                         reasons=[f"superseded by attempt {chosen['n']}"], verdict="rejected", reviewed=today)
    save_record(raw_dir, record)
    return chosen


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


def rejudged_modes(icon_set):
    """The attempt modes a rejudge of the set re-checks: a style run of set A also covers the art derived from
    set B, which the same check judged."""
    return {icon_set.mode, "derived"} if icon_set.mode == "style" else {icon_set.mode}


def rejudge_groups(groups, icon_set, raw_dir):
    """The groups that have an image of the set's mode to re-check."""
    modes = rejudged_modes(icon_set)
    return [g for g in groups if any(mode_of(a) in modes and a["verdict"] != "failed" and "image" in a
                                     for a in load_record(raw_dir, g)["attempts"])]


def rejudge(groups, icon_set, raw_dir, *, judge, today, log=print):
    """Re-run the set's check on every image of the set's mode, after the check changed. Returns the
    (icon, image, old reasons, new reasons) of each attempt whose verdict changed; each is stamped rejudged."""
    changed = []
    modes = rejudged_modes(icon_set)
    for group in groups:
        record = load_record(raw_dir, group)
        for attempt in record["attempts"]:
            if mode_of(attempt) not in modes or attempt["verdict"] == "failed" or "image" not in attempt or attempt.get("reviewed"):
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


BLP2_HEADER = struct.Struct("<4sIBBBBII16I16I")  # magic, type, encoding, alpha depth, alpha encoding, mips, w, h, offsets, sizes
BLP2_RAW_BGRA = 3  # an encoding Pillow does not read: the first mip is width * height BGRA pixels


def _open_raw_bgra(blp):
    """A BLP2 file in encoding 3 as a Pillow RGBA image, or None when the file is something else."""
    Image, _ = _pillow()
    data = Path(blp).read_bytes()
    if len(data) < BLP2_HEADER.size or data[:4] != b"BLP2":
        return None
    fields = BLP2_HEADER.unpack_from(data)
    encoding, width, height, offset, length = fields[2], fields[6], fields[7], fields[8], fields[24]
    if encoding != BLP2_RAW_BGRA or length < width * height * 4 or offset + width * height * 4 > len(data):
        return None
    return Image.frombytes("RGBA", (width, height), data[offset:offset + width * height * 4], "raw", "BGRA")


def decode_blp(blp, png, size=REFERENCE_SIZE):
    """Decode a BLP, composite it over black and upscale it to size for the model. Pillow reads palette and
    DXT BLPs; the raw BGRA encoding some item icons use is read here. Anything else is an ExtractError."""
    Image, _ = _pillow()
    try:
        with Image.open(blp) as image:
            rgba = image.convert("RGBA")
    except (OSError, ValueError, NotImplementedError) as error:  # Pillow's BLPFormatError is a NotImplementedError
        rgba = _open_raw_bgra(blp)
        if rgba is None:
            raise ExtractError(f"{Path(blp).name}: {error}") from error
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


def extract_all(groups, cache_dir=BLIZZARD, log=print, extract=extract_icon):
    """Extract the Blizzard icon of every group; return the sources map for generate. A missing icon is logged."""
    sources, missing = {}, []
    for group in groups:
        try:
            sources[group["icon"]] = extract(group["icon"], cache_dir)
        except (ExtractError, OSError, subprocess.TimeoutExpired) as error:
            missing.append(group["icon"])
            log(f"{group['icon']} {group['name']}: {error}")
    log(f"blizzard icons: {len(sources)} in {cache_dir}" + (f", {len(missing)} missing" if missing else ""))
    return sources


# Deriving set A from set B ----------------------------------------------------------------------

def _percentile(histogram, share):
    total, seen = sum(histogram), 0
    for value, count in enumerate(histogram):
        seen += count
        if seen >= share * total:
            return value
    return len(histogram) - 1


def _edge_fade(size):
    """A mask of 255 inside DERIVE_FADE[0] of the half side, falling smoothly to 0 at DERIVE_FADE[1], measured
    as the larger of the horizontal and vertical distances from the centre, so the fade follows the square."""
    Image, _ = _pillow()
    from PIL import ImageChops
    vertical = Image.linear_gradient("L").resize((size, size), Image.BILINEAR).point(lambda v: min(255, abs(2 * v - 255)))
    distance = ImageChops.lighter(vertical, vertical.transpose(Image.Transpose.ROTATE_90))
    start, end = DERIVE_FADE
    table = []
    for level in range(256):
        t = min(1.0, max(0.0, (level / 255 - start) / (end - start)))
        table.append(round(255 * (1 - (3 * t * t - 2 * t * t * t))))
    return distance.point(table)


def derive_light(source, target):
    """Write set A's light art for a set B painting: the brightest channel of each pixel, so a saturated colour
    counts as light; levels that put the backdrop at black and the brightest pixels at white; a light unsharp
    mask; the art shrunk to DERIVE_SCALE of the side on black and faded to black at the edge. The file is a
    luminance ("L") PNG; package turns it into the RGB PNG with equal channels that the game draws."""
    Image, _ = _pillow()
    from PIL import ImageChops, ImageFilter
    with Image.open(source) as image:
        red, green, blue = image.convert("RGB").split()
    light = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    histogram = light.histogram()
    black = min(_percentile(histogram, DERIVE_BLACK), DERIVE_BLACK_CAP)
    white = max(_percentile(histogram, DERIVE_WHITE), black + DERIVE_MIN_RANGE)
    table = [round(255 * max(0.0, min(1.0, (v - black) / (white - black))) ** DERIVE_GAMMA) for v in range(256)]
    radius, percent, threshold = DERIVE_SHARPEN
    light = light.point(table).filter(ImageFilter.UnsharpMask(radius=radius, percent=percent, threshold=threshold))
    size = light.size[0]
    inner = round(size * DERIVE_SCALE)
    canvas = Image.new("L", (size, size), 0)
    canvas.paste(light.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2, (size - inner) // 2))
    ImageChops.multiply(canvas, _edge_fade(size)).save(target, optimize=True)


def _derived_from(record, source):
    """The record's attempt derived from the set B attempt source, if any."""
    for attempt in _window(record):
        origin = attempt.get("derivedFrom", {})
        if mode_of(attempt) == "derived" and (origin.get("job"), origin.get("image")) == (source["job"], source["image"]):
            return attempt
    return None


def derive(groups, icon_set, raw_dir, source_dir, *, judge, today, transform=derive_light, force=False, log=print):
    """Make set A's light art for every group whose set B record has an accepted subject_reference repaint, at
    no credit cost, and run it through the set's check. The new attempt carries the repaint's job, prompt,
    model and Blizzard source, so the provenance row traces back to the set B record; derivedFrom names the
    repaint's image. A group already derived from that repaint is skipped unless force. Returns a summary."""
    raw_dir, source_dir = Path(raw_dir), Path(source_dir)
    raw_dir.mkdir(parents=True, exist_ok=True)
    summary = {"derived": 0, "accepted": 0, "rejected": 0, "skipped": 0, "missing": []}
    for group in groups:
        source = accepted_attempt(load_record(source_dir, group))
        if source is None or mode_of(source) != "subject_reference":
            summary["missing"].append(group["icon"])
            continue
        record = load_record(raw_dir, group)
        if not force and _derived_from(record, source) is not None:
            summary["skipped"] += 1
            continue
        n = len(record["attempts"]) + 1
        image = f"{group['icon']}-{n}.png"
        transform(source_dir / source["image"], raw_dir / image)
        reasons = list(judge(raw_dir / image))
        attempt = {
            "n": n, "model": source["model"], "mode": "derived", "lead": source["lead"], "prompt": source["prompt"],
            "date": today, "source": source.get("source"), "job": source["job"], "image": image,
            "derivedFrom": {"set": "B", "image": source["image"], "job": source["job"], "mode": mode_of(source),
                            "date": source["date"]},
            "reasons": reasons, "verdict": "rejected" if reasons else "accepted",
        }
        record["attempts"].append(attempt)
        save_record(raw_dir, record)
        summary["derived"] += 1
        summary["accepted" if not reasons else "rejected"] += 1
        log(f"{group['icon']} {group['name']}: derived from B {source['image']}: {attempt['verdict']} ({', '.join(reasons) or 'ok'})")
    return summary


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
        if "school" in entry["group"]:
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
    """The spells of a group, or its items, the group's name first; an item group names how many more items
    share the icon than it lists."""
    names = []
    members = group.get("spells") or group.get("items") or []
    for member in [{"name": group["name"]}] + list(members):
        if member["name"] not in names:
            names.append(member["name"])
    text = ", ".join(names)
    more = group.get("count", 0) - len(members)
    if group["category"] == "item" and more > 0:
        text += f" and {more} more item{'s' if more > 1 else ''}"
    return text


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
    if any(mode_of(e["attempt"]) == "derived" for e in entries):
        lines += [
            "",
            "## Derived from set B (`derived`)",
            "",
            "| Field | Value |",
            "| --- | --- |",
            "| Source | The accepted `subject_reference` repaint of the same file ID in `KstyleUI_IconsColour/PROVENANCE.md`: "
            "the row's Model, Prompt, Blizzard BLP sha256 and Job are that repaint's, so the job identifies the set B "
            "image the art came from. The row's Date is the day the light art was derived. |",
            f"| Method | `iconset.py derive`, Pillow only, no model and no credits: the brightest channel of each pixel, so "
            f"a saturated colour counts as light; levels that put the {DERIVE_BLACK:.0%} percentile (capped at "
            f"{DERIVE_BLACK_CAP}) at black and the {DERIVE_WHITE:.1%} percentile at white, gamma {DERIVE_GAMMA}; an "
            f"unsharp mask (radius {DERIVE_SHARPEN[0]}, {DERIVE_SHARPEN[1]}%); the art shrunk to {DERIVE_SCALE:.0%} of "
            f"the side on black and faded to black from {DERIVE_FADE[0]:.0%} to {DERIVE_FADE[1]:.0%} of the half side. |",
            f"| Checks | `Tools/icons/check_icons.py --set A` without the text check, which the repaint passed: {icon_set.checks} |",
        ]
    if any(e["attempt"].get("reviewed") for e in entries):
        lines += [
            "",
            "A method marked `accepted by eye` names the check reasons a reviewer overruled after comparing the image "
            "with Blizzard's icon at 128 and 32 pixels (`iconset.py accept`); the record keeps the review date.",
        ]
    lines += [
        "",
        "| File ID | Spells or items | Model | Method | Prompt | Blizzard BLP sha256 | Job | Date |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for entry in entries:
        group, attempt = entry["group"], entry["attempt"]
        digest = attempt.get("source", {}).get("blp_sha256", "")
        method = mode_of(attempt)
        if attempt.get("reviewed"):
            method += ", accepted by eye over " + ", ".join(attempt.get("overruled", []))
        lines.append(
            f"| `{group['icon']}` | {_cell(spell_names(group))} | {attempt['model']} | {method} "
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
            problems.append(f"Icons/{path.name} is not an icon file ID in Tools/data/abilities.json or items.json")

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


def blizzard_sources(groups, cache_dir=BLIZZARD):
    """The extracted Blizzard icon of each group already in the cache, for the contact sheets; nothing is extracted."""
    sources = {}
    for group in groups:
        png = Path(cache_dir) / f"{group['icon']}.png"
        if png.exists():
            sources[group["icon"]] = {"png": str(png)}
    return sources


def contact_sheets(icon_set, groups, raw_dir, out_dir, sources=None, log=print):
    """Write sheets of 64 accepted icons in the groups' order, captioned with the file ID: Blizzard's icon from
    sources when there is one (else a dark tile), the icon at full size and at 32 pixels."""
    Image, ImageDraw = _pillow()
    entries = [e for g in groups for e in accepted_entries([g], raw_dir)]
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    tile_w, tile_h = SHEET_TILE_W, ICON_SIZE + 16
    for start in range(0, len(entries), SHEET_ICONS):
        chunk = entries[start:start + SHEET_ICONS]
        rows = (len(chunk) + SHEET_COLUMNS - 1) // SHEET_COLUMNS
        sheet = Image.new("RGB", (SHEET_COLUMNS * tile_w, rows * tile_h), (24, 24, 24))
        draw = ImageDraw.Draw(sheet)
        for i, entry in enumerate(chunk):
            x, y = (i % SHEET_COLUMNS) * tile_w, (i // SHEET_COLUMNS) * tile_h
            source = (sources or {}).get(entry["group"]["icon"])
            if source:
                with Image.open(source["png"]) as original:
                    sheet.paste(original.convert("RGB").resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS), (x, y))
            with Image.open(Path(raw_dir) / entry["attempt"]["image"]) as image:
                mode = "L" if icon_set.greyscale else "RGB"
                big = image.convert(mode).resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
                small = image.convert(mode).resize((32, 32), Image.LANCZOS)
            sheet.paste(big.convert("RGB"), (x + ICON_SIZE + 4, y))
            sheet.paste(small.convert("RGB"), (x + 2 * ICON_SIZE + 8, y))
            draw.text((x + 2, y + ICON_SIZE + 2), f"{entry['group']['icon']} {entry['group']['name']}"[:34], fill=(200, 200, 200))
        path = out_dir / f"sheet-{start // SHEET_ICONS + 1:02d}.png"
        sheet.save(path)
        log(f"wrote {path}")


# Command line ----------------------------------------------------------------------------------

def _load_groups(args):
    data = {"icons": load_groups()}
    categories = args.categories.split(",") if getattr(args, "categories", None) else None
    unknown = set(categories or ()) - set(CATEGORIES)
    if unknown:
        raise SystemExit(f"iconset: unknown categories: {', '.join(sorted(unknown))}")
    return ordered_groups(data, categories, getattr(args, "owner", None), getattr(args, "race", None))


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
    for name in ("extract", "generate", "rejudge", "status", "package", "sheets", "verify", "derive", "accept"):
        command = sub.add_parser(name)
        if name != "derive":  # derive always writes set A from set B
            command.add_argument("--set", default="A", choices=sorted(SETS))
        if name not in ("package", "verify"):  # package writes the whole set: a filtered package would drop the rest
            command.add_argument("--categories", help="comma-separated subset of " + ",".join(CATEGORIES))
            command.add_argument("--owner", help="keep the icon groups a character of this class sees, such as WARRIOR")
            command.add_argument("--race", help="with --owner, also keep this race's racials, such as Orc")
        command.add_argument("--work-dir", type=Path, default=None, help="default ~/.local/share/wow-dev/icons/<set>")
        if name in ("extract", "generate", "rejudge", "sheets"):
            command.add_argument("--blizzard-dir", type=Path, default=BLIZZARD, help="cache of extracted Blizzard icons")
        if name in ("generate", "rejudge", "status", "accept"):
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
        if name == "accept":
            command.add_argument("icons", type=int, nargs="+", help="file IDs whose latest image of the mode a reviewer accepts")
            command.add_argument("--attempt", type=int, help="accept this attempt number instead of the latest image")
            command.add_argument("--note", default="", help="why the reviewer accepted it")
        if name == "derive":
            command.add_argument("--source-dir", type=Path, default=None, help="set B's raw folder (default ~/.local/share/wow-dev/icons/B/raw)")
            command.add_argument("--force", action="store_true", help="derive again even where the same repaint was already used")
    args = parser.parse_args(argv)

    icon_set = with_mode(SETS[getattr(args, "set", "A")], getattr(args, "mode", "style"))
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
    elif args.command == "accept":
        by_icon = {g["icon"]: g for g in groups}
        for icon in args.icons:
            if icon not in by_icon:
                raise SystemExit(f"iconset: {icon} is not an icon group")
            attempt = accept_by_eye(by_icon[icon], icon_set, raw, today=datetime.date.today().isoformat(),
                                    attempt=args.attempt, note=args.note)
            print(f"{icon} {by_icon[icon]['name']}: attempt {attempt['n']} accepted by eye over {', '.join(attempt['overruled']) or 'nothing'}")
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
    elif args.command == "derive":
        import check_icons  # noqa: F401  (make_judge imports it; fail early when Pillow is missing)

        summary = derive(groups, icon_set, raw, args.source_dir or WORK / "B" / "raw", judge=make_judge(text=False, icon_set=icon_set),
                         today=datetime.date.today().isoformat(), force=args.force)
        print(f"derived {summary['derived']}: accepted {summary['accepted']}, rejected {summary['rejected']}; "
              f"skipped {summary['skipped']} already derived, {len(summary['missing'])} groups without a set B repaint")
    elif args.command == "package":
        package(icon_set, groups, raw, data=not args.no_data)
    elif args.command == "sheets":
        contact_sheets(icon_set, groups, raw, work / "sheets", sources=blizzard_sources(groups, args.blizzard_dir))
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
            for group in todo:
                print(f"  {group['icon']} {group['name']} ({group['category']})")
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
