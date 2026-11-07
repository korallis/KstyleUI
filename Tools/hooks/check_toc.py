"""Fail when a file listed by a TOC or an XML include is missing or differs in letter case from disk.

Compares names with os.listdir, because macOS finds a file whose case differs and Linux does not.
"""

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from toc_files import toc_files  # noqa: E402


def on_disk(root, rel):
    """Return the path as spelled on disk, or None if any component is missing."""
    current = root
    actual = []
    for part in rel.split("/"):
        try:
            names = os.listdir(current)
        except OSError:
            return None
        if part not in names:
            folded = [n for n in names if n.lower() == part.lower()]
            if not folded:
                return None
            part = folded[0]
        actual.append(part)
        current = current / part
    return "/".join(actual)


def problems(root):
    found = []
    for path in toc_files(root):
        rel = Path(os.path.relpath(path, root)).as_posix()
        actual = on_disk(root, rel)
        if actual is None:
            found.append(f"missing: {rel}")
        elif actual != rel:
            found.append(f"case: {rel} != {actual}")
    return found


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="addon root that holds the TOC files (default: .)")
    args = parser.parse_args(argv)
    found = problems(Path(args.root))
    for line in found:
        print(line)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
