"""Build Tools/data/items.json: every item icon KstyleUI may replace, grouped by icon.

Usage: python3 Tools/icons/items.py --build 1.60.1.70840 [--from-dir DIR]
                                    [--out Tools/data/items.json] [--cache-dir DIR]

Without --from-dir the script downloads Item, ItemSparse, ItemClass and ItemSubClass from wago.tools
into Tools/data/db2cache/<build>/ with abilities.download_tables and reuses the files already there.

An item counts when the client has its ItemSparse row (its name and stats), the name is not a
placeholder (Monster -, OLD, Deprecated, [PH], test items) and the deprecated flag is clear. Items
share icons, so the output has one entry per icon file ID: the icon's category is "item", its name is
the most common item name (ties to the lowest item ID), its kind is the item class and subclass of
that item, and it lists up to MAX_ITEMS items by ID with the count of all of them. Each entry has a
rank, the order the icon generators draw them in: what a player sees most often comes first.

    1 consumables          potions, food, scrolls, bandages
    2 trade goods          cloth, ore, herbs, reagents and recipes
    3 gear                 weapons and armour of every quality
    4 containers           bags, quivers, ammunition and keys
    5 quest items
    6 everything else      junk, mounts, pets, gems, tokens

Within a rank an icon more items share comes first. iconset.py merges the file with abilities.json;
an icon a spell already uses keeps the spell's group.
"""

import argparse
import collections
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import abilities  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
DEFAULT_OUT = REPO / "Tools" / "data" / "items.json"

TABLES = ("Item", "ItemSparse", "ItemClass", "ItemSubClass")
MAX_ITEMS = 6  # items listed per icon; count carries the rest
FLAG_DEPRECATED = 0x10  # ItemSparse.Flags_0
PLACEHOLDER = re.compile(r"^(Monster ?-|Deprecated|OLD|zz|\[PH\]|\[DEP\]|\[DND\]|Test |QA |Unused|DEBUG|NPC |PH |\(PH\))", re.I)

CONSUMABLE, CONTAINER, WEAPON, ARMOR, REAGENT, PROJECTILE, TRADE_GOODS, RECIPE, QUIVER, QUEST, KEY = (
    0, 1, 2, 4, 5, 6, 7, 9, 11, 12, 13)
RANKS = {1: "consumables", 2: "trade goods", 3: "gear", 4: "containers", 5: "quest items", 6: "everything else"}
RANK_OF_CLASS = {
    CONSUMABLE: 1,
    TRADE_GOODS: 2, REAGENT: 2, RECIPE: 2,
    WEAPON: 3, ARMOR: 3,
    CONTAINER: 4, QUIVER: 4, PROJECTILE: 4, KEY: 4,
    QUEST: 5,
}
OTHER_RANK = 6

# The shape of one item entry, for tests and for the docstring of group_items.
SAMPLE_ITEM = {"id": 0, "name": "", "classID": 0, "subclassID": 0, "quality": 1, "level": 0, "kind": "Consumable"}


def _int(value):
    return int(value) if value not in (None, "") else 0


def item_rank(class_id):
    return RANK_OF_CLASS.get(class_id, OTHER_RANK)


def _kind(class_name, sub_name):
    """The item class and, when it adds something, the subclass: "Weapon (One-Handed Swords)"."""
    if not sub_name or sub_name == class_name or "OBSOLETE" in sub_name:
        return class_name
    return f"{class_name} ({sub_name})"


def is_placeholder(name, flags):
    return not name or bool(PLACEHOLDER.search(name)) or "DEPRECATED" in name.upper() or "(TEST)" in name.upper() \
        or "DNT" in name or bool(flags & FLAG_DEPRECATED)


def build_entries(tables):
    """Return one entry per item the client knows and a player may see, sorted by item ID."""
    classes = {_int(row["ClassID"]): row["ClassName_lang"] for row in tables["ItemClass"]}
    subclasses = {}
    for row in tables["ItemSubClass"]:
        subclasses[(_int(row["ClassID"]), _int(row["SubClassID"]))] = row["VerboseName_lang"] or row["DisplayName_lang"]
    sparse = {_int(row["ID"]): row for row in tables["ItemSparse"]}
    result = []
    for row in sorted(tables["Item"], key=lambda r: _int(r["ID"])):
        item_id, icon = _int(row["ID"]), _int(row["IconFileDataID"])
        info = sparse.get(item_id)
        if info is None or icon <= 0:
            continue
        name = info["Display_lang"]
        if is_placeholder(name, _int(info["Flags_0"])):
            continue
        class_id, sub_id = _int(row["ClassID"]), _int(row["SubclassID"])
        class_name = classes.get(class_id, str(class_id))
        result.append({
            "id": item_id,
            "name": name,
            "icon": icon,
            "classID": class_id,
            "subclassID": sub_id,
            "quality": _int(info["OverallQualityID"]),
            "level": _int(info["RequiredLevel"]),
            "kind": _kind(class_name, subclasses.get((class_id, sub_id), "")),
        })
    return result


def group_items(entries):
    """Group items by icon file ID: one group per icon with category item, the most common name (ties to
    the lowest item ID), that item's kind, the best rank among the items, the count of all items and the
    first MAX_ITEMS by ID. Sorted by rank, then by count descending, then by icon."""
    by_icon = collections.defaultdict(list)
    for entry in entries:
        by_icon[entry.get("icon", 0)].append(entry)
    groups = []
    for icon, items in by_icon.items():
        items = sorted(items, key=lambda item: item["id"])
        names = collections.Counter(item["name"] for item in items)
        best = max(names.values())
        lead = next(item for item in items if names[item["name"]] == best)
        groups.append({
            "icon": icon,
            "category": "item",
            "name": lead["name"],
            "kind": lead.get("kind", ""),
            "rank": min(item_rank(item.get("classID", OTHER_RANK)) for item in items),
            "count": len(items),
            "items": [{key: value for key, value in item.items() if key not in ("icon", "kind")} for item in items[:MAX_ITEMS]],
        })
    return sorted(groups, key=lambda g: (g["rank"], -g["count"], g["icon"]))


def build_items(tables):
    """The icon groups of the tables: group_items over build_entries."""
    return group_items(build_entries(tables))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build the item icon list from the game's data tables.")
    parser.add_argument("--build", required=True, help="game build, such as 1.60.1.70840")
    parser.add_argument("--from-dir", type=Path, help="folder with one <Table>.csv per table; skips the download")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output JSON file")
    parser.add_argument("--cache-dir", type=Path, default=abilities.DEFAULT_CACHE, help="download cache root")
    args = parser.parse_args(argv)

    try:
        folder = args.from_dir or abilities.download_tables(args.build, args.cache_dir, tables=TABLES)
        tables = {name: abilities.load_csv(Path(folder) / f"{name}.csv") for name in TABLES}
        groups = build_items(tables)
        if not groups:
            raise ValueError("no items found; check the Item and ItemSparse columns")
    except KeyError as err:
        print(f"items: missing column {err}", file=sys.stderr)
        return 1
    except (OSError, ValueError, csv.Error, abilities.DownloadError) as err:
        print(f"items: {err}", file=sys.stderr)
        return 1

    counts = {str(rank): sum(1 for group in groups if group["rank"] == rank) for rank in RANKS}
    abilities.write_json_atomic(
        args.out,
        {
            "build": args.build,
            "categories": ["item"],
            "ranks": {str(rank): name for rank, name in RANKS.items()},
            "counts": counts,
            "icons": groups,
        },
    )
    items = sum(group["count"] for group in groups)
    summary = ", ".join(f"{RANKS[int(rank)]} {count}" for rank, count in counts.items())
    print(f"Wrote {len(groups)} icon groups ({summary}) from {items} items to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
