"""List the files the game loads, in load order, from the TOCs and their XML includes.

Python twin of Tools/regression/toc_files.lua. Both must return the same paths in the same order.
"""

import posixpath
import re
from pathlib import Path

COMMENT = re.compile(r"<!--.*?-->", re.S)
ENTRY = re.compile(r"<(Script|Include)\b([^>]*)>")
FILE_ATTR = re.compile(r"\sfile\s*=\s*([\"'])(.*?)\1")


def _join(directory, rel):
    path = posixpath.normpath(posixpath.join(directory, rel.replace("\\", "/")))
    return "" if path == "." else path


def _read(root, rel):
    try:
        return (root / rel).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None


def _add(root, rel, out, visiting):
    if rel.lower().endswith(".xml"):
        _walk_xml(root, rel, out, visiting)
    else:
        out.append(rel)


def _walk_xml(root, rel, out, visiting):
    out.append(rel)
    if rel in visiting:
        return
    text = _read(root, rel)
    if text is None:
        return
    visiting.add(rel)
    directory = posixpath.dirname(rel)
    for match in ENTRY.finditer(COMMENT.sub("", text)):
        attr = FILE_ATTR.search(match.group(2))
        if attr:
            _add(root, _join(directory, attr.group(2)), out, visiting)
    visiting.discard(rel)


def _walk_toc(root, rel, out):
    directory = posixpath.dirname(rel)
    for line in (_read(root, rel) or "").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            _add(root, _join(directory, line), out, set())


def toc_files(root, module_glob=None):
    """Return every file <root>/<Name>.toc and its <Name>_*/*.toc modules load, in load order.

    Paths use "/" and start with root unless root is ".". module_glob overrides "<Name>_*".
    """
    root = Path(root)
    rels = []
    for toc in sorted(p.name for p in root.glob("*.toc")):
        _walk_toc(root, toc, rels)
        pattern = module_glob or f"{toc[:-4]}_*"
        for module_toc in sorted(p.relative_to(root).as_posix() for p in root.glob(f"{pattern}/*.toc")):
            _walk_toc(root, module_toc, rels)
    prefix = "" if str(root) == "." else f"{root.as_posix()}/"
    return [prefix + rel for rel in rels]
