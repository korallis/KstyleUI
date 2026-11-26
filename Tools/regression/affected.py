"""Pick the regression tests a change can affect, from a record of what each test file really loads.

run_all.py --affected BASE uses this. trace.lua records every file a test opens and every folder and tracked-file
pattern it lists through fs.lua; this module turns those lines into a per-test record, keeps the records in the
working copy's own git folder, and chooses the tests whose record meets a file that changed against BASE.
Tools/regression/README.md describes the mode and its limits.
"""

import fnmatch
import hashlib
import json
import os
import posixpath
import re
import subprocess
import tempfile
from pathlib import Path

VERSION = 4
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
    "test-shell-guard",
    "test-suite-load",
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
    "Tools/regression/fs.lua",
    "Tools/regression/stubs/*",
    "Tools/regression/load_files.lua",
    "Tools/regression/toc_files.lua",
    ".luacheckrc",
)

def shared_path():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return Path(base) / "kstyleui" / "regression-deps.json"


def cache_path(cwd=None):
    """Return KSTYLEUI_DEPS_CACHE, or a file in this working copy's own git folder, so another working copy on
    another branch never replaces these records."""
    explicit = os.environ.get("KSTYLEUI_DEPS_CACHE")
    if explicit:
        return Path(explicit)
    try:
        return Path(git("rev-parse", "--absolute-git-dir", cwd=cwd).strip()) / "kstyleui-regression-deps.json"
    except (OSError, RuntimeError):
        return shared_path()


def seen(record, root=".", memo=None):
    """Return one hash of what a record's test read, as it is under root now: the bytes of each file, whether
    each listed folder exists and the names its glob matches with which of them are folders (fs.list's dirs
    option tells them apart), and the paths git tracks for each pattern."""
    memo = {} if memo is None else memo

    def answer(kind, value):
        if (kind, value) not in memo:
            if kind == "f":
                found = fingerprint(os.path.join(root, value))
            elif kind == "n":
                folder, _, glob = value.rpartition("/")
                try:
                    found = repr(("listed", sorted((entry.name, entry.is_dir()) for entry in os.scandir(os.path.join(root, folder))
                                                   if fnmatch.fnmatchcase(entry.name, glob))))
                except OSError:
                    found = repr(("missing",))
            else:
                found = git("ls-files", "-z", "--", value, cwd=root)
            memo[kind, value] = found
        return memo[kind, value]

    digest = hashlib.sha1()
    for kind, key in (("f", "files"), ("n", "listings"), ("t", "names")):
        for value in sorted(record.get(key, [])):
            digest.update("{0} {1}\0{2}\n".format(kind, value, answer(kind, value)).encode("utf-8"))
    return digest.hexdigest()


def load_records(cwd=None):
    """Return this working copy's records. A working copy with none yet starts from the shared copy's records
    whose files, listings and tracked names are what this working copy holds: a record made on a tree where one
    of them differed may name the wrong files, so its test has no record and runs."""
    records = load_cache(cache_path(cwd))
    if records or os.environ.get("KSTYLEUI_DEPS_CACHE"):
        return records
    memo, records = {}, {}
    for test, record in load_cache(shared_path()).items():
        try:
            if record.get("seen") == seen(record, cwd or ".", memo):
                records[test] = record
        except (OSError, RuntimeError):
            pass
    return records


def save_records(records, cwd=None):
    """Merge records into this working copy's file and into the shared copy the next new working copy starts from."""
    own = cache_path(cwd)
    save_cache(own, records, None if own.exists() else load_records(cwd))
    if not os.environ.get("KSTYLEUI_DEPS_CACHE") and own != shared_path():
        save_cache(shared_path(), records)


def load_cache(path):
    """Return {test path: record}; an unreadable or older cache is empty."""
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    if not isinstance(data, dict) or data.get("version") != VERSION or not isinstance(data.get("tests"), dict):
        return {}
    return data["tests"]


def save_cache(path, records, start=None):
    """Merge records into the cache file, or into start when the file holds none. The write is atomic, so two
    runs at once never corrupt it."""
    path = Path(path)
    tests = load_cache(path) or dict(start or {})
    tests.update(records)
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temp = tempfile.mkstemp(dir=path.parent, prefix=path.name, suffix=".tmp")
    with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as out:
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


def fingerprint(path):
    """Return a hash of the test file's bytes, or "" when it cannot be read."""
    try:
        return hashlib.sha1(Path(path).read_bytes()).hexdigest()
    except OSError:
        return ""


def record_from_trace(text, root):
    """Turn trace.lua's lines into a record: {files, idle, listings, names}; run_all.py adds the test's fingerprint.

    listings holds "<folder>/<glob>" for each folder fs.list read ("<glob>" alone for the repository root), and
    names the patterns fs.tracked passed to git ls-files. idle holds the language files load_files.lua ran only
    where the game language is unset, where each returns on its first line; a change to one does not select the test.
    """
    files, idle, listings, names = set(), set(), set(), set()
    for line in text.splitlines():
        kind, _, value = line.partition(" ")
        if kind == "f":
            path = normalize(value, root)
            if path:
                files.add(path)
        elif kind == "s":
            path = normalize(value, root)
            if path:
                idle.add(path)
        elif kind == "n":
            folder, _, glob = value.rstrip("/").rpartition("/")
            if not any(c in glob for c in "*?["):
                folder, glob = value.rstrip("/"), "*"
            folder = "" if posixpath.normpath(folder or ".") == "." else normalize(folder, root)
            if folder is not None:
                listings.add(posixpath.join(folder, glob))
        elif kind == "t":
            names.add(posixpath.normpath(value))
    return {"files": sorted(files), "idle": sorted(idle - files), "listings": sorted(listings), "names": sorted(names)}


def prefixes(path):
    parts = path.split("/")
    return ["/".join(parts[: i + 1]) for i in range(len(parts))]


def pattern_hits(pattern, path):
    """True when a folder or glob covers the path or one of its folders."""
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


def files_in(folder):
    try:
        return git("ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", folder).split("\0")[:-1]
    except RuntimeError:
        return []


def changed_folders(changes):
    """Return the folders that appeared, every file in them being added, or that are gone from disk."""
    folders, kept = set(), set()
    for path, status in sorted(changes.items()):
        if status not in ("A", "D"):
            continue
        parents = prefixes(path)[:-1]
        for i, folder in enumerate(parents):
            if folder in kept:
                continue
            if folder in folders or (not os.path.isdir(folder) if status == "D" else all(changes.get(p) == "A" for p in files_in(folder))):
                folders.update(parents[i:])
                break
            kept.add(folder)
    return folders


def listing_hit(listing, path, folders):
    """True when adding or deleting path adds or removes a name in a "<folder>/<glob>" listing: the path itself, or
    its folder in the listing when that folder is one of changed_folders."""
    folder, _, glob = listing.rpartition("/")
    if folder and not path.startswith(folder + "/"):
        return False
    entry, _, deeper = path[len(folder) + 1 if folder else 0:].partition("/")
    return fnmatch.fnmatchcase(entry, glob) and (not deeper or posixpath.join(folder, entry) in folders)


def hit(test, record, changes, folders):
    """Return the reason a record meets a change, or None."""
    own = test.replace(os.sep, "/")
    if own in changes:
        return own + " itself changed"
    for path in record["files"]:
        if path in changes:
            return path + " changed"
    for path in record.get("idle", []):
        if changes.get(path) in ("A", "D"):
            return path + (" was added" if changes[path] == "A" else " was deleted")
    for path, status in sorted(changes.items()):
        if status in ("A", "D") and (
            any(pattern_hits(pattern, path) for pattern in record["names"])
            or any(listing_hit(listing, path, folders) for listing in record["listings"])
        ):
            return path + (" was added" if status == "A" else " was deleted")
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
    if any(fnmatch.fnmatchcase(path, "Tools/regression/*_env.lua") for path in changes):
        for test in tests:
            if test not in cache or cache[test].get("sha") != fingerprint(test):
                return everything(tests, "missing or stale dependency record for " + test + "; every test file runs")
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
    chosen, notes, folders = {}, [], changed_folders(generic)
    for test in tests:
        record = cache.get(test)
        stem = Path(test).stem
        if record is None:
            chosen[test] = "no record of what it loads yet"
            continue
        if record.get("sha") != fingerprint(test):
            chosen[test] = "the record was made from another version of this test file"
            continue
        reason = hit(test, record, generic, folders)
        for path, folder in sorted(lists.items()):
            if reason is None and any(p.startswith(folder + "/") and p.endswith(".lua") for p in record["files"]):
                reason = "{0} changed and lists the files {1} loads".format(path, folder)
        if reason is None and stem in guards:
            reason = "source guard, always runs"
        if reason:
            chosen[test] = reason
    loaded = set()
    for test in known:
        loaded.update(cache[test]["files"] + cache[test].get("idle", []))
    patterns = [pattern for test in known for pattern in cache[test]["names"] + cache[test]["listings"]]
    unread = sorted(path for path in generic if path not in loaded and not any(pattern_hits(pattern, path) for pattern in patterns))
    if unread:
        shown = ", ".join(unread[:8]) + (" and {0} more".format(len(unread) - 8) if len(unread) > 8 else "")
        notes.append("no test file loads " + shown)
    return chosen, notes
