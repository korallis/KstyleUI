"""Write every global name the Forever client gives addon code, for luacheck and the taint scan.

Usage: python3 Tools/build/gen_globals.py --source <wow-ui-source on branch forever>
                                          [--out Tools/data/forever_globals.lua]

The output is `return { read = { ... }, deprecated = { ... } }`, sorted, with a header naming the
source commit.

read holds:
  - each API namespace (`C_Spell`) and each global function in Blizzard_APIDocumentationGenerated,
    except "SecureOnly" ones, plus `Enum` and `Constants` when the docs define enumerations and
    constant tables. Widget methods ("ScriptObject" tables) are not globals.
  - each global that Blizzard's Lua defines or uses, in every file a TOC loads on the camelot
    game type into the global environment. Using a name counts because the docs omit much of the
    C API (`CreateFrame`, `InCombatLockdown`, `hooksecurefunc`) and engine frames (`UIParent`).
  - each named object Blizzard's XML creates (`PlayerFrame`, `GameFontNormal`), outside templates.
  Lua 5.1's own globals are left to luacheck's lua51 std.

deprecated holds the globals that Blizzard_Deprecated* folders define for the camelot game type
and nothing else defines. Forever does not load those folders, so these names are removed from
read even when Blizzard code still uses them.

TOC rules: the TOC is <Folder>_Camelot, _Forever, _Mainline or plain <Folder>.toc, in that order.
A game type list matches camelot when it names camelot, forever or mainline. `## AllowLoad: Glue`,
`## OnlyBetaAndPTR` and `[AllowLoad glue]` lines never load in game, and `[AllowLoadTextLocale]`
lines load only when they name enUS or enGB. Directives may stand before or after the path. `[Family]` is Mainline and
`[Game]` is Camelot. Files in a `## UseSecureEnvironment: 1` addon, or marked
`[LoadIntoEnvironment secure]`, are hidden from addons unless marked `[LoadIntoEnvironment global]`.
"""

import argparse
import dataclasses
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ADDONS = Path("Interface") / "AddOns"
DOCS = ADDONS / "Blizzard_APIDocumentationGenerated"
DEFAULT_OUT = Path(__file__).resolve().parents[1] / "data" / "forever_globals.lua"

CAMELOT_TYPES = {"camelot", "forever", "mainline"}
TEXT_LOCALES = {"enus", "engb"}
TOC_SUFFIXES = ("_Camelot", "_Forever", "_Mainline", "")
PATH_VARIABLES = {"[family]": "Mainline", "[game]": "Camelot"}
GLOBAL_ENV = "global"
SECURE_ENV = "secure"
DEPRECATED_PREFIX = "blizzard_deprecated"

IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
DIRECTIVE = re.compile(r"\[(\w+)(?:[\s:]+([^\]]*))?\]")
METADATA = re.compile(r"^##\s*([\w-]+)\s*:\s*(.*)$")

LUA51_STD = frozenset(
    "_G _VERSION arg assert collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io"
    " ipairs load loadfile loadstring math module newproxy next os package pairs pcall print rawequal"
    " rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack"
    " xpcall".split()
)
LUA_KEYWORDS = frozenset(
    "and break do else elseif end false for function if in local nil not or repeat return then true"
    " until while".split()
)

DOC_TYPE = re.compile(r'^\tType = "(\w+)",$', re.M)
DOC_NAMESPACE = re.compile(r'^\tNamespace = "([\w.]+)",$', re.M)
DOC_ENVIRONMENT = re.compile(r'^\tEnvironment = "(\w+)",$', re.M)
DOC_FUNCTION = re.compile(r'^\t\t\tName = "(\w+)",\n\t\t\tType = "Function",$', re.M)
DOC_FUNCTION_ENVIRONMENT = re.compile(r'^\t\t\tEnvironment = "(\w+)",$', re.M)
DOC_FUNCTION_END = re.compile(r"^\t\t},?$", re.M)
DOC_TABLE_TYPE = re.compile(r'^\t\t\tType = "(Enumeration|Constants)",$', re.M)
SECURE_ONLY = "SecureOnly"

LUA_TOKEN = re.compile(
    r"""
      (?P<space>\s+)
    | (?P<comment>--(?:\[(?P<ceq>=*)\[.*?\](?P=ceq)\]|[^\n]*))
    | (?P<long>\[(?P<leq>=*)\[.*?\](?P=leq)\])
    | (?P<string>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
    | (?P<number>0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)
    | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
    | (?P<op>\.\.\.|\.\.|==|~=|<=|>=|::|[-+*/%^#<>=(){}\[\];:,.])
    | (?P<other>.)
    """,
    re.X | re.S,
)
BLOCK_OPENERS = {"do", "if", "function", "repeat"}
BLOCK_CLOSERS = {"end", "until"}
OPENING_BRACKETS = {"(", "{", "["}
CLOSING_BRACKETS = {")", "}", "]"}
TABLE_KEY_PREVIOUS = {("op", "{"), ("op", ","), ("op", ";")}
FIELD_PREVIOUS = {("op", "."), ("op", ":")}


@dataclasses.dataclass
class Globals:
    read: list
    deprecated: list
    missing: list


# Game types and TOC files


def split_directives(text):
    """Return (rest, directives): text without its `[Name argument]` directives, and each
    directive as (name, argument). Path variables such as `[Family]` stay in the text."""
    found = []

    def take(match):
        name, argument = match.group(1).lower(), match.group(2)
        if argument is None and f"[{name}]" in PATH_VARIABLES:
            return match.group(0)
        found.append((name, (argument or "").strip().lower()))
        return " "

    return DIRECTIVE.sub(take, text).strip(), found


def in_list(spec, wanted):
    """Return True when a list such as "standard, camelot" or "wrath cata" names one of wanted."""
    return any(token in wanted for token in re.split(r"[\s,]+", spec.strip().lower()))


def environment_for(found, env):
    """Return the environment a line loads into on camelot, or None when it does not load."""
    for name, argument in found:
        if name == "allowloadgametype" and not in_list(argument, CAMELOT_TYPES):
            return None
        if name == "excludeloadgametype" and in_list(argument, CAMELOT_TYPES):
            return None
        if name == "allowload" and argument == "glue":
            return None
        if name == "allowloadtextlocale" and not in_list(argument, TEXT_LOCALES):
            return None
        if name == "loadintoenvironment":
            env = argument
    for name, argument in found:
        if name == "allowloadenvironment" and argument != env:
            return None
    return env


def find_toc(folder):
    """Return the TOC that Forever reads for an addon folder, or None."""
    tocs = {path.name.lower(): path for path in folder.glob("*.toc")}
    for suffix in TOC_SUFFIXES:
        toc = tocs.get(f"{folder.name}{suffix}.toc".lower())
        if toc:
            return toc
    return None


def read_toc(toc):
    """Return (metadata, lines): metadata maps each key that applies on camelot to its values,
    and lines are the (path, directives) file entries."""
    metadata = {}
    lines = []
    for raw in toc.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("##"):
            match = METADATA.match(line)
            if match:
                value, found = split_directives(match.group(2))
                if environment_for(found, GLOBAL_ENV) is not None:
                    metadata.setdefault(match.group(1).lower(), []).append(value.lower())
            continue
        if line.startswith("#"):
            continue
        path, found = split_directives(line)
        if path:
            lines.append((path, found))
    return metadata, lines


def addon_environment(metadata):
    """Return the addon's default environment on camelot, or None when it does not load in game."""
    for value in metadata.get("allowloadgametype", []):
        if not in_list(value, CAMELOT_TYPES):
            return None
    for value in metadata.get("excludeloadgametype", []):
        if in_list(value, CAMELOT_TYPES):
            return None
    if "glue" in metadata.get("allowload", []):
        return None
    if any(value not in ("", "0") for value in metadata.get("onlybetaandptr", [])):
        return None
    if any(value not in ("", "0") for value in metadata.get("usesecureenvironment", [])):
        return SECURE_ENV
    return GLOBAL_ENV


def resolve(base, rel):
    """Resolve a TOC or XML path against base, ignoring letter case as the game does."""
    rel = rel.replace("\\", "/")
    for variable, folder in PATH_VARIABLES.items():
        rel = re.sub(re.escape(variable), folder, rel, flags=re.I)
    path = base
    for part in rel.split("/"):
        if part in ("", "."):
            continue
        candidate = path / part
        if not candidate.exists() and path.is_dir():
            lowered = part.lower()
            candidate = next((entry for entry in path.iterdir() if entry.name.lower() == lowered), candidate)
        path = candidate
    return path if path.is_file() else None


# Lua


def lua_tokens(text):
    """Return the significant (kind, value) tokens of a Lua source, without comments or spaces."""
    tokens = []
    for match in LUA_TOKEN.finditer(text):
        kind = match.lastgroup
        if kind in ("space", "comment"):
            continue
        if kind in ("long", "string", "number"):
            tokens.append(("value", match.group()))
        elif kind == "name":
            value = match.group()
            tokens.append(("keyword" if value in LUA_KEYWORDS else "name", value))
        else:
            tokens.append(("op", match.group()))
    return tokens


def declared_locals(tokens):
    """Return (declared, sites). declared maps every local, parameter and loop variable the file
    declares to the token index from which its earliest declaration hides a global of that name.
    A `local` statement takes effect after the first token of its value, so `local X = X` reads
    global X. sites holds the index of each name token that declares a local."""
    declared = {"self": 0}
    sites = set()
    count = len(tokens)

    def declare(name, at, site):
        declared[name] = min(declared.get(name, at), at)
        sites.add(site)

    def name_list(j):
        names = []
        while j < count and tokens[j][0] == "name":
            names.append((tokens[j][1], j))
            if j + 1 < count and tokens[j + 1] == ("op", ","):
                j += 2
            else:
                j += 1
                break
        return names, j

    for i, (kind, value) in enumerate(tokens):
        if kind != "keyword":
            continue
        if value == "local":
            if i + 1 < count and tokens[i + 1] == ("keyword", "function"):
                if i + 2 < count and tokens[i + 2][0] == "name":
                    declare(tokens[i + 2][1], i + 2, i + 2)
                continue
            names, j = name_list(i + 1)
            at = j + 2 if j < count and tokens[j] == ("op", "=") else j
            for name, site in names:
                declare(name, at, site)
        elif value == "for":
            names, _ = name_list(i + 1)
            for name, site in names:
                declare(name, i + 1, site)
        elif value == "function":
            j = i + 1
            while j < count and tokens[j] != ("op", "("):
                j += 1
            j += 1
            while j < count and tokens[j] != ("op", ")"):
                if tokens[j][0] == "name":
                    declare(tokens[j][1], j, j)
                j += 1
    return declared, sites


def global_tables(tokens, visible):
    """Return the names that hold the global environment table: `_G` in a file loaded into the
    global environment, and any local set from `GetGlobalEnvironment()`, which is how a file in
    the secure environment publishes names to addons."""
    tables = {"_G"} if visible else set()
    for i in range(len(tokens) - 4):
        if (
            tokens[i] == ("keyword", "local")
            and tokens[i + 1][0] == "name"
            and tokens[i + 2] == ("op", "=")
            and tokens[i + 3] == ("name", "GetGlobalEnvironment")
            and tokens[i + 4] == ("op", "(")
        ):
            tables.add(tokens[i + 1][1])
    return tables


def global_field(tokens, i):
    """Return (name, assigns) for `_G.Name` or `_G["Name"]` starting after the table at i."""
    count = len(tokens)
    if i + 1 < count and tokens[i + 1] == ("op", ".") and i + 2 < count and tokens[i + 2][0] == "name":
        after = i + 3
        name = tokens[i + 2][1]
    elif (
        i + 3 < count
        and tokens[i + 1] == ("op", "[")
        and tokens[i + 2][0] == "value"
        and tokens[i + 2][1][:1] in ("'", '"')
        and tokens[i + 3] == ("op", "]")
    ):
        after = i + 4
        name = tokens[i + 2][1][1:-1]
    else:
        return None, False
    if not IDENTIFIER.match(name):
        return None, False
    return name, after < count and tokens[after] == ("op", "=")


def lua_globals(text, visible=True):
    """Return (defined, used): the global names a Lua file assigns or defines, and the ones it
    reads. After a file declares a name local anywhere, in any scope, the name is never counted
    again, which errs towards missing a global rather than inventing one. A file outside the
    global environment (visible False) counts only what it writes to or reads from the table
    `GetGlobalEnvironment()` returns."""
    tokens = lua_tokens(text)
    local, sites = declared_locals(tokens)
    tables = global_tables(tokens, visible)
    defined, used = set(), set()
    stack = []
    count = len(tokens)
    for i, (kind, value) in enumerate(tokens):
        previous = tokens[i - 1] if i > 0 else ("op", ";")
        following = tokens[i + 1] if i + 1 < count else ("op", ";")
        if kind == "name" and value in tables and previous not in FIELD_PREVIOUS:
            name, assigns = global_field(tokens, i)
            if name:
                (defined if assigns else used).add(name)
        if not visible:
            continue
        if kind == "keyword":
            if value in BLOCK_OPENERS:
                stack.append("block")
            elif value in BLOCK_CLOSERS and stack:
                stack.pop()
        elif kind == "op":
            if value in OPENING_BRACKETS:
                stack.append(value)
            elif value in CLOSING_BRACKETS and stack:
                stack.pop()
        elif (
            kind == "name"
            and i not in sites
            and previous not in FIELD_PREVIOUS
            and i < local.get(value, count)
        ):
            assigns = following == ("op", "=")
            if assigns and stack and stack[-1] == "{" and previous in TABLE_KEY_PREVIOUS:
                pass  # a table constructor key such as { Width = 10 }
            elif assigns or (previous == ("keyword", "function") and following == ("op", "(")):
                defined.add(value)
            else:
                used.add(value)
    return defined, used


# XML

FONT_TAGS = {"Font", "FontFamily"}


def local_tag(element):
    return element.tag.rsplit("}", 1)[-1] if isinstance(element.tag, str) else ""


def xml_contents(text):
    """Return (names, scripts, includes): the global object names an XML file creates and the
    files its Script and Include elements load."""
    root = ET.fromstring(text)
    names, scripts, includes = set(), [], []

    def visit(element, parent_name, in_template):
        tag = local_tag(element)
        file = element.get("file")
        if tag == "Script" and file:
            scripts.append(file)
        elif tag == "Include" and file:
            includes.append(file)
        template = in_template or any(
            (element.get(flag) or "").lower() == "true" for flag in ("virtual", "intrinsic")
        )
        name = element.get("name")
        resolved = None
        if name:
            if re.search(r"\$parent", name, re.I):
                resolved = re.sub(r"\$parent", parent_name, name, flags=re.I) if parent_name else None
            else:
                resolved = name
            if resolved and IDENTIFIER.match(resolved) and (tag in FONT_TAGS or not template):
                names.add(resolved)
        for child in element:
            visit(child, resolved or parent_name, template)

    visit(root, None, False)
    return names, scripts, includes


# Walking the source


class Walker:
    """Collect the globals of every file the chosen addons load on camelot."""

    def __init__(self):
        self.defined = set()
        self.used = set()
        self.missing = []
        self.seen = set()

    def walk_addon(self, folder):
        toc = find_toc(folder)
        if toc is None:
            return
        metadata, lines = read_toc(toc)
        env = addon_environment(metadata)
        if env is None:
            return
        for rel, found in lines:
            line_env = environment_for(found, env)
            if line_env is None:
                continue
            path = resolve(folder, rel)
            if path is None:
                self.missing.append(f"{toc.name}: {rel}")
                continue
            self.load(folder, path, line_env == GLOBAL_ENV)

    def load(self, folder, path, visible):
        key = (path, visible)
        if key in self.seen:
            return
        self.seen.add(key)
        text = path.read_text(encoding="utf-8", errors="replace")
        suffix = path.suffix.lower()
        if suffix == ".lua":
            defined, used = lua_globals(text, visible)
            self.defined |= defined
            self.used |= used
        elif suffix == ".xml":
            try:
                names, scripts, includes = xml_contents(text)
            except ET.ParseError as err:
                raise ValueError(f"{path}: {err}") from err
            if visible:
                self.defined |= names
            for rel in scripts + includes:
                # The game looks next to the XML file first, then in the addon folder.
                child = resolve(path.parent, rel) or resolve(folder, rel)
                if child is None:
                    self.missing.append(f"{path.name}: {rel}")
                else:
                    self.load(folder, child, visible)


def doc_globals(docs):
    """Return (names, secure_only): the global names the generated API documentation declares
    for addon code, and the ones it reserves for the secure environment."""
    names, secure_only = set(), set()
    for path in sorted(docs.glob("*.lua")):
        text = path.read_text(encoding="utf-8", errors="replace")
        for table_type in DOC_TABLE_TYPE.findall(text):
            names.add("Enum" if table_type == "Enumeration" else "Constants")
        kind = DOC_TYPE.search(text)
        if not kind or kind.group(1) != "System":
            continue
        environment = DOC_ENVIRONMENT.search(text)
        system_secure = bool(environment and environment.group(1) == SECURE_ONLY)
        namespace = DOC_NAMESPACE.search(text)
        if namespace:
            (secure_only if system_secure else names).add(namespace.group(1).split(".")[0])
            continue
        for match in DOC_FUNCTION.finditer(text):
            end = DOC_FUNCTION_END.search(text, match.end())
            body = text[match.end() : end.start() if end else len(text)]
            function_environment = DOC_FUNCTION_ENVIRONMENT.search(body)
            function_secure = bool(function_environment and function_environment.group(1) == SECURE_ONLY)
            (secure_only if system_secure or function_secure else names).add(match.group(1))
    return names, secure_only


def addon_folders(source):
    return sorted(path for path in (Path(source) / ADDONS).iterdir() if path.is_dir())


def collect(source):
    """Return the Globals for a wow-ui-source checkout."""
    real, shims = Walker(), Walker()
    for folder in addon_folders(source):
        (shims if folder.name.lower().startswith(DEPRECATED_PREFIX) else real).walk_addon(folder)
    documented, secure_only = doc_globals(Path(source) / DOCS)
    defined = documented | real.defined
    deprecated = (shims.defined - defined) - LUA51_STD
    read = ((defined | real.used) - deprecated - secure_only) - LUA51_STD
    return Globals(sorted(read), sorted(deprecated), real.missing + shims.missing)


# Output


def describe(source):
    """Return "<short hash> <subject>" for the source checkout's HEAD commit."""
    result = subprocess.run(
        ["git", "-C", str(source), "log", "-1", "--format=%h %s"], capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"{source} is not a git checkout: {result.stderr.strip()}")
    return result.stdout.strip()


def render(found, commit):
    lines = [
        f"-- forever_globals.lua: global names the Forever client gives addons, from wow-ui-source {commit}."
        " Generated by Tools/build/gen_globals.py; do not edit.",
        "return {",
        "\tread = {",
    ]
    lines += [f'\t\t"{name}",' for name in found.read]
    lines += ["\t},", "\tdeprecated = {"]
    lines += [f'\t\t"{name}",' for name in found.deprecated]
    lines += ["\t},", "}"]
    return "\n".join(lines) + "\n"


def write_atomically(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=path.name, suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", required=True, type=Path, help="wow-ui-source checkout on branch forever")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="Lua file to write")
    args = parser.parse_args(argv)

    if not (args.source / DOCS).is_dir():
        print(f"error: {args.source / DOCS} does not exist", file=sys.stderr)
        return 1
    try:
        found = collect(args.source)
        commit = describe(args.source)
    except (RuntimeError, ValueError) as err:
        print(f"error: {err}", file=sys.stderr)
        return 1
    if not found.read:
        print(f"error: no globals found in {args.source}", file=sys.stderr)
        return 1
    for entry in found.missing:
        print(f"warning: listed but missing: {entry}", file=sys.stderr)
    write_atomically(args.out, render(found, commit))
    print(f"wrote {len(found.read)} read and {len(found.deprecated)} deprecated globals to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
