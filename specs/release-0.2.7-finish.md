# Task: finish v0.2.7: notes and pictures in PR #534

**Goal**: everything for v0.2.7 is merged on `staging` (c5bda80e), and the full Mac suite is green. Bring the release notes and the published pictures up to date in draft PR #534 (branch `docs/release-v0-2-7`), fast. A final readiness recheck is running in parallel. **It will send you exact release-notes edits through the coordinator**: apply them when they arrive.

**Change**:
1. Rebase #534 onto `origin/staging`. In `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, replace the marked open-PR list with the `## Changelog` lines of every PR merged since your draft: #530, #533, #535, #536 and #537, plus any others in `git log v0.2.6..origin/staging` that aren't listed yet. Use player words and Added / Changed / Fixed. Set the date to today, 2026-11-20.
   - Mention the owner decisions plainly:
     - the data bar defaults to 14 units, so nothing moves or shrinks;
     - Medallions auras sit in rows above their frames, and the old look is under Aura layout, Crest fan;
     - the cooldowns are centred;
     - the Medallions dock shows the original five readouts by default.
   - Remove the overclaim "saved positions keep exact coordinates", and say instead: "positions you saved are kept; anything saved right at a screen edge is drawn just inside it".
2. Retake the pictures with `python Tools/render/readme.py` and `python Tools/media/marketing.py --pages`, the exact commands listed in #534's body.
   - Use real game scenery only (the scripts use the owner's backdrops; never AI scenery).
   - Keep the `game_*` in-game captures. The README's ultrawide heroes stay Spread.
   - Open every changed picture and check it shows the new looks: the Medallions centre (centred cooldowns, aura rows), the data bar (Frames top bar at 14 units, Medallions dock), the consumables bar and the crest minimap.
   - Commit the retaken files the scripts write in the same PR.
3. Retitle the PR `docs(release): v0.2.7 notes and pictures`, keep the `no changelog` label, mark it ready, and wait for green checks.

**Constraints**: minimal; only the files the scripts write plus the two notes files. On Windows (Beast), see `C:/Users/leeba/.claude/projects/C--Projects-KstyleUI/memory/beast-render-harness-chrome-urls.md` if a render writes no PNG. At most 2 renders at a time. Do not merge, tag or touch `main`.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `docs/media/**`, and the marketing and store page files that `Tools/media/marketing.py` writes.

**Gate**: `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`; green PR checks.

**Evidence of done**: the #534 head SHA with green checks; the list of included PRs; the list of retaken pictures, with one line on what changed in each.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
