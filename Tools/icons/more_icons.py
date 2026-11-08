"""Build Tools/data/icons_more.json: every icon the Forever client has that abilities.json and items.json do not
cover, grouped by file ID and ranked by what a player sees.

Usage: python3 Tools/icons/more_icons.py --build 1.60.1.70862 --from-dir Tools/data/db2cache/<build>
                                         --client ~/.local/share/wow-dev/icons/blizzard-all/client.csv
                                         [--known Tools/data/abilities.json --known Tools/data/items.json]
                                         [--out Tools/data/icons_more.json]

--from-dir holds one <Table>.csv per table in TABLES, exported from the installed client with
Tools/icons/casc_export.py (TACTTool and DBC2CSV read the game folder and never write to it). --client lists
the icons the client has, one id;Interface/ICONS/<Name>.blp row per icon, as a listfile does: Tools/icons/iconset.py
names writes it from the files TACTTool extracted. Every --known file's icons are left out: the first two data
files already cover them.

Each remaining icon becomes one group with a category, the order the generator draws them in, and a name:

    spell         SpellMisc's SpellIconFileDataID (joined on SpellMisc.SpellID, not the record's own ID), named
                  by the spells that use it (SpellName), or after the file when every spell is nameless. Rank 1
                  when a talent or a spell with a clean name uses the icon, rank 2 when only placeholder or
                  nameless spells ([DND], Test, zzOLD) do.
    currency      CurrencyTypes.InventoryIconFileID, named by the currency.
    mount         A spell icon one of whose spells is a mount's source spell (Mount.SourceSpellID), named by
                  the mount; it comes out of the spell groups before they are classified as spells.
    companion     BattlePetSpecies.IconFileDataID, named after the file (the species table carries no name).
    achievement   Achievement.IconFileID, named by the title.
    unlisted      Item.IconFileDataID for items items.json dropped (no ItemSparse row, a placeholder name or the
                  deprecated flag), named by the item when it has a name, else after the file.
    misc          Everything else: an icon no table references, named after the file (INV_Misc_Bag_07 reads as
                  "Misc Bag 07"), so the prompt still hints at the subject.

Within a category the groups come by rank, then by how many rows share the icon, then by file ID. The output has
the same shape as items.json ({build, categories, counts, icons}); each group carries the Blizzard file name as
file, its category, name, rank and count, a spell group its spells (up to MAX_SPELLS) and school, and an unlisted
group its kind. iconset.py merges the file after the other two, so its groups generate last and an icon a spell or
item group already has is never repeated.
"""

import argparse
import collections
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import abilities  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
DEFAULT_OUT = REPO / "Tools" / "data" / "icons_more.json"
DEFAULT_KNOWN = (REPO / "Tools" / "data" / "abilities.json", REPO / "Tools" / "data" / "items.json")

TABLES = ("SpellMisc", "SpellName", "Talent", "CurrencyTypes", "Achievement", "Mount", "BattlePetSpecies", "Item", "ItemSparse")
CATEGORIES = ("spell", "currency", "mount", "companion", "achievement", "unlisted", "misc")
MAX_SPELLS = 6
PLACEHOLDER = re.compile(r"(^\s*(\[|\()?\s*(DND|PH|DEP|DEPRECATED|Test|QA|OLD|zz|Unused|DEBUG|NPC|Monster ?-))|\((PH|DND)\)|\btest\b", re.I)
PREFIXES = ("INV", "Spell", "Ability", "Achievement", "Trade", "Creature", "Racial", "Pet", "Mount", "Companion")
ICON_ROW = re.compile(r"^(\d+);(?:[^;]*/)?interface/icons/([^/;]+)\.blp$", re.IGNORECASE)


def _int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def clean_name(name):
    """True for a name a player may read: not a placeholder."""
    return bool(name and name.strip()) and not PLACEHOLDER.search(name)


def file_words(name):
    """A Blizzard icon file name as words: the leading family prefix dropped, underscores and dashes as spaces."""
    name = re.sub(r"\.(tga|png|blp)$", "", name, flags=re.I)
    parts = [part for part in re.split(r"[_\-]+", name) if part]
    while len(parts) > 1 and parts[0] in PREFIXES:
        parts = parts[1:]
    return " ".join(parts)


def load_client(path):
    """{fileID: Name} from a listfile-shaped listing of the client's icons."""
    client = {}
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = ICON_ROW.match(line.rstrip("\r\n"))
            if match:
                client[int(match.group(1))] = match.group(2)
    return client


def load_known(paths):
    """The icon file IDs of the data files that already have groups."""
    known = set()
    for path in paths:
        data = json.loads(Path(path).read_text())
        known.update(_int(group["icon"]) for group in data["icons"])
    return known


def _spell_groups(tables, candidates, client):
    """The spell and mount groups: one per icon SpellMisc gives a spell, keyed by the spell's own ID (SpellID)."""
    names = {_int(row["ID"]): row.get("Name_lang", "") for row in tables.get("SpellName", [])}
    talents = {_int(row["SpellID"]) for row in tables.get("Talent", [])}
    mounts = {_int(row["SourceSpellID"]): row.get("Name_lang", "") for row in tables.get("Mount", [])}
    by_icon = collections.defaultdict(list)
    for row in tables.get("SpellMisc", []):
        icon = _int(row.get("SpellIconFileDataID"))
        if icon in candidates:
            spell = _int(row.get("SpellID"))
            by_icon[icon].append({"id": spell, "name": mounts.get(spell) or names.get(spell, ""), "school": _int(row.get("SchoolMask")),
                                  "talent": spell in talents, "mount": spell in mounts})
    groups = {}
    for icon, spells in by_icon.items():
        spells.sort(key=lambda s: s["id"])
        mount = next((s for s in spells if s["mount"]), None)
        clean = [s for s in spells if clean_name(s["name"])]
        lead_pool = clean or spells
        counter = collections.Counter(s["name"] for s in lead_pool)
        best = max(counter.values())
        lead = mount or next(s for s in lead_pool if counter[s["name"]] == best)
        groups[icon] = {
            "category": "mount" if mount else "spell", "name": lead["name"] or file_words(client[icon]), "school": lead["school"] or 1,
            "rank": 1 if mount or clean or any(s["talent"] for s in spells) else 2, "count": len(spells),
            "spells": [{"id": s["id"], "name": s["name"]} for s in spells[:MAX_SPELLS]],
        }
    return groups


def _simple_groups(rows, icon_field, name_field, category, candidates, client):
    groups = {}
    for row in rows:
        icon = _int(row.get(icon_field))
        if icon in candidates and icon not in groups:
            name = (row.get(name_field) or "").strip() if name_field else ""
            groups[icon] = {"category": category, "name": name or file_words(client[icon]), "rank": 1, "count": 0}
        if icon in groups:
            groups[icon]["count"] += 1
    return groups


def _unlisted_groups(tables, candidates, client):
    sparse = {_int(row["ID"]): row for row in tables.get("ItemSparse", [])}
    groups = {}
    for row in sorted(tables.get("Item", []), key=lambda r: _int(r["ID"])):
        icon = _int(row.get("IconFileDataID"))
        if icon not in candidates:
            continue
        info = sparse.get(_int(row["ID"]))
        name = (info or {}).get("Display_lang", "").strip()
        group = groups.get(icon)
        if group is None:
            group = {"category": "unlisted", "name": name or file_words(client[icon]), "kind": "item", "rank": 1, "count": 0, "items": []}
            groups[icon] = group
        group["count"] += 1
        if len(group["items"]) < MAX_SPELLS:
            group["items"].append({"id": _int(row["ID"]), "name": name or file_words(client[icon])})
    return groups


def build_groups(tables, client, known=()):
    """One group per client icon that known does not cover, in generation order."""
    candidates = {icon for icon in client if icon not in set(known)}
    groups = {}
    builders = (
        lambda: _spell_groups(tables, candidates, client),
        lambda: _simple_groups(tables.get("CurrencyTypes", []), "InventoryIconFileID", "Name_lang", "currency", candidates, client),
        lambda: _simple_groups(tables.get("BattlePetSpecies", []), "IconFileDataID", None, "companion", candidates, client),
        lambda: _simple_groups(tables.get("Achievement", []), "IconFileID", "Title_lang", "achievement", candidates, client),
        lambda: _unlisted_groups(tables, candidates, client),
    )
    for build in builders:
        for icon, group in build().items():
            if icon not in groups:
                groups[icon] = group
    for icon in candidates:
        if icon not in groups:
            groups[icon] = {"category": "misc", "name": file_words(client[icon]), "rank": 1, "count": 0}
    out = []
    for icon, group in groups.items():
        out.append({"icon": icon, "file": client[icon], **group})
    return sorted(out, key=lambda g: (CATEGORIES.index(g["category"]), g["rank"], -g["count"], g["icon"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build the list of the client's other icons from its data tables.")
    parser.add_argument("--build", required=True, help="game build, such as 1.60.1.70862")
    parser.add_argument("--from-dir", type=Path, required=True, help="folder with one <Table>.csv per table")
    parser.add_argument("--client", type=Path, required=True, help="id;path listing of the icons the client has")
    parser.add_argument("--known", type=Path, action="append", help="data files whose icons are already covered (default: abilities.json and items.json)")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output JSON file")
    args = parser.parse_args(argv)

    tables = {name: abilities.load_csv(args.from_dir / f"{name}.csv") for name in TABLES if (args.from_dir / f"{name}.csv").exists()}
    client = load_client(args.client)
    known = load_known(args.known or DEFAULT_KNOWN)
    groups = build_groups(tables, client, known)
    counts = collections.Counter(group["category"] for group in groups)
    data = {"build": args.build, "categories": list(CATEGORIES), "counts": {c: counts.get(c, 0) for c in CATEGORIES}, "icons": groups}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    # One group per line keeps the file small and its diffs readable.
    head = {key: value for key, value in data.items() if key != "icons"}
    text = json.dumps(head, ensure_ascii=False)[:-1] + ', "icons": [\n' + ",\n".join(json.dumps(g, ensure_ascii=False, separators=(",", ":")) for g in groups) + "\n]}\n"
    args.out.write_text(text, encoding="utf-8")
    print(f"wrote {len(groups)} icon groups to {args.out}: " + ", ".join(f"{c} {counts.get(c, 0)}" for c in CATEGORIES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
