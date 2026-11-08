"""Generate, check, package and ship icon set B, the repainted ability and item icons, as a loose-file pack.

Usage (run with a Python that has Pillow, such as ~/.local/share/wow-dev/venv/bin/python; names, verify
and install need none):
    iconset.py extract  [--owner WARRIOR] [--race Orc] [--categories class,pet]
    iconset.py generate [--mode style|subject_reference] [--owner WARRIOR] [--race Orc] [--jobs 8]
                        [--floor N] [--limit N] [--categories class,pet] [--reroll FILEID ...] [--dry-run]
    iconset.py rejudge  [--mode ...] [--owner ...]
    iconset.py status   [--mode ...]
    iconset.py package
    iconset.py sheets
    iconset.py verify
    iconset.py accept   [--mode ...] [--attempt N] [--note TEXT] FILEID ...
    iconset.py names    [--listfile FILE] [--blizzard-dir DIR] [--out FILE]
    iconset.py pack     [--out DIR] [--names FILE] [--source DIR]
    iconset.py install  --wow "/Applications/World of Warcraft/_forever_" [--pack DIR] [--uninstall] [--dry-run]

Set B is full-colour art that fills the square. Its source art lives in the repository in Tools/icons/setB
(Icons/<fileID>.png and PROVENANCE.md) and never ships inside the addon: the game loads it as a loose-file
texture pack in World of Warcraft/_forever_/Interface/Icons, the way AcidWeb's Clean Icons works, so every
icon is replaced everywhere, including the buff and debuff tiles the secure aura engine draws (docs/icons.md).

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
check on the images it already has, after the check changes, and stamps each changed verdict.

generate makes one 1:1 image per icon group with Higgsfield, in category order (class, pet, racial,
profession, general, item; items by rank, then by how many items share the icon), up to --jobs at a time (at most 12; the plus plan runs 8 and the run waits out
its rate limit). Each image goes through the set's check in check_icons (judge_colour for B,
judge_faithful for subject_reference, which also rejects a repaint that drifts from Blizzard's
icon); a rejected icon is rerolled at most twice, with a fix for the reasons added to its prompt. Raw
images and one JSON record per icon live outside the repository in ~/.local/share/wow-dev/icons/B/raw,
so a rerun skips finished icons. Each attempt records its mode; a subject_reference run repaints an
icon whose accepted image came from a style run, and the style image stays in the package until a
repaint is accepted. The run reads the credit balance at the start and every 100 images, and
stops before a job would take the balance below --floor (60 by default). --reroll makes a fresh attempt for icons the
owner marked on a contact sheet, even when they were accepted. accept records a reviewer's decision on a
rejected image after comparing it with Blizzard's icon by eye: the latest image of the mode (or --attempt N)
becomes accepted, the check's reasons move to overruled, and the provenance row says accepted by eye.

package writes each accepted icon as a 128x128 RGB PNG to Tools/icons/setB/Icons/<fileID>.png, removes PNGs
it no longer selects, and writes Tools/icons/setB/PROVENANCE.md.
sheets writes contact sheets of 64 icons for review: Blizzard's icon from the extract cache, the icon and its
32-pixel version.
verify checks the packaged files: Tools/tests/test_iconset.py runs it.

names writes Tools/data/icon_names.csv, the rows of the community listfile for every icon group's file ID
(id;Interface/ICONS/<Name>.blp, Blizzard's own mixed-case name), with a third field, encrypted, on an icon
whose extracted BLP is zero-filled: the client encrypts fewer than a hundred store and event icons, and a
loose file cannot replace one. The default listfile is ~/.local/share/wow-dev/atlas/tact/listfile-withcapitals.csv,
the wowdev community listfile with capitals; the committed names file keeps CI and the pack offline.
pack writes <out>/Interface/Icons/<Name>.tga for every packaged icon that has a name and is not encrypted,
in the format Clean Icons ships: 128x128, 32 bits per pixel with an 8-bit alpha channel (opaque), uncompressed,
bottom-left origin, TGA 2.0 footer. Icons it skips are reported with the reason. The default output is
~/.local/share/wow-dev/icons/pack.
install copies the pack into <wow>/Interface/Icons and nothing else, refusing a folder without .flavor.info
(a flavour folder such as _forever_ or _retail_). It copies only files that differ, so a rerun does nothing,
and writes KstyleUI-Icons.manifest.json beside them with the sha256 of every file it placed; a file an earlier
install placed that the new pack no longer has is removed when its content still matches, else kept. --uninstall
removes the manifest's files whose content still matches and the manifest, keeps a file the player changed,
and touches no other file. A manifest entry that is not a plain .tga file name, or a symbolic link where a
folder or file of the install should be, stops the command before anything changes. --dry-run reports without
writing. The game loads the files after a full restart.
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
MORE = REPO / "Tools" / "data" / "icons_more.json"  # the client's other icons, built by Tools/icons/more_icons.py; optional
SUBJECTS = REPO / "Tools" / "data" / "icon_subjects.json"
WORK = Path.home() / ".local" / "share" / "wow-dev" / "icons"
BLIZZARD = WORK / "blizzard"  # Blizzard's icons, read from the installed client; never in the repository
PACK_DIR = WORK / "pack"  # where pack writes Interface/Icons by default
ICON_NAMES = REPO / "Tools" / "data" / "icon_names.csv"  # the listfile rows of every icon group, written by names
LISTFILE = Path.home() / ".local" / "share" / "wow-dev" / "atlas" / "tact" / "listfile-withcapitals.csv"
MANIFEST = "KstyleUI-Icons.manifest.json"  # install writes it into Interface/Icons; uninstall reads it
FLAVOR_INFO = ".flavor.info"  # every World of Warcraft flavour folder (_forever_, _retail_) has one
TGA_FOOTER = bytes(8) + b"TRUEVISION-XFILE.\x00"  # the TGA 2.0 footer Clean Icons' files end with
TGA_HEADER = struct.Struct("<BBBHHBHHHHBB")
TGA_TRUECOLOR, TGA_BPP, TGA_ALPHA_BITS = 2, 32, 8
TACTTOOL = Path.home() / ".local" / "share" / "wow-dev" / "casc" / "TACTTool" / "TACTTool"
WOW_DIR = Path("/Applications/World of Warcraft")
TACT_PRODUCT, TACT_REGION = "wowf", "eu"
REFERENCE_SIZE = 512  # the 64 px Blizzard icon is upscaled to this for the model
MODES = ("style", "subject_reference")
ABILITY_CATEGORIES = ("class", "pet", "racial", "profession", "general")  # abilities.json: groups with spells a class owns
CATEGORIES = ABILITY_CATEGORIES + ("item", "spell", "currency", "mount", "companion", "achievement", "unlisted", "misc")
# What the faithful prompt calls an icon of each category; a category not listed is "ability" (a class spell).
ICON_KINDS = {"item": "item", "unlisted": "item", "spell": "spell", "currency": "currency", "mount": "mount",
              "companion": "companion pet", "achievement": "achievement", "misc": ""}
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

TEXT_HINT = "Draw no text, letters, numbers or writing of any kind."

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
# fire, nature, frost, shadow, arcane, as the combat text's school colour does; physical counts only alone.
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
    "text": TEXT_HINT,
}

CHECKS_B = ("no blank, flat (unreadable at 32 pixels), framed, grid, off-centre or text-bearing image is "
            "accepted")

# subject_reference: Blizzard's icon is image 1, the action-button strip is image 2. The pilot's v2 prompt.
FAITHFUL_LEAD = (
    'Image 1 is a World of Warcraft {what}icon, "{name}"{kind}. Image 2 shows the target UI style, dark glass action '
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
    "text": TEXT_HINT,
}
CHECKS_FAITHFUL = ("no blank, flat (unreadable at 32 pixels), grid or text-bearing image is accepted, no black "
                   "margin with a hard edge round the painting (a vignette is not a frame), and no repaint whose 8x8 "
                   "light-and-dark layout correlates below 0.6 with Blizzard's icon (drift)")
BUTTONS_REFERENCE = "docs/design/mockups/icons_B_buttons.png"

CLASS_NAMES = {"DEATHKNIGHT": "Death Knight", "DEMONHUNTER": "Demon Hunter"}
RACE_NAMES = {"Scourge": "Undead"}


@dataclass(frozen=True)
class IconSet:
    name: str  # the set: B
    folder: str  # repository folder of the packaged art: Icons/<fileID>.png and PROVENANCE.md
    model: str
    reference: str  # repository path of the style reference passed as the last image reference
    style: str
    hints: dict  # reason code -> the fix a reroll adds to the prompt
    floor: float  # credits the generate command leaves unspent by default
    checks: str  # what check_icons rejects, for PROVENANCE.md
    judge: str  # the name of the set's check in check_icons.judge_for
    palette: bool = False  # add the spell school's palette to each prompt
    mode: str = "style"  # style: paint from a text description; subject_reference: repaint Blizzard's icon


SETS = {
    "B": IconSet("B", "Tools/icons/setB", "gpt_image_2_5", "docs/design/mockups/icons_B_fullcolour.jpg",
                 STYLE_B, hints=HINTS_B, floor=60.0, checks=CHECKS_B, judge="B", palette=True),
}
SET_B = SETS["B"]


def faithful(icon_set):
    """The set in subject_reference mode: the same folder, repainted from Blizzard's icon in the button strip's finish."""
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
    if group["category"] not in ABILITY_CATEGORIES:
        return True
    wanted = {owner, race, "ALL"} - {None}
    return any(spell["category"] == "profession" or wanted & set(spell["owner"].split(",")) for spell in group["spells"])


def ordered_groups(data, categories=None, owner=None, race=None):
    wanted = set(categories or CATEGORIES)
    filtered = owner is not None or race is not None
    groups = [g for g in data["icons"] if g["category"] in wanted and (not filtered or uses(g, owner, race))]
    return sorted(groups, key=lambda g: (CATEGORIES.index(g["category"]), g.get("rank", 0), -g.get("count", 0), g["icon"]))


def load_groups(abilities_path=ABILITIES, items_path=ITEMS, more_path=MORE):
    """The icon groups of the data files as one list for ordered_groups: the spell groups of abilities.json,
    the item groups of items.json and the client's other icons from icons_more.json, when they exist. An
    earlier file's group keeps its file ID, so a later file's group for the same icon is dropped: the
    spell's repaint serves the items too."""
    icons = list(json.loads(Path(abilities_path).read_text())["icons"])
    for path in (Path(items_path), Path(more_path)):
        if path.exists():
            known = {g["icon"] for g in icons}
            icons += [g for g in json.loads(path.read_text())["icons"] if g["icon"] not in known]
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


def icon_kind(group):
    """What the prompts call an icon of the group's category: ability, item, spell, currency and so on; "" for misc."""
    return ICON_KINDS.get(group["category"], "ability")


def lead_for(group):
    if group["category"] == "item":
        return f'Fantasy game item icon for "{group["name"]}", {item_phrase(group)}.'
    if group["category"] not in ABILITY_CATEGORIES:
        kind = icon_kind(group)
        return f'Fantasy game {kind + " " if kind else ""}icon for "{group["name"]}".'
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
    kind = icon_kind(group)
    return FAITHFUL_LEAD.format(what=f"{kind} " if kind else "", name=group["name"],
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
    """The attempt modes a rejudge of the set re-checks."""
    return {icon_set.mode}


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
    icon_set = icon_set or SET_B
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


# Packaging -------------------------------------------------------------------------------------

def accepted_entries(groups, raw_dir):
    entries = []
    for group in groups:
        attempt = accepted_attempt(load_record(raw_dir, group))
        if attempt:
            entries.append({"group": group, "attempt": attempt})
    return sorted(entries, key=lambda e: e["group"]["icon"])


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
    tone = "full colour (RGB PNG)"
    repaint = faithful(icon_set)
    repainted = any(mode_of(e["attempt"]) == "subject_reference" for e in entries)
    lines = [
        f"# Icon set {icon_set.name} provenance",
        "",
        f"Icon set {icon_set.name}. Every icon in `Icons/` has a row below. `Tools/icons/iconset.py package` writes this "
        "file and the icons from the generation records; do not edit it by hand. `iconset.py pack` turns the icons into "
        "the loose-file texture pack players install (`docs/icons.md`).",
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


def downscale(source, target):
    Image, _ = _pillow()
    with Image.open(source) as image:
        image = image.convert("RGB")
        image = image.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
        image.save(target, optimize=True)


def package(icon_set, groups, raw_dir, repo=REPO, log=print):
    folder = Path(repo) / icon_set.folder
    icons = folder / "Icons"
    icons.mkdir(parents=True, exist_ok=True)
    entries = accepted_entries(groups, raw_dir)
    keep = set()
    for entry in entries:
        icon = entry["group"]["icon"]
        keep.add(f"{icon}.png")
        downscale(Path(raw_dir) / entry["attempt"]["image"], icons / f"{icon}.png")
    for stale in icons.glob("*.png"):
        if stale.name not in keep:
            stale.unlink()
    (folder / "PROVENANCE.md").write_text(render_provenance(icon_set, entries))
    log(f"packaged {len(entries)} icons into {folder}")
    return entries


def _png_header(path):
    head = Path(path).read_bytes()[:33]
    if len(head) < 33 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    width, height, depth, colour = struct.unpack(">IIBB", head[16:26])
    return width, height, depth, colour


def verify_package(icon_set, groups, repo=REPO, names=None):
    """List what is wrong with the packaged set: PNG format, file IDs, provenance rows, and with names (the table
    load_icon_names reads) an icon the pack could not name."""
    folder = Path(repo) / icon_set.folder
    icons_dir = folder / "Icons"
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
        if icon not in known:
            problems.append(f"Icons/{path.name} is not an icon file ID in Tools/data/abilities.json or items.json")
        if names is not None and icon not in names:
            problems.append(f"Icons/{path.name} has no listfile name in Tools/data/icon_names.csv: run iconset.py names")

    provenance = folder / "PROVENANCE.md"
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
                big = image.convert("RGB").resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
                small = image.convert("RGB").resize((32, 32), Image.LANCZOS)
            sheet.paste(big, (x + ICON_SIZE + 4, y))
            sheet.paste(small, (x + 2 * ICON_SIZE + 8, y))
            draw.text((x + 2, y + ICON_SIZE + 2), f"{entry['group']['icon']} {entry['group']['name']}"[:34], fill=(200, 200, 200))
        path = out_dir / f"sheet-{start // SHEET_ICONS + 1:02d}.png"
        sheet.save(path)
        log(f"wrote {path}")


# The loose-file pack ----------------------------------------------------------------------------

ICON_ROW = re.compile(r"^(\d+);(?:[^;]*/)?interface/icons/([^/;]+)\.blp(;encrypted)?$", re.IGNORECASE)


def load_icon_names(path):
    """Read a listfile (id;path per line): {fileID: Blizzard's icon name} for every Interface/Icons row, with the
    name's case as the file gives it, and the set of IDs a third field marks encrypted."""
    names, encrypted = {}, set()
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = ICON_ROW.match(line.rstrip("\r\n"))
            if match:
                icon = int(match.group(1))
                names[icon] = match.group(2)
                if match.group(3):
                    encrypted.add(icon)
    return names, encrypted


def is_encrypted_blp(path):
    """True when the extracted file exists and is zero-filled: TACTTool writes zeros for a file whose encryption
    key the client does not have, so the client cannot show a loose file in its place either."""
    path = Path(path)
    if not path.exists():
        return False
    data = path.read_bytes()
    return len(data) > 0 and data.count(0) == len(data)


def write_icon_names(listfile, icons, out, blizzard_dir=BLIZZARD):
    """Write the listfile rows of the given file IDs to out, marking the encrypted ones, and say how many were
    named, how many are encrypted and which IDs the listfile does not name."""
    wanted = set(icons)
    rows = {}
    with open(listfile, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = ICON_ROW.match(line.rstrip("\r\n"))
            if match and int(match.group(1)) in wanted:
                rows[int(match.group(1))] = line.rstrip("\r\n").split(";", 1)[1].split(";")[0]
    encrypted = {icon for icon in rows if is_encrypted_blp(Path(blizzard_dir) / f"{icon}.blp")}
    lines = [f"{icon};{rows[icon]}" + (";encrypted" if icon in encrypted else "") for icon in sorted(rows)]
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    Path(out).write_text("".join(line + "\n" for line in lines))
    return {"named": len(rows), "encrypted": len(encrypted), "unnamed": sorted(wanted - set(rows))}


def tga_bytes(width, height, rgb):
    """A TGA file as Clean Icons ships them: uncompressed true colour, 32 bits per pixel with an 8-bit alpha
    channel (opaque here), the rows stored bottom first, and the TGA 2.0 footer. rgb is the image's pixels
    top row first, three bytes each."""
    if len(rgb) != width * height * 3:
        raise ValueError(f"{len(rgb)} bytes of pixels for {width}x{height} RGB")
    header = TGA_HEADER.pack(0, 0, TGA_TRUECOLOR, 0, 0, 0, 0, 0, width, height, TGA_BPP, TGA_ALPHA_BITS)
    rows = []
    stride = width * 3
    for y in range(height - 1, -1, -1):
        row = rgb[y * stride:(y + 1) * stride]
        bgra = bytearray(width * 4)
        bgra[0::4], bgra[1::4], bgra[2::4], bgra[3::4] = row[2::3], row[1::3], row[0::3], b"\xff" * width
        rows.append(bytes(bgra))
    return header + b"".join(rows) + TGA_FOOTER


def tga_header(data):
    """The fields of a TGA header, or None when the bytes are not one."""
    if len(data) < TGA_HEADER.size:
        return None
    idlen, cmap, kind, _, _, _, _, _, width, height, bpp, desc = TGA_HEADER.unpack_from(data)
    if kind not in (1, 2, 3, 9, 10, 11) or cmap not in (0, 1) or width == 0 or height == 0:
        return None
    return {"type": kind, "width": width, "height": height, "bpp": bpp, "alpha": desc & 0x0F, "topLeft": bool(desc & 0x20)}


def read_png_rgb(path):
    """(width, height, RGB bytes top row first) of a PNG, through Pillow."""
    Image, _ = _pillow()
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        return rgb.width, rgb.height, rgb.tobytes()


def pack(source, out_dir, names, encrypted=(), decode=None, log=print):
    """Write <out_dir>/Interface/Icons/<Name>.tga for every <fileID>.png in source that names gives a name and
    encrypted does not list; remove a .tga the pack no longer makes. Returns the IDs written and the IDs skipped
    with the reason."""
    decode = decode or read_png_rgb
    folder = Path(out_dir) / "Interface" / "Icons"
    folder.mkdir(parents=True, exist_ok=True)
    written, skipped, keep = [], {}, set()
    for png in sorted(Path(source).glob("*.png")):
        if not png.stem.isdigit():
            continue
        icon = int(png.stem)
        if icon in encrypted:
            skipped[icon] = "encrypted"
            continue
        name = names.get(icon)
        if name is None:
            skipped[icon] = "no listfile name"
            continue
        width, height, rgb = decode(png)
        if (width, height) != (ICON_SIZE, ICON_SIZE):
            raise ValueError(f"{png.name} is {width}x{height}, not {ICON_SIZE}x{ICON_SIZE}")
        target = folder / f"{name}.tga"
        data = tga_bytes(width, height, rgb)
        if not target.exists() or target.read_bytes() != data:
            target.write_bytes(data)
        keep.add(target.name)
        written.append(icon)
    for stale in folder.glob("*.tga"):
        if stale.name not in keep:
            stale.unlink()
    log(f"packed {len(written)} icons into {folder}" + (f", skipped {len(skipped)}" if skipped else ""))
    for icon in sorted(skipped):
        log(f"  skipped {icon}: {skipped[icon]}")
    return {"written": written, "skipped": skipped}


def _sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _no_symlink(path):
    """Refuse a symbolic link where the install would write or remove: it could point outside Interface/Icons."""
    if Path(path).is_symlink():
        raise SystemExit(f"iconset: {path} is a symbolic link; the install touches only real files inside Interface/Icons")


def _read_manifest(manifest):
    """The files an earlier install placed, after checking every entry is a plain .tga name inside Interface/Icons."""
    _no_symlink(manifest)
    if not manifest.is_file():
        return {}
    listed = json.loads(manifest.read_text()).get("files", {})
    for name in listed:
        if (name != Path(name).name or "/" in name or "\\" in name or name in ("", ".", "..") or os.path.isabs(name)
                or not name.lower().endswith(".tga")):
            raise SystemExit(f"iconset: the manifest {manifest} names {name!r}, which is not a .tga file in Interface/Icons; nothing was changed")
    return listed


def _drop_owned(icons, owned, dry_run, log):
    """Remove the files of an earlier install that still match their recorded content; keep the rest. Returns
    (removed, kept)."""
    removed = kept = 0
    for name, digest in sorted(owned.items()):
        target = icons / name
        _no_symlink(target)
        if not target.is_file():
            continue
        if _sha256(target) != digest:
            kept += 1
            log(f"kept {target}: its content changed since the install")
            continue
        if not dry_run:
            target.unlink()
        removed += 1
    return removed, kept


def install(pack_dir, wow_dir, uninstall=False, dry_run=False, log=print):
    """Copy the pack's Interface/Icons files into the flavour folder wow_dir, or remove them again. See the module
    docstring. Returns the counts: copied, unchanged, replaced, dropped, kept for an install; removed, kept for
    an uninstall."""
    wow_dir, pack_dir = Path(wow_dir), Path(pack_dir)
    if not (wow_dir / FLAVOR_INFO).is_file():
        raise SystemExit(f"iconset: {wow_dir} is not a World of Warcraft flavour folder (no {FLAVOR_INFO}); "
                         "pass the _forever_ folder inside the game folder")
    interface = wow_dir / "Interface"
    icons = interface / "Icons"
    _no_symlink(interface)
    _no_symlink(icons)
    manifest = icons / MANIFEST
    verb = (lambda did, would: f"dry run: would {would}" if dry_run else did)
    if uninstall:
        summary = {"removed": 0, "kept": 0}
        listed = _read_manifest(manifest)
        if not listed and not manifest.is_file():
            log(f"nothing to uninstall: no {MANIFEST} in {icons}")
            return summary
        summary["removed"], summary["kept"] = _drop_owned(icons, listed, dry_run, log)
        if not dry_run:
            manifest.unlink()
        log(f"{verb('removed', 'remove')} {summary['removed']} icons from {icons}, kept {summary['kept']}")
        return summary
    source = pack_dir / "Interface" / "Icons"
    files = sorted(source.glob("*.tga"))
    if not files:
        raise SystemExit(f"iconset: no pack in {source}; run iconset.py pack first")
    previous = _read_manifest(manifest)
    for path in files:
        _no_symlink(icons / path.name)
    summary = {"copied": 0, "unchanged": 0, "replaced": 0, "dropped": 0, "kept": 0}
    placed = {}
    if not dry_run:
        icons.mkdir(parents=True, exist_ok=True)
    for path in files:
        digest = _sha256(path)
        target = icons / path.name
        placed[path.name] = digest
        if target.is_file():
            if _sha256(target) == digest:
                summary["unchanged"] += 1
                continue
            if path.name not in previous:
                summary["replaced"] += 1
        if not dry_run:
            target.write_bytes(path.read_bytes())
        summary["copied"] += 1
    gone = {name: digest for name, digest in previous.items() if name not in placed}
    summary["dropped"], summary["kept"] = _drop_owned(icons, gone, dry_run, log)
    if not dry_run:
        manifest.write_text(json.dumps({"pack": "KstyleUI icons", "files": placed}, indent=1, sort_keys=True) + "\n")
    log(f"{verb('copied', 'copy')} {summary['copied']} icons into {icons}, {summary['unchanged']} already there"
        + (f", {summary['replaced']} replaced files of another pack" if summary["replaced"] else "")
        + (f", {summary['dropped']} of an earlier install removed" if summary["dropped"] else "")
        + "; the game loads them after a full restart")
    return summary


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
    for name in ("names", "pack", "install"):
        command = sub.add_parser(name)
        if name == "names":
            command.add_argument("--listfile", type=Path, default=LISTFILE, help="the community listfile with capitals")
            command.add_argument("--blizzard-dir", type=Path, default=BLIZZARD, help="cache of extracted Blizzard icons")
            command.add_argument("--out", type=Path, default=ICON_NAMES)
        elif name == "pack":
            command.add_argument("--out", type=Path, default=PACK_DIR, help="the folder that gets Interface/Icons")
            command.add_argument("--names", type=Path, default=ICON_NAMES, help="the icon names (a listfile, or the committed extract)")
            command.add_argument("--source", type=Path, default=REPO / SET_B.folder / "Icons", help="the packaged PNGs")
        else:
            command.add_argument("--wow", type=Path, required=True, help="the flavour folder, such as /Applications/World of Warcraft/_forever_")
            command.add_argument("--pack", type=Path, default=PACK_DIR, help="the folder pack wrote")
            command.add_argument("--uninstall", action="store_true", help="remove the files the manifest lists")
            command.add_argument("--dry-run", action="store_true", help="say what would change; write nothing")
    for name in ("extract", "generate", "rejudge", "status", "package", "sheets", "verify", "accept"):
        command = sub.add_parser(name)
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
        if name == "accept":
            command.add_argument("icons", type=int, nargs="+", help="file IDs whose latest image of the mode a reviewer accepts")
            command.add_argument("--attempt", type=int, help="accept this attempt number instead of the latest image")
            command.add_argument("--note", default="", help="why the reviewer accepted it")
    args = parser.parse_args(argv)

    if args.command == "names":
        groups = load_groups()
        summary = write_icon_names(args.listfile, [g["icon"] for g in groups], args.out, blizzard_dir=args.blizzard_dir)
        print(f"named {summary['named']} icons in {args.out}, {summary['encrypted']} encrypted, "
              f"{len(summary['unnamed'])} without a listfile name")
        if summary["unnamed"]:
            print("unnamed: " + " ".join(str(i) for i in summary["unnamed"]))
        return 0
    if args.command == "pack":
        names, encrypted = load_icon_names(args.names)
        pack(args.source, args.out, names, encrypted)
        return 0
    if args.command == "install":
        install(args.pack, args.wow, uninstall=args.uninstall, dry_run=args.dry_run)
        return 0

    icon_set = with_mode(SET_B, getattr(args, "mode", "style"))
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
    elif args.command == "package":
        package(icon_set, groups, raw)
    elif args.command == "sheets":
        contact_sheets(icon_set, groups, raw, work / "sheets", sources=blizzard_sources(groups, args.blizzard_dir))
    elif args.command == "verify":
        names = load_icon_names(ICON_NAMES)[0] if ICON_NAMES.exists() else None
        problems = verify_package(icon_set, groups, names=names)
        for problem in problems:
            print(f"{icon_set.folder}: {problem}")
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
