#!/usr/bin/env python3
"""ci_scope.py: decide whether a CI job has work to do, from the files a pull request changes.

Usage: python3 Tools/hooks/ci_scope.py <lua|python|package>
Run it from the repository root after a checkout of at least two commits. A pull request run checks out the merge
commit of the pull request and its base, so the first parent is the base and the diff between it and HEAD is
exactly what the pull request changes. Prints one line that says whether the job runs and why, and appends
run=true or run=false to $GITHUB_OUTPUT. It always exits 0: a job that has nothing to do succeeds, so every
job reports a result on every pull request.

Only a pull request can skip work. Any other event (a push to staging, a manual run) runs everything, and so
does a pull request whose changes cannot be read. A file counts as inert for an area only when no test or
build step of that area can read it; when in doubt the file is not inert.
"""

import fnmatch
import os
import subprocess
import sys

AREAS = ("lua", "python", "package")

PIPELINE = (
    ".github/workflows/checks.yml",
    "Tools/hooks/ci_scope.py",
    "Tools/hooks/check-package.sh",
    "Tools/regression/toc_files.lua",
    "Tools/regression/run_all.py",
    "Tools/regression/run-all.sh",
    ".pkgmeta",
)

READ_BY_TESTS = (
    "docs/superpowers/plans/element-keys.md",
    "*/PROVENANCE.md",
    "PROVENANCE.md",
    "LICENSE.md",
    ".github/PULL_REQUEST_TEMPLATE.md",
)

DOCS_FOLDERS = ("docs/", "research_notes/", "reports/")
ROOT_NOTES = ("README.md", "AGENTS.md")
ADDON_FOLDERS = ("Core/", "Media/", "KstyleUI_")

EXTRA_INERT = {
    "lua": (".github/*", "Tools/tests/*", ".pre-commit-config.yaml"),
    "python": (),
    "package": (
        "Tools/*", ".github/*", ".luacheckrc", ".pre-commit-config.yaml", "KstyleUI_*/README.md",
    ),
}


def is_inert(area, path):
    """True when no job of the area can read the file."""
    if path in PIPELINE:
        return False
    if any(fnmatch.fnmatchcase(path, pattern) for pattern in READ_BY_TESTS):
        return False
    if any(fnmatch.fnmatchcase(path, pattern) for pattern in EXTRA_INERT[area]):
        return True
    if path.startswith(DOCS_FOLDERS) or path in ROOT_NOTES:
        return True
    return path.endswith(".md") and not path.startswith(ADDON_FOLDERS)


def decide(area, event, paths):
    """Return (run, reason). paths is the list of changed files, or None when it could not be read."""
    if event != "pull_request":
        return True, "not a pull request ({0}): everything runs".format(event or "no event")
    if not paths:
        return True, "the changed files could not be read or the pull request changes none: running to be safe"
    for path in paths:
        if not is_inert(area, path):
            return True, "{0} changed and the {1} checks can read it".format(path, area)
    shown = ", ".join(paths[:5]) + (" and {0} more".format(len(paths) - 5) if len(paths) > 5 else "")
    return False, "nothing the {0} checks read changed ({1} files: {2}); skipping with a success".format(area, len(paths), shown)


def changed_paths():
    """Return the files the merge commit changes against its first parent, or None."""
    try:
        parents = subprocess.run(["git", "rev-list", "--parents", "-n", "1", "HEAD"],
                                 capture_output=True, text=True, check=True).stdout.split()
        if len(parents) < 3:
            return None
        diff = subprocess.run(["git", "diff", "--name-only", "-z", parents[1], "HEAD"],
                              capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    return [path for path in diff.decode("utf-8", "replace").split("\0") if path]


def main(argv):
    if len(argv) != 1 or argv[0] not in AREAS:
        print("usage: ci_scope.py <{0}>".format("|".join(AREAS)), file=sys.stderr)
        return 2
    area = argv[0]
    event = os.environ.get("GITHUB_EVENT_NAME", "")
    run, reason = decide(area, event, changed_paths() if event == "pull_request" else None)
    print("{0}: {1}: {2}".format(area, "run" if run else "skip", reason))
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as handle:
            handle.write("run={0}\n".format("true" if run else "false"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
