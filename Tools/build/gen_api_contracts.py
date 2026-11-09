"""Write the Forever API contracts that addon code is checked against, for Tools/hooks/check_api_contracts.py.

Usage: python3 Tools/build/gen_api_contracts.py --source <wow-ui-source on branch forever>
                                                [--out Tools/data/forever_api_contracts.json]

The output is JSON with one entry per line and a header naming the source commit. Every entry carries
"at": the path (under Interface/AddOns) and line in the source that proves the name. It holds:
  - functions, namespaces: the C_ namespaces and their member functions, from the generated API
    documentation, plus members and namespaces that loaded Blizzard Lua assigns. Signatures and the
    Secret* and restriction metadata come from the documentation.
  - events: the documented LiteralName of each event, plus event names that loaded Blizzard Lua
    registers (RegisterEvent, RegisterUnitEvent, FrameUtil.RegisterFrameFor*, EventRegistry and
    EventUtil callbacks) or lists in a table whose name says "event".
  - cvars: CVar names that loaded Blizzard Lua passes as a literal to a Get/Set/Setup CVar call or
    stores in a variable or field whose name says "cvar". No canonical CVar list exists in the
    source, so a CVar that no loaded code names is unproven, not nonexistent.
  - templates: XML elements marked virtual or intrinsic, and every Font and FontFamily.
  - enums, constants: Enum and Constants tables and their members, from the documentation and from
    loaded Lua; removed lists names that loaded Lua sets to nil.
  - mixins: global tables named *Mixin that loaded Lua defines.
  - addons: every folder under Interface/AddOns and whether Forever loads it.

Only files that a TOC loads on the camelot game type count, as in gen_globals. Folders named
Blizzard_Deprecated* and Deprecated_* are not trusted: Forever does not load them.

The scanner in this file also reads addon code for check_api_contracts.py: scan_lua and scan_xml
return each checked occurrence with its line.
"""

import argparse
import collections
import difflib
import hashlib
import json
import mmap
import re
import subprocess
import sys
import tempfile
import os
import xml.parsers.expat
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gen_globals  # noqa: E402

OPENING_BRACKETS = gen_globals.OPENING_BRACKETS
CLOSING_BRACKETS = gen_globals.CLOSING_BRACKETS
DEFAULT_OUT = Path(__file__).resolve().parents[1] / "data" / "forever_api_contracts.json"
DEPRECATED_FOLDER = re.compile(r"^(blizzard_)?deprecated", re.I)
SCHEMA = 1

EVENT_SHAPE = re.compile(r"^[A-Z][A-Z0-9_]+$")
CVAR_SHAPE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")
ADDON_SHAPE = re.compile(r"^Blizzard_[A-Za-z0-9_]+$")
TEMPLATE_SPLIT = re.compile(r"[\s,]+")

# Argument that holds the event name, as (index for a:call, index for a.call or pcall(a.call, ...)).
EVENT_CALLS = {
    "RegisterEvent": (0, 1),
    "RegisterUnitEvent": (0, 1),
    "RegisterFrameEventAndCallback": (0, 0),
    "RegisterFrameEventAndCallbackWithHandle": (0, 0),
    "RegisterOnceFrameEventAndCallback": (0, 0),
}
EVENT_LIST_CALLS = {"RegisterFrameForEvents": 1, "RegisterFrameForUnitEvents": 1}
EVENT_WRAPPERS = {"Register": 1, "RegisterUnit": 1}
CVAR_FIRST_ARG = frozenset(
    "GetCVar GetCVarBool GetCVarDefault GetCVarInfo GetCVarBitfield SetCVar SetCVarBitfield GetCVarValue"
    " GetCVarValueBool GetCVarNumberOrDefault SetCVarCachable GetCVarMask SetCVarBitfieldMask"
    " GetCVarBitfieldDefault CreateCVarAccessorClosures ResetCVar".split()
)
CVAR_SECOND_ARG = frozenset("SetupCVarCheckbox SetupCVarDropdown SetupCVarSlider RegisterCVarSetting CreateCVarSlider".split())
TEMPLATE_CALLS = {
    "CreateFrame": 3,
    "CreateFramePool": 2,
    "CreateSecureFramePool": 2,
    "CreateTexture": 2,
    "CreateFontString": 2,
    "CreateTexturePool": 3,
    "CreateFontStringPool": 3,
    "SetElementInitializer": 1,
}
DOC_SKIP_META = frozenset(
    ("Name", "Type", "Documentation", "Arguments", "Returns", "Payload", "LiteralName", "Namespace", "SynchronousEvent")
)
ARG_FLAGS = ("NeverSecret", "ConditionalSecret", "SecretValue", "NeverSecretContents", "ConditionalSecretContents")

LIMITS = [
    "Names are existence checks against names that the generated documentation or loaded Blizzard Lua shows. A name no source shows is reported, not assumed absent.",
    "CVars have no canonical list: a CVar is known only when loaded Blizzard Lua names it as a literal. An engine CVar that no Lua names is reported as unproven.",
    "Event names are checked in RegisterEvent-style calls, K.Events wrappers and tables whose name says 'event' (names in capitals). Events passed as variables are listed as dynamic, not checked.",
    "Members are checked on C_ namespaces, Enum and Constants (also through a local alias declared once in the file). Fields of returned values and of frames are not checked: gen_widget_methods.py guards widget methods.",
    "A name built at run time (_G[prefix .. i], C_X[name], a template or event held in a variable) is dynamic: the guard lists it and checks only its literal part.",
    "A CVar that only the client executable proves records the executable's build, hash and the offset of its name, from --client-binary; regenerate with it, or that CVar is reported again.",
    "Global names (_G literals, hooksecurefunc strings) are checked against Tools/data/forever_globals.lua, which counts names that Blizzard code reads as well as defines.",
]


class Use:
    """One checked occurrence. name is None when the operand is dynamic; operand is then the source text."""

    __slots__ = ("category", "name", "line", "detail", "operand")

    def __init__(self, category, name, line, detail, operand=None):
        self.category, self.name, self.line, self.detail, self.operand = category, name, line, detail, operand


# Lua tokens


def tokenize(text):
    """Return (tokens, lines) for a Lua source: the tokens of gen_globals.lua_tokens, and the line
    each one starts on."""
    tokens, lines = [], []
    line = 1
    for match in gen_globals.LUA_TOKEN.finditer(text):
        kind = match.lastgroup
        raw = match.group()
        if kind not in ("space", "comment"):
            if kind in ("long", "string", "number"):
                tokens.append(("value", raw))
            elif kind == "name":
                tokens.append(("keyword" if raw in gen_globals.LUA_KEYWORDS else "name", raw))
            else:
                tokens.append(("op", raw))
            lines.append(line)
        line += raw.count("\n")
    return tokens, lines


class Expr(str):
    """The source text of a field value that is not a literal."""


class Table(dict):
    """A Lua table constructor: keyed fields as a dict, positional items in .array."""

    def __init__(self):
        super().__init__()
        self.array = []
        self.line = 0


def parse_table(tokens, lines, i):
    """Parse the table constructor that starts at tokens[i] and return (Table, next index)."""
    table = Table()
    table.line = lines[i]
    i += 1
    count = len(tokens)
    while i < count and tokens[i] != ("op", "}"):
        kind, value = tokens[i]
        if (kind, value) in (("op", ","), ("op", ";")):
            i += 1
        elif kind == "name" and i + 1 < count and tokens[i + 1] == ("op", "="):
            table[value], i = parse_value(tokens, lines, i + 2)
        else:
            item, i = parse_value(tokens, lines, i)
            table.array.append(item)
    return table, i + 1


def parse_value(tokens, lines, i):
    """Parse one field value at tokens[i]: a table, a literal, or the source text of an expression."""
    if tokens[i] == ("op", "{"):
        return parse_table(tokens, lines, i)
    depth = 0
    j = i
    while j < len(tokens):
        kind, value = tokens[j]
        if kind == "op" and value in OPENING_BRACKETS:
            depth += 1
        elif kind == "op" and value in CLOSING_BRACKETS:
            if depth == 0:
                break
            depth -= 1
        elif depth == 0 and kind == "op" and value in (",", ";"):
            break
        j += 1
    parts = tokens[i:j]
    if len(parts) == 1:
        kind, value = parts[0]
        if kind == "value" and value[:1] in "\"'":
            return value[1:-1], j
        if kind == "value":
            try:
                return int(value, 0), j
            except ValueError:
                return Expr(value), j
        if value in ("true", "false"):
            return value == "true", j
    return Expr("".join(value for _, value in parts)), j


def match_brackets(tokens):
    """Return a dict that maps the index of each opening bracket to the index of its closing one."""
    partner, stack = {}, []
    for i, (kind, value) in enumerate(tokens):
        if kind != "op":
            continue
        if value in OPENING_BRACKETS:
            stack.append(i)
        elif value in CLOSING_BRACKETS and stack:
            partner[stack.pop()] = i
    return partner


def string_value(token):
    """Return the text of a plain string literal token, or None for anything else."""
    kind, value = token
    if kind == "value" and value[:1] in ("'", '"') and "\\" not in value:
        return value[1:-1]
    return None


def source_text(tokens, start, end):
    text = " ".join(value for _, value in tokens[start:end])
    return text if len(text) <= 60 else text[:57] + "..."


def split_args(tokens, partner, open_index):
    """Return the (start, end) token ranges of the arguments of the call that opens at open_index."""
    close = partner.get(open_index)
    if close is None:
        return []
    ranges, start, i = [], open_index + 1, open_index + 1
    while i < close:
        kind, value = tokens[i]
        if kind == "op" and value in OPENING_BRACKETS:
            i = partner.get(i, i)
        elif (kind, value) == ("op", ","):
            ranges.append((start, i))
            start = i + 1
        i += 1
    if start < close:
        ranges.append((start, close))
    return ranges


def read_chain(tokens, partner, i, consts=None):
    """Read a name chain such as a.b["c"].d from tokens[i]. Return (parts, end, operand): the
    literal parts, the index after the chain, and the source text of the first computed key, which
    ends the chain, or None. A key that is a local holding one string literal counts as that string."""
    parts, j, count = [tokens[i][1]], i + 1, len(tokens)
    while j + 1 < count:
        if tokens[j] == ("op", ".") and tokens[j + 1][0] == "name":
            parts.append(tokens[j + 1][1])
            j += 2
        elif tokens[j] == ("op", "["):
            key = string_value(tokens[j + 1])
            if key is None and consts and tokens[j + 1][0] == "name" and tokens[j + 1][1] in consts:
                key = consts[tokens[j + 1][1]]
            if key is not None and gen_globals.IDENTIFIER.match(key) and tokens[j + 2] == ("op", "]"):
                parts.append(key)
                j += 3
            else:
                return parts, partner.get(j, j) + 1, source_text(tokens, j + 1, partner.get(j, j))
        else:
            break
    return parts, j, None


class Call:
    def __init__(self, chain, method, args, line):
        self.chain, self.method, self.args, self.line = chain, method, args, line


def iter_calls(tokens, lines, partner):
    """Yield a Call for each f(...) whose callee is a name chain such as a.b:c, skipping function
    declarations. pcall(a.b, x) is yielded as the call a.b(x), which is not a method call."""
    for i, token in enumerate(tokens):
        if token != ("op", "(") or i == 0 or tokens[i - 1][0] != "name":
            continue
        start = i - 1
        method = False
        chain = [tokens[start][1]]
        while start >= 2 and tokens[start - 1] in (("op", "."), ("op", ":")) and tokens[start - 2][0] == "name":
            if len(chain) == 1:
                method = tokens[start - 1] == ("op", ":")
            chain.insert(0, tokens[start - 2][1])
            start -= 2
        if start > 0 and tokens[start - 1] == ("keyword", "function"):
            continue
        args = split_args(tokens, partner, i)
        if chain == ["pcall"] and args:
            first = tokens[args[0][0] : args[0][1]]
            names = [t[1] for t in first if t[0] == "name"]
            if names and len(first) == len(names) + len([t for t in first if t[0] == "op"]) and all(
                t[0] in ("name", "op") and (t[0] == "name" or t[1] in (".", ":")) for t in first
            ):
                yield Call(names, False, args[1:], lines[i])
                continue
        yield Call(chain, method, args, lines[i])


def is_root(name):
    return name.startswith("C_") or name in ("Enum", "Constants")


def literal(tokens, start, end, consts):
    """Return (text, constant name) when tokens[start:end] is a string literal, or a name or a.b chain
    that the file sets once to a string literal; the constant name is None for a literal."""
    if end - start == 1:
        text = string_value(tokens[start])
        if text is not None:
            return text, None
        name = tokens[start][1]
        if tokens[start][0] == "name" and name in consts:
            return consts[name], name
        return None, None
    if (end - start) % 2 == 1 and all(
        tokens[k][0] == "name" if (k - start) % 2 == 0 else tokens[k] == ("op", ".") for k in range(start, end)
    ):
        key = ".".join(tokens[k][1] for k in range(start, end, 2))
        if key in consts:
            return consts[key], key
    return None, None


def field_constants(text):
    """Return {"a.b": text} for the fields the file sets once to a string literal."""
    tokens, _ = tokenize(text)
    partner = match_brackets(tokens)
    _, sites = gen_globals.declared_locals(tokens)
    return {key: value for key, value in string_constants(tokens, partner, sites).items() if "." in key}


def string_constants(tokens, partner, sites):
    """Return {name: text} for each local the file declares once as a string literal, and
    {"a.b": text} for each field it sets once to one, by assignment or in a table constructor."""
    declarations = collections.Counter(tokens[s][1] for s in sites)
    counts, found = collections.Counter(), {}
    count = len(tokens)

    def note(key, text):
        counts[key] += 1
        found[key] = text

    def plain(j):
        text = string_value(tokens[j]) if j < count else None
        follows = tokens[j + 1] if j + 1 < count else ("op", ";")
        return text if text is not None and follows not in (("op", ".."), ("op", ":"), ("op", ".")) else None

    for i, token in enumerate(tokens):
        if token == ("keyword", "local"):
            names, j = [], i + 1
            while j < count and tokens[j][0] == "name":
                names.append(tokens[j][1])
                j += 1
                if j < count and tokens[j] == ("op", ","):
                    j += 1
                else:
                    break
            if names and j < count and tokens[j] == ("op", "="):
                j += 1
                for name in names:
                    text = plain(j)
                    if text is None:
                        break
                    if declarations[name] == 1:
                        note(name, text)
                    j += 1
                    if j < count and tokens[j] == ("op", ","):
                        j += 1
            continue
        if token[0] != "name" or (i and tokens[i - 1] in gen_globals.FIELD_PREVIOUS):
            continue
        parts, end, computed = read_chain(tokens, partner, i)
        if computed is None and end < count and tokens[end] == ("op", ","):
            j = end
            while j + 1 < count and tokens[j] == ("op", ",") and tokens[j + 1][0] == "name":
                _, j, _ = read_chain(tokens, partner, j + 1)
            if j < count and tokens[j] == ("op", "="):
                if len(parts) > 1 or (i not in sites and parts[0] in found):
                    note(".".join(parts), None)
            continue
        if computed is not None or end >= count or tokens[end] != ("op", "=") or end + 1 >= count:
            continue
        if len(parts) > 1 and plain(end + 1) is not None:
            note(".".join(parts), plain(end + 1))
        elif len(parts) > 1 and tokens[end + 1][0] == "name" and tokens[end + 1][1] in found and plain(end + 1) is None and (
            end + 2 >= count or tokens[end + 2] not in (("op", "."), ("op", ":"), ("op", ".."), ("op", "["))
        ):
            note(".".join(parts), found[tokens[end + 1][1]])
        elif tokens[end + 1] == ("op", "{"):
            table_name = ".".join(parts)
            for k in range(end + 2, partner.get(end + 1, end + 1)):
                if tokens[k - 1] in (("op", "{"), ("op", ","), ("op", ";")) and tokens[k][0] == "name" and tokens[k + 1] == ("op", "=") and plain(k + 2) is not None:
                    note(table_name + "." + tokens[k][1], plain(k + 2))
        elif len(parts) > 1:
            note(".".join(parts), None)
        if len(parts) == 1 and i not in sites and parts[0] in found:
            note(parts[0], None)
    return {key: text if counts[key] == 1 else None for key, text in found.items()}


def function_heads(tokens):
    """Yield (name, colon, params, body start, body end) for each named function in the token list."""
    for i, token in enumerate(tokens):
        if token != ("keyword", "function"):
            continue
        j, colon, name = i + 1, False, None
        while j + 1 < len(tokens) and tokens[j][0] == "name":
            name = tokens[j][1]
            if tokens[j + 1] in (("op", "."), ("op", ":")):
                colon = tokens[j + 1] == ("op", ":")
                j += 2
            else:
                j += 1
                break
        if name is None and i >= 2 and tokens[i - 1] == ("op", "=") and tokens[i - 2][0] == "name":
            name, j = tokens[i - 2][1], i + 1
        if name is None or j >= len(tokens) or tokens[j] != ("op", "("):
            continue
        params, k = [], j + 1
        while k < len(tokens) and tokens[k] != ("op", ")"):
            if tokens[k][0] == "name":
                params.append(tokens[k][1])
            k += 1
        depth, end = 0, k
        while end < len(tokens):
            if tokens[end][0] == "keyword" and tokens[end][1] in gen_globals.BLOCK_OPENERS | {"function"}:
                depth += 1
            elif tokens[end][0] == "keyword" and tokens[end][1] in gen_globals.BLOCK_CLOSERS:
                depth -= 1
                if depth == 0:
                    break
            end += 1
        yield name, colon, params, k + 1, end


def member_getters(text):
    """Return {name: spec} for each function the file declares that looks a member up on a C_ table
    by one of its parameters: C_X[param] gives ("member", C_X parts, index of param), and
    api[member] with both names parameters gives ("pair", index of api, index of member). A call
    with a string in that position then names a member, as Api("GetCVar") names C_CVar.GetCVar."""
    tokens, _ = tokenize(text)
    partner = match_brackets(tokens)
    declared, sites = gen_globals.declared_locals(tokens)
    aliases = alias_table(tokens, partner, declared, sites)
    found = {}
    for name, colon, params, start, end in function_heads(tokens):
        for k in range(start, end - 3):
            if tokens[k][0] != "name" or tokens[k + 1] != ("op", "[") or tokens[k + 3] != ("op", "]"):
                continue
            key = tokens[k + 2][1]
            if tokens[k + 2][0] != "name" or key not in params:
                continue
            root, key_index = tokens[k][1], params.index(key)
            if root.startswith("C_") and root not in declared:
                found.setdefault(name, ("member", [root], key_index))
            elif root in aliases and aliases[root][1][0].startswith("C_"):
                found.setdefault(name, ("member", list(aliases[root][1]), key_index))
            elif root in params:
                found.setdefault(name, ("pair", params.index(root), key_index))
    return found


def event_parameters(text):
    """Return {name: (index for a:call, index for a.call)} for each function the file declares with
    a parameter named event, such as ns.On(event, fn). A call to it with a string in that position
    registers an event, one level removed from RegisterEvent."""
    tokens, _ = tokenize(text)
    found = {}
    for name, colon, params, _, _ in function_heads(tokens):
        if "event" in params:
            position = params.index("event")
            found[name] = (position, position + 1) if colon else (position - 1, position)
    return found


def uses_in_call(tokens, call, add, wrappers=None, consts=None, getters=None, aliases=None, partner=None):
    """Add the event, CVar, template and global-name uses that one call makes."""
    name = call.chain[-1]
    consts = consts or {}

    def operand(index, category, detail, split=False, shape=None):
        if index is None or index < 0 or index >= len(call.args):
            return
        start, end = call.args[index]
        text, constant = literal(tokens, start, end, consts)
        if text is not None:
            if constant:
                detail += " via " + constant
            for item in (TEMPLATE_SPLIT.split(text.strip()) if split else [text]):
                if item and (shape is None or shape.match(item)):
                    add(Use(category, item, call.line, detail))
            return
        if shape is not None:
            return
        if end - start == 1:
            if tokens[start][1] in ("nil", "false"):
                return
        if tokens[start] == ("op", "{"):
            for k in range(start, end):
                text = string_value(tokens[k])
                if text is not None:
                    add(Use(category, text, call.line, detail))
            return
        add(Use(category, None, call.line, detail, source_text(tokens, start, end)))

    if name in EVENT_CALLS:
        method_index, dot_index = EVENT_CALLS[name]
        operand(method_index if call.method else dot_index, "event", name)
    elif name in EVENT_LIST_CALLS and not call.method:
        operand(EVENT_LIST_CALLS[name], "event", name)
    elif name in EVENT_WRAPPERS and len(call.chain) > 1 and call.chain[-2] == "Events":
        operand(EVENT_WRAPPERS[name], "event", ".".join(call.chain[-2:]))
    elif name in CVAR_FIRST_ARG:
        operand(0, "cvar", name)
    elif len(call.chain) > 1 and call.chain[-2] == "CVars" and name in ("Exists", "Get", "Default", "Set", "SetBitfield"):
        operand(0, "cvar", ".".join(call.chain[-2:]))
    elif name in CVAR_SECOND_ARG:
        operand(1, "cvar", name)
    elif name in TEMPLATE_CALLS:
        operand(TEMPLATE_CALLS[name], "template", name, split=True)
    elif getters and name in getters:
        kind, first, second = getters[name]
        if kind == "member" and second < len(call.args):
            start, end = call.args[second]
            text, constant = literal(tokens, start, end, consts)
            member = first[:] + [text] if text else None
            add(Use("api", ".".join(member) if member else ".".join(first), call.line, "via " + name + (" " + constant if constant else ""), None if member else source_text(tokens, start, end)))
        elif kind == "pair" and max(first, second) < len(call.args):
            start, end = call.args[first]
            root = None
            if end - start >= 1 and tokens[start][0] == "name":
                parts, stop, computed = read_chain(tokens, partner, start)
                if stop == end and computed is None:
                    if parts[0] in (aliases or {}) and aliases[parts[0]][1][0].startswith("C_"):
                        root = list(aliases[parts[0]][1]) + parts[1:]
                    elif parts[0].startswith("C_"):
                        root = parts
            if root:
                start, end = call.args[second]
                text, constant = literal(tokens, start, end, consts)
                add(Use("api", ".".join(root + [text]) if text else ".".join(root), call.line, "via " + name, None if text else source_text(tokens, start, end)))
    elif wrappers and name in wrappers and name not in ("pcall", "xpcall"):
        method_index, dot_index = wrappers[name]
        operand(method_index if call.method else dot_index, "event", name + " (takes event)", shape=EVENT_SHAPE)


def alias_table(tokens, partner, declared, sites):
    """Return {alias: (token index of its declaration, parts)} for each local that the file declares
    once as C_X or Enum.X (also in 'local a, b = C_X, Enum and Enum.X')."""
    declarations = collections.Counter(tokens[s][1] for s in sites)
    aliases = {}
    count = len(tokens)

    def simple(j):
        if j >= count or tokens[j][0] != "name":
            return None, j
        parts, end, computed = read_chain(tokens, partner, j)
        result = parts if is_root(parts[0]) and computed is None else None
        if end < count and tokens[end][0] == "keyword" and tokens[end][1] in ("and", "or"):
            right, end2 = simple(end + 1)
            if tokens[end][1] == "and" and right is not None:
                result = right
            return result, end2
        return result, end

    for i, token in enumerate(tokens):
        if token != ("keyword", "local"):
            continue
        names, j = [], i + 1
        while j < count and tokens[j][0] == "name":
            names.append((tokens[j][1], j))
            j += 1
            if j < count and tokens[j] == ("op", ","):
                j += 1
            else:
                break
        if not names or j >= count or tokens[j] != ("op", "="):
            continue
        j += 1
        for name, site in names:
            parts, j = simple(j)
            if parts is not None and declarations[name] == 1 and len(parts) <= (1 if parts[0].startswith("C_") else 2):
                if not (len(parts) == 1 and parts[0] in ("Enum", "Constants")):
                    aliases[name] = (site, parts)
            if j < count and tokens[j] == ("op", ","):
                j += 1
    return aliases


def scan_lua(text, wrappers=None, getters=None, shared_consts=None):
    """Return (uses, defines) for one Lua source. uses holds a Use for each checked occurrence;
    defines holds the global names the file itself creates, which are not Blizzard's to prove.
    wrappers maps the names of addon functions that take an event to their event_parameters, and
    getters the names of those that look a C_ member up by name to their member_getters.
    shared_consts maps a.b names that other files set to one string, from field_constants."""
    tokens, lines = tokenize(text)
    partner = match_brackets(tokens)
    declared, sites = gen_globals.declared_locals(tokens)
    count = len(tokens)
    uses = []
    add = uses.append
    defines = set(gen_globals.lua_globals(text)[0])
    aliases = alias_table(tokens, partner, declared, sites)
    consts = dict(shared_consts or {})
    consts.update(string_constants(tokens, partner, sites))

    for call in iter_calls(tokens, lines, partner):
        uses_in_call(tokens, call, add, wrappers, consts, getters, aliases, partner)
        if call.chain == ["CreateFrame"] and len(call.args) > 1:
            start, end = call.args[1]
            name = string_value(tokens[start]) if end - start == 1 else None
            if name:
                defines.add(name)
        elif call.chain == ["hooksecurefunc"] and len(call.args) > 1:
            (a0, e0), (a1, e1) = call.args[0], call.args[1]
            first, second = string_value(tokens[a0]) if e0 - a0 == 1 else None, string_value(tokens[a1]) if e1 - a1 == 1 else None
            if first is not None:
                add(Use("global", first, call.line, "hooksecurefunc"))
            elif second is not None and tokens[a0][0] == "name" and e0 - a0 == 1:
                parts = None
                if tokens[a0][1].startswith("C_") and tokens[a0][1] not in declared:
                    parts = [tokens[a0][1]]
                elif tokens[a0][1] in aliases:
                    parts = list(aliases[tokens[a0][1]][1])
                if parts and parts[0].startswith("C_"):
                    add(Use("api", ".".join(parts + [second]), call.line, "hooksecurefunc"))

    registers_dynamically = any(u.category == "event" and u.name is None and "takes event" not in u.detail for u in uses)
    for i, (kind, value) in enumerate(tokens):
        previous = tokens[i - 1] if i else ("op", ";")
        following = tokens[i + 1] if i + 1 < count else ("op", ";")
        line = lines[i]
        if kind == "value":
            text_value = string_value((kind, value))
            if text_value is not None and ADDON_SHAPE.match(text_value):
                add(Use("addon", text_value, line, "string"))
            continue
        if kind != "name":
            continue
        lowered = value.lower()
        if previous in gen_globals.FIELD_PREVIOUS and not lowered.endswith(("cvar", "cvars", "event", "events")):
            continue
        if following == ("op", "=") and i + 2 < count and ("event" in lowered or "cvar" in lowered):
            collect_named(tokens, lines, partner, i, lowered, add, registers_dynamically)
        if previous in gen_globals.FIELD_PREVIOUS:
            continue
        if value == "_G" and "_G" not in declared:
            global_use(tokens, lines, partner, i, add, defines, consts)
            continue
        if value in aliases and i > aliases[value][0]:
            parts, end, computed = read_chain(tokens, partner, i, consts)
            full = list(aliases[value][1]) + parts[1:]
            if len(parts) > 1 or computed is not None:
                record_chain(tokens, full, computed, line, "alias " + value, end, add)
            continue
        if is_root(value) and i < declared.get(value, count):
            parts, end, computed = read_chain(tokens, partner, i, consts)
            if end < count and tokens[end] == ("op", "="):
                continue
            record_chain(tokens, parts, computed, line, "", end, add)
            continue
        if value != "Mixin" and value.endswith("Mixin") and i < declared.get(value, count) and following != ("op", "="):
            add(Use("mixin", value, line, "global"))
    resolved = {(u.category, u.name) for u in uses if " via " in u.detail}
    uses[:] = [u for u in uses if not (u.detail.startswith("table ") and u.detail[6:] in consts and (u.category, u.name) in resolved)]
    return uses, defines


def record_chain(tokens, parts, computed, line, detail, end, add):
    root = parts[0]
    name = ".".join(parts)
    if root.startswith("C_"):
        if len(parts) == 1 and computed is None:
            add(Use("namespace", name, line, detail))
        else:
            add(Use("api", name, line, detail, computed))
    elif len(parts) > 1 or computed is not None:
        add(Use("enum", name, line, detail, computed))


def collect_named(tokens, lines, partner, i, lowered, add, keys_ok):
    """Add the event or CVar names that a variable, field or table named *event* or *cvar* holds.
    The keys of an event table count only when keys_ok: the file registers events it holds in a
    variable. Without that, such a table is a lookup of names that need not be game events."""
    category = "event" if "event" in lowered else "cvar"
    shape = EVENT_SHAPE if category == "event" else CVAR_SHAPE
    detail = "table " + tokens[i][1]
    start = i + 2
    if tokens[start] != ("op", "{"):
        text = string_value(tokens[start])
        follows = tokens[start + 1] if start + 1 < len(tokens) else ("op", ";")
        if text is not None and shape.match(text) and follows != ("op", ".."):
            add(Use(category, text, lines[start], detail))
        return
    end = partner.get(start, start)
    for k in range(start + 1, end):
        text = string_value(tokens[k])
        before, after = tokens[k - 1], tokens[k + 1]
        if text is not None and shape.match(text):
            element = before in (("op", "{"), ("op", ","), ("op", ";")) and after in (("op", ","), ("op", ";"), ("op", "}"))
            bracket_key = before == ("op", "[") and after == ("op", "]")
            field = tokens[k - 2] in (("name", "name"), ("name", "cvar")) and before == ("op", "=")
            if element or bracket_key or (category == "cvar" and field):
                add(Use(category, text, lines[k], detail))
        elif keys_ok and category == "event" and tokens[k][0] == "name" and after == ("op", "=") and shape.match(tokens[k][1]):
            if before in (("op", "{"), ("op", ","), ("op", ";")):
                add(Use(category, tokens[k][1], lines[k], detail))


def global_use(tokens, lines, partner, i, add, defines, consts):
    """Add the use of _G.Name, _G["Name"] or _G[expression] that starts at tokens[i]."""
    count = len(tokens)
    if i + 2 < count and tokens[i + 1] == ("op", ".") and tokens[i + 2][0] == "name":
        name, after = tokens[i + 2][1], i + 3
    elif i + 1 < count and tokens[i + 1] == ("op", "["):
        close = partner.get(i + 1, i + 1)
        name, constant = literal(tokens, i + 2, close, consts)
        if name is not None and not gen_globals.IDENTIFIER.match(name):
            name = None
        after = close + 1
        if name is None:
            prefix = string_value(tokens[i + 2]) if close > i + 3 and tokens[i + 3] == ("op", "..") else None
            if after < count and tokens[after] == ("op", "="):
                return
            add(Use("global", None, lines[i], "prefix " + prefix if prefix else "", source_text(tokens, i + 2, close)))
            return
    else:
        return
    if after < count and tokens[after] == ("op", "="):
        defines.add(name)
        return
    add(Use("global", name, lines[i], "_G"))


def scan_xml(text):
    """Return (uses, defines) for one XML file: the templates and mixins it names, and the
    templates and objects it creates."""
    uses, defines = [], set()
    parser = xml.parsers.expat.ParserCreate()

    def start(tag, attrs):
        line = parser.CurrentLineNumber
        for key, value in attrs.items():
            if key == "inherits":
                for item in TEMPLATE_SPLIT.split(value.strip()):
                    if item:
                        uses.append(Use("template", item, line, "inherits"))
            elif key in ("mixin", "secureMixin"):
                for item in TEMPLATE_SPLIT.split(value.strip()):
                    if item:
                        uses.append(Use("mixin", item, line, key))
        name = attrs.get("name")
        if name:
            defines.add(name)

    parser.StartElementHandler = start
    try:
        parser.Parse(text, True)
    except xml.parsers.expat.ExpatError as err:
        raise ValueError(str(err)) from err
    return uses, defines


# Blizzard source


def scan_defs(text):
    """Return (defs, mixins): defs lists (parts, members, removed, line) for each statement that
    assigns C_X, C_X.Name, Enum.X, Enum.X.Name or Constants.X.Name, or declares function C_X.Name.
    members is the list of names a table constructor or EnumUtil.MakeEnum call gives, or None when
    the value is not known. mixins lists (name, line) for each global *Mixin that the file sets."""
    tokens, lines = tokenize(text)
    partner = match_brackets(tokens)
    declared, _ = gen_globals.declared_locals(tokens)
    count = len(tokens)
    defs, mixins = [], []
    for i, (kind, value) in enumerate(tokens):
        previous = tokens[i - 1] if i else ("op", ";")
        if kind != "name" or previous in gen_globals.FIELD_PREVIOUS or i >= declared.get(value, count):
            continue
        if value != "Mixin" and value.endswith("Mixin") and i + 1 < count:
            nxt = tokens[i + 1]
            if (nxt == ("op", "=") and previous != ("keyword", "local")) or (
                previous == ("keyword", "function") and nxt in (("op", ":"), ("op", "."))
            ):
                mixins.append((value, lines[i]))
        if not is_root(value):
            continue
        parts, end, computed = read_chain(tokens, partner, i)
        is_function = previous == ("keyword", "function") and end < count and tokens[end] == ("op", "(")
        if computed is not None or not (is_function or (end < count and tokens[end] == ("op", "="))):
            continue
        if is_function:
            defs.append((parts, None, False, lines[i]))
            continue
        start = end + 1
        if start >= count:
            continue
        if tokens[start] == ("keyword", "nil"):
            defs.append((parts, None, True, lines[i]))
        elif tokens[start] == ("op", "{"):
            table, _ = parse_table(tokens, lines, start)
            names = sorted(set(table) | {a for a in table.array if isinstance(a, str) and not isinstance(a, Expr)})
            defs.append((parts, names, False, lines[i]))
        elif tokens[start][0] == "name" and start + 1 < count:
            parts_rhs, rhs_end, _ = read_chain(tokens, partner, start)
            names = None
            if parts_rhs[-1] == "MakeEnum" and rhs_end < count and tokens[rhs_end] == ("op", "("):
                names = sorted(
                    s for s in (string_value(tokens[a]) for a, b in split_args(tokens, partner, rhs_end) if b - a == 1) if s
                )
            defs.append((parts, names, False, lines[i]))
        else:
            defs.append((parts, None, False, lines[i]))
    return defs, mixins


def xml_templates(text):
    """Return (name, tag, line) for each element in an XML file that other XML or CreateFrame can
    inherit: elements marked virtual or intrinsic, and every Font and FontFamily."""
    found = []
    parser = xml.parsers.expat.ParserCreate()

    def start(tag, attrs):
        name = attrs.get("name")
        if not name or "$" in name:
            return
        marked = any(attrs.get(flag, "").lower() == "true" for flag in ("virtual", "intrinsic"))
        if marked or tag in ("Font", "FontFamily"):
            found.append((name, tag, parser.CurrentLineNumber))

    parser.StartElementHandler = start
    parser.Parse(text, True)
    return found


class Loaded(gen_globals.Walker):
    """A gen_globals Walker that also remembers each file it loads, and whether any load puts the
    file in the global environment that addons see. Files in the secure environment still prove
    what Blizzard registers, uses and templates; they define nothing an addon can reach."""

    def __init__(self):
        super().__init__()
        self.files = {}

    def load(self, folder, path, visible):
        self.files[path] = self.files.get(path, False) or visible
        super().load(folder, path, visible)


def signature(table):
    """Return "name?:Type<Inner>, ..." for the Arguments, Returns or Payload table of a documented entry."""
    items = []
    for entry in getattr(table, "array", ()):
        text = entry.get("Name", "?") + ("?" if entry.get("Nilable") is True else "") + ":" + str(entry.get("Type", "?"))
        if entry.get("InnerType"):
            text += "<" + str(entry["InnerType"]) + ">"
        text += "".join("!" + flag for flag in ARG_FLAGS if entry.get(flag) is True)
        items.append(text)
    return ", ".join(items)


def doc_meta(entry):
    """Return the documented metadata of a function or event: every field but the signature and prose."""
    meta = {}
    for key, value in entry.items():
        if key in DOC_SKIP_META:
            continue
        meta[key] = [str(v) for v in value.array] if isinstance(value, Table) else value
    return meta


def collect(source):
    """Return the contracts dict for a wow-ui-source checkout."""
    source = Path(source)
    addons_dir = source / gen_globals.ADDONS
    walker = Loaded()
    addons = {}
    for folder in gen_globals.addon_folders(source):
        if DEPRECATED_FOLDER.match(folder.name):
            addons[folder.name] = "deprecated"
            continue
        toc = gen_globals.find_toc(folder)
        env = toc and gen_globals.addon_environment(gen_globals.read_toc(toc)[0])
        addons[folder.name] = "loaded" if env else "not loaded"
        walker.walk_addon(folder)

    def at(path, line):
        return f"{path.relative_to(addons_dir).as_posix()}:{line}"

    docs_dir = source / gen_globals.DOCS
    data = {name: {} for name in (
        "namespaces", "functions", "secure_only", "events", "cvars", "templates", "enums", "constants", "mixins", "removed")}
    pending = []
    for path in sorted(walker.files):
        visible = walker.files[path]
        text = path.read_text(encoding="utf-8", errors="replace")
        suffix = path.suffix.lower()
        if docs_dir in path.parents:
            collect_doc(path, text, at, data)
        elif suffix == ".lua":
            uses, _ = scan_lua(text)
            for use in uses:
                if use.name is None:
                    continue
                if use.category == "event" and EVENT_SHAPE.match(use.name):
                    pending.append(("events", use.name, {"at": at(path, use.line), "via": use.detail}))
                elif use.category == "cvar":
                    pending.append(("cvars", use.name.lower(), {"name": use.name, "at": at(path, use.line), "via": use.detail}))
                elif visible and use.category in ("api", "enum") and use.operand is None:
                    pending.append(("uses", use.name, at(path, use.line)))
            defs, mixins = scan_defs(text) if visible else ([], [])
            for name, line in mixins:
                data["mixins"].setdefault(name, {"at": at(path, line)})
            for parts, names, removed, line in defs:
                pending.append(("defs", (parts, names, removed), at(path, line)))
        elif suffix == ".xml":
            for name, tag, line in xml_templates(text):
                data["templates"].setdefault(name, {"at": at(path, line), "tag": tag})
    for section, key, entry in pending:
        if section == "defs":
            apply_def(data, key, entry)
        elif section != "uses":
            data[section].setdefault(key, entry)
    for section, key, entry in pending:
        if section == "uses":
            apply_use(data, key, entry)
    for name in list(data["removed"]):
        data["namespaces"].pop(name, None)
        data["enums"].pop(name.split(".", 1)[-1] if name.startswith("Enum.") else name, None)
        data["functions"].pop(name, None)
    data["addons"] = dict(sorted(addons.items()))
    return data


def collect_doc(path, text, at, data):
    tokens, lines = tokenize(text)
    start = next((i for i, t in enumerate(tokens) if t == ("op", "{")), None)
    if start is None:
        return
    table, _ = parse_table(tokens, lines, start)
    kind = table.get("Type")
    system_secure = table.get("Environment") == "SecureOnly"
    namespace = table.get("Namespace")
    if kind == "System":
        if namespace:
            entry = {"at": at(path, table.line), "system": table.get("Name")}
            if system_secure:
                entry["secure"] = True
            data["namespaces"].setdefault(namespace, entry)
        for fn in getattr(table.get("Functions"), "array", ()):
            if not namespace:
                continue
            name = namespace + "." + fn["Name"]
            if system_secure or fn.get("Environment") == "SecureOnly":
                data["secure_only"].setdefault(name, at(path, fn.line))
                continue
            entry = {"at": at(path, fn.line)}
            for key, source_table in (("args", fn.get("Arguments")), ("returns", fn.get("Returns"))):
                if signature(source_table):
                    entry[key] = signature(source_table)
            meta = doc_meta(fn)
            if meta:
                entry["meta"] = meta
            data["functions"].setdefault(name, entry)
        for event in getattr(table.get("Events"), "array", ()):
            literal = event.get("LiteralName")
            if literal:
                entry = {"at": at(path, event.line), "system": table.get("Name")}
                if signature(event.get("Payload")):
                    entry["payload"] = signature(event.get("Payload"))
                meta = doc_meta(event)
                if meta:
                    entry["meta"] = meta
                data["events"].setdefault(literal, entry)
    for item in getattr(table.get("Tables"), "array", ()):
        if item.get("Type") == "Enumeration":
            fields = [f["Name"] for f in getattr(item.get("Fields"), "array", ())]
            data["enums"].setdefault(item["Name"], {"at": at(path, item.line), "fields": fields})
        elif item.get("Type") == "Constants":
            values = [v["Name"] for v in getattr(item.get("Values"), "array", ())]
            data["constants"].setdefault(item["Name"], {"at": at(path, item.line), "values": values})


def apply_use(data, name, where):
    """Fold a C_X.Name or Enum.X.Name that loaded Blizzard Lua reads into data when no documentation
    covers the namespace or table. The entry says via use: the name is only known to be used."""
    parts = name.split(".")
    if name in data["secure_only"] or data["namespaces"].get(parts[0], {}).get("secure"):
        return
    if parts[0].startswith("C_"):
        entry = data["namespaces"].get(parts[0])
        if entry is not None and entry["system"] is not None:
            return
        entry = data["namespaces"].setdefault(parts[0], {"at": where, "system": None, "via": "use"})
        if len(parts) > 1 and entry.get("via") == "use":
            data["functions"].setdefault(name, {"at": where, "via": "use"})
        return
    if len(parts) < 2:
        return
    section, field = ("enums", "fields") if parts[0] == "Enum" else ("constants", "values")
    entry = data[section].setdefault(parts[1], {"at": where, field: [], "via": "use"})
    if entry.get("via") == "use" and len(parts) > 2 and parts[2] not in entry[field]:
        entry[field] = sorted(entry[field] + [parts[2]])


def apply_def(data, key, where):
    """Fold one assignment that loaded Blizzard Lua makes to C_X, Enum.X or Constants.X into data."""
    parts, names, removed = key
    root = parts[0]
    name = ".".join(parts)
    if name in data["secure_only"] or data["namespaces"].get(root, {}).get("secure"):
        return
    if removed:
        data["removed"].setdefault(name, where)
        return
    if root.startswith("C_"):
        if len(parts) == 1:
            entry = data["namespaces"].setdefault(root, {"at": where, "system": None})
            if names is None and entry["system"] is None:
                entry["open"] = True
            for member in names or ():
                data["functions"].setdefault(root + "." + member, {"at": where, "via": "lua"})
        else:
            data["namespaces"].setdefault(root, {"at": where, "system": None, "open": True})
            data["functions"].setdefault(name, {"at": where, "via": "lua"})
        return
    section, field = ("enums", "fields") if root == "Enum" else ("constants", "values")
    if len(parts) == 2:
        entry = data[section].setdefault(parts[1], {"at": where, field: []})
        if names is None and not entry[field]:
            entry["open"] = True
        entry[field] = sorted(set(entry[field]) | set(names or ()))
    elif len(parts) == 3:
        entry = data[section].setdefault(parts[1], {"at": where, field: []})
        entry[field] = sorted(set(entry[field]) | {parts[2]})


# Output


def describe(source):
    """Return (hash, subject) for the source checkout's HEAD commit."""
    result = subprocess.run(["git", "-C", str(source), "log", "-1", "--format=%h%n%s"], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"{source} is not a git checkout: {result.stderr.strip()}")
    return result.stdout.split("\n")[0], result.stdout.split("\n")[1]


AT_SECTIONS = ("secure_only", "removed")


def index_files(data):
    """Return (files, data): data with each "path:line" provenance replaced by "<index in files>:line"."""
    paths = set()
    for name, entries in data.items():
        for entry in entries.values():
            at = entry if name in AT_SECTIONS else entry.get("at") if isinstance(entry, dict) else None
            if at:
                paths.add(at.rsplit(":", 1)[0])
    files = sorted(paths)
    number = {path: i for i, path in enumerate(files)}

    def short(at):
        path, line = at.rsplit(":", 1)
        return f"{number[path]}:{line}"

    out = {}
    for name, entries in data.items():
        if name == "addons":
            out[name] = entries
        elif name in AT_SECTIONS:
            out[name] = {key: short(at) for key, at in entries.items()}
        else:
            out[name] = {key: dict(entry, at=short(entry["at"])) if "at" in entry else entry for key, entry in entries.items()}
    return files, out


def render(data, commit, subject, client=None):
    """Return the JSON text: a header, then one entry per line in each section."""
    dumps = lambda value: json.dumps(value, sort_keys=True, separators=(", ", ": "), ensure_ascii=True)  # noqa: E731
    files, data = index_files(data)
    head = {
        "schema": SCHEMA,
        "source": {"repo": "Gethe/wow-ui-source", "branch": "forever", "commit": commit, "subject": subject},
        "limits": LIMITS,
        "counts": {name: len(entries) for name, entries in sorted(data.items())},
        "files": files,
    }
    if client:
        head["client"] = client
    lines = ["{"]
    sections = [f"{dumps(key)}: {dumps(value)}" for key, value in head.items()]
    for name in sorted(data):
        entries = [f"{dumps(key)}: {dumps(data[name][key])}" for key in sorted(data[name])]
        sections.append(f"{dumps(name)}: {{\n" + ",\n".join(entries) + "\n}")
    lines.append(",\n".join(sections))
    lines.append("}")
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


def prove_cvars_in_client(data, binary, build, source, addon_root):
    """Add each CVar the addon code names that no loaded source does, when the client executable holds
    its exact name as a NUL-terminated string. Record the executable's build, hash and the offset
    of each name, never the string table. Return the client header."""
    version = (Path(source) / "version.txt").read_text(encoding="utf-8").strip()
    if build != version:
        raise ValueError(f"--client-build {build} does not match the source version {version}")
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hooks"))
    import check_api_contracts  # noqa: PLC0415

    scans, _ = check_api_contracts.scan_files(check_api_contracts.addon_paths(addon_root))
    wanted = sorted({u.name for _, uses, _ in scans for u in uses if u.category == "cvar" and u.name})
    digest = hashlib.sha256()
    with open(binary, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
        handle.seek(0)
        with mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ) as image:
            for name in wanted:
                if name.lower() in data["cvars"]:
                    continue
                offset = image.find(b"\0" + name.encode("ascii") + b"\0")
                if offset >= 0:
                    data["cvars"][name.lower()] = {"name": name, "offset": offset + 1, "via": "client binary"}
    return {"build": build, "file": Path(binary).name, "sha256": digest.hexdigest()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", required=True, type=Path, help="wow-ui-source checkout on branch forever")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="JSON file to write")
    parser.add_argument("--client-binary", type=Path, help="game executable that proves CVars no loaded source names")
    parser.add_argument("--client-build", help="build of --client-binary, for example 1.60.1.70862; must equal the source version")
    parser.add_argument("--addon-root", type=Path, default=Path(__file__).resolve().parents[2], help="addon checkout whose CVar names --client-binary may prove")
    args = parser.parse_args(argv)
    if bool(args.client_binary) != bool(args.client_build):
        print("error: --client-binary and --client-build go together", file=sys.stderr)
        return 1
    if not (args.source / gen_globals.DOCS).is_dir():
        print(f"error: {args.source / gen_globals.DOCS} does not exist", file=sys.stderr)
        return 1
    try:
        data = collect(args.source)
        commit, subject = describe(args.source)
        client = None
        if args.client_binary:
            client = prove_cvars_in_client(data, args.client_binary, args.client_build, args.source, args.addon_root)
    except (RuntimeError, ValueError, OSError) as err:
        print(f"error: {err}", file=sys.stderr)
        return 1
    if not data["functions"]:
        print(f"error: no API functions found in {args.source}", file=sys.stderr)
        return 1
    write_atomically(args.out, render(data, commit, subject, client))
    print(f"wrote {args.out}: " + ", ".join(f"{len(v)} {k}" for k, v in sorted(data.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
