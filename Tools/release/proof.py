"""Reuse staging checks of the tag's tree, refuse known red, or run the release's own gates."""

import http.client
import os
import subprocess
import time
import urllib.parse

from Tools.hooks.ci_scope import github_json


def tree(sha):
    return subprocess.run(["git", "rev-parse", "--verify", "--quiet", sha + "^{tree}"],
                          capture_output=True, text=True, check=False).stdout.strip() or None


def main():
    run_checks = True
    try:
        repo, sha = os.environ["GITHUB_REPOSITORY"], os.environ["GITHUB_SHA"]
        wanted = tree(sha)
        if not wanted:
            raise ValueError(sha)
        deadline = time.monotonic() + 900
        while True:
            result = github_json(f"/repos/{repo}/actions/workflows/checks.yml/runs?" + urllib.parse.urlencode(
                {"branch": "staging", "event": "push", "per_page": 100}))
            runs = [run for run in result["workflow_runs"]
                    if run["path"] == ".github/workflows/checks.yml" and run["event"] == "push"
                    and run["head_repository"]["full_name"] == repo and tree(run["head_sha"]) == wanted]
            if not runs:
                print(f"No checks.yml staging run for the tree of {sha}: running release gates")
                break
            newest = max(runs, key=lambda run: (run["created_at"], run["id"]))
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
