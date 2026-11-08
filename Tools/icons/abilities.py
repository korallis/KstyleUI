"""Build Tools/data/abilities.json: every ability icon KstyleUI may replace, grouped by icon.

Usage: python3 Tools/icons/abilities.py --build 1.60.1.70840 [--from-dir DIR]
                                        [--out Tools/data/abilities.json] [--cache-dir DIR]

Without --from-dir the script downloads each table from wago.tools into
Tools/data/db2cache/<build>/ and reuses the files already there. When wago.tools is down, export
the same tables from the installed game client with Tools/icons/casc_export.py, which writes that
folder, and run this script again.

Spell ranks and related spells share one icon file ID, so the output has one entry per icon, and
each entry is one icon to generate. Each entry has a category. The categories in priority order are
class, pet, racial, profession and general, so the icon generators can draw the most visible icons
first. Each spell carries its name, rank text, owner, skill line, school and a tooltip description
cleaned into plain text for image prompts.
"""

import argparse
import collections
import contextlib
import csv
import io
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_OUT = REPO / "Tools" / "data" / "abilities.json"
DEFAULT_CACHE = REPO / "Tools" / "data" / "db2cache"
WAGO_URL = "https://wago.tools/db2/{table}/csv?build={build}"
USER_AGENT = "KstyleUI-tools"
FALLBACK = "Export the tables from the game client with Tools/icons/casc_export.py, then rerun with --from-dir."

TABLES = (
    "SkillLineAbility",
    "SkillLine",
    "SkillRaceClassInfo",
    "SpellName",
    "Spell",
    "SpellMisc",
    "SpellClassOptions",
    "SpellEffect",
    "Talent",
    "ChrClasses",
    "ChrRaces",
    "CreatureFamily",
)
CATEGORIES = ("class", "pet", "racial", "profession", "general")
SCHOOLS = {1: "Physical", 2: "Holy", 4: "Fire", 8: "Nature", 16: "Frost", 32: "Shadow", 64: "Arcane"}

# SkillLine.CategoryID values, named in the SkillLineCategory table.
CLASS_SKILLS = 7
SECONDARY_SKILLS = 9
PROFESSIONS = 11
NOT_DISPLAYED = 12

# Skill lines whose spells are not abilities to draw. Engraving and Runes are Season of Discovery
# rune engraving: Forever's UI source has no engraving UI, and the spells use gear-slot icons.
EXCLUDED_LINES = {777: "Mounts", 778: "Companions", 2851: "Engraving", 2853: "Runes"}
# Beast Training is a hunter line, but its spells teach pet abilities and share their icons.
PET_TRAINING_LINES = {261}

ATTR0_PASSIVE = 0x40
ATTR0_HIDDEN = 0x80  # kept out of the spellbook; talents still show it in the talent frame
# SpellEffect.Effect values that make a profession spell a recipe: create item, enchant item and
# temporary enchant.
ITEM_EFFECTS = {24, 53, 54}
ALL_RACES = (1 << 64) - 1

ARRAY_HEADER = re.compile(r"\[(\d+)\]$")


class DownloadError(RuntimeError):
    """wago.tools did not return a table."""


def check_csv(text, source, content_type=""):
    """Raise ValueError when text is an HTML page or anything else that is not CSV."""
    first = text.split("\n", 1)[0].strip()
    if "html" in content_type.lower() or first.startswith("<") or "," not in first:
        raise ValueError(f"{source} is not CSV (content type {content_type or 'unknown'}, first line {first[:60]!r})")


def load_csv(path):
    """Read one exported table. Array columns such as RaceMasks[0] become RaceMasks_0."""
    with open(path, encoding="utf-8-sig", newline="") as stream:
        text = stream.read()
    check_csv(text, path)
    reader = csv.reader(io.StringIO(text, newline=""))
    header = [ARRAY_HEADER.sub(r"_\1", name) for name in next(reader)]
    return [dict(zip(header, row)) for row in reader if row]


def fetch_url(url, headers):
    """Return (status, content type, body) for url."""
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return response.status, response.headers.get("Content-Type", ""), response.read()
    except urllib.error.HTTPError as err:
        return err.code, err.headers.get("Content-Type", "") if err.headers else "", b""
    except urllib.error.URLError as err:
        raise DownloadError(f"could not reach {url}: {err.reason}. {FALLBACK}") from err


def download_tables(build, cache_dir, fetch=fetch_url, tables=TABLES):
    """Download every table for build into cache_dir/<build>/ and return that folder.

    A table already in the folder is not downloaded again. A table is saved only after it checks
    out as CSV, so the folder never holds an error page. items.py passes its own tables.
    """
    folder = Path(cache_dir) / build
    folder.mkdir(parents=True, exist_ok=True)
    for table in tables:
        path = folder / f"{table}.csv"
        if path.exists():
            continue
        url = WAGO_URL.format(table=table, build=build)
        status, content_type, body = fetch(url, {"User-Agent": USER_AGENT})
        if status != 200:
            raise DownloadError(f"wago.tools returned HTTP {status} for {table} ({url}). {FALLBACK}")
        text = body.decode("utf-8-sig")
        check_csv(text, url, content_type)
        _write_text_atomic(path, text)
    return folder


def _int(value):
    return int(value) if value not in (None, "") else 0


def _race_mask(row):
    """RaceMasks_0 and RaceMasks_1 are the signed low and high halves of one 64-bit mask."""
    return (_int(row["RaceMasks_0"]) & 0xFFFFFFFF) | ((_int(row["RaceMasks_1"]) & 0xFFFFFFFF) << 32)


def _race_restricted(mask):
    return mask not in (0, ALL_RACES)


def _tokens(mask, tokens):
    return ",".join(sorted({token for bit, token in tokens.items() if mask & bit}))


class _Tables:
    """Lookups over the raw tables that the classification needs."""

    def __init__(self, tables):
        self.lines = {_int(row["ID"]): row for row in tables["SkillLine"]}
        self.parents = {_int(row["ParentSkillLineID"]) for row in tables["SkillLine"]} - {0}
        self.skill_info = collections.defaultdict(list)
        for row in tables["SkillRaceClassInfo"]:
            self.skill_info[_int(row["SkillID"])].append(row)

        self.pet_lines = set(PET_TRAINING_LINES)
        for row in tables["CreatureFamily"]:
            self.pet_lines.update(_int(row[key]) for key in ("SkillLine_0", "SkillLine_1"))
        self.pet_lines.update(i for i, row in self.lines.items() if row["DisplayName_lang"].startswith("Pet - "))
        self.pet_lines.discard(0)

        self.class_tokens = {1 << (_int(row["ID"]) - 1): row["Filename"] for row in tables["ChrClasses"]}
        self.all_classes = sum(self.class_tokens)
        self.race_tokens = {
            1 << _int(row["PlayableRaceBit"]): row["ClientFileString"]
            for row in tables["ChrRaces"]
            if _int(row["PlayableRaceBit"]) >= 0
        }

        self.names = {_int(row["ID"]): row["Name_lang"] for row in tables["SpellName"]}
        self.text = {_int(row["ID"]): (row["NameSubtext_lang"], row["Description_lang"]) for row in tables["Spell"]}
        self.descriptions = {spell_id: text[1] for spell_id, text in self.text.items()}
        self.misc = {}
        for row in sorted(tables["SpellMisc"], key=lambda r: _int(r["DifficultyID"]), reverse=True):
            self.misc[_int(row["SpellID"])] = row  # the lowest DifficultyID, normally 0, wins
        self.item_spells = {_int(row["SpellID"]) for row in tables["SpellEffect"] if _int(row["Effect"]) in ITEM_EFFECTS}
        self.talents = {
            _int(value) for row in tables["Talent"] for key, value in row.items() if key.startswith("SpellRank_")
        } - {0}

        # A pet line has no class mask of its own, so its owner is the class whose spell set most
        # of its spells belong to: warlock for demons, hunter for beasts.
        class_by_set = {_int(row["SpellClassSet"]): row["Filename"] for row in tables["ChrClasses"]}
        spell_set = {_int(row["SpellID"]): _int(row["SpellClassSet"]) for row in tables["SpellClassOptions"]}
        line_sets = collections.defaultdict(collections.Counter)
        for row in tables["SkillLineAbility"]:
            token = class_by_set.get(spell_set.get(_int(row["Spell"]), 0))
            if token:
                line_sets[_int(row["SkillLine"])][token] += 1
        self.line_owner = {line: counts.most_common(1)[0][0] for line, counts in line_sets.items()}

    def class_restricted(self, mask):
        mask &= self.all_classes
        return mask not in (0, self.all_classes)

    def line_category(self, line_id):
        line = self.lines.get(line_id)
        if line is None or line_id in EXCLUDED_LINES or "[DNT]" in line["DisplayName_lang"]:
            return None
        if line_id in self.pet_lines:
            return "pet"
        category = _int(line["CategoryID"])
        if category == CLASS_SKILLS:
            return "class"
        info = self.skill_info[line_id]
        if category in (SECONDARY_SKILLS, NOT_DISPLAYED) and any(_race_restricted(_race_mask(r)) for r in info):
            return "racial"
        if category == SECONDARY_SKILLS and info and all(self.class_restricted(_int(r["ClassMask"])) for r in info):
            return "class"
        if category == PROFESSIONS or (category == SECONDARY_SKILLS and line_id in self.parents):
            return "profession"
        return "general"

    def line_class_mask(self, line_id):
        """The classes a skill line is limited to, or 0 when any class can learn it."""
        masks = [_int(row["ClassMask"]) for row in self.skill_info[line_id]]
        if not masks or not all(self.class_restricted(mask) for mask in masks):
            return 0
        combined = 0
        for mask in masks:
            combined |= mask
        return combined

    def owner(self, category, row, line_id):
        line = self.lines[line_id]
        if category == "racial":
            mask = _race_mask(row)
            if not _race_restricted(mask):
                mask = 0
                for info in self.skill_info[line_id]:
                    if _race_restricted(_race_mask(info)):
                        mask |= _race_mask(info)
            return _tokens(mask, self.race_tokens) or "ALL"
        if category == "profession":
            return self.lines.get(_int(line["ParentSkillLineID"]), line)["DisplayName_lang"]
        mask = _int(row["ClassMask"])
        if not self.class_restricted(mask):
            mask = self.line_class_mask(line_id)
        if self.class_restricted(mask):
            return _tokens(mask & self.all_classes, self.class_tokens)
        return self.line_owner.get(line_id) or ("PET" if category == "pet" else "ALL")


def _merge_owners(first, second):
    """Join two owner lists. ALL covers every owner, and a known class replaces the PET fallback."""
    owners = set(first.split(",")) | set(second.split(","))
    if "ALL" in owners:
        return "ALL"
    if len(owners) > 1:
        owners.discard("PET")
    return ",".join(sorted(owners))


def build_abilities(tables):
    """Return one entry per drawable spell, sorted by spell ID.

    A row counts when its skill line is a class, pet, racial, profession or general line, the spell
    is not a recipe, the client has its name and icon, and the spellbook shows it or it is a talent.
    A spell on several lines keeps the highest-priority category, and rows of that category merge
    their owners.
    """
    data = _Tables(tables)
    chosen = {}
    for row in sorted(tables["SkillLineAbility"], key=lambda r: _int(r["ID"])):
        spell_id = _int(row["Spell"])
        line_id = _int(row["SkillLine"])
        category = data.line_category(line_id)
        if category is None or _int(row["TrivialSkillLineRankHigh"]) > 0:
            continue
        if category == "profession" and spell_id in data.item_spells:
            continue
        name = data.names.get(spell_id)
        misc = data.misc.get(spell_id)
        if not name or misc is None or "[DNT]" in name or "(DND)" in name:
            continue
        icon = _int(misc["SpellIconFileDataID"])
        attributes = _int(misc["Attributes_0"])
        talent = spell_id in data.talents
        if icon <= 0 or (attributes & ATTR0_HIDDEN and not talent):
            continue
        previous = chosen.get(spell_id)
        if previous and previous["category"] == category:
            previous["owner"] = _merge_owners(previous["owner"], data.owner(category, row, line_id))
            continue
        if previous and CATEGORIES.index(previous["category"]) < CATEGORIES.index(category):
            continue
        subtext, description = data.text.get(spell_id, ("", ""))
        chosen[spell_id] = {
            "id": spell_id,
            "name": name,
            "subtext": subtext,
            "category": category,
            "owner": data.owner(category, row, line_id),
            "line": data.lines[line_id]["DisplayName_lang"],
            "icon": icon,
            "school": _int(misc["SchoolMask"]),
            "passive": bool(attributes & ATTR0_PASSIVE),
            "talent": talent,
            "description": clean_description(description, data.descriptions, data.names),
        }
    return [chosen[spell_id] for spell_id in sorted(chosen)]


def group_by_icon(abilities):
    """Group spells by icon file ID, sorted by icon and then spell ID.

    A group's category is the highest-priority category among its spells. Its name and school are
    the most common among the spells in that category, ties going to the lowest spell ID.
    """
    groups = collections.defaultdict(list)
    for spell in abilities:
        groups[spell["icon"]].append(spell)
    result = []
    for icon in sorted(groups):
        spells = sorted(groups[icon], key=lambda spell: spell["id"])
        category = min((spell["category"] for spell in spells), key=CATEGORIES.index)
        lead = [spell for spell in spells if spell["category"] == category]
        result.append(
            {
                "icon": icon,
                "category": category,
                "name": collections.Counter(spell["name"] for spell in lead).most_common(1)[0][0],
                "school": collections.Counter(spell["school"] for spell in lead).most_common(1)[0][0],
                "spells": [{key: value for key, value in spell.items() if key != "icon"} for spell in spells],
            }
        )
    return result


_REFERENCE = re.compile(r"\$@([a-z]+)(\d*)")
_FORM = re.compile(r"\$([lLgG])([^:;$]*):([^;$]*);")
_DIVISOR = re.compile(r"\$/\d+;\d*[A-Za-z]+\d*")
_VALUE = re.compile(r"\$\d*[A-Za-z]+\d*")
_CONDITION = re.compile(r"[^\[\]\s]*")
_ALTERNATIVE = re.compile(r"\?[^\[\]\s]*\[")
_ESCAPE = re.compile(r"\|([cC][0-9A-Fa-f]{8}|[rR]|n|T[^|]*\|t|H[^|]*\|h|h)")


def _skip_balanced(text, start, opener, closer):
    """Return the index just past the closer that matches text[start] == opener."""
    depth = 0
    for index in range(start, len(text)):
        if text[index] == opener:
            depth += 1
        elif text[index] == closer:
            depth -= 1
            if depth == 0:
                return index + 1
    return len(text)


def _conditional(text, start):
    """Read $?cond[a]?cond[b][c] from start (just past "$?"). Return (a, index past the chain).

    A condition with no bracket after it is dropped.
    """
    opening = _CONDITION.match(text, start).end()
    if text[opening : opening + 1] != "[":
        return "", opening
    end = _skip_balanced(text, opening, "[", "]")
    branch = text[opening + 1 : end - 1]
    while end < len(text):
        if text[end] == "[":
            end = _skip_balanced(text, end, "[", "]")
            continue
        alternative = _ALTERNATIVE.match(text, end)
        if not alternative:
            break
        end = _skip_balanced(text, alternative.end() - 1, "[", "]")
    return branch, end


def clean_description(text, descriptions, names):
    """Turn a tooltip template into plain text for an image prompt.

    Numbers and formulas become X, $l and $g forms pick the plural and the first gender, a
    conditional keeps its first branch, $@spelldesc and $@spellname references are filled in, UI
    escapes are dropped and whitespace collapses to single spaces.
    """
    return " ".join(_expand(text, descriptions, names, ()).split())


def _expand(text, descriptions, names, seen):
    out = []
    index = 0
    while index < len(text):
        char = text[index]
        if char == "|":
            escape = _ESCAPE.match(text, index)
            if escape:
                out.append(" " if escape.group(1) == "n" else "")
                index = escape.end()
            else:
                out.append(char)
                index += 1
            continue
        if char != "$":
            out.append(char)
            index += 1
            continue
        following = text[index + 1 : index + 2]
        if following == "@":
            reference = _REFERENCE.match(text, index)
            if not reference:
                index += 2
                continue
            kind, ref = reference.group(1), _int(reference.group(2))
            if kind in ("spelldesc", "spelltooltip") and ref not in seen:
                out.append(f" {_expand(descriptions.get(ref, ''), descriptions, names, seen + (ref,))} ")
            elif kind == "spellname":
                out.append(names.get(ref, ""))
            index = reference.end()
        elif following == "?":
            branch, index = _conditional(text, index + 2)
            out.append(_expand(branch, descriptions, names, seen))
        elif following == "{":
            index = _skip_balanced(text, index + 1, "{", "}")
            out.append("X")
        elif following == "<":
            closing = text.find(">", index)
            index = closing + 1 if closing >= 0 else len(text)
            out.append("X")
        else:
            form = _FORM.match(text, index)
            if form:
                out.append(form.group(3) if form.group(1) in "lL" else form.group(2))
                index = form.end()
                continue
            value = _DIVISOR.match(text, index) or _VALUE.match(text, index)
            if value:
                out.append("X")
                index = value.end()
            else:
                index += 1
    return "".join(out)


def _write_text_atomic(path, text):
    """Write text to path through a temporary file in the same folder and os.replace."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.", suffix=".tmp")
    umask = os.umask(0)
    os.umask(umask)
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(text)
        os.chmod(temporary, 0o666 & ~umask)  # mkstemp creates the file private (0600)
        os.replace(temporary, path)
    except BaseException:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(temporary)
        raise


def write_json_atomic(path, data):
    """Serialise data first, then write it atomically, so a failure never leaves a partial file."""
    _write_text_atomic(path, json.dumps(data, indent=1, ensure_ascii=False) + "\n")


def _missing_classes(abilities, tables):
    owners = set()
    for spell in abilities:
        if spell["category"] == "class":
            owners.update(spell["owner"].split(","))
    return sorted(row["Filename"] for row in tables["ChrClasses"] if row["Filename"] not in owners)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build the ability icon list from the game's data tables.")
    parser.add_argument("--build", required=True, help="game build, such as 1.60.1.70840")
    parser.add_argument("--from-dir", type=Path, help="folder with one <Table>.csv per table; skips the download")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output JSON file")
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE, help="download cache root")
    args = parser.parse_args(argv)

    try:
        folder = args.from_dir or download_tables(args.build, args.cache_dir)
        tables = {name: load_csv(Path(folder) / f"{name}.csv") for name in TABLES}
        spells = build_abilities(tables)
        groups = group_by_icon(spells)
        if not any(group["category"] == "class" for group in groups):
            raise ValueError("no class abilities found; check the SkillLine and SkillLineAbility columns")
    except KeyError as err:
        print(f"abilities: missing column {err}", file=sys.stderr)
        return 1
    except (OSError, ValueError, csv.Error, DownloadError) as err:
        print(f"abilities: {err}", file=sys.stderr)
        return 1

    counts = {category: sum(1 for group in groups if group["category"] == category) for category in CATEGORIES}
    write_json_atomic(
        args.out,
        {
            "build": args.build,
            "categories": list(CATEGORIES),
            "schools": {str(mask): name for mask, name in SCHOOLS.items()},
            "counts": counts,
            "icons": groups,
        },
    )
    missing = _missing_classes(spells, tables)
    if missing:
        print(f"warning: no class abilities: {', '.join(missing)}", file=sys.stderr)
    summary = ", ".join(f"{category} {count}" for category, count in counts.items())
    print(f"Wrote {len(groups)} icon groups ({summary}) from {len(spells)} spells to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
