"""Reuse staging checks of the tag's tree, refuse known red, or run the release's own gates."""

import http.client
import os
import subprocess
import time

from Tools.hooks.ci_scope import github_json


def tree(sha):
    return subprocess.run(["git", "rev-parse", "--verify", "--quiet", sha + "^{tree}"],
                          capture_output=True, text=True).stdout.strip() or None


def newest_match(repo, wanted):
    page = 1
    while True:
        runs = github_json(f"/repos/{repo}/actions/workflows/checks.yml/runs"
                           f"?branch=staging&event=push&per_page=100&page={page}")["workflow_runs"]
        for run in sorted(runs, key=lambda run: (run["created_at"], run["id"]), reverse=True):
            if (run["path"], run["event"], run["head_repository"]["full_name"]) != (
                    ".github/workflows/checks.yml", "push", repo):
                continue
            found = tree(run["head_sha"])
            if not found:
                raise ValueError(f"commit {run['head_sha']} of run {run['id']} is not in the checkout")
            if found == wanted:
                return run
        if len(runs) < 100:
            return None
        page += 1


def main():
    run_checks = True
    try:
        repo, sha = os.environ["GITHUB_REPOSITORY"], os.environ["GITHUB_SHA"]
        wanted = tree(sha)
        if not wanted:
            raise ValueError(sha)
        deadline = time.monotonic() + 900
        while True:
            newest = newest_match(repo, wanted)
            if not newest:
                print(f"No checks.yml staging run for the tree of {sha}: running release gates")
                break
            if newest["status"] == "completed":
                if newest["conclusion"] != "success":
                    print(f"Refusing release: checks.yml run {newest['id']} is {newest['conclusion']}")
                    return 1
                print(f"Tree {wanted} passed in checks.yml run {newest['id']}: reusing checks")
                run_checks = False
                break
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                print("Timed out waiting for proof: running release gates")
                break
            print(f"Waiting for checks.yml run {newest['id']} ({newest['status']})", flush=True)
            time.sleep(min(120, remaining))
    except (OSError, http.client.HTTPException, ValueError, KeyError, TypeError):
        print("API error or missing tree proof: running release gates")
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8", newline="\n") as output:
        output.write(f"run={str(run_checks).lower()}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
