"""Fail when addon code names a Forever API, event, template, CVar, enum or global that the Forever source does not show.

Usage: python3 Tools/hooks/check_api_contracts.py [--root .] [--contracts <json>] [--inventory] [paths...]

Reads Tools/data/forever_api_contracts.json, which Tools/build/gen_api_contracts.py writes from the
Forever UI source, and Tools/data/forever_globals.lua for global names. It needs no source checkout.
Each problem prints as "path:line: category: message". --inventory prints every checked occurrence
instead, with the source line that proves it, and lists the dynamic operands the guard cannot resolve.
docs/API_CONFORMANCE.md says what is and is not checked.
"""

import argparse
import difflib
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "build"))

import gen_api_contracts as scanner  # noqa: E402
import gen_globals  # noqa: E402
from toc_files import toc_files  # noqa: E402

REPO = HERE.parents[1]
DEFAULT_CONTRACTS = REPO / "Tools" / "data" / "forever_api_contracts.json"
DEFAULT_GLOBALS = REPO / "Tools" / "data" / "forever_globals.lua"
SKIPPED_FOLDERS = ("Libs/", ".release/")


class Result:
    """One checked occurrence. status is ok, problem or dynamic."""

    def __init__(self, path, use, status, message="", proof=""):
        self.path, self.use, self.status, self.message, self.proof = path, use, status, message, proof


class Contracts:
    def __init__(self, data, globals_text=""):
        self.data = data
        self.cvars = data["cvars"]
        self.removed = data["removed"]
        self.commit = data["source"]["commit"]
        section = None
        self.read, self.deprecated = set(), set()
        for line in globals_text.splitlines():
            stripped = line.strip()
            if stripped.startswith("read = {"):
                section = self.read
            elif stripped.startswith("deprecated = {"):
                section = self.deprecated
            elif section is not None:
                match = re.match(r'"([^"]+)",$', stripped)
                if match:
                    section.add(match.group(1))

    def where(self, entry):
        """Return the source path:line a contract entry came from."""
        if isinstance(entry, dict) and "offset" in entry:
            client = self.data["client"]
            return f"client {client['build']} sha256 {client['sha256'][:12]} offset 0x{entry['offset']:x}"
        at = entry if isinstance(entry, str) else entry["at"]
        index, line = at.split(":")
        return f"{self.data['files'][int(index)]}:{line}"

    def known(self, section, name):
        return self.data[section].get(name)


def load_contracts(path=DEFAULT_CONTRACTS, globals_path=DEFAULT_GLOBALS):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    globals_text = Path(globals_path).read_text(encoding="utf-8") if Path(globals_path).exists() else ""
    return Contracts(data, globals_text)


def close(name, pool):
    matches = difflib.get_close_matches(name, list(pool), 1, 0.75)
    return f" (did you mean {matches[0]}?)" if matches else ""


def check_use(contracts, use, local):
    """Return (status, message, proof) for one Use. local holds what the addon itself creates."""
    data = contracts.data
    category, name = use.category, use.name
    if category in ("namespace", "api"):
        return check_api(contracts, use)
    if category == "event":
        if name is None:
            return "dynamic", "event passed as a variable", ""
        entry = data["events"].get(name)
        if entry:
            return "ok", "", contracts.where(entry)
        return "problem", f"event {name} is not in the documentation or loaded Blizzard source" + close(name, data["events"]), ""
    if category == "cvar":
        entry = contracts.cvars.get(name.lower()) if name else None
        if name is None:
            return "dynamic", "CVar passed as a variable", ""
        if entry:
            return "ok", "", contracts.where(entry)
        return "problem", f"CVar {name} is not named by any loaded Blizzard source (unproven; regenerate with --client-binary to prove an engine CVar)" + close(name.lower(), contracts.cvars), ""
    if category == "template":
        if name is None:
            return "dynamic", "template passed as a variable", ""
        entry = data["templates"].get(name)
        if entry:
            return "ok", "", contracts.where(entry)
        if name in local["templates"]:
            return "ok", "template the addon defines", ""
        return "problem", f"template {name} is not defined by loaded Blizzard XML" + close(name, data["templates"]), ""
    if category == "enum":
        return check_enum(contracts, use)
    if category == "mixin":
        entry = data["mixins"].get(name)
        if entry:
            return "ok", "", contracts.where(entry)
        if name in local["globals"] or name in local["mixins"]:
            return "ok", "mixin the addon defines", ""
        return "problem", f"mixin {name} is not defined by loaded Blizzard Lua" + close(name, data["mixins"]), ""
    if category == "addon":
        status = data["addons"].get(name)
        if status == "loaded":
            return "ok", "", "Interface/AddOns/" + name
        if status:
            return "problem", f"addon {name} is {status} on Forever", ""
        return "problem", f"no Blizzard addon folder named {name}" + close(name, data["addons"]), ""
    if category == "global":
        return check_global(contracts, use, local)
    raise ValueError(category)


def check_api(contracts, use):
    data = contracts.data
    parts = (use.name or "").split(".")
    top = len(parts) if use.category == "namespace" or use.operand is not None else len(parts) - 1
    split = next((k for k in range(top, 0, -1) if ".".join(parts[:k]) in data["namespaces"]), None)
    if split is None:
        root = parts[0]
        if root in contracts.removed or any(key.startswith(root + ".") for key in data["secure_only"]):
            return "problem", f"{root} is not available to addons on Forever", contracts.removed.get(root, "")
        return "problem", f"namespace {root} is not documented or defined by loaded Blizzard Lua" + close(root, data["namespaces"]), ""
    namespace = ".".join(parts[:split])
    proof = contracts.where(data["namespaces"][namespace])
    if data["namespaces"][namespace].get("secure"):
        return "problem", f"{namespace} is for the secure environment and not available to addons", proof
    if use.operand is not None and len(parts) == split:
        return "dynamic", f"member of {namespace} computed at run time: [{use.operand}]", proof
    if use.category == "namespace" or len(parts) == split:
        return "ok", "", proof
    full = namespace + "." + parts[split]
    if full in data["secure_only"]:
        return "problem", f"{full} is for the secure environment and not available to addons", contracts.where(data["secure_only"][full])
    entry = data["functions"].get(full)
    if entry and full not in contracts.removed:
        return "ok", "", contracts.where(entry)
    if full in contracts.removed:
        return "problem", f"Forever removes {full}", contracts.where(contracts.removed[full])
    if data["namespaces"][namespace].get("open"):
        return "dynamic", "namespace defined in Lua with unknown members; member unverified", proof
    pool = [key.split(".", len(namespace.split(".")))[-1] for key in data["functions"] if key.startswith(namespace + ".")]
    return "problem", f"{namespace} has no member {parts[split]}" + close(parts[split], pool), proof


def check_enum(contracts, use):
    data = contracts.data
    parts = use.name.split(".")
    section = data["enums"] if parts[0] == "Enum" else data["constants"]
    field = "fields" if parts[0] == "Enum" else "values"
    entry = section.get(parts[1])
    if entry is None or ".".join(parts[:2]) in contracts.removed:
        return "problem", f"{parts[0]}.{parts[1]} is not in the documentation or loaded Blizzard Lua" + close(parts[1], section), ""
    proof = contracts.where(entry)
    if use.operand is not None:
        return "dynamic", f"member of {parts[0]}.{parts[1]} computed at run time: [{use.operand}]", proof
    if len(parts) == 2 or parts[2] in entry[field]:
        return "ok", "", proof
    if entry.get("open"):
        return "dynamic", "table defined in Lua with unknown members; member unverified", proof
    note = " (the source shows only the members loaded Blizzard code reads)" if entry.get("via") == "use" else ""
    return "problem", f"{parts[0]}.{parts[1]} has no member {parts[2]}{note}" + close(parts[2], entry[field]), proof


def check_global(contracts, use, local):
    name = use.name
    if name is None:
        prefix = use.detail[len("prefix "):] if use.detail.startswith("prefix ") else ""
        if not prefix:
            return "dynamic", f"global name computed at run time: [{use.operand}]", ""
        known = contracts.read | local["globals"]
        if any(candidate.startswith(prefix) for candidate in known):
            return "dynamic", f"global name starts with {prefix} and is computed at run time: [{use.operand}]", ""
        return "problem", f"no Forever global starts with {prefix}", ""
    if name in local["globals"] or name in gen_globals.LUA51_STD:
        return "ok", "", ""
    if name in contracts.deprecated:
        return "problem", f"{name} is a deprecated shim that Forever does not load", ""
    if name in contracts.read:
        return "ok", "", "Tools/data/forever_globals.lua"
    return "problem", f"global {name} is not defined or read by loaded Blizzard source" + close(name, contracts.read), ""


def addon_paths(root, paths=None):
    """Return the addon Lua and XML files to scan: the given paths, or every file a TOC loads."""
    root = Path(root)
    found = [Path(p) if Path(p).is_absolute() else root / p for p in paths] if paths else [Path(rel) for rel in toc_files(root)]
    seen, kept = set(), []
    for path in found:
        rel = os.path.relpath(path, root).replace(os.sep, "/")
        if path.suffix.lower() in (".lua", ".xml") and path not in seen and not rel.startswith(SKIPPED_FOLDERS) and path.exists():
            seen.add(path)
            kept.append(path)
    return kept


def scan_files(files):
    """Return (scans, local): each file's uses, and what the addon itself defines."""
    scans = []
    local = {"globals": set(), "templates": set(), "mixins": set()}
    texts = {path: path.read_text(encoding="utf-8", errors="replace") for path in files}
    own = {}
    for path, text in texts.items():
        if path.suffix.lower() == ".lua":
            own[path] = (scanner.event_parameters(text), scanner.member_getters(text))
    fields = {}
    for path, text in texts.items():
        if path.suffix.lower() == ".lua":
            for key, value in scanner.field_constants(text).items():
                fields.setdefault(key, set()).add(value)
    shared_consts = {key: next(iter(values)) for key, values in fields.items() if len(values) == 1}
    shared = [{}, {}]
    for index in (0, 1):
        names = {}
        for specs in own.values():
            for name, spec in specs[index].items():
                names.setdefault(name, []).append(str(spec))
        for path, specs in own.items():
            shared[index].update({n: s for n, s in specs[index].items() if len(set(names[n])) == 1})
    for path in files:
        text = texts[path]
        if path.suffix.lower() == ".lua":
            uses, defines = scanner.scan_lua(text, dict(shared[0], **own[path][0]), dict(shared[1], **own[path][1]), shared_consts)
            local["globals"] |= defines
            local["mixins"] |= {name for name, _ in scanner.scan_defs(text)[1]}
        else:
            try:
                uses, defines = scanner.scan_xml(text)
                local["templates"] |= {name for name, _, _ in scanner.xml_templates(text)}
            except Exception as err:  # noqa: BLE001
                scans.append((path, [], str(err)))
                continue
            local["globals"] |= defines
        scans.append((path, uses, None))
    return scans, local


def check(root, contracts, paths=None):
    """Return a Result for every checked occurrence under root, in file and line order."""
    root = Path(root)
    scans, local = scan_files(addon_paths(root, paths))
    results = []
    for path, uses, error in scans:
        rel = os.path.relpath(path, root).replace(os.sep, "/")
        if error:
            results.append(Result(rel, scanner.Use("xml", None, 0, ""), "problem", "XML does not parse: " + error))
            continue
        for use in uses:
            status, message, proof = check_use(contracts, use, local)
            results.append(Result(rel, use, status, message, proof))
    return results


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="addon root that holds the TOC files (default: .)")
    parser.add_argument("--contracts", default=str(DEFAULT_CONTRACTS), help="contracts JSON to check against")
    parser.add_argument("--globals", default=str(DEFAULT_GLOBALS), help="forever_globals.lua for global names")
    parser.add_argument("--inventory", action="store_true", help="list every checked occurrence, not only problems")
    parser.add_argument("paths", nargs="*", help="files to check instead of every file a TOC loads")
    args = parser.parse_args(argv)
    contracts = load_contracts(args.contracts, args.globals)
    results = check(args.root, contracts, args.paths)
    results.sort(key=lambda r: (r.path, r.use.line, r.use.category, r.use.name or ""))
    if args.inventory:
        print("category\tstatus\tlocation\tname\tdetail\tsource proof")
        for r in results:
            name = r.use.name if r.use.name is not None else "<dynamic> " + (r.use.operand or "")
            detail = r.message or r.use.detail
            print(f"{r.use.category}\t{r.status}\t{r.path}:{r.use.line}\t{name}\t{detail}\t{r.proof}")
        counts = {}
        for r in results:
            counts[(r.use.category, r.status)] = counts.get((r.use.category, r.status), 0) + 1
        print(f"# source {contracts.commit}; " + ", ".join(f"{c} {s}: {n}" for (c, s), n in sorted(counts.items())))
        return 1 if any(r.status == "problem" for r in results) else 0
    problems = [r for r in results if r.status == "problem"]
    for r in problems:
        print(f"{r.path}:{r.use.line}: {r.use.category}: {r.message}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
