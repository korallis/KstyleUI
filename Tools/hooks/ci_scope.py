#!/usr/bin/env python3
"""Decide CI work from PR changes, staging tree markers or a completed SHA proof.

Usage: ci_scope.py <lint|lua|python|package|all|proven-sha>. Writes run=true/false to
GITHUB_OUTPUT, or one output per area for all. Missing or uncertain proof runs.
"""

import fnmatch
import http.client
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request

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
    "docs/feature-map.md",
    "docs/media/marketing/*",
    "docs/media/plates",
    "docs/media/plates/*",
    "docs/store/gallery",
    "docs/store/gallery/*",
    "docs/store/description.md",
    "docs/store/curseforge.md",
    "docs/store/wago.md",
    "docs/superpowers/plans/element-keys.md",
    "docs/design/mockups/*",
    "docs/icons.md",
    "*/PROVENANCE.md",
    "PROVENANCE.md",
    "LICENSE.md",
    ".github/PULL_REQUEST_TEMPLATE.md",
)

READ_BY_AREA = {
    "python": ("README.md", "docs/media/readme/*"),
}

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
    if any(fnmatch.fnmatchcase(path, pattern) for pattern in READ_BY_AREA.get(area, ())):
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
    if area == "lint":
        return True, "lint checks every pull request"
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
        diff = subprocess.run(["git", "diff", "--name-only", "--no-renames", "-z", parents[1], "HEAD"],
                              capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    return [path for path in diff.decode("utf-8", "replace").split("\0") if path]


def current_tree():
    return subprocess.run(["git", "rev-parse", "HEAD^{tree}"], capture_output=True,
                          text=True, check=True).stdout.strip()


def github_json(path):
    request = urllib.request.Request(os.environ.get("GITHUB_API_URL", "https://api.github.com") + path,
                                     headers={"Authorization": "Bearer " + os.environ["GITHUB_TOKEN"],
                                              "Accept": "application/vnd.github+json",
                                              "X-GitHub-Api-Version": "2022-11-28"})
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response)


def push_decision(area):
    if area == "lua":
        return True, "staging always checks Mac CPU and cumulative instruction budgets"
    try:
        if os.environ.get("GITHUB_REF") != "refs/heads/staging":
            return True, "staging moved or no proof: running"
        tree = current_tree()
        green = f"green-{tree}-{area}"
        repo = os.environ["GITHUB_REPOSITORY"]
        matches = []
        for name in (green, f"red-{tree}-{area}", f"start-{tree}-{area}"):
            result = github_json(f"/repos/{repo}/actions/artifacts?" + urllib.parse.urlencode({"name": name, "per_page": 100}))
            artifacts = result["artifacts"]
            if result["total_count"] != len(artifacts):
                return True, "staging moved or no proof: running"
            matches.extend(artifact for artifact in artifacts if artifact["name"] == name)
        if matches:
            newest = max(matches, key=lambda artifact: artifact["created_at"])
            if sum(artifact["created_at"] == newest["created_at"] for artifact in matches) != 1:
                return True, "staging moved or no proof: running"
            if newest["name"] == green and not newest["expired"]:
                run_id = newest["workflow_run"]["id"]
                run = github_json(f"/repos/{repo}/actions/runs/{run_id}")
                if (run["path"] == ".github/workflows/checks.yml" and run["event"] == "pull_request"
                        and run["status"] == "completed" and run["conclusion"] == "success"
                        and run["head_repository"]["full_name"] == repo):
                    return False, f"tree {tree}, area {area} passed in run {run_id}: skipping"
    except (OSError, http.client.HTTPException, subprocess.CalledProcessError, ValueError, KeyError, TypeError):
        pass
    return True, "staging moved or no proof: running"


def sha_decision():
    try:
        repo, sha = os.environ["GITHUB_REPOSITORY"], os.environ["GITHUB_SHA"]
        deadline = time.monotonic() + 900
        while True:
            result = github_json(f"/repos/{repo}/actions/runs?" + urllib.parse.urlencode(
                {"head_sha": sha, "event": "push", "per_page": 100}))
            runs = [run for run in result["workflow_runs"]
                    if run["path"] == ".github/workflows/checks.yml" and run["event"] == "push"
                    and run["head_sha"] == sha and run["head_repository"]["full_name"] == repo]
            if not runs:
                return True, f"no checks.yml push run for {sha}: running"
            newest = max(runs, key=lambda run: (run["created_at"], run["id"]))
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return True, f"timed out waiting for checks.yml push run {newest['id']} after 900s: running"
            if newest["status"] == "completed" and newest["conclusion"] == "success":
                return False, f"SHA {sha} passed in checks.yml push run {newest['id']}: skipping"
            if newest["status"] not in ("queued", "in_progress"):
                return True, f"checks.yml push run {newest['id']} is {newest['status']}/{newest['conclusion']}: running"
            print(f"proven-sha: waiting for checks.yml push run {newest['id']} ({newest['status']}); "
                  f"{remaining:.0f}s remaining", flush=True)
            time.sleep(min(15, remaining))
    except (OSError, http.client.HTTPException, ValueError, KeyError, TypeError):
        return True, "API error or missing SHA proof: running"


def main(argv):
    if len(argv) != 1 or argv[0] not in ("lint",) + AREAS + ("all", "proven-sha"):
        print("usage: ci_scope.py <lint|{0}|all|proven-sha>".format("|".join(AREAS)), file=sys.stderr)
        return 2
    areas = ("lint",) + AREAS if argv[0] == "all" else (argv[0],)
    event = os.environ.get("GITHUB_EVENT_NAME", "")
    paths = changed_paths() if event == "pull_request" else None
    lines = []
    for area in areas:
        if area == "proven-sha":
            run, reason = sha_decision()
        else:
            run, reason = push_decision(area) if event == "push" else decide(area, event, paths)
        print("{0}: {1}: {2}".format(area, "run" if run else "skip", reason))
        lines.append("{0}={1}".format(area if argv[0] == "all" else "run", "true" if run else "false"))
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8", newline="\n") as handle:
            handle.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
