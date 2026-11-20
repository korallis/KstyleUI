"""Reuse exact-SHA checks, refuse known red, or run the release's own gates."""

import http.client
import os
import time
import urllib.parse

from Tools.hooks.ci_scope import github_json


def main():
    run_checks = True
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
                print(f"No checks.yml push run for {sha}: running release gates")
                break
            newest = max(runs, key=lambda run: (run["created_at"], run["id"]))
            if newest["status"] == "completed":
                if newest["conclusion"] != "success":
                    print(f"Refusing release: checks.yml run {newest['id']} is {newest['conclusion']}")
                    return 1
                print(f"SHA {sha} passed in checks.yml run {newest['id']}: reusing checks")
                run_checks = False
                break
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                print("Timed out waiting for proof: running release gates")
                break
            print(f"Waiting for checks.yml run {newest['id']} ({newest['status']})", flush=True)
            time.sleep(min(120, remaining))
    except (OSError, http.client.HTTPException, ValueError, KeyError, TypeError):
        print("API error or missing SHA proof: running release gates")
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8", newline="\n") as output:
        output.write(f"run={str(run_checks).lower()}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
