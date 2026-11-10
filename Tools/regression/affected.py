"""Pick the regression tests a change can affect, from a record of what each test file really loads.

run_all.py --affected BASE uses this. trace.lua records every file a test opens and every shell command it
runs; this module turns those lines into a per-test record, keeps the records in a cache outside the
repository, and chooses the tests whose record meets a file that changed against BASE.
Tools/regression/README.md describes the mode and its limits.
"""

import fnmatch
import hashlib
import json
import os
import posixpath
import re
import shlex
import subprocess
import tempfile
from pathlib import Path

VERSION = 2
SHARED_FRACTION = 0.5
SHARED_MINIMUM = 10
GUARDS = (
    "test-comments",
    "test-features",
    "test-fontstrings",
    "test-grades",
    "test-lua-source",
    "test-modules-load",
    "test-scaffold",
    "test-secrets",
    "test-suite-load",
    "test-syntax",
    "test-taint-scan",
    "test-tokens",
    "test-type-calls",
)
MODULE_LIST = re.compile(r"^(KstyleUI_\w+)/[^/]+\.(toc|xml)$")
SHARED_PATHS = (
    "Tools/regression/run-all.sh",
    "Tools/regression/run_all.py",
    "Tools/regression/affected.py",
    "Tools/regression/trace.lua",
    "Tools/regression/stubs/*",
    "Tools/regression/*_env.lua",
    "Tools/regression/load_files.lua",
    "Tools/regression/toc_files.lua",
    ".luacheckrc",
)
IGNORED_COMMANDS = ("mkdir", "rm", "uptime", "date", "echo", "true", "false")


def cache_path():
    explicit = os.environ.get("KSTYLEUI_DEPS_CACHE")
    if explicit:
        return Path(explicit)
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return Path(base) / "kstyleui" / "regression-deps.json"


def load_cache(path):
    """Return {test path: record}; an unreadable or older cache is empty."""
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    if not isinstance(data, dict) or data.get("version") != VERSION or not isinstance(data.get("tests"), dict):
        return {}
    return data["tests"]


def save_cache(path, records):
    """Merge records into the cache file. The write is atomic, so two runs at once never corrupt it."""
    path = Path(path)
    tests = load_cache(path)
    tests.update(records)
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temp = tempfile.mkstemp(dir=path.parent, prefix=path.name, suffix=".tmp")
    with os.fdopen(handle, "w", encoding="utf-8") as out:
        json.dump({"version": VERSION, "tests": tests}, out, indent=1, sort_keys=True)
        out.write("\n")
    os.replace(temp, path)


def normalize(path, root):
    """Return a path relative to the repository root, or None for a path outside it."""
    path = path.strip()
    if not path:
        return None
    if os.path.isabs(path):
        path = os.path.relpath(path, root)
    path = posixpath.normpath(path.replace(os.sep, "/"))
    if path == "." or path == ".." or path.startswith("../") or path.startswith(".git/"):
        return None
    return path


def command_deps(command):
    """Return (kind, patterns) for a shell command a test ran.

    kind is "names" when only the names in a folder matter (ls, git ls-files), "content" when file
    contents do (grep -r), "ignore" for a command that reads nothing in the repository, and "wide" when
    the command is unknown and the test must always run.
    """
    try:
        words = shlex.split(command)
    except ValueError:
        return "wide", []
    if not words:
        return "ignore", []
    name = words[0]
    if name in IGNORED_COMMANDS:
        return "ignore", []
    if name == "ls":
        return "names", [word for word in words[1:] if not word.startswith("-") and word != "2>/dev/null"]
    if name == "git" and words[1:2] == ["ls-files"]:
        return "names", [word for word in words[2:] if not word.startswith("-") and word != "2>/dev/null"] or ["*"]
    if name == "grep":
        operands, flags_done = [], False
        for word in words[1:]:
            if word == "2>/dev/null":
                continue
            if word.startswith("-") and not flags_done:
                continue
            operands.append(word)
        return "content", operands[1:] or ["*"]
    return "wide", []


def fingerprint(path):
    """Return a hash of the test file's bytes, or "" when it cannot be read."""
    try:
        return hashlib.sha1(Path(path).read_bytes()).hexdigest()
    except OSError:
        return ""


def record_from_trace(text, root):
    """Turn trace.lua's lines into a record: {files, names, content, wide}; run_all.py adds the test's fingerprint."""
    files, names, content, wide = set(), set(), set(), False
    for line in text.splitlines():
        kind, _, value = line.partition(" ")
        if kind == "f":
            path = normalize(value, root)
            if path:
                files.add(path)
        elif kind == "c":
            what, patterns = command_deps(value)
            if what == "wide":
                wide = True
            for pattern in patterns:
                pattern = normalize(pattern, root) if not any(c in pattern for c in "*?[") else posixpath.normpath(pattern)
                if pattern:
                    (names if what == "names" else content).add(pattern)
    return {"files": sorted(files), "names": sorted(names), "content": sorted(content), "wide": wide}


def prefixes(path):
    parts = path.split("/")
    return ["/".join(parts[: i + 1]) for i in range(len(parts))]


def pattern_hits(pattern, path):
    """True when a folder or glob a command named covers the path or one of its folders."""
    pattern = pattern.rstrip("/")
    return any(fnmatch.fnmatchcase(prefix, pattern) for prefix in prefixes(path))


def git(*args, cwd=None):
    result = subprocess.run(("git",) + args, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git " + " ".join(args) + " failed")
    return result.stdout


def changed_files(base, cwd=None):
    """Return (merge_base, {path: status}) for the working tree against the merge base with base.

    A status is "A", "M" or "D". Staged, unstaged and untracked files count; a rename is a delete and an add.
    """
    merge_base = git("merge-base", base, "HEAD", cwd=cwd).strip()
    changes = {}
    fields = git("diff", "--name-status", "--no-renames", "-z", merge_base, cwd=cwd).split("\0")
    for i in range(0, len(fields) - 1, 2):
        changes[fields[i + 1]] = fields[i][0]
    for path in git("ls-files", "--others", "--exclude-standard", "-z", cwd=cwd).split("\0"):
        if path:
            changes[path] = "A"
    return merge_base, changes


def hit(test, record, changes):
    """Return the reason a record meets a change, or None."""
    own = test.replace(os.sep, "/")
    if own in changes:
        return own + " itself changed"
    for path in record["files"]:
        if path in changes:
            return path + " changed"
    for path, status in sorted(changes.items()):
        if status in ("A", "D") and any(pattern_hits(pattern, path) for pattern in record["names"]):
            return path + (" was added" if status == "A" else " was deleted")
        if any(pattern_hits(pattern, path) for pattern in record["content"]):
            return path + " changed"
    return None


def everything(tests, why):
    return {test: "run everything" for test in tests}, [why]


def select(tests, changes, cache, guards=GUARDS):
    """Return (chosen, notes): {test: reason} for the tests to run and a list of lines that explain the choice.

    Every test runs when a shared file changed, when a changed file is loaded by half the tests or more,
    and when nothing is known about it. The source guards always run. A module's TOC or XML only lists
    that module's files, so it selects the tests that load the module's Lua files, not every test that
    walks the TOCs.
    """
    for path in sorted(changes):
        if any(fnmatch.fnmatchcase(path, pattern) for pattern in SHARED_PATHS):
            return everything(tests, path + " is shared by the whole suite, so every test file runs")
    known = [test for test in tests if test in cache]
    lists, generic = {}, {}
    for path, status in changes.items():
        match = MODULE_LIST.match(path)
        if match and any(cache[test]["files"] and any(p.startswith(match.group(1) + "/") for p in cache[test]["files"]) for test in known):
            lists[path] = match.group(1)
        else:
            generic[path] = status
    for path in sorted(generic):
        loaders = [test for test in known if path in cache[test]["files"]]
        if len(loaders) >= max(SHARED_MINIMUM, SHARED_FRACTION * len(tests)):
            return everything(tests, "{0} is loaded by {1} of {2} test files, so every test file runs".format(path, len(loaders), len(tests)))
    chosen, notes = {}, []
    for test in tests:
        record = cache.get(test)
        stem = Path(test).stem
        if record is None:
            chosen[test] = "no record of what it loads yet"
            continue
        if record.get("sha") != fingerprint(test):
            chosen[test] = "the record was made from another version of this test file"
            continue
        if record["wide"]:
            chosen[test] = "it runs commands that read the whole tree"
            continue
        reason = hit(test, record, generic)
        for path, folder in sorted(lists.items()):
            if reason is None and any(p.startswith(folder + "/") and p.endswith(".lua") for p in record["files"]):
                reason = "{0} changed and lists the files {1} loads".format(path, folder)
        if reason is None and stem in guards:
            reason = "source guard, always runs"
        if reason:
            chosen[test] = reason
    loaded = set()
    for test in known:
        loaded.update(cache[test]["files"])
    patterns = [pattern for test in known for pattern in cache[test]["names"] + cache[test]["content"]]
    unread = sorted(path for path in generic if path not in loaded and not any(pattern_hits(pattern, path) for pattern in patterns))
    if unread:
        shown = ", ".join(unread[:8]) + (" and {0} more".format(len(unread) - 8) if len(unread) > 8 else "")
        notes.append("no test file loads " + shown)
    return chosen, notes
