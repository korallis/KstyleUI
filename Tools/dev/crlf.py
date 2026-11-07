"""Convert addon files (.lua, .toc, .xml outside Tools/ and docs/) to CRLF line endings."""

import argparse
import os
import subprocess
import sys
from pathlib import Path

ADDON_SUFFIXES = {".lua", ".toc", ".xml"}
SKIPPED_TOP_DIRS = {"Tools", "docs"}


def is_addon_file(rel):
    parts = Path(rel).parts
    if not parts or parts[0] == ".." or parts[0] in SKIPPED_TOP_DIRS:
        return False
    return Path(rel).suffix in ADDON_SUFFIXES


def to_crlf(data):
    return data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")


def changed_files(root):
    out = subprocess.run(
        ["git", "-C", str(root), "status", "--porcelain", "-z", "--untracked-files=all"],
        check=True,
        capture_output=True,
    ).stdout.decode("utf-8", "surrogateescape")
    entries = out.split("\0")
    paths = []
    i = 0
    while i < len(entries):
        entry = entries[i]
        i += 1
        if len(entry) < 4:
            continue
        status, path = entry[:2], entry[3:]
        if "R" in status or "C" in status:
            i += 1  # the next entry is the rename or copy source
        paths.append(root / path)
    return paths


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", help="files to convert; default: changed and untracked files")
    parser.add_argument("--check", action="store_true", help="list LF addon files and exit 1, changing nothing")
    parser.add_argument("--root", default=".", help="repository root (default: current directory)")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    candidates = [Path(p).resolve() for p in args.paths] if args.paths else changed_files(root)

    found = []
    for path in candidates:
        rel = os.path.relpath(path, root)
        if not is_addon_file(rel) or not path.is_file():
            continue
        data = path.read_bytes()
        fixed = to_crlf(data)
        if fixed == data:
            continue
        found.append(Path(rel).as_posix())
        if not args.check:
            path.write_bytes(fixed)

    for rel in found:
        print(rel if args.check else f"crlf: {rel}")
    return 1 if args.check and found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
