"""Write KstyleUI_Meters/SpellSchools.lua: the school of every non-physical spell in Tools/data/abilities.json.

Usage: python3 Tools/build/gen_spell_schools.py [--out KstyleUI_Meters/SpellSchools.lua]

The client gives addons no school for a spell ID (C_Spell.GetSpellInfo returns name, icon, cast time,
ranges and the ID; Blizzard_DamageMeter reads none), so the Damage Meter's school colours come from
this table. A spell with several schools takes the first of holy, fire, nature, frost, shadow, arcane
(the order KstyleUI_CombatText uses); a spell missing here is drawn as physical.
"""

import argparse
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DATA = REPO / "Tools" / "data" / "abilities.json"
DEFAULT_OUT = REPO / "KstyleUI_Meters" / "SpellSchools.lua"
ORDER = (2, 4, 8, 16, 32, 64)
PER_LINE = 12
HEADER = "-- SpellSchools.lua: the school of every non-physical spell in Tools/data/abilities.json, written by Tools/build/gen_spell_schools.py; the client gives addons no school for a spell ID."


def primary(mask):
    for school in ORDER:
        if mask & school:
            return school
    return 1


def schools(data):
    """The non-physical spell IDs of each school, ascending."""
    out = {school: set() for school in ORDER}
    for icon in data["icons"]:
        for spell in icon["spells"]:
            school = primary(spell["school"])
            if school != 1:
                out[school].add(spell["id"])
    return {school: sorted(ids) for school, ids in out.items() if ids}


def render(data):
    lines = [HEADER, "local _, ns = ...", "", "local DATA = {"]
    for school, ids in schools(data).items():
        lines.append("\t[%d] = {" % school)
        for i in range(0, len(ids), PER_LINE):
            lines.append("\t\t" + ", ".join(str(n) for n in ids[i : i + PER_LINE]) + ",")
        lines.append("\t},")
    lines += [
        "}",
        "",
        "local map = {}",
        "for school, ids in pairs(DATA) do",
        "\tfor i = 1, #ids do",
        "\t\tmap[ids[i]] = school",
        "\tend",
        "end",
        "ns.SpellSchools = map",
        "",
    ]
    return "\r\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    data = json.loads(DATA.read_text(encoding="utf-8"))
    args.out.write_bytes(render(data).encode("ascii"))


if __name__ == "__main__":
    main()
