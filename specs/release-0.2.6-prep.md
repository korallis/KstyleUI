# Task: prepare the v0.2.6 release notes now, so tagging is fast

**Goal**: v0.2.6 ships as soon as the last PRs merge. Draft everything that does not depend on the remaining PRs now, in one draft PR, and keep it current.

**Target**: KstyleUI, latest `origin/staging`. Read how v0.2.5 was done: `CHANGELOG.md` (v0.2.5 entry), `docs/RELEASE_NOTES.md`, PR #455, and the `## Changelog` sections of every PR merged since tag `v0.2.5` (`git log v0.2.5..origin/staging`, `gh pr view <n> --json body`).

**Change**:
1. A `v0.2.6` entry in `CHANGELOG.md` and `docs/RELEASE_NOTES.md` built from the merged PRs' Changelog lines, in player words, grouped Added / Changed / Fixed, matching v0.2.5's style. Include: existing players move to the new default of tooltips at the cursor out of combat; the Personal Resource Display is off by default for new setups; the optional icon pack mention as in the store text.
2. Leave a clearly marked list of the still-open PRs (#460 and the audit batches: E-a, E-b, F-a, F-b, F-c, G8, G-b) at the end of the draft with their PR numbers when they exist; the coordinator adds their lines at tag time from each PR's own Changelog section.
3. Do not bump versions in TOC files or retake pictures (that happens after the last look change lands). Dry-run the picture retake commands once to prove they run (`python Tools/render/readme.py --help`, `python Tools/media/marketing.py --help`) and list the exact commands and run time in the PR body.

**Constraints**: minimal; docs only. Open a **draft** PR against `staging` titled `docs(release): v0.2.6 notes`, labelled `no changelog`. Local checks: `bash scripts/gate.sh lint` and `bash scripts/gate.sh python`.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`.

**Evidence of done**: the draft PR URL with green checks; the list of included PRs.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`.
