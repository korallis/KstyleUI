"""Keep KstyleUI's string tables in step with the code.

The English base (Tools/locale/enUS.json) lists every L["..."] key the game loads. Each translation
lives as UTF-8 in Tools/locale/<code>.json, and this script writes it to Core/Locales/<code>.lua as
ASCII, with every other byte as a Lua decimal escape, because addon files are ASCII only.

    python3 Tools/locale/strings.py sync     # rewrite the base, drop stale entries, write the Lua files
    python3 Tools/locale/strings.py check    # change nothing; list each problem and exit 1 if any
    python3 Tools/locale/strings.py stats    # how much of the base each locale covers
    python3 Tools/locale/strings.py missing deDE   # the English keys deDE has not translated
"""

import argparse
import json
import re
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(ROOT / "Tools" / "hooks"))

from toc_files import toc_files  # noqa: E402

LOCALES = ("deDE", "frFR", "esES", "zhCN")
NAMES = {"deDE": "German", "frFR": "French", "esES": "Spanish", "zhCN": "Simplified Chinese"}
BASE = "enUS"
OUT_DIR = Path("Core") / "Locales"
SYNC = "python3 Tools/locale/strings.py sync"

KEY = re.compile(r'(?<!\w)L\[\s*"((?:[^"\\\n]|\\.)*)"\s*\]')
SPEC = re.compile(r"%(?:%|[-+ #0]*\d*(?:\.\d+)?[cdEefgGioqsuxX])")
CODE = re.compile(r"\|(?:c[0-9a-fA-F]{8}|r|n|T[^|]*\|t|A[^|]*\|a|H[^|]*\|h|h)")
ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\\": "\\", '"': '"', "'": "'", "\n": "\n"}
PLAIN = {"\\": "\\\\", '"': '\\"', "\n": "\\n", "\r": "\\r", "\t": "\\t"}
# The faces KstyleUI bundles. A locale in GAME_FONT_LOCALES draws in the game's own font instead
# (Core/Locale.lua), so only the other locales must fit these faces, capitals included.
FACES = (
    "Cinzel-SemiBold.ttf",
    "AlegreyaSansTabular-Regular.ttf",
    "AlegreyaSansTabular-Medium.ttf",
    "AlegreyaSansTabular-Bold.ttf",
    "SourceSans3-Regular.ttf",
    "SourceSans3-Semibold.ttf",
    "Inter-SemiBold.ttf",
)
FONT_DIR = Path("Media") / "Fonts"
GAME_FONT_LOCALES = ("zhCN",)
EDGE = re.compile(r"^(\s*).*?(\s*)$", re.S)
ENTRY = re.compile(r'^\t\["((?:[^"\\]|\\.)*)"\] = "((?:[^"\\]|\\.)*)",$')


def unescape(text):
    """Decode the body of a double-quoted Lua 5.1 string into the text it holds."""
    out, i, raw = bytearray(), 0, text.encode("utf-8")
    while i < len(raw):
        byte = raw[i]
        if byte != 0x5C:
            out.append(byte)
            i += 1
            continue
        nxt = chr(raw[i + 1])
        if nxt.isdigit():
            digits = re.match(rb"\d{1,3}", raw[i + 1:i + 4]).group(0)
            out.append(int(digits))
            i += 1 + len(digits)
        elif nxt in ESCAPES:
            out.extend(ESCAPES[nxt].encode("ascii"))
            i += 2
        else:
            raise ValueError("unknown Lua escape \\" + nxt + " in " + repr(text))
    return out.decode("utf-8")


def escape(text):
    """Write text as the body of a double-quoted Lua string that holds only printable ASCII."""
    out = []
    for char in text:
        if char in PLAIN:
            out.append(PLAIN[char])
        elif " " <= char <= "~":
            out.append(char)
        else:
            out.extend("\\%03d" % byte for byte in char.encode("utf-8"))
    return "".join(out)


def code_keys(root=ROOT):
    """Return {key: [files]} for every L["..."] in the Lua files the game loads."""
    found, root = {}, Path(root).resolve()
    for path in toc_files(root):
        rel = Path(path).resolve().relative_to(root).as_posix()
        if not rel.endswith(".lua") or rel.startswith(OUT_DIR.as_posix() + "/"):
            continue
        text = (root / rel).read_text(encoding="ascii")
        for match in KEY.finditer(text):
            found.setdefault(unescape(match.group(1)), []).append(rel)
    return found


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent="\t", sort_keys=isinstance(value, dict)) + "\n", encoding="utf-8")


def base(root=ROOT):
    path = Path(root) / "Tools" / "locale" / (BASE + ".json")
    return read_json(path) if path.exists() else []


def source(code, root=ROOT):
    path = Path(root) / "Tools" / "locale" / (code + ".json")
    return read_json(path) if path.exists() else {}


def render(code, table):
    """Return the CRLF Lua file for one locale's table."""
    lines = [
        "-- %s.lua: %s strings for KstyleUI.L, written by Tools/locale/strings.py from Tools/locale/%s.json." % (code, NAMES[code], code),
        "local _, ns = ...",
        "",
        'if not ns.Locale.Uses("%s") then' % code,
        "\treturn",
        "end",
        "",
        "ns.Locale.Add({",
    ]
    for key in sorted(table):
        lines.append('\t["%s"] = "%s",' % (escape(key), escape(table[key])))
    lines.append("})")
    return "\r\n".join(lines) + "\r\n"


def parse(text):
    """Read a generated locale file back into {key: text}, decoding every escape."""
    table = {}
    for line in text.replace("\r\n", "\n").split("\n"):
        match = ENTRY.match(line)
        if match:
            table[unescape(match.group(1))] = unescape(match.group(2))
    return table


def xml():
    files = "".join('\t<Script file="%s.lua"/>\r\n' % code for code in LOCALES)
    return '<Ui xmlns="http://www.blizzard.com/wow/ui/">\r\n' + files + "</Ui>\r\n"


def codepoints(path):
    """Return the set of code points a TrueType font maps to a glyph (cmap formats 4 and 12)."""
    data = Path(path).read_bytes()
    tables = {}
    for i in range(struct.unpack(">H", data[4:6])[0]):
        tag, _, offset, _ = struct.unpack(">4sIII", data[12 + 16 * i:28 + 16 * i])
        tables[tag] = offset
    base = tables[b"cmap"]
    found = set()
    for i in range(struct.unpack(">H", data[base + 2:base + 4])[0]):
        sub = base + struct.unpack(">I", data[base + 8 + 8 * i:base + 12 + 8 * i])[0]
        kind = struct.unpack(">H", data[sub:sub + 2])[0]
        if kind == 4:
            count = struct.unpack(">H", data[sub + 6:sub + 8])[0] // 2
            ends = struct.unpack(">%dH" % count, data[sub + 14:sub + 14 + 2 * count])
            starts = struct.unpack(">%dH" % count, data[sub + 16 + 2 * count:sub + 16 + 4 * count])
            deltas = struct.unpack(">%dh" % count, data[sub + 16 + 4 * count:sub + 16 + 6 * count])
            at = sub + 16 + 6 * count
            ranges = struct.unpack(">%dH" % count, data[at:at + 2 * count])
            for k in range(count):
                for char in range(starts[k], ends[k] + 1):
                    if ranges[k]:
                        spot = at + 2 * k + ranges[k] + 2 * (char - starts[k])
                        glyph = struct.unpack(">H", data[spot:spot + 2])[0]
                        glyph = glyph and (glyph + deltas[k]) & 0xFFFF
                    else:
                        glyph = (char + deltas[k]) & 0xFFFF
                    if glyph and char != 0xFFFF:
                        found.add(char)
        elif kind == 12:
            for k in range(struct.unpack(">I", data[sub + 12:sub + 16])[0]):
                first, last, _ = struct.unpack(">III", data[sub + 16 + 12 * k:sub + 28 + 12 * k])
                found.update(range(first, last + 1))
    return found


def capital(char):
    """The capital Core/Locale.lua's Upper writes for char; it has none for a letter like ß."""
    upper = char.upper()
    return upper if len(upper) == 1 else char


def tokens(pattern, text):
    return [m.group(0).lower() for m in pattern.finditer(text)]


def problems(root=ROOT):
    """Return every way the base, the sources and the Lua files disagree with the code."""
    root = Path(root)
    out = []
    faces = {face: codepoints(root / FONT_DIR / face) for face in FACES if (root / FONT_DIR / face).exists()}
    keys, listed = code_keys(root), base(root)
    known = set(listed)
    for key in sorted(set(keys) - known):
        out.append("%s uses L[%s], which the English base lacks; run %s" % (keys[key][0], json.dumps(key), SYNC))
    for key in sorted(known - set(keys)):
        out.append("the English base lists %s, which no code uses; run %s" % (json.dumps(key), SYNC))
    if listed != sorted(listed):
        out.append("the English base is not sorted; run " + SYNC)
    if not (root / OUT_DIR / "Locales.xml").exists() or (root / OUT_DIR / "Locales.xml").read_bytes() != xml().encode("ascii"):
        out.append("%s is stale; run %s" % ((OUT_DIR / "Locales.xml").as_posix(), SYNC))
    for code in LOCALES:
        table = source(code, root)
        for key, text in sorted(table.items()):
            name = "%s %s" % (code, json.dumps(key, ensure_ascii=False))
            if key not in known:
                out.append("%s translates a key the English base lacks; run %s" % (name, SYNC))
            if not isinstance(text, str) or text.strip() == "":
                out.append("%s is empty" % name)
                continue
            if tokens(SPEC, text) != tokens(SPEC, key):
                out.append("%s changes the format specifiers %s to %s" % (name, tokens(SPEC, key), tokens(SPEC, text)))
            if sorted(tokens(CODE, text)) != sorted(tokens(CODE, key)):
                out.append("%s changes the escape codes %s to %s" % (name, tokens(CODE, key), tokens(CODE, text)))
            if text.count("\n") != key.count("\n"):
                out.append("%s changes the number of lines" % name)
            if EDGE.match(text).groups() != EDGE.match(key).groups():
                out.append("%s must keep the key's leading and trailing space" % name)
            if code not in GAME_FONT_LOCALES:
                for char in sorted(set(text) | {capital(c) for c in text}):
                    if char.isspace():
                        continue
                    lacking = [face for face, have in faces.items() if ord(char) not in have]
                    if lacking:
                        out.append("%s uses %s (U+%04X), which %s lacks" % (name, char, ord(char), ", ".join(lacking)))
        path = root / OUT_DIR / (code + ".lua")
        if not path.exists() or path.read_bytes() != render(code, table).encode("ascii"):
            out.append("%s is stale; run %s" % (path.relative_to(root).as_posix(), SYNC))
    return out


def sync(root=ROOT):
    root = Path(root)
    keys = sorted(code_keys(root))
    write_json(root / "Tools" / "locale" / (BASE + ".json"), keys)
    known = set(keys)
    (root / OUT_DIR).mkdir(parents=True, exist_ok=True)
    (root / OUT_DIR / "Locales.xml").write_bytes(xml().encode("ascii"))
    for code in LOCALES:
        table = {k: v for k, v in source(code, root).items() if k in known}
        if (root / "Tools" / "locale" / (code + ".json")).exists():
            write_json(root / "Tools" / "locale" / (code + ".json"), table)
        (root / OUT_DIR / (code + ".lua")).write_bytes(render(code, table).encode("ascii"))


def stats(root=ROOT):
    total = len(base(root))
    lines = []
    for code in LOCALES:
        have = len(source(code, root))
        lines.append("%s %d/%d (%.1f%%)" % (code, have, total, 100.0 * have / max(total, 1)))
    return lines


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=("sync", "check", "stats", "missing"))
    parser.add_argument("locale", nargs="?", help="for missing: the locale to list")
    args = parser.parse_args(argv)
    if args.command == "sync":
        sync()
        print("\n".join(stats()))
        return 0
    if args.command == "stats":
        print("\n".join(stats()))
        return 0
    if args.command == "missing":
        have = source(args.locale)
        for key in base():
            if key not in have:
                print(json.dumps(key, ensure_ascii=False))
        return 0
    found = problems()
    for line in found:
        print(line)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
